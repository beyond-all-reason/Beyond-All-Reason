
//#define IDLEHOVERSCALE 32
//#define IDLEHOVERSPEED 60
//#define IDLEBASEPIECE base

static-var isIdle, IdleX, IdleY, IdleZ, wasIdle;
IdleHover()
{
	var newIdleX; 
	var newIdleZ;
	var newIdleY;
	var IdleSpeed;
	var unitxz;
	var groundheight;
	while(TRUE){
		// Detect 'idleness' 
		// A hover type aircraft is considered idle if it is moving very slowly and is a [32] elmos above the ground.
		wasIdle = isIdle;
		
		isIdle = FALSE;
		//get PRINT(get GAME_FRAME, get CURRENT_SPEED, (get UNIT_Y)/65500, (get GROUND_HEIGHT)/65500);
		if ((get CURRENT_SPEED) < 10000) {
			unitxz = (get UNIT_XZ);
			newIdleX = (unitxz & 0xffff0000) / 0x00010000; // top 16 bits divided by 65K
			
			// Below does not work, as -100 is returned as 31000...
			//if (newIdleX & 0x00008000) newIdleX = newIdleX & 0xffff0000; // If the number is negative, it must be padded with 1's for twos complement negative number,
			newIdleZ = (unitxz & 0x0000ffff); // silly unpack
			//if (newIdleZ & 0x00008000) newIdleZ = newIdleZ & 0xffff0000; // If the number is negative, it must be padded with 1's for twos complement negative number
			
			// check if we are 'in map bounds'
			// As the packed XZ cant really deal with negative numbers.
			if ((newIdleX>0) && (newIdleX < 16000) && (newIdleZ>0) && (newIdleZ < 16000)){
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

			newIdleX = Rand(-1*IDLEHOVERSCALE,IDLEHOVERSCALE);

			newIdleY = Rand(-1*IDLEHOVERSCALE / 2,IDLEHOVERSCALE / 2);

			newIdleZ =  Rand(-1*IDLEHOVERSCALE,IDLEHOVERSCALE);

			IdleSpeed = Rand(IDLEHOVERSPEED,IDLEHOVERSPEED*3); 
			if (IdleSpeed < 10) IdleSpeed = 10; //wierd div by zero error?
			//get PRINT(newIdleX,newIdleY,newIdleZ,IdleSpeed);
			
			move IDLEBASEPIECE to x-axis [0.25]*newIdleX speed [0.25]*(newIdleX - IdleX)*30/IdleSpeed;
			move IDLEBASEPIECE to y-axis [0.25]*newIdleY speed [0.25]*(newIdleY - IdleY)*30/IdleSpeed;
			move IDLEBASEPIECE to z-axis [0.25]*newIdleZ speed [0.25]*(newIdleZ - IdleZ)*30/IdleSpeed;
			
			turn IDLEBASEPIECE to z-axis <0.25>  * newIdleX speed <0.25> * (newIdleX - IdleX)*30/IdleSpeed;
			turn IDLEBASEPIECE to y-axis <0.25>  * newIdleY speed <0.25> * (newIdleY - IdleY)*30/IdleSpeed;
			turn IDLEBASEPIECE to x-axis <-0.25> * newIdleZ speed <0.25> * (newIdleZ - IdleZ)*30/IdleSpeed;
			
			IdleX = newIdleX;
			IdleY = newIdleY;
			IdleZ = newIdleZ;
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