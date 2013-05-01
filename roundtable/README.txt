					jw, Sun Apr  7 17:19:49 CEST 2013

Continuous Servo
================

Servo
-----
options: 
  Hitec HS-311 , 4,1 x 2 x 3,6 cm cr-ok, 10 EUR
  BMS-705 26 g	(42 x 21.5 x 22 mm) 4.7 kg-cm 0.13 sec @ 60 deg	 15 EUR amazon, cr??
  CS-90BB (32.1 g) 22 x 44 x 29 mm (2.6 kg-cm)	0.23 sec @ 60 deg $17.99 cr??
  CS-3, (3 kg) 35 g 38,5 x 19 x 25 mm, 14EUR amazon, cr?
  Carson 500502015 - CS-3, 31 Ncm,  0,17 sec. 45°, 38,5 x 19 x 32 mm, 11 EUR
  	http://www.ebay.de/itm/261124575800


TowerPro SG90 data:
 * 9.0 g
 * 23.1×12.2×29.0 mm
 * 4.8V: 1.8 kg-cm
 * 4.8V: 0.10 sec/60°
TowerPro SG90 modifications:
 * cut away the two plastic notches from the main wheel to allow full 360 deg.
 * cut away the two metal fins from the potentiometer to allow full 360 deg.
 * solder away the potentiometer connectors, replace by 2x 3k3 smd resistors.
 * connect a wire with 100k to one of the motor pins or somewhere near.
   Monitor pulses when the motor turns on an oscilloscope.

Controller Hardware
-------------------
Attiny2313 board:
 * 6pin isp connector male
 * 6pin rs232/bluetooth connector female
 * 2pin power in connector 5V male
 * 3pin servo connector male
 * 1pin motor monitor connector male.
 * 3pin hall sensor  male
 * Red calibration indicator LED.
 * Green speed indicator LED.
 * three push bottons labeled 'left', 'stop', 'right'.


Software
--------

Setup:
 * 8mhz internal rc oscillator.
 * RS232 i/o driver in main loop.
 * 16bit PWM generator single channel 50hz, 1.0ms -- 2.0ms pulse.
 * Timer0 full speed, overflow at 80, with ca 100khz
 * 3 Interrupts: 
   16bit counters for hall sensor, timer0 overflow and motor monitor pulses.
 * Each hall sensor 0->1 or 1->0 we switch the green LED.
   If we know we move forward, we switch on, when the hall sensor goes 1
   Otherwise we switch on, when the hall sensor goes 0.

Calibration algorithm:
 We need to find the midpoint pwm value, where the motor would neither rotate
 forward nor backwards.  The 3k3 + 3k3 voltage divider put this value 
 approximatly at 1.5ms, we read this default value from the eeprom, at power up.
 if the value reads 0 or 0xffff, then we choose 1.5ms.

 At startup, or whenever speed 0 is set we calibrate this value
 * start with PWM 1.5ms (or previous value, if any)
 * every monitor pulse, read timer counter, if timer counter is above an 
   idle threshold:
    Choose increase mode. Increasingly adjust the motor pwm, until the 
    timer counter reliably reads a different value. If it is less, then 
    store this as new calibration value. If it is more, then toggle
    increas/decrease mode. Repeat until 
     a) 100 retries or b) timer counter reads below idle threshold.
    If a) then red error LED on.  Reset to 1.5ms, restart.
    If b) save calibration value to eeprom, print "stop %d\n" to stdout.
 Calibration done.

Command mode algorithm:
 If 'left' is pressed, decrease PWM width. forward rotation slows down
 and may eventually begin to rotate backwards, increasingly faster.
 If 'right' is pressed, increase PWM width. backwards rotation speeds and
 may eventually begin to rotate forward, increasingly faster.

 A +0 and -0 setting exists seperatly. Both have no movement, but the 
 green LED is on for the -0 setting and off for +0. Calibration is run, 
 continuously when in +0 or -0 setting. Calibration is saved to eeprom, 
 when toggling between +/-0.

 If 'stop' is pressed, speed is changed to +0 or -0; the one that does not 
 change sign is chosen.

 All changes are reported on stdout.

 Additional commands are accepted on stdin: 
 '+' => right
 '-' => left
 ' ' => toggle pause/go
 '1' ... '9' predefined speeds.
 '.' tenth introducer (with timeout waiting for another digit).
 

					jw, Sun Apr  7 17:19:31 CEST 2013

main_gear.svg
-------------
All that is round done. Servo and pinion supports added
Cut each layer twice from 4mm plywood or better quality wood.
Test done: 6mm plywood needs too much energy, it produces char-coal. Not good.

The diameter of the laser-beam is 0.3mm 
TODO: apply tooling correction to the main_gear.svg


					jw, Mon Mar 25 22:43:27 CET 2013

An inexpensive rotory table
---------------------------

This rotory table is designed to be sturdy, quite precise,
inexpensive and reproducable with a lasercutter.

Technical data (wooden protoype)
--------------------------------

Wooden Modell
 Diameter:     275 mm
 Height:     ca 40 mm
 Max Speed open loop: 7.2 RPM (8.4sec / Rev)
 Min Speed open loop: 0.5 RPM (120sec / Rev)
 Max Force:   ca 1 Nm
 Speed/Position Control: Arduino compatible

Concept
------- 
 Material: HDF (Hartfaserplatte) 4mm(& 3mm); 5x 30x40cm
           Steel pins 2mm diameter.
 Motor:    Mini-Servo TowerPro 90 (modded for continuous rotation)
 Control:  Attiny2313, PWM input or RS232 input
 Center:   No axis. Allows for custom openings.
 Positioning: Magnetic index on Servo, ca 600 Pulses per Revolution
 Total Cost: below 20 EUR

 All parts are cut from plywood. Several rings are cut in smaller segments
 to better use available area. The rotating top part is held down only by 
 its own weight and can be pulled upwards to open the rotary table.

 The top rests on six (wooden) wheels, and is centered by 4 pinions, 
 one of them driven by the servo. The pinions have 18 teeth each and mesh
 inside a ring of 234 teeth. 
 
