This is a 'Java/Processing' version of the 'Minimal 64 Home Computer' emulator.
Since 'Processing' is available on almost any platform, this should solve any portability issues.
It is also straight-forward to customize the keyboard layout (see explanation in the source code).

The emulator is using German keyboard layout. For customizing I suggest:

o Insert the the following into the 'keyPressed()' function: println(key, key == CODED, keyCode);
o Press and note key codes as shown in the console window.
o Identify corresponding PS2 scan codes in the provided map 'PS2_Scancodes_Set_2.png'.
o Update 'ps2ScanCodes' entries in the 'setup()' function.

Have fun!
