//#define TYPE
//	0 is lblade,rblade, 

Killed( severity, corpsetype )
{
	isDying = TRUE;
	corpsetype = 1;
	signal SIGNAL_MOVE;
	emit-sfx 1025 from body;
	if (RAND(0,100) < 33){
		if (RAND(0,100)<severity) explode body type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode head type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode tail type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lfthigh type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lbknee type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lfshin type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lbfoot type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rfthigh type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rbknee type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rfshin type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rbfoot type FALL | NOHEATCLOUD;
	}
	else 
	{
		call-script DeathAnim();
		if (RAND(0,200)<severity) explode body type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode head type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode tail type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode lfthigh type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode lbknee type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode lfshin type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode lbfoot type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode rfthigh type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode rbknee type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode rfshin type FALL | NOHEATCLOUD;
		if (RAND(0,200)<severity) explode rbfoot type FALL | NOHEATCLOUD;
		emit-sfx 1025 from body;
	}
	return( 0 );
}
/*

#include "raptor_death_2legged_ptaq.h"

static-var isDying;
#include "raptor_killed_2legged.h"

StopMoving(){
	signal SIGNAL_MOVE;
	isMoving=FALSE;
	if (!isDying){
		call-script StopWalking();
		start-script Idle();
	}
}

Create()
{
	isDying = FALSE;

*/