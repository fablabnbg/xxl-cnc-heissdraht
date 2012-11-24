/* 
 * PWMoutMK2.c -- PWM output generator for project Nely
 *
 * Copyright (C) 2009 Juergen Weigert
 *
 * Distribute under any GPL.
 * Have mercy, use with care.
 *
 * PWMoutMK2.c is a test implementation of an I2C snoop device.
 * We never pull SCL or SDA lines, we only listen and copy.
 * This device shall can be soldered into the I2C bus of an existing MK2
 * it will output RC conform PWM signals for driving Nely motor controllers.
 * The I2C protocol within the MK2 circuits is driven by the BL-CTRL slaves
 * which listen to the same addresses than we do.
 * MK2 uses one BL-CTRL per address; we use one PWMoutMK2 for all 4 addessess.
 * We'll use an ATmega48, so that we have excessive program and variable space 
 * if needed.
 *
 * Atmega48 has 2 8bit timer channels with two outputs each, and 1 16bit timer channel.
 * We can program all 4 8bit timers for one shot, and trigger them with the 16bit timer.
 * This creates a jitter-free hardware timer unit with sufficient resolution.
 *
 *
 * 2009-11-01, jw, V0.1 - branched from tinyPWMout
 * 2009-11-15, jw, V1.5 - can snoop on all 4 slave addresses. Yeah, it is possible!
 *                        This snoop is fully interrupt driven. Main loop still idles.
 * 2009-11-17, jw, V1.6 - delay at POR, so that FlightCtrl does not get confused.
 *                        mk2byte_to_pwm() done, integrator done. needs testing.
 * 2009-11-21, jw, V1.7 - debugging: integrator used only 2.5msec instead of 20msec
 *                        Flight test: MOTOR_MAX_HACKER_X30 was too low.
 * 2009-11-22, jw, V1.8 - added support for both hacker_x30 and kontronik_jazz
 * 2009-12-21, jw, V1.9 - debugged jitter. PWM_NCHAN <=5 cures it.
 * 2009-01-01, jw, V1.10 - More debugging n_ch[] should not exceed 8, to avoid hickups.
 *                         Feels like squashing symtoms without knowing the cause.
 *                         Extended MOTOR_MAX_HACKER_X30 from 15000 to 17500 to allow full range.
 * 2010-01-31, jw,         Added Board Layout Ascii Art. (very similar to I2CslaveMK2)
 * 2012-06-16, jw, V1.11 - SERVO_STANDARD added as a generic alternative to tuned ranges of
 *                         Hacker and Kontronic motor controllers.
 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * Programming: Pull SDA Jumper near pin 7 (tn2313 tn24)
 * -------------------------------------------------------------
 */
/*
 *	    |  ATmega48   | __AVR_ATtiny2313__ |  __AVR_ATtiny24__
 * ---------|-------------|--------------------|----------------------
 * I2C_SDA  |  PC4  DIL27 |  PB5  DIL17  MLF15 |  PA6	DIL7	MLF16
 * I2C_SCL  |  PC5  DIL28 |  PB7  DIL19  MLF17 |  PA4	DIL9	MLF1
 * ---------|-------------|--------------------|----------------------
 * PWM_CH1  |  PB0  DIL14 |  PB0  DIL12  MLF10 |  PB0	DIL2	MLF11
 * PWM_CH2  |  PB1  DIL15 |  PB1  DIL13  MLF11 |  PB1	DIL3	MLF12
 * PWM_CH3  |  PB2  DIL16 |  PB2  DIL14  MLF12 |  PB2	DIL5	MLF14
 * PWM_CH4  |  PB3  DIL17 |  PB3  DIL15  MLF13 |  PA0	DIL13	MLF5
 * PWM_CH5  |  PB4  DIL18 |  PB4  DIL16  MLF14 |  PA1	DIL12	MLF4
 * PWM_CH6  |  PB5  DIL19 |  PD4  DIL8   MLF6  |  PA2	DIL11	MLF3
 * PWM_CH7  |  PB6  DIL9  |  PD3  DIL7   MLF5  |  PA3	DIL10	MLF2
 * PWM_CH8  |  PB7  DIL10 |  PD2  DIL6   MLF4  |  PA5	DIL8	MLF20
 * PWM_CH9  |  PD2  DIL4  |  PD1  DIL3   MLF1  |  PA7	DIL6	MLF15	(addr-sel, debug LED)
 * PWM_CH10 |             |  PD0  DIL2   MLF20 |  (PB3	DIL4	MLF13 	reset)
 *	    |             |                    |  
 *             4k/256/512 |  2k/128/128        |  2k/128/128
 *
 * tested with tiny2313, 1..10 channels.
 * A channel may be disabled by programming 0
 *
 * With up to 8 channels, the maximum pulse width corresponds to 2.5usec
 * With 9 or 10 channels, the maximum pulse width corresponds to 2.0usec
 *
 */
