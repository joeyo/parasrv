#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include "parapin.h"
#include "lconf.h"

//#define BASE_ADDR LPT1
#define BASE_ADDR 0x8050

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

	/*
	luaConf lc;
	if (!lc.loadConf("parasrv.rc")) {
		exit(-1);
	}
	*/

	struct sockaddr_un addr;
	int so;
	const char *socket_path = "/tmp/parasrv.sock";

	if (argc > 1)
		socket_path = argv[1];

	if ((so = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		perror("socket error");
		exit(-1);
	}

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path)-1);

	unlink(socket_path); // in case socket already exists

	if (bind(so, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
		perror("bind error");
		exit(-1);
	}
	printf("binding to %s\n", socket_path);

	if (listen(so, 4) == -1) {
		perror("listen error");
		exit(-1);
	}

	while (true) {
		int co;
		if ((co = accept(so, NULL, NULL)) == -1) {
			perror("accept error");
			continue;
		}
		//printf("accept\n");

		ssize_t n;
		char buf[128];
		while ((n = recv(co, buf, sizeof(buf), 0)) > 0) {
			struct timespec ts;
			ts.tv_sec = 0; // 0 seconds
			ts.tv_nsec = 50000; // 50 micorseconds
			//printf("read %ld bytes: %.*s\n", n, (int)n, buf);
			set_pin(LP_PIN01);
			nanosleep(&ts, NULL);
			clear_pin(LP_PIN01);
			printf(".");
			fflush(stdout);
		}
		if (n < 0) {
			perror("read error");
			exit(-1);
		} else if (n == 0) {
			//printf("EOF\n");
			close(co);
		}
	}
	return 0;

	// todo
	// handle ctrl-c
	// close socket so

}
