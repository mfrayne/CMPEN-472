***********************************************************************
*
* Title:          SCI Serial Port and 7-segment Display at PORTB
*
* Objective:      CMPEN 472 Homework 5
*
* Revision:       V3.2  for CodeWarrior 5.2 Debugger Simulation
*
* Date:	          Feb 20, 2026
*
* Programmer:     Michael Frayne
*
* Company:        The Pennsylvania State University
*                 Department of Computer Science and Engineering
*
* Program:        Simple SCI Serial Port I/O and Demonstration
*                 Typewriter program and 7-Segment display, at PORTB
*                 
*
* Algorithm:      Simple Serial I/O use, typewriter
*
* Register use:	  A: Serial port data
*                 X,Y: Delay loop counters
*
* Memory use:     RAM Locations from $3000 for data, 
*                 RAM Locations from $3100 for program
*
* Output:         
*                 PORTB bit 7 to bit 4, 7-segment MSB
*                 PORTB bit 3 to bit 0, 7-segment LSB
*
* Observation:    This is a typewriter program that displays ASCII
*                 data on PORTB - 7-segment displays.
*
***********************************************************************
* Parameter Declearation Section
*
* Export Symbols
            XDEF        pstart       ; export 'pstart' symbol
            ABSENTRY    pstart       ; for assembly entry point
  
* Symbols and Macros
PORTB       EQU         $0001        ; i/o port B addresses
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

***********************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory
*
                  ORG         $3000        ; Reserved RAM memory starting address 
                                           ;   for Data for CMPEN 472 class
DelayCounter1    DC.W        $002E         ; X register count number for time delay
                                      ;   inner loop for msec
                                      ;   outer loop for sec
DimmingCounter   DC.W        $0088      ;   counter used for timing of dimming and brightening

offCounter  DC.B        100             ; stores the percent of the time that the LED should be off

onCounter   DC.B        0           ; stores the percent of the time that the LED shoulld be on
                                      ; offCounter and onCounter should add up to 100
                                      ; initial values don't matter as long as they are greater than one
                                      ; only one blink cycle with inital values then counters change


msg1        DC.B        'Hello', $00               ;stores ascii characters for first line of welcome message
msg2        DC.B        'You may type below', $00  ;stores ascii characters for second line of welcome message
                                                   
inputBuffer DS.B        5                          ; reserves space for input buffer
                                                   ; longest input instruction is QUIT so one byte needed for each char
                                                   ; and extra byte for enter character


; Each message ends with $00 (NULL ASCII character) for your program.
;
; There are 256 bytes from $3000 to $3100.  If you need more bytes for
; your messages, you can put more messages 'msg3' and 'msg4' at the end of 
; the program - before the last "END" line.
                                     ; Remaining data memory space for stack,
                                     ;   up to program memory start

*
***********************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory
*
                ORG        $3100        ; Program start address, in RAM
pstart          LDS        #$3100       ; initialize the stack pointer

                LDAA       #%11111111   ; Set PORTB bit 0,1,2,3,4,5,6,7
                STAA       DDRB         ; as output

                LDAA       #%00000000
                STAA       PORTB        ; clear all bits of PORTB

                ldaa       #$0C         ; Enable SCI port Tx and Rx units
                staa       SCICR2       ; disable SCI interrupts

                ldd        #$0001       ; Set SCI Baud Register = $0001 => 1.5M baud at 24MHz (for simulation)