#if 0

Board Layout:
			
        	           I2C-connector
                  	.-----------------.
                        | (-) (C) (D) (+) | 
           ServoPower
                (o)       ATmega48 DIL
                (o)     _______   ______	 RS232 connector
 Servo connectors      |       \_/      |           	(RxD)
  (PB3) (+) (-)	    (1)Reset          SCL(28)       	(TxD)        
  (PB2) (+) (-)	    (2)TxD            SDA(27)       	(GND)        
  	            (3)RxD               (26)                     
  (PB1) (+) (-)	    ...                ...      ISP Connector    
  (PB0) (+) (-)     (7)+5V            GND(22)		(GND)
 		    (8)GND               (21)     	(RES)
  (PB3) (+) (-)	    (9)X1             VCC(20)		(+5V)
  (PB2) (+) (-)	   (10)X2         PB5/SCK(19)		(SCK)
 	       	   (11)PD5       PB4/MISO(18)		(MISO)
  (PB1) (+) (-)	   (12)PD6       PB3/MOSI(17)		(MOSI)
  (PB0) (+) (-)    (13)PD7            PB2(16)
                   (14)PB0            PB1(15)
  (RES) (+) (-)        |________________|
               	
#endif


#define USE_STDIO 1
#ifdef USE_STDIO
# include <ctype.h>
# include <stdint.h>
# include <stdio.h>
# if __INT_MAX__ == 127
#  error "-mint8 crashes stdio in avr-libc-1.4.6"
# endif
#endif
#include <avr/io.h>
#include <util/twi.h>		// TW_SR_xxx
#include <avr/wdt.h>
#include <avr/interrupt.h>
#include "cpu_mhz.h"
#include "config.h"
#include "rs232.h"

#include <util/delay.h>			// needs F_CPU from cpu_mhz.h

#define VERSION_MAJOR	1
#define VERSION_MINOR	11

#ifndef DEBUG
# define DEBUG 1
#endif
#ifndef HAVE_RS232 
# define HAVE_RS232 1
#endif

#ifndef PWM_NCHAN
# define PWM_NCHAN 4	// we get massive jitter and low ch1 ch2 values if PWM_NCHAN > 5. Why?
#endif

#ifndef HAVE_WDT
# define HAVE_WDT 1
#endif

#define PWM_NCHAN_MAX	 10
#if (PWM_NCHAN > PWM_NCHAN_MAX)
# error "PWM_NCHAN exceeds EE layout limit"
#endif

#ifndef PWM_BAD_TIMEOUT
# define PWM_BAD_TIMEOUT	200	// 80==1.5s; 40==0.75sec; 200==4sec;
					// nr. of frames before approach_defaults();
					// define to 0 in config.h to disable.
#endif

#if (EE_OFF_USED_CEIL > EEPROM_SIZE)
# error "Ouch, data layout does not fit in EEPROM"
#endif

