; RTC_MPF-I - Real Time Clock


PIOBASE:  EQU 080h
PIODA:  EQU     PIOBASE        ; DATA PORT OF PIO   CHANNEL A; address & control: output
R_ADCT: EQU     PIODA
PIODB:  EQU     PIOBASE + 1h   ; DATA PORT OF PIO   CHANNEL B; data read/write: input & output
R_DATA: EQU     PIODB
PIOCA:  EQU     PIOBASE + 2h   ; CONTROL PORT OF PIO  CHANNEL A; address & control: output
R_ACDR: EQU     PIOCA
PIOCB:  EQU     PIOBASE + 3h   ; CONTROL PORT OF PIO  CHANNEL B; data read/write: input & output
R_DDRR:  EQU    PIOCB          ; rtc data port direction register

PIODW:  EQU     00001111b       ; mode 0: output
PIODR:  EQU     01001111b       ; mode 1: input
PIOICW: EQU     00000111b       ; Interrupt Control Word: disable interrupt
PIOIDW: EQU     00000011b       ; Interrupt Disable Word: disable interrupt

RTCHOLD EQU     010h
RTCREAD EQU     020h
RTCWRIT EQU     040h
RTCDMSK EQU     00Fh    ; RTC address mask
RTCNORD EQU     RTCREAD ^ 0FFh
RTCNOWR EQU     RTCWRIT ^ 0FFh
; masks in dual BCD mode as used in RTCBUF
RTC_MIM EQU     01111111b ; minute mask
RTC_AM  EQU     00000000b ; 
RTC_PM  EQU     01000000b ; the PM clock bit 
RTC_12h EQU     00000000b ; 
RTC_24h EQU     10000000b ; the 24 hour clock bit in dual BCD mode
RTC_HRM EQU     (RTC_PM | RTC_24h) ^ 0FFh ; reverse mask for the extra bits
RTC_lpy EQU     01000000b ; leap year flag for Feb 29, D2 > bit 6
RTC_DYM EQU     RTC_lpy ^ 0FFh ; reverse mask
RTC_MNM EQU     00011111b ; month mask

; most use two addresses, but not the day-in-week
SC1AD:  EQU     0   ; second
MI1AD:  EQU     2   ; minute
HR1AD:  EQU     4   ; hour,  HR10AD uses D2 for AM/PM, D3 for 12/24 hour clock
WDAD:   EQU     6   ; day-in-week
DY1AD:  EQU     7   ; day-in month
MO1AD:  EQU     9   ; month
YR1AD:  EQU     11  ; year in century

W150C:  EQU     21 ; ~15us at 1.79 MHz

MPFMON: EQU     0030h
SCAN:   EQU     05FEh
HEX7SG: EQU     0678h

; init

; read cycle:
; data-direction input
; assert HOLD & wait 150 us
; RLOOP:
; assert HOLD & READ
; assert address
; read data
; de-assert READ (not required, but convenient in code structure)
; repeat from RLOOP until done
; de-assert READ

; write cycle:
; data-direction output
; assert HOLD & wait 150 us
; WLOOP:
; assert address & data
; assert WRITE
; de-assert WRITE
; repeat from WLOOP until done
; deassert address & HOLD
; data-direction input

        ORG     1900H
; data here stored as BCD
RTCBUF:
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

        ORG     2000h

INIT:   
        JP      INIT_R
        
READ:
        JP      READ_R

WRITE:
        JP      WRITE_R

DSPTM:
        JP      SHOWTIM
        
DSPDT:
        JP      SHOWDAT

INIT_R:
        CALL    INIT_C
        RST     0
        
INIT_C:
; Channel pre-config
        LD      A, PIOIDW
        OUT     (PIOCA), A  ; channel A interrupt disable
        OUT     (PIOCB), B  ; channel B interrupt disable
        
