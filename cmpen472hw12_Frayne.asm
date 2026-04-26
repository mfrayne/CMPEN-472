;***********************************************************************
;*
;* Title:          SCI Serial Port and 7-segment Display at PORTB
;*
;* Objective:      CMPEN 472 Homework 5
;*
;* Revision:       V3.2  for CodeWarrior 5.2 Debugger Simulation
;*
;* Date:	          Feb 20, 2026
;*
;* Programmer:     Michael Frayne
;*
;* Company:        The Pennsylvania State University
;*                 Department of Computer Science and Engineering
;*
;* Program:        Simple SCI Serial Port I/O and Demonstration
;*                 Typewriter program and 7-Segment display, at PORTB
;*                 
;*
;* Algorithm:      Simple Serial I/O use, typewriter
;*
;* Register use:	  A: Serial port data
;*                 X,Y: Delay loop counters
;*
;* Memory use:     RAM Locations from $3000 for data, 
;*                 RAM Locations from $3100 for program
;*
;* Output:         
;*                 PORTB bit 7 to bit 4, 7-segment MSB
;*                 PORTB bit 3 to bit 0, 7-segment LSB
;*
;* Observation:    This is a typewriter program that displays ASCII
;*                 data on PORTB - 7-segment displays.
;*
;***********************************************************************
;* Parameter Declearation Section
;*
;* Export Symbols
            XDEF        pstart       ; export 'pstart' symbol
            ABSENTRY    pstart       ; for assembly entry point
  
;* Symbols and Macros
PORTB       EQU         $0001        ; i/o port B addresses
DDRB        EQU         $0003

SCIBDH      EQU         $00C8        ; Serial port (SCI) Baud Register H
SCIBDL      EQU         $00C9        ; Serial port (SCI) Baud Register L
SCICR2      EQU         $00CB        ; Serial port (SCI) Control Register 2
SCISR1      EQU         $00CC        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00CF        ; Serial port (SCI) Data Register

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

;***********************************************************************
;* Data Section: address used [ $3000 to $30FF ] RAM memory
;*
                  ORG         $3000        ; Reserved RAM memory starting address 
                                           ;   for Data for CMPEN 472 class
DelayCounter1     DC.W        $002E         ; X register count number for time delay
                                      ;   inner loop for msec
                                      ;   outer loop for sec
DimmingCounter    DC.W        $0088      ;   counter used for timing of dimming and brightening

offCounter        DC.B        100             ; stores the percent of the time that the LED should be off

onCounter         DC.B        0           ; stores the percent of the time that the LED shoulld be on
                                      ; offCounter and onCounter should add up to 100
                                      ; initial values don't matter as long as they are greater than one
                                      ; only one blink cycle with inital values then counters change

                                                   
inputBuffer        DS.B       $D1                          ; reserves space for input buffer
                                                   ; longest input instruction is QUIT so one byte needed for each char
                                                   ; and extra byte for enter character

totalValue         DS.W       1                    ; stores final converted value
digitValue         DS.B       1                    ; temp value to store value of each digit during conversions
asciiDigits        DS.B       17
numBytes           DS.W       1


; Each message ends with $00 (NULL ASCII character) for your program.
;
; There are 256 bytes from $3000 to $3100.  If you need more bytes for
; your messages, you can put more messages 'msg3' and 'msg4' at the end of 
; the program - before the last "END" line.
                                     ; Remaining data memory space for stack,
                                     ;   up to program memory start

;*
;***********************************************************************
;* Program Section: address used [ $3100 to $3FFF ] RAM memory
;*
                ORG        $3100        ; Program start address, in RAM
pstart          LDS        #$3100       ; initialize the stack pointer

                LDAA       #%11111111   ; Set PORTB bit 0,1,2,3,4,5,6,7
                STAA       DDRB         ; as output

                LDAA       #%00000000
                STAA       PORTB        ; clear all bits of PORTB

                ldaa       #$0C         ; Enable SCI port Tx and Rx units
                staa       SCICR2       ; disable SCI interrupts

                ldd        #$0001       ; Set SCI Baud Register = $0001 => 1.5M baud at 24MHz (for simulation)
                std        SCIBDH       ; SCI port baud rate change

                ;print start instructions and welcome message
                ldx   #welcomeMsg
                jsr   printlnmsg


                ;user input begins

startMenu
                ldaa    #'>'
                jsr     putchar
                ldab    #0                   ; resets inputbuffer counter
menuLoop    
                cmpb    #$D0                  ; check if char input counter above buffer limit (>13 bytes, longest input is 13 chars including enter at end)
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
            
                                  ; store a in input buffer with offset of x+
                        
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
 ;***********end of typeWriter********************



