function dump_call_stack()
	log('current call stack, frame depth: '..(#_call_stack/10))
	for i = 1, (#_call_stack/10) do
		dump_frame(i)
	end
end

function dump_frame(index)
	log('  ...frame dump '..index)
	local frame_start = ((index - 1) * 10) + 1
	log('     pc: '..tohex(_call_stack[frame_start])..', sp: '.._call_stack[frame_start+1])

	local lvars = ''
	for i = 2, 9 do
		lvars ..= tohex(_call_stack[frame_start + i])..' - '
	end
	log('     lvars: '..lvars..'\n')
end

function dump_stack()
	local st = ''
	if #_stack > 0 then
		for i = #_stack, 1, -1 do
			st ..= tohex(_stack[i], false)..' - '
		end
	else
		st = 'empty'
	end
	log('stack (top -> bottom): '..st..'\n')
end

function dump_globals()
	for i = 0, 15 do
		local gvars = ''
		for j = 0, 15 do
			gvars ..= sub(tohex(get_zword(global_var_address((i*16)+j))),3,6)..' - '
		end
		log(gvars)
	end
end

function infodump_header()
	log('     ***  Header  ***')
	log('z-code version: '..get_zbyte(_version_header_addr))
	local int_flags = get_zbyte(_interpreter_flags_header_addr)
	local flag = (int_flags & 2 == 2) and 'time' or 'score/moves'
	log('int flags: display '..flag)
	log('release number: '..get_zword(_release_number_header_addr))
	log('start paged mem: '..tohex(_paged_memory_mem_addr))
	log('dict add: '..tohex(_dictionary_mem_addr))
	log('obj add: '..tohex(_object_table_mem_addr))
	log('global add: '..tohex(_global_var_table_mem_addr))
	log('size of dyn mem: '..tohex(_static_memory_mem_addr))

	local serial_num = ""
	for i = 0, 5 do
		local byte = get_zbyte(_serial_code_header_addr + (0x.0001 * i))
		serial_num ..= chr(byte)
	end
	log('serial number: '..serial_num)
	log('abbr addr: '..tohex(_abbr_table_mem_addr))
	local file_size = zword_to_zaddress(get_zword(_file_length_header_addr),true)
	log('file size: '..tohex(file_size))
	log('checksum: '..tohex(get_zword(_file_checksum_header_addr)))
	log('screen size: '..get_zbyte(_screen_width_header_addr)..'x'..get_zbyte(_screen_height_header_addr))
	log('program_counter start: '..tohex(_program_counter))
	log('\n')
end

function infodump_dictionary()
	log('     ***  Dictionary  ***')
	local addr = _dictionary_mem_addr
	local num_separators = get_zbyte(addr)
	addr += 0x.0001
	log('num separators: '..num_separators)
	--documenation said these are zscii codes, but they are ASCII!! :/
	local separators = get_zbytes(addr, num_separators)
	addr += 0x.0001 * num_separators
	local seps = zscii_to_p8scii(separators)
	log('word separators: '..seps)
	local word_size = get_zbyte(addr)
	addr += 0x.0001
	local word_count = get_zword(addr)
	log('word count: '..word_count..'   word size: '..word_size)
	addr += 0x.0002
	-- log('start decoding at byte: '..tostr(unpack(get_zbytes(addr, 1)),true))
	local words = ''
	for i = 1, word_count do
		words ..= '['..sub('   '..tostr(i),-4)..'] '..sub(get_zstring(addr)..'       ',1,8)
		if (i % 4 == 0) words ..= '\n'
		addr += 0x.0007
	end
	log(words)
end

function infodump_abbreviations()
	log('     ***  Abbreviations  ***')
	for i = 0, 95 do
		-- log('(loop '..i..')')
		local abbr_address = abbr_address(i)
		-- log('  abbr_address at: '..tostr(abbr_address,true))
		local abbr = get_zstring(abbr_address)
		log('['..i..'] \"'..abbr..'\"')
	end
	log('\n\n')
end

function infodump_object_tree(from, to)
	local object_count = _zm_version == 3 and 255 or 286
	local attr_count = _zm_version == 3 and 31 or 47
	local s = from or 1
	local e = to or object_count
	if (e < s) s, e = e, s
	log('dumping objects '..s..' to '..e)
	for obj = s, e do

		local active_attributes = ''
		for i = 0, attr_count do
			local check = zobject_has_attribute(obj, i)
			if (check == true) active_attributes ..= tostr(i)..', '
		end
		log(obj..'. Attributes: '..active_attributes)

		log('Parent: '..zobject_family(obj, zparent)..'  Sibling: '..zobject_family(obj, zsibling)..'  Child: '..zobject_family(obj,zchild))
		log('property address: '..tohex(zobject_prop_table_address(obj)))
		log('  description: '..zobject_name(obj))
		log('    properties: ')
		local prop_list = zobject_prop_data_addr_or_prop_list(obj)
		for i = 1, #prop_list do
			local p = prop_list[i]
			local prop_string = '['..p..'] '
			local prop_addr, prop_len = zobject_prop_data_addr_or_prop_list(obj, p)
			-- local prop_len = extract_prop_len(prop_addr)
			-- log('(prop_len '..prop_len..')')
			local prop_bytes = get_zbytes(prop_addr, prop_len)
			for j = 1, #prop_bytes do
				local byte = prop_bytes[j]
				prop_string ..= sub(tohex(byte),5,6)..' '
			end
			log('      '..prop_string)
		end
		log('\n')
	end
end

function test_system_memory_correctness()

	--fill up the _stack for push/pop correctness check
	for i = 1, 9 do
		set_zword(_stack_mem_addr, i)
	end

	--repeatedly calling get_zbyte or get_zword at _stack_mem_addr
	-- should pop off values from the stack; we get a new value each call
	dump_stack()
	log(get_zbyte(_stack_mem_addr))
	log(get_zbyte(_stack_mem_addr))
	log(get_zbyte(_stack_mem_addr))
	log(get_zbyte(_stack_mem_addr))
	set_zbyte(_stack_mem_addr, 99)
	log(get_zbyte(_stack_mem_addr))
	log(get_zbyte(_stack_mem_addr))
	log(get_zbyte(_stack_mem_addr))

	dump_call_stack()
	dump_stack()

	call_stack_push()
	set_zword(local_var_address(5), 0x5555)
	set_zword(local_var_address(13), 0xcccc)
	set_zword(_stack_mem_addr, 0xaaaa)
	set_zword(_stack_mem_addr, 0xbbbb)
	_program_counter += 0x.0005
	call_stack_push()
	dump_call_stack()
	dump_stack()
	call_stack_pop()
	dump_call_stack()
	dump_stack()
	log('pc: '..tohex(_program_counter)..', sp: '.._stack_pointer)
	get_zword(_stack_mem_addr) --should error
end

-- function test_split_screen()
-- 	split_window(6)
-- 	set_window(1)
-- 	set_text_style(1)
-- 	set_zcursor(3,20)
-- 	output('hello')
-- 	set_zcursor(7,3)
-- 	output('world')
-- 	set_text_style(0)
-- 	output('CURSORSPACING?')
-- 	set_text_style(1)
-- 	set_zcursor(11,1)
-- 	output('**********************')
-- 	set_zcursor(12,1)
-- 	output('**********************')
-- 	set_zcursor(13,1)
-- 	output('**********************')
-- 	set_zcursor(12,5)
-- 	erase_line(1)
-- 	set_text_style(0)
-- 	set_zcursor(3,22)
-- 	output('!')
-- 	set_window(0)
-- end