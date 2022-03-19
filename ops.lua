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

	--log('_program_counter at: '..tohex(_program_counter))
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
	--log('jl: ') 
	branch(s < t)
end
function jg(s, t)
	--log('jg: ')
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
	--log('test: ')
	branch((a & b) == b)
end

function _or(a, b)
	--log('_or: ')
	set_var(a | b)
end

function _and(a, b)
	--log('_and: ')
	set_var(a & b)
end

function test_attr(obj, attr)
	--log('test_attr: '..tohex(obj)..','..tohex(attr))
	branch(zobject_has_attribute(obj, attr))
end

function set_attr(obj, attr)
	--log('set_attr: '..tohex(obj)..','..tohex(attr))
	zobject_set_attribute(obj, attr, 1) --turn the bit on
end
function clear_attr(obj, attr)
	--log('clear_attr: '..tohex(obj)..','..tohex(attr))
	zobject_set_attribute(obj, attr, 0) --turn the bit off
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
	local p = zobject_prop(obj, prop)
	set_var(p)
end
function get_prop_addr(obj, prop)
	--log('get_prop_addr: '..obj..','..prop)
	set_var(zobject_prop_address(obj, prop) << 16)
end
function get_next_prop(obj, prop)
	--log('get_next_prop: '..obj)
	--If prop is 0, the result is highest numbered prop on obj
	--Else, the number of its next lower numbered property
	--Else, 0
	local next_prop = 0
	local prop_list = zobject_prop_list(obj)
	if prop == 0 then 
		if (#prop_list > 0) next_prop = prop_list[1]
	else
		for i = 1, #prop_list do
			if (prop_list[i] == prop and i+1 <= #prop_list) then
				next_prop = prop_list[i+1]
			end
			--log(prop_list[i])
		end
	end
	-- --log('next prop: '..next_prop)
	set_var(next_prop)
end

function _add(a, b)
	--log('add: ('..a..' + '..b..')')
	set_var(a + b)
end

function _sub(a, b)
	--log('sub: ('..a..' - '..b..')')
	_add(a, -b)
end

function _mul(a, b)
	--log('mul: ('..a..' * '..b..')')
	set_var(a * b)
end

function _div(a, b)
	--log('div: ('..a..' / '..b..')')
	local d = a/b
	if ((a > 0 and b > 0) or (a < 0 and b < 0)) then
		d = flr(d)
	else
		d = ceil(d)
	end
	set_var(d)
end

function _mod(a, b)
	--log('mod: ('..a..' % '..b..')')
	--p8 mod gives non-compliant results
	--ex: -13 % -5, p8: "2", google and zmachine: "-3"
	local m
	if ((a > 0 and b > 0) or (a < 0 and b < 0)) then
		m = a - (flr(a/b) * b)
	else
		m = a - (ceil(a/b) * b)
	end
	set_var(m)
end

--short ops
function jz(a)
	--log('jz: ')
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
	local size_byte = zobject_prop_length(baddr)
	set_var(size_byte)
end
function inc(var)
	local zword = get_var(var)
	--log('inc: '..tohex(var)..'; current value: '..zword)
	zword += 1
	set_var(zword, var)
	return zword --eliminate redundant memory fetch when chained with other functions, like jg (nee inc_jg)
end
function dec(var)
	--log('dec: ')
	local zword = get_var(var)
	zword -= 1
	set_var(zword, var)
	return zword --eliminate redundant memory fetch when chained with other functions (nee dec_chk)
end
function print_addr(baddr)
	--log('print_addr: '..tohex(baddr))
	local zaddress = zword_to_zaddress(baddr)
	local str = get_zstring(zaddress)
	output(str)
end
function remove_obj(obj)
	--log('remove_obj: '..zobject_name(obj)..'('..obj..')')
	--set parent to 0 and stitch up the sibling chain gap
	--caused by removing this object from its family
	--children move with the obj

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
	--log('print_obj: '..obj..' with name: '..zobject_name(obj))
	output(zobject_name(obj))
end

function ret(a)
	--log('===> ret: '..tohex(a)..' <===')
	call_stack_pop(a)
end
function jump(s)
	--log('jump: '..tohex(s))
	s -= 2
	_program_counter += (s >> 16) --keep the sign
end
function print_paddr(saddr)
	--log('print_paddr: '..tohex(saddr))
	local zaddress = saddr >>> 15
	local str = get_zstring(zaddress)
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

--zero ops
function rtrue()
	--log('rtrue: ')
	ret(1)
end
function rfalse()
	--log('rfalse: ')
	ret(0)
end
function _print()
	local str = get_zstring()
	output(str)
end
function print_ret()
	--log('print_ret: ')
	_print()
	new_line()
	rtrue()
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
	local did_restore = restore_game()
	branch(did_restore)
end
function restart()
	--log('restart: ')
	reset_game()
end
function ret_popped()
	--log('ret_popped: ')
	local return_value = stack_pop()
	ret(return_value)
end
function pop()
	--log('pop: ')
	stack_pop()
end

function quit()
	--log('quit: ')
	story_loaded = false
end

function new_line()
	--log('new_line: ')
	output('\n')
end
function show_status()
	--log('show_status: ')
	update_status_bar()
end

--verify() computes a checksum
function verify()
	--log('verify: cheating on this')
	branch(true)
end

function put_prop(obj, prop, a)
	--log('put_prop: '..obj..','..prop..','..a)
	zobject_set_prop(obj, prop, a)
end

function read(baddr1, baddr2)
	if (_interrupt == nil) then
		--log('s/read: '..tohex(baddr1)..','..tohex(baddr2))
		--cache off addresses for capture_input to access
		text_buffer, parse_buffer = zword_to_zaddress(baddr1), zword_to_zaddress(baddr2)
		update_status_bar()
		_interrupt = capture_input
	else
		text_buffer, parse_buffer = 0x0, 0x0
		_interrupt = nil
	end
end
function print_char(n)
	--log('print_char: '..n)
	local char = zscii_to_p8scii({n})
	output(char)
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
function split_window(operands) 
	--log('split_window: NI')
end
function set_window(operands) 	
	--log('set_window: NI')
end
function output_stream(n) 
	--log('output_stream: '..n)
	if n == 2 then
		local p_flag = get_zbyte(peripherals)
		p_flag &= 0xf3 --clear bit 0; turn off transcription
		set_zbyte(peripherals, p_flag)
	end
end
function input_stream(operands) 
	--log('input_stream: NI')
end
function sound_effect(operands)
	--log('sound_effect: look at for v4')
end

--8.2 Reading and writing memory
function storew(baddr, n, zword)
	--log('storew: ')
	--Store a in the word at baddr +2∗ n
	-->>>16 for addressing, then << 1 for "*2"
	baddr = zword_to_zaddress(baddr) + (n >>> 15)
	set_zword(baddr, zword)
end

function storeb(baddr, n, zbyte)
	--log('storeb: ')
	baddr = zword_to_zaddress(baddr) + (n >>> 16)
	set_zbyte(baddr, zbyte)
end

--8.5 Call and return, throw, catch
function call_fv(raddr, a1, a2, a3)
	--log('call_fv: ')
	--log('  received: '..tohex(raddr)..', '..tohex(a1)..', '..tohex(a2)..', '..tohex(a3))
	if (raddr == 0x0) then
		set_var(0)
	else
		local a_vars = {a1, a2, a3}
		local r = zword_to_zaddress(raddr, true)
		--log('  unpacked raddr: '..tohex(r))
		local l = get_zbyte(r) --num local variables
		--log('  revealed l value: '..l)
		r += 0x.0001 -- the "1" in "r + 2 ∗ L + 1"
		call_stack_push()
		for i = 1, l do --the "L" in "r + 2 + L + 1"
			local zword = get_zword(r)
			if (a_vars[i]) zword = a_vars[i]
			local addr = local_var_address(i)
			set_zword(addr, zword)
			r += 0x.0002 ---- the "2" in "r + 2 ∗ L + 1"
		end
		--r should  be pointing to the start of the routine
		_program_counter = r
	end
end

function random(s, skip_set_var)
	--log('random: '..s)
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

_long_ops = {
	nil, je, jl, jg, dec_chk, inc_jg, jin, test, _or, _and, test_attr, set_attr, clear_attr, store, insert_obj, loadw, loadb, get_prop, get_prop_addr, get_next_prop, _add, _sub, _mul, _div, _mod
}

_short_ops = {
	jz, get_sibling, get_child, get_parent, get_prop_len, inc, dec, print_addr, nil, remove_obj, print_obj, ret, jump, print_paddr, load, _not
}

_zero_ops = {
	rtrue, rfalse, _print, print_ret, nop, _save, restore, restart, ret_popped, pop, quit, new_line, show_status, verify
}

_var_ops = {
	call_fv, storew, storeb, put_prop, read, print_char, print_num, random, push, pull, split_window, set_window, nil, nil, nil, nil, nil, nil, nil, output_stream, input_stream, sound_effect
}