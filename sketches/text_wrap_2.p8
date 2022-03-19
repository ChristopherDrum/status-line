pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
local phrase = "when in the course of human clue events it becomes necessary to take a thing seriously."


function in_set(char, set)
	for i = 1, #set do
		if (char == set[i]) return true
	end
	return false
end

--remove extraneous white space from player input
function strip(str)
	local words = split(str, ' ')
	local stripped = ''
	for i = 1, #words do
		local w = words[i]
		if (w != '') stripped ..= w..' '
	end
	if sub(stripped, -1) == ' ' then
		stripped = sub(stripped, 1, -2)
	end
	return stripped
end

function log(str)
	-- printh(str, 'wrapdebug')
end

line_buffer = nil --processed lines, waiting to be shown
local line_width = 32
local break_chars = {'\n', ' ', ':', '-', '_', ';'}
function buffer(str)
	if (line_buffer == nil) line_buffer = {''}
	local l = line_buffer[#line_buffer]

	local break_index = 99
	for i = 1 , #str do
		local char = sub(str,i,_)
		log('considering char: '..char)
		l ..= char
		log('  appended to l: '..l)
		if (in_set(char, break_chars)) break_index = #l
		if (break_index != 0) log('  >> break found at: '..break_index)

		local l2 = ''
		if #l > line_width then
			log('    >> line length: '..#l)
			log('    >> l2 break at: '..break_index-#l)
			if break_index < #l then
				l2 = sub(l,break_index-#l)
				if (ord(l,break_index) == 32) break_index -= 1
			end
			l = sub(l,1,break_index)
			log('        l: '..l)
			log('       l2: '..l2)
			line_buffer[#line_buffer] = l
			l = l2
			add(line_buffer, l)
			break_index = 99
		else
			line_buffer[#line_buffer] = l
		end
	end
end

buffer(phrase)
cls()
cursor(0,0)
for i = 1, #line_buffer do
	print(line_buffer[i])
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
