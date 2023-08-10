; ------------------------------------------------------
; ALIEN INVADERS for the MINIMAL 64 Home Computer
; by Carsten Herting (slu4) 2022 17.11.2022 - 20.11.2022
; Original SPACE INVADERS by TAITO 1978
; ------------------------------------------------------

#org 0x8000

start:          LDI 0xfe STA 0xffff
								CLW score
								CLB gamestate

	mainloop:			CLW counter
		waitloop:		JPS KeyHandler INW counter CPI 0x04 BCC waitloop		; on real hardware use 0x05
									INB framecount
									LDA gamestate
									DEC BCC gamestate0
										DEC BCC gamestate1
											DEC BCC gamestate2
												DEC BCC gamestate3

								; GAME OVER -------------------------------------
                LDA score+1 CPA hiscore+1 BCC nonewhigh BGT newhigh
									LDA hiscore+0 CPA score+0 BCS nonewhigh
	newhigh:					LDA score+1 STA hiscore+1
										LDA score+0 STA hiscore+0
										LDI 22 STA _XPos LDI 2 STA _YPos LDA hiscore+0 PHS LDA hiscore+1 PHS JPS DecPrint PLS PLS
	nonewhigh:		LDI 2 STA _XPos LDI 27 STA _YPos LDI <text9 PHS LDI >text9 PHS JPS _Print PLS PLS		; press <fire>
								LDI 6 STA _XPos LDI 7 STA _YPos LDI <textd PHS LDI >textd PHS JPS _Print PLS PLS		; game over
	waitendfire:	JPS _WaitInput CPI ' ' BNE waitendfire
									CLB gamestate
									JPA mainloop

								; SHIP DESTROYED --------------------------------
gamestate3:			JPS UpdateShot
								LDA framecount ANI 4 CLC RL7 ADI 9 PHS		; explosion animation
								LDA shippos PHS LDI 192 PHS JPS DrawSprite PLS PLS PLS		; players ship exploding
								DEB waitframes BCS mainloop
									LDI 12 PHS LDA shippos PHS LDI 192 PHS JPS DrawSprite PLS PLS PLS ; delete ship
									JPS ResetAlienShots
									LDI 4 STA gamestate
									DEB lives BEQ mainloop		; no lives left -> gamestate 4
										ADI '0' PHS							; there are lives left
										LDI 2 STA _XPos LDI 27 STA _YPos JPS _PrintChar PLS
										LDA lives DEC LSL ADB _XPos
										LDI ' ' PHS JPS _PrintChar JPS _PrintChar PLS		; delete one spare ship
										LDI 8 PHS LDI 16 STA shippos PHS LDI 192 PHS
										JPS DrawSprite PLS PLS PLS 											; draw new ship
										LDI 2 STA gamestate			; go back to the game
										JPA mainloop

								; GAME IS RUNNING -------------------------------
gamestate2:			LDA a_total CPI 0 BNE aliensleft								; check if some aliens are left over
									DEB gamestate JPA mainloop										; no aliens => setup a new level
	aliensleft:		JPS UpdateSaucer
								JPS KeyHandler
								JPS UpdateAlienShots
								JPS KeyHandler
								JPS UpdateShot
								JPS KeyHandler
								JPS UpdateAliens
								JPS KeyHandler
								LDA left CPI 1 BNE checkright										; check player's ship movement
									LDA shippos CPI 17 BCC checkright 
										DEB shippos JPA redrawship
	checkright:		LDA right CPI 1 BNE checkfire
									LDA shippos CPI 191 BCS checkfire
										INB shippos
		redrawship:		  LDI 8 PHS LDA shippos PHS LDI 192 PHS JPS DrawSprite PLS PLS PLS		; players ship
	checkfire:		LDA fire CPI 1 BNE mainloop
									JPS PlaceShot
									JPA mainloop

									; SETUP NEW LEVEL -----------------------------
gamestate1:	      LDI <0xc30c+0x0600 STA vc_loopx+1             ; CLEAR GAME AREA
									LDI >0xc30c+0x0600 STA vc_loopx+2
		vc_loopy:     LXI 25                                        ; screen width in words
		vc_loopx:     CLW 0xffff
									LDI 2 ADB vc_loopx+1
									DEX BGT vc_loopx                              ; self-modifying code
										LDI 14 ADW vc_loopx+1                       ; add blank number of cols
										CPI 0xf7 BCC vc_loopy												; clear until row 208 (starting at 0xf700)
									LDI <0xf88c STA vl_loopx+3             				; DRAW BOTTOM LINE
									LDI >0xf88c STA vl_loopx+4									
		              LXI 28
		vl_loopx:     LDI 0xff STA 0xffff INW vl_loopx+3
									DEX BGT vl_loopx                              ; self-modifying code
									LDI 32 PHS LDI 168 PHS JPS DrawWall PLS PLS 	; DRAW WALLS
									LDI 78 PHS LDI 168 PHS JPS DrawWall PLS PLS
									LDI 124 PHS LDI 168 PHS JPS DrawWall PLS PLS
									LDI 170 PHS LDI 168 PHS JPS DrawWall PLS PLS
									JPS ResetSaucer																; reset systems
									JPS ResetShot
									JPS ResetAlienShots
									JPS ResetAliens
									CLB left CLB right CLB fire
									LDI 13 STA _XPos LDI 2 STA _YPos							; print level
									INB level ADI '0' PHS JPS _Char PLS
  								LDI 8 PHS LDA shippos PHS LDI 192 PHS JPS DrawSprite PLS PLS PLS		; redraw players ship
									INB gamestate
									JPA mainloop

								; DRAW THE START SCREEN -------------------------
