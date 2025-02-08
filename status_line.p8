pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--status line 3.0
--by christopher drum

_engine_version = '3.0'

_program_counter, _interrupt, game_id = 0x0, nil, 0x0

story_loaded, full_color = false, false
punc = '.,!?_#\'"/\\-:()'
load_message = "DRAG IN A\nZ3/4/5/8 GAME\nOR A split1 FILE\nTO START PLAYING"
message = load_message


function rehydrate_menu_vars()
	local raw_strings = "screen_types`1`ega,0,7`b&w,6,0`green,138,131`amber,9,128`blue,12,129`oldlcd,131,129`plasma,8,130`invert,0,6/scroll_speeds`3`slow,7`medium,5`fast,4`faster,2`fastest,0/clock_types`1`24-hour,24`12-hour,12/cursor_types`1`block,▮`square,■`bar,|`under,_`dotted,\^:150a150a15000000"
	
	local strings = split(raw_strings,'/')
	for str in all(strings) do
		local def = split(str, '`')
		local menu = {}
		menu['default'] = def[2]
		local values = {}
		for i = 3, #def do
			add(values, split(def[i]))
		end
		menu['values'] = values
		_ENV[def[1]] = menu
	end
end

function rehydrate_ops()
	local raw_strings = "_zero_ops,_rtrue,_rfalse,_print,_print_rtrue,_nop,_save,_restore,_restart,_ret_pulled,_pop_catch,_quit,_new_line,_show_status,_btrue,_nop,_btrue/_short_ops,_jz,_get_sibling,_get_child,_get_parent,_get_prop_len,_inc,_dec,_print_addr,_call_f,_remove_obj,_print_obj,_ret,_jump,_print_paddr,_load,_not_call_p/_long_ops,_nop,_je,_jl,_jg,_dec_jl,_inc_jg,_jin,_test,_or,_and,_test_attr,_set_attr,_clear_attr,_store,_insert_obj,_loadw,_loadb,_get_prop,_get_prop_addr,_get_next_prop,_add,_sub,_mul,_div,_mod,_call_f,_call_p,_set_color,_throw/_var_ops,_call_f,_storew,_storeb,_put_prop,_read,_print_char,_print_num,_random,stack_push,_pull,_split_screen,_set_window,_call_f,_erase_window,_erase_line,_set_cursor,_get_cursor,_set_text_style,_nop,_output_stream,_input_stream,_sound_effect,_read_char,_scan_table,_not,_call_p,_call_p,_tokenise,_encode_text,_copy_table,_print_table,_check_arg_count/_ext_ops,_save,_restore,_log_shift,_art_shift,_set_font,_nop,_nop,_nop,_nop,_deny_undo,_deny_undo,_print_unicode,_nop,_nop,_nop"

	local strings = split(raw_strings,'/')
	for str in all(strings) do
		local def = split(str)
		_ENV[def[1]] = {}
		local str = {}
		for j = 2, #def do
			add(_ENV[def[1]],_ENV[def[j]])
			add(str, def[j])
		end
		add(_ENV[def[1]], str)
	end

end

function rehydrate_mem_addresses(raw_strings)
	local strings = split(raw_strings)
	for str in all(strings) do
		local def = split(str,"=")
		_ENV[def[1]] = tonum(def[2])
	end
end

--set must be single chars in a string
function in_set(val, set) 
	for i = 1, #set do
		if (set[i] == val) return true
	end
	return false
end

-- token-saving version for release
function tohex(value)
	return sub(tostr(value, 3), 3, 6)
end

function wait_for_any_key()
	local keypress = nil
	while keypress == nil do
		if stat(30) then
			poke(0x5f30,1)
			keypress = stat(31)
		end
		flip()
	end
	return keypress
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
#include save_restore.lua
#include io.lua

