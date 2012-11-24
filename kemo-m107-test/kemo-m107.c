/*
 * pwm for KEMO m107 -- simple test
 *
 * Copyright (C) 2012, jnweiger@gmail.com, distribute under MIT License, use with mercy.
 *
 * 2012-08-10, V0.01 -- initial draught, can drive the m107, cool.
 * 2012-08-12, V0.02 -- Move hall sensor to port C, so that motor drivers on port B
 *                      can never cause spurious PCINT. 
 *                      ISR(PCINT1_vect) counts hall sensor pulses.
 * 2012-08-14, V0.03 -- PWM generator via timer0
 * 2012-08-16, V0.04 -- Measuring speed and absolute position. looks good.
 *                      m0.priv.dir is needed, as we see pulses 200msec after switching off.
 *                      We see max 700 pulses/sec with 8 magnets. Equals ca 5200 rpm.
 * 2012-08-31, V0.05 -- factored out servo_data.h -- fully interrupt driven closed loop.
 */

#define VERSION '0.05'

#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#if __INT_MAX__ == 127
# error "-mint8 crashes stdio in avr-libc-1.4.6"
#endif
#include <avr/io.h>
#include <util/twi.h>		// TW_SR_xxx
#include <avr/wdt.h>
#include <avr/interrupt.h>

// #include "config.h"
#include "rs232.h"
#include "cpu_mhz.h"

#include <util/delay.h>			// needs F_CPU from cpu_mhz.h
#include "motor_data.h"			// port bits and driver data object

#define LED_PORT	PORTD
#define LED_DDR		DDRD
#define LED_BV		(1<<PD3)

// MSEC_DELAY 0.25 is just great for Pollin GMDP/404980 Motors
//                 (effective 31 HZ)
// MSEC_DELAY 0.1  is best with SPG DGO-3512ADA Motors

static void timer0_init(void);
static void rs232_recv(uint8_t byte);
static int rs232_putchar(char ch, FILE *fp);
static void rs232_recv(uint8_t byte);

static volatile int8_t m0_goto_0 = 0;	// extra command.
static volatile struct motor_data m0;

int main()
{
  M0_INIT();

  PCICR = PCICR_ENC;				// enable what motor_data.h needs.
#ifdef PCMSK0_ENC
  PCMSK0 = PCMSK0_ENC;
#endif
#ifdef PCMSK1_ENC
  PCMSK1 = PCMSK1_ENC;
#endif
#ifdef PCMSK2_ENC
  PCMSK2 = PCMSK2_ENC;
#endif

  LED_PORT &= ~(LED_BV);
  LED_DDR  |=  (LED_BV);

  // rs232_init(UBRV(38400), &rs232_recv);
  rs232_init(UBRV(115200), &rs232_recv);
  timer0_init();
  FILE lcd_fp = FDEV_SETUP_STREAM(rs232_putchar, NULL, _FDEV_SETUP_WRITE);
  stdout = &lcd_fp;
  putchar('\n');
  putchar('X');


  uint8_t zero_printed = 0;
  while (1)
    {
      _delay_ms(100.0);

      // must cast, because %d expects 16bit, not 32bit.
      if (m0.enc_speed != 0 || m0.pwm_val != 0 || !zero_printed)
        {
          printf("  s=%-4d v=%-4d x=%d\r\n", 
              (int)m0.pwm_val, 
	      (int)m0.enc_speed, 
	      (int)m0.enc_count);
	  if (m0.enc_speed || m0.pwm_val)
	    zero_printed = 0;
	  else
	    zero_printed = 1;
	}

      if (m0_goto_0)
        {
	  putchar('H');
	  putchar('?');
	  m0_goto_0 = 0;
	  // not impl.
	}
    }
}

static int rs232_putchar(char ch, FILE *fp)
{
  if (!rs232_headroom)
    {
      while (!rs232_headroom)
        ;
    }
  return rs232_send((uint8_t)ch);
}

static void rs232_recv(uint8_t byte)
{
			       //  quadratic appears to be quite right
			       //  1    2    3    4   5   6   7   8    9
  static int8_t key2pv[] = { -127, -64, -32, -16,  0, 16, 32, 64, 127 };
  // just an echo back dummy.
  rs232_send('=');
  rs232_send(byte);
  if (byte > '0' && byte <= '9') 
    {
      m0.pwm_val = key2pv[(byte - '1')];
      m0_goto_0 = 0;	// forget homing
    }
  if (byte == '0')
    {
      m0_goto_0 = 1;	// go home
    }
}


