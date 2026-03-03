****************************************************************************************
*                   
* Title:          LED Light ON/OFF and Switch ON/OFF
*
* Objective:      CMPEN 472 Homework 3 student program
*
* Revision:       V3.1 for CodeWorrior 5.2 Debugger Simulation
*
* Date:           Jan.31, 2026
*
* Programmer:     Michael Frayne
*
* Company:        Penn State
*
* Program:        LED 4 blink every 1 second
*                 ON for 0.2 second, OFF for 0.8 second when switch 1 is not pressed
*                 ON for 0.8 second, OFF for 0.2 second when switch 1 is pressed
*
* Note:           On CSM-12c128 board,
*                 Switch 1 is at PORTB bit 0, and
*                 LED 4 is at PORTB bit 7
*                 This program is developed and simulated using
*                 CodeWarrior 5.2 only, with swtich simulation problem.
*                 So, one MUST set "switch 1" at PORTB bit 0 as an 
*                 OUTPUT - not an INPUT.
*                 (If running on CSM-12C128 board, PORTB bit 0 must be set to INPUT).
*
* Algorithm:      Simple Parallel I/O  use and time delay-loop demo
*
* Register Use:   A: LED Light on/off state and Switch on/off state
*                 X,Y: Delay loop counters
*                 
* Memory Use:     RAM Locations from $3000 for data,
*                 RAM Locations from $3100 for program
*
* Input:          Parameters hard-coded in the program - PORTB
*                 Switch 1 at PORTB bit 0
*                 (set this bit as an output for simulation only - and add Switch)
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
*                 and switch1 changes the ratio of time off to time on which changes the brightness
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
Counter1    DC.W        $0030         ; X register count number for time delay
                                      ;   inner loop for msec
                                      ;   outer loop for sec
* Number $0030 will result .01 millisecond delay on my PC

                                      ; Remaining data memory space for stack,
                                      ;   up to program memroy start
                                      
offCounter  DC.W        1             ; stores the percent of the time that the LED should be off

onCounter   DC.W        99           ; stores the percent of the time that the LED shoulld be on
                                      ; offCounter and onCounter should add up to 100
                                      ; initial values don't matter as long as they are greater than one
                                      ; only one blink cycle with inital values then counters change
         
*
****************************************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory
*                                      
            ORG         $3100             ; Program start address, in RAM
pstart      LDS         #$3100            ; initialize the stack pointer

            LDAA        #%11110001        ; LED 1,2,3,4 at PORTB bit 4,5,6,
            STAA        DDRB              ; set PORTB bit 4,5,6,7 as output
                                          ; plus the bit 0 for switch 1
                                      
            LDAA        #%00000000    
            STAA        PORTB             ; clear all bits of PORTB - turns all lights off
            
            BSET        PORTB,#%10100000  ; initialize lights 2 and 4 to be ON (100%)   
            
mainLoop
            JSR         blinkLight        ; blinks light based on vlaues in onCounter and offCounter to dim the light
            LDAA        PORTB             ; check bit 0 of PORTB, switch 1
            ANDA        #%00000001        ; if 0, run sw1pressed 
            BNE         sw1notpsd         ; if 1, run sw1pressed
                                          ; Note: BEQ should be used for board as switch press behavoir on board is opposite of simulation
sw1pressed
            LDY         #35               ; value of light to be off 35% of the time
            STY         onCounter         ; stores new value for on counter
            LDY         #65               ; value of light to be off 65% of the time
            STY         offCounter        ; stores new value for off counter
            
            BRA         mainLoop          ; chekc switch, loop forever!

sw1notpsd                                 ; Loads correct values into sw1 not psd 
            LDY         #2                ; value of light to be off 2% of the time
            STY         onCounter         ; stores new value for on counter
            LDY         #98               ; value of light to be off 98% of the time
            STY         offCounter        ; stores new value for off counter 
            
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
            PSHY                            ; save Y
            LDY     onCounter               ; put number of loops to run for LED on into Y
            
            BSET    PORTB,#%00010000        ; Turns LED1 on
onLoop      JSR     delay10usec             ; waits 10 microseconds 
            DEY                             ; recudes count in Y register
            BNE     onLoop                  ; Loops until Y is 0
            
            LDY     offCounter              ; puts number of loops to run for LED off Y
            BCLR    PORTB,#%00010000        ; turns LED4 off
            
offLoop     JSR     delay10usec             ; delays for 10 micro seconds every loop
            DEY                             ; reduces count in X register
            BNE     offLoop                   ; Loops until Y is 0
            
            PULY                            ; returns value that was in Y before subroutine
            RTS                             ; returns to main loop

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
              PSHX                          ; save X
              LDX     Counter1              ; short delay
            
dlyLoop       NOP                           ; total time delay = X * NOP
              DEX
              BNE     dlyLoop
            
              PULX                          ; restore X
              RTS  
 
 
 
            
****************************************************************************************
            
            end                             ; last line of a file