;                 ldd        #$0002       ; Set SCI Baud Register = $0002 => 750K baud at 24MHz
;                 ldd        #$000D       ; Set SCI Baud Register = $000D => 115200 baud at 24MHz
;                 ldd        #$009C       ; Set SCI Baud Register = $009C => 9600 baud at 24MHz
                std        SCIBDH       ; SCI port baud rate change

                ldx   #msg1              ; print the first message, 'Hello'
                jsr   printlnmsg

                ldx   #msg2              ; print the second message
                jsr   printlnmsg

            
                                    
                ldx   #L1              ; print L1 menu message
                jsr   printlnmsg
            
                ldx   #F1              ; print F1 menu message
                jsr   printlnmsg
            
            
                ldx   #L2              ; print L2 menu message
                jsr   printlnmsg
            
            
                ldx   #F2              ; print F2 menu message
                jsr   printlnmsg

            
                ldx   #L3              ; print L3 menu message
                jsr   printlnmsg

            
                ldx   #F3              ; print F3 menu message
                jsr   printlnmsg
            
                ldx   #L4              ; print L4 menu message
                jsr   printlnmsg

            
                ldx   #F4                 ;print F4 menu message
                jsr   printlnmsg
            
                ldx   #QUIT               ;print QUIT menu message
                jsr   printlnmsg
            
                ldx   #msg3
                jsr   printlnmsg          ;print enter command propmt msg


startMenu
                ldab    #0                   ; resets inputbuffer counter
menuLoop    
                cmpb    #5                   ; check if char input counter above buffer limit (>5 bytes)
                beq     invalidInput         ; branch to invalid input if too many characters entered 
            
inputLoop       jsr     getchar              ; check for input and store in a if recieved any
                cmpa    #$00                 ;  if nothing typed, keep checking
                beq     inputLoop
            
                jsr     putchar              ; displays any text entered back to the terminal
            
            
            
                ldx     #inputBuffer         ; stores the address where the input buffer start
                abx                          ; adds b to inputBuffer address to put the entered character in the next position
                staa    X                    ; store a in inputbuffer at correct position
                incb                         ; increase b to move address to next position in buffer

                cmpa    #CR
                bne     menuLoop             ; if Enter/Return key is pressed stop looking for input and begin to process buffer
            
               ; ldaa    #$00                 ; adds null terminator to
                ;ldx     #inputBuffer
               ; abx   
               ; staa    X                    ; store a in input buffer with offset of x+
            
            
                jsr     parseInputBuffer    ; run subroutine to process the buffer and call correct subroutine based on input
                bra     startMenu           ; returns to start of menu to wait for another input
            

invalidInput
                ldaa   #CR                ; moves cursor to begining of line
                jsr    putchar            ; 
                ldaa   #LF                ; prints newline to terminal
                jsr    putchar
                ldx    #msg4
                jsr    printlnmsg         ; prints message 4(error message)
                bra    startMenu          ; returns to begining of menu





;subroutine section below
NULL        equ       $00



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


;***********parseInputBuffer***************************
;* Program: controls flow of program once input is enterd. Calls correct subroutine based on input
;* Input: buffer at address #inputBuffer  
;* Output: calls subroutine or displays invalid input message then returns to main program 
;* 
;* Registers modified: accumulator a stores one ascii of buffer at a time to be checked
;*                      register x stores the address of the character in buffer currently being evaluated 
;* Algorithm:   load the first value of buffer into a
;                if a matches 'L'
;                      load next value in buffer into a
;                      if a matches '1'
;                           call L1Sub
;                      if a matches '2'
;                           call L2Sub
;                       if a matches '3'
;                           call L3Sub
;                       if a matches '4'
;                           call L4Sub
;
;                 else if a matches F
;                      load next value in buffer into a
;                      if a matches '1'
;                           call L1Sub
;                      if a matches '2'
;                           call L2Sub
;                       if a matches '3'
;                           call L3Sub
;                       if a matches '4'
;                           call L4Sub     
;
;                 else if a matches 'Q'
;                      load next value in buffer into a
;                      if a matches 'U'
;                           load next value in buffer into a
;                           if a matches 'I'
;                             load next value in buffer into a
;                             if a matches 'T'
;                                 call quitSub
;                         if non match then print invalid message
;
;                 else
;                      print invalid message
;                 clean up and exit subroutine      
;     
;**********************************************

