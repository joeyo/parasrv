#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <errno.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include "parapin.h"

//#define BASE_ADDR LPT1
#define BASE_ADDR 0x8050

bool g_die = false;

void ctrl_c_handler(int i)
{
	printf("\nSignal %d: Exiting...\n", i);
	g_die = true;
}

int main (int argc, char *argv[])
{

	if (pin_init_user(BASE_ADDR) < 0) {
		printf("must be started as root or be suid\n");
		exit(-1);
	}

	// set all switchable pins as output
	pin_output_mode(LP_DATA_PINS | LP_SWITCHABLE_PINS); // all output
	clear_pin(LP_DATA_PINS | LP_SWITCHABLE_PINS); // pull low

	// drop permissions
	if (setgid(getgid()) != 0)
		perror("unable to drop group privileges");
	if (setuid(getuid()) != 0)
		perror("unable to drop user privileges");

	(void) signal(SIGINT, ctrl_c_handler);

	int bit[8];

	bit[0] = LP_PIN01;
	bit[1] = LP_PIN14;
	bit[2] = LP_PIN02;
	bit[3] = LP_PIN15; // output only. oops.
	bit[4] = LP_PIN03;
	bit[5] = LP_PIN16;
	bit[6] = LP_PIN04;
	bit[7] = LP_PIN17;

	while (!g_die) {
		for (int i=0; i<8; i++) {
			struct timespec ts;
			ts.tv_sec = 0; // 0 seconds
			ts.tv_nsec = 50000000; // 100 micorseconds
			set_pin(bit[i]);
			nanosleep(&ts, NULL);
			clear_pin(bit[i]);
		}
	}

	clear_pin(LP_DATA_PINS | LP_SWITCHABLE_PINS); // pull low

	return 0;

}
