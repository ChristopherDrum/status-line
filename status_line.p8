pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
--status line 2.0
--by christopher drum

_z_machine_version = 0
_engine_version = '2.0'
story_loaded = false
-- full_color = false

local screen_types = {
	default = 1, 
	values = {
		{'b&w', {6,0}}, {'green', {138, 131}}, 
		{'amber', {9,128}}, {'blue', {12,129}}, 
		{'oldlcd', {131,129}}, {'plasma', {8,130}}, 
		{'invert', {0,6}}--, {'ega', {7,0}}
	}
}
local scroll_speeds = {
	default = 3,
	values = {
		{'slow', 30}, {'medium', 20}, {'fast', 10}, 
		{'faster', 2}, {'fastest', -1}
	}
}
local clock_types = {
	default = 1,
	values = {
		{'24-hour', 24}, {'12-hour', 12}
	}
}
local cursor_types = {
	default = 1,
	values = {
		{'block', '▮'}, {'square', '■'}, 
		{'bar', '|'}, {'under', '_'}, {'dotted', '\^:150a150a15000000'}
	}
}

--frequently used values we can cache before starting
max_input_length = 0
z_parse_buffer_length = 0
separators = {}
_dictionary_lookup = {}
blank_line = '                                '
default_property_count = 0
packed_shift = 0
object_entry_size = 0
dictionary_word_size = 0

--these literally make the engine run
_program_counter = 0x0
_interrupt = nil


--useful functions
function in_set(val, set)
	for i = 1, #set do
		if (val == set[i]) return true
	end
	return false
end

function in_range(val,min,max)
	return mid(min,val,max) == val
end

function tohex(value, full)
	if (value == nil) return '(no_value)'
	local hex = tostr(value, true)
	if (full == false) hex = sub(hex, 3, 6)
	return hex
end

function log(str)
	printh(str, 'status_line_log_20')
end

lines_shown = 0
function wait_for_any_key(message)
	if message then 
		screen(message)
	else
		-- log('wait_for_any_key turning ON cursor?')
		draw_cursor(1)
		flip()
	end

	local keypress = ''
	while (keypress == '') do
		-- draw_cursor(1)
		if stat(30) then
			poke(0x5f30,1)
			keypress = stat(31)
		end
		-- flip()
	end
	-- log('keypress: '..keypress..' ('..ord(keypress))
	if (active_window == 0) deli(windows[active_window].screen_buffer)
	lines_shown = 0
	if not message then
		local o = ord(keypress)
		if (in_range(o,128,153)) o -= 63
		-- log('wait_for_any_key turning OFF cursor?')
		draw_cursor(0)
		return chr(o)
	end
end

local flip_time = t()
local c = 1
function draw_cursor(state)
	local win = windows[active_window]
	local px, py = unpack(win.p_cursor)
	-- log('draw_cursor at ('..win.z_cursor.x..','..win.z_cursor.y..') sees: '..px..','..py)
	if state then
		c = state
	elseif active_window == 0 then
		local blink = (t() - flip_time) >= 0.5
		if (blink == true) then
			flip_time = t()
			c = (c+1)%2
		end
	end
	local cur_col = (c == 0) and current_bg or current_fg
	-- log('  cur_col: '..cur_col)
	print(cursor_type, px, py, cur_col)
	-- flip()
end

