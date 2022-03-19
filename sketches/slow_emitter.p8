pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
text = {
"planetfall",
"infocom interactive fiction - a",
"science fiction story",
"copyright (c) 1983 by infocom,",
"inc. all rights reserved.",
"planetfall is a registered trad",
"emark of infocom, inc.",
"release 39 / serial number 8805",
"",
"another routine day of drudgery",
"aboard the stellar patrol ship ",
"feinstein. this morning's assig",
"nment for a certain lowly ensig",
"n seventh class: scrubbing the ",
"filthy metal deck at the port e",
"nd of level nine. with your pat",
"rol-issue self-contained multi-",
"purpose all-weather scrub brush",
"19 >> you shine the floor with a dili",
"gence born of the knowledge tha",
"t at any moment dreaded ensign ",
"first class blather, the bane o",
"f your shipboard existence, cou",
"ld appear.",
"",
"deck nine",
"this is a featureless corridor ",
"similar to every other corridor",
"on the ship. it curves away to ",
"starboard, and a gangway leads ",
"up. to port is the entrance to ",
"one of the ship's primary escap",
"e pods. the pod bulkhead is clo",
"sed."
}

max_lines = 20
emit_rate = 100 --??? framecount per emit?
frame_count = 0
emitted_lines = 0

function _init()
	poke(0x5f2d, 1)
	cls()
end

local function emit_text()
	
	cursor(0,120)
	local pause = #text > max_lines
	for i = 1, #text do
		print(text[i])
		frame_count += 1
		emitted_lines += 1
		while frame_count < emit_rate do
			flip()
			frame_count += 1
		end
		
		if (pause == true) and (i % (max_lines-1) == 0) then
			print("█ more █")
			local keypress = stat(31)
			while (keypress == '') keypress = stat(31) flip()
			emitted_lines = 0
		end
		frame_count = 0
	end
end

function _update60()
	emit_text()
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
