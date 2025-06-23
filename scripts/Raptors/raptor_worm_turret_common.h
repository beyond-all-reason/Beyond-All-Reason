
// Signal definitions
#define SIGNAL_AIM1 256

#include "../opencloseanim.h"

static-var segvelocity, segtarget, segposition, segdelta, timetozero, deceleratethreshold, gameFrame, segacceleration;


static-var aimy1velocity, aimy1target, aimy1position, aimy1delta, aimy1acceleration;


Motion(){
	var wigglefreq; // NOTE: DO NOT DECLARE VAR WITHIN A WHILE LOOP AS IT WILL OVERFLOW THE COB STACK!
	wigglefreq = RAND(0, WIGGLEFREQUENCY);

 	var sin;
	
	while(1){
		segdelta =  segtarget - segposition;
	
		if( (( get ABS(segdelta)) > SEG_PRECISION ) OR (get ABS(segvelocity) > SEG_JERK)){
			//Clamp segposition and segdelta between <-180>;<180>
			while (segposition >  <180>) segposition = segposition - <360>;
			while (segposition < <-180>) segposition = segposition + <360>;
			while (segdelta >  <180>) segdelta = segdelta - <360>;
			while (segdelta < <-180>) segdelta = segdelta + <360>;
		
			//number of frames required to decelerate to 0
			timetozero = get ABS(segvelocity) / segacceleration;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(segvelocity)) - (timetozero * (timetozero - 1) * segacceleration / 2); 
			
			//get PRINT ( segdelta , deceleratethreshold, segvelocity, timetozero );
			
			if (get ABS(segdelta) <= deceleratethreshold){ //we need to decelerate
				if (segvelocity > 0) segvelocity = segvelocity - segacceleration;
				else 				   segvelocity = segvelocity + segacceleration;
			}	
			else //we need to accelerate
			{
				if (segdelta > 0) segvelocity = get MIN(       MAX_SEG_VELOCITY, segvelocity + segacceleration); 
				else                segvelocity = get MAX((-1) * MAX_SEG_VELOCITY, segvelocity - segacceleration);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(segvelocity) < SEG_JERK){
				// segvelocity = segdelta;// maybe this?
				if ((segdelta >        SEG_JERK)) segvelocity =        SEG_JERK;
				if ((segdelta < (-1) * SEG_JERK)) segvelocity = (-1) * SEG_JERK;
			}
			
			segposition = segposition + segvelocity; 
			
			
			turn seg1 to x-axis segposition now;
			turn seg2 to x-axis segposition now;
			turn seg3 to x-axis segposition now;
			turn seg4 to x-axis segposition now;
			turn seg5 to x-axis segposition now;
			turn head to x-axis segposition now;
			
			
			segdelta = segtarget - segposition ; 
		}
		

		aimy1delta = aimy1target - aimy1position;
		if( ( get ABS(aimy1delta) > AIMY1_PRECISION ) OR ( get ABS(aimy1velocity) > AIMY1_JERK)){
		
			//Clamp aimy1position and aimy1delta between <-180>;<180>
			while (aimy1position >  <180>) aimy1position = aimy1position - <360>;
			while (aimy1position < <-180>) aimy1position = aimy1position + <360>;
			while (aimy1delta >  <180>) aimy1delta = aimy1delta - <360>;
			while (aimy1delta < <-180>) aimy1delta = aimy1delta + <360>;
		
			//number of frames required to decelerate to 0
			timetozero = get ABS(aimy1velocity) / aimy1acceleration;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(aimy1velocity)) - (timetozero * (timetozero - 1) * aimy1acceleration / 2); 
			
			//get PRINT ( aimy1delta , deceleratethreshold , aimy1velocity, timetozero );
			
			if (get ABS(aimy1delta) <= deceleratethreshold){ //we need to decelerate
				if (aimy1velocity > 0) aimy1velocity = aimy1velocity - aimy1acceleration;
				else 				   aimy1velocity = aimy1velocity + aimy1acceleration;
			}	
			else //we need to accelerate
			{
				if (aimy1delta > 0) aimy1velocity = get MIN(       MAX_AIMY1_VELOCITY, aimy1velocity + aimy1acceleration); 
				else                aimy1velocity = get MAX((-1) * MAX_AIMY1_VELOCITY, aimy1velocity - aimy1acceleration);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(aimy1velocity) < AIMY1_JERK){
				//this line will only have effect if our delta is less than jerk
				aimy1velocity = aimy1delta;
			
				if ((aimy1delta >        AIMY1_JERK)) aimy1velocity =        AIMY1_JERK;			
				if ((aimy1delta < (-1) * AIMY1_JERK)) aimy1velocity = (-1) * AIMY1_JERK; 
				
			}
			
			aimy1position = aimy1position + aimy1velocity; 
			turn aimy to y-axis aimy1position now;
			aimy1delta = aimy1target - aimy1position ; 	
			if ((aimy1delta < <7>) AND (aimy1delta > <-7>)){
				//return (1); // INHEADING
			}
		}
		//aimy1velocity = 0;
		

		if (AboveGround ==1 ){
		 
		 // lets have the worm do a Z wave instead
		 //	KSIN:	return int(1024*math::sinf(TAANG2RAD*(float)p1));
		 	turn seg1 to z-axis (get KSIN(wigglefreq + 1 * WIGGLEPHASE)) * WIGGLEAMPLITUDE speed WIGGLESPEED;
		 	turn seg2 to z-axis (get KSIN(wigglefreq + 2 * WIGGLEPHASE)) * WIGGLEAMPLITUDE speed WIGGLESPEED;
		 	turn seg3 to z-axis (get KSIN(wigglefreq + 3 * WIGGLEPHASE)) * WIGGLEAMPLITUDE speed WIGGLESPEED;
		 	turn seg4 to z-axis (get KSIN(wigglefreq + 4 * WIGGLEPHASE)) * WIGGLEAMPLITUDE speed WIGGLESPEED;
		 	turn seg5 to z-axis (get KSIN(wigglefreq + 5 * WIGGLEPHASE)) * WIGGLEAMPLITUDE speed WIGGLESPEED;
		 	turn head to z-axis (get KSIN(wigglefreq + 6 * WIGGLEPHASE)) * WIGGLEAMPLITUDE speed WIGGLESPEED;
		}
		wigglefreq = wigglefreq + WIGGLEFREQUENCY;
		if (wigglefreq > 65536) wigglefreq = wigglefreq - 65536;
		sleep 30;
	}
}



