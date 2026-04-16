;*******************************************************
;* CMPEN 472, 2022 Spring 
;* Homework 10: Timer Interrupt Sample Program, 
;* MC9S12C128 Program (set to MC9S12C32 for Simulation/Debug)
;* CodeWarrior Simulator/Debug edition, not for CSM-12C128 board
;* April.   09, 2021 Michael Frayne
;* 
;* This program is a 1024 data transfer program running on the 
;*   CodeWarrior Debugger/Simulator as follows: 
;*   1. Program starts with print messages on the simulator Terminal,
;*      an intro message at 1.5M baud (this program will not work 
;*      on the CSM-12C128 board - 1.5M baud too fast).
;*   2. Then user may hit any key, it's a typewriter program at 1.5M baud.
;*      But hitting the Enter key will terminate the typewriter mode with 
;*      the instruction message print.
;*   3. Two messages are (1) start terminal data capture into a file and
;*      (2) hit Enter key for the 1024 data transfer to begin. 
;*   4. At this time, user setup the Terminal Output file, data capture to a file.
;*   5. User hits an Enter key to send 1024 data, to the Terminal and
;*      the data saved in to a file named RxData3.txt  which may be looked at 
;*      or plotted using Excel sheet.
;*   6. User may repeat the step 3 above as many times as he/she like.
;*      User plots or prints the data to verify the correct data transmit.
;* 
;* We assumed 24MHz bus clock and 4MHz external resonator clock frequency.  
;* 
;*******************************************************
;*******************************************************

; export symbols - program starting point
            XDEF        Entry   ; export 'Entry' symbol
            ABSENTRY    Entry   ; for assembly entry point

; include derivative specific macros
PORTB       EQU         $0001
DDRB        EQU         $0003

SCIBDH      EQU         $00C8   ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9   ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB   ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC   ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF   ; Serial port (SCI) Data Register

TIOS        EQU         $0040   ; Timer Input Capture (IC) or Output Compare (OC) select
TIE         EQU         $004C   ; Timer interrupt enable register
TCNTH       EQU         $0044   ; Timer free runing main counter
TSCR1       EQU         $0046   ; Timer system control 1
TSCR2       EQU         $004D   ; Timer system control 2
TFLG1       EQU         $004E   ; Timer interrupt flag 1
TC4H        EQU         $0058   ; Timer channel 4 register

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d     ; carriage return, ASCII 'Return' key
LF          equ         $0a     ; line feed, ASCII 'next line' character
CN          equ         $3A     ; colon

DATAmax     equ         2048    ; Data count maximum, 1024 constant

;*******************************************************
; variable/data section
            ORG    $3000        ; RAMStart defined as $3000
                                ; in MC9S12C128 chip

ctr125u     DS.W   1            ; 16bit interrupt counter for 125 uSec. of time

hours                 DC.B   0                 ; Hour
minutes               DC.B   0                 ; Minute
seconds               DC.B   0                 ; Second
ctr2p5m               DS.W   1                 ; interrupt counter for 2.5 mSec. of time


displayTimeAddr       DS.W    1

inputHour             DS.B    1
inputMinute           DS.B    1
inputSecond           DS.B    1



BUF         DS.B   11            ; character buffer for a 16bit number in decimal ASCII
CTR         DS.B   1             ; character buffer fill count


msg2        DC.B   'When ready, hit Enter key.', $00

triWaveDirection      DC.B    0

sqWaveOut   DC.B      0
triCtr      DC.W      1
;*          more text messages at the End of this program

;*******************************************************
; interrupt vector section

            ORG     $FFE6       ; Timer channel 6 interrupt vector setup, on simulator
            DC.W    oc4isr
            
            ORG    $FFF0             ; RTI interrupt vector setup for the simulator
            DC.W   rtiisr


;*******************************************************
; code section

            ORG    $3100
Entry
            LDS    #Entry       ; initialize the stack pointer

            LDAA   #%11111111   ; Set PORTB bit 0,1,2,3,4,5,6,7
            STAA   DDRB         ; as output
            LDAA   #%00000000   ; Clear PORTB bit 0,1,2,3,4,5,6,7
            STAA   PORTB        ; Clear all bits of PORTB, initialize

            ldaa   #$0C         ; Enable SCI port Tx and Rx units
            staa   SCICR2       ; disable SCI interrupts

            ldd    #$0001       ; Set SCI Baud Register = $0001 => 1.5M baud at 24MHz (for simulation)
