; --------------------------------------------------------------------------
; VGA demo moving any number between 1..255 of 16 x 16 bouncing ball sprites
; by C. Herting (slu4) 2022
; --------------------------------------------------------------------------
#org 0x8000

start:          LDI 0xfe STA 0xffff
                JPS _Clear

                JPS _ReadSpace JPS _ReadHex               ; skip spaces and parse first address
                  LDA _ReadNum+2 CPI 0xf0 BEQ randomize   ; wurde eine Zahl eingelesen?
                    LDA _ReadNum+0 STA number             ; use this many bubbles

                ; generate random balls
randomize:      LDI <table STA ptr+0 LDI >table STA ptr+1
                LYA number
randloop:       LDI 0 STR ptr INW ptr           ; xpos
                JPS _Random ANI 1 STR ptr
  redox:        JPS _Random CPI 192 BCS redox
                  LSL ORR ptr STR ptr
                  LDI 0 ROL PHS INW ptr
                  PLS STR ptr INW ptr
                LDI 0 STR ptr INW ptr           ; ypos
  redoy:        JPS _Random CPI 224 BCS redoy
                  STR ptr INW ptr
                LDI 0 STR ptr INW ptr           ; clear xold/yold
                LDI 0 STR ptr INW ptr
                LDI 0 STR ptr INW ptr
                JPS _Random STR ptr INW ptr     ; vx/vy
                JPS _Random STR ptr INW ptr
                DEY BGT randloop

  mainloop:     ; draw all balls that have changed pixel position
                LDI <table+1 STA xposlptr+0 LDI >table+1 STA xposlptr+1
                LDI <table+2 STA xposmptr+0 LDI >table+2 STA xposmptr+1
                LDI <table+4 STA yposptr+0 LDI >table+4 STA yposptr+1
                LDI <table+5 STA xoldlptr+0 LDI >table+5 STA xoldlptr+1
                LDI <table+6 STA xoldmptr+0 LDI >table+6 STA xoldmptr+1
                LDI <table+7 STA yoldptr+0 LDI >table+7 STA yoldptr+1
                LYA number
  drawloop:     LDR xoldlptr CPR xposlptr BNE drawit
                  LDR yoldptr CPR yposptr BEQ drawdone
  drawit:           CLB mask
                    LDR xoldlptr PHS LDR xoldmptr PHS LDR yoldptr PHS
                    JPS DrawSprite PLS PLS PLS
                    INB mask
                    LDR xposlptr STR xoldlptr PHS
                    LDR xposmptr STR xoldmptr PHS
                    LDR yposptr STR yoldptr PHS
                    JPS DrawSprite PLS PLS PLS
  drawdone:     LDI 10 ADW xposlptr LDI 10 ADW xposmptr
                LDI 10 ADW xoldlptr LDI 10 ADW xoldmptr
                LDI 10 ADW yposptr LDI 10 ADW yoldptr
                DEY BGT drawloop

                ; move all the balls
                LDI <table+0 STA xpos0ptr+0 LDI >table+0 STA xpos0ptr+1
                LDI <table+1 STA xposlptr+0 LDI >table+1 STA xposlptr+1
                LDI <table+2 STA xposmptr+0 LDI >table+2 STA xposmptr+1
                LDI <table+3 STA ypos0ptr+0 LDI >table+3 STA ypos0ptr+1
                LDI <table+4 STA yposptr+0 LDI >table+4 STA yposptr+1
                LDI <table+5 STA xoldlptr+0 LDI >table+5 STA xoldlptr+1
                LDI <table+6 STA xoldmptr+0 LDI >table+6 STA xoldmptr+1
                LDI <table+7 STA yoldptr+0 LDI >table+7 STA yoldptr+1
                LDI <table+8 STA vxptr+0 LDI >table+8 STA vxptr+1
                LDI <table+9 STA vyptr+0 LDI >table+9 STA vyptr+1
                LYA number
moveloop:       LDR vxptr CPI 0 BMI vxneg
                  ADR xpos0ptr STR xpos0ptr
                  LDI 0 ACR xposlptr STR xposlptr
                  LDI 0 ACR xposmptr STR xposmptr BEQ movey
                    LDR xposlptr CPI 128 BCC movey
                      LDI 127 STR xposlptr
                      LDR vxptr NEG STR vxptr JPA movey
    vxneg:      ADR xpos0ptr STR xpos0ptr 
                LDR xposlptr SCI 0 STR xposlptr
                LDR xposmptr SCI 0 STR xposmptr BCS movey
                  LDI 0 STR xposlptr STR xposmptr
                  LDR vxptr NEG STR vxptr
    movey:      LDR vyptr CPI 0 BMI vyneg
                  ADR ypos0ptr STR ypos0ptr
                  LDI 0 ACR yposptr STR yposptr
                  CPI 224 BCC movedone
                    LDI 223 STR yposptr
                    LDR vyptr NEG STR vyptr
                    JPA movedone
    vyneg:      ADR ypos0ptr STR ypos0ptr 
                LDR yposptr SCI 0 STR yposptr BCS movedone
                  LDI 0 STR yposptr
                  LDR vyptr NEG STR vyptr
    movedone:   LDI 10 ADW xpos0ptr LDI 10 ADW xposlptr LDI 10 ADW xposmptr
                LDI 10 ADW ypos0ptr LDI 10 ADW yposptr
                LDI 10 ADW xoldlptr LDI 10 ADW xoldmptr LDI 10 ADW yoldptr
                LDI 10 ADW vxptr LDI 10 ADW vyptr
                DEY BGT moveloop
                  JPA mainloop

; ------------------------------------------------
; Draws a 16x16 pixel sprite at the given position
; push: x_lsb, x_msb, y
; pull: #, #, #
; modifies: X
; ------------------------------------------------
DrawSprite:     LDS 3 LL6 STA addr+0                          ; use ypos
                LDS 3 RL7 ANI 63 ADI 0xc3 STA addr+1
                LDS 4 DEC LDS 5                               ; add xpos
                RL6 ANI 63 ADI 12 ORB addr+0                  ; preprare target address
                LDS 5 ANI 7 STA shift                         ; calc bit pos
                LDI <data STA dptr+0 LDI >data STA dptr+1     ; data is hard-coded
lineloop:       LDR dptr STA buffer+0 INW dptr
                LDR dptr STA buffer+1 CLB buffer+2
                LXA shift DEX BCC shiftdone                   ; shift that buffer to pixel position
  shiftloop:    LLW buffer+0 RLB buffer+2 DEX BCS shiftloop
  shiftdone:    NEB mask BEQ clearit
                  LDA buffer+0 ORR addr STR addr INW addr     ; store line buffer to VRAM addr
                  LDA buffer+1 ORR addr STR addr INW addr
                  LDA buffer+2 ORR addr STR addr
                  JPA common
  clearit:      LDA buffer+0 NOT ANR addr STR addr INW addr   ; store line buffer to VRAM addr
                LDA buffer+1 NOT ANR addr STR addr INW addr
                LDA buffer+2 NOT ANR addr STR addr
  common:       LDI 62 ADW addr                               ; ... and move to the next line
                INW dptr LDA dptr+0 CPI <data+32 BNE lineloop ; haben wir alle sprite daten verarbeitet?
                  RTS

shift:          0xff
dptr:           0xffff
addr:           0xffff
mask:           0x01
data:           0xe0,0x07,0x98,0x1a,0x04,0x34,0x02,0x68,      ; 32 bytes of sprite data
                0x62,0x50,0x11,0xa0,0x09,0xd0,0x09,0xa0,
                0x01,0xd0,0x03,0xa8,0x05,0xd4,0x0a,0x6a,
                0x56,0x55,0xac,0x2a,0x58,0x1d,0xe0,0x07,
buffer:         0xff, 0xff, 0xff

number:             5                            ; number of entities to contructs

ptr:                0xffff                        ; pointers to access sprite data
xpos0ptr:           0xffff
xposlptr:           0xffff
xposmptr:           0xffff
ypos0ptr:           0xffff
yposptr:            0xffff
xoldlptr:           0xffff
xoldmptr:           0xffff
yoldptr:            0xffff
vxptr:              0xffff
vyptr:              0xffff

#mute

table:          ; position data for sprite entities

#mute           ; MinOS API definitions generated by 'asm os.asm -s_'

#org 0xb000 _Start:
#org 0xb003 _Prompt:
#org 0xb006 _ReadLine:
#org 0xb009 _ReadSpace:
#org 0xb00c _ReadHex:
#org 0xb00f _SerialWait:
#org 0xb012 _SerialPrint:
#org 0xb015 _FindFile:
#org 0xb018 _LoadFile:
#org 0xb01b _SaveFile:
#org 0xb01e _MemMove:
#org 0xb021 _Random:
#org 0xb024 _ScanPS2:
#org 0xb027 _ReadInput:
#org 0xb02a _WaitInput:
#org 0xb02d _ClearVRAM:
#org 0xb030 _Clear:
#org 0xb033 _ClearRow:
#org 0xb036 _SetPixel:
#org 0xb039 _ClrPixel:
#org 0xb03c _GetPixel:
#org 0xb03f _Char:
#org 0xb042 _Line:
#org 0xb045 _Rect:
#org 0xb048 _Print:
#org 0xb04b _PrintChar:
#org 0xb04e _PrintHex:
#org 0xb051 _ScrollUp:
#org 0xb054 _ScrollDn:
#org 0xbf70 _ReadPtr:
#org 0xbf72 _ReadNum:
#org 0xbf84 _RandomState:
#org 0xbf8c _XPos:
#org 0xbf8d _YPos:
#org 0xbf8e _ReadBuffer:
