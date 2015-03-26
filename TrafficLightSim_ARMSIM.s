@ CSC230 --  Traffic Light simulation program
@ Cortland Thibodeau 

@===== STAGE 0
@  	Sets initial outputs and screen for INIT
@ Calls StartSim to start the simulation,
@	polls for left black button, returns to main to exit simulation

        .equ    SWI_EXIT, 		0x11		@terminate program
        @ swi codes for using the Embest board
        .equ    SWI_SETSEG8, 		0x200	@display on 8 Segment
        .equ    SWI_SETLED, 		0x201	@LEDs on/off
        .equ    SWI_CheckBlack, 	0x202	@check press Black button
        .equ    SWI_CheckBlue, 		0x203	@check press Blue button
        .equ    SWI_DRAW_STRING, 	0x204	@display a string on LCD
        .equ    SWI_DRAW_INT, 		0x205	@display an int on LCD  
        .equ    SWI_CLEAR_DISPLAY, 	0x206	@clear LCD
        .equ    SWI_DRAW_CHAR, 		0x207	@display a char on LCD
        .equ    SWI_CLEAR_LINE, 	0x208	@clear a line on LCD
        .equ 	SEG_A,	0x80		@ patterns for 8 segment display
		.equ 	SEG_B,	0x40
		.equ 	SEG_C,	0x20
		.equ 	SEG_D,	0x08
		.equ 	SEG_E,	0x04
		.equ 	SEG_F,	0x02
		.equ 	SEG_G,	0x01
		.equ 	SEG_P,	0x10                
        .equ    LEFT_LED, 	0x02	@patterns for LED lights
        .equ    RIGHT_LED, 	0x01
        .equ    BOTH_LED, 	0x03
        .equ    NO_LED, 	0x00       
        .equ    LEFT_BLACK_BUTTON, 	0x02	@ bit patterns for black buttons
        .equ    RIGHT_BLACK_BUTTON, 0x01
        @ bit patterns for blue keys 
        .equ    Ph1, 		0x0100	@ =8
        .equ    Ph2, 		0x0200	@ =9
        .equ    Ps1, 		0x0400	@ =10
        .equ    Ps2, 		0x0800	@ =11

		@ timing related
		.equ    SWI_GetTicks, 		0x6d	@get current time 
		.equ    EmbestTimerMask, 	0x7fff	@ 15 bit mask for Embest timer
											@(2^15) -1 = 32,767        										
        .equ	OneSecond,	1000	@ Time intervals
        .equ	TwoSecond,	2000
	@define the 2 streets
	@	.equ	MAIN_STREET		0
	@	.equ	SIDE_STREET		1
 
       .text           
       .global _start

@===== The entry point of the program
_start:		
	@ initialize all outputs
	BL Init				@ void Init ()
	@ Check for left black button press to start simulation
RepeatTillBlackLeft:
	swi     SWI_CheckBlack
	cmp     r0, #LEFT_BLACK_BUTTON	@ start of simulation
	beq		StrS
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq     StpS

	bne     RepeatTillBlackLeft
StrS:	
	BL StartSim		@else start simulation: void StartSim()
	@ on return here, the right black button was pressed
StpS:
	BL EndSim		@clear board: void EndSim()
EndTrafficLight:
	swi	SWI_EXIT
	
@ === Init ( )-->void
@   Inputs:	none	
@   Results:  none 
@   Description:
@ 		both LED lights on
@		8-segment = point only
@		LCD = ID only
Init:
	stmfd	sp!,{r0-r2,lr}
	@ LCD = ID on line 1
	mov	r1, #0			@ r1 = row
	mov	r0, #0			@ r0 = column 
	ldr	r2, =lineID		@ identification
	swi	SWI_DRAW_STRING
	mov r1, #1
	ldr r2, =lineID2
	swi SWI_DRAW_STRING
	@ both LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	@ display point only on 8-segment
	mov	r0, #10			@8-segment pattern off
	mov	r1, #1			@point on
	BL	Display8Segment
	@==============================Drawing the Road=============================@
	ldr	r2,=lowRoadLine
	mov	r1, #5			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=highRoadLine
	mov	r1, #9			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	mov r1, #7
	swi SWI_DRAW_STRING
	ldr	r2,=lowRoadLine
	mov	r1, #11			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING

DoneInit:
	LDMFD	sp!,{r0-r2,pc}

@===== EndSim()
@   Inputs:  none
@   Results: none
@   Description:
@      Clear the board and display the last message
EndSim:	
	stmfd	sp!, {r0-r2,lr}
	mov	r0, #10				@8-segment pattern off
	mov	r1,#0
	BL	Display8Segment		@Display8Segment(R0:number;R1:point)
	mov	r0, #NO_LED
	swi	SWI_SETLED
	swi	SWI_CLEAR_DISPLAY
	mov	r0, #5
	mov	r1, #7
	ldr	r2, =Goodbye
	swi	SWI_DRAW_STRING  	@ display goodbye message on line 7
	ldmfd	sp!, {r0-r2,pc}
	
@ === StartSim ( )-->void
@   Inputs:	none	
@   Results:  none 
@   Description:
@ 		XXX
StartSim:
	stmfd	sp!,{r1-r10,lr}	
	mov	r1,#1		@initially start in S1.1
StartCarCycle:
	BL	CarCycle	@int:R0 CarCycle(State:R1 )
	cmp	r0,#0		@check why it returned
	beq	DoneStartSim	@right black was pressed - end simulation
	mov	r1,r0		@else set input to ped cycle place of call
	BL	PedCycle	@void PedCycle( CallPosition:R1);
	cmp	r0,#-1		@check why it returned
	beq	DoneStartSim	@right black was pressed - end simulation
	@on return from PedCycle, go back to correct state in CarCycle
	@test R1 where the call position to PedCycle came from originally
	cmp	r1,#3		@if from I3, go back to S1.1
	beq	S1Car
	mov	r1,#5		@else restart CarCycle from State S5
	bal	StartCarCycle
S1Car:
	mov	r1,#1		@restart CarCycle from State S1.1	
	bal	StartCarCycle

	
RepeatTillBlackRight:
	mov	r0,r2	@get previous LED setting
	eor	r0,r0, #BOTH_LED
	mov	r2,r0	@save LED setting
	swi	SWI_SETLED
	mov	r10,#OneSecond
	BL	Wait	@void Wait(Delay:r10)
	swi     SWI_CheckBlack
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	bne     RepeatTillBlackRight

DoneStartSim:
	LDMFD	sp!,{r1-r10,pc}

	
@====================================CARCYCLE===================================@
CarCycle:
	STMFD	sp!,{r1-r10,lr}
CarCycleLoop:
	cmp r1, #5
	beq Start2	@ If r1 is 5 then it will return to the second start (usually after a ped cycle)
	BL CarState1 @ Car state 1 is called (S1)
	swi SWI_CheckBlack @ I1
	cmp     r0, #RIGHT_BLACK_BUTTON	@ stop simulation
	beq		TerminateProgramCC	@ Terminating the program from Car Cycle
	BL CarState2	@ The wait and poll S2 is started (S2)
	cmp r0, #-1		@ Did it return from a R. black button
	beq TerminateProgramCC	@ Terminate the program
	cmp r0, #1
	beq PedCall	@ Returned from a blue button being pressed and Ped Cycle begins
	BL	CarState3 @ (S3 and S4)