;            ldd    #$0002       ; Set SCI Baud Re  gister = $0002 => 750K baud at 24MHz
;            ldd    #$000D       ; Set SCI Baud Register = $000D => 115200 baud at 24MHz
;            ldd    #$009C       ; Set SCI Baud Register = $009C => 9600 baud at 24MHz
            std    SCIBDH       ; SCI port baud rate change

            ldx     #msg1            ; print the first message, '1024 data transmit'
            jsr     printmsg
            jsr     nextline

;            ldx     #msg2            ; print the second message, user instruction,
;            jsr     printmsg         ;   hit 'Enter'
;            jsr     nextline
            
            
            bset   RTICTL,%00011001 ; set RTI: dev=10*(2**10)=2.555msec for C128 board
                                    ;      4MHz quartz oscillator clock
            bset   CRGINT,%10000000 ; enable RTI interrupt
            bset   CRGFLG,%10000000 ; clear RTI IF (Interrupt Flag)
            
            ldx    #0
            stx    ctr2p5m          ; initialize interrupt counter with 0.
            cli  
            
            
            
            ldx     #seconds
            stx     displayTimeAddr
            
            
            
newCmd      
            ldaa    #'>'
            jsr     putchar            
            ldaa    #' '
            jsr     putchar
            ldx     #BUF
            
            ldab    #0

mloop
            jsr     updateTime
            jsr     getchar
            cmpa    #0
            beq     mloop
            
            
            cmpb    #11
            bge     invalidInput
            addb    #1
            staa    1,X+
            
            
            jsr     putchar          ; type writer, with echo print
            cmpa    #CR
            bne     mloop           ; if Enter/Return key is pressed, move the
            
            
  
            ;ldaa    #LF              ; cursor to next line
            ;jsr     putchar
            ldaa    #$00
            staa    X
            
            
            jsr     parseCmd
            
            bra     newCmd

           ; ldx     #msg3            ; print '> Set Terminal save file RxData3.txt'
           ; jsr     printmsg
           ; jsr     nextline

          ;  ldx     #msg4            ; print '> Press Enter/Return key to start sawtooth wave'
          ;  jsr     printmsg
          ;  jsr     nextline

          ;  jsr     delay1ms         ; flush out SCI serial port 
                                     ; wait to finish sending last characters

invalidInput
            jsr     nextline
            ldx     #invalidInputErr
            jsr     printmsg
            jsr     nextline
            bra     newCmd

;subroutine section below


;***************generateWave**********************
;* Program: 
;* Input: 
;* Output: 
;* Registers modified: 
;* Algorithm:
;    
;**********************************************
generateWave
             pshd
             pshx

             ldx     #msg3
             jsr     printmsg
             jsr     nextline
             
             ldx     #msg4
             jsr     printmsg
             jsr     nextline

gwLoop
             jsr     updateTime
             jsr     getchar
             cmpa    #0
             beq     gwLoop
             cmpa    #CR
             bne     gwLoop           ; if Enter/Return key is pressed, move the

             jsr     nextline
             jsr     nextline
             jsr     delay1ms         ; flush out SCI serial port 
                                     ; wait to finish sending last characters

             ldx     #0               ; Enter/Return key hit
             stx     ctr125u
             jsr     StartTimer4oc

             CLI                      ; Interrupt enable, for Timer OC6 interrupt start


gwloop2048
             jsr     updateTime
             ldd     ctr125u
             cpd     #DATAmax         ; 1024 bytes will be sent, the receiver at Windows PC 
             bhs     gwloopTxON         ;   will only take 1024 bytes.
             bra     gwloop2048         ; set Terminal Cache Size to 10000 lines, update from 1000 lines

gwloopTxON
             LDAA    #%00000000
             STAA    TIE               ; disable OC6 interrupt

             ;jsr     nextline
             jsr     nextline
 
             ldx     #msg5            ; print '> Done!  Close Output file.'
             jsr     printmsg
             jsr     nextline

             ;ldx     #msg6            ; print '> Ready for next data transmission'
             ;jsr     printmsg
             ;jsr     nextline




             pulx
             puld 
             rts




