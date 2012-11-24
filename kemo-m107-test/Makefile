# Makefile for project $(NAME)
# Distribute under MIT, use with care.
#
# 2012-08-06, jw

NAME          = kemo-m107
CFILES        = $(NAME).c rs232.c # eeprom.c i2c_slave_cb.c
CPU           = mega48
#PROG_HW       = stk200
#PROG_HW       = usbasp
PROG_HW       = usbtiny
#PROG_SW       = avrdude
PROG_SW       = sudo avrdude

TOP_DIR       = .

include $(TOP_DIR)/avr_common.mk

CFLAGS		= -O2 -Wall

distclean:: 
	rm -f download* ee_data.* 

## header file dependencies
#############################
include depend.mk