Start2:
	mov r1, #0	@ No confusion on R1 and a Start 2 repeat
	mov	r0, #LEFT_LED	@Left Led is set
	swi	SWI_SETLED
	BL	CarState4	@ Low road cycles are called (S5)
	BL	CarState5	@ (S6 and S7)
	cmp r0, #-1
	beq TerminateProgramCC @ Returned that the R. Black has been pressed
	cmp r0, #3
	beq PedCall	@ Returned from Blue being pressed
	bne		CarCycleLoop @ The infinite Loop
	bal		DoneCarCycle @ If it somehow gets here. It ends the program
PedCall:
	bal DoneCarCycle	@ Skipping the terminate
TerminateProgramCC:
	mov r0, #0	@ 0 is returned to start sim notifying that the program should be terminated
	
DoneCarCycle:
	LDMFD	sp!,{r1-r10,pc}
@==================================ENDCARCYCLE==================================@

@===================================CARSTATES===================================@

CarState1:
	STMFD	sp!,{r1-r10,lr}
	mov r9, #0	@ Counter
	mov	r0, #LEFT_LED
	swi	SWI_SETLED	@ Set LED
	mov	r0, #10			@8-segment pattern off
	mov	r1, #1			@point on
	BL	Display8Segment
CarLoop1:	
	mov r10, #1	@ State and screen set
	BL	DrawScreen
	BL	DrawState
	mov r10, #TwoSecond 
	BL	Wait	@ Two second wait called
	mov r10, #2	@ Screen and state are set
	BL	DrawScreen
	mov	r10, #1
	BL	DrawState
	mov r10, #OneSecond
	BL	Wait	@ One second wait
	add r9,r9,#1	@ Counter
	cmp r9, #4	@ Is the counter done 
	bne CarLoop1	@ Counter loop call
	bal DoneCarState1
DoneCarState1:
	LDMFD	sp!,{r1-r10,pc}
@-------------------------------------------------------------------------------@	
CarState2:
	STMFD	sp!,{r1-r10,lr}
	mov r9, #0	@ Counter
CarLoop2:	
	mov r10, #1	@ Screen and state are called and set
	BL	DrawScreen
	mov r10, #2
	BL	DrawState
	mov r10, #TwoSecond
	BL	WaitAndPoll	@ The two second wait and poll
	cmp r0, #-1
	beq DoneCarState2	@ Black button ^
	cmp r0, #1
	beq DoneCarState2	@ Blue button ^
	mov r10, #2	@ The screen and state are called/set
	BL	DrawScreen
	BL	DrawState
	mov r10, #OneSecond
	BL	WaitAndPoll @ Same wait and poll as above but with 1 sec.
	cmp r0, #-1
	beq DoneCarState2
	cmp r0, #1
	beq DoneCarState2
	add r9,r9,#1	@ Loop calls and counter addition
	cmp r9, #2
	bne CarLoop2
	bal DoneCarState2
DoneCarState2:
	LDMFD	sp!,{r1-r10,pc}
@-------------------------------------------------------------------------------@
CarState3:
	STMFD	sp!,{r1-r10,lr}
	mov	r0, #10			@8-segment pattern off
	mov	r1, #0			@point off
	BL	Display8Segment
	mov r10, #3	@ The screen and state are set
	BL	DrawScreen
	BL	DrawState
	mov r10, #TwoSecond	@ Two second wait
	BL	Wait
	mov	r0, #BOTH_LED	@ Both leds come on
	swi	SWI_SETLED
	mov r10, #4	@ Screen and state
	BL	DrawScreen
	BL	DrawState
	mov r10, #OneSecond
	BL	Wait	@ Wait one second
	bal DoneCarState3 @ Tis done
DoneCarState3:
	LDMFD	sp!,{r1-r10,pc}
@-------------------------------------------------------------------------------@
CarState4:
	STMFD	sp!,{r1-r10,lr}
	mov	r0, #RIGHT_LED
	swi	SWI_SETLED
	mov r9, #0
	mov	r0, #10			@8-segment pattern off
	mov	r1, #1			@point on
	BL	Display8Segment
