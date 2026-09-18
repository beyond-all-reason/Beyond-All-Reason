
// Signal definitions
//static-var  isMoving, maxSpeed;

// Lets think in ms all the way
// --------------------------------------------- VA ---------------------------------------------------
// What surely needs to defined within an exported anim?


//static-var maxSpeed;//, remainder_ms; // remainder is in milliseconds, and should never be touched outside of the VA_CALC function 

#ifndef VA_INIT
	#define VA_INIT()\
		maxSpeed = get (MAX_SPEED); \
		if (maxSpeed < 1) maxSpeed = 1; 
#endif
//VA_init(){
//	maxSpeed = get (MAX_SPEED);
//	if (maxSpeed < 1) maxSpeed = 1; 
//}

// the sane minimum speed must be kept, as we always hit it on the start of an animation.

#ifndef VA_DEFAULT_ANIM_TIME
	#define VA_DEFAULT_ANIM_TIME 33
#endif
#ifndef VA_MIN_ANIM_TIME
	#define VA_MIN_ANIM_TIME (VA_DEFAULT_ANIM_TIME/2)
#endif
#ifndef VA_MAX_ANIM_TIME
	#define VA_MAX_ANIM_TIME (VA_DEFAULT_ANIM_TIME*2)
#endif

/*
VA_CALC(desiredFrames, remainder_ms){ // we can abuse the stack of Walk for
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
*/

#ifndef VA_CALC_DESIRED_FRAMES
	#define VA_CALC_DESIRED_FRAMES() \
			currTime = VA_DEFAULT_ANIM_TIME * maxSpeed / (get (CURRENT_SPEED) + 1); \
			if (currTime < VA_MIN_ANIM_TIME) currTime = VA_MIN_ANIM_TIME; \
			if (currTime > VA_MAX_ANIM_TIME) currTime = VA_MAX_ANIM_TIME; \
            tmp = currTime; \
			currTime = desiredFrames * currTime + remainder_ms; \
			desiredFrames = currTime / 33;  \
			remainder_ms = currTime % 33;  \
			get PRINT (get GAME_FRAME, desiredFrames, remainder_ms, tmp);
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

		turn lfoot to x-axis <-40.243512> speed <1273.943828> / desiredFrames; //delta=42.46 
		sleep ((33 * desiredFrames) -1);

	} // The actual walk 
	while(isMoving){
		if (isMoving){
			desiredFrames = 2;
			VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <-40.243512> speed <1273.943828> / desiredFrames; //delta=42.46 
			sleep ((33 * desiredFrames) -1);
		}
	}
}
    */


