*************************************************************************
*
* Title:          LED Light Blinking
* 
* Objective:      CMPEN 472 Homework 2 in-class-room demonstration program 
* 
* Revision:       V3.2 for CodeWarrior 5.2 Debugger Simulation
* 
* Date:           Jan. 26, 2026 
* 
* Programmer:     Michael Frayne
* 
* Company:        Penn State
* 
* Algoritm:       Simple Parallel I/O use and time delay-loop demo 
* 
* Register use:   A: LED Light on/off state and Switch 1 on/off state
*                 X,Y: Delay loop counters
* 
* Memory use:     RAM Locations from $3000 for data,
*                 RAM Locations from $3100 for program
*                  
* Input:          Parameters hard-coded in the program - PORTB                
*                 Switch 1 at PORTB bit 0
*                 Switch 1 at PORTS bit 1
*                 Switch 1 at PORTS bit 2
*                 Switch 1 at PORTS bit 3
*
* Output:            LED 1 at PORTB bit 4                 
*                    LED 2 at PORTB bit 5
*                    LED 3 at PORTB bit 6
*                    LED 4 at PORTB bit 7
*
* Observation:    This is a program that blinks LEDs and blinking period can 
*                 be changed with the delay loop counter value.
*
* Notes:          All Homework programs MUST have comments similar
*                 to this HOMEWORK 2 program. So, please use those
*                 comment format for all your subsequent CMPEN 472
*                 Homework programs.                 
*                
* Commetns:       This progarm is devleoped and simulated using CodeWorrior
*                 development software and targeted for Axion 
*                 Manufacturing's CSM-12C128 board running at 24MHz
*
**************************************************************************
* Parameter Declaration Section
*
* Export Symbols
            XDEF      pstart        ; export 'pstart' symbol
            ABSENTRY  pstart        ; for assembly entry point                

* Symbols and Macros
PORTA       EQU       $0000         ; i/o port A addresses
DDRA        EQU       $0002
PORTB       EQU       $0001         ; i/o port B addresses
DDRB        EQU       $0003       
                
**************************************************************************
* Data Section: address used [ $3000 to $30FF ] RAM memory
*
            ORG         $3000        ; Reserved RAM memory starting address
                                     ;   for Data for CMPEN 472 class
Counter1    DC.W        $0100        ; X register count number for time delay
                                     ;   inner loop for msec
Counter2    DC.W        $00BF        ; Y register count number for time delay    TODO: change to 1000 if doens't work properly
                                     ;   outer looop for sec
                                     
                                     ; Remaining data memory space for stack.
                                     ;   up to program memroy start
*
**************************************************************************
* Program Section: address used [ $3100 to $3FFF ] RAM memory 
*                                                            
            ORG       $3100         ; Program start address, in RAM
pstart      LDS       #$3100        ; initialize the stack pointer

;            LDAA      #%11110000    ;LED 1,2,3,4 at PORTB bit 4,5,6,7 FOR CSM-12C128 board only
            LDAA      #%11111111    ; LED 1,2,3,4 at PORTB bit 4,5,6,7 FOR Simulation only
            STAA      DDRB          ; set PORTB bit 4,5,6,7 as output
            
            LDAA      #%00000000
            STAA      PORTB         ; Turn off  LED 1,2,3,4 (all bits in PORTB, forsimulation only
                       
mainLoop    LDAA      PORTB             ; load data from PORTB into accumulator A
            ANDA      #%00000001        ; read switch 1 at PORTB bit 0
            BNE       sw1pushed         ; check to see if it is pushed

;LED 1 and 4 blink alteratively when switch 1 not pressed             
sw1notpsh   BSET      PORTB,%10000000   ; Turn ON LED 4 at PORTB bit 7
            BCLR      PORTB,%00010000   ; Turn off LED 1 at PORTB bit 4
            JSR       delay1sec         ; Wait for 1 second
            
            BCLR      PORTB,%10000000   ; Turn off LED 4 at PORTB bit 7
            BSET      PORTB,%00010000   ; Turn ON LED 1 at PORTB bit 4
            JSR       delay1sec         ; Wait for 1 second
            BRA       mainLoop          

;all LEDs blink simulatiously when switch 1 pressed            
sw1pushed   BSET      PORTB,%10000000   ; Turn ON LED 4 at PORTB bit 7
            BSET      PORTB,%01000000   ; Turn ON LED 3 at PORTB bit 6
            BSET      PORTB,%00100000   ; Turn ON LED 2 at PORTB bit 5
            BSET      PORTB,%00010000   ; Turn ON LED 1 at PORTB bit 4
            JSR       delay1sec         ; Wait for 1 second
            
            BCLR      PORTB,%10000000   ; Turn off LED 4 at PORTB bit 7
            BCLR      PORTB,%01000000   ; Turn off LED 3 at PORTB bit 6
            BCLR      PORTB,%00100000   ; Turn off LED 2 at PORTB bit 5
            BCLR      PORTB,%00010000   ; Turn off LED 1 at PORTB bit 4
            JSR       delay1sec         ; Wait for 1 second
            
            
            BRA       mainLoop          
            
            
**************************************************************************
* Subroutine Section: address used [ $3100 to $3FFF ] RAM memory
*

;**************************************************************************
; delay1sec subroutine            
; Input: a 16bit count number in 'Counter2'
; Output: 1 second time delay, cpu cycles waisted
; Registers in use: Y register as counter
; Memory locations in use: a 16bit input number at 'Counter2'
;
; Comments: one can add runs of delayMS subroutine instructions to lengthen
;           the delay time.                     
            
delay1sec
            PSHY                  ; saveY            
            LDY   Counter2        ; long delay by
          
dly1Loop    JSR   delayMS         ; total time delay = Y * delayMS
            DEY   
            BNE   dly1Loop
            
            PULY                  ; restore Y
            RTS                   ; return
            
;**************************************************************************
; delayMS subroutine            
;            
; This subroutine cause few msec. delay
;           
; Input: a 16bit count number in 'Counter1'
; Output: time delay, cpu cycle waisted
; Registers in use: X register as counter
; Memory locations in use: a 16bit input number at 'Counter1'
;
; Comments: one can add more NOP instructions to lengthen
;           the delay time.

delayMS
            PSHX                  ; save X
            LDX   Counter1        ; short delay
           
dlyMSLoop   NOP                   ; total time delay = X * NOP
            DEX
            BNE   dlyMSLoop
            
            PULX                  ; restore X
            RTS                   ; return

**************************************************************************
* End of program
*  
            end                  ; last line of a file    
             
            
            
            
            
             