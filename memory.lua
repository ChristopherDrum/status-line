_memory = {{}}
_memory_start_state = nil
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
		local bank = _memory_start_state[i]
		for j = 1, #bank do
			_memory[i][j] = _memory_start_state[i][j]
		end
	end
	flush_volatile_state()
	initialize_game()
end

function clear_all_memory()
	_memory = {{}}
	_memory_start_state = nil
	flush_volatile_state()
end

function flush_volatile_state()
	_call_stack = {}
	_program_counter = 0x0
	_interrupt = nil
	_current_state = ''
	active_table = 1
	max_input_length = 0
	separators = {}
	_main_dict = {}
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

function local_var_at_zindex(zaddress)
	local index = zaddress << 16
	local var = top_frame().vars[index]
	return var, index
end

function abbr_address(index)
	--abbreviation addresses are word addresses (2*addr)
	return zword_to_zaddress(get_zword(_abbr_table_mem_addr + (index >>> 15))<<1)
end 

function zobject_address(index)
	-- skip first 31/63 zwords of "default property table"
	local address = _object_table_mem_addr + (_zm_object_property_count>>>15)
	-- log('zobject_address old: '..tohex(old_address)..' new: '..tohex(address))
	address += (index-1)*_zm_object_entry_size
	return address
end

function local_var_addr(index)
	--log(' getting address for local var: '..tohex(index))
	-- assert(index > 0 and index < 16, 'ERR: asked to retrieve local var '..tostr(index))
	return _local_var_table_mem_addr + (index >>> 16)
end

function global_var_addr(index)
	--log(' address for G'..sub(tostr(index,true),5,6)..' is: '..tohex(addr))
	return _global_var_table_mem_addr + (index >>> 15) 	-- index*0x.0002 == (index>>>15)
end

function set_var(value, var_byte, indirect)
	local var_address = decode_var_address(var_byte)
	set_zword(var_address, value, indirect)
end

function get_var(var_byte, indirect)
	local var_address = decode_var_address(var_byte)
	return get_zword(var_address, indirect)
end

function decode_var_address(var_byte)
	local var_byte = var_byte or get_zbyte()
	-- log('decode_var_address: '..var_byte)
	if (var_byte == 0) return _stack_mem_addr
	if (var_byte < 16) return local_var_addr(var_byte)
	if (var_byte >= 16) return global_var_addr(var_byte-16) -- -16 ONLY when decoding var byte
end

function zword_to_zaddress(zaddress, is_packed)
	local shift = 16
	if (is_packed) shift -= _zm_packed_shift
	return (zaddress >>> shift)
end

function zaddress_at_zaddress(zaddress, is_packed)
	return zword_to_zaddress(get_zword(zaddress), is_packed)
end