parseInputBuffer        psha                  ; save registers used in subroutine
                        pshx   
                        
                        ldx     #inputBuffer     ;load first byte of buffer into a
                        ldaa    0,X
                        
                        cmpa    #'L'             ; check if a is 'L'
                        bne     cmpF             ; branch to check for F if not L
                        ldaa    1,X              ; load next char of buffer to a if a is 'L'
                                                                       
                        cmpa    #'1'             ; check if a is '1'
                        bne     l2               ; branch if not '1'
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D              ; checks if it's a new line char
                        lbne     invalid          ; prints invalid message if no newline after L1
                        jsr     L1Sub            ; call L1Sub if buffer holds 'L1'exactly
                        lbra     endParse
                                                
l2                      cmpa    #'2'             ; check if a is '2'
                        bne     l3               ; branch if not '2'
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D              ; check if a is new line
                        lbne     invalid          ; prints invalid message if no newline after L2
                        jsr     L2Sub            ; call L3Sub if buffer holds 'L2'exactly
                        lbra     endParse
                        
l3                      cmpa    #'3'             ; check if a is '3'
                        bne     l4               ; branch if not '3'
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D              ; check if a is new line
                        lbne     invalid          ; prints invalid message if no newline after L3
                        jsr     L3Sub            ; call L3Sub if buffer holds 'L3'exactly
                        lbra     endParse
                        
l4                      cmpa    #'4'             ; check if a is '3'
                        lbne     invalid          ; prints invliad message if buffer is L then anything beside 1,2,3, or 4
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D             ; check if a is new line
                        bne     invalid          ; prints invalid message if no newline after L4
                        jsr     L4Sub            ; call L4Sub if buffer holds 'L4'exactly 
                        lbra     endParse       
                                                  ; end of L parse
                                                                        
cmpF                        
                        cmpa    #'F'             ; check if a is 'L'
                        bne     cmpQ             ; branch to check for Q if not L
                        ldaa    1,X              ; load next char of buffer into a
                        
                        
                        cmpa    #'1'             ; check if a is '1'
                        bne     f2               ; branch if a not '1'
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D             ; check fi a is new line
                        lbne     invalid          ; prints invalid message if no newline after F1
                        jsr     F1Sub             ; call F1Sub if buffer holds 'F1' exactly
                        bra     endParse 
                                                
f2                      cmpa    #'2'             ; check if a is '2'
                        bne     f3               ; branch if a not '2'
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D              ; check if a is new line
                        lbne     invalid          ; prints invalid message if no newline after F2
                        jsr     F2Sub             ; call F1Sub if buffer holds 'F1' exactly
                        bra     endParse

f3                      cmpa    #'3'              ; check if a is '3'
                        bne     f4                ; branch if a not '3'
                        ldaa    2,X               ; load next char of buffer into a
                        
                        cmpa    #$0D              ; check if newline 
                        lbne     invalid          ; prints invalid message if no newline after F3
                        jsr     F3Sub             ; call F3Sub if buffer holds 'F3' exactly
                        bra     endParse

f4                      cmpa    #'4'              ; check if a is '4'
                        bne     invalid           ; prints invliad message if buffer is F then anything beside 1,2,3, or 4
                        ldaa    2,X              ; load next char of buffer into a
                        
                        cmpa    #$0D              ; check if newlinw
                        lbne     invalid          ; prints invalid message if no newline after F4
                        jsr     F4Sub             ; call F4Sub if buffer holds 'F4' exactly
                        bra     endParse       ; end of F parse
                        
                        
                        