; Channel A final configuration, address & control port
        LD      A, 0h
        OUT     (R_ADCT), A  ; zero addr/ctrl before setting output mode
        LD      A, PIODW
        OUT     (R_ACDR), A   ; addr/ctrl port, channel A output mode
        
; Channel B initial configuration, data port 
        LD      A, 0h
        OUT     (R_ADCT), A   ; zero data before setting output mode
        LD      A, PIODR
        OUT     (R_DDRR), A   ; data port, channel B input mode
        
        RET
        
READ_R:
        CALL    READ_C
        RST     0
        
READ_C:
        LD      A, PIODR
        OUT     (R_DDRR), A  ; data port, channel B input mode
        LD      A, RTCHOLD
        OUT     (R_ADCT), A  ; assert HOLD
        CALL    WAIT150u
        
        LD      HL, RTCBUF
        LD      A, SC1AD    ; second nibbles
        CALL    RD2NIB
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, MI1AD    ; minute nibbles
        CALL    RD2NIB
        AND     RTC_MIM
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, HR1AD
        CALL    RD2NIB      ; hour nibbles
        AND     RTC_HRM     ; mask off PM & 24h bits
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, WDAD     ; week-day nibble
        CALL    RD1NIB
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, DY1AD    ; day-of month nibbles
        CALL    RD2NIB
        AND     RTC_DYM     ; mask leap year flag
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, MO1AD    ; month nibbles
        CALL    RD2NIB
        LD      (HL), A     ; store in buffer
        
        INC     HL
        LD      A, YR1AD    ; year in century nibbles
        CALL    RD2NIB
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
        
        LD      HL, RTCBUF
        LD      B, (HL)
        LD      A, SC1AD | RTCHOLD   ; second nibbles
        CALL    WR2NIB
        
        INC     HL
        LD      B, (HL)
        LD      A, MI1AD | RTCHOLD    ; minute nibbles
        CALL    WR2NIB
        
        INC     HL
        LD      B, (HL)
        LD      A, HR1AD | RTCHOLD
        CALL    WR2NIB      ; hour nibbles
        
        INC     HL
        LD      A, (HL)
        OR      RTC_24h               ; add the 24 hour clock bit
        LD      B, A
        LD      A, WDAD | RTCHOLD     ; day-of-week nibble
        CALL    WR1NIB

        INC     HL
        LD      B, (HL)
        LD      A, DY1AD | RTCHOLD
        CALL    WR2NIB      ; day-of-month nibbles
        
        INC     HL
        LD      B, (HL)
        LD      A, MO1AD | RTCHOLD
        CALL    WR2NIB      ; month nibbles
        
        INC     HL
        LD      B, (HL)
        LD      A, YR1AD | RTCHOLD
        CALL    WR2NIB      ; year-in-century nibbles
        
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
        
WAIT150u:
        PUSH    AF
        PUSH    BC
        LD      B, W150C
W150LP:
        DJNZ    W150LP		; Wait
        POP     BC
        POP     AF
        RET

DSPT_R:
        LD      HL, DISPBUF
        LD      A, (RTCBUF)     ; seconds
        CALL    HEX7SG
        LD      A,(RTCBUF+1)    ; minutes
        CALL    HEX7SG
        LD      A,(RTCBUF+2)    ; hours
        CALL    HEX7SG
        LD      IX, DISPBUF
        CALL    SCAN
        
        RST     0

DSPD_R:
        LD      HL, DISPBUF
        LD      A, (RTCBUF+6)   ; years
        CALL    HEX7SG
        LD      A,(RTCBUF+5)    ; months
        CALL    HEX7SG
        LD      A,(RTCBUF+4)    ; day-of-month
        CALL    HEX7SG
        LD      IX, DISPBUF
        CALL    SCAN
        
        RST     0

SHOWTIM:
        CALL    READ_C
        JR      DSPT_R
        
SHOWDAT:
        CALL    READ_C
        JR      DSPD_R