;***********getAsciiHexValue***************************
;* Program: converts a hex value in ascii format to the actual number value and stores it in memory
;* Input: address to ascii of hex formatted number, first value of hex number  
;* Output: stores value of hex ascii in totalValue 
;* 
;* Registers modified: b - used as counter, a - holds each digit to be processed, 
;                      x - holds memory address of digit in buffer being processed, 
;                      d - used for shifting total values before adding the current digit
;* Algorithm:
;                       digit to be processed is stored in a
;                       eliminate ascii bias of that value
;                       iterate through at most 4 spaces of buffer
;                       in each iteration
;                            load totalValue into d and shift left 4 bits - binary to hex
;                            add value to a - next hex digit
;                            if next value is newline ($0D) before 4 space are iterated through then break from loop
;                            load next value in buffer and decrement b
;                            loop
;                          
;     
;**********************************************
getAsciiHexValue
               pshb
               ldab    #4               ;counter for how many digits are checked
               
               
convertHexAsciiLoop               
               suba    #48                ; eliminate ascii part of numeric digit
               blt     asciiHexConverted  ; if less than 0 ascii character was not digit or letter so nothing is set
               cmpa    #10                ; if checks value relative to 10
               blt     addToTotal       ;
               
               
               
               suba    #17                ; eliminates ascii values between 9 and A
               blt     asciiHexConverted ; if less than 0 after subtraction ascii value was between 9 and A so not valid and subroutine ends
               cmpa    #5                 ;
               bgt     asciiHexConverted  ; if ascii value above F then not value end subroutine ends
               adda    #10                ; only gets here if ascii value is A-F which is above 10 so 10 must be added to a

addToTotal               
               pshd
               ldd     totalValue
               LSLd        ; left shift done 4 times as each hex value is 4 bits
               LSLd     
               LSLd     
               LSLd    
               std     totalValue
               puld
               
               
               staa    digitValue   ; stores the real value of the digit
               
               pshd                 ; saves value in D register as D will be used to add to the total
               ldd     #0           ; clears D register
               ldab    digitValue   ; loads the value of the digit to be appended
               addd    totalValue   ; adds the current total to d
               std     totalValue   ; stores d which is the new total into the total value
               puld                 ; returns d to it's previous state
               
               ldaa     1,X+        ; get the next ascii value from the buffer and update X
               decb                 ; decrease the counter
               bne      convertHexAsciiLoop  ; loop continues until maximum of 4 ascii values are evaluated
               
asciiHexConverted
               ldaa     -1,X         ; load last value of x into buffer to be checked outside of subroutine
               cmpb     #4           ; b is only 4 if no iterations were done meaning there were no numbers given and returns error
               clc                   ; clears carry bit - indicates conversion success
               bne      endOfaHC     ; branches if b is not 4 - success
               sec                   ; sets c if b is 4 incicating error for process that called subroutine
                    
endOfaHC       
               
               pulb                  ; restore b
               rts                   ; return to caller routine

;***********end of getAsciiHexValue********************


;***********parseS***************************
;* Program: Parses the buffer for show command 
;* Input: input buffer, address to position of buffer stored in x  
;* Output: validates the user input and outputs the value stored at the designated address
;* 
;* Registers modified: A register, X register
;* Algorithm:  check if there is a a '$' run getAsciiHexValue to verify the ascii hex value and store it in total value
;              check if the value after the hex value is an newline
;              if any of these fail then an invalid address message is printed
;              if everything is typed correctly then print the address and value stored in the address as shown in the example
;
;     
;**********************************************
parseS            
               
               cmpa   #$24             ; load hex for '$' ascii
               bne    parseSerr          ; print invalid message if input is anything other than '$'
               ldaa   1,X+              ; load next character into accumulator a
                        
               jsr    getAsciiHexValue  ; ensures value is valid 4 digit hex
               bcs    parseSerr         ; carry bit set if there was an error and cleared if not
                
               cmpa   #$0D              ;checks if next value is newline
               beq    correctParseS     ; if it is then the input is a correct parse to the value of the address is output

parseSerr      ldx    #addressErrMsg    ; loads an address error message for incorrect input of address
               jsr    printlnmsg        ; prints error message       
               rts                      ; returns subroutine
               
correctParseS  
               pshy                     ; store y
               ldy    totalValue        ; loads the value in totalValue which the the real value converted from the ascii hex
               sty    outputAddress     ; stores the address to display in outputAddress 
               puly                     ; restore y
               jsr    getOutput         ; displays the correct outout to the user
               rts                      ;returns from subroutine
                                       

;***********end of parseS********************


