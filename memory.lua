_memory = {{}}
_memory_start_state = {}
_memory_bank_size = 16384 -- (1024*64)/4; four 64K banks


-- used for throw/catch
call_type = { none = 0, func = 1, proc = 2, intr = 3 }

-- frame prototype: program_counter, call_type, num_args
frame = { pc = 0, call = 0, args = 0 }

function frame:new()
 local obj = {
 	stack = {},
	vars = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
 }
 return setmetatable(obj, {__index=self})
end

function frame:stack_push(val)
	add(self.stack,val)
	-- log("pushing "..tostr(val)..", and now "..tostr(self.stack[#self.stack]))
end

function frame:stack_pop()
	if #self.stack == 0 then
		log("ERR: asked to pop beyond the this frame's stack count")
		return nil
	end
	-- log("popping "..tostr(self.stack[#self.stack]))
	return deli(self.stack)
end

function top_frame()
	return _call_stack[#_call_stack]
end

function stack_top()
	local st = top_frame().stack
	return st[#st]
end

function set_stack_top(val)
	local st = top_frame().stack
	st[#st] = val
	top_frame().stack = st
end

--reset play session data (leave loaded game alone)
function _restart()
	for i = 1, #_memory_start_state do
		_memory[1][i] = _memory_start_state[i]
	end
	flush_volatile_state()
	initialize_game()
end

function clear_all_memory()
	_memory = {{}}
	_memory_start_state = {}
	flush_volatile_state()
end

function flush_volatile_state()
	_call_stack = {}
	_program_counter = 0x0
	_interrupt = nil
	_current_state = ''
	max_input_length = 0
	separators, _main_dict = {}, {}
	story_loaded = false
end

--may just be a zbyte, but storage is the same
function stack_push(zword)
	-- log('+ + stack_push: '..tohex(zword))
	top_frame():stack_push(zword)
end

function stack_pop()
	-- log('- - stack_pop: '..tohex(top_frame().stack))
	return top_frame():stack_pop()
end

function call_stack_push()
	if (#_call_stack > 0) top_frame().pc = _program_counter
	add(_call_stack, frame:new())
end

function call_stack_pop()
	deli(_call_stack)
	_program_counter = top_frame().pc
end

function abbr_address(index)
	--abbreviation addresses are word addresses (2*addr)
	return zword_to_zaddress(get_zword(_abbr_table_mem_addr + (index >>> 15))<<1)
end 

--zobject_address(index) replaced with inline calculations
--search for _zobject_address usage

--rather than passing off to set_zword, we'll do it here directly
function set_var(value, _var_byte, indirect)
	-- log("  [mem] set_var: "..tostr(value)..','..tostr(var_byte))
	local var_byte = _var_byte or get_zbyte()

	if (var_byte == 0) then
		if (indirect) set_stack_top(value) else stack_push(value)

	elseif (var_byte < 16) then
		local zaddr = _local_var_table_mem_addr + (var_byte >>> 16)
		top_frame().vars[zaddr<<16] = value

	else
		local zaddr = _global_var_table_mem_addr + ((var_byte-16) >>> 15) 	-- index*0x.0002 == (index>>>15)
		set_zbyte(zaddr, value>>>8)
		set_zbyte(zaddr+0x.0001, value)
	end
end

function get_var(_var_byte, indirect)
	-- log("  [mem] get_var: "..tostr(var_byte))
	local var_address
	local var_byte = _var_byte or get_zbyte()
	if (var_byte == 0) then
		var_address = _stack_mem_addr
	elseif (var_byte < 16) then
		var_address = _local_var_table_mem_addr + (var_byte >>> 16)
	else
		var_address = _global_var_table_mem_addr + ((var_byte-16) >>> 15) 	-- index*0x.0002 == (index>>>15)
	end
	return get_zword(var_address, indirect)
end

function zword_to_zaddress(zaddress, _is_packed)
	local is_packed = _is_packed or false
	zaddress >>>= 16
	if (is_packed == true) zaddress <<= _zm_packed_shift
	-- log("zword_to_zaddress("..tostr(is_packed)..") returning: "..tohex(zaddress))
	return zaddress
end

function zaddress_at_zaddress(zaddress, is_packed)
	return zword_to_zaddress(get_zword(zaddress), is_packed)
end

-- returns value stored at zaddress, memory bank (if any), index into storage, cell
function get_dword(zaddress, indirect)
	local zaddress = zaddress or _program_counter
	-- log("  [mem] get_dword at address "..tohex(zaddress))
	-- local base = (zaddress & 0xffff)

	if zaddress < 0xa then
		local bank = (zaddress & 0x000f) + 1
		local za = ((zaddress<<16)>>>2) + 1 --contains index and cell
		local index = za & 0xffff
		local cell = (za & 0x.ffff) << 2
		-- local bank, index, cell = get_memory_location(zaddress)
		-- log("  [mem]  memory banks "..bank..','..index..','..cell)
		return _memory[bank][index], bank, index, cell
	end

	if zaddress >= _local_var_table_mem_addr then
		local index = zaddress << 16
		local var = top_frame().vars[index]
		-- log2("  getLocal: "..index.." -> "..tohex(var))
		return var, nil, index
	end

	if zaddress == _stack_mem_addr then
		-- log("  [mem] get dword at _stack_mem_addr: "..tohex(zaddress))
		if (indirect) return stack_top()
		return stack_pop()
	end
end

--zaddresses *must* be right-aligned before requesting
--a zbyte or zword. Some routines need to add an offset
--and the result may transition from 2- to 3-byte address
function get_zbyte(zaddress)
	if not zaddress then
		zaddress = _program_counter
		_program_counter += 0x.0001
	end

	local dword, _, _, cell  = get_dword(zaddress)
	if (zaddress < 0xa) dword >>>= -((cell<<3)-8)
	-- log('  [mem] get_zbyte from: '..tohex(zaddress).." --> "..sub(tohex(dword & 0xff),5,6))
	return dword & 0xff
end

function get_zbytes(zaddress, num_bytes)
	if (not zaddress) return

	local bytes = {}
	for i = 0, num_bytes - 1 do
		add(bytes, get_zbyte(zaddress))
		zaddress += 0x.0001
	end
	return bytes
end

function set_zbyte(zaddress, _byte)
	--log('  [mem] set_zbyte at '..tohex(zaddress)..' to value: '..tohex(byte))
	local byte = _byte & 0xff --filter off garbage
	-- local base = (zaddress & 0xffff)
	-- assert(base != _local_var_table_mem_addr, "asked to write a zbyte to local var: "..tohex(zaddress))
	if zaddress == _stack_mem_addr then
		-- log('  [mem] setting stack: '..tohex(byte))
		stack_push(byte)
	elseif zaddress < 0xa then --regular memory
		local dword, bank, index, cell  = get_dword(zaddress)
		local offset = cell<<3
		local filter = ~(0xff00.0000 >>> offset)
		dword &= filter
		-- byte <<= 8
		byte >>>= offset-8
		dword |= byte
		_memory[bank][index] = dword
	end
end

function set_zbytes(zaddress, bytes)
	for i = 1, #bytes do
		set_zbyte(zaddress, bytes[i])
		zaddress += 0x.0001
	end
end

function get_zword(zaddress, indirect)
	if not zaddress then
		zaddress = _program_counter
		_program_counter += 0x.0002
	end
	-- local base = (zaddress & 0xffff)
	local dword, _, _, cell  = get_dword(zaddress, indirect)

	if zaddress < 0xa then
		dword <<= (cell<<3)
		if cell == 3 then
			local dwordb = get_dword(zaddress + 0x.0001)
			dword |= (dwordb >>> 8)
		end
	end
	-- log('  [mem] get_zword from: '..tohex(zaddress).." --> "..sub(tohex(dword & 0xff),3,6))
	return dword & 0xffff
end

function set_zword(zaddress, _zword, indirect)
	local zword = _zword & 0xffff --filter off garbage
	-- log('  [mem] set_zword at: '..tohex(zaddress)..' to: '..sub(tohex(_zword),3,6))
	
	if zaddress == _stack_mem_addr then
		-- log('  [mem] setting stack: '..tohex(zword))
		if (indirect) set_stack_top(zword) else stack_push(zword)

	elseif zaddress < 0xa then --this should also resolve global var access because those addresses are maintained by the zcode, not us
		set_zbyte(zaddress, zword>>>8)
		set_zbyte(zaddress+0x.0001, zword)

	elseif zaddress >= _local_var_table_mem_addr then
		-- log2("  setLocal: "..(zaddress<<16).." -> "..tohex(zword))
		top_frame().vars[zaddress<<16] = zword
	end
end

function zobject_attributes_byte_bit(index, attribute_id)
	if (index == 0) return 0
	local address = _zobject_address + (((index-1)*_zm_object_entry_size)>>>16) --zobject_address(index)
	local byte_index = flr(attribute_id>>3)
	local attr_bit = attribute_id % 8
	address += (byte_index>>>16)
	-- log('  [mem] zobject_attributes_byte_bit: index = '..tohex(byte_index)..', attr_bit == '..tohex(attr_bit))
	return get_zbyte(address), attr_bit, address
end

function zobject_has_attribute(index, attribute_id)
	if (index == 0) return 0
	local attr_byte, attr_bit = zobject_attributes_byte_bit(index, attribute_id)
	local attr_check = (0x80>>attr_bit)
	-- log('  [mem] zobject_has_attribute: '..zobject_name(index)..', '..attribute_id..' '..tostr(attr_check))
	return (attr_byte & attr_check) == attr_check
end

function zobject_set_attribute(index, attribute_id, val)
	if ((index < 1) or (val > 1)) return
	-- log('  [mem] zobject_set_attribute: '..zobject_name(index)..', set attr '..attribute_id..' to: '..val)
	local attr_byte, attr_bit, address = zobject_attributes_byte_bit(index, attribute_id)
	-- log('     byte was: '..tohex(attr_byte))
	attr_byte &= ~(0x80>>attr_bit)
	attr_byte |= (val<<(7-attr_bit))
	-- log('     byte now: '..tohex(attr_byte))
	set_zbyte(address, attr_byte)
end

zparent, zsibling, zchild = 0, 1, 2
function zfamily_address(index, family_member)
	local address = _zobject_address + (((index-1)*_zm_object_entry_size)>>>16)--zobject_address(index)
	local attr_size, member_size = 0x.0006, 0x.0002
	if (_zm_version == 3) attr_size, member_size = 0x.0004, 0x.0001
	address += attr_size + (family_member * member_size)
	return address
end

function zobject_family(index, family_member)
	if (index == 0) return 0
	local address = zfamily_address(index, family_member)
	if (_zm_version == 3) return get_zbyte(address)
	return get_zword(address)
end

function zobject_set_family(index, family_member, family_index)
	if (index == 0) return 0
	local address = zfamily_address(index, family_member)
	if (_zm_version == 3) set_zbyte(address, family_index) else set_zword(address, family_index)
end

-- 12.3.1
function zobject_prop_table_address(index)
	local offset = (_zm_version == 3) and 0x.0007 or 0x.000c
	local prop_table_address = _zobject_address + (((index-1)*_zm_object_entry_size)>>>16) + offset
	local zword = get_zword(prop_table_address)
	return zword_to_zaddress(zword)
end

-- 12.4
function zobject_name(obj_index)
	local prop_addr = zobject_prop_table_address(obj_index)
	local text_length = get_zbyte(prop_addr)
	if text_length > 0 then
		return get_zstring(prop_addr + 0x.0001)
	end
	return ''
end

-- 12.4.1
function extract_prop_len_num(local_addr)
	-- address should be passed as internal 0xf.ffff style
	-- in other words, run zword_to_zaddress before passing here
	local len_num_byte = get_zbyte(local_addr)
	if (len_num_byte == 0x0) return 0, 0, 0
	-- log("  [mem] extracted len_num byte: "..tohex(len_num_byte))
	-- offset represents how many bytes define this property
	local len, num, offset = 0, 0, 1

	if (_zm_version == 3) then
		-- bits |7.6.5| == len; |4.3.2.1.0| == prop num
		len = ((len_num_byte >>> 5) & 0x7) + 1
		num = (len_num_byte & 0x1f)
		-- log("  [mem] z3 len: "..len..", num: "..num)
	else
		-- bits |7.6| == len; |5.4.3.2.1.0| == prop num
		num = (len_num_byte & 0x3f)

		if (len_num_byte & 0x80 == 0) then
			len = ((len_num_byte >>> 6) & 0x1) + 1

		else
			--otherwise, bits |5.4.3.2.1.0| == len, on the NEXT byte
			len_num_byte = get_zbyte(local_addr + 0x.0001)
			-- log("     second byte at "..tohex(local_addr + 0x.0001)..": "..tohex(len_num_byte))
			len = len_num_byte & 0x3f
			if (len == 0x0) len = 0x40 -- '0' should be interpreted as 63(+1)
			offset = 2
		end
	end

	return len, num, offset
end

--the work these two ops do is functionally equivalent
--step through props to find a specific one
target_addr, target_next = 0, 1
function zobject_search_properties(obj, prop, target)
	if (obj == 0) return 0

	local prop_addr = zobject_prop_table_address(obj)
	local text_length = get_zbyte(prop_addr)
	prop_addr += (0x.0001 + (text_length >>> 15))

	local prop_len, prop_num, offset = extract_prop_len_num(prop_addr)
	if prop == 0 then
		if (target == target_next and prop_num > 0) return prop_num
		return 0
	end

	local get_next = false
	while prop_num > 0 do
		if prop_num == prop then
			if target == target_addr then
				return (prop_addr + (offset >>> 16)), prop_len
			else
				get_next = true
			end
		end
		prop_addr += ((prop_len + offset) >>> 16)
		prop_len, prop_num, offset = extract_prop_len_num(prop_addr)
		if (get_next == true) return prop_num
	end
	return 0
end

function zobject_get_prop(index, property)

	--properties start at 1, not 0; offsets are (property - 1) * offset
	local function zobject_default_property(property)
		assert(property <= _zm_object_property_count, 'ERR: default object property '..property)
		local address = _object_table_mem_addr + ((property - 1) >>> 15)
		return get_zword(address)
	end

	if (index == 0) return 0
	local prop_data_addr, len = zobject_search_properties(index, property, target_addr)
	if (prop_data_addr == 0) return zobject_default_property(property)

	if (len == 1) return get_zbyte(prop_data_addr)
	if (len == 2) return get_zword(prop_data_addr)
	return 0
end

function zobject_set_prop(index, property, value)
	if (index == 0) return 0
	local prop_data_addr, len = zobject_search_properties(index, property, target_addr)
	
	if (len == 1) set_zbyte(prop_data_addr, value & 0xff)
	if (len == 2) set_zword(prop_data_addr, value & 0xffff)
end

function get_zstring(zaddress, _is_dict)
	local is_dict = _is_dict or false
	local end_found, zchars = false, {}

	while end_found == false do
		local zword = get_zword(zaddress)
		for shift = 10, 0, -5 do
			add(zchars, (zword >>> shift) & 0x1F)
		end
		if (zaddress) zaddress += 0x.0002
		end_found = ((zword & 0x8000) == 0x8000)
		if _is_dict == true then
			end_found = #zchars == _zm_dictionary_word_length
		end
	end
	return zscii_to_p8scii(zchars)
end

--upper/lower visually reversed in p8scii
local zchar_tables = {
	'     abcdefghijklmnopqrstuvwxyz', 
	'     ABCDEFGHIJKLMNOPQRSTUVWXYZ', 
	'      \n0123456789'..punc}

function zscii_to_p8scii(zchars, _casestyle)
	local casestyle = _casestyle or nil

	local zscii, zscii_decode, abbr_code = nil, false, nil
	local zstring, active_table = '', 1
	for i = 1, #zchars do
		local zchar = zchars[i]
		if zscii_decode == true then
			if zscii == nil then
				zscii = zchar << 5
			else
				zscii |= zchar
				local c = chr(zscii)
				if (casestyle) c = case_setter(c,casestyle)
				zstring ..= c
				zscii_decode = false
				zscii = nil
				active_table = 1
			end

		elseif abbr_code then
			local index = ((abbr_code-1)<<5)+zchar
			local abbr_address = abbr_address(index)
			abbr_code = nil
			zstring ..= get_zstring(abbr_address)
			active_table = 1

		elseif zchar == 0 then
			zstring ..= ' '
			active_table = 1

		elseif zchar < 4 then
			abbr_code = zchar

		elseif zchar == 4 then
			active_table = 2

		elseif zchar == 5 then
			active_table = 3

		elseif zchar == 6 and active_table == 3 then
			zscii_decode = true

		elseif zchar > 31 then
			local c = chr(zchar)
			if (casestyle) c = case_setter(c,casestyle)
			zstring ..= c
			active_table = 1

		else
			local lookup_string = zchar_tables[active_table]
			zstring ..= lookup_string[zchar]
			active_table = 1
		end
	end
	return zstring
end

function load_instruction()

	local op_table, op_code, operands = nil, 0, {}

	local function extract_operand_by_type(op_type)
		if (op_type == 0) return get_zword()
		if (op_type == 1) return get_zbyte()
		if (op_type == 2) return get_var()
		return nil
	end

	local function extract_operands(info, count)
		for i = count - 1, 0, -1 do
			local op_type = (info >>> (i * 2)) & 0x03
			local operand = extract_operand_by_type(op_type)
			if (operand == nil) break
			add(operands, operand)
		end
	end
	
	local pc = _program_counter
	local op_definition = get_zbyte()
	local op_form = (op_definition >>> 6) & 0xff
	if (op_definition == 0xbe) op_form = 0xbe

	if op_form <= 0x01 then
		op_table = _long_ops
		op_code = (op_definition & 0x1f)
		operands = {get_zbyte(), get_zbyte()}

		if (op_definition & 0x40 == 0x40) operands[1] = get_var(operands[1])
		if (op_definition & 0x20 == 0x20) operands[2] = get_var(operands[2])

	-- $BE indicates an extended instruction
	elseif (op_form == 0xbe) and (_zm_version >= 5) then
		op_table = _ext_ops
		op_code = get_zbyte()
		extract_operands(get_zbyte(), 4)

	elseif op_form == 0x02 then
		op_table = _short_ops
		op_code = (op_definition & 0xf)
		local op_type = (op_definition & 0x30) >>> 4
		operands = {extract_operand_by_type(op_type)}
		if op_type == 3 then
			op_table = _zero_ops
			operands = {}
		end

	elseif op_form == 0x03 then
		op_table = (op_definition & 0x20 == 0) and _long_ops or _var_ops
		op_code = (op_definition & 0x1f)

		local type_information, op_count
		if (_zm_version > 3) and (op_definition == 0xec or op_definition == 0xfa) then
			type_information, op_count = get_zword(), 8
		else
			type_information, op_count = get_zbyte(), 4
		end
		extract_operands(type_information, op_count)
		if ((op_table == _long_ops) and (#operands == 1) and (op_code > 1)) get_zbyte()
	end

	-- Logging
	local op_string = ''
	for i = 1, #operands do
		op_string ..= sub(tohex(operands[i]), 3, 6) .. ' '
	end
	log3(sub(tohex(pc), 6) .. ': ' .. op_table[#op_table][op_code + 1] .. '(' .. op_string .. ')')

	return op_table[op_code + 1], operands
end

function capture_mem_state(state)

	-- dynamic memory can never exceed 0xffff, so bank is always the first one
	local addr = _static_memory_mem_addr - 0x.0001
	local mem_max_index = (((addr<<16)>>>2) + 1)&0xffff
	-- log3("capture_mem_state until addr: "..tohex(addr)..', index: '..mem_max_index)
	if state != nil then
		-- log('  [mem] capture _memory_start_state')
		_memory_start_state = {unpack(_memory[1])}
		-- log3(" memory[1] len: "..#_memory[1]..', copy: '..#_memory_start_state)

		while #_memory_start_state > mem_max_index do
			deli(_memory_start_state)
		end
		-- log("  [mem] after memory_start_state with bank "..mem_max_bank..": "..stat(0))
	else

		local memory_dump = dword_to_str(tonum(_engine_version))

		-- log('  [mem] saving memory up to bank: '..mem_max_bank..', index: '..mem_max_index)
		memory_dump ..= dword_to_str(mem_max_index)
		for i = 1, mem_max_bank do
			local max_j = (i == mem_max_bank) and mem_max_index or #_memory[i]
			for j = 1, max_j do
				memory_dump ..= dword_to_str(_memory[i][j])
			end
		end

		-- log('  [mem] saving call stack: '..(#_call_stack))
		memory_dump ..= dword_to_str(#_call_stack)
		for i = 1, #_call_stack do
			local frame = _call_stack[i]
			memory_dump ..= dword_to_str(frame.pc)
			memory_dump ..= dword_to_str(frame.call)
			memory_dump ..= dword_to_str(frame.args)
			-- log("  [mem] saving frame"..i..": "..tohex(frame.pc)..', '..tohex(frame.call)..', '..tohex(frame.args))
			memory_dump ..= dword_to_str(#frame.stack)
			-- log("  [mem] ---frame stack---")
			for j = 1, #frame.stack do
				memory_dump ..= dword_to_str(frame.stack[j])
				-- log("  [mem]  "..j..': '..tohex(frame.stack[j])..' -> '..dword_to_str(frame.stack[j]))
			end
			-- log("  [mem] ---frame vars---")
			for k = 1, 16 do
				memory_dump ..= dword_to_str(frame.vars[k])
				-- log("  [mem]  "..k..": "..tohex(frame.vars[k])..' -> '..dword_to_str(frame.vars[k]))
			end
		end

		-- log('  [mem] saving pc: '..(tohex(_program_counter,true)))
		memory_dump ..= dword_to_str(_program_counter)
		memory_dump ..= dword_to_str(checksum)

		_current_state = memory_dump
	end
end

function load_story_file()
	clear_all_memory()
	while stat(120) do
		if (#_memory[#_memory] == _memory_bank_size) add(_memory, {})
		local bank_num = #_memory
		local chunk = serial(0x800, 0x4300, 1024)
		for j = 0, chunk-1, 4 do
			local a, b, c, d = peek(0x4300+j, 4)
			a <<= 8
			c >>>= 8
			d >>>= 16
			local dword = (a|b|c|d)
			add(_memory[bank_num], dword)
		end
	end
	initialize_game()
end