gamestate0:			JPS _Clear
								LDI 2 STA _XPos LDI 0 STA _YPos LDI <text0 PHS LDI >text0 PHS JPS _Print PLS PLS
								LDI 18 STA _XPos LDI 0 STA _YPos LDI <text1 PHS LDI >text1 PHS JPS _Print PLS PLS
								LDI 12 STA _XPos LDI 5 STA _YPos LDI <text2 PHS LDI >text2 PHS JPS _Print PLS PLS
								LDI 7 STA _XPos LDI 8 STA _YPos LDI <text3 PHS LDI >text3 PHS JPS _Print PLS PLS
								LDI 3 STA _XPos LDI 13 STA _YPos LDI <text4 PHS LDI >text4 PHS JPS _Print PLS PLS
								LDI 10 STA _XPos LDI 16 STA _YPos LDI <text5 PHS LDI >text5 PHS JPS _Print PLS PLS
								LDI 10 STA _XPos LDI 18 STA _YPos LDI <text6 PHS LDI >text6 PHS JPS _Print PLS PLS
								LDI 10 STA _XPos LDI 20 STA _YPos LDI <text7 PHS LDI >text7 PHS JPS _Print PLS PLS
								LDI 10 STA _XPos LDI 22 STA _YPos LDI <text8 PHS LDI >text8 PHS JPS _Print PLS PLS
								LDI 2 STA _XPos LDI 27 STA _YPos LDI <text9 PHS LDI >text9 PHS JPS _Print PLS PLS
								LDI 17 STA _XPos LDI 27 STA _YPos LDI <texta PHS LDI >texta PHS JPS _Print PLS PLS
								LDI 3 STA _XPos LDI 25 STA _YPos LDI <texte PHS LDI >texte PHS JPS _Print PLS PLS
								LDI 6 PHS LDI 56 PHS LDI 128 PHS JPS DrawSprite PLS PLS PLS
								LDI 5 PHS LDI 56 PHS LDI 144 PHS JPS DrawSprite PLS PLS PLS
								LDI 3 PHS LDI 56 PHS LDI 160 PHS JPS DrawSprite PLS PLS PLS
								LDI 1 PHS LDI 56 PHS LDI 176 PHS JPS DrawSprite PLS PLS PLS
								LDI 8 PHS LDI 56 PHS LDI 200 PHS JPS DrawSprite PLS PLS PLS
								LDI 2 STA _XPos LDI 2 STA _YPos LDA score+0 PHS LDA score+1 PHS JPS DecPrint PLS PLS
								LDI 22 STA _XPos LDI 2 STA _YPos LDA hiscore+0 PHS LDA hiscore+1 PHS JPS DecPrint PLS PLS
	waitstart:		JPS _Random JPS _WaitInput CPI ' ' BNE waitstart
									CLB fire CLB left CLB right							; init a new game
									CLB level CLW score
									LDI 3 STA lives
									LDI 16 STA shippos
									LDI 2 STA _XPos LDI 2 STA _YPos LDA score+0 PHS LDA score+1 PHS JPS DecPrint PLS PLS
									LDI 12 STA _XPos LDI 0 STA _YPos LDI <textb PHS LDI >textb PHS JPS _Print PLS PLS
                  LDI 2 STA _XPos LDI 27 STA _YPos LDI <textc PHS LDI >textc PHS JPS _Print PLS PLS		; number of lives
  								LDI 8 PHS LDI 24 PHS LDI 216 PHS JPS DrawSprite PLS PLS PLS													; ship symbol
  								LDI 8 PHS LDI 40 PHS LDI 216 PHS JPS DrawSprite PLS PLS PLS													; ship symbol
									INB gamestate														; start the level setup
									JPA mainloop

; ----------------------------------------------------------------------------------------------

ResetSaucer:			CLB u_state
									LDI 0x58 STA u_timer+0
									LDI 0x02 STA u_timer+1
									RTS

UpdateSaucer:			LDA u_state
									DEC BCC sr_state0
										DEC BCC sr_state1
											DEC BCC sr_state2
												DEC BCC sr_state3

	sr_state4:			DEW u_timer BCS sr_rts
									LDA u_pos RL6 ANI 31 STA _XPos LDI 4 STA _YPos
									LDI <u_empty PHS LDI >u_empty PHS JPS _Print PLS PLS	; delete number
									JPA ResetSaucer			; and return from there

	sr_state3:			DEW u_timer BCS sr_rts
										LDI 12 PHS LDA u_pos PHS LDI 32 PHS	; delete pop explosion
									  JPS DrawSprite PLS PLS PLS
										LDA u_valptr+0 CPI <u_values+9 BCS ResetSaucer		; too many tries -> no score adv and return from there
											SBI <u_values LL2 STA u_timer+0
											LDI >u_text STA u_timer+1
											LDI <u_text ADW u_timer
											LDA u_timer+0 PHS LDA u_timer+1 PHS		; push pointer to val string
											LDA u_pos RL6 ANI 31 STA _XPos LDI 4 STA _YPos
											JPS _Print PLS PLS
											LDR u_valptr ADW score						; add value to score
											LDI 2 STA _XPos LDI 2 STA _YPos		; reprint score
											LDA score+0 PHS LDA score+1 PHS
											JPS DecPrint PLS PLS
											LDI 0 STA u_timer+1 LDI 24 STA u_timer+0
											INB u_state
											RTS

	sr_state2:			LDI 11 PHS LDA u_pos PHS LDI 32 PHS		; draw pop explosion
									JPS DrawSprite PLS PLS PLS
									LDI 12 STA u_timer+0 LDI 0 STA u_timer+1
									INB u_state
									RTS

	sr_state1:			LDA framecount ANI 1 DEC BCC sr_nostep
										LDA u_step ADB u_pos
		sr_nostep:		LDA u_pos CPI 0 BEQ sr_delete
										CPI 209 BEQ sr_delete
		sr_draw:					LDA u_step INC LSR ADI 6 PHS		; push costume
											JPA sr_common
		sr_delete:		JPS ResetSaucer
									LDI 12 PHS
		sr_common:		LDA u_pos PHS LDI 32 PHS				; push pos
									JPS DrawSprite PLS PLS PLS			; draw/del the sprite
									RTS

	sr_state0:			DEW u_timer BCS sr_rts
										LDA a_total CPI 12 BCC sr_rts
											JPS _Random ANI 2 SBI 1 STA u_step
											CPI 1 BNE sr_notone
												STA u_pos JPA sr_setval
		sr_notone:				LDI 208 STA u_pos
		sr_setval:				LDI <u_values STA u_valptr+0	; point to "300 points"
											LDI >u_values STA u_valptr+1
											INB u_state
		sr_rts:				RTS

ResetAlienShots:	JPS as0_reset
									JPS as1_reset
									JPS as2_reset
	as_rts:					RTS

as0_reset:				LDA as0_active CPI 0xff BEQ as_rts
										LDI 0xff STA as0_active										; deactivate this shot
										LDA as0_timer CPI 0xff BNE as0_delexpl
											LDI 12 PHS LDA as0_x DEC PHS LDA as0_y PHS
											JPS DrawShot PLS PLS PLS
											RTS
	as0_delexpl:			LDI 3 PHS LDA as0_x PHS LDA as0_y PHS			; delete a small explosion (type II)
										JPS DrawSmall PLS PLS PLS
										RTS

as1_reset:				LDA as1_active CPI 0xff BEQ as_rts
										LDI 0xff STA as1_active										; deactivate this shot
										LDA as1_timer CPI 0xff BNE as1_delexpl
											LDI 12 PHS LDA as1_x DEC PHS LDA as1_y PHS
											JPS DrawShot PLS PLS PLS
											RTS
	as1_delexpl:			LDI 3 PHS LDA as1_x PHS LDA as1_y PHS			; delete a small explosion (type II)
										JPS DrawSmall PLS PLS PLS
										RTS

as2_reset:				LDA as2_active CPI 0xff BEQ as_rts
										LDI 0xff STA as2_active										; deactivate this shot
										LDA as2_timer CPI 0xff BNE as2_delexpl
											LDI 12 PHS LDA as2_x DEC PHS LDA as2_y PHS
											JPS DrawShot PLS PLS PLS
											RTS
	as2_delexpl:			LDI 3 PHS LDA as2_x PHS LDA as2_y PHS			; delete a small explosion (type II)
										JPS DrawSmall PLS PLS PLS
										RTS

UpdateAlienShots:	JPS as_manage JPS KeyHandler
									JPS as0_update JPS KeyHandler
									JPS as1_update JPS KeyHandler
									JPS as2_update JPS KeyHandler
									RTS

as_manage:				LDA level LL2 TAX												; time to place a new shot?
									JPS _Random CPX BCS as_rts
	as_redorand:			JPS _Random RL5 ANI 15 CPI 11 BCS as_redorand		; pick a random column 0..10
										  STA as_col
									LDA level LL3 TAX
									JPS _Random CPX BCS as_usecol						; time for a precise shot?
										LDA shippos ADI 8 SBA a_x
										CPI 176 BCS as_usecol
											RL5 ANI 15 STA as_col								; pick the column under which the player ship is located

	as_usecol:				LDI 0 STA as_c
		as_cloop:				LDI 0 STA as_r
		as_rloop:				LDA as_col ADA as_c CPI 11 BCC as_cokay
											SBI 11
			as_cokay:			STA as_ptr+0 STA as_colcmod						; (col+c) % 11, store result for later
										LDI >a_alive STA as_ptr+1
										LDA as_r ADB as_ptr+0									; + 1*r
										LDA as_r LSL ADB as_ptr+0							; + 2*r
										LDA as_r LL3 ADB as_ptr+0							; + 8*r
										LDI <a_alive ADW as_ptr								; point to alive table position
										LDR as_ptr CPI 1 BEQ as_living
										INB as_r CPI 5 BCC as_rloop
		as_living:				LDA as_r CPI 5 BCS as_trynext				; no alien found in this column
												LDA as_colcmod LL4 ADI 8 ADA a_x STA as_px	; put exactly below alien (upper row of shot pixels is empty)
												LDA as_r LL4 NEG ADA a_y STA as_py
												LDA as0_active CPI 0xff BNE as_try1					; find a free slot
													LDA as_px STA as0_x LDA as_py STA as0_y
													LDI 0xff STA as0_timer LDI 1 STA as0_active
													RTS
		as_try1:						LDA as1_active CPI 0xff BNE as_try2
													LDA as_px STA as1_x LDA as_py STA as1_y
													LDI 0xff STA as1_timer LDI 1 STA as1_active
													RTS
		as_try2:						LDA as2_active CPI 0xff BNE as_rts
													LDA as_px STA as2_x LDA as_py STA as2_y
													LDI 0xff STA as2_timer LDI 1 STA as2_active
													RTS
		as_trynext:			INB as_c CPI 11 BCC as_cloop
											RTS

as0_update:				LDA as0_active CPI 0xff BEQ as_rts					; is this slot active?
										LDA as0_timer CPI 0xff BNE as0_explosion	; shot is exploding
											INB as0_y CPI 207 BCC as0_falling				; the shot is currently falling down
												LDI 1 PHS															; shot has reached the bottom
												LDI 4 SBB as0_x PHS
												LDI 207 STA as0_y PHS
												JPS DrawSmall PLS PLS PLS
												LDI 12 STA as0_timer
												RTS
	as0_falling:				; shot is still falling down -> COLLISION DETECTION
											LDA as0_y ADI 7 LL6 STA addr+0                      ; LSB of ypos*64
  		              	LDA as0_y ADI 7 RL7 ANI 63 ADI 0xc3 STA addr+1	    ; MSB of ypos*64 (rotate via C)
      		          	LDA as0_x RL6 ANI 63 ADI 12 ORB addr+0        			; xpos/8
          		      	LDA as0_x ANI 7 ADI 0x0c STA as0_llx          			; use sub pixel pos
											LDI 1																								; generate pixel mask
	as0_llx:						SEC																									; this instruction gets modified
											ANR addr CPI 0 BEQ as0_emptyspace
												;	a white pixel was hit
												LDI 12 PHS LDA as0_x DEC PHS LDA as0_y DEC PHS		; delete shot at its last position
												JPS DrawShot PLS PLS PLS
												LDA as0_y CPI 184 BCC as0_anywhite								; was the player's ship hit?
													CPI 192 BCS as0_anywhite
														LDI 60 STA waitframes
														LDI 3 STA gamestate														; ship destroyed
														RTS
	as0_anywhite:					LDI 1 PHS																					; plot explosion
												LDI 4 SBB as0_x PHS LDI 5 ADB as0_y PHS						; rember this position
												JPS DrawSmall PLS PLS PLS
												LDI 12 STA as0_timer
												RTS
	as0_emptyspace:			; free pixel below shot => plot the shot at new position
											LDA framecount ADI 0		; as0 pic
											ANI 15 LSR LSR ADI 0		; as0 type
											PHS
											LDA as0_x DEC PHS LDA as0_y PHS											
											JPS DrawShot PLS PLS PLS
											RTS
	as0_explosion:	DEB as0_timer BGT as_rts
										LDI 3 PHS LDA as0_x PHS LDA as0_y PHS			; delete the explosion after some frames
										JPS DrawSmall PLS PLS PLS
										LDI 0xff STA as0_active
										RTS

