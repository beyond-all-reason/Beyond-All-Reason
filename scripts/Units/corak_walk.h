// These two static-var's MUST be declared in the script that includes this header.
//static-var  isMoving, maxSpeed;
// The animation function's name gets exported as ANIMATIONNAME, e.g. WALK

#ifndef ANIMATIONNAME_INIT
	#define ANIMATIONNAME_INIT()\
		maxSpeed = get (MAX_SPEED); \
		if (maxSpeed < 1) maxSpeed = 1; 
#endif

// Times here are specified as milliseconds per frame. So 33 is the default speed.
#ifndef ANIMATIONNAME_DEFAULT_ANIM_TIME
	#define ANIMATIONNAME_DEFAULT_ANIM_TIME 33
#endif
#ifndef ANIMATIONNAME_MIN_ANIM_TIME
	#define ANIMATIONNAME_MIN_ANIM_TIME (ANIMATIONNAME_DEFAULT_ANIM_TIME/2)
#endif
#ifndef ANIMATIONNAME_MAX_ANIM_TIME
	#define ANIMATIONNAME_MAX_ANIM_TIME (ANIMATIONNAME_DEFAULT_ANIM_TIME*3)
#endif

/*
ANIMATIONNAME_CALC(desiredFrames, remainder_ms){ // we can abuse the stack of Walk for
	// Add 1 to avoid division by zero
	currTime = VA_DEFAULT_ANIM_TIME * maxSpeed / (get (CURRENT_SPEED) + 1);
	if (currTime < VA_MIN_ANIM_TIME) currTime = VA_MIN_ANIM_TIME;
	if (currTime > VA_MAX_ANIM_TIME) currTime = VA_MAX_ANIM_TIME;

	// Lets assume DefaultFrame is 2 
	// Lets also assume:
	//  - A: slow movement, at 66% of original speed, means currTime = 50 
	//  - B: Faster movement, at 133% of original speed, means currTime = 24
	currTime = desiredFrames * currTime + remainder_ms;

	desiredFrames = currTime / 33; // here we clobber desiredFrames to save one var 
	remainder_ms = currTime % 33;

    // Lets also add an ANIMNAME_AMPLITUDE 

}
*/

#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES() \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (get (CURRENT_SPEED) + 1); \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \
			currTime = desiredFrames * currTime + remainder_ms; \
			remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  
#endif

/*
// VAS is much more complex, as it not only controls the animation's speed, but also its AMPLITUDE 
// 
VAS_CALC(desiredFrames, remainder_ms){ // we can abuse the stack of Walk for
	// Add 1 to avoid division by zero
	currTime = VA_DEFAULT_ANIM_TIME * maxSpeed / (get (CURRENT_SPEED) + 1);
	if (currTime < VA_MIN_ANIM_TIME) currTime = VA_MIN_ANIM_TIME;
	if (currTime > VA_MAX_ANIM_TIME) currTime = VA_MAX_ANIM_TIME;

	// Lets assume DefaultFrame is 2 
	// Lets also assume:
	//  - A: slow movement, at 66% of original speed, means currTime = 50 
	//  - B: Faster movement, at 133% of original speed, means currTime = 24
	currTime = desiredFrames * currTime + remainder_ms;

	desiredFrames = currTime / 33; // here we clobber desiredFrames to save one var 
	remainder_ms = currTime % 33;
}


Walk_VA(){
	set-signal-mask SIGNAL_MOVE; 
	var remainder_ms;
	var currTime;
	var desiredFrames;
	remainder_ms = 0;
	if (isMoving) { // The first step from stance to walk
		desiredFrames = 2;
		VA_CALC_DESIRED_FRAMES();

		turn lfoot to x-axis ((<-40.243512> *ANIMATIONNAME_amplitude)/100) speed ((<1273.943828> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33 * desiredFrames) -1);

	} // The actual walk 
	while(isMoving){
		if (isMoving){
			desiredFrames = 2;
			VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<-40.243512> *ANIMATIONNAME_amplitude)/100) speed ((<1273.943828> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			sleep ((33 * desiredFrames) -1);
		}
	}
}
    */
#define MOVESCALE 100

// There are two options going forward. Either ANIMATIONNAME_amplitude is #defined by the script that includes this, OR 
// There is a mix factor that blends between amplitude and timing modulation. 

// If the anim is supposed to go faster than the default, then we blend 25% of that into timing, and the rest into amplitude
#ifndef ANIMATIONNAME_FAST_SPEED_BLEND
	#define ANIMATIONNAME_FAST_SPEED_BLEND 20
#endif
// If we are moving slower than default, then its a straight up 50/50 blend 
#ifndef ANIMATIONNAME_SLOW_SPEED_BLEND
	#define ANIMATIONNAME_SLOW_SPEED_BLEND 50
