/*
 * Copyright (C) 2012 jnweiger@gmail.com
 * Distribute under MIT License, use with mercy.
 */
#define M0_PWM_PORT	PORTB
#define M0_PWM_DDR	DDRB
#define M0_PWM_FWD_BV	0x04		// output: only one please!
#define M0_PWM_BWD_BV	0x02		// output: only one please!

#define M0_ENC_PORT	PORTC
#define M0_ENC_PIN	PINC
#define M0_ENC_DDR	DDRC
#define M0_ENC_BV	0x01		// input, trigger PCINT8 in PCI1 

#define PCICR_ENC	(1<<PCIE1)	// enable PCI1 (p.69)
#define PCMSK1_ENC 	(0x01)		// PCINT8 is lowest bit here. (p.70)
// #define PCMSK2_ENC 	(0x00)		// 
// #define PCMSK3_ENC 	(0x00)		//

// init: PWM: pull all low; all pins outout	
// 	 ENC: enable pullup
#define M0_INIT()	do {				\
  M0_PWM_PORT &= ~(M0_PWM_FWD_BV|M0_PWM_BWD_BV);        \
  M0_PWM_DDR |=   (M0_PWM_FWD_BV|M0_PWM_BWD_BV);	\
							\
  M0_ENC_DDR &= ~(M0_ENC_BV);				\
  M0_ENC_PORT |= (M0_ENC_BV);        			\
} while (0)


struct motor_data_private
{
  // all these values are private to the interrupt handlers. Do not touch!
  // pwm_val is double buffered. 
  volatile int8_t pwm_val;     	// pwm drive speed. may be 0, while reversing.

  volatile int8_t dir;		// direction of last movement; 0: uninitiaized, -1: bwd, +1: fwd
  volatile int32_t enc_count;	// updated by pin change interrupt.
};

struct motor_data
{
  // pwm_val = 0; stop
  // pwm_val = 127: full fwd
  // pwm_val = -129: full bwd
  volatile int8_t pwm_val;	// pwm drive set speed.

  // positions are relative to the start position.
  volatile int32_t enc_count; // last measured position

  // speed is relative to the pwm frequency:
  // If you lower the pwm-frequency, you get higher speed values.
  volatile int32_t enc_speed; // last measured speed

  struct motor_data_private priv;
};
