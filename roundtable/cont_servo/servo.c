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
 *   PD3:	IN hall index sensor
 *   PD4:	OUT red LED
 *   PD5:	OUT green LED
 *
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
#define PW_BUT_INCR     20
#define PW_TUNED_STOP	-12

#define BUTTON_STEP_DIVISOR	500			// 200: 5 promille each 20msec
#define BUTTON_STEP (((uint16_t)PW_MAX-PW_MIN)/BUTTON_STEP_DIVISOR)

#define T1TOP  22370		// 8000000/8*0.020

static int rs232_putchar(char ch, FILE *fp)
{
  if (!rs232_headroom)
    {
      while (!rs232_headroom)
        ;
    }
  return rs232_send((uint8_t)ch);
}

static uint8_t led_what = 3;	// default: flash once every second

static void rs232_recv(uint8_t byte)
{
  // just an echo back dummy.
  rs232_send('=');
  rs232_send(byte);
  if (byte > '0' && byte < '9') 
    led_what = byte - '0';
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

  sei();			// enable interrupts.
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
  uint16_t pwm_stop_val = (PW_MIN+PW_MAX)/2+PW_TUNED_STOP;
  OCR1B	= pulse_width = pwm_stop_val;	// start stopped.

#define BAUD      19200
  rs232_init(UBRV(BAUD), &rs232_recv);

  uint16_t counter = 0;
  uint8_t paused = 0;
  uint8_t button_seen = 0;

  for (;;)
    {
      if (!button_seen)
	{
	  if (PINB & (1<<PB0))
	    {
	      button_seen = 1;
	      if (paused) pulse_width = pwm_stop_val;
	      pulse_width += PW_BUT_INCR;
	      if (pulse_width > PW_MAX) pulse_width = PW_MAX;
	      paused = 0;
	    }
	  if (PINB & (1<<PB2))
	    { 
	      button_seen = 1;
	      if (paused) pulse_width = pwm_stop_val;
	      pulse_width -= PW_BUT_INCR;
	      if (pulse_width < PW_MIN) pulse_width = PW_MIN;
	      paused = 0;
	    }
	  if (PINB & (1<<PB1))
	    {
	      button_seen = 1;
	      if (paused) 
		paused = 0;
	      else 
		paused = 1;
	    }
	  }
	else
	  {
	    // disable automatic key repeat
	    if (!(PINB & ((1<<PB0)|(1<<PB1)|(1<<PB2))))
	      button_seen = 0;	// need a release before press.

	  }

      if (paused)
        OCR1B = pwm_stop_val;
      else
        OCR1B = pulse_width;

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
          // rs232_send_hex(pulse_width>>8);	  
          // rs232_send_hex(pulse_width&0xff);	  
          // rs232_send('\r');	  
          // rs232_send('\n');	  
	}
      else
        {
	  _delay_ms(100.0);
	}
    }
}
