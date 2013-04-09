# Makefile for project $(NAME)
# Distribute under GPLv2, use with care.
#
# 2008-09-25, jw@suse.de
# 2012-11-24, jw@suse.de

NAME          = cont_servo
CFILES        = blink.c # $(NAME).c eeprom.c i2c_slave_cb.c

CPU           = tiny2313
#CPU           = mega48
#CPU           = mega169
#CPU           = mega644

PROG_HW       = usbtiny		# www.ladyada.com
#PROG_HW       = usbasp		# www.fischl.de
#PROG_HW       = stk200		# www.atmel.com
#PROG_HW       = butterfly	# www.atmel.com
#PROG_HW       = mkbutterfly	# www.mikrokopter.de
#PROG_PORT     = /dev/ttyUSB0
#PROG_PORT     = /dev/ttyACM0
#PROG_PORT     = /dev/rfcomm1
#AVRDUDE_OPT   = -b 57600 -P $(PROG_PORT)

PROG_SW       = avrdude
#PROG_SW       = sudo avrdude	# recommended, if you get permission denied errors.
#PROG_SW       = uisp		# deprecated


## try this, if $(ISP) magic fails
#UPLOAD_CMD    = $(PROG_SW) -p AT$(CPU) -c $(PROG_HW) $(AVRDUDE_OPT) $(addprefix -P,$(PROG_PORT)) -U $(NAME).hex -v

CFLAGS        += -Os -g -Wall -DLED_PORT=PORTB -DLED_DDR=DDRB -DLED_BITS=0xaf
#CFLAGS        += -Os -g -Wall
#LDFLAGS       += -Wl,-u,vfprintf -lprintf_min

TOP_DIR       = .

include $(TOP_DIR)/avr_common.mk
#DIST_EXCLUDE += --exclude photos


distclean:: 
	rm -f download* ee_data.* 

## header file dependencies
#############################
include depend.mk
