;*******************************************************
;* CMPEN 472, HW8 Real Time Interrupt, MC9S12C128 Program
;* CodeWarrior Simulator/Debug edition, not for CSM-12C128 board
;* Oct.  13, 2016 Kyusun Choi
;* Oct.  14, 2020 Kyusun Choi
;* Oct.  23, 2021 Kyusun Choi
;* Oct.  23, 2022 Kyusun Choi
;* 
;* 1 second LED1 blink, timer using Real Time Interrupt.
;* This program is a 1 second timer using 
;* a Real Time Interrupt service subroutine (RTIISR).  This program
;* displays the time on the 7 Segment Disply in Visualization Tool 
;* every 1 second.  That is, this program 
;* displays '1 0 1 0 1 0 . . . ' on the 7 segment displys. 
;* The 7 segment displys are connected to port B of
;* MC9S12C32 chip in CodeWarrior Debugger/Simulator.
;* Also on the Terminal component of the simulator,  
;* user may enter any key, it will be displayed on the screen - effectively
;* it is a typewriter.
;*
;* Please note the new feature of this program:
;* RTI vector, initialization of CRGFLG, CRGINT, RTICTL, registers for the
;* Real Time Interrupt.
;* We assumed 24MHz bus clock and 4MHz external resonator clock frequency.  
;* 
;*******************************************************
;*******************************************************

; export symbols - program starting point
            XDEF        Entry        ; export 'Entry' symbol
            ABSENTRY    Entry        ; for assembly entry point

; include derivative specific macros
PORTA       EQU         $0000
PORTB       EQU         $0001
DDRA        EQU         $0002
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character
CN          equ         $3a

;*******************************************************
; variable/data section
            ORG    $3000             ; RAMStart defined as $3000
                                     ; in MC9S12C128 chip

hours                 DC.B   0                 ; Hour
minutes               DC.B   0                 ; Minute
seconds               DC.B   0                 ; Second
ctr2p5m               DS.W   1                 ; interrupt counter for 2.5 mSec. of time


displayTimeAddr       DC.W    ZERO
ZERO                  DC.B    0    


inputHour             DS.B    1
inputMinute           DS.B    1
inputSecond           DS.B    1

;*******************************************************
; interrupt vector section
            ORG    $FFF0             ; RTI interrupt vector setup for the simulator
;            ORG    $3FF0             ; RTI interrupt vector setup for the CSM-12C128 board
            DC.W   rtiisr

;*******************************************************
; code section

            ORG    $3100
Entry
            LDS    #Entry         ; initialize the stack pointer

            LDAA   #%11111111   ; Set PORTA and PORTB bit 0,1,2,3,4,5,6,7
            STAA   DDRA         ; all bits of PORTA as output
            STAA   PORTA        ; set all bits of PORTA, initialize
            STAA   DDRB         ; all bits of PORTB as output
            STAA   PORTB        ; set all bits of PORTB, initialize

            ldaa   #$0C         ; Enable SCI port Tx and Rx units
            staa   SCICR2       ; disable SCI interrupts

            ldd    #$0001       ; Set SCI Baud Register = $0001 => 1.5M baud at 24MHz (for simulation)
;            ldd    #$0002       ; Set SCI Baud Register = $0002 => 750K baud at 24MHz
;            ldd    #$000D       ; Set SCI Baud Register = $000D => 115200 baud at 24MHz
;            ldd    #$009C       ; Set SCI Baud Register = $009C => 9600 baud at 24MHz
            std    SCIBDH       ; SCI port baud rate change

            ldx    #msg1          ; print the first message, 'Hello'
            jsr    printmsg
            jsr    nextline
            
            bset   RTICTL,%00011001 ; set RTI: dev=10*(2**10)=2.555msec for C128 board
                                    ;      4MHz quartz oscillator clock
            bset   CRGINT,%10000000 ; enable RTI interrupt
            bset   CRGFLG,%10000000 ; clear RTI IF (Interrupt Flag)


            ldx    #0
            stx    ctr2p5m          ; initialize interrupt counter with 0.
            cli                     ; enable interrupt, global


newCommand   
            ldx    #cmdContent      ; resets pointer for buffer
            ldab   #0               ; reset counter for characters entered
            
