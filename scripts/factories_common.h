// This is for easy common stuff like opening the yards , bugger off and setting build stance

// Note: the order of ops in FACTORY_CLOSE_BUILD is quite debateable

/*
Activate()
{
	signal SIGNAL_TURNON;
	set-signal-mask SIGNAL_TURNON;

	FACTORY_OPEN;
}

*/

/*
Deactivate()
{
	signal SIGNAL_TURNON;
	set-signal-mask SIGNAL_TURNON;
    sleep 5000;

	FACTORY_CLOSE;
}
*/

#define FACTORY_OPEN_BUILD set YARD_OPEN to 1;\
	while( !get YARD_OPEN ) \
	{ \
		set BUGGER_OFF to 1; \
		sleep 1430; \
		set YARD_OPEN to 1; \
	} \
	set INBUILDSTANCE to 1;
	
#define FACTORY_CLOSE_BUILD 	set YARD_OPEN to 0;\
	while( get YARD_OPEN )\
	{\
		set BUGGER_OFF to 1;\
		sleep 1430;\
		set YARD_OPEN to 0;\
	}\
	set BUGGER_OFF to 1;\
	set INBUILDSTANCE to 0;
