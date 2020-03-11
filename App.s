; Definitions  -- references to 'UM' are to the User Manual.

; Memory initialisation
  AREA  Memory, CODE, READWRITE
counter space 4

; Timer Stuff -- UM, Table 173

T0  equ  0xE0004000    ; Timer 0 Base Address
T1  equ  0xE0008000

IR  equ  0      ; Add this to a timer's base address to get actual register address
TCR  equ  4
MCR  equ  0x14
MR0  equ  0x18

TimerCommandReset  equ  2
TimerCommandRun  equ  1
TimerModeResetAndInterrupt  equ  3
TimerResetTimer0Interrupt  equ  1
TimerResetAllInterrupts  equ  0xFF

; VIC Stuff -- UM, Table 41
VIC  equ  0xFFFFF000    ; VIC Base Address
IntEnable  equ  0x10
VectAddr  equ  0x30
VectAddr0  equ  0x100
VectCtrl0  equ  0x200

Timer0ChannelNumber  equ  4  ; UM, Table 63
Timer0Mask  equ  1<<Timer0ChannelNumber  ; UM, Table 63
IRQslot_en  equ  5    ; UM, Table 58

; GPIO Stuff
IO0DIR  EQU  0xE0028008
IO0SET  EQU  0xE0028004
IO0CLR  EQU  0xE002800C

; Constants
TABLE_LEN equ 8

  AREA  InitialisationAndMain, CODE, READONLY
  IMPORT  main

; (c) Mike Brady, 2014 -- 2019.

  EXPORT  start
start
; initialisation code

  ; initialise SP
  ldr sp, =0x40002000 ; initialise SP to top of stack

  ; Initialise GPIO0
  bl initLed

  ; Initialise the VIC
  ldr  r0,=VIC      ; looking at you, VIC!

  ldr  r1,=irqhan
  str  r1,[r0,#VectAddr0]   ; associate our interrupt handler with Vectored Interrupt 0

  mov  r1,#Timer0ChannelNumber+(1<<IRQslot_en)
  str  r1,[r0,#VectCtrl0]   ; make Timer 0 interrupts the source of Vectored Interrupt 0

  mov  r1,#Timer0Mask
  str  r1,[r0,#IntEnable]  ; enable Timer 0 interrupts to be recognised by the VIC

  mov  r1,#0
  str  r1,[r0,#VectAddr]     ; remove any pending interrupt (may not be needed)

  ; Initialise Timer 0
  ldr  r0,=T0      ; looking at you, Timer 0!

  mov  r1,#TimerCommandReset
  str  r1,[r0,#TCR]

  mov  r1,#TimerResetAllInterrupts
  str  r1,[r0,#IR]

  ldr  r1,=(14745600/1600)-1   ; 1 / 1600 = 1us
  str  r1,[r0,#MR0]

  mov  r1,#TimerModeResetAndInterrupt
  str  r1,[r0,#MCR]

  mov  r1,#TimerCommandRun
  str  r1,[r0,#TCR]

;from here, initialisation is finished, so it should be the main body of the main program

  ;
  ; main
  ;
  ldr r0, =counter
  ldr r4, =table
  ldr r6, =IO0CLR
  ldr r7, =IO0SET
while_true                  ; while(true) {
  mov r2, #0
fori
  cmp r2, #TABLE_LEN        ;   for (int i = 0; i < TABLE_LEN; i++)
  bhs efori                 ;   {
  mov r1, #0                ;     counter = 0
while_not_800               ;     while(counter < 800)
  cmp r1, #800              ;     {
  ldr r1, [r0]              ;       read(counter)
  blo while_not_800         ;     }
  ldr r3, [r4, r2, lsl #2]  ;     table_entry = table[i]
  ldr r5, =0x00260000       ;     mask = P0.21, P0.18-P0.17
  str r5, [r7]              ;     turn_off_leds(mask)
  str r3, [r6]              ;     turn_on_leds(table_entry)
  add r2, #1
  b fori                    ;   }
efori
  b while_true              ; }

wloop  b  wloop      ; branch always
;main program execution will never drop below the statement above.

  AREA  InterruptStuff, CODE, READONLY
irqhan  sub  lr,lr,#4
  stmfd  sp!,{r0-r1,lr}  ; the lr will be restored to the pc

;this is the body of the interrupt handler

;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts

  ldr r0, =counter
  ldr r1, [r0]
  add r1, #1
  str r1, [r0]           ; counter++

;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
  ldr  r0,=T0
  mov  r1,#TimerResetTimer0Interrupt
  str  r1,[r0,#IR]       ; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
  ldr  r0,=VIC
  mov  r1,#0
  str  r1,[r0,#VectAddr]  ; reset VIC

  ldmfd  sp!,{r0-r1,pc}^  ; return from interrupt, restoring pc from lr
        ; and also restoring the CPSR

;
; initLed
; initialise P0.21, P0.18-P0.17 to output and turn them off
; parameters:
;   none
; return:
;   none
;
initLed
  ldr r1, =IO0DIR
  ldr r2, =0x00260000  ;select P0.21, P0.18-P0.17
  str r2, [r1]    ;make them outputs
  ldr r1, =IO0SET
  str r2, [r1]    ;set them to turn the LEDs off
  bx lr

table
  dcd 0x00000000
  dcd 0x00020000
  dcd 0x00040000
  dcd 0x00060000
  dcd 0x00200000
  dcd 0x00220000
  dcd 0x00240000
  dcd 0x00260000

  END