#if (PWM_NCHAN > 8)
# if CPU_MHZ == 8
#  define PWM_TMAX	16000
# endif
# if CPU_MHZ == 16
#  define PWM_TMAX	32000
# endif
# if CPU_MHZ == 20
#  define PWM_TMAX	40000
# endif
#else
# if CPU_MHZ == 8
#  define PWM_TMAX	20000
# endif
# if CPU_MHZ == 16
#  define PWM_TMAX	40000
# endif
# if CPU_MHZ == 20
#  define PWM_TMAX	50000
# endif
#endif
#define PWM_TOFF (PWM_TMAX/10)			// enable if > 250usec
#define PWM_TMIN (PWM_TMAX/4)			// min 500usec
#define PWM_DEFAULT 0

static uint16_t mk2byte_to_pwm_servo_kds290(uint8_t byte)
{
  // KDS N290 Servos have a very limited range. 
  // They only do 90 deg.  and move between 1.0ms and 2.0ms
#if CPU_MHZ == 8
# define SERVO_KDS290_OFF  8000   // 4100 eq 0.5ms
# define SERVO_KDS290_MIN  8000   // 4100 eq 0.5ms
# define SERVO_KDS290_MAX 16500	  // 19000 eq 2.3ms 
# define SCALE_UP_SERVO_KDS290 \
	((SERVO_KDS290_MAX - \
	  SERVO_KDS290_MIN)>>8)
#else
# error "SERVO_KDS290_OFF/MIN/MAX known only for 8Mhz"
#endif
  // if (!byte) return SERVO_KDS290_OFF;
  uint16_t v =  byte * SCALE_UP_SERVO_KDS290 + SERVO_KDS290_MIN;
  if (v > SERVO_KDS290_MAX)
      v = SERVO_KDS290_MAX;
  return v;
}


static uint16_t mk2byte_to_pwm_hacker(uint8_t byte)
{
#if CPU_MHZ == 8
// from nely-1.67/master/master.c
# define MOTOR_OFF_HACKER_X30 7000
# define MOTOR_MIN_HACKER_X30 7500      // was 8000, 7700
# define MOTOR_MAX_HACKER_X30 17500	// 17500 eq 2.1ms (was 15000)
# define MOTOR_MAX_HACKER_X30_EXTRA 0	// always 0, unless we suspect a range error
# define SCALE_UP_HACKER_X30 \
	((MOTOR_MAX_HACKER_X30 + \
	  MOTOR_MAX_HACKER_X30_EXTRA - \
	  MOTOR_MIN_HACKER_X30)>>8)
#else
# error "MOTOR_OFF/MIN/MAX known only for 8Mhz"
#endif
  if (!byte)
    return MOTOR_OFF_HACKER_X30;
  uint16_t v =  byte * SCALE_UP_HACKER_X30 + MOTOR_MIN_HACKER_X30;
  if (v > MOTOR_MAX_HACKER_X30)
      v = MOTOR_MAX_HACKER_X30;
  return v;
}

static uint16_t mk2byte_to_pwm_kontronik(uint8_t byte)
{
#if CPU_MHZ == 8
// from nely-1.67/master/master.c
# define MOTOR_OFF_KONTRONIK_JAZZ 15000
# define MOTOR_MIN_KONTRONIK_JAZZ 11000		// was 13000
# define MOTOR_MAX_KONTRONIK_JAZZ  4000		// was 5000
# define MOTOR_MAX_KONTRONIK_JAZZ_EXTRA -9000	// was 0
# define SCALE_UP_KONTRONIK_JAZZ \
	((MOTOR_MAX_KONTRONIK_JAZZ + \
	  MOTOR_MAX_KONTRONIK_JAZZ_EXTRA - \
	  MOTOR_MIN_KONTRONIK_JAZZ)>>8)
#else
# error "MOTOR_OFF/MIN/MAX known only for 8Mhz"
#endif
  if (!byte)
    return MOTOR_OFF_KONTRONIK_JAZZ;
  int16_t v =  byte * SCALE_UP_KONTRONIK_JAZZ + MOTOR_MIN_KONTRONIK_JAZZ;
  if (v < MOTOR_MAX_KONTRONIK_JAZZ)
      v = MOTOR_MAX_KONTRONIK_JAZZ;
  return v;
}

