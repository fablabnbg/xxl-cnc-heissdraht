#include <avr/io.h>
#define OC0A_BIT   3
#define OC0B_BIT   4
#define OC0A_DDR  DDRB

void pwm_init(){
	OC0A_DDR|=1<<OC0A_BIT;
	OC0A_DDR|=1<<OC0B_BIT;
	TCCR0A=0xA3;
	TCCR0B=0x05;
	OCR0A=127;
	OCR0B=127;
}

void pwm_set_a(int val){
	OCR0A=val;
}

void pwm_set_b(int val){
	OCR0B=val;
}
