
//#define IDLEHOVERSCALE 32
//#define IDLEHOVERSPEED 60
//#define IDLEBASEPIECE base

#ifndef IDLEBASEPIECE
	#define IDLEBASEPIECE base
#endif

#ifndef IDLEHOVERSPEED
	#define IDLEHOVERSPEED 60
#endif

#ifndef IDLEHOVERSCALE
	#define IDLEHOVERSCALE 32
#endif

static-var IdleX, IdleY, IdleZ;
IdleHover()
{
	// These three vars could be optimized to 1 var, but its not really needed
	var newIdle;
	var unitxz;
	var unitz;
	var unitx;
	var groundheight;
	
	var IdleSpeed;
	var isIdle;
	var wasIdle;
	isIdle = FALSE;
	wasIdle = FALSE;
	while(TRUE){
		// Detect 'idleness' 
		// A hover type aircraft is considered idle if it is moving very slowly and is a [32] elmos above the ground.
		wasIdle = isIdle;
		
		isIdle = FALSE;
		//get PRINT(get GAME_FRAME, get CURRENT_SPEED, (get UNIT_Y)/65500, (get GROUND_HEIGHT)/65500);
		if ((get CURRENT_SPEED) < 10000) {
			unitxz = (get UNIT_XZ);
			unitz = (unitxz & 0x0000ffff); // silly unpack
			unitx = (unitxz & 0xffff0000) / 0x00010000; // top 16 bits divided by 65K
			
			// Below does not work, as -100 is returned as 31000...
			//if (newIdleX & 0x00008000) newIdleX = newIdleX & 0xffff0000; // If the number is negative, it must be padded with 1's for twos complement negative number,
			//if (newIdleZ & 0x00008000) newIdleZ = newIdleZ & 0xffff0000; // If the number is negative, it must be padded with 1's for twos complement negative number
			
			// check if we are 'in map bounds'
			// As the packed XZ cant really deal with negative numbers.
			if ((unitx>0) && (unitx < 16000) && (unitz>0) && (unitz < 16000)){
				groundheight = (get GROUND_HEIGHT(unitxz)); // GROUND HEIGHT EXPECT PACKED COORDS!
				if (((get UNIT_Y) - groundheight) > [32] ){
					isIdle = TRUE;
				}
			}
		}
		
		//get PRINT(get GAME_FRAME, get CURRENT_SPEED, ((get UNIT_Y) - (get GROUND_HEIGHT)) /[1]);
		//get PRINT(get GAME_FRAME, newIdleX, newIdleZ, isIdle);
		//get PRINT((get GAME_FRAME), newIdleX, newIdleZ, (get GROUND_HEIGHT(unitxz)));

		if (isIdle){
			IdleSpeed = Rand(IDLEHOVERSPEED,IDLEHOVERSPEED*3); 
			if (IdleSpeed < 10) IdleSpeed = 10; //wierd div by zero error?
			//get PRINT(newIdleX,newIdleY,newIdleZ,IdleSpeed);
			
			newIdle = Rand(-1*IDLEHOVERSCALE,IDLEHOVERSCALE);
			move IDLEBASEPIECE to x-axis [0.25] * newIdle speed [0.25] * (newIdle - IdleX)*30/IdleSpeed;
			turn IDLEBASEPIECE to z-axis <0.25> * newIdle speed <0.25> * (newIdle - IdleX)*30/IdleSpeed;
			IdleX = newIdle;

			newIdle = Rand(-1*IDLEHOVERSCALE / 2,IDLEHOVERSCALE / 2);
			move IDLEBASEPIECE to y-axis [0.25] * newIdle speed [0.25] * (newIdle - IdleY)*30/IdleSpeed;
			turn IDLEBASEPIECE to y-axis <0.25> * newIdle speed <0.25> * (newIdle - IdleY)*30/IdleSpeed;
			IdleY = newIdle;

			newIdle =  Rand(-1*IDLEHOVERSCALE,IDLEHOVERSCALE);
			move IDLEBASEPIECE to z-axis [0.25] * newIdle speed [0.25] * (newIdle - IdleZ)*30/IdleSpeed;
			turn IDLEBASEPIECE to x-axis <-0.25> * newIdle speed <0.25> * (newIdle - IdleZ)*30/IdleSpeed;
			IdleZ = newIdle;
			
			sleep 1000*IdleSpeed/30;
			sleep 98;
		}
		else{
			if (wasIdle) {
				move IDLEBASEPIECE to x-axis [0] speed [0.25]*(IdleX);
				move IDLEBASEPIECE to y-axis [0] speed [0.25]*(IdleY);
				move IDLEBASEPIECE to z-axis [0] speed [0.25]*(IdleZ);
			
				turn IDLEBASEPIECE to z-axis <0> speed <0.25>*(IdleX);
				turn IDLEBASEPIECE to y-axis <0> speed <0.25>*(IdleY);
				turn IDLEBASEPIECE to x-axis <0> speed <0.25>*(IdleZ);
			}
			sleep 1000;
		}
	}
}