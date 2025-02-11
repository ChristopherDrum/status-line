# Status Line
A z-machine interpreter, written in Lua, for the Pico-8. 
The primary product page exists at itch.io
https://christopherdrum.itch.io/statusline

A set of modified Infocom games that work great with Status Line are in the companion repository, [Status Line Classics](https://github.com/ChristopherDrum/status-line-classics)

With v3.0 we support all z3, z4, z5, and z8 game files, including the following features:
- timed input support
- EGA-style color output
- completely redesigned bold and italic fonts
- slightly faster processing compared to Status Line 2
- game file import up to 512K with the help of...
- ...Status Line SPLIT. Local-only web app for cutting large files into 2 pieces.

Exporting the project to a standalone .p8.png or system executable requires processing this code in shrinko8.
https://thisismypassport.github.io/shrinko8/