// StateChg.h -- Generic State Change support for units that activate and deactivate or whatever

// Due to limitiations of the scripting language, this file must be included twice.  The
// first time must be where the static variables are declared.  The second time must be
// where the functions are defined (and of course before they are called.)

// The Following macros must be defined:  ACTIVATECMD and DEACTIVATECMD.  They are the commands
// to run when the units is actiavted or deactivated.

#ifndef STATECHG_1_
#define STATECHG_1_

// State variables

static-var	statechg_DesiredState, statechg_StateChanging;

#else

#ifndef STATECHG_2_
#define STATECHG_2_

// The states that can be requested

#define ACTIVE 0
#define INACTIVE 1

// State change request functions

InitState()
	{
	// Initial state
	statechg_DesiredState = INACTIVE;
	statechg_StateChanging = FALSE;
	}


RequestState( requestedstate )
	{
	var actualstate;

	// Is it busy?
	if (statechg_StateChanging)
		{
		// Then just tell it how we want to end up.  A script is already running and will take care of it.
		statechg_DesiredState = requestedstate;
		return 0;
		}

	// Keep everybody else out
	statechg_StateChanging = TRUE;

	// Since nothing was running, the actual state is the current desired state
	actualstate = statechg_DesiredState;

	// State our desires
	statechg_DesiredState = requestedstate;

	// Process until everything is right and decent
	while (statechg_DesiredState != actualstate)
		{
		// Change the state

		if (statechg_DesiredState == ACTIVE)
			{
			ACTIVATECMD
			actualstate = ACTIVE;
			}

		if (statechg_DesiredState == INACTIVE)
			{
			DEACTIVATECMD
			actualstate = INACTIVE;
			}
		}

	// Okay, we are finshed
	statechg_StateChanging = FALSE;
	}

#else
// We should never get here.  Introduce an error yelp!
#endif
#endif