cmpQ                        
                        cmpa    #'Q'              ; check if first char is 'Q'
                        bne     invalid           ; 
                        ldaa    1,X               ; load second char of buffer into a
                        cmpa    #'U'              ; check if second char is 'U'
                        bne     invalid           ; if not print invalid message
                        ldaa    2,X               ; load third char of buffer into a
                        cmpa    #'I'              ; check if third char is 'I'
                        bne     invalid           ; print invalid message
                        ldaa    3,X               ; load fourth char of buffer into a
                        cmpa    #'T'              ; check if fourth char is 'T'
                        bne     invalid           ; if not prints invalid message
                        jsr     quitSub           ; if the chars in buffer are QUIT then quitSub is run
                        bra     endParse
                                                
                        
invalid                 ldaa   #CR                ; move the cursor to beginning of the line
                        jsr    putchar            ;   Cariage Return/Enter key
                        ldaa   #LF                ; move the cursor to next line, Line Feed
                        jsr    putchar            ; print msg4 which tells the user their input is invalid
                        ldx    #msg4
                        jsr    printlnmsg       
                        
endParse                pula
                        pulx                      ;resotre registers
                        rts

;***********L1Sub***************************
;* Program: brightens led from 0% to 100% over .3 seconds
;* Input:  DimmingCounter, onCounter, offCounter 
;* Output: changes the brightness of LED1
;* 
;* Registers modified: x
;* Algorithm:
;             prints message so user knows what process is run based on their input
;             turn LED on for onCounter cycles
;             turns LED off for offCounter cycles
;             loops keeping onCounter and offCounter the same for DimmingCounter loops
;             increments onCounter 
;             decrements offCounters
;             loops subroutine until offCounter reaches 0
;     
;**********************************************

L1Sub
                        pshx
                        ldx   #L1              ; print L2 menu message
                        jsr   printlnmsg
                        ;brighten LED1 over .3 seconds
increaseLoop                              ; increases light level from 0% to 100%
            LDX         DimmingCounter    ; load counter into x for how many times the brightness stays the same to change 
brightenLoop                              ; keeps the same brightness for .003 seconds
            
            JSR         blinkLight        ; blinks light based on vlaues in onCounter and offCounter to dim the light
            DEX
            BNE         brightenLoop      ; holds each brightness for a number of times so brightening happens in 0.3 seconds
            
            INC         onCounter         ; increase onCounter by 1
            DEC         offCounter        ; decrease offCounter by 1
            BNE         increaseLoop      ; when offCounter reaches 0 the loop ends

                        pulx
                        rts

;***********parseInputBuffer***************************
;* Program: changes bit on PORTB to turn LED2 on
;* Input:  PORTB 
;* Output: LED 2 turns on
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               set bit 5 of port b
;
;**********************************************
L2Sub
                        pshx
                        ldx   #L2              ; print L2 menu message
                        jsr   printlnmsg
                        bset  PORTB,#%00100000
                        pulx
                        rts
                        
                        
;***********L3Sub***************************
;* Program: changes bit on PORTB to turn LED3 on
;* Input:  PORTB 
;* Output: LED 3 turns on
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               set bit 6 of port b
;     
;**********************************************
L3Sub
                        pshx
                        ldx   #L3              ; print L2 menu message
                        jsr   printlnmsg
                        bset  PORTB,#%01000000
                        pulx
                        rts
         
                        
;***********L4Sub***************************
;* Program: changes bit on PORTB to turn LED4 on
;* Input:  PORTB 
;* Output: LED 4 turns on
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               set bit 7 of port b
;     
;**********************************************                        
L4Sub
                        pshx
                        ldx   #L4              ; print L2 menu message
                        jsr   printlnmsg
                        bset  PORTB,#%10000000
                        pulx
                        rts


;***********F1Sub***************************
;* Program: brightens led from 100% to 0% over .3 seconds
;* Input:  DimmingCounter, onCounter, offCounter 
;* Output: changes the brightness of LED1
;* 
;* Registers modified: x 
;* Algorithm:
;             turn LED on for onCounter cycles
;             turns LED off for offCounter cycles
;             loops keeping onCounter and offCounter the same for DimmingCounter loops
;             increments onCounter 
;             decrements offCounters
;             loops subroutine until onCounter reaches 0
;
;**********************************************

