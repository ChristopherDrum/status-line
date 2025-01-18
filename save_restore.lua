-- did_restore = false
function save_game(char)
	-- log('save_game: '..tostr(char))

	-- if did_restore == true then 
	-- 	log('  re-entered from restore_game')
	-- 	did_restore = false
	-- 	_save(2)
	-- 	return
	-- end

	--can the keyboard handler be shared with capture_input()?
	if show_warning == true then
		output('Enter filename (max 30 chars; careful, do NOT press "ESC")\n\n>', true)
		show_warning = false
	end

	if (not char) return

	--do the save
	if char == '\r' then
		local filename = current_input..'_'..game_id..'_save'
		write_save_state(filename)
		current_input, visible_input = '', ''
		show_warning = true
		local s = (_zm_version == 3) and true or 1
		_save(s)

	else
		process_input_char(char, 30)
	end
end

function write_save_state(filename)

	local d = ""
	local function dump(num)
		d ..= dword_to_str(num)
	end

	dump(tonum(_engine_version))
	dump(tonum(game_id.."0000", 0x3))
	dump(tonum(_program_counter))

	--all of memory bank 1
	for i = 1, _memory_bank_size do
		dump(_memory[1][i])
	end

	-- log('  [mem] saving call stack: '..(#_call_stack))
	dump(#_call_stack)
	for i = 1, #_call_stack do
		local frame = _call_stack[i]
		dump(frame.pc)
		dump(frame.call)
		dump(frame.args)
		-- log("  [mem] saving frame"..i..": "..tohex(frame.pc)..', '..tohex(frame.call)..', '..tohex(frame.args))
		dump(#frame.stack)
		-- log("  [mem] ---frame stack---")
		for j = 1, #frame.stack do
			dump(frame.stack[j])
			-- log("  [mem]  "..j..': '..tohex(frame.stack[j])..' -> '..dword_to_str(frame.stack[j]))
		end
		-- log("---capture frame vars---")
		for k = 1, 16 do
			dump(frame.vars[k])
			-- log("  [mem]  "..k..": "..tohex(frame.vars[k])..' -> '..dword_to_str(frame.vars[k]))
		end
	end
	printh(d, filename, true) --true the first write, false afterward to append
end

function restore_game()

	output('Drag in a '..game_id..'_save.p8l file or any key to exit.\n', true)
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
			local hex = chr(a)..chr(b)..chr(c)..chr(d)..chr(e)..chr(f)..chr(g)..chr(h)
			add(temp, tonum(hex, 0x3))
		end
	end

	local index = 1
	local save_engine = temp[index]
	-- log(" restore save_engine says raw: "..save_engine..", _engine_version: "..tonum(_engine_version))
	if save_engine != tonum(_engine_version) then
		output('This save file requires v'..tostr(save_engine)..' of Status Line.\n', true)
		return (_zm_version == 3) and false or 0
	end

	index += 1
	local save_id = tohex(temp[index],false)
	-- log(" restore game_id says raw: "..tostr(temp[index],0x3)..", save_id: "..save_id..", game_id: "..game_id)
	if save_id != game_id then
		output('This save file appears to be for a different game.\n')
		return (_zm_version == 3) and false or 0
	end

	index += 1
	_program_counter = temp[index]

	index += 1
	for i = 1, _memory_bank_size do
		_memory[1][i] = temp[index]
		-- log(" restore "..i..": "..dword_to_str(temp[index]))
		index += 1
	end

	_call_stack = {}
	local call_stack_length = temp[index]

	index += 1
	for i = 1, call_stack_length do
		local frame = frame:new()
		frame.pc = temp[index]
		frame.call = temp[index + 1]
		frame.args = temp[index + 2]
		-- log("restoring frame "..i..": "..tohex(frame.pc)..', '..tohex(frame.call)..', '..tohex(frame.args))
		local stack_length = temp[index + 3]
		
		-- log3("---frame stack---")
		for j = 1, stack_length do
			add(frame.stack, temp[index + 3 + j])
		end
		index += 3 + stack_length --now points to last item on frame stack

		-- log("---restoring frame vars---")
		for k = 1, 16 do
			frame.vars[k] = temp[index + k]
			-- log("  "..k..":"..frame.vars[k])
		end
		add(_call_stack, frame)
		index += 17 --bring us to the start of next frame
	end

	current_input = ''
	-- did_restore = true
	return (_zm_version == 3) and true or 2
end