# CHANGE LOG

Oct 28 2023: Microcode 1.22 update:

o The instruction LTX replaces LAX but remains functionally identical.

o The instruction LTA replaces LAY and now uses the accumulator A as table index rather than the Y register.

Nov 26 2023: Larger reserved memory range for expansion cards

The memory range reserved for expansion cards is extended to a full page 0xbf00 - 0xbfff. This involves changes in the documentation (reference manual, manual.txt) and also makes relocating some OS variables (e.g. cursor position _XPos and _YPos) necessary, forcing an update of all software using these variables ;-) as well as the "standard" flash.bin.

