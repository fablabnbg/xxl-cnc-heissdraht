/*
 * Copyright (C) 2005-2008 jw@suse.de
 * This code is distributable under the GPL.
 *
 * rs232.h -- serial line transmitter for attiny2313, atmega8, atmega48
 */

#include "cpu_mhz.h"	// written by 'make 20mhz'

#ifndef RS232_RECEIVE
# define  RS232_RECEIVE 1		// uncomment here, if you need it.
#endif

#ifndef U2X_VAL
# define U2X_VAL	1
#endif
#ifndef CPU_MHZ
# define CPU_MHZ 	20
#endif

// documented in attiny2313_doc2543.pdf page 137, except for 20Mhz.
#if (CPU_MHZ_10 == 200)
# define UBRV_115200	21	// 21 only
# define UBRV_38400	64	// 62-64-67 tested
# define UBRV_19200	130	// untested
# define UBRV_9600	259	// 247-259-273 tested

#elif (CPU_MHZ_10 == 160)
# define UBRV_115200	16	// 16,17 tested
# define UBRV_38400	51	// 49-51-53 tested
# define UBRV_19200	103	// untested
# define UBRV_9600	207	// 197-207-218

#elif (CPU_MHZ_10 == 80)
# define UBRV_115200	8	// 8 only
# define UBRV_38400	26	// 25, 26, 27 tested.
# define UBRV_19200	54	// untested
# define UBRV_9600	103	// 100-103-110

#elif (CPU_MHZ_10 == 40)
# define UBRV_115200	3 	// -- 3 does not work
# define UBRV_38400	13	// 13 only (12 does not work)
# define UBRV_19200	28	// untested
# define UBRV_9600	54	// 53-57, (51 does not work.)

#elif (CPU_MHZ_10 == 25)
# define UBRV_115200	2 	// untested
# define UBRV_38400	8	// untested
# define UBRV_19200	16	// untested
# define UBRV_9600	32	// untested

#elif (CPU_MHZ_10 == 20)
# define UBRV_115200	0	// error_CPU_MHZ_TOO_LOW
# define UBRV_38400	7	// untested
# define UBRV_19200	14	// untested
# define UBRV_9600	28	// untested

#elif (CPU_MHZ_10 == 10)
# define UBRV_115200	0	// error_CPU_MHZ_TOO_LOW
# define UBRV_38400	0	// error_CPU_MHZ_TOO_LOW
# define UBRV_19200	7	// untested
# define UBRV_9600	12	// untested

#else
# if HAVE_RS232
#  error "unknown CPU_MHZ: not impl"
# else
#  warning "unknown CPU_MHZ: faking UBRR_*"
#  define UBRV_115200	0
#  define UBRV_38400	0
#  define UBRV_19200	0
#  define UBRV_9600	0
# endif
#endif

#define UBRV(x) (((x)==115200)?UBRV_115200: \
		(((x)== 38400)?UBRV_38400: \
		(((x)== 19200)?UBRV_19200: \
		(((x)==  9600)?UBRV_9600: \
		   0))))

#ifndef RS232_BUF_SIZE
# define RS232_BUF_SIZE 30
#endif

#define rs232_send_is_ready() (rs232_headroom)
#define rs232_send_str_P(name) rs232_send_strn_P((PGM_P)(name), strlen_P((PGM_P)(name)))

#ifdef RS232_RECEIVE
extern void rs232_init(uint16_t baud_ubrv, void (*recv_cb)(uint8_t));
#else
extern void rs232_init(uint16_t baud_ubrv);
#endif
extern uint8_t rs232_send(uint8_t byte);
extern uint8_t rs232_send_hex(uint8_t byte);
extern void    rs232_send_unsafe(uint8_t byte);
extern uint8_t rs232_send_str(uint8_t *str);
extern uint8_t rs232_send_strn(uint8_t *str, uint8_t n);
#ifdef  PGM_P
extern uint8_t rs232_send_strn_P(PGM_P str, uint8_t n);
#endif
extern uint8_t rs232_send_str_poll(char *str);
extern void    rs232_wait_sent(uint8_t byte);
extern volatile uint8_t rs232_headroom;
