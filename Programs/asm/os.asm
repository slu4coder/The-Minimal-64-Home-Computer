; ******************************************************************
; *****                                                        *****
; *****       MinOS 2.0 for the MINIMAL 64 Home Computer       *****
; *****                                                        *****
; ***** written by Carsten Herting - last update Apr 14th 2023 *****
; *****                                                        *****
; ******************************************************************

; LICENSING INFORMATION
; This file is free software: you can redistribute it and/or modify it under the terms of the
; GNU General Public License as published by the Free Software Foundation, either
; version 3 of the License, or (at your option) any later version.
; This file is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
; implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
; License for more details. You should have received a copy of the GNU General Public License along
; with this program. If not, see https://www.gnu.org/licenses/.

; HOW TO USE THIS CODE
; This file represents the sourcecode of the operating system 'MinOS 2' of the 'MINIMAL 64'.
; A HEX file of the OS code can be produced by typing 'asm os.asm'. This HEX file can be burned
; into the first 3 banks of the 512KB FLASH SSD ROM of the MINIMAL and will allow it to boot.
; In case a prior version of MinOS is already installed in your hardware, the OS can be updated
; 'in situ': Upload the HEX file into RAM 0x0000-0x2fff by typing 'receive ENTER' and pasting the
; HEX file into a terminal to the MINIMAL 64 via the UART interface. When the upload into RAM has
; completed, type 'flash ENTER' to copy the OS from RAM into FLASH banks 0-2. Upon pressing RESET,
; the new OS will start. Since only banks 0-2 are updated, user files will remain on the SSD.

; By default FLASH is deaktivated by the OS (BANK = 0xff) yielding contiguous RAM 0x0000-0xffff.
; Only during file access FLASH is activ.

; _<label> are API labels providing access to kernel functions & data via a jump table. They will not change.

; **********************************************************************************************************

#org 0x0000                                                    ; Bank 0, Address 0 = entry point after RESET

OS_Bootloader:  LDI <OS_Image_Start STA 0xfffc                 ; prepare OS image address at 0xfffc/d
                LDI >OS_Image_Start STA 0xfffd
                LDI <_Start STA 0xfffe                         ; prepare OS target address at 0xfffe/f
                LDI >_Start STA 0xffff

  imcopyloop:   LDR 0xfffc STR 0xfffe                          ; copy the OS image to RAM
                INW 0xfffc INW 0xfffe
                LDA 0xfffe CPI <OS_Image_End BNE imcopyloop    ; destination address beyond OS kernel?
                  LDA 0xffff CPI >OS_Image_End BCC imcopyloop

; **********************************************************************************************************

OS_Image_Start:                                                ; OS image starts HERE

  #mute                                                        ; do not emit origin address...
  #org 0xb000                                                  ; ... but assemble for this destination
  #emit                                                        ; begin emitting code here

  ; KERNEL JUMP TABLE
  _Start:         JPA OS_Start
  _Prompt:        JPA OS_Prompt
  _ReadLine:      JPA OS_ReadLine
  _ReadSpace:     JPA OS_ReadSpace
  _ReadHex:       JPA OS_ReadHex
  _SerialWait:    JPA OS_SerialWait
  _SerialPrint:   JPA OS_SerialPrint
  _FindFile:      JPA OS_FindFile
  _LoadFile:      JPA OS_LoadFile
  _SaveFile:      JPA OS_SaveFile
  _MemMove:       JPA OS_MemMove
  _Random:        JPA OS_Random
  _ScanPS2:       JPA OS_ScanPS2
  _ReadInput:     JPA OS_ReadInput
  _WaitInput:     JPA OS_WaitInput
  _ClearVRAM:     JPA OS_ClearVRAM
  _Clear:         JPA OS_Clear
  _ClearRow:      JPA OS_ClearRow
  _SetPixel:      JPA OS_SetPixel
  _ClrPixel:      JPA OS_ClrPixel
  _GetPixel:      JPA OS_GetPixel
  _Char:          JPA OS_Char
  _Line:          JPA OS_Line
  _Rect:          JPA OS_Rect
  _Print:         JPA OS_Print
  _PrintChar:     JPA OS_PrintChar
  _PrintHex:      JPA OS_PrintHex
  _ScrollUp:      JPA OS_ScrollUp
  _ScrollDn:      JPA OS_ScrollDn
  _ResetPS2:      JPA OS_ResetPS2

OS_Start:       LDI 0xfe STA 0xffff                            ; switch off FLASH and init stack

                LDI <uarttxt PHS LDI >uarttxt PHS              ; send start screen via UART
                JPS OS_SerialPrint PLS PLS

                JPS OS_ClearVRAM                               ; show VGA start screen
                JPS OS_Logo                                    ; show 'Minimal' logo
                LDI 15 STA _XPos LDI 1 STA _YPos               ; display splash screen text
                LDI <logotxt1 PHS LDI >logotxt1 PHS
                JPS OS_Print PLS PLS
                LDI 15 STA _XPos
                LDI <logotxt2 PHS LDI >logotxt2 PHS
                JPS OS_Print PLS PLS
                LDI 15 STA _XPos
                LDI <logotxt3 PHS LDI >logotxt3 PHS
                JPS OS_Print PLS PLS

  OS_Prompt:    BFF LDI 0xfe STA 0xffff                        ; re-init stack
                LDI <readytxt PHS LDI >readytxt PHS  ; display 'READY.'
                JPS OS_Print PLS PLS

  newline:      LDI <_ReadBuffer STA _ReadPtr+0                ; parse a line of user input
                LDI >_ReadBuffer STA _ReadPtr+1
                JPS OS_ReadLine                                ; MAIN LOOP: read in a line of user input
                JPS OS_ReadSpace                               ; omit leading spaces
                LDR _ReadPtr CPI 10 BEQ newline                ; empty line?
                  JPS OS_LoadFile CPI 0 BEQ OS_Error           ; load the file (=instruction)
                    JPR PtrD                                   ; run a loaded program with command line ptr on stack

  OS_Error:     LDI <errortxt PHS LDI >errortxt PHS JPS OS_Print
                JPA OS_Prompt

  uarttxt:      27, '[H', 27, '[J', 27, '[?25hREADY.', 10, 0   ; HOME, CLR, SHOW CURSOR
  readytxt:     'READY.', 10, 0
  errortxt:     '?FILE NOT FOUND.', 10, 0
  logotxt1:     '*****  M I N I M A L  6 4  *****', 10, 10, 0
  logotxt2:     '64KB RAM - 512KB SSD - MinOS 2.0', 10, 10, 0
  logotxt3:     'Type ', 39, 'show manual', 39, ' for more info', 10, 10, 0

; --------------------------------------------------
; Generates a pseudo-random byte in A
; --------------------------------------------------
OS_Random:      INB _RandomState+0          ; x++
                XRA _RandomState+1
                XRA _RandomState+3
                STA _RandomState+1          ; a = a^c^x
                ADB _RandomState+2          ; b = b+a
                LSR
                ADA _RandomState+3
                XRA _RandomState+1
                STA _RandomState+3          ; c = (c+(b>>1))^a)
                RTS                         ; return c in A

; --------------------------------------------------
; Moves N bytes from S.. to D.. taking overlap into account.
; push: D_lsb, D_msb, S_lsb, S_msb, N_lsb, N_msb
; Pull: #, #, #, #, #, #
; --------------------------------------------------
OS_MemMove:   LDS 3 STA PtrB+1 LDS 4 STA PtrB+0            ; B = number of bytes
              DEW PtrB BCC mc_done
              LDS 5 STA PtrA+1 LDS 6 STA PtrA+0            ; A = source
              LDS 7 STA PtrC+1 LDS 8 STA PtrC+0            ; C = destination
              LDA PtrA+1 CPA PtrC+1 BCC a_less_c BNE c_less_a
                LDA PtrA+0 CPA PtrC+0 BCC a_less_c BEQ mc_done
  c_less_a:   LDR PtrA STR PtrC
              INW PtrA INW PtrC
              DEW PtrB BCS c_less_a
                RTS
  a_less_c:   LDA PtrB+1 ADB PtrA+1 LDA PtrB+1 ADB PtrC+1
              LDA PtrB+0 ADW PtrA LDA PtrB+0 ADW PtrC
    alc_loop: LDR PtrA STR PtrC
              DEW PtrA DEW PtrC
              DEW PtrB BCS alc_loop
  mc_done:      RTS

; -------------------------------------------------------------------------------------
; Reads a line of input into _ReadBuffer starting from _ReadPtr
; set _ReadPtr to the desired position within _ReadBuffer buffer (1-50 chars)
; modifies: _ReadPtr
; -------------------------------------------------------------------------------------
OS_ReadLine:  LDA _ReadPtr+0 PHS LDA _ReadPtr+1 PHS       ; save desired start of parsing
  waitchar:   LDI 160 PHS JPS OS_Char PLS                 ; put the cursor
              JPS OS_WaitInput                            ; wait on any input
              CPI 0x80 BCS waitchar                       ; ignore unprintable chars (UP, DN, PgUp, etc.)
              CPI 9 BEQ waitchar                          ; no TAB
              CPI 27 BNE checkback                        ; ESC invalidates input data
                JPS clrcursor
                PLS STA _ReadPtr+1 PLS STA _ReadPtr+0     ; move to start of input and put ENTER
                LDI 10 STR _ReadPtr
                PHS JPS OS_PrintChar PLS                  ; perform 'ENTER'
                RTS
  checkback:  CPI 8 BNE havenoback                        ; check for BACKSPACE
                LDA _XPos CPI 0 BEQ waitchar              ; check for BACKSPACE at linestart
                  JPS clrcursor
                  DEB _XPos DEB _ReadPtr+0 JPA waitchar
  havenoback: STR _ReadPtr CPI 10 BEQ haveenter           ; check for ENTER
                LDA _ReadPtr+0 CPI <ReadLast BEQ waitchar ; end of line reached?
                  LDR _ReadPtr PHS JPS OS_Char PLS
                   INB _XPos INB _ReadPtr+0
                   JPA waitchar
  haveenter:  JPS clrcursor
              PLS STA _ReadPtr+1 PLS STA _ReadPtr+0       ; move to start of input
              LDI 10 PHS JPS OS_PrintChar PLS             ; perform 'ENTER'
              RTS
  clrcursor:  LDI ' ' PHS JPS OS_Char PLS RTS

  ; modifies: _ReadPtr
  OS_ReadSpace: LDR _ReadPtr CPI 32 BCC ps_useit
                  CPI 39 BGT ps_useit
                    INB _ReadPtr+0 JPA OS_ReadSpace
    ps_useit:   RTS

; --------------------------------------------------
; Schreibt einen nullterminierten String at <stradr>
; push: stradr_lsb, stradr_msb
; pull: #, #
; --------------------------------------------------
OS_SerialPrint: LDS 4 STA printaddr+0           ; get string pointer LSB
                LDS 3 STA printaddr+1           ; get string pointer MSB
  printloop:    LDA
  printaddr:    0xffff CPI 0 BEQ printend       ; self-modifying code
                  OUT JPS _SerialWait           ; will wait a bit longer than needed
                  INW printaddr JPA printloop
  printend:      RTS

; --------------------------------------------------
; Parses hex number 0000..ffff from _ReadPtr into _ReadNum
; breaks at any char != [0..9, a..f]
; modifies: _ReadPtr, _ReadNum
; --------------------------------------------------
OS_ReadHex:    CLW _ReadNum LDI 0xf0 STA _ReadNum+2
  hxgetchar:    LDR _ReadPtr                    ; input string lesen
                CPI 'g' BCS hxreturn            ; above f? -> melde Fehler!
                CPI 'a' BCS hxletter            ; a...f?
                CPI ':' BCS hxreturn            ; above 9? -> Separator: Zurück, wenn was da ist, sonst übergehen.
                CPI '0' BCS hxzahl              ; 0...9?
                  JPA hxreturn                  ; unter 0? -> Separator: Zurück, wenn was da ist, sonst übergehen.
  hxletter:     SBI 39
  hxzahl:       SBI 48 PHS
                LLW _ReadNum RLB _ReadNum+2     ; shift existing hex data 4 steps to the left
                LLW _ReadNum RLB _ReadNum+2
                LLW _ReadNum RLB _ReadNum+2
                LLW _ReadNum RLB _ReadNum+2
                PLS ADB _ReadNum+0              ; add new hex nibble (carry cannot happen)
                INW _ReadPtr JPA hxgetchar
  hxreturn:     RTS

; --------------------------------------------------
; This routine takes 260 cycles when called via API + 4 cycles for OUT
; Minimum OUT interval: 352 = 11 * 32 8MHz cycles -> 264 6MHz CPU
; --------------------------------------------------
OS_SerialWait:  CLC LDI 22                      ; CLC: 5, LDI: 4
  wuart_loop:   DEC BNE wuart_loop              ; duration = n * 10 cycles
                RTS                             ; JPS: 14, RTS: 12, API-JPA: 5, OUT: 4

; -------------------------------------------------------
; Loads <filename> pointed to by _ReadPtr from SSD
; <filename> must be terminated by <= 39 "'"
; success: returns A=1, _ReadPtr points beyond <filename>
; failure: returns A=0, _ReadPtr points to <filename>
; modifies: _ReadPtr, PtrA, PtrB, PtrC, PtrD
; -------------------------------------------------------
OS_LoadFile:       JPS OS_FindFile CPI 1 BNE lf_failure            ; check result in A
                      ; PtrA0..2 now points to file in FLASH, FLASH is active
                      LDI 20 ADW PtrA JPS OS_FlashA                ; search for target addr
                      LDR PtrA STA PtrC+0 STA PtrD+0 INW PtrA JPS OS_FlashA  ; destination addr -> PtrC, PtrD
                      LDR PtrA STA PtrC+1 STA PtrD+1 INW PtrA JPS OS_FlashA
                      LDR PtrA STA PtrB+0 INW PtrA JPS OS_FlashA   ; bytesize -> PtrB (PtrA now points to data)
                      LDR PtrA STA PtrB+1 INW PtrA JPS OS_FlashA
  lf_loadloop:        DEW PtrB BCC lf_success                      ; alles kopiert?
                        LDR PtrA BFF                               ; copy block from A -> to C (formerly: SEC ROR BNK ROL)
                        STR PtrC                                   ; store in RAM
                        LDA PtrA+2 BNK                             ; reactivate FLASH
                        INW PtrA INW PtrC JPS OS_FlashA JPA lf_loadloop
  lf_success:         BFF LDI 1 RTS                                ; switch off FLASH
  lf_failure:         BFF LDI 0 RTS

; Produces a FLASH/BANK address in the correct form: PtrA+2: bank, PtrA0..1: 12bit section address
; Adds the value of bits 12-15 of PtrA to PtrA+2, updates bank register and clears upper nibble of PtrA
; Call this routine everytime a FLASH pointer PtrA is modified!
; modifies: PtrA+0..2, bank register
OS_FlashA:      LDA PtrA+1 RL5 ANI 0x0f                            ; is something in the upper nibble?
                CPI 0 BEQ fa_farts
                  ADB PtrA+2 BNK                                   ; there was something -> update bank register PtrA+2
                  LDI 0x0f ANB PtrA+1                              ; correct PtrA+1
  fa_farts:     RTS

; --------------------------------------------------
; Searches SSD for <filename> at _ReadPtr (any char <= 39 terminates <filename>)
; returns A=1: _ReadPtr points beyond <filename>, PtrA0..2/BANK point at start of file in FLASH
; returns A=0: _ReadPtr points to start of <filename>, PtrA0..2/BANK point beyond last file in FLASH
; modifies: _ReadPtr, PtrA, PtrB, PtrC, BANK
; --------------------------------------------------
OS_FindFile:      ; browse through all stored files and see if <filename> matches name, any char <=39 stops
                  CLW PtrA LDI 2 STA PtrA+2 BNK                    ; FLASH ON, SSD address -> PtrA
  ff_search:        LDR PtrA CPI 0xff BEQ ff_returnfalse           ; end of data reached -> no match
                    ; check if name matches (across banks)
                    LDA PtrA+0 STA PtrC+0 LDA PtrA+1 STA PtrC+1    ; PtrA -> PtrC
                    LDA PtrA+2 STA PtrC+2
                    LDA _ReadPtr+0 STA PtrB+0                      ; _ReadPtr -> PtrB
                    LDA _ReadPtr+1 STA PtrB+1
  match_loop:       LDR PtrB CPI 39 BGT ff_isnoend                 ; tausche <= "'" (SPACE, ENTER, 0) gegen 0 aus
                      LDI 0
  ff_isnoend:       CPR PtrC BNE files_dontmatch                   ; stimmen Buchstaben überein?
                      CPI 0 BEQ ff_returntrue                      ; wurde gemeinsame 0 erreicht => match!
                        INW PtrB INW PtrC SBI 0x10 BCC match_loop  ; teste nä. Buchstaben, handle 12-bit overflow in C
                          STA PtrC+1 INB PtrC+2 BNK JPA match_loop
                    ; this filename does not match => jump over (across banks)
  files_dontmatch:  LDI 22 ADW PtrA JPS OS_FlashA                  ; advance over header to bytesize LSB
                    LDR PtrA STA PtrB+0 INW PtrA JPS OS_FlashA     ; extract bytesize -> PtrB
                    LDR PtrA STA PtrB+1 INW PtrA
                    LDA PtrB+0 ADW PtrA LDA PtrB+1 ADB PtrA+1      ; PtrA points beyond this file
                      LSR LSR LSR LSR ADB PtrA+2 BNK               ; update BANK
                      LDA PtrA+1 LSL LSL LSL LSL LSL
                      ROL ROL ROL ROL STA PtrA+1 JPA ff_search     ; use only lower 12 bits
  ff_returntrue:    LDA PtrB+0 STA _ReadPtr+0                      ; parse over good filename
                    LDA PtrB+1 STA _ReadPtr+1
                    LDI 1 RTS
  ff_returnfalse:   LDI 0 RTS                                      ; not found, don't change _ReadPtr

; --------------------------------------------------
; Saves a RAM area as file <name> to SSD drive, checks if there is enough space, asks before overwriting
; expects: _ReadPtr points to filename starting with char >= 40, terminated by char <= 39
; push: first_lsb, first_msb, last_lsb, last_msb
; pull: #, #, #, result (1: success, 0: failure, 2: user abortion) same as in A
; modifies: X, PtrA, PtrB, PtrC, PtrD, PtrE, PtrF, _ReadPtr
; --------------------------------------------------
OS_SaveFile:      LDS 3 STA PtrF+1 LDS 4 STA PtrF+0
                  LDS 5 STA PtrE+1 LDS 6 STA PtrE+0
                  ; assemble a zero-filled 20-byte filename starting at _ReadBuffer for the header
                  LXI 19                                           ; copy up to 19 chars of filename
                  LDI <_ReadBuffer STA PtrD+0                      ; _ReadBuffer -> temp PtrD
                  LDI >_ReadBuffer STA PtrD+1
  sf_namecopy:    LDR _ReadPtr CPI 39 BLE sf_nameend               ; read a name char, anything <= 39 ends name
                    STR PtrD INW _ReadPtr INW PtrD                 ; copy name char
                    DEX BNE sf_namecopy
  sf_nameend:     LDI 0 STR PtrD                                   ; overwrite rest including 20th byte with zero
                  INW PtrD DEX BCS sf_nameend                      ; PtrD points beyond 20-byte area

                  ; invalidate exisiting files with that name, look for enough free space on the SSD
  sf_existfile:   LDI <_ReadBuffer STA _ReadPtr+0                  ; _ReadPtr points back to filename
                  LDI >_ReadBuffer STA _ReadPtr+1
                  JPS OS_FindFile CPI 1 BNE sf_foundfree
                    LDA PtrA+2 CPI 3 BCC sf_returnfalse            ; file is write protected

                    LDI <sf_asktext PHS LDI >sf_asktext PHS
                    JPS OS_Print PLS PLS
                    JPS OS_WaitInput CPI 'y' BNE sf_returnbrk      ; used break => no error

                    ; invalidate existing filename to 0
                    LXI 10                                         ; re-read a maximum times
                    LDI 0x05 BNK LDI 0xaa STA 0x0555               ; INIT FLASH WRITE PROGRAM
                    LDI 0x02 BNK LDI 0x55 STA 0x0aaa
                    LDI 0x05 BNK LDI 0xa0 STA 0x0555
                    LDA PtrA+2 BNK LDI 0 STR PtrA                  ; START INVALIDATE WRITE PROCESS
    sf_delcheck:    DEX BCC sf_returnfalse                         ; write took too long => ERROR!!!
                      LDR PtrA CPI 0 BNE sf_delcheck               ; re-read FLASH location -> data okay?
                        JPA sf_existfile

  sf_foundfree:   ; PtrA/PtrA+2 now point to free SSD space
                  LDA PtrE+1 SBB PtrF+1                            ; calculate data bytesize in PtrF
                  LDA PtrE+0 SBW PtrF
                  INW PtrF                                         ; PtrF = last - first + 1

                  LDA PtrA+1 STA PtrB+1 LDA PtrA+0 STA PtrB+0      ; FLASH start -> temp PtrB
                  LDA PtrF+1 STA PtrC+1 LDA PtrF+0 STA PtrC+0      ; data bytesize -> temp PtrC
                  LXI 4
  sf_shiftloop:   DEX BCC sf_shifted
                    LDA PtrB+1 LSR STA PtrB+1                      ; divide FLASH start by 2
                    LDA PtrB+0 ROR STA PtrB+0
                    LDA PtrC+1 LSR STA PtrC+1                      ; divide bytesize by 2
                    LDA PtrC+0 ROR STA PtrC+0
                    JPA sf_shiftloop
                  LDA PtrA+2 STA PtrB+1                            ; PtrB now holds FLASH start in nibbles (rounded down)
                  INW PtrB                                         ; add 1 nibble for rounding up
                  LDI 3 ADW PtrC                                   ; PtrC now holds bytesize in nibbles + 3 (headersize + rouning safety)

  sf_shifted:     LDA PtrC+0 ADW PtrB LDA PtrC+1 ADB PtrB+1
                  CPI 0x80 BCS sf_returnfalse                      ; 512KB overflow!

                  ; write header start address and bytesize
                  LDA PtrE+0 STA _ReadBuffer+20                    ; write start addr to header
                  LDA PtrE+1 STA _ReadBuffer+21
                  LDA PtrF+0 STA _ReadBuffer+22                    ; write data bytesize to header
                  LDA PtrF+1 STA _ReadBuffer+23

                  ; write header to FLASH memory
                  LDI <_ReadBuffer STA PtrC+0                      ; start addr of header -> PtrC
                  LDI >_ReadBuffer STA PtrC+1                      ; free addr is already in PtrA, PtrA+2
                  CLB PtrB+1 LDI 24 STA PtrB+0                     ; bytesize of header -> PtrB
                  JPS OS_FLASHWrite                                ; write the header (incrementing PtrA, PtrA+2)
                  LDA PtrB+1 CPI 0xff BNE sf_returnfalse           ; check if all bytes have been written successfully

                  ; write body to FLASH memory
                  LDA _ReadBuffer+20 STA PtrC+0                    ; start -> PtrC
                  LDA _ReadBuffer+21 STA PtrC+1
                  LDA _ReadBuffer+22 STA PtrB+0                    ; bytesize -> PtrB
                  LDA _ReadBuffer+23 STA PtrB+1                    ; PtrA, PtrA+2 already positioned behind header
                  JPS OS_FLASHWrite                                ; write the data body
                  LDA PtrB+1 CPI 0xff BNE sf_returnfalse           ; check if all bytes have been written successfully
                    BFF LDI 1 STS 6 RTS                            ; return success, FLASH off

  sf_returnfalse: BFF LDI 0 STS 6 RTS                              ; return failure, FLASH off
  sf_returnbrk:   BFF LDI 2 STS 6 RTS                              ; signal user abortion

  sf_asktext:     'OVERWRITE (y/n)?', 10, 0

; --------------------------------------------------
; Writes data to FLASH at PtrA0..2 and BNK, PtrC: RAM source, PtrB: bytesize
; expects PtrA+2 and BNK have already been set
; modifies: PtrA (points to byte after target data if successful)
;           PtrB (0xffff: success by underflow, else failure)
;           PtrC (points to byte after source data if successful)
; modifies: X
; --------------------------------------------------
OS_FLASHWrite:      DEW PtrB BCC fw_return                    ; Anzahl runterzählen
                    LDR PtrA CPI 0xff BNE fw_return           ; teste FLASH, ob dest byte == 0xff ist
                      LDI 0xff BNK LDR PtrC PHS               ; switch OFF FLASH while accessing RAM
                      LXI 10                                  ; re-read a maximum times
                      LDI 0x05 BNK LDI 0xaa STA 0x0555        ; INIT FLASH WRITE PROGRAM
                      LDI 0x02 BNK LDI 0x55 STA 0x0aaa
                      LDI 0x05 BNK LDI 0xa0 STA 0x0555
                      LDA PtrA+2 BNK                          ; set FLASH bank to write to
                      PLS STR PtrA                            ; INITIATE BYTE WRITE PROCESS
  fw_writecheck:      DEX BCC fw_return                       ; write took too long => PtrB != 0xffff => ERROR!
                        LDS 0 CPR PtrA BNE fw_writecheck      ; re-read FLASH location until is data okay
                          INW PtrC INW PtrA                   ; DATA OKAY! Increase both pointers to next byte
                          LDA PtrA+1 SBI 0x10 BCC OS_FLASHWrite ; no need to correct bank and address?
                            STA PtrA+1 INB PtrA+2 BNK         ; correct it!
                            JPA OS_FLASHWrite                 ; write next data byte to FLASH
  fw_return:      RTS

; ************************************************************************
; Eraseses a 4KB FLASH sector without any protection (handle with care!)
; push: FLASH sector (bank index) to be erased completely to 0xff
; pull: #
; modifies: bank register back to 0xff
; ************************************************************************
OS_FLASHErase:  LDI 0x05 BNK LDI 0xaa STA 0x0555              ; issue FLASH ERASE COMMAND
                LDI 0x02 BNK LDI 0x55 STA 0x0aaa
                LDI 0x05 BNK LDI 0x80 STA 0x0555
                LDI 0x05 BNK LDI 0xaa STA 0x0555
                LDI 0x02 BNK LDI 0x55 STA 0x0aaa
                LDS 3 BNK LDI 0x30 STA 0x0fff                 ; initiate the BLOCK ERASE command
  fe_wait:      LDA 0x0fff LSL BCC fe_wait                    ; wait for 8th bit go HIGH, this code HAS to run in RAM!
                  BFF RTS                                     ; done, FLASH OFF

; *******************************************************************************
; Clears pixel area (0.058s)
; highly optimized with self-modifying code
; modifies: X
; *******************************************************************************
OS_Clear:       LDI <ViewPort STA vc_loopx+1                  ; set start index
                LDI >ViewPort STA vc_loopx+2
  vc_loopy:     LXI 25                                        ; screen width in words
  vc_loopx:     CLW 0xffff
                LDI 2 ADB vc_loopx+1
                DEX BGT vc_loopx                              ; self-modifying code
                  LDI 14 ADW vc_loopx+1                       ; add blank number of cols
                  CPI 0xff BCC vc_loopy
                RTS

; *******************************************************************************
; Clears the entire video RAM including the blanking areas (0.070s)
; *******************************************************************************
OS_ClearVRAM:   CLB ca_loop+1 LDI 0xc0 STA ca_loop+2          ; init video RAM pointer
  ca_loop:      CLW 0xffff                                    ; erase area 0xc000 to 0xfeff
                LDI 2 ADW ca_loop+1 CPI 0xff BCC ca_loop
                  RTS

; *******************************************************************************
; Plots the 'Minimal' logo as 80x32 bitmap
; modifies: X, Y
; *******************************************************************************
OS_Logo:        LDI 0x01 BNK                                  ; Plot the logo
                LDI <MinimalLogo STA vl_get+1
                LDI >MinimalLogo STA vl_get+2
                LDI <ViewPort+515 STA vl_put+1
                LDI >ViewPort+515 STA vl_put+2
                LYI 32
  vl_loopy:     LXI 10
  vl_get:       LDA 0xffff
  vl_put:       STA 0xffff
                INW vl_get+1 INW vl_put+1
                DEX BGT vl_get
                  LDI 54 ADW vl_put+1
                  DEY BGT vl_loopy
                    BFF RTS

; *******************************************************************************
; Scrolls the video area one character upwards (0.07s)
; modifies: X, Y
; *******************************************************************************
OS_ScrollUp:  LDI <ViewPort                                   ; init LSBs
              STA sc_get+1 STA sc_put+1 STA sc_gett+1 STA sc_putt+1
              LDI 0xc3 STA sc_put+2                           ; init MSBs
              LDI 0xc4 STA sc_putt+2
              LDI 0xc5 STA sc_get+2
              LDI 0xc6 STA sc_gett+2
              LYI 29                                          ; move 29 rows
  sc_loop:    LXI 50                                          ; move 50 cols
  sc_get:     LDA 0xffff                                      ; copy line of a top half-char
  sc_put:     STA 0xffff
  sc_gett:    LDA 0xffff                                      ; copy line of bottom half-char
  sc_putt:    STA 0xffff
              INB sc_put+1 STA sc_get+1 STA sc_putt+1 STA sc_gett+1
              DEX BGT sc_get
                LDI 14 ADB sc_put+1 STA sc_get+1 STA sc_putt+1 STA sc_gett+1 BCC sc_loop    ; add blank cols
                  LDI 2 ADB sc_put+2                          ; move down one line
                  INC STA sc_putt+2
                  INC STA sc_get+2
                  INC STA sc_gett+2
                  DEY BGT sc_loop
              JPS OS_ClearRow RTS

; *******************************************************************************
; Scrolls the video area one character downwards (0.07s)
; modifies: X, Y
; *******************************************************************************
OS_ScrollDn:  LDI <ViewPort                                   ; init LSBs
              STA sd_get+1 STA sd_put+1 STA sd_gett+1 STA sd_putt+1
              LDI 0xfb STA sd_get+2                           ; init MSBs
              LDI 0xfc STA sd_gett+2
              LDI 0xfd STA sd_put+2
              LDI 0xfe STA sd_putt+2
              LYI 29                                          ; move 29 rows
  sd_loop:    LXI 50                                          ; move 50 cols
  sd_get:     LDA 0xffff                                      ; copy line of a top half-char
  sd_put:     STA 0xffff
  sd_gett:    LDA 0xffff                                      ; copy line of bottom half-char
  sd_putt:    STA 0xffff
              INB sd_put+1 STA sd_get+1 STA sd_putt+1 STA sd_gett+1
              DEX BGT sd_get
                LDI 14 ADB sd_put+1 STA sd_get+1 STA sd_putt+1 STA sd_gett+1 BCC sd_loop    ; add blank cols
                  LDI 2 SBB sd_putt+2                         ; move up one line
                  DEC STA sd_put+2
                  DEC STA sd_gett+2
                  DEC STA sd_get+2
                  DEY BGT sd_loop
              JPS OS_ClearRow RTS

; *******************************************************************************
; Sets a pixel at position (x, y) without safety check (highly optimized)
; push: xpos_lsb, xpos_msb, ypos
; pull: #, #, #
; *******************************************************************************
OS_SetPixel:      LDI 0x01 BNK                                ; turn on FLASH bank for table access
                  LDS 3                                       ; safety check: CPI 240 BCS vs_exit
                    STA vs_llsbptr+1 STA vs_lmsbptr+1         ; set line table index
  vs_lmsbptr:       LDA LineMSBTable STA vs_index+2           ; extract msb line start address
                  LDS 4 DEC                                   ; move the x_msb's 1th bit into carry
                  LDS 5 RL6 ANI 63                            ; safety check: CPI 50 BCS vs_exit
  vs_llsbptr:       ADA LineLSBTable STA vs_index+1           ; add lsb line start address, overflow into msb cannot happen
                    LDS 5 ANI 7 STA vs_btptr+1                ; set bit table index
  vs_btptr:         LDA BitTable                              ; set the pixel
  vs_index:         ORB 0xffff                                ; self-modifying code
  vs_exit:        BFF RTS

; *******************************************************************************
; Clears a pixel at position (x, y)
; push: xpos_lsb, xpos_msb, ypos
; pull: #, #, #
; *******************************************************************************
OS_ClrPixel:     LDI 0x01 BNK                                 ; turn on FLASH bank for table access
                  LDS 3                                       ; CPI 240 BCS vc_exit
                    STA vc_llsbptr+1 STA vc_lmsbptr+1         ; set line table index
  vc_lmsbptr:       LDA LineMSBTable STA vc_index+2           ; extract msb line start address
                  LDS 4 DEC                                   ; move the x_msb's 1th bit into carry
                  LDS 5 RL6 ANI 63                            ; CPI 50 BCS vc_exit ; find byte position
  vc_llsbptr:       ADA LineLSBTable STA vc_index+1           ; add lsb line start address, overflow into msb cannot happen
                    LDS 5 ANI 7 STA vc_btptr+1                ; set bit table index
  vc_btptr:         LDA BitTable NOT                          ; set the pixel
  vc_index:         ANB 0xffff                                ; self-modifying code
  vc_exit:        BFF RTS

; *******************************************************************************
; Gets the pixel state at position (x, y)
; A=0: pixel off state, A!=0: pixel on state
; push: xpos_lsb, xpos_msb, ypos
; pull: #, #, #
; *******************************************************************************
OS_GetPixel:     LDI 0x01 BNK                                 ; turn on FLASH bank for table access
                  LDS 3                                       ; CPI 240 BCS vg_exit
                    STA vg_llsbptr+1 STA vg_lmsbptr+1         ; set line table index
  vg_lmsbptr:       LDA LineMSBTable STA vg_index+2           ; extract msb line start address
                  LDS 4 DEC                                   ; move the x_msb's 1th bit into carry
                  LDS 5 RL6 ANI 63                            ; CPI 50 BCS vg_exit ; find byte position
  vg_llsbptr:       ADA LineLSBTable STA vg_index+1           ; add lsb line start address, overflow into msb cannot happen
                    LDS 5 ANI 7 STA vg_btptr+1                ; set bit table index
  vg_btptr:         LDA BitTable                              ; set the pixel
  vg_index:         ANA 0xffff                                ; self-modifying code
  vg_exit:        BFF RTS

; **********************************************************************************
; draws a rect at (x, y) with width w and height h (w=0, h=0 will draw a single dot)
; note: a rect of width 3 will appear to have the width 4 because of pixel width 1
; push: x_lsb, x_msb, y, w_lsb, w_msb, h
; pull: #, #, #, #, #, #
; modifies: X
; **********************************************************************************
OS_Rect:          LDI 0x01 BNK                                ; turn on FLASH bank for table access
                  LDS 6                                       ; get y position
                  STA re_lsbptr+1 STA re_msbptr+1             ; set line table index
  re_msbptr:      LDA LineMSBTable                            ; extract msb start address
                  STA re_tlindex+2 STA re_trindex+2           ; set top msb start address
                  STA re_mlindex+2 STA re_mrindex+2           ; also set for middle part
                  LDS 7 DEC                                   ; get x pos, trick: move the x_msb's 1th bit to C
                  LDS 8 RL6 ANI 63
  re_lsbptr:      ADA LineLSBTable STA re_tlindex+1           ; add lsb line start address, overflow into msb cannot happen
                  LDS 8 ANI 7 STA re_tlbptr+1 STA re_mlbptr+1 ; set bit table index

                  LDS 4 DEC                                   ; get x width
                  LDS 5 RL6 ANI 63
                  ADA re_tlindex+1 STA re_trindex+1           ; set right coarse index
                  LDS 5 ANI 7 ADA re_tlbptr+1
                  CPI 8 BCC re_noplus
                    ANI 7 STA re_trbptr+1 STA re_mrbptr+1 INB re_trindex+1          ; one more full byte
                    JPA re_allsetup
    re_noplus:    STA re_trbptr+1 STA re_mrbptr+1

  re_allsetup:    LDA re_tlindex+1 STA re_mlindex+1           ; save for middle section
                  LDA re_trindex+1 STA re_mrindex+1

                  ; plot the top border
  re_tlbptr:      LDA RectLeftTable STA re_blbpat+1           ; top left bit pattern
  re_tlindex:     ORB 0xffff
                  INB re_tlindex+1 CPA re_trindex+1 BCS re_trbptr
                    LDI 0xff JPA re_tlindex
  re_trbptr:      LDA RectRightTable STA re_brbpat+1          ; top right bit pattern
  re_trindex:     ORB 0xffff

                  ; plot left/right border
                  LDS 3 DEC BCC re_exit                       ; quit after top border at h=0
                    TAX
  re_midloop:       DEX BCC re_bottom                         ; h=1 ? no middle section
                      LDI 64 ADW re_mlindex+1                 ; one line down
                      LDI 64 ADW re_mrindex+1
  re_mlbptr:          LDA BitTable
  re_mlindex:         ORB 0xffff                              ; index of left border
  re_mrbptr:          LDA BitTable
  re_mrindex:         ORB 0xffff                              ; index of right border
                      JPA re_midloop

                  ; plot the bottom border
  re_bottom:      LDI 64 ADW re_mlindex+1                     ; one line down
                  LDA re_mlindex+1 STA re_blindex+1
                  LDA re_mlindex+2 STA re_blindex+2
                  LDI 64 ADW re_mrindex+1
                  LDA re_mrindex+1 STA re_brindex+1
                  LDA re_mrindex+2 STA re_brindex+2
  re_blbpat:      LDI 0xff                                    ; bottom left bit pattern
  re_blindex:     ORB 0xffff
                  INB re_blindex+1 CPA re_brindex+1 BCS re_brbpat
                    LDI 0xff JPA re_blindex
  re_brbpat:      LDI 0xff                                    ; bottom left bit pattern
  re_brindex:     ORB 0xffff
  re_exit:        BFF RTS

; ************************************************************** 5.02s for 1024 random lines
; draws a line from point (x1, y1) to point (x2, y2)
; push: x1_lsb, x1_msb, y1, x2_lsb, x2_msb, y2
; pull: #, #, #, #, #, #
; highly optimized with self-modifying code
; **************************************************************
OS_Line:       LDI 0x01 BNK                                    ; switch on table access
                LDI INW STA li_incx STA li_incy                ; init incx/y to INW (for self-modifying code)
                LDS 5 STA li_dx+0                              ; init x, dx
                LDS 4 STA li_dx+1
                LDS 7 STA li_x+1 SBB li_dx+1
                LDS 8 STA li_x+0 SBW li_dx BPL li_next
                  INB li_incx NEW li_dx                        ; incx = DEW, dx is now pos
  li_next:      CLB li_dy+1
                LDS 3 STA li_dy+0                              ; init y, dy
                LDS 6 STA li_y+0 SBW li_dy BPL li_initdone     ; li_y+1 always stays zero
                  INB li_incy NEW li_dy                        ; incy = DEW, dy is now pos

  li_initdone:  LDA li_dx+1 CPI 0 BNE li_dxgreater             ; is dx > dy ?
                  LDA li_dx+0 CPA li_dy+0 BGT li_dxgreater
                    LDA li_incx STA li_ddx                     ; CASE dy <= dx
                    LDI LDA STA li_pdx                         ; equivalent to pdx=0
                    LDA li_incy STA li_pdy STA li_ddy
                    LDA li_dx+0 STA li_dsdir+0 LDA li_dx+1 STA li_dsdir+1   ; change dx and dy
                    LDA li_dy+0 STA li_dfdir+0 LDA li_dy+1 STA li_dfdir+1
                    JPA li_weiter
  li_dxgreater: LDA li_incy STA li_ddy                         ; CASE dx > dy
                LDI LDA STA li_pdy                             ; equivalent to pdy=0
                LDA li_incx STA li_pdx STA li_ddx
                LDA li_dy+0 STA li_dsdir+0 LDA li_dy+1 STA li_dsdir+1   ; leave dx and dy unchanged
                LDA li_dx+0 STA li_dfdir+0 LDA li_dx+1 STA li_dfdir+1
  li_weiter:    STA li_t+1
                LSR STA li_err+1 LDA li_dfdir+0 STA li_t+0
                ROR STA li_err+0                               ; init err, t

  li_loop:      LDA li_y+0 STA li_llsbtptr+1 STA li_lmsbtptr+1 ; PLOT THE PIXEL, set line lsb/msb table index
  li_lmsbtptr:  LDA LineMSBTable STA li_index+2                ; extract msb line start address
                LDA li_x+1 DEC LDA li_x+0 RL6 ANI 63           ; move x_msb's 0th bit into C and find byte pos
  li_llsbtptr:  ADA LineLSBTable STA li_index+1                ; add lsb line start address
                LDA li_x+0 ANI 7 STA li_btptr+1                ; set bit table index (msb only)
  li_btptr:     LDA BitTable                                   ; set the pixel with the correct mask
  li_index:     ORB 0xffff                                     ; self-modifying code

  li_done:      DEW li_t BCC li_end                            ; MOVE ALONG THE LINE, MINIMIZING ERRORS
                  LDA li_dsdir+1 SBB li_err+1
                  LDA li_dsdir+0 SBW li_err BPL li_pdx
                    LDA li_dfdir+1 ADB li_err+1
                    LDA li_dfdir+0 ADW li_err
  li_ddx:           INW li_x                                   ; diagonal step (self-modifying code)
  li_ddy:           INW li_y
                    JPA li_loop
  li_pdx:         INW li_x                                     ; parallel step (self-modifying code)
  li_pdy:         INW li_y
                  JPA li_loop

  li_end:       BFF RTS

  li_t:         0x0000      ; counts fast steps
  li_x:         0x0000      ; current pixel position
  li_y:         0x0000      ; MSB not used
  li_dx:        0x0000      ; (x2-x1)
  li_dy:        0x0000      ; (y2-y1) MSB *is* used here
  li_incx:      0xff        ; temp storage for either 'INW' or 'DEW'
  li_incy:      0xff
  li_dsdir:     0x0000
  li_dfdir:     0x0000
  li_err:       0x0000      ; error term

; *******************************************************************************
; Prints a null-terminated string into video RAM starting at (_XPos, _YPos)
; updates cursor position, handles LF and scrolling
; push: textaddr_lsb, textaddr_msb
; pull: #, #
; modifies: _XPos, _YPos, X, Y
; *******************************************************************************
OS_Print:      LDA _YPos LSL ADI >ViewPort STA vp_index+2      ; multiply y with 8*64=512
                LDI <ViewPort STA vp_index+1
                LDA _XPos ADW vp_index+1                       ; text starting position
                LDS 3 STA vp_tptr+2 LDS 4 STA vp_tptr+1        ; copy text pointer
  vp_tloop:     LDI >Charset STA vp_cptr+2                     ; init char data pointer
  vp_tptr:      LDA 0xffff CPI 0 BEQ vp_exit                   ; load next char and test for end
                  CPI 10 BNE vp_regular                        ; test for ENTER
                    INW vp_tptr+1 LDA _XPos                    ; consume ENTER
  vp_nextrow:       SBB vp_index+1 CLB _XPos                   ; move cursor back to linestart
                    LDA _YPos CPI 29 BCC vp_godown             ; ENTER in row 29? scroll!
                      JPS OS_ScrollUp JPA vp_tloop
    vp_godown:      INB _YPos LDI 2 ADB vp_index+2             ; move cursor one down
                    JPA vp_tloop
  vp_regular:     STA vp_cptr+1                                ; start of current char's data
                  LDI 0x01 BNK                                 ; switch on charset access
  vp_cptr:        LDA 0xffff                                   ; get char byte
  vp_index:       STA 0xffff
                    LDI 64 ADW vp_index+1                      ; move down one pixel row
                    INB vp_cptr+2                              ; move to next char data row
                    CPI >Charset+2048 BCC vp_cptr              ; plot 8 bytes
                      BFF INW vp_index+1 INW vp_tptr+1         ; switch off charset access and move one step right
                      LDI 2 SBB vp_index+2                     ; move back to top of row
                      INB _XPos CPI 50 BCC vp_tloop            ; advance cursor position
                        JPA vp_nextrow                         ; do wrap-around when printing outside viewport
  vp_exit:      RTS

; *******************************************************************************
; Prints a single character at position (_XPos, _YPos)
; updates _XPos and _YPos and handles LF incl. scrolling
; push: <char>
; pull: #
; *******************************************************************************
OS_PrintChar:  LDS 3 CPI 10 BNE pz_regular
  pz_enter:       CLB _XPos INB _YPos CPI 30 BCC pz_exit       ; ENTER in row 29? scroll!
                    DEB _YPos JPA OS_ScrollUp                  ; ... and return from there ;-)
    pz_godown:    INB _YPos RTS                                ; move cursor one down
  pz_regular:   PHS JPS OS_Char PLS
                INB _XPos CPI 50 BCS pz_enter
  pz_exit:        RTS

; *******************************************************************************
; Puts a character at position (_XPos, _YPos) without changing _XPos or _YPos
; push: <char>
; pull: #
; *******************************************************************************
OS_Char:        LDS 3 STA pc_cptr+1                            ; set char data pointer LSB
                LDI >Charset STA pc_cptr+2                     ; set char data pointer MSB
                LDI <ViewPort ADA _XPos STA pc_index+1         ; index to video position of char
                LDA _YPos LSL ADI >ViewPort STA pc_index+2     ; multiply y with 8*64 = 512
                LDI 0x01 BNK                                   ; switch on charset access
  pc_cptr:      LDA 0xffff                                     ; get char byte
  pc_index:     STA 0xffff                                     ; store in video RAM
                LDI 64 ADW pc_index+1                          ; move down one pixel row
                INB pc_cptr+2                                  ; move to next charset data row (+256)
                CPI >Charset+2048 BCC pc_cptr                  ; plot 8 bytes
  pc_exit:        BFF RTS                                      ; switch off charset access

; *******************************************************************************
; Clears the row at current _YPos screen position
; modifies: X
; *******************************************************************************
OS_ClearRow:   LDA _YPos LSL ADI >ViewPort
                STA cr_upper+2 INC STA cr_lower+2             ; init half row pointers
                LDI <ViewPort STA cr_upper+1 STA cr_lower+1   ; init start of row
  cr_line:      LXI 25                                        ; screen width in words
  cr_upper:     CLW 0xffff
  cr_lower:     CLW 0xffff
                LDI 2 ADB cr_upper+1 STA cr_lower+1
                DEX BGT cr_upper
                  LDI 14 ADB cr_upper+1 STA cr_lower+1 BCC cr_line
                RTS

; --------------------------------------------------
; Prints out a byte value <val> in HEX format
; push: <val>
; pull: #
; modifies:
; --------------------------------------------------
OS_PrintHex:   LDS 3 RL5 ANI 15 ADI '0'                        ; extract MSB
                CPI 58 BCC th_msn
                  ADI 39
  th_msn:       PHS JPS OS_PrintChar PLS
                LDS 3 ANI 15 ADI '0'                           ; extract LSB
                CPI 58 BCC th_lsn
                  ADI 39
  th_lsn:       PHS JPS OS_PrintChar PLS
                RTS

; -------------------------------------------------------------------------------------
; Reads out the PS2 keyboard register. Stores ASCII code of pressed key in 'ps2_ascii'.
; Call this routine in intervals < 835µs (~5000 clocks) to not miss any PS2 datagrams.
; In case a '0xf0 release' is detected, the routine waits some time for next datagram.
; modifies: ps2_ascii
; -------------------------------------------------------------------------------------
OS_ScanPS2:       INK CPI 0xff BEQ key_rts                     ; fast readout of keyboard register
  key_reentry:      CPI 0xf0 BEQ key_release
                      CPI 0x11 BEQ key_alt                     ; special keys pressed?
                        CPI 0x12 BEQ key_shift
                          CPI 0x59 BEQ key_shift
                            CPI 0x14 BEQ key_ctrl
                              CPI 0xe0 BEQ key_rts             ; ignore special marker for cursor keys
                    ANI 0x7f STA ps2_ptr+0                     ; set scan table index according to SHIFT / ALT / CTRL
                    LDA ps2_release CPI 1 BEQ key_clearrel     ; marked as a release? -> don't store
                      LDI >PS2Table STA ps2_ptr+1
                      LDI 1
                      CPA ps2_shift BNE key_check2             ; chose the right PS2 scan code table
                        LDI 0x80 ADB ps2_ptr+0 JPA key_ptrok
  key_check2:         CPA ps2_alt BNE key_check3
                        INB ps2_ptr+1 JPA key_ptrok
  key_check3:         CPA ps2_ctrl BNE key_ptrok
                        INB ps2_ptr+1 LDI 0x80 ADB ps2_ptr+0
  key_ptrok:          LDI 0x01 BNK LDA                         ; switch to PS2 table in FLASH
  ps2_ptr:            0xffff STA ps2_ascii                     ; read table data from FLASH memory and store ASCII code
                      BFF RTS                                  ; do not use A so that this routine can be called often without processing key immediately
  key_release:    LDI 0x01 STA ps2_release                     ; IMPROVED PS2 RELEASE DETECTION - WORKS GREAT!
                  LDI 0
    key_wait:     NOP NOP NOP NOP NOP INC BCC key_wait         ; wait 4.6ms for next datagram
                    INK CPI 0xff BNE key_reentry               ; treat the actual key, too
                      JPA key_clearrel                         ; ignore this 0xf0. We have missed it's datum.
  key_shift:      LDA ps2_release NEG STA ps2_shift
                      JPA key_clearrel
  key_alt:        LDA ps2_release NEG STA ps2_alt
                      JPA key_clearrel
  key_ctrl:       LDA ps2_release NEG STA ps2_ctrl
  key_clearrel:   LDI 0xff STA ps2_release
  key_rts:        RTS

  ps2_shift:      0xff                                         ; state of special keys
  ps2_ctrl:       0xff
  ps2_alt:        0xff
  ps2_release:    0xff
  ps2_ascii:      0x00                                         ; store "pressed" key code here

; --------------------------------------------------------------------------------------------
; Resets the state of keys ALT, SHIFT, CTRL to avoid lock-up after a longer operation (CTRL+V)
; --------------------------------------------------------------------------------------------
OS_ResetPS2:      LDI 0xff
                  STA ps2_shift STA ps2_ctrl STA ps2_alt
                  RTS

; *******************************************************************************
; Read input from any input source
; Returns either 0 for no input or the ASCII code of the last pressed key
; *******************************************************************************
OS_ReadInput:     INP CPI 0xff BNE ri_exit                     ; check for direct terminal input
                    JPS OS_ScanPS2                             ; read/clear PS2 register and convert it to ASCII
                    LDA ps2_ascii CLB ps2_ascii                ; load ASCII key code into A, CLB does not change A
  ri_exit:        RTS                                          ; returns A

; *******************************************************************************
; Wait on input from any input source
; Returns either 0 for no input or the ASCII code of the pressed key
; *******************************************************************************
OS_WaitInput:     WIN                                          ; FAST testing (read/clear must happen within 32/4*3=24 cycles of receiving with UART)
                  INP CPI 0xff BNE wi_exit
                    JPS OS_ScanPS2                             ; read/clear PS/2 register, UART already cleared
                    LDA ps2_ascii CPI 0 BEQ OS_WaitInput       ; Is there a new ASCII key code? No => repeat
                      CLB ps2_ascii                            ; CLB does not change A
  wi_exit:        RTS                                          ; clear keyboard and return uart in A

OS_Image_End:                                                  ; address of first byte beyond OS kernel code

#mute
                ; GLOBAL OS LABELS AND CONSTANTS
#org 0xbf70     _ReadPtr:                    ; Zeiger (2 bytes) auf das letzte eingelesene Zeichen (to be reset at startup)
#org 0xbf72     _ReadNum:                    ; 3-byte storage for parsed 16-bit number, MSB: 0xf0=invalid, 0x00=valid
#org 0xbf75     PtrA:                        ; lokaler pointer (3 bytes) used for FLASH addr and bank
#org 0xbf78     PtrB:                        ; lokaler pointer (3 bytes)
#org 0xbf7b     PtrC:                        ; lokaler pointer (3 bytes)
#org 0xbf7e     PtrD:                        ; lokaler pointer (2 bytes)
#org 0xbf80     PtrE:                        ; lokaler pointer (2 bytes)
#org 0xbf82     PtrF:                        ; lokaler pointer (2 bytes)
#org 0xbf84     _RandomState:                ; 4-byte storage (x, a, b, c) state of the pseudo-random generator
#org 0xbf88     ; unused
#org 0xbf89     ; unused
#org 0xbf8a     ; unused
#org 0xbf8b     ; unused
#org 0xbf8c     _XPos:                       ; current VGA cursor col position (x: 0..49)
#org 0xbf8d     _YPos:                       ; current VGA cursor row position (y: 0..29)
#org 0xbf8e     _ReadBuffer:                 ; 50 bytes of OS read buffer (input line)
#org 0xbfbf     ReadLast:                    ; last byte of read buffer

                                             ; 0xbfc0 - 0xbfff reserved for expansion cards

#org 0xc30c     ViewPort:                    ; start index of viewport area 0xc000 + 12*64 + 12

#emit

; **********************************************************************************************************

#org 0x1000
  #mute
  #org 0x0000   ; BANK 1: Charset & Table Data
  #emit
Charset:        ; CHARACTER SET (256 x 8 bytes) and lookup tables for bit value
BitTable:       0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xc0,0x03,0x00,0x18,0x66,0x66,0x18,0x46,0x3c,0x30,0x30,0x0c,0x00,0x00,0x00,0x00,0x00,0x00,0x3c,0x18,0x3c,0x3c,0x60,0x7e,0x3c,0x7e,0x3c,0x3c,0x00,0x00,0x70,0x00,0x0e,0x3c,0x3c,0x18,0x3e,0x3c,0x1e,0x7e,0x7e,0x3c,0x66,0x3c,0x78,0x66,0x06,0xc6,0x66,0x3c,0x3e,0x3c,0x3e,0x3c,0x7e,0x66,0x66,0xc6,0x66,0x66,0x7e,0x3c,0x00,0x3c,0x08,0x00,0x3c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x70,0x18,0x0e,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x18,0x18,0xff,0xff,0x80,0x01,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0xe7,0x99,0x99,0xe7,0xb9,0xc3,0xcf,0xcf,0xf3,0xff,0xff,0xff,0xff,0xff,0xff,0xc3,0xe7,0xc3,0xc3,0x9f,0x81,0xc3,0x81,0xc3,0xc3,0xff,0xff,0x8f,0xff,0xf1,0xc3,0xc3,0xe7,0xc1,0xc3,0xe1,0x81,0x81,0xc3,0x99,0xc3,0x87,0x99,0xf9,0x39,0x99,0xc3,0xc1,0xc3,0xc1,0xc3,0x81,0x99,0x99,0x39,0x99,0x99,0x81,0xc3,0xff,0xc3,0xf7,0xff,0xc3,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x8f,0xe7,0xf1,0xff,0xff,
RectLeftTable:  0xff,0xfe,0xfc,0xf8,0xf0,0xe0,0xc0,0x80,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe0,0x07,0x00,0x18,0x66,0x66,0x7c,0x66,0x66,0x30,0x18,0x18,0x66,0x18,0x00,0x00,0x00,0xc0,0x66,0x18,0x66,0x66,0x70,0x06,0x66,0x66,0x66,0x66,0x00,0x00,0x18,0x00,0x18,0x66,0x66,0x3c,0x66,0x66,0x36,0x06,0x06,0x66,0x66,0x18,0x30,0x36,0x06,0xee,0x6e,0x66,0x66,0x66,0x66,0x66,0x18,0x66,0x66,0xc6,0x66,0x66,0x60,0x0c,0x06,0x30,0x1c,0x00,0x66,0x00,0x06,0x00,0x60,0x00,0x70,0x00,0x06,0x18,0x60,0x06,0x1c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x00,0x08,0x00,0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x18,0x18,0xfe,0x7f,0xc0,0x03,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0xe7,0x99,0x99,0x83,0x99,0x99,0xcf,0xe7,0xe7,0x99,0xe7,0xff,0xff,0xff,0x3f,0x99,0xe7,0x99,0x99,0x8f,0xf9,0x99,0x99,0x99,0x99,0xff,0xff,0xe7,0xff,0xe7,0x99,0x99,0xc3,0x99,0x99,0xc9,0xf9,0xf9,0x99,0x99,0xe7,0xcf,0xc9,0xf9,0x11,0x91,0x99,0x99,0x99,0x99,0x99,0xe7,0x99,0x99,0x39,0x99,0x99,0x9f,0xf3,0xf9,0xcf,0xe3,0xff,0x99,0xff,0xf9,0xff,0x9f,0xff,0x8f,0xff,0xf9,0xe7,0x9f,0xf9,0xe3,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xe7,0xff,0xff,0xff,0xff,0xff,0xff,0xe7,0xe7,0xe7,0xff,0xf7,
RectRightTable: 0x01,0x03,0x07,0x0f,0x1f,0x3f,0x7f,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x70,0x0e,0x00,0x18,0x66,0xff,0x06,0x30,0x3c,0x30,0x0c,0x30,0x3c,0x18,0x00,0x00,0x00,0x60,0x76,0x1c,0x60,0x60,0x78,0x3e,0x06,0x30,0x66,0x66,0x18,0x18,0x0c,0x7e,0x30,0x60,0x76,0x66,0x66,0x06,0x66,0x06,0x06,0x06,0x66,0x18,0x30,0x1e,0x06,0xfe,0x7e,0x66,0x66,0x66,0x66,0x06,0x18,0x66,0x66,0xc6,0x3c,0x66,0x30,0x0c,0x0c,0x30,0x36,0x00,0x76,0x3c,0x06,0x3c,0x60,0x3c,0x18,0x7c,0x06,0x00,0x00,0x06,0x18,0x66,0x3e,0x3c,0x3e,0x7c,0x3e,0x7c,0x7e,0x66,0x66,0xc6,0x66,0x66,0x7e,0x18,0x18,0x18,0x00,0x0c,0x00,0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x38,0x1c,0xfc,0x3f,0xe0,0x07,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0xe7,0x99,0x00,0xf9,0xcf,0xc3,0xcf,0xf3,0xcf,0xc3,0xe7,0xff,0xff,0xff,0x9f,0x89,0xe3,0x9f,0x9f,0x87,0xc1,0xf9,0xcf,0x99,0x99,0xe7,0xe7,0xf3,0x81,0xcf,0x9f,0x89,0x99,0x99,0xf9,0x99,0xf9,0xf9,0xf9,0x99,0xe7,0xcf,0xe1,0xf9,0x01,0x81,0x99,0x99,0x99,0x99,0xf9,0xe7,0x99,0x99,0x39,0xc3,0x99,0xcf,0xf3,0xf3,0xcf,0xc9,0xff,0x89,0xc3,0xf9,0xc3,0x9f,0xc3,0xe7,0x83,0xf9,0xff,0xff,0xf9,0xe7,0x99,0xc1,0xc3,0xc1,0x83,0xc1,0x83,0x81,0x99,0x99,0x39,0x99,0x99,0x81,0xe7,0xe7,0xe7,0xff,0xf3,
                0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x38,0x1c,0x00,0x18,0x00,0x66,0x3c,0x18,0x1c,0x00,0x0c,0x30,0xff,0x7e,0x00,0x7e,0x00,0x30,0x6e,0x18,0x30,0x38,0x66,0x60,0x3e,0x18,0x3c,0x7c,0x00,0x00,0x06,0x00,0x60,0x30,0x76,0x7e,0x3e,0x06,0x66,0x1e,0x1e,0x76,0x7e,0x18,0x30,0x0e,0x06,0xd6,0x7e,0x66,0x3e,0x66,0x3e,0x3c,0x18,0x66,0x66,0xd6,0x18,0x3c,0x18,0x0c,0x18,0x30,0x63,0x00,0x76,0x60,0x3e,0x06,0x7c,0x66,0x7c,0x66,0x3e,0x1c,0x60,0x36,0x18,0xfe,0x66,0x66,0x66,0x66,0x66,0x06,0x18,0x66,0x66,0xd6,0x3c,0x66,0x30,0x0e,0x18,0x70,0xdc,0xfe,0xf8,0xff,0x1f,0xf8,0xff,0x1f,0xf8,0xff,0x1f,0xff,0xe0,0x07,0xf0,0x0f,0xf8,0x1f,0xf0,0x0f,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0x00,0xf0,0x0f,0xff,0xe7,0xff,0x99,0xc3,0xe7,0xe3,0xff,0xf3,0xcf,0x00,0x81,0xff,0x81,0xff,0xcf,0x91,0xe7,0xcf,0xc7,0x99,0x9f,0xc1,0xe7,0xc3,0x83,0xff,0xff,0xf9,0xff,0x9f,0xcf,0x89,0x81,0xc1,0xf9,0x99,0xe1,0xe1,0x89,0x81,0xe7,0xcf,0xf1,0xf9,0x29,0x81,0x99,0xc1,0x99,0xc1,0xc3,0xe7,0x99,0x99,0x29,0xe7,0xc3,0xe7,0xf3,0xe7,0xcf,0x9c,0xff,0x89,0x9f,0xc1,0xf9,0x83,0x99,0x83,0x99,0xc1,0xe3,0x9f,0xc9,0xe7,0x01,0x99,0x99,0x99,0x99,0x99,0xf9,0xe7,0x99,0x99,0x29,0xc3,0x99,0xcf,0xf1,0xe7,0x8f,0x23,0x01,
                0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x1c,0x38,0x00,0x00,0x00,0xff,0x60,0x0c,0xe6,0x00,0x0c,0x30,0x3c,0x18,0x00,0x00,0x00,0x18,0x66,0x18,0x0c,0x60,0xfe,0x60,0x66,0x18,0x66,0x60,0x00,0x00,0x0c,0x7e,0x30,0x18,0x06,0x66,0x66,0x06,0x66,0x06,0x06,0x66,0x66,0x18,0x30,0x1e,0x06,0xc6,0x76,0x66,0x06,0x66,0x1e,0x60,0x18,0x66,0x66,0xfe,0x3c,0x18,0x0c,0x0c,0x30,0x30,0x00,0x00,0x06,0x7c,0x66,0x06,0x66,0x7e,0x18,0x66,0x66,0x18,0x60,0x1e,0x18,0xfe,0x66,0x66,0x66,0x66,0x06,0x3c,0x18,0x66,0x66,0xfe,0x18,0x66,0x18,0x18,0x18,0x18,0x76,0xfe,0xf8,0xff,0x1f,0xf8,0xff,0x1f,0xf8,0xff,0x1f,0xff,0xf0,0x0f,0xe0,0x07,0xf0,0x0f,0xf8,0x1f,0x00,0x00,0x00,0xf0,0xf0,0xf0,0xf0,0x0f,0x0f,0x0f,0x0f,0xff,0xff,0xff,0xff,0xff,0xff,0x00,0x9f,0xf3,0x19,0xff,0xf3,0xcf,0xc3,0xe7,0xff,0xff,0xff,0xe7,0x99,0xe7,0xf3,0x9f,0x01,0x9f,0x99,0xe7,0x99,0x9f,0xff,0xff,0xf3,0x81,0xcf,0xe7,0xf9,0x99,0x99,0xf9,0x99,0xf9,0xf9,0x99,0x99,0xe7,0xcf,0xe1,0xf9,0x39,0x89,0x99,0xf9,0x99,0xe1,0x9f,0xe7,0x99,0x99,0x01,0xc3,0xe7,0xf3,0xf3,0xcf,0xcf,0xff,0xff,0xf9,0x83,0x99,0xf9,0x99,0x81,0xe7,0x99,0x99,0xe7,0x9f,0xe1,0xe7,0x01,0x99,0x99,0x99,0x99,0xf9,0xc3,0xe7,0x99,0x99,0x01,0xe7,0x99,0xe7,0xe7,0xe7,0xe7,0x89,0x01,
                0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0e,0x70,0x00,0x00,0x00,0x66,0x3e,0x66,0x66,0x00,0x18,0x18,0x66,0x18,0x18,0x00,0x18,0x0c,0x66,0x18,0x06,0x66,0x60,0x66,0x66,0x18,0x66,0x66,0x18,0x18,0x18,0x00,0x18,0x00,0x66,0x66,0x66,0x66,0x36,0x06,0x06,0x66,0x66,0x18,0x36,0x36,0x06,0xc6,0x66,0x66,0x06,0x3c,0x36,0x66,0x18,0x66,0x3c,0xee,0x66,0x18,0x06,0x0c,0x60,0x30,0x00,0x00,0x66,0x66,0x66,0x06,0x66,0x06,0x18,0x7c,0x66,0x18,0x60,0x36,0x18,0xd6,0x66,0x66,0x3e,0x7c,0x06,0x60,0x18,0x66,0x3c,0x7c,0x3c,0x7c,0x0c,0x18,0x18,0x18,0x00,0x0c,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x38,0x1c,0x00,0x00,0xe0,0x07,0xfc,0x3f,0x00,0x00,0x00,0xf0,0xf0,0xf0,0xf0,0x0f,0x0f,0x0f,0x0f,0xff,0xff,0xff,0xff,0xff,0xff,0x99,0xc1,0x99,0x99,0xff,0xe7,0xe7,0x99,0xe7,0xe7,0xff,0xe7,0xf3,0x99,0xe7,0xf9,0x99,0x9f,0x99,0x99,0xe7,0x99,0x99,0xe7,0xe7,0xe7,0xff,0xe7,0xff,0x99,0x99,0x99,0x99,0xc9,0xf9,0xf9,0x99,0x99,0xe7,0xc9,0xc9,0xf9,0x39,0x99,0x99,0xf9,0xc3,0xc9,0x99,0xe7,0x99,0xc3,0x11,0x99,0xe7,0xf9,0xf3,0x9f,0xcf,0xff,0xff,0x99,0x99,0x99,0xf9,0x99,0xf9,0xe7,0x83,0x99,0xe7,0x9f,0xc9,0xe7,0x29,0x99,0x99,0xc1,0x83,0xf9,0x9f,0xe7,0x99,0xc3,0x83,0xc3,0x83,0xf3,0xe7,0xe7,0xe7,0xff,0xf3,
                0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x07,0xe0,0x00,0x18,0x00,0x66,0x18,0x62,0xfc,0x00,0x30,0x0c,0x00,0x00,0x18,0x00,0x18,0x06,0x3c,0x7e,0x7e,0x3c,0x60,0x3c,0x3c,0x18,0x3c,0x3c,0x00,0x18,0x70,0x00,0x0e,0x18,0x3c,0x66,0x3e,0x3c,0x1e,0x7e,0x06,0x3c,0x66,0x3c,0x1c,0x66,0x7e,0xc6,0x66,0x3c,0x06,0x70,0x66,0x3c,0x18,0x3c,0x18,0xc6,0x66,0x18,0x7e,0x3c,0xc0,0x3c,0x00,0x00,0x3c,0x7c,0x3e,0x3c,0x7c,0x3c,0x18,0x60,0x66,0x3c,0x60,0x66,0x3c,0xc6,0x66,0x3c,0x06,0x60,0x06,0x3e,0x70,0x7c,0x18,0x6c,0x66,0x30,0x7e,0x70,0x18,0x0e,0x00,0x08,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0xc0,0x03,0xfe,0x7f,0x00,0x00,0x00,0xf0,0xf0,0xf0,0xf0,0x0f,0x0f,0x0f,0x0f,0xff,0xff,0xff,0xff,0xe7,0xff,0x99,0xe7,0x9d,0x03,0xff,0xcf,0xf3,0xff,0xff,0xe7,0xff,0xe7,0xf9,0xc3,0x81,0x81,0xc3,0x9f,0xc3,0xc3,0xe7,0xc3,0xc3,0xff,0xe7,0x8f,0xff,0xf1,0xe7,0xc3,0x99,0xc1,0xc3,0xe1,0x81,0xf9,0xc3,0x99,0xc3,0xe3,0x99,0x81,0x39,0x99,0xc3,0xf9,0x8f,0x99,0xc3,0xe7,0xc3,0xe7,0x39,0x99,0xe7,0x81,0xc3,0x3f,0xc3,0xff,0xff,0xc3,0x83,0xc1,0xc3,0x83,0xc3,0xe7,0x9f,0x99,0xc3,0x9f,0x99,0xc3,0x39,0x99,0xc3,0xf9,0x9f,0xf9,0xc1,0x8f,0x83,0xe7,0x93,0x99,0xcf,0x81,0x8f,0xe7,0xf1,0xff,0xf7,
                0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x03,0xc0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x0c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3e,0x00,0x00,0x3c,0x00,0x00,0x00,0x00,0x00,0x06,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x1e,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x80,0x01,0xff,0xff,0x00,0x00,0x00,0xf0,0xf0,0xf0,0xf0,0x0f,0x0f,0x0f,0x0f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xf3,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xf3,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xc1,0xff,0xff,0xc3,0xff,0xff,0xff,0xff,0xff,0xf9,0x9f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xe1,0xff,0xff,0xe7,0xff,0xff,0xff,

#org 0x1800
  #mute
  #org 0x0800   ; LSB of the VRAM line address
  #emit
LineLSBTable:   0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,
                0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,0x0c,0x4c,0x8c,0xcc,

#org 0x1900
  #mute
  #org 0x0900   ; MSB of the VRAM line address
  #emit
LineMSBTable:   0xc3,0xc3,0xc3,0xc3,0xc4,0xc4,0xc4,0xc4,0xc5,0xc5,0xc5,0xc5,0xc6,0xc6,0xc6,0xc6,0xc7,0xc7,0xc7,0xc7,
                0xc8,0xc8,0xc8,0xc8,0xc9,0xc9,0xc9,0xc9,0xca,0xca,0xca,0xca,0xcb,0xcb,0xcb,0xcb,0xcc,0xcc,0xcc,0xcc,
                0xcd,0xcd,0xcd,0xcd,0xce,0xce,0xce,0xce,0xcf,0xcf,0xcf,0xcf,0xd0,0xd0,0xd0,0xd0,0xd1,0xd1,0xd1,0xd1,
                0xd2,0xd2,0xd2,0xd2,0xd3,0xd3,0xd3,0xd3,0xd4,0xd4,0xd4,0xd4,0xd5,0xd5,0xd5,0xd5,0xd6,0xd6,0xd6,0xd6,
                0xd7,0xd7,0xd7,0xd7,0xd8,0xd8,0xd8,0xd8,0xd9,0xd9,0xd9,0xd9,0xda,0xda,0xda,0xda,0xdb,0xdb,0xdb,0xdb,
                0xdc,0xdc,0xdc,0xdc,0xdd,0xdd,0xdd,0xdd,0xde,0xde,0xde,0xde,0xdf,0xdf,0xdf,0xdf,0xe0,0xe0,0xe0,0xe0,
                0xe1,0xe1,0xe1,0xe1,0xe2,0xe2,0xe2,0xe2,0xe3,0xe3,0xe3,0xe3,0xe4,0xe4,0xe4,0xe4,0xe5,0xe5,0xe5,0xe5,
                0xe6,0xe6,0xe6,0xe6,0xe7,0xe7,0xe7,0xe7,0xe8,0xe8,0xe8,0xe8,0xe9,0xe9,0xe9,0xe9,0xea,0xea,0xea,0xea,
                0xeb,0xeb,0xeb,0xeb,0xec,0xec,0xec,0xec,0xed,0xed,0xed,0xed,0xee,0xee,0xee,0xee,0xef,0xef,0xef,0xef,
                0xf0,0xf0,0xf0,0xf0,0xf1,0xf1,0xf1,0xf1,0xf2,0xf2,0xf2,0xf2,0xf3,0xf3,0xf3,0xf3,0xf4,0xf4,0xf4,0xf4,
                0xf5,0xf5,0xf5,0xf5,0xf6,0xf6,0xf6,0xf6,0xf7,0xf7,0xf7,0xf7,0xf8,0xf8,0xf8,0xf8,0xf9,0xf9,0xf9,0xf9,
                0xfa,0xfa,0xfa,0xfa,0xfb,0xfb,0xfb,0xfb,0xfc,0xfc,0xfc,0xfc,0xfd,0xfd,0xfd,0xfd,0xfe,0xfe,0xfe,0xfe,

#org 0x1a00
  #mute
  #org 0x0a00   ; PS/2 lookup table (in: PS/2 scancode and state PLAIN, SHIFT, ALTGR or CTRL, out: ASCII code)
  #emit
                ; '_ReadInput' and '_WaitInput' emit the following pseudo-ASCII codes for special PS/2 keypresses:
                ; ------------------------------------------------------------------------------------------------
                ; 0xe0 - 0xe7: CTRL q, Cursor Up, Cursor Down, Cursor Left, Cursor Right, Pos1, End, Page Up
                ; 0xe8 - 0xef: Page Down, CTRL a, CTRL x, CTRL c, CTRL v, CTRL l, CTRL s, CTRL n
                ; 0xf0 - 0xf2: Delete, CTRL r, CTRL t
                ; 0xf3 - 0xff: unused

PS2Table:       ; GERMAN KEYBOARD LAYOUT
  ; state: PLAIN keys
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0, 0x09,  '^',    0,  ;  0x0_
        0,    0,    0,    0,    0,  'q',  '1',    0,    0,    0,  'y',  's',  'a',  'w',  '2',    0,  ;  0x1_
        0,  'c',  'x',  'd',  'e',  '4',  '3',    0,    0,  ' ',  'v',  'f',  't',  'r',  '5',    0,  ;  0x2_
        0,  'n',  'b',  'h',  'g',  'z',  '6',    0,    0,    0,  'm',  'j',  'u',  '7',  '8',    0,  ;  0x3_
        0,  ',',  'k',  'i',  'o',  '0',  '9',    0,    0,  '.',  '-',  'l',    0,  'p',    0,    0,  ;  0x4_
        0,    0,    0,    0,    0,   39,    0,    0,    0,    0,   10,  '+',    0,  '#',    0,    0,  ;  0x5_
        0,  '<',    0,    0,    0,    0,    8,    0,    0, 0xe6,    0, 0xe3, 0xe5,    0,    0,    0,  ;  0x6_
        0, 0xf0, 0xe2,    0, 0xe4, 0xe1,   27,    0,    0,    0, 0xe8,    0,    0, 0xe7,    0,    0,  ;  0x7_
  ;  -------------------------------------------------------------------------------------------------+------
  ;  0x_0  0x_1  0x_2  0x_3  0x_4  0x_5  0x_6  0x_7  0x_8  0x_9  0x_a  0x_b  0x_c  0x_d  0x_e  0x_f   ;  scan
  ;                                                                                                   ;  code
  ; state: with SHIFT
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x0_
        0,    0,    0,    0,    0,  'Q',  '!',    0,    0,    0,  'Y',  'S',  'A',  'W',  '"',    0,  ;  0x1_
        0,  'C',  'X',  'D',  'E',  '$',    0,    0,    0,    0,  'V',  'F',  'T',  'R',  '%',    0,  ;  0x2_
        0,  'N',  'B',  'H',  'G',  'Z',  '&',    0,    0,    0,  'M',  'J',  'U',  '/',  '(',    0,  ;  0x3_
        0,  ';',  'K',  'I',  'O',  '=',  ')',    0,    0,  ':',  '_',  'L',    0,  'P',  '?',    0,  ;  0x4_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  '*',    0,   39,    0,    0,  ;  0x5_
        0,  '>',    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x6_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x7_
  ;  -------------------------------------------------------------------------------------------------+------
  ;  0x_0  0x_1  0x_2  0x_3  0x_4  0x_5  0x_6  0x_7  0x_8  0x_9  0x_a  0x_b  0x_c  0x_d  0x_e  0x_f   ;  scan
  ;                                                                                                   ;  code

  ; state: with ALTGR(=ALT)
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x0_
        0,    0,    0,    0,    0,  '@',    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x1_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x2_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  '{',  '[',    0,  ;  0x3_
        0,    0,    0,    0,    0,  '}',  ']',    0,    0,    0,    0,    0,    0,    0,  '\',    0,  ;  0x4_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  '~',    0,    0,    0,    0,  ;  0x5_
        0,  '|',    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x6_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x7_
  ;  -------------------------------------------------------------------------------------------------+------
  ;  0x_0  0x_1  0x_2  0x_3  0x_4  0x_5  0x_6  0x_7  0x_8  0x_9  0x_a  0x_b  0x_c  0x_d  0x_e  0x_f   ;  scan
  ;                                                                                                   ;  code
  ; state: with CTRL(=STRG)
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x0_
        0,    0,    0,    0,    0, 0xe0,    0,    0,    0,    0,    0, 0xee, 0xe9,    0,    0,    0,  ;  0x1_
        0, 0xeb, 0xea,    0,    0,    0,    0,    0,    0,    0, 0xec,    0, 0xf2, 0xf1,    0,    0,  ;  0x2_
        0, 0xef,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x3_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0, 0xed,    0,    0,    0,    0,  ;  0x4_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x5_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x6_
        0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  ;  0x7_
  ;  -------------------------------------------------------------------------------------------------+------
  ;  0x_0  0x_1  0x_2  0x_3  0x_4  0x_5  0x_6  0x_7  0x_8  0x_9  0x_a  0x_b  0x_c  0x_d  0x_e  0x_f   ;  scan
  ;                                                                                                   ;  code

#org 0x1c00
  #mute
  #org 0x0c00   ; 80 x 32 pixel 'Minimal' logo (320 bytes)
  #emit
MinimalLogo:    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,
                0x80,0x07,0x00,0x00,0x0e,0x00,0x00,0x00,0x80,0xe3,0x80,0x0f,0x00,0x80,0x1f,0x00,0x00,0x00,0xc0,0xe0,
                0x80,0x3f,0x00,0xc0,0x1f,0x00,0x00,0x00,0xe0,0xe0,0x80,0x7b,0x00,0xf0,0x1f,0x00,0x00,0x00,0x70,0xe0,
                0x80,0xf3,0x01,0xfc,0x0e,0x00,0x00,0x00,0x30,0xe0,0x80,0xe3,0x03,0x3e,0x0e,0x00,0x00,0x00,0x38,0x60,
                0x00,0x87,0x87,0x0f,0x0e,0x00,0x00,0x00,0x18,0x70,0x00,0x07,0xcf,0x07,0x07,0x00,0x00,0x00,0x1c,0x30,
                0x00,0x07,0xfe,0x01,0x07,0x00,0x00,0x00,0x1c,0x38,0x00,0x07,0xfc,0x00,0x03,0x00,0x00,0x00,0x0c,0x18,
                0x00,0x0e,0x30,0x80,0x03,0x00,0x00,0x00,0x0c,0x0c,0x00,0x0e,0x00,0x80,0x03,0x00,0x00,0x00,0x0e,0x0e,
                0x00,0x0e,0x00,0x80,0x01,0x00,0x00,0x00,0x0e,0x06,0x00,0x07,0x00,0x80,0x01,0x00,0x00,0x00,0x0e,0x03,
                0x00,0x07,0x00,0xc0,0x01,0x00,0x00,0x00,0x8e,0x01,0x80,0x03,0x80,0xc3,0x01,0x00,0x00,0x3e,0xce,0x00,
                0xc0,0xf3,0xc0,0xc7,0x03,0x00,0x80,0x3f,0x6e,0x00,0xc0,0xf9,0x80,0x87,0x03,0x00,0xc0,0x3d,0x3c,0x00,
                0xe0,0x38,0x00,0x80,0x83,0x01,0xce,0x1c,0xfe,0x3f,0xe0,0x00,0x00,0x00,0xc7,0x31,0xef,0xfe,0xe7,0x07,
                0x70,0x00,0x00,0x0c,0xc7,0xb9,0xe7,0xff,0x01,0x00,0x70,0x00,0x33,0x1e,0x8e,0xfd,0xe6,0x03,0x00,0x00,
                0x38,0x0e,0x3b,0x0e,0x8e,0x7f,0x06,0x00,0x00,0x00,0x38,0x8e,0x3f,0x0e,0x8e,0x3b,0x00,0x00,0x00,0x00,
                0x1c,0x87,0x3f,0x3e,0x9c,0x01,0x00,0x00,0x00,0x00,0x1c,0x87,0x3f,0x1e,0x1c,0x00,0x00,0x00,0x00,0x00,
                0x0e,0x9f,0x77,0x0c,0x38,0x00,0x00,0x00,0x00,0x00,0x0e,0x0f,0x03,0x00,0x38,0x00,0x00,0x00,0x00,0x00,
                0x0f,0x06,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x07,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,

#org 0x1d40     ; 0x1d40 - 0x1e7f unused

#org 0x1e80
  #mute
  #org 0x0e80   ; list of mnemonics
  #emit
Mnemonics:      'NOP', 'BNK', 'BFF', 'WIN', 'INP', 'INK', 'OUT',
                'NOT', 'NEG', 'INC', 'DEC', 'CLC', 'SEC',
                'LSL', 'LL2', 'LL3', 'LL4', 'LL5', 'LL6', 'LL7', 'LSR',
                'ROL', 'RL2', 'RL3', 'RL4', 'RL5', 'RL6', 'RL7', 'ROR',
                'LDI', 'ADI', 'SBI', 'ACI', 'SCI', 'CPI', 'ANI', 'ORI', 'XRI',
                'JPA', 'LDA', 'STA', 'ADA', 'SBA', 'ACA', 'SCA', 'CPA', 'ANA', 'ORA', 'XRA',
                'JPR', 'LDR', 'STR', 'ADR', 'SBR', 'ACR', 'SCR', 'CPR', 'ANR', 'ORR',
                'CLB', 'NOB', 'NEB', 'INB', 'DEB', 'ADB', 'SBB', 'ACB', 'SCB',
                'ANB', 'ORB', 'LLB', 'LRB', 'RLB', 'RRB',
                'CLW', 'NOW', 'NEW', 'INW', 'DEW', 'ADW', 'SBW', 'ACW', 'SCW', 'LLW', 'RLW',
                'JPS', 'RTS', 'PHS', 'PLS', 'LDS', 'STS',
                'BNE', 'BEQ', 'BCC', 'BCS', 'BPL', 'BMI', 'BGT', 'BLE',
                'TAX', 'TXA', 'TXY', 'LXI', 'LXA', 'LAX', 'INX', 'DEX', 'ADX', 'SBX', 'CPX', 'ANX', 'ORX', 'XRX',
                'TAY', 'TYA', 'TYX', 'LYI', 'LYA', 'LAY', 'INY', 'DEY', 'ADY', 'SBY', 'CPY', 'ANY', 'ORY', 'XRY',
                'HLT'

; **********************************************************************************************************

#org 0x2000

'save', 0, '              ', 0, SaveStart, SaveEnd-SaveStart    ; file header

  #mute
  #org 0xbf00                                                   ; target address at the end of OS kernel RAM
  #emit                                                         ; this allows to save code with target 0xbd00

  ; --------------------------------------------------
  ; usage: "save <first_hex_addr> <last_hex_addr> <filename> <ENTER>"
  ; receives access to command line on stack
  ; --------------------------------------------------
  SaveStart:      LXI 1                                         ; read in first and last hex woard address
    sv_loop:      JPS _ReadSpace JPS _ReadHex                   ; skip spaces and parse first address
                  LDA _ReadNum+2 CPI 0xf0 BEQ sv_syntax         ; wurde eine Zahl eingelesen?
                    LDA _ReadNum+0 PHS LDA _ReadNum+1 PHS       ; push onto stack
                  DEX BCS sv_loop
                    JPS _ReadSpace
                    LDR _ReadPtr CPI 39 BLE sv_syntax           ; look for a valid filename
                      JPS OS_SaveFile CPI 0 BNE _Prompt
                        LDI <sv_errortxt PHS LDI >sv_errortxt PHS
                        JPA sv_print
    sv_syntax:      LDI <sv_syntaxtxt PHS LDI >sv_syntaxtxt PHS
    sv_print:       JPS _Print JPA _Prompt                      ; stack cleanup intentionally left out

    sv_syntaxtxt: 'save <fst> <lst> <name>', 10, 0
    sv_errortxt:  '?ERROR.', 10, 0

  SaveEnd:

; **********************************************************************************************************

'dir', 0, '               ', 0, DirStart, DirEnd-DirStart       ; file header

  #mute
  #org 0xbd00                                                   ; target address of the code
  #emit

  ; --------------------------------------------------
  ; Displays the directory of the SSD drive
  ; usage: "dir <ENTER>"
  ; --------------------------------------------------
  DirStart:       LDI <dirtext PHS LDI >dirtext PHS JPS _Print PLS PLS ; print the directory headline
                  LDI 2 STA PtrA+2 BNK CLW PtrA                        ; FLASH on, point PtrA to start of SSD
                  LDI 0x07 STA PtrC+2 LDI 0xe0 STA PtrC+1 CLB PtrC+0   ; 0x7e banks = SSD - 8KB -> PtrC in chunks of 16 bytes

  dc_lookfiles:   LDA PtrA+2 BNK LDR PtrA CPI 0xff BEQ dc_endreached   ; end of used area reached?

                    ; first extract all data, later decide on printing
                    LDA PtrA+0 STA _ReadNum+0                          ; copy PtrA and PtrA+2 for printing
                    LDA PtrA+1 STA _ReadNum+1
                    LDA PtrA+2 BNK STA _ReadNum+2
                    LDI 20 ADW PtrA JPS dc_FlashA                      ; read start address -> PtrE
                    LDR PtrA STA PtrE+0 INW PtrA JPS dc_FlashA
                    LDR PtrA STA PtrE+1 INW PtrA JPS dc_FlashA
                    LDR PtrA STA PtrB+0 INW PtrA JPS dc_FlashA         ; read bytesize -> PtrB, F
                    LDR PtrA STA PtrB+1 INW PtrA JPS dc_FlashA         ; PtrA, PtrA+2 now point to data section
                    LDA PtrB+0 ADW PtrA+0                              ; add data byte size to reach next file pos
                    LDA PtrB+1 ADB PtrA+1 JPS dc_FlashA
                    LDA PtrB+0 SBW PtrC LDI 0 SCB PtrC+2               ; subtract data bytesize in PtrB from PtrC
                    LDA PtrB+1 SBW PtrC+1
                    LDI 24 SBW PtrC LDI 0 SCB PtrC+2                   ; subtract headersize from PtrC

                    CLB _XPos
                    JPS _ReadInput
                    CPI 0x0a BEQ _Prompt                               ; ENTER = user break
                    CPI 27 BEQ _Prompt                                 ; ESC = user break

                    LDA _ReadNum+2 BNK LDR _ReadNum CPI 0 BEQ dc_lookfiles  ; check once if info should be printed
  dc_nextchar:        PHS JPS _PrintChar PLS                           ; print filename
                      INW _ReadNum SBI 0x10 BCC dc_noover
                        STA _ReadNum+1 INB _ReadNum+2 BNK
  dc_noover:          LDA _ReadNum+2 BNK LDR _ReadNum CPI 0 BNE dc_nextchar  ; print stuff here
  dc_nameend:         LDI 20 STA _XPos
                      LDA PtrE+1 PHS JPS _PrintHex PLS                 ; start
                      LDA PtrE+0 PHS JPS _PrintHex PLS
                      LDI 27 STA _XPos
                      LDA PtrB+1 PHS JPS _PrintHex PLS                 ; bytesize
                      LDA PtrB+0 PHS JPS _PrintHex PLS
                      INB _YPos CPI 30 BCC dc_lookfiles                ; number of rows
                        DEB _YPos JPS _ScrollUp JPA dc_lookfiles

  dc_endreached:  LDI 25 STA _XPos
                  LDA PtrC+2 PHS JPS _PrintHex PLS
                  LDA PtrC+1 PHS JPS _PrintHex PLS
                  LDA PtrC+0 PHS JPS _PrintHex PLS
                  LDI 20 STA _XPos LDI <freetext PHS LDI >freetext PHS JPS _Print
                  JPA _Prompt

  dirtext:      10, 'FILENAME........... DEST ..SIZE (ESC to stop)', 10, 0
  freetext:     'FREE ', 10, 0

  ; Produces a FLASH/BANK address in the correct form: PtrA+2: bank, PtrA0..1: 12bit section address
  ; Adds the value of bits 12-15 of PtrA to PtrA+2, updates bank register and clears upper nibble of PtrA
  ; Call this routine everytime a FLASH pointer PtrA is modified!
  ; modifies: PtrA+0..2, bank register
  dc_FlashA:      LDA PtrA+1 RL5 ANI 0x0f    ; is something in the upper nibble?
                  CPI 0 BEQ dc_farts
                    ADB PtrA+2 BNK           ; there was something -> update bank register PtrA+2
                    LDI 0x0f ANB PtrA+1      ; correct PtrA+1
    dc_farts:     RTS

  DirEnd:

; **********************************************************************************************************

'defrag', 0, '            ', 0, DefragStart, DefragEnd-DefragStart     ; file header

  #mute
  #org 0xbd00                                                          ; target address of the code
  #emit

  ; ---------------------------------------------------------------
  ; Defragments the SSD by removing/formating/freeing deleted parts
  ; usage: "defrag <ENTER>"
  ; ---------------------------------------------------------------
  DefragStart:    LDI 3 STA dg_next+2 STA dg_bis+2 STA dg_newbank      ; pnext = pbis = FLASH start
                  CLW dg_next CLW dg_bis

    dg_nextchunk: CLW dg_ram                                           ; reset RAM buffer pointer

    dg_biseqnext: LDA dg_bis+0 CPA dg_next+0 BNE dg_copyabyte          ; bis = next?
                    LDA dg_bis+1 CPA dg_next+1 BNE dg_copyabyte
                      LDA dg_bis+2 CPA dg_next+2 BNE dg_copyabyte
                        ; current file was processed (read into RAM) completely => fetch next one
                        LDA dg_next+0 STA PtrA+0                       ; bis now points beyond current file
                        LDA dg_next+1 STA PtrA+1
                        LDA dg_next+2 STA PtrA+2                       ; set bank register
      dg_checknext:     LDA PtrA+2 BNK LDR PtrA                        ; READ BYTE AT "NEXT" LOCATION
                        CPI 0xff BEQ dg_endofused                      ; END OF USED SSD AREA REACHED?
                          PHS                                          ; NO! -> store first byte of filename
                          LDI 22 ADW PtrA JPS dg_FlashA                ; extract data bytesize
                          LDR PtrA STA PtrB+0 INW PtrA JPS dg_FlashA   ; read bytesize -> PtrB
                          LDR PtrA STA PtrB+1 INW PtrA JPS dg_FlashA   ; PtrA now point to data section
                          LDA PtrB+0 ADW PtrA+0                        ; add data byte size to reach next file pos
                          LDA PtrB+1 ADB PtrA+1 JPS dg_FlashA          ; PtrA points beyond current file
                          LDA PtrA+0 STA dg_next+0                     ; WE HAVE AN UNTESTED NEW NEXT FILE LOCATION
                          LDA PtrA+1 STA dg_next+1
                          LDA PtrA+2 STA dg_next+2
                          PLS CPI 0 BNE dg_copythisfile                ; *bis = 0? Was that a visible file that needs copying?
                            LDI '.' PHS JPS _PrintChar PLS             ; signal an invisible fragment
                            LDA dg_next+0 STA dg_bis+0                 ; mark it as processed...
                            LDA dg_next+1 STA dg_bis+1                 ; ... without copying it to RAM
                            LDA dg_next+2 STA dg_bis+2                 ; now PtrA = next = bis
                            JPA dg_checknext                           ; go look for a non-deleted file
    dg_copythisfile:      LDI '#' PHS JPS _PrintChar PLS               ; signal a visible file
                          JPA dg_biseqnext                             ; reenter copying loop

    dg_copyabyte: LDA dg_ram+1 CPI 0x80 BCC dg_ramokay                 ; is there enough space in RAM buffer?
                    ; RAM buffer is full => byte cannot be read and written
                    JPS writeRAM LDA PtrB+1 CPI 0xff BEQ dg_nextchunk  ; formats and writes (unfinished) chunk
      dg_error:       LDI <dg_errtxt PHS LDI >dg_errtxt PHS            ; error message
                      JPS _Print
                      JPA _Prompt
    dg_ramokay:   ; read a byte from 'dg_bis' to dg_ram
                  LDA dg_bis+2 BNK                                     ; set bank register for read
                  LDR dg_bis BFF STR dg_ram                            ; read FLASH address and result store in RAM
                  INW dg_ram INW dg_bis SBI 0x10 BCC dg_biseqnext
                    STA dg_bis+1 INB dg_bis+2 JPA dg_biseqnext

; writes a chunk of used data in RAM to FLASH starting at bank 'dg_newbank+1' 0x000
  writeRAM:     CLW PtrA LDA dg_newbank STA PtrA+2                     ; set FLASH write destination
                LDA dg_ram+0 STA PtrB+0                                ; bytesize = RAM "beyond" pointer
                LDA dg_ram+1 STA PtrB+1
                CLW PtrC                                               ; set RAM source 0x0000
                DEW dg_ram BCS dg_bytes                                ; calculate "last used" RAM location
                  STA PtrB+0 STA PtrB+1 RTS                            ; return "success" since nothing was written
  dg_bytes:     LDA dg_ram+1 RL5 ANI 0x0f TAX                          ; get nibble (bits 12-15), add 1 for number
  dg_bankloop:  LDA dg_newbank PHS JPS OS_FLASHErase PLS               ; erase this FLASH bank
                INB dg_newbank                                         ; goto next free bank
                DEX BCS dg_bankloop
                  LDA PtrA+2 BNK                                       ; set bank register, everything else was set above
                  JPS OS_FLASHWrite                                    ; write used RAM chunk to FLASH
                  RTS

; end of used SSD area => write the rest of RAM buffer to FLASH, format all used banks above
  dg_endofused: JPS writeRAM LDA PtrB+1 CPI 0xff BNE dg_error          ; formats and writes (unfinished) chunk
                DEW dg_bis BCS dg_laloop                               ; perform dg_bis-- to point to "last processed" location
                  DEB dg_bis+2                                         ; calculate the max used FLASH bank
    dg_laloop:  LDA dg_newbank CPA dg_bis+2 BGT dg_raus
                  PHS JPS OS_FLASHErase PLS                            ; format this bank
                  INB dg_newbank JPA dg_laloop
    dg_raus:    LDI 10 PHS JPS OS_PrintChar                            ; ENTER
                JPA _Prompt                                            ; END

  ; Produces a FLASH/BANK address in the correct form: PtrA+2: bank, PtrA0..1: 12bit section address
  ; Adds the value of bits 12-15 of PtrA to PtrA+2, updates bank register and clears upper nibble of PtrA
  ; Call this routine everytime a FLASH pointer PtrA is modified!
  ; modifies: PtrA+0..2, bank register
  dg_FlashA:      LDA PtrA+1 RL5 ANI 0x0f    ; is something in the upper nibble?
                  CPI 0 BEQ dg_farts
                    ADB PtrA+2 BNK           ; there was something -> update bank register PtrA+2
                    LDI 0x0f ANB PtrA+1      ; correct PtrA+1
    dg_farts:     RTS

  dg_errtxt:      '?ERROR.', 10, 0

  dg_ram:         0xffff                     ; pointer to next free RAM location (0x0000..0x8000)
  dg_bis:         0xff, 0xffff               ; pointer (bank/sector addr) to last read location of FLASH
  dg_next:        0xff, 0xffff               ; pointer beyond current file's FLASH area
  dg_newbank:     0xff

  DefragEnd:

; **********************************************************************************************************

'run', 0, '               ', 0, RunStart, RunEnd-RunStart ; file header

  #mute
  #org 0xbd00                                             ; target address of the code
  #emit

  ; --------------------------------------------------
  ; Displays the directory of the SSD drive
  ; usage: "jump <address> <ENTER>"
  ; --------------------------------------------------
  RunStart:       JPS _ReadSpace JPS _ReadHex             ; skip spaces and parse first address
                  LDA _ReadNum+2 CPI 0xf0 BEQ 0x0000      ; default ist 0x0000
                    JPR _ReadNum

  RunEnd:

; **********************************************************************************************************

'clear', 0, '             ', 0, ClearStart, ClearEnd-ClearStart    ; file header

  #mute
  #org 0xbd00                                             ; target address of the code
  #emit

  ; --------------------------------------------------
  ; Clears the VGA screen and positions the cursor at the top
  ; usage: "jump <address> <ENTER>"
  ; --------------------------------------------------
  ClearStart:     JPS _Clear
                  CLB _XPos CLB _YPos
                  JPS _Prompt

  ClearEnd:

; **********************************************************************************************************

'del', 0, '               ', 0, DelStart, DelEnd-DelStart ; file header

  #mute
  #org 0xbd00                                             ; target address of the code
  #emit

  ; --------------------------------------------------
  ; Deletes a file from the SSD
  ; usage: "del <filename> <ENTER>"
  ; modifies: X
  ; --------------------------------------------------
  DelStart:       JPS _ReadSpace
                  LDR _ReadPtr CPI 39 BLE de_syntax       ; look for a valid filename
                  ; invalidate exisiting file with that name
                    JPS _FindFile CPI 1 BNE de_notferror
                    LDA PtrA+2 CPI 3 BCC de_canterror
                    ; file exists and may be deleted, invalidate it's name to 0
                    LXI 10                                ; re-read a maximum times
                    LDI 0x05 BNK LDI 0xaa STA 0x0555      ; INIT FLASH WRITE PROGRAM
                    LDI 0x02 BNK LDI 0x55 STA 0x0aaa
                    LDI 0x05 BNK LDI 0xa0 STA 0x0555
                    LDA PtrA+2 BNK LDI 0 STR PtrA         ; START WRITE PROCESS
    de_delcheck:    DEX BCC de_flasherror                 ; write took too long => ERROR!!!
                      LDR PtrA CPI 0 BNE de_delcheck      ; re-read FLASH location -> data okay?
                        JPA _Prompt                       ; FLASH off und zurück
  de_syntax:      LDI <de_errortxt PHS LDI >de_errortxt PHS JPS _Print JPA _Prompt
  de_flasherror:  LDI <de_flashtxt PHS LDI >de_flashtxt PHS JPS _Print JPA _Prompt
  de_canterror:   LDI <de_canttxt PHS LDI >de_canttxt PHS JPS _Print JPA _Prompt
  de_notferror:   LDI <de_notftxt PHS LDI >de_notftxt PHS JPS _Print JPA _Prompt

  de_errortxt:    'del <name>', 10, 0
  de_flashtxt:    '?WRITE ERROR.', 10, 0
  de_canttxt:     '?FILE PROTECTED.', 10, 0
  de_notftxt:     '?FILE NOT FOUND.', 10, 0

  DelEnd:

; **********************************************************************************************************

'show', 0, '              ', 0, ShowStart, ShowEnd-ShowStart ; file header

  #mute
  #org 0xbd00                                             ; target address of the code
  #emit

  ; --------------------------------------------------
  ; Displays a text file by § paragraph
  ; usage: "show <filename> <ENTER>"
  ; modifies:
  ; --------------------------------------------------
  ShowStart:      JPS _ReadSpace
                  LDR _ReadPtr CPI 39 BGT sh_syntaxok         ; look for a valid filename
                    LDI <sh_errortxt PHS LDI >sh_errortxt PHS ; show syntax
                    JPS _Print JPA _Prompt
    sh_syntaxok:  JPS _FindFile CPI 1 BEQ sh_found            ; A=1: success
                    LDI <sh_notftxt PHS LDI >sh_notftxt PHS
                    JPS _Print JPA _Prompt                    ; resets stack and switches off FLASH
    sh_found:     LDI 24 ADW PtrA                             ; A0-2/BANK now hold the start of the file - 1
    sh_firstpage: LDI 0xff PHS                                ; push end marker
    sh_nextpage:  LDA PtrA+0 PHS LDA PtrA+1 PHS LDA PtrA+2 PHS  ; push previous page
                  JPS _Clear CLW _XPos                        ; clear screen and X/Y pos
    sh_nextchar:  INW PtrA JPS OS_FlashA                      ; goto next char
    sh_shownext:  LDA PtrA+2 BNK LDR PtrA                     ; load next char from FLASH
                  CPI 0 BMI _Prompt BEQ _Prompt               ; end reached?
                    CPI '%' BNE sh_printchar
                      JPS _WaitInput CPI 27 BEQ _Prompt       ; stop at % char
                        CPI 0xe1 BEQ sh_backpage
                        CPI 0xe7 BEQ sh_backpage
                        CPI 0x08 BNE sh_nextpage
      sh_backpage:        PLS CPI 0xff BEQ sh_firstpage
                            STA PtrA+2 PLS STA PtrA+1 PLS STA PtrA+0
                          PLS CPI 0xff BEQ sh_firstpage
                            STA PtrA+2 PLS STA PtrA+1 PLS STA PtrA+0
                          JPA sh_nextpage
    sh_printchar:   PHS JPS _PrintChar PLS JPA sh_nextchar

  sh_notftxt:     '?FILE NOT FOUND.', 10, 0
  sh_errortxt:    'show <name>', 10, 0

  ShowEnd:

; **********************************************************************************************************

'mon', 0, '               ', 0, MonStart, MonEnd-MonStart ; file header

  #mute
  #org 0xbd00                                             ; target address of the code
  #emit

  ; --------------------------------------------------
  ; Memory Monitor
  ; usage: "mon <ENTER>"
  ; modifies: X
  ; --------------------------------------------------
  MonStart:   LDI <montxt PHS LDI >montxt PHS JPS _Print PLS PLS   ; print start line
              LDI 0xff STA PtrA+2 CLW PtrA+0              ; default memory address and bank

              LDR _ReadPtr CPI 10 BNE initline            ; use command line of mon

              JPS _ReadSpace JPS _ReadHex                 ; skip an optional start address
              LDA _ReadNum+2 CPI 0xf0 BEQ monline         ; wurde eine Zahl eingelesen?
                JPS mon_numtoa                            ; first address

  monline:    JPS mon_addr
              INB _XPos

              LDI <_ReadBuffer+5 STA _ReadPtr+0           ; parse fewer bytes due to "0000 _"
              LDI >_ReadBuffer+5 STA _ReadPtr+1
              JPS _ReadLine                               ; get a line of input until ENTER or end of input buffer

  initline:   LDI 0xf0 STA _ReadNum+2                     ; invalidate parsed number
              CLW _ReadNum CLB mode                       ; reset monitor mode=0

              LDR _ReadPtr CPI 10 BNE parsing
                JPA _Prompt                               ; FLASH off and back to OS

  parsing:    LDR _ReadPtr                                ; BYTE-BY-BYTE PARSING OF THE LINE INPUT BUFFER
              CPI '#' BEQ cross                           ; # switch to 'bank' mode
              CPI ':' BEQ doppel                          ; : switch to 'deposit' mode
              CPI '.' BEQ punkt                           ; . switch to 'list' mode
              CPI 'a' BCS sletter                         ; a..f for hex numbers
              CPI '0' BCS zahl                            ; 0..9 for numbers
                NOP NOP
                LDA _ReadNum+2                            ; ALLES ANDERE IST "ENTER"
                CPI 0xf0 BNE doaction                     ; prüfe, ob valide parse-Daten vorliegen
  clrparsed:      LDI 0xf0 STA _ReadNum+2                 ; ***** ENDE DES PARSINGS (AUCH MEHRERER BYTES) *****
                  CLW _ReadNum
  parsed:         LDR _ReadPtr                            ; ENDE DES PARSINGS EINES BYTES
                  CPI 10 BEQ monline                      ; prüfe hier NOCHMAL auf ENTER wg. Zeilenende
                    INB _ReadPtr JPA parsing              ; gehe zum nächsten Zeichen des Puffers

  doppel:     LDI 1 JPA setmode                           ; : => umschalten auf DEPOSIT mode
  punkt:      LDI 2 JPA setmode                           ; . => umschalten auf LIST mode
  cross:      LDI 3                                       ; # => umschalten auf BANK mode
  setmode:    STA mode
              LDA _ReadNum+2                              ; validen input vorhergehend . oder : als 'PtrA' übernehmen
              CPI 0xf0 BEQ clrparsed                      ; liegt kein valider input vor?
    setmemadr:  JPS mon_numtoa
                JPA clrparsed                             ; . : kam ohne valide Addresse davor

    sletter:  SBI 39                                      ; parse one byte normal hex input
    zahl:     SBI 48 PHS
              LLW _ReadNum RLB _ReadNum+2                 ; this automatically validates a parsed number
              LLW _ReadNum RLB _ReadNum+2                 ; shift existing hex data to the left
              LLW _ReadNum RLB _ReadNum+2
              LLW _ReadNum RLB _ReadNum+2
              PLS ADB _ReadNum                            ; add new hex nibble to the right
              JPA parsed

  doaction:     LDA mode                                  ; ***** ES LIEGT EIN VALIDES PARSE-DATUM VOR *****
                CPI 0 BEQ setmemadr                       ; mode=0 -> übernimm Daten als einfache neue PtrA
                CPI 1 BEQ mode_deposit                    ; mode=1 -> übernimm Daten als 'deposit'
                CPI 2 BEQ startlistpage

  ; mode=3 -> set bank address
                  LDI <banktxt PHS LDI >banktxt PHS JPS _Print PLS PLS
                  LDA _ReadNum+0 STA PtrA+2 PHS JPS _PrintHex PLS   ; pointless to set BNK here, just store in PtrA+2
                  LDI 10 PHS JPS _PrintChar PLS           ; ENTER
                  JPA clrparsed

  ; mode=2 -> Daten sind 'list until', print list
  startlistpage:  LDI 24 STA PtrC                         ; reuse as line counter
  startlistline:  LXI 16                                  ; init 16-bytes counter
                  JPS mon_addr
                  LDI 2 ADB _XPos                         ; two spaces
  nextlist:       LDA PtrA+2 BNK LDR PtrA
                  PHS JPS _PrintHex PLS                   ; Speicherinhalt drucken
                  LDA PtrA+0
                  CPA _ReadNum+0
                  BNE listweiter
                    LDA PtrA+1
                    CPA _ReadNum+1
                    BNE listweiter
                      JPS mon_enter
                      JPA clrparsed
  listweiter:     INW PtrA
                  DEX BEQ lineend
                    LL5 BNE nextlist
                      INB _XPos
                      JPA nextlist                        ; bug-fix by paulscottrobson Thank you!

  lineend:        JPS mon_enter
                  DEB PtrC BNE startlistline              ; reuse as line counter
                    JPS _WaitInput
  lineinput:        CPI 27 BNE startlistpage              ; warte auf Tastendruck
                      JPA clrparsed

  mode_deposit: LDA _ReadNum STR PtrA                     ; validen Daten -> deposit in RAM only
                INW PtrA JPA clrparsed

  mon_enter:    LDI 10 PHS JPS _PrintChar PLS             ; ENTER
                RTS
  mon_addr:     LDA PtrA+1 PHS JPS _PrintHex PLS          ; Drucke aktuelle list-Adresse
                LDA PtrA+0 PHS JPS _PrintHex PLS
                RTS
  mon_numtoa:   LDA _ReadNum+0 STA PtrA+0                 ; valide Daten -> PtrA
                LDA _ReadNum+1 STA PtrA+1
                RTS

  mode:         0xff
  montxt:       10, 'MONITOR (: write | . to | # bank | ESC to stop)', 10, 0
  banktxt:      'BANK ', 0

  MonEnd:

; **********************************************************************************************************

'memset', 0, '            ', 0, MemsetStart, MemsetEnd-MemsetStart          ; file header

  #mute
  #org 0xbd00                                             ; target address of the code
  #emit

  ; --------------------------------------------------
  ; usage: "memset <adr_first> <adr_last> <byte> <ENTER>"
  ; --------------------------------------------------
  MemsetStart:    JPS _ReadSpace JPS _ReadHex             ; skip spaces and parse first address
                  LDA _ReadNum+2 CPI 0xf0 BEQ mf_syntax   ; wurde eine Zahl eingelesen?
                    LDA _ReadNum+0 STA PtrA+0             ; first address
                    LDA _ReadNum+1 STA PtrA+1
                  JPS _ReadSpace JPS _ReadHex             ; skip spaces and parse last address
                  LDA _ReadNum+2 CPI 0xf0 BEQ mf_syntax
                    LDA _ReadNum+0 STA PtrB+0             ; last address
                    LDA _ReadNum+1 STA PtrB+1
                  JPS _ReadSpace JPS _ReadHex             ; skip spaces and parse byte value
                  LDA _ReadNum+2 CPI 0xf0 BEQ mf_syntax

  mfnext:           LDA _ReadNum+0 STR PtrA               ; BESCHREIBE DEN SPEICHER
                    LDA PtrA+0 CPA PtrB+0 BNE mfweiter
                      LDA PtrA+1 CPA PtrB+1 BEQ _Prompt
  mfweiter:             INW PtrA
                        JPA mfnext

  mf_syntax:      LDI <mf_errortxt PHS LDI >mf_errortxt PHS JPS _Print
                  JPA _Prompt

  mf_errortxt:    'memset <fst> <lst> <val>', 10, 0

  MemsetEnd:

; **********************************************************************************************************

'memmove', 0, '           ', 0, MemmoveStart, MemmoveEnd-MemmoveStart   ; file header

  #mute
  #org 0xbd00                                                    ; target address of the code
  #emit

  ; --------------------------------------------------
  ; usage: "memmove <adr_first> <adr_last> <adr_dest> <ENTER>"
  ; --------------------------------------------------
  MemmoveStart:   JPS _ReadSpace JPS _ReadHex                    ; skip spaces and parse first address
                  LDA _ReadNum+2 CPI 0xf0 BEQ sc_syntax          ; wurde eine Zahl eingelesen?
                    LDA _ReadNum+0 STA PtrA+0                    ; first address
                    LDA _ReadNum+1 STA PtrA+1
                  JPS _ReadSpace JPS _ReadHex                    ; skip spaces and parse last address
                  LDA _ReadNum+2 CPI 0xf0 BEQ sc_syntax
                    LDA _ReadNum+0 STA PtrB+0                    ; last address
                    LDA _ReadNum+1 STA PtrB+1
                  JPS _ReadSpace JPS _ReadHex                    ; skip spaces and parse byte value
                  LDA _ReadNum+2 CPI 0xf0 BEQ sc_syntax
                    LDA _ReadNum+0 PHS
                    LDA _ReadNum+1 PHS                           ; push destination
                    LDA PtrA+0 PHS SBW PtrB                      ; push source
                    LDA PtrA+1 PHS SBB PtrB+1 INW PtrB           ; B = B - A + 1
                    LDA PtrB+0 PHS LDA PtrB+1 PHS                ; push number of bytes
                    JPS OS_MemMove                               ; do not clean up the stack
                    JPA _Prompt

  sc_syntax:      LDI <sc_errortxt PHS LDI >sc_errortxt PHS JPS _Print
                  JPA _Prompt

  sc_errortxt:    'memmove <fst> <lst> <dst>', 10, 0

  MemmoveEnd:

; **********************************************************************************************************

'format', 0, '            ', 0, FormatStart, FormatEnd-FormatStart      ; file header

  #mute
  #org 0xbd00                                                    ; target address of the code
  #emit

  ; --------------------------------------------------
  ; usage: "format <ENTER>"
  ; --------------------------------------------------
  FormatStart:    LDI <fm_asktext PHS LDI >fm_asktext
                  PHS JPS _Print PLS PLS
                  JPS _WaitInput
    fm_input:     CPI 'y' BNE _Prompt
                    LDI <fm_formtext PHS LDI >fm_formtext
                    PHS JPS _Print PLS PLS
    format_all:     LDI 0x03                                     ; start of SSD area is bank #03
    format_loop:    PHS JPS OS_FLASHErase PLS                    ; push bank address and delete
                    INC BPL format_loop
                  JPA _Prompt

    fm_asktext:   'Are you sure? (y/n)', 10, 0
    fm_formtext:  'Formating sectors 3-127...', 10, 0

  FormatEnd:

; **********************************************************************************************************

'flash', 0, '             ', 0, FlashStart, FlashEnd-FlashStart  ; file header

  #mute
  #org 0xbd00                                                    ; target address of the code
  #emit

  ; --------------------------------------------------
  ; usage: "update <ENTER>", then paste a HEX file
  ; --------------------------------------------------
  FlashStart:         LDI <asktext PHS LDI >asktext PHS
                      JPS _Print PLS PLS
                      JPS _WaitInput
                      CPI 'y' BNE _Prompt
                        LDI <writetext PHS LDI >writetext PHS
                        JPS _Print PLS PLS
                        LDI 0x00 PHS JPS OS_FLASHErase PLS       ; erase banks 0x00-0x02
                        LDI 0x01 PHS JPS OS_FLASHErase PLS
                        LDI 0x02 PHS JPS OS_FLASHErase PLS
                        LDI <0x0000 STA PtrC+0
                        LDI >0x0000 STA PtrC+1                   ; write data to banks 0x00-0x02
                        LDI <0x3000 STA PtrB+0
                        LDI >0x3000 STA PtrB+1                   ; byte size of the 3 sectors
                        CLW PtrA LDI 0 BNK STA PtrA+2
                        JPS OS_FLASHWrite
                        LDA PtrB+1 CPI 0xff BEQ _Prompt          ; all went well
                          LDI <ferrortext PHS LDI >ferrortext PHS
                          JPS _Print JPA _Prompt

  asktext:        'Write RAM 0000-2fff to FLASH banks 0-2 (y/n)?', 10, 0
  writetext:      'Writing...', 10, 0
  ferrortext:     '?ERROR.', 10, 0

  FlashEnd:

; **********************************************************************************************************

'receive', 0, '           ', 0, ReceiveStart, ReceiveEnd-ReceiveStart     ; file header

  #mute
  #org 0xbd00                                                    ; target address of the code
  #emit

  ; -----------------------------------------------
  ; usage: "receive <ENTER>", then paste a HEX file
  ; -----------------------------------------------
  ReceiveStart:   LDI 0xfe STA 0xffff
                  LDI <hl_starttext PHS LDI >hl_starttext PHS
                  JPS _Print PLS PLS
                  LDI >_ReadBuffer STA PtrA+1 STA _ReadPtr+1
                  CLW hl_errors                                  ; clear number of errors

                  LDA _YPos LSL ADI >ViewPort                    ; prepare the "read line" indicator to cursor position
                  STA hl_validline+2 STA hl_validline+5
                  LDI 0x0c STA hl_validline+1 ADI 64 STA hl_validline+4

  hl_readline:    LDI <_ReadBuffer STA PtrA+0 STA _ReadPtr+0
  hl_readchar:    JPS _WaitInput
                  CPI 27 BEQ _Prompt
                  CPI 13 BEQ hl_readchar                         ; ignore CR
                    STR PtrA                                     ; store char ggfs. OUT
                    CPI 10 BEQ hl_scanforhex                     ; end of the line?
                      INB PtrA JPA hl_readchar                   ; look for more

  hl_scanforhex:  LDR _ReadPtr
                  CPI ':' BEQ hl_validline
                  CPI 10 BEQ hl_readline
                    INB _ReadPtr JPA hl_scanforhex

  hl_validline:   INW 0xffff                                     ; indicate line start
                  INW 0xffff                                     ; indicate line start
                  INB _ReadPtr                                   ; move over ':'
                  JPS hl_ReadHexByte                             ; parse number of data bytes
                  STA hl_numbytes STA hl_checksum                ; store number, init line checksum
                  JPS hl_ReadHexByte STA PtrB+1 ADB hl_checksum  ; parse 16-bit address
                  JPS hl_ReadHexByte STA PtrB+0 ADB hl_checksum
                  JPS hl_ReadHexByte                             ; parse record type
                  CPI 0x01 BEQ hl_endoffile
                    CPI 0x00 BNE hl_countaserr                   ; only allow DATA type 0x00 here
                      DEB hl_numbytes BCC hl_alllineread         ; > 0 bytes to process?

                      LDA hl_first+1 CPI 0xff BNE hl_dataloop
                        LDA PtrB+1 STA hl_first+1
                        LDA PtrB+0 STA hl_first+0

  hl_dataloop:          JPS hl_ReadHexByte STR PtrB ADB hl_checksum
                        INW PtrB DEB hl_numbytes BCS hl_dataloop

                          LDA PtrB+1 STA hl_last+1
                          LDA PtrB+0 STA hl_last+0

  hl_alllineread:         JPS hl_ReadHexByte ADB hl_checksum     ; read the checksum at the end
                          CPI 0x00 BEQ hl_readline               ; no errors? -> goto next line
  hl_countaserr:            INW hl_errors JPA hl_readline        ; go read the next line even with errors

  hl_endoffile:   ADB hl_checksum                                ; add record type that was already read
                  JPS hl_ReadHexByte ADB hl_checksum BNE hl_haveerrors   ; errors in last checksum?
                    LDA hl_errors+0 CPI 0 BNE hl_haveerrors      ; ... or in any line of the file?
                    LDA hl_errors+1 CPI 0 BEQ hl_allgood         ; ... or in any line of the file?
  hl_haveerrors:  LDI <hl_errortext PHS LDI >hl_errortext PHS    ; output the number of errors that occured
                  JPS _Print PLS PLS
                  LDA hl_errors+1 PHS JPS _PrintHex PLS          ; output number of errors
                  LDA hl_errors+0 PHS JPS _PrintHex PLS
                  JPA hl_exit

  hl_allgood:       LDI <hl_ramarea PHS LDI >hl_ramarea PHS      ; output the number of errors that occured
                    JPS _Print PLS PLS
                    LDA hl_first+1 PHS JPS _PrintHex PLS
                    LDA hl_first+0 PHS JPS _PrintHex PLS
                    INB _XPos
                    DEW hl_last
                    LDA hl_last+1 PHS JPS _PrintHex PLS
                    LDA hl_last+0 PHS JPS _PrintHex PLS
  hl_exit:          LDI 10 OUT PHS JPS OS_PrintChar              ; ENTER
                    JPA _Prompt

  ; *****************************************************************
  ; Parse a two digit HEX number
  ; *****************************************************************
  hl_ReadHexByte:  LDR _ReadPtr SBI 48
                    CPI 17 BCC hl_gotfirst
                      SBI 7
    hl_gotfirst:    LL4 STA hl_hexresult                         ; store upper nibble
                    INB _ReadPtr
                    LDR _ReadPtr SBI 48
                    CPI 17 BCC hl_gotsecond
                      SBI 7
    hl_gotsecond:   ADB hl_hexresult                             ; add lower nibble
                    INB _ReadPtr
                    LDA hl_hexresult                             ; return full byte value in A
                    RTS

  hl_starttext:     'Waiting for HEX file... (ESC to stop)', 10, 0
  hl_errortext:     '?CHECKSUM ERRORS: ', 0
  hl_ramarea:       'Data written to ', 0

  hl_hexresult:     0x00
  hl_checksum:      0x00
  hl_numbytes:      0x00
  hl_errors:        0x0000
  hl_first:         0xffff
  hl_last:          0x0000

  ReceiveEnd:

; **********************************************************************************************************

0, '                  ', 0, 0x0000, 0x3000-*-2                   ; dummy file filling up rest of bank 0x02

#org 0x0000
