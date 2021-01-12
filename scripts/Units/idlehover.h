
//#define IDLEHOVERSCALE 32
//#define IDLEHOVERSPEED 60
//#define IDLEBASEPIECE base

static-var isIdle, IdleX, IdleY, IdleZ, wasIdle;
IdleHover()
{
	while(TRUE){
		// Detect 'idleness' 
		wasIdle = isIdle;
		// get PRINT(get GAME_FRAME, get CURRENT_SPEED, (get UNIT_Y)/65500, (get GROUND_HEIGHT)/65500);
		if (((get CURRENT_SPEED) < 10000) AND (((get UNIT_Y) - (get GROUND_HEIGHT)) > [64] )) {
			isIdle = TRUE;
		}
		else
		{
			isIdle = FALSE;
		}
	
	
		if (isIdle){
			var newIdleX;
			newIdleX = Rand(-1*IDLEHOVERSCALE,IDLEHOVERSCALE);
			var newIdleY;
			newIdleY = Rand(-1*IDLEHOVERSCALE / 2,IDLEHOVERSCALE / 2);
			var newIdleZ;
			newIdleZ =  Rand(-1*IDLEHOVERSCALE,IDLEHOVERSCALE);
			var IdleSpeed;
			IdleSpeed = Rand(IDLEHOVERSPEED,IDLEHOVERSPEED*3); 
			
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