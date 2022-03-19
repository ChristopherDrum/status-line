line_buffer = nil --processed lines, waiting to be shown
screen_buffer = {} --what the player is currently reading
cursor_x, cursor_y = 0, 0 --pixel location at which to draw input cursor
input_cursor = 0 --which actual character is being edited?

function get_cursor_position(str)
	cursor_x, cursor_y = peek(0x5f26), peek(0x5f27)
	cursor_x += (#str * 4)
	if (cursor_y == 122) cursor_y -= 6
end

--remove extraneous white space from player input
function strip(str)
	local words = split(str, ' ')
	local stripped = ''
	for i = 1, #words do
		local w = words[i]
		if (w != '') stripped ..= w..' '
	end
	if sub(stripped, -1) == ' ' then
		stripped = sub(stripped, 1, #stripped-1)
	end
	return stripped
end

local break_chars = {'\n', ' ', ':', '-', '_', ';'}
local break_index = 99
function output(str)
	-- log('received str: |'..str..'|')
	if (line_buffer == nil) line_buffer = {''}
	local l = line_buffer[#line_buffer]

	for i = 1 , #str do
		local char = sub(str,i,_)
		-- log('considering char: '..char)
		if (char != '\n') l ..= char
		-- log('  appended to l: '..l)
		if (in_set(char, break_chars)) break_index = #l
		-- if (break_index != 99) log('  >> break found at: '..break_index)
		if #l > line_width or char == '\n' then
			local l2 = ''
			if break_index < #l then
				l2 = sub(l,break_index-#l)
				-- log('      >> l2 broke at '..break_index-#l..' as: '..l2)
				local check = ord(l,break_index)
				if (check == 32) break_index -= 1
			end
			l = sub(l,1,break_index)
			-- log('        l:'..l)
			-- log('       l2:'..l2)
			line_buffer[#line_buffer] = l
			l = l2
			add(line_buffer, l)
			break_index = 99
		else
			line_buffer[#line_buffer] = l
		end
	end
end


max_lines = lines_height - 1
frame_count = 0
function flush_line_buffer()
	if (line_buffer == nil) return

	local paginate = #line_buffer > lines_height
	for i = 1, #line_buffer do
		local str = line_buffer[i]

		-- we control text scroll onto screen with this pause loop
		while frame_count < emit_rate do
			flip()
			frame_count += 1
		end
		
		if (paginate == true) and (i % max_lines == 0) then
			wait_for_any_key("- - MORE - -")
		end
		screen(str)
		frame_count = 0
	end
	line_buffer = nil
	refresh_screen()
end

function refresh_screen()
	while #screen_buffer > max_lines do
		deli(screen_buffer,1)
	end
	clip(0,8,128,120)
	rectfill(0,8,128,120,0)
	cursor(0,8)
	for i = 1, #screen_buffer do
		local str = screen_buffer[i]
		--blank lines for "new line" keep cursor spacing consistent
		if (str == '\n') str = '' 
		if (i == #screen_buffer) then 
			get_cursor_position(str)
		else
			cursor_x, cursor_y = 0, 0
		end
		-- log('  |'..str..'|')
		print(str, 1)
	end
	clip()
	cursor()
end

--stream 1 to screen
--stream 2 unimplemented
function screen(str)
	clip(0,8,128,120)
	cursor(0,122)
	add(screen_buffer, str)
	print(str, 1)
	flip()
	clip()
	cursor()
end


function tokenise(str)

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

text_buffer, parse_buffer = 0x0, 0x0
local current_input = ''

function capture_input(c)
	if (not c) return
	poke(0x5f30,1)

	--normalize char to p8scii lowercase
	local o = ord(c)
	if (mid(128,o,153) == o) o -= 31
	if (mid(65,o,90) == o) o += 32
	local char = chr(o)

	--called by read so buffer addresses must be non-zero
	assert(text_buffer != 0, 'text buffer address has not been captured')
	assert(parse_buffer != 0, 'parse buffer address has not been captured')

	if (max_input_length == 0) max_input_length = get_zbyte(text_buffer) - 1
	if (parse_buffer_length == 0) parse_buffer_length = get_zbyte(parse_buffer)

	if (char == '\r' and current_input == '') then
		read()

	elseif (char == '\r') then

		add(line_buffer, '')

		--normalize the current input
		current_input = strip(current_input)

		if in_set(current_input, {'script', 'unscript'}) then
			current_input = ''
			screen('[NOT SUPPORTED]')
			screen('>')
			refresh_screen()

		else
			--tokenize and byte it
			local bytes, tokens = tokenise(current_input)

			--fill text buffer
			local addr = text_buffer + 0x.0001
			set_zbytes(addr, bytes)

			local max_tokens = min(#tokens, parse_buffer_length)
			set_zbyte(parse_buffer+0x.0001, max_tokens)
			parse_buffer += 0x.0002
			for i = 1, max_tokens do
				local word, index = unpack(tokens[i])
				-- log('looking up word: '..word)
				local dict_addr = _dictionary_lookup[sub(word,1,6)] or 0x0
				-- log('received addr: '..tohex(dict_addr))
				set_zword(parse_buffer, dict_addr)
				set_zbyte(parse_buffer+0x.0002, #word)
				set_zbyte(parse_buffer+0x.0003, index)
				parse_buffer += 0x.0004
			end
			
			current_input = ''
			read()
		end

	else
		local l = screen_buffer[#screen_buffer]

		if char == '\b' then
			if #current_input > 0 then
				current_input = sub(current_input, 1, #current_input - 1)
				l = sub(l, 1, #l-1)
			end
		elseif char != '' then
			if #current_input < max_input_length then
				current_input ..= char

				o = ord(c)
				if (mid(65,o,90) == o) o += 32
				if (mid(97,o,122) == o) o -= 32
				if (mid(128,o,153) == o) o -= 31
				l ..= chr(o)
			end
		end

		if #l == 0 then
			deli(screen_buffer, #screen_buffer)
		elseif #l > 32 then
			add(screen_buffer, sub(l,33))
		else
			screen_buffer[#screen_buffer] = l
		end
		
		if (char != '') refresh_screen()
	end

end

local mem_max_index = nil
function capture_save_state()
	if mem_max_index == nil then
		local zaddress = zword_to_zaddress(get_zword(_static_mem_addr))
		zaddress -= 0x.0001 --one byte less marks the end of dynamic mem
		local base = (zaddress & 0xffff)
		local za = (zaddress << 14) + 1
		mem_max_index = za & 0xffff
	end

	memory_copy, call_stack_copy, stack_copy = {}, {}, {}

	for i = 1, mem_max_index do
		add(memory_copy, _memory[i])
	end
	for i = 1, #_call_stack do
		add(call_stack_copy, _call_stack[i])
	end
	for i = 1, #_stack do
		add(stack_copy, _stack[i])
	end
	pc_copy = _program_counter
end

function dword_to_str(dword)
	local hex = tostr(dword,true)
	return sub(hex,3,6)..sub(hex,8)
end

local show_warning = true
function save_game(char)
	--keyboard handler should probably be shared
	--with capture_input(); both modify current_input similarly
	if show_warning == true then
		screen('eNTER FILENAME (30 CHARACTERS)')
		screen('(careful: dO not PRESS "ESC")')
		screen('>')
		refresh_screen()
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
			screen_buffer[#screen_buffer] = '>'..current_input
			refresh_screen()
		end
		
	--do the save
	elseif char == '\r' then
		local filename = current_input..'_'..game_id()..'_save'
		local memory_dump = dword_to_str(_engine_version)

		-- log('saving memory length: '..(index))
		memory_dump ..= dword_to_str(#memory_copy)
		for i = 1, #memory_copy do
			memory_dump ..= dword_to_str(memory_copy[i])
		end

		-- log('saving call stack: '..(#_call_stack))
		memory_dump ..= dword_to_str(#call_stack_copy)
		for i = 1, #call_stack_copy do
			memory_dump ..= dword_to_str(call_stack_copy[i])
		end

		-- log('saving stack: '..(#_stack))
		memory_dump ..= dword_to_str(#stack_copy)
		for i = 1, #stack_copy do
			memory_dump ..= dword_to_str(stack_copy[i])
		end

		-- log('saving pc: '..(tohex(_program_counter,true)))
		memory_dump ..= dword_to_str(pc_copy)
		-- log('saving checksum: '..(tohex(checksum,true)))
		local checksum = get_zword(file_checksum)
		memory_dump ..= dword_to_str(checksum)

		--write the actual file
		printh(memory_dump, filename, true)

		current_input = ''
		show_warning = true
		_save(true)
	end
end

function restore_game()

	screen('dRAG IN A '..game_id()..'_SAVE.P8L FILE')
	screen('OR ANY KEY TO EXIT')
	refresh_screen()
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
		if (key_pressed or file_dropped) stop_waiting = true
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
		screen('tHIS SAVE FILE APPEARS TO BE')
		screen('FOR A DIFFERENT GAME.')
		screen(save_checksum..' vs. '..this_checksum)
		refresh_screen()
		return false
	end

	local offset = 1
	local save_version = temp[offset]
	if (save_version > _engine_version) then
		screen('tHIS SAVE FILE REQUIRES')
		screen('v'..tostr(save_version)..' OF sTATUS lINE')
		screen('OR HIGHER.')
		refresh_screen()
		return false
	end

	offset += 1
	local memory_length = temp[offset]
	for i = 1, memory_length do
		_memory[i] = temp[offset + i]
	end
	-- log('last memory slot: '..tohex(_memory[memory_length]))

	offset += memory_length + 1
	_call_stack = {}
	local call_stack_length = temp[offset]
	-- log('call_stack_length: '..call_stack_length)
	for i = 1, call_stack_length do
		_call_stack[i] = temp[offset + i]
	end

	offset += call_stack_length + 1
	_stack = {}
	local stack_length = temp[offset]
	-- log('stack_length: '..stack_length)
	for i = 1, stack_length do
		_stack[i] = temp[offset + i]
	end
	-- log('last stack: '..tohex(_stack[stack_length]))

	-- log('setting pc to: '..tohex(temp[#temp-1]))
	_program_counter = temp[#temp-1]
	current_input = ''
	return true
end

function update_status_bar()

	local obj = get_zword(global_var_address(0))
	local location = zobject_name(obj)
	local scorea = get_zword(global_var_address(1))
	local scoreb = get_zword(global_var_address(2))
	local flag = get_zbyte(interpreter_flags)
	local separator = '/'
	if (flag & 2) == 2 then
		local ampm = ''
		if clock_type == 12 then
			ampm = 'A'
			if (scorea >= 12) then 
				ampm = 'P'
				scorea -= 12
			end
			if (scorea == 0) scorea = 12
		end
		separator = ':'
		scoreb = sub('0'..scoreb, -2)..ampm
	end

	local score = scorea..separator..scoreb
	clip(0,0,128,7)
	rectfill(0,0,127,127,1)
	-- useful to use status bar for debug info
	score = tostr(stat(0))
	local loc = sub(location, 1, 30-#score-2)
	if (#loc < #location) loc = sub(loc, 1, #loc-1)..chr(144)
	print(loc, 4, 1, 0)
	print(score, 124-(#score*4), 1, 0)

	flip()
	clip()
end