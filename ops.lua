--order/numbering follows zmach06e.pdf
--<result> means set_var(some value)
--<branch> means send true/false to branch()
--alias for set_var to _result, just for clarity in function definitions

_result = set_var

function _branch(should_branch)
	--log('branch called with should_branch: '..tostr(should_branch,true))
	local branch_arg = get_zbyte()
	--log('branch arg: '..tohex(branch_arg))
	local reverse_arg = (branch_arg & 0x80) == 0
	local big_branch = (branch_arg & 0x40) == 0
	local offset = (branch_arg & 0x3f)

	if (reverse_arg == true) should_branch = not should_branch

	if big_branch == true then
		--log('big_branch evaluated')
		if (offset > 31) offset -= 64
		offset <<= 8
		offset += get_zbyte()
	end

	--log('_program_counter at: '..tohex(_program_counter))
	--log('branch offset at: '..offset)
	if should_branch == true then
		--log('should_branch is true')
		if offset == 0 or offset == 1 then --same as rfalse/rtrue
			_ret(offset)
		else 
			offset >>= 16 --keep the sign!
			_program_counter += (offset - 0x.0002)
		end
	end
end

--8.2 Reading and writing memory

function _load(var)
	--log('load: '..var)
	_result(get_var(var, true))
end

function _store(var, a)
	--log('store: '..tohex(var)..','..tohex(a))
	set_var(a, var, true)
end

--n >>> 16 for addressing, then << 1 for "*2"
function _loadw(baddr, n)
	--log('_loadw: '..tohex(baddr)..', '..n)
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	local zword = get_zword(baddr)
	_result(zword)
end

function _storew(baddr, n, zword)
	--log('_storew: '..tohex(baddr)..','..n..','..tohex(zword))
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	set_zword(baddr, zword)
end

function _loadb(baddr, n)
	--log('_loadb: '..tohex(baddr)..', '..n)
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	local zbyte = get_zbyte(baddr)
	_result(zbyte)
end

function _storeb(baddr, n, zbyte)
	--log('_storeb: '..tohex(baddr)..','..n..','..zbyte)
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	set_zbyte(baddr, zbyte)
end

function _push(a)
	--log('_push: '..a)
	stack_push(a)
end

function _pull(var)
	--log('_pull: '..var)
	local a = stack_pop()
	set_var(a, var, true)
end

function _pop()
	--log('_pop: ')
	stack_pop()
end

function _scan_table(a, baddr, n, byte) --<result> <branch>
	--log('_scan_table: '..tohex(a)..','..tohex(baddr)..','..n..','..tohex(byte))
	local byte = byte or 0x82
	local getter = ((byte & 0x80) == 0x80) and get_zword or get_zbyte
	local entry_len = byte & 0x7f --strip the top bit
	local base_addr = zword_to_zaddress(baddr)

	local found_addr, should_branch = 0, false
	for i = 0, n-1 do
		local check_addr = base_addr + ((i * entry_len)>>>16)
		local value = getter(check_addr)
			--log('  check addr: '..tohex(check_addr)..', found: '..tohex(value)..', compare against: '..tohex(a))
		if value == a then
			--log('    FOUND!')
			found_addr = check_addr
			should_branch = true
			break
		end
	end
	_result(found_addr)
	_branch(should_branch)
end

function _copy_table(baddr1, baddr2, s)
	--log('copy_table: Not Implemented')
end

--8.3 Arithmetic

function _add(a, b)
	--log('_add: ('..a..' + '..b..')')
	_result(a + b)
end

function _sub(a, b)
	--log('_sub: ('..a..' - '..b..')')
	_result(a - b)
end

function _mul(a, b)
	--log('_mul: ('..a..' * '..b..')')
	_result(a * b)
end

function _div(s, t, ret)
	local op = ceil
	if ((s&0x8000) == (t&0x8000)) op = flr
	local v = op(s/t)
	--log('_div: ('..s..' / '..t..') = '..v)
	if (ret) return v
	_result(v)
end

