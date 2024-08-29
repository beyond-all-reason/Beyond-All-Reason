
UnitSpeed(){
	maxSpeed = get MAX_SPEED; // this returns cob units per frame i think
	animFramesPerKeyframe = MOVESPEED; //we need to calc the frames per keyframe value, from the known animtime
	maxSpeed = maxSpeed + (maxSpeed /(2*animFramesPerKeyframe)); // add fudge
	while(TRUE){
		animSpeed = (get CURRENT_SPEED);
		if (animSpeed<1) animSpeed=1;
		animSpeed = (maxSpeed * MOVESPEED) / animSpeed; 
		//get PRINT(maxSpeed, animFramesPerKeyframe, animSpeed); //how to print debug info from bos
		if (animSpeed<2) animSpeed=2;
		if (animspeed> 2* MOVESPEED) animSpeed = 2 * MOVESPEED;
		sleep 197;
	}
}


StartMoving(reversing){
	signal SIGNAL_MOVE;
  set-signal-mask SIGNAL_MOVE;
	isMoving=TRUE;
  start-script UnitSpeed();
	start-script Walk();
}

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
	animSpeed = MOVESPEED;
	emit-sfx 1024 + 2 from base;
	emit-sfx 1024 + 2 from base;
	emit-sfx 1024 + 2 from base;
	emit-sfx 1024 + 2 from base;
	turn base to x-axis <-90> now;
	move base to y-axis [-1] *MOVESCALE now;
	move base to y-axis [0] speed [1]*MOVESCALE;
	turn base to x-axis <0> speed <90>;
	var smoke;
	smoke = 0;
	while(smoke < 9){
	//for (smoke = 0; smoke < 8; smoke = smoke+1){
		smoke = smoke + 1;
		sleep 90;
		emit-sfx 1024 + 2 from head;
	}
	gun_1 = 1;
	return (0);
}


	

	
RestoreAfterDelay()
{
	sleep 1000;
	turn aimy1 to y-axis <0> speed <180>;
	turn aimy1 to x-axis <0> speed <180>;
}
