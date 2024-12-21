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

function addr_offset(baddr, n, amt)
	-- log("  [ops] addr_offset: "..tohex(baddr).." by: "..tohex(n))
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
	if (baddr == mem_stream_addr) log(" ! ! asked to load from mem stream ? ?")
	-- log("   with offset: "..tohex(baddr))
	_result(get_zword(baddr))
end

function _storew(baddr, n, zword)
	baddr = addr_offset(baddr, n, 15)
	-- log("   with offset: "..tohex(baddr))
	set_zword(baddr, zword)
end

function _loadb(baddr, n)
	baddr = addr_offset(baddr, n, 16)
	-- log("   with offset: "..tohex(baddr))
	_result(get_zbyte(baddr))
end

function _storeb(baddr, n, zbyte)
	baddr = addr_offset(baddr, n, 16)
	-- log("   with offset: "..tohex(baddr))
	set_zbyte(baddr, zbyte)
end

-- _push(a) and _pop() are _stack_push and _stack_pop in memory.lua

function _pull(var)
	local a = stack_pop()
	_result(a, var, true)
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
	-- log("  [ops] _add: "..a.."("..tohex(a)..") "..b.."("..tohex(b)..")")
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
	-- log("  [ops] _add: "..a.."("..tohex(a)..") "..b.."("..tohex(b)..")")
	_result(a | b)
end

function _and(a, b)
	-- log("  [ops] _and: "..a.."("..tohex(a)..") "..b.."("..tohex(b)..")")
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
	-- log("  [ops] _jz: "..a.."("..tohex(a)..")")
	_branch(a == 0)
end

function _je(a, b1, b2, b3)
	-- log("  [ops] _je: "..a.."("..tohex(a)..") "..tostr(b1).."("..tohex(b1)..")"..tostr(b2).."("..tohex(b2)..")"..tostr(b3).."("..tohex(b3)..")")
	_branch(del({b1,b2,b3},a) == a)
end

function _jl(s, t)
	-- log("  [ops] _jl: "..s.."("..tohex(s)..") "..t.."("..tohex(t)..")")
	_branch(s < t)
end

function _jg(s, t)
	-- log("  [ops] _jg: "..s.."("..tohex(s)..") "..t.."("..tohex(t)..")")
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

