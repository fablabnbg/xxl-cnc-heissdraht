/*
 * Copyright (C) 2005,2008 jw@suse.de
 * This code is distributable under the GPL.
 *
 * rs232.c -- serial line transmitter and receiver for 
 * attiny2313 and atmega8, atmega48
 * 
 * 2008-01-27, jw - started porting to atmega48 using avr-libc-1.4.6 names.
 * 2008-02-01, jw - rxd pulldown added to schematics, to discharge statics.
 * 2008-02-02, jw - prepared for stdio. Debug LED glows while we wait
 *                  for the buffer to make room.
 * 2013-04-09, jw - SIG_USART0_RECV is poisoned. Use instead.
 */
#if 0
         [E]___[B]          BSF17            PC COM port, 
        |   BSF   |                           9pin male
        |___17 ___|             C     _____         
            [C]                 +---+-|_3k3_|--- 1 +10V
                _____      B  |/    |     +----- 2 TxD -10V
TxD0  (3)   ---|_10k_|--------|     +----------- 3 RxD 
                              |\ E        |      4
                                +------------+-- 5 GND 0V
                                          |  |   6
                                 _____    |  |   7
                             +---|_47k_|--+  |   8 +10V
                             |            |  |   9
RxD0  (2)   ---o o-----+     |           |4| |
             Jumper   C \| B |           |7| |
                         |---+--|<|--+   |k| |
                 BSF17  /|    1N4148 |    |  |
                      E+             |    |  |
GND   (10)  -----------+-------------+----+--+ 

#endif


#include <avr/io.h>
#if __GNUC__ < 4 || __GNUC__ == 4 && __GNUC_MINOR__ == 0 && __GNUC_PATCHLEVEL__ <= 2
# include <avr/signal.h>		// required with gcc-4.0.2 and before
#endif
#include <avr/interrupt.h>
#include "config.h"
#include "rs232.h"

#if HAVE_RS232
volatile static uint8_t rs232_buf[RS232_BUF_SIZE];
volatile static uint8_t rs232_buf_idx_head;
volatile static uint8_t rs232_buf_idx_tail;
volatile        uint8_t rs232_headroom;

// they all still have slightly different names.
#if defined(__AVR_ATmega48__) || defined(__AVR_ATmega88__) || defined(__AVR_ATmega168__)
# define __AVR_ATmegaX8__ 1
#endif

#if defined(__AVR_ATmegaX8__)
#define UBRRL UBRR0L
#define UBRRH UBRR0H
#define UBRR  UBRR0
#define UDR   UDR0

#define UCSRA UCSR0A
#define RXC   RXC0
#define TXC   TXC0
#define UDRE  UDRE0
#define FE    FE0
#define DOR   DOR0
#define UPE   UPE0
#define U2X   U2X0
#define MPCM  MPCM0

#define UCSRB UCSR0B
#define RXCIE RXCIE0 
#define TXCIE TXCIE0 
#define UDRIE UDRIE0 
#define RXEN  RXEN0  
#define TXEN  TXEN0  
#define UCSZ2 UCSZ02 
#define RXB8  RXB80  
#define TXB8  TXB80  

#define UCSRC  UCSR0C
#define UMSEL1 UMSEL01
#define UMSEL0 UMSEL00
#define UPM1   UPM01
#define UPM0   UPM00
#define USBS   USBS0
#define UCSZ1  UCSZ01
#define UCSZ0  UCSZ00
#define UCPOL  UCPOL0

#define SIG_USART_UDRE SIG_USART_DATA
#endif

#if defined(__AVR_ATtiny2313__)
#define USART0_RX_vect   USART_RX_vect
#define USART0_UDRE_vect USART_UDRE_vect
#define USART0_TX_vect   USART_TX_vect
#define UMSEL0 UMSEL
#endif

#if defined(__AVR_ATmega8__)
#define USART0_RX_vect  SIG_UART_RECV
#define USART0_UDRE_vect  SIG_UART_DATA
#define USART0_TX_vect SIG_UART_TRANS
#define UMSEL0 UMSEL
#endif

