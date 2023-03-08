#org 0x8000

start:    LDI 0x1e  ; sends all visible chars starting from 30 up until 255 via UART

next:     OUT NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP
          INC
          BCC next
            JPA start
