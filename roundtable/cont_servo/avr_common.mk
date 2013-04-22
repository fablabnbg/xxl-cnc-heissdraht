# avr_common.mk -- common Makefile macros for avr projects
#
# (C) Copyright 2008,2012 Juergen Weigert, jw@suse.de
# Distribute under GPLv2, use with care.
#
# 2007-07-23, jw, 	features: VPATH support
# 2008-01-27, jw	added make depend, make help. 
#                       make NNmhz did not generates cpu_mhz.h - fixed.
# 2008-02-01, jw	fixed egrep to let error messages through.
# 2008-09-29, jw	improved 'make help', added 'make clock rc=8mhz'
# 2009-08-09, jw	do not rename dirs if under svn.
# 2010-02-08, jw	do not overwrite CFLAGS or other Makefile variables.
#                       pass down -A AVRDUDE_OPT, honor UPLOAD_CMD.
# 2012-08-06, jw        added explicit PATH assignments as a workaround to
#                       BNC#767294
# 2012-11-24, jw	Reading cpu_mhz.h implemented.
#
# Makefile example:
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # Makefile for project $(NAME)
# # Distribute under GPLv2, use with care.
# #
# # 2007-06-08, jw
# # 2012-11-24, jw
# 
# NAME		= tinyPWMout
# OFILES	= $(NAME).o eeprom.o i2c_slave_cb.o
# CPU		= tiny2313
# PROG_SW	= avrdude
# PROG_HW	= stk200
# TOP_DIR	= ..
# 
# include $(TOP_DIR)/avr_common.mk
# 
# distclean:: 
# 	rm -f download* ee_data.* 
# 
# ## header file dependencies
# #############################
# include depend.mk
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

ifeq ($(TOP_DIR),)
  TOP_DIR	= .
endif

ifeq ($(PROJ),)
  PROJ		:= $(NAME)
endif

ifeq ($(PROG_HW),)
else
  ISP_OPT	+= -c '$(PROG_HW)'
endif

ifeq ($(PROG_SW),)
else
  ISP_OPT	+= -s '$(PROG_SW)'
endif

ifeq ($(CPU),)
else
  ISP_OPT	+= -p '$(CPU)'
endif

ifeq ($(AVRDUDE_OPT),)
else
  ISP_OPT	+= -A '$(AVRDUDE_OPT)'
endif

ifeq ($(CFILES),)
  CFILES	:= $(OFILES:%.o=%.c)
endif

# OFILES reside in cwd, even if sources were found via VPATH
ifeq ($(OFILES),)
  OFILES	:= $(subst $(TOP_DIR)/,./,$(CFILES:%.c=%.o))
endif

ifeq ($(ISP),)
ISP		= perl $(TOP_DIR)/avr_isp.pl $(ISP_OPT)
endif


CC		= avr-gcc -mmcu=at$(CPU)

ifeq ($(O2HEX),)
O2HEX		= avr-objcopy -O ihex
endif
ifeq ($(O2HEX_T),)
O2HEX_T		= $(O2HEX) -j .text -j .data
endif
ifeq ($(O2HEX_EE),)
O2HEX_EE	= $(O2HEX) -j .eeprom --change-section-lma .eeprom=0
endif
ifeq ($(OBJDUMP),)
OBJDUMP		= avr-objdump
endif
ifeq ($(OBJCOPY),)
OBJCOPY		= avr-objcopy -v
endif
ifeq ($(AVRSIZE),)
AVRSIZE		= avr-size
endif

# don't use -mint8, or preprocesor will issue silly warnings. 
# avr-libc stdio cannot handle -mint8 either.
# have -I. here, so that .c files from VPATH find .h files in the target dir, not source dir.
ifeq ($(CFLAGS),)
  CFLAGS	= -I.  -Wall -g -O2 # -mint8 
endif

# .c files found via VPATH say
# include <config.h> to prefer the config.h from the target directory via -I
# include "config.h" to prefer the config.h next to themselves.

ifeq ($(TOP_DIR),)
else
  VPATH		= $(TOP_DIR)
  CFLAGS	+= -I$(VPATH)
endif

DIST_EXCLUDE	= --exclude \*.tgz --exclude core --exclude \*.orig --exclude \*.swp
MAKE_SUBDIRS	= for d in $(SUBDIRS); do $(MAKE) $(MFLAGS) -C $$d $@; done
MAKE_SUBDIRS_NP	= for d in $(SUBDIRS); do $(MAKE) $(MFLAGS) --no-print-directory -C $$d $@; done

SHELL		= /bin/sh

# .PHONY: $(NAME).hex $(NAME)-src.hex version.h flashcount

# always rebuild version.h  and flashcount
.PHONY: version.h flashcount help

ifeq ($(NAME),)
all::
else
all:: $(NAME).hex 
endif

%.hex:: %.out; $(O2HEX_T) $^ $@

flashcount::
	@read n < flashcount; echo > flashcount "$$(($$n + 1))"
	@echo -n flashcount=
	@cat flashcount

