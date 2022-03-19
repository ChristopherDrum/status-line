_function dump_call_stack()
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
	log('z-code version: '..get_zbyte(version))
	local int_flags = get_zbyte(interpreter_flags)
	local flag = (int_flags & 2 == 2) and 'time' or 'score/moves'
	log('int flags: display '..flag)
	log('release number: '..get_zword(release_number_addr))
	log('start paged mem: '..tohex(_paged_memory_addr))
	log('dict add: '..tohex(_dictionary_addr))
	log('obj add: '..tohex(_object_table_addr))
	log('global add: '..tohex(_global_var_table_addr))
	log('size of dyn mem: '..tohex(_static_mem_addr))

	local serial_num = ""
	for i = 0, 5 do
		local byte = get_zbyte(serial_code + (0x.0001 * i))
		serial_num ..= chr(byte)
	end
	log('serial number: '..serial_num)
	log('abbr addr: '..tohex(_abbr_table_addr))
	local file_size = zword_to_zaddress(get_zword(file_length),true)
	log('file size: '..tohex(file_size))
	log('checksum: '..tohex(get_zword(file_checksum)))
	log('screen size: '..get_zbyte(screen_width)..'x'..get_zbyte(screen_height))
	log('program_counter start: '..tohex(_program_counter))
	log('\n')
end

function infodump_dictionary()
	log('     ***  Dictionary  ***')
	local addr = _dictionary_addr
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
	local s = from and from or 1
	local e = to and to or from or 255
	if (e < s) s, e = e, s
	s = max(1, s)
	e = min(255, e)
	log('dumping objects '..s..' to '..e)
	for obj = s, e do
		local za = zobject_attributes(obj)

		local active_attributes = ''
		for i = 0, 31 do
			if ((za & (0x8000.0000>>>i)) != 0) active_attributes ..= i..' '
		end
		log('attributes: '..active_attributes)
		log('parent: '..zobject_family(obj, zparent)..'  sibling: '..zobject_family(obj, zsibling)..'  child: '..zobject_family(obj,zchild))
		log('property address: '..tohex(zobject_prop_table_address(obj)))
		log('  description: '..zobject_name(obj))
		-- log('    properties: ')
		-- for i = 1, #zobject.properties do
		-- 	local prop = zobject.properties[i]
		-- 	local prop_string = '['..prop[1]..'] '
		-- 	for j = 2, #prop do
		-- 		prop_string ..= sub(tohex(prop[j]),5,6)..' '
		-- 	end
		-- 	log('      '..prop_string)
		-- end
		log('\n')
	end
end

function test_system_memory_correctness()

	--fill up the _stack for push/pop correctness check
	for i = 1, 9 do
		set_zword(_stack_var_addr, i)
	end

	--repeatedly calling get_zbyte or get_zword at _stack_var_addr
	-- should pop off values from the stack; we get a new value each call
	dump_stack()
	log(get_zbyte(_stack_var_addr))
	log(get_zbyte(_stack_var_addr))
	log(get_zbyte(_stack_var_addr))
	log(get_zbyte(_stack_var_addr))
	set_zbyte(_stack_var_addr, 99)
	log(get_zbyte(_stack_var_addr))
	log(get_zbyte(_stack_var_addr))
	log(get_zbyte(_stack_var_addr))

	dump_call_stack()
	dump_stack()

	call_stack_push()
	set_zword(local_var_address(5), 0x5555)
	set_zword(local_var_address(13), 0xcccc)
	set_zword(_stack_var_addr, 0xaaaa)
	set_zword(_stack_var_addr, 0xbbbb)
	_program_counter += 0x.0005
	call_stack_push()
	dump_call_stack()
	dump_stack()
	call_stack_pop()
	dump_call_stack()
	dump_stack()
	log('pc: '..tohex(_program_counter)..', sp: '.._stack_pointer)
	get_zword(_stack_var_addr) --should error
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