Open(){
 
	set ARMORED to 0;
	move seg1 to y-axis [0] speed [1] * WORMSIZE;
	sleep 250;
	segtarget = <0>;
	wait-for-move seg1 along x-axis;
	AboveGround = 1;

}
Close(){
	  
  
	set ARMORED to 1;
	AboveGround = 0;
 	turn seg1 to z-axis <0> speed WIGGLESPEED;
 	turn seg2 to z-axis <0> speed WIGGLESPEED;
 	turn seg3 to z-axis <0> speed WIGGLESPEED;
 	turn seg4 to z-axis <0> speed WIGGLESPEED;
 	turn seg5 to z-axis <0> speed WIGGLESPEED;
 	turn head to z-axis <0> speed WIGGLESPEED;
	
	segtarget = <-14>;
	move seg1 to y-axis [-1.04] * WORMSIZE speed [0.6] * WORMSIZE;
	wait-for-move seg1 along x-axis;

}

Create()
{
	move base to y-axis [-0.2] * WORMSIZE now;
	move base to y-axis <0> speed [0.1] * WORMSIZE;
	
	segvelocity = 0;
	segtarget= 0;
	segposition = 0;
	segdelta= 0;
	timetozero = 0;
	deceleratethreshold= 0;
	gameFrame= 0;
	segacceleration =  SEG_ACCELERATION;

	aimy1velocity= 0;
	aimy1target =0;
	aimy1position= 0;
	aimy1delta =0;
	aimy1acceleration = AIMY1_ACCELERATION;
	
	
	move seg1 to y-axis [-2.0] * WORMSIZE now;
	
	restore_delay = 2000;
	AboveGround = 0;
						 
	start-script OpenCloseAnim(1);
	SLEEP_UNTIL_UNITFINISHED;
 	//move aimpoint to y-axis [8] now;
 	start-script OpenCloseAnim(0);
 	start-script Motion();
}

