-- #include save_restore.lua
function save_game(char) end
function restore_game() end

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
	log("  [drw]  reset_io_state fg = "..current_fg..", bg = "..current_bg)

	current_text_style = 0
	text_format_updated = false
	window_attributes = 0b00000000.00001010

	emit_rate = 0 --the lower the faster
	clock_type, cursor_type = nil, nil
	make_bold, make_inverse = false, false

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

	origin_y = (_zm_version == 3) and 7 or 0
	windows[0].h = _zm_screen_height

	did_trim_nl, clear_last_line = false, false
	lines_shown = 0

	z_text_buffer, z_parse_buffer = nil, nil
	z_timed_interval, z_timed_routine = 0, nil
	z_current_time = 0
	current_input, visible_input = '', ''

	show_warning = true
end

text_colors = ''
function update_text_colors()
	log("  [drw] update_text_colors: fg = "..current_fg..", bg = "..current_bg)
	text_colors = '\f'..tostr(current_fg,true)[6]..'\#'..tostr(current_bg,true)[6]
	text_format_updated = true
end

text_styles = ''
function _set_text_style(n)
	log("  [drw] _set_text_style to: "..n)
	if (n > 0) n |= current_text_style
	make_bold, make_inverse = (n&2 == 2), (n&1 == 1)
	local inverse = (make_inverse == true) and '\^i' or '\^-i'
	local border = (active_window == 0) and '\^-b' or ''
	local emphasis = (n > 1) and '\014' or '\015'
	if checksum == 0xfc65 then -- Bureaucracy masterpiece
		if (active_window == 1) and (make_bold == true) then
			--suppress bold in window 1 because of form fields
			inverse, emphasis, make_bold = '\^i', '\015', false
		end
	end
	text_styles = emphasis..inverse..border
	log("  [drw] text_styles is: "..text_styles)
	current_text_style = n
	local font_width = 4
	if (n > 1) font_width = 5
	if (make_bold == true) font_width = 6
	set_zbyte(_font_width_units_addr, font_width)
	text_format_updated = true
end

function set_z_cursor(_win, _x, _y)
	log3(" set_z_cursor: ".._win..', x: '.._x..', y: '.._y)
	local win = windows[_win]
	local px = flr((_x - 1) << 2) + 1
	local py = ((_y - 1) * 6) + 1
	if (_zm_version > 3 and _win == 0) py += 1
	local py_offset = (_win == 0) and windows[1].h*6 or 0
	win.p_cursor = {px, py + py_offset + origin_y}	
	win.z_cursor = {_x, _y}
end

