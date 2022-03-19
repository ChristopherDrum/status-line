-- memory address markers
_paged_memory_addr = 0x0
_dictionary_addr = 0x0
_object_table_addr = 0x0
_global_var_table_addr = 0x0
_abbr_table_addr = 0x0
_static_mem_addr = 0x0
_dynamic_mem_addr = 0x0
_high_mem_addr = 0x0
_local_var_table_addr = 0x2
_stack_var_addr = 0x3.0001 --disambiguate from 0x3 the literal number 3
_program_counter_addr = 0x4

--locations in header, v3 only
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
screen_height = 0x.0020
screen_width = 0x.0021

--memory is as close to 128K bytes as I can get it
--lua indices run 0x0001 to 0x7fff; ideally we WANT 0x0000 to 0xffff
--so this means we are 8 bytes short of the 128K z-machine specification
--games that use every single possible byte will fail in Status Line
--this will be addressed in a more robust memory banking strategy
--when z5 game support is added
_memory = {}
--call stack holds a flat list of frame data
--a frame consists of 10 numbers:
--   a stack pointer, a program counter, 8 zwords for in-scope local vars
_call_stack = {}
_stack = {}

--these copies are used to grab a save state snapshot
memory_copy = {}
call_stack_copy = {}
stack_copy = {}
pc_copy = nil

local _memory_start_state = {}

--we can't just reset all memory when the game resets
--otherwise the player would have to drag the z3 game file in again
function reset_game()
	_memory = {}
	for i = 1, #_memory_start_state do
		add(_memory, _memory_start_state[i])
	end
	_call_stack = {}
	_stack = {}
	_program_counter = 0x0
	_interrupt = nil
	story_loaded = false
	initialize_game()
end

function reset_all_memory()
	_memory = {}
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
--there is no such thing as popping individual bytes from the words
function stack_push(zword)
	log('+ + stack_push: '..tohex(zword))
	add(_stack, zword)
end

