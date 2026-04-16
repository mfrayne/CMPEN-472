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


firstNumber           DS.W       1             ; stores the value of the first number typed
operationAddress      DS.W       1             ; stores address of the subroutine to run depending on the operation
secondNumber          DS.W       1             ; stores the value of the second number typed
result                DS.W       1             ; stores result of operation
decimalValue          DS.W       1             ; stores the decimal value for an ascii to decimal conversion
digitValue            DS.B       1             ; stores the digit value for conversions
asciiResult           DS.B       5             ; stores each decimal digit of result as ascii


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

            ldx    #errSpace
            stx    errAddress

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
            
            psha
            ldaa   #$20
            cmpa   calculationOut
            pula
            bne    looop
            
            staa   1,X+             ; stores cmd typed in in input buffer
            ;put letter in cmd content and figure out if I need to 
            
            cmpb   #13
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
            ldab     X                   ; load value from address to be displayed on lcd
            
            
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
            PULD
    
                        
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
            
            ldx      #cmdMsg
            jsr      printmsg
            
            ldx      #errorMsg           ; prints error message
            jsr      printmsg
            
            ldx      errAddress
            jsr      printmsg
            
            jsr      nextline            ; prints new line
            
            ldaa     #$00                ; checks if error is there is no error
            cmpa     isError
            beq      checkCalcEmpty        ; if no error skip clearing command buffer and update time


            staa    isError            ; resets error message so error is not printed
            
            ldx     #space
            stx     errAddress
            ldx     #cmdContent
            


clrCmdLoop              
            ldaa     #$20                  ; loop through each space in the cmd buffer nad replace each char with a space
            staa     1,X+ 
            
            cpx      #endCmdContent
            bne      clrCmdLoop



checkCalcEmpty   
            ldaa     #$20
            cmpa     calculationOut
            beq      increaseTime    


            ldx      #calculationOut

clrCalcOutLoop
            ldaa     #$20                  ; loop through each space in the cmd buffer nad replace each char with a space
            staa     1,X+ 
            
            cpx      #endCalcOut
            bne      clrCalcOutLoop


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


;***********parseCalculation***************************
;* Program: controls flow of program once input is enterd. Calls correct subroutine based on input
;* Input: buffer at address #inputBuffer  
;* Output: calls subroutine or displays invalid input message then returns to main program 
;* 
;* Registers modified: a - current ascii value being evaluated, x - pointer to current place in buffer
;* Algorithm:        check ascii in buffer until 4 chars are checked or a non decimal digit is reached
;                           if decimal digit add digit to first number value
;                           
;                    check value after first decimal number
;                           if '+' store addition subroutine address in operationAddress to be called if second number is valid
;                           if '-' store subraction subroutine address in operationAddress to be called if second number is valid
;                           if '*' store multiplication subroutine address in operationAddress to be called if second number is valid
;                           if '/' store division subroutine address in operationAddress to be called if second number is valid
;                           if anything else throw error as either first number too long or invalid character
;                    check ascii in buffer until 4 chars are checked or a non decimal digit is reached
;                           if decimal digit, add digit to first number value
;                    check value after second decimal number
;                           if CR then calculate and print result
;                           if anything else then number is too long or invalid character so error thrown 
;**********************************************

parseCalculation        
                        pshy
                        psha                  ; save registers used in subroutine
                        pshx   
                        
                        ;ldx     #OutputLineBegin   ; print indentation for output
                        ;jsr     printmsg
                        
                        
                        ldx     #cmdContent     ;load first byte of buffer into a
                        ldaa    1,X+
                        
                        
                        
                        ; verify decimal value - each value must be ascii 0-9 and 1 to 4 digits long
                        ldy     #0
                        sty     firstNumber     ;clears whatever value was in firstNumber before
                        ldab    #0              ;initalizes a counter to 0
                        