function memory(str)
	-- log('  [mem] memory asked to record '..#str..' zscii chars')
	if (#str == 0) return
	local addr = mem_stream_addr[#mem_stream_addr]
	local table_len = get_zword(addr)
	local p8bytes = pack(ord(str,1,#str))
	set_zbytes(addr + 0x.0002 + (table_len>>>16), p8bytes)
	set_zword(addr, table_len + #p8bytes)
end

--process word wrapping into a buffer
function output(str, flush_now)
	log3('  [drw] output to window '..active_window..', raw str: '..str)
	if (mem_stream == true) memory(str) return
	if (screen_stream == false) return

	local buffer = windows[active_window].buffer
	local current_format = text_styles .. text_colors
	local current_line = deli(buffer)

	if current_line then
		if text_format_updated == true then
			current_line ..= current_format
			text_format_updated = false
		end
	else
		current_line = current_format
	end

	local pixel_len = print(current_line, 0, -20)

	for i = 1, #str do
		local char = case_setter(str[i], flipcase)
		
		-- adjust visual length; don't call print() every char to get the new length
		if (char != '\n') pixel_len += 4
		if make_bold == true then
			if (char >= ' ') char = chr(ord(char) + 96)
			if (char != '\n') pixel_len += 1
		end

		--add the adjusted character (might have switched to bold font set)
		current_line ..= char

		-- have we found a visually appealing line-break character?
		if (in_set(char, " \n:-_;")) break_index = #current_line

		-- handle right border and newline wrap triggers
		if pixel_len > 128 or char == '\n' then
			local first, second = unpack(split(current_line, break_index, false))
			add(buffer, first)

			second = second or ''
			while (second[1] == ' ') second = sub(second,2)

			current_line = current_format..second
			pixel_len = print(current_line, 0, -20)
			break_index = 0
		end
	end

	-- add remaining content to buffer and flush
	if (#current_line) add(buffer, current_line)
	if (_interrupt or flush_now) flush_line_buffer()
end

--buffered lines receive pagination
function flush_line_buffer(_w)
	local w = _w or active_window
	local win = windows[w]
	local buffer = win.buffer

	if (#buffer == 0 or win.h == 0) return

	clip(unpack(win.screen_rect))
	while #buffer > 0 do

		local str = deli(buffer, 1)
		if (str == text_styles..text_colors) goto continue 
		
		-- Pagination needed first?
		if w == 0 and lines_shown == (win.h - 1) then
			screen("\^i"..text_colors.."          - - MORE - -          ")
			reuse_last_line, lines_shown = true, 0
			wait_for_any_key()
			lines_shown = 0
		end

		-- Trim newline if present
		did_trim_nl = false
		if str[-1] == '\n' then
			str = sub(str, 1, -2)
			-- if w == 0 or (w == 1 and _zm_version == 3) then
				did_trim_nl = true
			-- end
		end

		-- Display the line and track last line
		win.last_line = str
		screen(str)

		::continue::
	end
	clip()
end

--actually put text onto the screen and adjust the z_cursor to reflect the new state
function screen(str)
	log3(' [drw] screen ('..active_window..'): '..str)
	local win = windows[active_window]
	local zx, zy = unpack(win.z_cursor)
	log3("   window "..active_window.." z_cursor start at: "..zx..','..zy)

	local px, py = unpack(win.p_cursor)
	if active_window == 0 then
		if reuse_last_line == true then
			--skip the line scroll
			log3("   reusing last line")
			reuse_last_line = false
		else
			if (did_trim_nl == true) print(text_colors..'\n',px,py)

			--scroll up by a line to make room for the next line
			log3("   scrolling up by a line")
			print(text_colors..'\n')
		end

		rectfill(0,121,128,128,current_bg)

		--print the line to screen and update the lines_shown count 
		--this will be caught by pagination on the next line flushed
		local pixel_count = print('\^d'..emit_rate..str, 1, 122) - 1
		log3("   win0 pixel count: "..pixel_count)
		
		zx = flr(pixel_count>>2) + 1 -- z_cursor starts at 1,1
		zy = win.h
		lines_shown += 1
	else
		--  = print(str,0,-20)
		local pixel_count = print(str, px, py) - px
		log3("   win1 pixel count: "..pixel_count)

		zx += flr(pixel_count>>2)
		-- if _zm_version == 3 then
			if did_trim_nl == true then
				zx = 1
				zy += 1
			end
		-- end
	end

	set_z_cursor(active_window, zx, zy)
	log3("   z_cursor moved to: "..zx..','..zy)
	flip()
end

function _tokenise(baddr1, baddr2, baddr3, _bit)
	-- log('[prs] _tokenise from: '..tohex(baddr1)..' into: '..tohex(baddr2)..' alt dict: '..tohex(baddr3)..' bit?: '..tohex(_bit or 0))
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
	-- log("  [prs] num_bytes: "..num_bytes)
	-- move past the parse_buffer header info: max tokens and token_count
	parse_buffer += 0x.0002

	-- accumulators for the found elements
	local word, index, token_count = "", 0, 0
	local offset = (_zm_version < 5) and 0 or 1

	local function commit_token()
		if #word > 0 then
			local word_addr = dict[sub(word,1,_zm_dictionary_word_length)] or 0x0

			if (bit > 0) and (word_addr == 0x0) then
				--nothing to do here
			else
				set_zword(parse_buffer, word_addr)
				set_zbyte(parse_buffer+0x.0002, #word)
				set_zbyte(parse_buffer+0x.0003, index+offset)
				log("  [prs] token for "..word..": "..tohex(word_addr)..', '..#word..', '..index+offset)
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
		--do we have a token commit trigger?
		if char == ' ' or in_set(char, separators) then
			commit_token()
			word = (char != ' ') and char or ""
			index = (char != ' ') and j or 0
		
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
	log("  [prs] _encode_text: "..tohex(baddr1)..', '..n..', '..p)
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

function process_input_char(real, visible, max_length)
	if real == '\b' then
		if #current_input > 0 then
			current_input = sub(current_input, 1, -2)
			visible_input = sub(visible_input, 1, -2)
		end
	elseif real != '' then
		if #current_input < max_length then
			current_input ..= real
			visible_input ..= case_setter(visible, visual_case)
		end
	end
	reuse_last_line = true
	screen(windows[active_window].last_line..sub(visible_input, -30))
end

--called by read; z_text_buffer must be non-zero; z_parse_buffer could be nil
function capture_char(char)
	capture_input(char)
end

function capture_line(char)
	capture_input(char)
end

function capture_input(char)
	lines_shown = 0

	if z_timed_routine then
		local current_time = stat(94)*60 + stat(95)
		log3("checking current time: "..tostr(current_time).." vs. "..z_current_time)
		if (current_time - z_current_time) >= z_timed_interval then
			-- log3("calling timed_routine...")
			local timed_response = _call_fp(call_type.intr, z_timed_routine)
			log3("timed_response says: "..timed_response)
			if timed_response == 1 then
				_read(0) --false
			end
			z_current_time = current_time
		end
	end
	
	if (not char) draw_cursor() return
	poke(0x5f30,1)

	draw_cursor(current_bg)

	if (_interrupt == capture_char) _read_char(char)

	if _interrupt == capture_line then
		if char == '\r' then
			--strip whitespace; was external function but only used here
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
			process_input_char(case_setter(char, lowercase), char, max_input_length)
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
	-- score = tostr(stat(0))
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