function _init()
	poke(0x5f2d, 1)
	poke(0x5f36,0x4)
	memcpy(0x5600,0x2000,0x800)

	cartdata('drum_statusline_1')

	rehydrate_menu_vars()
	build_menu('screen', 0, screen_types)
	build_menu('scroll', 1, scroll_speeds)
	build_menu('clock', 2, clock_types)
	build_menu('cursor', 3, cursor_types)
	rehydrate_ops()
	rehydrate_mem_addresses(--[[language::mem_addresses]]"_paged_memory_mem_addr=0x0,_dictionary_mem_addr=0x0,_object_table_mem_addr=0x0,_global_var_table_mem_addr=0x0,_static_memory_mem_addr=0x0,_abbr_table_mem_addr=0x0,_dynamic_memory_mem_addr=0x0,_high_memory_mem_addr=0x0,_program_counter_mem_addr=0xc,_local_var_table_mem_addr=0xe,_stack_mem_addr=0xd,_version_header_addr=0x.0000,_interpreter_flags_header_addr=0x.0001,_release_number_header_addr=0x.0002,_paged_memory_header_addr=0x.0004,_program_counter_header_addr=0x.0006,_dictionary_header_addr=0x.0008,_object_table_header_addr=0x.000a,_global_var_table_header_addr=0x.000c,_static_memory_header_addr=0x.000e,_peripherals_header_addr=0x.0010,_serial_code_header_addr=0x.0012,_abbr_table_header_addr=0x.0018,_file_length_header_addr=0x.001a,_file_checksum_header_addr=0x.001c,_interpreter_number_header_addr=0x.001e,_interpreter_version_header_addr=0x.001f,_screen_height_header_addr=0x.0020,_screen_width_header_addr=0x.0021,_screen_width_units_addr=0x.0022,_screen_height_units_addr=0x.0024,_font_height_units_addr=0x.0026,_font_width_units_addr=0x.0027,_default_bg_color_addr=0x.002c,_default_fg_color_addr=0x.002d,_terminating_chars_table_addr=0x.002e,_standard_revision_num_addr=0x.0032,_alt_character_set_addr=0x.0034,_extension_table_addr=0x.0036"
)
end

function draw_splashscreen()
	cls(0)
	pal(split("128,130,133,134,5,6,7,8,9,10,11,12,13,14,15"),1)
	sspr(0,0,128,128,0,0)
	print(message, 21, 66,7)
	flip()
end

function setup_palette()
	pal()
	local st = dget(0) or 1
	local mode, fg, bg = unpack(screen_types.values[st]) 
	full_color = mode == 'ega'
	p = split("0,0,8,139,10,140,136,12,7,6,5,133,14,15")
	p[0], p[15] = bg, fg
	pal(p,1)
end

function setup_user_prefs()
	local er = dget(1) or 3
	local ct = dget(2) or 1
	local cur = dget(3) or 1

	_, emit_rate = unpack(scroll_speeds.values[er])
	_, clock_type = unpack(clock_types.values[ct])
	_, cursor_type = unpack(cursor_types.values[cur])
end

cursor_string = " "
function _update60()
	if (story_loaded == true) then
		if _interrupt then
			cursor_string = (stat(95)%2 == 0) and cursor_type or " "
			local key = nil
			if stat(30) and key == nil then
				poke(0x5f30,1)
				key = stat(31)
			end
			if (key == nil) and (_interrupt == capture_char) then
				if (btn(0)) key = chr(131)
				if (btn(1)) key = chr(132)
				if (btn(2)) key = chr(129)
				if (btn(3)) key = chr(130)
			end
			_interrupt(key)

		else
			--I found this method of running multiple vm instructions per frame easier to regulate
			local _count = 0
			local max_instruction = 180
			while _count < max_instruction and 
					_interrupt == nil and
					story_loaded == true do
				local func, operands = load_instruction()
				func(unpack(operands))
				_count += 1
			end
		end

	else
		if stat(120) then
			message = '\n\n\nsTORY IS LOADING...'
			draw_splashscreen()
			load_story_file()
		else
			if _program_counter != 0x0 then
				--let the player see end-of-game text
				flush_line_buffer()
				screen("\^i"..text_colors.."       ~ END OF SESSION ~       ")
				wait_for_any_key()
				clear_all_memory()
				message = load_message
			end
			pal()
			draw_splashscreen()
		end
	end