;***********getOutput***************************
;* Program: displays the output message to user with the address and the value stored at that address in binary, hex, and decimal
;* Input: address to be printed in outputAddress 
;* Output: message to user with address and value stored at that address 
;* 
;* Registers modified: X register, Y register
;* Algorithm: prints each part of the output and whenever a number is needed it calls a subroutine to convert to number to correct ascii
;     
;**********************************************
getOutput         
               pshx                             ;save x
               ;prints '>$' to start the output line
               ldx     #outputStart             ; load start of output msg
               jsr     printmsg                 ; prints start of output msg
               
               ;prints address value
               ldy     #16                      ; stores 16 in Y - number to convert to is base 16
               ldx     outputAddress            ; load output address into x
               stx     totalValue               ; stores outputAddress in totalValue
               jsr     printNumber              ; prints the number in the correct format using the value in totalValue
               
               ;prints space between address and binary representation of value
               ldx     #outputSpace1            ; loads address of second space in the output message
               jsr     printmsg                 ; prints second space in output msg
               
               
               ;prints number as binary
               ldy     outputAddress            ; loads address of output to y
               ldx     Y                        ; loads value at outputAddress in x
               stx     totalValue               ; stores that value in total value to be printed
               ldy     #2                       ; loads 2 to y to print number in base 2
                    
               jsr     printNumber              ; prints binary version of value
               
               ;prints space between binary number and hex
               ldx     #outputSpace2            ; loads third space
               jsr     printmsg                 ; prints third space of output msg
               
               ;prints hex number
               ldy     outputAddress            ; address of where value to be displayed in outuput is stored
               ldx     Y                        ; loads value to be dispalyed into x
               stx     totalValue               ; stores value to be displayed in totalValue
               ldy     #16                      ; loads 16 to y to print in base 16
               jsr     printNumber              ; prints hex representation of value stored at x
               
               ;prints space between hex and decimal representation
               ldx     #outputSpace3            ; load address of third space of output
               jsr     printmsg                 ; prints third space of output
               
               ldy     outputAddress            ; address of where value to be displayed in outuput is stored
               ldx     Y                        ; loads value to be dispalyed into x
               stx     totalValue               ; stores value to be displayed in totalValue
               ldy     #10                      ; loads 10 to y to print in base 10
               jsr     printNumber              ; prints decimal representation of value stored at x
               
               ldaa   #CR                ; moves cursor to begining of line
               jsr    putchar            ; 
               ldaa   #LF                ; prints newline to terminal
               jsr    putchar
               
               
               pulx                             ;restore x
               rts                              ; return from subroutine
                         
                    
;***********getOutput********************



;**************printNumber***********************
;* Program: prints the number in totalValue in the base specified in y
;* Input: address to be printed in outputAddress 
;* Output: message to user with address and value stored at that address 
;* 
;* Registers modified: X register, a register
;* Algorithm: 
;              run convertBase which converts to the base stored in y and stores ascii of each digit in asciiDigits
;               checks if representation is in decimal
;                     eliminates leading zeros
;               checks if value is in hex 
;                     address of where to start printing to 4 digits before the end
;               all other bases
;                     print entire buffer
;               
;     
;**********************************************
printNumber
                      pshx                        ; save x
                      psha                        ; save a
              
                      jsr     convertBase         ; converts the number in totalValue and stores the ascii of each digit in the base specified in y 
                      ldx     #asciiDigits        ; loads address of the digits buffer
              
eliminateLeading0     ldaa     1,X+               ; loads first value in buffer and increments X
                      cpy     #10                 ; checks if base is 0
                      bne     endLead0            ; if don't remove leading Zeros
                      cmpa    #'0'                ; check if first digit is 0
                      beq     eliminateLeading0   ; loop, moving digit to start at until there are no leading zeros
                      
                      
                     
                      
endLead0              
                      cpy     #16                 ; checks if number should be in Hex format
                      bne     skipHexOffset       ; if not then there is no additional offset for 
                      ldaa    7,X+
                      ldaa    5,X+                ; moves address of buffer to start at for hex numbers to 4 digits before the end so only 4 digits are printed
skipHexOffset         dex                      
                      cmpa    #NULL               ; if a is NULL then number was zero and decimal number moved through all digits so it prints one 0 for the decimal representation
                      bne     printAsciiDigit     ; if a is not null then move to print step
                      ldx     #ZERO               ; load address of ZERO to print '0'
              
printAsciiDigit       jsr     printmsg            ; print ascii in buffer
              
                      pula                        ;restore a
                      pulx                        ; restore x
                      rts                         ; return from subroutine


;******************printNumber*******************



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
               tfr      y,x            ; moves y to x as x is used in the multiplication
               
               ;puts in null character then move up through memory
               
               pshd                     ;save d
               ldd      #asciiDigits    ; load address of ascii buffer
               addd     #16             ; moves to the end of buffer
               tfr      D,Y             ; transfers that address to y
               puld                     ; restores d
               
               
               ldab     NULL            ; loads NULL into b
               stab     Y               ; stores NULL at end of buffer 
               dey                      ; moves up buffer from end
               
               ldab     #16            ; b used as counter in subroutine - largetst number of digits is 16 for binary numbers
placeAsciiLoop                         ; loop places each ascii ascii character in memory
               pshd                    ; stores d outside loop because it's used in multiplication
               pshx                    ; stores x outside of loop because it's used in multiplication
              
               
               ldd      totalValue    ; loads value to be divided into D
               IDIV                   ; D/X, result in X and remainder in D
               stx      totalValue    ; puts value after division in total Value to be divided in next iteration
               pulx                   ; restores x to dividend value - base to convert to
               
               
                             
               addd     #48                  ; adds ascii offset for digits
               cpd      #57                  ; checks if number is 10 or greater
               ble      convertAsciiDigit    ; skips additional ascii offset if only digit
               addd     #7                   ; adds ascii offset for letters if above 9
               
