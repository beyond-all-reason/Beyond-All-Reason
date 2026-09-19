// These two static-var's MUST be declared in the script that includes this header.
//static-var  isMoving, maxSpeed;
// The animation function's name gets exported as ANIMATIONNAME, e.g. WALK

#ifndef ANIMATIONNAME_INIT
	#define ANIMATIONNAME_INIT()\
		maxSpeed = get (MAX_SPEED); \
		if (maxSpeed < 1) maxSpeed = 1; 
#endif


// the sane minimum speed must be kept, as we always hit it on the start of an animation.

#ifndef ANIMATIONNAME_DEFAULT_ANIM_TIME
	#define ANIMATIONNAME_DEFAULT_ANIM_TIME 33
#endif
#ifndef ANIMATIONNAME_MIN_ANIM_TIME
	#define ANIMATIONNAME_MIN_ANIM_TIME (ANIMATIONNAME_DEFAULT_ANIM_TIME/2)
#endif
#ifndef ANIMATIONNAME_MAX_ANIM_TIME
	#define ANIMATIONNAME_MAX_ANIM_TIME (ANIMATIONNAME_DEFAULT_ANIM_TIME*2)
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
            tmp = currTime; \
			currTime = desiredFrames * currTime + remainder_ms; \
			remainder_ms = currTime % 33;  \
			get PRINT (get GAME_FRAME, desiredFrames, remainder_ms, tmp); \
			desiredFrames = currTime / 33;  \
            animAmplitude = 3300/tmp;\

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

		turn lfoot to x-axis ((<-40.243512> *animAmplitude)/100) speed ((<1273.943828> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33 * desiredFrames) -1);

	} // The actual walk 
	while(isMoving){
		if (isMoving){
			desiredFrames = 2;
			VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<-40.243512> *animAmplitude)/100) speed ((<1273.943828> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			sleep ((33 * desiredFrames) -1);
		}
	}
}
    */
#define MOVESCALE 100

// There are two options going forward. Either animAmplitude is #defined by the script that includes this, OR 
// There is a mix factor that blends between amplitude and timing modulation. 
// Ideally, 
//#define animAmplitude 100

#ifndef VA_CALC_DESIRED_FRAMES
	#define VA_CALC_DESIRED_FRAMES() \
            tmp = get (CURRENT_SPEED); \
			currTime = ANIMATIONNAME_DEFAULT_ANIM_TIME * maxSpeed / (tmp + 1); \
            rawSpeed = currTime; \
			if (currTime < ANIMATIONNAME_MIN_ANIM_TIME) currTime = ANIMATIONNAME_MIN_ANIM_TIME; \
			if (currTime > ANIMATIONNAME_MAX_ANIM_TIME) currTime = ANIMATIONNAME_MAX_ANIM_TIME; \
            tmp = currTime; \
			currTime = desiredFrames * currTime + remainder_ms; \
			remainder_ms = currTime % 33;  \
			desiredFrames = currTime / 33;  \
			get PRINT (get GAME_FRAME, desiredFrames, remainder_ms, rawSpeed); \
            animAmplitude = 3300/tmp;\
            desiredFrames = 2; \

#endif

#ifndef ANIMATIONNAME_SIGNAL_MASK
	#define ANIMATIONNAME_SIGNAL_MASK SIGNAL_MOVE
#endif

