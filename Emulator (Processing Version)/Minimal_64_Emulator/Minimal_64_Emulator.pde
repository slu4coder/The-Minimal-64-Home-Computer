// -----------------------------------------------------------------------------------------------------
// 'MINIMAL 64 Home Computer' emulator written by Carsten Herting (slu4) 2023, last update Apr 11th 2023
// -----------------------------------------------------------------------------------------------------

final int screenWidth = 1024;          // set the screen width (original size is 400 x 240 pixels)

// function keys used by the emulator
final int KEYCODE_F12 = 108;           // QUIT
final int KEYCODE_F11 = 107;           // RESET
final int KEYCODE_F10 = 106;           // PASTE clipboard data as serial input

import java.awt.Toolkit; // for clipboard access
import java.awt.datatransfer.*; // for clipboard access
import java.util.HashMap; // for PS2 code hash maps

HashMap<Integer, byte[]> ps2ScanCodes = new HashMap<Integer, byte[]>();
boolean[] keyPressedStates = new boolean[0x100]; // remember state of all keys (for repeat handling)
long[] keyPressedTimestamps = new long[0x100]; // timestamps of keypresses
ArrayList<Byte> serialInput = new ArrayList<Byte>();
ArrayList<Byte> ps2Input = new ArrayList<Byte>();
int serialWaitClocks=0, ps2WaitClocks=0; // emulates the speed of a PS2 or serial sender
int haveClocks=0; // number of cycles to be simulated
int flashState=0; // determines the state of a write operation to FLASH (see SSF39 datasheet)

byte[] mFlash; byte[] mRam = new byte[0x10000]; // memory of the CPU
int mBank=0, mA=0, mFlags=0, mPC=0; // register states of the CPU

final int FLAG_Z = 1; // zero flag
final int FLAG_C = 2; // carry flag
final int FLAG_N = 4; // negative flag

final int[] clocksPerInstruction = { // clock cycles used per instruction
  16, 4, 4, 6, 5, 5, 4, 6, 6, 5, 5, 5, 5, 5, 6, 7, 8, 9, 10, 11, 13, 5, 6, 7, 8, 9, 10, 11, 12, 5, 5, 5,
  5, 5, 5, 5, 5, 12, 5, 7, 7, 8, 8, 8, 8, 8, 8, 8, 15, 8, 10, 10, 11, 11, 11, 11, 11, 11, 11, 8, 9, 9, 9, 9,
  8, 9, 8, 9, 8, 8, 8, 8, 8, 8, 9, 11, 11, 11, 12, 11, 12, 11, 12, 10, 10, 14, 12, 11, 7, 8, 15, 5, 5, 5, 5, 5,  
  5, 5, 5, 6, 6, 7, 7, 10, 13, 7, 7, 7, 7, 7, 7, 7, 13, 7, 7, 10, 8, 11, 14, 8, 8, 8, 8, 8, 8, 8, 14, 6 };

// -------------------------------------------------------------------------------------------------

void settings() { size(screenWidth, screenWidth*240/400, P2D); }