#if defined(__AVR_ATtiny2313__)
# if (PWM_NCHAN <= 1)
#  define PORTB_PWM_BITS 0x01
# endif
# if (PWM_NCHAN == 2)
#  define PORTB_PWM_BITS 0x03
# endif
# if (PWM_NCHAN == 3)
#  define PORTB_PWM_BITS 0x07
# endif
# if (PWM_NCHAN == 4)
#  define PORTB_PWM_BITS 0x0f
# endif
# if (PWM_NCHAN >= 5)
#  define PORTB_PWM_BITS 0x1f
# endif
# if (PWM_NCHAN == 6)
#  define PORTD_PWM_BITS 0x10
# endif
# if (PWM_NCHAN == 7)
#  define PORTD_PWM_BITS 0x18
# endif
# if (PWM_NCHAN == 8)
#  define PORTD_PWM_BITS 0x1c
# endif
# if (PWM_NCHAN == 9)
#  define PORTD_PWM_BITS 0x1e
# endif
# if (PWM_NCHAN == 10)
#  define PORTD_PWM_BITS 0x1f
# endif
#endif

#if defined(__AVR_ATmega48__)
# if (PWM_NCHAN <= 1)
#  define PORTB_PWM_BITS 0x01
# endif
# if (PWM_NCHAN == 2)
#  define PORTB_PWM_BITS 0x03
# endif
# if (PWM_NCHAN == 3)
#  define PORTB_PWM_BITS 0x07
# endif
# if (PWM_NCHAN == 4)
#  define PORTB_PWM_BITS 0x0f
# endif
# if (PWM_NCHAN == 5)
#  define PORTB_PWM_BITS 0x1f
# endif
# if (PWM_NCHAN == 6)
#  define PORTB_PWM_BITS 0x2f
# endif
# if (PWM_NCHAN == 7)
#  define PORTB_PWM_BITS 0x3f
# endif
# if (PWM_NCHAN == 8)
#  define PORTB_PWM_BITS 0xff
# endif
# if (PWM_NCHAN == 9)
# error "channel 9 not wired"
#  define PORTB_PWM_BITS 0xff
# endif
# if (PWM_NCHAN == 10)
# error "channel 10 not wired"
#  define PORTB_PWM_BITS 0xff
# endif
#endif

#if defined(__AVR_ATtiny24__)
# if (PWM_NCHAN <= 1)
#  define PORTB_PWM_BITS 0x01
# endif
# if (PWM_NCHAN == 2)
#  define PORTB_PWM_BITS 0x03
# endif
# if (PWM_NCHAN == 3)
#  define PORTB_PWM_BITS 0x07
# endif
# if (PWM_NCHAN == 4)
#  define PORTB_PWM_BITS 0x07
#  define PORTA_PWM_BITS 0x01
# endif
# if (PWM_NCHAN == 5)
#  define PORTB_PWM_BITS 0x07
#  define PORTA_PWM_BITS 0x03
# endif
# if (PWM_NCHAN == 6)
#  define PORTB_PWM_BITS 0x07
#  define PORTA_PWM_BITS 0x07
# endif
# if (PWM_NCHAN == 7)
#  define PORTB_PWM_BITS 0x07
#  define PORTA_PWM_BITS 0x0f
# endif
# if (PWM_NCHAN == 8)
#  define PORTB_PWM_BITS 0x07
#  define PORTA_PWM_BITS 0x2f
# endif
# if (PWM_NCHAN == 9)
#  define PORTB_PWM_BITS 0x07
#  define PORTA_PWM_BITS 0xaf
# endif
# if (PWM_NCHAN == 10)
#  define PORTB_PWM_BITS 0x0f
#  define PORTA_PWM_BITS 0xaf
# endif
#endif

static volatile uint16_t pwm_cur[PWM_NCHAN];	// current value
static volatile uint8_t cur_chan;	// 0 here corresponds to PWM_CH1
static volatile uint8_t ovl_count = 0;	// frames without i2c input.