function build_menu(name, dval, table)
	local var = dget(dval)
	if (var == 0) var = table.default
	dset(dval, var)
	local item_name = unpack(table.values[var])
	local right_dec = (var < #table.values) and '•' or ''
	local left_dec = (var > 1) and '•' or ''
	local item_str = name..': '..left_dec..item_name..right_dec
	menuitem(dval+1, item_str, function(b) if (b < 112) then if (b&1 <= 0) then var += 1 end if (b&1 > 0) then var -= 1 end var = mid(1, var, #table.values) dset(dval, var) build_menu(name, dval, table) end end)
end

#include memory.lua
#include ops.lua
#include io.lua
-- #include debug.lua

function _init()
	poke(0x5f2d, 1)
	poke(0x5f36,0x4)
	memcpy(0x5600,0x2000,0x800)

	cartdata('drum_statusline_1')

	build_menu('screen', 0, screen_types)
	build_menu('scroll', 1, scroll_speeds)
	build_menu('clock', 2, clock_types)
	build_menu('cursor', 3, cursor_types)
end

function draw_splashscreen(did_load)
	cls(0)

	-- sspr(0,0,128,124,0,0)--monitor
	-- rectfill(6,125,122,127,1)
	-- sspr(90,125,7,3,83,124)--knobs
	-- sspr(90,125,7,3,93,124)

	-- color(7)
	-- line(33,83,93,83)
	-- print('V'.._engine_version, 82, 69)

	-- if (did_load == true) then
	-- 	sspr(100,124,14,4,103,116)
	-- 	print('sTORY IS LOADING', 31, 100)
	-- else
	-- 	sspr(114,124,14,4,103,116)
	-- 	print('DRAG IN A Z3/4 STORY\n  TO START PLAYING', 24, 92)
	-- end

	-- color()
	-- flip()
end

function game_id()
	local id = zword_to_zaddress(get_zword(_static_mem_addr))
	return tohex(id<<16, false)
end

function setup_palette()
	local st = dget(0) or 1
	local type = screen_types.values[st]
	full_color = type[1] == 'ega'
	fg, bg = unpack(type[2])
	pal({fg,0,8,139,10,140,136,12,7,10,11,12,13,14,15,bg},1)
	palt(0,false)
end

function setup_user_prefs()
	local er = dget(1) or 3
	local ct = dget(2) or 1
	local cur = dget(3) or 1

	_, emit_rate = unpack(scroll_speeds.values[er])
	_, clock_type = unpack(clock_types.values[ct])
	_, cursor_type = unpack(cursor_types.values[cur])
end

function _update60()

	if (story_loaded == true) then
		--_interrupt is set when _read() is called
		if _interrupt then
			local key = nil
			if stat(30) and not key then
				key = stat(31)
				poke(0x5f30,1)
			end
			_interrupt(key)
		else
			--I found this method of running multiple vm instructions
			--per frame more consistent and easier to regulate
			local count = 0
			local max_instruction = 50
			while count < max_instruction and 
					_interrupt == nil and
					story_loaded == true do
				local func, operands = load_instruction()
				if (func == _save) capture_state(_current_state)
				func(unpack(operands))
				count += 1
				-- log('instruction count: '..count)
			end
		end
		draw_cursor()

	else
		if (stat(120)) then
			draw_splashscreen(true)
			load_story_file()
		else
			if (_program_counter != 0x0) then
				--let the player see end-of-game text
				flush_line_buffer()
				wait_for_any_key("\^i       ~ END OF SESSION ~       ")
				reset_all_memory()
			end
			pal()
			draw_splashscreen(false)
		end
	end
end

function build_dictionary_lookup()
	local addr = _dictionary_addr
	local num_separators = get_zbyte(addr)
	addr += 0x.0001 + (0x.0001 * num_separators)
	local entry_length = (get_zbyte(addr) >>> 16)
	-- log('entry length: '..entry_length)
	addr += 0x.0001
	local word_count = get_zword(addr)
	-- log('dictionary entries: '..word_count)
	addr += 0x.0002
	-- log('start decoding at byte: '..tostr(unpack(get_zbytes(addr, 1)),true))
	for i = 1, word_count do
		local zstring = get_zstring(addr,1)
		local lower = ''
		for j = 1, #zstring do
			local c = ord(sub(zstring,j,j))
			if (c >= 65 and c <= 90) c += 32
			lower ..= chr(c)
		end
		_dictionary_lookup[lower] = (addr << 16)
		-- log('  '..lower..', set to '..tohex(addr << 16)..'(was '..tohex(addr)..')')
		addr += entry_length
	end
end

function fetch_parser_separators()
	local num_separators = get_zbyte(_dictionary_addr)
	local seps = get_zbytes(_dictionary_addr + 0x.0001, num_separators)
	seps = zscii_to_p8scii(seps)
	-- log('fetch_parser_separators: '..seps)
	for i = 1, num_separators do
		local k = sub(seps, i, i)
		add(separators, k)
	end
end

function process_header()
	_z_machine_version = get_zbyte(version)

	origin_y = 8
	screen_height = 20
	packed_shift = 1
	default_property_count = 31
	object_entry_size = 0x.0009
	dictionary_word_size = 6
	if _z_machine_version > 3 then
		origin_y = 1
		screen_height = 21
		packed_shift = 2
		default_property_count = 63
		object_entry_size = 0x.000e
		dictionary_word_size = 9
	end

	set_zbyte(_screen_height, screen_height)
	set_zbyte(_screen_width, 32)

	local i_flag = get_zbyte(interpreter_flags)
	if _z_machine_version == 3 then
		i_flag &= 0x3b --turn off some bits
		i_flag |= 0x20 --enable upper window
	else
		i_flag = 0x9c
		-- if (full_color == true) i_flag |= 0x01
	end
	-- log('interpreter flags set to: '..tohex(i_flag))
	set_zbyte(interpreter_flags, i_flag)

	-- local p_flag = get_zbyte(peripherals)
	-- p_flag &= 0xff --no transcription
	set_zbyte(peripherals, 0x03)

	set_zbyte(interpreter_number, 4) --amiga
	set_zbyte(interpreter_version, ord('P'))
end

function cache_memory_addresses()
	_program_counter = zword_to_zaddress(get_zword(program_counter_addr))
	_paged_memory_addr = zword_to_zaddress(get_zword(paged_memory_addr))
	_dictionary_addr = zword_to_zaddress(get_zword(dictionary_addr))
	_object_table_addr = zword_to_zaddress(get_zword(object_table_addr))
	_global_var_table_addr = zword_to_zaddress(get_zword(global_var_table_addr))
	_abbr_table_addr = zword_to_zaddress(get_zword(abbr_table_addr))
	_static_mem_addr = zword_to_zaddress(get_zword(static_mem_addr))
end

function patch()
	local checksum = get_zword(file_checksum)
	log('checksum: '..tohex(checksum))
	if (checksum == 0x16ab) set_zbyte(0x.fddd,1) --trinity, @fredrick
	if (in_set(checksum, {0x4860, 0xfc65})) set_zbyte(_screen_width, 40) --amfv, beau
end

function initialize_game()

	setup_user_prefs()
	setup_palette()
	process_header()
	cache_memory_addresses()
	fetch_parser_separators()
	build_dictionary_lookup()

	patch()

	call_stack_push()
	--special case at startup for the program counter
	_call_stack[#_call_stack - 9] = _program_counter

	active_window = 0
	windows[0].screen_buffer = {}
	split_window(0)
	if (_memory_start_state == nil) capture_state(_memory_start_state)
	update_current_format(0)
	update_p_cursor()
	story_loaded = true

	cls()
end
__gfx__
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555550
55666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666655
56666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
56666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
56666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
56666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
56666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
56666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
56666666666655555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555666666666665
56666666665555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555556666666665
5666666666d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555d6666666665
566666666ddd55555555555555555555555555555555557d7d7777777dd7d7d7d777dd777d7d77d7755555555555555555555555555555555555ddd666666665
566666666dddd555555555555555555777777d7dd777771000000000000000000000000000000000007777d771d777d7d75d555555555555555dddd666666665
566666666ddddd555555575777777000000000000000111111111111111111111111111111111111111110000000000111d7177777d7555555ddddd666666665
566666666dddddd55555510000001111111111111111111111111111551115111551111111111111111111111111111111000000000000555dddddd666666665
566666666ddddddd500001111111111111111111115155511155511111515551155515511111151111111111111111111111111111111100ddddddd666666665
566666666ddddddd0111111111111111111115111511551555551515515515555551555155151555511111151111111111111111111111110dddddd666666665
566666666dddddd01111111111111151111111151515515551515515555115555555515555515555115155555515515155111111111111110dddddd666666665
566666666dddddd011111111111111155515155551515515555555515555551555555555155555555555555151515511151551111111111110ddddd666666665
566666666ddddd0111111111111511115555115555551515555555555555555155515555555555555555555155555555151511511111111110ddddd666666665
566666666ddddd0111111111111111155115555555555555555555555555555555555555555555555555555551555551515155111111111110ddddd666666665
566666666ddddd0111111111111115155555555555555555555555555555555555555555555555555555555555555515511155111111111110ddddd666666665
566666666ddddd0111111111111515555555555555555555555555555555555555555555555555555555555555555555555551515511111110ddddd666666665
566666666ddddd0111111111111115511555555555555555555555555555555555555555555555555555555555551511515551111111111110ddddd666666665
566666666ddddd0111111177777711555515555555555555555555555555555555555555555555555555555555555151511511515111111110ddddd666666665
566666666ddddd0111111177777715515155555555555555555555555555555555555555555555555555555555555515155115111115111110ddddd666666665
566666666ddddd0111111111117777155555155555555555555555555555555555555555555555555555555555555515555155111511111110ddddd666666665
566666666ddddd0111111111117777551551515555555555555555555555555555555555555555555555555551515551555151151151111110ddddd666666665
566666666ddddd0011111111111177771555555555555555555555555555555555555555555555555555555555555555551551511151111110ddddd666666665
566666666ddddd0011111111151177771555515551555555555555555555555555555555555555555555555555155555155151115115111110ddddd666666665
566666666ddddd0111111111111115777715155515555555555555555555555555555555555555555555555555115155515115515151111110ddddd666666665
566666666ddddd0011111111111115777755155551551555555555555555555555555555555555555555555555555515555111511111111100ddddd666666665
566666666ddddd0001111111111177771555551555555555555555555555555555555555555555555555515555515151151511111151111110ddddd666666665
566666666ddddd0011111115115177771555515515515555555555555555555555555555555555555555555555551511555115111111111110ddddd666666665
566666666ddddd0111111111117777115515155555555555555555555555555555555555555555555555551555151155551111551111111100ddddd666666665
566666666ddddd0011111111117777515515155555555555555555555555555555555555555555555515555555515115515155151151111100ddddd666666665
566666666ddddd0111111177777711115115555551555555555555555555555555555555555555551555555551555555151151111111111000ddddd666666665
566666666ddddd0011111177777711515151511551555555555555555555555555555555555555155555555555555155115151515111111110ddddd666666665
566666666ddddd0011111151111511115551151155555555555555555555555555555555555555555515551555555515515115115511111000ddddd666666665
566666666ddddd0001111111111111511155555555555555555555555555555555555555555555151555555515555115511555511111111110ddddd666666665
566666666ddddd0001111111111155555155555551155515515555555555555555555555555555515551515551155555551111115551111110ddddd666666665
566666666ddddd0100111111111155115155155551555555555515155555555555555555555555155555555155555155111515111151111100ddddd666666665
566666666ddddd0000010111777777775515155515511515555551555555555555555555515555555555555555511555155151115111111100ddddd666666665
566666666ddddd0111011111777777775555555555555115551555515555555555555555555551555551555555555515511111111151111100ddddd666666665
566666666ddddd0011101177771111777755155577775115555555511555555555515577771551555151515115555115511511111111111010ddddd666666665
566666666ddddd0011111177771111777751511177775555151511551555515551555577775555555511555515551111111115111511111110ddddd666666665
566666666ddddd0001111177775115111115777777777777555517777777751151777777777777555777755117777151157777777777111010ddddd666666665
566666666ddddd0111011177771111115151777777777777555517777777755111777777777777551777711517777155557777777777111100ddddd666666665
566666666ddddd0001111111777777775151511577775555111551511557777555551177775551515777755157777151777711111111111010ddddd666666665
566666666ddddd0101111111777777771111111577775115551151151117777515551577771555555777755117777115777711111111111100ddddd666666665
566666666ddddd0110101111111111777711111177771551115557777777777155111177775555551777755517777111557777777711111100ddddd666666665
566666666ddddd0011111111111111777711111577775111155517777777777551151577775511155777751157777551517777777711111000ddddd666666665
566666666ddddd0101111177771111777751511577775115555777711517777151555577771111111777751517777155115111117777111110ddddd66666d665
566666666ddddd0100111177771111777715151577775111115777715157777115151577775111511777755517777155515111117777111100ddddd666666665
566666666ddddd0001111111777777771111155111777777555517777777777115515151777777555117777777777111777777777711110110ddddd666d66665
566666666ddddd0000111011777777771151111151777777115557777777777551551555777777515157777777777515777777777711111100ddddd666666665
566666666ddddd0001011111111111111155115151111111551155555515151151551155111555115115511115511115511115111111101010ddddd666666d65
566666666ddddd0001011111111111111111511551111511115151155551151155111155555511551155111111111115111511111111101100ddddd666666665
566666666ddddd0011011101011111111151511115511111155115551111151115151551111111151515511511151115151111111111101100ddddd6666d6665
566666666ddddd0011010100110111111151111115555111511511111511551555111111515555551111111115511151511151111111011110ddddd6666d6665
566666666ddddd0001111177771111111111151177771155511151551511511111115151511111511115511151111111111111111111011100ddddd666666665
566666666ddddd0000001177771111111111111177771115111115151111115515515151555111151511551151151151111111111111111110ddddd6d666d665
566666666ddddd0001111077771011111111551551111111151515551155111511115551111115115515115515151111511111111111110000ddddd666666665
566666666ddddd0001011077770011111115151511111115151111555111151111511115111155515111115111111151111111111111110100ddddd6666d6665
566666666ddddd0011011177771010111111117777771515115777777777751151117777777711115111111151115115111111111110110100ddddd666666665
566666666ddddd0010011177771011111111517777771111115777777777715151517777777751111111111111155111151111111111111100ddddd66d666665
566666666ddddd0001111077771111110111115177771111111777711157777111777711517777115551111111115511111111111011010100ddddd666666665
56d666666ddddd0000111077771011111111111177771551111777711157777515777715117777115111551111511111115111101011110110ddddd66666d665
566666666ddddd0010010177771101011111111177771115515777751117777111777777777777511511551111111111111111111111111110ddddd666d66665
566666666ddddd0000111177771111010111111177771511111777711517777115777777777777511151111115111111111111110110111100ddddd6d6666665
566666666ddddd0000011177770111101111111177771111115777711517777111777715111111151151111111511151111110111111110000ddddd666d6d6d5
5666d6666ddddd0001010177771100111001111177771511111777751117777111777711111111111111111111111511110111011101111100ddddd666666665
566666666ddddd0000011177777777777711117777777715111777715117777551157777777711111111151111111111110101111111111000ddddd666666665
56666dd66ddddd0001100077777777777710117777777711111777711157777155517777777715151115111111111105111111111011111000ddddd666dd6665
56d666666ddddd0000101101100100010111111011111101111111111111111115111511111101111111011111111010100110011111011100ddddd6666d6665
5666d6666ddddd0000101101001001010110111101100111111111111111111111111011110111011111011110111110001101001010111000ddddd66d66d665
56666d6d6ddddd0000100110001111010001101110111111111111111111111011111111111111111111111110011101011110110011100010ddddd666666665
56d6666d6ddddd0000001101101010010110111011010011111111111111111100111111111111100101111110111111001111010110011010ddddd66666d665
566666666ddddd0000000000000111110001011111111110111111011111110111110111011110111100011101001111011011111110110100ddddd666d666d5
566666666ddddd0000100010011111010101001101111100100111100001101111111111111111011111111111110111010111001011011000ddddd66666d665
56d6d66d6ddddd0001000000101000110000001011111111111101111001111110011111111011110101110010101111001111110100011100ddddd666666665
566666666ddddd0000000001000000100011010011001111011001111101001111111011110101111001111100001010000100010111001100ddddd6d6666d65
5666d6666ddddd0000000001100010100100010110101011111111100110110011111010111111101110011111110111100110110101010000ddddd6ddd66665
5666666d6ddddd0010000001001101000011111101010111000110010111110111111011011011001100011111011100101101000010100100ddddd666666665
566666666ddddd0000100110100000101100001101110001110000110000101111110101011111111101010100111001101110110110111000ddddd666d66d65
5666d6d66ddddd0000000000001011111000000011100101101111111111100111010110000110111111111000000000000111000000101000ddddd66666d665
5666dd666ddddd0000000001101000001010000110011111011111101011010010011100011000111001110000110100011011110100011000ddddd66666d665
566d66666ddddd0000011000001110111101000100001010010011011010000010110110001001011001111100000000010000011010110100ddddd666666665
566666d66ddddd0000000000101001000101001010001110000110011100111100010001000101010101101010111000010010101111101000ddddd666666665
56666d666ddddd0001000000000100110100010101101001001001110101101001111010110001110011100100001010001001000010001000ddddd66d6d6665
56d66d666ddddd0000100000100111110111100110110010110111101111001010010000100100100001000100100000000001100110010000ddddd6666666d5
56666666dddddd0000000011000110001101101000010110110101001001001010000011011100100011001011001000000100000000000100ddddd666666665
566666666ddddd0000000011011000001001100100000000001011011100100011000110000001010010001010001000101000000100010000ddddd666666665
566666666ddddd0000010001011001010001000000001000000010000001000100110010010000011000101101000110011000100100110000ddddd666d66665
56d6dd6d6ddddd0000000001100001101001100001110010000111100001000010010110000010000001000010001100000000000100100000ddddd6d666d665
566666666ddddd0000001001010001001100110000100111000100100100010010101101010110100101010100001010001000010100000000ddddd666666665
56666d666ddddd0000000000000000010001000101001000011010000100100110000000000001010000100000001000000101100110000000ddddd666d66665
566666666ddddd0000000000000000000000000000000011000100000100000000011000000110110101010100001000010010011010100000ddddd6d6666d65
5666d6666ddddd0000010000100000000001000000001011110010010000011100000100000110011100000010000000010001000100100000ddddd66d666665
5666666d6ddddd0000000001100100000010000000000100010000010000000100110001100001000000101000001001000001100000100000ddddd666dd6665
5666d6666ddddd0000000010010000100111000000110100000000000010001100000010000100000000000001100001000100000010000000ddddd666666665
56d666666ddddd0000000000000000101000000100010000000000000000010101100000001000011100010000000100011000110010000000ddddd66d666665
56666d666ddddd0000000110000000110000101001001100010110000000001011010000000011000001010001000000110001000000000000ddddd66666d665
566666666ddddd0000000001000000001000000100000000001000011011000010001010000000101010011001010010100000001000000000ddddd666d66665
566dd6666ddddd0000000000000010001001001000101100000000100001000011000000100000000011000001010000000110100000000000ddddd666666665
566666666ddddd0000000000000101100001011000010001000010000001010000000110111001100011101110100101000000000000000000ddddd666666665
56d6666d6ddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ddddd66d66d665
566666666dddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dddddd666666d65
566d66d66ddddd6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d6ddddd666666665
566666d66dddd6ddd111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111dddd6dddd666d66665
566666666ddd6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6ddd666666665
56d66d6666d6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6d666d666665
56666666666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6666666d665
566666666d66dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd6666d666d665
566d6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665
566666dd666666666d6666666666d66666666666666666666666d666666666666666d666dd66d666d66d666d666d6666d6666666666666666666666dd66d6d65
566666d666d66dd666d666d666666666666dd66d66d66666666666666666d6666d66666d66666d66d66666d6d6dddd666666666666666666666666666d666665
566d66d6666666666666666666666666d66666666666d66d66666666666666666666d66666666666666666666666666666666666666666666666666666666dd5
566666666d666666666666d666d666d6d66d666666666d66dd666d6d66666d66666666d6dd66d66d66666666666666666666666666666666666666666dd66665
56dd666666666d6666d666666d6666666666666d66666d666666d6666d6d666d66666666666666666d66d666d66666666666666666666666666666666d666665
5666d666d66d666d6666666666666666d666666666666666666666666666666d666d6666d66666d666d66ddd66d6d66666d66666666666666666666666d66665
566666666666666d666d6d666d6666666dd6666666d6d666d66d666d6666d6666d66666d666d66666dd6666666d666d6d666d66666666666666666d6d666d665
55666666d66666666d66666d6d666dd66d6666d6666d66d6666666666666666666666666666666d6666d6666666666666666d666d66666666666666666666655
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555550
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111111677bbddddddddd6aa99
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666666600015555555d67bbbd666666616a999
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d66666d00015555555d6bbbbd6666666169999
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ddddd0000ddddddddd6bbbb11111111169999

__map__
0405060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0707070707000000000707070000000000070507000000000005020500000000000500050000000000050505000000000406070604000000010307030100000007010101000000000004040407000000050702070200000000000200000000000000000000070e0000000000000303000b0b0000000000000205020000000000
000000000000000004040200010000000a050000000000000a0e0a07050000000c060c07020000000a0806010500000006060c05070000000402000000000000080402020400000002040402010000000a040f020500000000040e0400000000000000040200000000000e000000000000000000040000000804040201000000
0c0a0905030000000c080402070000000c080601030000000c080604030000000a090704020000000e020704030000000c020605030000000e080402020000000c0a0605030000000c0a060403000000000400020000000000040002010000000804020204000000000e00070000000002040402010000000e08040001000000
040a0a0106000000000c0a060500000000060a0507000000000c02010600000000060a0907000000000c060106000000000e060101000000000c020507000000000a0a0705000000000e040207000000000e040403000000000a0605050000000002020106000000000e0e090500000000060a09050000000006090502000000
000c0a0601000000000c0a070c00000000060a0605000000000c020403000000000e040202000000000a0a0506000000000a0a0602000000000a0a0707000000000a040205000000000a0a0403000000000e080207000000060202010300000001020202040000000c08080406000000040a0000000000000000000e00000000
02040000000000000c0a0e0905000000060a0705030000000c02010106000000060a0a05070000000c020601070000000c020601010000000c020a09070000000a0a0705050000000e040202070000000e080405030000000a0a06050d00000004020201070000000e0e090505000000060a090505000000040a090502000000
0c0a0601010000000609050604000000060a0605050000000c020408070000000e040202020000000a090505060000000a0a0606020000000a0a0507070000000a04020505000000080a0604030000000e080402070000000c04030206000000040402020200000006040c02030000000008060100000000040a040000000000
000000000000000006060600060000000b0b0000000000000b0f0b0f0b0000000f070e0f060000000d0c06030b00000007070c090f00000006030000000000000603030306000000060c0c0c0600000009060f060900000000060f06000000000000000603000000000007000000000000000000060000000c06060603000000
0f0b0b0b0f000000070606060f0000000f0c0f030f0000000f0c0e0c0f0000000b0b0f08080000000f030f0c0f00000003030f0b0f0000000f0c0c0c0c0000000f0b0f0b0f0000000f0d0f0c0c000000000600060000000000060006030000000c0603060c000000000f000f0000000003060c06030000000f0c0e0006000000
060b0b030e000000000e0b0f0b00000000070f0b0f000000000e03030e00000000070b0b07000000000e07030e000000000f070303000000000e030b0f000000000b0b0f0b000000000f06060f000000000f060607000000000b070b0b000000000303030e000000000f0f0b0b00000000070b0b0b000000000e0b0b07000000
000e0b0f0300000000060b070e00000000070b070b000000000e030c07000000000f060606000000000b0b0b0e000000000b0b0f06000000000b0b0f0f000000000b06060b000000000b0b0c07000000000f0c030f0000000703030307000000030606060c0000000e0c0c0c0e000000060b0000000000000000000007000000
060c0000000000000f0b0f0b0b000000070b070b0f0000000e0303030e000000070b0b0b0f0000000f0307030f0000000f030703030000000e03030b0f0000000b0b0f0b0b0000000f0606060f0000000f060606030000000b070b0b0b000000030303030e0000000f0f0b0b0b000000070b0b0b0b0000000e0b0b0b07000000
070b0f0303000000060b0b070e000000070b070b0b0000000e030f0c070000000f060606060000000b0b0b0b0e0000000b0b0b0e040000000b0b0b0f0f0000000b0b060b0b0000000b0b0e0c070000000f0c06030f0000000e0607060e000000060606060600000007060e0607000000000c0f030000000000060b0600000000