looop       jsr    updateTime       ; if 1 second is up, update the time 

            jsr    getchar          ;  type writer - check the key board
            tsta                    ;  if nothing typed, keep checking
            beq    looop
            
            
            ; check if isError is a space
            psha
            ldaa   #$00
            cmpa   isError
            pula
            bne    looop
            
            
            staa   1,X+             ; stores cmd typed in in input buffer
            ;put letter in cmd content and figure out if I need to 
            
            cmpb   #11
            bge    invalidInput
            incb
            
            
            cmpa   #CR
            bne    looop            ; if Enter/Return key is pressed, move the
            ;ldaa   #LF              ; cursor to next line
            ;jsr    putchar
            
            
            jsr    parseCmd
            bcc    newCommand


invalidInput                         
            ldaa   #$20
            staa   isError
            bra    newCommand

;subroutine section below

;***********RTI interrupt service routine***************
rtiisr      bset   CRGFLG,%10000000 ; clear RTI Interrupt Flag - for the next one
            ldx    ctr2p5m          ; every time the RTI occur, increase
            inx                     ;    the 16bit interrupt count
            stx    ctr2p5m
rtidone     RTI
;***********end of RTI interrupt service routine********

;***************updateTime**********************
;* Program: updates and outputs the time to the terminal
;* Input:   ctr2p5m variable
;* Output:  time, command, and error
;* Registers modified: x,y,d
;* Algorithm:
;    Check for 1 second passed
;      if not 1 second yet, just pass
;      if 1 second has reached, then send correct time in decimal format to port b
;         convert the seconds, minutes, and hours, into ascii and display in the correct format
;         update seconds, minutes, and hours with proper overflow
;**********************************************
updateTime      ; can update ascii directly with time if conversion approach takes too long then ascii converstion can be done in parse cmd
            pshy
            pshx                         ; save register
            pshd
            
            
            
            ldx      ctr2p5m          ; check for 1 sec
            cpx     #150             ; 2.5msec * 200 = 0.5 sec
            ;cpx      #400              ; 2.5msec * 40 = 1 sec
            lblo     doneUpdate          ; NOT yet
            
            ldx      #0                  ; reset the interupt counter
            stx      ctr2p5m
                    
                   
            ldx      displayTimeAddr     ; load address to value to be displayed on lcd
            ldaa     X                   ; load value from address to be displayed on lcd
            
            ; transfer a to b           ; make each digit displayed a decimal digit
            TAB                         ; moves content from a to b
            andb     #%00001111         ; masks to work with the lower 4 bits
            cmpb     #10                ; checks if the lower 4 bits are over 10
            blt      displayTime        ; if not then continue and send as is to PORTB
            subb     #10                ; if lower 4 bits above 10 then subtract 10 from the lower 4 bits
            anda     #%11110000         ; 
            adda     #%00010000         ; add one to the upper 4 bits
            ABA                         ; combine to one number to send to PORTB
            
            
displayTime 
            staa     PORTB              ; Sends time to PORTB to be displayed on LCD
            
                        
            pshd                         ;save registers
            pshx
            
            
            
            ; convert seconds
            
            
            ldy      #secondsAscii       ;stores pointer to second digit for seconds ascii 
            iny
            
            
            ldab      seconds            ; loads seconds value
            ldx       #10                ; loads 10 to x for division for ascii converion
            ldaa      #0                 ; clears a to not effect the multiplication
            
            IDIV                         ; division
            
            addd      #48                ; add ascii offset to remainder
            stab       Y                 ; store first ascii digit
            dey                          ; move to second ascii digit
            
            tfr       X,D                ; move result to d to be divided again
            ldx       #10                ; load 10 into x again for division
            
            
            IDIV                         ;complete integer divison
            addd      #48                ; add ascii offset
            stab       Y                 ; store second digit
            
            
            
            ; convert minutes
            
            ldy      #minutesAscii       ; load pointer to second ascii digit
            iny
            
            ldab      minutes            ; load values for division
            ldx       #10                ; a is already cleared so no need to clear manually
            
            IDIV                         ; complete division
            
            addd      #48                ; add ascii offset
            stab       Y                 ; store first digit
            dey                          ; move to second digit
            
            tfr       X,D                ; move result to divisor for next division
            ldx       #10                ; load dividend again
            
            
            IDIV                         ; complete division
            addd      #48                ; add ascii offset
            stab       Y                 ; store at first minutes digit 
            
            
            ;hours
            ldy       #hoursAscii        ; load pointer to second ascii digit
            iny
            
            ldab      hours              ; loads values for divion
            ldx       #10
            
            IDIV                         ; execute division
            
            addd      #48                ; add ascii offset
            stab       Y                 ; store at first digit of hours
            dey
            
            tfr       X,D                ; move result to divisor
            ldx       #10                ; load dividend
            
            
            IDIV                         ; execute division
            addd      #48                ; add ascii offset
            stab       Y                 ; store at first digit of hours
            
            
            pulx                         ; restore register to before division
            puld
            
            ;end of ascii conversion
            
            
         
            
            
            ; print time message
            ldx      #timeClockMsg       ; prints time and command entered
            jsr      printmsg
            
            ldx      #errorMsg           ; prints error message
            jsr      printmsg
            jsr      nextline            ; prints new line
            
            ldaa     #$00                ; checks if error is there is no error
            cmpa     isError
            beq      increaseTime        ; if no error skip clearing command buffer and update time


            staa     isError            ; resets error message so error is not printed
            ldx     #cmdContent

