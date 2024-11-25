# Status Line
A z-machine interpreter, written in Lua, for the Pico-8. 
The primary product page exists at itch.io
https://christopherdrum.itch.io/statusline

A set of modified Infocom games that work great with Status Line are in the sibling repository, [Status Line Classics](https://github.com/ChristopherDrum/status-line-classics)

The project is getting more complex and needs proper version control from now. This repository begins with v2.0 of the source code which supports z3 and z4 game files.  Once v2.x feels stable, work will begin on v3.0 which will finalize this project by adding z5 (and likely z7/8) support.

v3.0 Notes

- Save/Restore files will not be compatible with previous versions (unless I have enough free tokens at the end to support dual-formats). I've replaced how the call stack works, organizing data into proper frame structures. The previous method of using synchronized call_stack and local stack tables was untenable. As well, we need to be able to support proper frame information, which includes new data points for z5 (and technically for z4 I think, though I was ignoring that information).
