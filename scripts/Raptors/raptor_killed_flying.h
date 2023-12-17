Killed( severity, corpsetype )
	{
	corpsetype = 1;
	emit-sfx 1025 from body;
	if (RAND(0,100)<severity) explode body type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode head type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode tail type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode lblade type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode mblade type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode rblade type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode rsack type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode lsack type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode rowing type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode lowing type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode riwing type FALL | NOHEATCLOUD;
	if (RAND(0,100)<severity) explode liwing type FALL | NOHEATCLOUD;
	return( 0 );
	}