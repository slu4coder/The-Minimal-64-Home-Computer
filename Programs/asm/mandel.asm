; Displays the 'Mandelbrot Set' by projecting the area (-2.2..0.925) * (-0.9375..0.9375) onto 400 x 240 pixels
; using a maximum of 256 (64, 16) iterations and 16/32-bit math operations with 9-bit fixed-point integer values
;
; by Carsten Herting (slu4) 2023
;
; For a detailed explanation of this approach see https://github.com/rahra/intfract.
;
; This version is specifically optimized for the 'Minimal 64' hardware is meant to complement the more readable 
; and generalized version by Michael Kamprath:
; https://github.com/michaelkamprath/bespokeasm/blob/main/examples/slu4-minimal-64/software/mandelbrot.min64.
; It's main purpose is to serve as a benchmark and to demonstrate the multi-byte number crunching capabilities
; of the 'Minimal 64'.
; 
; Runtime (6MHz CPU clock with max. 256,   64,   16 iterations):   73:20min,   22:00min,   8:20min.
; Runtime of Michael's version (max. 256 iterations only):       1380:00min,   --------,   -------.

#org 0x8000     JPS _Clear

                CLB ypos
                LDI 0xfe STA cb+1 LDI 0x20 STA cb+0

newline:        CLW xpos
                LDI 0xfb STA ca+1 LDI 0x9c STA ca+0

nextpixel:      LDA xpos+0 PHS LDA xpos+1 PHS             ; always set the current pixel to white
                LDA ypos PHS JPS _SetPixel

                LDA ca+0 STA za+0 LDA ca+1 STA za+1       ; inititialize iteration to za = ca and zb = cb
                LDA cb+0 STA zb+0 LDA cb+1 STA zb+1

                LYI 255                                   ; set maximum iteration steps

interate:       LDA za+0 STA inta+0 STA intb+0            ; calculate za^2
                LDA za+1 STA inta+1 STA intb+1
                JPS Multiply
                LDA intc+3 LSR
                LDA intc+2 ROR STA zaq+1
                LDA intc+1 ROR STA zaq+0

                LDA zb+0 STA inta+0 STA intb+0            ; calculate zb^2
                LDA zb+1 STA inta+1 STA intb+1
                JPS Multiply
                LDA intc+3 LSR
                LDA intc+2 ROR STA zbq+1
                LDA intc+1 ROR STA zbq+0

                LDA zaq+0 ADA zbq+0                       ; quit iteration with white pixel if (za^2 + zb^2 >= 4)
                LDA zaq+1 ACA zbq+1
                CPI 0x08 BCS white

                  LDA za+0 STA inta+0 LDA za+1 STA inta+1 ; zb = (za * zb)>>8 + cb
                  LDA zb+0 STA intb+0 LDA zb+1 STA intb+1
                  JPS Multiply
                  LDA intc+1 STA zb+0
                  LDA intc+2 ADA cb+1 STA zb+1
                  LDA cb+0 ADW zb

                  LDA zaq+0 STA za+0 LDA zaq+1 STA za+1   ; za = za^2 - zb^2 + ca
                  LDA zbq+1 SBB za+1 LDA zbq+0 SBW za
                  LDA ca+0 ADW za LDA ca+1 ADB za+1

                  DEY BCS interate

  black:          JPS _ClrPixel                           ; iteration ended => black pixel
  white:          PLS PLS PLS
                  LDI 4 ADW ca INW xpos BEQ nextpixel
                    LDA xpos+0 CPI 144 BCC nextpixel
                      LDI 4 ADW cb INB ypos CPI 240 BCC newline
                        HLT

                ; 32-bit intc = (16-bit inta) * (16-bit intb)
Multiply:       CLB intsign
                LDA inta+1 CPI 0 BPL apos                 ; make A positive
                  NOB intsign NEW inta
  apos:         LDA intb+1 CPI 0 BPL bpos                 ; make B positive
                  NOB intsign NEW intb
  bpos:         LXI 16 CLW intc+0 CLW intc+2 JPA entry    ; init unsigned multiplication 16bit x 16bit = 32bit
    next:         LLW intc RLW intc+2                     ; shift the current result up one step
  entry:        LLW inta BCC bitisoff                     ; shift out the highest bit of A
                  LDA intb+0 ADW intc+0 LDI 0 ACW intc+2  ; add 16-bit B to 32-bit result
                  LDA intb+1 ADB intc+1 LDI 0 ACW intc+2
  bitisoff:     DEX BNE next
                  ADA intsign BPL exit                    ; add to A=0
                    NOW intc NOW intc+2                   ; negate 32-bit result
                    INW intc LDI 0 ACW intc+2
  exit:         RTS

#mute

xpos:         0, 0                          ; pixel position on screen
ypos:         0

ca:           0, 0                          ; fixed-point Mandelbrot variables
cb:           0, 0
za:           0, 0
zb:           0, 0
zaq:          0, 0
zbq:          0, 0

inta:				  0, 0                          ; math registers
intb:				  0, 0
intc:				  0, 0, 0, 0
intsign:      0

#org 0xb030 _Clear:                         ; some API routines
#org 0xb036 _SetPixel:
#org 0xb039 _ClrPixel:
