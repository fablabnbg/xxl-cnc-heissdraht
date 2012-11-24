# Created by ./avr_isp.pl, V0.9h, Tue Aug  7 01:26:58 2012
# Do not edit here. Will be overwritten.
# Add your own bit macros to avr_fuse_macros.pl, and send them
# upstream, if you deem them useful for public.
{
  'eesz' => 256,
  'flashsz' => 4096,
  'fuse_e' => {
    'SELFPRGEN' => [ 0, 1, 'Self-Programming Enable, 1=false' ]
  },
  'fuse_h' => {
    'BODLEVEL0' => [ 0, 1, 'Brown-out Detector trigger level' ],
    'BODLEVEL1' => [ 1, 1, 'Brown-out Detector trigger level' ],
    'BODLEVEL2' => [ 2, 1, 'Brown-out Detector trigger level' ],
    'DWEN' => [ 6, 1, 'DebugWIRE Enable, 1=false' ],
    'EESAVE' => [ 3, 1, 'EEPROM is preserved through chip erase, 1=false' ],
    'RSTDISBL' => [ 7, 1, 'External Reset disable, 1=enabled' ],
    'SPIEN' => [ 5, 0, 'Enable Serial Programming, 1=false' ],
    'WDTON' => [ 4, 1, 'Watchdog Timer always on, 1=false' ]
  },
  'fuse_l' => {
    'CKDIV8' => [ 7, 0, 'Divide clock by 8, 1=false' ],
    'CKOUT' => [ 6, 1, 'Clock Output Enable, 1=false' ],
    'CKSEL0' => [ 0, 0, 'Select Clock source' ],
    'CKSEL1' => [ 1, 1, 'Select Clock source' ],
    'CKSEL2' => [ 2, 0, 'Select Clock source' ],
    'CKSEL3' => [ 3, 0, 'Select Clock source' ],
    'SUT0' => [ 4, 0, 'Select startup time' ],
    'SUT1' => [ 5, 1, 'Select startup time' ]
  },
  'lock' => {
    'LB1' => [ 0, 1, '' ],
    'LB2' => [ 1, 1, '' ]
  },
  'macro' => {
    'bod=1.8v' => [ 'BODLEVEL[2..0]=110', 'brown-out detector at 1.8V' ],
    'bod=2.7v' => [ 'BODLEVEL[2..0]=101', 'brown-out detector at 2.7V' ],
    'bod=4.3v' => [ 'fuse_h.BODLEVEL[2..0]=100', 'brown-out detector at 4.3V' ],
    'bod=off' => [ 'BODLEVEL[2..0]=111', 'brown-out detector disabled' ],
    'clock=0.5mhz' => [ 'CKSEL=1000,CKDIV8=1', 'external quartz 0.5Mhz XTAL1 XTAL2' ],
    'clock=1.8432mhz' => [ 'CKSEL=1010,CKDIV8=1', 'external quartz 0.9-3Mhz XTAL1 XTAL2' ],
    'clock=11.0592mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=128khz' => [ 'CKSEL=0011,CKDIV8=1', 'internal WDT-osc' ],
    'clock=12mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=14.7456mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=16khz' => [ 'CKSEL=0011,CKDIV8=0', 'internal WDT-osc /8' ],
    'clock=16mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=18.4320mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=18.432mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=1mhz' => [ 'CKSEL=1010,CKDIV8=1', 'external quartz 0.9-3Mhz XTAL1 XTAL2' ],
    'clock=2.5mhz' => [ 'CKSEL=1110,CKDIV8=0', 'external quartz 8-20Mhz XTAL1 XTAL2 /8' ],
    'clock=20mhz' => [ 'CKSEL=1110,CKDIV8=1', 'external quartz 8-20Mhz XTAL1 XTAL2' ],
    'clock=2mhz' => [ 'CKSEL=1010,CKDIV8=1', 'external quartz 0.9-3Mhz XTAL1 XTAL2' ],
    'clock=3.6864mhz' => [ 'CKSEL=1100,CKDIV8=1', 'external quartz 3-8Mhz XTAL1 XTAL2' ],
    'clock=4mhz' => [ 'CKSEL=1100,CKDIV8=1', 'external quartz 3-8Mhz XTAL1 XTAL2' ],
    'clock=500000hz' => [ 'CKSEL=1000,CKDIV8=1', 'external quartz 0.5Mhz XTAL1 XTAL2' ],
    'clock=500khz' => [ 'CKSEL=1000,CKDIV8=1', 'external quartz 0.5Mhz XTAL1 XTAL2' ],
    'clock=7.3728mhz' => [ 'CKSEL=1100,CKDIV8=1', 'external quartz 3-8Mhz XTAL1 XTAL2' ],
    'clock=ext_clock' => [ 'CKSEL=0000,CKDIV8=1', 'external clock via XTAL1' ],
    'clock=i128khz' => [ 'CKSEL=0011,CKDIV8=1', 'internal WDT-osc' ],
    'clock=i16khz' => [ 'CKSEL=0011,CKDIV8=0', 'internal WDT-osc /8' ],
    'clock=i1mhz' => [ 'CKSEL=0010,CKDIV8=0', 'internal RC-osc /8' ],
    'clock=i8mhz' => [ 'CKSEL=0010,CKDIV8=1', 'internal RC-osc' ],
    'lbmode=1' => [ 'LB[2..1]=11', 'all unlocked' ],
    'lbmode=2' => [ 'LB[2..1]=10', 'flash+eeprom: no write, fuses locked' ],
    'lbmode=3' => [ 'LB[2..1]=00', 'flash+eeprom: no write or verify, fuses locked' ]
  },
  'pagesz' => 64,
  'ramsz' => 512,
  'xramsz' => 768
}