function _call_fp(...)
	local type, raddr, a1, a2, a3, a4, a5, a6, a7 = ...

	if (raddr == 0x0) then
		if (type == call_type.func) _result(0)

	else 
		--z3/4 formula is "r = r + 2 ∗ L + 1"
		--z5 formula is "r = r + 1"
		local r = zword_to_zaddress(raddr, true)
		local l = get_zbyte(r) --num local vars
		-- log("  _call_fp: "..tohex(raddr).." -> "..tohex(r)..', ('..l..' locals)')
		r += 0x.0001 -- "1"
		call_stack_push()
		if (_zm_version >= 5) top_frame().pc = r

		--set local vars on the new frame
		local a_vars = {a1, a2, a3, a4, a5, a6, a7}
		local n = min(l, #a_vars)
		for i = 1, l do -- "L"
			if (i <= n) then 
				zword = a_vars[i]
			else
				zword = (_zm_version < 5) and get_zword(r) or 0
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
		-- log("  [ops] _call "..type.."(1=f,2=p) : "..tohex(raddr))
		-- log("  [ops]  --> set pc to: "..tohex(_program_counter))
	end
end

function _ret(a)
	local call = top_frame().call
	-- log("  [ops] _ret() with frame type: "..call)

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
	-- log("  [ops] _check_arg_count: "..tostr(n)..' vs. frame #'..#_call_stack..", "..tostr(top_frame().args))
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
	-- if (member != 0) log('  found: '..zobject_name(member)..'('..fam..')')
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
	-- log('  [ops] insert_obj: '..zobject_name(obj1)..'('..obj1..')'..' into '..zobject_name(obj2)..'('..obj2..')')
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
	local addr, len = zobject_prop_data_addr_or_prop_list(obj, prop)
	log("  [prp] _get_prop_addr returning: "..tohex(addr)..", "..tostr(len))
	_result(addr << 16)
end

function _get_next_prop(obj, prop)
	-- log('  [ops] get_next_prop for: '..zobject_name(obj)..'('..obj..'), prop: '..prop)
	local next_prop = 0
	local prop_list = zobject_prop_data_addr_or_prop_list(obj)
	if (prop_list == 0) prop_list = {}
	if prop == 0 then 
		if (#prop_list > 0) next_prop = prop_list[1]
	else
		for i = 1, #prop_list do
			if (prop_list[i] == prop) and (i < #prop_list) then
				next_prop = prop_list[i+1]
				break
			end
		end
	end
	-- log('      found: '..next_prop)
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
	log("  [prp]  _get_prop_len: "..tohex(baddr)..", len: "..len)
	_result(len)
end



--8.7 Windows

function _split_screen(lines)
	log('  [ops] _split_screen: '..lines)
	flush_line_buffer(0)

	--split at # lines
	local win0, win1 = windows[0], windows[1]
	win1.h = min(_zm_screen_height, lines)
	local p_height = win1.h*6 + origin_y
	win1.screen_rect = {0, origin_y, 128, p_height}
	win0.h = max(0, _zm_screen_height - lines)
	win0.screen_rect = {0, p_height, 128, 128}

	--adjust z_cursors to reflect the split
	if (win1.z_cursor.y > win1.h) set_z_cursor(1, 1, 1)

	win0.z_cursor.y += lines
	if (win1.h > win0.z_cursor.y) set_z_cursor(0, 1, 1)

	--z3 mandate
	if (_zm_version == 3 and lines > 0) _erase_window(1)
end

function _set_window(win)
	log('  [ops] _set_window: '..win)
	-- flush_line_buffer()
	active_window = win
	if _zm_version < 4 then 
		if (win == 1) _erase_window(1)
	else 
		_set_cursor(1,1)
	end
end

--"It is an error in V4-5 to use this instruction when window 0 is selected"
--autosplitting on z4 Nord & Bert revealed a status line bug in the game (!)
function _set_cursor(lin, col)
	log('  [ops] _set_cursor: line '..lin..', col '..col)
	if (_zm_version > 3 and active_window == 0) return
	if (col < 1) col = 1
	flush_line_buffer()
	set_z_cursor(active_window,col,lin)
end

function _get_cursor(baddr)
	log('  [ops] _get_cursor: '..tohex(baddr))
	baddr = zword_to_zaddress(baddr)
	local zc = windows[active_window].z_cursor
	set_zword(baddr, zc.y)
	set_zword(baddr + 0x.0002, zc.x)
end

--_buffer_mode; not sure this applies to us so _nop() for now

function _set_color(byte0, byte1)
	log('  [ops] _set_color: fg = '..byte0..', bg = '..byte1)
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
	log('  [ops] _set_font: '..n)
	_result(0)
end



--8.8 Input and output streams

function _output_stream(_n, baddr, w)
	-- log('  [ops] output_stream: '.._n..', '..tohex(baddr)..', '..tostr(w))
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
	output('  [ops] _input_stream '..n..'?!?!')
end



--8.9 Input
	--timer disabled in header flags at startup

function _read(baddr1, baddr2, time, raddr)
	if (not _interrupt) then
		-- log('  [ops] _read: '..tohex(baddr1)..','..tohex(baddr2)..', time: '..tohex(time)..', '..tohex(raddr))
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
	--log('  [ops] _read_char: '..one..','..tohex(time)..','..tohex(raddr))
	flush_line_buffer()
	local char = wait_for_any_key()
	_result(ord(char))
end



--8.10 Character based output

function _print_char(n)
	log('  [prt] _print_char: '..n)
	if (n == 10) n = 13	
	if (n != 0) output(chr(n))
end

function _new_line()
	log('  [prt] new_line')
	output('\n')
end

function _print(string)
	local zstring = get_zstring(string)
	log('  [prt] _print: '..zstring)
	output(zstring)
end

function _print_rtrue(string)
	log('  [prt] _print_rtrue')
	_print(string)
	_new_line()
	_rtrue()
end

function _print_addr(baddr, is_packed)
	local is_packed = is_packed or false
	local zaddress = zword_to_zaddress(baddr, is_packed)
	local zstring = get_zstring(zaddress)
	log('  [prt] print_addr: '..zstring)
	output(zstring)
end

function _print_paddr(saddr)
	_print_addr(saddr, true)
end

function _print_num(s)
	log('  [prt] _print_num: '..s)
	output(tostr(s))
end

function _print_obj(obj)
	if (obj == 0) return
	local name = zobject_name(obj)
	log('  [prt] print_obj: '..name)
	output(name)
end

function _print_table(baddr, x, _y, _n)
	-- log('  [ops] _print_table: '..tohex(baddr)..','..x..','.._y)
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
	log('  [ops] erase_line: '..val)
	if (val == 1) screen(text_colors..blank_line)
end

function _erase_window(win)
	log('  [ops] _erase_window: '..win)
	if win >= 0 then
		local a,b,c,d = unpack(windows[win].screen_rect)
		clip(a,b,c,d)
		cls(current_bg)
		clip()

	elseif win == -1 then
		_split_screen(0)
		cls(current_bg)
		if (_zm_version >= 5) _set_cursor(1,1)
	
	elseif win == -2 then
		cls(current_bg)
	end
	flip()

	if win <= 0 then
		windows[0].buffer = {}
		lines_shown = 0
	end
end



--8.12 Sound, mouse, and menus

function _sound_effect(number)
	-- log('  [ops] sound_effect: '..number)
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

function _deny_undo()
	-- log("  [ops] _deny_undo")
	_result(-1)
end


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

function _not_call_p(...)
	if (_zm_version < 5) _not(...) else _call_p(...)
end