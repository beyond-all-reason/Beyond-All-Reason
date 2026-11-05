// popup_openclose.h
//
// Popup units have open and close animations that need to be fast and reversible
// while blocking their shots for most of the transition (they may settle etc too).
//
// Do not use this with e.g. opencloseanim.h
//
// Usage:
// 1. Include this header.
// 2. Define OpenAnim() and CloseAnim(). These are animations-only and end in waits.
//    Either can be killed partway by the other script which moves and turns in reverse.
// 3. `start-script RequestOpen()` and `RequestClose()` from aiming, restore, and stun code.
// 4. Popups built in an open pose sets isOpen = TRUE and wantOpen = TRUE in its Create().
//    One built partly open closes with `start-script CloseBuildPost()`, not `RequestClose()`.
// 5. isOpen is TRUE only once fully opened. Weapons block shots with `return (!isOpen)`.

#ifndef SIGNAL_OPENCLOSE
	#define SIGNAL_OPENCLOSE 131072 // Check your free bits.
#endif

static-var isOpen, isInTransition, wantOpen;

RequestOpen()
{
	// already open or opening
	if (wantOpen)
	{
		return (0);
	}
	wantOpen = TRUE;
	signal SIGNAL_OPENCLOSE;
	set-signal-mask SIGNAL_OPENCLOSE;
	isInTransition = TRUE;
	call-script OpenAnim();
	isOpen = TRUE;
	isInTransition = FALSE;
}

RequestClose()
{
	// already closed or closing
	if (!wantOpen)
	{
		return (0);
	}
	wantOpen = FALSE;
	isOpen = FALSE;
	signal SIGNAL_OPENCLOSE;
	set-signal-mask SIGNAL_OPENCLOSE;
	isInTransition = TRUE;
	call-script CloseAnim();
	isInTransition = FALSE;
}

CloseBuildPose()
{
	// already asked to open
	if (wantOpen)
	{
		return (0);
	}
	wantOpen = TRUE;
	call-script RequestClose();
}
