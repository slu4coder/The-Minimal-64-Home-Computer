                #org 0x7000

                LDI 0xfe STA 0xffff      ; init stack
                JPS _Clear CLW _XPos
start:          LDI <string PHS          ; put LSB of string address on the stack
                LDI >string PHS          ; put MSB of string address on the stack
                JPS _Print PLS PLS       ; clean up the stack
                JPS _WaitInput
                JPA start

string:         'Hello! Press any key. ', 0

#mute

#org 0xb02a _WaitInput:
#org 0xb030 _Clear:
#org 0xb048 _Print:
#org 0xbf8c _XPos:
