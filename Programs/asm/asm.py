# Python Assembler for the 'MINIMAL 64 HOME COMPUTER' written by Carsten Herting (slu4) 2023

# This assembler reads an assembly language source file, translates the instructions into machine code,
# and emits the code in Intel Hex format. The program is structured into two main passes: Pass 1: Parse
# the source code and store label definitions and their program counter (PC) values. Pass 2: Emit the
# machine code based on the parsed instructions and label values. Here's an overview of the key components
# and how they work together:
#   1) File handling: The program reads the input assembly file specified as a command-line argument, 
# appends a null character ('\0') to mark the end of the file, and stores the content in a string 
# called src.
#   2) findelem() function: This function iterates over the source code, counting lines and skipping 
# whitespaces and comments. It returns the length of the current element in the source code. It is 
# used in both Pass 1 and Pass 2.
#   3) Pass 1: The program iterates through the source code using findelem() to identify label definitions,
# mnemonics, preprocessor commands, and expressions. It stores the label definitions and their corresponding
# PC values in a dictionary called labels. It also increments the PC based on the type of element encountered.
#   4) Pass 2: The program resets the PC and iterates through the source code again, emitting machine code 
# based on the parsed instructions and label values. During this pass, it handles preprocessor commands
# (e.g., #org, #mute, and #emit), label definitions, mnemonics, strings, operators, and expressions. The
# generated machine code is stored in an IntelHex object called 'ih'.
#   5) Output: The program writes the output to the console in Intel Hex format.

mne = "NOP BNK BFF WIN INP INK OUT NOT NEG INC DEC CLC SEC LSL LL2 LL3 LL4 LL5 LL6 LL7 LSR ROL RL2 RL3 RL4 RL5 RL6 RL7 ROR LDI ADI SBI ACI SCI CPI ANI ORI XRI JPA LDA STA ADA SBA ACA SCA CPA ANA ORA XRA JPR LDR STR ADR SBR ACR SCR CPR ANR ORR CLB NOB NEB INB DEB ADB SBB ACB SCB ANB ORB LLB LRB RLB RRB CLW NOW NEW INW DEW ADW SBW ACW SCW LLW RLW JPS RTS PHS PLS LDS STS BNE BEQ BCC BCS BPL BMI BGT BLE TAX TXA TXY LXI LXA LAX INX DEX ADX SBX CPX ANX ORX XRX TAY TYA TYX LYI LYA LAY INY DEY ADY SBY CPY ANY ORY XRY HLT".split()

import sys, re; from intelhex import IntelHex; ih = IntelHex(); src = ""; ep = 0; pc = 0; line = 1; labels={}
try: file = open(sys.argv[1]); src = file.read() + "\0"; file.close()
except (FileNotFoundError, IndexError): exit("USAGE: asm.py <filename>")

def findelem(): # SKIP WHITESPACES AND COMMENTS, COUNT LINES AND RETURN ELEMENT LENGTH
	global ep, line, src
	while ep < len(src):
		if src[ep] == '\n': ep += 1; line += 1
		elif m := re.match(r"[ ,\r\t]+|;[^\n\0]*", src[ep:]): ep += m.end() # skip whitespaces & comments
		else: m = re.match(r"'[^'\n\0]*'|[^ ,;\t\n\r\0]*", src[ep:]); return m.end() if m else None # length

while size := findelem(): # PASS 1: STORE LABEL DEFINITIONS AND THEIR PC
	if src[ep:ep+size].endswith(':'): # elements ending with ':' are definitions
		definition = src[ep:ep+size-1] # extract the identifier
		if definition in labels: exit("Error in line " + str(line) + ": \'" + definition + "\' already exists.")
		else: labels[definition] = pc # add unique labels to the dictionary
	elif size == 3 and src[ep:ep+size] in mne: pc += 1 # check for mnemonics
	elif src[ep] == '#': # check for pre-processor commands
		if src[ep:].find("#org") == 0: # parse pre-processor stuff, only use #org here
			ep += size; size = findelem() # parse for the proceeding element which must be a hex address
			if re.fullmatch(r"0x[0-9a-f]+", src[ep:ep+size]): pc = int(src[ep:ep+size], 16) # set PC
			else: exit("Error in line " + str(line) + ": Expecting a hex address.")
	elif src[ep] == '\'': pc += size-2 # check for 'string' (errors due to missing closing ' are cought elsewhere)
	elif src[ep] == '<' or src[ep] == '>': pc += 1 # check for LSB/MSB operator
	else: # it must be an expression
		if src[ep] == '+' or src[ep] == '-': size -= 1; ep += 1	# consume optional leading + or -
		if re.fullmatch(r"0x[0-9a-f]{3}", src[ep:ep+5]): pc += 2 # check for HEX 0xabc...
		elif src[ep].isdigit(): pc += 1 # check for HEX 0x.. or DEC byte
		else: pc += 2 # all other stuff must be a label or * operator
	ep += size # move over this element

