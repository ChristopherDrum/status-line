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
	
	current_text_style = 0
	current_format, current_format_updated = '', false
	window_attributes = 0b00000000.00001010

	emit_rate = 0 --the lower the faster
	clock_type, cursor_type = nil, nil
	make_bold, make_inverse = false, false

	mem_stream, screen_stream, trans_stream, script_stream = false, true, false, false
	mem_stream_addr, memory_output = {}, {}

	active_window = 0
	windows = {
		[0] = {
			y = 1, -- x is ALWAYS 1
			h = 21, -- w is ALWAYS 32
			z_cursor = {x=1,y=21}, --formerly cur_x, cur_y
			p_cursor = {0,0}, -- unnamed vars for unpack()ing
			screen_rect = {},
			buffer = {},
			last_line = ''
		},
		{
			y = 1,
			h = 0,
			z_cursor = {x=1,y=1},
			p_cursor = {0,0},
			screen_rect = {},
			buffer = {}
		}
	}

	origin_y = nil
	break_chars = "\n :-_;"
	break_index = 0

	did_trim_nl, clear_last_line = false, false
	lines_shown = 0

	z_text_buffer, z_parse_buffer = nil, nil
	current_input, visible_input = '', ''

	show_warning = true
end

function current_color_string()
	return '\f'..tostr(current_fg,true)[6]..'\#'..tostr(current_bg,true)[6]
end

function _set_text_style(n)
	-- log("  [drw] _set_text_style to: "..n)
	if (n > 0) n |= current_text_style
	local inverse, emphasis = '\^-i\^-b', '\015'
	make_bold, make_inverse = (n&2 == 2), (n&1 == 1)

	if (make_inverse == true) inverse = '\^i\^-b'
	if (n > 1) emphasis = '\014'
	if checksum == 0xfc65 then -- Bureaucracy masterpiece
		if (active_window == 1) and (make_bold == true) then
			--suppress bold in window 1 because of form fields
			inverse, emphasis, make_bold = '\^i', '\015', false
		end
	end
	current_format = inverse..emphasis..current_color_string()
	-- log("  [drw] current_format is: "..current_format)
	current_format_updated = true
	current_text_style = n
end

function update_screen_rect(zwin_num)
	if (not origin_y) origin_y = (_zm_version == 3) and 8 or 1
	local win = windows[zwin_num]
	local py = (win.y-1)*6 + origin_y
	if (_zm_version > 3 and zwin_num == 1) py = 0
	local ph = (win.h)*6
	-- log('  [drw] setting screen rect '..zwin_num..': 0, '..py..', 128,'..(origin_y+ph))
	win.screen_rect = {0, py, 128, origin_y+ph}
end

function update_p_cursor()
	local win = windows[active_window]
	local px, py, w, h = unpack(win.screen_rect)
	local cx, cy = win.z_cursor.x, win.z_cursor.y
	px = ((cx - 1)<<2) + 1
	py += (cy - 1)*6 + 1
	if (_zm_version == 3) py -= 1
	win.p_cursor = {px, py}
end

function memory(str)
	log('  [mem] memory asked to record '..#str..' zscii chars')
	if (#str == 0) return
	local addr = mem_stream_addr[#mem_stream_addr]
	local table_len = get_zword(addr)
	local p8bytes = pack(ord(str,1,#str))
	set_zbytes(addr + 0x.0002 + (table_len>>>16), p8bytes)
	set_zword(addr, table_len + #p8bytes)
end

function output(str, flush_now)
	-- log('  [drw] ('..active_window..') output str: '..str)
	if (mem_stream == true) memory(str) return
	if screen_stream == true then
		log('  [drw] output to screen '..active_window..': '..str)
		local buffer = windows[active_window].buffer
		local current_line = nil
		if (#buffer > 0) current_line = deli(buffer)

		if not current_line then
			current_line = current_format
			current_format_updated = false
		end

		local visual_len = print(current_line, 0, -20)

		for i = 1 , #str do
			local char = case_setter(ord(str,i), flipcase)

			if current_format_updated == true then
				current_line ..= current_format
				current_format_updated = false
			end

			local o = ord(char)
			visual_len += 4
			if make_bold == true then
				if (o >= 32) o+=96
				if (o != 10) visual_len += 1
			end 
			current_line ..= chr(o)

			if (in_set(char, break_chars)) break_index = #current_line
			if (visual_len > 128) or (char == '\n') then

				local next_line, next = current_format, nil
				current_line, next = unpack(split(current_line, break_index, false))
				if (next) next_line ..= next 

				add(buffer, current_line)

				visual_len = print(next_line, 0, -20)
				current_line = next_line
				current_format_updated = false

				break_index = 0
			end
		end
		if (current_line) add(buffer, current_line)
	end
	if (flush_now) flush_line_buffer()
end

function flush_line_buffer()
	local win = windows[active_window]
	local buffer = win.buffer
	-- log('  [drw] flush_line_buffer '..active_window..', '..tostr(#buffer)..' lines')
	-- log('  [drw]    lines shown: '..lines_shown..' vs win height: '..win.h)
	if (#buffer == 0 or win.h == 0) return
	-- log('  [drw]    flush window '..active_window..' with line height: '..win.h)
	while #buffer > 0 do
		local str = deli(buffer, 1)
		if (str == current_format) goto skip
		if active_window == 0 then
			if #buffer != 0 then
				if lines_shown == (win.h - 1) then
					screen("\^i"..current_color_string().."          - - MORE - -          ")
					reuse_last_line = true
					wait_for_any_key()
					lines_shown = 0
				end
			end
		end
		-- log('last char: '..ord(sub(str,-1)))
		if str[-1] == '\n' then
			str = sub(str,1,-2)
			if (active_window == 0 or (active_window == 1 and _zm_version == 3)) did_trim_nl = true
		end
		-- if (active_window == 0) did_trim_nl = dtn
		win.last_line = str
		screen(str)
		::skip::
	end
	-- log('  [drw] after flushing, buffer len is: '..#windows[active_window].buffer)
end

function screen(str)
	-- log('  [drw] screen '..active_window..': '..str)
	local win = windows[active_window]

	clip(unpack(win.screen_rect))
	local x = print(str,0,-20)
	local cx = x>>>2

	cursor(unpack(win.p_cursor))
	if active_window == 0 then
		if reuse_last_line == true then
			rectfill(0,121,128,128,current_bg)
			reuse_last_line = false
		else
			print('\n')
		end
		cursor(1,122)
		print('\^'..emit_rate..str)
		cx += 1
		lines_shown += 1
	else
		if win.z_cursor.y <= win.h then
			print(str)
			cx += win.z_cursor.x
			if _zm_version == 3 then
				if did_trim_nl == true then
					cx = 1
					win.z_cursor.y += 1
				end
			end
		end

	end

	win.z_cursor.x = cx
	update_p_cursor()

	flip()
	clip()
end

function _tokenise(baddr1, baddr2, baddr3, _bit)
	log('[prs] _tokenise from: '..tohex(baddr1)..' into: '..tohex(baddr2)..' alt dict: '..tohex(baddr3)..' bit?: '..tohex(bit))
	local tokens, index, z_adjust = {}, 0, 0
	local bit = _bit or 0
	str = ''

	local function commit(i)
		if (index == 0) return
		local s = sub(str,index,i-1)
		-- log("commit token: ^"..s.."^")
		if (_zm_version > 4) index += 1
		add(tokens, {s,index,z_adjust})
		index, z_adjust = 0, 0
	end

	local text_buffer = zword_to_zaddress(baddr1)
	local parse_buffer = zword_to_zaddress(baddr2)

	local addr = text_buffer + 0x.0001
	local num_bytes = 256
	if _zm_version >= 5 then
		num_bytes = get_zbyte(addr)
		addr += 0x.0001
	end

	--this is redundant work for a direct pipeline
	local j = 1
	while true do
		if (j > num_bytes) break
		local c = get_zbyte(addr)
		if (_zm_version < 5 and c == 0) break
		str ..= chr(c)
		addr += 0x.0001
		j+=1
	end

	for i = 1, #str do
		local char = str[i]

		if (in_set(char, punc)) z_adjust += 1

		if char == ' ' then
			commit(i)

		elseif in_set(char, separators) then
			z_adjust -= 1
			commit(i)
			add(tokens, {char,i,0})

		elseif index == 0 then
			index = i
		end
	end
	commit(#str+1)
	-- log("  [prs] token count: "..#tokens)
	local dict = _main_dict
	if (baddr3 != nil) dict = build_dictionary(zaddress_at_zaddress(baddr3))

	local parse_buffer_length = get_zbyte(parse_buffer)
	-- local max_tokens = min(#tokens, parse_buffer_length)
	parse_buffer += 0x.0001
	set_zbyte(parse_buffer, #tokens)
	parse_buffer += 0x.0001
	for i = 1, #tokens do
		local word, index, z_adjust = unpack(tokens[i])
		log("  [prs]  looking up substring: ^"..sub(word,1,_zm_dictionary_word_length-z_adjust).."^")
		local dict_addr = dict[sub(word,1,_zm_dictionary_word_length-z_adjust)] or 0x0
		
		if (bit > 0) and (dict_addr == nil) then
			--nothing to do here
		else
			set_zword(parse_buffer, dict_addr)
			set_zbyte(parse_buffer+0x.0002, #word)
			set_zbyte(parse_buffer+0x.0003, index)
			log("  [prs] token values set to: "..dict_addr..','..#word..','..index)
		end
		parse_buffer += 0x.0004
	end
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
	set_zwords(baddr2, zwords)
	
end


lowercase, visual_case, flipcase = 1, 2, 3
function case_setter(char, case)
	local o = (case == flipcase) and char or ord(char)

	if case == lowercase then
		if (in_range(o,128,153)) o -= 31
		if (in_range(o,65,90)) o += 32

	elseif case == visual_case then
		if (in_range(o,97,122)) o -= 32
		if (in_range(o,128,153)) o -= 31
	
	elseif case == flipcase then
		if in_range(o,97,122) then
			o -= 32
		elseif in_range(o,65,90) then
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
function capture_input(char)
	lines_shown = 0
	if (not char) draw_cursor() return
	poke(0x5f30,1)

	draw_cursor(current_bg)

	if (max_input_length == 0) max_input_length = get_zbyte(zword_to_zaddress(z_text_buffer)) - 1

	-- log('[prs] current input: '..current_input)
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

		current_input, visible_input = '', ''
		_read(13)

	else
		process_input_char(case_setter(char, lowercase), char, max_input_length)
	end
end

function dword_to_str(dword)
	local hex = tostr(dword,3)
	return sub(hex,3)
end

--only for v3 games; I'd like to rework this to use far fewer tokens
function show_status()

	local obj = get_zword(global_var_addr(0))
	local location = zobject_name(obj)
	local scorea = get_zword(global_var_addr(1))
	local scoreb = get_zword(global_var_addr(2))
	local flag = get_zbyte(_interpreter_flags_header_addr)
	local separator = '/'
	if (flag & 2) == 2 then
		local ampm = ''
		if clock_type == 12 then
			ampm = 'a'
			if scorea >= 12 then 
				ampm = 'p'
				scorea -= 12
			end
			if (scorea == 0) scorea = 12
		end
		separator = ':'
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
		flipped ..= case_setter(ord(loc,i), flipcase)
	end
	print('\^i'..current_color_string()..flipped, 1, 1)
end