;*******************end gwSub***************************

;***************gwSub**********************
;* Program: 
;* Input: 
;* Output: 
;* Registers modified: 
;* Algorithm:
;    
;**********************************************
gwSub
             ldd   #3000              ; 125usec with (24MHz/1 clock)
             addd  TC4H               ;    for next interrupt
             std   TC4H               ; 
             bset  TFLG1,%00010000    ; clear timer CH6 interrupt flag, not needed if fast clear enabled
             ldd   ctr125u
             ldx   ctr125u
             inx                      ; update OC6 (125usec) interrupt counter
             stx   ctr125u
             clra                     ;   print ctr125u, only the last byte 
             jsr   pnum10             ;   to make the file RxData3.txt with exactly 1024 data 
gwdone       RTI




;*******************end gwSub***************************


;***************gw2Sub**********************
;* Program: 
;* Input: 
;* Output: 
;* Registers modified: 
;* Algorithm:
;    
;**********************************************
gw2Sub
            ldd   #3000              ; 125usec with (24MHz/1 clock)
            addd  TC4H               ;    for next interrupt
            std   TC4H               ; 
            bset  TFLG1,%00010000    ; clear timer CH4 interrupt flag, not needed if fast clear enabled
            ldd   ctr125u
            ldx   ctr125u
            inx                          ; update OC4 (125usec) interrupt counter
            stx   ctr125u
            clra                     ;   print ctr125u, only the last byte
            andb  #%00111111 
            jsr   pnum10             ;   to make the file RxData3.txt with exactly 1024 data 
gw2done     RTI




;*******************end gw2Sub***************************




;***************gtSub**********************
;* Program: 
;* Input: 
;* Output: 
;* Registers modified: 
;* Algorithm:
;    
;**********************************************
gtSub
             ldd   #3000              ; 125usec with (24MHz/1 clock)
             addd  TC4H               ;    for next interrupt
             std   TC4H               ; 
             bset  TFLG1,%00010000    ; clear timer CH6 interrupt flag, not needed if fast clear enabled
             
             
             
             
              
                 
             ldab    triWaveDirection 
             bne    triSubtract
             
             ldd    triCtr        
             addd   #1
             std    triCtr
             bra    flip   
             
triSubtract  
             ldd    triCtr
             subd   #1
             std    triCtr                   


flip
             ldd    triCtr
             subd   #1
             cpd    #254
             blo    triend
             
             ldab   triWaveDirection
             comb
             stab   triWaveDirection
             
 


triend             
             ldx   ctr125u
             inx   
             stx   ctr125u
             
             ldd   triCtr
             jsr   pnum10
             rti




;*******************end gtSub***************************



;***************gqSub**********************
;* Program: 
;* Input: 
;* Output: 
;* Registers modified: 
;* Algorithm:
;    
;**********************************************
gqSub
             ldd   #3000              ; 125usec with (24MHz/1 clock)
             addd  TC4H               ;    for next interrupt
             std   TC4H               ; 
             bset  TFLG1,%00010000    ; clear timer CH6 interrupt flag, not needed if fast clear enabled
             
             ldx   ctr125u
             ldd   ctr125u  
             cmpb  #255
             bne   donegq
             ldab  sqWaveOut
             comb
             stab  sqWaveOut
             
donegq       
             inx
             stx    ctr125u
             ldab   sqWaveOut
             clra 
             jsr   pnum10
             rti




;*******************end gqSub***************************



;***************gq2Sub**********************
;* Program: 
;* Input: 
;* Output: 
;* Registers modified: 
;* Algorithm:
;    
;**********************************************
gq2Sub
             ldd   #3000              ; 125usec with (24MHz/1 clock)
             addd  TC4H               ;    for next interrupt
             std   TC4H               ; 
             bset  TFLG1,%00010000    ; clear timer CH6 interrupt flag, not needed if fast clear enabled
             
             ;ldx   ctr125u
             ldd   ctr125u
             andb  #%00111111  
             cmpb  #63
             bne   donegq2
             
             ldab  sqWaveOut
             comb
             stab  sqWaveOut
             