#endif
/*
#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE_OLD
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE_OLD(DESIREDFRAMES) \
            tmp = get (CURRENT_SPEED); \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (tmp + 1); \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \


            // Lets try this as float, and then go ints

            currentPCt = (ANIMATIONNAME_DEFAULT_ANIM_TIME / currTime) - 1.0 ; // positive means faster than default, negative means slower 
            currTime = currTime * (1.0 - (currentPCt) * ANIMATIONNAME_SLOW_SPEED_BLEND ); 
            ANIMATIONNAME_amplitude =  (1.0 + (currentPCt) * (1.0 - ANIMATIONNAME_SLOW_SPEED_BLEND)); 

            // ok go to ints:

            currentPCt = ((100 * ANIMATIONNAME_DEFAULT_ANIM_TIME) / currTime) - 100; // positive means faster than default, negative means slower 

            currTime = (currTime * (100 - ((currentPCt * ANIMATIONNAME_SLOW_SPEED_BLEND)/ 100))) / 100; 

            ANIMATIONNAME_amplitude = 100 + (currentPCt) * (100 - ANIMATIONNAME_SLOW_SPEED_BLEND) / 100; 


            if (currTime > ANIMATIONNAME_DEFAULT_ANIM_TIME) { // e.g. we are going slow.
                currPCTdelta = (100 * (currTime - ANIMATIONNAME_DEFAULT_ANIM_TIME)) / ANIMATIONNAME_DEFAULT_ANIM_TIME; \

                currPCTtime = 100 + currPCTdelta * ANIMATIONNAME_SLOW_SPEED_BLEND / 100; \
                currPCTamplitude = 100 - currPCTdelta * (100 - ANIMATIONNAME_SLOW_SPEED_BLEND) / 100; \

                currTime = currTime - (currPCTdelta * (100 - ANIMATIONNAME_SLOW_SPEED_BLEND)) / 100; \

                ANIMATIONNAME_amplitude = 100 - (currPCTdelta * (100 - ANIMATIONNAME_SLOW_SPEED_BLEND)) / 100; \

                // Lets simulate for running slow at currTime of 50ms
                // currPCTdelta = ~40% 
                // currTime = 50 - (50 * (100 - 60) / 100)

            }else{
                currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME - ((ANIMATIONNAME_DEFAULT_ANIM_TIME - currTime) * ANIMATIONNAME_FAST_SPEED_BLEND) / 100; \
                ANIMATIONNAME_amplitude = (ANIMATIONNAME_amplitude * ANIMATIONNAME_FAST_SPEED_BLEND) / 100; \
            }
			currTime = DESIREDFRAMES * currTime + remainder_ms; \
			ANIMATIONNAME_remainder_ms = currTime % 33;  \
			ANIMATIONNAME_desiredFrames = currTime / 33;  \
            ANIMATIONNAME_amplitude


			get PRINT (get GAME_FRAME, ANIMATIONNAME_desiredFrames, ANIMATIONNAME_remainder_ms, rawSpeed); \
            ANIMATIONNAME_amplitude = 3300/tmp;\
            desiredFrames = 2; \

#endif
*/

/*
// ALMOST

#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE() \
            tmp = get (CURRENT_SPEED); \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (tmp + 1); \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \
            currentPCt = ((100 * ANIMATIONNAME_DEFAULT_ANIM_TIME) / currTime) - 100; \
            currTime = (currTime * (100 - ((currentPCt * ANIMATIONNAME_SLOW_SPEED_BLEND)/ 100))) / 100; \
            ANIMATIONNAME_amplitude = 100 + (currentPCt) * (100 - ANIMATIONNAME_SLOW_SPEED_BLEND) / 100; \
			currTime = desiredFrames * currTime + ANIMATIONNAME_remainder_ms; \
			ANIMATIONNAME_remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  \
			get PRINT (currentPCt, currTime, desiredFrames, ANIMATIONNAME_amplitude); \

#endif

*/
 /*
#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE() \
            tmp = get (CURRENT_SPEED); \
			currentPCt = (((100 * tmp) / (maxSpeed)) - 100); \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (tmp + 1); \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \
            currTime = (ANIMATIONNAME_DEFAULT_ANIM_TIME * (100 - ((currentPCt * ANIMATIONNAME_SLOW_SPEED_BLEND)/ 100))) / 100; \
            tmp = currTime; \
            act_time = currTime; \
            ANIMATIONNAME_amplitude = 100 + (currentPCt) * (100 - ANIMATIONNAME_SLOW_SPEED_BLEND) / 100; \
			currTime = desiredFrames * currTime + ANIMATIONNAME_remainder_ms; \
			ANIMATIONNAME_remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  \
            if (desiredFrames < 1) desiredFrames = 1; \
			get PRINT (currentPCt, currTime, ANIMATIONNAME_amplitude, tmp); \

#endif
*/

/*
// Ok knowing that its a 50/50 blend:

#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE() \
            tmp = get (CURRENT_SPEED); \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (tmp + 1); \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \
			currentPCt = (ANIMATIONNAME_DEFAULT_ANIM_TIME * 100 / currTime) - 100; \
            currTime = (ANIMATIONNAME_DEFAULT_ANIM_TIME * (100 - ((currentPCt * ANIMATIONNAME_SLOW_SPEED_BLEND)/ 100))) / 100; \
            tmp = currTime; \
            act_time = currTime; \
            ANIMATIONNAME_amplitude = 100 + (currentPCt * 60) / 100; \
			currTime = desiredFrames * currTime + ANIMATIONNAME_remainder_ms; \
			ANIMATIONNAME_remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  \
            if (desiredFrames < 1) desiredFrames = 1; \
			get PRINT (currentPCt, currTime, ANIMATIONNAME_amplitude, tmp); \

#endif
*/
/*
// Optimized:

// Ok knowing that its a 50/50 blend:

#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE() \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (get (CURRENT_SPEED) + 1); \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \
			currentPCt = (ANIMATIONNAME_DEFAULT_ANIM_TIME * 100 / currTime) - 100; \
            currTime = (ANIMATIONNAME_DEFAULT_ANIM_TIME * (100 - (currentPCt / 2))) / 100; \
            ANIMATIONNAME_amplitude = 100 + ((currentPCt * 60) / 100); \
			currTime = desiredFrames * currTime + ANIMATIONNAME_remainder_ms; \
			ANIMATIONNAME_remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  \

            //get PRINT (get (GAME_FRAME), currentPCt, currTime, ANIMATIONNAME_amplitude); \

 #endif
*/
// Optimized further

// Ok knowing that its a 50/50 blend:

#ifndef ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE
	#define ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE() \
            currentPCt = ((100 * get (CURRENT_SPEED) ) / maxSpeed  - 100); \
			if (currentPCt < -66) currentPCt = -66; \
			if (currentPCt > 75) currentPCt = 75; \
            currTime = (ANIMATIONNAME_DEFAULT_ANIM_TIME * (100 - (currentPCt / 2))) / 100; \
            ANIMATIONNAME_amplitude = 100 + ((currentPCt * 60) / 100); \
			currTime = desiredFrames * currTime + ANIMATIONNAME_remainder_ms; \
			ANIMATIONNAME_remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  \

            //get PRINT (get (GAME_FRAME), currentPCt, currTime, ANIMATIONNAME_amplitude); \

 #endif



#ifndef ANIMATIONNAME_SIGNAL_MASK
	#define ANIMATIONNAME_SIGNAL_MASK SIGNAL_MOVE
#endif

ANIMNAME() {//Created by https://github.com/Beherith/Skeletor_S3O from N:\animations\corak_anim_walk_v2.blend 
	set-signal-mask ANIMATIONNAME_SIGNAL_MASK;
    var ANIMATIONNAME_remainder_ms;
	var currTime;
    var currentPCt;
	var desiredFrames;
    var ANIMATIONNAME_amplitude; // Always expressed in percent.

    ANIMATIONNAME_amplitude = 100;
	ANIMATIONNAME_remainder_ms = 0;// RAND(0, 66); // Im pretty sure any static

    if (isMoving) { // The first frame of the walking animation MUST be done at at most 2x the desired frames. 
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
            desiredFrames = 4;

			turn lfoot to x-axis ((<-40.243512>/ 100)  *ANIMATIONNAME_amplitude) speed ((<1273.943828> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-7.440659> *ANIMATIONNAME_amplitude)/100) speed ((<223.219252> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-5.865953> *ANIMATIONNAME_amplitude)/100) speed ((<727.995439> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-6.830024> *ANIMATIONNAME_amplitude)/100) speed ((<172.844587> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<0.345820> *ANIMATIONNAME_amplitude)/100) speed ((<29.023982> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<0.304802> *ANIMATIONNAME_amplitude)/100) speed ((<19.258346> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<26.076006> *ANIMATIONNAME_amplitude)/100) speed ((<770.050910> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.157717> *ANIMATIONNAME_amplitude)/100) speed ((<7.701529> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-0.087720> *ANIMATIONNAME_amplitude)/100) speed ((<27.150911> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<18.795205> *ANIMATIONNAME_amplitude)/100) speed ((<152.239487> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<23.125820> *ANIMATIONNAME_amplitude)/100) speed ((<731.292682> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<4.131044> *ANIMATIONNAME_amplitude)/100) speed ((<165.843277> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-0.006083> *ANIMATIONNAME_amplitude)/100) speed ((<9.977088> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-15.533187> *ANIMATIONNAME_amplitude)/100) speed ((<362.612128> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-4.025448> *ANIMATIONNAME_amplitude)/100) speed ((<134.371865> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-1.012513> *ANIMATIONNAME_amplitude)/100) speed ((<204.477528> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-2.390000> *ANIMATIONNAME_amplitude)/100) speed ((<71.699998> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<3.0> *ANIMATIONNAME_amplitude)/100) speed ((<90.0> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<39.611634> *ANIMATIONNAME_amplitude)/100) speed ((<1130.819000> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-9.393908> *ANIMATIONNAME_amplitude)/100) speed ((<282.235463> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<5.383341> *ANIMATIONNAME_amplitude)/100) speed ((<241.075747> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.381296> *ANIMATIONNAME_amplitude)/100) speed ((<29.623899> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.363446> *ANIMATIONNAME_amplitude)/100) speed ((<38.107235> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-31.505187> *ANIMATIONNAME_amplitude)/100) speed ((<1037.860666> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<3.062627> *ANIMATIONNAME_amplitude)/100) speed ((<76.071680> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<3.820081> *ANIMATIONNAME_amplitude)/100) speed ((<190.336606> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-0.115769> *ANIMATIONNAME_amplitude)/100) speed ((<357.617331> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-22.733392> *ANIMATIONNAME_amplitude)/100) speed ((<614.661624> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<2.905186> *ANIMATIONNAME_amplitude)/100) speed ((<18.693993> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<2.837642> *ANIMATIONNAME_amplitude)/100) speed ((<115.024912> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<6.073401> *ANIMATIONNAME_amplitude)/100) speed ((<288.740629> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-2.618910> *ANIMATIONNAME_amplitude)/100) speed ((<373.295110> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<0.276228> *ANIMATIONNAME_amplitude)/100) speed ((<187.966625> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-6.060918> *ANIMATIONNAME_amplitude)/100) speed ((<182.948716> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:4
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
            
			turn lfoot to x-axis ((<-30.657758> *ANIMATIONNAME_amplitude)/100) speed ((<287.572616> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-1.578026> *ANIMATIONNAME_amplitude)/100) speed ((<175.878977> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-3.384192> *ANIMATIONNAME_amplitude)/100) speed ((<74.452829> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-6.365428> *ANIMATIONNAME_amplitude)/100) speed ((<13.937889> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<0.627497> *ANIMATIONNAME_amplitude)/100) speed ((<8.450319> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-0.125771> *ANIMATIONNAME_amplitude)/100) speed ((<12.917179> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<34.419505> *ANIMATIONNAME_amplitude)/100) speed ((<250.304986> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<4.133390> *ANIMATIONNAME_amplitude)/100) speed ((<126.633291> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<38.934206> *ANIMATIONNAME_amplitude)/100) speed ((<604.170018> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<43.405395> *ANIMATIONNAME_amplitude)/100) speed ((<608.387233> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-0.157018> *ANIMATIONNAME_amplitude)/100) speed ((<128.641886> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<4.913218> *ANIMATIONNAME_amplitude)/100) speed ((<147.579022> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-38.188086> *ANIMATIONNAME_amplitude)/100) speed ((<679.646972> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-9.569086> *ANIMATIONNAME_amplitude)/100) speed ((<166.309155> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-6.279474> *ANIMATIONNAME_amplitude)/100) speed ((<158.008808> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.520000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([15.599999] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-0.0> *ANIMATIONNAME_amplitude)/100) speed ((<71.699998> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<5.0> *ANIMATIONNAME_amplitude)/100) speed ((<59.999993> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<24.484406> *ANIMATIONNAME_amplitude)/100) speed ((<453.816842> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-0.003345> *ANIMATIONNAME_amplitude)/100) speed ((<281.716910> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-25.170605> *ANIMATIONNAME_amplitude)/100) speed ((<916.618362> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<1.658174> *ANIMATIONNAME_amplitude)/100) speed ((<38.306322> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<2.094784> *ANIMATIONNAME_amplitude)/100) speed ((<73.746915> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<12.264737> *ANIMATIONNAME_amplitude)/100) speed ((<1313.097704> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.090587> *ANIMATIONNAME_amplitude)/100) speed ((<94.596422> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<-1.066060> *ANIMATIONNAME_amplitude)/100) speed ((<146.584218> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-4.646985> *ANIMATIONNAME_amplitude)/100) speed ((<135.936497> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-39.697541> *ANIMATIONNAME_amplitude)/100) speed ((<508.924481> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<2.737817> *ANIMATIONNAME_amplitude)/100) speed ((<5.021079> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<5.181143> *ANIMATIONNAME_amplitude)/100) speed ((<70.305026> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<14.323402> *ANIMATIONNAME_amplitude)/100) speed ((<247.500020> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-3.641867> *ANIMATIONNAME_amplitude)/100) speed ((<30.688723> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<-1.015437> *ANIMATIONNAME_amplitude)/100) speed ((<38.749968> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-8.679222> *ANIMATIONNAME_amplitude)/100) speed ((<78.549118> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:6
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<-39.010424> *ANIMATIONNAME_amplitude)/100) speed ((<250.579970> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-0.002108> *ANIMATIONNAME_amplitude)/100) speed ((<47.277535> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-0.006890> *ANIMATIONNAME_amplitude)/100) speed ((<101.319038> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<22.853738> *ANIMATIONNAME_amplitude)/100) speed ((<876.574965> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-1.186151> *ANIMATIONNAME_amplitude)/100) speed ((<54.409440> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<4.123133> *ANIMATIONNAME_amplitude)/100) speed ((<127.467114> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-14.821478> *ANIMATIONNAME_amplitude)/100) speed ((<1477.229506> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.568119> *ANIMATIONNAME_amplitude)/100) speed ((<10.721675> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-1.088983> *ANIMATIONNAME_amplitude)/100) speed ((<156.671196> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<7.764953> *ANIMATIONNAME_amplitude)/100) speed ((<935.077597> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<34.201735> *ANIMATIONNAME_amplitude)/100) speed ((<276.109782> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-1.961119> *ANIMATIONNAME_amplitude)/100) speed ((<54.123014> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<5.895231> *ANIMATIONNAME_amplitude)/100) speed ((<29.460377> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-19.159760> *ANIMATIONNAME_amplitude)/100) speed ((<570.849794> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-4.950884> *ANIMATIONNAME_amplitude)/100) speed ((<138.546089> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-1.486378> *ANIMATIONNAME_amplitude)/100) speed ((<143.792862> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.990000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([14.100001] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<6.740000> *ANIMATIONNAME_amplitude)/100) speed ((<202.199998> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<2.970000> *ANIMATIONNAME_amplitude)/100) speed ((<60.900003> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<37.153043> *ANIMATIONNAME_amplitude)/100) speed ((<380.059097> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<8.934135> *ANIMATIONNAME_amplitude)/100) speed ((<268.003689> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-12.813064> *ANIMATIONNAME_amplitude)/100) speed ((<384.291590> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-9.596093> *ANIMATIONNAME_amplitude)/100) speed ((<467.235346> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<-1.342735> *ANIMATIONNAME_amplitude)/100) speed ((<90.027277> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<1.142380> *ANIMATIONNAME_amplitude)/100) speed ((<28.572115> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-10.387000> *ANIMATIONNAME_amplitude)/100) speed ((<679.552101> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.839981> *ANIMATIONNAME_amplitude)/100) speed ((<22.481842> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<3.611564> *ANIMATIONNAME_amplitude)/100) speed ((<140.328704> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-15.163607> *ANIMATIONNAME_amplitude)/100) speed ((<315.498660> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-25.794549> *ANIMATIONNAME_amplitude)/100) speed ((<417.089753> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-2.194373> *ANIMATIONNAME_amplitude)/100) speed ((<147.965705> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<4.020788> *ANIMATIONNAME_amplitude)/100) speed ((<34.810670> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<13.726036> *ANIMATIONNAME_amplitude)/100) speed ((<17.920974> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-3.523284> *ANIMATIONNAME_amplitude)/100) speed ((<3.557483> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-5.940345> *ANIMATIONNAME_amplitude)/100) speed ((<82.166318> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:8
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<2.496757> *ANIMATIONNAME_amplitude)/100) speed ((<1245.215437> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<23.683565> *ANIMATIONNAME_amplitude)/100) speed ((<24.894810> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-0.307654> *ANIMATIONNAME_amplitude)/100) speed ((<26.354925> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<1.733618> *ANIMATIONNAME_amplitude)/100) speed ((<71.685440> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-41.143980> *ANIMATIONNAME_amplitude)/100) speed ((<789.675070> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-1.093781> *ANIMATIONNAME_amplitude)/100) speed ((<15.769877> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-4.328630> *ANIMATIONNAME_amplitude)/100) speed ((<97.189416> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-0.334923> *ANIMATIONNAME_amplitude)/100) speed ((<242.996259> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<8.135991> *ANIMATIONNAME_amplitude)/100) speed ((<781.972333> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-2.494973> *ANIMATIONNAME_amplitude)/100) speed ((<16.015626> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<2.347090> *ANIMATIONNAME_amplitude)/100) speed ((<106.444227> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-2.433948> *ANIMATIONNAME_amplitude)/100) speed ((<501.774362> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-0.551755> *ANIMATIONNAME_amplitude)/100) speed ((<131.973857> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-0.128355> *ANIMATIONNAME_amplitude)/100) speed ((<40.740708> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.028000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([28.860000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<3.070000> *ANIMATIONNAME_amplitude)/100) speed ((<110.099994> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-0.010000> *ANIMATIONNAME_amplitude)/100) speed ((<89.400000> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<0.579182> *ANIMATIONNAME_amplitude)/100) speed ((<1097.215835> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<9.697182> *ANIMATIONNAME_amplitude)/100) speed ((<22.891422> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-5.852873> *ANIMATIONNAME_amplitude)/100) speed ((<208.805747> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-2.039017> *ANIMATIONNAME_amplitude)/100) speed ((<226.712269> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<-2.372498> *ANIMATIONNAME_amplitude)/100) speed ((<30.892883> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<0.697846> *ANIMATIONNAME_amplitude)/100) speed ((<13.336030> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<1.418999> *ANIMATIONNAME_amplitude)/100) speed ((<354.179965> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-1.985140> *ANIMATIONNAME_amplitude)/100) speed ((<34.354772> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<3.043927> *ANIMATIONNAME_amplitude)/100) speed ((<17.029096> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-3.987276> *ANIMATIONNAME_amplitude)/100) speed ((<335.289948> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-2.410771> *ANIMATIONNAME_amplitude)/100) speed ((<701.513340> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-4.519230> *ANIMATIONNAME_amplitude)/100) speed ((<69.745691> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<2.522605> *ANIMATIONNAME_amplitude)/100) speed ((<44.945490> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<1.362851> *ANIMATIONNAME_amplitude)/100) speed ((<370.895552> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-0.497283> *ANIMATIONNAME_amplitude)/100) speed ((<90.780029> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<-0.026282> *ANIMATIONNAME_amplitude)/100) speed ((<31.278638> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<0.085185> *ANIMATIONNAME_amplitude)/100) speed ((<180.765899> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:10
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<38.743818> *ANIMATIONNAME_amplitude)/100) speed ((<1087.411814> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<6.114390> *ANIMATIONNAME_amplitude)/100) speed ((<527.075257> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-1.151940> *ANIMATIONNAME_amplitude)/100) speed ((<25.328603> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<0.462818> *ANIMATIONNAME_amplitude)/100) speed ((<38.124001> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-32.212361> *ANIMATIONNAME_amplitude)/100) speed ((<267.948594> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-1.218581> *ANIMATIONNAME_amplitude)/100) speed ((<3.743992> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-1.139046> *ANIMATIONNAME_amplitude)/100) speed ((<95.687518> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<11.429264> *ANIMATIONNAME_amplitude)/100) speed ((<352.925592> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-23.522654> *ANIMATIONNAME_amplitude)/100) speed ((<949.759345> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-4.561886> *ANIMATIONNAME_amplitude)/100) speed ((<62.007396> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-1.962713> *ANIMATIONNAME_amplitude)/100) speed ((<129.294085> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-11.546510> *ANIMATIONNAME_amplitude)/100) speed ((<273.376866> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<0.020005> *ANIMATIONNAME_amplitude)/100) speed ((<17.152801> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-2.829427> *ANIMATIONNAME_amplitude)/100) speed ((<81.032159> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.295000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([8.010001] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-2.090000> *ANIMATIONNAME_amplitude)/100) speed ((<154.800001> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-3.020000> *ANIMATIONNAME_amplitude)/100) speed ((<90.299997> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<-42.315286> *ANIMATIONNAME_amplitude)/100) speed ((<1286.834032> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<7.682254> *ANIMATIONNAME_amplitude)/100) speed ((<60.447840> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<6.232020> *ANIMATIONNAME_amplitude)/100) speed ((<362.546770> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-5.922912> *ANIMATIONNAME_amplitude)/100) speed ((<116.516840> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.237168> *ANIMATIONNAME_amplitude)/100) speed ((<78.289998> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.176416> *ANIMATIONNAME_amplitude)/100) speed ((<26.227860> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<24.980239> *ANIMATIONNAME_amplitude)/100) speed ((<706.837193> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.548087> *ANIMATIONNAME_amplitude)/100) speed ((<43.111597> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<0.357049> *ANIMATIONNAME_amplitude)/100) speed ((<80.606348> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<13.709837> *ANIMATIONNAME_amplitude)/100) speed ((<530.913396> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<23.022121> *ANIMATIONNAME_amplitude)/100) speed ((<762.986759> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-4.234439> *ANIMATIONNAME_amplitude)/100) speed ((<8.543721> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<0.031378> *ANIMATIONNAME_amplitude)/100) speed ((<74.736792> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-14.629546> *ANIMATIONNAME_amplitude)/100) speed ((<479.771920> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<4.218827> *ANIMATIONNAME_amplitude)/100) speed ((<141.483307> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<1.933472> *ANIMATIONNAME_amplitude)/100) speed ((<58.792617> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<6.110734> *ANIMATIONNAME_amplitude)/100) speed ((<180.766460> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:12
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<25.040025> *ANIMATIONNAME_amplitude)/100) speed ((<411.113782> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-25.275077> *ANIMATIONNAME_amplitude)/100) speed ((<941.684012> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-1.282850> *ANIMATIONNAME_amplitude)/100) speed ((<3.927293> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-2.896653> *ANIMATIONNAME_amplitude)/100) speed ((<100.784134> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<11.758685> *ANIMATIONNAME_amplitude)/100) speed ((<1319.131382> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.728330> *ANIMATIONNAME_amplitude)/100) speed ((<14.707537> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<1.978969> *ANIMATIONNAME_amplitude)/100) speed ((<93.540465> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-5.147298> *ANIMATIONNAME_amplitude)/100) speed ((<497.296866> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-39.148165> *ANIMATIONNAME_amplitude)/100) speed ((<468.765325> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-2.765572> *ANIMATIONNAME_amplitude)/100) speed ((<53.889431> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-5.165048> *ANIMATIONNAME_amplitude)/100) speed ((<96.070032> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<15.052499> *ANIMATIONNAME_amplitude)/100) speed ((<797.970266> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<2.670525> *ANIMATIONNAME_amplitude)/100) speed ((<79.515585> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<0.899942> *ANIMATIONNAME_amplitude)/100) speed ((<111.881066> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.510000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([6.449999] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-0.020000> *ANIMATIONNAME_amplitude)/100) speed ((<62.100001> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-5.360000> *ANIMATIONNAME_amplitude)/100) speed ((<70.200006> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<-30.524095> *ANIMATIONNAME_amplitude)/100) speed ((<353.735736> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<1.575841> *ANIMATIONNAME_amplitude)/100) speed ((<183.192403> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<3.379851> *ANIMATIONNAME_amplitude)/100) speed ((<85.565069> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.124295> *ANIMATIONNAME_amplitude)/100) speed ((<3.386209> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<0.562551> *ANIMATIONNAME_amplitude)/100) speed ((<22.169016> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<34.785873> *ANIMATIONNAME_amplitude)/100) speed ((<294.169042> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.766034> *ANIMATIONNAME_amplitude)/100) speed ((<6.538402> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<-4.202078> *ANIMATIONNAME_amplitude)/100) speed ((<136.773819> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<36.269674> *ANIMATIONNAME_amplitude)/100) speed ((<676.795095> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<42.784230> *ANIMATIONNAME_amplitude)/100) speed ((<592.863272> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-0.065047> *ANIMATIONNAME_amplitude)/100) speed ((<125.081756> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<-4.734660> *ANIMATIONNAME_amplitude)/100) speed ((<142.981142> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-36.734161> *ANIMATIONNAME_amplitude)/100) speed ((<663.138439> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<10.583475> *ANIMATIONNAME_amplitude)/100) speed ((<190.939458> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<8.318628> *ANIMATIONNAME_amplitude)/100) speed ((<191.554687> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<8.849594> *ANIMATIONNAME_amplitude)/100) speed ((<82.165818> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:14
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<37.387998> *ANIMATIONNAME_amplitude)/100) speed ((<370.439186> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-8.962304> *ANIMATIONNAME_amplitude)/100) speed ((<268.846559> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<12.859584> *ANIMATIONNAME_amplitude)/100) speed ((<385.678150> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-9.441686> *ANIMATIONNAME_amplitude)/100) speed ((<475.001758> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<1.271139> *ANIMATIONNAME_amplitude)/100) speed ((<76.619681> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-1.407645> *ANIMATIONNAME_amplitude)/100) speed ((<44.670228> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-10.324155> *ANIMATIONNAME_amplitude)/100) speed ((<662.485225> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<0.960237> *ANIMATIONNAME_amplitude)/100) speed ((<50.657005> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-3.255075> *ANIMATIONNAME_amplitude)/100) speed ((<157.021326> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-15.936846> *ANIMATIONNAME_amplitude)/100) speed ((<323.686434> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-25.377240> *ANIMATIONNAME_amplitude)/100) speed ((<413.127749> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<2.240162> *ANIMATIONNAME_amplitude)/100) speed ((<150.172014> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-4.056589> *ANIMATIONNAME_amplitude)/100) speed ((<33.253758> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<13.964900> *ANIMATIONNAME_amplitude)/100) speed ((<32.627976> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<2.304844> *ANIMATIONNAME_amplitude)/100) speed ((<10.970419> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<1.097682> *ANIMATIONNAME_amplitude)/100) speed ((<5.932195> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-1.027000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([15.509999] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<6.120000> *ANIMATIONNAME_amplitude)/100) speed ((<184.199989> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-3.020000> *ANIMATIONNAME_amplitude)/100) speed ((<70.199999> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<-37.669118> *ANIMATIONNAME_amplitude)/100) speed ((<214.350700> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<0.002079> *ANIMATIONNAME_amplitude)/100) speed ((<47.212867> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<0.006794> *ANIMATIONNAME_amplitude)/100) speed ((<101.191700> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<22.375748> *ANIMATIONNAME_amplitude)/100) speed ((<849.199349> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-3.001270> *ANIMATIONNAME_amplitude)/100) speed ((<106.914647> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-15.573975> *ANIMATIONNAME_amplitude)/100) speed ((<1510.795463> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<1.078429> *ANIMATIONNAME_amplitude)/100) speed ((<55.333897> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<0.621153> *ANIMATIONNAME_amplitude)/100) speed ((<144.696955> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<7.481300> *ANIMATIONNAME_amplitude)/100) speed ((<863.651218> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<35.130125> *ANIMATIONNAME_amplitude)/100) speed ((<229.623139> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<1.654511> *ANIMATIONNAME_amplitude)/100) speed ((<51.586739> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<-5.841921> *ANIMATIONNAME_amplitude)/100) speed ((<33.217822> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-19.401972> *ANIMATIONNAME_amplitude)/100) speed ((<519.965670> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<5.353858> *ANIMATIONNAME_amplitude)/100) speed ((<156.888527> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<3.084982> *ANIMATIONNAME_amplitude)/100) speed ((<157.009377> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<5.762510> *ANIMATIONNAME_amplitude)/100) speed ((<92.612524> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:16
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<0.464192> *ANIMATIONNAME_amplitude)/100) speed ((<1107.714192> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-9.697005> *ANIMATIONNAME_amplitude)/100) speed ((<22.041012> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<5.833231> *ANIMATIONNAME_amplitude)/100) speed ((<210.790579> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-2.0> *ANIMATIONNAME_amplitude)/100) speed ((<223.240686> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<2.411943> *ANIMATIONNAME_amplitude)/100) speed ((<34.224105> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-0.749186> *ANIMATIONNAME_amplitude)/100) speed ((<19.753780> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<1.204694> *ANIMATIONNAME_amplitude)/100) speed ((<345.865479> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<1.961544> *ANIMATIONNAME_amplitude)/100) speed ((<30.039223> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-2.972589> *ANIMATIONNAME_amplitude)/100) speed ((<8.474591> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-4.648268> *ANIMATIONNAME_amplitude)/100) speed ((<338.657342> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-2.351720> *ANIMATIONNAME_amplitude)/100) speed ((<690.765615> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<4.489955> *ANIMATIONNAME_amplitude)/100) speed ((<67.493810> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-2.580664> *ANIMATIONNAME_amplitude)/100) speed ((<44.277734> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<2.055360> *ANIMATIONNAME_amplitude)/100) speed ((<357.286182> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-0.287076> *ANIMATIONNAME_amplitude)/100) speed ((<77.757598> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<0.713883> *ANIMATIONNAME_amplitude)/100) speed ((<11.513976> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.065000] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 speed ((([28.860001] *MOVESCALE)/100) *ANIMATIONNAME_amplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<3.050000> *ANIMATIONNAME_amplitude)/100) speed ((<92.099998> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-0.060000> *ANIMATIONNAME_amplitude)/100) speed ((<88.799998> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<4.648639> *ANIMATIONNAME_amplitude)/100) speed ((<1269.532721> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<22.810462> *ANIMATIONNAME_amplitude)/100) speed ((<13.041427> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<-1.186372> *ANIMATIONNAME_amplitude)/100) speed ((<40.379282> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.668387> *ANIMATIONNAME_amplitude)/100) speed ((<69.986508> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-41.861666> *ANIMATIONNAME_amplitude)/100) speed ((<788.630717> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<2.536832> *ANIMATIONNAME_amplitude)/100) speed ((<43.752081> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<4.475032> *ANIMATIONNAME_amplitude)/100) speed ((<115.616342> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-0.686195> *ANIMATIONNAME_amplitude)/100) speed ((<245.024858> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<8.108854> *ANIMATIONNAME_amplitude)/100) speed ((<810.638150> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<2.222653> *ANIMATIONNAME_amplitude)/100) speed ((<17.044253> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<-2.104883> *ANIMATIONNAME_amplitude)/100) speed ((<112.111131> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-3.048251> *ANIMATIONNAME_amplitude)/100) speed ((<490.611639> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-0.061343> *ANIMATIONNAME_amplitude)/100) speed ((<162.456033> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<0.968246> *ANIMATIONNAME_amplitude)/100) speed ((<63.502084> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-0.411658> *ANIMATIONNAME_amplitude)/100) speed ((<185.225044> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:18
            desiredFrames = 2;
		    ANIMATIONNAME_CALC_DESIRED_FRAMES_AMPLITUDE();
			turn lfoot to x-axis ((<-40.243512> *ANIMATIONNAME_amplitude)/100) speed ((<1221.231110> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-7.440659> *ANIMATIONNAME_amplitude)/100) speed ((<67.690385> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-5.865953> *ANIMATIONNAME_amplitude)/100) speed ((<350.975516> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-6.830024> *ANIMATIONNAME_amplitude)/100) speed ((<144.890839> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<0.345820> *ANIMATIONNAME_amplitude)/100) speed ((<61.983694> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<0.304802> *ANIMATIONNAME_amplitude)/100) speed ((<31.619633> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<26.076006> *ANIMATIONNAME_amplitude)/100) speed ((<746.139360> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.157717> *ANIMATIONNAME_amplitude)/100) speed ((<63.577841> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-0.087720> *ANIMATIONNAME_amplitude)/100) speed ((<86.546071> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<18.795205> *ANIMATIONNAME_amplitude)/100) speed ((<703.304203> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<23.125820> *ANIMATIONNAME_amplitude)/100) speed ((<764.326189> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<4.131044> *ANIMATIONNAME_amplitude)/100) speed ((<10.767332> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-0.006083> *ANIMATIONNAME_amplitude)/100) speed ((<77.237453> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-15.533187> *ANIMATIONNAME_amplitude)/100) speed ((<527.656427> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-4.025448> *ANIMATIONNAME_amplitude)/100) speed ((<112.151159> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-1.012513> *ANIMATIONNAME_amplitude)/100) speed ((<51.791888> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-2.390000> *ANIMATIONNAME_amplitude)/100) speed ((<163.199994> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<3.0> *ANIMATIONNAME_amplitude)/100) speed ((<91.800016> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<39.693501> *ANIMATIONNAME_amplitude)/100) speed ((<1051.345854> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<5.049624> *ANIMATIONNAME_amplitude)/100) speed ((<532.825140> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.401872> *ANIMATIONNAME_amplitude)/100) speed ((<47.647319> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.387074> *ANIMATIONNAME_amplitude)/100) speed ((<8.439376> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-31.194563> *ANIMATIONNAME_amplitude)/100) speed ((<320.013077> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<2.029706> *ANIMATIONNAME_amplitude)/100) speed ((<15.213766> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<1.439265> *ANIMATIONNAME_amplitude)/100) speed ((<91.072985> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<13.871573> *ANIMATIONNAME_amplitude)/100) speed ((<436.733046> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-22.875507> *ANIMATIONNAME_amplitude)/100) speed ((<929.530826> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<4.381601> *ANIMATIONNAME_amplitude)/100) speed ((<64.768449> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<1.935411> *ANIMATIONNAME_amplitude)/100) speed ((<121.208802> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-11.229837> *ANIMATIONNAME_amplitude)/100) speed ((<245.447582> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-0.266262> *ANIMATIONNAME_amplitude)/100) speed ((<6.147563> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<3.633788> *ANIMATIONNAME_amplitude)/100) speed ((<79.966261> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-6.060918> *ANIMATIONNAME_amplitude)/100) speed ((<169.477809> *ANIMATIONNAME_amplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
	}
}
// Call this from StopMoving()!
STOP_ANIMNAME() {
	move pelvis to y-axis [0.0] speed [14.430001];
	turn lfoot to x-axis <2.221282> speed <636.971914>;
	turn lfoot to y-axis <18.400562> speed <363.997720>;
	turn lfoot to z-axis <0.0> speed <134.425701>;
	turn lknee to x-axis <-1.068538> speed <445.542661>;
	turn lknee to y-axis <-0.337143> speed <63.733557>;
	turn lknee to z-axis <-0.621646> speed <40.672059>;
	turn lleg to x-axis <0.407642> speed <738.614753>;
	turn lleg to y-axis <0.817311> speed <78.466755>;
	turn lleg to z-axis <-0.414435> speed <31.788921>;
	turn lloarm to x-axis <13.720556> speed <467.538799>;
	turn lthigh to x-axis <-1.250603> speed <474.879672>;
	turn lthigh to y-axis <0.326487> speed <76.971956>;
	turn lthigh to z-axis <-1.397065> speed <111.814142>;
	turn luparm to x-axis <-3.446116> speed <398.985133>;
	turn luparm to y-axis <5.803404> speed <102.238764>;
	turn luparm to z-axis <-8.504510> speed <83.154578>;
	turn pelvis to x-axis <0.0> speed <101.099999>;
	turn pelvis to y-axis <0.0> speed <45.900008>;
	turn rfoot to x-axis <1.917668> speed <643.417016>;
	turn rfoot to y-axis <-18.801757> speed <192.146661>;
	turn rfoot to z-axis <0.0> speed <134.003519>;
	turn rknee to x-axis <-2.652517> speed <443.287956>;
	turn rknee to y-axis <0.906795> speed <53.457324>;
	turn rknee to z-axis <1.368760> speed <45.019783>;
	turn rleg to x-axis <3.090169> speed <755.397732>;
	turn rleg to y-axis <-2.524473> speed <95.168303>;
	turn rleg to z-axis <0.526905> speed <44.996533>;
	turn rloarm to x-axis <11.804809> speed <431.825609>;
	turn rthigh to x-axis <-2.244671> speed <464.765413>;
	turn rthigh to y-axis <-0.996521> speed <71.490571>;
	turn rthigh to z-axis <3.528319> speed <98.292017>;
	turn ruparm to x-axis <-3.551286> speed <331.569220>;
	turn ruparm to y-axis <-5.989326> speed <95.777344>;
	turn ruparm to z-axis <9.824261> speed <186.647555>;
	turn torso to y-axis <0.0> speed <92.612522>;
}
