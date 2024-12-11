--follows zmach06e.pdf
--<result> == _result(some value)
--<branch> == _branch(true/false)
--<return> == _ret(value)
--alias for for clarity in result handling
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
			_program_counter += (offset - (2>>>16))
		end
	end
end

--8.2 Reading and writing memory

function _load(var)
	_result(get_var(var,true))
end

function _store(var, a)
	_result(a, var, true)
end

function addr_offset(baddr, n, amt)
	-- log("addr_offset: "..tohex(baddr)..", "..tohex(n)..", "..amt)
	local addr = zword_to_zaddress(baddr)
	local offset = (abs(n)>>>amt)
	if (n < 0) offset = -offset
	local temp = addr + offset
	--"Dynamic memory can be read or written to
	--...using loadb, loadw, storeb and storew"
	--so if we exceed those boundaries, reverse the offset
	if (temp < 0 or temp > 0x.ffff) temp = addr - offset
	return temp
end

function _loadw(baddr, n)
	baddr = addr_offset(baddr, n, 15)
	_result(get_zword(baddr))
end

function _storew(baddr, n, zword)
	baddr = addr_offset(baddr, n, 15)
	set_zword(baddr, zword)
end

function _loadb(baddr, n)
	baddr = addr_offset(baddr, n, 16)
	_result(get_zbyte(baddr))
end

function _storeb(baddr, n, zbyte)
	baddr = addr_offset(baddr, n, 16)
	set_zbyte(baddr, zbyte)
end

-- _push(a) and _pop() are _stack_push and _stack_pop in memory.lua

function _pull(var)
	local a = stack_pop()
	_result(a, var, true)
end


function _scan_table(a, baddr, n, byte) --<result> <branch>
	-- log('scan_table: '..tohex(a)..','..tohex(baddr)..','..n..','..tohex(byte))
	local base_addr = zword_to_zaddress(baddr)
	local byte = byte or 0x82
	local getter = ((byte & 0x80) == 0x80) and get_zword or get_zbyte
	local entry_len = (byte & 0x7f)>>16 --strip the top bit

	local should_branch = false
	for i = 1, n do
		if getter(base_addr) == a then
			should_branch = true
			break
		end
		base_addr += entry_len
	end
	
	if (should_branch == false) base_addr = 0
	_result(base_addr<<16) --reconvert shifted zaddress to zword
	_branch(should_branch)
end

function _copy_table(baddr1, baddr2, s)
	-- log('_copy_table from: '..tohex(baddr1)..' to: '..tohex(baddr2)..','..s..' bytes')
	local from = zword_to_zaddress(baddr1)
	if baddr2 == 0 then
		for i = 0, s-1 do
			set_zbyte(from+(i>>>16), 0)
		end
	else
		local to = zword_to_zaddress(baddr2)
		local st, en, step = s-1, 0, -1
		if (s < 0) or (from > to) then
			s = abs(s)
			st, en, step = 0, s-1, 1
		end
		for i = st, en, step do
			local offset = i>>>16
			local byte = get_zbyte(from+offset)
			set_zbyte(to+offset, byte)
		end
	end
end



--8.3 Arithmetic

function _add(a, b)
	_result(a + b)
end

function _sub(a, b)
	_result(a - b)
end

function _mul(a, b)
	_result(a * b)
end

function _div(a, b, help)
	local op = ceil
	if ((a&0x8000) == (b&0x8000)) op = flr
	-- if ((a > 0 and b > 0) or (a < 0 and b < 0)) then
	local d = op(a/b)
	if (help) return d else _result(d)
end

function _mod(a, b)
	--p8 mod gives non-compliant results: -13 % -5, p8: "2", zm: "-3"
	_result(a - (_div(a,b,true) * b))
end

function _inc(var)
	return _inc_dec(var,1)
end

function _dec(var)
	return _inc_dec(var,-1)
end