convertAsciiDigit
               stab      1,Y-                ; stores remainder with ascii offset added to space in buffer then moves to next byte in the buffer
               puld                          ; restores the value of d to get the value in the counterb
               
               decb                          ; decrements loop counter
               bne      placeAsciiLoop       ; loops if counter isn't 0
               
               
               pulx
               pulb                          ; restore x
               puly                          ; restore b
               rts                           ; restore y
                         
                    
;***********convertBase********************
         
          
                
;***********parseW***************************
;* Program: verify user input for W command and if good writes speicified value to specified memory location then outputs the location and value in three different formats. if not valid then it prints an error message 
;* Input: user input stored in buffer  
;* Output: shows value is now stored in the specified memory location or prints an error message
;* 
;* Registers modified: A register, y register, x register
;* Algorithm: 
;              check for '$'

;**********************************************
parseW         
               ;parse '$'   
               cmpa   #$24             ; load hex for '$' ascii
               bne    parseWaddressErr          ; print invalid message if input is anything other than '$'
               ldaa   1,X+              ; load next character into accumulator a
               
               ; parse data value         
               jsr    getAsciiHexValue  ; ensures value is valid 4 digit hex
               bcs    parseWaddressErr  ; carry bit set if there was an error and cleared if not
               
               pshy
               ldy    totalValue        ; updates address
               sty    outputAddress     ; stores new address
               puly
               
               ;space value
               cmpa   #32               ; checks for space
               bne    parseWaddressErr  ; throw error if anything but space
               ldaa   1,X+              ; loads next value into a
               
               ;data value
               cmpa   #$24             ; load hex for '$' ascii
               bne    checkDecimal          ; checks if number is decimal if no '$'
               ldaa   1,X+              ; load next character into accumulator a
               
               jsr    getAsciiHexValue  ;validates data if it's in hex format
               bcs    parseWdataErr     ; if there was an issue extracting the value then data error is printed
               bra    parseWoutput      ; jumps over decimal verification

checkDecimal   jsr    verifyDecimal     ; converts ascii to decimal and checks if the number is a valid decimal number
               bcs    parseWdataErr     ; data error printed if verifyDecmial failed          
               
               
parseWoutput   pshy                     ; saves y
               pshx                     ; saves x
               ldx    outputAddress     ; loads the address where we want to store data into x
               ldy    totalValue        ; updates data at address
               sty    X                 ; stores data at address which is value stored in output Address
               pulx                     ;restore x
               puly                     ; restore y
                
               cmpa   #$0D              ;checks if next value is newline
               beq    correctParseW     ; if it is then the parse is correct otherwise data error



parseWdataErr       ldx    #dataErrMsg         ;dataError message is loaded
                    jsr    printlnmsg          ; dataError message is printed
                    rts                        ; return from subroutine

parseWaddressErr    ldx    #addressErrMsg      ;address error message is loaded
                    jsr    printlnmsg          ; address error is printed
                    rts
               
correctParseW  
               
               jsr    getOutput               ;output is generated if user input is correct
               rts  
                  

;***********end of parseW********************                


;***********parseDump***************************
;* Program: verify user input for W command and if good writes speicified value to specified memory location then outputs the location and value in three different formats. if not valid then it prints an error message 
;* Input: user input stored in buffer  
;* Output: shows value is now stored in the specified memory location or prints an error message
;* 
;* Registers modified: A register, y register, x register
;* Algorithm: 
;              check for '$'

;**********************************************
parseMemDump         
               ;parse '$'   
               cmpa   #$24             ; load hex for '$' ascii
               bne    parseDumpaddressErr          ; print invalid message if input is anything other than '$'
               ldaa   1,X+              ; load next character into accumulator a
               
               ; parse data value         
               jsr    getAsciiHexValue  ; ensures value is valid 4 digit hex
               bcs    parseDumpaddressErr  ; carry bit set if there was an error and cleared if not
               
               pshy
               ldy    totalValue        ; updates address
               sty    outputAddress     ; stores new address
               puly
               
               ;space value
               cmpa   #32               ; checks for space
               bne    parseDumpaddressErr  ; throw error if anything but space
               ldaa   1,X+              ; loads next value into a
               
               ;data value
               cmpa   #$24             ; load hex for '$' ascii
               bne    checkDecimal          ; checks if number is decimal if no '$'
               ldaa   1,X+              ; load next character into accumulator a
               
               jsr    getAsciiHexValue  ;validates data if it's in hex format
               bcs    parseDumpdataErr     ; if there was an issue extracting the value then data error is printed
               bra    parseDumpoutput      ; jumps over decimal verification         
               
               
parseDumpoutput   pshy                     ; saves y
               ldy    totalValue        ; updates data at address
               sty    numBytes          ; stores second value entered as number of bytes to be displayed from memory
               puly                     ; restore y
                
               cmpa   #$0D              ;checks if next value is newline
               beq    correctParseDump    ; if it is then the parse is correct otherwise data error



parseDumpdataErr       ldx    #dataErrMsg         ;dataError message is loaded
                    jsr    printlnmsg          ; dataError message is printed
                    sec
                    rts                        ; return from subroutine

parseDumpaddressErr    ldx    #addressErrMsg      ;address error message is loaded
                    jsr    printlnmsg          ; address error is printed
                    sec
                    rts
               
correctParseDump  
               
               ;jsr    getOutput               ;output is generated if user input is correct
               clc
               rts  
                  

;***********end of parsememDump********************  


;***********verifyDecimal***************************
;* Program: verifies that the ascii in the buffer is a decimal number and converts the ascii to the actual value
;* Input: input buffer with address stored in x  
;* Output: stores the ascii as a decimal number if valid and if not prints an error message  
;* 
;* Registers modified:y,d,b,x,a, ccr 
;* Algorithm:
;                 continually multiplies the total value by 10 then adds the next digit in the buffer with the ascii bias removed
;                 checks if each digit is valid decimal digit and ensures number is not too large by checking for overflows
;                     uses the carry bit the indicate if the number is valid or not
;**********************************************
verifyDecimal       
               pshy                         ; save y
               ldy      #$0000              ; clear y
               sty      totalValue          ; store at totalValue clearing it
               
               pshb                         ;save b
               ldab     #5                  ; load 5 into be to be used as counter - max decimal length is 5
               
               
decimalConversionLoop       suba     #48             ; eliminates the ascii bias for decimal digits
                            cmpa     #0              ; checks for below 0
                            blt      notDecimal      ; if below 0 then it's not a decimal digit 
                            cmpa     #9              ; check if above 9
                            bgt      notDecimal      ; if above 9 then not a decmial
                            staa     digitValue      ; if between 0 and 9 then store in digitValue
               
                            pshd                     ; save d
                            ldd      totalValue      ; load total value into d
                            ldy      #10             ; load the base which is 10 to y
                            EMUL                     ; multiply value times base D*Y -> Y:D

                            addb     digitValue      ; add digit to lower byte of D
                            adca     #0              ; add carry to upper byte of D
                            std      totalValue      ; store that value in total value
                            puld                     ; restore D
                            bcs      notDecimal      ; branches if there is an overflow indicating number typed in was too large
               
                            cpy      #0              ; checks if multiplication overflowed 16 bits indicating typed value was too large
                            bne      notDecimal      ; throw error
               
                            ldaa     1,X+            ; loads next value from buffer
                            decb                     ; decrease counter
                            bne      decimalConversionLoop    ; loops until 5 digits are parsed
                            
                            
notDecimal     
                            dex                      ;reverses increment of buffer at end of loop
                            ldaa     X               ; loads the last value of the buffer into a
                            cmpa     #$0D            ; checks if last valuse was an enter char 
                            beq      isDecimal       ; if it was then the value is decimal
                            sec                      ; sets clear if it is valid decimal
                            pulb                     ; restore b
                            puly                     ; restore y
                            rts                      ; return subroutine
                            
isDecimal                   clc                      ;clear carry if not value
                            
                            pulb                     ;restore b
                            puly                     ;restore y
               
                            rts                      ; return from subroutine
;***********end of verifyDecimal********************


;***********parseGo***************************
;* Program:
;* Input: 
;* Output:
;* 
;* Registers modified: 
;* Algorithm:  
;
;     
;**********************************************
parseGo            
               
               cmpa   #$24             ; load hex for '$' ascii
               bne    parseGoerr          ; print invalid message if input is anything other than '$'
               ldaa   1,X+              ; load next character into accumulator a
                        
               jsr    getAsciiHexValue  ; ensures value is valid 4 digit hex
               bcs    parseGoerr         ; carry bit set if there was an error and cleared if not
                
               cmpa   #CR              ;checks if next value is newline
               beq    correctParseGo     ; if it is then the input is a correct parse to the value of the address is output

parseGoerr     ldx    #addressErrMsg    ; loads an address error message for incorrect input of address
               jsr    printlnmsg        ; prints error message       
               rts                      ; returns subroutine
               
correctParseGo  
               ldx    totalValue
               JMP    X        ; loads the value in totalValue which the the real value converted from the ascii hex
               ; sty    outputAddress     ; stores the address to display in outputAddress 
               rts                      ;returns from subroutine
                                       

;***********end of parseGo********************

;***********memoryDump***************************
;* Program:
;* Input: 
;* Output:
;* 
;* Registers modified: 
;* Algorithm:  
;
;     
;**********************************************
memoryDump            
               pshx
               pshd
               
               ldd     outputAddress
               addd    numBytes
               std     numBytes
               
               ldx     outputAddress
               ;ldab    #0
displayWordM                   
               ldab    #0
               ; print address for start of each line - X
               pshd
               tfr     X,D
               lsra               
               lsra             ; moves upper 4 bits of x to lower 4 of a
               lsra
               lsra
               
               
               cmpa   #10
               blo    skipHexDigit1
               adda   #$07
skipHexDigit1                              
               adda   #$30      ; add ascii bias
               
               
               jsr    putchar   ; prints first digit of address
               tfr    X,D       ; store d
               anda   #$0F      ; get rid of upper bits
               
               cmpa   #10
               blo    skipHexDigit2
               adda   #$07
skipHexDigit2                              
               adda   #$30      ; add ascii bias
               
               jsr    putchar   ; print second digit of address
               clra   
               lsld
               lsld             ; move upper bits of b to lower bits of a
               lsld
               lsld
               
               cmpa   #10
               blo    skipHexDigit3
               adda   #$07
skipHexDigit3                              
               adda   #$30      ; add ascii bias
               
               
               jsr    putchar   ; print third digit
               clra   
               lsld
               lsld             ; move lowest bits of address to a
               lsld
               lsld
               
               cmpa   #10
               blo    skipHexDigit4
               adda   #$07
skipHexDigit4                              
               adda   #$30      ; add ascii bias
               
               jsr    putchar   ; print fourth digit of address
               
               puld             ;restore d
               
               
               
               ;TBA
               ;jsr     putchar
               
displayByteM               
               ldaa    #$20
               jsr     putchar
               ;print space
               
               pshb
               ldab    1,X+
               clra
               
               lsld    ; moves top four bits from b to a
               lsld
               lsld
               lsld
               
               lsrb    ; shifts b bits back to lower bits of b
               lsrb
               lsrb
               lsrb
               
               ;print a as ascii
               adda    #$30
               cmpa    #$39
               ble     printLSB
               adda    #$07
               
printLSB               ;print b as ascii
               addb    #$30
               cmpb    #$39
               ble     printByte
               addb    #$07
               
printByte
               jsr    putchar
               TBA    
               jsr    putchar
               
               pulb
               
               cpx     numBytes
               beq     endMemDump
               
               incb
               cmpb    #16
               bne     displayByteM
               
               
               
               ldaa   #CR                ; move the cursor to beginning of the line
               jsr    putchar            ;   Cariage Return/Enter key
               ldaa   #LF                ; move the cursor to next line, Line Feed
               jsr    putchar
               
               lbra     displayWordM        

endMemDump
               ldaa   #CR                ; move the cursor to beginning of the line
               jsr    putchar            ;   Cariage Return/Enter key
               ldaa   #LF                ; move the cursor to next line, Line Feed
               jsr    putchar
               puld
               pulx 
               clc             
               rts                      ;returns from subroutine
                                       

;***********end of memoryDump********************





;***********parseLDump***************************
;* Program:
;* Input: 
;* Output:
;* 
;* Registers modified:
;* Algorithm: 
;              

;**********************************************
parseLDump         
               ;parse '$'   
               cmpa   #$24             ; load hex for '$' ascii
               lbne    parseDumpaddressErr          ; print invalid message if input is anything other than '$'
               ldaa   1,X+              ; load next character into accumulator a
               
               ; parse data value         
               jsr    getAsciiHexValue  ; ensures value is valid 4 digit hex
               lbcs    parseDumpaddressErr  ; carry bit set if there was an error and cleared if not
               
               pshy
               ldy    totalValue        ; updates address
               sty    outputAddress     ; stores new address
               puly
               
               ;space value
               cmpa   #32               ; checks for space
               lbne    parseDumpaddressErr  ; throw error if anything but space
               ldaa   1,X+              ; loads next value into a
               
               ;numBytes value
               cmpa   #$24
               lbne   parseLDumpdataErr             ; load hex for '$' ascii
               ;lbne    checkDecimal          ; checks if number is decimal if no '$'
               ldaa   1,X+              ; load next character into accumulator a
               
               jsr    getAsciiHexValue  ;validates data if it's in hex format
               bcs    parseLDumpdataErr     ; if there was an issue extracting the value then data error is printed
               ;bra    parseLDumpoutput      ; jumps over decimal verification         
               
               
parseLDumpoutput   
               pshy                     ; saves y
               ldy    totalValue        ; updates data at address
               sty    numBytes          ; stores second value entered as number of bytes to be displayed from memory
               puly                     ; restore y
               
               
               ldy    #getLoadDataFile
               sty    getStoreByte 
               cmpa   #CR              ;checks if next value is newline
               lbeq    correctParseDump    ; if it is then the parse is correct otherwise data error
               ldy    #getLoadDataType
               sty    getStoreByte
               cmpa   #' '
               lbeq    correctParseLDump


parseLDumpdataErr       
                    ldx    #dataErrMsg         ;dataError message is loaded
                    jsr    printlnmsg          ; dataError message is printed
                    sec
                    rts                        ; return from subroutine

parseLDumpaddressErr    
                    ldx    #addressErrMsg      ;address error message is loaded
                    jsr    printlnmsg          ; address error is printed
                    sec
                    rts
               
correctParseLDump  
               
               ;jsr    getOutput               ;output is generated if user input is correct
               clc
               rts  
                  

;***********end of parsemLDump******************** 

 


;***********parseInputBuffer***************************
;* Program: controls flow of program once input is enterd. Calls correct subroutine based on input
;* Input: buffer at address #inputBuffer  
;* Output: calls subroutine or displays invalid input message then returns to main program 
;* 
;* Registers modified: accumulator a stores one ascii of buffer at a time to be checked
;*                      register x stores the address of the character in buffer currently being evaluated 
;* Algorithm:   load the first value of buffer into a
;                if a matches 'S'
;                      parse show and if valid show user memroy space
;
;                 else if a matches W
;                      parse write and if valid write to memory and display to user
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
                        ldaa    1,X+
                        
                        cmpa    #'S'             ; check if a is 's'
                        bne     cmpWrite             ; branch to check for F if not L
                        ldaa    1,X+              ; load next char of buffer to a if a is 'L'
                        
                        jsr     parseS            ; sets z bit to 0 if invalid and sets z bit to 1 if valid 
                        lbra    endParse
                                                
cmpWrite                cmpa    #'W'             ; check if a is 'W'
                        bne     cmpM               ; branch if not 'W'
                        ldaa    1,X+              ; load next char of buffer into a
                        
                        jsr     parseW
                        lbra    endParse
                        
                        
cmpM                    
                        cmpa    #'M'
                        bne     cmpL
                        ldaa    1,X+
                        
                        cmpa    #'D'
                        bne     invalid
                        ldaa    1,X+
                        jsr     parseMemDump
                        bcs     endParse
                        jsr     memoryDump
                        bra     endParse

cmpL                                                
                        cmpa    #'L'
                        bne     cmpG
                        ldaa    1,X+
                        
                        cmpa    #'D'
                        bne     invalid
                        ldaa    1,X+
                        jsr     parseLDump
                        bcs     endParse
                        jsr     loadDump
                        bra     endParse 
                        
cmpG                    
                        cmpa    #'G'
                        bne     cmpQ
                        ldaa    1,X+
                        cmpa    #'O'
                        bne     invalid
                        ldaa    1,X+
                        jsr     parseGo
                        bra     endParse
                        
                        
                        
cmpQ                        
                        cmpa    #'Q'              ; check if first char is 'Q'
                        bne     invalid           ; 
                        ldaa    1,X+               ; load second char of buffer into a
                        cmpa    #'U'              ; check if second char is 'U'
                        bne     invalid           ; if not print invalid message
                        ldaa    1,X+               ; load third char of buffer into a
                        cmpa    #'I'              ; check if third char is 'I'
                        bne     invalid           ; print invalid message
                        ldaa    1,X+               ; load fourth char of buffer into a
                        cmpa    #'T'              ; check if fourth char is 'T'
                        bne     invalid           ; if not prints invalid message
                        ldaa    1,X+
                        cmpa    #$0D
                        bne     invalid
                        
                        ldx     #QUIT              ;if the chars are QUIT exactly then type writer program will begin
                        jsr     printlnmsg         ;prints QUIT message so user knows the menu program has ended and is now on typewriter
                        pula                       ;
                        pulx
                        jsr     typeWriterLoop
                                                
                        
invalid                 ldaa   #CR                ; move the cursor to beginning of the line
                        jsr    putchar            ;   Cariage Return/Enter key
                        ldaa   #LF                ; move the cursor to next line, Line Feed
                        jsr    putchar            ; print msg4 which tells the user their input is invalid
                        ldx    #msg4
                        jsr    printlnmsg       
                        
endParse                
                        pula
                        pulx                      ;resotre registers
                        rts

;***********end of parseBuffer******************

;***********getLoadDataFile***************************
;* Program: 
;* Input:   
;* Output:  
;* 
;* Registers modified: 
;* Algorithm:
;     
;**********************************************
getLoadDataFile       
inputfileLoop       
               jsr     getchar              ; check for input and store in a if recieved any
               cmpa    #$00                 ;  if nothing typed, keep checking
               beq     inputfileLoop
               cmpa    #$1A
               beq     skipputchar
               jsr     putchar
skipputchar 
               rts
;***********end of getLoadDataFile********************



;***********getLoadDataType***************************
;* Program: 
;* Input:   
;* Output:  
;* 
;* Registers modified: 
;* Algorithm:
;     
;**********************************************
getLoadDataType       
               ldaa     1,X+
               rts
;***********end of getLoadDataType********************



;***********loadDump***************************
;* Program: 
;* Input:   
;* Output:  
;* 
;* Registers modified: 
;* Algorithm:
;     
;**********************************************
loadDump       
               ldy      outputAddress
               ;store 16 bytes verifing each ascii is hex and decrement numBytes 
               ;check for enter
               ;
storeWord
               ldab     #16