Activate()
{
	start-script OpenCloseAnim(1);
}

Deactivate()
{
	start-script OpenCloseAnim(0);
}

SetMaxReloadTime(reloadMS)
{
	restore_delay = reloadMS * 2;
}

static-var  Stunned;
ExecuteRestoreAfterDelay()
{
    if (Stunned) {
        return (1);
    }
	set-signal-mask 0;
	start-script OpenCloseAnim(0);
}
SetStunned(State)
{
    Stunned = State;
	if (!Stunned) {
	    start-script ExecuteRestoreAfterDelay();
	}
}
RestoreAfterDelay()
{
	sleep restore_delay;
	start-script ExecuteRestoreAfterDelay();
}

AimWeapon1(heading, pitch)
{
	// Only calls OpenCloseAnim(1) and the rest of the AimWeapon function 
	// if the time left to shoot is less that 5 seconds. 
	frameslefttoshot = (GET WEAPON_RELOADSTATE(1)) - (GET GAME_FRAME);
    if (frameslefttoshot > 150)
    {
        return (0);
    }
	start-script OpenCloseAnim(1);

	isAiming = 1;
	signal SIGNAL_AIM1;
	set-signal-mask SIGNAL_AIM1;
	while( !AboveGround )
	{
		sleep 250;
	}
	aimy1target = heading;
	aimy1delta = aimy1target - aimy1position;
	
	segtarget = -1 * pitch /  6;
	segdelta = segtarget - segposition;
	
	while (get ABS(aimy1delta) > <10>){
		sleep 30;
	}
	#if (SPIT ==1)
		frameslefttoshot = (GET WEAPON_RELOADSTATE(1)) - (GET GAME_FRAME);
		
		if (frameslefttoshot < 15){ // GET WEAPON_RELOADSTATE(1) gives the frame weapon 1 can fire on
			// if we can fire in 10 frames, do the spit
			
				segtarget = segtarget -500;
				segacceleration = 10 * SEG_ACCELERATION;
				sleep 150;
				
				segtarget = segtarget - SPIT;
		
				sleep 150;
				segacceleration = SEG_ACCELERATION;
		
		}
	#endif
	
	// once we are pretty near to the target heading, as above, we need to do a quick shooty anim:
	
	isAiming = 0;
	start-script RestoreAfterDelay();
	return (1);
}

Shot1()
{
	//emit-sfx 1024 + 0 from flare;
	//segtarget = segtarget +  (Rand( 100, 200 ));
	//aimy1target = aimy1target +  (Rand( 0, 400 ) - 200);
	return (TRUE);
}


//Needs defines before usage:
//UNITSIZE 1-20, small for small units, large for large units, 
//MAXTILT ~100, how much unit should move
//BASEPIECE piecename, 
//HITSPEED <55>, for small units, <15> for large units


// angle[x|z] is always [-500;500], damage is multiplied by 100
// thus if our maxtilt is 100/100, then we get 500, which is about 2.7 degrees of max tilt, which should also kind of scale with unitsize, e.g. smaller units should tilt more, while larger less
// 

// hitspeed should be a part of unitsize, to simplify scaling
HitByWeapon(anglex, anglez, damage)	// angle[x|z] is always [-500;500], damage is multiplied by 100
{
	var amount;//, speedz, speedx;
	amount = damage / (10 * WORMSIZE);
	var randpiece;
	randpiece = 0;
	if (amount < 3  ) return (0);
	//if (RAND(1, MAXTILT) < amount){
	if (1){
		randpiece = RAND(1, 3);
		if (randpiece == 1) emit-sfx 1024 from base;
		if (randpiece == 2) emit-sfx 1024 from seg1;
		if (randpiece == 3) emit-sfx 1024 from seg2;
	}
	if (amount > 100){
		amount = 100;
	}	
	if (anglex ==0 ) { //this happens when hit by lasers
		if (anglez == 0){
			amount = amount / 2;
			anglex = RAND(1,500);
			anglez = RAND(1,500);
		}
	} 
	
	segtarget = segtarget +     ((Rand( 0, amount ) - amount / 2))/6;
	aimy1target = aimy1target +  (Rand( 0, amount ) - amount / 2);
}