clrCmdLoop              
            ldaa    #$20                  ; loop through each space in the cmd buffer nad replace each char with a space
            staa    1,X+ 
            
            cpx     #endCmdContent
            bne     clrCmdLoop





            ; update time
increaseTime              
            ldaa     seconds             ; load value of seconds
            inca                         ; increase seconds
            staa     seconds             ; store new value
            cmpa     #60                 ; check if new value is 60
            bne      doneUpdate          ; if not then update is done
            
            
            
            ldaa     #0                  ; if new value is 60 then over flow and add to minutes
            staa     seconds             ; set new seconds to 0
            
            ldaa     minutes             ; load minutes value
            inca                         ; increase minutes
            staa     minutes             ; store new value of minutes
            cmpa     #60                 ; check if minutes overflow
            bne      doneUpdate          ; if no overflow then update is done

            
            
            ldaa     #0                  ; if there is overflow set new value of minutes to 0
            staa     minutes
            
            ldaa     hours               ; load hours value
            inca                         ; increment hours vlaue
            staa     hours               ; store new hours value
            cmpa     #24                 ; check for overflow
            bne      doneUpdate          ; if no overflow then skip to done
            
            ldaa     #0                  ; if overflow then set new hours value to 0
            staa     hours
            

doneUpdate   
            puld         
            pulx                          ; restore registers
            puly                          ; return from subroutine
            rts
;***************end of updateTime***************


;***************parseCmd**********************
;* Program: parses the characters typed in cmd buffer
;* Input: cmd buffer  
;* Output: action based on command
;* Registers modified: CCR, X, D, Y
;* Algorithm:
;    Check if first char is s
;        update address to be seconds
;    Check if first char is m
;        update address to be minutes
;    Check if first char is h
;        update adress to be hours
;    Check if first char is t
;        check for correct time format and bounds 
;        update time variable
;    Check if first char is q
;         check for CR and if there run type writer
;       otherwise reutnr error
;
;      if not 0.5 second yet, just pass
;      if 0.5 second has reached, then toggle LED and reset ctr2p5m
;**********************************************
parseCmd
            pshx
            pshd

            ldx     #cmdContent
            ldaa    1,X+
            
            cmpa    #'s'                ; check for s
            bne     checkM              ; if not move to s
            ldaa    1,X+                ; load next char
            cmpa    #CR                 ; check for enter
            lbne     invalidCmd         ; print error if not
            ldx     #seconds            ; update display address to seconds
            stx     displayTimeAddr
            lbra    endParse            ; move to end of subroutine
            
checkM            
            cmpa    #'m'                 ; check for m
            bne     checkH               ; if not move to h
            ldaa    1,X+                 ; load next char
            cmpa    #CR                  ; check for enter
            lbne     invalidCmd          ; print error if not
            ldx     #minutes             ; pudate display address to minutes
            stx     displayTimeAddr
            lbra    endParse             ;move to end of subroutine

checkH            
            cmpa    #'h'                 ; check for m
            bne     checkT                ; if not move to h
            ldaa    1,X+                  ; load next char
            cmpa    #CR                  ; check for enter
            lbne     invalidCmd           ; print error if not
            ldx     #hours                ; pudate display address to minutes
            stx     displayTimeAddr
            lbra    endParse               ;move to end of subroutine


