con
{{
┌──────────────────────────────────────────┐
│ Main RAM Hex Dumper                      │
│ Author: Thomas Watson                    │               
│ Copyright (c) 2008 Thomas Watson         │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘
}}

var
byte cog

pub dump(baudrate)
cog := cognew(@entry, (clkfreq/baudrate) << 2) + 1

pub stop
if cog
  cogstop(cog~ - 1)

dat
org 0
entry
              mov btime, par
              shr btime, #2
              mov addr, #0
              or dira, pinout
              or outa, pinout
              call #newline
              mov bytecount, #1
loop
              rdbyte hex, addr
              add bytecount, #data
              sub bytecount, #1
              movd :store, bytecount
              sub bytecount, #data
              add bytecount, #1
:store        mov 0-0, hex
              call #hexcalc
              call #hexout
              mov dataout, #" "
              call #byteout
              add addr, #1
              cmp bytecount, #16 wz
        if_z  call #newline
              cmp addr, memend  wz
        if_z  jmp #done
              add bytecount, #1
              jmp #loop

done
              cogid temp
              cogstop temp

hexout
              mov dataout, byte1
              call #byteout
              mov dataout, byte2
              call #byteout
hexout_ret    ret

newline
              mov dataout, #" "
              call #byteout
              mov dataout, #" "
              call #byteout
              mov idx, #16
              movs :get, #data
:looper
              mov dataout, #" "
:get          mov temp, 0-0
              cmp temp, #126    wc, wz
if_nc_and_nz  mov dataout, #"."
if_c_or_z     cmp temp, #32     wc, wz
if_c          mov dataout, #"."
              cmp dataout, #"." wz
if_nz         mov dataout, temp
              call #byteout
              add :get, #1
              djnz idx, #:looper
              mov dataout, #10
              call #byteout
              mov dataout, #13
              call #byteout
              mov temp, addr
              shr temp, #8
              mov hex, temp
              call #hexcalc
              call #hexout
              mov temp, addr
              and temp, #$FF
              mov hex, temp
              call #hexcalc
              call #hexout
              mov dataout, #" "
              call #byteout
              mov bytecount, #0
newline_ret   ret

hexcalc
              mov temp, hex
              and temp, #$F
              shr hex, #4
              cmp hex, #9 wc, wz
if_nc_and_nz  add hex, #55
if_z_or_c     add hex, #"0"
              cmp temp, #9 wc, wz
if_nc_and_nz  add temp, #55
if_z_or_c     add temp, #"0"
              mov byte1, hex
              mov byte2, temp
hexcalc_ret   ret

byteout
              shl dataout, #2
              add dataout, h400
              mov bitcount, #10
              shr dataout, #1
              mov time, cnt
              add time, btime
:loop
              waitcnt time, btime 
              shr dataout, #1 wc
              muxc outa, pinout
              djnz bitcount, #:loop
byteout_ret   ret
              
h400 long $400              
memend long $8000
pinout long 1 << 30
btime res 1
bytecount res 1
bitcount res 1
addr res 1
idx res 1
byte1 res 1
byte2 res 1
temp res 1
time res 1
hex res 1
dataout res 1
data res 16
fit 496



{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}} 