function _mod(s, t)
	--p8 gives non-compliant results
	--ex: -13 % -5, p8: "2", zmachine: "-3"
	local r = (s - (_div(s, t, true) * t))
	--log('_mod: ('..a..' % '..b..') = '..r)
	_result(r)
end

function _inc(var, ret)
	local v = get_var(var, true) + 1
	_store(var, v)
	if (ret) return v
end

function _dec(var, ret)
	local v = get_var(var, true) - 1
	_store(var, v)
	if (ret) return v
end

function _inc_jg(var, s)
	--log('_inc_jg: '..tohex(var)..', '..tohex(s))
	local v = _inc(var, true)
	_jg(v, s)
end

function _dec_jl(var, s)
	--log('_dec_jl: ')
	local v = _dec(var, true)
	_jl(v, s)
end

function _or(a, b)
	--log('_or: '..a..' | '..b)
	_result(a | b)
end

function _and(a, b)
	--log('_and: '..a..' & '..b)
	_result(a & b)
end

function _not(a)
	--log('_not: '..a)
	_result(~a)
end

function _log_shift(a, t)
	--log('_log_shift: '..a..','..t)
	_result(a>>>t)
end

function _art_shift(s, t)
	--log('_art_shift: '..s..','..t)
	_result(s>>t)
end

--8.4 Comparisons and jumps

function _jz(a)
	--log('_jz: '..a)
	_branch(a == 0)
end

function _je(a, b1, b2, b3)
	--log('_je: '..tohex(a)..','..tohex(b1)..','..tohex(b2)..','..tohex(b3))
	local should_branch = ((a == b1) or (a == b2) or (a == b3))
	_branch(should_branch)
end

function _jl(s, t)
	--log('jl: '..s..' < '..t) 
	_branch(s < t)
end

function _jg(s, t)
	--log('jg: '..s..' > '..t)
	_branch(s > t)
end

function _jin(obj, n)
	local parent = zobject_family(obj, zparent)
	--log('jin: '..obj..' with parent '..parent..', '..n)
	local should_branch = ((parent == n) or (n==0 and parent == nil))
	_branch(should_branch)
end

function _test(a, b)
	--log('test:('..a..'&'..b..') == '..b..'?')
	_branch((a & b) == b)
end

function _jump(s)
	--log('jump: '..tohex(s))
	_program_counter += ((s - 2) >> 16) --keep the sign
end

--8.5 Call and return, throw and catch

function _call_fv(raddr, a1, a2, a3, a4, a5, a6, a7)
	--log('call_fv: '..tohex(raddr)..', '..tohex(a1)..', '..tohex(a2)..', '..tohex(a3)..', '..tohex(a4)..', '..tohex(a5)..', '..tohex(a6)..', '..tohex(a7))
	if raddr == 0x0 then
		set_var(0)
	else 
		--z3/4 formula is "r = r + 2 ∗ L + 1"
		--z5 formula is "r = r + 1"
		local r = zword_to_zaddress(raddr, true)
		--log('  unpacked raddr: '..tohex(r))
		local l = get_zbyte(r) --num local vars
		--log('  revealed l value: '..l)
		r += 0x.0001 -- "1"
		call_stack_push()

		local a_vars = {a1, a2, a3, a4, a5, a6, a7}
		-- if #a_vars > 0 then
		for i = 1, l do -- "L"
			local zword = 0
			if _zm_version < 5 then
				if i <= #a_vars then 
					zword = a_vars[i]
				else
					zword = get_zword(r)
				end
				r += 0x.0002 --"2"
			end
			set_zword(local_var_addr(i), zword)
		end
		--r should be pointing to the start of the routine
		_program_counter = r
	end
end

function _ret(a)
	--log('===> ret: '..tohex(a)..' <===')
	call_stack_pop(a)
end

function _rtrue()
	--log('rtrue: ')
	_ret(1)
end

function _rfalse()
	--log('rfalse: ')
	_ret(0)
end

function _ret_pulled()
	--log('_ret_pulled: ')
	_ret(stack_pop())
end

function _check_arg_count(n)
	log('_check_arg_count: Not Implemented')
end

function _catch()
	log('_catch: Not Implemented')
end

function _throw(a, fp)
	log('_throw: Not Implemented')
end

--8.6 Objects, attributes, and properties

function get_family_member(obj, fam)
	--log('get_family_member: '..obj..','..fam)
	local member = zobject_family(obj, fam)
	if (not member) member = 0
	_result(member)
	if (fam != zparent) _branch(member != 0)
end

function _get_sibling(obj) 
	get_family_member(obj, zsibling) 
end	

function _get_child(obj) 
	get_family_member(obj, zchild) 
end

function _get_parent(obj) 
	get_family_member(obj, zparent) 
end

function _remove_obj(obj)
	--log('remove_obj: '..zobject_name(obj)..'('..obj..')')
	--set parent to 0 and stitch up the sibling chain gap
	--children always move with their parent
	local original_parent = zobject_family(obj, zparent)
	if original_parent != 0 then

		local next_child = zobject_family(original_parent, zchild)
		local next_sibling = zobject_family(obj, zsibling)
		if next_child == obj then
			zobject_set_family(original_parent, zchild, next_sibling)
		else
			while next_child != 0 do
				if zobject_family(next_child, zsibling) == obj then
					zobject_set_family(next_child, zsibling, next_sibling)
					next_child = 0
				else
					next_child = zobject_family(next_child, zsibling)
				end
			end
		end
	end
	zobject_set_family(obj, zparent,  0)
	zobject_set_family(obj, zsibling, 0)
end

function _insert_obj(obj1, obj2)
	--log('insert_obj: '..zobject_name(obj1)..'('..obj1..')'..' into '..zobject_name(obj2)..'('..obj2..')')
	_remove_obj(obj1)
	local first_child = zobject_family(obj2, zchild)
	zobject_set_family(obj2, zchild, obj1)
	zobject_set_family(obj1, zparent, obj2)
	zobject_set_family(obj1, zsibling, first_child)
end	

function _test_attr(obj, attr)
	--log('test_attr: '..tohex(obj)..','..tohex(attr))
	_branch(zobject_has_attribute(obj, attr))
end

function _set_attr(obj, attr)
	--log('set_attr: '..tohex(obj)..','..tohex(attr))
	zobject_set_attribute(obj, attr, 1)
end

function _clear_attr(obj, attr)
	--log('clear_attr: '..tohex(obj)..','..tohex(attr))
	zobject_set_attribute(obj, attr, 0)
end

function _put_prop(obj, prop, a)
	--log('put_prop: '..obj..','..prop..','..tohex(a))
	zobject_set_prop(obj, prop, a)
end

function _get_prop(obj, prop)
	--log('get_prop: '..obj..','..prop)
	local p = zobject_get_prop(obj, prop)
	_result(p)
end
function _get_prop_addr(obj, prop)
	--log('get_prop_addr: '..obj..','..prop)
	_result(zobject_prop_data_addr_or_prop_list(obj, prop) << 16)
end