CarLoop4:
	mov r10, #5
	BL	DrawScreen
	BL	DrawState
	mov r10, #TwoSecond
	BL	Wait
	add r9,r9,#1
	cmp r9, #3
	bne CarLoop4	@ This loop does the S5 green loop for the low road
	bal DoneCarState4
DoneCarState4:
	LDMFD	sp!,{r1-r10,pc}
@-------------------------------------------------------------------------------@
CarState5:
	STMFD	sp!,{r1-r10,lr}
	mov	r0, #10			@8-segment pattern off
	mov	r1, #0			@point off
	BL	Display8Segment
	mov	r0, #RIGHT_LED
	swi	SWI_SETLED
	mov r10, #6	@ States and Screen
	BL	DrawScreen
	BL	DrawState
	mov r10, #TwoSecond
	BL	Wait	@ Pls wait for 2 seconds
	mov	r0, #BOTH_LED
	swi	SWI_SETLED	@ Set the LEDS
	mov r10, #4
	BL	DrawScreen
	mov r10, #7
	BL	DrawState	@ Screen and State
	mov r10, #OneSecond
	BL	Wait	@ Wait and poll and the end just to save typing on checking switches. Doesnt make too big of a dif with the 1 second wait
@----------------------------------------I3-------------------------------------@
	swi SWI_CheckBlue @ Checks all the blues if true goes to Done2
	cmp r0, #Ph1
	beq PedCallI3
	cmp r0, #Ph2
	beq PedCallI3
	cmp r0, #Ps1
	beq PedCallI3
	cmp r0, #Ps2
	beq PedCallI3
	swi SWI_CheckBlack	@ Checks the R. Black and goes to Done1 if trued
	cmp r0, #RIGHT_BLACK_BUTTON
	beq TerminateCS5
	bal DoneCarState5
TerminateCS5:	
	mov r0, #-1
	bal DoneCarState5
PedCallI3:
	mov r0, #3	@ Changing the return so that it knows where the ped call is coming from
DoneCarState5:
	LDMFD	sp!,{r1-r10,pc}
	
@=================================ENDCARSTATES==================================@

@===================================PEDCYLCE====================================@
PedCycle:
	STMFD	sp!,{r2-r10,lr}
	mov	r0, #BOTH_LED
	swi	SWI_SETLED
	cmp r1, #3	@ Came from I3
	beq PedStart2
	BL PedState1	@ does the lights first
PedStart2:
	BL PedState2	@ Second Ped start
DonePedCycle:
	LDMFD	sp!,{r2-r10,pc}
@=================================DONEPEDCYCLE==================================@

@===================================PEDSTATES===================================@
PedState1: @ This is the lights coming from I1 or I2 
	STMFD	sp!,{r2-r10,lr}
	mov	r0, #10			@8-segment pattern off
	mov	r1, #0			@point on
	BL	Display8Segment
	mov r10, #3
	BL	DrawScreen
	mov r10, #8
	BL	DrawState
	mov r10, #TwoSecond
	BL	Wait
	mov r10, #4
	BL	DrawScreen
	mov r10, #9
	BL	DrawState
	mov r10, #OneSecond
	BL	Wait
	bal DonePedState1
DonePedState1:
	LDMFD	sp!,{r2-r10,pc}

@-------------------------------------------------------------------------------@	
@ This is the REAL ped crossing cycle where the countdown
@ occurs as well as !!! amd XXX
PedState2:
	STMFD	sp!,{r2-r10,lr}
	mov r10, #7
	BL	DrawScreen
	mov r10, #10
	BL	DrawState
	mov r0, #6
	BL	Display8Segment
	mov r10, #OneSecond
	BL	Wait
	mov r0, #5
	BL	Display8Segment
	BL	Wait
	mov r0, #4
	BL	Display8Segment
	BL	Wait
	mov r0, #3
	BL	Display8Segment
	BL	Wait
	mov r10, #8
	BL	DrawScreen
	mov r10, #11
	BL	DrawState
	mov	r0, #2
	BL	Display8Segment
	mov r10, #OneSecond
	BL	Wait
	mov r0, #1
	BL	Display8Segment
	BL	Wait
	mov r10, #4
	BL	DrawScreen
	mov r10, #12
	BL	DrawState
	mov r0, #0
	BL Display8Segment
	mov r10, #OneSecond
	BL	WaitAndPoll
	cmp r0, #RIGHT_BLACK_BUTTON
	beq TerminateFromPedCycle
	bal DonePedState2