F1Sub
                        ldx   #F1              ; print L2 menu message
                        jsr   printlnmsg
                        ;dim LED1 over .3 seconds
decreaseLOOP                              ; decreases light level from 100% to 0%
            LDX         DimmingCounter
dimmingLoop
            JSR         blinkLight        ; blinks light based on vlaues in onCounter and offCounter to dim the light
            DEX
            BNE         dimmingLoop       ; holds each brightness for a number of times so dimming happens in 0.3 seconds
            
            INC         offCounter        ; increase offCounter by 1
            DEC         onCounter         ; decrease onCounter by 1
            BNE         decreaseLOOP      ; when onCounter reaches 0 the loop ends 
            
                        rts


;***********F2Sub***************************
;* Program: changes bit on PORTB to turn LED2 off
;* Input:  PORTB 
;* Output: LED 2 turns off
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               clear bit 5 of port b
;     
;**********************************************
F2Sub
                        pshx
                        ldx   #F2              ; print L2 menu message
                        jsr   printlnmsg
                        bclr PORTB,#%00100000
                        pulx
                        rts

;***********F3Sub***************************
;* Program: changes bit on PORTB to turn LED3 off
;* Input:  PORTB 
;* Output: LED 3 turns off
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               clear bit 6 of port b
;     
;**********************************************
F3Sub
                        pshx
                        ldx   #F3              ; print L2 menu message
                        jsr   printlnmsg
                        bclr PORTB,#%01000000
                        pulx
                        rts


;***********F4Sub***************************
;* Program: changes bit on PORTB to turn LED4 off
;* Input:  PORTB 
;* Output: LED 4 turns off
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               clear bit 7 of port b
;     
;**********************************************
F4Sub
                        pshx
                        ldx   #F4              ; print L2 menu message
                        jsr   printlnmsg
                        bclr PORTB,#%10000000
                        pulx
                        rts
                        

;***********quiteSub***************************
;* Program: exits main program and calls typeWriterLoop subroutine where program remains for the duriation
;* Input:  no input 
;* Output:  no output
;* 
;* Registers modified: x
;* Algorithm:   prints message so user knows what process is run based on their input 
;               calls typeWriter subroutine
;     
;**********************************************
quitSub
                        pshx
                        ldx   #QUIT              ; print L2 menu message
                        jsr   printlnmsg
                        jsr   typeWriterLoop
                        pulx
                        rts

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
printmsg       psha                   ;Save registers
               pshx
printmsgloop   ldaa    1,X+           ;pick up an ASCII character from string
                                       ;   pointed by X register
                                       ;then update the X register to point to
                                       ;   the next byte
               cmpa    #NULL
               beq     printmsgdone   ;end of strint yet?
               jsr     putchar        ;if not, print character and do next
               bra     printmsgloop              

printmsgdone   
               
               pulx 
               pula
               rts
;***********end of printmsg********************

;***********printlnmsg***************************
;* Program: Output character string to SCI port, print message
;* Input:   Register X points to ASCII characters in memory
;* Output:  
;* 
;* Registers modified: A 
;* Algorithm:
;     calls printmsg
;     print newline character
;**********************************************
printlnmsg     psha
               jsr    printmsg       
               ldaa   #CR                ; move the cursor to beginning of the line
               jsr    putchar            ;   Cariage Return/Enter key
               ldaa   #LF                ; move the cursor to next line, Line Feed
               jsr    putchar
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
putchar        brclr SCISR1,#%10000000,putchar   ; wait for transmit buffer empty
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
getchar        brclr SCISR1,#%00100000,getchar7
               ldaa  SCIDRL
               rts
getchar7       clra
               rts
;****************end of getchar**************** 