as1_update:				LDA as1_active CPI 0xff BEQ as_rts					; is this slot active?
										LDA as1_timer CPI 0xff BNE as1_explosion	; shot is exploding
											INB as1_y CPI 207 BCC as1_falling				; the shot is currently falling down
												LDI 1 PHS															; shot has reached the bottom
												LDI 4 SBB as1_x PHS
												LDI 207 STA as1_y PHS
												JPS DrawSmall PLS PLS PLS
												LDI 12 STA as1_timer
												RTS
	as1_falling:				; shot is still falling down -> COLLISION DETECTION
											LDA as1_y ADI 7 LL6 STA addr+0                      ; LSB of ypos*64
  		              	LDA as1_y ADI 7 RL7 ANI 63 ADI 0xc3 STA addr+1	    ; MSB of ypos*64 (rotate via C)
      		          	LDA as1_x RL6 ANI 63 ADI 12 ORB addr+0        			; xpos/8
          		      	LDA as1_x ANI 7 ADI 0x0c STA as1_llx          			; use sub pixel pos
											LDI 1																								; generate pixel mask
	as1_llx:						SEC																									; this instruction gets modified
											ANR addr CPI 0 BEQ as1_emptyspace
												;	a white pixel was hit
												LDI 12 PHS LDA as1_x DEC PHS LDA as1_y DEC PHS		; delete shot at its last position
												JPS DrawShot PLS PLS PLS
												LDA as1_y CPI 184 BCC as1_anywhite								; was the player's ship hit?
													CPI 192 BCS as1_anywhite
														LDI 60 STA waitframes
														LDI 3 STA gamestate														; ship destroyed
														RTS
	as1_anywhite:					LDI 1 PHS																					; plot explosion
												LDI 4 SBB as1_x PHS LDI 5 ADB as1_y PHS						; rember this position
												JPS DrawSmall PLS PLS PLS
												LDI 12 STA as1_timer
												RTS
	as1_emptyspace:			; free pixel below shot => plot the shot at new position
											LDA framecount ADI 1		; as1_ pic
											ANI 15 LSR LSR ADI 4		; as1_ type
											PHS
											LDA as1_x DEC PHS LDA as1_y PHS											
											JPS DrawShot PLS PLS PLS
											RTS
	as1_explosion:	DEB as1_timer BGT as_rts
										LDI 3 PHS LDA as1_x PHS LDA as1_y PHS			; delete the explosion after some frames
										JPS DrawSmall PLS PLS PLS
										LDI 0xff STA as1_active
										RTS

as2_update:				LDA as2_active CPI 0xff BEQ as_rts					; is this slot active?
										LDA as2_timer CPI 0xff BNE as2_explosion	; shot is exploding
											INB as2_y CPI 207 BCC as2_falling				; the shot is currently falling down
												LDI 1 PHS															; shot has reached the bottom
												LDI 4 SBB as2_x PHS
												LDI 207 STA as2_y PHS
												JPS DrawSmall PLS PLS PLS
												LDI 12 STA as2_timer
												RTS
	as2_falling:				; shot is still falling down -> COLLISION DETECTION
											LDA as2_y ADI 7 LL6 STA addr+0                      ; LSB of ypos*64
  		              	LDA as2_y ADI 7 RL7 ANI 63 ADI 0xc3 STA addr+1	    ; MSB of ypos*64 (rotate via C)
      		          	LDA as2_x RL6 ANI 63 ADI 12 ORB addr+0        			; xpos/8
          		      	LDA as2_x ANI 7 ADI 0x0c STA as2_llx          			; use sub pixel pos
											LDI 1																								; generate pixel mask
	as2_llx:						SEC																									; this instruction gets modified
											ANR addr CPI 0 BEQ as2_emptyspace
												;	a white pixel was hit
												LDI 12 PHS LDA as2_x DEC PHS LDA as2_y DEC PHS		; delete shot at its last position
												JPS DrawShot PLS PLS PLS
												LDA as2_y CPI 184 BCC as2_anywhite								; was the player's ship hit?
													CPI 192 BCS as2_anywhite
														LDI 60 STA waitframes
														LDI 3 STA gamestate														; ship destroyed
														RTS
	as2_anywhite:					LDI 1 PHS																					; plot explosion
												LDI 4 SBB as2_x PHS LDI 5 ADB as2_y PHS						; rember this position
												JPS DrawSmall PLS PLS PLS
												LDI 12 STA as2_timer
												RTS
	as2_emptyspace:			; free pixel below shot => plot the shot at new position
											LDA framecount ADI 2		; as2_ pic
											ANI 15 LSR LSR ADI 8		; as2_ type
											PHS
											LDA as2_x DEC PHS LDA as2_y PHS											
											JPS DrawShot PLS PLS PLS
											RTS
	as2_explosion:	DEB as2_timer BGT as_rts
										LDI 3 PHS LDA as2_x PHS LDA as2_y PHS			; delete the explosion after some frames
										JPS DrawSmall PLS PLS PLS
										LDI 0xff STA as2_active
										RTS


ResetShot:				CLB s_state
									RTS

PlaceShot:				LDA s_state CPI 0 BNE ps_rts		; already active
										LDI 1 STA s_state
										LDA shippos ADI 8 STA s_x
										LDI 188 STA s_y
										INW u_valptr
										JPS DrawLaser
	ps_rts:					RTS

