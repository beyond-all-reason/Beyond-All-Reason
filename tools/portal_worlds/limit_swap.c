/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Offscreen verification harness: bound drawing cost without changing the engine. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdlib.h>
#include <time.h>

void SDL_GL_SwapWindow(void *window)
{
	static void (*swap)(void *);
	static long long deadline;
	if (!swap) swap = dlsym(RTLD_NEXT, "SDL_GL_SwapWindow");
	swap(window);
	const char *setting = getenv("SPRING_PROBE_FPS");
	const double fps = setting ? atof(setting) : 30;
	if (fps <= 0) return;
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	const long long stamp = (long long)now.tv_sec * 1000000000LL + now.tv_nsec;
	const long long interval = (long long)(1000000000.0 / fps);
	if (!deadline || stamp > deadline + interval) deadline = stamp;
	deadline += interval;
	struct timespec until = { deadline / 1000000000LL, deadline % 1000000000LL };
	while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &until, NULL) == EINTR) {}
}