verifyDecimalLoop1      ;jsr     putchar         ;echos each char as they are checked
                        suba    #48             ;eliminate ascii bias for decimal digit
                        cmpa    #9              ; check if value is decimal digit 
                        BHI     checkOperation  ; BHI is unsigned so anything less than 0 will overflow and be caught
                                                ; branch if less than 0 or greater than 9
                                                
                        ldy     #firstNumber    ; loads address of number to alter for subroutine
                        jsr     addDecimalDigit ; will multiply by 10 then add digit
                        
                        ldaa    1,X+             ; load next value from buffer and move pointer
                        incb                     ; increase counter
                        cmpb    #3               ; ensure no more than 4 digits in first number
                        ble     verifyDecimalLoop1  ; loops until 4 numbers are checked or non decimal digit char is found



checkOperation          cmpb    #0                ; checks that there was at lease 1 decimal digit
                        beq     invalid           ; invalid if no decimal digits for first number
                        ldaa    -1,X              ; reload in ascii value to be compare as ascii bias was previously removed          
                        
addition                
                        cmpa    #'+'                ; check if addition
                        bne     subtraction         ; move to subtraction if not addition
                        ldy     #additionSub        ; stores address to addition subroutine if it is addition
                        bra     checkSecondNumber   ; move on to check for second decmial number
                        
subtraction             cmpa    #'-'                ; check if subtraction
                        bne     multiplication      ; move to multiplication if not subtraction
                        ldy     #subtractionSub     ; stores address to addition subroutine if it is subtraction
                        bra     checkSecondNumber   ; move on to check for second decmial number
                        
                        
multiplication          cmpa    #'*'                ; check if multiplication
                        bne     division            ; move to division if not subtraction
                        ldy     #multiplicationSub  ; stores address to addition subroutine if it is multiplication
                        bra     checkSecondNumber   ; move on to check for second decmial number
                        
                        
division                cmpa    #'/'                ; check if division
                        bne     invalid             ; division is lasat operand to be check so must be invalid char if not '/'
                        ldaa    X                ; load value after operation which should be start of second number
                        cmpa    #$30
                        beq     invalid
                        
                        ldy     #divisionSub        ; stores address to addition subroutine if it is division
                                                    ; move on to check for second decmial number

                        
checkSecondNumber       
                        sty     operationAddress    ; store address of subroutine calculation at operationAddres
                        ldaa    1,X+               

                        ldy     #0
                        sty     secondNumber            ;clears the value in secondNumber
                        ldab    #0                      ; initialize counter
                        
verifyDecimalLoop2      
                        cmpa    #CR                     ; checks if enter character at begingin of each loop
                        beq     checkReturn             ; if char is a newline/enter then break from loop
                        suba    #48                     ; eliminate ascii bias for decimal digits
                        cmpa    #9
                        BHI     checkReturn
                        
                        ldy     #secondNumber          ; loads address of number to alter for subroutine
                        jsr     addDecimalDigit        ; will multiply by 10 then add digit
                        
                        ldaa    1,X+                   ; load next value and move pointer
                        incb                           ; increase count
                        cmpb    #3                     ; check counter
                        ble     verifyDecimalLoop2     ; loops 4 times or until non-decimal digit reached

                        
checkReturn             cmpb    #0                     ; ensures there was at least one decimal digit in the second number
                        beq     invalid                ; invalid message if no second number
                        ldaa    -1,X                   ; load current char again as ascii bias was removed
                        cmpa    #CR
                        bne     invalid
                        jsr     getResult         ; calculates result and prints it or prints an overflow message
                        
                        pulx
                        pula
                        puly
                        clc
                        rts
                        
                        ;bra     endCalcParse          ; branch to end of subroutine
                        
invalid                 
                        
                        ;ldaa   #CR                ; move the cursor to beginning of the line
                        ;jsr    putchar            ;   Cariage Return/Enter key
                        ;ldaa   #LF                ; move the cursor to next line, Line Feed
                        ;jsr    putchar            ; print msg4 which tells the user their input is invalid
                        
                        ;ldx    #OutputLineBegin   ; prints space at the begingin of output line
                        ;jsr    printmsg
                        ;ldx    #invalidInputMsg   ; prints invalid formate message
                        ;jsr    printlnmsg       
                        
                        pulx
                        pula
                        puly
                        sec
                        rts
                                        
;endCalcParse                
;                        pula
;                        pulx                      ;resotre registers
 ;                       rts