// port pins are common to tiny2313 mega8 megax8
#define USART_PORT	PORTD
#define USART_PIN	PIND
#define USART_DDR	DDRD
#define RXD_BIT		(1<<PD0)
#define TXD_BIT		(1<<PD1)

#if RS232_RECEIVE
static void (*rs232_rxd_cb)(uint8_t) = (void(*)(uint8_t))0;

ISR(USART0_RX_vect)
{
  uint8_t ch = UDR;
  if (rs232_rxd_cb) rs232_rxd_cb(ch);
}

void rs232_init(uint16_t ubrr, void (*recv_cb)(uint8_t))
#else
void rs232_init(uint16_t ubrr)
#endif
{
  rs232_buf_idx_head = 0;
  rs232_buf_idx_tail = 0;
  rs232_headroom = RS232_BUF_SIZE;

  // FIXME: we should catch this at compile time.
  while (!ubrr) ;	// catch if too slow to do the req baud rate


#define UC_PAR_NONE (0<<UPM1)|(0<<UPM0)
#define UC_PAR_EVEN (1<<UPM1)|(0<<UPM0)
#define UC_PAR_ODD  (1<<UPM1)|(1<<UPM0)
#define UC_STOPB1   (0<<USBS)
#define UC_STOPB2   (1<<USBS)
#define UC_CS5      (0<<UCSZ1)|(0<<UCSZ0)
#define UC_CS6      (0<<UCSZ1)|(1<<UCSZ0)
#define UC_CS7      (1<<UCSZ1)|(0<<UCSZ0)
#define UC_CS8      (1<<UCSZ1)|(1<<UCSZ0)
#define UC_CS9      (1<<UCSZ1)|(1<<UCSZ0)
#define UC_MASYNC   (0<<UMSEL0)
#define UC_MSYNC    (1<<UMSEL0)
#define UC_PASYNC   (0<<UCPOL)
#define UC_PSYN_FALL_RX (0<<UCPOL)	// receive at falling edge of clock
#define UC_PSYN_RISE_TX (0<<UCPOL)	// transmit at rising edge of clock
#define UC_PSYN_RISE_RX (1<<UCPOL)	// receive at rising edge of clock
#define UC_PSYN_FALL_TX (1<<UCPOL)	// transmit at falling edge of clock

#define UB_CS5      (0<<UCSZ2)
#define UB_CS6      (0<<UCSZ2)
#define UB_CS7      (0<<UCSZ2)
#define UB_CS8      (0<<UCSZ2)
#define UB_CS9      (1<<UCSZ2)

  // clear TXC, UDRE and set double speed.
  UCSRA = (U2X_VAL<<U2X)|(0<<MPCM);	

  // enable data-reg empty interrupt, switch on transmitter, CS8
  UCSRB = (1<<UDRIE)|(1<<TXEN)|UB_CS8;
# define UCSRC_V  UC_MASYNC | UC_CS8 | UC_STOPB1 | UC_PAR_NONE | UC_PASYNC

  // URSEL = 1, atmega8 special: when talking to UCSRC
  // UMSEL = 1, synchronuous mode
#if defined(__AVR_ATmega8__)
#define UCSRC_VAL (1<<URSEL)|UCSRC_V;
#endif
#if defined(__AVR_ATmegaX8__)
#define UCSRC_VAL (0<<UMSEL1)|UCSRC_V;
#endif
#if defined(__AVR_ATtiny2313__)
#define UCSRC_VAL UCSRC_V;
#endif
  UCSRC = UCSRC_VAL;

  UBRRL = ubrr & 0xff;	
#ifdef __AVR_ATmega8__
  UBRRH = (ubrr >> 8) & ~(1<<URSEL);
#else
  UBRRH = (ubrr >> 8);
#endif

  USART_DDR |= TXD_BIT;	//TxD is an output pin

#if RS232_RECEIVE
  USART_DDR &= ~RXD_BIT;		// input 
  USART_PORT |= RXD_BIT;		// enable pullup
  UCSRB |= (1<<RXEN)|(1<<RXCIE);
  rs232_rxd_cb = recv_cb;
#endif
  sei();
}