// BL-CTRL says
// Slaveadr = 0x52 = Vorne, 0x54 = Hinten, 0x56 = Rechts, 0x58 = Links
// those are multiplied by two.

// addr 41 = front, 42 = back, 43 = right, 44 = left
#define I2C_ADDR_BASE 41
#define I2C_ADDR_TOP  44
#define I2C_ADDR_N    (I2C_ADDR_TOP-I2C_ADDR_BASE+1)
// listen to 40..47, which is the smallest range that includes 41..44
#define I2C_ADDR_MASK 0x07

#if (((I2C_ADDR_BASE & ~I2C_ADDR_MASK) + I2C_ADDR_MASK) < I2C_ADDR_TOP)
# error "I2C_ADDR_MASK does not cover I2C_ADDR_BASE..I2C_ADDR_TOP"
#endif

volatile static uint8_t  ch_r[8];		// last raw byte value
volatile static uint8_t ch_n[I2C_ADDR_N];	// nr of values seen
volatile static uint16_t ch_v[I2C_ADDR_N];	// sum of values seen
volatile static uint8_t maxcount = 0;
volatile static uint8_t twi_seen = 0;


ISR(SIG_OUTPUT_COMPARE1A)
{
  // this triggers once every 2.5msec (aka once per channel)
  // creating the fixed time slots for every channel.
  // This way, channel phase does not change, when lower channel numbers change value.
  volatile uint16_t width = (cur_chan < PWM_NCHAN) ? pwm_cur[cur_chan] : 0;

  if (width > PWM_TOFF)			// enable if > 250usec
    {
      // switch on a PWM pin.
#if defined(__AVR_ATmega48__)
      PORTB |= (1<<cur_chan);
#endif
#if defined(__AVR_ATtiny2313__)
      if (cur_chan < 5) PORTB |= (1<<cur_chan);
      else 		PORTD |= (1<<(9-cur_chan));
#endif
#if defined(__AVR_ATtiny24__)
      if      (cur_chan < 3)  PORTB |= (1<<cur_chan);
      else if (cur_chan < 7)  PORTA |= (1<<(cur_chan-3));
      else if (cur_chan == 7) PORTA |= (1<<PA5);
# if (NCHAN > 8)
      else if (cur_chan == 8) PORTA |= (1<<PA7);
      else if (cur_chan == 9) PORTB |= (1<<PB3);
# endif
#endif
      OCR1B = width;
    }
  else
    OCR1B = PWM_TMAX/2;			// invisible dummy 

  // prepare next channel
#if (PWM_NCHAN < 8)
  if (++cur_chan >= 8) cur_chan = 0; 		// 8 channels minimum for frameing.
#else
  if (++cur_chan >= PWM_NCHAN) cur_chan = 0;
#endif

  if (cur_chan == 0 && ovl_count < 0xff) ovl_count++;

#if PWM_BAD_TIMEOUT
  if (cur_chan == 0 && ovl_count > PWM_BAD_TIMEOUT)
    {
      // trivial hard cut version of approach_defaults():
      for (cur_chan = 0; cur_chan < PWM_NCHAN; cur_chan++)
        pwm_cur[cur_chan] = PWM_DEFAULT;
      cur_chan = 0;
    }
#endif
}


ISR(SIG_OUTPUT_COMPARE1B)
{
  // switch off all PWM pins.
  PORTB &= ~(PORTB_PWM_BITS);
#ifdef PORTD_PWM_BITS
  PORTD &= ~(PORTD_PWM_BITS);
#endif
#ifdef PORTA_PWM_BITS
  PORTA &= ~(PORTA_PWM_BITS);
#endif

# if DEBUG
  PIND |= (1<<PD2);	// heartbeat LED toggle
# endif

  volatile uint8_t my_cur_chan = cur_chan;
  
  if (my_cur_chan < PWM_NCHAN)
    {
      // we calculate now the next pwm_cur[] value.
      // we do it after changing pins, so that the time needed during calculation
      // does not influence the timing.
      // and we do it for exaclty only the next cur_chan here for lowest latency.

      // this takes 7 .. 50 usec
      // Read the regs, while intterupts are still disabled... (since this is ISR())
      volatile uint8_t n  = ch_n[my_cur_chan];
      volatile uint16_t v = ch_v[my_cur_chan];
      // we do a lot of uncritical math below. allow nested interrupts.
      sei();

      if (n)
        {
          volatile uint8_t byte = ((v+(n>>1))/n);
#ifdef HAVE_SERVOS_NELY
	  // numbering on the mikrokopter is north=1, south=2, east=3, west=4
	  // north and south run clockwise, east and west counterclockwise.
          if (my_cur_chan < 2)
            pwm_cur[my_cur_chan] = mk2byte_to_pwm_servo_kds290(byte);
          else
            pwm_cur[my_cur_chan] = mk2byte_to_pwm_servo_kds290(255-byte);
#else
# ifdef HAVE_MIXED_MOTORS
          if (my_cur_chan < 2)
            pwm_cur[my_cur_chan] = mk2byte_to_pwm_kontronik(byte);
          else
            pwm_cur[my_cur_chan] = mk2byte_to_pwm_hacker(byte);
# else
          pwm_cur[my_cur_chan] = mk2byte_to_pwm_hacker(byte);
          if (my_cur_chan < 4) ch_r[my_cur_chan+4] = byte;
# endif
#endif
          ch_v[my_cur_chan] = 0; ch_n[my_cur_chan] = 0;
          maxcount = n;
	}
    }
}

#if HAVE_RS232 && USE_STDIO
static int rs232_putchar(char ch, FILE *fp)
{
  if (!rs232_headroom)
    {
      while (!rs232_headroom)
        ;
    }
  _delay_ms(0.2);	// FIXME: we see glitches otherwise...
  return rs232_send((uint8_t)ch);
}
#endif

static uint8_t lcd_what = 1;

// rs232 input can select multiple display pages.
// the buttons on the lcd send numbers 1..8

static void rs232_recv(uint8_t byte)
{
  // just an echo back dummy.
  rs232_send('=');
  rs232_send(byte);
  if (byte > '0' && byte < '9') 
    lcd_what = byte - '0';
}


#if HAVE_WDT		// see group__avr__watchdog.html
// without this, a watchdog can be as deadly as no watch dog at all.
// it may hang during init. Seen on an attiny24
uint8_t mcusr_mirror __attribute__ ((section (".noinit")));
void get_mcusr(void) __attribute__((naked)) __attribute((section(".init3")));
void get_mcusr(void)		// 14 bytes
{
  mcusr_mirror = MCUSR;
  MCUSR = 0;	// RESET bits by writing 0. doc2545 p48
  wdt_disable();
}
#endif

static void t1_init()
{
#if defined(__AVR_ATtiny2313__) || defined(__AVR_ATtiny24__) || defined(__AVR_ATmega48__)
  // CTC-Mode 4 with OCR1A as TOP	//(0<<WGM13)|(1<<WGM12)|(0<<WGM11)|(0<<WGM10);
  // TOV does not trigger in CTC mode.
  OCR1A = PWM_TMAX;					// TOP.
  OCR1B = PWM_DEFAULT; 					// value to start.
  TCNT1 = 0;						// TOP.
  TCCR1A = (uint8_t)((0<<COM1A1)|(0<<COM1A0)|		// disconnect OC1A from PB3
                     (0<<COM1B1)|(0<<COM1B0)|		// disconnect OC1B from PB4
		     (0<<WGM11)|(0<<WGM10));		// mode 4
  TCCR1B = (uint8_t)((0<<CS12)|(0<<CS11)|(1<<CS10)|	// full speed, no prescaler 
                     (0<<ICNC1)|(0<<ICES1)|		// no ICP1 tricks
		     (0<<WGM13)|(1<<WGM12));		// mode 4
# if defined(__AVR_ATtiny24__) || defined(__AVR_ATmega48__)
  TIMSK1 = (uint8_t)((1<<OCIE1A)|(1<<OCIE1B)); 		// A+B int.req: yes
# else
  TIMSK  = (uint8_t)((1<<OCIE1A)|(1<<OCIE1B)); 		// A+B int.req: yes
# endif
#else
# error "timer impl. only for tiny2313, tiny24, mega48"
#endif
}