donegq2       
             ldx    ctr125u
             inx
             stx    ctr125u
             ldab   sqWaveOut
             clra 
             jsr   pnum10
             rti




;*******************end gq2Sub***************************





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

            ldx     #BUF
            ldaa    1,X+
            
            cmpa    #'s'                ; check for s
            bne     checkM              ; if not move to s
            ldaa    1,X+                ; load next char
            cmpa    #CR                 ; check for enter
            lbne    invalidCmd         ; print error if not
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
            lbne    checkg                ; if not move to q
            ldaa    1,X+                   ; load next char
            cmpa    #$20                   ; check for space
            lbne    invalidTime            ; if not print error
            ldaa    1,X+                   ; load next char
            
            
            ; validate hour number
            suba    #$30                   ; remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi    invalidTime            ; not not print error 
            staa    inputHour              ; store in temp hours variable
            
            ldaa    1,X+                   ; load next char 
            cmpa    #CN                    ; check if colon
            beq     minutesNumber          ; if so move to validate second number
            suba    #$30                   ; if not then remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi    invalidTime            ; if not print error
            
            psha                           ; save a
            ldab    #10                    
            ldaa    inputHour              ; load temp variable to a
            MUL                            ; multiply a by 10
            pula                           ; restore value in a before multiplication
            aba                            ; add a to result of multiplication
            cmpa    #24                    ; check if over 24
            lbge    invalidTime             ; if >= print error
            staa    inputHour              ; otherwise store value
            
            ; first colon
            ldaa    1,X+                   ; load next character
            cmpa    #CN                    ; check for colon
            lbne    invalidTime            ; if not print error
            
            
            ; minutes number
minutesNumber
            ldaa    1,X+                   ;load next character
            suba    #$30                   ; remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi    invalidTime             ; if so print error
            staa    inputMinute            ; store in temp variable
            
            ldaa    1,X+                   ; load next character
            suba    #$30                   ; remove ascii offset
            cmpa    #9                     ; check if below 10
            lbhi    invalidTime            ; if not print error
            
            psha
            ldab    #10                    ; multiply value in a by 10 then add a and store in temp
            ldaa    inputMinute
            MUL     
            pula
            aba
            cmpa    #60                    ; check if new minutes less than 60
            lbge     invalidTime             ; if not print error
            staa    inputMinute            ; store in temp minutes
            
            ;second colong
            ldaa    1,X+
            cmpa    #CN                    ;check for colon
            lbne     invalidTime
            
            ; seconds number
            ldaa    1,X+                   ; do same thing as for minutes number
            suba    #$30
            cmpa    #9
            lbhi    invalidTime
            staa    inputSecond
            
            ldaa    1,X+
            suba    #$30
            cmpa    #9
            lbhi    invalidTime
            
            psha
            ldab    #10
            ldaa    inputSecond
            MUL     
            pula
            aba
            cmpa    #60
            lbge    invalidTime
            staa    inputSecond
            
            
            ;store temp values once validated
            ldaa    inputHour               ;store new hours
            staa    hours
            ldaa    inputMinute             ; store new minutes
            staa    minutes
            ldaa    inputSecond             ;store new seconds
            staa    seconds
            
            lbra    endParse                ; skip to end of subroutine


checkg
            cmpa    #'g'
            bne     checkQ
            ldaa    1,X+
            cmpa    #'w'
            bne     checkgt
            
            ldaa    1,X+
            cmpa    #CR
            bne     checkgw2
            
            ldx     #gwSub
            stx     $FFE6
            jsr     generateWave
            bra     endParse    
            
            
checkgw2    
            cmpa    #'2'
            bne     invalidCmd
            ldx     #gw2Sub
            stx     $FFE6
            jsr     generateWave
            bra     endParse
            
checkgt     
            cmpa    #'t'
            bne     checkgq
            ldaa    1,X+
            cmpa    #CR
            bne     invalidCmd
            ldx     #gtSub
            stx     $FFE6
            jsr     generateWave
            bra     endParse
            
checkgq     
            cmpa    #'q'
            bne     invalidCmd
            
            ldaa    1,X+
            cmpa    #CR
            bne     checkgq2
            ldx     #gqSub
            stx     $FFE6
            jsr     generateWave
            bra     endParse    
            
            