storeByte               
               pshy
               ldy      getStoreByte        ;put right addres into this and make subroutine to ldaa 1,X+
               jsr      Y
               puly
               
               ;jsr      putchar
               
               suba     #$30
               cmpa     #10
               blo      skipHex1
               suba     #7
               cmpa     #15
               bhi      LDInvalid              
skipHex1      
               
               
               
               pshb
               clrb
               lsrd
               lsrd
               lsrd
               lsrd
 
               pshy
               ldy      getStoreByte        ;put right addres into this and make subroutine to ldaa 1,X+
               jsr      Y
               puly
               ;jsr      putchar
               
               suba     #$30
               cmpa     #10
               blo      skipHex2
               suba     #7
               cmpa     #15
               bhi      LDInvalid              
skipHex2  
               
               
               
               ABA
               pulb
               
               
               staa     Y
               iny
               
               pshy
               ldy      numBytes
               dey
               sty      numBytes
               puly
               beq      LDDone
               
               
               decb
               bne      storeByte
               
               pshy
               ldy      #getLoadDataFile
               sty      getStoreByte
               puly
               
               pshy
               ldy      getStoreByte
               jsr      Y
               ;ldy      #getLoadDataFile
               ;sty      getStoreByte
               
               puly
               
               
               
               cmpa     #CR
               beq      storeWord
               cmpa     #LF
               beq      storeWord
               pshb

LDInvalid
               ;print invalid message - data invalid 
               pulb
               ldx      #dataErrMsg
               jsr      printlnmsg          
               
LDDone               
               
               pshy
               ldy      getStoreByte        ;put right addres into this and make subroutine to ldaa 1,X+
               jsr      Y
               jsr      Y
               puly
               ldaa     #CR
               jsr      putchar
               ldaa     #LF
               jsr      putchar
               rts
;***********end of loadDump********************


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
;***********end of printlnmsg********************


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






;OPTIONAL
;more variable/data section below
; this is after the program code section
; of the RAM.  RAM ends at $3FFF
; in MC9S12C128 chip



welcomeMsg         DC.B        'Welcome to the Simple Memory Access Program!',$0D,$0A
                   DC.B        'Enter one of the following commands (examples shown below)',$0D,$0A
                   DC.B        "and hit 'Enter'",$0D,$0A
                   DC.B        'S:    Show the content of memory location in word',$0D,$0A
                   DC.B        'W:    Write the data word (not byte) to memory location',$0D,$0A
                   DC.B        'MD:       Display the contents of continuous memory locations',$0D,$0A
                   DC.B        'LD:         Load a block of data to continuous memory locations',$0D,$0A
                   DC.B        'GO:       Run the program at the specified memory location',$0D,$0A
                   
                   
                   
                   DC.B        "QUIT: Quit menu program, run 'Type writer' program", $0D,$0A,$00                   
                   DC.B        '>S$3000                  ',$3B,'to see the memory content at $3000 and $3001',$0D,$0A
                   DC.B        '> $3000 => %0001001001101010    $126A    4714',$0D,$0A
                   DC.B        '>',$0D,$0D,$0A
                   DC.B        '>W$3003 $126A            ',$3B,'to write $126A to memory locations $3003 and $3004',$0D,$0A
                   DC.B        '> $3003 => %0001001001101010    $126A    4714',$0D,$0A
                   DC.B        '>',$0D,$0D,$0A
                   DC.B        '>W$3003 4714             ',$3B,'to write $126A to memory location $3003 and $3004',$0D,$0A
                   DC.B        '> $3003 => %0001001001101010    $126A    4714',$0D,$0A
                   DC.B        '>',$0D,$0D,$0A
                   DC.B        'QUIT                    ',$3B,'quit the Simple Memory Access Program',$0D,$0A
QUIT               DC.B        'Type-writing now, hit any keys:',$00  




; QUIT                    ;quit the Simple Memory Access Program
; Type-writing now, hit any keys:


msg1                DC.B        'Hello', $00               ;stores ascii characters for first line of welcome message
msg2                DC.B        'You may type below', $00  ;stores ascii characters for second line of welcome message
msg3                DC.B        'Enter your command below:', $00
msg4                DC.B        'Error: Invalid command', $00



addressErrMsg       DC.B       'invalid input, address',$00
dataErrMsg          DC.B       'invalid input, data',$00
outputmsg           DC.B       '$3003 => %0001001001101010    $126A    04714',$00
        
outputAddress       DC.W       $3000
outputStart         DC.B       '>$',$00
outputSpace1        DC.B       ' => %',$00
outputSpace2        DC.B       '    $',$00
outputSpace3        DC.B       '    ',$00

ZERO                DC.B       '0',$00

getStoreByte        DS.W       1  

;binaryValueOutput   DC.B       '%10101010',$00
;hexValueOutput      DC.B       '$1010',$00
;decimalValueOutput  DC.B       '65000',$00


               END               ; this is end of assembly source file
                                 ; lines below are ignored - not assembled/compiled