;****************************************************************************************
; delay10usec subroutine   
;
; This subroutine causes 10 micro second delay
;
; Input: a 16bit count number in 'Counter1'
; Output: time delay, cpu cycle waisted
; Registers in use: X register, as counter
; Memory locations in use: a 16 bit input number at 'Counter1'
;
; Comments: one can add more NOP instruction to lengthen
;           the delay time.

delay10usec                                 ; delay 10 microseconds         
              PSHX                          ; save X                        ; 2 cycles
              LDX     DelayCounter1         ; short delay                   ; 3 cycles
            
                                                                            ; 3*16  
dlyLoop       NOP                           ; total time delay = X * NOP    ; 1 cycle
              DEX                                                           ; 1 cycle
              BNE     dlyLoop                                               ; 3 cycle when branch and 1 cycle when fall through
            
              PULX                          ; restore X                     ; 3 cycle
              RTS                                                           ; 5 cycle
              
                                                                            ; 241 cycles for delay subroutine
;****************delay10usec**************** 

;****************************************************************************************
; blinkLight subroutine   
;
; This subroutine turns LED4 on then off for 10usec * the value in onCount and offCount
; This causes the light to appear to dim based on the ratio of the time the light is off vs on
;
; Input: a 16bit count numbers in 'onCounter' and 'offCounter'
; Output: dimming of LED brightness by blinking the LED and chaning the ratio of time it's on and time it's off
; Registers in use: Y register, as counter
; Memory locations in use: a 16 bit input numbers at 'onCounter' and 'offCounter'
;
; Comments: one can add more NOP instruction to lengthen
;           the delay time.

blinkLight
            PSHY                            ; save Y                                             ; 2 cycles
            LDY     onCounter               ; put number of loops to run for LED on into Y       ; 3 cycles
            BSET    PORTB,#%00010000        ; Turns LED1 on                                      ; 4 cycles
            
                                                                                                 ; start of loop
onLoop      JSR     delay10usec             ; waits 10 microseconds                              ; 4 cycles then 241 cycles for delay
            DEY                             ; recudes count in Y register                        ; 1 cycle
            BLE     onLoop                  ; Loops until Y is 0                                 ; 3 cycles on branch and 1 on fall through
                                                                                                 ; end of loop 
                                                                                                 
            LDY     offCounter              ; puts number of loops to run for LED off Y          ; 3 cycles
            BCLR    PORTB,#%00010000        ; turns LED4 off                                     ; 4 cycles
            
                                                                                                 ; start of loop
offLoop     JSR     delay10usec             ; delays for 10 micro seconds every loop             ; 4 cycles then for delay 241 cycles
            DEY                             ; reduces count in X register                        ; 1 cycles
            BLE     offLoop                   ; Loops until Y is 0                               ; 3 cycles on branch and 1 on fall through
                                                                                                 ; end of loop
            
            PULY                            ; returns value that was in Y before subroutine      ; 3 cycles
            RTS                             ; returns to main loop                               ; 5 cycles
                                                                                                 ; 24 constant
                                                                                                 ; 24896 cycles











;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip

msg3           DC.B        'Enter your command below:', $00
msg4           DC.B        'Error: Invalid command', $00

L1             DC.B        'L1: LED1 goes from 0% light level to 100% lightlevel in 0.3 seconds', $00
F1             DC.B        'F1: LED1 goes from 100% light level to 100% lightlevel in 0.3 seconds', $00
L2             DC.B        'L2: Turn on LED2', $00
F2             DC.B        'F2: Turn off LED2', $00
L3             DC.B        'L3: Turn on LED3', $00
F3             DC.B        'F3: Turn off LED3', $00
L4             DC.B        'L4: Turn on LED4', $00
F4             DC.B        'F4: Turn off LED4', $00
QUIT           DC.B        "QUIT: Quit menu program, run 'Type writer' program", $00


BufferMsg      DC.B        'test buffer', $00


               END               ; this is end of assembly source file
                                 ; lines below are ignored - not assembled/compiled