;***********end of parseCalculation******************








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
            lbne    checkCalc                ; if not move to q
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
            
checkCalc            
            jsr     parseCalculation
            bcc     endParse
            ;bcs     invalidCmd
            
            cmpa    #'q'                     ; check for q
            bne     invalidCmd              ; if not no other commands left so print error
            ldaa    1,X+
            cmpa    #CR                     ; check next char for enter 
            bne     invalidCmd              ; if not print error
            jsr     typeWriter          ; if so run type writer program for lifetime of program
            
            
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
            
            dex
removeCRLoop            
            ldaa    1,X+
            cmpa    #CR
            bne     removeCRLoop                ; replace return after cmd so rest of line can print
            ldaa    #$20
            staa    -1,X
            
            ldx     #invalidInputMsg
            stx     errAddress
            
            sec                               ; set carry indictaing invalid input
            puld                              ; restore registers
            pulx                              ; return from subroutine
            rts
            
;***************end of parseCmd***************


;***********addDecimalDigit***************************
;* Program: performs one decimal left shift and adds a number to the least significant digit 
;* Input: address of number to shift  
;* Output: number is shifted with added digit and saved in memory 
;* 
;* Registers modified: Y,D - used for multiplication to shift value, 
;*                     X - holds address of number to shift 
;* Algorithm:
;                 
;**********************************************

addDecimalDigit
                        staa      digitValue     ; stores a in digit value to add to number
                        
                        pshx                     ; save x
                        pshy                     ; save y
                        pshd                     ; save d
                      
                         
                        
                        TFR       Y,X             ; transfer y to x
                        
                        ldd       X              ; load number into d
                        ldy       #10            ; load 10 into y
                        EMUL                     ; multiplies D*Y -> Y:D, no overflow guarenteed as working with 4 decimal digit numbers
                        addb      digitValue
                        adca      #0
                        std       x              ; store that at the address of the number
                                                
                        puld                     ; restore d
                        puly                     ; restore y
                        pulx                     ; restore x
                        
                        rts




;***********end of addDecimalDigit********************



;***********addition***************************
;* Program: adds firstNumber to secondNumber and stores in result
;* Input:firstNumber, secondNumber  
;* Output: carry bit, result   
;* 
;* Registers modified:  d - used for computation
;* Algorithm:  load firstNumber in d then adds secondNumber and stores the result
;              checks if result id more than 4 decimal digits and sets the carry bit if so otherwise carry bit is cleared
;                              
;**********************************************

additionSub
                        pshd                      ; save d register
                        ldd       firstNumber     ; load firstNumber
                        addd      secondNumber    ; add secondNumber
                        std       result          ; store result
                        
                        
                        cpd       #9999           ; check if sum 4 digits or less
                        clc                       ; clear carry by default
                        ble       endAddition     ; z bit set by cpd and will brach to skip set carry if sum is <=#9999
                        sec                       ; set carry if sum uses more than 4 decimal digits
endAddition 
                        puld                      ; restore d register
                        rts                       ; return from subroutine

;***********end of addition********************

;***********subtraction***************************
;* Program:subtracts secondNumber from fistNumber 
;* Input: firstNumber, secondNumber  
;* Output: result  
;*                  
;* Registers modified: d -  used for computation
;* Algorithm:      load firstNumber into d then subtract secondNumber and store result
;                  carry bit always cleared as negative numbers can't be input so result can be negative but never more than 4 digits
;                 
;**********************************************

subtractionSub
                        pshd                      ; save d register
                        ldd       firstNumber     ; load firstNumber
                        subd      secondNumber    ; subtract secondNumber from first
                        std       result          ; store difference in result
                        clc                       ; clear carry indicating no overflow
                        puld                      ; restore d register
                        rts                       ; return from subroutine

;***********end of subtration********************

;***********multiplication***************************
;* Program: multplies firstNumber and secondNumber
;* Input:   firstNumber and secondNumber
;* Output:  product in result 
;* 
;* Registers modified: d - firstNumber then lower bits of product after multipliation
;*                     y - secondNumber then upper bits of product after multiplication
;* Algorithm:
;                   load firstNumber and secondNumber into d and y
;                     extended multiply
;                     ensure upper bits are 0 and lower bits <#9999
;                       clears carry if true and sets if not
;                     store lower bits of product 
;                 
;**********************************************