UpdateShot:				LDA s_state DEC BCC us_rts
										DEC BCC us_fired
											DEC BCC us_smallex
  us_popping:			DEB s_timer BCS us_rts								; wait while alien is popping
										LDI 12 PHS LDA s_x PHS LDA s_y PHS
										JPS DrawSprite PLS PLS PLS					; clear alien pop
										CLB a_halt
										CLB s_state
	us_rts:						RTS

	us_smallex:			DEB s_timer BCS us_rts								; wait while a small explosion is active
										LDI 2 PHS LDA s_x PHS LDA s_y PHS		; clear the small explosion
										JPS DrawSmall PLS PLS PLS
										CLB s_state													; back to normal
										LDA s_y CPI 24 BEQ us_rts					  ; eat up wall infront of the explosion
											LDI 3 PHS LDA s_x PHS LDA s_y SBI 3 PHS
											JPS DrawSmall PLS PLS PLS
											RTS

	us_fired:				JPS DeleteLaser															; delete laser at the old poition
									LDA s_y CPI 28 BGT us_flying								; new position would be 4 pixels higher (24)
										LDI 0 PHS																	; draw explosion at the top
										LDI 4 SBB s_x PHS													; set explosion (x|y)
										LDI 24 STA s_y PHS
										JPS DrawSmall PLS PLS PLS
										LDI 2 STA s_state LDI 12 STA s_timer
										RTS
		us_flying:		LYI 4																				; PIXEL-EXACT COLLISION DETECTION starting from old top
									LDA s_y LL6 STA addr+0                      ; LSB of ypos*64
                	LDA s_y RL7 ANI 63 ADI 0xc3 STA addr+1	    ; MSB of ypos*64 (rotate via C)
                	LDA s_x RL6 ANI 63 ADI 12 ORB addr+0        ; xpos/8
                	LDA s_x ANI 7 ADI 0x0c STA us_llx           ; use sub pixel pos
									LDI 1																				; generate pixel mask
	us_llx:					SEC																					; this instruction gets modified
									STA us_mask

	us_flyloop:			DEB s_y LDI 64 SBW addr LDR addr						; move one pixel up
									ANA us_mask CPI 0 BEQ us_nopixel
										; pixel is white -> check for collision with alien
										LDA s_x SBA a_x+0 STA s_dx
											RL5 ANI 15 STA s_ix					; horizontal tile index of current alien
										LDA a_y SBA s_y STA s_dy
											RL6 ANI 31 STA s_by LSR STA s_iy	; vertical byte index, vertical tile index
										LDA s_dx CPI 176 BCS us_noalien
											LDA s_dy CPI 80 BCS us_noalien
												LDI >a_alive STA us_ptr+1
												LDA s_iy STA us_ptr+0
												LSL PHS ADB us_ptr+0 PLS
												LL2 ADB us_ptr+0
												LDA s_ix ADB us_ptr+0
												LDI <a_alive ADW us_ptr
												LDR us_ptr CPI 1 BNE us_noalien
													; alien getroffen
													LDI 0 STR us_ptr							; mark alien as dead
													DEB a_total LDI 1 STA a_halt
													LDI 12 STA s_timer LDI 3 STA s_state
													LDI 11 PHS
													LDA s_ix LL4 ADA a_x+0 STA s_x PHS
													LDA s_by LL3 NEG ADA a_y SBI 7 STA s_y PHS
													JPS DrawSprite PLS PLS PLS		; draw alien pop
													LDA s_iy LSR INC ADW score
													LDI 2 STA _XPos LDI 2 STA _YPos LDA score+0 PHS LDA score+1 PHS JPS DecPrint PLS PLS
													RTS
										; no alien hit -> check for collision with wall, shot or saucer
	us_noalien:  			LDA s_y CPI 40 BCS us_wallshot
											; saucer was hit
											LDI 2 STA u_state CLB s_state
											RTS
	us_wallshot:		  ; wall or alien shot was hit
										LDI 0 PHS LDI 4 SBB s_x PHS DEB s_y PHS		; store correct explosion position
										JPS DrawSmall PLS PLS PLS									; show little explosion
										LDI 2 STA s_state LDI 12 STA s_timer
										RTS																				; exit without drawing the Laser!
	us_nopixel:			DEY BGT us_flyloop
										JPS DrawLaser															; no collisions => draw the laser
										RTS

	us_mask:				0
	us_ptr:					0x0000

ResetAliens:			LDI 26 STA a_x+0 CLB a_x+1
									LDA level ADI 15 LL3 DEC STA a_y
									LDI 0xff STA a_num
									LDI 55 STA a_total
									LDI 2 STA a_step
									CLB a_halt
									CLB a_costume
									LXI 55												; 
									LDI <a_alive STA ra_loop+3
									LDI >a_alive STA ra_loop+4
	ra_loop:				LDI 1 STA 0xffff INW ra_loop+3 DEX BGT ra_loop
									RTS

