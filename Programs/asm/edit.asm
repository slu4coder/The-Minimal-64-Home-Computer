; ------------------------------------------------------
;
; Minimal Text Editor for the 'Minimal 64 Home Computer'
;  written by Carsten Herting - last update 22.9.2022
;
; ------------------------------------------------------

; LICENSING INFORMATION
; This file is free software: you can redistribute it and/or modify it under the terms of the
; GNU General Public License as published by the Free Software Foundation, either
; version 3 of the License, or (at your option) any later version.
; This file is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
; implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
; License for more details. You should have received a copy of the GNU General Public License along
; with this program. If not, see https://www.gnu.org/licenses/.

#org 0x0000

Editor:       LDI 0xfe STA 0xffff                   ; init the stack pointer
              LDA iscoldstart CPI 1 BNE warmstart   ; is it a warmstart
                CLB iscoldstart CLB data            ; invalidate text data only at first (cold) start
                LDI <0xafff STA copyptr+0           ; invalidate copied data
                LDI >0xafff STA copyptr+1
                JPS clrnameptr
                CLB namebuf                         ; invalidate any filename

  warmstart:  JPS _ReadSpace                        ; parse command line: skip spaces after 'edit/run   filename'
              LDR _ReadPtr CPI 33 BCC mainload      ; FILENAME following 'edit' in command line?
                LDA _ReadPtr+0 STA strcpy_s+0       ; prepare copy of filename into buffer
                LDA _ReadPtr+1 STA strcpy_s+1
                LDI <namebuf STA strcpy_d+0
                LDI >namebuf STA strcpy_d+1
                JPS _LoadFile                       ; load it with filename in _ReadPtr
                CPI 1 BEQ loaddone                  ; everything okay?
                  LDI '?' PHS JPS _PrintChar PLS
                  LDI 10 PHS JPS _PrintChar PLS     ; ENTER
                  JPA _Prompt
    loaddone:   LDI 0 STR _ReadPtr                  ; LOADED! => truncate rest of command line
                JPS strcpy                          ; copy filename into name buffer
                LDA strcpy_d+0 STA nameptr+0        ; copy nameptr (pointing to end of file)
                LDA strcpy_d+1 STA nameptr+1

; ------------------------------------------------------------

  mainload:   CLW markptr                           ; jump here after LOAD
              CLB cptr+0 CLB tptr+0                 ; init cursor to top of file
              LDI >data STA cptr+1 STA tptr+1
              CLB xcur CLB ycur CLB xorg
              LDI 1 STA yorg+0 CLB yorg+1           ; yorg = 1
              CLB changed
              JPS pullline
              LDI 2 STA redraw                      ; redraw all

  mainclear:  CLB state

  mainloop:   LDA state                             ; process according to state
              CPI 'N' BEQ StateNew
                CPI 'L' BEQ StateLoad
                  CPI 'S' BEQ StateSave
                    CPI 'R' BEQ StateReceive
                      JPA StateChar

; ------------------------------------------------------------
; SCREEN REFRESH
; ------------------------------------------------------------

Update:       LDA xcur SBI 45 BCC ud_usexorg        ; check whether cursor has moved outside viewport
                CPA xorg BCS ud_usexmin
  ud_usexorg: LDA xorg
  ud_usexmin: CPA xcur BCC ud_useit
                LDA xcur
  ud_useit:   CPA xorg BEQ ud_notnew
                STA xorg
                JPS pushline
                LDI 2 STA redraw

  ud_notnew:  LDA redraw                            ; switch case "redraw"
              CPI 1 BEQ ud_lindraw
                CPI 2 BEQ ud_alldraw
                  JPS InvertChar                    ; delete old cursor
  ud_return:      CLB redraw
                  LDA state CPI 0 BNE ud_exit       ; state != 0 ? exit!
                    LDA ycur STA _YPos              ; state = 0 => draw cursor
                    LDA xcur SBA xorg ADI 4
                    STA _XPos JPS InvertChar        ; invert cursor position
  ud_exit:          RTS

; ------------------------------------------------------------

  ud_alldraw:   JPS _Clear                              ; REDRAW = 2: WHOLE SCREEN
                CLW _XPos
                LDA yorg+0 PHS LDA yorg+1 PHS
                JPS Print999 PLS PLS                    ; print 000| line number
                CLB pc_n                                ; count drawn rows
                LDA tptr+0 STA pc_ptr+0 STA pc_sptr+0   ; init pointers
                LDA tptr+1 STA pc_ptr+1 STA pc_sptr+1
  ud_while:     LDA pc_n CPI 30 BCS ud_return
                LDR pc_ptr CPI 0 BEQ ud_return
                  CPI 10 BNE ud_notret
                    LDA pc_n CPI 29 BCS ud_dontprint    ; it was ENTER
                      LDI 10 PHS JPS _PrintChar PLS     ; print ENTER
                      LDA yorg+0 STA pu_len+0
                      LDA yorg+1 STA pu_len+1
                      LDA pc_n INC ADW pu_len
                      LDA pu_len+0 PHS LDA pu_len+1 PHS
                      JPS Print999 PLS PLS
  ud_dontprint:       INW pc_ptr
                      LDA pc_ptr+0 STA pc_sptr+0
                      LDA pc_ptr+1 STA pc_sptr+1
                      INB pc_n
                      JPA ud_while

  ud_notret:      TAX                                   ; save the char
                  LDA pc_ptr+0 SBA pc_sptr+0
                  CPA xorg BCC ud_notprint
                  SBI 46 BCC ud_print
                    SBA xorg BCS ud_notprint
  ud_print:           TXA PHS JPS _Char PLS INB _XPos
  ud_notprint:    INW pc_ptr
                  JPA ud_while

; ------------------------------------------------------------

  ud_lindraw:   CLB _XPos LDA ycur STA _YPos            ; REDRAW = 1: CLEAR AND DRAW CURRENT LINE ONLY
                JPS _ClearRow
                LDA yorg+0 STA pu_len+0
                LDA yorg+1 STA pu_len+1
                LDA ycur ADW pu_len
                LDA pu_len+0 PHS LDA pu_len+1 PHS JPS Print999 PLS PLS
                CLB pc_ptr+0 LDI >line STA pc_ptr+1 ; pc_ptr -> line buffer start
  ud_while2:    LDR pc_ptr TAX
                CPI 0 BEQ ud_return
                CPI 10 BEQ ud_return
                  LDA pc_ptr+0 CPA xorg BCC ud_notprnt
                    SBI 46 BCC ud_doprnt
                      CPA xorg BCS ud_notprnt
  ud_doprnt:      TXA PHS JPS _Char PLS INB _XPos
  ud_notprnt:   INB pc_ptr+0
                JPA ud_while2

; ------------------------------------------------------------
; INPUT HANDLER FOR NORMAL INPUT
; ------------------------------------------------------------

StateChar:  JPS Update                             ; check if redraw is needed but always draw cursor
            JPS _WaitInput                         ; get char
            CPI 8 BEQ pc_BackSp                    ; BACKSPACE
            CPI 9 BEQ pc_Tab                       ; convert TABULATOR to SPACE
            CPI 27 BEQ mainloop                    ; discard ESC
            CPI 13 BEQ mainloop                    ; discard CR
            CPI 0xe0 BCC pc_default                ; 0xe0 - 0xfe are custom function keys (see PS2 table)
              SBI 0xe0 LSL                         ; calculate table index (x2 due to words)
              ADI <jumptable STA jumpaddr+1        ; calculate pointer to jump address
              LDI >jumptable ACI 0 STA jumpaddr+2  ; add a possible C flag overflow
  jumpaddr:   JPR 0xffff                           ; jump to the address stored at that table location

              ; JUMP TABLE FOR HANDLING SPECIAL FUNCTION KEYS
  jumptable:  pc_CtrlQ, pc_Up, pc_Down, pc_Left, pc_Right, pc_Pos1, pc_End, pc_PgUp, pc_PgDown  ; 0xe0-0xe8
              pc_CtrlA, pc_CtrlX, pc_CtrlC, pc_CtrlV, pc_CtrlL, pc_CtrlS, pc_CtrlN, pc_Delete   ; 0xe9-0xf0
              pc_CtrlR, pc_CtrlT                                                                ; 0xf1 - 0xf2
; ------------------------------------------------------------

  pc_CtrlA:     LDA tptr+0 STA marktptr+0          ; save tptr
                LDA tptr+1 STA marktptr+1
                LDA yorg+0 STA markyorg+0          ; save yorg
                LDA yorg+1 STA markyorg+1
                LDA cptr+0 STA markptr+0           ; save "cptr + xcur" as cursor pos in text
                LDA cptr+1 STA markptr+1
                LDA xcur STA markx ADW markptr     ; save cursor x/y
                LDA ycur STA marky
                JPA mainloop

; ------------------------------------------------------------

  pc_CtrlX:     JPS pushline                             ; update data with current line
                JPS CopyMarked
                LDI <0xafff CPA copyptr+0 BNE pc_n42ok
                  LDI >0xafff CPA copyptr+1 BEQ mainloop ; has something been saved?
    pc_n42ok:       LDA cptr+0 STA pc_sptr+0
                    LDA cptr+1 STA pc_sptr+1
                    LDA xcur ADW pc_sptr                 ; pc_sptr = current cursor position
                    LDI 0 PHS LDA pc_sptr+0 PHS LDA pc_sptr+1 PHS
                    JPS length PLS                       ; get rest length of text to shift
                    PLS STA pc_ptr+1 PLS STA pc_ptr+0 INW pc_ptr  ; pc_ptr = number of bytes to shift (incl. 0)
                    LDA markptr+0 PHS LDA markptr+1 PHS  ; push destination
                    LDA pc_sptr+0 PHS LDA pc_sptr+1 PHS  ; push sources
                    LDA pc_ptr+0 PHS LDA pc_ptr+1 PHS    ; push number of bytes to move
                    JPS _MemMove LDI 6 ADW 0xffff        ; move and clean up stack
                LDA marktptr+0 STA tptr+0 LDA marktptr+1 STA tptr+1
                LDA markyorg+0 STA yorg+0 LDA markyorg+1 STA yorg+1
                LDA markptr+0 STA cptr+0 LDA markptr+1 STA cptr+1
                LDA markx STA xcur SBW cptr LDA marky STA ycur
  pc_reuse2:    JPS pullline
                JPS _ResetPS2                            ; clears ALT, CTRL, SHIFT key status
                LDI 2 STA redraw
                JPA mainloop

; ------------------------------------------------------------

  pc_CtrlC:     JPS pushline
                JPS CopyMarked
                JPA mainloop