function stack_pop()
	log('- - stack_pop: '..tohex(_stack[#_stack]))
	-- assert(#_stack > 0, 'ERR: asked to pop from an empty stack!')
	if (#_stack == _call_stack[#_call_stack - 8]) then
		--log('ERR: asked to pop beyond the limit of this frames base sp')
		return nil
	end
	return deli(_stack, #_stack)
end

function stack_pop_to(index)
	--log('- - stack_pop_to: '..index)
	assert(index <= #_stack, 'ERR: asked to pop stack to an index greater than the stack size')
	if (index == 0) then
		_stack = {}
	else
		while (#_stack > index) deli(_stack, #_stack)
	end
	assert(#_stack == index, "didn't pop the stack to the right index:"..#_stack.." vs. "..index)
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
	if (ret_value != nil) then
		local var_byte = get_zbyte()
		local ret_address = decode_var_address(var_byte)
		--log('(var byte: '..tohex(var_byte)..' coverted to address: '..tohex(ret_address)..', set to: '..tohex(ret_value)..')')
		set_zword(ret_address, ret_value)
	end
end


function stack_index(zaddress)

	local si = (zaddress << 16)
	si = 0xf - si
	si = si >> 1
	si = flr(si)
	si = #_call_stack - si

	local si = #_call_stack - (flr((0xf - (zaddress<< 16)) >> 1))
	--log('call_stack_index for zaddress: '..tohex(zaddress)..' is: '..si)
	return si
end

function abbr_address(index)
	--abbreviation addresses are packed >>>16 and << 1 == >>>15
	return zword_to_zaddress(get_zword(_abbr_table_addr + (index >>> 15)), true)
end

function zobject_address(index)
	-- skip first 31 zwords of "default property table"
	local address = _object_table_addr + 0x.003e 
	address += (index-1)*0x.0009
	return address
end

function local_var_address(index)
	-- --log(' getting address for local var: '..tohex(index))
	assert(index > 0 and index < 16, 'ERR: asked to retrieve local var '..tostr(index))
	return _local_var_table_addr + (index >>> 16)
end

function global_var_address(index)
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
	log('   --> '..tohex(r))
	return r
end

function decode_var_address(var_byte)
	local var_byte = var_byte or get_zbyte()
	log(' --> asked to decode var byte: '..var_byte)
	if (var_byte == 0) return _stack_var_addr
	if (var_byte < 16) return local_var_address(var_byte)
	if (var_byte >= 16) return global_var_address(var_byte-16) -- subtract 16 ONLY when decoding a var byte!
end

function zword_to_zaddress(zaddress, is_packed)
	zaddress >>>= 16
	if (is_packed) zaddress <<= 1
	return zaddress
end

-- a "zaddress" means the address is shifted as far right as possible
-- to allow for 3-byte addressing. It represents the VM address
-- as the VM understands things
-- index: the index into the _memory table
-- cell: the 0-indexed byte within the dword contained at index
function get_dword(zaddress, indirect)
	local zaddress = zaddress or _program_counter
	local base = (zaddress & 0xffff)

	--getting the index of the memory address
	--is also useful for the save/restore function
	--maybe factor this out and share the code?
	if (base <= 0x0001) then
		local za = (zaddress << 14) + 1
		local index = za & 0xffff
		local cell = (za & 0x.ffff) << 2
		return _memory[index], cell, index
	end

	if (base == 0x0002) then
		index = stack_index(zaddress)
		return _call_stack[index], nil, index
	end

	if (zaddress == _stack_var_addr) then
		if (indirect) return _stack[#_stack]
		return stack_pop()
	end
	-- --log('zaddress (vm): '..tostr(zaddress << packed, true))
	-- --log('paddress (p8): '..tostr(paddress, true))
	-- --log('location (table): '..index..', '..cell)
end

--zaddresses *must* be right-aligned before requesting a zbyte or zword
--to allow for 3-byte address possibilities
--i.e. 0x1a892 is possible (though it will never go beyond 0x1fffe)
--WHY pre-shift? Because some routines need to add an offset to the address
--and the resulting address may transition from 2-byte to 3-byte
function get_zbyte(zaddress)
	if (zaddress == nil) then
		zaddress = _program_counter
		_program_counter += 0x.0001
	end
	local base = (zaddress & 0xffff)
	local dword, cell  = get_dword(zaddress)

	if (base <= 0x0001) then
		if cell < 2 then
			dword >>>= (8 - (8*cell))
		else
			dword <<= (2 << cell)
		end
	elseif (base == 0x0002) then
		if (zaddress & 0x.0001 == 0x.0001) dword <<= 16
	end
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
	local byte &= 0xff --filter off any zword garbage
	local base = (zaddress & 0xffff)

	if (zaddress == _stack_var_addr) then
		log(' setting stack var byte: '..byte)
		stack_push(byte)
	else
		local dword, cell, index  = get_dword(zaddress)
		if (base <= 0x0001) then
			local filter = ~(0xff00.0000 >>> (cell << 3))
			dword &= filter
			byte <<= 8
			byte >>>= (cell << 3)
			dword |= byte
			_memory[index] = dword
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
	local dword, cell, index  = get_dword(zaddress, indirect)
	-- --log('fetched dword: '..tohex(dword))
	local base = (zaddress & 0xffff)

	if (base <= 0x0001) then
		dword <<= (8 * cell)
		if cell == 3 then
			local dwordb = _memory[index+1]
			dword |= (dwordb >>> 8)
		end
	elseif (base == 0x0002) then
		if (zaddress & 0x.0001 == 0x.0001) dword <<= 16
	end
	return dword & 0xffff
end

function set_zword(zaddress, zword, indirect)
	log(' setting zword: '..tohex(zword))
	local zword &= 0xffff --filter off any dword garbage
	local base = (zaddress & 0xffff)
	--log('set_zword at '..tohex(zaddress)..' to value: '..tohex(zword))
	
	if (zaddress == _stack_var_addr) then
		log(' setting stack var zword: '..tohex(zword))
		if indirect then
			_stack[#_stack] = zword
		else
			stack_push(zword)
		end
	else
		local dword, cell, index  = get_dword(zaddress, indirect)
		if (base <= 0x0001) then
			local filter = ~(0xffff.0000 >>> (cell << 3))
			dword &= filter
			if cell == 3 then
				local dwordb = _memory[index+1]
				dwordb &= 0x00ff.ffff
				dwordb |= (zword << 8)
				_memory[index+1] = dwordb
			end
			zword >>>= (cell << 3)
			dword |= zword
			_memory[index] = dword
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

function zobject_attributes(index)
	local address = zobject_address(index)
	log('  address for zobject: '..index..', '..tohex(address,true))
	local zworda = get_zword(address)
	local zwordb = get_zword(address + 0x.0002)
	return zworda | (zwordb >>> 16)
end

function zobject_has_attribute(index, attribute_id)
	local attributes = zobject_attributes(index)
	log('  zobject: '..index..', attributes: '..tohex(attributes,true))
	local attr_check = (0x8000 >>> attribute_id)
	log('    attr_check: '..tohex(attr_check,true))
	return (attributes & attr_check) == attr_check
end

function zobject_set_attribute(index, attribute_id, val)
	assert(val <= 1, 'can only set binary value on attributes,'..index..','..attribute_id..','..val)
	local attributes = zobject_attributes(index)
	if (val == 1) attributes |= (0x8000 >>> attribute_id)
	if (val == 0) attributes &= (~(0x8000 >>> attribute_id))
	--log('object: '..index..', set attr '..attribute_id..': '..tohex(attributes))
	local za = zobject_address(index)
	if (attribute_id < 16) then
		set_zword(za, attributes)
	else
		set_zword(za+0x.0002, (attributes<<16))
	end
end

--properties start with number 1, not 0
--so the table address is pointing at property #1
--therefore, offsets for the address are (property - 1) * offset
function zobject_default_property(property)
	assert(property <= 31, 'ERR: default object property '..property)
	local address = _object_table_addr + ((property - 1) * 0x.0002)
	return get_zword(address)
end

zparent, zsibling, zchild = 0, 1, 2
function zobject_family(index, family_member)
	local address = zobject_address(index)
	return get_zbyte(address + 0x.0004 + (family_member * 0x.0001))
end

function zobject_set_family(index, family_member, family_index)
	local address = zobject_address(index)
	address += 0x.0004 + (family_member * 0x.0001)
	set_zbyte(address, family_index)
end

function zobject_prop_table_address(index)
	local prop_table_address = zobject_address(index) + 0x.0007
	local zword = get_zword(prop_table_address)
	return zword_to_zaddress(zword)
end

function zobject_text_length(index)
	local prop_address = zobject_prop_table_address(index)
	return get_zbyte(prop_address)
end

function zobject_name(index)
	local text_length = zobject_text_length(index)
	local prop_address = zobject_prop_table_address(index)
	if (text_length > 0) return get_zstring(prop_address + 0x.0001)
	return ''
end

function zobject_prop_length(prop_address)
	local byte = get_zbyte(prop_address - 0x.0001)
	return ((byte >> 5) & 0x1f) + 1
end

function zobject_prop_list(index)
	--log('zobject prop list called for "'..zobject_name(index)..'": '..index)
	local prop_list = {}
	local prop_table_address = zobject_prop_table_address(index)
	local text_length = get_zbyte(prop_table_address)
	prop_table_address += (text_length * 0x.0002) + 0x.0001
	local size_byte = get_zbyte(prop_table_address)
	while size_byte != 0 do
		local num_bytes = ((size_byte & 0xe0)>>5) + 1
		local prop_num = size_byte & 0x1f
		add(prop_list, prop_num)
		prop_table_address += (0x.0001 * (num_bytes+1))
		size_byte = get_zbyte(prop_table_address)
	end
	return prop_list
end

function zobject_prop_address(index, property)
	--log('zobject prop address called for "'..zobject_name(index)..'": '..index..', property #'..property)
	local prop_table_address = zobject_prop_table_address(index)
	local text_length = get_zbyte(prop_table_address)
	prop_table_address += (text_length * 0x.0002) + 0x.0001
	local size_byte = get_zbyte(prop_table_address)
	while size_byte != 0 do
		local num_bytes = ((size_byte & 0xe0)>>5) + 1
		local prop_num = size_byte & 0x1f
		-- --log('prop num: '..prop_num..', has num bytes: '..num_bytes)
		if (prop_num == property) then
			--log('found property '..property..' at address: '..tohex(prop_table_address, true))
			return prop_table_address + 0x.0001
		else
			prop_table_address += (0x.0001 * (num_bytes+1))
		end
		size_byte = get_zbyte(prop_table_address)
	end
	return 0
end

function zobject_prop(index, property)
	local prop_address = zobject_prop_address(index, property)
	if (prop_address == 0) return zobject_default_property(property)
	local size_byte = get_zbyte(prop_address-0x.0001)
	local num_bytes = ((size_byte & 0xe0)>>5) + 1
	-- assert(num_bytes < 3, 'ERR: asked to get data for property '..property..' with invalid length '..num_bytes)
	if num_bytes == 1 then
		return get_zbyte(prop_address)
	elseif num_bytes == 2 then
		return get_zword(prop_address)
	else
		return 0
	end
end

function zobject_set_prop(index, property, value)
	local prop_address = zobject_prop_address(index, property)
	assert(prop_address != nil, 'ERR: property '..property..' does not exist for object '..index)

	local size_byte = get_zbyte(prop_address-0x.0001)
	local num_bytes = ((size_byte & 0xe0)>>5) + 1
	-- assert(num_bytes < 3, 'ERR: asked to get data for property '..property..' with invalid length '..num_bytes)
	if num_bytes == 1 then
		 set_zbyte(prop_address, value & 0xff)
	elseif num_bytes == 2 then
		 set_zword(prop_address, value & 0xffff)
	end
end

function get_zstring(zaddress)
	local end_found, zchars = false, {}
	-- log('fetching zstring starting at address: '..tostr(zaddress,true))
	while end_found == false do
		local zword = get_zword(zaddress)
		-- log('address: '..tostr(zaddress,true)..' -> '..tostr(zword,true))
		add(zchars, ((zword & 0x7c00)>>10))
		add(zchars, ((zword & 0x03e0)>>5))
		add(zchars, (zword & 0x001f))
		if (zaddress) zaddress += 0x.0002
		end_found = ((zword & 0x8000) == 0x8000)
		-- log(' zchars: '..zscii_to_p8scii(zchars))
		-- if (end_found == true) log('  > end found at zword: '..tohex(zword,true))
	end
	return zscii_to_p8scii(zchars), zaddress
end

--the u(pper) and l(ower) zchar sets are reversed for p8scii purposes
--feel free to set them to be the same, if you don't like mixed case
local u_zchars = 'abcdefghijklmnopqrstuvwxyz'
local l_zchars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local p_zchars = ' \n0123456789.,!?_#'.."'"..'"/\\-:()'
local zchar_tables = {l_zchars, u_zchars, p_zchars}

function zscii_to_p8scii(zchars)
	local zstring = ''
	local active_table = 1
	local ascii, ascii_decode = nil, false
	local abbr_code = nil
	for i = 1, #zchars do
		local zchar = zchars[i]
		-- log('converting zchar: '..zchar)
		if ascii_decode == true then
			if ascii == nil then
				ascii = zchar << 5
			else
				ascii |= zchar
				zstring ..= chr(ascii)
				ascii_decode = false
				ascii = nil
				active_table = 1
			end

		elseif abbr_code != nil then
			--32(abbr_code-1)+next_zchar
			local index = ((abbr_code-1)<<5)+zchar
			local abbr_address = abbr_address(index)
			abbr_code = nil
			zstring ..= get_zstring(abbr_address)

		elseif zchar == 0 then
			zstring ..= ' '

		elseif zchar < 4 then
			abbr_code = zchar

		elseif zchar == 4 then
			active_table += 1
			if (active_table > 3) active_table = 1

		elseif zchar == 5 then
			active_table -= 1
			if (active_table < 1) active_table = 3

		elseif zchar == 6 and active_table == 3 then
			ascii_decode = true

		elseif zchar > 31 then
			if (mid(97,zchar,122) == zchar) then
				zchar -= 32
			elseif (mid(65,zchar,90) == zchar) then
				zchar += 32
			end
			zstring ..= chr(zchar)

		else
			local lookup_string = zchar_tables[active_table]
			zstring ..= sub(lookup_string, zchar-5, zchar-5)
			active_table = 1
		end
	end
	-- log('became: |'..zstring..'|\n')
	return zstring
end

function load_instruction()
	
	-- An instruction consists of two parts: 
	-- the opcode and the operands.
	-- The first one to three bytes contain the opcode and 
	-- the types of the operands.
	-- Subsequent bytes contain the operands proper.
	
	local op_definition = get_zbyte()
	local op_form = (op_definition >> 6) & 0xffff

	local op_table, op_code, operands = nil, 0, {}
	if (op_form <= 0x01) then
		-- --log(' long instruction found')
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
		-- --log(' short instruction found')
		-- The first byte of a short instruction is %10ttxxxx.
		-- %tt is the type of the operand (or %11 if absent),
		-- %xxxx is the 1OP (0OP if operand absent) opcode
		op_table = _short_ops
		op_code = (op_definition & 0xf)
		local op_type = (op_definition & 0x30) >> 4
		if op_type == 0 then
			operands = get_zword()
		elseif op_type == 1 then
			operands = get_zbyte()
		elseif op_type == 2 then
			operands = get_var()
		elseif op_type == 3 then
			--log(' actually a zero op')
			op_table = _zero_ops
			operands = nil
		end
		operands = {operands}

	elseif (op_form == 0x03) then
		-- --log(' var instruction found')
		-- The first byte of a v3 variable instruction is %11axxxxx
		-- (two exceptions for v4+) where %xxxxx is the VAR opcode.
		-- If %a is %1 its a VAR opcode (if %0, a 2OP opcode)
		-- The second byte contains type info for the operands.
		-- It is divided into pairs of bits, 
		-- each indicating the operand type, beginning with top bits.
		-- Subsequent bytes contain the operands in that order.
		-- A %11 pair means ‘no operand’

		op_table = _var_ops
		if (op_definition & 0x20 == 0x00) op_table = _long_ops
		op_code = (op_definition & 0x1f)

		local type_information
		type_information = get_zbyte()
		for i = 0, 3 do
			local op_type = (type_information & (0xc0 >> (i*2))) >> (3-i)*2
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
			--log('  op type: '..op_type..', operand '..i..': '..tohex(operand))
			add(operands, operand)
		end
	end
	local func = op_table[op_code+1]
	return func, operands
end

function load_story_file()
	while stat(120) do
		local chunk = serial(0x800, 0x4300, 0x1000)
		for j = 0, chunk-1, 4 do
			local a, b, c, d = peek(0x4300+j, 4)
			local a <<= 8
			local c >>>= 8
			local d >>>= 16
			local dword = (a|b|c|d)
			add(_memory, dword)
			add(_memory_start_state, dword)
		end
	end
	initialize_game()
end