static-var isSmoking;
DamagedSmoke(healthpercent, randpiece) // ah yes, clever use of stack variables 
{
	var healthpercent;
	var randpiece;
	while( TRUE )
	{
		healthpercent = get HEALTH;
		
		if( healthpercent < 65 )
		{
			randpiece = RAND(1, 3);
			if (randpiece == 1) emit-sfx 1024 from base;
			if (randpiece == 2) emit-sfx 1024 from head;
			if (randpiece == 3) emit-sfx 1024 from seg3;
		} 
		else {
			isSmoking = 0;
			return;
			//break; // bos2cob.py does not like this one!
		}
		if (healthpercent < 4) healthpercent = 4; 
		sleep healthpercent * 50;
	}
	sleep 97;
	isSmoking = 0;
}

HitByWeaponId(anglex, anglez, weaponid, dmg) //weaponID is always 0,lasers and flamers give angles of 0
{
	if( get BUILD_PERCENT_LEFT) return (100);
	if (isSmoking == 0)	{ 
		isSmoking = 1;
		start-script DamagedSmoke();
	}
	//get PRINT(anglex, anglez, weaponid, dmg);
	start-script HitByWeapon(dmg, anglez,anglex); //I dont know why param order must be switched, and this also runs a frame later :(
	return (100); //return damage percent
}


FireWeapon1()
{
	//segtarget = segtarget + get RAND(0, 10000);
	#if (RECOIL > 0)
		segtarget = segtarget - RECOIL;
		segacceleration = 10 * SEG_ACCELERATION;
		sleep 150;
		
		segtarget = segtarget + 000;

		sleep 150;
		segacceleration = SEG_ACCELERATION;
	#endif
}

QueryWeapon1(pieceIndex)
{
	pieceIndex = flare;
}



AimFromWeapon1(pieceIndex)
{
	pieceIndex = head;
}

Killed(severity, corpsetype)
{
	move base to y-axis [-0.2] * WORMSIZE speed [0.1] * WORMSIZE;
	var randSeverity;
	randSeverity = RAND(0,severity);

	//get PRINT(severity, randSeverity);
	//Head pops off an it recedes
	if (randSeverity >= 0) {
		emit-sfx 1025 from head;
		explode head type FALL | NOHEATCLOUD;
		hide head;
	}
	
	if (randSeverity >= 10) {
		emit-sfx 1025 from seg5;
		explode seg5 type FALL | NOHEATCLOUD;
		hide seg5;
	}
	
	if (randSeverity >= 20) {
		emit-sfx 1025 from seg4;
		explode seg4 type FALL | NOHEATCLOUD;
		hide seg4;
	}
	if (randSeverity >= 30) {
		emit-sfx 1025 from seg3;
		explode seg3 type FALL | NOHEATCLOUD;
		hide seg3;
	}
	if (randSeverity >= 40) {
		emit-sfx 1025 from seg2;
		explode seg2 type FALL | NOHEATCLOUD;
		hide seg2;
	}
	if (randSeverity >= 50) {
		emit-sfx 1025 from seg1;
		explode seg1 type FALL | NOHEATCLOUD;
		hide seg1;
	}
	if (randSeverity <= 50) {
		//get PRINT(severity, randSeverity, 666, 666);
		call-script OpenCloseAnim(0);
		sleep 1500;
		corpsetype = 1;
	}else{
		//get PRINT(severity, randSeverity, 555, 555);
		corpsetype = 2;
	}
	return(corpsetype);
}