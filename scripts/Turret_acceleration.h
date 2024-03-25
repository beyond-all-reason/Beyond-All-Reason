
static-var aimy1delta, timetozero, deceleratethreshold;
static-var aimy1velocity, aimy1target, aimy1position, gameFrame;
//-------------------------------CONSTANT ACCELERATION TURRET TURNING---------------------------
// MaxVelocity and acceleration are in degrees per frame (not second!)
// Jerk is the minimum velocity of the turret
// A high precision requirement can result in overshoots if desired 
// (c) CC BY NC ND Beherith mysterme@gmail.com

#define MAX_AIMY1_VELOCITY <3.00>
#define AIMY1_ACCELERATION <0.15>
#define AIMY1_JERK <0.5>
#define AIMY1_PRECISION <1.2>
#define AIMY1_RESTORE_SPEED <1.0>

RestoreBody() // no need to signal, as threads inherit parents signal masks
{

	sleep 3000;
	start-script Close();
	//turn aimy1 to y-axis <0.000000> speed <60.000000>;
	turn lshoulder to x-axis <0.0> speed <150>;
	turn rshoulder to x-axis <0.0> speed <150>;
	while ( get ABS(aimy1position) > AIMY1_RESTORE_SPEED){
		if (aimy1position > 0 ) {
			aimy1position = aimy1position - AIMY1_RESTORE_SPEED;
			aimy1velocity = (-1) * AIMY1_RESTORE_SPEED;
		}
		else
		{
			aimy1position = aimy1position + AIMY1_RESTORE_SPEED;
			aimy1velocity = AIMY1_RESTORE_SPEED;
		}
		turn aimy1 to y-axis aimy1position speed 30 * AIMY1_RESTORE_SPEED;
		sleep 30;
	}
	aimy1velocity = 0;
}


AimWeapon1(heading, pitch)
{

	start-script Open();
	signal SIGNAL_BODY;
	set-signal-mask SIGNAL_BODY;
	
	if( !HandsUp )
	{
		return (0);
	}
	//signal SIGNAL_HEAD;
	//We can do this any time
	turn lshoulder to x-axis <0.0> - pitch speed <150>;
	turn rshoulder to x-axis <0.0> - pitch speed <150>;	
	aimy1target = heading;
	aimy1delta = aimy1target - aimy1position;

	
	while( ( get ABS(aimy1delta) > AIMY1_PRECISION ) OR (get ABS(aimy1velocity) > AIMY1_JERK)){
		if (gameFrame != get(GAME_FRAME)){ //this is to make sure we dont get double-called, as previous aimweapon thread runs before new aimweaponthread can signal-kill previous one 
			gameFrame = get(GAME_FRAME);
	
			//Clamp aimy1position and aimy1delta between <-180>;<180>
			while (aimy1position >  <180>) aimy1position = aimy1position - <360>;
			while (aimy1position < <-180>) aimy1position = aimy1position + <360>;
			while (aimy1delta >  <180>) aimy1delta = aimy1delta - <360>;
			while (aimy1delta < <-180>) aimy1delta = aimy1delta + <360>;
		
			//number of frames required to decelerate to 0
			timetozero = get ABS(aimy1velocity) / AIMY1_ACCELERATION;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(aimy1velocity)) - (timetozero * (timetozero - 1) * AIMY1_ACCELERATION / 2); 
			
			//get PRINT ( aimy1delta , deceleratethreshold, aimy1velocity, timetozero );
			
			if (get ABS(aimy1delta) <= deceleratethreshold){ //we need to decelerate
				if (aimy1velocity > 0) aimy1velocity = aimy1velocity - AIMY1_ACCELERATION;
				else 				   aimy1velocity = aimy1velocity + AIMY1_ACCELERATION;
			}	
			else //we need to accelerate
			{
				if (aimy1delta > 0) aimy1velocity = get MIN(       MAX_AIMY1_VELOCITY, aimy1velocity + AIMY1_ACCELERATION); 
				else                aimy1velocity = get MAX((-1) * MAX_AIMY1_VELOCITY, aimy1velocity - AIMY1_ACCELERATION);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(aimy1velocity) < AIMY1_JERK){
				if ((aimy1delta >        AIMY1_JERK)) aimy1velocity =        AIMY1_JERK;
				if ((aimy1delta < (-1) * AIMY1_JERK)) aimy1velocity = (-1) * AIMY1_JERK;
			}
			aimy1position = aimy1position + aimy1velocity; 
			turn aimy1 to y-axis aimy1position now;
			aimy1delta = aimy1target - aimy1position ; 	
		}
		sleep 30;
	}
	aimy1velocity = 0;
	start-script RestoreBody();
	return (1);
}