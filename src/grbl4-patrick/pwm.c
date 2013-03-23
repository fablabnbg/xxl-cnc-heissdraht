#include <avr/io.h>
#define OC0A_BIT   3
#define OC0A_DDR  DDRB

void pwm_init(){
	OC0A_DDR|=1<<OC0A_BIT;
	TCCR0A=0x83;	// clear OC0A on compare; Fast PWM 3
	TCCR0B=0x05;	// prescale 1/1024
	OCR0A=100;
}