checkgq2    
            cmpa    #'2'
            bne     invalidCmd
            ldx     #gq2Sub
            stx     $FFE6
            jsr     generateWave
            bra     endParse    
                  
            
checkQ
            cmpa    #'q'                     ; check for q
            bne     invalidCmd              ; if not no other commands left so print error
            ldaa    1,X+
            cmpa    #CR                     ; check next char for enter 
            bne     invalidCmd              ; if not print error     
            jsr     typeWriter          ; if so run type writer program for lifetime of program
            
            
endParse            
            
            ldaa    #'>'
            jsr     putchar
            ldaa    #' '
            jsr     putchar
            jsr     nextline
            puld                              ;clear carry indicating success
            pulx                              ; restore registers
            rts                               ; return from subroutine
            
            
invalidCmd  
            
            ldx     #invalidCmdErr 
            jsr     printmsg
            jsr     nextline
                                             ; set carry indictaing invalid input
            puld                              ; restore registers
            pulx                              ; return from subroutine
            rts
invalidTime
            ldx     #timeFormatErr
            jsr     printmsg
            jsr     nextline
            puld
            pulx
            rts
            
;***************end of parseCmd***************


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
            cpx     #200             ; 2.5msec * 200 = 0.5 sec
            ;cpx      #400              ; 2.5msec * 400 = 1 sec
            lblo     doneUpdate          ; NOT yet
            
            ldx      #0                  ; reset the interupt counter
            stx      ctr2p5m
                    
                   
            ldx      displayTimeAddr     ; load address to value to be displayed on lcd
            ldab     X                   ; load value from address to be displayed on lcd
            
            clra
            LDX     #10
            IDIV                         ;D/X = X R->D   seperates two decimal digits
            PSHD                         ; stores d on the stack
            TFR     X,D                  ; moves larger decimal digit to D
            
            LSLD    
            LSLD                         ;shift larger digit into upper four bits of B register
            LSLD
            LSLD
            
            ADDD    SP                   ; adds smaller decimal digit to D
                                         ; now upper 4 bits of b is the larger decimal number and the lower 4 bits are the smaller decimal digit
            stab    PORTB                ; send data to port b to be displayed
            puld       
            
           
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

;***********typeWriter***************************
;* Program: runs type writer once menu selection quits. gets char input and displays in on 7 segment display
;* Input: ascii characters from serial port  
;* Output: sends char to PORTB
;* 
;* Registers modified: A register
;* Algorithm: continually checks for input availible. when input is availible it is stored in a then send to PORTB and displayed on terminal
;     
;**********************************************
typeWriter      
                jsr   nextline
                ;ldx   #space
                ;jsr   printmsg
                ldx   #typeWriterMsg
                jsr   printmsg
                jsr   nextline

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


;***********Timer OC4 interrupt service routine***************
oc4isr
            ldd   #3000              ; 125usec with (24MHz/1 clock)
            addd  TC4H               ;    for next interrupt
            std   TC4H               ; 
            bset  TFLG1,%00010000    ; clear timer CH6 interrupt flag, not needed if fast clear enabled
            ldd   ctr125u
            ldx   ctr125u
            inx                      ; update OC6 (125usec) interrupt counter
            stx   ctr125u
            clra                     ;   print ctr125u, only the last byte 
            jsr   pnum10             ;   to make the file RxData3.txt with exactly 1024 data 
oc4done     RTI
;***********end of Timer OC4 interrupt service routine********

;***************StartTimer4oc************************
;* Program: Start the timer interrupt, timer channel 4 output compare
;* Input:   Constants - channel 4 output compare, 125usec at 24MHz
;* Output:  None, only the timer interrupt
;* Registers modified: D used and CCR modified
;* Algorithm:
;             initialize TIOS, TIE, TSCR1, TSCR2, TC2H, and TFLG1
;**********************************************
StartTimer4oc
            PSHD
            LDAA   #%00010000
            STAA   TIOS              ; set CH4 Output Compare
            STAA   TIE               ; set CH4 interrupt Enable
            LDAA   #%10000000        ; enable timer, Fast Flag Clear not set
            STAA   TSCR1
            LDAA   #%00000000        ; TOI Off, TCRE Off, TCLK = BCLK/1
            STAA   TSCR2             ;   not needed if started from reset

            LDD    #3000            ; 125usec with (24MHz/1 clock)
            ADDD   TCNTH            ;    for first interrupt
            STD    TC4H             ; 

            BSET   TFLG1,%00010000   ; initial Timer CH4 interrupt flag Clear, not needed if fast clear set
            LDAA   #%00010000
            STAA   TIE               ; set CH4 interrupt Enable
            PULD
            RTS
