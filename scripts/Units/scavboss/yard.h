#ifndef SCRIPTS_YARD_H
#define SCRIPTS_YARD_H

// keep trying to open building'sbuild areauntil we succeed
OpenBuildArea()
	{
	set YARD_OPEN to TRUE;

	while(!(get YARD_OPEN))
		{
		set BUGGER_OFF to TRUE;
		sleep 1500;
		set YARD_OPEN to TRUE;
		}

	set BUGGER_OFF to FALSE;
	}


// keep trying to close building'sbuild areauntil we succeed
CloseBuildArea()
	{
	set YARD_OPEN to FALSE;

	while(get YARD_OPEN)
		{
		set BUGGER_OFF to TRUE;
		sleep 1500;
		set YARD_OPEN to FALSE;
		}

	set BUGGER_OFF to FALSE;
	}

#endif // SCRIPTS_YARD_H