Walk() {//Created by https://github.com/Beherith/Skeletor_S3O from N:\animations\corak_anim_walk_v2.blend 
	set-signal-mask SIGNAL_MOVE;
    var remainder_ms;
	var currTime;
	var desiredFrames;
    var tmp;

	remainder_ms = 0;
	if (isMoving) { //Frame:2
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();


			turn lfoot to x-axis <-40.243512> speed <1273.943828> / desiredFrames; //delta=42.46 
			turn lfoot to z-axis <-7.440659> speed <223.219252> / desiredFrames; //delta=7.44 
			turn lfoot to y-axis <-5.865953> speed <727.995439> / desiredFrames; //delta=-24.27 
			turn lknee to x-axis <-6.830024> speed <172.844587> / desiredFrames; //delta=5.76 
			turn lknee to z-axis <0.345820> speed <29.023982> / desiredFrames; //delta=-0.97 
			turn lknee to y-axis <0.304802> speed <19.258346> / desiredFrames; //delta=0.64 
			turn lleg to x-axis <26.076006> speed <770.050910> / desiredFrames; //delta=-25.67 
			turn lleg to z-axis <-0.157717> speed <7.701529> / desiredFrames; //delta=-0.26 
			turn lleg to y-axis <-0.087720> speed <27.150911> / desiredFrames; //delta=-0.91 
			turn lloarm to x-axis <18.795205> speed <152.239487> / desiredFrames; //delta=-5.07 
			turn lthigh to x-axis <23.125820> speed <731.292682> / desiredFrames; //delta=-24.38 
			turn lthigh to z-axis <4.131044> speed <165.843277> / desiredFrames; //delta=-5.53 
			turn lthigh to y-axis <-0.006083> speed <9.977088> / desiredFrames; //delta=-0.33 
			turn luparm to x-axis <-15.533187> speed <362.612128> / desiredFrames; //delta=12.09 
			turn luparm to z-axis <-4.025448> speed <134.371865> / desiredFrames; //delta=-4.48 
			turn luparm to y-axis <-1.012513> speed <204.477528> / desiredFrames; //delta=-6.82 
			turn pelvis to x-axis <-2.390000> speed <71.699998> / desiredFrames; //delta=2.39 
			turn pelvis to y-axis <3.0> speed <90.0> / desiredFrames; //delta=3.00 
			turn rfoot to x-axis <39.611634> speed <1130.819000> / desiredFrames; //delta=-37.69 
			turn rfoot to y-axis <-9.393908> speed <282.235463> / desiredFrames; //delta=9.41 
			turn rknee to x-axis <5.383341> speed <241.075747> / desiredFrames; //delta=-8.04 
			turn rknee to z-axis <0.381296> speed <29.623899> / desiredFrames; //delta=0.99 
			turn rknee to y-axis <-0.363446> speed <38.107235> / desiredFrames; //delta=-1.27 
			turn rleg to x-axis <-31.505187> speed <1037.860666> / desiredFrames; //delta=34.60 
			turn rleg to z-axis <3.062627> speed <76.071680> / desiredFrames; //delta=-2.54 
			turn rleg to y-axis <3.820081> speed <190.336606> / desiredFrames; //delta=6.34 
			turn rloarm to x-axis <-0.115769> speed <357.617331> / desiredFrames; //delta=11.92 
			turn rthigh to x-axis <-22.733392> speed <614.661624> / desiredFrames; //delta=20.49 
			turn rthigh to z-axis <2.905186> speed <18.693993> / desiredFrames; //delta=0.62 
			turn rthigh to y-axis <2.837642> speed <115.024912> / desiredFrames; //delta=3.83 
			turn ruparm to x-axis <6.073401> speed <288.740629> / desiredFrames; //delta=-9.62 
			turn ruparm to z-axis <-2.618910> speed <373.295110> / desiredFrames; //delta=12.44 
			turn ruparm to y-axis <0.276228> speed <187.966625> / desiredFrames; //delta=6.27 
			turn torso to y-axis <-6.060918> speed <182.948716> / desiredFrames; //delta=-6.10 
		sleep ((33*desiredFrames) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:4
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
            
			turn lfoot to x-axis <-30.657758> speed <287.572616> / desiredFrames; //delta=-9.59 
			turn lfoot to z-axis <-1.578026> speed <175.878977> / desiredFrames; //delta=-5.86 
			turn lfoot to y-axis <-3.384192> speed <74.452829> / desiredFrames; //delta=2.48 
			turn lknee to x-axis <-6.365428> speed <13.937889> / desiredFrames; //delta=-0.46 
			turn lknee to z-axis <0.627497> speed <8.450319> / desiredFrames; //delta=-0.28 
			turn lknee to y-axis <-0.125771> speed <12.917179> / desiredFrames; //delta=-0.43 
			turn lleg to x-axis <34.419505> speed <250.304986> / desiredFrames; //delta=-8.34 
			turn lleg to y-axis <4.133390> speed <126.633291> / desiredFrames; //delta=4.22 
			turn lloarm to x-axis <38.934206> speed <604.170018> / desiredFrames; //delta=-20.14 
			turn lthigh to x-axis <43.405395> speed <608.387233> / desiredFrames; //delta=-20.28 
			turn lthigh to z-axis <-0.157018> speed <128.641886> / desiredFrames; //delta=4.29 
			turn lthigh to y-axis <4.913218> speed <147.579022> / desiredFrames; //delta=4.92 
			turn luparm to x-axis <-38.188086> speed <679.646972> / desiredFrames; //delta=22.65 
			turn luparm to z-axis <-9.569086> speed <166.309155> / desiredFrames; //delta=5.54 
			turn luparm to y-axis <-6.279474> speed <158.008808> / desiredFrames; //delta=-5.27 
			move pelvis to y-axis [-0.520000] speed [15.599999] / desiredFrames; //delta=-0.52 
			turn pelvis to x-axis <-0.0> speed <71.699998> / desiredFrames; //delta=-2.39 
			turn pelvis to y-axis <5.0> speed <59.999993> / desiredFrames; //delta=2.00 
			turn rfoot to x-axis <24.484406> speed <453.816842> / desiredFrames; //delta=15.13 
			turn rfoot to y-axis <-0.003345> speed <281.716910> / desiredFrames; //delta=9.39 
			turn rknee to x-axis <-25.170605> speed <916.618362> / desiredFrames; //delta=30.55 
			turn rknee to z-axis <1.658174> speed <38.306322> / desiredFrames; //delta=-1.28 
			turn rknee to y-axis <2.094784> speed <73.746915> / desiredFrames; //delta=2.46 
			turn rleg to x-axis <12.264737> speed <1313.097704> / desiredFrames; //delta=-43.77 
			turn rleg to z-axis <-0.090587> speed <94.596422> / desiredFrames; //delta=3.15 
			turn rleg to y-axis <-1.066060> speed <146.584218> / desiredFrames; //delta=-4.89 
			turn rloarm to x-axis <-4.646985> speed <135.936497> / desiredFrames; //delta=4.53 
			turn rthigh to x-axis <-39.697541> speed <508.924481> / desiredFrames; //delta=16.96 
			turn rthigh to z-axis <2.737817> speed <5.021079> / desiredFrames; //delta=0.17 
			turn rthigh to y-axis <5.181143> speed <70.305026> / desiredFrames; //delta=2.34 
			turn ruparm to x-axis <14.323402> speed <247.500020> / desiredFrames; //delta=-8.25 
			turn ruparm to z-axis <-3.641867> speed <30.688723> / desiredFrames; //delta=1.02 
			turn ruparm to y-axis <-1.015437> speed <38.749968> / desiredFrames; //delta=-1.29 
			turn torso to y-axis <-8.679222> speed <78.549118> / desiredFrames; //delta=-2.62 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:6
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <-39.010424> speed <250.579970> / desiredFrames; //delta=8.35 
			turn lfoot to z-axis <-0.002108> speed <47.277535> / desiredFrames; //delta=-1.58 
			turn lfoot to y-axis <-0.006890> speed <101.319038> / desiredFrames; //delta=3.38 
			turn lknee to x-axis <22.853738> speed <876.574965> / desiredFrames; //delta=-29.22 
			turn lknee to z-axis <-1.186151> speed <54.409440> / desiredFrames; //delta=1.81 
			turn lknee to y-axis <4.123133> speed <127.467114> / desiredFrames; //delta=4.25 
			turn lleg to x-axis <-14.821478> speed <1477.229506> / desiredFrames; //delta=49.24 
			turn lleg to z-axis <-0.568119> speed <10.721675> / desiredFrames; //delta=0.36 
			turn lleg to y-axis <-1.088983> speed <156.671196> / desiredFrames; //delta=-5.22 
			turn lloarm to x-axis <7.764953> speed <935.077597> / desiredFrames; //delta=31.17 
			turn lthigh to x-axis <34.201735> speed <276.109782> / desiredFrames; //delta=9.20 
			turn lthigh to z-axis <-1.961119> speed <54.123014> / desiredFrames; //delta=1.80 
			turn lthigh to y-axis <5.895231> speed <29.460377> / desiredFrames; //delta=0.98 
			turn luparm to x-axis <-19.159760> speed <570.849794> / desiredFrames; //delta=-19.03 
			turn luparm to z-axis <-4.950884> speed <138.546089> / desiredFrames; //delta=-4.62 
			turn luparm to y-axis <-1.486378> speed <143.792862> / desiredFrames; //delta=4.79 
			move pelvis to y-axis [-0.990000] speed [14.100001] / desiredFrames; //delta=-0.47 
			turn pelvis to x-axis <6.740000> speed <202.199998> / desiredFrames; //delta=-6.74 
			turn pelvis to y-axis <2.970000> speed <60.900003> / desiredFrames; //delta=-2.03 
			turn rfoot to x-axis <37.153043> speed <380.059097> / desiredFrames; //delta=-12.67 
			turn rfoot to z-axis <8.934135> speed <268.003689> / desiredFrames; //delta=-8.93 
			turn rfoot to y-axis <-12.813064> speed <384.291590> / desiredFrames; //delta=-12.81 
			turn rknee to x-axis <-9.596093> speed <467.235346> / desiredFrames; //delta=-15.57 
			turn rknee to z-axis <-1.342735> speed <90.027277> / desiredFrames; //delta=3.00 
			turn rknee to y-axis <1.142380> speed <28.572115> / desiredFrames; //delta=-0.95 
			turn rleg to x-axis <-10.387000> speed <679.552101> / desiredFrames; //delta=22.65 
			turn rleg to z-axis <-0.839981> speed <22.481842> / desiredFrames; //delta=0.75 
			turn rleg to y-axis <3.611564> speed <140.328704> / desiredFrames; //delta=4.68 
			turn rloarm to x-axis <-15.163607> speed <315.498660> / desiredFrames; //delta=10.52 
			turn rthigh to x-axis <-25.794549> speed <417.089753> / desiredFrames; //delta=-13.90 
			turn rthigh to z-axis <-2.194373> speed <147.965705> / desiredFrames; //delta=4.93 
			turn rthigh to y-axis <4.020788> speed <34.810670> / desiredFrames; //delta=-1.16 
			turn ruparm to x-axis <13.726036> speed <17.920974> / desiredFrames; //delta=0.60 
			turn ruparm to z-axis <-3.523284> speed <3.557483> / desiredFrames; //delta=-0.12 
			turn torso to y-axis <-5.940345> speed <82.166318> / desiredFrames; //delta=2.74 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:8
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <2.496757> speed <1245.215437> / desiredFrames; //delta=-41.51 
			turn lknee to x-axis <23.683565> speed <24.894810> / desiredFrames; //delta=-0.83 
			turn lknee to z-axis <-0.307654> speed <26.354925> / desiredFrames; //delta=-0.88 
			turn lknee to y-axis <1.733618> speed <71.685440> / desiredFrames; //delta=-2.39 
			turn lleg to x-axis <-41.143980> speed <789.675070> / desiredFrames; //delta=26.32 
			turn lleg to z-axis <-1.093781> speed <15.769877> / desiredFrames; //delta=0.53 
			turn lleg to y-axis <-4.328630> speed <97.189416> / desiredFrames; //delta=-3.24 
			turn lloarm to x-axis <-0.334923> speed <242.996259> / desiredFrames; //delta=8.10 
			turn lthigh to x-axis <8.135991> speed <781.972333> / desiredFrames; //delta=26.07 
			turn lthigh to z-axis <-2.494973> speed <16.015626> / desiredFrames; //delta=0.53 
			turn lthigh to y-axis <2.347090> speed <106.444227> / desiredFrames; //delta=-3.55 
			turn luparm to x-axis <-2.433948> speed <501.774362> / desiredFrames; //delta=-16.73 
			turn luparm to z-axis <-0.551755> speed <131.973857> / desiredFrames; //delta=-4.40 
			turn luparm to y-axis <-0.128355> speed <40.740708> / desiredFrames; //delta=1.36 
			move pelvis to y-axis [-0.028000] speed [28.860000] / desiredFrames; //delta=0.96 
			turn pelvis to x-axis <3.070000> speed <110.099994> / desiredFrames; //delta=3.67 
			turn pelvis to y-axis <-0.010000> speed <89.400000> / desiredFrames; //delta=-2.98 
			turn rfoot to x-axis <0.579182> speed <1097.215835> / desiredFrames; //delta=36.57 
			turn rfoot to z-axis <9.697182> speed <22.891422> / desiredFrames; //delta=-0.76 
			turn rfoot to y-axis <-5.852873> speed <208.805747> / desiredFrames; //delta=6.96 
			turn rknee to x-axis <-2.039017> speed <226.712269> / desiredFrames; //delta=-7.56 
			turn rknee to z-axis <-2.372498> speed <30.892883> / desiredFrames; //delta=1.03 
			turn rknee to y-axis <0.697846> speed <13.336030> / desiredFrames; //delta=-0.44 
			turn rleg to x-axis <1.418999> speed <354.179965> / desiredFrames; //delta=-11.81 
			turn rleg to z-axis <-1.985140> speed <34.354772> / desiredFrames; //delta=1.15 
			turn rleg to y-axis <3.043927> speed <17.029096> / desiredFrames; //delta=-0.57 
			turn rloarm to x-axis <-3.987276> speed <335.289948> / desiredFrames; //delta=-11.18 
			turn rthigh to x-axis <-2.410771> speed <701.513340> / desiredFrames; //delta=-23.38 
			turn rthigh to z-axis <-4.519230> speed <69.745691> / desiredFrames; //delta=2.32 
			turn rthigh to y-axis <2.522605> speed <44.945490> / desiredFrames; //delta=-1.50 
			turn ruparm to x-axis <1.362851> speed <370.895552> / desiredFrames; //delta=12.36 
			turn ruparm to z-axis <-0.497283> speed <90.780029> / desiredFrames; //delta=-3.03 
			turn ruparm to y-axis <-0.026282> speed <31.278638> / desiredFrames; //delta=1.04 
			turn torso to y-axis <0.085185> speed <180.765899> / desiredFrames; //delta=6.03 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:10
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <38.743818> speed <1087.411814> / desiredFrames; //delta=-36.25 
			turn lknee to x-axis <6.114390> speed <527.075257> / desiredFrames; //delta=17.57 
			turn lknee to z-axis <-1.151940> speed <25.328603> / desiredFrames; //delta=0.84 
			turn lknee to y-axis <0.462818> speed <38.124001> / desiredFrames; //delta=-1.27 
			turn lleg to x-axis <-32.212361> speed <267.948594> / desiredFrames; //delta=-8.93 
			turn lleg to z-axis <-1.218581> speed <3.743992> / desiredFrames; //delta=0.12 
			turn lleg to y-axis <-1.139046> speed <95.687518> / desiredFrames; //delta=3.19 
			turn lloarm to x-axis <11.429264> speed <352.925592> / desiredFrames; //delta=-11.76 
			turn lthigh to x-axis <-23.522654> speed <949.759345> / desiredFrames; //delta=31.66 
			turn lthigh to z-axis <-4.561886> speed <62.007396> / desiredFrames; //delta=2.07 
			turn lthigh to y-axis <-1.962713> speed <129.294085> / desiredFrames; //delta=-4.31 
			turn luparm to x-axis <-11.546510> speed <273.376866> / desiredFrames; //delta=9.11 
			turn luparm to z-axis <0.020005> speed <17.152801> / desiredFrames; //delta=-0.57 
			turn luparm to y-axis <-2.829427> speed <81.032159> / desiredFrames; //delta=-2.70 
			move pelvis to y-axis [-0.295000] speed [8.010001] / desiredFrames; //delta=-0.27 
			turn pelvis to x-axis <-2.090000> speed <154.800001> / desiredFrames; //delta=5.16 
			turn pelvis to y-axis <-3.020000> speed <90.299997> / desiredFrames; //delta=-3.01 
			turn rfoot to x-axis <-42.315286> speed <1286.834032> / desiredFrames; //delta=42.89 
			turn rfoot to z-axis <7.682254> speed <60.447840> / desiredFrames; //delta=2.01 
			turn rfoot to y-axis <6.232020> speed <362.546770> / desiredFrames; //delta=12.08 
			turn rknee to x-axis <-5.922912> speed <116.516840> / desiredFrames; //delta=3.88 
			turn rknee to z-axis <0.237168> speed <78.289998> / desiredFrames; //delta=-2.61 
			turn rknee to y-axis <-0.176416> speed <26.227860> / desiredFrames; //delta=-0.87 
			turn rleg to x-axis <24.980239> speed <706.837193> / desiredFrames; //delta=-23.56 
			turn rleg to z-axis <-0.548087> speed <43.111597> / desiredFrames; //delta=-1.44 
			turn rleg to y-axis <0.357049> speed <80.606348> / desiredFrames; //delta=-2.69 
			turn rloarm to x-axis <13.709837> speed <530.913396> / desiredFrames; //delta=-17.70 
			turn rthigh to x-axis <23.022121> speed <762.986759> / desiredFrames; //delta=-25.43 
			turn rthigh to z-axis <-4.234439> speed <8.543721> / desiredFrames; //delta=-0.28 
			turn rthigh to y-axis <0.031378> speed <74.736792> / desiredFrames; //delta=-2.49 
			turn ruparm to x-axis <-14.629546> speed <479.771920> / desiredFrames; //delta=15.99 
			turn ruparm to z-axis <4.218827> speed <141.483307> / desiredFrames; //delta=-4.72 
			turn ruparm to y-axis <1.933472> speed <58.792617> / desiredFrames; //delta=1.96 
			turn torso to y-axis <6.110734> speed <180.766460> / desiredFrames; //delta=6.03 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:12
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <25.040025> speed <411.113782> / desiredFrames; //delta=13.70 
			turn lknee to x-axis <-25.275077> speed <941.684012> / desiredFrames; //delta=31.39 
			turn lknee to z-axis <-1.282850> speed <3.927293> / desiredFrames; //delta=0.13 
			turn lknee to y-axis <-2.896653> speed <100.784134> / desiredFrames; //delta=-3.36 
			turn lleg to x-axis <11.758685> speed <1319.131382> / desiredFrames; //delta=-43.97 
			turn lleg to z-axis <-0.728330> speed <14.707537> / desiredFrames; //delta=-0.49 
			turn lleg to y-axis <1.978969> speed <93.540465> / desiredFrames; //delta=3.12 
			turn lloarm to x-axis <-5.147298> speed <497.296866> / desiredFrames; //delta=16.58 
			turn lthigh to x-axis <-39.148165> speed <468.765325> / desiredFrames; //delta=15.63 
			turn lthigh to z-axis <-2.765572> speed <53.889431> / desiredFrames; //delta=-1.80 
			turn lthigh to y-axis <-5.165048> speed <96.070032> / desiredFrames; //delta=-3.20 
			turn luparm to x-axis <15.052499> speed <797.970266> / desiredFrames; //delta=-26.60 
			turn luparm to z-axis <2.670525> speed <79.515585> / desiredFrames; //delta=-2.65 
			turn luparm to y-axis <0.899942> speed <111.881066> / desiredFrames; //delta=3.73 
			move pelvis to y-axis [-0.510000] speed [6.449999] / desiredFrames; //delta=-0.21 
			turn pelvis to x-axis <-0.020000> speed <62.100001> / desiredFrames; //delta=-2.07 
			turn pelvis to y-axis <-5.360000> speed <70.200006> / desiredFrames; //delta=-2.34 
			turn rfoot to x-axis <-30.524095> speed <353.735736> / desiredFrames; //delta=-11.79 
			turn rfoot to z-axis <1.575841> speed <183.192403> / desiredFrames; //delta=6.11 
			turn rfoot to y-axis <3.379851> speed <85.565069> / desiredFrames; //delta=-2.85 
			turn rknee to z-axis <0.124295> speed <3.386209> / desiredFrames; //delta=0.11 
			turn rknee to y-axis <0.562551> speed <22.169016> / desiredFrames; //delta=0.74 
			turn rleg to x-axis <34.785873> speed <294.169042> / desiredFrames; //delta=-9.81 
			turn rleg to z-axis <-0.766034> speed <6.538402> / desiredFrames; //delta=0.22 
			turn rleg to y-axis <-4.202078> speed <136.773819> / desiredFrames; //delta=-4.56 
			turn rloarm to x-axis <36.269674> speed <676.795095> / desiredFrames; //delta=-22.56 
			turn rthigh to x-axis <42.784230> speed <592.863272> / desiredFrames; //delta=-19.76 
			turn rthigh to z-axis <-0.065047> speed <125.081756> / desiredFrames; //delta=-4.17 
			turn rthigh to y-axis <-4.734660> speed <142.981142> / desiredFrames; //delta=-4.77 
			turn ruparm to x-axis <-36.734161> speed <663.138439> / desiredFrames; //delta=22.10 
			turn ruparm to z-axis <10.583475> speed <190.939458> / desiredFrames; //delta=-6.36 
			turn ruparm to y-axis <8.318628> speed <191.554687> / desiredFrames; //delta=6.39 
			turn torso to y-axis <8.849594> speed <82.165818> / desiredFrames; //delta=2.74 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:14
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <37.387998> speed <370.439186> / desiredFrames; //delta=-12.35 
			turn lfoot to z-axis <-8.962304> speed <268.846559> / desiredFrames; //delta=8.96 
			turn lfoot to y-axis <12.859584> speed <385.678150> / desiredFrames; //delta=12.86 
			turn lknee to x-axis <-9.441686> speed <475.001758> / desiredFrames; //delta=-15.83 
			turn lknee to z-axis <1.271139> speed <76.619681> / desiredFrames; //delta=-2.55 
			turn lknee to y-axis <-1.407645> speed <44.670228> / desiredFrames; //delta=1.49 
			turn lleg to x-axis <-10.324155> speed <662.485225> / desiredFrames; //delta=22.08 
			turn lleg to z-axis <0.960237> speed <50.657005> / desiredFrames; //delta=-1.69 
			turn lleg to y-axis <-3.255075> speed <157.021326> / desiredFrames; //delta=-5.23 
			turn lloarm to x-axis <-15.936846> speed <323.686434> / desiredFrames; //delta=10.79 
			turn lthigh to x-axis <-25.377240> speed <413.127749> / desiredFrames; //delta=-13.77 
			turn lthigh to z-axis <2.240162> speed <150.172014> / desiredFrames; //delta=-5.01 
			turn lthigh to y-axis <-4.056589> speed <33.253758> / desiredFrames; //delta=1.11 
			turn luparm to x-axis <13.964900> speed <32.627976> / desiredFrames; //delta=1.09 
			turn luparm to z-axis <2.304844> speed <10.970419> / desiredFrames; //delta=0.37 
			turn luparm to y-axis <1.097682> speed <5.932195> / desiredFrames; //delta=0.20 
			move pelvis to y-axis [-1.027000] speed [15.509999] / desiredFrames; //delta=-0.52 
			turn pelvis to x-axis <6.120000> speed <184.199989> / desiredFrames; //delta=-6.14 
			turn pelvis to y-axis <-3.020000> speed <70.199999> / desiredFrames; //delta=2.34 
			turn rfoot to x-axis <-37.669118> speed <214.350700> / desiredFrames; //delta=7.15 
			turn rfoot to z-axis <0.002079> speed <47.212867> / desiredFrames; //delta=1.57 
			turn rfoot to y-axis <0.006794> speed <101.191700> / desiredFrames; //delta=-3.37 
			turn rknee to x-axis <22.375748> speed <849.199349> / desiredFrames; //delta=-28.31 
			turn rknee to y-axis <-3.001270> speed <106.914647> / desiredFrames; //delta=-3.56 
			turn rleg to x-axis <-15.573975> speed <1510.795463> / desiredFrames; //delta=50.36 
			turn rleg to z-axis <1.078429> speed <55.333897> / desiredFrames; //delta=-1.84 
			turn rleg to y-axis <0.621153> speed <144.696955> / desiredFrames; //delta=4.82 
			turn rloarm to x-axis <7.481300> speed <863.651218> / desiredFrames; //delta=28.79 
			turn rthigh to x-axis <35.130125> speed <229.623139> / desiredFrames; //delta=7.65 
			turn rthigh to z-axis <1.654511> speed <51.586739> / desiredFrames; //delta=-1.72 
			turn rthigh to y-axis <-5.841921> speed <33.217822> / desiredFrames; //delta=-1.11 
			turn ruparm to x-axis <-19.401972> speed <519.965670> / desiredFrames; //delta=-17.33 
			turn ruparm to z-axis <5.353858> speed <156.888527> / desiredFrames; //delta=5.23 
			turn ruparm to y-axis <3.084982> speed <157.009377> / desiredFrames; //delta=-5.23 
			turn torso to y-axis <5.762510> speed <92.612524> / desiredFrames; //delta=-3.09 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:16
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <0.464192> speed <1107.714192> / desiredFrames; //delta=36.92 
			turn lfoot to z-axis <-9.697005> speed <22.041012> / desiredFrames; //delta=0.73 
			turn lfoot to y-axis <5.833231> speed <210.790579> / desiredFrames; //delta=-7.03 
			turn lknee to x-axis <-2.0> speed <223.240686> / desiredFrames; //delta=-7.44 
			turn lknee to z-axis <2.411943> speed <34.224105> / desiredFrames; //delta=-1.14 
			turn lknee to y-axis <-0.749186> speed <19.753780> / desiredFrames; //delta=0.66 
			turn lleg to x-axis <1.204694> speed <345.865479> / desiredFrames; //delta=-11.53 
			turn lleg to z-axis <1.961544> speed <30.039223> / desiredFrames; //delta=-1.00 
			turn lleg to y-axis <-2.972589> speed <8.474591> / desiredFrames; //delta=0.28 
			turn lloarm to x-axis <-4.648268> speed <338.657342> / desiredFrames; //delta=-11.29 
			turn lthigh to x-axis <-2.351720> speed <690.765615> / desiredFrames; //delta=-23.03 
			turn lthigh to z-axis <4.489955> speed <67.493810> / desiredFrames; //delta=-2.25 
			turn lthigh to y-axis <-2.580664> speed <44.277734> / desiredFrames; //delta=1.48 
			turn luparm to x-axis <2.055360> speed <357.286182> / desiredFrames; //delta=11.91 
			turn luparm to z-axis <-0.287076> speed <77.757598> / desiredFrames; //delta=2.59 
			turn luparm to y-axis <0.713883> speed <11.513976> / desiredFrames; //delta=-0.38 
			move pelvis to y-axis [-0.065000] speed [28.860001] / desiredFrames; //delta=0.96 
			turn pelvis to x-axis <3.050000> speed <92.099998> / desiredFrames; //delta=3.07 
			turn pelvis to y-axis <-0.060000> speed <88.799998> / desiredFrames; //delta=2.96 
			turn rfoot to x-axis <4.648639> speed <1269.532721> / desiredFrames; //delta=-42.32 
			turn rknee to x-axis <22.810462> speed <13.041427> / desiredFrames; //delta=-0.43 
			turn rknee to z-axis <-1.186372> speed <40.379282> / desiredFrames; //delta=1.35 
			turn rknee to y-axis <-0.668387> speed <69.986508> / desiredFrames; //delta=2.33 
			turn rleg to x-axis <-41.861666> speed <788.630717> / desiredFrames; //delta=26.29 
			turn rleg to z-axis <2.536832> speed <43.752081> / desiredFrames; //delta=-1.46 
			turn rleg to y-axis <4.475032> speed <115.616342> / desiredFrames; //delta=3.85 
			turn rloarm to x-axis <-0.686195> speed <245.024858> / desiredFrames; //delta=8.17 
			turn rthigh to x-axis <8.108854> speed <810.638150> / desiredFrames; //delta=27.02 
			turn rthigh to z-axis <2.222653> speed <17.044253> / desiredFrames; //delta=-0.57 
			turn rthigh to y-axis <-2.104883> speed <112.111131> / desiredFrames; //delta=3.74 
			turn ruparm to x-axis <-3.048251> speed <490.611639> / desiredFrames; //delta=-16.35 
			turn ruparm to z-axis <-0.061343> speed <162.456033> / desiredFrames; //delta=5.42 
			turn ruparm to y-axis <0.968246> speed <63.502084> / desiredFrames; //delta=-2.12 
			turn torso to y-axis <-0.411658> speed <185.225044> / desiredFrames; //delta=-6.17 
		sleep ((33*desiredFrames) -1);
		}
		if (isMoving) { //Frame:18
            desiredFrames = 2;
		    VA_CALC_DESIRED_FRAMES();
			turn lfoot to x-axis <-40.243512> speed <1221.231110> / desiredFrames; //delta=40.71 
			turn lfoot to z-axis <-7.440659> speed <67.690385> / desiredFrames; //delta=-2.26 
			turn lfoot to y-axis <-5.865953> speed <350.975516> / desiredFrames; //delta=-11.70 
			turn lknee to x-axis <-6.830024> speed <144.890839> / desiredFrames; //delta=4.83 
			turn lknee to z-axis <0.345820> speed <61.983694> / desiredFrames; //delta=2.07 
			turn lknee to y-axis <0.304802> speed <31.619633> / desiredFrames; //delta=1.05 
			turn lleg to x-axis <26.076006> speed <746.139360> / desiredFrames; //delta=-24.87 
			turn lleg to z-axis <-0.157717> speed <63.577841> / desiredFrames; //delta=2.12 
			turn lleg to y-axis <-0.087720> speed <86.546071> / desiredFrames; //delta=2.88 
			turn lloarm to x-axis <18.795205> speed <703.304203> / desiredFrames; //delta=-23.44 
			turn lthigh to x-axis <23.125820> speed <764.326189> / desiredFrames; //delta=-25.48 
			turn lthigh to z-axis <4.131044> speed <10.767332> / desiredFrames; //delta=0.36 
			turn lthigh to y-axis <-0.006083> speed <77.237453> / desiredFrames; //delta=2.57 
			turn luparm to x-axis <-15.533187> speed <527.656427> / desiredFrames; //delta=17.59 
			turn luparm to z-axis <-4.025448> speed <112.151159> / desiredFrames; //delta=3.74 
			turn luparm to y-axis <-1.012513> speed <51.791888> / desiredFrames; //delta=-1.73 
			turn pelvis to x-axis <-2.390000> speed <163.199994> / desiredFrames; //delta=5.44 
			turn pelvis to y-axis <3.0> speed <91.800016> / desiredFrames; //delta=3.06 
			turn rfoot to x-axis <39.693501> speed <1051.345854> / desiredFrames; //delta=-35.04 
			turn rknee to x-axis <5.049624> speed <532.825140> / desiredFrames; //delta=17.76 
			turn rknee to z-axis <0.401872> speed <47.647319> / desiredFrames; //delta=-1.59 
			turn rknee to y-axis <-0.387074> speed <8.439376> / desiredFrames; //delta=0.28 
			turn rleg to x-axis <-31.194563> speed <320.013077> / desiredFrames; //delta=-10.67 
			turn rleg to z-axis <2.029706> speed <15.213766> / desiredFrames; //delta=0.51 
			turn rleg to y-axis <1.439265> speed <91.072985> / desiredFrames; //delta=-3.04 
			turn rloarm to x-axis <13.871573> speed <436.733046> / desiredFrames; //delta=-14.56 
			turn rthigh to x-axis <-22.875507> speed <929.530826> / desiredFrames; //delta=30.98 
			turn rthigh to z-axis <4.381601> speed <64.768449> / desiredFrames; //delta=-2.16 
			turn rthigh to y-axis <1.935411> speed <121.208802> / desiredFrames; //delta=4.04 
			turn ruparm to x-axis <-11.229837> speed <245.447582> / desiredFrames; //delta=8.18 
			turn ruparm to z-axis <-0.266262> speed <6.147563> / desiredFrames; //delta=0.20 
			turn ruparm to y-axis <3.633788> speed <79.966261> / desiredFrames; //delta=2.67 
			turn torso to y-axis <-6.060918> speed <169.477809> / desiredFrames; //delta=-5.65 
		sleep ((33*desiredFrames) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
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