ep = 0; pc = 0; line = 1; isemit = True # PASS 2: CODE EMISSION
while size:= findelem(): # translate all elements
	if src[ep:].find("#mute") == 0: isemit = False # pre-processor commands
	elif src[ep:].find("#emit") == 0: isemit = True
	elif src[ep:].find("#org") == 0: # will influence the memory position of code emission
		ep += size; size = findelem() # only accept #org and change PC when emitting
		if isemit and re.fullmatch(r"0x[0-9a-f]+", src[ep:ep+size]): pc = int(src[ep:ep+size], 16)
	elif isemit: # is code emission on?
		if src[ep:ep+size].endswith(':'): pass # don't output anything
		elif src[ep] == '\'': # string content
			for c in src[ep+1:ep+size-1]: ih[pc] = ord(c); pc += 1
		elif size == 3 and src[ep:ep+size] in mne: ih[pc] = mne.index(src[ep:ep+size]); pc += 1 # mnemonic
		else: # EXPRESSION PARSING
			x = ep; type = ""; term = 0; expr = 0; sign = 1; signs = {'+': 1, '-': -1}
			if src[x] == '<' or src[x] == '>': type = src[x]; x += 1	# take LSB and MSB operators
			while x < ep+size: # look for terms 'label+0xffff-50+*': THE FIRST ELEMENT DETERMINS THE SIZE
				if src[x] in signs: sign = signs[src[x]]; x += 1; term = 0	# take a leading sign & reset term
				if src[x] == '*': term = pc; x += 1; type = 'w' if type == "" else type # use current PC as a term
				elif hex := re.match(r"0x[0-9a-f]+", src[x:]): # hex value
					term = int(hex.group(), 16); x += hex.end(); type = 'w' if type == "" and hex.end() > 4 else type
				elif num := re.match(r"[0-9]+", src[x:]): term = int(num.group()); x += num.end() # dec (byte!) value
				elif (ref := re.match(r"[_a-zA-Z][_a-zA-Z0-9]*", src[x:])) and ref.group() in labels: # label reference
					term = labels[ref.group()]; x += ref.end(); type = 'w' if type == "" else type
				else: exit("Error in line " + str(line) + ": Unknown expression \'" + src[x:ep+size] + "\'") # catches anything else
				expr += sign * term # add/subtract this term to the expression
			if type == 'w': ih[pc] = expr & 0xff; ih[pc+1] = (expr & 0xff00)>>8; pc += 2 # emit expression word
			elif type == '>': ih[pc] = (expr & 0xff00)>>8; pc += 1 # emit MSB only
			else: ih[pc] = expr & 0x00ff; pc += 1 # emit LSB (standard)
	ep += size # consume current element after having it processed
ih.write_hex_file(sys.stdout) # output the hexfile to the console

# Language Definition (EBNF) by Carsten Herting (slu4) 2023

# char        = ? any character ?
# letter      = 'a' | ... | 'z' | 'A' | ... | 'Z'
# digit       = '0' | ... | '9'
# hexdigit    = digit | 'a' | ... | 'f'           (* only lower-case allowed *)
# hexnum  	  = '0x', hexdigit, {hexdigit}
# dec_lsb  	  = digit, {digit}                    (* only the lsb part of dec numbers will be used *)
# label       = ('_' | letter), {'_' | letter | digit}
# gap         = ' ' | ',' | '\t' | '\r' | '\n'
# add-op  	  = '+' | '-'
# lsbmsb-op   = '<' | '>'
# mnemonic    = 'NOP' | ... | 'HLT'
# pre-proc 	  = '#emit' | '#mute' | ( '#org', gap, {gap}, hexnum )
# comment 	  = ';', { char - ( '\n' | '\0' ) }
# definition  = label, ':'
# string  	  = "'", { char - ( '\n' | '\0' | "'" ) }, "'"
# program 	  = {gap}, [ element, { gap, {gap}, element } ], {gap}, '\0'
# element 	  = pre-proc | comment | string | mnemonic | definition | expression
# expression  = [ lsbmsb-op ], [ add-op ], term, { add-op, term }			(* 1st term determines size *)
# term        = hexnum | dec_lsb | label | '*'

# LICENSING INFORMATION
# This file is free software: you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
# This file is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
# License for more details. You should have received a copy of the GNU General Public License along
# with this program. If not, see https://www.gnu.org/licenses/.