ISR(USART0_UDRE_vect)
{
  if (rs232_headroom < RS232_BUF_SIZE)
    {
      UDR = rs232_buf[rs232_buf_idx_tail++];
      rs232_headroom++;

      // it is a ring buffer. take care.
      if (rs232_buf_idx_tail >= RS232_BUF_SIZE)
        rs232_buf_idx_tail = 0;
    }
  else
    {
      UCSRB &= ~(1<<UDRIE);	// all done. ring buffer is empty now.
    }
}



// returns one more than the number of available bytes in buffer
// or 0, if full.
uint8_t rs232_send(uint8_t byte)
{
  if (!rs232_headroom)
    return 0;	// sorry, we are full
  cli();
  rs232_buf[rs232_buf_idx_head++] = byte;

  // it is a ring buffer. take care.
  if (rs232_buf_idx_head >= RS232_BUF_SIZE)
    rs232_buf_idx_head = 0;
  uint8_t r = rs232_headroom--;
  if (r == RS232_BUF_SIZE)
    {
      UCSRB |= (1<<UDRIE);	// ring buffer no longer empty.
    }
  sei();
  return r;
}

// same as above, but used while interrupts are already disabled.
// and nothing is returned.

#if 0
void rs232_send_unsafe(uint8_t byte)
{
  if (!rs232_headroom)
    return;	// sorry, we are full
  rs232_buf[rs232_buf_idx_head++] = byte;

  // it is a ring buffer. take care.
  if (rs232_buf_idx_head >= RS232_BUF_SIZE)
    rs232_buf_idx_head = 0;
  uint8_t r = rs232_headroom--;
  if (r == RS232_BUF_SIZE)
    {
      UCSRB |= (1<<UDRIE);	// ring buffer no longer empty.
    }
}
#endif

#if 1	// needed for attiny2313, not enough memory for stdio stuff.
# if 0
#define hex_nibble(n) (((n) < 10) ? ((n) + '0') : ((n) + ('A' - 10)))
# else
static uint8_t hex_nibble(uint8_t val)
{
  if (val < 10) return val + '0';
  return val + 'A' - 10;
}
# endif

uint8_t rs232_send_hex(uint8_t byte)
{
  uint8_t n = byte >> 4;
  rs232_send(hex_nibble(n));
  n = byte & 0xf;
  return rs232_send(hex_nibble(n));
}
#endif

#if 0
uint8_t rs232_send_hexdump(uint8_t *buf, uint8_t len)
{
  while (len-- > 0)
    rs232_send_hex(*buf++);
  return rs232_headroom;
}
#endif

#if 0
uint8_t rs232_send_strn_P(PGM_P str, uint8_t n)
{
  if (rs232_headroom < n)
    return 0;	// sorry, we are full
  cli();
  while (n-- > 0)
    rs232_send_unsafe(pgm_read_byte(str++));
  sei();
  return rs232_headroom;
}

uint8_t rs232_send_str(uint8_t *str)
{
  uint8_t n = 0;
  uint8_t *p = str;
  while (n < RS232_BUF_SIZE && *p++) n++;
  return rs232_send_strn(str, n);
}

uint8_t rs232_send_strn(uint8_t *str, uint8_t n)
{
  if (rs232_headroom < n)
    return 0;	// sorry, we are full
  cli();
  while (n-- > 0)
    rs232_send_unsafe(*str++);
  sei();
  return rs232_headroom;
}

// this handles strings longer than RS232_BUF_SIZE;
uint8_t rs232_send_str_poll(char *str)
{
  while (*str)
    {
      while (!rs232_headroom); 
      rs232_send(*str++);
    }
  return rs232_headroom;
}
#endif

#if 0
// blocks until n bytes are available in send buffer
void rs232_wait_sent(uint8_t n)
{
  while (rs232_headroom < n);
}
#endif

#endif // HAVE_RS232
