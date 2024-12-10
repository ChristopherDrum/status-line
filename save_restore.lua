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
		process_input_char(case_setter(char, lowercase), char, 30)
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