checkT     
            ; t and space
            cmpa    #'t'                   ; check for t
            lbne     checkQ                ; if not move to q
            ldaa    1,X+                   ; load next char
            cmpa    #$20                   ; check for space
            lbne     invalidCmd            ; if not print error
            ldaa    1,X+                   ; load next char
            
            
            ; validate hour number
            suba    #$30                   ; remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi     invalidCmd            ; not not print error 
            staa    inputHour              ; store in temp hours variable
            
            ldaa    1,X+                   ; load next char 
            cmpa    #CN                    ; check if colon
            beq     minutesNumber          ; if so move to validate second number
            suba    #$30                   ; if not then remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi     invalidCmd            ; if not print error
            
            psha                           ; save a
            ldab    #10                    
            ldaa    inputHour              ; load temp variable to a
            MUL                            ; multiply a by 10
            pula                           ; restore value in a before multiplication
            aba                            ; add a to result of multiplication
            cmpa    #24                    ; check if over 24
            lbge    invalidCmd             ; if >= print error
            staa    inputHour              ; otherwise store value
            
            ; first colon
            ldaa    1,X+                   ; load next character
            cmpa    #CN                    ; check for colon
            lbne     invalidCmd            ; if not print error
            
            
            ; minutes number
minutesNumber
            ldaa    1,X+                   ;load next character
            suba    #$30                   ; remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi    invalidCmd             ; if so print error
            staa    inputMinute            ; store in temp variable
            
            ldaa    1,X+                   ; load next character
            suba    #$30                   ; remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi     invalidCmd            ; if not print error
            
            psha
            ldab    #10                    ; multiply value in a by 10 then add a and store in temp
            ldaa    inputMinute
            MUL     
            pula
            aba
            cmpa    #60                    ; check if new minutes less than 60
            bge     invalidCmd             ; if not print error
            staa    inputMinute            ; store in temp minutes
            
            ;second colong
            ldaa    1,X+
            cmpa    #CN                    ;check for colon
            bne     invalidCmd
            
            ; seconds number
            ldaa    1,X+                   ; do same thing as for minutes number
            suba    #$30
            cmpa    #9
            lbhi     invalidCmd
            staa    inputSecond
            
            ldaa    1,X+
            suba    #$30
            cmpa    #9
            lbhi     invalidCmd
            
            psha
            ldab    #10
            ldaa    inputSecond
            MUL     
            pula
            aba
            cmpa    #60
            lbge     invalidCmd
            staa    inputSecond
            
            
            ;store temp values once validated
            ldaa    inputHour               ;store new hours
            staa    hours
            ldaa    inputMinute             ; store new minutes
            staa    minutes
            ldaa    inputSecond             ;store new seconds
            staa    seconds
            
            lbra    endParse                ; skip to end of subroutine
            
checkQ            
            cmpa    #'q'                     ; check for q
            bne     invalidCmd              ; if not no other commands left so print error
            ldaa    1,X+
            cmpa    #CR                     ; check next char for enter 
            bne     invalidCmd              ; if not print error
            jsr     typeWriterLoop          ; if so run type writer program for lifetime of program
            
            
endParse            
            
            ldx     #cmdContent              ; load address to beginign of cmd buffer

clrCmdLoop2              
            ldaa    #$20
            staa    1,X+                     ; iterate through each value of cmd buffer
                                             ; turn all values to spaces
            cpx     #endCmdContent
            bne     clrCmdLoop2
            
            clc
            puld                              ;clear carry indicating success
            pulx                              ; restore registers
            rts                               ; return from subroutine
            
            
invalidCmd  
            ldaa    1,X+
            cmpa    #CR
            bne     invalidCmd                ; clear cmd buffer and replace with spaces
            ldaa    #$20
            staa    -1,X
            
setCarry    sec                               ; set carry indictaing invalid input
            puld                              ; restore registers
            pulx                              ; return from subroutine
            rts
            
;***************end of parseCmd***************


;***********printmsg***************************
;* Program: Output character string to SCI port, print message
;* Input:   Register X points to ASCII characters in memory
;* Output:  message printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Pick up 1 byte from memory where X register is pointing
;     Send it out to SCI port
;     Update X register to point to the next byte
;     Repeat until the byte data $00 is encountered
;       (String is terminated with NULL=$00)
;**********************************************
NULL            equ     $00
printmsg        psha                   ;Save registers
                pshx
