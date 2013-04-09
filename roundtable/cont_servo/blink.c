/*
 * blink.c -- simple LED blinker
 *
 * Copyright (C) 2008, jw@suse.de, distribute under GPL, use with mercy.
 *
 */
// #include "config.h"
#include "cpu_mhz.h"

#include <util/delay.h>			// needs F_CPU from cpu_mhz.h
#include <avr/io.h>

#define LED_PORT PORTD
#define LED_DDR  DDRD

#define LED_BITS	0xff		// try all ...

int main()
{
  LED_DDR |= LED_BITS;			// all pins outout
  for (;;)
    {
      _delay_ms(500.0); LED_PORT &= ~(LED_BITS);        // pull low ...
      _delay_ms(500.0); LED_PORT |=   LED_BITS;         // pull high ...
    }
}
