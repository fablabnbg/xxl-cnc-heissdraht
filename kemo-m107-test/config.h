#define HAVE_WDT 1
#define HAVE_RS232 1
#define RS232_RECEIVE 1
// RS232_BUF_SIZE should be large enough to hold one screen ful of output.
// update_lcd() would delay us otherwise.
#define RS232_BUF_SIZE 40
#define HAVE_SERVOS_NELY 1	// allow full range, and have two inverted, two normal.
