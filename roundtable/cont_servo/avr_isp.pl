#! /usr/bin/perl -w
#
# avr_isp.pl - In-circuit-programmer script for atmega and attiny CPUs.
# using either avrdude or uisp. Most code here is for fuse handling.
# 
# (C) Copyright 2008, Juergen Weigert, jw@suse.de
# Distribute under GPLv2, use with care.
#
# This collects all the intricate cases from my monstereous Makefiles.
#
# 2007-07-11, jw, v0.3 -- tested: upload download clock
# 2008-01-28, jw, v0.4 -- added: output of cpu_mhz.h to clock command.
# 2008-09-11, jw, v0.5 -- added reading cpu type from Makefile, when auto.
# 2008-09-20, jw, v0.6 -- reading avr/io.h for mem sizes and fuses.
# 2008-09-21, jw, v0.7 -- expanding macros for fuse bits.
# 2008-09-22, jw, v0.8 -- can do 'clock=20mhz', 'wrfuse CKDIV8=0', 'wrfuse BOD=2.7V' etc now.
# 2008-09-22, jw, v0.9 -- run cpu_defs automatically if no fuses are defined at all. 
#                         mk_fuse_default() added. direct assignment 'wrfuse 
#                         lfuse=0xe4' implemented.
# 2008-09-25, jw, v0.9a -- test $dongle_port, and do not fail on macros.
# 2008-09-25, jw, v0.9b -- all mhz values from the baud rate tables in doc2545 added.
#                          Fallback to p version of the cpu if the one without 
#                          has no FUSE_* defs.
#                          Option -r for running programmer unter sudo added.
# 2008-09-28, jw, v0.9c -- fixed newly introduced $dongle_port sanity check.
# 2008-09-29, jw, v0.9d -- tuned verboseness, made all internal oscillators 
#                          available as clock=i...hz
# 2008-11-09, jw, v0.9e -- added include file printing during compile_cpu_defines();
#                          added clock bits for old tiny26; yes, it is incompatible with tiny261
# 2009-04-26, jw, V0.9f -- support for mega16 added.
# 2009-04-26, jw, V0.9g -- merged back those two different 0.9e versions we had.
# 2010-02-05, jw, V0.9h -- type-dependant port defaults. print programmer 
#                          command, if called with -v
# 2012-11-24, jw, V0.9i -- hint added to error messages.
# 2012-11-25, jw, V0.9j -- reading cpu_mhz.h implemented. WIP

use Data::Dumper;
use strict;
use Carp; $SIG{__DIE__} = sub { Carp::confess(@_); };
$Carp::CarpLevel = 1;	# skip the ANON() frame from the above handler.

my $version = '0.9j';
my %dongle_defaults = ( 
  stk200    => { port => '/dev/parport0', avrdude_opt => '-E noreset' },
  butterfly => { port => '/dev/ttyS0',    avrdude_opt => '-b 19200' },
  usbasp    => { },
  usbtiny   => { }
);
my $dongle_port = '';
my $dongle_type = 'stk200';
my $verify = 1;
my $verbose = 1;
my $noop = 0;
my $sudo_root = 0;
my $programmer = '--none--';
my $cpu = 'auto';
my $avrdude_ee_count = 0;
my $avrdude_opt = '';
my $macro_file = "avr_fuse_macros.pl";


my %std_fuse_comment = 
(
    SELFPRGEN => 'Self-Programming Enable, 1=false',
    RSTDISBL  => 'External Reset disable, 1=enabled',
    DWEN      => 'DebugWIRE Enable, 1=false',
    SPIEN     => 'Enable Serial Programming, 1=false',
    WDTON     => 'Watchdog Timer always on, 1=false',
    EESAVE    => 'EEPROM is preserved through chip erase, 1=false',
    BODLEVEL2 => 'Brown-out Detector trigger level',
    BODLEVEL1 => 'Brown-out Detector trigger level',
    BODLEVEL0 => 'Brown-out Detector trigger level',
    CKDIV8    => 'Divide clock by 8, 1=false',
    CKOUT     => 'Clock Output Enable, 1=false',
    SUT1      => 'Select startup time',
    SUT0      => 'Select startup time',
    CKSEL3    => 'Select Clock source',
    CKSEL2    => 'Select Clock source',
    CKSEL1    => 'Select Clock source',
    CKSEL0    => 'Select Clock source',
);

