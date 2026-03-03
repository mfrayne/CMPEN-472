****************************************************************************************
*                   
* Title:          LED Light ON/OFF and Switch ON/OFF
*
* Objective:      CMPEN 472 Homework 3 student program
*
* Revision:       V3.1 for CodeWorrior 5.2 Debugger Simulation
*
* Date:           Feb. 8, 2026
*
* Programmer:     Michael Frayne
*
* Company:        Penn State
*
* Program:        Repeatedly brighten then dim LED 1
*                 LED 1 will go from 0% brightness to 100% in 0.3 seconds
*                 LED 1 will then go from 100% brightness to 0% in 0.3 seconds
*
* Note:           On CSM-12c128 board,
*                 Switch 1 is at PORTB bit 0, and
*                 LED 4 is at PORTB bit 7
*                 This program is developed and simulated using
*
* Algorithm:      Simple dimming and brightening loop
*
* Register Use:   A: LED Light on/off state and Switch on/off state
*                 X,Y: Delay loop counters
*                 
* Memory Use:     RAM Locations from $3000 for data,
*                 RAM Locations from $3100 for program
*
* Input:          Parameters hard-coded in the program - PORTB
*                 Switch 1 at PORTB bit 0
*                 Switch 2 at PORTB bit 1
*                 Switch 3 at PORTB bit 2
*                 Switch 4 at PORTB bit 3
*
* Output:         LED 1 at PORTB bit 4
*                 LED 2 at PORTB bit 5
*                 LED 3 at PORTB bit 6
*                 LED 4 at PORTB bit 7
*
* Observation:    This is a program that blinks an LED to change it's brightness 
*                 and changes the brightness from low to high and high to low
*                 
*
****************************************************************************************
* Parameter Declaration Section
*
* Export Symbols
            XDEF        pstart        ; export 'pgstart symbol
            ABSENTRY    pstart        ; for assembly entry point
            
* Symbols and Macros
PORTA       EQU         $0000         ; i/o port A addresses
DDRA        EQU         $0002
PORTB       EQU         $0001         ; i/o port B addresses
DDRB        EQU         $0003

****************************************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory 
*

                 ORG         $3000         ; Reserved RAM memory starting address
                                      ;   for Data for CMPEN 472 class
DelayCounter1    DC.W        $002E         ; X register count number for time delay
                                      ;   inner loop for msec
                                      ;   outer loop for sec
DimmingCounter   DC.W        $0088      ;   counter used for timing of dimming and brightening

* Number $0030 will result .01 millisecond delay on my PC

                                      ; Remaining data memory space for stack,
                                      ;   up to program memroy start

offCounter  DC.B        100             ; stores the percent of the time that the LED should be off

onCounter   DC.B        0           ; stores the percent of the time that the LED shoulld be on
                                      ; offCounter and onCounter should add up to 100
                                      ; initial values don't matter as long as they are greater than one
                                      ; only one blink cycle with inital values then counters change
         
*
****************************************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory
*                                      
            ORG         $3100             ; Program start address, in RAM
pstart      LDS         #$3100            ; initialize the stack pointer

            LDAA        #%11110000        ; LED 1,2,3,4 at PORTB bit 4,5,6,
            STAA        DDRB              ; set PORTB bit 4,5,6,7 as output
                                      
            LDAA        #%00000000    
            STAA        PORTB             ; clear all bits of PORTB - turns all lights off
            
            BSET        PORTB,#%01000000  ; initialize lights 3 to be ON (100%)   
            
mainLoop                                  ;each loop of main takes about 0.6 seconds

increaseLoop                              ; increases light level from 0% to 100%
            LDX         DimmingCounter    ; load counter into x for how many times the brightness stays the same to change 
brightenLoop                              ; keeps the same brightness for .003 seconds
            
            JSR         blinkLight        ; blinks light based on vlaues in onCounter and offCounter to dim the light
            DEX
            BNE         brightenLoop      ; holds each brightness for a number of times so brightening happens in 0.3 seconds
            
            INC         onCounter         ; increase onCounter by 1
            DEC         offCounter        ; decrease offCounter by 1
            BNE         increaseLoop      ; when offCounter reaches 0 the loop ends


decreaseLOOP                              ; decreases light level from 100% to 0%
            LDX         DimmingCounter
dimmingLoop
            JSR         blinkLight        ; blinks light based on vlaues in onCounter and offCounter to dim the light
            DEX
            BNE         dimmingLoop       ; holds each brightness for a number of times so dimming happens in 0.3 seconds
            
            INC         offCounter        ; increase offCounter by 1
            DEC         onCounter         ; decrease onCounter by 1
            BNE         decreaseLOOP      ; when onCounter reaches 0 the loop ends                             
            
            
            BRA         mainLoop          ; check switch, loop forever!

****************************************************************************************
* Subroutine Sectoin: address used [ $3100 to $3FFF ] RAM 
*
 
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
                                                                           
 
 
 
            
****************************************************************************************
            
            end                             ; last line of a file