void setup()
{
  if ((mFlash = loadBytes("flash.bin")) == null || mFlash.length != 0x80000) exit(); // load the flash.bin image into FLASH
  surface.setTitle("Minimal 64 Emulator - F12: QUIT, F11: RESET, F10: PASTE clipboard data as serial input.");

  ps2ScanCodes.put((int)'A', new byte[] {(byte)0x1C});  // init PS2 scan codes to be emitted (german keyboard layout)
  ps2ScanCodes.put((int)'B', new byte[] {(byte)0x32});
  ps2ScanCodes.put((int)'C', new byte[] {(byte)0x21});
  ps2ScanCodes.put((int)'D', new byte[] {(byte)0x23});
  ps2ScanCodes.put((int)'E', new byte[] {(byte)0x24});
  ps2ScanCodes.put((int)'F', new byte[] {(byte)0x2B});
  ps2ScanCodes.put((int)'G', new byte[] {(byte)0x34});
  ps2ScanCodes.put((int)'H', new byte[] {(byte)0x33});
  ps2ScanCodes.put((int)'I', new byte[] {(byte)0x43});
  ps2ScanCodes.put((int)'J', new byte[] {(byte)0x3B});
  ps2ScanCodes.put((int)'K', new byte[] {(byte)0x42});
  ps2ScanCodes.put((int)'L', new byte[] {(byte)0x4B});
  ps2ScanCodes.put((int)'M', new byte[] {(byte)0x3A});
  ps2ScanCodes.put((int)'N', new byte[] {(byte)0x31});
  ps2ScanCodes.put((int)'O', new byte[] {(byte)0x44});
  ps2ScanCodes.put((int)'P', new byte[] {(byte)0x4D});
  ps2ScanCodes.put((int)'Q', new byte[] {(byte)0x15});
  ps2ScanCodes.put((int)'R', new byte[] {(byte)0x2D});
  ps2ScanCodes.put((int)'S', new byte[] {(byte)0x1B});
  ps2ScanCodes.put((int)'T', new byte[] {(byte)0x2C});
  ps2ScanCodes.put((int)'U', new byte[] {(byte)0x3C});
  ps2ScanCodes.put((int)'V', new byte[] {(byte)0x2A});
  ps2ScanCodes.put((int)'W', new byte[] {(byte)0x1D});
  ps2ScanCodes.put((int)'X', new byte[] {(byte)0x22});
  ps2ScanCodes.put((int)'Y', new byte[] {(byte)0x35});
  ps2ScanCodes.put((int)'Z', new byte[] {(byte)0x1A});
  ps2ScanCodes.put((int)'0', new byte[] {(byte)0x45});
  ps2ScanCodes.put((int)'1', new byte[] {(byte)0x16});
  ps2ScanCodes.put((int)'2', new byte[] {(byte)0x1E});
  ps2ScanCodes.put((int)'3', new byte[] {(byte)0x26});
  ps2ScanCodes.put((int)'4', new byte[] {(byte)0x25});
  ps2ScanCodes.put((int)'5', new byte[] {(byte)0x2E});
  ps2ScanCodes.put((int)'6', new byte[] {(byte)0x36});
  ps2ScanCodes.put((int)'7', new byte[] {(byte)0x3D});
  ps2ScanCodes.put((int)'8', new byte[] {(byte)0x3E});
  ps2ScanCodes.put((int)'9', new byte[] {(byte)0x46});  
  ps2ScanCodes.put((int)' ', new byte[] {(byte)0x29});
  ps2ScanCodes.put((int)ENTER, new byte[] {(byte)0x5A});
  ps2ScanCodes.put((int)ESC, new byte[] {(byte)0x76});
  ps2ScanCodes.put((int)TAB, new byte[] {(byte)0x0D});
  ps2ScanCodes.put((int)java.awt.event.KeyEvent.VK_BACK_SPACE, new byte[] {(byte)0x66});
  ps2ScanCodes.put((int)java.awt.event.KeyEvent.VK_DELETE, new byte[] {(byte)0xE0, (byte)0x71});
  ps2ScanCodes.put((int)java.awt.event.KeyEvent.VK_UP, new byte[] {(byte)0xE0, (byte)0x75});
  ps2ScanCodes.put((int)java.awt.event.KeyEvent.VK_DOWN, new byte[] {(byte)0xE0, (byte)0x72});
  ps2ScanCodes.put((int)java.awt.event.KeyEvent.VK_LEFT, new byte[] {(byte)0xE0, (byte)0x6B});
  ps2ScanCodes.put((int)java.awt.event.KeyEvent.VK_RIGHT, new byte[] {(byte)0xE0, (byte)0x74});
  ps2ScanCodes.put(2, new byte[] {(byte)0xE0, (byte)0x6C}); // HOME (POS1)
  ps2ScanCodes.put(3, new byte[] {(byte)0xE0, (byte)0x69}); // END
  ps2ScanCodes.put(16, new byte[] {(byte)0xE0, (byte)0x7D}); // PAGE_UP
  ps2ScanCodes.put(11, new byte[] {(byte)0xE0, (byte)0x7A}); // PAGE_DOWN
  ps2ScanCodes.put((int)',', new byte[] {(byte)0x41}); // COMMA
  ps2ScanCodes.put((int)'.', new byte[] {(byte)0x49}); // DECIMAL
  ps2ScanCodes.put(47, new byte[] {(byte)0x4A}); // MINUS
  ps2ScanCodes.put(92, new byte[] {(byte)0x5D}); // HASH
  ps2ScanCodes.put(93, new byte[] {(byte)0x5B}); // PLUS
  ps2ScanCodes.put(0, new byte[] {(byte)0x61}); // LESS/GREATER/PIPE
  ps2ScanCodes.put(45, new byte[] {(byte)0x4E}); // BACKSLASH  
  ps2ScanCodes.put(96, new byte[] {(byte)0x0E}); // POWER 
}

