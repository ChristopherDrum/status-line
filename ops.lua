--functions with <result> means to set_var(some value)
--functions with <branch> means send true/false to branch()

function branch(should_branch)
	--log('branch called with should_branch: '..tostr(should_branch,true))
	local branch_arg = get_zbyte()
	--log('branch arg: '..tohex(branch_arg))
	local reverse_arg = (branch_arg & 0x80) == 0
	local big_branch = (branch_arg & 0x40) == 0
	--log('  against 0x40: '..tohex(branch_arg & 0x40))
	local offset = (branch_arg & 0x3f)

	if (reverse_arg == true) should_branch = not should_branch

	if (big_branch == true) then
		--log('big_branch evaluated')
		if (offset > 31) offset -= 64
		offset <<= 8
		offset += get_zbyte()
	end

	-- --log('_program_counter at: '..tohex(_program_counter))
	--log('branch offset at: '..offset)
	if (should_branch == true) then
		--log('should_branch is true')
		if offset == 0 or offset == 1 then --same as rfalse/rtrue
			ret(offset)
		else 
			offset >>= 16 --keep the sign!
			_program_counter += (offset - 0x.0002)
		end
	end
end

--long ops
function je(a, b1, b2, b3)
	--log('je: '..tohex(a)..','..tohex(b1)..','..tohex(b2)..','..tohex(b3))
	local b_vars = {b1, b2, b3}
	local should_branch = false
	for i = 1, #b_vars do
		if (a == b_vars[i]) should_branch = true
	end
	branch(should_branch)
end

function jl(s, t)
	--log('jl: '..s..' < '..t) 
	branch(s < t)
end
function jg(s, t)
	--log('jg: '..s..' > '..t)
	branch(s > t)
end
function dec_chk(var, s)
	--log('dec_chk: ')
	local val = dec(var)
	jl(val, s)
end
function inc_jg(var, s)
	--log('inc_jg: '..tohex(var)..', '..tohex(s))
	local val = inc(var)
	jg(val, s)
end
function jin(obj, n)
	local parent = zobject_family(obj, zparent)
	--log('jin: '..obj..' with parent '..parent..', '..n)
	local should_branch = ((parent == n) or (n==0 and parent == nil))
	branch(should_branch)
end

function test(a, b)
	--log('test:('..a..'&'..b..') == '..b..'?')
	branch((a & b) == b)
end

function _or(a, b)
	--log('_or: '..a..' | '..b)
	set_var(a | b)
end

function _and(a, b)
	--log('_and: '..a..' & '..b)
	set_var(a & b)
end

function test_attr(obj, attr)
	--log('test_attr: '..tohex(obj)..','..tohex(attr))
	branch(zobject_has_attribute(obj, attr))
end

function set_attr(obj, attr)
	--log('set_attr: '..tohex(obj)..','..tohex(attr))
	zobject_set_attribute(obj, attr, 1)
end
function clear_attr(obj, attr)
	--log('clear_attr: '..tohex(obj)..','..tohex(attr))
	zobject_set_attribute(obj, attr, 0)
end

function store(var, a)
	--log('store: '..tohex(var)..','..tohex(a))
	set_var(a, var, true)
end

function insert_obj(obj1, obj2)
	--log('insert_obj: '..zobject_name(obj1)..'('..obj1..')'..' into '..zobject_name(obj2)..'('..obj2..')')
	remove_obj(obj1)
	local first_child = zobject_family(obj2, zchild)
	zobject_set_family(obj2, zchild, obj1)
	zobject_set_family(obj1, zparent, obj2)
	zobject_set_family(obj1, zsibling, first_child)
end	

function loadw(baddr, n)
	--log('loadw: '..tohex(baddr)..', '..n)
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	--log('  baddr now: '..tohex(baddr))
	local zword = get_zword(baddr)
	--log('  got zword: '..tohex(zword))
	set_var(zword)