static void i2c_init()
{
#if defined(__AVR_ATmega48__)
  // doc2545, p205ff

  // TWAR: TWA[6-0], TWGCE	(slave mode only)
  // TWAMR: TWAM[6-0]		(slave mode only)
  // TWBR			(master mode only)
  // TWCR: TWINT, TWEA, TWSTA, TWSTO, TWWC, TWEN, TWIE
  // TWDR: 
  // TWSR: TWS[7-3], TWPS[1-0]

  TWAR =  (I2C_ADDR_BASE<<1) | (0<<TWGCE);		// listen to base address 
  TWAMR = (I2C_ADDR_MASK<<1) | (0<<0);			// and upwards...

  TWDR = 0xff;				// default to line released
  TWCR = (1<<TWINT)|(1<<TWEA)|(0<<TWSTA)|(0<<TWSTO)|\
         (0<<TWWC)|(1<<TWEN)|(1<<TWIE);
  // TWINT: set by hardware when ready for software;
  //        and reset by software, when hardware may shift in more bits
  // TWEA: 0=no ack, disconnecte. 1=normal ack
  // TWSTA: master 1=send start cond
  // TWSTO: slave 1=recover from error: release lines, reset state.
  // TWWC: set by hardware of write collistion

  // doc2545, p227ff

#else
# error "i2c_init slave hardware, snoop mode: only impl for mega48"
#endif // __AVR_ATmega48__
}

#if 0
static void i2c_reset()
{
  TWCR |= (1<<TWSTO);
  // slave 1=recover from error: release lines, reset state.
}
#endif