help:: 
	@echo 
	@echo avr_common.mk uses the following variables:
	@echo
	@echo 'NAME        name of the binary. Specify in Makefile, no default.'
	@echo 'PROJ        name of the project. Specify in Makefile, defaults to "$$(NAME)".'
	@echo 'OFILES      list of object files. Should include at least "$$(NAME).o".'
	@echo 'CFILES      C files. If you specify either OFILES or CFILES, the other is automatic.'
	@echo '            Specify in Makefile, no default.'
	@echo 'TOP_DIR     directory where avr_common.mk is found. Default "."'
	@echo 'SUBDIRS     directories with own Makefiles. Specify in Makefile, optional.'
	@echo 'CC          compiler name. Default: "$(value CC)"'
	@echo 'INC         include paths. Default: "$(value INC)"'
	@echo 'CFLAGS      compiler options. Default: "$(value CFLAGS)"'
	@echo 'LDFLAGS     compiler options. Default: "$(value LDFLAGS)"'
	@echo 'ISP         upload helper. Default: "$(value ISP)"'
	@echo 'PROG_SW     upload software. Use e.g. "avrdude", "uisp" or "sudo avrdude".'
	@echo 'PROG_HW     upload hardware dongle. Use e.g. "stk200", "usbasp",'
	@echo '            "usbtiny", "butterfly".'
	                  
	@echo 'CPU         name of the ATMEL processor chip. Specify in Makefile,'
	@echo '            no default. Valid names with $(value CC) are:'
	@cpu=`$(CC) -mmcu=not_a_valid_mcu -x c /dev/null 2>&1 | grep ' at'`; echo $$cpu | fold -s
	@echo 
	@echo avr_common.mk offers the following additional make targets: 
	@echo
	@echo "help        - print this online help."
	@echo 'depend      - create depend.mk using $$(OFILES).'
	@echo 'all         - compile and link $$(NAME) using $$(OFILES).'
	@echo 'reset       - reset the device. Also a useful connectivity test.'
	@echo 'upload      - create and load $$(NAME) into the device.'
	@echo 'flashcount  - file with an upload counter.'
	@echo 'erase       - erase flash (and eeprom) of device.'
	@echo 'clock rc=1mhz rc=8mhz'
	@echo 'clock wdt=128khz wdt=16khz'
	@echo 'clock pll=16mhz pll=2mhz'
	@echo 'clock q=32768hz q=2.5mhz q=12mhz q=16mhz q=20mhz'
	@echo 'clock ext=10mhz'
	@echo '            - program the device clock speed, using internal or external sources'
	@echo '            - and write cpu_mhz.h header file.
	@echo 'clock'
	@echo '            - read cpu_mhz.h and program the device click speed accordingly.
	@echo 'download    - retrieve binary from device flash.'
	@echo 'download_ee - retrieve eeprom contents from device.'
	@echo 'clean       - remove all generated (and temporary) files.'
	@echo 'dist        - pack everything into a compressed tar archive.'
	@echo 'version     - increment the minor version number in file "version.h"'
	@echo '              and rename the current directory accordingly.'
	@echo 
	@echo 'For further details, see $(TOP_DIR)/avr_common.mk'


depend depend.mk:: $(CFILES)
	$(CC) -MM $(INC) $(CFLAGS) $(CFILES) > depend.mk || rm -f depend.mk

install:: all upload

# erase zaps the eeprom. be careful with that...
erase:: download_ee flashcount
	$(ISP) erase

#upload_dist: upload_all
#upload_src: upload_all
#install_all: upload_all
#install_src: upload_all
#install_dist: upload_all

ifeq ($(NAME),)
else
## use egrep to make dude half quiet.
ifeq ($(UPLOAD_CMD),)
up upload:: $(NAME).hex flashcount
	$(ISP) up $(NAME).hex 2>&1 | egrep -i '(error|device|bytes|failed|check)'
	@# test "`wc -c < $(NAME)-ee.hex`" -gt 13 && $(ISP) up_ee $(NAME)-ee.hex
else
up upload:: $(NAME).hex flashcount
	$(UPLOAD_CMD)
endif

ee_up ee_upload upload_ee up_ee:: $(NAME)-ee.hex
	$(ISP) up_ee $(NAME)-ee.hex


# if __bss_start > 60, we probably have strings in RAM, check __data
# if __bss_end gets close to __stack, think of subroutine calls.
#
# In order to know how much flash the final program will consume, one needs to
# add the values for both, .text and .data (but not .bss), while the amount of
# pre-allocated SRAM is the sum of .data and .bss.

$(NAME).out: $(OFILES)
	# PATH manipulation added here as a workaround for bnc#767294
	PATH=/usr/avr/bin:$$PATH \
	$(CC) $(LDFLAGS) $(INC) $(CFLAGS) -Wl,-Map,$(NAME).map,--cref -o $(NAME).out $(OFILES)
	@$(AVRSIZE) $(NAME).out
#	@$(OBJDUMP) -t $(NAME).out | egrep '(__stack|__bss|_etext)'
#	@$(OBJDUMP) -h $(NAME).out | \
#	perl -ane '{printf "$$1 %d bytes.\n", hex($$2) if $$_ =~ m{\.(text)\s+(\S+)}}'