; ------------------------------------------------------------

  pc_CtrlV:     JPS pushline

                LDA cptr+0 STA pc_ptr+0 LDA cptr+1 STA pc_ptr+1
                LDA xcur ADW pc_ptr                   ; pc_ptr = address of current cursor position in the line
                LDI 0 PHS                             ; find remaining data length until (and excluding here) 0
                LDA pc_ptr+0 STA pc_dptr+0 PHS        ; pc_dptr = source for move, destination for insert
                LDA pc_ptr+1 STA pc_dptr+1 PHS
                JPS length PLS
                PLS STA pc_sptr+1 PLS STA pc_sptr+0   ; pc_sptr = bytesize of remaining text that needs shifting
                INW pc_sptr                           ;           increase for zero-terminator!

                LDI <0xafff STA pu_len+0              ; pu_len = bytesize of clipboard data
                LDI >0xafff STA pu_len+1
                LDA copyptr+1 SBB pu_len+1
                LDA copyptr+0 SBW pu_len

                LDA pu_len+1 ADB pc_ptr+1 LDA pu_len+0 ADW pc_ptr+0    ; pc_ptr = move destination address
                LDA pc_ptr+0 PHS LDA pc_ptr+1 PHS     ; push move destination
                LDA pc_dptr+0 PHS LDA pc_dptr+1 PHS   ; push move source
                LDA pc_sptr+0 PHS LDA pc_sptr+1 PHS   ; push move anzahl
                JPS _MemMove LDI 6 ADW 0xffff         ; move exisiting text to pc_ptr

                ; move the reverse stuff into text, update cptr, xcur, ycur, yorg and tptr char by char

                LDI <0xafff STA pc_ptr+0              ; pc_ptr = source at top of clipboard
                LDI >0xafff STA pc_ptr+1
  ctrlv_loop:   DEW pu_len BCC pc_reuse2              ; insert the backwards clipboard and *** exit *** here
                  LDR pc_ptr STR pc_dptr              ; copy a char starting at cursor pos
                  CPI 10 BEQ pc22enter                ; was it an ENTER?
                    INB xcur JPA pc22done             ; no ENTER -> only move cursor left
    pc22enter:    CLB xcur                            ; ENTER-Event!
                  LDA cptr+0 PHS LDA cptr+1 PHS
                  JPS getnext                         ; modifies pc_sptr!!!
                  PLS STA cptr+1 PLS STA cptr+0
                  LDA ycur CPI 29 BCS pc22doorg       ; was cursor at the bottom?
                    INB ycur JPA pc22done             ; no bottom -> only move cursor down
    pc22doorg:    INW yorg                            ; move origin down
                  LDA tptr+0 PHS LDA tptr+1 PHS
                  JPS getnext                         ; modifies pc_sptr!!!
                  PLS STA tptr+1 PLS STA tptr+0
    pc22done:     INW pc_dptr DEW pc_ptr              ; advance to next char, got down clipboard data
                  JPA ctrlv_loop

; ------------------------------------------------------------

  pc_CtrlQ:     JPS pushline
                JPA _Start

; ------------------------------------------------------------

  pc_CtrlR:     LDI 'R' STA state               ; RECEIVE
                JPS InvertChar                  ; delete old cursor
                LDI <0xafff STA copyptr+0       ; reset copyptr
                LDI >0xafff STA copyptr+1
                CLW _XPos JPS _ClearRow
                LDI <receivestr PHS LDI >receivestr PHS
                JPS _Print PLS PLS
                JPA mainloop

; ------------------------------------------------------------
                                                ; TRANSMIT FILE
  pc_CtrlT:     LDI 10 OUT JPS _SerialWait      ; ENTER
                LDI <data PHS LDI >data PHS     ; print out the whole file via UART
                JPS _SerialPrint PLS PLS
                LDI 10 OUT JPS _SerialWait      ; ENTER
                JPA rd2mainclear

; ------------------------------------------------------------

  pc_CtrlL:     LDI 'L' STA state               ; change state to "L"
                JPS InvertChar                  ; delete current cursor
                LDI <loadstr PHS LDI >loadstr PHS
  pc_reuseL1:   JPS pushline                    ; from here on same for "L and "S"
                CLW _XPos JPS _ClearRow         ; clears both X and Y position
                JPS _Print PLS PLS              ; print message
                LDI <namebuf PHS LDI >namebuf PHS
  pc_reuseL2:   JPS _Print PLS PLS
                JPS InvertChar                  ; put new cursor
                JPA mainloop

; ------------------------------------------------------------

  pc_CtrlS:     LDI 'S' STA state
                JPS InvertChar                        ; delete current cursor
    pc_AbortS:  LDI <savestr PHS LDI >savestr PHS     ; print "SAVE"
                JPA pc_reuseL1

; ------------------------------------------------------------

  pc_CtrlN:     LDI 'N' STA state               ; NEW
                LDI <newstr PHS LDI >newstr PHS
                JPS pushline
                JPS InvertChar                  ; delete old cursor
                CLW _XPos JPS _ClearRow
                JPA pc_reuseL2

; ------------------------------------------------------------

  pc_BackSp:    CLW markptr
                LDI 1 STA redraw
                LDA xcur CPI 0 BEQ pc_8else
                  DEB xcur PHS LDI >line PHS                ; case "xcur > 0"
                  JPS cutchar PLS PLS
                  LDI 1 STA changed
                  JPA mainloop
    pc_8else:   LDA cptr+0 PHS LDA cptr+1 PHS JPS getprev   ; case "xcur = 0"
                PLS STA pc_ptr+1 PLS STA pc_ptr+0           ; pc_ptr = prev
                CPA cptr+0 BNE pc_8if
                  LDA pc_ptr+1 CPA cptr+1 BEQ mainloop
    pc_8if:         JPS pushline                            ; prev != cptr -> alles okay
                    LDI 10 PHS LDA pc_ptr+0 PHS LDA pc_ptr+1 PHS
                    JPS length PLS PLS PLS STA pc_n         ; pc_n = length of prev exclusive return
                    LDI 10 PHS LDA cptr+0 PHS LDA cptr+1 PHS
                    JPS length PLS PLS PLS                  ; length of cptr exclusive return
                    ADA pc_n BCS mainloop CPI 254 BCS mainloop ; test l0 + l1 < 254
                      DEW cptr
                      LDA cptr+0 PHS LDA cptr+1 PHS
                      JPS cutchar PLS PLS
                      DEB ycur
                      LDA pc_n STA xcur
                      LDA pc_ptr+0 STA cptr+0 LDA pc_ptr+1 STA cptr+1   ; cptr = prev
                      JPA pc_reuse2

