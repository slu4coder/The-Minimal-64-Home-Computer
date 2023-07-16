# Emulator (Java/Processing)

This is the portable 'Java/Processing' version of the 'Minimal 64 Home Computer' emulator.

The emulator is using German keyboard layout. For customizing do the following:

o Uncomment the first line of the 'keyPressed()' function in the source code: println(keyCode);

o Run the emulator and press any keys under question.

o Note the corresponding keyCodes printed out in Processing's console window.

o Identify the corresponding PS/2 scan codes (see section 'PS/2 Keyboard' in the 'Minimal 64 Reference Manual':
  https://docs.google.com/document/d/1e4hL9Z7BLIoUlErWgJOngnSMYLXjfnsZB9BtlwhTC6U/edit?usp=sharing

o Update the pre-defined 'keyScancodePairs' entries in the source code.

Have fun!
