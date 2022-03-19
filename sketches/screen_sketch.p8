pico-8 cartridge // http://www.pico-8.com
version 34
__lua__

zgame_version = 3
screen_mode = 'ega'
screen_width = 32
active_window = nil --the z-machine index, not the lua table index
current_bg = 0 --defaults (esp for monochrome) is set by the pal() in _init()
current_fg = 1
origin_y = (zgame_version == 3) and 8 or 0 -- 8 for v3, 0 for v4,v5
screen_height = (zgame_version == 3) and 20 or 21 --20 for v3, 21 for v4,v5

screen = {}
function set_window(zwin_num)
	active_window = screen[zwin_num+1]
end

function make_window(_y, _h)
	local window = {
		--upper left of window in 1-indexed char units
		x = 1, y = _y or 1,
		
		--width/height of window in char units
		w = screen_width, h = _h or screen_height,
		
		--position of cursor *relative to x,y*; can be offscreen
		cur_x = _x, cur_y = _y,
				
		--need to know what colors this window drew itself in
		-- fg = current_fg, bg = current_bg,

		--how do we obtain the addr for the newline routine?
		-- newline_addr = 0x0,
		--do we even need this newline count for our wrap func?
		-- newline_count = 0,
		
		--the style for next output
		font_style = 0,
		
		--not many options for us here
		font = 1,
		
		--height/width of font as defined above; here 1x1 
		style_hw = 0x11,
		
		--defaults for v1-4
		attributes = 0b00000000.00001010,

		buffer = {}
	}
	return window
end

function set_text_style(style)
	active_window.font_style = (style >= 1) and 1 or 0
end

function set_zcursor(lin, col)
	active_window.cur_x = col
	active_window.cur_y = lin
end

function cursor_px()
	local cx,cy = active_window.cur_x-1, active_window.cur_y-1
	local wx,wy = active_window.x-1, active_window.y-1

	local px = (wx+cx)<<2
	local py = (wy+cy)*6
	return px, origin_y + py
end

function erase_screen()
	rectfill(0,0,128,128,current_bg)
end

function erase_line(val)
	local px, py = cursor_px()
	rectfill(px,py,128, py+5, current_bg)
end

--z5 sets *both* windows, which really means the fg/bg are globals
function set_color(f, b)
	if (screen_mode == 'ega') then
		if (f >= 1 and f < 10) then
			current_fg = mid(1,f,9)
		-- elseif f == 1 then
		-- 	current_fg = default_fg
		-- elseif f == 255 then
			--I can't think of a reliable way to grab the "foreground color"
			--of any arbitrary character position. What if that position
			--contains a space? What if its just a '.'? Which pixel can we 100%
			--guarantee is available to sample with pget()?
			--None that I can think of. 
			--current_fg = cursor_fg 
		end --0 is the other option, we'll do nothing

		if (b > 1 and b < 255) then
			current_bg = mid(2,b,9)
		elseif b == 1 then
			current_bg = 0
		end

		-- for w in all(screen) do
		-- 	w.fg, w.bg = current_fg, current_bg
		-- end
	end
end

function screen_rect(select)
	local win
	if type(select) == 'table' then
		win = select
	else
		win = screen[select+1]
	end

	local px = (win.x-1)<<2
	local py = (win.y-1)*6
	local pw = win.w<<2
	local ph = (win.h)*6
	return {px, origin_y + py, pw, ph}
end

function buffer(str, zwin_num)

end

function output(str)
	if (str == '\n') then
		active_window.cur_y += 1
		active_window.cur_x = 1
		-- printh(active_window.cur_x..','..active_window.cur_y..','..active_window.y..','..active_window.h,'screen_sketch')
		-- if active_window.cur_y >= (active_window.y + active_window.h - 1) then
		-- 	scroll_window()
		-- 	active_window.cur_y -= 1
		-- end
	else
		clip(unpack(screen_rect(active_window)))
		local px, py = cursor_px()
		cursor(px,py,1)
		local c = '\#'..tostr(current_bg)..'\f'..tostr(current_fg)
		local s = (active_window.font_style > 0) and '\^i' or ''
		print(c..s..tostr(str)..'\^-i')
		active_window.cur_x += #str
		if (active_window.cur_x > active_window.w) then
			active_window.cur_x = 1
			active_window.cur_y += 1
		end
		cursor()
		clip()
	end
end

function erase_window(zwin_num)
	if zwin_num == -1 then
		split_win(0)
		erase_window(0)
	elseif zwin_num == -2 then
		erase_window(0)
		erase_window(1)
	else
		clip(unpack(screen_rect(zwin_num)))
		rectfill(0,0,128,128,current_bg)
		clip()
	end
end

--win is 0-indexed by the z-machine; 1-indexed by Lua
function split_window(lines)
	if (lines == 0) then --unsplit
		if (screen[2] != nil) then
			deli(screen, 2)
			screen[1].x = 1
			screen[2].y = 2
		end
	else
		if (#screen == 1) add(screen, make_window(screen[1].y, lines))
		erase_window(1) --which is index 2 in screen :shrug:
		screen[1].y += lines
		screen[1].h = screen_height - screen[1].y + 1
	end
end

function step()
	if (stat(110) > 0) stop()
end

--0default_bg, 1default_fg, 2black, 3red, 4green, 5yellow, 6blue, 7magenta, 8cyan, 9white
function setup_palette()
	pal()
	local zcolors = {0,6,0,8,139,10,140,136,12,7}
	for i = 1, #zcolors do
		pal(i-1, zcolors[i], 1)
	end
end

function scroll_window(num_lines, zwin_num)
	local num_lines = num_lines or 1
	local win = zwin_num and screen[zwin_num] or active_window
	local y = win.y - 1
	num_lines = min(num_lines, win.h)
	win.cur_y -= num_lines

	local dest = 0x6000 + (origin_y<<6) + ((y*6)<<6)
	local source = dest + ((num_lines*6)<<6)
	local length = 384*(win.h - num_lines)
	printh(num_lines..','..y..','..tostr(dest,true)..','..tostr(source,true)..','..length, 'screen_sketch')
	memcpy(dest, source, length)
	memset(dest+length,(current_bg<<4)+current_bg,384*num_lines)
end

-- function _init()
	poke(0x5f36,0x4)
	setup_palette()
	cls()
	add(screen, make_window())
	split_window(15)
	rectfill(0,0,127,6,current_fg)
	rectfill(0,120,127,128,current_fg)

	print('wEST OF hOUSE', 4, 1, 0)
-- end

-- function _draw()
	set_color(3,6)
	erase_window(1)
	set_window(1)
	set_zcursor(1,1)
	for i = 1, active_window.h do
		set_text_style(i%2)
		output('line '..i)
		output('\n')
	end
	scroll_window(3)
	scroll_window(4)
	output('now text goes here')
	
	set_color(8,5)
	set_window(0)
	erase_window(0)
	set_zcursor(1,1)
	for i = 1, active_window.h do
		output('line '..i)
		output('\n')
	end
	scroll_window(2)
	output('now text goes here')

	cursor(50,80)
-- end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
