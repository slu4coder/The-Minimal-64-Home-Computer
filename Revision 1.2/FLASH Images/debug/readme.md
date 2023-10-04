These FLASH images might by helpful to debug your board in case it won't start up properly.

'debug' writes a back and a white 8x8 pixel square into VRAM's upper left corner
        prior to starting the bootloader.
        This might show you a 'first sign of life' in case the OS doesn't boot.
'debug2' writes 0xff contiguously into VRAM starting from the left upper corner
         for each byte copied from FLASH to RAM during bootstrapping.
         This lets you monitor the boot process in case the OS doesn't boot.
