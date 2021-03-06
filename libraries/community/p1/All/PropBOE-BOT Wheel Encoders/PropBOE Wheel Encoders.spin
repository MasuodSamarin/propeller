{{
┌──────────────────────────────────────────┐
│ PropBOE Wheel Encoders V0.1              │
│ Author: Richard Brockmeier               │               
│ Copyright (c) 2012 Richard Brockmeier    │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘
This object is used to read the BOE-BOT wheel encoders with the PropBOE.
The object does not indicate the direction of rotation, as these are simple encoders.
}}



VAR
  long  rticks,lticks,estack[20],ResetFlag
   
OBJ
    pin    : "Input Output Pins"                         ' I/O convenience methods  
PUB Start(rpin,lpin)
{{This method must be called first to set the pins the
  Encoders are connected to.
  rpin = Right Encoder Pin
  Lpin = Left Encoder Pin
}}      
  cognew(Encode(rpin,lpin),@estack)
  

PUB RESET
''Set flag to reset the counts
    ResetFlag := 1
    
PUB ReadLeft
''Read Left Encoder count
  result := lticks

PUB ReadRight
''Read Right Encoder count
  result := rticks

PRI Encode(rpin,lpin)
  ResetFlag := 0
  'Set up the counter
  CTRA[5..0]   := rpin          'Right input pin 0
  CTRA[30..26] := %01010        'Positive Edge Detector 
  FRQA := 1                     'Add 1 at each positive Edge
  'Set up the counter
  CTRB[5..0]   := lpin          'Left input pin 8
  CTRB[30..26] := %01010        'Positive Edge Detector 
  FRQB := 1                     'Add 1 at each positive Edge

  repeat
    rticks := PHSA
    lticks := PHSB
    if pin.in(rpin) == 1 
            CTRA[30..26] := %01110        'Negative Edge Detector
    else
            CTRA[30..26] := %01010        'Positive Edge Detector
    if pin.in(lpin) == 1
            CTRB[30..26] := %01110        'Negative Edge Detector
    else
            CTRB[30..26] := %01010        'Positive Edge Detector
    if ResetFlag
      PHSA := 0
      PHSB := 0
      ResetFlag := 0


DAT

     
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