end
function loadb(baddr, n)
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	local zbyte = get_zbyte(baddr)
	--log('loadb fetched '..tohex(zbyte)..' from address '..tohex(baddr))
	set_var(zbyte)
end
function get_prop(obj, prop)
	--log('get_prop: '..obj..','..prop)
	local p = zobject_get_prop(obj, prop)
	set_var(p)
end
function get_prop_addr(obj, prop)
	--log('get_prop_addr: '..obj..','..prop)
	set_var(zobject_prop_data_addr_or_prop_list(obj, prop) << 16)
end
function get_next_prop(obj, prop)
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

function jz(a)
	--log('jz: '..a)
	branch(a == 0)
end

function get_family_member(obj, fam)
	--log('get_family_member: '..obj..','..fam)
	local member = zobject_family(obj, fam)
	if (not member) member = 0
	set_var(member)
	if (fam != zparent) branch(member != 0)
end
function get_sibling(obj) 
	get_family_member(obj, zsibling) 
end	
function get_child(obj) 
	get_family_member(obj, zchild) 
end
function get_parent(obj) 
	get_family_member(obj, zparent) 
end
function get_prop_len(baddr)
	--log('get_prop_len: '..tohex(baddr))
	local baddr = zword_to_zaddress(baddr)
	local len_byte = get_zbyte(baddr - 0x.0001)
	local len = extract_prop_len(len_byte)
	set_var(len)
end
function inc_dec(var, amt)
	local zword = get_var(var)
	--log('inc_dec: '..tohex(var)..'; current value: '..zword..' by '..amt)
	zword += amt --amt may be 1 or -1
	set_var(zword, var)
	return zword
end

function inc(var)
	return inc_dec(var,1)
end
function dec(var)
	return inc_dec(var,-1)
end

function print_addr(baddr)
	local zaddress = zword_to_zaddress(baddr)
	local str, zchars = get_zstring(zaddress)
	--log('print_addr: '..str)
	-- memory(zchars)
	output(str)
end
function remove_obj(obj)
	--log('remove_obj: '..zobject_name(obj)..'('..obj..')')
	--set parent to 0 and stitch up the sibling chain gap
	--children always move with their parent

	local original_parent = zobject_family(obj, zparent)
	if (original_parent != 0) then

		local next_child = zobject_family(original_parent, zchild)
		local next_sibling = zobject_family(obj, zsibling)
		if (next_child == obj) then
			zobject_set_family(original_parent, zchild, next_sibling)
		else
			while (next_child != 0) do
				if (zobject_family(next_child, zsibling) == obj) then
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

function print_obj(obj)
	local name, zchars = zobject_name(obj)
--log('print_obj with name: '..name)
	-- memory(zchars)
	output(name)
end

function ret(a)
	--log('===> ret: '..tohex(a)..' <===')
	call_stack_pop(a)
end
function jump(s)
	--log('jump: '..tohex(s))
	_program_counter += ((s - 2) >> 16) --keep the sign
end
function print_paddr(saddr)
	local zaddress = zword_to_zaddress(saddr, true)
	local str, zchars = get_zstring(zaddress)
--log('print_paddr: '..str)
	-- memory(zchars)
	output(str)
end
function load(var)
	--log('load: '..var)
	local a = get_var(var,true)
	set_var(a)
end
function _not(a)
	--log('_not: '..a)
	set_var(~a)
end

function rtrue()
	--log('rtrue: ')
	ret(1)
end
function rfalse()
	--log('rfalse: ')
	ret(0)
end
function _print(zstring)
	local str, zchars = get_zstring(zstring)
--log('_print: '..str)
	-- memory(zchars)
	output(str)
end
function print_ret(zstring)
--log('print_ret')
	_print(zstring)
	new_line()
	rtrue()
end
function _show_status()
	if (_z_machine_version == 3) show_status()
end

function nop()
	--log('nop: ')
