#include	"msp430.h"
; author: Diego Figueroa Velez
; date: 07/15/15
; title: Traffic Light System (TLS)
;-------------------------------------------------------------------------------
		ORG		0C000h					; Program Start
;-------------------------------------------------------------------------------
;		Housekeeping and Boot-up
; In this segment, initialize Port1 as output for the LEDs and Port2 as I/O
; interface for button interrupts. In Port1, the most significant nibble corresponds
; to the main street traffic lights and the least significant nibble corresponds
; to the secondary street traffic lights. In Port2: bit 0 is the Primary MAIN lane,
; bit 1 is the Primary LEFT lane, bit 2 is the Secondary MAIN lane and bit 3 is
; the Secondary LEFT lane. Start up begins with Primary MAIN routine.
;-------------------------------------------------------------------------------
RESET		mov.w		#0400h,SP				; Initialize SP
StopWDT		mov.w		#WDTPW+WDTHOLD,&WDTCTL			; Stop WDT
SetupACLK	bis.b		#DIVA_3,&BCSCTL1			; source ACLK/8
		bis.b		#XCAP_3,&BCSCTL3			; 12.5 pF capacitor
SetupP1		bic.b		#11111111b,&P1OUT			; LEDs off
		bis.b		#11111111b,&P1DIR			; P1.0 to 1.7 as output
		bis.b		#00100010b,&P1OUT			; STOP on both
SetupP2		bic.b		#00001111b,&P2SEL			; P2.0 to 2.3 can interrupt
		bic.b		#00001111b,&P2DIR			; P2.0 to 2.3 as input
		bic.b		#00001111b,&P2IFG			; reset interrupt flags
		bis.b		#00001111b,&P2REN			; select internal resistors
		bis.b		#00001111b,&P2OUT			; make it pull-up
		bis.b		#00001111b,&P2IE			; enable P2 interrupts
SetupRegs	mov.w		#0,R15					; clear R15
		mov.w		#0,R14					; clear R14
		mov.w		#0,R13					; clear R13
SetupC0		mov.w		#CCIE,&CCTL0				; enable CCR0 interrupts
		mov.w		#512,&CCR0				; count 512 cycles
		call		#Tint					; 1 second before starting sequence
;-------------------------------------------------------------------------------
;		Primary MAIN Routine
;-------------------------------------------------------------------------------
PMAIN		mov.b		#00001110b,&P2IE			; disable interrupts from Primary
		bic.b		#00000001b,R15				; clear sensor status
		bic.b		#00100000b,&P1OUT			; PSTOP off
		bis.b		#10000000b,&P1OUT			; PGO on
		call		#Tmin					; wait 5s
;-------------------------------------------------------------------------------
;		Polling
; Check if any lane has cars, using the R15 as a queue.
;-------------------------------------------------------------------------------
Poll		bit.b		#00000001b,R15				; Check if Primary has cars
		jnz		PMAIN					; Go to Primary MAIN
		bit.b		#00000010b,R15				; Check if Primary LEFT has cars
		jnz		PLEFT					; Go to Primary LEFT
		bit.b		#00000100b,R15				; Check if Secondary has cars
		jnz		SMAIN					; Go to Secondary MAIN
		bit.b		#00001000b,R15				; Check if Secondary LEFT has cars
		jnz		SLEFT					; Go to Secondary LEFT
		jmp		Poll					; Keep waiting for cars
;-------------------------------------------------------------------------------
;		Check subroutine
; Checks if Primary MAIN lane is on, if it is: turn it off. Return otherwise.
;-------------------------------------------------------------------------------
Check		mov.b		#00001111b,&P2IE			; enable interrupts from sensors
		bit.b		#10000000b,&P1OUT			; test if Primary is on
		jz		Return					; it is off, return
		xor.b		#11000000b,&P1OUT			; go from GO to SLOW
		call		#Tint					; wait 1s
		xor.b		#01100000b,&P1OUT			; go from SLOW to STOP
		call		#Tint					; wait 1s
Return		ret
;-------------------------------------------------------------------------------
;		Primary LEFT routine
;-------------------------------------------------------------------------------
PLEFT		call		#Check					; disable Primary
		bic.b		#00000010b,R15				; clear sensor status
                bic.b           #00100000b,&P1OUT                       ; STOP off
		bis.b		#00010000b,&P1OUT			; PLEFT on
		mov.b		#3,R14					; count up to 9s if needed
L1		bic.b		#00000010b,R15				; clear sensor status
		call		#Tsec					; wait 3s
		dec		R14					; 3s have passed
		cmp		#0,R14					; check if 9s have passed
		jeq		TogglePL				; 9s have passed
		bit.b		#00000010b,R15				; check if there are still cars
		jnz		L1					; there are still cars, repeat
TogglePL	mov.b		#00001101b,&P2IE			; disable interrupts from PrimaryL
		xor.b		#01010000b,&P1OUT			; go from LEFT to SLOW
		call		#Tint					; wait 1s
		xor.b		#01100000b,&P1OUT			; go from SLOW to STOP
		call		#Tint					; wait 1s
		bit.b		#00001111b,R15				; check if there are cars in other lanes
		jnz		Poll					; if there are, find in what lane
		jmp		PMAIN					; jump to Main if otherwise
;-------------------------------------------------------------------------------
;		Secondary MAIN routine
;-------------------------------------------------------------------------------
SMAIN		call		#Check					; disable Primary
		bic.b		#00000100b,R15				; clear sensor status
		bic.b		#00000010b,&P1OUT			; STOP off
		bis.b		#00001000b,&P1OUT			; SGO on
		mov.b		#3,R14					; count up to 9s if needed