function _get_next_prop(obj, prop)
	--log('get_next_prop: '..obj)
	--If prop is 0, result is highest numbered prop
	--Else,  next lower numbered prop; else, 0
	local next_prop = 0
	local prop_list = zobject_prop_data_addr_or_prop_list(obj)
	if prop == 0 then 
		if (#prop_list > 0) next_prop = prop_list[1]
	else
		for i = 1, #prop_list do
			if (prop_list[i] == prop) and (i+1 <= #prop_list) then
				next_prop = prop_list[i+1]
			end
		end
	end
	--log('next prop: '..next_prop)
	_result(next_prop)
end

function _get_prop_len(baddr)
	--log('get_prop_len: '..tohex(baddr))
	local baddr = zword_to_zaddress(baddr)
	local len_byte = get_zbyte(baddr - 0x.0001)
	local len = extract_prop_len(len_byte)
	_result(len)
end


--8.7 Windows

function _split_screen(lines)
	--log('_split_screen called: '..lines)
	flush_line_buffer(0)
	local win0 = windows[0]
	local win1 = windows[1]
	local cur_y_offset = max(0, win0.h - win0.z_cursor.y)
	if lines == 0 then --unsplit
		win1.y = 1
		win1.h = 0
		win0.y = 1
		win0.h = _zm_screen_height
	else
		win1.y = 1
		win1.h = lines
		win0.y = lines + 1
		win0.h = max(0, _zm_screen_height - win1.h)
	end
	win0.z_cursor.y = win0.h - cur_y_offset
	if win0.z_cursor.y < 1 then
		win0.z_cursor = {x=1,y=1}
	end
	update_screen_rect(1)
	update_screen_rect(0)
	if (lines > 0 and _zm_version == 3) _erase_window(1)
end

function _set_window(win)
	--log('set_window: '..win)
	flush_line_buffer()
	active_window = win
	if (win == 1) _set_cursor(1,1)
end

--"It is an error in V4-5 to use this instruction when window 0 is selected"
--autosplitting on z4 Nord & Bert reveals a status line bug (!)
function _set_cursor(lin, col)
	--log('set_zcursor to line '..lin..', col '..col)
	flush_line_buffer()
	if ((_zm_version == 5) and (lin > windows[1].h)) _split_screen(lin)
	windows[1].z_cursor = {x=col, y=lin}
	update_p_cursor()
end

function _get_cursor(baddr)
	--log('get_cursor called')
	baddr = zword_to_zaddress(baddr)
	local zc = windows[active_window].z_cursor
	set_zword(baddr, zc.y)
	set_zword(baddr + 0x.0002, zc.x)
end

--ignore; we have to buffer regardless
function _buffer_mode(bit)
	log('_buffer_mode: Not Implemented')
end

function _set_color(byte0, byte1)
	log('_set_color: Not Implemented')
end

function _set_text_style(n)
	log('set_text_style: '..n)
	update_text_style(n)
end

function _set_font(n)
	log('_set_font: Not Implemented')
	_result(0)
end

--8.8 Input and output streams

function _output_stream(n, baddr)
	--log('output_stream: '..n..', '..tohex(baddr))
	if abs(n) == 1 then
		screen_output = (n > 0)

	elseif abs(n) == 2 then
		local p_flag = get_zbyte(_peripherals_header_addr)
		if (n > 0) p_flag |= 0x01 --turn on transcription
		if (n < 0) p_flag &= 0xfe --turn off transcription
		set_zbyte(_peripherals_header_addr, p_flag)

	else
		if n > 0 then
			set_zword(zword_to_zaddress(baddr), 0x00)
			add(memory_output, baddr)
		else
			deli(memory_output)
		end
	end
end

function _input_stream(operands)
	--log('input_stream: NI')
end

--8.9 Input

function _read(baddr1, baddr2, time, raddr)
	--timer not yet implemented
	if (not _interrupt) then
		--log('s/read: '..tohex(baddr1)..','..tohex(baddr2)..', time: '..tohex(time)..', '..tohex(raddr))
		flush_line_buffer()
		--cache addresses for capture_input()
		z_text_buffer = zword_to_zaddress(baddr1)
		z_parse_buffer = zword_to_zaddress(baddr2)
		_show_status()
		_interrupt = capture_input

	else
		z_text_buffer, z_parse_buffer = 0x0, 0x0
		_interrupt = nil
	end
end

function _read_char(one, time, raddr)
	--timer not yet implemented
	--log('read_char: '..one..','..tohex(time)..','..tohex(raddr))
	flush_line_buffer()
	local char = wait_for_any_key()
	set_var(ord(char))
end


--8.10 Character based output

function _print_char(n)
	--log('print_char '..n..': '..chr(n))
	if (n == 10) n = 13	
	output(chr(n))
end

function _new_line()
	--log('new_line')
	_print_char(10)
end

function _print(string)
	local zstring = get_zstring(string)
	--log('_print: '..zstring)
	output(zstring)
end

function _print_rtrue(string)
	--log('_print_rtrue')
	_print(string)
	_new_line()
	_rtrue()
end

function _print_addr(baddr, is_packed)
	local is_packed = is_packed or false
	local zaddress = zword_to_zaddress(baddr, is_packed)
	local zstring = get_zstring(zaddress)
	--log('print_addr: '..zstring)
	output(zstring)
end

function _print_paddr(saddr)
	_print_addr(saddr, true)
end

function _print_num(s)
	--log('print_num: '..s)
	output(tostr(s))
end

function _print_obj(obj)
	local name, zchars = zobject_name(obj)
	--log('print_obj with name: '..name)
	output(name)
end

function _print_table(baddr, x, y, n)
	log('_print_table: Not Implemented')
end

--8.11 Miscellaneous screen output

function _erase_line(val)
	--log('erase_line: '..val)
	if (val == 1) screen("\^i\#"..current_fg..'\f'..current_bg..blank_line)
end

function _erase_window(win)
	--log('erase_window: '..win)
	if win >= 0 then
		local a,b,c,d = unpack(windows[win].screen_rect)
		rectfill(a,b,c,d,current_bg)

	else
		cls(current_bg)
		_split_screen(0)
	end

	if win <= 0 then
		windows[0].buffer = {}
		lines_shown = 0
	end
end

--8.12 Sound, mouse, and menus

function _sound_effect(number)
	--log('sound_effect: '..number)
	if mid(1,number,2) == number then
		local tone = (number == 1) and "7" or "1"
		print("\ac"..tone)
	end
end

--8.13 Save, restore, and undo

function _save(did_save)
	--log('_save: ')
	if _interrupt == nil then
		_interrupt = save_game
	else
		_interrupt = nil
		if _zm_version == 3 then
			_branch(did_save)
		else 
			set_var(did_save)
		end
	end
end

function _restore()
	--log('restore: ')
	local rg = restore_game()
	if _zm_version == 3 then
		_branch(rg)
	else
		set_var(rg)
	end
end

function _save_undo()
	--log('_save_undo: Not Implemented')
end

function _restore_undo()
	--log('_restore_undo: Not Implemented')
end

--8.14 Miscellaneous

function _nop()
	--log('_nop: ')
end

function _random(s)
	--log('_random: '..tostr(s))

	if s > 0 then
		set_var(flr(rnd(s)) + 1)

	else
		srand(s)
		if (s == 0) srand(stat(93)..stat(94)..stat(95))
		set_var(0)
	end
end

function _restart()
	-- log('restart: ')
	reset_session()
end

function _quit()
	story_loaded = false
end

function _show_status()
	if (_zm_version == 3) show_status()
end

function _verify()
	-- log('_verify: cheating on this')
	_branch(true)
end

function _piracy()
	--log('_piracy: cheating on this')
	_branch(true)
end

function _tokenise(baddr1, baddr2, baddr3, bit)
	--log('_tokenise: Not Implemented')
end

function _encode_text(baddr1, n, p, baddr2)
	--log('_encode_text: Not Implemented')
end

_long_ops = {
	nil, _je, _jl, _jg, _dec_jl, _inc_jg, _jin, _test, _or, _and, _test_attr, _set_attr, _clear_attr, _store, _insert_obj, _loadw, _loadb, _get_prop, _get_prop_addr, _get_next_prop, _add, _sub, _mul, _div, _mod, _call_fv
}

_short_ops = {
	_jz, _get_sibling, _get_child, _get_parent, _get_prop_len, _inc, _dec, _print_addr, _call_fv, _remove_obj, _print_obj, _ret, _jump, _print_paddr, _load, _not
}

_zero_ops = {
	_rtrue, _rfalse, _print, _print_rtrue, _nop, _save, _restore, _restart, _ret_pulled, _pop, _quit, _new_line, _show_status, _verify
}

_var_ops = {
	_call_fv, _storew, _storeb, _put_prop, _read, 
	_print_char, _print_num, _random, _push, _pull, 
	_split_screen, _set_window, _call_fv, _erase_window, _erase_line, 
	_set_cursor, _get_cursor, _set_text_style, _buffer_mode, _output_stream, _input_stream, _sound_effect, _read_char, _scan_table
}