void draw()
{
  haveClocks += int(6000000/frameRate);
  
  while(haveClocks > 0) haveClocks -= DoInstruction(); // executes instruction and consumes number of clock cycles used
  
  PImage videoRam = new PImage(512, 252); // video RAM
  int videoAddress = 0xc000; // start of first row
  for(int i=0; i<512*252; i+=8) // 64 bytes per row, 252 rows
  {
    byte b = mRam[videoAddress++]; // fetch next byte of VRAM    
    for(int j=0; j<8; j++) { videoRam.pixels[i+j] = (b & 1) == 1 ? 0xffb0ffb0 : 0xff282828; b>>=1; }
  }
  videoRam.updatePixels();
  
  image(videoRam.get(96, 12, 400, 240), 0, 0, width, height); // only project the visible area of VRAM onto the canvas

  if (keyPressed) handleKeyRepeat();
}

// -------------------------------------------------------------------------------------------------

void keyReleased() // handle key release event
{
  keyPressedStates[keyCode & 0xff] = false;
  convertKeyCodeToPS2(false);
}

void keyPressed() // handle keypress event
{
  switch(keyCode)
  {
    case KEYCODE_F12: saveBytes("flash.bin", mFlash); exit(); // EXIT
    case KEYCODE_F11: mPC = 0; mBank = 0; break; // RESET
    case KEYCODE_F10: // PASTE clipboard data as serial input
    {
      java.awt.datatransfer.Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard(); // Get the system clipboard
      if (clipboard.isDataFlavorAvailable(DataFlavor.stringFlavor)) // Check if the clipboard contains text
      {
        try
        {
          String str = (String) clipboard.getData(DataFlavor.stringFlavor); // Get the text data from the clipboard
          for(byte b : str.getBytes()) serialInput.add(b);
        } 
        catch (UnsupportedFlavorException e) {} 
        catch (IOException e) {}
      }
      break;
    }
    default: // convert keypresses to PS2 input
      keyPressedStates[keyCode & 0xff] = true; // note the changed state of the key
      keyPressedTimestamps[keyCode & 0xff] = millis(); // note the timestamp the key was pressed
      convertKeyCodeToPS2(true);
      break;
  }
  
  if (key == 27) key = 0; // disable Processing's ESC function
}

void handleKeyRepeat()
{
  long currentTime = millis();
  for (int i = 0; i < keyPressedStates.length; i++)
  {
    if (keyPressedStates[i] && currentTime - keyPressedTimestamps[i] > 260) // delayTime
    {
      keyPressedTimestamps[i] = currentTime - 260 + 60; // - delayTime + repeatTime
      keyCode = i; convertKeyCodeToPS2(true); // simulate a repeating key
    }
  }
}

void convertKeyCodeToPS2(boolean isPressed) // convert Processing's keyCodes/key into PS2 scancodes
{   
  if (isPressed == false) ps2Input.add((byte)(0xf0)); // emit PS2 'release' scancode before emitting actual key scan codes
  
  if (keyCode == SHIFT && key == CODED) { ps2Input.add((byte)(0x12)); return; } // handle special keys SHIFT, CTRL, ALT, ALTGR first
  else if (keyCode == CONTROL && key == CODED) { ps2Input.add((byte)(0x14)); return; }
  else if (keyCode == ALT && key == CODED) { ps2Input.add((byte)(0x11)); return; }
  else if (keyCode == 19 && key != CODED) { ps2Input.add((byte)(0x11)); return; }
  else // emit PS2 scan codes for all other keys
  {
    byte[] scanCode = ps2ScanCodes.get(keyCode);
    if (scanCode != null) for (byte c : scanCode) ps2Input.add(c);
  }
}

