-- memory address markers
_paged_memory_addr = 0x0
_dictionary_addr = 0x0
_object_table_addr = 0x0
_global_var_table_addr = 0x0
_abbr_table_addr = 0x0
_static_mem_addr = 0x0
_dynamic_mem_addr = 0x0
_high_mem_addr = 0x0

_program_counter_addr = 0xa
_local_var_table_addr = 0xb
_stack_var_addr = 0xc.0001 -- +.0001 to disambiguate from real number 0xc
--just need the above to be higher than _memory can reach. 
--On a 256K z5 game, we'll have memory addresses potentially as high as 0x7.fff8

-- header locations 3+
version = 0x.0000
interpreter_flags = 0x.0001
release_number_addr = 0x.0002
paged_memory_addr = 0x.0004
program_counter_addr = 0x.0006
dictionary_addr = 0x.0008
object_table_addr = 0x.000a
global_var_table_addr = 0x.000c
static_mem_addr = 0x.000e
peripherals = 0x.0010
serial_code = 0x.0012
abbr_table_addr = 0x.0018
file_length = 0x.001a
file_checksum = 0x.001c
-- header locations v4+
interpreter_number = 0x.001e
interpreter_version = 0x.001f
_screen_height = 0x.0020 --lines
_screen_width = 0x.0021 --characters

active_table = 1

bank_size = 16384 -- (1024*64)/4; four 64K banks
_memory = {{}}
--call stack holds a flat list of frame data
--a frame consists of 10 numbers:
--   stack pointer, program counter, 8 zwords for in-scope local vars
_call_stack = {}
_stack = {}

--these copies are used to grab a save state snapshot
_memory_start_state = nil
_current_state = ''

--we can't reset all memory otherwise the player
--would have to drag the z3 game file in again
function reset_game()
	for i = 1, #_memory_start_state do
		local bank = _memory_start_state[i]
		for j = 1, #bank do
			_memory[i][j] = _memory_start_state[i][j]
		end
	end
	_call_stack = {}
	_stack = {}
	_program_counter = 0x0
	_interrupt = nil
	story_loaded = false
	initialize_game()
end

function reset_all_memory()
	_memory = {{}}
	_call_stack = {}
	_stack = {}
	_program_counter = 0x0
	_interrupt = nil
	max_input_length = 0
	parse_buffer_length = 0
	separators = {}
	_dictionary_lookup = {}
	story_loaded = false
end

--may just be a zbyte, but storage is the same
--there is no such thing as popping individual bytes from words
function stack_push(zword)
	-- log('+ + stack_push: '..tohex(zword))
	add(_stack, zword)
end

function stack_pop()
	-- log('- - stack_pop: '..tohex(_stack[#_stack]))
	--assert(#_stack > 0, 'ERR: asked to pop from an empty stack!')
	if (#_stack == _call_stack[#_call_stack - 8]) then
		--log('ERR: asked to pop beyond the limit of this frames base sp')
		return nil
	end
	return deli(_stack, #_stack)
end

function stack_pop_to(index)
	--log('- - stack_pop_to: '..index)
	-- assert(index <= #_stack, 'ERR: asked to pop to an index > stack size')
	if index == 0 then
		_stack = {}
	else
		while (#_stack > index) deli(_stack, #_stack)
	end
	-- assert(#_stack == index, "didn't pop stack to the right index:"..#_stack.." vs. "..index)
end

function call_stack_push()
	_call_stack[#_call_stack - 9] = _program_counter
	for i = 1, 10 do
		add(_call_stack, 0x0)
	end
	_call_stack[#_call_stack - 8] = #_stack
end

function call_stack_pop(ret_value)
	stack_pop_to(_call_stack[#_call_stack - 8])
	for i = 1, 10 do
		deli(_call_stack, #_call_stack)
	end
	_program_counter = _call_stack[#_call_stack - 9]
	if ret_value != nil then
		local var_byte = get_zbyte()
		local ret_address = decode_var_address(var_byte)
		--log('(var byte: '..tohex(var_byte)..' converted to address: '..tohex(ret_address)..', set to: '..tohex(ret_value)..')')
		set_zword(ret_address, ret_value)
	end
end


function stack_index(zaddress)
	local si = #_call_stack - (flr((0xf - (zaddress << 16)) >>> 1))
	--log('call_stack_index for zaddress: '..tohex(zaddress)..' is: '..si)
	return si
end

function abbr_address(index)
	--abbreviation addresses are word addresses (2*addr)
	return zword_to_zaddress(get_zword(_abbr_table_addr + (index >>> 15))<<1)
end 

function zobject_address(index)
	-- skip first 31/63 zwords of "default property table"
	local address = _object_table_addr + (default_property_count>>>15)
	-- log('zobject_address old: '..tohex(old_address)..' new: '..tohex(address))
	address += (index-1)*object_entry_size
	return address
end

function local_var_addr(index)
	--log(' getting address for local var: '..tohex(index))
	-- assert(index > 0 and index < 16, 'ERR: asked to retrieve local var '..tostr(index))
	return _local_var_table_addr + (index >>> 16)
end

function global_var_addr(index)
	-- index*0x.0002 == (index>>>15)
	local addr = _global_var_table_addr + (index >>> 15)
	--log(' address for G'..sub(tostr(index,true),5,6)..' is: '..tohex(addr))
	return addr
end

function set_var(value, var_byte, indirect)
	local var_address = decode_var_address(var_byte)
	set_zword(var_address, value, indirect)
end

function get_var(var_byte, indirect)
	local var_address = decode_var_address(var_byte)
	local r = get_zword(var_address, indirect)
	return r
end

function decode_var_address(var_byte)
	local var_byte = var_byte or get_zbyte()
	-- log('decode_var_address: '..var_byte)
	if (var_byte == 0) return _stack_var_addr
	if (var_byte < 16) return local_var_addr(var_byte)
	if (var_byte >= 16) return global_var_addr(var_byte-16) -- -16 ONLY when decoding var byte
end

function zword_to_zaddress(zaddress, is_packed)
	local shift = 16
	if (is_packed) shift -= packed_shift
	return (zaddress >>> shift)
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
	return bank, index, cell
end

function get_dword(zaddress, indirect)
	local zaddress = zaddress or _program_counter
	local base = (zaddress & 0xffff)

	if (base < 0xa) then
		local bank, index, cell = get_memory_location(zaddress)
		return _memory[bank][index], bank, index, cell
	end

	if (base == _local_var_table_addr) then
		index = stack_index(zaddress)
		return _call_stack[index], nil, index
	end

	if (zaddress == _stack_var_addr) then
		if (indirect) return _stack[#_stack]
		return stack_pop()
	end
end

--zaddresses *must* be right-aligned before requesting
--a zbyte or zword. Some routines need to add an offset
--and the result may transition from 2- to 3-byte address
function get_zbyte(zaddress)
	if (zaddress == nil) then
	-- log('______________________PC at: '..tohex(_program_counter))
		zaddress = _program_counter
		_program_counter += 0x.0001
	-- log('                       now: '..tohex(_program_counter))
	end
	local base = (zaddress & 0xffff)
	local dword, _, _, cell  = get_dword(zaddress)

	if (base < 0xa) then
		if cell < 2 then
			dword >>>= (8 - (8*cell))
		else
			dword <<= (2 << cell)
		end
	elseif (base == _local_var_table_addr) then
		if (zaddress & 0x.0001 == 0x.0001) dword <<= 16
	end
	-- if (zaddress == _screen_width) then
	-- 	log('screen width called, returning: '..(dword & 0xff))
	-- elseif zaddress == interpreter_flags then
	-- 	log('interpreter flags, returning: '..tohex(dword))
	-- end
	return dword & 0xff
end

function get_zbytes(zaddress, num_bytes)
	if (not zaddress) return
	if (not num_bytes) return get_zbyte(zaddress)

	local bytes = {}
	for i = 0, num_bytes - 1 do
		add(bytes, get_zbyte(zaddress + (i*0x.0001)))
	end
	return bytes
end

function set_zbyte(zaddress, byte)
	--log('set_zbyte at '..tohex(zaddress)..' to value: '..byte)
	local byte &= 0xff --filter off zword garbage
	local base = (zaddress & 0xffff)

	if (zaddress == _stack_var_addr) then
		-- log(' setting stack var byte: '..byte)
		stack_push(byte)
	else
		local dword, bank, index, cell  = get_dword(zaddress)
		if (base < 0xa) then
			local filter = ~(0xff00.0000 >>> (cell << 3))
			dword &= filter
			byte <<= 8
			byte >>>= (cell << 3)
			dword |= byte
			_memory[bank][index] = dword
		else
			if (zaddress & 0x.0001 == 0) then
				dword = (dword & 0x.ffff) | byte
			else
				dword = (dword & 0xffff) | (byte >>> 16)
			end
			_call_stack[index] = dword
		end
	end
end

function set_zbytes(zaddress, bytes)
	for i = 1, #bytes do
		local byte = bytes[i]
		set_zbyte(zaddress, byte)
		zaddress += 0x.0001
	end
end

function get_zword(zaddress, indirect)
	if (zaddress == nil) then
		zaddress = _program_counter
		_program_counter += 0x.0002
	end	
	local dword, bank, index, cell  = get_dword(zaddress, indirect)
	-- log('  get_zword at address: '..tohex(zaddress,true)..', fetched: '..tohex(dword))
	local base = (zaddress & 0xffff)

	if (base < 0xa) then
		dword <<= (8 * cell)
		if cell == 3 then
			index += 1
			if (index > #_memory[bank]) bank += 1 index = 1
			local dwordb = _memory[bank][index]
			-- log('  consecutive dword '..tohex(dwordb))
			dword |= (dwordb >>> 8)
		end
	elseif (base == _local_var_table_addr) then
		if (zaddress & 0x.0001 == 0x.0001) dword <<= 16
	end
	return dword & 0xffff
end

function set_zword(zaddress, zword, indirect)
	-- log(' setting zword: '..tohex(zword))
	local zword &= 0xffff --filter off dword garbage
	-- local base = (zaddress & 0xffff)
	--log('set_zword at '..tohex(zaddress)..' to value: '..tohex(zword))
	
	if (zaddress == _stack_var_addr) then
		-- log(' setting stack var zword: '..tohex(zword))
		if indirect then
			_stack[#_stack] = zword
		else
			stack_push(zword)
		end
	else
		local dword, bank, index, cell  = get_dword(zaddress, indirect)
		if (zaddress < 0xa) then
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
			_call_stack[index] = dword
		end
	end
end

function zobject_attributes_byte_bit(index, attribute_id)
	-- old_zobject_attributes(index)
	local address = zobject_address(index)
	-- local byte_count = (_z_machine_version == 3) and 4 or 6
	local byte_index = flr(attribute_id>>3)
	local attr_bit = attribute_id % 8
	address += (0x.0001 * byte_index)
	-- log('  NEW zobject_attributes_byte_bit: '..get_zbyte(address)..', '..attr_bit..','..tohex(address))
	return get_zbyte(address), attr_bit, address
end

function zobject_has_attribute(index, attribute_id)
	local attr_byte, attr_bit = zobject_attributes_byte_bit(index, attribute_id)
	-- log('  NEW zobject_has_attribute: '..index..', id:'..attribute_id..', attributes: '..tohex(attr_byte,true))
	local attr_check = (0x80>>attr_bit)
	-- log('    attr_check: '..tohex(attr_check,true))
	-- log('    '..tostr((attr_byte & attr_check) == attr_check))
	return (attr_byte & attr_check) == attr_check
end

function zobject_set_attribute(index, attribute_id, val)
	-- log('zobject_set_attribute object: '..index..', set attr '..attribute_id..' to: '..val)
	-- assert(val <= 1, 'can only set binary value on attributes,'..index..','..attribute_id..','..val)
	local attr_byte, attr_bit, address = zobject_attributes_byte_bit(index, attribute_id)
	-- log('    NEW current attributes: '..tohex(attr_byte))
	attr_byte &= ~(0x80>>attr_bit)
	attr_byte |= (val<<(7-attr_bit))
	-- log('    set bit '..attr_bit..', became: '..tohex(attr_byte))
	set_zbyte(address, attr_byte)
end

--properties start at 1, not 0
--so the table address is pointing at property #1
--therefore, offsets are (property - 1) * offset
function zobject_default_property(property)
	assert(property <= default_property_count, 'ERR: default object property '..property)
	local address = _object_table_addr + ((property - 1) * 0x.0002)
	return get_zword(address)
end

zparent, zsibling, zchild = 0, 1, 2
function zfamily_address(index, family_member)
	local address = zobject_address(index)
	local attr_size, member_size = 0x.0004, 0x.0001
	if (_z_machine_version > 3) attr_size, member_size = 0x.0006, 0x.0002 
	address += attr_size + (family_member * member_size)
	return address
end

function zobject_family(index, family_member)
	local address = zfamily_address(index, family_member)
	if (_z_machine_version == 3) return get_zbyte(address)
	return get_zword(address)
end

function zobject_set_family(index, family_member, family_index)
	local address = zfamily_address(index, family_member)
	if _z_machine_version == 3 then
		set_zbyte(address, family_index)
	else
		set_zword(address, family_index)
	end
end

-- 12.3.1
function zobject_prop_table_address(index)
	local offset = (_z_machine_version == 3) and 0x.0007 or 0x.000c
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
	if (text_length > 0) then
		local str, zchars = get_zstring(prop_address + 0x.0001)
		return str, zchars
	end
	return '', {}
end

-- 12.4.1
function zobject_prop_num_len(prop_num_len_address)
	local raw_byte = get_zbyte(prop_num_len_address)
	local prop_num, prop_len, offset = 0, 0, 1
	if _z_machine_version == 3 then
		prop_num = raw_byte & 0x1f
		prop_len = extract_prop_len(raw_byte)
	else
		prop_num = raw_byte & 0x3f
		if (raw_byte & 0x80) == 0x80 then
			local next_byte = get_zbyte(prop_num_len_address + 0x.0001)
			-- log('  checking prop len on next_byte: '..tohex(next_byte))
			prop_len = extract_prop_len(next_byte)
			if (prop_len == 0) prop_len = 64
			offset = 2
		else
			-- log('  checking prop len on raw_byte: '..tohex(raw_byte))
			prop_len = extract_prop_len(raw_byte)
		end
	end
	return prop_num, prop_len, offset
end

-- 12.4.2
function extract_prop_len(len_byte)
	if _z_machine_version == 3 then
		-- log('extract_prop_len: '..len_byte)
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
		-- log('prop num: '..prop_num..', has num bytes: '..prop_len)

		if (collect_list == true) then
			add(prop_list, prop_num)
		else
			if (prop_num == property) then
				-- log('found property '..property..' at address: '..tohex(prop_address, true))
				-- log('  returning address: '..tohex(prop_address + (offset >>> 16)))
				return (prop_address + (offset >>> 16)), prop_len
			end
		end

		prop_address += ((prop_len + offset) >>> 16)
		prop_num, prop_len, offset = zobject_prop_num_len(prop_address)
	end
	
	if (collect_list == true) then
		-- log('returning prop list: '..#prop_list)
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
	assert(prop_data_address != 0, 'ERR: property '..property..' does not exist for object '..index)

	local len_byte = get_zbyte(prop_data_address - 0x.0001)
	local len = extract_prop_len(len_byte)
	-- log('zobject_set_prop '..property..' at addr: '..tohex(prop_data_address)..', value: '..value..', len: '..len)
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
			zstring ..= sub(lookup_string, zchar, _)
			active_table = 1
		end
	end
	return zstring
end

function load_instruction()
	
	-- An instruction consists of opcode and operands
	-- First 1 to 3 bytes contain opcode and operand types
	-- Subsequent bytes are the operands
	-- log('::load_instruction at: '..tohex(_program_counter))	
	local op_definition = get_zbyte()
	-- log(' op_definition: '..tohex(op_definition))
	local op_form = (op_definition >>> 6) & 0xffff

	local op_table, op_code, operands = nil, 0, {}
	if (op_form <= 0x01) then
		-- log(' long instruction found')
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

	elseif (op_form == 0x02) then
		-- log(' short instruction found')
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
			-- log(' - a zero op')
			op_table = _zero_ops
			operands = nil
		end
		operands = {operands}

	elseif (op_form == 0x03) then
		-- log(' var instruction found')
		-- The first byte of a v3 variable instruction is %11axxxxx
		-- (two exceptions for v4+) where %xxxxx is the VAR opcode.
		-- If %a is %1 its a VAR opcode (if %0, a 2OP opcode)
		-- The second byte contains type info for the operands.
		-- It is divided into pairs of bits, 
		-- each indicating the operand type, beginning with top bits.
		-- Subsequent bytes contain the operands in that order.
		-- A %11 pair means ???no operand???

		op_table = _var_ops
		-- if _z_machine_version > 3 then
			if (op_definition & 0x20 == 0) then
				-- log('  (2OP actually)')
				op_table = _long_ops
			end
		-- end
		op_code = (op_definition & 0x1f)

		local type_information, num_bytes, filter
		if (_z_machine_version > 3 and (in_set(op_definition, {0xec, 0xfa}))) then
			-- log('double var op_code')
			type_information = get_zword()
			num_bytes = 7 -- for the loop; 8 bytes really
			filter = 0xc000
		else
			type_information = get_zbyte()
			num_bytes = 3 --4 bytes really
			filter = 0xc0
		end
		-- log(' type_information: '..tohex(type_information))
		for i = 0, num_bytes do
			local filtered_byte = type_information & (filter >>> (i << 1))
			local op_type = filtered_byte >>> ((num_bytes-i)<<1)
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
		if ((op_table == _long_ops) and (#operands == 1) and (op_code > 1)) get_zbyte()
	end
	-- log('  opcode: '..op_code)
	local func = op_table[op_code+1]
	return func, operands
end

function capture_state(state)

	local mem_max_bank, mem_max_index, _ = get_memory_location( _static_mem_addr - 0x.0001)

	if state == _memory_start_state then
		-- log('capture _memory_start_state')
		_memory_start_state = {}
		for i = 1, mem_max_bank do
			add(_memory_start_state, {})
			local max_j = bank_size
			if (i == mem_max_bank) max_j = mem_max_index
			for j = 1, max_j do
				_memory_start_state[i][j] = _memory[i][j]
			end
		end
	else

		local memory_dump = dword_to_str(tonum(_engine_version))

		-- log('saving memory up to bank: '..mem_max_bank..', index: '..mem_max_index)
		memory_dump ..= dword_to_str(mem_max_index)
		for i = 1, mem_max_bank do
			local max_j = bank_size
			if (i == mem_max_bank) max_j = mem_max_index
			for j = 1, max_j do
				memory_dump ..= dword_to_str(_memory[i][j])
			end
		end

		-- log('saving call stack: '..(#_call_stack))
		memory_dump ..= dword_to_str(#_call_stack)
		for i = 1, #_call_stack do
			memory_dump ..= dword_to_str(_call_stack[i])
		end

		-- log('saving stack: '..(#_stack))
		memory_dump ..= dword_to_str(#_stack)
		for i = 1, #_stack do
			memory_dump ..= dword_to_str(_stack[i])
		end

		-- log('saving pc: '..(tohex(_program_counter,true)))
		memory_dump ..= dword_to_str(_program_counter)
		-- log('saving checksum: '..(tohex(checksum,true)))
		local checksum = get_zword(file_checksum)
		memory_dump ..= dword_to_str(checksum)

		_current_state = memory_dump
	end
end

function load_story_file()
	while stat(120) do
		if (#_memory[#_memory] == bank_size) add(_memory, {})
		local bank_num = #_memory
		local chunk = serial(0x800, 0x4300, 1024)
		for j = 0, chunk-1, 4 do
			local a, b, c, d = peek(0x4300+j, 4)
			local a <<= 8
			local c >>>= 8
			local d >>>= 16
			local dword = (a|b|c|d)
			add(_memory[bank_num], dword)
		end
	end
	initialize_game()
end