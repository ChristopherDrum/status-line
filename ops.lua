--follows zmach06e.pdf
--<result> == _result(some value)
--<branch> == _branch(true/false)
--<return> == _ret(value)
--alias for readability in result handling
_result = set_var

function _branch(should_branch)
	--log('branch called with should_branch: '..tostr(should_branch,true))
	local branch_arg = get_zbyte()
	local reverse_arg = (branch_arg & 0x80) == 0
	local big_branch = (branch_arg & 0x40) == 0
	local offset = (branch_arg & 0x3f)

	if (reverse_arg == true) should_branch = not should_branch

	if big_branch == true then
		if (offset > 31) offset -= 64
		offset <<= 8
		offset += get_zbyte()
	end


	if should_branch == true then
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
	_result(get_var(var,true))
end

function _store(var, a)
	-- log("  [ops] _store: "..var.."("..tohex(var).."), "..a.."("..tohex(a)..")")
	_result(a, var, true)
end

--perform math on the raw bytes before resolving to 24-bit address space
--this gives 16-bit wraparound which handles +n -n properly 
function _loadw(baddr, n)
	local addr = zword_to_zaddress(baddr+n*2)
	_result(get_zword(addr))
end

function _storew(baddr, n, zword)
	local addr = zword_to_zaddress(baddr+n*2)
	set_zword(addr, zword)
end

function _loadb(baddr, n)
	local addr = zword_to_zaddress(baddr+n)
	_result(get_zbyte(addr))
end

function _storeb(baddr, n, zbyte)
	local addr = zword_to_zaddress(baddr+n)
	set_zbyte(addr, zbyte)
end

-- _push(a) and _pop() are _stack_push and _stack_pop in memory.lua

function _pull(var)
	_result(stack_pop(), var, true)
end

function _scan_table(a, baddr, n, byte) --<result> <branch>
	-- log('  [ops] scan_table: '..tohex(a)..','..tohex(baddr)..','..n..','..tohex(byte))
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
	-- log('  [ops] _copy_table from: '..tohex(baddr1)..' to: '..tohex(baddr2)..','..s..' bytes')
	local from = zword_to_zaddress(baddr1)
	if baddr2 == 0 then
		for i = 0, s-1 do
			set_zbyte(from+(i>>>16), 0)
		end
	else
		local to = zword_to_zaddress(baddr2)
		local st, en, step = s-1, 0, -1
		if s < 0 or from > to then
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
	local d = a/b
	d = (d < 0) and ceil(d) or flr(d)
	if (help) return d else _result(d)
end

function _mod(a, b)
	--p8 mod gives non-compliant results: -13 % -5, p8: "2", zm: "-3"
	_result(a - (_div(a,b,true) * b))
end

function _inc(var)
	local zword = get_var(var) + 1
	_result(zword, var)
end

function _dec(var)
	local zword = get_var(var) - 1 
	_result(zword, var)
end

function _inc_jg(var, s)
	local zword = get_var(var) + 1
	_result(zword, var)
	_branch(zword > s)
end

function _dec_jl(var, s)
	local zword = get_var(var) - 1 
	_result(zword, var)
	_branch(zword < s)
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
	if b1 then
		if a == b1 or a == b2 or a == b3 then
			_branch(true)
		else 
			_branch(false)
		end
	else
		_program_counter += 0x.0001
	end
end

function _jl(s, t)
	_branch(s < t)
end

function _jg(s, t)
	_branch(s > t)
end

function _jin(obj, n)
	local parent = zobject_family(obj, zparent)
	--log('  [ops] jin: '..obj..' with parent '..parent..', '..n)
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

function _call_f(...)
	_call_fp(call_type.func, ...)
end

function _call_p(...)
	_call_fp(call_type.proc, ...)
end

--_call_p shared opcode with _not; see bottom of this file

function _call_fp(type, raddr, a1, a2, a3, a4, a5, a6, a7)
	
	if raddr == 0x0 then
		if (type != call_type.func) return
		_result(0)

	else
		--z3/4 formula is "r = r + 2 times L + 1"
		--z5 formula is "r = r + 1"
		local r = zword_to_zaddress(raddr, true)
		local l = get_zbyte(r) --num local vars
		-- log("  _call_fp: "..tohex(raddr).." -> "..tohex(r)..', ('..l..' locals)')
		r += 0x.0001 -- "1"

		--special handling for frame pc in interrupt situation
		local fpc, pc = top_frame().pc, _program_counter
		call_stack_push()
		if (type == call_type.intr) _call_stack[#_call_stack-1].pc = 0x0 --watch for this signal...

		if (_zm_version >= 5) top_frame().pc = r
		-- if (#_call_stack >= 4) log3("  b frame #4: pc at: "..tohex(_call_stack[4].pc))

		--set local vars on the new frame
		local a_vars = {a1, a2, a3, a4, a5, a6, a7}
		local n = min(l, #a_vars)
		for i = 1, l do -- "L"
			if i <= n then 
				zword = a_vars[i]
			else
				zword = (_zm_version < 5) and get_zword(r) or 0
			end
			-- var_str ..= tohex(zword)..'  '
			set_zword(_local_var_table_mem_addr + (i >>> 16), zword)
			r += 0x.0002 --"2 * l"
		end

		--finish building out the top frame
		if (_zm_version < 5) top_frame().pc = r
		top_frame().call = type
		top_frame().args = n

		_program_counter = top_frame().pc

		--in an interrupt, the normal instruction load loop is not run
		--so we run it manually here 
		if type == call_type.intr then
			while _program_counter != 0x0 do
				-- log3(" --- running timed routine ---")
				local func, operands = load_instruction()
				func(unpack(operands))
			end
			top_frame().pc = fpc
			_program_counter = pc
			return stack_pop()
		end

	end
end

function _ret(a)
	local call = top_frame().call

	call_stack_pop() --in all cases

	if call == call_type.intr then
		stack_push(a)

	elseif call == call_type.func then
		_result(a)
	end
end

function _rtrue()
	_ret(1)
end

function _rfalse()
	_ret(0)
end

function _ret_pulled()
	_ret(stack_top())
end

function _check_arg_count(n)
	_branch(top_frame().args >= n)
end

function _catch()
	_result(#_call_stack)
end

function _throw(a, fp)
	-- assert(fp <= #_call_stack, "Tried to throw to non-existant frame "..fp.." out of "..#_call_stack)
	while #_call_stack > fp do
		call_stack_pop()
	end
	_ret(a)
end



--8.6 Objects, attributes, and properties

function _get_family_member(obj, fam)
	-- log('  [ops] _get_family_member: '..zobject_name(obj))
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
	if (obj == 0) return
	-- log('  [ops] remove_obj: '..zobject_name(obj)..'('..obj..')')
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
	if (obj1 == 0 or obj2 == 0) return

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
	local addr = zobject_search_properties(obj, prop, target_addr)
	-- log("  [prp] _get_prop_addr returning: "..tohex(addr)..", "..tostr(len))
	_result(addr << 16)
end

function _get_next_prop(obj, prop)
	-- log('  [ops] get_next_prop for: '..zobject_name(obj)..'('..obj..'), prop: '..prop)
	local next_prop = zobject_search_properties(obj, prop, target_next)
	_result(next_prop)
end

function _get_prop_len(baddr)
	local len = 0
	if baddr != 0 then
		local addr = zword_to_zaddress(baddr-1)
		local byte = get_zbyte(addr)
		if _zm_version > 3 then
			if (byte & 0x80 == 0x80) then 
				addr -= 0x.0001
			end
		end
		len = extract_prop_len_num(addr)
	end
	-- log("  [prp]  _get_prop_len: "..tohex(baddr)..", len: "..len)
	_result(len)
end



--8.7 Windows

function _split_screen(lines)
	flush_line_buffer(1)
	flush_line_buffer(0)

	--split at # lines
	local win0, win1 = windows[0], windows[1]
	win1.h = min(_zm_screen_height, lines)
	local p_height = win1.h*6 + origin_y
	win1.screen_rect = {0, origin_y, 128, p_height+1}
	win0.h = max(0, _zm_screen_height - lines)
	win0.screen_rect = {0, p_height+1, 128, 128}

	--adjust z_cursors to reflect the split
	if (win1.z_cursor[2] > win1.h) set_z_cursor(1, 1, 1)

	win0.z_cursor[2] += lines
	if (win1.h > win0.z_cursor[2]) set_z_cursor(0, 1, 1)

	--z3 mandate
	if (_zm_version == 3 and lines > 0) _erase_window(1)
end

function _set_window(win)
	flush_line_buffer()
	active_window = win
	if (win == 1) _set_cursor(1,1)
end

--"It is an error in V4-5 to use this instruction when window 0 is selected"
--autosplitting Nord & Bert revealed status line bug (!)
function _set_cursor(lin, col)
	-- log('  [ops] _set_cursor to line: '..lin..' col: '..col)
	if (_zm_version > 3 and active_window == 0) return
	flush_line_buffer()
	if (active_window == 1 and lin > windows[1].h) then
		windows[1].h = min(_zm_screen_height, lin)
		local p_height = windows[1].h*6 + origin_y
		windows[1].screen_rect = {0, origin_y, 128, p_height+1}
	end
	set_z_cursor(active_window,col,lin)
end

function _get_cursor(baddr)
	baddr = zword_to_zaddress(baddr)
	local zx,zy = unpack(windows[active_window].z_cursor)
	if (active_window == 1 and windows[1].fakex) zx = windows[1].fakex
	-- log('  [ops] _get_cursor reports line: '..zy..' col: '..zx)
	set_zword(baddr, zy)
	set_zword(baddr + 0x.0002, zx)
end

--_buffer_mode; not sure this applies to us so _nop() for now

function _set_color(byte0, byte1)
	if byte0 > 0 then
		current_fg = (byte0 > 1) and byte0 
		or get_zbyte(_default_fg_color_addr)
	end
	if byte1 > 0 then
		current_bg = (byte1 > 1) and byte1 
		or get_zbyte(_default_bg_color_addr)
	end
	update_text_colors()
end

--_set_text_style defined in io.lua

function _set_font(n)
	_result(0)
end



--8.8 Input and output streams

function _output_stream(_n, baddr, w)
	if (_n == 0) return

	local n, on_off = abs(_n), (_n > 0)

	if n == 1 then
		screen_stream = on_off

	elseif n == 2 then
		trans_stream = on_off
		local p_flag = get_zbyte(_peripherals_header_addr)
		--transcription on, off
		if (trans_stream == true) p_flag |= 0x01 else p_flag &= 0xfe
		set_zbyte(_peripherals_header_addr, p_flag)

	elseif n == 3 then
		mem_stream = on_off
		if mem_stream == true then
			local addr = zword_to_zaddress(baddr)
			add(mem_stream_addr, addr)
			set_zword(addr, 0x00)
		else
			deli(mem_stream_addr)
			mem_stream = (#mem_stream_addr > 0)
		end
	elseif n == 4 then
		script_stream = on_off
	end
end

function _input_stream(n)
	-- log3('  [ops] _input_stream '..n)
end



--8.9 Input

function _read(baddr1, baddr2, time, raddr)
	if (not _interrupt) then
		flush_line_buffer()
		--cache addresses for capture_input()
		z_text_buffer = baddr1
		z_parse_buffer = baddr2 --hold this and use it in capture_input if it exists
		if raddr then
			z_timed_interval = time\10
			z_timed_routine = raddr
			z_current_time = stat(94)*60 + stat(95)
		end
		_show_status()
		preloaded = false
		_interrupt = capture_line

	else
		preloaded = false
		current_input, visible_input = '', ''
		z_text_buffer, z_parse_buffer, _interrupt = nil, nil, nil
		z_timed_interval, z_timed_routine, z_current_time = 0, nil, 0
		if (_zm_version > 4) _result(baddr1) --receives 13 from capture_input
	end
end

function _read_char(one, time, raddr)
	if (not _interrupt) then
		flush_line_buffer()
		-- log3("_read_char with time: "..tostr(time))
		if raddr then
			z_timed_interval = time\10
			z_timed_routine = raddr
			z_current_time = stat(94)*60 + stat(95)
			-- log3("interval set to : "..tostr(z_timed_interval))
		end
		_interrupt = capture_char
	else
		_interrupt = nil
		z_timed_interval, z_timed_routine, z_current_time = 0, nil, 0
		_result(ord(one)) --overload 'one' for the return value
	end
end



--8.10 Character based output

function _print_char(n)
	if (n == 10) n = 13	
	if (n != 0) output(chr(n))
end

function _print_unicode(c)
	if (c > 255) c = 63 --unsupported, default to "?"
	_print_char(c)
end

function _new_line()
	output(chr(13))
end

function _print(string)
	local zstring = get_zstring(string)
	output(zstring)
end

function _print_rtrue(string)
	_print(string)
	_new_line()
	_rtrue()
end

function _print_addr(baddr, is_packed)
	local zaddress = zword_to_zaddress(baddr, is_packed)
	_print(zaddress)
end

function _print_paddr(saddr)
	_print_addr(saddr, true)
end

function _print_num(s)
	output(tostr(s))
end

function _print_obj(obj)
	if (obj == 0) return
	local name = zobject_name(obj)
	output(name)
end

function _print_table(baddr, width, _height, _skip)
	local skip = _skip or 0
	local height = _height or 1

	local za = zword_to_zaddress(baddr)
	local zx, zy = unpack(windows[active_window].z_cursor)
	for i = 1, height do
		local str = ""
		for j = 1, width + skip do
			if j <= width then
				_print_char(get_zbyte(za))
			end
			za += 0x.0001
		end
		if height > 1 then
			zy += 1
			_set_cursor(zy,zx)
		end
	end
end



--8.11 Miscellaneous screen output

function _erase_line(val)
	if val == 1 then
		local px,py = unpack(windows[active_window].p_cursor)
		rectfill(px,py,128,py+5,current_bg)
	end
end

function _erase_window(win)
	if win >= 0 then
		local a,b,c,d = unpack(windows[win].screen_rect)
		rectfill(a,b,c,d,current_bg)

		if win == 1 then
			set_z_cursor(win, 1, 1)
		else
			if _zm_version >= 5 then
				set_z_cursor(win, 1, 1)
			else
				set_z_cursor(win, 1, windows[win].h)
			end
		end

	elseif win == -1 then
		_split_screen(0)
		active_window = 0
		cls(current_bg)
		if _zm_version < 5 then
			set_z_cursor(0, 1, windows[0].h)
		else
			set_z_cursor(0, 1, 1)
		end
	
	elseif win == -2 then
		cls(current_bg)
	end
	flip()

	if win <= 0 then
		windows[0].buffer = {}
		lines_shown = 0
	else
		windows[1].buffer = {}
	end
end



--8.12 Sound, mouse, and menus

function _sound_effect(number)
	-- log('  [snd] sound_effect: '..number)
	if (number == 1) print("\ac3")
	if (number == 2) print("\ac1")
end

--8.13 Save, restore, and undo

function _save(did_save)
	--log('_save: ')
	if _interrupt == nil then
		_interrupt = save_game
		output('Enter filename (max 30 chars; careful, do NOT press "ESC")\n\n>', true)
	else
		_interrupt = nil
		if (_zm_version == 3) _branch(did_save) else _result(did_save)
	end
end

function _restore(baddr1, n, baddr2)
	-- log('restore: '..tostr(baddr1)..', '..tostr(n)..', '..tostr(baddr2))
	local rg = restore_game()
	if _zm_version == 3 then 
		_branch(rg)
	else
		-- log('  rg == '..tostr(rg))
		if (rg != 0 and n) rg = n
		-- log('  rg == '..tostr(rg))
		_result(rg)
	end
end

function _deny_undo()
	_result(-1)
end


--8.14 Miscellaneous

function _nop()
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

--_show_status() defined in io.lua

--_verify() and _piracy() are just _branch(true)

function _btrue()
	_branch(true)
end

--_tokenise and _encode_text moved to io.lua


-- Overloads; functions to route calls based on zm version
function _pop_catch()
	if (_zm_version < 5) stack_pop() else _catch()
end

function _not_call_p(...)
	if (_zm_version < 5) _not(...) else _call_fp(call_type.proc, ...)
end