end

function _save(did_save)
	--log('_save: ')
	if _interrupt == nil then
		_interrupt = save_game
	else
		_interrupt = nil
		branch(did_save)
	end
end
function restore()
	--log('restore: ')
	branch(restore_game())
end
function restart()
	--log('restart: ')
	reset_game()
end
function ret_popped()
	--log('ret_popped: ')
	ret(stack_pop())
end
function pop()
	--log('pop: ')
	stack_pop()
end

function quit()
	story_loaded = false
end

function new_line()
--log('new_line')
	-- output('\n')
	print_char(10)
end

function verify()
	--log('verify: cheating on this')
	branch(true)
end

function put_prop(obj, prop, a)
	--log('put_prop: '..obj..','..prop..','..tohex(a))
	zobject_set_prop(obj, prop, a)
end

--timer function turned off in header for now
function read(baddr1, baddr2, time, raddr)
	if (_interrupt == nil) then
	--log('s/read: '..tohex(baddr1)..','..tohex(baddr2)..', time: '..tohex(time)..', '..tohex(raddr))
		--cache addresses for capture_input()
		flush_line_buffer()
		z_text_buffer, z_parse_buffer = zword_to_zaddress(baddr1), zword_to_zaddress(baddr2)
		_show_status()
		_interrupt = capture_input
	else
		z_text_buffer, z_parse_buffer = 0x0, 0x0
		_interrupt = nil
	end
end
function print_char(n)
	-- local char = zscii_to_p8scii({n})
	if (n == 10) n = 13
--log('print_char '..n..': '..chr(n))
	output(chr(n))
end
function print_num(s)
	--log('print_num: '..s)
	output(tostr(s))
end
function push(a)
	--log('push: '..a)
	stack_push(a)
end
function pull(var)
	--log('pull: '..var)
	local a = stack_pop()
	set_var(a, var, true)
end
function split_window(lines)
--log('split_window called: '..lines)
	flush_line_buffer(0)
	local win0 = windows[0]
	local win1 = windows[1]
	local cur_y_offset = win0.h - win0.z_cursor.y
	if (lines == 0) then --unsplit
		win1.y = 1
		win1.h = 0
		win0.y = 1
		win0.h = screen_height
	else
		win1.y = 1
		win1.h = lines
		win0.y = lines + 1
		win0.h = max(0, screen_height - win1.h)
	end
	win0.z_cursor.y = win0.h - cur_y_offset
	if (win0.z_cursor.y < 1) then
		win0.z_cursor = {x=1,y=1}
	end
	update_screen_rect(1)
	update_screen_rect(0)
	if (lines > 0 and _z_machine_version == 3) erase_window(1)
end

function set_window(win)
--log('set_window: '..win)
	flush_line_buffer()
	-- lines_shown = 0
	-- draw_cursor(win) --any value sent to draw_cursor should clear it
	active_window = win
	if (win == 1) set_zcursor(1,1)
end

function erase_window(win)
--log('erase_window: '..win)
	if win >= 0 then
		local a,b,c,d = unpack(windows[win].screen_rect)
		rectfill(a,b,c,d,current_bg)
	else
		if (win == -1) split_window(0)
		cls(current_bg)
	end
	if (win <= 0) then
		windows[0].buffer = nil
		windows[0].screen_buffer = {}
		lines_shown = 0
	end
end

function erase_line(val)
--log('erase_line: '..val)
	if (val == 1) screen("\^i\#"..current_fg..'\f'..current_bg..blank_line)
end

--"It is an error in V4-5 to use this instruction when window 0 is selected"
--autosplitting on z4 Nord & Bert reveals a status line bug in the game (!)
function set_zcursor(lin, col)
--log('set_zcursor to line '..lin..', col '..col)
	flush_line_buffer()
	if ((_z_machine_version == 5) and (lin > windows[1].h)) split_window(lin)
	windows[1].z_cursor = {x=col, y=lin}
	update_p_cursor()