end

function build_dictionary(addr)
	local dict, seps = {}
	local num_separators = get_zbyte(addr)

	addr += 0x.0001
	local seps = get_zbytes(addr, num_separators)
	separators = zscii_to_p8scii(seps)

	addr += (num_separators >>> 16)
	local entry_length = (get_zbyte(addr) >>> 16)

	addr += 0x.0001
	local word_count = abs(get_zword(addr))

	addr += 0x.0002
	-- log("  [dct] "..separators..", entry len: "..tohex(entry_length)..", count: "..word_count)
	for i = 1, word_count do
		local zstring = get_zstring(addr, true)
		dict[zstring] = (addr << 16)
		-- log("  ["..i.."] "..zstring..": "..tohex(addr))
		addr += entry_length
	end
	return dict
end

function process_header()
	_zm_version = get_zbyte(_version_header_addr)

	local i_flag = get_zbyte(_interpreter_flags_header_addr)
	local p_flag = 0x0082

	if _zm_version < 4 then
		_zm_screen_height = 20
		_zm_packed_shift = 1
		_zm_object_property_count = 31
		_zm_object_entry_size = 9
		_zm_dictionary_word_length = 6

		i_flag &= 0x07 --preserve the game's bottom 3 bits
		i_flag |= 0x20 --enable upper window
		full_color = false
	else
		_zm_screen_height = 21
		_zm_packed_shift = (_zm_version < 8) and 2 or 3
		_zm_object_property_count = 63
		_zm_object_entry_size = 14
		_zm_dictionary_word_length = 9

		set_zbyte(_interpreter_number_header_addr, 6) --ibm pc
		set_zbyte(_interpreter_version_header_addr, 112) --"P"		
		set_zbyte(_screen_height_header_addr, _zm_screen_height)
		set_zbyte(_screen_width_header_addr, 32)

		if _zm_version >= 5 then
			set_zword(_screen_width_units_addr, 128)
			set_zword(_screen_height_units_addr, 128)
			set_zbyte(_font_height_units_addr, 6)
			set_zbyte(_font_width_units_addr, 4)
			i_flag = 0x9c --sound fx and timed keyboard disabled
		else
			i_flag = 0x30 --for z4
		end

		if full_color == true then
			i_flag |= 0x01
			p_flag = 0x00c2
			set_zbyte(_default_bg_color_addr, 9)
			set_zbyte(_default_fg_color_addr, 2)
		end
	end
	set_zbyte(_interpreter_flags_header_addr, i_flag)
	set_zword(_peripherals_header_addr, p_flag)
	set_zword(_standard_revision_num_addr, 0x0101) --1.1 spec adherance

	_program_counter 		= zaddress_at_zaddress(_program_counter_header_addr)
	_dictionary_mem_addr 	= zaddress_at_zaddress(_dictionary_header_addr)
	_object_table_mem_addr 	= zaddress_at_zaddress(_object_table_header_addr)
	_global_var_table_mem_addr = zaddress_at_zaddress(_global_var_table_header_addr)
	_abbr_table_mem_addr 	= zaddress_at_zaddress(_abbr_table_header_addr)
	_static_memory_mem_addr = zaddress_at_zaddress(_static_memory_header_addr)
	_zobject_address 		= _object_table_mem_addr + (_zm_object_property_count>>>15)

	game_id = get_zword(_file_checksum_header_addr)
	-- log(tostr(game_id, 3))
	if (game_id == 0) game_id = _static_memory_mem_addr << 16
	-- log(tostr(_static_memory_mem_addr<<16, 3))
	game_id = tohex(game_id, false)
	-- log("checksum/game_id: "..game_id)

	--patches for specific games; just saving tokens by putting it here :/
	if (game_id == "16ab") set_zbyte(0x.fddd,1) --trinity, thanks @fredrick
	if (game_id == "4860" or game_id == "fc65") set_zbyte(_screen_width_header_addr, 40) --amfv, bur
end