function _inc_dec(var, amt)
	local zword = get_var(var) + amt
	_result(zword, var)
	return zword
end

function _inc_jg(var, s)
	local val = _inc(var)
	_jg(val, s)
end

function _dec_jl(var, s)
	local val = _dec(var)
	_jl(val, s)
end

function _or(a, b)
	_result(a | b)
end

function _and(a, b)
	_result(a & b)
end

function _not(a)
	_result(~a)
end

function _log_shift(a, t)
	_result(flr(a<<t))
end

function _art_shift(s, t)
	_result(s>>-t)
end



--8.4 Comparisons and jumps

function _jz(a)
	_branch(a == 0)
end

function _je(a, b1, b2, b3)
	_branch(del({b1,b2,b3},a) == a)
end

function _jl(s, t)
	_branch(s < t)
end

function _jg(s, t)
	_branch(s > t)
end

function _jin(obj, n)
	local parent = zobject_family(obj, zparent)
	--log('jin: '..obj..' with parent '..parent..', '..n)
	local should_branch = ((parent == n) or (n==0 and parent == nil))
	_branch(should_branch)
end

function _test(a, b)
	_branch((a & b) == b)
end

function _jump(s)
	_program_counter += ((s - 2) >> 16) --keep the sign
end



--8.5 Call and return, throw and catch

function _call_f(raddr, a1, a2, a3, a4, a5, a6, a7)
	_call_fp(raddr, call_type.func, a1, a2, a3, a4, a5, a6, a7)
end

function _call_p(raddr, a1, a2, a3, a4, a5, a6, a7)
	_call_fp(raddr, call_type.proc, a1, a2, a3, a4, a5, a6, a7)
end

function _call_fp(raddr, type, a1, a2, a3, a4, a5, a6, a7)
	-- local var_str = ""
	if (raddr == 0x0) then
		if (type == call_type.func) _result(0)

	else 
		--z3/4 formula is "r = r + 2 ∗ L + 1"
		--z5 formula is "r = r + 1"
		local r = zword_to_zaddress(raddr, true)
		local l = get_zbyte(r) --num local vars
		r += 0x.0001 -- "1"
		call_stack_push()
		if (_zm_version >= 5) top_frame().pc = r

		--set local vars on the new frame
		local a_vars = {a1, a2, a3, a4, a5, a6, a7}
		local n = #a_vars
		for i = 1, l do -- "L"
			local zword = 0
			if (i <= n) then 
				zword = a_vars[i]
			else
				if (_zm_version < 5) zword = get_zword(r)
			end
			-- var_str ..= tohex(zword)..'  '
			set_zword(local_var_addr(i), zword)
			r += 0x.0002 --"2 * l"
		end

		--finish building out the top frame
		if (_zm_version < 5) top_frame().pc = r
		top_frame().call = type
		top_frame().args = n

		_program_counter = top_frame().pc
		-- log("_call "..type.."(1=f,2=p) : "..tohex(raddr).." "..var_str)
		-- log(" --> set pc to: "..tohex(_program_counter))
	end
end

function _ret(a)
	local call = top_frame().call
	-- log("_ret() with frame type: "..call)

	call_stack_pop() --in all cases
	
	if call != call_type.proc then
		if (a != nil) _result(a)
	end
end

function _rtrue()
	_ret(1)
end

function _rfalse()
	_ret(0)
end

function _ret_pulled()
	_ret(stack_pop())
end

function _check_arg_count(n)
	_branch(top_frame().args >= n)
end

