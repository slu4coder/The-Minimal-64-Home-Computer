This is a 'Java/Processing' 3.5.4 version of the 'Minimal 64 Home Computer' emulator.
Since 'Processing' is available on almost any platform, this should solve any portability issues.
It is also straight-forward to customize the keyboard layout (see explanation in the source code).

The emulator is using German keyboard layout. For customizing I suggest:

o Insert the the following into the 'keyPressed()' function: println(key, key == CODED, keyCode);
o Press and note key codes as shown in the console window.
o Identify corresponding PS2 scan codes in the provided map 'PS2_Scancodes_Set_2.png'.
o Update the pre-defined 'keyScancodePairs' entries.

NOTE: Please use Processing version 3.5.4 and not Processing 4.x to run this program. The reason being that
with version 4.x a bug in Processing's keyboard detection under the P2D renderer does not allow to distinguish
between SHIFT and PAGE_UP. I have filed a bug report.

Have fun!