// -------------------------------------------------------------------------------------------------

int ReadMem(int at) // reads a byte from memory (either FLASH or RAM)
{
  if (((mBank & 0x80) != 0) || ((at & 0xf000) != 0)) return (int)(mRam[at & 0xffff]) & 0xff;
  else return (int)(mFlash[(mBank<<12) | (at & 0x0fff)]) & 0xff;
}

void WriteMem(int b, int at) // writes a byte to memory (either FLASH or RAM), emulates FLASH behaviour according to SSF39 datasheet
{
  if (((mBank & 0x80) != 0) || ((at & 0xf000) != 0)) mRam[at & 0xffff] = (byte)(b); // RAM WRITE ACCESS
  else // FLASH WRITE ACCESS
  {
    int adr15 = ((mBank<<12) | (at & 0x0fff)) & 0x7fff;    // FLASH only needs 15 bits
    switch (flashState)
    {
      case 0: if (adr15 == 0x5555 && b == 0xaa) flashState = 1; else flashState = 0; break;
      case 1: if (adr15 == 0x2aaa && b == 0x55) flashState = 2; else flashState = 0; break;
      case 2:
        if (adr15 == 0x5555 && b == 0xa0) { flashState = 3; break; }
        if (adr15 == 0x5555 && b == 0x80) { flashState = 4; break; }
        flashState = 0; break;
      case 3: mFlash[(mBank<<12) | (at & 0x0fff)] &= (byte)(b); flashState = 0; break;    // write operation only writes 1->0, not 0->1
      case 4: if (adr15 == 0x5555 && b == 0xaa) flashState = 5; else flashState = 0; break;
      case 5: if (adr15 == 0x2aaa && b == 0x55) flashState = 6; else flashState = 0; break;
      case 6:
        for (int i=0; i<0x1000; i++) mFlash[(mBank<<12) | i] = (byte)(0xff);  // sector erase operation
        flashState = 0; break;
      default: flashState = 0; break;
    }
  }
}

