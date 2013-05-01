/*
 * servo.c -- simple servo controller
 *
 * Copyright (C) 2013, jw@suse.de, distribute under GPL, use with mercy.
 *
 * Board config:
 *   PB0:	IN right switch n-c
 *   PB1:	IN stop switch n-c
 *   PB2:	IN left switch n-c
 *   PB4:	OUT motor PWM
 *
 *   PD2:	IN motor sensor
 *   PD3:	IN hall index sensor (aka INT1)
 *   PD4:	OUT red LED
 *   PD5:	OUT green LED
 *
 * 2013-04-10, V0.1, jw - initial draught.
 * 2013-04-12, V0.2, jw - stdio removed. Not enough space.
 * 2013-04-22, V0.3, jw - added hall sensor and rs232 reporting.
 *                        Single char commands accepted:   
 *                        '+' or 'l' are same as right button (rotates ccw),   
 *                        '-' or 'r' are same as left button (rotates cw)   
 *                        ' ' toggles pause/go. A printout is done, whenever 
 *                        a command is received, even if illegal.
 * 2013-05-01, V0.4, jw - speedup() function to allow an exponential speed curve
 */

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#if __INT_MAX__ == 127
# error "-mint8 crashes stdio in avr-libc-1.4.6"
#endif
#include <avr/io.h>
#include <avr/interrupt.h>		// sei()

#include "config.h"
#include "cpu_mhz.h"
#include "version.h"
#include "rs232.h"
#include <util/delay.h>			// needs F_CPU from cpu_mhz.h

#define LED_PORT PORTD
#define LED_DDR  DDRD
#define RED_LED_BITS	(1<<4)
#define GREEN_LED_BITS	(1<<5)
#define LED_BITS	(RED_LED_BITS|GREEN_LED_BITS)
#define T1TOP  22370		// 8000000/8*0.020
#define PW_MIN   500		// 0.5 msec
#define PW_MAX  2400		// 2.4 msec
#define PW_BUT_INCR     3
#define PW_TUNED_STOP	-24

#define BUTTON_STEP_DIVISOR	500			// 200: 5 promille each 20msec
#define BUTTON_STEP (((uint16_t)PW_MAX-PW_MIN)/BUTTON_STEP_DIVISOR)

#define T1TOP  22370		// 8000000/8*0.020

#define HALL_PER_REV	1272	// or a bit less. 1274 = 13*98 ???

static uint16_t hall_counter = 0;
ISR(INT1_vect)
{
  hall_counter++;
}

int16_t speedup(int16_t speed)
{
  if (speed == 0) return 0;
  int8_t dir = 1;
  if (speed < 0)
    {
      dir = -1;
      speed = -speed;
    }

  // with speed += 1
  // -2 -1 0 1 2  3  4
  // -9 -4 0 4 9 16 25
  speed += 1;
  return speed * speed * dir;
}


#if 0	// tn2313 has not enough code space for stdio
static int rs232_putchar(char ch, FILE *fp)
{
  if (!rs232_headroom)
    {
      while (!rs232_headroom)
        ;
    }
  return rs232_send((uint8_t)ch);
}
#endif

static uint8_t cmd_seen = 0;	
static void rs232_recv(uint8_t byte)
{
  // just an echo back dummy.
  rs232_send('=');
  rs232_send(byte);
  cmd_seen = byte;
}

static void hall_init()
{
  MCUCR = (0<<ISC11)|(1<<ISC10)|	// Any change on INT1 triggers (PD3)
  	  (0<<ISC01)|(1<<ISC00);	// Any change on INT0 triggers (PD2)
  GIMSK = (1<<INT1)|(0<<INT0)|(0<<PCIE);// enable INT1 only.
  EIFR  = 0xff;				// clear any left over flags.
}

static void timer_init()
{
  /*
   * Init T1 in Fast PWM Mode, prescaler 8.
   * A prescaler of 4 would be preferred, but is not available.
   * Mode 15: TOP is OCR1A, OCR1B updates are buffered, done at TOP.
   *
   * The input capture unit is used with its noise filter enabled.
   * upon CAPTURE low high, we sample the ICR1 start
   * upon CAPTURE high low, we sample the ICR1, subtract start from it.
   * 
   * Output pin is OC1B, fully hardware driven:
   * set at TOP, cleared at OCR1B match.
   */
#if (CPU_MHZ != 8)
# error "must run at 8Mhz"
#endif

  OCR1A = T1TOP;				// fixed 50Hz
  OCR1B	= (PW_MIN+PW_MAX)/2;			// start with medium pwm

  TCCR1A = (0<<COM1A1)|(0<<COM1A0)|		// OC1A disconnected
           (1<<COM1B1)|(0<<COM1B0)|		// OC1B set at TOP, clear at OCR1B match
	   (1<<WGM11)|(1<<WGM10);		// Mode 15.

  TCCR1B = (0<<ICNC1)|(0<<ICES1)|(1<<WGM13)|(1<<WGM12)|(0<<CS12)|(1<<CS11)|(0<<CS10);

  TIMSK = 0;
  // TIMSK = (1<<ICIE1)|	// enable input capture interrupt
  // 	  (1<<OCIE1B);		// enable ouput compare interrupt B

}