TerminateFromPedCycle:
	mov r0, #0
DonePedState2:
	LDMFD	sp!,{r2-r10,pc}
@=================================DONEPEDSTATES=================================@

@ ==== void Wait(Delay:r10) 
@   Inputs:  R10 = delay in milliseconds
@   Results: none
@   Description:
@      Wait for r10 milliseconds using a 15-bit timer 
Wait:
	stmfd	sp!, {r0-r2,r7-r10,lr}
	ldr     r7, =EmbestTimerMask
	swi     SWI_GetTicks		@get time T1
	and		r1,r0,r7			@T1 in 15 bits
WaitLoop:
	swi SWI_GetTicks			@get time T2
	and		r2,r0,r7			@T2 in 15 bits
	cmp		r2,r1				@ is T2>T1?
	bge		simpletimeW
	sub		r9,r7,r1			@ elapsed TIME= 32,676 - T1
	add		r9,r9,r2			@    + T2
	bal		CheckIntervalW
simpletimeW:
		sub		r9,r2,r1		@ elapsed TIME = T2-T1
CheckIntervalW:
	cmp		r9,r10				@is TIME < desired interval?
	blt		WaitLoop
WaitDone:
	ldmfd	sp!, {r0-r2,r7-r10,pc}	
	
@ ==== int:R0 WaitAndPoll(Delay:r10) 
@   Inputs:  R10 = delay in milliseconds
@   Results:	0=>interval finished
@				-1=>stop simulation (right black button)
@				1=>blue button number for pedestrian requestl
@   Description:
@      Wait for r10 milliseconds using a 15-bit timer while polling
@		Stay for the interval unless there is a pedestrian request 
@		(blue button or an end of simulation request (right black button)
@	  **THIS IS THE SAME AS WAIT EXPECT IT CHECKS SWI IN CHECKINTERVAL**

@================================WAITANDPOLL====================================@
WaitAndPoll:
	stmfd	sp!,{r1-r10,lr}
	ldr     r7, =EmbestTimerMask
	swi     SWI_GetTicks		@get time T1
	and		r1,r0,r7			@T1 in 15 bits
WaitLoopP:
	
	swi SWI_GetTicks			@get time T2
	and		r2,r0,r7			@T2 in 15 bits
	cmp		r2,r1				@ is T2>T1?
	bge		simpletimeWP
	sub		r9,r7,r1			@ elapsed TIME= 32,676 - T1
	add		r9,r9,r2			@    + T2
	bal		CheckIntervalWP
simpletimeWP:
		sub		r9,r2,r1		@ elapsed TIME = T2-T1
CheckIntervalWP:
	swi SWI_CheckBlack	@ Checks the R. Black and goes to Done1 if trued
	cmp r0, #RIGHT_BLACK_BUTTON
	beq Done1
	swi SWI_CheckBlue @ Checks all the blues if true goes to Done2
	cmp r0, #Ph1
	beq Done2
	cmp r0, #Ph2
	beq Done2
	cmp r0, #Ps1
	beq Done2
	cmp r0, #Ps2
	beq Done2
	cmp		r9,r10				@is TIME < desired interval?
	blt		WaitLoopP
	mov r0, #0
	bal DoneWaitAndPoll
Done2:	
	mov r0, #1	@ Shows that the call is a ped call (return) then skips done1
	bal DoneWaitAndPoll
Done1:
	mov r0, #-1	@ Ending the program from wait and poll through returning -1 to the top
DoneWaitAndPoll:
	LDMFD	sp!,{r1-r10,pc}
@==============================DONEWAITANDPOLL==================================@
	
@ *** void Display8Segment (Number:R0; Point:R1) ***
@   Inputs:  R0=bumber to display; R1=point or no point
@   Results:  none
@   Description:
@ 		Displays the number 0-9 in R0 on the 8-segment
@ 		If R1 = 1, the point is also shown
Display8Segment:
	STMFD 	sp!,{r0-r2,lr}
	ldr 	r2,=Digits
	ldr 	r0,[r2,r0,lsl#2]
	tst 	r1,#0x01 @if r1=1,
	orrne 	r0,r0,#SEG_P 			@then show P
	swi 	SWI_SETSEG8
	LDMFD 	sp!,{r0-r2,pc}
	
@ *** void DrawScreen (PatternType:R10) ***
@   Inputs:  R10: pattern to display according to state
@   Results:  none
@   Description:
@ 		Displays on LCD screen the 5 lines denoting
@		the state of the traffic light
@	Possible displays:
@	1 => S1.1 or S2.1- Green High Street
@	2 => S1.2 or S2.2	- Green blink High Street
@	3 => S3 or P1 - Yellow High Street   
@	4 => S4 or S7 or P2 or P5 - all red
@	5 => S5	- Green Side Road
@	6 => S6 - Yellow Side Road
@	7 => P3 - all pedestrian crossing
@	8 => P4 - all pedestrian hurry

@@@ NOTE: State number on upper right corner is shown
@@@ 		by procedure void DrawState (PatternType:R10)
@@@			called from within each state before calling
@@@			this DrawScreen

@==================================DrawScreen===================================@
DrawScreen:
	STMFD 	sp!,{r0-r2,lr}
	cmp	r10,#1
	beq	S11
	cmp	r10,#2
	beq	S12
	cmp	r10,#3
	beq	S3
	cmp r10,#4
	beq S4
	cmp r10,#5
	beq S5
	cmp r10,#6
	beq S6
	cmp r10,#7
	beq P3
	cmp r10,#8
	beq P4
	bal	EndDrawScreen

S11:
	ldr	r2,=line1S11
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S11
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S11
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen

S12:
	ldr	r2,=line1S12
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S12
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S12
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen

S3:
	ldr	r2,=line1S3
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S3
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S3
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen

S4:
	ldr	r2,=line1S4
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S4
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S4
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen

S5:
	ldr	r2,=line1S5
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S5
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S5
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
S6:
	ldr	r2,=line1S6
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S6
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S6
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
P3:
	ldr	r2,=line1P3
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P3
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P3
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
	
P4:
	ldr	r2,=line1P4
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P4
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P4
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
 
EndDrawScreen:
	LDMFD 	sp!,{r0-r2,pc}

@================================ENDDRAWSCREEN==================================@
	
@ *** void DrawState (PatternType:R10) ***
@   Inputs:  R10: number to display according to state
@   Results:  none
@   Description:
@ 		Displays on LCD screen the state number
@		on top right corner

@=================================DrawState=====================================@
DrawState:
	STMFD 	sp!,{r0-r2,lr}
	cmp	r10,#1
	beq	S1draw
	cmp	r10,#2
	beq	S2draw
	cmp	r10,#3
	beq	S3draw
	cmp r10,#4
	beq S4draw
	cmp r10,#5
	beq S5draw
	cmp r10,#6
	beq S6draw
	cmp r10,#7
	beq S7draw
	cmp r10,#8
	beq P1draw
	cmp r10,#9
	beq P2draw
	cmp r10,#10
	beq P3draw
	cmp r10,#11
	beq P4draw
	cmp r10,#12
	beq P5draw
	bal	EndDrawScreen

S1draw:
	ldr	r2,=S1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

S2draw:
	ldr	r2,=S2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

S3draw:
	ldr	r2,=S3label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

S4draw:
	ldr	r2,=S4label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

S5draw:
	ldr	r2,=S5label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

S6draw:
	ldr	r2,=S6label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

S7draw:
	ldr	r2,=S7label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

P1draw:
	ldr	r2,=P1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

P2draw:
	ldr	r2,=P2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

P3draw:
	ldr	r2,=P3label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

P4draw:
	ldr	r2,=P4label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState

P5draw:
	ldr	r2,=P5label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
	
EndDrawState:
	LDMFD 	sp!,{r0-r2,pc}

@=================================ENDDRAWSTATE==================================@
	
@@@@@@@@@@@@=========================
	.data
	.align
Digits:							@ for 8-segment display
	.word SEG_A|SEG_B|SEG_C|SEG_D|SEG_E|SEG_G 	@0
	.word SEG_B|SEG_C 							@1
	.word SEG_A|SEG_B|SEG_F|SEG_E|SEG_D 		@2
	.word SEG_A|SEG_B|SEG_F|SEG_C|SEG_D 		@3
	.word SEG_G|SEG_F|SEG_B|SEG_C 				@4
	.word SEG_A|SEG_G|SEG_F|SEG_C|SEG_D 		@5
	.word SEG_A|SEG_G|SEG_F|SEG_E|SEG_D|SEG_C 	@6
	.word SEG_A|SEG_B|SEG_C 					@7
	.word SEG_A|SEG_B|SEG_C|SEG_D|SEG_E|SEG_F|SEG_G @8
	.word SEG_A|SEG_B|SEG_F|SEG_G|SEG_C 		@9
	.word 0 									@Blank 
	.align
lineID:		.asciz	"              Traffic Light"
lineID2:	.asciz	"      Cortland Thibodeau, V00772904"
highRoadLine:	.asciz  "-----         -----"
lowRoadLine:	.asciz  "     |       |     "

@ patterns for all states on LCD
line1S11:		.asciz	"     |  R W  |     "
line3S11:		.asciz	"GGG W         GGG W"
line5S11:		.asciz	"     |  R W  |     "

line1S12:		.asciz	"     |  R W  |     "
line3S12:		.asciz	"  W             W  "
line5S12:		.asciz	"     |  R W  |     "

line1S3:		.asciz	"     |  R W  |     "
line3S3:		.asciz	"YYY W         YYY W"
line5S3:		.asciz	"     |  R W  |     "

line1S4:		.asciz	"     |  R W  |     "
line3S4:		.asciz	" R W           R W "
line5S4:		.asciz	"     |  R W  |     "

line1S5:		.asciz	"     | GGG W |     "
line3S5:		.asciz	" R W           R W "
line5S5:		.asciz	"     | GGG W |     "

line1S6:		.asciz	"     | YYY W |     "
line3S6:		.asciz	" R W           R W "
line5S6:		.asciz	"     | YYY W |     "

line1P3:		.asciz	"     | R XXX |     "
line3P3:		.asciz	"R XXX         R XXX"
line5P3:		.asciz	"     | R XXX |     "

line1P4:		.asciz	"     | R !!! |     "
line3P4:		.asciz	"R !!!         R !!!"
line5P4:		.asciz	"     | R !!! |     "

S1label:		.asciz	"S1"
S2label:		.asciz	"S2"
S3label:		.asciz	"S3"
S4label:		.asciz	"S4"
S5label:		.asciz	"S5"
S6label:		.asciz	"S6"
S7label:		.asciz	"S7"
P1label:		.asciz	"P1"
P2label:		.asciz	"P2"
P3label:		.asciz	"P3"
P4label:		.asciz	"P4"
P5label:		.asciz	"P5"

Goodbye:
	.asciz	"*** Traffic Light program ended ***"

	.end