static void timer0_init()
{
  // start timer0, with slowest prescaler. Normal mode.
  TCCR0A = 0;		// hardware output disconnected
  TCCR0B = (1<<CS02)|(0<<CS01)|(1<<CS00);	// prescaler/1024 p105
  // TCCR0B = (1<<CS02)|(0<<CS01)|(0<<CS00);	// prescaler/256 p105
  // TCCR0B = (0<<CS02)|(1<<CS01)|(1<<CS00);	// prescaler/64 p105
  // TCCR0B = (0<<CS02)|(1<<CS01)|(0<<CS00);	// prescaler/8 p105
#if CPU_MHZ != 8
# error: timer0_init requires CPU_MHZ == 8
#endif

  // 0 is a one count gap.
  // 254 is a one count pulse.
  // 255 is a one cpu-clock spike.
  OCR0A = 0;	// irrelevant before the first TOV

  // enable software interrupts OC0A and TOV0
  TIMSK0 = (0<<OCIE0B)|(1<<OCIE0A)|(1<<TOIE0);
}
 

ISR(TIMER0_OVF_vect)
{
  // cli();		// this is default unless ISR(... ,ISR_NOBLOCK)
  m0.enc_speed = m0.priv.enc_count - m0.enc_count;
  m0.enc_count = m0.priv.enc_count;

  // Our input is m0.pwm_val. We program this speed, if we can.
  // m0.priv.dir == 0, initially. So we can start in both directions.
  
  if (m0.enc_speed &&				// if, we are already (or still) rolling...
      ((m0.pwm_val > 0 && m0.priv.dir < 0) ||	// and they want to go the other way...
       (m0.pwm_val < 0 && m0.priv.dir > 0)))
    // ... then stop before reversing, to help our poor encoder, 
    // which does not know the direction of rotation.
    {
      m0.priv.pwm_val = 0;				
      LED_PORT |= (LED_BV);	// brake-lights. Well, not really. Rolling to a halt.
    }
  else
    {
      LED_PORT &= ~(LED_BV);
      m0.priv.pwm_val = m0.pwm_val;
    }

  // now we buffered pwm_val into the private internal structure.
  // it should be safe to say
  // sei();
  // FIXME: can we allow sei() now?
  // We should measure, how long we stay in this handler,
  // we should know, how many hall encoder interrupts to expect while we are here.

  if (m0.priv.pwm_val == 0)
    {
      M0_PWM_PORT &= ~(M0_PWM_FWD_BV|M0_PWM_BWD_BV);	// stop
    }
  else if (m0.priv.pwm_val < 0)
    {
      m0.priv.dir = -1;
      M0_PWM_PORT &= ~(M0_PWM_FWD_BV);
      M0_PWM_PORT |=  (M0_PWM_BWD_BV);	// bwd full or pwm rising edge
      if (m0.priv.pwm_val > -127)
       {
         // pwm compute
	 // small values of OCR0A cause smaller pulses
	 OCR0A = 2 * -m0.priv.pwm_val;
       }
    }
  else if (m0.priv.pwm_val > 0)
    {
      m0.priv.dir = 1;
      M0_PWM_PORT &= ~(M0_PWM_BWD_BV);
      M0_PWM_PORT |=  (M0_PWM_FWD_BV);	// fwd full or pwm rising edge
      if (m0.priv.pwm_val < 127)
       {
         // pwm compute
	 // small values of OCR0A cause smaller pulses
	 OCR0A = 2 * m0.priv.pwm_val;
       }
    }
}


ISR(TIMER0_COMPA_vect)
{
  // cli();		// this is default unless ISR(... ,ISR_NOBLOCK)
  if (m0.priv.pwm_val < 127 && m0.priv.pwm_val > -127)
    {
      M0_PWM_PORT &= ~(M0_PWM_FWD_BV|M0_PWM_BWD_BV);	// pwm falling edge
    }
}

ISR(PCINT1_vect)	// PCINT8 pin is in PCMSK1
{
  // cli();		// this is default unless ISR(... ,ISR_NOBLOCK)
  // count it, if the hall sensors bit is set.
  // otherwise, it could also have been one of the other pins on port B
  if (M0_ENC_PIN & M0_ENC_BV)
    m0.priv.enc_count += m0.priv.dir;
}
