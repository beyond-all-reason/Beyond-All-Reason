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
		if (RAND(0,100)<severity) explode lthigh type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lknee type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lshin type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode lfoot type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rthigh type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rknee type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rshin type FALL | NOHEATCLOUD;
		if (RAND(0,100)<severity) explode rfoot type FALL | NOHEATCLOUD;
	}
	else 
	{
		if (RAND(0,100) < 50) {
			call-script DeathAnim();
			if (RAND(0,200)<severity) explode body type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode head type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode tail type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode lthigh type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode lknee type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode lshin type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode lfoot type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode rthigh type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode rknee type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode rshin type FALL | NOHEATCLOUD;
			if (RAND(0,200)<severity) explode rfoot type FALL | NOHEATCLOUD;
		}
		else
		{
			call-script DeathAnimPtaq();
		}
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