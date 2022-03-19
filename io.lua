current_bg = 0
current_fg = 1
current_font = 1
-- current_style = 0
-- current_style_hw = 0x11
current_format = ''
current_format_updated = false
window_attributes = 0b00000000.00001010

origin_y = nil
screen_height = nil

--io control
emit_rate = 1 --the lower the faster
clock_type = nil
cursor_type = nil
make_bold = false

screen_output = true
memory_output = {}

--0-indexed windows to match z-machine index usage
active_window = nil
windows = {
	[0] = {
		y = 1, -- x is ALWAYS 1
		h = 21, -- w is ALWAYS 32
		z_cursor = {x=1,y=21}, --formerly cur_x, cur_y
		p_cursor = {0,0}, -- unnamed vars for unpack()ing
		screen_rect = {},
		buffer = nil,
		screen_buffer = {}
	},
	{
		y = 1,
		h = 0,
		z_cursor = {x=1,y=1},
		p_cursor = {0,0},
		screen_rect = {},
		buffer = nil
	}
}

function update_current_format(n)
	local inverse, emphasis = '\^-i\^-b', '\015'
	make_bold = false

	if ((n & 1) == 1) inverse = '\^i'
	if (n > 1) emphasis = '\014'
	if (active_window == 1 and (n&2 == 2)) inverse, emphasis = '\^i', '\015'
	if (active_window == 0) make_bold = (n&2 == 2)

	current_format = inverse..emphasis..'\f'..current_fg..'\#'..current_bg
	current_format_updated = true
end

function update_screen_rect(zwin_num)
	local win = windows[zwin_num]
	local py = (win.y-1)*6
	local ph = (win.h)*6
	-- log('setting screen rect '..zwin_num..': 0, '..(origin_y + py)..', 128,'..(origin_y+ph))
	win.screen_rect = {0, origin_y + py, 128, origin_y+ph}
end