UpdateAliens:			LDA a_halt CPI 1 BEQ ua_rts
	ua_nextnum:				INB a_num CPI 55 BCC ua_below
											CLB a_num LDA a_costume XRI 1 STA a_costume		; change costume
											JPS ua_movexstep
	ua_below:					LDI <a_alive STA ua_ptr+1
										LDI >a_alive STA ua_ptr+2
										LDA a_num ADW ua_ptr+1													; set alien index
	ua_ptr:						LDA 0xffff																		; self-modifying code here
										CPI 0 BEQ ua_nextnum
											; here we have the current alien to move
											LDA a_num PHS JPS GetModDiv11
											STA a_pic LL4 STA a_r
											PLS LL4 STA a_c
											LDA a_pic ANI 6 ORA a_costume			; prepare costume
											PHS
											LDA a_x+0 STA ua_pos+0						; prepare x
											LDA a_x+1 STA ua_pos+1
											LDA a_c ADW ua_pos LDA ua_pos+0 PHS
											LDA a_y SBI 7 SBA a_r PHS					; prepare y
											JPS DrawSprite PLS PLS PLS				; draw the alien
											JPS KeyHandler
											LDI 12 PHS												; costume 12 is empty for erasing
											LDA ua_pos+0 PHS
											LDA a_y SBI 15 SBA a_r PHS
											JPS DrawSprite PLS PLS PLS				; ??? erase the sprite above (slow!)
											LDA a_y SBI 7 SBA a_r CPI 192 BCC ua_notlanded	; check for aliens reaching the ground
												LDI 1 STA lives LDI 60 STA waitframes					; take away spare lives...
												LDI 3 STA gamestate							; ... and destroy ship
												RTS
	ua_notlanded:				LDA ua_pos CPI 10 BCC ua_turnaliens		; check for aliens reaching the border => turn
												CPI 198 BCS ua_turnaliens
	      									RTS
	ua_turnaliens:			NEB a_step
											JPS ua_movexstep
											LDI 8 ADB a_y
											LDI 0xff STA a_num
	ua_rts: 						RTS

	ua_movexstep:				LDA a_step CPI 2 BNE ua_substep		; move aliens a step
												ADW a_x RTS
	ua_substep:					LDI 2 SBW a_x RTS

	ua_pos:					0xffff
; ----------------------------------------------------------------------------------------------

KeyHandler:     INK CPI 0xff BEQ key_rts
                	CPI 0xf0 BEQ release
  key_entry:    CPI 0x29 BEQ isspace
                CPI 0x1c BEQ isa
                CPI 0x23 BEQ isd
  key_rts:        RTS
isa:            LDA pressed STA left ORI 1 STA pressed CLB right RTS
isspace:        LDA pressed STA fire ORI 1 STA pressed RTS
isd:            LDA pressed STA right ORI 1 STA pressed CLB left RTS
release:        LDI 0 STA released_cntr
  key_wait:		INK CPI 0xff BNE key_release
  				NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP		; wait for key up datagram
  				NOP NOP NOP
  				INB released_cntr CPI 0 BNE key_wait
  				JPA key_rts									; no 2nd datagram -> avoid
  key_release:  CLB pressed JPA key_entry					; released key was received -> analyze it
pressed:        1
released_cntr:	0
; print number 000 - 999 +  '0'
; push: number_lsb, number_msb
; pull: #, #
; pu_len (2 bytes), pu_n (1 byte)
DecPrint:       LDS 3 STA pu_len+1                          ; PRINT A POSITIVE NUMBER 000| - 999|
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
                LDI '0' PHS JPS _PrintChar PLS
                RTS
pu_len:         0xffff
pu_n:           0xff

; ----------------------------------------------------------------------------------
; Draws a 16x8 pixel sprite (alien, ship, explosions) at the given position (0..255)
; push: num, x, y
; pull: #, #, #
; modifies: X, Y registers
; ----------------------------------------------------------------------------------
DrawSprite:     LDI <sprites STA dptr+0 LDI >sprites STA dptr+1	; init sprite data pointer
								LDS 5 LL4 ADW dptr														; point to sprite num (+ num*16 bytes)
								LDS 3 LL6 STA addr+0                          ; LSB of ypos*64
                LDS 3 RL7 ANI 63 ADI 0xc3 STA addr+1					; MSB of ypos*64 (rotate via C)
                LDS 4 RL6 ANI 63 ADI 12 ORB addr+0            ; xpos/8
                LDS 4 ANI 7 STA shift                         ; store sub byte pixel pos
								LYI 8																					; number of lines to process
	lineloop:     LDR dptr STA buffer+0 STA buffer+3 INW dptr		; prepare the bit masks
                LDR dptr STA buffer+1 STA buffer+4 INW dptr
                CLB buffer+2 LDI 0xff STA buffer+5
                LXA shift DEX BCC shiftdone                   ; shift that buffer to pixel position
	shiftloop:			SEC RLW buffer+3 RLB buffer+5								; keep mask
									LLW buffer+0 RLB buffer+2                   ; set mask
									DEX BCS shiftloop
  shiftdone:				LDA buffer+3 ANR addr ORA buffer+0 STR addr INW addr
										LDA buffer+4 ANR addr ORA buffer+1 STR addr INW addr
										LDA buffer+5 ANR addr ORA buffer+2 STR addr LDI 62 ADW addr                               ; ... and move to the next line
										DEY BNE lineloop													; haben wir alle sprite daten verarbeitet?
											RTS

shift:          0xff
addr:           0xffff
dptr:           0xffff
buffer:         0xff, 0xff, 0xff, 0xff, 0xff, 0xff

; ----------------------------------------------------------------------------------
; Draws a 3x8 pixel alien shot at the given position (0..255)
; push: num, x, y
; pull: #, #, #
; modifies: X, Y registers
; ----------------------------------------------------------------------------------
DrawShot:       LDI <shots STA dptr+0 LDI >shots STA dptr+1		; init sprite data pointer
								LDS 5 LL3 ADW dptr														; point to shot num (+ num*8 bytes)
								LDS 3 LL6 STA addr+0                          ; LSB of ypos*64
                LDS 3 RL7 ANI 63 ADI 0xc3 STA addr+1					; MSB of ypos*64 (rotate via C)
                LDS 4 RL6 ANI 63 ADI 12 ORB addr+0            ; xpos/8
                LDS 4 ANI 7 STA shift                         ; store sub byte pixel pos
								LYI 8																					; number of lines to process
	ds_lineloop:  LDR dptr STA buffer+0
								ORI 0xf8 STA buffer+2 INW dptr								; prepare the bit masks
                CLB buffer+1 LDI 0xff STA buffer+3
                LXA shift DEX BCC ds_shiftdone                ; shift that buffer to pixel position
	ds_shiftloop:		LLW buffer+0 SEC RLW buffer+2								; set mask, keep mask
									DEX BCS ds_shiftloop
  ds_shiftdone:			LDA buffer+2 ANR addr ORA buffer+0 STR addr INW addr
										LDA buffer+3 ANR addr ORA buffer+1 STR addr LDI 63 ADW addr   ; ... and move to the next line
										DEY BNE ds_lineloop												; haben wir alle sprite daten verarbeitet?
											RTS