; ------------------------------------------------------------

  pc_Delete:    CLW markptr
                LDA xcur STA pc_dptr+0 LDI >line STA pc_dptr+1
                LDR pc_dptr CPI 10 BNE pc_127else
                  JPS pushline                        ; case delete an '\n'
                  LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext
                  PLS STA pc_ptr+1 PLS STA pc_ptr+0   ; pc_ptr = next
                  LDI 10 PHS LDA pc_ptr+0 PHS LDA pc_ptr+1 PHS
                  JPS length PLS PLS PLS STA pc_n     ; length of next line
                  LDI 10 PHS LDA cptr+0 PHS LDA cptr+1 PHS
                  JPS length PLS PLS PLS              ; length of this line
                  ADA pc_n BCS mainloop CPI 254 BCS mainloop
                    DEW pc_ptr                        ; next - 1
                    LDA pc_ptr+0 PHS LDA pc_ptr+1 PHS
                    JPS cutchar PLS PLS
                    JPA pc_reuse2
    pc_127else: CPI 0 BEQ mainloop                    ;  do not cut the very last zero in the file
                  LDA xcur PHS LDI >line PHS
                  JPS cutchar PLS PLS
                  LDI 1 STA changed
                  LDI 1 STA redraw
                  JPA mainloop

; ------------------------------------------------------------

  pc_Tab:     LDI 32                                  ; then goto default

; ------------------------------------------------------------

  pc_default: TAX                                     ; getchar -> X
              LDI 0 PHS PHS LDI >line PHS             ; DEFAULT (including ENTER)
              STA pc_sptr+1 STA pc_dptr+1
              JPS length PLS PLS                      ; pc_sptr = source = lenght of line (index points to terminating zero)
              PLS CPI 254 BCS mainloop
                STA pc_sptr+0
                INC STA pc_dptr+0                     ; pc_dptr = destination = pc_sptr + 1 (one beyond)
    pc_forlp: LDA pc_sptr+0 CPA xcur BCC pc_endf      ; shift the line content to the right including xcur index
                LDR pc_sptr STR pc_dptr
                DEB pc_dptr+0 DEB pc_sptr+0 BCS pc_forlp
    pc_endf:  LDI 1 STA changed                       ; mark es changed
              TXA STR pc_dptr                         ; now put in the new character
              CPI 10 BNE pc_not10
                JPS pushline
                LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext   ; cptr = getnext(cptr)
                PLS STA cptr+1 PLS STA cptr+0
                LDA ycur CPI 29 BCS pc_bottom
                  INB ycur
                  JPA pc_daswars
    pc_bottom:  LDA tptr+0 PHS LDA tptr+1 PHS JPS getnext   ; tptr = getnext(tptr)
                PLS STA tptr+1 PLS STA tptr+0
                INW yorg
    pc_daswars: JPS pullline
                CLB xcur LDI 2    ; draw all
                JPA pc_dend
    pc_not10: INB xcur LDI 1      ; draw line
    pc_dend:  STA redraw
              CLW markptr
              JPA mainloop

; ------------------------------------------------------------

  pc_Up:        JPS pushline
                LDA cptr+0 PHS LDA cptr+1 PHS JPS getprev
                PLS STA pc_ptr+1 PLS STA pc_ptr+0
                CPA cptr+0 BNE csi_ain
                  LDA pc_ptr+1 CPA cptr+1 BEQ mainclear               ; leave if
    csi_ain:        LDA pc_ptr+0 STA cptr+0 LDA pc_ptr+1 STA cptr+1
                      LDA ycur CPI 0 BEQ csi_aelse
                        DEB ycur
                        JPA csi_bweiter
    csi_aelse:        LDA tptr+0 PHS LDA tptr+1 PHS JPS getprev
                      PLS STA tptr+1 PLS STA tptr+0
                      JPS InvertChar                                  ; delete old cursor
                      JPS _ScrollDn
                      DEW yorg
                      LDI 1 STA redraw
                      JPA csi_bweiter

; ------------------------------------------------------------

  pc_Down:      JPS pushline
                LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext
                PLS STA pc_ptr+1 PLS STA pc_ptr+0
                CPA cptr+0 BNE csi_bin
                  LDA pc_ptr+1 CPA cptr+1 BEQ mainclear               ; leave if
    csi_bin:        DEW pc_ptr LDR pc_ptr CPI 10 BNE mainclear
                      INW pc_ptr
                      LDA pc_ptr+0 STA cptr+0 LDA pc_ptr+1 STA cptr+1
                      LDA ycur CPI 29 BCS csi_belse
                        INB ycur
                        JPA csi_bweiter
    csi_belse:        LDA tptr+0 PHS LDA tptr+1 PHS JPS getnext
                      PLS STA tptr+1 PLS STA tptr+0
                      JPS InvertChar                                  ; delete old cursor
                      JPS _ScrollUp
                      INW yorg
                      LDI 1 STA redraw
    csi_bweiter:      JPS pullline
                      LDI 10 PHS LDI <line PHS LDI >line PHS JPS length
                      PLS PLS PLS CPA xcur BCS mainclear
                        STA xcur
                        JPA mainclear

