function reset_io_state()
	current_bg, current_fg, current_font = 0, 1, 1
	
	current_format = ''
	current_format_updated = false
	window_attributes = 0b00000000.00001010

	emit_rate = 0 --the lower the faster
	clock_type, cursor_type = nil, nil
	make_bold, make_inverse = false, true

	screen_output = true
	memory_output = {}

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

	z_text_buffer, z_parse_buffer = 0x0, 0x0
	current_input, visible_input = '', ''

	show_warning = true
end

function _set_text_style(n)
	local inverse, emphasis = '\^-i\^-b', '\015'
	make_bold = (n&2 == 2)
	make_inverse = (n&1 == 1)

	if (make_inverse == true) inverse = '\^i'
	if (n > 1) emphasis = '\014'
	if checksum == 0xfc65 then -- Bureaucracy masterpiece
		if (active_window == 1) and (make_bold == true) then
			--suppress bold in window 1 because of form fields
			inverse, emphasis, make_bold = '\^i', '\015', false
		end
	end

	current_format = inverse..emphasis..'\f'..current_fg..'\#'..current_bg
	current_format_updated = true
end

function update_screen_rect(zwin_num)
	if (not origin_y) origin_y = (_zm_version == 3) and 8 or 1
	local win = windows[zwin_num]
	local py = (win.y-1)*6 + origin_y
	if (_zm_version > 3 and zwin_num == 1) py = 0
	local ph = (win.h)*6
	-- log('setting screen rect '..zwin_num..': 0, '..py..', 128,'..(origin_y+ph))
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
	return px, py
end

--remove extraneous white space from player input
function strip(str)
	local words = split(str, ' ', false)
	local stripped = ''
	for i = 1, #words do
		local w = words[i]
		if (w != '') stripped ..= w..' '
	end
	if (stripped[-1] == ' ') stripped = sub(stripped, 1, -2)
	return stripped
end