;***************end of StartTimer4oc*****************


;***********pnum10***************************
;* Program: print a word (16bit) in decimal to SCI port
;* Input:   Register D contains a 16 bit number to print in decimal number
;* Output:  decimal number printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Keep divide number by 10 and keep the remainders
;     Then send it out to SCI port
;  Need memory location for counter CTR and buffer BUF(6 byte max)
;**********************************************
pnum10          pshd                   ;Save registers
                pshx
                pshy
                clr     CTR            ; clear character count of an 8 bit number

                ldy     #BUF
pnum10p1        ldx     #10
                idiv
                beq     pnum10p2
                stab    1,y+
                inc     CTR
                tfr     x,d
                bra     pnum10p1

pnum10p2        stab    1,y+
                inc     CTR                        
;--------------------------------------

pnum10p3        ldaa    #$30                
                adda    1,-y
                jsr     putchar
                dec     CTR
                bne     pnum10p3
                jsr     nextline
                puly
                pulx
                puld
                rts
;***********end of pnum10********************

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
nextline
            psha
            ldaa  #CR              ; move the cursor to beginning of the line
            jsr   putchar          ;   Cariage Return/Enter key
            ldaa  #LF              ; move the cursor to next line, Line Feed
            jsr   putchar
            pula
            rts
;****************end of nextline***************

;****************delay1ms**********************
delay1ms:   pshx
            ldx   #$1000           ; count down X, $8FFF may be more than 10ms 
d1msloop    nop                    ;   X <= X - 1
            dex                    ; simple loop
            bne   d1msloop
            pulx
            rts
;****************end of delay1ms***************

;***********RTI interrupt service routine***************
rtiisr      bset   CRGFLG,%10000000 ; clear RTI Interrupt Flag - for the next one
            cli
            ldx    ctr2p5m          ; every time the RTI occur, increase
            inx                     ;    the 16bit interrupt count
            stx    ctr2p5m
rtidone     RTI
;***********end of RTI interrupt service routine********

msg1        DC.B   'Hello, you may used the following commands',CR,'t - sets the time',CR,'s - display seconds on clock',CR,'m - display minutes on clock',CR,'h - display hours on clock',CR,'q - quit program and strat typeWriter program',CR,'gw - generate sawtooth wave',CR,'gw2 - generate sawtooth wave at 125Hz',CR,'t - sets the time',CR,'gt - geneerate triangle wave',CR,'gq - generate square wave',CR,'gq2 - generate square wave at 125Hz', $00

space       DC.B   '       ',$00
gwmsg       DC.B   'sawtooth wave generation ....',$00
gw2msg      DC.B   'sawtooth wave 125Hz generation ....',$00
gtmsg       DC.B   'triangle wave generation ....',$00
gqmsg       DC.B   'square wave generation ....',$00
gq2msg      DC.B   'square wave 125Hz generation ....',$00


typeWriterMsg     DC.B     '      Wave Generator and Clock stopped and Typewrite program started.',CR,LF,'       You may type below.',CR,LF,$00
invalidInputErr   DC.B     '      Error> Invalid input format',$00
invalidCmdErr     DC.B     '      Error> Invalid command.',$00
timeFormatErr     DC.B     '      Error> Invalid time format. Correct example => 00:00:00 to 23:59:59',$00



msg3        DC.B   '> Be sure to start saving Terminal data: open Output file = RxData3.txt', $00
msg4        DC.B   '> When ready, hit Enter/Return key for sawtooth wave, 2048 point print.', $00
msg5        DC.B   '> Done!  You may close the Output file.', $00
msg6        DC.B   '> Ready for next data transmission, hit Enter key.', $00

            END                    ; this is end of assembly source file
                                   ; lines below are ignored - not assembled
