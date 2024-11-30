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
	local a = get_var(var,true)
	set_var(a)
end

function _store(var, a)
	--log('store: '..tohex(var)..','..tohex(a))
	set_var(a, var, true)
end

function _loadw(baddr, n)
	--log('loadw: '..tohex(baddr)..', '..n)
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	--log('  baddr now: '..tohex(baddr))
	local zword = get_zword(baddr)
	--log('  got zword: '..tohex(zword))
	set_var(zword)
end

function _storew(baddr, n, zword)
	--log('storew: '..tohex(baddr)..','..n..','..tohex(zword))
	--Store zword in the word at baddr + 2∗n
	-->>>16 for addressing, then << 1 for "*2"
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	set_zword(baddr, zword)
end

function _loadb(baddr, n)
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	local zbyte = get_zbyte(baddr)
	--log('loadb fetched '..tohex(zbyte)..' from address '..tohex(baddr))
	set_var(zbyte)
end

function _storeb(baddr, n, zbyte)
	--log('storeb: '..tohex(baddr)..','..n..','..zbyte)
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	set_zbyte(baddr, zbyte)
end

function _push(a)
	--log('push: '..a)
	stack_push(a)
end

function _pull(var)
	--log('pull: '..var)
	local a = stack_pop()
	set_var(a, var, true)
end

function _pop_catch()
	if (_zm_version < 5) then
		--log('v3/4 pop: ')
		stack_pop()
	else
		--log("v5 catch")
	end
end

function _scan_table(a, baddr, n, byte) --<result> <branch>
	--log('scan_table: '..tohex(a)..','..tohex(baddr)..','..n..','..tohex(byte))
	local byte = byte or 0x82
	local getter = ((byte & 0x80) == 0x80) and get_zword or get_zbyte
	local entry_len = byte & 0x7f --strip the top bit
	local base_addr = zword_to_zaddress(baddr)

	local found_addr, should_branch = 0, false
	for i = 0, n-1 do
		local check_addr = base_addr + ((i * entry_len)>>>16)
		local value = getter(check_addr)
			--log('  check addr: '..tohex(check_addr)..', found: '..tohex(value)..', compare against: '..tohex(a))
		if (value == a) then
			--log('    FOUND!')
			found_addr = check_addr
			should_branch = true
			break
		end
	end

	set_var(found_addr)
	_branch(should_branch)
end

function _copy_table(baddr1, baddr2, s)
	--log("_copy_table not yet implemented")
end



--8.3 Arithmetic

function _add(a, b)
	--log('add: ('..a..' + '..b..')')
	set_var(a + b)
end

function _sub(a, b)
	--log('sub: ('..a..' - '..b..')')
	set_var(a - b)
end

function _mul(a, b)
	--log('mul: ('..a..' * '..b..')')
	set_var(a * b)
end

function _div(a, b)
	local d = a/b
	if ((a&0x8000) == (b&0x8000)) then
	-- if ((a > 0 and b > 0) or (a < 0 and b < 0)) then
		d = flr(d)
	else
		d = ceil(d)
	end
	--log('div: ('..a..' / '..b..') = '..d)
	set_var(d)
end

function _mod(a, b)
	--log('mod: ('..a..' % '..b..')')
	--p8 mod gives non-compliant results
	--ex: -13 % -5, p8: "2", zmachine: "-3"
	local m
	if ((a > 0 and b > 0) or (a < 0 and b < 0)) then
		m = a - (flr(a/b) * b)
	else
		m = a - (ceil(a/b) * b)
	end
	set_var(m)
end

function _inc(var)
	return inc_dec(var,1)
end

function _dec(var)
	return inc_dec(var,-1)
end

function _inc_dec(var, amt)
	local zword = get_var(var)
	--log('inc_dec: '..tohex(var)..'; current value: '..zword..' by '..amt)
	zword += amt --amt may be 1 or -1
	set_var(zword, var)
	return zword
end

function _inc_jg(var, s)
	--log('inc_jg: '..tohex(var)..', '..tohex(s))
	local val = _inc(var)
	_jg(val, s)
end

function _dec_jl(var, s)
	--log('inc_jg: '..tohex(var)..', '..tohex(s))
	local val = _dec(var)
	_jl(val, s)
end