void DoFlagZN(int a) // update the Z and N flag
{
  if ((a & 0xff) == 0) mFlags |= FLAG_Z; else mFlags &= ~FLAG_Z;
  if ((a & 0x80) != 0) mFlags |= FLAG_N; else mFlags &= ~FLAG_N;
}
void DoFlagCAdd(int a) { if ((a & 0xffffff00) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C; } // handle C during addition
void DoFlagCSub(int a) { if ((a & 0xffffff00) != 0) mFlags &= ~FLAG_C; else mFlags |= FLAG_C; } // handle C during subtraction
void DoFlagCLikeZ() { int c = (mFlags & FLAG_Z)<<1; mFlags = (mFlags & 5) | c; } // make C=Z
int TakeAddr() { int a = ReadMem(mPC++); a |= ReadMem(mPC++)<<8; return a; } // consume a 16-bit absolute address from program counter (mPC)
int GetAddr(int adr) { int a = ReadMem(adr++); a |= (ReadMem(adr++)<<8); return a; } // get a 16-bit relative address

// -------------------------------------------------------------------------------------------------

int DoInstruction() // handle all instructions
{
  int inst = ReadMem(mPC++); // fetch instruction at program counter
  switch(inst) // process the instruction
  {
    case 0: break; // NOP
    case 1: mBank = mA; break; // BNK
    case 2: mBank = 0xff; break; // BFF
    case 3: if (serialInput.size() == 0 && ps2Input.size() == 0) mPC--; break; // WIN
    case 4: // INP
      if (serialInput.size() > 0 && serialWaitClocks <= 0) { mA = serialInput.remove(0); serialWaitClocks = 264; }
      else mA = 0xff;
      break;
    case 5: // INK
      if (ps2Input.size() > 0 && ps2WaitClocks <= 0) { mA = ps2Input.remove(0); ps2WaitClocks = 5400; }
      else mA = 0xff;
      break;
    case 6: print((char)(mA)); break; // OUT
    case 7: mA = (~mA) & 0xff; break; // NOT
    case 8:  // NEG
      mA = (-mA) & 0xff;
      DoFlagZN(mA);
      DoFlagCLikeZ();
      break;
    case 9: // INC
      mA++;
      mA &= 0xff;
      DoFlagZN(mA);
      DoFlagCLikeZ();
      break;
    case 10: // DEC
      mA--; mA &= 0xff;
      if (mA == 0xff) mFlags &= ~FLAG_C; else mFlags |= FLAG_C;
      DoFlagZN(mA);
      break;
    case 11: mFlags &= ~FLAG_C; break; // CLC
    case 12: mFlags |= FLAG_C; break; // SEC
    case 13: case 14: case 15: case 16: case 17: case 18: case 19: // LSL, LL2-7
    {
      int a = mA<<(1 + inst - 13); // -LSL
      if ((a & 0x00000100) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      mA = a & 0xff;
      DoFlagZN(mA);
      break;
    }
    case 20: // LSR
    {
      if ((mA & 1) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      mA >>= 1; mA &= 0xff;
      mFlags &= ~FLAG_N;
      if (mA == 0) mFlags |= FLAG_Z; else mFlags &= ~FLAG_Z;
      break;
    }
    case 21: case 22: case 23: case 24: case 25: case 26: case 27: // ROL, RL2-7
    {
      for (int i=0; i<1 + inst - 21; i++) // -ROL
      {
        int a = mA<<1;
        if ((mFlags & FLAG_C) != 0) a |= 1;
        if ((a & 0x00000100) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
        mA = a & 0xff;
      }
      DoFlagZN(mA);
      break;
    }  
    case 28: // ROR
    {
      int a = mA & 0xff;
      if ((mFlags & FLAG_C) != 0) a |= 0x100;
      if ((a & 1) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      mA = ((a>>1) & 0xff);
      DoFlagZN(mA);
      break;
    }
    case 29: mA = ReadMem(mPC++); break; // LDI
    case 30: // ADI
    {
      int a = (mA & 0xff) + ReadMem(mPC++);
      mA = a & 0xff;
      DoFlagCAdd(a); DoFlagZN(mA);
      break;
    }
    case 31: // SBI
    {
      int a = mA - ReadMem(mPC++);
      mA = a & 0xff;
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 32: // ACI
    {
      int a = mA + ReadMem(mPC++);
      if ((mFlags & FLAG_C) != 0) a++;
      mA = a & 0xff;
      DoFlagCAdd(a); DoFlagZN(mA);
      break;
    }
    case 33: // SCI
    {
      int a = mA - ReadMem(mPC++);
      if ((mFlags & FLAG_C) == 0) a--;
      mA = a & 0xff;
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 34: // CPI
    {
      int a = mA - ReadMem(mPC++);
      DoFlagCSub(a);
      DoFlagZN(a);
      break;
    }
    case 35: mA &= ReadMem(mPC++); break; // ANI
    case 36: mA |= ReadMem(mPC++); break; // ORI
    case 37: mA ^= ReadMem(mPC++); break; // XRI
    case 38: mPC = TakeAddr(); break; // JPA
    case 39: mA = ReadMem(TakeAddr()); break; // LDA
    case 40: WriteMem(mA, TakeAddr()); break; // STA
    case 41: // ADA
    {
      int a = mA + ReadMem(TakeAddr());
      mA = a & 0xff;
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 42: // SBA
    {
      int a = mA - ReadMem(TakeAddr());
      mA = a & 0xff;
      DoFlagCSub(a); DoFlagZN(mA);
      break;
    }
    case 43: // ACA
    {
      int a = mA + ReadMem(TakeAddr());
      if ((mFlags & FLAG_C) != 0) a++;
      mA = a & 0xff;
      DoFlagCAdd(a); DoFlagZN(mA);
      break;
    }
    case 44: // SCA
    {
      int a = mA - ReadMem(TakeAddr());
      if ((mFlags & FLAG_C) == 0) a--;
      mA = a & 0xff;
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 45: // CPA
    {
      int a = mA - ReadMem(TakeAddr());
      DoFlagCSub(a);
      DoFlagZN(a);
      break;
    }
    case 46: mA &= ReadMem(TakeAddr()); break; // ANA
    case 47: mA |= ReadMem(TakeAddr()); break; // ORA
    case 48: mA ^= ReadMem(TakeAddr()); break; // XRA
    case 49: mPC = GetAddr(TakeAddr()); break; // JPR
    case 50: mA = ReadMem(GetAddr(TakeAddr())); break; // LDR
    case 51: WriteMem(mA, GetAddr(TakeAddr())); break; // STR
    case 52: // ADR
    {
      int a = mA + ReadMem(GetAddr(TakeAddr()));
      mA = a & 0xff;
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 53: // SBR
    {
      int a = mA - ReadMem(GetAddr(TakeAddr()));
      mA = a & 0xff;
      DoFlagCSub(a); DoFlagZN(mA);
      break;
    }
    case 54: // ACR
    {
      int a = mA + ReadMem(GetAddr(TakeAddr()));
      if ((mFlags & FLAG_C) != 0) a++;
      mA = a & 0xff;
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 55: // SCR
    {
      int a = (mA & 0xff) - ReadMem(GetAddr(TakeAddr()));
      if ((mFlags & FLAG_C) == 0) a--;
      mA = a & 0xff;
      DoFlagCSub(a); DoFlagZN(mA);
      break;
    }
    case 56: // CPR
    {
      int a = mA - ReadMem(GetAddr(TakeAddr()));
      DoFlagCSub(a);
      DoFlagZN(a);
      break;
    }
    case 57: mA &= ReadMem(GetAddr(TakeAddr())); break; // ANR
    case 58: mA |= ReadMem(GetAddr(TakeAddr())); break; // ORR
    case 59: WriteMem(0, TakeAddr()); break; // CLB
    case 60: // NOB
    {
      int adr = TakeAddr();
      mA = ~ReadMem(adr);
      WriteMem(mA, adr);
      break;
    }
    case 61: // NEB
    {
      int adr = TakeAddr();
      int a = -ReadMem(adr);
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagZN(mA); DoFlagCLikeZ();
      break;
    }
    case 62: // INB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr) + 1;
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 63: // DEB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr) - 1;
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagCSub(a); DoFlagZN(mA);
      break;
    }
    case 64: // ADB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr) + mA;
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 65: // SBB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr) - mA;
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagCSub(a); DoFlagZN(mA);
      break;
    }
    case 66: // ACB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr) + mA;
      if ((mFlags & FLAG_C) != 0) a++;
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 67: // SCB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr) - mA;
      if ((mFlags & FLAG_C) == 0) a--;
      mA = a & 0xff;
      WriteMem(mA, adr);
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 68: // ANB
    {
      int adr = TakeAddr();
      mA &= ReadMem(adr);
      WriteMem(mA, adr);
      break;
    }
    case 69: // ORB
    {
      int adr = TakeAddr();
      mA |= ReadMem(adr);
      WriteMem(mA, adr);
      break;
    }
    case 70: // LLB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr)<<1;
      mA = a & 0xff;
      WriteMem(mA, adr);
      if ((a & 0x00000100) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 71: // LRB
    {
      int adr = TakeAddr();
      mA = ReadMem(adr);
      if ((mA & 1) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      mA = ((mA & 0xff)>>1); mFlags &= ~FLAG_N;
      if (mA == 0) mFlags |= FLAG_Z; else mFlags &= ~FLAG_Z;
      WriteMem(mA, adr);
      break;
    }
    case 72: // RLB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr)<<1;
      if ((mFlags & FLAG_C) != 0) a |= 1;
      mA = a & 0xff;
      WriteMem(mA, adr);
      if ((a & 0x00000100) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }  
    case 73: // RRB
    {
      int adr = TakeAddr();
      int a = ReadMem(adr);
      if ((mFlags & FLAG_C) != 0) a |= 0x100;
      mA = ((a>>1) & 0xff);
      WriteMem(mA, adr);
      if ((a & 1) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 74: // CLW
    {
      int adr = TakeAddr();
      WriteMem(0, adr);
      WriteMem(0, adr+1);
      break;
    }
    case 75: // NOW
    {
      int adr = TakeAddr();
      int a = ~ReadMem(adr);
      mA = (~ReadMem(adr+1)) & 0xff;
      WriteMem(a, adr);
      WriteMem(mA, adr+1);
      break;
    }
    case 76: // NEW
    {
      int adr = TakeAddr();
      int a = -((ReadMem(adr+1)<<8) | ReadMem(adr));
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1);
      WriteMem(a & 0xff, adr);
      DoFlagZN(mA);
      DoFlagCLikeZ();
      break;
    }
    case 77: // INW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr)) + 1;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1);
      WriteMem(a & 0xff, adr);
      if ((a & 0xffff0000) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 78: // DEW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr)) - 1;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1);
      WriteMem(a & 0xff, adr);
      if ((a & 0xffff0000) != 0) mFlags &= ~FLAG_C; else mFlags |= FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 79: // ADW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr)) + mA;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1); WriteMem(a & 0xff, adr);
      if ((a & 0xffff0000) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 80: // SBW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr)) - mA;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1); WriteMem(a & 0xff, adr);
      if ((a & 0xffff0000) != 0) mFlags &= ~FLAG_C; else mFlags |= FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 81: // ACW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr)) + mA;
      if ((mFlags & FLAG_C) != 0) a++;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1); WriteMem(a & 0xff, adr);
      if ((a & 0xffff0000) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 82: // SCW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr)) - mA;
      if ((mFlags & FLAG_C) == 0) a--;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1);
      WriteMem(a & 0xff, adr);
      if ((a & 0xffff0000) != 0) mFlags &= ~FLAG_C; else mFlags |= FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 83: // LLW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr))<<1;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1); WriteMem(a & 0xff, adr);
      if ((a & 0x00010000) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 84: // RLW
    {
      int adr = TakeAddr();
      int a = ((ReadMem(adr+1)<<8) | ReadMem(adr))<<1;
      if ((mFlags & FLAG_C) != 0) a |= 1;
      mA = (a>>8) & 0xff;
      WriteMem(mA, adr+1); WriteMem(a & 0xff, adr);
      if ((a & 0x00010000) != 0) mFlags |= FLAG_C; else mFlags &= ~FLAG_C;
      DoFlagZN(mA);
      break;
    }
    case 85: // JPS
    { 
      mA = 0; // devalidate A register
      int ret = mPC; // return address - 2 is put onto the stack
      int pc = TakeAddr();
      int sp = ReadMem(0xffff);
      WriteMem(ret, 0xff00 | sp);
      WriteMem(ret>>8, 0xff00 | (sp-1));
      WriteMem(sp-2, 0xffff);
      mPC = pc;
      break;
    }
    case 86: // RTS
    {
      int sp = ReadMem(0xffff);
      mPC = ReadMem(0xff00 | (sp+1))<<8;
      mPC |= ReadMem(0xff00 | (sp+2));
      mPC += 2; // return address - 2 was put onto the stack
      WriteMem(sp+2, 0xffff);
      break;
    }
    case 87: // PHS
    {
      int sp = ReadMem(0xffff);
      WriteMem(mA, 0xff00 | sp);
      WriteMem(sp-1, 0xffff);
      break;
    }
    case 88: // PLS
    {
      int sp = ReadMem(0xffff);
      mA = ReadMem(0xff00 | sp+1) & 0xff;
      WriteMem(sp+1, 0xffff);
      break;
    }
    case 89: // LDS
    {
      int sp = ReadMem(0xffff) + ReadMem(mPC++);
      mA = ReadMem(0xff00 | sp);
      break;
    }
    case 90: // STS
    {
      int sp = ReadMem(0xffff) + ReadMem(mPC++);
      WriteMem(mA, 0xff00 | sp);
      break;
    }
    case 91: // BNE
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_Z) == 0) mPC = pc;
      break;
    }
    case 92: // BEQ
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_Z) != 0) mPC = pc;
      break;
    }
    case 93: // BCC
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_C) == 0) mPC = pc;
      break;
    }
    case 94: // BCS
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_C) != 0) mPC = pc;
      break;
    }
    case 95: // BPL
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_N) == 0) mPC = pc;
      break;
    }
    case 96: // BMI
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_N) != 0) mPC = pc;
      break;
    }
    case 97: // BGT
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_C) != 0 && (mFlags & FLAG_Z) == 0) mPC = pc;
      break;
    }
    case 98: // BLE
    {
      int pc = TakeAddr();
      if ((mFlags & FLAG_C) == 0 || (mFlags & FLAG_Z) != 0) mPC = pc;
      break;
    }
    case 99: WriteMem(mA, 0xff00); break; // TAX
    case 100: mA = ReadMem(0xff00); break; // TXA
    case 101: WriteMem(ReadMem(0xff00), 0xff01); break; // TXY
    case 102: WriteMem(ReadMem(mPC++), 0xff00); break; // LXI
    case 103: // LXA
    {
      int adr = TakeAddr();
      WriteMem(ReadMem(adr), 0xff00);
      break;
    }
    case 104: mA = ReadMem(TakeAddr() + ReadMem(0xff00)); break; // LAX
    case 105: // INX
    {
      int a = ReadMem(0xff00) + 1;
      mA = a & 0xff;
      WriteMem(mA, 0xff00);
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 106: // DEX
    {
      int a = ReadMem(0xff00) - 1;
      mA = a & 0xff;
      WriteMem(mA, 0xff00);
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 107: // ADX
    {
      int a = (mA & 0xff) + ReadMem(0xff00);
      mA = a & 0xff;
      DoFlagCAdd(a); DoFlagZN(mA);
      break;
    }
    case 108: // SBX
    {
      int a = mA - ReadMem(0xff00);
      mA = a & 0xff;
      DoFlagCSub(a); DoFlagZN(mA);
      break;
    }
    case 109: // CPX
    {
      int a = mA - ReadMem(0xff00);
      DoFlagCSub(a);
      DoFlagZN(a);
      break;
    }
    case 110: mA &= ReadMem(0xff00); break; // ANX
    case 111: mA |= ReadMem(0xff00); break; // ORX
    case 112: mA ^= ReadMem(0xff00); break; // XRX
    case 113: WriteMem(mA, 0xff01); break; // TAY
    case 114: mA = ReadMem(0xff01); break; // TYA
    case 115: WriteMem(ReadMem(0xff01), 0xff00); break; // TYX
    case 116: WriteMem(ReadMem(mPC++), 0xff01); break; // LYI
    case 117: // LYA
    {
      int adr = TakeAddr();
      WriteMem(ReadMem(adr), 0xff01);
      break;
    }
    case 118: mA = ReadMem(TakeAddr() + ReadMem(0xff01)); break; // LAY
    case 119: // INY
    {
      int a = ReadMem(0xff01) + 1;
      mA = a & 0xff;
      WriteMem(mA, 0xff01);
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 120: // DEY
    {
      int a = ReadMem(0xff01) - 1;
      mA = a & 0xff;
      WriteMem(mA, 0xff01);
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 121: // ADY
    {
      int a = mA + ReadMem(0xff01);
      mA = a & 0xff;
      DoFlagCAdd(a);
      DoFlagZN(mA);
      break;
    }
    case 122: // SBY
    {
      int a = mA - ReadMem(0xff01);
      mA = a & 0xff;
      DoFlagCSub(a);
      DoFlagZN(mA);
      break;
    }
    case 123: // CPY
    {
      int a = mA - ReadMem(0xff01);
      DoFlagCSub(a);
      DoFlagZN(a);
      break;
    }
    case 124: mA &= ReadMem(0xff01); break; // ANY
    case 125: mA |= ReadMem(0xff01); break; // ORY
    case 126: mA ^= ReadMem(0xff01); break; // XRY
    case 127: mPC--; break; // HLT
    default:;
  }

  int cpi = clocksPerInstruction[inst];
  if (serialWaitClocks > 0) serialWaitClocks -= cpi;
  if (ps2WaitClocks > 0) ps2WaitClocks -= cpi;

  return cpi; // return the number of clocks the instruction is taking
}

/*
 LICENSING INFORMATION
 This file is free software: you can redistribute it and/or modify it under the terms of the
 GNU General Public License as published by the Free Software Foundation, either
 version 3 of the License, or (at your option) any later version.
 This file is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
 License for more details. You should have received a copy of the GNU General Public License along
 with this program. If not, see https://www.gnu.org/licenses/.  
*/