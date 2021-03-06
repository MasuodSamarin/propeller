{{┌────────────────────────────────────┐
  │ CANbus loopback demos              │
  │ Author: Chris Gadd                 │
  │ Copyright (c) 2015 Chris Gadd      │
  │ See end of file for terms of use.  │
  └────────────────────────────────────┘
  For this demo, place a pull-up resistor on the Tx_pin, and connect the Tx_pin to the Rx_pin - also works with loopback through a MCP2551
   The writer object transmits a bitstream containing ID, data length, and data to the reader.
   The reader object receives and decodes the bitstream, and displays it on a serial terminal at 115_200bps
'...............................................................................................................................
  Supports standard, extended, and remote frame messages
   Standard frame:                                                                                                  CRC delimiter     
                 RTR                                                                                                │ ACK                                                   
   SOF           │ IDE   Data length (0 - 8 bytes)                                                                  │ │ ACK delimiter                                       
   │ Ident A     │ │ R0  │  Byte 0   Byte 1   Byte 2   Byte 3   Byte 4   Byte 5   Byte 6   Byte 7   CRC             │ │ │ EOF                                               
                                                                                                                                                                
   0_xxxxxxxxxxx_0_0_0_xxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxxxxxxxxx_1_i_1_1111111     

   Extended frame:                                                                                                                         CRC delimiter    
                 SRR                    RTR                                                                                                │ ACK            
   SOF           │ IDE                  │ R1    Data length                                                                                │ │ ACK delimiter
   │ Ident A     │ │ Ident B            │ │ R0  │  Byte 0   Byte 1   Byte 2   Byte 3   Byte 4   Byte 5   Byte 6   Byte 7   CRC             │ │ │ EOF        
                                                                                                                                      
   0_xxxxxxxxxxx_1_1_xxxxxxxxxxxxxxxxxx_0_0_0_xxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxx_xxxxxxxxxxxxxxx_1_i_1_1111111

   Standard remote frame:                   CRC delimiter                                              
                 RTR                        │ ACK                                                      
   SOF           │ IDE   Data length        │ │ ACK delimiter                                          
   │ Ident A     │ │ R0  │  CRC             │ │ │ EOF        
                                                  
   0_xxxxxxxxxxx_1_0_0_0000_xxxxxxxxxxxxxxx_1_i_1_1111111

   Extended remote frame:                                          CRC delimiter                       
                 SRR                    RTR                        │ ACK                                                                   
   SOF           │ IDE                  │ R1    Data length        │ │ ACK delimiter                                                       
   │ Ident A     │ │ Ident B            │ │ R0  │  CRC             │ │ │ EOF                                                               
                                                                                                                             
   0_xxxxxxxxxxx_1_1_xxxxxxxxxxxxxxxxxx_1_0_0_0000_xxxxxxxxxxxxxxx_1_i_1_1111111
   
}}
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  Rx_pin  = 25
  Tx_pin  = 24
  bitrate = 1_000_000
  
VAR
  long  ident
  byte  dlc,tx_data[8]                                  ' String of bytes to send

OBJ
  writer   : "CANbus writer 1Mbps"                      ' Standalone writer, good up to 1Mbps
  reader   : "CANbus reader 1Mbps"                      ' Standalone reader, good up to 1Mpbs, requires 2 cogs, requires a pin for synchronizing cogs
' reader   : "CANbus reader 500Kbps"                    ' Standalone reader, good up to 500Kbps, requires 1 cog
  canbus   : "CANbus controller 500Kbps"                ' Unified reader/writer, good up to 500Kbps, requires 1 cog
  fds      : "FullDuplexSerial"
                                                      
PUB Main
  CANbus_RW                     ' Demonstrate the separate reader and writer objects
' CANbus_controller             ' Demonstrate the unified reader / writer object

PRI CANbus_RW | i, n
                        
  reader.loopback(true)                                 ' Loopback must be set before starting the reader object 
  reader.start(rx_pin,tx_pin,7,bitrate)                 ' Using pin 7 for sync
' reader.start(rx_pin,tx_pin,bitrate)                   ' 500Kbps reader doesn't have a sync pin
  writer.Start(rx_pin,tx_pin,bitrate)
  fds.Start(31,30,0,115200)
  waitcnt(cnt + clkfreq)
  fds.Tx($00)
  fds.Tx($01)

  ident := $001                                         ' $000 is invalid and will cause reader to hang 
  dlc := 0                                             
  n := 0                                               

  repeat                                                
    waitcnt(cnt + clkfreq / 20)
    SendWriter
    CheckReader                                         ' Display the message received by the reader
    Ident++                                             ' Increment the ID, data length counter, and data bytes
    if ++dlc == 9                                       
      dlc := 0                                          ' Keep number of data bytes in range 0 to 8
    if dlc                                              
      repeat i from 0 to dlc - 1
        tx_data[i] := n++

PRI SendWriter
    if dlc == 0
      writer.SendRTR(ident)                             ' Send either a remote-transmission request
    else                                                '  or a normal message
      writer.SendStr(ident,@dlc)                        

PRI CheckReader | a
  if reader.ID                                          ' Check if an ID was received
    if reader.ID > $7FF
      fds.Hex(reader.ID,8)
    else
      fds.Hex(reader.ID,3)
    fds.Tx($09)                                         
    if reader.CheckRTR
      fds.Str(string("remote transmission request"))
    else
      a := reader.DataAddress                           ' DataAddress returns the address of a string of data bytes
      repeat byte[a++]                                  '  The first byte contains the string length 
        fds.Hex(byte[a++],2)                            '  Display bytes
        fds.Tx(" ")
    fds.Tx($0D)                                                                                                            
    reader.NextID                                       ' Clear current ID buffer and advance to next
    return true

PRI CANbus_controller | i, n

  canbus.Loopback(true)                                 
  canbus.Start(rx_pin,tx_pin,bitrate)
  fds.Start(31,30,0,115200)
  waitcnt(cnt + clkfreq)
  fds.Tx($00)
  fds.Tx($01)

  ident := $001                                         ' $000 is invalid and will cause reader to hang
  dlc := 0                                             
  n := 0                                               
  
  repeat                                                
    waitcnt(cnt + clkfreq / 20)
    SendCAN
    CheckCAN                                            
    Ident++                                             
    if ++dlc == 9                                       
      dlc := 0                                          
    if dlc                                              
      repeat i from 0 to dlc - 1
        tx_data[i] := n++

PRI SendCAN
    if dlc == 0
      canbus.SendRTR(ident)                             ' Send either a remote-transmission request
    else                                                '  or a normal message
      canbus.SendStr(ident,@dlc)                        

PRI CheckCAN | a
  if canbus.ID                                          ' Check if an ID was received
    if canbus.ID > $7FF
      fds.Hex(canbus.ID,8)
    else
      fds.Hex(canbus.ID,3)
    fds.Tx($09)                                         
    if canbus.CheckRTR
      fds.Str(string("remote transmission request"))
    else
      a := canbus.DataAddress                           ' DataAddress returns the address of a string of data bytes
      repeat byte[a++]                                  '  The first byte contains the string length 
        fds.Hex(byte[a++],2)                            '  Display bytes
        fds.Tx(" ")
    fds.Tx($0D)                                                                                                            
    canbus.NextID                                       ' Clear current ID buffer and advance to next
    return true

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