#
# These are the builtin macros. 
# They are written to $macro_file, and used from there
# Edit there (too), if you get errors with newer header files.
#
my %fuse_macro = (
  'std' => {
    'LBmode=3' => [ 'LB[2..1]=00', 'flash+eeprom: no write or verify, fuses locked' ],
    'LBmode=2' => [ 'LB[2..1]=10', 'flash+eeprom: no write, fuses locked' ],
    'LBmode=1' => [ 'LB[2..1]=11', 'all unlocked' ],

    'BOD=off'  => [ 'BODLEVEL[2..0]=111', 'brown-out detector disabled' ],
    'BOD=1.8V' => [ 'BODLEVEL[2..0]=110', 'brown-out detector at 1.8V' ],
    'BOD=2.7V' => [ 'BODLEVEL[2..0]=101', 'brown-out detector at 2.7V' ],
    'BOD=4.3V' => [ 'fuse_h.BODLEVEL[2..0]=100', 'brown-out detector at 4.3V' ],

    'clock=ext_clock'  => [ 'CKSEL=0000,CKDIV8=1', 'external clock via XTAL1' ],
    'clock=20mhz'      => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=2.5mhz'     => [ 'CKSEL=1110,CKDIV8=0', 'external quartz 8-20Mhz XTAL1 XTAL2 /8' ],
    'clock=18.4320mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=18.432mhz'  => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=16mhz'      => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=14.7456mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=12mhz'      => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=11.0592mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=7.3728mhz'  => [ 'CKSEL=1100,CKDIV8=1', 'external quartz 3-8Mhz XTAL1 XTAL2' ],
    'clock=4mhz'       => [ 'CKSEL=1100,CKDIV8=1', 'external quartz 3-8Mhz XTAL1 XTAL2' ],
    'clock=3.6864mhz'  => [ 'CKSEL=1100,CKDIV8=1', 'external quartz 3-8Mhz XTAL1 XTAL2' ],
    'clock=2mhz'       => [ 'CKSEL=1010,CKDIV8=1', 'external quartz 0.9-3Mhz XTAL1 XTAL2' ],
    'clock=1.8432mhz'  => [ 'CKSEL=1010,CKDIV8=1', 'external quartz 0.9-3Mhz XTAL1 XTAL2' ],
    'clock=1mhz'       => [ 'CKSEL=1010,CKDIV8=1', 'external quartz 0.9-3Mhz XTAL1 XTAL2' ],
    'clock=0.5mhz'     => [ 'CKSEL=1000,CKDIV8=1', 'external quartz 0.5Mhz XTAL1 XTAL2' ],
    'clock=500khz'     => [ 'CKSEL=1000,CKDIV8=1', 'external quartz 0.5Mhz XTAL1 XTAL2' ],
    'clock=500000hz'   => [ 'CKSEL=1000,CKDIV8=1', 'external quartz 0.5Mhz XTAL1 XTAL2' ],
    'clock=i8mhz'      => [ 'CKSEL=0010,CKDIV8=1', 'internal RC-osc' ],
    'clock=i1mhz'      => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc /8' ],
    'clock=128khz'     => [ 'CKSEL=0011,CKDIV8=1', 'internal WDT-osc' ],
    'clock=16khz'      => [ 'CKSEL=0011,CKDIV8=0', 'internal WDT-osc /8' ],
    'clock=i128khz'    => [ 'CKSEL=0011,CKDIV8=1', 'internal WDT-osc' ],
    'clock=i16khz'     => [ 'CKSEL=0011,CKDIV8=0', 'internal WDT-osc /8' ],
  },

  # cpu family name: replace the first digit with an 'X'. FIXME: first two digits?
  tinyX61 => {
    'clock=8mhz'     => [ 'CKSEL=0010,CKDIV8=1', 'internal RC-osc' ],
    'clock=1mhz'     => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc /8' ],
    'clock=128khz'   => [ 'CKSEL=0011,CKDIV8=1', 'internal WDT-osc' ],
    'clock=16khz'    => [ 'CKSEL=0011,CKDIV8=0', 'internal WDT-osc /8' ],

    'clock=32768hz'  => [ 'CKSEL=0100,CKDIV8=1', 'external slow quartz XTAL1 XTAL2' ], 
    'clock=32.768khz'=> [ 'CKSEL=0100,CKDIV8=1', 'external slow quartz XTAL1 XTAL2' ], 
    'clock=16mhz'    => [ 'CKSEL=0001,CKDIV8=1', 'internal PLL-osc-64Mhz/4' ], 
    'clock=2mhz'     => [ 'CKSEL=0001,CKDIV8=0', 'internal PLL-osc-64Mhz/4 /8' ], 
    'clock=i16mhz'   => [ 'CKSEL=0001,CKDIV8=1', 'internal PLL-osc-64Mhz/4' ], 
    'clock=i2mhz'    => [ 'CKSEL=0001,CKDIV8=0', 'internal PLL-osc-64Mhz/4 /8' ], 
    'clock=ext_16mhz'=> [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
  },
  tiny26 => {
    'clock=8mhz'     => [ 'CKSEL=0100,CKOPT=1,PLLCK=1', 'internal RC-osc 8Mhz' ],
    'clock=4mhz'     => [ 'CKSEL=0011,CKOPT=1,PLLCK=1', 'internal RC-osc 4Mhz' ],
    'clock=2mhz'     => [ 'CKSEL=0010,CKOPT=1,PLLCK=1', 'internal RC-osc 2Mhz' ],
    'clock=1mhz'     => [ 'CKSEL=0001,CKOPT=1,PLLCK=1', 'internal RC-osc 1Mhz' ],

    'clock=i8mhz'    => [ 'CKSEL=0100,CKOPT=1,PLLCK=1', 'internal RC-osc 8Mhz' ],
    'clock=i4mhz'    => [ 'CKSEL=0011,CKOPT=1,PLLCK=1', 'internal RC-osc 4Mhz' ],
    'clock=i2mhz'    => [ 'CKSEL=0010,CKOPT=1,PLLCK=1', 'internal RC-osc 2Mhz' ],
    'clock=i1mhz'    => [ 'CKSEL=0001,CKOPT=1,PLLCK=1', 'internal RC-osc 1Mhz' ],
    'clock=i16mhz'   => [ 'CKSEL=0001,CKOPT=1,PLLCK=0', 'internal PLL-osc-64Mhz/4' ], 

    'clock=32768hz'  => [ 'CKSEL=1001,CKOPT=0,PLLCK=1', 'external slow quartz XTAL1 XTAL2' ], 
    'clock=32.768khz'=> [ 'CKSEL=1001,CKOPT=0,PLLCK=1', 'external slow quartz XTAL1 XTAL2' ], 
  },
  tiny2313 => {
    'clock=0.5mhz'  => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc 4Mhz /8' ],
    'clock=500khz'  => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc 4Mhz /8' ],
    'clock=1mhz'    => [ 'CKSEL=0100,CKDIV8=0', 'internal RC-osc 8Mhz /8' ],
    'clock=4mhz'    => [ 'CKSEL=0010,CKDIV8=1', 'internal RC-osc 4Mhz' ],
    'clock=8mhz'    => [ 'CKSEL=0100,CKDIV8=1', 'internal RC-osc 8Mhz' ],
    'clock=i0.5mhz' => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc 4Mhz /8' ],
    'clock=i500khz' => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc 4Mhz /8' ],
    'clock=i1mhz'   => [ 'CKSEL=0100,CKDIV8=0', 'internal RC-osc 8Mhz /8' ],
    'clock=i8mhz'   => [ 'CKSEL=0100,CKDIV8=1', 'internal RC-osc 8Mhz' ],
    'clock=i4mhz'   => [ 'CKSEL=0010,CKDIV8=1', 'internal RC-osc 4Mhz' ],
    'clock=128khz'  => [ 'CKSEL=0110,CKDIV8=1', 'internal WDT-osc' ],
    'clock=16khz'   => [ 'CKSEL=0110,CKDIV8=0', 'internal WDT-osc /8' ],
    'clock=i128khz' => [ 'CKSEL=0110,CKDIV8=1', 'internal WDT-osc' ],
    'clock=i16khz'  => [ 'CKSEL=0110,CKDIV8=0', 'internal WDT-osc /8' ],
  },
  mega16 => {		# doc2466
    __no_std__	=>	1,	# do not include std macros here.
    'LBmode=3' =>      [ 'LB[2..1]=00', 'flash+eeprom: no write or verify, fuses locked' ],
    'LBmode=2' =>      [ 'LB[2..1]=10', 'flash+eeprom: no write, fuses locked' ],
    'LBmode=1' =>      [ 'LB[2..1]=11', 'all unlocked' ],

    'BLB0mode=1'    => [ 'BLB0[2..1]=11', 'no restrictions' ],
    'BLB0mode=2'    => [ 'BLB0[2..1]=10', 'no SPM write to App' ],
    'BLB0mode=3'    => [ 'BLB0[2..1]=00', 'no SPM write to App, no LPM from Boot read App, no App Interrupts in Boot' ],
    'BLB0mode=4'    => [ 'BLB0[2..1]=01', 'no LPM from Boot read App, no App Interrupts in Boot' ],
    'BLB1mode=1'    => [ 'BLB0[2..1]=11', 'no restrictions' ],
    'BLB1mode=2'    => [ 'BLB0[2..1]=10', 'no SPM write to Boot' ],
    'BLB1mode=3'    => [ 'BLB0[2..1]=00', 'no SPM write to Boot, no LPM from App read Boot, no Boot Interrupts in App' ],
    'BLB1mode=4'    => [ 'BLB0[2..1]=01', 'no LPM from App read Boot, no Boot Interrupts in App' ],

    'BOD=off'	    => [ 'BODLEVEL=0, BODEN=1', 'brown-out detector disabled' ],
    'BOD=2.7V'	    => [ 'BODLEVEL=1, BODEN=0', 'brown-out detector at 2.7V' ],
    'BOD=4.0V'	    => [ 'BODLEVEL=0, BODEN=0', 'brown-out detector at 2.7V' ],

    'clock=i8mhz'     => [ 'CKSEL=0100', 'internal RC-osc 8Mhz' ],
    'clock=i4mhz'     => [ 'CKSEL=0011', 'internal RC-osc 4Mhz' ],
    'clock=i2mhz'     => [ 'CKSEL=0010', 'internal RC-osc 2Mhz' ],
    'clock=i1mhz'     => [ 'CKSEL=0001', 'internal RC-osc 1Mhz' ],
    'clock=ext_clock' => [ 'CKSEL=0000', 'external clock via XTAL1' ],
    'clock=32768hz'   => [ 'CKSEL=1001', 'external slow quartz 32.768khz XTAL1 XTAL2' ], 
    'clock=0.4-0.9mhz' => [ 'CKSEL=1010,CKOPT=1', 'external quartz 0.4-0.9Mhz XTAL1 XTAL2' ],
    'clock=0.9-3.0mhz' => [ 'CKSEL=1100,CKOPT=1', 'external quartz 0.9-3.0Mhz XTAL1 XTAL2' ],
    'clock=3.0-8.0mhz' => [ 'CKSEL=1110,CKOPT=1', 'external quartz 3.0-8.0Mhz XTAL1 XTAL2' ],
    'clock=1.0-16.0mhz' => [ 'CKSEL=1110,CKOPT=0', 'external quartz >= 1.0Mhz XTAL1 XTAL2' ],

  },
  mega8 => {		# doc2486, same as mega16 ?
    __no_std__	=>	1,	# do not include std macros here.
    'clock=i8mhz'     => [ 'CKSEL=0100', 'internal RC-osc 8Mhz' ],
    'clock=i4mhz'     => [ 'CKSEL=0011', 'internal RC-osc 4Mhz' ],
    'clock=i2mhz'     => [ 'CKSEL=0010', 'internal RC-osc 2Mhz' ],
    'clock=i1mhz'     => [ 'CKSEL=0001', 'internal RC-osc 1Mhz' ],
    'clock=ext_clock' => [ 'CKSEL=0000', 'external clock via XTAL1' ],
    'clock=32768hz'   => [ 'CKSEL=1001', 'external slow quartz 32.768khz XTAL1 XTAL2' ], 
    'clock=0.4-0.9mhz' => [ 'CKSEL=1010,CKOPT=1', 'external quartz 0.4-0.9Mhz XTAL1 XTAL2' ],
    'clock=0.9-3.0mhz' => [ 'CKSEL=1100,CKOPT=1', 'external quartz 0.9-3.0Mhz XTAL1 XTAL2' ],
    'clock=3.0-8.0mhz' => [ 'CKSEL=1110,CKOPT=1', 'external quartz 3.0-8.0Mhz XTAL1 XTAL2' ],
    'clock=1.0-16.0mhz' => [ 'CKSEL=1110,CKOPT=0', 'external quartz >= 1.0Mhz XTAL1 XTAL2' ],
  },
);


# The following definitions serve as example only.
# Please run $0 cpu_defs for your cpu to get fresh
# definitions from the header files.

my %m_tnx61 = 	# doc102865p168
(
  lock => { 
    LB2       => [ 1, 1, '' ],
    LB1       => [ 0, 1, '' ] },
  fuse_e => { 
    SELFPRGEN => [ 0, 1, 'Self-Programming Enable, 1=false' ] },
  fuse_h => {
    RSTDISBL  => [ 7, 1, 'External Reset disable, 1=enabled' ],
    DWEN      => [ 6, 1, 'DebugWIRE Enable, 1=false' ],
    SPIEN     => [ 5, 0, 'Enable Serial Programming, 1=false' ],
    WDTON     => [ 4, 1, 'Watchdog Timer always on, 1=false' ],
    EESAVE    => [ 3, 1, 'EEPROM is preserved through chip erase, 1=false' ],
    BODLEVEL2 => [ 2, 1, 'Brown-out Detector trigger level' ],
    BODLEVEL1 => [ 1, 1, 'Brown-out Detector trigger level' ],
    BODLEVEL0 => [ 0, 1, 'Brown-out Detector trigger level' ] },
  fuse_l => {
    CKDIV8    => [ 7, 0, 'Divide clock by 8, 1=false' ],
    CKOUT     => [ 6, 1, 'Clock Output Enable, 1=false' ],
    SUT1      => [ 5, 1, 'Select startup time' ],
    SUT0      => [ 4, 0, 'Select startup time' ],
    CKSEL3    => [ 3, 0, 'Select Clock source' ],
    CKSEL2    => [ 2, 0, 'Select Clock source' ],
    CKSEL1    => [ 1, 1, 'Select Clock source' ],
    CKSEL0    => [ 0, 0, 'Select Clock source' ] },
);

# The following definitions serve as example only.
# Please run $0 cpu_defs for your cpu to get fresh
# definitions from the header files.

my %cpu = 
(
  tiny11	=> { flashsz=>    1024, eesz=>     0, ramsz=> 0 },
  tiny12	=> { flashsz=>    1024, eesz=>    64, ramsz=> 0 },
  tiny13	=> { flashsz=>    1024, eesz=>    64, ramsz=> 64 },
  tiny2313	=> { flashsz=>  2*1024, eesz=>   128, ramsz=> 128 },
  tiny24	=> { flashsz=>  2*1024, eesz=>   128, ramsz=> 128 },
  tiny25	=> { flashsz=>  2*1024, eesz=>   128, ramsz=> 128 },
  tiny26	=> { flashsz=>  2*1024, eesz=>   128, ramsz=> 128 },
  tiny44	=> { flashsz=>  4*1024, eesz=>   256, ramsz=> 256 },
  tiny45	=> { flashsz=>  4*1024, eesz=>   256, ramsz=> 256 },
  tiny84	=> { flashsz=>  8*1024, eesz=>   512, ramsz=> 512 },
  tiny85	=> { flashsz=>  8*1024, eesz=>   512, ramsz=> 512 },
  tiny261	=> { flashsz=>  2*1024, eesz=>   128, ramsz=> 128, %m_tnx61 },
  tiny461	=> { flashsz=>  4*1024, eesz=>   256, ramsz=> 256, %m_tnx61 },
  tiny861	=> { flashsz=>  8*1024, eesz=>   512, ramsz=> 512, %m_tnx61 },
  mega48	=> { flashsz=>  4*1024, eesz=>   256, ramsz=> 512 },
  mega88	=> { flashsz=>  8*1024, eesz=>   512, ramsz=> 1024 },
  mega8		=> { flashsz=>  8*1024, eesz=>   512, ramsz=> 1024 },
  mega168	=> { flashsz=> 16*1024, eesz=>   512, ramsz=> 1024 },
  mega128	=> { flashsz=>128*1024, eesz=>4*1024, ramsz=>4*1024 },
  auto		=> { flashsz=>      -1, eesz=>    -1, ramsz=>   -1 },
);


$ENV{SHELL} = '/bin/sh';

## see what is available, prefer avrdude
$programmer = 'uisp'    if `sh -c "type -t uisp"`;
$programmer = 'avrdude' if `sh -c "type -t avrdude"`;


while (defined (my $arg = shift))
  {
    if ($arg !~ m{^-})		{ unshift @ARGV, $arg; last; }
  
    if    ($arg eq '-q') 	{ $verbose = 0; }
    elsif ($arg eq '-v')	{ $verbose++; }
    elsif ($arg eq '-V')	{ $verify = shift; }
    elsif ($arg eq '-n')	{ $noop = 1; }
    elsif ($arg eq '-F')	{ $verify = 0; }
    elsif ($arg eq '-c')	{ $dongle_type = shift; }
    elsif ($arg eq '-A')	{ $avrdude_opt = shift; }
    elsif ($arg eq '-y')	{ $avrdude_ee_count = 1; }
    elsif ($arg eq '-s')	{ $programmer = shift; }
    elsif ($arg eq '-r')	{ $sudo_root = 1; }
    elsif ($arg eq '-P')	{ $dongle_port = shift; }
    elsif ($arg eq '-p')	{ $cpu = shift; }
    else			{ usage("no such option: $arg"); }
  }

$cpu = cpu_from_makefile() if $cpu eq 'auto';
die "please specify cpu with -p or in Makefile\n" unless defined $cpu;
$cpu =~ s{^at}{}i;
$cpu = lc $cpu;

my $opcode = shift or usage("no command given.");
my $cmd = $sudo_root ? 'sudo ' : '';

my $defines_file = "avr_fuse_defs_$cpu.pl";

if ($opcode =~ m{^(cpu_?)?def}i)	# cpu_defs
  {
    my $d = compile_cpu_defines($cpu);
    $cpu{$cpu} = write_cpu_defines($defines_file, $d, \%std_fuse_comment, mk_fuse_macros($cpu));
    test_cpu_defines(\%cpu, $cpu);
    $opcode = shift or exit 0;
  }
else
  {
    if (-f $defines_file && -s _)
      {
        $cpu{$cpu} = do $defines_file;
	print "$defines_file loaded.\n" if $verbose;
      }
  }

if ($opcode eq 'list')
  {
    print "Known CPUs are:\n\n";
    print join ' ', keys %cpu;
    print "\n\n";
    exit 0;
  }
elsif ($opcode eq 'flashsize')  { print "$cpu{$cpu}{flashsz}\n"; exit 0; }
elsif ($opcode =~ m{^e\w+size}) { print "$cpu{$cpu}{eesz}\n"; exit 0; }
elsif ($opcode eq 'ramsize')    { print "$cpu{$cpu}{ramsz}\n"; exit 0; }

my $defaults = $dongle_defaults{lc $dongle_type} || {};

if (!length $dongle_port)
  {
    if (defined $defaults->{port})
      {
	$dongle_port = $defaults->{port};
	print "default port for '$dongle_type': $dongle_port\n" if $verbose;
      }
  }
die "checking $dongle_port: $!\n" if length $dongle_port and !$noop and ! -c $dongle_port;	# test if the char-device exists.

if ($programmer =~ m{dude}i)
  {
    my $avrdude_rdfuse_opt = "-U lfuse:r:-:r -U hfuse:r:-:r -U efuse:r:-:r 2>/dev/null";

    usage("please specify -p cpu for $programmer") if 
      $cpu eq 'auto' && $opcode ne 'version';

    $avrdude_opt = ($defaults->{avrdude_opt}||'') unless length $avrdude_opt;

    $cmd .= "$programmer -c $dongle_type -p AT$cpu";
    $cmd .= " -P $dongle_port" if length $dongle_port;
    $cmd .= " -y" if $avrdude_ee_count;
    $cmd .= " -F" unless $verify;
    $cmd .= " -q" if $verbose < 2;
    $cmd .= " -q" if $verbose < 1;
    $cmd .= " $avrdude_opt" if length $avrdude_opt;

    if ($opcode =~ m{^up\w+ee})
      {
        my $filename = shift || 'main.hex';
        $cmd .= qq{ -U "eeprom:w:$filename"};
      }
    elsif ($opcode =~ m{^up})
      {
        my $filename = shift || 'main.hex';
        $cmd .= qq{ -U "flash:w:$filename"};
      }
    elsif ($opcode =~ m{^down\w+ee})
      {
        my $filename = shift || 'download.hex';
        $cmd .= qq{ -U "eeprom:r:$filename:i"};
      }
    elsif ($opcode =~ m{^down})
      {
        my $filename = shift || 'download.hex';
        $cmd .= qq{ -U "flash:r:$filename:i"};
      }
    elsif ($opcode =~ m{^reset})
      {
        # the empty command.
	$cmd .= $avrdude_opt;
      }
    elsif ($opcode =~ m{^erase})
      {
        $cmd .= qq{ -e};
      }
    elsif ($opcode =~ m{^version})
      {
	$verbose = 0;
        print "$0 version $version\n";
        $cmd = qq{$programmer -v 2>&1 | head -4};
      }
    elsif ($opcode =~ m{^clock})
      {
        $opcode .= '=' . shift unless $opcode =~ m{=};
	my $file = shift;
	if ($opcode =~ m{from})
	  {
	    $opcode = parse_load_cpu_mhz($file, 'F_CPU');
	  }
	else
	  {
	    parse_save_cpu_mhz($file, $opcode);
	  }
	$cmd = fuse_operation(\%cpu, $cpu, $cmd, "-q -q $avrdude_rdfuse_opt", $opcode);
      }
    elsif ($opcode =~ m{^wr_?fuse})
      {
	$cmd = fuse_operation(\%cpu, $cpu, $cmd, "-q -q $avrdude_rdfuse_opt", @ARGV);
      }
    elsif ($opcode =~ m{^rd_?fuse})
      {
        $cmd .= qq{ -q $avrdude_rdfuse_opt | xxd -p};
      }
    else
      {
	usage("command not implemented: $opcode");
      }
  }
elsif ($programmer =~ m{uisp}i)
  {
    print "Support for $programmer is unmaintained. Please try avrdude if this fails.\n" if $verbose;
    $cmd .= "$programmer -dprog=$dongle_type";
    $cmd .= " --hash=128" if $verbose && $opcode =~ m{^(up|down)};
    $cmd .= " -dpart=at$cpu" if $cpu && $cpu ne 'auto';
    $cmd .= " -v=0" if $verbose < 1;
    $cmd .= " -v=$verbose" if $verbose > 1;

    if ($opcode =~ m{^up\w+ee})
      {
        my $filename = shift || 'main.hex';
	$cmd .= qq{ --verify} if $verify;
        $cmd .= qq{ --segment=eeprom --erase --upload if=$filename};
      }
    elsif ($opcode =~ m{^up})
      {
        my $filename = shift || 'main.hex';
	$cmd .= qq{ --verify} if $verify;
        $cmd .= qq{ --segment=flash --erase --upload if=$filename};
      }
    elsif ($opcode =~ m{^down\w+ee})
      {
        my $filename = shift || 'download.hex';
	my $s = ''; $s = " --size=$cpu{$cpu}{eesz}" if $cpu{$cpu}{eesz} > 0;
        $cmd .= qq{ --segment=eeprom --download$s of=$filename};
      }
    elsif ($opcode =~ m{^down})
      {
        my $filename = shift || 'download.hex';
        $cmd .= qq{ --segment=flash --download of=$filename};
      }
    elsif ($opcode =~ m{^reset})
      {
        $cmd .= qq{ };
      }
    elsif ($opcode =~ m{^erase})
      {
        $cmd .= qq{ --erase};
      }
    elsif ($opcode =~ m{^version})
      {
	$verbose = 0;
        print "$0 version $version\n\n";
        $cmd = qq{uisp --version 2>&1 | head -3};
      }
    elsif ($opcode =~ m{^clock})
      {
        my $f = clock_fuses($cpu, @ARGV);
        $cmd .= join '', map { sprintf " --wr_fuse_%s=0x%02x", $_, $f->{$_} } keys %$f;
	warn "old code. uisp code should be updated to use the new macro interpreter. see avrdude branch of clock command.";
      }
    elsif ($opcode =~ m{^rd_?fuse})
      {
        $cmd .= qq{ --rd_fuses};
      }
    else
      {
	usage("command not implemented: $opcode");
      }
  }
else
  {
    usage("programmer $programmer is unknown");
  }

print "$cmd\n" if $verbose or $noop;
exit 0 if $noop;
system $cmd and die "command failed: $cmd: $!\n\nHint: try again, programming may not be 100% reliable\n";

exit 0;
###################################################################
sub usage
{
  my ($msg) = @_;
  print qq{
avr-isp Version $version

Usage:
	$0 [options] <command> args...

Valid options are:
 -v			Be more verbose. Default: $verbose
 -q             	Be quiet. Not verbose.
 -c pgm_dongle  	Specify hardware dongle (e.g. stk200, usbasp).
                        Default: $dongle_type
 -s programmer  	Select 'avrdude' or 'uisp'. Default: $programmer
 -P dongle_port     	Specify port with dongle. Default: depends on -c
 -A avrdude_options     Specify options to calling avrdude. Default: depends on -c
 -r                     Run programmer as root (like -s 'sudo ...'). Try this, 
                        if you see 'permission denied' errors.
 -n             	No operation. Print the suggested command line only.
 -F                     Disable verify. Default: verify=$verify
 -y             	Avrdude only: use last 4 bytes as flashcount.
 -p cpu			Specify the CPU type. Use 'list' to get a list.
			Avrdude: mandatory; Uisp: default auto-detect.
			Use 'auto' to query Makefile for CPU=....

Valid commands are:
  upload file.hex	Upload hex record file.hex to the device flash.
  upload_ee file.hex	Upload hex record file.hex to the device eeprom.
  download file.hex	Download device flash to hex record file.hex.
  download_ee file.hex	Download device eeropm to hex record file.hex.
  list 			List known device CPUs.
  flashsize 		Print size of flash memory in bytes. Use with -p
  ramsize 		Print size of ram memory in bytes. Use with -p
  eesize 		Print size of eeprom memory in bytes. Use with -p
  erase 		Erase the device, flash and eeprom.
  reset 		Reset the device.
  version 		Print version numbers.
  clock NNmhz           Program device fuses to run at NN Megahertz.
  clock NNmhz file.h    As above, but also write F_CPU, CPU_MHZ to file.h.
  rdfuses               Read the fuses from device.
  wrfuses bits=val ...  Write fuse bits to the device.
  cpu_defines           Compile memory and fuse definitions from header files.
};

  print "\nError: $msg\n" if $msg;
  exit 1;
}

sub parse_load_cpu_mhz
{
  my ($file, $symbol) = @_;
  $symbol ||= 'F_CPU';
  my $mhz = undef;
  open my $fd, "<", $file or die "$0: read($file) failed: $!\n";
  while (defined (my $line = <$fd>))
    {
      chomp $line;
      ## # define F_CPU 1000000L
      if ($line =~ m{^#\s*define\s+\Q$symbol\E\s+([\d\.]+)})
        {
	  $mhz = $1;
	  $mhz = $mhz / 1000000.;
	}
    }
  close $fd;
  print "$file loaded: ${mhz}mhz.\n" if $verbose;
  return "clock=" . $mhz . "mhz";
}

sub parse_save_cpu_mhz
{
  my ($file, $mhz) = @_;

  $mhz =~ s{^\D*}{};	# strip off 'clock=' prefix;
  $mhz =~ s{mhz$}{}i;
  $mhz *= 0.001 if $mhz =~ s{khz$}{}i;
  $mhz *= 0.000001 if $mhz =~ s{hz$}{}i;
  return $mhz unless defined $file;

  open my $fd, ">", $file or die "$0: open($file) failed: $!\n";
  printf $fd qq{// autogenerated by $0, }.scalar(localtime).qq{
#ifndef CPU_MHZ
# define CPU_MHZ %d
# define CPU_MHZ_10 %d
# define F_CPU %ldL
#endif
}, $mhz, 10*$mhz, 1000000*$mhz;
  close $fd or die "$0: write($file) failed: $!\n";
  print "$file written.\n" if $verbose;
  return $mhz;
}

##
## this is obsolete code, used with uisp
##
sub clock_fuses
{
  my ($cpu, $mhz, $file, @opt) = @_;

  $mhz = parse_save_cpu_mhz($file, $mhz);
  my $f = do_clock_fuses($cpu, $mhz);
}

##
## this is obsolete code, used with uisp
##
sub do_clock_fuses
{
  my ($cpu, $mhz) = @_;

  if ($cpu =~ m{^mega8$})
    {
      # factory default: l => 0xe1, h => 0xd9, e => 0xff
      print "using external crystal\n" if $verbose and $mhz =~ m{^(16)};
      return { l => 0xff, h => 0xc1 } if $mhz == 16;
      return { l => 0xe4, h => 0xd1 } if $mhz ==  8;
      return { l => 0xe3, h => 0xd1 } if $mhz ==  4;
      return { l => 0xe2, h => 0xd1 } if $mhz ==  2;
      return { l => 0xe1, h => 0xd1 } if $mhz ==  1;
      usage("$cpu $mhz MHZ not impl. Try 16, 8, 4, 2, 1");
    }
  elsif ($cpu =~ m{^mega(4|8|16)8$})
    {
      # factory default: l => 0x62, h => 0xdf, e => 0xff, lock=0xff
      print "using external crystal\n" if $verbose and $mhz =~ m{^(20|16)};
      return { l => 0xf7, h => 0xdf } if $mhz == 20;
      return { l => 0xe4, h => 0xdf } if $mhz == 16;
      return { l => 0xe2, h => 0xdf } if $mhz ==  8;
      return { l => 0x62, h => 0xdf } if $mhz ==  1;
      return { l => 0xe3, h => 0xdf } if $mhz ==  0.128;
      usage("$cpu $mhz MHZ not impl. Try 20, 16, 8, 1, 128khz");
    }
  elsif ($cpu =~ m{^tiny2313$})
    {
      # factory default: l => 0x62, h => 0xdf
      print "using external crystal\n" if $verbose and $mhz =~ m{^(20|16|2.5)};
      return { l => 0xef } if $mhz == 20;
      return { l => 0xe4 } if $mhz == 8;
      return { l => 0xe2 } if $mhz == 4;
      return { l => 0x6f } if $mhz == 2.5;
      return { l => 0x64 } if $mhz == 1;
      return { l => 0x62 } if $mhz == 0.5;
      return { l => 0xe6 } if $mhz == 0.128;
      return { l => 0x66 } if $mhz == 0.016;
      usage("$cpu $mhz MHZ not impl. Try 20, 8, 4, 2.5, 1, 500khz, 128khz, 16khz");
    }
  elsif ($cpu =~ m{^tiny24$})
    {
      # factory default: l => 0x62, h => 0xdf
      print "using external crystal\n" if $verbose and $mhz =~ m{^(20|16)};
      return { l => 0xe2 } if $mhz == 8;
      return { l => 0x62 } if $mhz == 1;
      usage("$cpu $mhz MHZ not impl. Try 8, 1");
    }
  elsif ($cpu =~ m{^auto})
    {
      usage("clock_fuses: cpu autodetect not impl.");
    }
  usage("$cpu: clock setting not impl.");
}

sub compile_cpu_defines
{
  my ($cpu) = @_;
  my $filename = '__compile_cpu_defines.c';
  open O, ">$filename"; 
  print O "#include <avr/io.h>\n";
  close O or die "could not write $filename\n";
  # -E -CC -dN 
  # produces comments and defines in correct order.
  # this is exploited to derive in which fuse byte which bit definitions
  # go.
  # We expect #define LFUSE_DEFAULT right after the
  # bit definitions.

  my $cmd1 = "avr-gcc -mmcu=at$cpu -E -CC -dN $filename";
  my $cmd2 = "avr-gcc -mmcu=at$cpu -E $filename";

  print "$cmd1\n" if $verbose;
  open IN, "$cmd1|" or die "failed to exec '$cmd1'\n";
  my %defs;
  my %fuse;
  my @bits = ();
  while (defined (my $line = <IN>))
    {
      chomp $line;
      if ($line =~ m{^#\s*define\s+(RAMEND|XRAMEND|E2END|FLASHEND|SPM_PAGESIZE|FUSE_MEMORY_SIZE|__LOCK_BITS_EXIST|__BOOT_LOCK_BITS_1_EXIST|__BOOT_LOCK_BITS_0_EXIST)})
        {
	  $defs{$1} = undef;
	}
      elsif ($line =~ m{^#\s*define\s+(\w)?FUSE_(\w+)})
        {
	  if ($1 || $2 eq 'DEFAULT')
	    {
	      die "prefix must not be empty with suffix DEFAULT\n" unless $1;
	      die "suffix must be DEFAULT with nonempty prefix '$1'\n" if $2 ne 'DEFAULT';
	      $fuse{$1} = { map { $_ => undef } @bits };
	      $defs{$1 . "FUSE_DEFAULT"} = undef;
	      @bits = ();
	    }
	  else
	    {
	      push @bits, $2;
	      $defs{"FUSE_$2"} = undef;
	    }
	}
    }
  close IN;
  die "left over fuse bits @bits\n" if scalar @bits;

  die "No memory or fuse definitions found.\n" unless keys %defs;

  open O, ">>$filename";
  for my $d (keys %defs)
    {
      print O qq{#ifdef $d\n"$d" $d\n#endif\n};
    }

  my %files_seen;

  print "$cmd2\n" if $verbose;
  open IN, "$cmd2|" or die "failed to exec '$cmd2'\n";
  while (defined (my $line = <IN>))
    {
      if ($line =~ m{^"(\w+)"\s*(.*)$})
        {
	  my ($name,$cval) = ($1,$2);
	  next unless exists $defs{$name};
	  $cval = 1 unless length $cval;
	  $cval =~ s{\(unsigned char\)}{}g;	# perl likes no casts.

	  $cval = 1 unless length $cval;
	  # now it is a C expression, it should work in perl too.
	  my $val = eval $cval;	
	  die "$name: eval('$cval') failed: $@ $!\n" unless defined $val;
	  $val = ~$val if $val > (1<<24);	# oops, negated bit???
	  $defs{$name} = $val;	
	}
      elsif ($line =~ m{^#\s*\d+\s+"(\S+/include/\S+)"\s})
        {
	  # $line = qq{# 1 "/opt/cross/lib/gcc/avr/4.3/../../../../avr/include/avr/iotn26.h" 1 3\n};
	  $files_seen{$1}++;
	}
    }

  printf "Including\n %s\n\n", join "\n ", sort keys %files_seen if $verbose;

  for my $f (keys %fuse)
    {
      for my $b (keys %{$fuse{$f}})
        {
	  my $dk = "FUSE_$b";
	  die "oops, FUSE $f bit $b is not in defs. Cmd: $cmd2\n" unless defined $defs{$dk};
	  $fuse{$f}{$b} = $defs{$dk};
	  delete $defs{$dk};
	}
      $defs{'FUSE_'.$f} = $fuse{$f};
    }
  unlink $filename;

  # atmega48 has no FUSE_* definitions, only *END
  # try atmega48p instead.
  # is this a bug in avrlibc?
  #
  # We expect ca 15 definitions.
  if (scalar keys %defs < 10 && $cpu !~ m{p$})
    {
      printf "only %d fuse definitions for $cpu, trying ${cpu}p\n", scalar keys %defs;
      my $defs2 = compile_cpu_defines($cpu . 'p');
      if (scalar keys %defs < scalar keys %$defs2)
        {
          printf "good, now %d fuse definitions.\n", scalar keys %$defs2;
	  return $defs2;
	}
      else
        {
	  print "no, not good.\n";
	}
    }
  return \%defs;
}

sub test_cpu_defines
{
  my ($hash, $cpu) = @_;

  my $mac = $hash->{$cpu}{macro};

  # if the interpreter has no complaints, all is well.
  my $ov = $verbose; $verbose = 0;
  interpret_assignments($hash, $cpu, 0, keys %$mac);
  $verbose = $ov;
}

sub fuse_operation
{
  my ($hash, $cpu, $cmd_pre, $cmd_opts, @array) = @_;
  my $f = interpret_assignments($hash, $cpu, 0, @array);
  fill_in_unchanged_bits($f, $cmd_pre . ' ' . $cmd_opts);
  my $cmd = join '', map { sprintf " -U %sfuse:w:0x%02x:m", $_->{fuse}, $_->{new} } grep { exists $_->{new} } values %$f;
  return "echo 'no changes'" unless length $cmd;
  return $cmd_pre . " -q" . $cmd;
}

sub fill_in_unchanged_bits
{
  my ($f, $cmd_l_h_e) = @_;
  my $need_fill = 0;
  for my $v (values %$f) { $need_fill += $v->{more}; }

  if ($need_fill && !$noop)
    {
      print "query '$cmd_l_h_e'\n" if $verbose > 1;
      open IN, "-|", $cmd_l_h_e or die "command failed: $cmd_l_h_e: $! $@\n";
      my $lhe = <IN> ||'';
      close IN;
      local $SIG{__DIE__} = undef;
      warn "no response from '$cmd_l_h_e'\n" unless length $lhe;
      if (length $lhe <= 3)
	{
	  # response was binary
	  my @lhe = unpack 'CCC', $lhe;
	  for my $k (qw(fuse_l fuse_h fuse_e))
	    {
	      my $old = shift @lhe;
	      next unless exists $f->{$k};
	      $f->{$k}{old} = $old;
	    }
	}
      else
	{
	  die "oops, non-binary response not implemented. was that uisp?\n";
	}
    }

  for my $k (qw(fuse_l fuse_h fuse_e))
    {
      next unless exists $f->{$k};
      unless (defined $f->{$k}{old})
        {
	  die    "value of $k unknown, have no default for $k\n" unless defined $f->{$k}{default};
	  printf "value of $k unknown, using default 0x%02x\n", $f->{$k}{default};
	  $f->{$k}{old} = $f->{$k}{default};
	}
      $f->{$k}{new} = ($f->{$k}{old} & ~$f->{$k}{mask}) | $f->{$k}{val};
      printf "$k: 0x%02x -> 0x%02x\n", $f->{$k}{old}, $f->{$k}{new} if $verbose;
    }

  return $f;
}

sub interpret_assignments
{
  my ($hash, $cpu, $nofail, @aa) = @_;
  my @a = @aa;	# we'll parse destructive, but may need it later.
  my %todo = map { $_ => 1 } @a;

  $hash->{$cpu}{macro} ||= mk_fuse_macros($cpu);

  my %bitloc;
  # find out where which bit is. and make the match case insensitive
  for my $h (keys %{$hash->{$cpu}})	
    {
      $bitloc{lc $h} = undef;
      my $v = $hash->{$cpu}{$h};
      next unless ref $v eq 'HASH';
      for my $b (keys %$v)
	{
	  next if ref $v->{$b} ne 'ARRAY';
	  $bitloc{lc $b} = $h;
	  $bitloc{lc "$h.$b"} = $h;
	}
    }

  my $r;
  while (defined (my $a = shift @a))
    {
      ## FIXME: we need some way for range-macros.
      ## clock=14.7645Mhz should fall in the range between 8..20 Mhz.
      ##
      if (my $m = $hash->{$cpu}{macro}{lc $a})
        {
          delete $todo{$a};
	  print "\nmacro($m->[0]): $m->[1]\n" if $verbose && $m->[1];
	  $a = $m->[0];
	  $todo{$a} = 1;
	}

      if ($ a=~ m{[,\s]})
        {
          delete $todo{$a};
	  my @f = split(/[,\s]+/, $a);
          %todo = ( %todo, map { $_ => 1 } @f );

	  # take one now, unshift the rest.
	  $a = shift @f;
	  unshift @a, @f;
	}
    
      if ($a =~ m{([lhe]?)_?fuse_?([lhe]?)=(0x[\da-f]+|\d+)$}i)
        {
          delete $todo{$a};

	  my ($letter,$l2,$val) = ($1,$2,$3);
	  $letter ||= $l2;
	  die "$a: which fuse? please try lfuse,hfuse,efuse\n" unless $letter;

	  $r->{byte}{"fuse_$letter"} = 
	    {
	      mask => 0xff,
	      val  => ($val =~ m{^0x}) ? hex($val) : $val,
	      default => mk_fuse_default($hash->{$cpu}{"fuse_$letter"}),
	      more    => 0
	    };
	}
      elsif ($a =~ m{(\S+)=([01]+)})
	{
          delete $todo{$a};
	  my ($name, $bits) = ($1, $2);
	  my @bits = split //, $bits;
	  my $base;
	  my @nums;
	  if ($name =~ m{^(\S+)\[(\d+,[\d,]+)\]$}) 	# FOO[3,2,1]	= @bits
	    {
	      $base = $1;
	      @nums = split /,/, $2;
	    }
	  elsif ($name =~ m{^(\S+)\[(\d+)\.\.(\d+)\]$})	# FOO[3..0]	= @bits
	    {
	      $base = $1;
	      @nums = ($2 <= $3) ? $2..$3 : reverse $3..$2;
	    }
	  elsif ($name =~ m{^(\S+)\[(\d+)\]$})		# FOO[321]	= @bits
	    {
	      $base = $1;
	      @nums = split //, $2;
	    }
	  else
	    {
	      $base = $name;
	      if (scalar @bits == 1)			# FOO		= 1
		{
		  @nums = ('');
		}
	      else					# FOO		= 0110
		{
		  @nums = reverse 0..$#bits;
		}
	    }
	  die "number of variables and bits does not match\n" if scalar @nums ne scalar @bits;
	  for my $i (0..$#bits)
	    {
	      my $bit =  "$base$nums[$i]"; 
	      $r->{bits}{$bit} = $bits[$i];
	      $todo{$bit} = 1;
	    }
	}
      elsif (!$nofail)
	{
          local $SIG{__DIE__};
          my $have = join ', ', grep { !/^\w+\./ } sort keys %bitloc;
	  die "'$a' is not a bit assignment nor a macro. We have:\n $have\n";
	}
    }

  for my $b (keys %{$r->{bits}})
    {
      if (my $h = $bitloc{lc $b})
	{
	  delete $todo{$b};
	  my $hb = $b; $hb =~ s{^\S+\.}{};	# chop the prefix.

	  ## HACK alert: try mixed case, upper case or lower case.
	  ## we should have normalized everything to lower case before.
	  my $a = $hash->{$cpu}{$h}{$hb} ||
	          $hash->{$cpu}{$h}{uc $hb} ||
		  $hash->{$cpu}{$h}{lc $hb};

	  die "bit $hb not found in $h of $cpu\n" unless defined $a;
	  my $bv = 1 << $a->[0];
	  $r->{byte}{$h}{mask}    |= $bv;
	  $r->{byte}{$h}{val}     |= $r->{bits}{$b} ? $bv : 0;	# make sure it exists
	  $r->{byte}{$h}{default} |= mk_fuse_default($hash->{$cpu}{$h});
	  $r->{byte}{$h}{more} = scalar keys %{$hash->{$cpu}{$h}} 
	    unless defined $r->{byte}{$h}{more};
	  $r->{byte}{$h}{more}--;
	}
    }

  for my $k (keys %{$r->{byte}})
    {
      $r->{byte}{$k}{fuse} = $1 if $k =~ m{^fuse_(.)$};
    }

  if (!$nofail && keys %todo)
    {
      my @fuses = grep { /fuse/ } keys %{$hash->{$cpu}};
      if (!scalar(@fuses) and !$hash->{__just_written}{$cpu}++)
        {
	  # don't complain about an outdated defines file, if there is none.
	  my $d = compile_cpu_defines($cpu);
	  $hash->{$cpu} = write_cpu_defines($defines_file, $d, \%std_fuse_comment, mk_fuse_macros($cpu));
	  return interpret_assignments($hash, $cpu, $nofail, @aa) if -s $defines_file;
	}
      my $todo = join ', ', keys %todo;
      my $have = join ', ', grep { !/^\w+\./ } sort keys %bitloc;
      local $SIG{__DIE__};
      die qq{
$todo:
 not in $cpu definition. 
Try updating the definitions with 
 $0 cpu_defs
Currently we have these bits and macros:
 $have
};
    }
  return $r->{byte};
}

sub mk_fuse_default
{
  my ($f) = @_;

  #
  # Be save, and default the default to all unprogrammed.
  # Only remove the bits we know programmed by default.
  #
  my $default = 0xff;	
  for my $bit (values %$f)
    {
      $default &= ~(1 << $bit->[0]) unless $bit->[1];
    }
  return $default;
}

sub load_fuse_macro
{
  if (-f $macro_file && -s _)
    {
      my $macro = do $macro_file;
      print "$macro_file loaded.\n" if $verbose;
      return $macro;
    }

  save_dumper($macro_file, \%fuse_macro, qq{# Started with builtin defaults from $0, V$version, } . 
scalar(localtime) . qq{
# Add your own macros here and send them upstream, if you like.
});
  return \%fuse_macro;
}

# collects from std, cpu-family and cpu-name
# and converts to all lower case for easier matching.
sub mk_fuse_macros
{
  my ($cpu) = @_;

  my %m;
  my $family = $cpu;
  my $family2 = $cpu;
  $family =~ s{(\d)}{X};
  $family2 =~ s{(\d\d)}{X};

  my $fuse_macro = load_fuse_macro();
  my $no_std = $fuse_macro->{$cpu}{__no_std__} || 0;

  for my $layer ('std', $family, $family2, $cpu)
    {
      next if $layer eq 'std' and $no_std;
      if (defined (my $m = $fuse_macro->{$layer}))
	{
	  for my $k (keys %$m)
	    {
	      $m{lc $k} = $m->{$k} unless $k =~ m{^__.*__$};
	    }
	}
    }
  return \%m;
}

sub write_cpu_defines
{
  my ($defines_file, $defs, $comments, $macros) = @_;

  #
  # transform the bitvalues found in the FUSE_X defines into the fuse_x hashes 
  # where the values are [ bitidx, default, comment ];
  #
  # transform the FOOEND values into foosz values, which are FOOEND+1
  #
  my %cpu;
  $cpu{pagesz} = $defs->{SPM_PAGESIZE} if defined $defs->{SPM_PAGESIZE};
  for my $end (grep { /END$/ } keys %$defs)
    {
      my $sz = lc $end;

      $sz =~ s{end$}{sz};
      $sz =~ s{^e2}{ee};

      $cpu{$sz} = $defs->{$end}+1;
      if ($sz eq 'ramsz')
	{ 
	  my $ramsz_pessimistic = 1 << ffs($cpu{ramsz});
	  if ($ramsz_pessimistic < $cpu{ramsz})
	    {
	      print "Strange RAMEND=$defs->{RAMEND} indicates RAMSTART>0;\n" if $verbose;
	      print "rounding ramsz down to $ramsz_pessimistic.\n" if $verbose;
	      $cpu{ramsz} = $ramsz_pessimistic;
	    }
	}
    }

  if ($defs->{__LOCK_BITS_EXIST})
    {
      $cpu{lock} = 
        { 
    	  LB2       => [ 1, 1, '' ],
    	  LB1       => [ 0, 1, '' ] 
	};
    }

  for my $fuse (grep { /^FUSE_.$/ } keys %$defs)
    {
      my $f = $1 if $fuse =~ m{(.)$};
      my $defaultname = $f . "FUSE_DEFAULT";
      my $fdefault = defined ($defs->{$defaultname}) ? ($defs->{$defaultname} ^ 0xff) : 0xff;

      # 2008-09-21, jw: inconsistency bug in avr/io*.h: 
      # all defaults are noninverted bit values (unprogrammed=0, programmed=1), 
      # except for fuse E when it reads 0xff, then it means all unprogrammed.
      # 
      # Example:
      # compare default of bit 0 in e-fuse of mega48 and mega88:
      # The manual doc2545p280f says 1=unprogrammed for both devices, 
      # but the headers define a 1 for mega48 and a 0 for mega88.
      #
      $fdefault = 0xff if $f eq 'E' and $fdefault == 0;
      my $cf = 'fuse_' . lc $f;
      for my $bitname (keys %{$defs->{$fuse}})
	{
	  my $bv = $defs->{$fuse}{$bitname};
	  my $bitpos = ffs($bv);
	  my $default = ($fdefault & $bv) ? 1 : 0;
	  my $comment = $std_fuse_comment{$bitname} || '';
	  $cpu{$cf}{$bitname} = [ $bitpos, $default, $comment ];
	}
    }
  $cpu{macro} = $macros;

  save_dumper($defines_file, \%cpu, qq{# Created by $0, V$version, } 
. scalar(localtime) . qq{
# Do not edit here. Will be overwritten.
# Add your own bit macros to $macro_file, and send them
# upstream, if you deem them useful for public.
});

  return \%cpu;
}

sub save_dumper
{
  my ($filename, $data, $header) = @_;
  local $Data::Dumper::Sortkeys = 1;
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Indent = 1;
  open O, ">", $filename;
  print O $header if $header;

  my $out = Dumper $data;
  while ($out =~ s{^(.*?)(\[.*?\])}{}s)
    {
      my ($pre, $arr) = ($1,$2);
      $arr .= $1 if $arr =~ m{\[.*\[}s and $out =~ s{^(.*?\])}{}s;
      $arr =~ s{\s+}{ }gs;
      print O $pre, $arr;
    }
  print O $out;

  close O or die "could not write $filename: $!\n";
  print "$filename written.\n" if $verbose;
}

sub ffs		#not exported by any perl module??
{
  my ($val) = @_;
  my $n = -1;
  for my $i (0..31)
    {
      my $bv = (1<<$i);
      $n = $i if $val & $bv;
      last if $val < $bv;
    }
  return $n;
}

sub cpu_from_makefile
{
  open IN, "<Makefile" or return undef;
  while (defined(my $line = <IN>))
    {
      chomp $line;
      if ($line =~ m{^CPU\s*=\s*(\w+)})
        {
          print "reading Makefile: CPU=$1\n" if $verbose;
	  close IN;
	  return $1;
	}
    }
  return undef;
}
