; You can take a look at the raw PS/2 data your Minimal 64 is receiving by using the following code snippet:

#org 0x8000

test:       INK CPI 0xff BEQ test PHS JPS 0xb04e PLS JPA test   ; calls API function _PrintHex