function memory(str)
	-- log('==> memory at level: '..#memory_output)
	if ((#memory_output == 0) or (#str == 0)) return
	local table_addr = zword_to_zaddress(memory_output[#memory_output])
	-- log('  memory asked to record '..#str..' zscii chars')
	local table_len = get_zword(table_addr)
	-- log('  current table len '..table_len)
	local zscii = p8scii_to_zscii(str)
	set_zbytes(table_addr + 0x.0002 + (table_len>>>16), zscii)
	set_zword(table_addr, table_len + #zscii)
end

function p8scii_to_zscii(str)
	local zscii = {}
	for i = 1, #str do
		local o = ord(str,i)
		if (o == 13) o = 10
		add(zscii, o)
	end
	return zscii
end

function output(str, flush_now)
	-- log('('..active_window..') output str: '..str)
	if #memory_output > 0 then
		-- log('   redirected to memory')
		memory(str) 
	else
		if (screen_output == false) return
		-- log('   output to screen '..active_window..': '..str)
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

			-- log('considering char: '..char)
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
			-- log('current line: '..current_line)
			if (visual_len > 128) or (char == '\n') then

				local next_line, next = current_format, nil
				current_line, next = unpack(split(current_line, break_index, false))
				if (next) next_line ..= next 
				-- log('on split current: '..current_line)
				-- log('on split next: '..next_line)

				add(buffer, current_line)
				-- add(buffer, '')
				-- flush_line_buffer()

				visual_len = print(next_line, 0, -20)
				current_line = next_line
				current_format_updated = false

				break_index = 0
			end
		end
		-- buffer[#buffer] = current_line
		if (current_line) add(buffer, current_line)
	end
	if (flush_now) flush_line_buffer()
end

function flush_line_buffer()
	local win = windows[active_window]
	local buffer = win.buffer
	-- log('flush_line_buffer '..active_window..', '..tostr(#buffer)..' lines')
	-- log('  lines shown: '..lines_shown..' vs win height: '..win.h)
	if (#buffer == 0 or win.h == 0) return
	-- log('flush window '..active_window..' with line height: '..win.h)
	while #buffer > 0 do
		local str = deli(buffer, 1)
		if (str == current_format) goto skip
		if active_window == 0 then
			-- if sub(str, -1) != '>' then
			if #buffer != 0 then
				if lines_shown == (win.h - 1) then
					screen("\^i\#0\f1          - - MORE - -          ")
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
	-- log('after flushing, buffer len is: '..#windows[active_window].buffer)
end

function screen(str)
	-- log('screen '..active_window..': '..str)
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

function tokenise(str)
	-- log('tokenise: '..str)
	local tokens, bytes = {}, {}
	local index = 0
	local z_adjust = 0

	local function commit(i)
		if (index == 0) return
		local s = sub(str,index,i-1)
		add(tokens, {s,index,z_adjust})
		index = 0
		z_adjust = 0
	end

	for i = 1, #str do
		local char = str[i]
		-- log('  char '..i..': '..ord(char))
		add(bytes, ord(char))

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
	add(bytes, 0x0)
	return bytes, tokens
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
			current_input = sub(current_input, 1, #current_input - 1)
			visible_input = sub(visible_input, 1, #visible_input - 1)
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

--called by read; buffer addresses must be non-zero
function capture_input(char)
	lines_shown = 0
	if (not char) draw_cursor() return
	poke(0x5f30,1)

	draw_cursor(current_bg)

	if (max_input_length == 0) max_input_length = get_zbyte(z_text_buffer) - 1
	if (z_parse_buffer_length == 0) z_parse_buffer_length = get_zbyte(z_parse_buffer)

	-- log('current input: '..current_input)
	if char == '\r' then

		--normalize the current input
		current_input = strip(current_input)

		--tokenize and byte it
		local bytes, tokens = tokenise(current_input)

		--fill text buffer
		local addr = z_text_buffer + 0x.0001
		set_zbytes(addr, bytes)

		local max_tokens = min(#tokens, z_parse_buffer_length)
		set_zbyte(z_parse_buffer+0x.0001, max_tokens)
		z_parse_buffer += 0x.0002
		for i = 1, max_tokens do
			local word, index, z_adjust = unpack(tokens[i])
			-- log('looking up word: '..word)
			-- log('  substring: '..sub(word,1,_zm_dictionary_word_size-z_adjust))
			local dict_addr = _dictionary_lookup[sub(word,1,_zm_dictionary_word_size-z_adjust)] or 0x0
			-- log('  received: '..tohex(dict_addr))
			set_zword(z_parse_buffer, dict_addr)
			set_zbyte(z_parse_buffer+0x.0002, #word)
			set_zbyte(z_parse_buffer+0x.0003, index)
			z_parse_buffer += 0x.0004
		end
		
		current_input, visible_input = '', ''
		_read()

	else
		process_input_char(case_setter(char, lowercase), char, max_input_length)
	end
end

function dword_to_str(dword)
	local hex = tostr(dword,3)
	return sub(hex,3)
end

function save_game(char)
	-- log('save_game: '..tostr(char)..','..tostr(ord(char)))
	--can the keyboard handler be shared with capture_input()?
	if show_warning == true then
		output('Enter filename (max 30 chars; careful, do NOT press "ESC")\n\n>', true)
		flush_line_buffer()
		show_warning = false
	end

	if (not char) return

	--do the save
	if char == '\r' then
		capture_state(_current_state)
		local filename = current_input..'_'..game_id()..'_save'
		printh(_current_state, filename, true)
		current_input, visible_input = '', ''
		show_warning = true
		local s = (_zm_version == 3) and true or 1
		_save(s)

	else
		char = case_setter(char, lowercase)
		process_input_char(char, char, 30)
	end

end

function restore_game()

	output('Drag in a '..game_id()..'_save.p8l file or any key to exit.\n', true)
	extcmd("folder")

	--hang out waiting for a file drop or keypress
	local key_pressed, file_dropped, stop_waiting = false, false, false
	while stop_waiting == false do
		flip()
		if stat(30) then
			poke(0x5f30,1)
			key_pressed = true
		end
		if (stat(120)) file_dropped = true
		stop_waiting = key_pressed or file_dropped
	end

	if (key_pressed == true) current_input = '' return false

	local temp = {}
	while stat(120) do
		local chunk = serial(0x800, 0x4300, 0x1000)
		for j = 0, chunk-1, 8 do
			local a, b, c, d, e, f, g, h = peek(0x4300+j, 8)
			local hex = '0x'..chr(a)..chr(b)..chr(c)..chr(d)..'.'..chr(e)..chr(f)..chr(g)..chr(h)
			add(temp, tonum(hex))
		end
	end

	log(temp[#temp]..','..checksum)
	local save_checksum = dword_to_str(temp[#temp])
	local this_checksum = dword_to_str(checksum)

	if save_checksum != this_checksum then
		output('This save file appears to be for a different game.\n')
		output(save_checksum..' vs. '..this_checksum..'\n', true)
		return (_zm_version == 3) and false or 0
	end

	local offset = 1
	local save_version = temp[offset]
	if save_version > tonum(_engine_version) then
		output('This save file requires v'..tostr(save_version)..' of Status Line.\n', true)
		return (_zm_version == 3) and false or 0
	end

	offset += 1
	local memory_length = temp[offset]
	local mem_max_bank, mem_max_index, _ = get_memory_location( _static_memory_mem_addr - 0x.0001)
	-- log('memory_length ('..mem_max_bank..','..mem_max_index..'): '..memory_length)
	local temp_index = 1
	for i = 1, mem_max_bank do
		local max_j = _memory_bank_size
		if (i == mem_max_bank) max_j = mem_max_index
		for j = 1, max_j do
			_memory[i][j] = temp[offset+temp_index]
			temp_index += 1
		end
	end

	offset += memory_length + 1
	_call_stack = {}
	local call_stack_length = temp[offset]
	-- log('call_stack_length: '..call_stack_length)
	temp_index = 1
	for i = 1, call_stack_length do
		local frame = frame:new()
		frame.pc = temp[offset + 1]
		frame.call = temp[offset + 2]
		frame.args = temp[offset + 3]
		-- log("restoring frame "..i..": "..tohex(frame.pc)..', '..tohex(frame.call)..', '..tohex(frame.args))
		local stack_length = temp[offset + 4]
		-- log("---frame stack---")
		for j = 1, stack_length do
			local val = temp[offset + 4 + j]
			add(frame.stack, val)
			-- log("  "..j..': '..tohex(temp[offset + 4 + j])..' -> '..tohex(frame.stack[j]))
		end
		offset += 4 + stack_length
		-- log("---frame vars---")
		for k = 1, 16 do
			local val = temp[offset + k]
			frame.vars[k] =  val
			-- log("  "..k..": "..tohex(temp[offset + k])..' -> '..tohex(frame.vars[k]))
		end
		add(_call_stack, frame)
		offset += 16
	end

	_program_counter = temp[#temp-1]
	-- log('restoring pc: '..tohex(_program_counter, true))
	current_input = ''
	return (_zm_version == 3) and true or 2
end

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
	-- useful to use status bar for debug info
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
	print('\^i\#'..current_bg..'\f'..current_fg..flipped, 1, 1)
end