function _or(a, b)
	--log('_or: '..a..' | '..b)
	set_var(a | b)
end

function _and(a, b)
	--log('_and: '..a..' & '..b)
	set_var(a & b)
end

function _not(a)
	--log('_not: '..a)
	set_var(~a)
end

function _log_shift(a, t)
	--The result is floor(a ∗ 2^t) modulo $10000
	if t > 0 then
		a <<= t
	else
		a >>>= t
	end
	set_var(a)
end

function _art_shift(s, t)
	if t > 0 then
		s <<= t
	else
		s >>= t
	end
	set_var(s)
end



--8.4 Comparisons and jumps

function _jz(a)
	--log('jz: '..a)
	_branch(a == 0)
end

function _je(a, b1, b2, b3)
	--log('je: '..tohex(a)..','..tohex(b1)..','..tohex(b2)..','..tohex(b3))
	local b_vars = {b1, b2, b3}
	local should_branch = false
	for i = 1, #b_vars do
		if (a == b_vars[i]) should_branch = true
	end
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

function _call_f(raddr, a1, a2, a3, a4, a5, a6, a7)
	_call_fp(raddr, type, a1, a2, a3, a4, a5, a6, a7)
end

function _call_fp(raddr, type, a1, a2, a3, a4, a5, a6, a7)
	if (raddr == 0x0) then
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
				if (i <= #a_vars) then 
					zword = a_vars[i]
				else
					zword = get_zword(r)
				end
				r += 0x.0002 --"2"
			end
			set_zword(local_var_addr(i), zword)
		end
			--r should be pointing to the start of the routine
		-- end
		_program_counter = r
	end
end


function _dec_chk(var, s)
	--log('dec_chk: ')
	local val = dec(var)
	_jl(val, s)
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



function _insert_obj(obj1, obj2)
	--log('insert_obj: '..zobject_name(obj1)..'('..obj1..')'..' into '..zobject_name(obj2)..'('..obj2..')')
	_remove_obj(obj1)
	local first_child = zobject_family(obj2, zchild)
	zobject_set_family(obj2, zchild, obj1)
	zobject_set_family(obj1, zparent, obj2)
	zobject_set_family(obj1, zsibling, first_child)
end	



function _get_prop(obj, prop)
	--log('get_prop: '..obj..','..prop)
	local p = zobject_get_prop(obj, prop)
	set_var(p)
end

function _get_prop_addr(obj, prop)
	--log('get_prop_addr: '..obj..','..prop)
	set_var(zobject_prop_data_addr_or_prop_list(obj, prop) << 16)
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
			if (prop_list[i] == prop and i+1 <= #prop_list) then
				next_prop = prop_list[i+1]
			end
		end
	end
	--log('next prop: '..next_prop)
	set_var(next_prop)
end









function _get_family_member(obj, fam)
	--log('get_family_member: '..obj..','..fam)
	local member = zobject_family(obj, fam)
	if (not member) member = 0
	_result(member)
	if (fam != zparent) _branch(member != 0)
end

function _get_sibling(obj) 
	_get_family_member(obj, zsibling) 
end	

function _get_child(obj) 
	_get_family_member(obj, zchild) 
end

function _get_parent(obj) 
	_get_family_member(obj, zparent) 
end

function _get_prop_len(baddr)
	--log('get_prop_len: '..tohex(baddr))
	local baddr = zword_to_zaddress(baddr)
	local len_byte = get_zbyte(baddr - 0x.0001)
	local len = extract_prop_len(len_byte)
	set_var(len)
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

function _ret(a)
	--log('===> ret: '..tohex(a)..' <===')
	call_stack_pop(a)
end







function _rtrue()
	--log('rtrue: ')
	ret(1)
end

function _rfalse()
	--log('rfalse: ')
	ret(0)
end

function _show_status()
	if (_zm_version == 3) show_status()
end

function _ret_pulled()
	--log('_ret_pulled: ')
	_ret(stack_pop())
end



function _put_prop(obj, prop, a)
	--log('put_prop: '..obj..','..prop..','..tohex(a))
	zobject_set_prop(obj, prop, a)
end





function _split_window(lines)
	--log('split_window called: '..lines)
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
	if (lines > 0 and _zm_version == 3) erase_window(1)
end

function _set_window(win)
	--log('set_window: '..win)
	flush_line_buffer()
	active_window = win
	if (win == 1) _set_zcursor(1,1)
end

--"It is an error in V4-5 to use this instruction when window 0 is selected"
--autosplitting on z4 Nord & Bert reveals a status line bug in the game (!)
function _set_zcursor(lin, col)
	--log('_set_zcursor to line '..lin..', col '..col)
	flush_line_buffer()
	if ((_zm_version == 5) and (lin > windows[1].h)) _split_window(lin)
	windows[1].z_cursor = {x=col, y=lin}
	update_p_cursor()
end

function _get_cursor(baddr)
	--log('_get_cursor called')
	baddr = zword_to_zaddress(baddr)
	local zc = windows[active_window].z_cursor
	set_zword(baddr, zc.y)
	set_zword(baddr + 0x.0002, zc.x)
end

function _set_text_style(n)
	--log('set_text_style: '..n)
	update_current_format(n)
end

function _buffer_mode(bit)
	--ignore; we have to buffer regardless
end

function _output_stream(n, baddr)
	--log('output_stream: '..n..', '..tohex(baddr))
	if (n == 1) screen_output = true
	if (n == -1) screen_output = false
	if (n == 3) set_zword(zword_to_zaddress(baddr),0x00) add(memory_output,baddr)
	if (n == -3) deli(memory_output)
	if n == 2 then
		local p_flag = get_zbyte(peripherals)
		p_flag |= 0x01 --turn on transcription
		set_zbyte(peripherals, p_flag)
	end
	if n == -2 then
		local p_flag = get_zbyte(peripherals)
		p_flag &= 0xfe --turn off transcription
		set_zbyte(peripherals, p_flag)
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
	if (number == 1) print("\ac3")
	if (number == 2) print("\ac1")
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

function _random(s, skip_set_var)
	if (s < 0) then
		srand(s) 
		if (not skip_set_var) set_var(0)
	elseif (s > 0) then
		local rnd = flr(rnd(s)) + 1
		if (not skip_set_var) set_var(rnd)
	else
		srand(tonum(tostr(stat(93))..tostr(stat(94))..tostr(stat(95))))
		if (not skip_set_var) set_var(0)
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
	_branch(true)
end

function _tokenise(baddr1, baddr2, baddr3, bit)
	--log('_tokenise: Not Implemented')
end

function _encode_text(baddr1, n, p, baddr2)
	--log('_encode_text: Not Implemented')
end

-- Overloads; functions to route calls based on zm version
function _not_call_p(raddr, a1, a2, a3, a4, a5, a6, a7)
	if _zm_version < 5 then
		_not(raddr)
	else
		_call_p(raddr, a1, a2, a3, a4, a5, a6, a7)
	end
end

_zero_ops = {
	_rtrue, _rfalse, _print, _print_rtrue, _nop, _save, _restore, _restart, _ret_pulled, _pop_catch, _quit, _new_line, _show_status, _verify, _piracy
}

_short_ops = {
	_jz, _get_sibling, _get_child, _get_parent, _get_prop_len, _inc, _dec, _print_addr, _call_f, _remove_obj, _print_obj, _ret, _jump, _print_paddr, _load, _not_call_p
}

_long_ops = {
	nil, _je, _jl, _jg, _dec_jl, _inc_jg, _jin, _test, _or, _and, _test_attr, _set_attr, _clear_attr, _store, _insert_obj, _loadw, _loadb, _get_prop, _get_prop_addr, _get_next_prop, _add, _sub, _mul, _div, _mod, _call_f, _call_p, _set_color, _throw
}

_var_ops = {
	_call_f, _storew, _storeb, _put_prop, _read, 
	_print_char, _print_num, _random, _push, _pull, 
	_split_screen, _set_window, _call_f, _erase_window, _erase_line, 
	_set_cursor, _get_cursor, _set_text_style, _buffer_mode, _output_stream, _input_stream, _sound_effect, _read_char, _scan_table, _not, _call_p, _call_p, _tokenise, _encode_text, _copy_table, _print_table, _check_arg_count
}

_ext_ops = {
	_save_v5, _restore_v5, _log_shift, _art_shift, _set_font, nil, nil, nil, nil, _save_undo, _restore_undo
}