end

function get_cursor(baddr)
--log('get_cursor called')
	baddr = zword_to_zaddress(baddr)
	local zc = windows[active_window].z_cursor
	set_zword(baddr, zc.y)
	set_zword(baddr + 0x.0002, zc.x)
end

function set_text_style(n)
	-- current_style = n
--log('set_text_style: '..n)
	update_current_format(n)
end

function buffer_mode(bit)
--log('buffer_mode: '..tostr(bit))
	--ignore; we have to buffer regardless
end

function output_stream(n, baddr)
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

function input_stream(operands)
	--log('input_stream: NI')
end

function sound_effect(number)
	--experimental
	--log('sound_effect: '..number)
	-- if (number == 1) print("\ac7")
	-- if (number == 2) print("\ac1")
end

--timer is "OFF" in the header, until z5 Border Zone support
function read_char(one, time, raddr)
--log('read_char: '..one..','..tohex(time)..','..tohex(raddr))
	--if (active_window == 1) 
	flush_line_buffer()
	local char = wait_for_any_key()
	set_var(ord(char))
end

function scan_table(a, baddr, n, byte) --<result> <branch>
	--log('scan_table: '..tohex(a)..','..tohex(baddr)..','..n..','..tohex(byte))
	local byte = byte or 0x82
	local getter = ((byte & 0x80) == 0x80) and get_zword or get_zbyte
	local entry_len = byte & 0x7f --strip the top bit
	local base_addr = zword_to_zaddress(baddr)

	local found_addr, should_branch = 0, false
	for i = 0, n-1 do
		local check_addr = base_addr + ((i * entry_len)>>>16)
		local value = getter(check_addr)
		--log('  check addr: '..tohex(check_addr)..', found: '..tohex(value))
		if (value == a) then
			--log('    FOUND!')
			found_addr = check_addr
			should_branch = true
			break
		end
	end

	set_var(found_addr)
	branch(should_branch)
end

function storew(baddr, n, zword)
	--log('storew: '..tohex(baddr)..','..n..','..tohex(zword))
	--Store zword in the word at baddr + 2∗n
	-->>>16 for addressing, then << 1 for "*2"
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	set_zword(baddr, zword)
end

function storeb(baddr, n, zbyte)
	--log('storeb: '..tohex(baddr)..','..n..','..zbyte)
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	set_zbyte(baddr, zbyte)
end

function call_fv(raddr, a1, a2, a3, a4, a5, a6, a7)
	--log('call_fv: '..tohex(raddr)..', '..tohex(a1)..', '..tohex(a2)..', '..tohex(a3)..', '..tohex(a4)..', '..tohex(a5)..', '..tohex(a6)..', '..tohex(a7))
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
			if _z_machine_version < 5 then
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

function random(s, skip_set_var)
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

--call_f0, call_f1
_long_ops = {
	nil, je, jl, jg, dec_chk, inc_jg, jin, test, _or, _and, test_attr, set_attr, clear_attr, store, insert_obj, loadw, loadb, get_prop, get_prop_addr, get_next_prop, _add, _sub, _mul, _div, _mod, call_fv
}

_short_ops = {
	jz, get_sibling, get_child, get_parent, get_prop_len, inc, dec, print_addr, call_fv, remove_obj, print_obj, ret, jump, print_paddr, load, _not
}

_zero_ops = {
	rtrue, rfalse, _print, print_ret, nop, _save, restore, restart, ret_popped, pop, quit, new_line, _show_status, verify
}

_var_ops = {
	call_fv, storew, storeb, put_prop, read, 
	print_char, print_num, random, push, pull, 
	split_window, set_window, call_fv, erase_window, erase_line, 
	set_zcursor, get_cursor, set_text_style, buffer_mode, output_stream, 
	input_stream, sound_effect, read_char, scan_table
}