multiplicationSub
                        pshd                       ; save d and y register
                        pshy
                        ldd       firstNumber      ; load firstNumber
                        ldy      secondNumber      ; load secondNumber
                        
                        EMUL                       ; multiplies d and y register
                        cpy       #0               ; checks if y is 0
                        bne       multErr          ; y is upper bits of product so if not 0 product is more than 4 decimal digits
                        cpd       #9999            ; checks if d is <= #9999 unsigned
                        BHI       multErr          ; if above #9999 set carry bit to indicate overflow 
                        
                        std       result           ; store result if no error
                        clc                        ; clear carry indicating no overflow
                        puly                       ; restore d and y register
                        puld
                        rts                        ; return from subroutine
multErr                 
                        sec                        ; set carry indicating overflow
                        puly                       ; restore y and d register
                        puld
                        rts                        ; return from subroutine



;***********end of multiplication********************

;***********division***************************
;* Program:  divide second number from first number
;* Input: firstNumber and secondNumber 
;* Output: quotient storedi n result  
;* 
;* Registers modified: d and x used for division
;* Algorithm:  load first number into d and secondNumber in x
;                 integer divide 
;                  clear carry bit
;                 
;**********************************************

divisionSub
                        pshd                         ; save x and d register
                        pshx
                        ldd       firstNumber        ; load firstNumber into d register
                        ldx       secondNumber       ; load secondNumber into x register
                        IDIV                         ; integer divide 
                        stx       result             ; store the quotient
                        clc                          ; clear carry bit
                        pulx                         ; restore x and d register
                        puld
                        rts                          ; return from subroutine




;***********end of division********************


;***********getResult***************************
;* Program:  calculate result then convert that result to ascii and print to output
;* Input:  address of subroutine to call to calculate result
;* Output: prints the result of the calculate typed in  
;* 
;* Registers modified: x - used to store address of subroutine to call and for address of message to call 
;* Algorithm:       call correct subroutine to perform calculation
;                   check for overflow
;                       print result if no overflow
;                       print overflow error if there is overflow
;                 
;**********************************************

getResult
                        pshy
                        pshx  
                        pshd
                        
                                                     ; save x register
                        ldx        operationAddress     ; load address of subroutine to run
                        jsr        0,X                  ; run correct subroutine based on operation
                        
                        bcs        overflowError        ; branch if carry set indicating overflow
                        ;jsr        printResult          ; if carry clear then print the result 
                        ldy        #cmdContent
                        ldx        #calculationOut
                        
addCmdCalcOut           
                        ldaa       1,Y+
                        staa       1,X+
                        cmpa       #CR
                        bne        addCmdCalcOut
                        
                        deX
                        
                        ;add cmd content to calculation out
                          ;add firstnumber assic to calc out
                          ;add operator to ascii out
                          ;add second number to ascii out
                          
                        ; add equal sign
                        
                        
                        ldaa         #$3D     ; print =
                        staa         1,X+
                        
                        

                        
                        
                        ;jsr         printmsg
                        
                        ldy         result       ; load result
                        cpy         #0           ; check if result is negative
                        bge         positive     ; skip printing negative sign if positive
                        ldaa        #$2D
                        staa        1,X+
                        ;ldx         #NEGsign     ; print negative sign
                        ;jsr         printmsg
                                                
                        pshd                     ; save d register
                        ldd         #-1          ; get magnitude of number
                        EMULS                    ; multipy result in y by -1 in d
                        std         result       ; store magnitude of result when negative
                        puld
                        
positive                ;call convert base that turns number into ascii and stores value in buffer                        
                        jsr       convertBase         ; converts the number in totalValue and stores the ascii of each digit in the base specified in y 
                        ldy       #asciiResult        ; loads address of the digits buffer
              
eliminateLeading0       ldaa      1,Y+               ; loads first value in buffer and increments X
                        cmpa      #'0'                ; check if first digit is 0
                        beq       eliminateLeading0   ; loop, moving digit to start at until there are no leading zeros
                      
                        dey
                        cmpa      #$00               ; if a is NULL then number was zero and decimal number moved through all digits so it prints one 0 for the decimal representation
                        bne       moveResultToOut     ; if a is not null then move to print step
                        ;ldy       #ZERO               ; load address of ZERO to print '0'
                        ldaa      #$30
                        staa      X
                        bra       endPutCalc
                        
                        
moveResultToOut         ;ldy          #asciiResult
                        
                        staa         1,X+
                        ldaa         1,Y+
                        cmpa         #$00
                        bne          moveResultToOut
                        
                        dex     
                        ldaa         #$20
                        staa         x
                        
                        
endPutCalc                        
                        puld
                        pulx
                        puly                            ; restore x
                        rts                             ; return from subroutine
                        
overflowError           
                        ldx        #overflowErrMsg
                        stx        errAddress
                        ldaa       #$20
                        staa       isError
                          
                        ;ldaa      #CR                   ; prints a newline character
                        ;jsr       putchar
                        ;ldx       #OutputLineBegin      ; prints tab spacing for output
                        ;jsr       printmsg              
                        ;ldx       #overflowErrMsg       ; print overflow message
                        ;jsr       printlnmsg
                        
                        puld
                        pulx
                        puly                            ; restore x
                        rts                             ; return from subroutine




;***********end of getResult********************


;***********printResult***************************
;* Program: converts result to ascii then print it
;* Input: result of calculation stored in result 
;* Output:   
;* 
;* Registers modified: 
;* Algorithm:              print equal sign
;                               check if number is negative and if so print negative sign and get magnitude of number
;                          convert result to ascii and store in a buffer
;                           print that buffer without leading zeros and prints one 0 if all 0s
;                 
;**********************************************

;printResult                                                
;                        pshx                     ; store x and y registers
;                        pshy                      
 ;                       
;                        ldx         #EQUsign     ; print =
;                        jsr         printmsg
 ;                       
  ;                      ldy         result       ; load result
   ;                     cpy         #0           ; check if result is negative
    ;                    bge         positive     ; skip printing negative sign if positive
     ;                   ldx         #NEGsign     ; print negative sign
      ;                  jsr         printmsg
       ;                                         
        ;                pshd                     ; save d register
         ;               ldd         #-1          ; get magnitude of number
          ;              EMULS                    ; multipy result in y by -1 in d
           ;             std         result       ; store magnitude of result when negative
            ;            puld
                        
;positive                ;call convert base that turns number into ascii and stores value in buffer                        
 ;                       jsr       convertBase         ; converts the number in totalValue and stores the ascii of each digit in the base specified in y 
  ;                      ldx       #asciiResult        ; loads address of the digits buffer
              
;eliminateLeading0       ldaa      1,X+               ; loads first value in buffer and increments X
 ;                       cmpa      #'0'                ; check if first digit is 0
  ;                      beq       eliminateLeading0   ; loop, moving digit to start at until there are no leading zeros
   ;                   
    ;                    dex
     ;                   cmpa      #NULL               ; if a is NULL then number was zero and decimal number moved through all digits so it prints one 0 for the decimal representation
      ;                  bne       printAsciiDigit     ; if a is not null then move to print step
       ;                 ldx       #ZERO               ; load address of ZERO to print '0'
        ;      
;printAsciiDigit         
 ;                       
                        ;jsr       printmsg            ; print ascii in buffer
                                                        ;                        
                        ;ldaa      #CR                  ;print newline
                        ;jsr       putchar
                        
                        
   ;                     puly                          ; restore y and x
  ;                      pulx
                        
    ;                    rts                           ; return from subroutine


;***********end of printResult********************