; ------------------------------------------------------------

  pc_Left:      LDA xcur CPI 0 BEQ csi_delse
                  DEB xcur
                  JPA mainclear
    csi_delse:  LDA cptr+0 CPI <data BNE csi_din
                  LDA cptr+1 CPI >data BEQ mainclear
      csi_din:      JPS pushline
                    LDA cptr+0 PHS LDA cptr+1 PHS JPS getprev
                    PLS STA pc_ptr+1 PLS STA pc_ptr+0
                    CPA cptr+0 BNE csi_din2
                      LDA pc_ptr+1 CPA cptr+1 BEQ mainclear           ; leave if
        csi_din2:       LDA pc_ptr+0 STA cptr+0 LDA pc_ptr+1 STA cptr+1
                        LDA ycur CPI 0 BEQ csi_delse2
                          DEB ycur
                          JPA csi_dweiter
        csi_delse2:     LDA tptr+0 PHS LDA tptr+1 PHS JPS getnext
                        PLS STA tptr+1 PLS STA tptr+0
                        JPS InvertChar                                ; delete old cursor
                        JPS _ScrollDn
                        DEW yorg
                        LDI 1 STA redraw
        csi_dweiter:    JPS pullline
                        LDI 10 PHS LDI <line PHS LDI >line PHS JPS length
                        PLS PLS PLS STA xcur
                        JPA mainclear

; ------------------------------------------------------------

  pc_Right:     LDI 10 PHS LDI <line PHS LDI >line PHS JPS length
                PLS PLS PLS
                CPA xcur BCC csi_celse BEQ csi_celse
                  INB xcur
                  JPA mainclear
    csi_celse:  STA pc_ptr+0 LDI >line STA pc_ptr+1
                LDR pc_ptr CPI 0 BEQ mainclear
                  JPS pushline
                  LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext
                  PLS STA pc_ptr+1 PLS STA pc_ptr+0
                  CPA cptr+0 BNE csi_cin
                    LDA pc_ptr+1 CPA cptr+1 BEQ mainclear
      csi_cin:        DEW pc_ptr LDR pc_ptr CPI 10 BNE mainclear
                        INW pc_ptr
                        LDA pc_ptr+0 STA cptr+0 LDA pc_ptr+1 STA cptr+1
                        LDA ycur CPI 29 BCS csi_celse2
                          INB ycur
                          JPA csi_cweiter
      csi_celse2:       LDA tptr+0 PHS LDA tptr+1 PHS JPS getnext
                        PLS STA tptr+1 PLS STA tptr+0
                        JPS InvertChar                                ; delete old cursor
                        JPS _ScrollUp
                        INW yorg
                        LDI 1 STA redraw
      csi_cweiter:      JPS pullline
        csi_reuse:      CLB xcur
                        JPA mainclear

; ------------------------------------------------------------

  pc_Pos1:        JPA csi_reuse

; ------------------------------------------------------------

  pc_End:         LDI 10 PHS LDI <line PHS LDI >line PHS JPS length
                  PLS PLS PLS STA xcur
                  JPA mainclear

; ------------------------------------------------------------

  pc_PgUp:        LDA cptr+1 CPI >data BNE pp5_noteq            ; if (cptr == data) break;
                    LDA cptr+0 CPI <data BEQ mainclear          ; quick exit when already up
    pp5_noteq:        JPS pushline
                  LDA tptr+1 CPI >data BNE pp5_else             ; if (tptr == data) ...
                    LDA tptr+0 CPI <data BNE pp5_else
                      STA cptr+0 LDA tptr+1 STA cptr+1          ; ... { cptr = tptr; ycur = 0; }
                      CLB ycur JPA pp5_pullout
    pp5_else:     CLB pc_n
    pp5_loop:     LDA tptr+0 PHS LDA tptr+1 PHS JPS getprev
                  LDS 2 CPA tptr+0 BNE pp5_lpnoteq
                    LDS 1 CPA tptr+1 BEQ pp5_lpout
    pp5_lpnoteq:      PLS STA tptr+1 PLS STA tptr+0
                      DEW yorg
                      INB pc_n CPI 30 BCC pp5_loop
    pp5_lpout:    LDA ycur ADA pc_n SBI 30 BCS pp5_ispos
                    LDI 0
    pp5_ispos:    STA ycur
                  LDA tptr+1 STA cptr+1 LDA tptr+0 STA cptr+0   ; cptr = tptr
                  CLB pc_n                                      ; for (int i=0; i<ycur; i++) cptr = getnext(cptr);
    pp5_for:      LDA pc_n CPA ycur BCS pp5_pullout
                    LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext
                    PLS STA cptr+1 PLS STA cptr+0
                    INB pc_n JPA pp5_for
    pp5_pullout:        JPS pullline
                        LDI 10 PHS LDI <line PHS LDI >line PHS JPS length
                        PLS PLS PLS CPA xcur BCC pp5_useit
                          LDA xcur
          pp5_useit:    STA xcur
          rd2mainclear: LDI 2 STA redraw
                        JPA mainclear

; ------------------------------------------------------------

  pc_PgDown:      LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext     ; bptr = getnext(cptr);
                  PLS STA bptr+1 PLS STA bptr+0
                  LDR bptr CPI 0 BEQ mainclear                  ; if (*bptr == 0) break;
                    JPS pushline
                  CLB pc_n
    pp3_for1:     INB pc_n ADA ycur SBI 29 BCS pp3_for1end      ; start for with i=1
                    LDA bptr+0 PHS LDA bptr+1 PHS JPS getnext   ; char* n = getnext(bptr);
                    PLS STA pc_ptr+1 PLS STA pc_ptr+0
                    LDR pc_ptr CPI 0 BEQ pp3_for1brk            ; if (*n == 0) break;
                      LDA pc_ptr+0 STA bptr+0                   ; else bptr = n;
                      LDA pc_ptr+1 STA bptr+1
                      JPA pp3_for1
    pp3_for1brk:  LDA bptr+0 STA cptr+0 LDA bptr+1 STA cptr+1   ; if (i < 29-ycur) { cptr = bptr; ycur += i; }
                  LDA pc_n ADB ycur JPA pp5_pullout             ; reuse code from pc_PgUp
    pp3_for1end:  CLB pc_n
    pp3_for2:       LDA bptr+0 PHS LDA bptr+1 PHS JPS getnext   ; char* n = getnext(bptr);
                    PLS STA pc_ptr+1 PLS STA pc_ptr+0
                    LDR pc_ptr CPI 0 BEQ pp3_for2brk            ; if (*n == 0) break;
                      LDA pc_ptr+0 STA bptr+0                   ; else bptr = n;
                      LDA pc_ptr+1 STA bptr+1
                      LDA tptr+0 PHS LDA tptr+1 PHS JPS getnext ; tptr = getnext(tptr);
                      PLS STA tptr+1 PLS STA tptr+0
                      LDA cptr+0 PHS LDA cptr+1 PHS JPS getnext ; tptr = getnext(tptr);
                      PLS STA cptr+1 PLS STA cptr+0
                      INW yorg INB pc_n CPI 30 BCC pp3_for2
                        JPA pp5_pullout                         ; normal end reached
    pp3_for2brk:  LDA pc_n CPI 0 BNE pp5_pullout
                    LDA bptr+0 STA cptr+0 LDA bptr+1 STA cptr+1 ; if (i == 0) { cptr = bptr; ycur = 29; }
                    LDI 29 STA ycur JPA pp5_pullout

; ------------------------------------------------------------
; INPUT HANDLER FOR MENU STATE "NEW", "LOAD", "SAVE"
; ------------------------------------------------------------

StateReceive:   JPS _WaitInput
                CPI 27 BEQ rec_end                ; ESC ends this process
                CPI 13 BEQ StateReceive           ; ignore CR
                CPI 9 BNE rec_normal
                  LDI ' ' STR copyptr DEW copyptr ; convert TAB to double SPACE
                  LDI ' '
  rec_normal:     STR copyptr DEW copyptr
  rec_indicator:  INW 0xc45e INW 0xc49e           ; show receive indicator after "..."
                  JPA StateReceive
  rec_end:      LDI 10 OUT
                CLB state
                JPA pc_CtrlV

; ------------------------------------------------------------

StateNew:   JPS _WaitInput
            CPI 'y' BNE rd2mainclear
              CLB data
              CLB namebuf
              JPS clrnameptr
              JPA mainload

; ------------------------------------------------------------

