This is a 'Java/Processing 4' version of the 'Minimal 64 Home Computer' emulator.
Since 'Processing 4' is available on almost any platform, this should solve any portability issues.
It is also straight-forward to customize the keyboard layout (see explanation in the source code).

The emulator is using German keyboard layout. For customizing I suggest:

o Uncomment the first line of the 'keyPressed()' function: println(keyCode);
o Press and note Processing 4's keyCodes as shown in the console window.
o Identify the corresponding PS2 scan codes in the provided map 'PS2_Scancodes_Set_2.png'.
o Update the pre-defined 'keyScancodePairs' entries.

NOTE: Due to a bug in Processing's keyboard handler, the keys PAGE_UP and SHIFT share the same keyCode 16
on a German keyboard. As a work-around, I use the '´' key as PAGE_UP. I have filed a bug report.

Have fun!