;***********convertBase***************************
;* Program: converts to the base determined by the Y register then stores each digit as ascii in a buffer
;* Input: base to convert to in register Y, value   
;* Output: ascii values of the values in the specified base stored in buffer Y
;* 
;* Registers modified: A register, X register, Y register, D register
;* Algorithm: 
;                 starts at end of buffer and places a NULL
;                   moves through the buffer from bottom to top
;                   for each digit it divides by the base then converts the remainder to ascii and stores in buffer
;                  then moves to digit above current place in buffer
;     
;**********************************************
convertBase            
               
               pshy
               pshb                    ; saves b from outside subroutine - used as counter for loop in subroutine
               pshx                    ; saves x from outside subroutine - used as divisor in subroutine
               ldx      #10
                              
               pshd                     ;save d
               ldd      #asciiResult    ; load address of ascii buffer
               addd     #4              ; moves to the end of buffer
               tfr      D,Y             ; transfers that address to y
               puld                     ; restores d
               
               
               ldab     #$00            ; loads NULL into b
               stab     Y               ; stores NULL at end of buffer 
               dey                      ; moves up buffer from end
               
               ldab     #4              ; b used as counter in subroutine - largetst number of digits is 16 for binary numbers
placeAsciiLoop                          ; loop places each ascii ascii character in memory
               pshd                     ; stores d outside loop because it's used in multiplication
               pshx                     ; stores x outside of loop because it's used in multiplication
              
               
               ldd      result          ; loads value to be divided into D
               IDIV                     ; D/X, result in X and remainder in D
               stx      result          ; puts value after division in total Value to be divided in next iteration
               pulx                     ; restores x to dividend value - base to convert to
               
               
                             
               addd     #48                  ; adds ascii offset for digits
               stab     1,Y-                 ; stores remainder with ascii offset added to space in buffer then moves to next byte in the buffer
               puld                          ; restores the value of d to get the value in the counterb
               
               decb                          ; decrements loop counter
               bne      placeAsciiLoop       ; loops if counter isn't 0
               
               
               pulx
               pulb                          ; restore x
               puly                          ; restore b
               rts                           ; restore y
                         
                    
;***********convertBase********************
         











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
typeWriter      
                jsr   nextline
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




timeClockMsg              DC.B         'Tcalc> '
hoursAscii                DC.B         '00',CN
minutesAscii              DC.B         '00',CN
secondsAscii              DC.B         '00'
space                     DC.B         '    '
calculationOut            DC.B         '                  '
endCalcOut                DC.B         $00
cmdMsg                    DC.B         'CMD> '
cmdContent                DC.B         '               '
endCmdContent             DC.B         $00
errorMsg                  DC.B         'Error>'
isError                   DC.B          $00,$00
errAddress                DS.W         1 
invalidInputMsg           DC.B         'Invalid input',$00
overflowErrMsg            DC.B         'Overflow',$00
errSpace                  DC.B         ' ',$00

msg1                      DC.B   'Hello',CR,LF
                          DC.B   'You may use the following commands:',CR      ; type a welcome message explaining commands
                          DC.B   't 00:00:00 - sets the time to the entered time',CR
                          DC.B   'q - quits the program and runs the typewriter program',CR
                          DC.B   'h - displays the hour in decimal format on the display',CR
                          DC.B   'm - displays the minute in decimal format on the display',CR
                          DC.B   'm - displays the second in decimal format on the display',CR
                          DC.B        'The calculator rules are as follows:',$0D,$0A
                   DC.B        "1.Input positive decimal integer numbers only",$0D,$0A
                   DC.B        '2.Input and output maximum four digit numbers only',$0D,$0A
                   DC.B        '3.Valid operators are: +, -, *, and /',$0D,$0A
                   DC.B        '4.Input number with leading zero is OK', $0D,$0A                   
                   DC.B        '5.Input only two numbers and one operator in between, no spaces',$0D,$0A
                   DC.B        '6.Ineger Division. Fractions will be truncated',$0D,$0A
                   DC.B        '7.Results longer than 4 decimal digits will cause an overflow error',$0D,$0A
                   DC.B        '8.Incorrect input format will cause "Invalid input format" error',$0D,$0A
                   ;DC.B        'You may begin calculating',$00

                          DC.B   'the time and characters entered will display every second',CR                       
                      
msg2                      DC.B   'You may type below', $00

typeWriterMsg             DC.B         '       Clock and Calculator stopped and Typewrite program started',CR
                          DC.B         '       You may type below.',$00
            
            
            END               ; this is end of assembly source file
                              ; lines below are ignored - not assembled/compiled
                              
                              