function update_p_cursor()
	-- log('update_p_cursor ('..active_window..'):')
	local win = windows[active_window]
	local px, py, w, h = unpack(win.screen_rect)
	local cx, cy = win.z_cursor.x, win.z_cursor.y
	px += (cx - 1)<<2
	py += (cy - 1)*6
	if (_z_machine_version > 3 and active_window == 0) py += 1
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
	if (sub(stripped, -1) == ' ') stripped = sub(stripped, 1, #stripped-1)
	return stripped
end

local break_chars = {'\n', ' ', ':', '-', '_', ';'}
local break_index = 0

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

function output(str)
	if (#memory_output > 0) then
		-- log('output redirected to memory...')
		memory(str) 
	else
		if (screen_output == false) return
		log('('..active_window..') output str: '..str)
		local current_line = windows[active_window].buffer
		if (not current_line) then
			current_line = current_format
			current_format_updated = false
		end
		local visual_len = print(current_line, 0, -20)

		for i = 1 , #str do
			local char = sub(str,i,_)
			-- log('considering char: '..char)
			if current_format_updated == true then
				current_line ..= current_format
				current_format_updated = false
			end

			local o = ord(char)
			visual_len += 4
			if (make_bold == true) then
				if (o >= 32) o+=96
				if (o != 10) visual_len += 1
			end 
			current_line ..= chr(o)

			if (in_set(char, break_chars)) break_index = #current_line
			-- log('current line: '..current_line)
			if visual_len > 128 or char == '\n' then

				local next_line, next = current_format, nil
				current_line, next = unpack(split(current_line, break_index, false))
				if (next) next_line ..= next 
				-- log('on split current: '..current_line)
				-- log('on split next: '..next_line)

				windows[active_window].buffer = current_line
				flush_line_buffer()

				visual_len = print(next_line, 0, -20)
				current_line = next_line
				current_format_updated = false

				break_index = 0
			end
		end
		windows[active_window].buffer = current_line
	end
end

flip_count = 0
function flush_line_buffer()
	local win = windows[active_window]
	-- log('flush window '..active_window..' with line height: '..win.h)
	-- log('  lines shown so far: '..lines_shown)
	-- log('  about to show: '..tostr(win.buffer))
	if (win.buffer == nil or win.buffer == current_format or win.h == 0) return

	while flip_count < emit_rate do
		flip()
		flip_count += 1
	end

	if active_window == 0 then
		-- log('  active window == 0')
		if sub(win.buffer, -1) != '>' then
			-- log('  '..sub(win.buffer, -1)..' != <')
			if lines_shown == (win.h - 1) then
				-- log('  '..lines_shown..' == '..(win.h - 1))
				wait_for_any_key("\^i          - - MORE - -          ")
			end
		end
	end

	screen(win.buffer)
	win.buffer = nil
	flip_count = 0
end

function screen(str)
	-- log('received str: '..str)
	local win = windows[active_window]
	local nl = sub(str,-1) == '\n'
	if (nl == true) str = sub(str,1,#str-1)
	-- log('output to screen '..active_window..': '..str)
	if active_window == 0 then
		lines_shown += 1
		add(win.screen_buffer, str)
		if #win.screen_buffer > (screen_height + 4) then
			deli(win.screen_buffer, 1)
		end
		refresh_screen()
	else
		-- log(':: asked to print to window 1 ('..win.z_cursor.x..','..win.z_cursor.y..'): '..str)
		if win.z_cursor.y <= win.h then
			cursor(unpack(win.p_cursor))
			local x = print(str)
			local cx = win.z_cursor.x + ((x>>2)+1)
			local cy = win.z_cursor.y
			if (cx > 32 or nl == true) then
				cx = 1
				cy += 1
			end
			win.z_cursor = {x=cx, y=cy}
			update_p_cursor()
		end
	end
	-- print(tostr(stat(0)), 90,0,10)
	flip()
end

function refresh_screen()
	--only available on windows[0]
	-- log('refresh_screen')
	local win = windows[0]
	local sbuffer = win.screen_buffer
	if (#sbuffer == 0) return

	clip(unpack(win.screen_rect))
	rectfill(0,0,128,128,current_bg)
	local loop_count, x = min(#sbuffer, screen_height), 0
	for i = loop_count, 1, -1 do
		cursor(0, (screen_height - (i-1)) * 6 + 2)
		x = print(sbuffer[#sbuffer - (i-1)])
	end
	win.z_cursor.x = (x>>2)+1
	update_p_cursor()
	clip()
end

function tokenise(str)
	-- log('tokenise: '..str)
	local tokens, bytes = {}, {}
	local index = 0

	local function commit(i)
		if (index == 0) return
		add(tokens, {sub(str,index,i-1),index})
		index = 0
	end

	for i = 1, #str do
		local char = sub(str,i,_)
		add(bytes, ord(char))

		if char == ' ' then
			commit(i)

		elseif in_set(char, separators) then
			commit(i)
			add(tokens, {char,i})

		else
			if (index == 0) index = i
		end
	end
	commit(#str+1)
	add(bytes, 0x0)
	return bytes, tokens
end

function p8scii_trans(c)
	local o = ord(c)
	if (in_range(o,128,153)) o -= 31
	if (in_range(o,65,90)) o += 32
	return chr(o)
end

z_text_buffer, z_parse_buffer = 0x0, 0x0
local current_input = ''

function capture_input(c)
	lines_shown = 0
	if (not c) return
	poke(0x5f30,1)

	--normalize char to p8scii lowercase
	local char = p8scii_trans(c)

	--called by read so buffer addresses must be non-zero
	-- assert(z_text_buffer != 0, 'text buffer address has not been captured')
	-- assert(z_parse_buffer != 0, 'parse buffer address has not been captured')

	if (max_input_length == 0) max_input_length = get_zbyte(z_text_buffer) - 1
	if (z_parse_buffer_length == 0) z_parse_buffer_length = get_zbyte(z_parse_buffer)

	-- log('current input: '..current_input)
	if (char == '\r' and current_input == '') then
		read()

	elseif (char == '\r') then

		--normalize the current input
		-- log('current input before: '..current_input)
		current_input = strip(current_input)
		-- log('current input after: '..current_input)

		--tokenize and byte it
		local bytes, tokens = tokenise(current_input)

		--fill text buffer
		local addr = z_text_buffer + 0x.0001
		set_zbytes(addr, bytes)

		local max_tokens = min(#tokens, z_parse_buffer_length)
		set_zbyte(z_parse_buffer+0x.0001, max_tokens)
		z_parse_buffer += 0x.0002
		for i = 1, max_tokens do
			local word, index = unpack(tokens[i])
			-- log('looking up word: '..word)
			local dict_addr = _dictionary_lookup[sub(word,1,dictionary_word_size)] or 0x0
			set_zword(z_parse_buffer, dict_addr)
			set_zbyte(z_parse_buffer+0x.0002, #word)
			set_zbyte(z_parse_buffer+0x.0003, index)
			z_parse_buffer += 0x.0004
		end
		
		current_input = ''
		read()

	else
		local sbuffer = windows[active_window].screen_buffer
		local l = sbuffer[#sbuffer]

		if char == '\b' then
			if #current_input > 0 then
				current_input = sub(current_input, 1, #current_input - 1)
				l = sub(l, 1, #l-1)
			end
		elseif char != '' then
			if #current_input < max_input_length then
				current_input ..= char

				o = ord(c)
				if in_range(o,65,90) then
					o += 32
				elseif in_range(o,97,122) then
					o -= 32
				elseif in_range(o,128,153) then
					o -= 31
				end
				l ..= chr(o)
			end
		end

		if #l == 0 then
			deli(sbuffer, #sbuffer)
		elseif print(l, 0, -20) > 128 then
			add(sbuffer, sub(l,-1))
		else
			sbuffer[#sbuffer] = l
		end
		if (char != '') refresh_screen()
	end
end


function dword_to_str(dword)
	local hex = tostr(dword,true)
	return sub(hex,3,6)..sub(hex,8)
end

local show_warning = true
function save_game(char)
	--can the keyboard handler be shared with capture_input()?
	if show_warning == true then
		output('eNTER FILENAME (30 CHARACTERS) (careful: dO not PRESS "ESC")\n\n>\n')
		show_warning = false
	end

	--process chars for the save game filename
	if char and char != '\r' then

		if char == '\b' then
			if #current_input > 0 then
				current_input = sub(current_input, 1, #current_input - 1)
			end
		elseif not in_set(char, {'', '\r'}) then
			if (#current_input < 30) current_input ..= char
		end

		if char != '' then 
			local sbuffer = windows[active_window].screen_buffer
			sbuffer[#sbuffer] = '>'..current_input
			windows[active_window].screen_buffer = sbuffer
			refresh_screen()
		end

	--do the save
	elseif char == '\r' then
		local filename = current_input..'_'..game_id()..'_save'
		printh(_current_state, filename, true)
		current_input = ''
		show_warning = true
		_save(true)
	end
end

function restore_game()

	output('dRAG IN A '..game_id()..'_SAVE.P8L FILE OR ANY KEY TO EXIT\n')
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

	local save_checksum = dword_to_str(temp[#temp])
	local this_checksum = dword_to_str(get_zword(file_checksum))

	if (save_checksum != this_checksum) then
		output('tHIS SAVE FILE APPEARS TO BE FOR A DIFFERENT GAME.\n')
		output(save_checksum..' vs. '..this_checksum..'\n')
		return false
	end

	local offset = 1
	local save_version = temp[offset]
	if (save_version > tonum(_engine_version)) then
		output('tHIS SAVE FILE REQUIRES v'..tostr(save_version)..' OF sTATUS lINE OR HIGHER.\n')
		return false
	end

	offset += 1
	local memory_length = temp[offset]
	local mem_max_bank = (memory_length\bank_size)+1
	local mem_max_index = memory_length - ((mem_max_bank-1)*bank_size)
	-- log('memory_length ('..mem_max_bank..','..mem_max_index..'): '..memory_length)
	local temp_index = 1
	for i = 1, mem_max_bank do
		local max_j = bank_size
		if (i == mem_max_bank) max_j = mem_max_index
		for j = 1, max_j do
			_memory[i][j] = temp[offset+temp_index]
			temp_index += 1
		end
	end

	-- log('memory dump ('..temp_index..')...')
	-- for i = 1, memory_length do
	-- 	log(tohex(_memory[1][i]))
	-- end
	-- log('last memory slot (bank '..mem_max_bank..', idx '..mem_max_index..'): '..tohex(_memory[mem_max_bank][mem_max_index]))

	offset += memory_length + 1
	_call_stack = {}
	local call_stack_length = temp[offset]
	-- log('call_stack_length: '..call_stack_length)
	for i = 1, call_stack_length do
		_call_stack[i] = temp[offset + i]
	end
	-- log('loaded call stack: ')
	-- for i = 1, #_call_stack do
	-- 	log('  '.._call_stack[i])
	-- end
	-- log('last call stack: '..tohex(_call_stack[call_stack_length]))

	offset += call_stack_length + 1
	_stack = {}
	local stack_length = temp[offset]
	-- log('stack_length: '..stack_length)
	for i = 1, stack_length do
		_stack[i] = temp[offset + i]
	end

	-- log('loaded stack: ')
	-- for i = 1, #_stack do
	-- 	log('  '.._stack[i])
	-- end
	-- log('last stack: '..tohex(_stack[stack_length]))

	-- log('setting pc to: '..tohex(temp[#temp-1]))
	_program_counter = temp[#temp-1]
	current_input = ''
	process_header()
	return true
end

function show_status()

	-- local obj = get_zword(global_var_addr(0))
	-- local location = zobject_name(obj)
	-- local scorea = get_zword(global_var_addr(1))
	-- local scoreb = get_zword(global_var_addr(2))
	-- local flag = get_zbyte(interpreter_flags)
	-- local separator = '/'
	-- if (flag & 2) == 2 then
	-- 	local ampm = ''
	-- 	if clock_type == 12 then
	-- 		ampm = 'A'
	-- 		if (scorea >= 12) then 
	-- 			ampm = 'P'
	-- 			scorea -= 12
	-- 		end
	-- 		if (scorea == 0) scorea = 12
	-- 	end
	-- 	separator = ':'
	-- 	scoreb = sub('0'..scoreb, -2)..ampm
	-- end

	-- local score = scorea..separator..scoreb..' '
	-- -- useful to use status bar for debug info
	-- -- score = tostr(stat(0))
	-- local loc = ' '..sub(location, 1, 30-#score-2)
	-- if (#loc < #location) loc = sub(loc, 1, #loc-1)..chr(144)
	-- local spacer_len = 32 - #loc - #score
	-- local spacer = sub(blank_line,-spacer_len)
	-- print('\^i\#'..current_bg..'\f'..current_fg..loc..spacer..score, 0, 1)
end