; ----------------------------------------------------------------------------------
; Draws or erases an 8x8 pixel sprite at the given position (0..255)
; push: num 0..1 (bit1=0: draw, bit1=1: erase), x, y
; pull: #, #, #
; modifies: X, Y registers
; ----------------------------------------------------------------------------------
DrawSmall:      LDI <smalls STA dptr+0 LDI >smalls STA dptr+1	; init sprite data pointer
								LDS 5 ANI 1 LL3 ADW dptr											; point to shot num (+ num*8 bytes)
								LDS 3 LL6 STA addr+0                          ; LSB of ypos*64
                LDS 3 RL7 ANI 63 ADI 0xc3 STA addr+1					; MSB of ypos*64 (rotate via C)
                LDS 4 RL6 ANI 63 ADI 12 ORB addr+0            ; xpos/8
                LDS 4 ANI 7 STA shift                         ; store sub byte pixel pos
								LYI 8																					; number of lines to process
	dm_lineloop:  LDR dptr STA buffer+0 INW dptr CLB buffer+1		; prepare the bit masks
								LXA shift DEX BCC dm_shiftdone                ; shift that buffer to pixel position
	dm_shiftloop:		LLW buffer+0 DEX BCS dm_shiftloop
  dm_shiftdone: LDS 5 ANI 2 CPI 2 BEQ dm_clearit
                  LDA buffer+0 ORR addr STR addr INW addr     ; store line buffer to VRAM addr
                  LDA buffer+1 ORR addr STR addr JPA dm_common
  dm_clearit:   LDA buffer+0 NOT ANR addr STR addr INW addr   ; store line buffer to VRAM addr
                LDA buffer+1 NOT ANR addr STR addr
  dm_common:    LDI 63 ADW addr                               ; ... and move to the next line
								DEY BNE dm_lineloop														; haben wir alle sprite daten verarbeitet?
									RTS

; ----------------------------------------------------------------------------------
; Draws a 24x16 pixel sprite (wall) at the given position (0..255)
; push: x, y
; pull: #, #
; modifies: X, Y registers
; ----------------------------------------------------------------------------------
DrawWall:       LDI <wall STA dptr+0 LDI >wall STA dptr+1     ; hard-coded wall data pointer
								LDS 3 LL6 STA addr+0                          ; LSB of ypos*64
                LDS 3 RL7 ANI 63 ADI 0xc3 STA addr+1					; MSB of ypos*64 (rotate via C)
                LDS 4 RL6 ANI 63 ADI 12 ORB addr+0            ; xpos/8
                LDS 4 ANI 7 STA shift                         ; store sub byte pixel pos
								LYI 16																				; number of lines to process
	dw_lineloop:  LDR dptr STA buffer+0 INW dptr								; prepare the bit masks
	              LDR dptr STA buffer+1 INW dptr
								LDR dptr STA buffer+2 INW dptr CLB buffer+3
                LXA shift DEX BCC dw_shiftdone                ; shift that buffer to pixel position
	dw_shiftloop:		LLW buffer+0 RLW buffer+2 DEX BCS dw_shiftloop
  dw_shiftdone:		  LDA buffer+0 ORR addr STR addr INW addr
										LDA buffer+1 ORR addr STR addr INW addr
										LDA buffer+2 ORR addr STR addr INW addr
										LDA buffer+3 ORR addr STR addr LDI 61 ADW addr    ; ... and move to the next line
										DEY BNE dw_lineloop												; haben wir alle sprite daten verarbeitet?
											RTS

DrawLaser:			LDA s_y LL6 STA addr+0                        ; LSB of ypos*64
                LDA s_y RL7 ANI 63 ADI 0xc3 STA addr+1				; MSB of ypos*64 (rotate via C)
                LDA s_x RL6 ANI 63 ADI 12 ORB addr+0          ; xpos/8
                LDA s_x ANI 7 ADI 0x0c STA dl_llx             ; use sub pixel pos
								LDI 1
	dl_llx:				SEC TAX
								LDR addr ORX STR addr LDI 64 ADW addr
								LDR addr ORX STR addr LDI 64 ADW addr
								LDR addr ORX STR addr LDI 64 ADW addr
								LDR addr ORX STR addr
								RTS

	dl_mask:			0

DeleteLaser:		LDA s_y LL6 STA addr+0                        ; LSB of ypos*64
                LDA s_y RL7 ANI 63 ADI 0xc3 STA addr+1				; MSB of ypos*64 (rotate via C)
                LDA s_x RL6 ANI 63 ADI 12 ORB addr+0          ; xpos/8
                LDA s_x ANI 7 ADI 0x0c STA de_llx             ; use sub pixel pos
								LDI 1
	de_llx:				SEC NOT TAX
								LDR addr ANX STR addr LDI 64 ADW addr
								LDR addr ANX STR addr LDI 64 ADW addr
								LDR addr ANX STR addr LDI 64 ADW addr
								LDR addr ANX STR addr
								RTS

; ---------------------------------
; returns the num / 11 and num % 11
; push:					num 0..54
; pull: 				num % 11
; A: return     num / 11
; ---------------------------------
GetModDiv11:		LDS 3
								CPI 44 BCS gdm44
									CPI 33 BCS gdm33
										CPI 22 BCS gdm22
											CPI 11 BCS gdm11
												STS 3 LDI 0 RTS
	gdm44:				SBI 44 STS 3 LDI 4 RTS
	gdm33:				SBI 33 STS 3 LDI 3 RTS
	gdm22:				SBI 22 STS 3 LDI 2 RTS
	gdm11:				SBI 11 STS 3 LDI 1 RTS

; ----------------------------------------------------------------------------------------------

