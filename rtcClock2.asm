;           RTC & CTC demo program for MicroProfessor MPF-I(B)

; Based on Zilog Z80 Family Data Book, January 1989, p 366
; by fjkraan@electrickery 2022-01-28
; z80asm version (https://github.com/udo-munk/z80pack/tree/master/z80asm)
; This program assumes a CTC at port 40h and the standard MPF-I(B) hex
; display.

; MPF-I CPU clock: 1.79 MHz. A prescaler of 256 and a time constant of 84
; and a division of again 83 in the ISR results in a counter update 
; interval of approx. 1 s.

; RTCCLOCK version 0.3, 2022-02-05

;           Memory organisation
RAM:    EQU     1980h
ROM:    EQU     2200h
RAMSIZ: EQU     90h

;           CTC ports

CTCBASE:EQU     40h
CTC0:   EQU     CTCBASE + 0         ;CTC 0 PORT
CTC1:   EQU     CTCBASE + 1         ;CTC 1 PORT
CTC2:   EQU     CTCBASE + 2         ;CTC 2 PORT
CTC3:   EQU     CTCBASE + 3         ;CTC 3 PORT
LITES:  EQU     0C0h                ;LIGHT PORT for debug

;           CTC Constants
CCW:    EQU     1
INTEN:  EQU     80h     ; Interrupt enable
CTRMODE:EQU     40h     ; Counter mode
P256:   EQU     20h     ; Prescaler 256
RISEDO: EQU     10h     ; Rising Edge Trigger
PSTRT:  EQU     8       ; Trigger by CLK/TRG
TCLOAD: EQU     4       ; Time constant in following byte load (TIME)
RESET:  EQU     2       ; Software Reset
TIMER:  EQU     84      ; CTC TIMER VALUE 
COUNTER:EQU     83      ; ISR COUNT value

;            PIO ports
PIOBASE:EQU     080h
PIODA:  EQU     PIOBASE + 0    ; DATA PORT OF PIO   CHANNEL A; address & control: output
R_ADCT: EQU     PIODA
PIODB:  EQU     PIOBASE + 1    ; DATA PORT OF PIO   CHANNEL B; data read/write: input & output
R_DATA: EQU     PIODB
PIOCA:  EQU     PIOBASE + 2    ; CONTROL PORT OF PIO  CHANNEL A; address & control: output
R_ACDR: EQU     PIOCA
PIOCB:  EQU     PIOBASE + 3    ; CONTROL PORT OF PIO  CHANNEL B; data read/write: input & output
R_DDRR: EQU     PIOCB          ; rtc data port direction register

;           PIO Constants
PIODW:  EQU     00001111b       ; mode 0: output
PIODR:  EQU     01001111b       ; mode 1: input
PIOICW: EQU     00000111b       ; Interrupt Control Word: disable interrupt
PIOIDW: EQU     00000011b       ; Interrupt Disable Word: disable interrupt

; Z80 PIO bits to MSM5832 RTC pin mapping
RTCHOLD EQU     010h
RTCREAD EQU     020h
RTCWRIT EQU     040h
RTCDMSK EQU     00Fh    ; RTC address mask
RTCNORD EQU     RTCREAD ^ 0FFh
RTCNOWR EQU     RTCWRIT ^ 0FFh
; masks in dual BCD mode as used in READ_C and WRITE_C
RTC_MIM EQU     01111111b ; minute mask
RTC_AM  EQU     00000000b ; 
RTC_PM  EQU     01000000b ; the PM clock bit 
RTC_12h EQU     00000000b ; 
RTC_24h EQU     10000000b ; the 24 hour clock bit in dual BCD mode
RTC_HRM EQU     (RTC_PM | RTC_24h) ^ 0FFh ; reverse mask for the extra bits
RTC_lpy EQU     01000000b ; leap year flag for Feb 29, D2 > bit 6
RTC_DYM EQU     RTC_lpy ^ 0FFh ; reverse mask
RTC_MNM EQU     00011111b ; month mask

; MSM5832 registers: most values use two addresses, but not the day-in-week
SC1AD:  EQU     0   ; second
MI1AD:  EQU     2   ; minute
HR1AD:  EQU     4   ; hour,  HR10AD uses D2 for AM/PM, D3 for 12/24 hour clock
WDAD:   EQU     6   ; day-in-week
DY1AD:  EQU     7   ; day-in month
MO1AD:  EQU     9   ; month
YR1AD:  EQU     11  ; year in century

; DJNZ = (13 Tstates) * W150C + 8 T states. (152,5 us + 4.5 us) = 157 us
W150C:  EQU     21 ; ~150us at 1.79 MHz

; Monitor ROM routines
SCAN:   EQU     05FEh       ; 
SCAN1:  EQU     0624h       ; input: (IX), output: carry & A
HEX7SEG:EQU     0678h       ; input: A (2 * BCD), output (HL). HL+2

;       RAM organisation
        ORG     RAM
MANBUF:         ; buffer to store BCD values when manually setting time and date
        DEFB    00      ; seconds MANBUF+0
        DEFB    00      ; minutes MANBUF+1
        DEFB    00      ; hours   MANBUF+2
        DEFB    00      ; day-of-week
        DEFB    00      ; days    MANBUF+4
        DEFB    00      ; months  MANBUF+5
        DEFB    00      ; years   MANBUF+6
        
RTCBUF:                 ; data here stored as binary
        DEFB    00      ; seconds RTCBUF+0
        DEFB    00      ; minutes RTCBUF+1
        DEFB    00      ; hours   RTCBUF+2
        DEFB    00      ; day-of-week
        DEFB    00      ; days    RTCBUF+4
        DEFB    00      ; months  RTCBUF+5
        DEFB    00      ; years   RTCBUF+6
    
DISPBUF:                ; six digits, from right to left
        DEFW    0000    ; seconds / years
        DEFW    0000    ; minutes / months
        DEFW    0000    ; hours   / days

        DEFS    64      ;STACK AREA
STAK:   EQU     $
COUNT:  DEFS    1       ;ICT COUNT VALUE
SECFLAG:DEFS    1       ; second boundary flag, triggers RTCBUF update 
RTCRDFL:DEFS    1       ; clock update from RTC flag, triggers READ_C call
POINTON:DEFS    1       ; point on right digit on flag, used to flag an RTC access
POINTBT:EQU     01000000b ; the point is bit 6. UM, p37

MROFFS: EQU     RTCBUF - MANBUF ; This offset is handy with LD (IX+MROFFS),A
RB_SC:  EQU     RTCBUF + 0
RB_MI:  EQU     RTCBUF + 1
RB_HR:  EQU     RTCBUF + 2

;;          *** MAIN PROGRAM ***

        ORG     ROM
        JP      BEGIN
        
SETRTC:        
        CALL   SETRBUF
        RST     0
        
GETRTC:
        CALL    READ_C
        RST     0

        ORG     $ & 0FFF0h | 10h
INTVEC: 
        DEFW    ICTC0
        DEFW    ICTC1
        DEFW    ICTC2
        DEFW    ICTC3
        
BEGIN:  
        LD      SP,STAK         ;INIT SP
        IM      2               ;VECTOR INTERRUPT MODE
        LD      A,INTVEC / 256  ;UPPER VECTOR BYTE
        LD      I,A
        CALL    INIT            ;INIT DEVICES (CTC & memory)
        LD      A, 1
        LD      (RTCRDFL), A    ; trigger RTC read
        EI                      ;ALLOW INTERRUPTS

LOOP:        
        LD      A, (SECFLAG)
        CP      1
        LD      A, 0            ; clear secflag, regardless of state
        LD      (SECFLAG), A
        JP      NZ, NO_SEC     ; part below only once per second
        LD      A, (RTCRDFL)
        CP      1
        JR      NZ, NO_RTC      ; 
        CALL    READ_C
NO_RTC:                         ; no RTC access
        CALL    UPDTIME
NO_SEC:                         ; no second passed
        CALL    DSP             ; Show time on display
        JR      LOOP            ;LOOP FOREVER
        
INIT:
; PIO Channel pre-config
        LD      A, PIOIDW
        OUT     (PIOCA), A      ; channel A interrupt disable
        OUT     (PIOCB), B      ; channel B interrupt disable
        
; PIO Channel A final configuration, address & control port
        LD      A, 0h
        OUT     (R_ADCT), A     ; zero addr/ctrl before setting output mode
        LD      A, PIODW
        OUT     (R_ACDR), A     ; addr/ctrl port, channel A output mode
        
; PIO Channel B initial configuration, data port 
        LD      A, 0h
        OUT     (R_ADCT), A     ; zero data before setting output mode
        LD      A, PIODR
        OUT     (R_DDRR), A     ; data port, channel B input mode

; CTC0 init 
        LD      A, INTEN + P256 + TCLOAD + RESET + CCW
        OUT     (CTC0), A       ;SET CTC MODE
        LD      A, TIMER
        OUT     (CTC0), A       ;SET TIME CONSTANT
        LD      A, INTVEC & 11111110b
        OUT     (CTC0), A       ;SET VECTOR VALUE
        LD      A, COUNTER      ;INIT COUNTER VALUE
        LD      (COUNT), A
        XOR      A
        LD      (SECFLAG), A
        
; display memory init
        LD      (DISPBUF), A     ; clear display buffer
        LD      (DISPBUF + 1), A
        LD      (DISPBUF + 2), A
        LD      (DISPBUF + 3), A
        LD      (DISPBUF + 4), A
        LD      (DISPBUF + 5), A
        
        LD      A, 01010101b
        OUT     (LITES), A
        
        RET
        
UPDTIME:
        ; update seconds up to 60
        ; update minutes up to 60 when seconds == 60, reset seconds
        ; update hours up to 24 when minutes == 60, reset minutes
        ; update date when hours == 24, reset hours
        ; ....
        LD      A, (RB_SC)
        INC     A
        CP      60
        JR      Z, UT_S0
        LD      (RB_SC), A
        JR      UPDDONE
        
UT_S0:
        LD      A, 0
        LD      (RB_SC), A          ; set seconds to zero
        LD      A, (RB_MI)
        INC     A                   ; update minutes
        CP      60
        JR      Z, UT_M0
        LD      (RB_MI), A
        JR      UPDDONE
        
UT_M0:
        LD      A, 1
        LD      (RTCRDFL), A        ; set flag to trigger RTC read
        LD      A, 0
        LD      (RB_MI), A          ; set minutes to zero
        LD      A, (RB_HR)
        INC     A                   ; update hours
        CP      24
        JR      Z, UT_H0
        LD      (RB_HR), A
        JR      UPDDONE
        
UT_H0:     ; date update not implemented yet; 
        LD      A, 0
        LD      (RB_HR), A          ; set hours to zero

UPDDONE:
        RET

DSP:
        LD      HL, DISPBUF      ; point to rightmost value
        LD      BC, RTCBUF
        LD      A, (BC)
        CALL    BIN2BCD
        CALL    HEX7SEG
        CALL    POINTM
        INC     BC              ; points to minutes value
        LD      A, (BC)
        CALL    BIN2BCD
        CALL    HEX7SEG
        INC     BC              ; points to hours value
        LD      A, (BC)
        CALL    BIN2BCD
        CALL    HEX7SEG
       
        LD      IX, DISPBUF
        CALL    SCAN1           ; call ROM display routine
        
        RET
        
POINTM:
        PUSH    AF
        LD      A, (POINTON)
        ADD     A, 0
        JR      Z, PNTMNOT
        LD      A, (DISPBUF)
        OR      POINTBT
        LD      (DISPBUF), A
PNTMNOT:
        POP     AF
        RET
        
READ_C:
        LD      A, 1
        LD      (POINTON), A    ; set flag for the rightmost display dot
        
        LD      A, PIODR
        OUT     (R_DDRR), A  ; data port, channel B input mode
        LD      A, RTCHOLD
        OUT     (R_ADCT), A  ; assert HOLD
        CALL    WAIT150u
        
        LD      HL, RTCBUF
        LD      A, SC1AD    ; second nibbles
        CALL    RD2NIB
        CALL    BCD2BIN
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, MI1AD    ; minute nibbles
        CALL    RD2NIB
        AND     RTC_MIM
        CALL    BCD2BIN
        LD      (HL), A     ; store in buffer
        
        OUT     (LITES), A  ; debug 
        
        INC     HL
        LD      A, HR1AD
        CALL    RD2NIB      ; hour nibbles
        AND     RTC_HRM     ; mask off PM & 24h bits
        CALL    BCD2BIN
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, WDAD     ; week-day nibble
        CALL    RD1NIB
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, DY1AD    ; day-of month nibbles
        CALL    RD2NIB
        AND     RTC_DYM     ; mask leap year flag
        CALL    BCD2BIN
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, MO1AD    ; month nibbles
        CALL    RD2NIB
        CALL    BCD2BIN
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, YR1AD    ; year in century nibbles
        CALL    RD2NIB
        CALL    BCD2BIN
        LD      (HL), A     ; store in buffer

        LD      A, 0
        OUT     (R_ADCT), A  ; de-assert HOLD
                
        RET
      
RD1NIB:                     ; read one nibble, expects RTC address in A, 
        PUSH    BC
        OR      RTCHOLD
        LD      C, A        ; keep address + HOLD
        OUT     (R_ADCT), A  ; address + HOLD out
        OR      RTCHOLD | RTCREAD
        OUT     (R_ADCT), A  ; address + HOLD + READ out
        
        IN      A, (R_DATA)  ; data in
        AND     RTCDMSK     ; mask upper nibble
        LD      B, A        ; keep value from RTC
        LD      A, C
        OUT     (R_ADCT), A  ; address + HOLD out
        LD      A, B
        
        POP     BC
        RET

RD2NIB:                     ; read two consecutive nibbles, expects 
                            ; first RTC address in A
        PUSH    BC
        LD      B, A        ; keep address
        CALL    RD1NIB
        LD      C, A        ; keep lower nibble
        LD      A, B        ; restore address
        INC     A           ; point to next
        CALL    RD1NIB
        RLC     A           ; shift to upper nibble
        RLC     A
        RLC     A
        RLC     A
        OR      C           ; combine nibbles
        POP     BC
        RET
        
WRITE_R:
        CALL    WRITE_C
        RST     0
        
WRITE_C:
        LD      A, PIODW
        OUT     (R_DDRR), A  ; data port, channel B output mode
        LD      A, RTCHOLD
        OUT     (R_ADCT), A
        CALL    WAIT150u
        
        LD      HL, RB_SC
        LD      A, (HL)
        CALL    BIN2BCD
        LD      B, A
        LD      A, SC1AD | RTCHOLD   ; second nibbles
        CALL    WR2NIB
        
        INC     HL                    ; RB_MI
        LD      A, (HL)
        CALL    BIN2BCD
        LD      B, A
        LD      A, MI1AD | RTCHOLD    ; minute nibbles
        CALL    WR2NIB
        
        INC     HL                    ; RB_HR
        LD      A, (HL)
        CALL    CALCPM
        CALL    BIN2BCD
        OR      C                   ; add the 24 hour and optional PM clock bits
        LD      B, A
        LD      A, HR1AD | RTCHOLD
        CALL    WR2NIB              ; hour nibbles
        
        INC     HL
        LD      A, (HL)
        CALL    BIN2BCD
        LD      B, A
        LD      A, WDAD | RTCHOLD     ; day-of-week nibble
        CALL    WR1NIB

        INC     HL
        LD      A, (HL)
        CALL    BIN2BCD
        LD      B, A
        LD      A, DY1AD | RTCHOLD
        CALL    WR2NIB              ; day-of-month nibbles
        
        INC     HL
        LD      A, (HL)
        CALL    BIN2BCD
        LD      B, A
        LD      A, MO1AD | RTCHOLD
        CALL    WR2NIB              ; month nibbles
        
        INC     HL
        LD      A, (HL)
        CALL    BIN2BCD
        LD      B, A
        LD      A, YR1AD | RTCHOLD
        CALL    WR2NIB              ; year-in-century nibbles
        
        LD      A, 0
        OUT     (R_ADCT), A  ; de-assert HOLD
        
        LD      A, PIODR
        OUT     (R_DDRR), A  ; data port, channel B input mode

        RET
        
WR1NIB:                       ; write a nibble from (HL) to RTC
        OUT     (R_ADCT), A   ; address & hold out
        LD      C, R_DATA
        OUT     (C), B        ; data out
        OR      RTCWRIT
        OUT     (R_ADCT), A   ; assert write
        AND     RTCNOWR       
        OUT     (R_ADCT), A   ; de-assert write

        RET

WR2NIB:                     ; write nibbles from (HL) and (HL+1) to RTC
        PUSH    AF          ; save RTC address
        CALL    WR1NIB
        POP     AF          ; restore RTC address
        INC     A           ; point to next 10's address, HOLD not effected
        RRC     B
        RRC     B
        RRC     B
        RRC     B
        CALL    WR1NIB
        RET
        
CALCPM:
        PUSH    AF
        LD      C, RTC_24h  ; preset for AM pattern
        CP      12
        JR      C, CPLOW
        LD      C, RTC_24h | RTC_PM ; override with PB pattern
CPLOW:
        POP     AF
        RET

WAIT150u:
        PUSH    AF
        PUSH    BC
        LD      B, W150C
W150LP:
        DJNZ    W150LP         ; Wait
        POP     BC
        POP     AF
        RET

BCD2BIN:
        ; input; A contains 2 BCD digits - MSN and LSN
        ; output; A contains a binary value
        PUSH    BC
        PUSH    AF
        AND     0F0h    ; create MSN value only
        RRCA
        LD      C, A    ; keep MSN * 8 
        RRCA
        RRCA
        ADD     A, C    ; add MSN * 2 to MSN * 8
        LD      C, A    ; keep the MSN * 10
        POP     AF
        AND     00Fh    ; create LSN value only
        ADD     A, C       ; create complete binary value
        POP     BC
        RET
        
BIN2BCD:
        ; input; A contains a binary value less than 100 (MSNb & LSNb)
        ; output; A contains two BCD digits - MSN and LSN
        PUSH    BC
        LD      B, 0            ; start with zero MSB
BI2BLP  SUB     10
        JP      C, BI2BRY       ; done counting 10s
        INC     B
        JR      BI2BLP          ; continue until A < 10
BI2BRY  ADD     A, 10           ; compensate 
        RLC     B               ; move 10s to upper nibble
        RLC     B
        RLC     B
        RLC     B
        ADD     A, B            ; merge nibbles
        POP     BC

        RET
        
SETRBUF:
        LD      IX, MANBUF      ; point to RTCBUF seconds
        LD      A, (IX + 0)     ; load from MANBUF seconds
        CALL    BCD2BIN
        LD      (IX + MROFFS), A     ; store to RTCBUF seconds
        INC     IX
        
        LD      A, (IX + 0)     ; minutes
        CALL    BCD2BIN
        LD      (IX + MROFFS), A  ; 
        INC     IX
        
        LD      A, (IX + 0)     ; hours
        CALL    BCD2BIN
        LD      (IX + MROFFS), A  ; 
        INC     IX

        LD      A, (IX + 0)  ; day of week
        CALL    BCD2BIN
        LD      (IX + MROFFS), A  ; 
        INC     IX

        LD      A, (IX + 0)  ; day of month
        CALL    BCD2BIN
        LD      (IX + MROFFS), A  ; 
        INC     IX

        LD      A, (IX + 0)  ; months
        CALL    BCD2BIN
        LD      (IX + MROFFS), A  ; 
        INC     IX
       
        LD      A, (IX + 0)  ; years
        CALL    BCD2BIN
        LD      (IX + MROFFS), A  ; 
        INC     IX
        
        CALL    WRITE_C
;        RST     0               ; return to monitor
;        JP      READ_C
        RET

;       INTERRUPT SERVICE ROUTINES 

ICTC1:
ICTC2:
ICTC3:
        EI
        RETI                    ;DUMMY ROUTINES
        
ICTC0:
        PUSH    AF
        LD      A, (COUNT)      ;CHANGE TIMER COUNT
        DEC     A
        LD      (COUNT), A
        CP      0
        JR      NZ, IC0DONE     ; (COUNT) not yet zero, exit ISR
        LD      A, COUNTER      ;ELSE, RESET COUNTER VALUE
        LD      (COUNT), A
        
        LD      A, 1
        LD      (SECFLAG), A
        
IC0DONE:
        POP     AF
        EI
        RETI

        END
