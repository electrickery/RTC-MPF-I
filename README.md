# RTC-MPF-I
A Real Time Clock for the Multitech Microprofessor MPF-I(B) based on an 
OKI MSM5832 Real Time Clock.

This uses the Z80-PIO via the P2 connector to interface to the MSM5832. 
Currently only the rudiments are implemented to write and read the RTC 
and display time. For the time display routine, a second-sized 
interval interrupt is generated using the Z80-CTC. The RTC is read every 
minute.

The hardware diagram:
![Schema of the RTC board](./RTC_MPF.sch.pdf)

The board: 
![The PCB for RTC-MPF-I version 1.0.](RTC_MPF-I_v1.0.jpg)

The source code is assembled with z80pack/z80asm from 
https://github.com/udo-munk/z80pack. Uploading to the 
MPF-memory is done with https://github.com/electrickery/ROM-emulator.

Both hardware and software are in the debugging phase.
