#include <avr/io.h>
#define OC0A_BIT   3
#define OC0A_DDR  PORTB

void pwm_init(){
	OC0A_DDR|=1<<OC0A_BIT;
	TCCR0A=0x83;
	TCCR0B=0x05;
	OCR0A=0;
}