function _catch()
	_result(#_call_stack)
end

function _throw(a, fp)
	assert(fp <= #_call_stack, "Tried to throw to non-existant frame "..fp.." out of "..#_call_stack)
	while #_call_stack > fp do
		call_stack_pop()
	end
	_ret(a)
end



--8.6 Objects, attributes, and properties

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

function _remove_obj(obj)
	--log('remove_obj: '..zobject_name(obj)..'('..obj..')')
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
	_branch(zobject_has_attribute(obj, attr))
end

function _set_attr(obj, attr)
	zobject_set_attribute(obj, attr, 1)
end

function _clear_attr(obj, attr)
	zobject_set_attribute(obj, attr, 0)
end

function _put_prop(obj, prop, a)
	zobject_set_prop(obj, prop, a)
end

function _get_prop(obj, prop)
	_result(zobject_get_prop(obj, prop))
end

function _get_prop_addr(obj, prop)
	_result(zobject_prop_data_addr_or_prop_list(obj, prop) << 16)
end

function _get_next_prop(obj, prop)
	--log('get_next_prop: '..obj)
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
	--log('  next prop: '..next_prop)
	_result(next_prop)
end

function _get_prop_len(baddr)
	--log('get_prop_len: '..tohex(baddr))
	if baddr == 0 then
		_result(0)
	else
		local baddr = zword_to_zaddress(baddr)
		local len_byte = get_zbyte(baddr - 0x.0001)
		_result(extract_prop_len(len_byte))
	end
end



--8.7 Windows

function _split_screen(lines)
	log('split_window called: '..lines)
	flush_line_buffer(0)
	local win0, win1 = windows[0], windows[1]
	local cur_y_offset = max(0, win0.h - win0.z_cursor.y)
	if lines == 0 then --unsplit
		win1.y, win1.h = 1, 0
		win0.y, win0.h = 1, _zm_screen_height
	else
		win1.y, win1.h = 1, lines
		win0.y = lines + 1
		win0.h = max(0, _zm_screen_height - win1.h)
	end
	win0.z_cursor.y = win0.h - cur_y_offset
	if win0.z_cursor.y < 1 then
		win0.z_cursor = {x=1,y=1}
	end
	update_screen_rect(1)
	update_screen_rect(0)
	if (_zm_version == 3 and lines > 0) erase_window(1)
end

function _set_window(win)
	log('set_window: '..win)
	flush_line_buffer()
	active_window = win
	if (win == 1) _set_cursor(1,1)
end

--"It is an error in V4-5 to use this instruction when window 0 is selected"
--autosplitting on z4 Nord & Bert revealed a status line bug in the game (!)
function _set_cursor(lin, col)
	log('_set_zcursor to line '..lin..', col '..col)
	flush_line_buffer()
	if ((_zm_version > 4) and (lin > windows[1].h)) _split_screen(lin)
	windows[1].z_cursor = {x=col, y=lin}
	update_p_cursor()
end

function _get_cursor(baddr)
	log('_get_cursor called')
	baddr = zword_to_zaddress(baddr)
	local zc = windows[active_window].z_cursor
	set_zword(baddr, zc.y)
	set_zword(baddr + 0x.0002, zc.x)
end

--_buffer_mode; not sure this applies to us so _nop() for now

function _set_color(byte0, byte1)
	-- log('_set_color: '..tohex(byte0)..', '..tohex(byte1))
	if (byte0 > 1) current_fg = byte0
	if (byte1 > 1) current_bg = byte1
	if (byte0 == 1) current_fg = get_zbyte(_default_fg_color_addr)
	if (byte1 == 1) current_bg = get_zbyte(_default_bg_color_addr)
	_set_text_style(current_text_style)
end

--_set_text_style defined in io.lua

function _set_font(n)
	log('_set_font: '..n)
	_result(0)
end



--8.8 Input and output streams

function _output_stream(n, baddr)
	-- log('output_stream: '..n..', '..tohex(baddr))
	if abs(n) == 1 then
		screen_output = (n > 0)

	elseif abs(n) == 2 then
		local p_flag = get_zbyte(_peripherals_header_addr)
		if (n > 0) p_flag |= 0x01 --transcription on
		if (n < 0) p_flag &= 0xfe --off
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

function _input_stream(n)
	output('_input_stream '..n..'requested?!')
end



--8.9 Input
	--timer disabled in header flags at startup

function _read(baddr1, baddr2, time, raddr)
	if (not _interrupt) then
		-- log('s/read: '..tohex(baddr1)..','..tohex(baddr2)..', time: '..tohex(time)..', '..tohex(raddr))
		flush_line_buffer()
		--cache addresses for capture_input()
		z_text_buffer = baddr1
		z_parse_buffer = baddr2 --hold this and use it in capture_input if it exists
		_show_status()
		_interrupt = capture_input

	else
		z_text_buffer, z_parse_buffer, _interrupt = nil, nil, nil
		if (_zm_version > 4) _result(baddr1) --receives 13 (or something else?) from _read
	end
end

function _read_char(one, time, raddr)
	--log('read_char: '..one..','..tohex(time)..','..tohex(raddr))
	flush_line_buffer()
	local char = wait_for_any_key()
	_result(ord(char))
end



--8.10 Character based output

function _print_char(n)
	log('_print_char '..n..': '..chr(n))
	if (n == 10) n = 13	
	if (n != 0) output(chr(n))
end

function _new_line()
	log('new_line')
	output('\n')
end

function _print(string)
	local zstring = get_zstring(string)
	log('_print: '..zstring)
	output(zstring)
end

function _print_rtrue(string)
	-- log('_print_rtrue')
	_print(string)
	_new_line()
	_rtrue()
end

function _print_addr(baddr, is_packed)
	local is_packed = is_packed or false
	local zaddress = zword_to_zaddress(baddr, is_packed)
	local zstring = get_zstring(zaddress)
	log('print_addr: '..zstring)
	output(zstring)
end

function _print_paddr(saddr)
	_print_addr(saddr, true)
end

function _print_num(s)
	log('_print_num: '..s)
	output(tostr(s))
end

function _print_obj(obj)
	local name, _ = zobject_name(obj)
	log('print_obj with name: '..name)
	output(name)
end

function _print_table(baddr, x, _y, _n)
	local n = _n or 0
	local y = _y or 1
	local za = zword_to_zaddress(baddr)
	for i = 1, y do
		for j = 0, x+n-1 do
			if (j < x) _print_char(get_zbyte(za))
			za += 0x.0001
		end
		_new_line()
	end
end



--8.11 Miscellaneous screen output

function _erase_line(val)
	log('erase_line: '..val)
	if (val == 1) screen("\^i"..current_color_string()..blank_line)
end

function _erase_window(win)
	log('erase_window: '..win)
	if win >= 0 then
		local a,b,c,d = unpack(windows[win].screen_rect)
		rectfill(a,b,c,d,current_bg)
		if (_zm_version >= 5) _set_cursor(1,1)
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
		if (_zm_version == 3) _branch(did_save) else _result(did_save)
	end
end

function _restore()
	--log('restore: ')
	local rg = restore_game()
	if (_zm_version == 3) _branch(rg) else _result(rg)
end

function _save_undo()
	_result(-1)
end
--we don't support undo, so we nop return_undo (won't be called)


--8.14 Miscellaneous

function _nop()
	-- log('_nop: ')
end

function _random(s)
	local r = 0
	if s > 0 then
		r = flr(rnd(s)) + 1
	else
		if (s == 0) s = stat(93)..stat(94)..stat(95)
		srand(s)
	end
	_result(r)
end

--_restart() defined in memory.lua

function _quit()
	story_loaded = false
end

function _show_status()
	if (_zm_version == 3) show_status()
end

--_verify() and _piracy() are just _branch(true)

function _btrue()
	_branch(true)
end

--_tokenise and _encode_text moved to io.lua


-- Overloads; functions to route calls based on zm version

function _pop_catch()
	if (_zm_version < 5) stack_pop() else _catch()
end

function _not_call_p(raddr, a1, a2, a3, a4, a5, a6, a7)
	if (_zm_version < 5) _not(raddr) else _call_p(raddr, a1, a2, a3, a4, a5, a6, a7)
end