int main()
{
  static uint16_t pulse_width;

  DDRB = 0;
  DDRD = 0;
  LED_DDR |= LED_BITS;			// LED pins out
  DDRB |= (1<<PB4);			// PWM out
  PORTD	= (1<<PD2)|(1<<PD3);		// pullups for sensors
  PORTB	= (1<<PB0)|(1<<PB1)|(1<<PB2);	// pullups for switches
  timer_init();
  hall_init();
  sei();			// enable interrupts.

  uint16_t pwm_stop_val = (PW_MIN+PW_MAX)/2+PW_TUNED_STOP;
  OCR1B	= pulse_width = pwm_stop_val;	// start stopped.

#define BAUD      19200
  rs232_init(UBRV(BAUD), &rs232_recv);

  uint16_t counter = 0;
  uint8_t paused = 0;
  uint8_t button_seen = 0;
  int16_t incr_counter = 0;

  for (;;)
    {
      if (!button_seen)
	{
	  if ((PINB & (1<<PB0)) || cmd_seen == '+' || cmd_seen == 'l')
	    {
	      if (!cmd_seen) button_seen = 1;
	      if (paused) 
	        {
		  pulse_width = pwm_stop_val;
		  incr_counter = 0;
		}
	      incr_counter++;
	      pulse_width = pwm_stop_val + speedup(incr_counter) * PW_BUT_INCR;
	      if (pulse_width > PW_MAX) pulse_width = PW_MAX;
	      paused = 0;
              rs232_send('l');
	    }
	  if ((PINB & (1<<PB2)) || cmd_seen == '-' || cmd_seen == 'r')
	    { 
	      if (!cmd_seen) button_seen = 1;
	      if (paused) 
	        {
		  pulse_width = pwm_stop_val;
		  incr_counter = 0;
		}
	      incr_counter--;
	      pulse_width = pwm_stop_val + speedup(incr_counter) * PW_BUT_INCR;
	      if (pulse_width < PW_MIN) pulse_width = PW_MIN;
	      paused = 0;
              rs232_send('r');
	    }
	  if ((PINB & (1<<PB1)) || cmd_seen == ' ')
	    {
	      if (!cmd_seen) button_seen = 1;
	      if (paused) 
	        {
		  paused = 0;
                  rs232_send('g');	  
		}
	      else 
	        {
		  paused = 1;
                  rs232_send('p');	  
		}
	    }
	}
      else
	{
	  // disable automatic key repeat
	  if (!(PINB & ((1<<PB0)|(1<<PB1)|(1<<PB2))))
	    button_seen = 0;	// need a release before press.
	  if (cmd_seen)
	    rs232_send('!');
	}

      if (paused)
        OCR1B = pwm_stop_val;
      else
        OCR1B = pulse_width;

      if (cmd_seen)
        {
	  cmd_seen = 0;	// very small race
          rs232_send_hex(pulse_width>>8);	  
          rs232_send_hex(pulse_width&0xff);	  
          rs232_send(' ');	  
          rs232_send_hex(hall_counter>>8);	  
          rs232_send_hex(hall_counter&0xff);	  
          rs232_send('\r');	  
          rs232_send('\n');	  
	}


      if (!(counter++ % 8))	// (1<<(led_what-1))))
        {
          _delay_ms(10.0); 
	  if (pulse_width > pwm_stop_val)
	    LED_PORT |=   GREEN_LED_BITS;         // pull high ...
	  if (pulse_width < pwm_stop_val)
	    LED_PORT |=   RED_LED_BITS;           // pull high ...
          _delay_ms(10.0);
	  if (paused) LED_PORT &= ~(LED_BITS);        // pull low ...
	  _delay_ms(80.0);
	  if (!paused) LED_PORT &= ~(LED_BITS);        // pull low ...
	}
      else
        {
	  _delay_ms(100.0);
	}
    }
}