sprites:        0xc0,0x03,0xf8,0x1f,0xfc,0x3f,0x9c,0x39,0xfc,0x3f,0x70,0x0e,0x98,0x19,0x30,0x0c,
								0xc0,0x03,0xf8,0x1f,0xfc,0x3f,0x9c,0x39,0xfc,0x3f,0x60,0x06,0xb0,0x0d,0x0c,0x30,
								0x20,0x08,0x40,0x04,0xe0,0x0f,0xb0,0x1b,0xf8,0x3f,0xe8,0x2f,0x28,0x28,0xc0,0x06,
								0x20,0x08,0x48,0x24,0xe8,0x2f,0xb8,0x3b,0xf8,0x3f,0xf0,0x1f,0x20,0x08,0x10,0x10,
								0x80,0x01,0xc0,0x03,0xe0,0x07,0xb0,0x0d,0xf0,0x0f,0xa0,0x05,0x10,0x08,0x20,0x04,
								0x80,0x01,0xc0,0x03,0xe0,0x07,0xb0,0x0d,0xf0,0x0f,0x40,0x02,0xa0,0x05,0x50,0x0a,
								0xe0,0x03,0xf8,0x0f,0xfc,0x1f,0x56,0x35,0xff,0x7f,0xdc,0x1d,0x08,0x08,0x00,0x00,
								0xc0,0x07,0xf0,0x1f,0xf8,0x3f,0xac,0x6a,0xfe,0xff,0xb8,0x3b,0x10,0x10,0x00,0x00,
								0x00,0x01,0x80,0x03,0x80,0x03,0xf8,0x3f,0xfc,0x7f,0xfc,0x7f,0xfc,0x7f,0xfc,0x7f,
								0x0c,0x20,0x41,0x98,0x08,0x03,0x40,0x40,0xd2,0x8c,0x84,0x23,0xf8,0x0f,0xec,0x4f,
								0x40,0x00,0x00,0x08,0x40,0x05,0x48,0x00,0x80,0x0d,0xa2,0x15,0xf8,0x27,0xfc,0xaf,
								0x48,0x24,0x90,0x12,0x20,0x08,0x0c,0x60,0x20,0x08,0x10,0x10,0x88,0x22,0x40,0x04,
								0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,

shots:					0x00,0x02,0x01,0x02,0x04,0x02,0x01,0x02,0x00,0x00,0x02,0x04,0x02,0x01,0x02,0x04,
								0x00,0x02,0x04,0x02,0x01,0x02,0x04,0x02,0x00,0x00,0x02,0x01,0x02,0x04,0x02,0x01,
								0x00,0x02,0x02,0x02,0x02,0x02,0x02,0x07,0x00,0x02,0x02,0x02,0x02,0x07,0x02,0x02,
								0x00,0x02,0x02,0x07,0x02,0x02,0x02,0x02,0x00,0x02,0x07,0x02,0x02,0x02,0x02,0x02,
								0x00,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x00,0x02,0x03,0x06,0x02,0x03,0x06,0x02,
								0x00,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x00,0x02,0x06,0x03,0x02,0x06,0x03,0x02,
								0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,

smalls:					0x91,0x44,0x7e,0xff,0xff,0x7e,0x24,0x89,0x10,0x3a,0x78,0x3c,0x3a,0x7c,0x3a,0x54,

wall:						0xf0,0xff,0x03,0xf8,0xff,0x07,0xfc,0xff,0x0f,0xfe,0xff,0x1f,
								0xff,0xff,0x3f,0xff,0xff,0x3f,0xff,0xff,0x3f,0xff,0xff,0x3f,
								0xff,0xff,0x3f,0xff,0xff,0x3f,0xff,0xff,0x3f,0xff,0xff,0x3f,
								0x7f,0xc0,0x3f,0x3f,0x80,0x3f,0x1f,0x00,0x3f,0x1f,0x00,0x3f,

hiscore:				0x00c6

u_values:				0, 30, 20, 10, 10, 5, 5, 5, 5
u_text:					'---', 0, '300', 0, '200', 0, '100', 0, '100', 0
								' 50', 0, ' 50', 0, ' 50', 0, ' 50', 0
u_empty:				'   ', 0

text0:					'SCORE<1>', 0
text1:					'HI-SCORE', 0
text2:					'PLAY', 0
text3:					'ALIEN INVADERS', 0
text4:					'* SCORE ADVANCE TABLE *', 0
text5:					'= MYSTERY', 0
text6:					'= 30 POINTS', 0
text7:					'= 20 POINTS', 0
text8:					'= 10 POINTS', 0
text9:					'PRESS <SPACE>', 0
texta:					'CREDIT 00', 0
textb:					'WAVE', 0
textc:					'3            ', 0
textd:					'   GAME OVER   ', 0
texte:					'<A> -- <D>', 0

; ----------------------------------------------------------------------------------------------

#mute

; global variables of ALIEN INVADERS
gamestate:			0
score:					0x0000
shippos:				0				; horizontal position of the ship (left upper corner)
lives:					0
level:					0
fire:						0				; keyboard control state, modified by KeyHandler
left:						0
right:					0
waitframes:			0x0000
framecount:			0x00
counter:				0x0000

a_total:				0				; alien system
a_x:						0x0000
a_y:						0
a_c:						0
a_r:						0
a_pic:					0
a_num:					0
a_step:					0				; 1: ax+=2, -1: ax-=2
a_costume:			0
a_halt:					0				; can be used to stop the movement for a while
a_alive:				0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0				; state of each alien
								0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
								0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
								0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
								0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

s_x:						0
s_y:						0
s_timer:				0
s_state:				0
s_dx:						0
s_dy:						0
s_ix:						0
s_iy:						0
s_by:						0

u_state:				0
u_valptr:				0xffff
u_timer:				0x0000
u_pos:					0
u_step:					0

as_ptr:					0xffff
as_col:					0
as_c:						0
as_r:						0
as_colcmod:			0		; holds (col+c)%11
as_px:					0
as_py:					0

as0_active:			0		; -1: free, >=0: shot type
as0_x:					0
as0_y:					0		; TOP MIDDLE position of the shot
as0_timer:			0
as1_active:			0		; -1: free, >=0: shot type
as1_x:					0
as1_y:					0		; TOP MIDDLE position of the shot
as1_timer:			0
as2_active:			0		; -1: free, >=0: shot type
as2_x:					0
as2_y:					0		; TOP MIDDLE position of the shot
as2_timer:			0

; ----------------------------------------------------------------------------------------------

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