StateLoad:  JPS _WaitInput
            CPI 10 BNE pl_next1                           ; ENTER
              LDA nameptr+0 CPI <namebuf BEQ rd2mainclear ; is there a non-zero filename?
                LDI <namebuf STA strcpy_s+0               ; copy filename into _ReadBuffer (out of bank #00!!!)
                LDI >namebuf STA strcpy_s+1
                LDI <_ReadBuffer STA strcpy_d+0 STA _ReadPtr+0  ; point _ReadPtr to start of filename
                LDI >_ReadBuffer STA strcpy_d+1 STA _ReadPtr+1
                JPS strcpy                                ; copy the filename away from FLASH interferance
                JPS _LoadFile CPI 1 BEQ mainload          ; success?
                  LDI <notfile PHS LDI >notfile PHS
                  JPS _Print PLS PLS                      ; moves cursor by 11 steps
                  JPS _WaitInput                      ; clear released keys, wait on a keypress
                    LXI 11
  sl_delete:        DEB _XPos
                    LDI 32 PHS JPS _Char PLS
                    DEX BGT sl_delete
                  JPS InvertChar
                  JPA mainloop

  notfile:  ' not found.', 0

  pl_next1:   CPI 8 BNE pl_default                        ; handle backspace
                LDA nameptr+0 CPI <namebuf BEQ mainloop   ; left border reached?
                  LDI 32 PHS JPS _Char PLS                ; del old cursor
                  DEB _XPos
                  LDI 160 PHS JPS _Char PLS               ; show new cursor
                  DEW nameptr LDI 0 STR nameptr           ; write zero terminator
                  JPA mainloop

  pl_default: CPI 0xe0 BEQ _Start                         ; Ctrl+Q also works here
              CPI 27 BEQ rd2mainclear                     ; DEFAULT: ESC -> leave input
              CPI 33 BCC mainloop                         ;          ignore SPACE and below
              CPI 0x80 BCS mainloop                       ;          ignore chars >= 128
              TAX
              LDA nameptr+0 SBI <namebuf CPI 19 BCS mainloop  ; filename too long?
                TXA STR nameptr
                PHS JPS _Char PLS INB _XPos
                JPS InvertChar       ; show new cursor position
                INW nameptr LDI 0 STR nameptr             ; always write a zero at the end of the name
                JPA mainloop

; ------------------------------------------------------------

StateSave:  JPS _WaitInput
            CPI 10 BNE pl_next1                           ; ATTENTION: SaveFile modifies _ReadBuffer!!!
              LDA nameptr+0 CPI <namebuf BEQ rd2mainclear ; ENTER PRESSED: Any name there?
                CLB pc_ptr+0 LDI >data STA pc_ptr+1       ; find the end of the file
  ps_findz:     LDR pc_ptr CPI 0 BEQ ps_saveit            ; found last (0) byte?
                  INW pc_ptr JPA ps_findz
  ps_saveit:    LDI <namebuf STA _ReadPtr+0               ; set parse pointer to start of the name
                LDI >namebuf STA _ReadPtr+1
                LDI <data PHS LDI >data PHS               ; start address of the data
                LDA pc_ptr+0 PHS LDA pc_ptr+1 PHS         ; address of last byte to save (0)
                JPS InvertChar INB _XPos                  ; behind name: del cursor & move right for "OVERWRITING (y/n)?"
                JPS _SaveFile PLS PLS PLS                 ; call save (will copy filename to _ReadBuffer start)
                PLS CPI 1 BEQ rd2mainclear                ; get result: success?
                  JPA pc_AbortS                           ; 0: error or 2: user abortion => back to name input

; ------------------------------------------------------------
; Copies a marked area in reversed order downwards from 0xafff
; modifies: pc_ptr, pu_len
; ------------------------------------------------------------
CopyMarked:   LDI <0xafff STA copyptr+0 ; set copyptr to upper end of usable RAM
              LDI >0xafff STA copyptr+1
              LDA cptr+0 STA pu_len+0   ; pc_ptr = starts at markptr and goes up reight before cptr
              LDA cptr+1 STA pu_len+1   ; pu_len = current text pos - markptr = marked bytesize
              LDA xcur ADW pu_len
              LDA markptr+1 STA pc_ptr+1 SBB pu_len+1 BCC cm_return  ; subtract markptr to get the required bytesize
              LDA markptr+0 STA pc_ptr+0 SBW pu_len BCC cm_return    ; don't do anything if A is later than cursor
  cm_loop:      DEW pu_len BCC cm_return                             ; copy the stuff
                  LDR pc_ptr STR copyptr
                  INW pc_ptr DEW copyptr                             ; reverse order
                  JPA cm_loop
  cm_return:  RTS

; ------------------------------------------------------------
; HELPER ROUTINES
; ------------------------------------------------------------

; init the filename pointer to start of filename buffer
clrnameptr:    LDI <namebuf STA nameptr+0       ; point to start of filename
                LDI >namebuf STA nameptr+1
                RTS

; calculate the length of a string (excluding the terminator)
; push: terminator (active lower or equal), string_LSB, string_MSB
; pull: #, len_MSB, len_LSB
length:         LDS 4 STA lenptr+0 LDS 3 STA lenptr+1
                LDS 5 STA lenterm
  lenloop:      LDI
  lenterm:      0xff CPA
  lenptr:       0xffff BCS lenende              ; stops when reaching char <= lenterm
                  INW lenptr JPA lenloop
  lenende:      LDS 3 SBB lenptr+1
                LDS 4 SBW lenptr
                LDA lenptr+1 STS 4
                LDA lenptr+0 STS 5
                RTS

; ------------------------------------------------------------

; returns next line address after \n or returns address of EOF
; push: address LSB, MSB
; pull: address MSB, LSB
getnext:        LDS 4 STA pu_sptr+0
                LDS 3 STA pu_sptr+1
  gn_loop:      LDR pu_sptr
                CPI 0 BEQ gn_return
                CPI 10 BEQ gn_addret
                  INW pu_sptr
                  JPA gn_loop
  gn_addret:    INW pu_sptr
  gn_return:    LDA pu_sptr+1 STS 3
                LDA pu_sptr+0 STS 4
                RTS

; ------------------------------------------------------------

; returns previous line's address or returns the same address
; push: address LSB, MSB
; pull: address MSB, LSB
getprev:        LDS 4 STA pu_sptr+0
                LDS 3 STA pu_sptr+1
                LDI >data CPA pu_sptr+1 BNE gp_loop1
                LDI <data CPA pu_sptr+0 BEQ gp_return
  gp_loop1:       DEW pu_sptr
  gp_loop2:       LDI >data CPA pu_sptr+1 BNE gp_loopon
                  LDI <data CPA pu_sptr+0 BEQ gp_return
  gp_loopon:        DEW pu_sptr
                    LDR pu_sptr CPI 10 BNE gp_loop2
                      INW pu_sptr
  gp_return:    LDA pu_sptr+1 STS 3
                LDA pu_sptr+0 STS 4
                RTS

; ------------------------------------------------------------

; pulls current line incuding \n into 'line buffer' and terminates with zero
pullline:       LDA cptr+0 PHS LDA cptr+1 PHS
                JPS getnext
                PLS PLS SBA cptr+0 STA pu_n
                  CLB pu_dptr+0 LDI >line STA pu_dptr+1
                  LDA cptr+0 STA pu_sptr+0 LDA cptr+1 STA pu_sptr+1
  pl_loop:      DEB pu_n BCC pl_return
                  LDR pu_sptr STR pu_dptr
                  INW pu_sptr INW pu_dptr
                  JPA pl_loop
  pl_return:    LDI 0 STR pu_dptr
                CLB changed
                RTS

; ------------------------------------------------------------

; push 'line buffer' into current line postion, replacing the old line
pushline:       LDA changed CPI 0 BEQ pl_nochange
                  CLB changed
                  LDA cptr+0 STA pu_dptr+0 PHS
                  LDA cptr+1 STA pu_dptr+1 PHS
                  JPS getnext
                  PLS STA pu_sptr+1 PLS STA pu_sptr+0           ; get next pointer
                  LDI 0 PHS PHS LDI >line PHS
                  JPS length PLS PLS PLS STA pu_n               ; get newsize of "line"
                  ADW pu_dptr                                   ; pu_dptr = cptr + newsize
                  LDI 0 PHS LDA pu_sptr+0 PHS LDA pu_sptr+1 PHS
                  JPS length PLS
                  PLS STA pu_len+1 PLS STA pu_len+0 INW pu_len  ; pu_len = rest (incl. zero)
                  LDA pu_dptr+0 PHS LDA pu_dptr+1 PHS           ; push dest
                  LDA pu_sptr+0 PHS LDA pu_sptr+1 PHS           ; push source
                  LDA pu_len+0 PHS LDA pu_len+1 PHS             ; push size
                  JPS _MemMove LDI 6 ADW 0xffff
                  LDA cptr+0 PHS LDA cptr+1 PHS                 ; push dest
                  LDI <line PHS LDI >line PHS                   ; push source
                  LDA pu_n PHS LDI 0 PHS                        ; push size
                  JPS _MemMove LDI 6 ADW 0xffff
  pl_nochange:  RTS

; ------------------------------------------------------------

; cuts out a character from a zero-terminated string, moving the tail end and shortening the string
; push: str_lsb, str_msb
; pull: #, #
cutchar:        LDS 3 STA cut_dptr+1 STA cut_sptr+1             ; retrieve address of the char to cut
                LDS 4 STA cut_dptr+0 STA cut_sptr+0
                INW cut_sptr
  cut_loop:     LDA
  cut_sptr:     0xffff STA
  cut_dptr:     0xffff CPI 0 BEQ cut_done
                  INW cut_sptr INW cut_dptr JPA cut_loop
  cut_done:     RTS

; ------------------------------------------------------------

; print number 000| - 999|
; push: number_lsb, number_msb
; pull: #, #
; pu_len (2 bytes), pu_n (1 byte)
Print999:       LDS 3 STA pu_len+1                          ; PRINT A POSITIVE NUMBER 000| - 999|
                LDS 4 STA pu_len+0
                LDI '0' STA pu_n
  p100loop:     LDI 100 SBW pu_len BCC p99end100
                  INB pu_n JPA p100loop
  p99end100:    LDI 100 ADW pu_len
                LDA pu_n PHS JPS _PrintChar PLS
                LDI '0' STA pu_n
  p10loop:      LDI 10 SBB pu_len+0 BCC p99end10
                  INB pu_n JPA p10loop
  p99end10:     LDA pu_n PHS JPS _PrintChar PLS
                LDI 58 ADB pu_len+0
                LDA pu_len+0 PHS JPS _PrintChar PLS
                LDI '|' PHS JPS _PrintChar PLS
                RTS

; ------------------------------------------------------------
; Inverts a character at position (_XPos, _YPos) without changing _XPos or _YPos
; ------------------------------------------------------------
InvertChar:    LDI <viewport ADA _XPos STA in_index+1       ; index to video position of char
                LDA _YPos LSL ADI >viewport STA in_index+2  ; multiply y with 8*64 = 512
                ADI 2 STA in_end+1                          ; end condition
  in_index:     NOB 0xffff                                  ; invert video RAM
                LDI 64 ADW in_index+1                       ; move down one pixel row
  in_end:       CPI 0xff BCC in_index                       ; plot 8 bytes
  in_exit:        RTS                                       ; switch off charset access

; ------------------------------------------------------------
; copies the content of a source string at 'strcpy_s' to a
; destination at 'strcpy_d' (no overlap allowed! no safety!)
; ------------------------------------------------------------
strcpy:          LDA
  strcpy_s:      0xffff                                     ; self-modifying code
                STA
  strcpy_d:      0xffff CPI 0 BEQ strcpyend
                  INW strcpy_s INW strcpy_d
                  JPA strcpy
  strcpyend:    RTS

; ------------------------------------------------------------
; DATA AREA OF THE EDITOR
; ------------------------------------------------------------

newstr:         'NEW (y/n)?', 0
loadstr:        'LOAD ', 0
savestr:        'SAVE ', 0
receivestr:     'RECEIVING (ESC)...', 0

iscoldstart:    1             ; indicating first (cold) start of this editor

#mute
                              ; 54 bytes of edit's variables
namebuf:        '...................', 0  ; buffer for filename
nameptr:        0xffff
copyptr:        0xffff        ; points to the next free byte below copied data, growing downwards
markptr:        0xffff        ; pointer to linestart of a marked area, invalid: MSB = 0x00
marktptr:       0xffff        ; remembers the top ptr while marking
markyorg:       0xffff        ; remember the yorg that fits to the top
markx:          0xff          ; remembers xcur while marking
marky:          0xff          ; remembers ycur while marking
tptr:           0xffff        ; top pointer
cptr:           0xffff        ; current line pointer
bptr:           0xffff        ; bottom pointer
state:          0xff          ; 0: edit mode, N: New, S: Save, L: Load
xcur:           0xff          ; must be followed by ycur
ycur:           0xff          ; y position of the cursor (starting from 0)
xorg:           0xff          ; x position of the cursor (starting from 0)
yorg:           0xffff        ; global line number of the first columns of the screen (starting from 1)
redraw:         0xff          ; 2: all, 1: line, 0: nix
changed:        0xff          ; 1: line was changed, 0: line is unchnaged (no need to pushline)

pc_sptr:        0xffff        ; shared by functions that only use these basic procedures:
pc_dptr:        0xffff        ; pushline / pullline / getprev / getnext / length
pc_ptr:         0xffff
pc_n:           0xff

pu_sptr:        0xffff        ; used inside these often used funtions:
pu_dptr:        0xffff        ; pushline / pullline / getprev / getnext / length
pu_len:         0xffff
pu_n:           0xff

#org 0x0f00     line:         ; alligned 256 bytes line buffer
#org 0x1000     data:         ; beginning of the data area
#org 0xa000     copy:         ; beginning of the copybuffer area
#org 0xc30c     viewport:     ; beginning of visible VRAM area

#mute                         ; MinOS label definitions generated by 'asm os.asm -s_'

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
#org 0xb057 _ResetPS2:
#org 0xbf70 _ReadPtr:
#org 0xbf72 _ReadNum:
#org 0xbf84 _RandomState:
#org 0xbf8c _XPos:
#org 0xbf8d _YPos:
#org 0xbf8e _ReadBuffer:
