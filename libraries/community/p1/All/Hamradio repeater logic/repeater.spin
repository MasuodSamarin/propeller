{{
''***************************************
''*  Ham Radio repeater logic           *
''*  Author: Thierry Eggen, ON5TE       *
''*  Copyright (c) 2014 Thierry Eggen   *
''*  See end of file for terms of use.  *
''***************************************

We have here a Ham radio repeater logic. It's currently in test at ON0UBA UHF repeater.

Inputs:  - CarrierSensePin       : connected to the normal squelch of the receiver
         - CtcssSensePin         : connected to the CTCSS decoder if any
         - EcholinkSensePin      : connected to an external Echolink gateway (not yet in use at ON0UBA)
         - ADCInputPin           : DTMF decoder input, sigma-delta, see Propeller AN008 ADC conversion

Outputs: - ADCOutputPin          : DTMF decoder feedback pin, see above
         - PTT                   : to switchon the transmitter
         - CWPin                 : audio output of CW ID keyer
         - KeyerBusyPin          : high when keyer is busy transmitting
         - TalkthroughPin        : used to activate a relay connecting audio from RX to TX (to avoid noise when CW ID only)
         - TxPowerPin            : to switch TX power supply via a relay
         - EcholinkPTT           : currently not implemented, should simply mimic PTT

Some inputs and outputs are managed via small and simple methods to:
         - make the code more readable (TxON and TxOff easier to understand than OUTA[XYZ]~~ and so on)
         - easier to cope with the positive or inverse logic of your squelches, relays, etc.
         - easier to manage trace for debugging while keeping main code easy to read

Parameters you should adapt to your wishes:
         - various timers in the CON section
         - CW pitch, volume(s), speed
         - your repeater ID: Mycall in DAT section
         - DTMF strings: same DAT section as above,are used to remote control some repeater features         

It's built on a Quickstart board with one 100 k resistor and two 1 k capacitors directly soldered on the ADC pads.

Other compononts are mounted on a Quickstart prototypîng board:
         - an AN25 optocoupler with a 120 ohms series resistor for the transmitter PTT, between PTT pin and ground
         - a VR05R51 dip relay to switchon or mute audio, directly between TalkThroughPin and ground, in parallel with a protection diode reverse polarized
         - input sense pins are fed from TTL level from the receiver through 2k2 limiting resistors
         - one 7805 regulator to get power supply from transceivers supply
         - simple resistor/capacitor dividers to adapt audio levels

There is also an external relay used to power off the transmitter if any problem happens (tvi, bci, etc.).

The Rx and TX are good old Kenwood TK 705.
              
Many thanks to the gentlemen who contributed indirectly to this software: Jeff Martin, Andy Lindsay, Chip Gracey, Johannes Ahlebrand, Phil Pilgrim
}}
con
  _CLKMODE = XTAL1 + PLL16X
  _CLKFREQ = 80_000_000

  ' give our IO pins some friendly names
  Pin0            =       0               ' future SD card boot   ' micro sd card, pullup 10K
  Pin1            =       1               ' future SD card boot   ' micro sd card, pullup 10K
  Pin2            =       2               ' future SD card boot   ' micro sd card, pullup 10K
  Pin3            =       3               ' future SD card boot   ' micro sd card, pullup 10K
  Pin4            =       4                                       ' micro SD card optional (card inserted)
  Pin5            =       5                                       ' micro SD card optional (write enable)
  Pin6            =       6               ' free           
  Pin7            =       7               ' free

  ADCInputPin     =       8               ' DTMF decoder input    ' ADC sigma delta
  ADCOutputPin    =       9               ' DTMF decoder input    ' ADC sigma delta
  Pin10           =       10              ' free
  Pin11           =       11              ' free
  Pin12           =       12              ' free
  CarrierSensePin =       13              ' Carrier detect    
  Pin14           =       14              ' free
  CTCSSSensePin   =       15              ' Detects CTCSS (external)

  PTT             =       16              ' Push to talk output   + Led via Buffer
  Pin17           =       17              ' free                  + Led via Buffer
  CWPin           =       18              ' free                  + Led via Buffer
  KeyerBusyPin    =       19              ' keyre is busy pin     + Led via Buffer              
  TalkThroughPin  =       20              ' Mute Audio switch (HIGH: Audio On, LOW: Audio Off)  + Led via buffer
  Pin21           =       21              ' free                  + Led via Buffer
  Pin22           =       22              ' free                  + Led via buffer  
  TxPowerPin      =       23              ' TX power relay        + Led via Buffer

  Pin24           =       24              ' free 
  Pin25           =       25              ' free 
  Pin26           =       26              ' free 
  Pin27           =       27              ' free 
  Pin28           =       28              ' reserved I2C bootstrap memory
  Pin29           =       29              ' reserved I2C bootstrap memory
  Pin30           =       30              ' reserved serial port to PC
  Pin31           =       31              ' reserved serial port to PC  

  ' for future use
  
  EcholinkSensePin = Pin14                ' Detects a link RX carrier (such as EchoLink/IRLP) 
  EcholinkPTT      = -1                   ' Input to EchoLink (ie: CTS or DSR pin)

  ' various
  
  Yes   = 1
  No    = 0
  Null  = 0
   
  ' state machine statii

  #1
  Nothing
  NextIdle
  NextActive
  NextClosed
  NextSleeping
  RepeaterOn
  RepeaterOff
  RepeaterSleeping
  
con     ' following are implementer parameters 
  ' various timers
  TimerIdDelta        = 600_000         ' milliseconds between automatic CW ID sending, 600_000 is a good value (10 minutes)
  TimerCloseDownDelta =   5_000         ' milliseconds of silence before closing repeater after carrier off
  TimerRogerBeepDelta =   1_000         ' milliseconds between input carrier off and roger beep
  TimerSleepingDelta  = 300_000         ' milliseconds: the repeater is put to sleep by remote control for TimerSleeping duration
  TxFullPowerDelay    =     200         ' milliseconds, may vary depending on the transmitter 

  ' CW keyer specific
  HighVolume          = 1                ' CW Keyer audio damping volume when nobody speaks, between 0 (volume max) and 5(volume low), approx 6dB per step   
  LowVolume           = 2                ' CW Keyer reduced volume when ident. superimposed on voice. 
  CwTone              = 800              ' CW ident frequency in Hz
  CwSpeed             = 12               ' CW ident approximately in WPM

  ' DTMF decoding and goertzel specific
  NBINS               = 8                 ' Eight DTMF frequencies to be monitored
  SamplingRate        = 8000              ' frequency (Hz) at which the ADC is sampled.   
  GoertzelRate        = 5                 ' number of times per second to report results
  GoertzelN           = 91                ' number of samples required to obtain each result. The higher this number is, the narrower the passband of the consequent filters.
  Treshold            = 500               ' we consider a frequency as present when nbins[x]  greater than treshold

  DTMFStringLength    = 4                 ' Remote control string length, must always be preceded by "*", which cannot appear inside the string. Ex "*A123" is OK 
 
    'debug
  Trace               = no               ' if trace = No, then trace display routines are not active BEWARE: trace process may slow down the logic a lot
                                         ' beware: if trace == yes and no serial port connected on the other side of the usb cable, system may block                

obj
  Keyer         : "CW Keyer Sinus"
  goertzel      : "goertzel"                     ' Goertzel algorithm used for DTMF decoding
  pst           : "parallax serial terminal"     ' for debug only, not needed otherwise

VAR
  long  MainStatus              ' system main status : On, Off, Sleeping
  long  NextStatus              ' finite state machine status
  long  RTC                     ' return code
  long  CwVolume                ' CW volume, may be dynamically modified, even while sending a string
  long  RunningClock            ' 32 bits long, init at zero, incremented every millisecond, recycles approx every month ...need perhaps to be reset automatically
  long  TimerId           '     ' keeps track of next time to send CW ID
  long  TimerRogerBeep          ' next time roger beep should ring, continuously updated while relay active
  long  TimerCloseDown          ' same as above, closes repeater after some silence with didididadida indication
  long  TimerSleeping           ' keeps track of next time to reopen the repeater, which has been put to sleep because of kerchunker etc.
  long  RogerBeepSent           ' to avoid multiple dadida between carrier down and close down
  ' DTMF and Goertzel specific  
  long  bins[8], count, pcount  ' these variables need to stay together, same order
  long  dtmfpointer, DTMFStack[30]    ' stacksize 30 probably oversized
  byte  dtmfpattern , dtmfchar, dtmfstring[DTMFStringLength+1]

  long clockstack[10]
   
dat
  RogerBeep       byte    Null,0                ' roger beep byte as null terminated string          
  MyCall          byte    "ON0UBA",0            ' repeater call sign
  DTMF_On         byte    "A123",0              ' DTMF code to put repeater in operation  
  DTMF_Off        byte    "A456",0              ' put repeater in long standby mode
  DTMF_Sleep      byte    "B123",0              ' put repeater asleep for TimerSleepingDelta milliseconds
  DTMF_TO_long    byte    "C123",0              ' duration between atomatic CW ID set to TimerIdDelta milliseconds
  DTMF_TO_short   byte    "C456",0              ' duration between atomatic CW ID set to 30 seconds 
  DTMF_Reboot     byte    "D456",0              ' reboot repeater logic
  
pub start
  if trace == Yes 
    pst.start(115200)                                                           ' start serial terminal at 115200 bps
    Pausems(2000)                                                               ' wait while somebody loads the terminal on the PC
'
' =============== MAIN INIT ===============
'    
' Define Input Pins
  Dira[CarrierSensePin] := 0
  Dira[CTCSSSensePin] := 0
  
' Define Output Pins
  Dira[PTT] := 1
  Dira[CWPin] := 1           
  Dira[TalkThroughPin] := 1
  Dira[TXPowerPin] := 1  
  'Dira[LINK_TX] := 1        

  ' launch various COGs
  cognew(clock(@runningclock),@clockstack)                                      ' clock in milliseconds since start, value in long RunningClock
     
  ' launch Goertzel algorithm to detect DTMF tones
  longmove(@bins, @dtmf, NBINS)                                                 ' tell goertzel algorithm which frequencies to watch
  goertzel.start(ADCInputPin, ADCOutputPin, NBINS, @bins, @count, SamplingRate, GoertzelRate, GoertzelN)
  cognew(DTMFProc,@DTMFStack)                                                   ' launch DTMF commands detection
  rtc := keyer.start(cwpin,CWTone,CWSpeed,HighVolume,keyerbusypin)              ' Init CW keyer

  ' Init system status and  finite state machine
  MainStatus := RepeaterOn
  NextStatus := NextIdle                     
  TxPowerOn

  ' send CW ID followed by OK
  TxON                                                                      ' activate transmitter
  Keyer.SetVolume(HighVolume)                                               ' make sure CW volume is high
  Keyer.Send(@mycall)                                                       ' send our ID
  Keyer.send(string("       OK"))
  Repeat while Keyerbusy == Yes                                             ' wait until transmitted         
  TxOff                                                                     ' deactivate transmitter
  TimerId := RunningClock + TimerIdDelta                                    ' TimerID now contains when to send next ID

'
' =============== MAIN LOOP ===============
'    
  repeat                                                                        ' forever ...
      
    case MainStatus                                                             
      RepeaterOn       : TimerSleeping := RunningClock + TimerSleepingDelta     ' re actualize sleep timer
      RepeaterOff      : TxPowerOff                                             ' shut down transmitter
      RepeaterSleeping : NextStatus := NextSleeping                             ' go to sleep 

    case Nextstatus
      NextIdle      : NextStatus := Idle
      NextActive    : NextStatus := Active
      NextSleeping  : NextStatus := Sleeping
      Other:                                                                    ' should NEVER happen
        Pst.str(string("fatal error, status : "))
        pst.dec(nextstatus)
        pausems(10_000)
        reboot

pub Idle
  
    If RunningClock > TimerId                                                   ' if it's time to send our ID
      TxON                                                                      ' activate transmitter
      Keyer.SetVolume(HighVolume)                                               ' make sure CW volume is high
      Keyer.Send(@mycall)                                                       ' send our ID
      TimerId := RunningClock + TimerIdDelta                                    ' TimerID now contains when to send next ID
      Return NextIdle                                                           ' goback to idle status
      
    If CtcssSense == Yes AND CarrierSense == Yes                                ' if somebody starts keyng the repeater
      pausems(100)                                                              ' for minimum 100 milliseconds
      If CtcssSense == Yes AND CarrierSense == Yes   
        TxOn                                                                    ' then activate trransmitter
        TalkThroughYes                                                          ' connect RX audio to TX mike input
        Keyer.SetVolume(LowVolume)                                              ' reduce CW keyer volume 
        RogerBeep := "K"                                                        ' remember that next roger bee shall be a "K"
        Return NextActive                                                       ' make status := active
{
    If EcholinkSense == Yes                                                     ' same as above for Echolink
      pausems(100)
      If EcholinkSense == Yes   
        TxOn
        TalkThroughYes
        Keyer.SetVolume(LowVolume)                                               ' remember that next roger bee shall be a "L"
        RogerBeep := "L"
        Return NextActive
}       
    If KeyerBusy == No                                                          ' if even the keyer has finished transmitting something
      TxOFF                                                                     ' deactivate transmitter
      Return NextIdle                                                           ' goback to Idle
    
    Return NextIdle                                                             ' if nothing happened, goback to idle anyway
 
pub Active
  ' while somebody talking:
  If (CtcssSense == Yes AND CarrierSense == Yes) {OR EcholinkSense == Yes}
    TalkThroughYes                                                              ' keep sending RX audio to transmitter
    RogerBeepSent := No                                                         ' remember we did not send Roger Beep yet
    TimerRogerBeep := RunningClock + TimerRogerBeepDelta                        ' wait more time before Roger Beep
    TimerCloseDown := RunningClock + TimerCloseDownDelta                        ' wait more time before close down
    If RunningClock > TimerId                                                   ' if it's time to send our ID
      Keyer.SetVolume(LowVolume)                                                ' make sure CW volume is low
      Keyer.Send(@mycall)                                                       ' send our ID
      TimerId := RunningClock + TimerIdDelta                                    ' TimerID now contains when to send next ID
    return nextactive
  Else
    TalkThroughNo                                                               ' stop relaying audio

  if (RunningClock > TimerRogerBeep) AND RogerBeepSent == No                    ' this may happen only when no carrier nor Ctcss nor Echolink present
      Keyer.SetVolume(HighVolume)                                               ' then we may key with full audio power   
      Keyer.send(@RogerBeep)                                                    ' send the roger beeep corresponding to repeater initiator: RX or Echolink        
      RogerBeepSent := Yes                                                      ' remember it has been done to avoid repetition
      return NextActive


  if RunningClock > TimerCloseDown                                              ' this may happen only when no carrier nor Ctcss present 
      Keyer.SetVolume(HighVolume)                                               ' then we may key with full audio power
      TalkThroughNo                                                             ' make sure audio from RX is muted
      Keyer.Send(string("VA"))                                                  ' and send Roger-Out
      Repeat while Keyerbusy == Yes                                             ' wait until transmitted (it is the only place in this soft wher we really wait and block)
      TxOFF                                                                     ' stop transmitter
      return NextIdle                                                           ' and goback waiting for new events

      
      
  return NextActive

pub Sleeping

  TxOff                                                                         ' make sure transmitter is Off

  if RunningClock > TimerSleeping                                               ' put the mainstatus back to ON after TimeSleeping milliseconds
    mainstatus := RepeaterOn
    Return NextIdle

  Return  NextSleeping
    
                           ' That's all folks!
                           ' =================
                           
PRI Clock(TimeSinceReset)   ' increments continuously TimeSinceReset in milliseconds. Runs in in its own COG
  'long[TimeSinceReset] := 0
  repeat                    ' the method is not exactly tuned to one millisecond: error of less than 2 percent
    waitcnt(79_000 + cnt)   ' rough compensation: 79 instead of 80
    long[TimeSinceReset]++

pri banner(banstring)      ' trace utility routine. Be carefull, this can be very time consuming when activated
  if trace <> Yes          ' ignore if trace not activated
    return
  TraceAt(10,2,banstring)  ' display "banstring" at fixed screenplace
  pst.str(string("                               "))
  return

pri TraceAt(x,y,tracestring) ' display string at position
  if trace <> Yes            ' ignore if trace not activated
    return
  pst.position(x,y)
  pst.str(tracestring)
  return
'
'   input and output pins management
'
{
  Although it would be (very slightly) faster and with a (very slightlier) compact
  code to simply put OUTA and INA instructions into the main code, I preferred
  to have separate routines where it's easy to put debug or print instructions as well
  as to convert from positive to negative logic without making the main code heavier to read.
  We don't need so high peformance here in terms of timing.
}
pri TxON
  outa[PTT] := 1                                                                ' replace with 0 for opposite logic
  TraceAt(40,6,string("Tx      : ON "))
  Pausems(TxFullPowerDelay)                                                     ' let the transmitter gain full power
  return

pri TxOFF
  outa[PTT] := 0
  TraceAt(40,6,string("Tx      : OFF"))
  return
  
pri TxPowerON
  outa[TXPowerpin] := 1
  Pausems(500)                  ' let te transmitter initialize  ' replace with 0 for opposite logic
  TraceAt(40,5,string("Tx Power: ON "))
  return

pri TxPowerOFF
  outa[TXPOwerPin] := 0
  TraceAt(40,5,string("Tx Power: OFF"))
  return    
{                                                                               ' for future use if Echolink or similar    
pri LinkTxON
  outa[LINK_TX] := 1
  return

pri LinkTxOFF
  outa[LINK_TX] := 0
  return
 }
pri TalkThroughNo                                                               ' audio from RX NOT sent to TX 
  outa [TalkThroughPin] := 0
  TraceAt(40,8,string("Talk Through: No "))   
  return

pri  TalkThroughYes                                                             ' RX audio feeds TX input (micro)
  outa [TalkThroughPin] := 1
  TraceAt(40,8,string("Talk Through: Yes"))     
  return    
 '
'   Input pins management
'   positive or negative logic can be acoommodated replacing 0 with 1 in the "if ina ...." instructions
'
pri CarrierSense
  if ina[CarrierSensePin] <> 1                                                  ' 0 or 1 depending on positive or negative logic   
    TraceAt(10,6,string("Carrier:  ON "))  
    return Yes
  else
    TraceAt(10,6,string("Carrier:  OFF"))   
    return No  

pri CtcssSense
  if ina[CTCSSSensePin] <> 0                                                    ' 0 or 1 depending on positive or negative logic   
    TraceAt(10,7,string("Rx CTCSS: ON "))
    return Yes
  else
    TraceAt(10,7,string("Rx CTCSS: OFF"))   
    return No

{    
pri EcholinkSense
  if ina[EcholinkSensePin] <> 0                                                 ' 0 or 1 depending on positive or negative logic   
    TraceAt(10,9,string("Echolink sense :  ON "))  
    return Yes
  else
    TraceAt(10,9,string("Echolink sense :  OFF"))   
    return No
}    
pri KeyerBusy
  if ina[KeyerBusyPin] <> 0                                                     ' 0 or 1 depending on positive or negative logic   
    TraceAt(10,8,string("Keyer Busy    "))
    return Yes
  else
    TraceAt(10,8,string("Keyer Inactive"))   
    return No
    
pri pausems (duration)                                                          ' wait for duration milliseconds
  waitcnt(80_000 * duration + cnt)
  return
                           
Pri DTMFProc                                                                    ' this method runs in its own COG           
   repeat
      dtmfpointer := 0
      repeat while dtmfpointer < 4
        dtmfchar := "X"
        repeat while dtmfchar == "X"
          dtmfchar := getdtmfchar
        repeat while getdtmfchar <> "X"
        if dtmfchar == "*"
          dtmfpointer := 0
        else
          dtmfstring[dtmfpointer] := dtmfchar
          dtmfpointer++
      if strcomp(@dtmfstring,@DTMF_On) == true          
        MainStatus := RepeaterON                                                ' make repeater active
      elseif strcomp(@dtmfstring,@DTMF_Off) == true
        Mainstatus := RepeaterOFF                                               ' make repeater inactive (shut down TX power)
      elseif strcomp(@dtmfstring,@DTMF_Sleep) == true
        MainStatus := RepeaterSleeping                                          ' put repeater to sleep for a few minutes (see parameters)
      elseif strcomp(@dtmfstring,@DTMF_Reboot) == true
        Reboot
      elseif strcomp(@dtmfstring,@DTMF_TO_Long) == true                          ' reset timer to initial value                        
        TimerID := TimerIDDelta               
      elseif strcomp(@dtmfstring,@DTMF_TO_Short) == true
        TimerID := 30_000                                                       ' 30 seconds for test purpose
               
Pri GetDTMFChar | addr, i                                                       ' REM :this routine is blocking if you remove the "other: return "X"" line below
  repeat
    repeat while count == pcount
    pcount := count
    dtmfpattern := 0
    repeat i from 0 to NBINS - 1                        ' for each frequency ...
      if bins[i] > treshold                             ' get Goertzel coefficients
        setbitbyte(@dtmfpattern, i)                     ' reflect bit per bit in a byte
   case dtmfpattern                                     ' decode corresponding DTMF
     %00010001 : return "1"
     %00100001 : return "2"
     %01000001 : return "3"
     %10000001 : return "A"
     %00010010 : return "4"
     %00100010 : return "5"
     %01000010 : return "6"
     %10000010 : return "B"
     %00010100 : return "7"
     %00100100 : return "8"
     %01000100 : return "9"
     %10000100 : return "C"
     %00011000 : return "*"
     %00101000 : return "0"
     %01001000 : return "#"
     %10001000 : return "D"
     other :return "X"                                   ' return X if no valid DTMF received
  
Pri SetBitByte(variableAddr,index)                       ' set one sepcifed bit in a byte
  byte[variableAddr] := byte[variableAddr] | (1<<index)
  return
DAT
  dtmf          long      697,770,852,941,1209,1336,1477,1633  '              ' frequencies to watch for DTMF detection'
  
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