ANIMNAME() {//Created by https://github.com/Beherith/Skeletor_S3O from N:\animations\corak_anim_walk_v2.blend 
	set-signal-mask ANIMATIONNAME_SIGNAL_MASK;
    var remainder_ms;
	var currTime;
	var desiredFrames;
    var tmp;
    var animAmplitude;
    var rawSpeed;
    animAmplitude = 100;

	remainder_ms = 0;
	if (isMoving) { //Frame:2
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
            desiredFrames = 4;

			turn lfoot to x-axis ((<-40.243512> *animAmplitude)/100) speed ((<1273.943828> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-7.440659> *animAmplitude)/100) speed ((<223.219252> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-5.865953> *animAmplitude)/100) speed ((<727.995439> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-6.830024> *animAmplitude)/100) speed ((<172.844587> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<0.345820> *animAmplitude)/100) speed ((<29.023982> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<0.304802> *animAmplitude)/100) speed ((<19.258346> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<26.076006> *animAmplitude)/100) speed ((<770.050910> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.157717> *animAmplitude)/100) speed ((<7.701529> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-0.087720> *animAmplitude)/100) speed ((<27.150911> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<18.795205> *animAmplitude)/100) speed ((<152.239487> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<23.125820> *animAmplitude)/100) speed ((<731.292682> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<4.131044> *animAmplitude)/100) speed ((<165.843277> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-0.006083> *animAmplitude)/100) speed ((<9.977088> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-15.533187> *animAmplitude)/100) speed ((<362.612128> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-4.025448> *animAmplitude)/100) speed ((<134.371865> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-1.012513> *animAmplitude)/100) speed ((<204.477528> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-2.390000> *animAmplitude)/100) speed ((<71.699998> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<39.611634> *animAmplitude)/100) speed ((<1130.819000> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-9.393908> *animAmplitude)/100) speed ((<282.235463> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<5.383341> *animAmplitude)/100) speed ((<241.075747> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.381296> *animAmplitude)/100) speed ((<29.623899> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.363446> *animAmplitude)/100) speed ((<38.107235> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-31.505187> *animAmplitude)/100) speed ((<1037.860666> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<3.062627> *animAmplitude)/100) speed ((<76.071680> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<3.820081> *animAmplitude)/100) speed ((<190.336606> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-0.115769> *animAmplitude)/100) speed ((<357.617331> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-22.733392> *animAmplitude)/100) speed ((<614.661624> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<2.905186> *animAmplitude)/100) speed ((<18.693993> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<2.837642> *animAmplitude)/100) speed ((<115.024912> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<6.073401> *animAmplitude)/100) speed ((<288.740629> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-2.618910> *animAmplitude)/100) speed ((<373.295110> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<0.276228> *animAmplitude)/100) speed ((<187.966625> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-6.060918> *animAmplitude)/100) speed ((<182.948716> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:4
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
            
			turn lfoot to x-axis ((<-30.657758> *animAmplitude)/100) speed ((<287.572616> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-1.578026> *animAmplitude)/100) speed ((<175.878977> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-3.384192> *animAmplitude)/100) speed ((<74.452829> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-6.365428> *animAmplitude)/100) speed ((<13.937889> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<0.627497> *animAmplitude)/100) speed ((<8.450319> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-0.125771> *animAmplitude)/100) speed ((<12.917179> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<34.419505> *animAmplitude)/100) speed ((<250.304986> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<4.133390> *animAmplitude)/100) speed ((<126.633291> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<38.934206> *animAmplitude)/100) speed ((<604.170018> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<43.405395> *animAmplitude)/100) speed ((<608.387233> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-0.157018> *animAmplitude)/100) speed ((<128.641886> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<4.913218> *animAmplitude)/100) speed ((<147.579022> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-38.188086> *animAmplitude)/100) speed ((<679.646972> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-9.569086> *animAmplitude)/100) speed ((<166.309155> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-6.279474> *animAmplitude)/100) speed ((<158.008808> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.520000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([15.599999] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-0.0> *animAmplitude)/100) speed ((<71.699998> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<24.484406> *animAmplitude)/100) speed ((<453.816842> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-0.003345> *animAmplitude)/100) speed ((<281.716910> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-25.170605> *animAmplitude)/100) speed ((<916.618362> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<1.658174> *animAmplitude)/100) speed ((<38.306322> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<2.094784> *animAmplitude)/100) speed ((<73.746915> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<12.264737> *animAmplitude)/100) speed ((<1313.097704> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.090587> *animAmplitude)/100) speed ((<94.596422> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<-1.066060> *animAmplitude)/100) speed ((<146.584218> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-4.646985> *animAmplitude)/100) speed ((<135.936497> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-39.697541> *animAmplitude)/100) speed ((<508.924481> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<2.737817> *animAmplitude)/100) speed ((<5.021079> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<5.181143> *animAmplitude)/100) speed ((<70.305026> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<14.323402> *animAmplitude)/100) speed ((<247.500020> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-3.641867> *animAmplitude)/100) speed ((<30.688723> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<-1.015437> *animAmplitude)/100) speed ((<38.749968> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-8.679222> *animAmplitude)/100) speed ((<78.549118> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:6
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<-39.010424> *animAmplitude)/100) speed ((<250.579970> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-0.002108> *animAmplitude)/100) speed ((<47.277535> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-0.006890> *animAmplitude)/100) speed ((<101.319038> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<22.853738> *animAmplitude)/100) speed ((<876.574965> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-1.186151> *animAmplitude)/100) speed ((<54.409440> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<4.123133> *animAmplitude)/100) speed ((<127.467114> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-14.821478> *animAmplitude)/100) speed ((<1477.229506> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.568119> *animAmplitude)/100) speed ((<10.721675> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-1.088983> *animAmplitude)/100) speed ((<156.671196> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<7.764953> *animAmplitude)/100) speed ((<935.077597> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<34.201735> *animAmplitude)/100) speed ((<276.109782> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-1.961119> *animAmplitude)/100) speed ((<54.123014> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<5.895231> *animAmplitude)/100) speed ((<29.460377> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-19.159760> *animAmplitude)/100) speed ((<570.849794> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-4.950884> *animAmplitude)/100) speed ((<138.546089> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-1.486378> *animAmplitude)/100) speed ((<143.792862> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.990000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([14.100001] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<6.740000> *animAmplitude)/100) speed ((<202.199998> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<2.970000> *animAmplitude)/100) speed ((<60.900003> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<37.153043> *animAmplitude)/100) speed ((<380.059097> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<8.934135> *animAmplitude)/100) speed ((<268.003689> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-12.813064> *animAmplitude)/100) speed ((<384.291590> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-9.596093> *animAmplitude)/100) speed ((<467.235346> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<-1.342735> *animAmplitude)/100) speed ((<90.027277> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<1.142380> *animAmplitude)/100) speed ((<28.572115> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-10.387000> *animAmplitude)/100) speed ((<679.552101> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.839981> *animAmplitude)/100) speed ((<22.481842> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<3.611564> *animAmplitude)/100) speed ((<140.328704> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-15.163607> *animAmplitude)/100) speed ((<315.498660> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-25.794549> *animAmplitude)/100) speed ((<417.089753> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-2.194373> *animAmplitude)/100) speed ((<147.965705> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<4.020788> *animAmplitude)/100) speed ((<34.810670> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<13.726036> *animAmplitude)/100) speed ((<17.920974> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-3.523284> *animAmplitude)/100) speed ((<3.557483> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-5.940345> *animAmplitude)/100) speed ((<82.166318> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:8
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<2.496757> *animAmplitude)/100) speed ((<1245.215437> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<23.683565> *animAmplitude)/100) speed ((<24.894810> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-0.307654> *animAmplitude)/100) speed ((<26.354925> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<1.733618> *animAmplitude)/100) speed ((<71.685440> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-41.143980> *animAmplitude)/100) speed ((<789.675070> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-1.093781> *animAmplitude)/100) speed ((<15.769877> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-4.328630> *animAmplitude)/100) speed ((<97.189416> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-0.334923> *animAmplitude)/100) speed ((<242.996259> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<8.135991> *animAmplitude)/100) speed ((<781.972333> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-2.494973> *animAmplitude)/100) speed ((<16.015626> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<2.347090> *animAmplitude)/100) speed ((<106.444227> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-2.433948> *animAmplitude)/100) speed ((<501.774362> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-0.551755> *animAmplitude)/100) speed ((<131.973857> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-0.128355> *animAmplitude)/100) speed ((<40.740708> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.028000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([28.860000] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<3.070000> *animAmplitude)/100) speed ((<110.099994> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-0.010000> *animAmplitude)/100) speed ((<89.400000> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<0.579182> *animAmplitude)/100) speed ((<1097.215835> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<9.697182> *animAmplitude)/100) speed ((<22.891422> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<-5.852873> *animAmplitude)/100) speed ((<208.805747> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-2.039017> *animAmplitude)/100) speed ((<226.712269> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<-2.372498> *animAmplitude)/100) speed ((<30.892883> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<0.697846> *animAmplitude)/100) speed ((<13.336030> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<1.418999> *animAmplitude)/100) speed ((<354.179965> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-1.985140> *animAmplitude)/100) speed ((<34.354772> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<3.043927> *animAmplitude)/100) speed ((<17.029096> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-3.987276> *animAmplitude)/100) speed ((<335.289948> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-2.410771> *animAmplitude)/100) speed ((<701.513340> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-4.519230> *animAmplitude)/100) speed ((<69.745691> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<2.522605> *animAmplitude)/100) speed ((<44.945490> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<1.362851> *animAmplitude)/100) speed ((<370.895552> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-0.497283> *animAmplitude)/100) speed ((<90.780029> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<-0.026282> *animAmplitude)/100) speed ((<31.278638> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<0.085185> *animAmplitude)/100) speed ((<180.765899> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:10
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<38.743818> *animAmplitude)/100) speed ((<1087.411814> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<6.114390> *animAmplitude)/100) speed ((<527.075257> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-1.151940> *animAmplitude)/100) speed ((<25.328603> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<0.462818> *animAmplitude)/100) speed ((<38.124001> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-32.212361> *animAmplitude)/100) speed ((<267.948594> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-1.218581> *animAmplitude)/100) speed ((<3.743992> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-1.139046> *animAmplitude)/100) speed ((<95.687518> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<11.429264> *animAmplitude)/100) speed ((<352.925592> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-23.522654> *animAmplitude)/100) speed ((<949.759345> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-4.561886> *animAmplitude)/100) speed ((<62.007396> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-1.962713> *animAmplitude)/100) speed ((<129.294085> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-11.546510> *animAmplitude)/100) speed ((<273.376866> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<0.020005> *animAmplitude)/100) speed ((<17.152801> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-2.829427> *animAmplitude)/100) speed ((<81.032159> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.295000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([8.010001] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-2.090000> *animAmplitude)/100) speed ((<154.800001> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-3.020000> *animAmplitude)/100) speed ((<90.299997> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<-42.315286> *animAmplitude)/100) speed ((<1286.834032> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<7.682254> *animAmplitude)/100) speed ((<60.447840> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<6.232020> *animAmplitude)/100) speed ((<362.546770> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<-5.922912> *animAmplitude)/100) speed ((<116.516840> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.237168> *animAmplitude)/100) speed ((<78.289998> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.176416> *animAmplitude)/100) speed ((<26.227860> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<24.980239> *animAmplitude)/100) speed ((<706.837193> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.548087> *animAmplitude)/100) speed ((<43.111597> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<0.357049> *animAmplitude)/100) speed ((<80.606348> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<13.709837> *animAmplitude)/100) speed ((<530.913396> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<23.022121> *animAmplitude)/100) speed ((<762.986759> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-4.234439> *animAmplitude)/100) speed ((<8.543721> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<0.031378> *animAmplitude)/100) speed ((<74.736792> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-14.629546> *animAmplitude)/100) speed ((<479.771920> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<4.218827> *animAmplitude)/100) speed ((<141.483307> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<1.933472> *animAmplitude)/100) speed ((<58.792617> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<6.110734> *animAmplitude)/100) speed ((<180.766460> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:12
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<25.040025> *animAmplitude)/100) speed ((<411.113782> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-25.275077> *animAmplitude)/100) speed ((<941.684012> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<-1.282850> *animAmplitude)/100) speed ((<3.927293> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-2.896653> *animAmplitude)/100) speed ((<100.784134> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<11.758685> *animAmplitude)/100) speed ((<1319.131382> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.728330> *animAmplitude)/100) speed ((<14.707537> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<1.978969> *animAmplitude)/100) speed ((<93.540465> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-5.147298> *animAmplitude)/100) speed ((<497.296866> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-39.148165> *animAmplitude)/100) speed ((<468.765325> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<-2.765572> *animAmplitude)/100) speed ((<53.889431> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-5.165048> *animAmplitude)/100) speed ((<96.070032> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<15.052499> *animAmplitude)/100) speed ((<797.970266> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<2.670525> *animAmplitude)/100) speed ((<79.515585> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<0.899942> *animAmplitude)/100) speed ((<111.881066> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.510000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([6.449999] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-0.020000> *animAmplitude)/100) speed ((<62.100001> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-5.360000> *animAmplitude)/100) speed ((<70.200006> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<-30.524095> *animAmplitude)/100) speed ((<353.735736> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<1.575841> *animAmplitude)/100) speed ((<183.192403> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<3.379851> *animAmplitude)/100) speed ((<85.565069> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.124295> *animAmplitude)/100) speed ((<3.386209> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<0.562551> *animAmplitude)/100) speed ((<22.169016> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<34.785873> *animAmplitude)/100) speed ((<294.169042> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<-0.766034> *animAmplitude)/100) speed ((<6.538402> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<-4.202078> *animAmplitude)/100) speed ((<136.773819> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<36.269674> *animAmplitude)/100) speed ((<676.795095> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<42.784230> *animAmplitude)/100) speed ((<592.863272> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<-0.065047> *animAmplitude)/100) speed ((<125.081756> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<-4.734660> *animAmplitude)/100) speed ((<142.981142> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-36.734161> *animAmplitude)/100) speed ((<663.138439> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<10.583475> *animAmplitude)/100) speed ((<190.939458> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<8.318628> *animAmplitude)/100) speed ((<191.554687> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<8.849594> *animAmplitude)/100) speed ((<82.165818> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:14
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<37.387998> *animAmplitude)/100) speed ((<370.439186> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-8.962304> *animAmplitude)/100) speed ((<268.846559> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<12.859584> *animAmplitude)/100) speed ((<385.678150> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-9.441686> *animAmplitude)/100) speed ((<475.001758> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<1.271139> *animAmplitude)/100) speed ((<76.619681> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-1.407645> *animAmplitude)/100) speed ((<44.670228> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<-10.324155> *animAmplitude)/100) speed ((<662.485225> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<0.960237> *animAmplitude)/100) speed ((<50.657005> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-3.255075> *animAmplitude)/100) speed ((<157.021326> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-15.936846> *animAmplitude)/100) speed ((<323.686434> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-25.377240> *animAmplitude)/100) speed ((<413.127749> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<2.240162> *animAmplitude)/100) speed ((<150.172014> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-4.056589> *animAmplitude)/100) speed ((<33.253758> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<13.964900> *animAmplitude)/100) speed ((<32.627976> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<2.304844> *animAmplitude)/100) speed ((<10.970419> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<1.097682> *animAmplitude)/100) speed ((<5.932195> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-1.027000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([15.509999] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<6.120000> *animAmplitude)/100) speed ((<184.199989> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-3.020000> *animAmplitude)/100) speed ((<70.199999> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<-37.669118> *animAmplitude)/100) speed ((<214.350700> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to z-axis ((<0.002079> *animAmplitude)/100) speed ((<47.212867> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to y-axis ((<0.006794> *animAmplitude)/100) speed ((<101.191700> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<22.375748> *animAmplitude)/100) speed ((<849.199349> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-3.001270> *animAmplitude)/100) speed ((<106.914647> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-15.573975> *animAmplitude)/100) speed ((<1510.795463> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<1.078429> *animAmplitude)/100) speed ((<55.333897> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<0.621153> *animAmplitude)/100) speed ((<144.696955> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<7.481300> *animAmplitude)/100) speed ((<863.651218> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<35.130125> *animAmplitude)/100) speed ((<229.623139> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<1.654511> *animAmplitude)/100) speed ((<51.586739> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<-5.841921> *animAmplitude)/100) speed ((<33.217822> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-19.401972> *animAmplitude)/100) speed ((<519.965670> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<5.353858> *animAmplitude)/100) speed ((<156.888527> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<3.084982> *animAmplitude)/100) speed ((<157.009377> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<5.762510> *animAmplitude)/100) speed ((<92.612524> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:16
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<0.464192> *animAmplitude)/100) speed ((<1107.714192> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-9.697005> *animAmplitude)/100) speed ((<22.041012> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<5.833231> *animAmplitude)/100) speed ((<210.790579> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-2.0> *animAmplitude)/100) speed ((<223.240686> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<2.411943> *animAmplitude)/100) speed ((<34.224105> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<-0.749186> *animAmplitude)/100) speed ((<19.753780> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<1.204694> *animAmplitude)/100) speed ((<345.865479> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<1.961544> *animAmplitude)/100) speed ((<30.039223> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-2.972589> *animAmplitude)/100) speed ((<8.474591> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<-4.648268> *animAmplitude)/100) speed ((<338.657342> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<-2.351720> *animAmplitude)/100) speed ((<690.765615> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<4.489955> *animAmplitude)/100) speed ((<67.493810> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-2.580664> *animAmplitude)/100) speed ((<44.277734> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<2.055360> *animAmplitude)/100) speed ((<357.286182> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-0.287076> *animAmplitude)/100) speed ((<77.757598> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<0.713883> *animAmplitude)/100) speed ((<11.513976> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			move pelvis to y-axis ((([-0.065000] *MOVESCALE)/100) *animAmplitude)/100 speed ((([28.860001] *MOVESCALE)/100) *animAmplitude)/100 / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<3.050000> *animAmplitude)/100) speed ((<92.099998> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<-0.060000> *animAmplitude)/100) speed ((<88.799998> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<4.648639> *animAmplitude)/100) speed ((<1269.532721> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<22.810462> *animAmplitude)/100) speed ((<13.041427> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<-1.186372> *animAmplitude)/100) speed ((<40.379282> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.668387> *animAmplitude)/100) speed ((<69.986508> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-41.861666> *animAmplitude)/100) speed ((<788.630717> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<2.536832> *animAmplitude)/100) speed ((<43.752081> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<4.475032> *animAmplitude)/100) speed ((<115.616342> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<-0.686195> *animAmplitude)/100) speed ((<245.024858> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<8.108854> *animAmplitude)/100) speed ((<810.638150> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<2.222653> *animAmplitude)/100) speed ((<17.044253> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<-2.104883> *animAmplitude)/100) speed ((<112.111131> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-3.048251> *animAmplitude)/100) speed ((<490.611639> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-0.061343> *animAmplitude)/100) speed ((<162.456033> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<0.968246> *animAmplitude)/100) speed ((<63.502084> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-0.411658> *animAmplitude)/100) speed ((<185.225044> *animAmplitude)/100) / desiredFrames; //delta=%.2f
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:18
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis ((<-40.243512> *animAmplitude)/100) speed ((<1221.231110> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to z-axis ((<-7.440659> *animAmplitude)/100) speed ((<67.690385> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lfoot to y-axis ((<-5.865953> *animAmplitude)/100) speed ((<350.975516> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to x-axis ((<-6.830024> *animAmplitude)/100) speed ((<144.890839> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to z-axis ((<0.345820> *animAmplitude)/100) speed ((<61.983694> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lknee to y-axis ((<0.304802> *animAmplitude)/100) speed ((<31.619633> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to x-axis ((<26.076006> *animAmplitude)/100) speed ((<746.139360> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to z-axis ((<-0.157717> *animAmplitude)/100) speed ((<63.577841> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lleg to y-axis ((<-0.087720> *animAmplitude)/100) speed ((<86.546071> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lloarm to x-axis ((<18.795205> *animAmplitude)/100) speed ((<703.304203> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to x-axis ((<23.125820> *animAmplitude)/100) speed ((<764.326189> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to z-axis ((<4.131044> *animAmplitude)/100) speed ((<10.767332> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn lthigh to y-axis ((<-0.006083> *animAmplitude)/100) speed ((<77.237453> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to x-axis ((<-15.533187> *animAmplitude)/100) speed ((<527.656427> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to z-axis ((<-4.025448> *animAmplitude)/100) speed ((<112.151159> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn luparm to y-axis ((<-1.012513> *animAmplitude)/100) speed ((<51.791888> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to x-axis ((<-2.390000> *animAmplitude)/100) speed ((<163.199994> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn pelvis to y-axis ((<3.0> *animAmplitude)/100) speed ((<91.800016> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rfoot to x-axis ((<39.693501> *animAmplitude)/100) speed ((<1051.345854> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to x-axis ((<5.049624> *animAmplitude)/100) speed ((<532.825140> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to z-axis ((<0.401872> *animAmplitude)/100) speed ((<47.647319> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rknee to y-axis ((<-0.387074> *animAmplitude)/100) speed ((<8.439376> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to x-axis ((<-31.194563> *animAmplitude)/100) speed ((<320.013077> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to z-axis ((<2.029706> *animAmplitude)/100) speed ((<15.213766> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rleg to y-axis ((<1.439265> *animAmplitude)/100) speed ((<91.072985> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rloarm to x-axis ((<13.871573> *animAmplitude)/100) speed ((<436.733046> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to x-axis ((<-22.875507> *animAmplitude)/100) speed ((<929.530826> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to z-axis ((<4.381601> *animAmplitude)/100) speed ((<64.768449> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn rthigh to y-axis ((<1.935411> *animAmplitude)/100) speed ((<121.208802> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to x-axis ((<-11.229837> *animAmplitude)/100) speed ((<245.447582> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to z-axis ((<-0.266262> *animAmplitude)/100) speed ((<6.147563> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn ruparm to y-axis ((<3.633788> *animAmplitude)/100) speed ((<79.966261> *animAmplitude)/100) / desiredFrames; //delta=%.2f
			turn torso to y-axis ((<-6.060918> *animAmplitude)/100) speed ((<169.477809> *animAmplitude)/100) / desiredFrames; //delta=%.2f
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