-- "zaddress" is shifted as far right as possible to allow 3-byte addressing
-- bank: which subtable in _memory
-- index: index into the bank
-- cell: 0-indexed byte at _memory[bank][index]
function get_memory_location(zaddress)
	-- log('get_memory_location for address: '..tohex(zaddress,true))
	local bank = (zaddress & 0x000f) + 1
	local za = ((zaddress<<16)>>>2) + 1 --contains index and cell
	local index = za & 0xffff
	local cell = (za & 0x.ffff) << 2
	-- log("...we have "..#_memory.." banks, last bank holds"..#_memory[#_memory])
	-- log("...we were asked for Bank #"..bank..", Index #"..index..", Cell #"..cell)
	return bank, index, cell
end

-- returns value stored at zaddress, memory bank (if any), index into storage, cell
function get_dword(zaddress, indirect)
	local zaddress = zaddress or _program_counter
	-- log("get_dword at address "..tohex(zaddress))
	local base = (zaddress & 0xffff)

	if base < 0xa then
		local bank, index, cell = get_memory_location(zaddress)
		return _memory[bank][index], bank, index, cell
	end

	if base == _local_var_table_mem_addr then
		-- log("get dword at local var addr: "..tohex(zaddress))
		local var, index = local_var_at_zindex(zaddress)
		return var, nil, index
	end

	if zaddress == _stack_mem_addr then
		if (indirect) return stack_top()
		return stack_pop()
	end
end

--zaddresses *must* be right-aligned before requesting
--a zbyte or zword. Some routines need to add an offset
--and the result may transition from 2- to 3-byte address
function get_zbyte(zaddress)
	if not zaddress then
	-- log('_________________get_zbyte from PC: '..tohex(_program_counter))
		zaddress = _program_counter
		_program_counter += 0x.0001
	-- log('                       now: '..tohex(_program_counter))
	end
	local base = (zaddress & 0xffff)
	local dword, _, _, cell  = get_dword(zaddress)

	if base < 0xa then
		if cell < 2 then
			dword >>>= (8 - (8*cell))
		else
			dword <<= (2 << cell)
		end
	elseif base == _local_var_table_mem_addr then
		-- log("get_zbyte at local var table: "..tohex(zaddress))
		if (zaddress & 0x.000f > 0) dword <<= 16
	end

	return dword & 0xff
end

function get_zbytes(zaddress, num_bytes)
	if (not zaddress) return
	if (not num_bytes) return get_zbyte(zaddress)

	local bytes = {}
	for i = 0, num_bytes - 1 do
		add(bytes, get_zbyte(zaddress + (i>>>16)))
	end
	return bytes
end

function set_zbyte(zaddress, _byte)
	--log('set_zbyte at '..tohex(zaddress)..' to value: '..tohex(byte))
	local byte = _byte & 0xff --filter off garbage
	local base = (zaddress & 0xffff)

	if zaddress == _stack_mem_addr then
		-- log(' setting stack: '..tohex(byte))
		stack_push(byte)
	else
		local dword, bank, index, cell  = get_dword(zaddress)
		if base < 0xa then --regular memory
			local filter = ~(0xff00.0000 >>> (cell << 3))
			dword &= filter
			byte <<= 8
			byte >>>= (cell << 3)
			dword |= byte
			_memory[bank][index] = dword
		else --local var
			if (zaddress & 0x.0001) == 0 then
				dword = (dword & 0x.ffff) | byte
			else
				dword = (dword & 0xffff) | (byte >>> 16)
			end
			top_frame().vars[index] = dword
		end
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
	local base = (zaddress & 0xffff)
	local dword, bank, index, cell  = get_dword(zaddress, indirect)
	-- log('  get_zword at address: '..tohex(zaddress,true)..', fetched: '..tohex(dword))

	if base < 0xa then
		dword <<= (8 * cell)
		if cell == 3 then
			index += 1
			if (index > #_memory[bank]) bank += 1 index = 1
			local dwordb = _memory[bank][index]
			-- log('  consecutive dword '..tohex(dwordb))
			dword |= (dwordb >>> 8)
		end
	elseif base == _local_var_table_mem_addr then
		if (zaddress & 0x.0001 == 0x.0001) dword <<= 16
	end
	return dword & 0xffff
end

function set_zword(zaddress, _zword, indirect)
	-- log(' setting zword at '..tohex(zaddress)..' to value: '..tohex(zword))
	local zword = _zword & 0xffff --filter off garbage
	-- local base = (zaddress & 0xffff)
	
	if zaddress == _stack_mem_addr then
		-- log(' setting stack: '..tohex(zword))
		if indirect then
			set_stack_top(zword)
		else
			stack_push(zword)
		end
	else
		local dword, bank, index, cell  = get_dword(zaddress, indirect)
		if zaddress < 0xa then
			local filter = ~(0xffff.0000 >>> (cell << 3))
			dword &= filter
			if cell == 3 then
				local next_index = index + 1
				local next_bank = bank
				if (next_index > #_memory[bank]) next_bank += 1 next_index = 1
				local dwordb = _memory[next_bank][next_index]
				dwordb &= 0x00ff.ffff
				dwordb |= (zword << 8)
				_memory[next_bank][next_index] = dwordb
			end
			zword >>>= (cell << 3)
			dword |= zword
			_memory[bank][index] = dword
		else
			if (zaddress & 0x.0001 == 0) then
				dword = (dword & 0x.ffff) | zword
			else
				dword = (dword & 0xffff) | (zword >>> 16)
			end
			top_frame().vars[index] = dword
		end
	end
end

function zobject_attributes_byte_bit(index, attribute_id)
	-- old_zobject_attributes(index)
	local address = zobject_address(index)
	-- local byte_count = (_zm_version == 3) and 4 or 6
	local byte_index = flr(attribute_id>>3)
	local attr_bit = attribute_id % 8
	address += (byte_index>>>16)
	-- log('  NEW zobject_attributes_byte_bit: '..get_zbyte(address)..', '..attr_bit..','..tohex(address))
	return get_zbyte(address), attr_bit, address
end

function zobject_has_attribute(index, attribute_id)
	local attr_byte, attr_bit = zobject_attributes_byte_bit(index, attribute_id)
	local attr_check = (0x80>>attr_bit)
	return (attr_byte & attr_check) == attr_check
end

function zobject_set_attribute(index, attribute_id, val)
	-- log('zobject_set_attribute object: '..index..', set attr '..attribute_id..' to: '..val)
	-- assert(val <= 1, 'can only set binary value on attributes,'..index..','..attribute_id..','..val)
	local attr_byte, attr_bit, address = zobject_attributes_byte_bit(index, attribute_id)
	attr_byte &= ~(0x80>>attr_bit)
	attr_byte |= (val<<(7-attr_bit))
	set_zbyte(address, attr_byte)
end

--properties start at 1, not 0; offsets are (property - 1) * offset
function zobject_default_property(property)
	assert(property <= _zm_object_property_count, 'ERR: default object property '..property)
	local address = _object_table_mem_addr + ((property - 1) >>> 15)
	return get_zword(address)
end

zparent, zsibling, zchild = 0, 1, 2
function zfamily_address(index, family_member)
	local address = zobject_address(index)
	local attr_size, member_size = 0x.0006, 0x.0002
	if (_zm_version == 3) attr_size, member_size = 0x.0004, 0x.0001
	address += attr_size + (family_member * member_size)
	return address
end

function zobject_family(index, family_member)
	local address = zfamily_address(index, family_member)
	if (_zm_version == 3) return get_zbyte(address)
	return get_zword(address)
end

function zobject_set_family(index, family_member, family_index)
	local address = zfamily_address(index, family_member)
	if _zm_version == 3 then
		set_zbyte(address, family_index)
	else
		set_zword(address, family_index)
	end
end

-- 12.3.1
function zobject_prop_table_address(index)
	local offset = (_zm_version == 3) and 0x.0007 or 0x.000c
	local prop_table_address = zobject_address(index) + offset
	local zword = get_zword(prop_table_address)
	return zword_to_zaddress(zword)
end

-- 12.4
function zobject_text_length(index)
	--text length is the number of 2-byte words
	local prop_address = zobject_prop_table_address(index)
	return get_zbyte(prop_address), prop_address
end

function zobject_name(index)
	local text_length, prop_address = zobject_text_length(index)
	if text_length > 0 then
		local str, zchars = get_zstring(prop_address + 0x.0001)
		return str, zchars
	end
	return '', {}
end

-- 12.4.1
function zobject_prop_num_len(prop_num_len_address)
	local raw_byte = get_zbyte(prop_num_len_address)
	local prop_num, prop_len, offset = 0, 0, 1
	if _zm_version == 3 then
		prop_num = raw_byte & 0x1f
		prop_len = extract_prop_len(raw_byte)
	else
		prop_num = raw_byte & 0x3f
		if (raw_byte & 0x80) == 0x80 then
			local next_byte = get_zbyte(prop_num_len_address + 0x.0001)
			prop_len = extract_prop_len(next_byte)
			if (prop_len == 0) prop_len = 64
			offset = 2
		else
			prop_len = extract_prop_len(raw_byte)
		end
	end
	return prop_num, prop_len, offset
end

-- 12.4.2
function extract_prop_len(len_byte)
	if _zm_version == 3 then
		return ((len_byte >>> 5) & 0x7) + 1
	else
		if (len_byte & 0x80) == 0 then
			return ((len_byte >>> 6) & 0x1) + 1
		else
			return (len_byte & 0x7f)
		end
	end
end

function zobject_prop_data_addr_or_prop_list(index, property)
	
	local collect_list = (property == nil)
	local prop_list = {}

	local text_length, prop_address = zobject_text_length(index)
	--value * 0x.0002 == value >>> 15 (i.e. >>> 16 for *.0001, << 1 for *2)
	prop_address += (0x.0001 + (text_length >>> 15))

	local prop_num, prop_len, offset = zobject_prop_num_len(prop_address)
	while prop_num > 0 do

		if collect_list == true then
			add(prop_list, prop_num)
		else
			if prop_num == property then
				return (prop_address + (offset >>> 16)), prop_len
			end
		end

		prop_address += ((prop_len + offset) >>> 16)
		prop_num, prop_len, offset = zobject_prop_num_len(prop_address)
	end
	
	if collect_list == true then
		return prop_list
	end
	return 0
end

function zobject_get_prop(index, property)
	local prop_data_address = zobject_prop_data_addr_or_prop_list(index, property)
	if (prop_data_address == 0) return zobject_default_property(property)

	local len_byte = get_zbyte(prop_data_address - 0x.0001)
	local len = extract_prop_len(len_byte)
	-- log('zobject_get_prop '..property..' at addr: '..tohex(prop_data_address)..', len: '..len)
	if (len == 1) return get_zbyte(prop_data_address)
	if (len == 2) return get_zword(prop_data_address)
	return 0
end

function zobject_set_prop(index, property, value)
	local prop_data_address = zobject_prop_data_addr_or_prop_list(index, property)
	-- assert(prop_data_address != 0, 'ERR: property '..property..' does not exist for object '..index)

	local len_byte = get_zbyte(prop_data_address - 0x.0001)
	local len = extract_prop_len(len_byte)

	if len == 1 then
		 set_zbyte(prop_data_address, value & 0xff)
	else
		 set_zword(prop_data_address, value & 0xffff)
	end
end

function get_zstring(zaddress)
	local end_found, zchars = false, {}
	-- log('fetching zstring starting at address: '..tostr(zaddress,true))

	while end_found == false do
		local zword = get_zword(zaddress)
		add(zchars, ((zword & 0x7c00)>>>10))
		add(zchars, ((zword & 0x03e0)>>>5))
		add(zchars, (zword & 0x001f))
		if (zaddress) zaddress += 0x.0002
		end_found = ((zword & 0x8000) == 0x8000)
	end
	active_table = 1
	return zscii_to_p8scii(zchars)
end

--the u(pper) and l(ower) are reversed for p8scii
--set them to the same if you don't like mixed case
local l_zchars = '     abcdefghijklmnopqrstuvwxyz'
local u_zchars = '     ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local p_zchars = '      \n0123456789'..punc
local zchar_tables = {l_zchars, u_zchars, p_zchars}

local zscii, zscii_decode, abbr_code = nil, false, nil

function zscii_to_p8scii(zchars)
	local zstring = ''
	for i = 1, #zchars do
		local zchar = zchars[i]
		-- log('  zchar: '..zchar..', table: '..active_table)
		if zscii_decode == true then
			if zscii == nil then
				zscii = zchar << 5
			else
				zscii |= zchar
				zstring ..= chr(zscii)
				zscii_decode = false
				zscii = nil
				active_table = 1
			end

		elseif abbr_code then
			--32(abbr_code-1)+next_zchar
			-- log('abbreviation code hit!')
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
			zstring ..= chr(zchar)
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
	local function extract_operands(info, _count)
		-- log(' extract_operands: '..tohex(info)..', '.._count)
		for i = _count-1, 0, -1 do
			local op_type = (info >>> (i*2)) & 0x03
			-- log('  byte '..i..', op type: '..op_type)
			local operand
			if op_type == 0 then
				operand = get_zword()
			elseif op_type == 1 then
				operand = get_zbyte()
			elseif op_type == 2 then
				operand = get_var()
			elseif op_type == 3 then
				break
			end
			-- log('  operand '..tohex(operand))
			add(operands, operand)
		end
	end
	
	-- An instruction consists of opcode and operands
	-- First 1 to 3 bytes contain opcode and operand types
	-- Subsequent bytes are the operands
	local pc = _program_counter
	local op_definition = get_zbyte()
	log(' op_definition: '..tohex(op_definition))
	op_form = (op_definition >>> 6)
	if (op_definition == 0xbe) op_form = 0xbe
	op_form &= 0xff

	local op_table_name
	if op_form <= 0x01 then
		op_table_name = 'long'
		-- The first byte of a long instruction is %0abxxxxx where
		-- 0 == "long instruction" indicator
		-- a == "operand type of first byte"
		-- b == "operand type of second byte"
		-- %xxxxx == "5 bits which indicate the 2OP opcode"
		op_table = _long_ops
		op_code = (op_definition & 0x1f)
		operands[1] = get_zbyte()
		operands[2] = get_zbyte()
		if (op_definition & 0x40 == 0x40) then
			operands[1] = get_var(operands[1])
		end
		if (op_definition & 0x20 == 0x20) then
			operands[2] = get_var(operands[2])
		end

	elseif op_form == 0xbe and _zm_version >= 5 then
		op_table_name = 'ext'
		-- the first byte of an extended instruction is $BE, it is an extended instruction. 
		-- The second byte contains the EXT opcode.
		-- Then follow the operand types (one byte) and the operands themselves,
		-- in the same format as for variable instructions (as op_form 0x03 below).
		op_table = _ext_ops
		op_code = get_zbyte()
		type_information = get_zbyte()
		extract_operands(type_information,4)

	elseif op_form == 0x02 then
		op_table_name = 'short'
		-- The first byte of a short instruction is %10ttxxxx.
		-- %tt is the type of the operand (or %11 if absent),
		-- %xxxx is the 1OP (0OP if operand absent) opcode
		op_table = _short_ops
		op_code = (op_definition & 0xf)
		local op_type = (op_definition & 0x30) >>> 4
		if op_type == 0 then
			operands = get_zword()
		elseif op_type == 1 then
			operands = get_zbyte()
		elseif op_type == 2 then
			operands = get_var()
		elseif op_type == 3 then
			op_table_name = 'zero'
			op_table = _zero_ops
			operands = nil
		end
		operands = {operands}

	elseif op_form == 0x03 then
		op_table_name = 'var'
		-- The first byte of a v3 variable instruction is %11axxxxx
		-- (two exceptions for v4+) where %xxxxx is the VAR opcode.
		-- If %a is %1 its a VAR opcode (if %0, a 2OP opcode)
		-- The second byte contains type info for the operands.
		-- It is divided into pairs of bits, 
		-- each indicating the operand type, beginning with top bits.
		-- Subsequent bytes contain the operands in that order.
		-- A %11 pair means ‘no operand’

		op_table = _var_ops
		if (op_definition & 0x20 == 0) then
			op_table_name = '2OP'
			op_table = _long_ops
		end
		op_code = (op_definition & 0x1f)

		local type_information, num_bytes
		if ((_zm_version > 3) and (op_definition == 0xec or op_definition == 0xfa)) then
			log('double var')
			type_information, num_bytes = get_zword(), 8
		else
			type_information, num_bytes = get_zbyte(), 4
		end
		extract_operands(type_information, num_bytes)
		if ((op_table == _long_ops) and (#operands == 1) and (op_code > 1)) get_zbyte()
	end
	local op_string = ''
	for i = 1, #operands do
		op_string ..= tohex(operands[i])..', '
	end
	log(sub(tohex(pc),8)..": "..op_table_name..(op_code+1)..'('..op_string..')')
	local func = op_table[op_code+1]
	return func, operands
end

function capture_state(state)

	local mem_max_bank, mem_max_index, _ = get_memory_location( _static_memory_mem_addr - 0x.0001)

	if state == _memory_start_state then
		-- log('capture _memory_start_state')
		_memory_start_state = {}
		for i = 1, mem_max_bank do
			if i < mem_max_bank then
				_memory_start_state[i] = {unpack(_memory[i])}
			else
				add(_memory_start_state, {})
				for j = 1, mem_max_index do
					_memory_start_state[i][j] = _memory[i][j]
				end			
			end
		end
		-- log("after memory_start_state with bank "..mem_max_bank..": "..stat(0))
	else

		local memory_dump = dword_to_str(tonum(_engine_version))

		-- log('saving memory up to bank: '..mem_max_bank..', index: '..mem_max_index)
		memory_dump ..= dword_to_str(mem_max_index)
		for i = 1, mem_max_bank do
			local max_j = _memory_bank_size
			if (i == mem_max_bank) max_j = mem_max_index
			for j = 1, max_j do
				memory_dump ..= dword_to_str(_memory[i][j])
			end
		end

		-- log('saving call stack: '..(#_call_stack))
		memory_dump ..= dword_to_str(#_call_stack)
		for i = 1, #_call_stack do
			local frame = _call_stack[i]
			memory_dump ..= dword_to_str(frame.pc)
			memory_dump ..= dword_to_str(frame.call)
			memory_dump ..= dword_to_str(frame.args)
			-- log("saving frame"..i..": "..tohex(frame.pc)..', '..tohex(frame.call)..', '..tohex(frame.args))
			--save local stack size and values
			memory_dump ..= dword_to_str(#frame.stack)
			-- log("---frame stack---")
			for j = 1, #frame.stack do
				memory_dump ..= dword_to_str(frame.stack[j])
				-- log("  "..j..': '..tohex(frame.stack[j])..' -> '..dword_to_str(frame.stack[j]))
			end
			--save local vars (always 16)
			-- log("---frame vars---")
			for k = 1, 16 do
				memory_dump ..= dword_to_str(frame.vars[k])
				-- log("  "..k..": "..tohex(frame.vars[k])..' -> '..dword_to_str(frame.vars[k]))
			end
		end

		-- log('saving pc: '..(tohex(_program_counter,true)))
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