// modelled after http://www.ermicro.com/blog/?p=1239
ISR(TWI_vect)
{
  static volatile uint8_t i2c_state = 0;
  static volatile uint8_t i2c_addr = 0;
  uint8_t twi_TWSR = TWSR;
  uint8_t twi_TWDR = TWDR;

  // cli();		// this is default unless ISR(... ,ISR_NOBLOCK)
  twi_TWSR = twi_TWSR & 0xF8;     // get status, mask prescaler bits

  // do not look into TWDR after this:
  // TWCR |= (1<<TWINT);    // Clear TWINT Flag

  switch(twi_TWSR) 
    {
    case TW_SR_SLA_ACK:           // 0x60: SLA+W received, ACK returned
      i2c_addr = twi_TWDR >> 1;  // here we see our own slave address
      i2c_state = 0;            // Start I2C State for Register Address required	 

      TWCR |= (1<<TWINT);    // Clear TWINT Flag
      break;

    case TW_SR_DATA_ACK:     // 0x80: data received, ACK returned
      if (i2c_addr >= I2C_ADDR_BASE && i2c_addr <= I2C_ADDR_TOP)
	{
	  if (i2c_state == 0) 
	    {
	      // first byte for this channel
	      // BUG alert: the servo sneezes, sometimes, if we let ch_n go beyond 8.
	      if (ch_n[i2c_addr-I2C_ADDR_BASE] < 8)
	        {
	          ch_v[i2c_addr-I2C_ADDR_BASE] += twi_TWDR;
	          ch_r[i2c_addr-I2C_ADDR_BASE] =  twi_TWDR;
	          ch_n[i2c_addr-I2C_ADDR_BASE]++;
	        }
	      twi_seen++;
	      i2c_state = 1;
	    }
	  // no other bytes used
	}

      TWCR |= (1<<TWINT);    // Clear TWINT Flag
      break;

    case TW_SR_STOP:         // 0xA0: stop or repeated start condition received while selected
      
      // if (i2c_state == 2) {
	i2c_state = 0;	      // Reset I2C State
      // }	   

      TWCR |= (1<<TWINT);    // Clear TWINT Flag
      break;

    case TW_ST_SLA_ACK:      // 0xA8: SLA+R received, ACK returned
    case TW_ST_DATA_ACK:     // 0xB8: data transmitted, ACK received
//      if (i2c_state == 1) {
//	i2c_slave_action(0); // Call Read I2C Action (rw_status = 0)
//
//	TWDR = regdata;      // Store data in TWDR register
	i2c_state = 0;	      // Reset I2C State
//      }	   	  

      TWCR |= (1<<TWINT);    // Clear TWINT Flag
      break;

    case TW_ST_DATA_NACK:    // 0xC0: data transmitted, NACK received
    case TW_ST_LAST_DATA:    // 0xC8: last data byte transmitted, ACK received
    case TW_BUS_ERROR:       // 0x00: illegal start or stop condition
    default:
      TWCR |= (1<<TWINT) | (1<<TWSTO);    // Clear TWINT Flag and reset bus
      i2c_state = 0;         // Back to the Begining State
    }

  // Enable Global Interrupt
  // sei();	this was default anyway
}

 
int main()
{
  int8_t i;

  // start the PWM generator in Interrupt mode.
  // init 16bit counter freerunning for PWM generator
  cur_chan = 0;
  for (i = 0; i < PWM_NCHAN; i++) pwm_cur[i] = PWM_DEFAULT;

  t1_init();

  PORTB &= ~(PORTB_PWM_BITS); DDRB |= PORTB_PWM_BITS;
#ifdef PORTD_PWM_BITS
  PORTD &= ~(PORTD_PWM_BITS); DDRD |= PORTD_PWM_BITS;
#endif
#ifdef PORTA_PWM_BITS
  PORTA &= ~(PORTA_PWM_BITS); DDRA |= PORTA_PWM_BITS;
#endif
#if DEBUG
  DDRD |= (1<<PD2);	// heartbeat LED 
#endif

  sei();

  rs232_init(UBRV(38400), &rs232_recv);
  FILE lcd_fp = FDEV_SETUP_STREAM(rs232_putchar, NULL, _FDEV_SETUP_WRITE);
  stdout = &lcd_fp;
  putchar('\n');
  putchar('X');

#if HAVE_WDT
  if (mcusr_mirror & (1<<PORF))
    {
      // If we came from power on reset:
      // Wait for FlightCtrl to initialize the motors, otherwise we have a bus
      // congestion right from the start. It probably does some queries that we
      // mess up (e.g. detecting number of motors).
      // (Not needed with new ME hardware, where we are alone, 
      // but still a good idea to remain compatible.)

      for (i = 0; i < 15; i++)
        {
          _delay_ms(200.0);	
          putchar('P');
	}
    }

  wdt_enable(WDTO_2S);
#endif
  i2c_init();
  
  i=20;
  pwm_cur[0] = PWM_TMAX/3+0;
  pwm_cur[1] = PWM_TMAX/3+1;
  pwm_cur[2] = PWM_TMAX/3+2;
  pwm_cur[3] = PWM_TMAX/3+3;
  for (;;)
    {
#if 0
      uint16_t x = pwm_cur[1]+i;
      if (x > PWM_TMAX || x < PWM_TMIN)
	i = -i; 
      else
        pwm_cur[1] = x;
#endif
      ovl_count = 0;

      _delay_ms(200.0);	
      if (twi_seen)
        {
#if 0
	  printf("%02x %d %d %d %d %d %d %d %d %02x \r", twi_seen, 
	  	ch_r[0], ch_r[1], ch_r[2], ch_r[3], ch_r[4], ch_r[5], ch_r[6], 
		ch_r[7], maxcount);
#else
	  printf("%02x%5d%5d%5d%5d %02x \r", twi_seen, pwm_cur[0], pwm_cur[1], pwm_cur[2],
	                                                  pwm_cur[3], maxcount);
#endif
	  twi_seen=0;
	}
      else
        putchar('.');
      // rs232_send('.');
#if HAVE_WDT
      wdt_reset();
#endif
    }
}