printmsgloop    ldaa    1,X+           ;pick up an ASCII character from string
                                       ;   pointed by X register
                                       ;then update the X register to point to
                                       ;   the next byte
                cmpa    #NULL
                beq     printmsgdone   ;end of strint yet?
                bsr     putchar        ;if not, print character and do next
                bra     printmsgloop
printmsgdone    pulx 
                pula
                rts
;***********end of printmsg********************

;***************putchar************************
;* Program: Send one character to SCI port, terminal
;* Input:   Accumulator A contains an ASCII character, 8bit
;* Output:  Send one character to SCI port, terminal
;* Registers modified: CCR
;* Algorithm:
;    Wait for transmit buffer become empty
;      Transmit buffer empty is indicated by TDRE bit
;      TDRE = 1 : empty - Transmit Data Register Empty, ready to transmit
;      TDRE = 0 : not empty, transmission in progress
;**********************************************
putchar     brclr SCISR1,#%10000000,putchar   ; wait for transmit buffer empty
            staa  SCIDRL                      ; send a character
            rts
;***************end of putchar*****************

;****************getchar***********************
;* Program: Input one character from SCI port (terminal/keyboard)
;*             if a character is received, other wise return NULL
;* Input:   none    
;* Output:  Accumulator A containing the received ASCII character
;*          if a character is received.
;*          Otherwise Accumulator A will contain a NULL character, $00.
;* Registers modified: CCR
;* Algorithm:
;    Check for receive buffer become full
;      Receive buffer full is indicated by RDRF bit
;      RDRF = 1 : full - Receive Data Register Full, 1 byte received
;      RDRF = 0 : not full, 0 byte received
;**********************************************

getchar     brclr SCISR1,#%00100000,getchar7
            ldaa  SCIDRL
            rts
getchar7    clra
            rts
;****************end of getchar**************** 

;****************nextline**********************
nextline    psha
            ldaa  #CR              ; move the cursor to beginning of the line
            jsr   putchar          ;   Cariage Return/Enter key
            ldaa  #LF              ; move the cursor to next line, Line Feed
            jsr   putchar
            pula
            rts
;****************end of nextline***************

;***********typeWriter***************************
;* Program: runs type writer once menu selection quits. gets char input and displays in on 7 segment display
;* Input: ascii characters from serial port  
;* Output: sends char to PORTB
;* 
;* Registers modified: A register
;* Algorithm: continually checks for input availible. when input is availible it is stored in a then send to PORTB and displayed on terminal
;     
;**********************************************
typeWriterLoop  jsr   getchar            ; type writer - check the key board
                cmpa  #$00               ;  if nothing typed, keep checking
                beq   typeWriterLoop
                                         ;  otherwise - what is typed on key board
                jsr   putchar            ; is displayed on the terminal window - echo print

                staa  PORTB              ; show the character on PORTB

                cmpa  #CR
                bne   typeWriterLoop     ; if Enter/Return key is pressed, move the
                ldaa  #LF                ; cursor to next line
                jsr   putchar
                bra   typeWriterLoop
 ;***********end of typeWriter********************




timeClockMsg              DC.B         'Clock> '
hoursAscii                DC.B         '00',CN
minutesAscii              DC.B         '00',CN
secondsAscii              DC.B         '00'
space                     DC.B         '     '
cmdMsg                    DC.B         'CMD> '
cmdContent                DC.B         '               '
endCmdContent             DC.B         $00
errorMsg                  DC.B         'Error>'
isError                   DC.B          $00
invalidInputMsg           DC.B         'Invalid input',$00

msg1                  DC.B   'Hello',CR,LF
                      DC.B   'You may use the following commands:',CR      ; type a welcome message explaining commands
                      DC.B   't 00:00:00 - sets the time to the entered time',CR
                      DC.B   'q - quits the program and runs the typewriter program',CR
                      DC.B   'h - displays the hour in decimal format on the display',CR
                      DC.B   'm - displays the minute in decimal format on the display',CR
                      DC.B   'm - displays the second in decimal format on the display',CR
                      DC.B   'the time and characters entered will display every second',CR                       
                      
msg2                  DC.B   'You may type below', $00
            
            
            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled
                              
                              
