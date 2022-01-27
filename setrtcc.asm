00000 ; SOURCE
00010 ;******************************************************
00020 ;*        Setrtcc routine  for U-bus RTCC             *
00030 ;*        Electrickery Utilities (c) 1989             *
00040 ;*        'Distributed by Kraantronics'               *
00050 ;*       Written by F.J. Kraan 6 mei 1989             *
00060 ;*           Latest update 12 december 1989          *
00070 ;******************************************************
00100 	ORG	05200H		; Default start point
00105 SETRTCC	JP	START
00110 DAT	EQU	132D		; Port A data address
00120 ADR	EQU	133D		; Port B address address
00130 CON	EQU	134D		; Port C r/w cntl.address
00140 PCTL	EQU	135D		; Pia control word addres
00141 HOUR	EQU	16451D		; Dos hour byte
00142 MINIT	EQU	16450D		; Dos minit byte address
00143 SECON	EQU	16449D		; Dos seconds byte addres
00144 DOS	EQU	402DH		; Dos reentry
00145 YEAR	EQU	16452D		; Dos year byte address
00146 MONTH	EQU	16554D		; Dos month byte address
00147 DAY	EQU	16553D		; Dos day byte address
00150 DOSDISP	EQU	4467H		; Dos' display routine
00160 CWR	EQU	128D		; Cntl.word write port A
00170 CRD	EQU	144D		; Cntl.word read port A
00180 
00185 MOFF	EQU	0		; RTC	any mode off
00190 HOLD	EQU	16D		; RTC hold 
00200 READ	EQU	48D		; RTC hold + read
00210 WRITE	EQU	80D		; RTC hold + write
00220 LPTIM	EQU	46D		; Wait const 150uS @4MHz
00230 SLEAP	EQU	1D		; Leap year flag set
00240 RLEAP	EQU	0D		; Leap year flag reset
00250 MASK	EQU	011B		; used for H10 and D10
00251 SEC1	EQU	0		; Rtc single seconds
00252 SEC10	EQU	1		; Rtc decade seconds
00253 MIN1	EQU	2		; Rtc single minutes
00254 MIN10	EQU	3		; RTC decade minutes
00255 HOUR1	EQU	4		; Rtc single hours
00256 HOUR10	EQU	5		; Rtc decade hours+flags
00257 DOW	EQU	6		; Rtc day of week
00258 DAY1	EQU	7		; Rtc single day 
00259 DAY10	EQU	8		; Rtc decade day
00260 MNTH1	EQU	9		; Rtc single month
00261 MNTH10	EQU	10D		; Rtc decade month+flags
00262 YEAR1	EQU	11D		; Rtc single years
00263 YEAR10	EQU	12D		; RTC decade years
00264 S1	DEFB	'x'
00265 S10	DEFB	'x'
00266 MI1	DEFB	'x'
00267 MI10	DEFB	'x'
00268 H1	DEFB	'x'
00269 H10	DEFB	'x'
00270 W	DEFB	0
00271 D1	DEFB	'x'
00272 D10	DEFB	'x'
00273 MO1	DEFB	'x'
00274 MO10	DEFB	'x'
00275 Y1	DEFB	'x'
00276 Y10	DEFB	'x'
00280 TSECON	DEFB	'x'
00281 TMINIT	DEFB	'x'
00282 THOUR	DEFB	'x'
00283 TYEAR	DEFB	'x'
00284 TDAY	DEFB	'x'
00285 TMONTH	DEFB	'x'
00286 MES1	DEFM	'Electrickery Utilities (c) 1989'
00287 	DEFB	0DH
00288 MES2	DEFM	'U-bus RTCC is set.'
00289 	DEFB	0DH
00310 PPINIT	LD	A,CWR
00320 	LD	B,0
00330 	LD	C,PCTL
00340 	OUT	(C),A
00350 	LD	A,MOFF
00360 	LD	C,CON
00370 	OUT	(C),A
00380 	RET
00390 
00400 SETHOLD	LD	A,HOLD
00410 	LD	C,CON
00420 	OUT	(C),A
00430 	RET
00440 
00450 RSTHOLD	LD	A,MOFF
00460 	LD	C,CON
00470 	OUT	(C),A
00480 	RET
00490 
00500 CONVBN	EQU	$
00510 ; This routine makes from a byte two BCD nibbles.
00520 ; At entry the byte should be in A and at exit the 
00530 ; resulting nibbles are in B (MSN) and C (LSN).
00540 	LD	B,0
00550 AGAIN	SUB	10D
00560 	JP	C,ENDCON
00570 	INC	B
00580 	JP	AGAIN
00590 ENDCON	ADD	A,10D
00600 	LD	C,A
00610 	RET
00700 CONVERT	EQU	$
00710 	LD	A,(TSECON)
00720 	CALL	CONVBN
00730 	LD	(S1),BC
00740 	LD	A,(TMINIT)
00750 	CALL	CONVBN
00760 	LD	(MI1),BC
00770 	LD	A,(THOUR)
00780 	CALL	CONVBN
00790 	LD	(H1),BC
00800 	LD	A,(TDAY)
00810 	CALL	CONVBN
00820 	LD	(D1),BC
00830 	LD	A,(TMONTH)
00840 	CALL	CONVBN
00850 	LD	(MO1),BC
00860 	LD	A,(TYEAR)
00870 	CALL	CONVBN
00880 	LD	(Y1),BC
00890 	RET
00895 
00900 AJUST	EQU	$
00911 	LD	A,(MO10)
00913 	OR	A
00915 	JP	NZ,NOLEAP
00917 	CP	3
00919 	JP	NC,NOLEAP
00925 	LD	A,(TYEAR)
00927 	SRL	A
00930 	JP	C,NOLEAP
00940 	SRL	A
00950 	JP	C,NOLEAP
00960 	LD	A,(D10)
00970 	SET	2,A		; Set leap year flag in 
00980 	LD	(D10),A		; month 1 and 2 of years
00990 NOLEAP	EQU $			; devidable by 4.
01000 	LD	A,(H10)
01010 	SET	3,A		; Set 24 hour format
01020 	LD	(H10),A
01030 	RET
01040 
01400 GETDOS	EQU	$
01410 	LD	HL,SECON
01420 	LD	DE,TSECON
01430 	LD	B,0
01440 	LD	C,6
01445 	DI
01450 	LDIR
01455 	EI
01460 	RET
01470 
01500 MESSAG	EQU	$
01510 	LD	HL,MES1
01520 	CALL	DOSDISP
01530 	LD	HL,MES2
01540 	CALL	DOSDISP
01550 	RET
01560 
01600 W150US	NOP			; Keep 1st byte free
01601 ; This is a 150uS wait routine at the cpu clock speed
01602 ; of 4 MHz. At this speed the DJNZ instruction takes
01603 ; about 3.25 uS, so 46 should be enough. 
01605 	PUSH	BC		; Save B register
01610 	LD	B,46		; Init wait loop
01620 WAIT	DJNZ	WAIT		; Wait
01625 	POP	BC		; Retreive B register
01630 	RET			; Back
01640 
02000 WRRTC	EQU	$
02001 	DI
02010 	LD	HL,S1
02020 	LD	E,0
02022 LOOP	LD	C,ADR
02024 	LD	A,E
02026 	OUT	(C),A		; Set RTCC address
02030 	LD	C,DAT
02040 	LD	A,(HL)
02050 	OUT	(C),A		; Set RTCC data
02060 	LD	A,WRITE
02070 	LD	C,CON
02080 	OUT	(C),A		; Start RTCC write puls
02085 	NOP
02090 	LD	A,HOLD
02100 	OUT	(C),A		; Stop RTCC write puls
02110 	INC	HL
02120 	INC	E
02130 	LD	A,E
02140 	CP	13D
02150 	JP	NZ,LOOP
02155 	EI
02160 	RET
02170 
03000 START	CALL	PPINIT
03010 	CALL	GETDOS		; Get dos time and date
03020 	CALL	CONVERT		; CHange bytes to nibbles
03025 	CALL	AJUST		; Check for leap year etc
03030 	CALL	SETHOLD		; Hold the RTC 
03035 	CALL	W150US		; Wait 150 us at 4 MHz
03040 	CALL	WRRTC		; Write prepared data
03045 	CALL	RSTHOLD		; Lift RTC hold
03065 	CALL	MESSAG		; Show its finished
03070 	JP	DOS