L2		bic.b		#00000100b,R15				; clear sensor status
		call		#Tsec					; wait 3s
		dec		R14					; 3s have passed
		cmp		#0,R14					; check if 9s have passed
		jeq		ToggleSM				; 9s have passed
		bit.b		#00000100b,R15				; check if there are still cars
		jnz		L2					; there are still cars, repeat
ToggleSM	mov.b		#00001011b,&P2IE			; disable interrupts from Secondary		
		xor.b		#00001100b,&P1OUT			; go from GO to SLOW
		call		#Tint					; wait 1s
		xor.b		#00000110b,&P1OUT			; go from SLOW to STOP
		call		#Tint					; wait 1s
		bit.b		#00001111b,R15				; check if there are cars in other lanes
		jnz		Poll					; if there are, find in what lane
		jmp		PMAIN					; jump to Main if otherwise
;-------------------------------------------------------------------------------
;		Secondary LEFT routine
;-------------------------------------------------------------------------------
SLEFT		call		#Check					; disable Primary
		bic.b		#00001000b,R15				; clear sensor status
                bic.b           #00000010b,&P1OUT			; STOP off
		bis.b		#00000001b,&P1OUT			; SLEFT on
		mov.b		#3,R14					; count up to 9s if needed
L3		bic.b		#00001000b,R15				; clear sensor status
		call		#Tsec					; wait 3s
		dec		R14					; 2.5s have passed
		cmp		#0,R14					; check if 10s have passed
		jeq		ToggleSL				; 10s have passed
		bit.b		#00001000b,R15				; check if there are still cars
		jnz		L3					; there are still cars, repeat
ToggleSL	mov.b		#00000111b,&P2IE			; disable interrupts from SecondaryL
		xor.b		#00000101b,&P1OUT			; go from LEFT to SLOW
		call		#Tint					; wait 1s
		xor.b		#00000110b,&P1OUT			; go from SLOW to STOP
		call		#Tint					; wait 1s
		bit.b		#00001111b,R15				; check if there are cars in other lanes
		jnz		Poll					; if there are, find in what lane
		jmp		PMAIN					; jump to Main if otherwise
;-------------------------------------------------------------------------------
;		Tmin subroutine (5s)
; Minimum interval that has to pass for the Primary MAIN lane before changing lights.
;-------------------------------------------------------------------------------
Tmin		mov.w		#TASSEL_1+MC_1+ID_3,&TACTL		; source ACLK, up mode
		mov.w		#5,R13					; count 5s
Lmin		bis.w		#GIE+LPM0,SR				; enable interrupts and LPM0
		dec		R13					; a second has passed
		cmp		#0,R13					; count over?
		jne		Lmin					; No, again
		mov.w		#MC_0+TACLR,&TACTL			; stop and reset ACLK
		ret
;-------------------------------------------------------------------------------
;		Tsec subroutine (3s)
; Interval used for non-priority lanes.
;-------------------------------------------------------------------------------
Tsec		mov.w		#TASSEL_1+MC_1+ID_3,&TACTL		; source ACLK, up mode
		mov.w		#3,R13					; count 3s
Lsec		bis.w		#GIE+LPM0,SR				; enable interrupts and LPM0
		dec		R13					; a second has passed
		cmp		#0,R13					; count over?
		jne		Lsec					; No, again
		mov.w		#MC_0+TACLR,&TACTL			; stop and reset ACLK
		ret
;-------------------------------------------------------------------------------
;		Tint subroutine (1s)
; Interval routine used in between light changes.
;-------------------------------------------------------------------------------
Tint		mov.w		#TASSEL_1+MC_1+ID_3,&TACTL		; source ACLK, up mode
		bis.w		#GIE+LPM0,SR				; enable interrupts and LPM0
		mov.w		#MC_0+TACLR,&TACTL			; stop and reset ACLK
		ret
;-------------------------------------------------------------------------------
;		Button Interrupt Service Routine
; Checks where interrupts come from and adds to queue using the R15.
;-------------------------------------------------------------------------------
P2_ISR		bit.b		#00000001b,&P2IFG			; check if interrupt comes from P2.0
		jnz		P0					; if it does, jump
		bit.b		#00000010b,&P2IFG			; check if interrupt comes from P2.1
		jnz		P1					; if it does, jump
		bit.b		#00000100b,&P2IFG			; check if interrupt comes from P2.2
		jnz		P2					; if it does, jump
		bit.b		#00001000b,&P2IFG			; check if interrupt comes from P2.3
		jnz		P3					; if it does, jump
P0		bis.b		#00000001b,R15				; assign flag to P2.0
		bic.b		#00000001b,&P2IFG			; clear interrupt flag
		jmp		RetInt
P1		bis.b		#00000010b,R15				; assign flag to P2.1
		bic.b		#00000010b,&P2IFG			; clear interrupt flag
		jmp		RetInt
P2		bis.b		#00000100b,R15				; assign flag to P2.2
		bic.b		#00000100b,&P2IFG			; clear interrupt flag
		jmp		RetInt
P3		bis.b		#00001000b,R15				; assign flag to P2.3
		bic.b		#00001000b,&P2IFG			; clear interrupt flag
RetInt		reti
;-------------------------------------------------------------------------------
;		Timer_A0 Interrupt Service Routine
; Used to count time and wakes the CPU when count is done.
;-------------------------------------------------------------------------------
TA0_ISR		bic.b		#CPUOFF, 0(SP)				; exit LPM0 on RETI
		reti
;-------------------------------------------------------------------------------
;		Interrupt Vectors
;-------------------------------------------------------------------------------
		ORG		0FFFEh					; MSP430 RESET address
		DW		RESET
		ORG		0FFF2h					; Timer_A0 CCR0 interrupt address
		DW		TA0_ISR
		ORG		0FFE6h					; P2 I/0 interrupt address
		DW		P2_ISR
		END