function initialize_game()

	setup_palette()

	process_header()
	reset_io_state()
	setup_user_prefs()

	_main_dict = build_dictionary(_dictionary_mem_addr)

	call_stack_push()
	top_frame().pc = _program_counter
	top_frame().args = 0

	if (#_memory_start_state == 0) _memory_start_state = {unpack(_memory[1])}
	_erase_window(-1) --"the operation should happen at the start of a game"
	_set_text_style(0)
	update_text_colors()
	story_loaded = true

	cls(current_bg)
end
__gfx__
00000444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444400000
00044444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444000
00444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444400
04444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333444444444444444440
04444334444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444334444444444444440
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444444444444444
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444444444444444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344444444444444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344444444444444
44434444444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333334444444444344444444444444
44434444444333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333344444444344444444444444
44434444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333334444444344444444444444
44434444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333334444444344444444444444
444344444d5333333333330000000000000000000000000000000000000000000000000000000000000000000000333333333333333444444344444444444444
444344444d5533333331111111111111111111111111111111111111111111111111111111111111111111111111000003333333333444444344444444444444
444344444d5553333111111111111111111111111111111111111111111111111111111111111111111111111111111110033333333444444344444444444444
444344444d5555331111111111111111111111111111111111111111111111111111111111111111111111111111111111103333333444444344444444444444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344443333333344
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344446666666344
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344446668666344
444344444d5555111111111111111111111111111111111111111111111111111111111111111111111111111111111111111033333444444344446697f66344
444344444d5555111111177111111111111111111111111111111111111111111111111111111111111111111111111111111033333444444344446a777e6344
444344444d55551111111177111111111111111111111111111111111111111111111111111111111111111111111111111110333334444443444466b7d66344
444344444d555511111111177111111111111111111111111111111111111111111111111111111111111111111111111111103333344444434444666c666344
444344444d5551111111111177111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344446666666344
444344444d5551111111111117711111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111177111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111771111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111117777711111171111111111111111171111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771111111111111111771111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771111111111111111771111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111177777711117777111177777711177117711117777711111111111111111111111111111103333444444344444444444444
444344444d5551111111111777111111771111111117711111771111177117711177111771111111111111111111111111111103333444444344444444444444
444344444d5551111111111117711111771111117777711111771111177117711117771111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771111177117711111771111177117711111177711111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771771177117711111771771177117711177111771111111111111111111111111111103333444444344444444444444
444344444d5551111111117777711111177711117771771111177711117771771117777711111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111777777777111111111111111111111111111103333444444344444444444444
444344444d5551111111177771111111177111111111111111111111111111111771111177111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111177111111111111111111111111111111711777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111111111111111111111111111111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111777111177177711111777771111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111177111117711771117711177111111111777111177111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111177111117711771117777777111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711171111177111117711771117711111111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711771111177111117711771117711177111111111711777117111111111111111111111111111103333444444344444444444444
444344444d5551111111177777771111777711117711771111777771111111111771111177111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111777777777111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d555111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110333344444434444422dd44444
444344444d55511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111033334444443444422222d4444
444344444d555511111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333344444434440277752d444
444344444d555511111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333344444434450227772d444
444344444d5555111111111111111111111111111111111111111111111111111111111111111111111111111111111111111033333444444344502227722444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344502222722444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344550222225444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344555000054444
444344444d5555551111111111111111111111111111111111111111111111111111111111111111111111111111111111103333333444444344455555544444
444344444d5555555111111111111111111111111111111111111111111111111111111111111111111111111111111110033333333444444344445555444444
444344444d5555555555111111111111111111111111111111111111111111111111111111111111111111111111110005553333333444444344444444444444
444344444d5555555555555511111111111111111111111111111111111111111111111111111111111111111111105555555333333444444344444444444444
4443444444d55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555553333444444434444422dd44444
4443444444d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555533344444443444422222d4444
44434444444dd555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555534444444434440257752d444
4443444444444dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd444444444434450272272d444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344502722722444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344502577522444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344550222225444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344555000054444
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444455555544444
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444445555444444
44444334444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444334444444444444444
44444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
4444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444d222222222222244444444444444
444444444d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d334444444444444d555555555555244444444444444
044444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444444444445244444444444440
044444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444bbbbb4445244444444444440
004444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444444444445244444444444400
000444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444444444445244444444444000
000004444d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d034444444444444d000000000000244444444400000
__map__
0405060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070700000000070707000000000007050700000000000502050000000000050005000000000005050500000000040607060400000001030703010000000701010100000000000404040700000005070207020000000000020000000000000000000007000000000000000300000b0b0000000000000205020000000000
000000000000000004040200010000000a050000000000000a0e0a07050000000c060c07020000000a0806010500000006060c05070000000402000000000000080402020400000002040402010000000a040f020500000000040e0400000000000000040200000000000e000000000000000000040000000804040201000000
0c0a0905030000000c0604020700000006090402070000000608060403000000080a0907040000000e020c08070000000c020e09070000000e080402010000000c0a0f05030000000c0a0e0403000000000800040000000000080004030000000804020204000000000e00070000000002040402010000000e08040001000000
040a0a0106000000000e0505060000000402060503000000000c0201060000000808060503000000000c0e01060000000c02060201000000000c0a040300000004020605050000000800040202000000080004050200000004020a07050000000804040202000000000c0e0b0900000000060a0905000000000c0a0906000000
000c0a06010000000006050304000000000c020201000000000c020403000000040e020103000000000a090506000000000a0a0503000000000a090b07000000000a040205000000000a0a0403000000000e080207000000060202010300000001020202040000000c08040406000000040a0000000000000000000e00000000
0204000000000000080c0a0f090000000c0a0609070000000c0a010106000000060a0909070000000c020601070000000c020601010000000c02010d06000000020a0e09050000000e040202070000000c08080503000000020a06050500000004020201070000000c0e0b0905000000060a0909050000000c0a090503000000
0c0a06010100000006090506040000000c0a0605050000000c020408070000000e040202010000000209090d06000000020a0a060200000002090b0f060000000a04020505000000080a0604030000000e080402070000000c04070206000000040402020200000006040e02030000000008060100000000040a040000000000
000000000000000006060600060000000b0b0000000000000b0f0b0f0b0000000f070e0f060000000d0c06030b00000007070c090f00000006030000000000000603030306000000060c0c0c0600000009060f060900000000060f06000000000000000603000000000007000000000000000000060000000c06060603000000
060d0d0d06000000060706060f000000060d0c030f000000070c0e0c070000000c0e0d0f0c0000000f030f0c0700000006030f0b060000000f0c0e06060000000e0b0f0b06000000060d0f0c06000000000600060000000000060006030000000c0603060c000000000f000f0000000003060c06030000000f0c0e0006000000
060b0b030e000000000e0b0b0e00000001070b0b07000000000e03030e000000080e0b0b0e00000000060f030e0000000c060f06060000000006090e070000000303070b0b00000006000f060f0000000c000c0d06000000030b070b0b000000070606060e00000000070f0b0900000000070b0b0b00000000060b0b06000000
00070b070300000000060b070e000000000b070303000000000e030c07000000060f06060c000000000b0b0b0e000000000b0b070300000000090b0f0e000000000b070e0d000000000b0b0c07000000000f0c030f0000000703030307000000030606060c0000000e0c0c0c0e000000060b0000000000000000000007000000
060c000000000000060b0f0b0b000000070b070b07000000060b030b06000000070b0b0b070000000f0307030f0000000f030703030000000e030b0b060000000b0b0f0b0b0000000f0606060f0000000e0c0c0d060000000b0b070b0b000000030303030f0000000f0f0b09090000000b0f0f0d09000000060b0b0b06000000
070b0b0703000000060b0b070e000000070b0b070b0000000e030f0c070000000f060606060000000b0b0b0f0e0000000b0b0b070200000009090b0f0e0000000b0b060b0b0000000b0b0e0c070000000f0c06030f0000000e0607060e000000060606060600000007060e0607000000000c0f030000000000060b0600000000
