; Displays the 'Mandelbrot Set' by projecting the area (-2.5..1) * (-1..1) onto 32 x 22 pixels
; using a maximum of 14 iterations and 16/32-bit math operations with 9-bit fixed-point integer values
; as used by ... in his video series '8-Bit Battle Royale' benchmarking various 8-bit systems.
;
; by Carsten Herting (slu4) 2023

#org 0x8000     JPS _Clear

                CLB _YPos
                LDI 0xfe STA cb+1 LDI 0x06 STA cb+0       ; set cb

newline:        CLB _XPos
                LDI 0xfa STA ca+1 LDI 0xf8 STA ca+0       ; set ca

nextpixel:      LDA ca+0 STA za+0 LDA ca+1 STA za+1       ; inititialize iteration to za = ca and zb = cb
                LDA cb+0 STA zb+0 LDA cb+1 STA zb+1

                LYI 14                                    ; set maximum iteration steps to (n+1)

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
                CPI 0x08 BCS plotpixel

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

plotpixel:          TYA ADI 33 PHS JPS _Char PLS         ; plot current pixel
                    LDI 56 ADW ca
                    INB _XPos CPI 32 BCC nextpixel        ; advance to next position
                      LDI 46 ADW cb
                      INB _YPos CPI 22 BCC newline        ; advance to next line
                        
                        CLB _XPos JPA _Prompt

                ; 32-bit intc = (16-bit inta) * (16-bit intb)
Multiply:       CLB intsign
                LDA inta+1 CPI 0 BPL apos                 ; make A positive
                  NOB intsign NEW inta
  apos:         LDA intb+1 CPI 0 BPL bpos                 ; make B positive
                  NOB intsign NEW intb
  bpos:         LXI 16 CLW intc+0 CLW intc+2 JPA entry    ; init unsigned multiplication 16bit x 16bit = 32bit
    next:         LLW intc RLW intc+2                     ; shift the current result up one step
  entry:        LLW inta BCC bitisoff                     ; shift out the highest bit of A
                  LDA intb+0 ADW intc+0 BCC firstok INW intc+2  ; add 16-bit B to 32-bit result
    firstok:      LDA intb+1 ADB intc+1 BCC bitisoff INW intc+2
  bitisoff:     DEX BNE next
                  ADA intsign BPL exit                    ; add to A=0
                    NOW intc NOW intc+2                   ; negate 32-bit result
                    INW intc BCC exit INW intc+2
  exit:         RTS

#mute

ca:           0, 0                                        ; fixed-point Mandelbrot variables
cb:           0, 0
za:           0, 0
zb:           0, 0
zaq:          0, 0
zbq:          0, 0

inta:				  0, 0                                        ; math registers
intb:				  0, 0
intc:				  0, 0, 0, 0
intsign:      0

#org 0xb030 _Clear:                                       ; API routines used
#org 0xb003 _Prompt:
#org 0xbccc _XPos:
#org 0xbccd _YPos:
#org 0xb03f _Char:
