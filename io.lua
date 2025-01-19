zchar_map_str = [[
	00, 00, 00, 00, 05, 00, 00, 00, 00, 07,
    00, 00, 00, 00, 00, 00, 00, 00, 00, 00,
    00, 00, 00, 00, 00, 00, 00, 00, 00, 00,
    00, 32, 20, 25, 23, 00, 00, 00, 24, 30,
    31, 00, 00, 19, 28, 18, 26, 00, 01, 02,
    03, 04, 05, 06, 07, 08, 09, 29, 00, 00,
    00, 00, 21, 00, 06, 07, 08, 09, 10, 11,
    12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    00, 27, 00, 00, 22, 00, 06, 07, 08, 09,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
    30, 31
]]
zchar_map = split(zchar_map_str)

function reset_io_state()
	current_bg, current_fg, current_font = 0, 15, 1
	if (full_color == true) then
		current_fg = get_zbyte(_default_fg_color_addr)
		current_bg = get_zbyte(_default_bg_color_addr)
	end
	pal(0,current_bg)
	-- log("  [drw]  reset_io_state fg = "..current_fg..", bg = "..current_bg)

	current_text_style = 0
	text_style_updated = false
	text_style, text_colors = '', ''
	font_width = 4

	window_attributes = 0b00000000.00001010

	emit_rate = 0 --the lower the faster
	clock_type, cursor_type = nil, nil

	mem_stream, screen_stream, trans_stream, script_stream = false, true, false, false
	mem_stream_addr, memory_output = {}, {}

	active_window = 0
	windows = {
		[0] = {
			h = 21,
			z_cursor = {1,21},
			p_cursor = {0,0}, -- unnamed vars for unpack()ing
			screen_rect = {}, -- unnamed vars for unpack()ing
			buffer = {},
			last_line = ''
		},
		{
			h = 0,
			z_cursor = {1,1},
			p_cursor = {0,0},
			screen_rect = {},
			buffer = {},
			last_line = ''
		}
	}

	if (_zm_version >= 5) windows[0].z_cursor = {1,1}
	origin_y = (_zm_version == 3) and 7 or 0
	windows[0].h = _zm_screen_height

	did_trim_nl, reuse_last_line = false, false
	lines_shown = 0

	z_text_buffer, z_parse_buffer = nil, nil
	z_timed_interval, z_timed_routine = 0, nil
	z_current_time = 0
	current_input, visible_input = '', ''

	show_warning = true
end

function update_text_colors()
	-- log("  [drw] update_text_colors: fg = "..current_fg..", bg = "..current_bg)
	text_colors = '\f'..tostr(current_fg,true)[6]..'\#'..tostr(current_bg,true)[6]
	text_style_updated = true
end

function _set_text_style(n)
	-- log("  [drw] _set_text_style to: "..n)
	if (n > 0) n |= current_text_style

	local inverse = (n&1 == 1) and '\^i' or '\^-i\^-b'
	if (n&4 == 4 and n&2 != 2) inverse ..= "\^-b"
	local font_shift = (n&2 == 2 or n&4 == 4) and '\014' or '\015'
	font_width = (n&2 == 2) and 5 or 4

	if (game_id == "fc65" or game_id == "91e0") and active_window == 1 then -- Bureaucracy MP & SLC
		if (n&4 == 2) n	&= 0xb --suppress the bold bit; maybe not the best idea
	end

	set_zbyte(_font_width_units_addr, font_width)
	text_style = font_shift..inverse
	current_text_style = n
	text_style_updated = true
end

function set_z_cursor(_win, _x, _y)
	-- log(" set_z_cursor ".._win..'  x: '.._x..', y: '.._y)	
	local win = windows[_win]
	_x, _y = mid(1,_x,32), mid(1,_y,win.h)
	local px = flr((_x - 1) << 2) + 1
	local py = ((_y - 1) * 6) + 1
	-- log("  equals px: "..px..", py: "..py)
	if (_zm_version > 3 and _win == 0) py += 1
	local py_offset = (_win == 0) and windows[1].h*6 or 0
	win.p_cursor = {px, py + py_offset + origin_y}
	-- log("  win.p_cursor: "..win.p_cursor[1]..", "..win.p_cursor[2])
	cursor(unpack(win.p_cursor))
	-- log("  print cursor set to: "..peek(0x5f26)..", "..peek(0x5f27))
	win.z_cursor = {_x, _y}
end

function memory(str)
	if (#str == 0) return
	local addr = mem_stream_addr[#mem_stream_addr]
	local table_len = get_zword(addr)
	local p8bytes = pack(ord(str,1,#str))
	set_zbytes(addr + 0x.0002 + (table_len>>>16), p8bytes)
	set_zword(addr, table_len + #p8bytes)
end

--actually put text onto the screen and adjust the z_cursor to reflect the new state
-- local slow_down = false
function screen(str)
	-- local delay = 500
	local win = windows[active_window]
	clip(unpack(win.screen_rect))
	local zx, zy = unpack(win.z_cursor)
	-- log("  [drw] screen("..active_window.."): |"..str.."| (x: "..zx.." y: "..zy..")")
	-- if (sub(str,-9) == "LEFT ARM.") slow_down = true

	if active_window == 0 then
		-- log(" -- reuse last line says: "..tostr(reuse_last_line))
		-- log("print cursor starts at: "..peek(0x5f26)..", "..peek(0x5f27))
		if (reuse_last_line == false) print("\n")
		-- if (slow_down == true) if (reuse_last_line == false) log("1. scrolled up a line") for i = 1, 30000 do for j = 1, delay do end end
		-- log(" -- blanking the last line")
		rectfill(0,121,128,128,current_bg)
		-- if (slow_down == true) log("2. just drew a rectfill to blank out a line") for i = 1, 30000 do for j = 1, delay do end end

		--print the line to screen and update the lines_shown count 
		--this will be caught by pagination on the next line flushed
		-- log(" -- printing the string")
		local pixel_count = print('\^d'..emit_rate..str, 1, 122) - 1
		-- if (slow_down == true) log("3. drew the string to screen") for i = 1, 30000 do for j = 1, delay do end end

		if reuse_last_line == true then
			reuse_last_line = false
			if (pixel_count > 128 and _interrupt == capture_line) then
				rectfill(0,121,128,128,current_bg)
				-- if (slow_down == true) log("4. had to reblank the line, due to length") for i = 1, 30000 do for j = 1, delay do end end
				print('\^d'..emit_rate..str, 1-(pixel_count-128), 122)
				-- if (slow_down == true) log("5. reprinted the line with negative horizontal offset") for i = 1, 30000 do for j = 1, delay do end end
				-- log(" -- blanked and printed the string a second time (shifted)")
			end
		end
		
		zx = ceil(pixel_count>>2) -- z_cursor starts at 1,1
		zy = win.h
		lines_shown += 1
	else
		local px, py = unpack(win.p_cursor)
		local pixel_count = print(str, px, py) - px

		zx += ceil(pixel_count>>2)
		if did_trim_nl == true then
			--from docs: "the upper window should never be scrolled"
			zx = 1
			zy += 1
		end
	end

	set_z_cursor(active_window, zx, zy)
	-- log3("   z_cursor moved to: "..zx..','..zy)
	flip()
	clip()
end

--buffered lines receive pagination
function flush_line_buffer(_w)
	local w = _w or active_window
	local win = windows[w]
	local buffer = win.buffer

	if (#buffer == 0 or win.h == 0) return

	while #buffer > 0 do

		local str = deli(buffer, 1)
		
		-- Pagination needed first?
		if w == 0 and lines_shown == (win.h - 1) then
			screen("\^i"..text_colors.."          - - MORE - -          ")
			reuse_last_line, lines_shown = true, 0
			wait_for_any_key()
			lines_shown = 0
		end

		-- Trim newline if present
		did_trim_nl = false
		-- if w == 1 then
			if str[-1] == '\n' then
				str = sub(str, 1, -2)
				did_trim_nl = true
			end
		-- end

		-- Display the line and track it
		win.last_line = str
		screen(str)

	end
end

--process word wrapping into a buffer
local break_index = 0
function output(str, flush_now)
	-- log('output win'..active_window..': '..str)
	if (mem_stream == true) memory(str) return
	if (screen_stream == false) return

	local buffer = windows[active_window].buffer
	local current_format = text_style..text_colors
	local current_line = deli(buffer)

	if current_line then
		if text_style_updated == true then
			current_line ..= current_format
			text_style_updated = false
		end
	else
		current_line = current_format
	end

	local cx, cy = cursor(0, -20)
	local pixel_len = print(current_line)
	cursor(cx,cy)

	for i = 1, #str do
		local char = case_setter(str[i], flipcase)
		local c = char
		
		-- estimate the total visual length
		if (char != '\n') pixel_len += font_width

		-- switch into bold font, if needed
		if current_text_style & 2 == 2 then --bold characters sit in shifted range
			if (char >= ' ') char = chr(ord(char) + 96)
		end

		--add the character
		current_line ..= char

		if active_window == 0 then
			-- have we found a visually appealing line-break character?
			-- have to check the char BEFORE it was emboldened
			-- but we need the length of the line AFTER the char was added
			if (in_set(c, " \n:-_;")) break_index = #current_line

			-- handle right border and newline wrap triggers
			if pixel_len > 128 or c == '\n' then
				if (break_index == 0) break_index = #current_line-1
				local first, second = unpack(split(current_line, break_index, false))
				add(buffer, first)

				second = second or ''
				while (second[1] == ' ') second = sub(second,2)

				current_line = current_format..second
				cx, cy = cursor(0, -20)
				pixel_len = print(current_line)
				cursor(cx,cy)

				break_index = 0
			end
		else 
			if c == '\n' then
				add(buffer, current_line)
				current_line = current_format
				flush_line_buffer()
			end
		end
	end

	-- add remaining content to buffer and flush
	if (#current_line > 0) add(buffer, current_line)
	if (flush_now == true) flush_line_buffer()
end

function _tokenise(baddr1, baddr2, baddr3, _bit)
	local bit = _bit or 0
	local text_buffer = zword_to_zaddress(baddr1)
	local parse_buffer = zword_to_zaddress(baddr2)
	baddr2 = parse_buffer --cache the start pointer
	local dict = (baddr3 == nil) and _main_dict or build_dictionary(zword_to_zaddress(baddr3))

	-- move past the text_buffer header info
	text_buffer += 0x.0001
	local num_bytes = 255
	if _zm_version >= 5 then
		num_bytes = get_zbyte(text_buffer)
		text_buffer += 0x.0001
	end

	-- move past the parse_buffer header info: max tokens and token_count
	parse_buffer += 0x.0002

	-- accumulators for the found elements
	local word, index, token_count = "", 0, 0
	local offset = (_zm_version < 5) and 0 or 1

	local function commit_token()
		if #word > 0 then
			local word_addr = dict[sub(word,1,_zm_dictionary_word_length)] or 0x0
			-- log("commit_token: "..word)
			if (bit > 0) and (word_addr == 0x0) then
				--nothing to do here
			else
				set_zword(parse_buffer, word_addr)
				set_zbyte(parse_buffer+0x.0002, #word)
				set_zbyte(parse_buffer+0x.0003, index+offset)
			end
			parse_buffer += 0x.0004
			token_count += 1
		end
	end

	for j = 1, num_bytes do
		local c = get_zbyte(text_buffer)
		text_buffer += 0x.0001
		if (_zm_version < 5 and c == 0) then break end

		local char = chr(c)
		-- log("tokenizing byte: "..tostr(c).." as char: "..char)
		--do we have a token commit trigger?
		if char == ' ' or in_set(char, separators) then
			commit_token()
			word, index = "", 0
			if char != ' ' then
				word, index = char, j
				commit_token()
				word, index = "", 0
			end
		--start tracking a new token
		else
			if (index == 0) index = j
			word ..= char
		end
	end
	commit_token() --capture that last byte, if valid

	-- Update token count in parse buffer
	set_zbyte(baddr2 + 0x.0001, token_count)
end

function _encode_text(baddr1, n, p, baddr2)
	-- log("  [prs] _encode_text: "..tohex(baddr1)..', '..n..', '..p)
	if (not baddr2) return --we don't use this function ourselves

	local zwords, word, count = {}, 0, 1

	local function commit(v)
		word = (word << 5) | v
		if count % 3 == 0 then
			add(zwords, word)
			word = 0
		end
		count += 1
	end

	local input_addr = zword_to_zaddress(baddr1 + p)
	local bytes = get_zbytes(input_addr, n)
	local max_words = (_zm_version < 4) and 2 or 3

	for i = 1, max_words*3 do
		local o = ord(str[i]) or 5
		if mid(65, o, 90) == o then 
			commit(4)
		elseif o == 10 or
				mid(48, o, 57) == o or
				in_set(str[i], punc) then
			commit(5)
		end
		commit(zchar_map[o])

		if (#zwords >= max_words) break
	end
	zwords[#zwords] |= 0x8000 -- set bit flag for end of zstring
	
	local out_addr = zword_to_zaddress(baddr2)
	for word in all(zwords) do
		set_zword(out_addr, word)
		out_addr += 0x.0002
	end
end

--visual_case refers to how input from the keyboard is processed
--ASCII holds capital letters in a different range than P8SCII does
--So 'Q' typed becomes '...', which we have to remap to P8's 'Q'
lowercase, visual_case, flipcase = 1, 2, 3
function case_setter(char, case)
	local o = ord(char)

	if case == lowercase then
		if (o >= 128 and o <= 153) then
			o -= 31
		elseif (o >= 65 and o <= 90) then
			o += 32
		end

	elseif case == visual_case then
		if (o >= 97 and o <= 122) then
			o -= 32
		elseif (o >= 128 and o <= 153) then 
			o -= 31
		end
	
	elseif case == flipcase then
		if (o >= 97 and o <= 122) then
			o -= 32
		elseif (o >= 65 and o <= 90) then
			o += 32
		elseif o == 13 then
			o = 10
		end
	end

	return chr(o)
end

function process_input_char(char, max_length)
	if char == '\b' then
		if #current_input > 0 then
			current_input = sub(current_input, 1, -2)
			visible_input = sub(visible_input, 1, -2)
		end
	elseif char and char != '' and char != '\r' then
		if #current_input < max_length then
			current_input ..= case_setter(char, lowercase)
			visible_input ..= case_setter(char, visual_case)
		end
	end

	reuse_last_line = true
	screen(windows[active_window].last_line..visible_input..cursor_string)
end

--called by read; z_text_buffer must be non-zero; z_parse_buffer could be nil
function capture_char(char)
	cursor_string = " "
	capture_input(char)
end

function capture_line(char)
	capture_input(char)
end

preloaded = false
function capture_input(char)
	lines_shown = 0

	local win = windows[active_window]
	if char then
		poke(0x5f30,1)

		if _interrupt == capture_char then
			_read_char(char)

		elseif _interrupt == capture_line then

			--prep the input line, if necessary
			if _zm_version >= 5 and preloaded == false then
				local text_buffer = zword_to_zaddress(z_text_buffer)
				local num_bytes = get_zbyte(text_buffer + 0x.0001)
				if num_bytes > 0 then
					local pre = get_zbytes(text_buffer+0x.0002, num_bytes)
					local zstring = zscii_to_p8scii(pre, lowercase)
					local flipped = zscii_to_p8scii(pre, flipcase)
					local last_line = win.last_line
					local left, right = unpack(split(last_line, #last_line-num_bytes))
					if (flipped == right) then
						win.last_line = left
						current_input = zstring
						visible_input = right
					end
				end
				preloaded = true
			end

			if char == '\r' then
				reuse_last_line = true
				add(win.buffer, win.last_line..visible_input) --commit user input to the transcript
				add(win.buffer, text_style..text_colors) --prep the buffer for the next line

				--strip whitespace
				local words, stripped = split(current_input, ' ', false), ''
				for w in all(words) do
					if (#w > 0) stripped ..= (#stripped == 0 and '' or ' ')..w
				end
				current_input = stripped
	
				--fill text buffer
				local bytes = pack(ord(current_input, 1, #current_input))
	
				local text_buffer = zword_to_zaddress(z_text_buffer)
				local addr = text_buffer + 0x.0001
				if _zm_version >= 5 then
					local num_bytes = get_zbyte(addr)
					if (preloaded == true) num_bytes = 0
					set_zbyte(addr, #bytes+num_bytes)
					addr += 0x.0001 + (num_bytes>>>16)
				else 
					add(bytes, 0x0)
				end
				set_zbytes(addr, bytes)
				
				--handle the parse buffer
				if (z_parse_buffer) _tokenise(z_text_buffer, z_parse_buffer)
				_read(13)
	
			else
				if (max_input_length == 0) max_input_length = get_zbyte(zword_to_zaddress(z_text_buffer)) - 1
				process_input_char(char, max_input_length)
			end

		end

	else
		if (active_window == 0 and _interrupt == capture_line) process_input_char()

		if z_timed_routine then
			local current_time = stat(94)*60 + stat(95)
			if (current_time - z_current_time) >= z_timed_interval then
				local cached_line = win.last_line --routines that print to screen need to restore back to input state
				local timed_response = _call_fp(call_type.intr, z_timed_routine)
				if timed_response == 1 then
					_read(0) --false
				end
				if (_interrupt == capture_line) win.last_line = cached_line
				flush_line_buffer()
				z_current_time = current_time
			end
		end
	end
end

function dword_to_str(dword)
	local hex = tostr(dword,3)
	return sub(hex,3)
end

--only for v3 games; I'd like to rework this to use far fewer tokens
function show_status()
	local obj = get_zword(_global_var_table_mem_addr) --global 0
	local location = zobject_name(obj)
	local scorea = get_zword(_global_var_table_mem_addr + 0x.0002) --global 1
	local scoreb = get_zword(_global_var_table_mem_addr + 0x.0004) --global 2
	local flag = get_zbyte(_interpreter_flags_header_addr)
	local separator = '/'
	if (flag & 2) == 2 then
		local ampm = ''
		separator = ':'
		if clock_type == 12 then
			ampm = 'a'
			if scorea >= 12 then 
				ampm = 'p'
				scorea -= 12
			end
			if (scorea == 0) scorea = 12
		end
		scoreb = sub('0'..scoreb, -2)..ampm
	end

	local score = scorea..separator..scoreb..' '
	local loc = ' '..sub(location, 1, 30-#score-2)
	if (#loc < #location) loc = sub(loc, 1, -2)..chr(144)
	local spacer_len = 32 - #loc - #score
	local spacer = sub(blank_line,-spacer_len)
	loc ..= spacer..score
	local flipped = ""
	for i = 1, #loc do
		flipped ..= case_setter(loc[i], flipcase)
	end
	print('\^i'..text_colors..flipped, 1, 1)
end