.c.o:
	# PATH manipulation added here as a workaround for bnc#767294
	PATH=/usr/avr/bin:$$PATH \
	$(CC) $(INC) $(CFLAGS) -c $<


$(NAME).s: $(NAME).c
	# PATH manipulation added here as a workaround for bnc#767294
	PATH=/usr/avr/bin:$$PATH \
	$(CC) $(INC) $(CFLAGS) -S -o $(NAME).s -c $<
endif


ee_down ee_download download_ee down_ee:: 
	$(ISP) down_ee ee_data.hex
	@mkdir -p down
	d=`date '+%Y%m%d%H%M%S'`; \
	$(OBJCOPY) -I ihex -O binary ee_data.hex down/ee_data.bin.$$d; \
	set -x; ln -sf down/ee_data.bin.$$d ee_data.bin

rdfuses rdfuse rd_fuses rd_fuse::; $(ISP) -q $@

2.5mhz 4mhz 12mhz 16mhz 20mhz:; $(ISP) clock $@ cpu_mhz.h
1mhz 8mhz::; $(ISP) clock i$@ cpu_mhz.h

#
# keep this target in sync with the capabilies of
# avr_isp.pl %fuse_macro, ...
#
fuse fuses clock::
	@if   [ -n "$(rc)" ]; then \
	  set -x; $(ISP) clock i$(rc)  cpu_mhz.h; \
	elif [ -n "$(pll)" ]; then \
	  set -x; $(ISP) clock i$(pll) cpu_mhz.h; \
	elif [ -n "$(q)" ]; then \
	  set -x; $(ISP) clock $(q)    cpu_mhz.h; \
	elif [ -n "$(wdt)" ]; then \
	  set -x; $(ISP) clock i$(wdt) cpu_mhz.h; \
	elif [ -n "$(ext)" ]; then \
	  set -x; $(ISP) clock ext_$(wdt) cpu_mhz.h; \
	else \
	  set -x; $(ISP) clock from=F_CPU cpu_mhz.h; \
	fi \


download down reset::; $(ISP) $@

install.sh:: Makefile
	echo  > $@ '#! /bin/sh'
	echo >> $@ '# $@ -- install binaries, how the Makefile does it.'
	echo >> $@ '# (C) 2005 jw@suse.de, distribute under GPL, use with care.'
	echo >> $@ 
	echo >> $@ 'ISP="$(ISP)"'
	echo >> $@ 'set -x'
	make -n upload | sed -n -e 's@$(ISP)@$$ISP@p' >> $@
	clock=`grep 'CPU_MHZ\b' cpu_mhz.h|sed -e 's@.*CPU_MHZ@@'`; \
	echo \$$ISP clock $${clock}mhz >> $@
	chmod a+x $@

clean::
	rm -f *.o *.s *.out *.hex

distclean:: clean
	rm -f *.orig *.map *~

ifeq ($(TOP_DIR),.)

# := evaluates immediatly, but = propagates.
VERSION		= $(shell read a b < version; printf "%d.%02d" $$a $$b)
VERSION_MAJ	= $(shell read a b < version; echo $$a)
VERSION_MIN	= $(shell read a b < version; echo $$b)
OLD_VERSION	:= VERSION

version:: incr_vmin # rename

version.h::
	@echo \#define VERSION   \"$(VERSION)\"    > version.h; \
	echo \#define VERSION_MAJ $(VERSION_MAJ) >> version.h; \
	echo \#define VERSION_MIN $(VERSION_MIN) >> version.h

incr:: incr_vmin

incr_vmin::
	read a b < version; echo > version "$${a:-0} $$(($$b + 1))"
	@cat version

incr_vmaj::
	read a b < version; echo > version "$$(($$a + 1)) $${b:-0}"
	@cat version


rename:: 
	test -d .svn || git branch || ( \
	n="$(PROJ)-$(VERSION)"; rm -f ../$(PROJ); \
	mv `/bin/pwd` "../$$n" 2> /dev/null; ln -s $$n ../$(PROJ); true )


bin dist-bin:: $(NAME).hex $(NAME)-ee.hex version.h install.sh
	n="$(PROJ)-$(VERSION)"; ln -s . $$n; \
	tar zcvf ../$$n-bin.tgz $$n/$(NAME).hex $$n/$(NAME)-ee.hex $$n/install.sh $$n/doc/matrix.txt; \
	rm $$n; test -d .svn || git branch || mv `/bin/pwd` "../$$n" 2> /dev/null; true

dist:: distclean version.h
	n="$(PROJ)-$(VERSION)"; \
	test -f ../$$n.tgz && (echo "WARNING: ../$$n.tgz exists, press ENTER to overwrite"; read a); \
	ln -s . $$n; tar zcvf "../$$n.tgz" $(DIST_EXCLUDE) --exclude "$$n/$$n" $$n/*; \
	rm $$n; test -d .svn || git branch || mv `/bin/pwd` "../$$n" 2> /dev/null; true

else
version dist bin dist-bin::; $(MAKE) -C $(TOP_DIR) $@
endif
