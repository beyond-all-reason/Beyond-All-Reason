// For N:\animations\Raptors\raptor_2legged_swim.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 7))
//#define MOVESCALE 100 //Higher values are bigger, 100 is default
//static-var animAmplitude; //Higher values are bigger, 100 is default
// this animation uses the static-var animFramesPerKeyframe which contains how many frames each keyframe takes
//static-var animSpeed, maxSpeed, animFramesPerKeyframe, isMoving;
//#define SIGNAL_MOVE 1
Swim() {// For N:\animations\Raptors\raptor_2legged_swim.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 7)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:6
			turn head to x-axis ((<-6.375634> *animAmplitude)/100) speed ((<191.269023> *animAmplitude)/100) / animSpeed; //delta=6.38
			turn head to z-axis ((<0.411281> *animAmplitude)/100) speed ((<12.338443> *animAmplitude)/100) / animSpeed; //delta=-0.41
			turn head to y-axis ((<4.363053> *animAmplitude)/100) speed ((<130.891581> *animAmplitude)/100) / animSpeed; //delta=4.36
			turn lfoot to x-axis ((<9.459326> *animAmplitude)/100) speed ((<150.076157> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn lfoot to z-axis ((<0.627570> *animAmplitude)/100) speed ((<18.827098> *animAmplitude)/100) / animSpeed; //delta=-0.63
			turn lfoot to y-axis ((<-3.530131> *animAmplitude)/100) speed ((<105.903942> *animAmplitude)/100) / animSpeed; //delta=-3.53
			turn lknee to x-axis ((<4.891793> *animAmplitude)/100) speed ((<153.337893> *animAmplitude)/100) / animSpeed; //delta=-5.11
			turn lthigh to x-axis ((<-0.726596> *animAmplitude)/100) speed ((<100.248093> *animAmplitude)/100) / animSpeed; //delta=3.34
			turn lthigh to z-axis ((<0.245394> *animAmplitude)/100) speed ((<7.361809> *animAmplitude)/100) / animSpeed; //delta=-0.25
			turn lthigh to y-axis ((<3.408205> *animAmplitude)/100) speed ((<102.246158> *animAmplitude)/100) / animSpeed; //delta=3.41
			turn rfoot to x-axis ((<6.505517> *animAmplitude)/100) speed ((<146.709944> *animAmplitude)/100) / animSpeed; //delta=-4.89
			turn rfoot to z-axis ((<-0.358806> *animAmplitude)/100) speed ((<10.764167> *animAmplitude)/100) / animSpeed; //delta=0.36
			turn rfoot to y-axis ((<3.780539> *animAmplitude)/100) speed ((<113.416162> *animAmplitude)/100) / animSpeed; //delta=3.78
			turn rknee to x-axis ((<6.538980> *animAmplitude)/100) speed ((<145.713913> *animAmplitude)/100) / animSpeed; //delta=-4.86
			turn rshin to x-axis ((<0.737423> *animAmplitude)/100) speed ((<20.094889> *animAmplitude)/100) / animSpeed; //delta=-0.67
			turn rthigh to x-axis ((<-4.803467> *animAmplitude)/100) speed ((<110.274539> *animAmplitude)/100) / animSpeed; //delta=3.68
			turn rthigh to z-axis ((<-0.287712> *animAmplitude)/100) speed ((<8.631352> *animAmplitude)/100) / animSpeed; //delta=0.29
			turn rthigh to y-axis ((<-3.715490> *animAmplitude)/100) speed ((<111.464704> *animAmplitude)/100) / animSpeed; //delta=-3.72
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:12
			move body to z-axis (((([-1.589830] *MOVESCALE)/100) *animAmplitude)/100) speed (((([47.694898] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.59
			move body to y-axis (((([0.366884] *MOVESCALE)/100) *animAmplitude)/100) speed (((([11.006514] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.37
			turn body to x-axis ((<7.081318> *animAmplitude)/100) speed ((<212.439545> *animAmplitude)/100) / animSpeed; //delta=-7.08
			turn head to x-axis ((<-15.070462> *animAmplitude)/100) speed ((<260.844848> *animAmplitude)/100) / animSpeed; //delta=8.69
			turn head to z-axis ((<1.095718> *animAmplitude)/100) speed ((<20.533095> *animAmplitude)/100) / animSpeed; //delta=-0.68
			turn head to y-axis ((<4.490769> *animAmplitude)/100) speed ((<3.831493> *animAmplitude)/100) / animSpeed; //delta=0.13
			turn lfoot to x-axis ((<79.037863> *animAmplitude)/100) speed ((<2087.356106> *animAmplitude)/100) / animSpeed; //delta=-69.58
			turn lfoot to z-axis ((<-34.085718> *animAmplitude)/100) speed ((<1041.398625> *animAmplitude)/100) / animSpeed; //delta=34.71
			turn lfoot to y-axis ((<48.381047> *animAmplitude)/100) speed ((<1557.335363> *animAmplitude)/100) / animSpeed; //delta=51.91//WARNING: possible gimbal lock issue detected in frame 12 bone lfoot

			turn lknee to x-axis ((<2.743575> *animAmplitude)/100) speed ((<64.446536> *animAmplitude)/100) / animSpeed; //delta=2.15
			turn lknee to z-axis ((<-0.106469> *animAmplitude)/100) speed ((<4.106898> *animAmplitude)/100) / animSpeed; //delta=0.14
			turn lshin to x-axis ((<1.611816> *animAmplitude)/100) speed ((<216.980408> *animAmplitude)/100) / animSpeed; //delta=-7.23
			turn lshin to z-axis ((<-0.147761> *animAmplitude)/100) speed ((<5.779971> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn lthigh to x-axis ((<-61.675201> *animAmplitude)/100) speed ((<1828.458168> *animAmplitude)/100) / animSpeed; //delta=60.95
			turn lthigh to z-axis ((<-17.065779> *animAmplitude)/100) speed ((<519.335184> *animAmplitude)/100) / animSpeed; //delta=17.31
			turn lthigh to y-axis ((<-28.077275> *animAmplitude)/100) speed ((<944.564416> *animAmplitude)/100) / animSpeed; //delta=-31.49
			turn rfoot to x-axis ((<76.297892> *animAmplitude)/100) speed ((<2093.771242> *animAmplitude)/100) / animSpeed; //delta=-69.79
			turn rfoot to z-axis ((<19.144231> *animAmplitude)/100) speed ((<585.091107> *animAmplitude)/100) / animSpeed; //delta=-19.50
			turn rfoot to y-axis ((<-35.661019> *animAmplitude)/100) speed ((<1183.246723> *animAmplitude)/100) / animSpeed; //delta=-39.44
			turn rknee to x-axis ((<2.053512> *animAmplitude)/100) speed ((<134.564035> *animAmplitude)/100) / animSpeed; //delta=4.49
			turn rshin to x-axis ((<11.365119> *animAmplitude)/100) speed ((<318.830874> *animAmplitude)/100) / animSpeed; //delta=-10.63
			turn rshin to z-axis ((<0.092507> *animAmplitude)/100) speed ((<3.675905> *animAmplitude)/100) / animSpeed; //delta=-0.12
			turn rthigh to x-axis ((<-64.803674> *animAmplitude)/100) speed ((<1800.006210> *animAmplitude)/100) / animSpeed; //delta=60.00
			turn rthigh to z-axis ((<23.215734> *animAmplitude)/100) speed ((<705.103385> *animAmplitude)/100) / animSpeed; //delta=-23.50
			turn rthigh to y-axis ((<34.834467> *animAmplitude)/100) speed ((<1156.498708> *animAmplitude)/100) / animSpeed; //delta=38.55
			turn tail to z-axis ((<-0.848312> *animAmplitude)/100) speed ((<25.449362> *animAmplitude)/100) / animSpeed; //delta=0.85
			turn tail to y-axis ((<-6.844830> *animAmplitude)/100) speed ((<205.344890> *animAmplitude)/100) / animSpeed; //delta=-6.84
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:18
			turn body to x-axis ((<2.399009> *animAmplitude)/100) speed ((<140.469269> *animAmplitude)/100) / animSpeed; //delta=4.68
			turn head to x-axis ((<-8.075413> *animAmplitude)/100) speed ((<209.851483> *animAmplitude)/100) / animSpeed; //delta=-7.00
			turn head to z-axis ((<0.543087> *animAmplitude)/100) speed ((<16.578936> *animAmplitude)/100) / animSpeed; //delta=0.55
			turn head to y-axis ((<4.382390> *animAmplitude)/100) speed ((<3.251366> *animAmplitude)/100) / animSpeed; //delta=-0.11
			turn lfoot to x-axis ((<21.843580> *animAmplitude)/100) speed ((<1715.828487> *animAmplitude)/100) / animSpeed; //delta=57.19
			turn lfoot to z-axis ((<10.321923> *animAmplitude)/100) speed ((<1332.229209> *animAmplitude)/100) / animSpeed; //delta=-44.41
			turn lfoot to y-axis ((<-17.806412> *animAmplitude)/100) speed ((<1985.623794> *animAmplitude)/100) / animSpeed; //delta=-66.19//WARNING: possible gimbal lock issue detected in frame 18 bone lfoot

			turn lknee to x-axis ((<-9.822840> *animAmplitude)/100) speed ((<376.992453> *animAmplitude)/100) / animSpeed; //delta=12.57
			turn lknee to z-axis ((<0.048942> *animAmplitude)/100) speed ((<4.662337> *animAmplitude)/100) / animSpeed; //delta=-0.16
			turn lshin to x-axis ((<16.166503> *animAmplitude)/100) speed ((<436.640611> *animAmplitude)/100) / animSpeed; //delta=-14.55
			turn lshin to z-axis ((<0.136379> *animAmplitude)/100) speed ((<8.524201> *animAmplitude)/100) / animSpeed; //delta=-0.28
			turn lshin to y-axis ((<0.126884> *animAmplitude)/100) speed ((<4.958466> *animAmplitude)/100) / animSpeed; //delta=0.17
			turn lthigh to x-axis ((<22.209805> *animAmplitude)/100) speed ((<2516.550176> *animAmplitude)/100) / animSpeed; //delta=-83.89
			turn lthigh to z-axis ((<-40.869530> *animAmplitude)/100) speed ((<714.112516> *animAmplitude)/100) / animSpeed; //delta=23.80
			turn lthigh to y-axis ((<59.800034> *animAmplitude)/100) speed ((<2636.319285> *animAmplitude)/100) / animSpeed; //delta=87.88//WARNING: possible gimbal lock issue detected in frame 18 bone lthigh

			turn rfoot to x-axis ((<19.070592> *animAmplitude)/100) speed ((<1716.819001> *animAmplitude)/100) / animSpeed; //delta=57.23
			turn rfoot to z-axis ((<-9.180024> *animAmplitude)/100) speed ((<849.727647> *animAmplitude)/100) / animSpeed; //delta=28.32
			turn rfoot to y-axis ((<16.978937> *animAmplitude)/100) speed ((<1579.198664> *animAmplitude)/100) / animSpeed; //delta=52.64//WARNING: possible gimbal lock issue detected in frame 18 bone rfoot

			turn rknee to x-axis ((<-7.311528> *animAmplitude)/100) speed ((<280.951198> *animAmplitude)/100) / animSpeed; //delta=9.37
			turn rknee to z-axis ((<-0.069672> *animAmplitude)/100) speed ((<4.158444> *animAmplitude)/100) / animSpeed; //delta=0.14
			turn rshin to x-axis ((<20.410897> *animAmplitude)/100) speed ((<271.373337> *animAmplitude)/100) / animSpeed; //delta=-9.05
			turn rshin to z-axis ((<-0.173399> *animAmplitude)/100) speed ((<7.977177> *animAmplitude)/100) / animSpeed; //delta=0.27
			turn rshin to y-axis ((<-0.093121> *animAmplitude)/100) speed ((<3.488922> *animAmplitude)/100) / animSpeed; //delta=-0.12
			turn rthigh to x-axis ((<20.052438> *animAmplitude)/100) speed ((<2545.683357> *animAmplitude)/100) / animSpeed; //delta=-84.86
			turn rthigh to z-axis ((<40.484075> *animAmplitude)/100) speed ((<518.050212> *animAmplitude)/100) / animSpeed; //delta=-17.27
			turn rthigh to y-axis ((<-57.200652> *animAmplitude)/100) speed ((<2761.053565> *animAmplitude)/100) / animSpeed; //delta=-92.04//WARNING: possible gimbal lock issue detected in frame 18 bone rthigh

			turn tail to z-axis ((<-0.0> *animAmplitude)/100) speed ((<25.449362> *animAmplitude)/100) / animSpeed; //delta=-0.85
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<205.344890> *animAmplitude)/100) / animSpeed; //delta=6.84
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:24
			move body to z-axis (((([1.354689] *MOVESCALE)/100) *animAmplitude)/100) speed (((([88.335575] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=2.94
			move body to y-axis (((([0.538738] *MOVESCALE)/100) *animAmplitude)/100) speed (((([5.155626] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.17
			turn body to x-axis ((<-2.283299> *animAmplitude)/100) speed ((<140.469256> *animAmplitude)/100) / animSpeed; //delta=4.68
			turn head to x-axis ((<0.295483> *animAmplitude)/100) speed ((<251.126877> *animAmplitude)/100) / animSpeed; //delta=-8.37
			turn head to z-axis ((<-0.096233> *animAmplitude)/100) speed ((<19.179589> *animAmplitude)/100) / animSpeed; //delta=0.64
			turn lfoot to x-axis ((<33.878268> *animAmplitude)/100) speed ((<361.040623> *animAmplitude)/100) / animSpeed; //delta=-12.03
			turn lfoot to z-axis ((<11.091670> *animAmplitude)/100) speed ((<23.092409> *animAmplitude)/100) / animSpeed; //delta=-0.77
			turn lfoot to y-axis ((<-10.052952> *animAmplitude)/100) speed ((<232.603800> *animAmplitude)/100) / animSpeed; //delta=7.75
			turn lknee to x-axis ((<-79.894123> *animAmplitude)/100) speed ((<2102.138488> *animAmplitude)/100) / animSpeed; //delta=70.07
			turn lknee to z-axis ((<-0.723264> *animAmplitude)/100) speed ((<23.166163> *animAmplitude)/100) / animSpeed; //delta=0.77
			turn lknee to y-axis ((<-0.608339> *animAmplitude)/100) speed ((<16.567370> *animAmplitude)/100) / animSpeed; //delta=-0.55
			turn lshin to x-axis ((<51.624738> *animAmplitude)/100) speed ((<1063.747066> *animAmplitude)/100) / animSpeed; //delta=-35.46
			turn lshin to z-axis ((<-0.234371> *animAmplitude)/100) speed ((<11.122494> *animAmplitude)/100) / animSpeed; //delta=0.37
			turn lshin to y-axis ((<0.268278> *animAmplitude)/100) speed ((<4.241796> *animAmplitude)/100) / animSpeed; //delta=0.14
			turn lthigh to x-axis ((<48.941895> *animAmplitude)/100) speed ((<801.962700> *animAmplitude)/100) / animSpeed; //delta=-26.73
			turn lthigh to z-axis ((<-90.803117> *animAmplitude)/100) speed ((<1498.007607> *animAmplitude)/100) / animSpeed; //delta=49.93
			turn lthigh to y-axis ((<112.957115> *animAmplitude)/100) speed ((<1594.712431> *animAmplitude)/100) / animSpeed; //delta=53.16
			turn rfoot to x-axis ((<32.992119> *animAmplitude)/100) speed ((<417.645816> *animAmplitude)/100) / animSpeed; //delta=-13.92
			turn rfoot to z-axis ((<-10.696057> *animAmplitude)/100) speed ((<45.480992> *animAmplitude)/100) / animSpeed; //delta=1.52
			turn rfoot to y-axis ((<10.103512> *animAmplitude)/100) speed ((<206.262740> *animAmplitude)/100) / animSpeed; //delta=-6.88
			turn rknee to x-axis ((<-73.282493> *animAmplitude)/100) speed ((<1979.128950> *animAmplitude)/100) / animSpeed; //delta=65.97
			turn rknee to z-axis ((<0.297057> *animAmplitude)/100) speed ((<11.001871> *animAmplitude)/100) / animSpeed; //delta=-0.37
			turn rknee to y-axis ((<0.238336> *animAmplitude)/100) speed ((<4.397650> *animAmplitude)/100) / animSpeed; //delta=0.15
			turn rshin to x-axis ((<49.560334> *animAmplitude)/100) speed ((<874.483121> *animAmplitude)/100) / animSpeed; //delta=-29.15
			turn rshin to z-axis ((<0.128995> *animAmplitude)/100) speed ((<9.071843> *animAmplitude)/100) / animSpeed; //delta=-0.30
			turn rthigh to x-axis ((<48.282911> *animAmplitude)/100) speed ((<846.914190> *animAmplitude)/100) / animSpeed; //delta=-28.23
			turn rthigh to z-axis ((<87.847591> *animAmplitude)/100) speed ((<1420.905495> *animAmplitude)/100) / animSpeed; //delta=-47.36
			turn rthigh to y-axis ((<-108.512028> *animAmplitude)/100) speed ((<1539.341282> *animAmplitude)/100) / animSpeed; //delta=-51.31
			turn tail to z-axis ((<-0.299499> *animAmplitude)/100) speed ((<8.984966> *animAmplitude)/100) / animSpeed; //delta=0.30
			turn tail to y-axis ((<7.533121> *animAmplitude)/100) speed ((<225.993619> *animAmplitude)/100) / animSpeed; //delta=7.53
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:30
			turn body to x-axis ((<-1.826640> *animAmplitude)/100) speed ((<13.699795> *animAmplitude)/100) / animSpeed; //delta=-0.46
			turn head to x-axis ((<2.781466> *animAmplitude)/100) speed ((<74.579499> *animAmplitude)/100) / animSpeed; //delta=-2.49
			turn head to z-axis ((<-0.286258> *animAmplitude)/100) speed ((<5.700759> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn lfoot to x-axis ((<24.198045> *animAmplitude)/100) speed ((<290.406666> *animAmplitude)/100) / animSpeed; //delta=9.68
			turn lfoot to z-axis ((<6.740073> *animAmplitude)/100) speed ((<130.547890> *animAmplitude)/100) / animSpeed; //delta=4.35
			turn lfoot to y-axis ((<-11.797793> *animAmplitude)/100) speed ((<52.345229> *animAmplitude)/100) / animSpeed; //delta=-1.74
			turn lknee to x-axis ((<-46.935878> *animAmplitude)/100) speed ((<988.747337> *animAmplitude)/100) / animSpeed; //delta=-32.96
			turn lknee to z-axis ((<-0.121391> *animAmplitude)/100) speed ((<18.056176> *animAmplitude)/100) / animSpeed; //delta=-0.60
			turn lknee to y-axis ((<-0.036128> *animAmplitude)/100) speed ((<17.166316> *animAmplitude)/100) / animSpeed; //delta=0.57
			turn lshin to x-axis ((<34.317391> *animAmplitude)/100) speed ((<519.220428> *animAmplitude)/100) / animSpeed; //delta=17.31
			turn lshin to z-axis ((<-0.079183> *animAmplitude)/100) speed ((<4.655646> *animAmplitude)/100) / animSpeed; //delta=-0.16
			turn lshin to y-axis ((<0.166287> *animAmplitude)/100) speed ((<3.059722> *animAmplitude)/100) / animSpeed; //delta=-0.10
			turn lthigh to x-axis ((<47.538434> *animAmplitude)/100) speed ((<42.103813> *animAmplitude)/100) / animSpeed; //delta=1.40
			turn lthigh to z-axis ((<-69.528191> *animAmplitude)/100) speed ((<638.247778> *animAmplitude)/100) / animSpeed; //delta=-21.27
			turn lthigh to y-axis ((<91.598280> *animAmplitude)/100) speed ((<640.765045> *animAmplitude)/100) / animSpeed; //delta=-21.36
			turn rfoot to x-axis ((<22.187277> *animAmplitude)/100) speed ((<324.145256> *animAmplitude)/100) / animSpeed; //delta=10.80
			turn rfoot to z-axis ((<-6.047473> *animAmplitude)/100) speed ((<139.457496> *animAmplitude)/100) / animSpeed; //delta=-4.65
			turn rfoot to y-axis ((<11.364578> *animAmplitude)/100) speed ((<37.831965> *animAmplitude)/100) / animSpeed; //delta=1.26
			turn rknee to x-axis ((<-43.029379> *animAmplitude)/100) speed ((<907.593420> *animAmplitude)/100) / animSpeed; //delta=-30.25
			turn rknee to z-axis ((<0.041937> *animAmplitude)/100) speed ((<7.653592> *animAmplitude)/100) / animSpeed; //delta=0.26
			turn rknee to y-axis ((<0.052229> *animAmplitude)/100) speed ((<5.583210> *animAmplitude)/100) / animSpeed; //delta=-0.19
			turn rshin to x-axis ((<35.523264> *animAmplitude)/100) speed ((<421.112103> *animAmplitude)/100) / animSpeed; //delta=14.04
			turn rshin to z-axis ((<-0.036528> *animAmplitude)/100) speed ((<4.965695> *animAmplitude)/100) / animSpeed; //delta=0.17
			turn rthigh to x-axis ((<46.507554> *animAmplitude)/100) speed ((<53.260722> *animAmplitude)/100) / animSpeed; //delta=1.78
			turn rthigh to z-axis ((<67.843811> *animAmplitude)/100) speed ((<600.113398> *animAmplitude)/100) / animSpeed; //delta=20.00
			turn rthigh to y-axis ((<-88.474753> *animAmplitude)/100) speed ((<601.118255> *animAmplitude)/100) / animSpeed; //delta=20.04
			turn tail to z-axis ((<-0.0> *animAmplitude)/100) speed ((<8.984966> *animAmplitude)/100) / animSpeed; //delta=-0.30
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<225.993619> *animAmplitude)/100) / animSpeed; //delta=-7.53
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:36
			turn body to x-axis ((<-1.369980> *animAmplitude)/100) speed ((<13.699798> *animAmplitude)/100) / animSpeed; //delta=-0.46
			turn head to x-axis ((<5.267450> *animAmplitude)/100) speed ((<74.579499> *animAmplitude)/100) / animSpeed; //delta=-2.49
			turn head to z-axis ((<-0.476283> *animAmplitude)/100) speed ((<5.700759> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn lfoot to x-axis ((<4.972341> *animAmplitude)/100) speed ((<576.771120> *animAmplitude)/100) / animSpeed; //delta=19.23
			turn lfoot to z-axis ((<0.908447> *animAmplitude)/100) speed ((<174.948805> *animAmplitude)/100) / animSpeed; //delta=5.83
			turn lfoot to y-axis ((<-15.470874> *animAmplitude)/100) speed ((<110.192407> *animAmplitude)/100) / animSpeed; //delta=-3.67
			turn lknee to x-axis ((<-9.212660> *animAmplitude)/100) speed ((<1131.696554> *animAmplitude)/100) / animSpeed; //delta=-37.72
			turn lknee to z-axis ((<0.249756> *animAmplitude)/100) speed ((<11.134424> *animAmplitude)/100) / animSpeed; //delta=-0.37
			turn lknee to y-axis ((<-0.198975> *animAmplitude)/100) speed ((<4.885406> *animAmplitude)/100) / animSpeed; //delta=-0.16
			turn lshin to x-axis ((<18.157773> *animAmplitude)/100) speed ((<484.788539> *animAmplitude)/100) / animSpeed; //delta=16.16
			turn lshin to z-axis ((<0.419779> *animAmplitude)/100) speed ((<14.968846> *animAmplitude)/100) / animSpeed; //delta=-0.50
			turn lshin to y-axis ((<0.038316> *animAmplitude)/100) speed ((<3.839137> *animAmplitude)/100) / animSpeed; //delta=-0.13
			turn lthigh to x-axis ((<38.423714> *animAmplitude)/100) speed ((<273.441603> *animAmplitude)/100) / animSpeed; //delta=9.11
			turn lthigh to z-axis ((<-40.709724> *animAmplitude)/100) speed ((<864.554007> *animAmplitude)/100) / animSpeed; //delta=-28.82
			turn lthigh to y-axis ((<61.427498> *animAmplitude)/100) speed ((<905.123487> *animAmplitude)/100) / animSpeed; //delta=-30.17
			turn rfoot to x-axis ((<2.490134> *animAmplitude)/100) speed ((<590.914298> *animAmplitude)/100) / animSpeed; //delta=19.70
			turn rfoot to z-axis ((<-0.057435> *animAmplitude)/100) speed ((<179.701162> *animAmplitude)/100) / animSpeed; //delta=-5.99
			turn rfoot to y-axis ((<14.694293> *animAmplitude)/100) speed ((<99.891465> *animAmplitude)/100) / animSpeed; //delta=3.33
			turn rknee to x-axis ((<-6.824358> *animAmplitude)/100) speed ((<1086.150620> *animAmplitude)/100) / animSpeed; //delta=-36.21
			turn rknee to z-axis ((<-0.270547> *animAmplitude)/100) speed ((<9.374547> *animAmplitude)/100) / animSpeed; //delta=0.31
			turn rknee to y-axis ((<0.244326> *animAmplitude)/100) speed ((<5.762910> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn rshin to x-axis ((<21.684510> *animAmplitude)/100) speed ((<415.162616> *animAmplitude)/100) / animSpeed; //delta=13.84
			turn rshin to z-axis ((<-0.471390> *animAmplitude)/100) speed ((<13.045874> *animAmplitude)/100) / animSpeed; //delta=0.43
			turn rshin to y-axis ((<0.010637> *animAmplitude)/100) speed ((<3.906037> *animAmplitude)/100) / animSpeed; //delta=0.13
			turn rthigh to x-axis ((<36.762055> *animAmplitude)/100) speed ((<292.364950> *animAmplitude)/100) / animSpeed; //delta=9.75
			turn rthigh to z-axis ((<39.498035> *animAmplitude)/100) speed ((<850.373305> *animAmplitude)/100) / animSpeed; //delta=28.35
			turn rthigh to y-axis ((<-58.806467> *animAmplitude)/100) speed ((<890.048576> *animAmplitude)/100) / animSpeed; //delta=29.67
			turn tail to z-axis ((<0.200786> *animAmplitude)/100) speed ((<6.023571> *animAmplitude)/100) / animSpeed; //delta=-0.20
			turn tail to y-axis ((<-7.797609> *animAmplitude)/100) speed ((<233.928284> *animAmplitude)/100) / animSpeed; //delta=-7.80
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:42
			turn body to x-axis ((<-0.913320> *animAmplitude)/100) speed ((<13.699795> *animAmplitude)/100) / animSpeed; //delta=-0.46
			turn head to x-axis ((<7.753434> *animAmplitude)/100) speed ((<74.579519> *animAmplitude)/100) / animSpeed; //delta=-2.49
			turn head to z-axis ((<-0.666309> *animAmplitude)/100) speed ((<5.700758> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn lfoot to x-axis ((<-1.210412> *animAmplitude)/100) speed ((<185.482596> *animAmplitude)/100) / animSpeed; //delta=6.18
			turn lfoot to z-axis ((<-1.012918> *animAmplitude)/100) speed ((<57.640946> *animAmplitude)/100) / animSpeed; //delta=1.92
			turn lfoot to y-axis ((<-3.303302> *animAmplitude)/100) speed ((<365.027159> *animAmplitude)/100) / animSpeed; //delta=12.17
			turn lknee to x-axis ((<12.214251> *animAmplitude)/100) speed ((<642.807339> *animAmplitude)/100) / animSpeed; //delta=-21.43
			turn lknee to z-axis ((<0.029056> *animAmplitude)/100) speed ((<6.621027> *animAmplitude)/100) / animSpeed; //delta=0.22
			turn lknee to y-axis ((<-0.030970> *animAmplitude)/100) speed ((<5.040143> *animAmplitude)/100) / animSpeed; //delta=0.17
			turn lshin to x-axis ((<-1.622528> *animAmplitude)/100) speed ((<593.409015> *animAmplitude)/100) / animSpeed; //delta=19.78
			turn lshin to z-axis ((<0.030598> *animAmplitude)/100) speed ((<11.675432> *animAmplitude)/100) / animSpeed; //delta=0.39
			turn lthigh to x-axis ((<27.914203> *animAmplitude)/100) speed ((<315.285340> *animAmplitude)/100) / animSpeed; //delta=10.51
			turn lthigh to z-axis ((<-7.371745> *animAmplitude)/100) speed ((<1000.139349> *animAmplitude)/100) / animSpeed; //delta=-33.34
			turn lthigh to y-axis ((<21.908166> *animAmplitude)/100) speed ((<1185.579933> *animAmplitude)/100) / animSpeed; //delta=-39.52
			turn rfoot to x-axis ((<-4.400297> *animAmplitude)/100) speed ((<206.712930> *animAmplitude)/100) / animSpeed; //delta=6.89
			turn rfoot to z-axis ((<1.003057> *animAmplitude)/100) speed ((<31.814754> *animAmplitude)/100) / animSpeed; //delta=-1.06
			turn rfoot to y-axis ((<1.219914> *animAmplitude)/100) speed ((<404.231362> *animAmplitude)/100) / animSpeed; //delta=-13.47
			turn rknee to x-axis ((<14.286644> *animAmplitude)/100) speed ((<633.330081> *animAmplitude)/100) / animSpeed; //delta=-21.11
			turn rknee to z-axis ((<-0.010839> *animAmplitude)/100) speed ((<7.791267> *animAmplitude)/100) / animSpeed; //delta=-0.26
			turn rknee to y-axis ((<0.008117> *animAmplitude)/100) speed ((<7.086294> *animAmplitude)/100) / animSpeed; //delta=-0.24
			turn rshin to x-axis ((<4.700742> *animAmplitude)/100) speed ((<509.513035> *animAmplitude)/100) / animSpeed; //delta=16.98
			turn rshin to z-axis ((<-0.005896> *animAmplitude)/100) speed ((<13.964844> *animAmplitude)/100) / animSpeed; //delta=-0.47
			turn rthigh to x-axis ((<23.882190> *animAmplitude)/100) speed ((<386.395959> *animAmplitude)/100) / animSpeed; //delta=12.88
			turn rthigh to z-axis ((<6.019011> *animAmplitude)/100) speed ((<1004.370716> *animAmplitude)/100) / animSpeed; //delta=33.48
			turn rthigh to y-axis ((<-19.130274> *animAmplitude)/100) speed ((<1190.285797> *animAmplitude)/100) / animSpeed; //delta=39.68
			turn tail to z-axis ((<-0.0> *animAmplitude)/100) speed ((<6.023571> *animAmplitude)/100) / animSpeed; //delta=0.20
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<233.928284> *animAmplitude)/100) / animSpeed; //delta=7.80
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:48
			turn body to x-axis ((<-0.456660> *animAmplitude)/100) speed ((<13.699798> *animAmplitude)/100) / animSpeed; //delta=-0.46
			turn head to x-axis ((<0.688899> *animAmplitude)/100) speed ((<211.936027> *animAmplitude)/100) / animSpeed; //delta=7.06
			turn head to z-axis ((<-0.127514> *animAmplitude)/100) speed ((<16.163853> *animAmplitude)/100) / animSpeed; //delta=-0.54
			turn lfoot to x-axis ((<4.306958> *animAmplitude)/100) speed ((<165.521082> *animAmplitude)/100) / animSpeed; //delta=-5.52
			turn lfoot to z-axis ((<-0.232427> *animAmplitude)/100) speed ((<23.414733> *animAmplitude)/100) / animSpeed; //delta=-0.78
			turn lfoot to y-axis ((<3.731892> *animAmplitude)/100) speed ((<211.055823> *animAmplitude)/100) / animSpeed; //delta=7.04
			turn lknee to x-axis ((<11.562219> *animAmplitude)/100) speed ((<19.560962> *animAmplitude)/100) / animSpeed; //delta=0.65
			turn lshin to x-axis ((<-6.037254> *animAmplitude)/100) speed ((<132.441779> *animAmplitude)/100) / animSpeed; //delta=4.41
			turn lthigh to x-axis ((<6.669072> *animAmplitude)/100) speed ((<637.353916> *animAmplitude)/100) / animSpeed; //delta=21.25
			turn lthigh to z-axis ((<1.094567> *animAmplitude)/100) speed ((<253.989373> *animAmplitude)/100) / animSpeed; //delta=-8.47
			turn lthigh to y-axis ((<0.720556> *animAmplitude)/100) speed ((<635.628299> *animAmplitude)/100) / animSpeed; //delta=-21.19
			turn rfoot to x-axis ((<1.388100> *animAmplitude)/100) speed ((<173.651915> *animAmplitude)/100) / animSpeed; //delta=-5.79
			turn rfoot to z-axis ((<0.087261> *animAmplitude)/100) speed ((<27.473880> *animAmplitude)/100) / animSpeed; //delta=0.92
			turn rfoot to y-axis ((<-3.717212> *animAmplitude)/100) speed ((<148.113784> *animAmplitude)/100) / animSpeed; //delta=-4.94
			turn rknee to x-axis ((<13.238560> *animAmplitude)/100) speed ((<31.442520> *animAmplitude)/100) / animSpeed; //delta=1.05
			turn rshin to x-axis ((<0.570101> *animAmplitude)/100) speed ((<123.919227> *animAmplitude)/100) / animSpeed; //delta=4.13
			turn rthigh to x-axis ((<2.272713> *animAmplitude)/100) speed ((<648.284302> *animAmplitude)/100) / animSpeed; //delta=21.61
			turn rthigh to z-axis ((<-1.083117> *animAmplitude)/100) speed ((<213.063841> *animAmplitude)/100) / animSpeed; //delta=7.10
			turn rthigh to y-axis ((<-0.845099> *animAmplitude)/100) speed ((<548.555254> *animAmplitude)/100) / animSpeed; //delta=18.29
			turn tail to y-axis ((<7.467435> *animAmplitude)/100) speed ((<224.023042> *animAmplitude)/100) / animSpeed; //delta=7.47
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:54
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([40.640677] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.35
			move body to y-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([16.162140] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-0.54
			turn body to x-axis ((<-0.0> *animAmplitude)/100) speed ((<13.699795> *animAmplitude)/100) / animSpeed; //delta=-0.46
			turn head to x-axis ((<-6.375634> *animAmplitude)/100) speed ((<211.936002> *animAmplitude)/100) / animSpeed; //delta=7.06
			turn head to z-axis ((<0.411281> *animAmplitude)/100) speed ((<16.163853> *animAmplitude)/100) / animSpeed; //delta=-0.54
			turn lfoot to x-axis ((<9.459326> *animAmplitude)/100) speed ((<154.571057> *animAmplitude)/100) / animSpeed; //delta=-5.15
			turn lfoot to z-axis ((<0.627570> *animAmplitude)/100) speed ((<25.799915> *animAmplitude)/100) / animSpeed; //delta=-0.86
			turn lfoot to y-axis ((<-3.530131> *animAmplitude)/100) speed ((<217.860715> *animAmplitude)/100) / animSpeed; //delta=-7.26
			turn lknee to x-axis ((<4.891793> *animAmplitude)/100) speed ((<200.112790> *animAmplitude)/100) / animSpeed; //delta=6.67
			turn lshin to x-axis ((<-5.620864> *animAmplitude)/100) speed ((<12.491677> *animAmplitude)/100) / animSpeed; //delta=-0.42
			turn lthigh to x-axis ((<-0.726596> *animAmplitude)/100) speed ((<221.870035> *animAmplitude)/100) / animSpeed; //delta=7.40
			turn lthigh to z-axis ((<0.245394> *animAmplitude)/100) speed ((<25.475200> *animAmplitude)/100) / animSpeed; //delta=0.85
			turn lthigh to y-axis ((<3.408205> *animAmplitude)/100) speed ((<80.629464> *animAmplitude)/100) / animSpeed; //delta=2.69
			turn rfoot to x-axis ((<6.505517> *animAmplitude)/100) speed ((<153.522513> *animAmplitude)/100) / animSpeed; //delta=-5.12
			turn rfoot to z-axis ((<-0.358806> *animAmplitude)/100) speed ((<13.382001> *animAmplitude)/100) / animSpeed; //delta=0.45
			turn rfoot to y-axis ((<3.780539> *animAmplitude)/100) speed ((<224.932515> *animAmplitude)/100) / animSpeed; //delta=7.50
			turn rknee to x-axis ((<6.538980> *animAmplitude)/100) speed ((<200.987418> *animAmplitude)/100) / animSpeed; //delta=6.70
			turn rshin to x-axis ((<0.737423> *animAmplitude)/100) speed ((<5.019648> *animAmplitude)/100) / animSpeed; //delta=-0.17
			turn rthigh to x-axis ((<-4.803467> *animAmplitude)/100) speed ((<212.285404> *animAmplitude)/100) / animSpeed; //delta=7.08
			turn rthigh to z-axis ((<-0.287712> *animAmplitude)/100) speed ((<23.862167> *animAmplitude)/100) / animSpeed; //delta=-0.80
			turn rthigh to y-axis ((<-3.715490> *animAmplitude)/100) speed ((<86.111743> *animAmplitude)/100) / animSpeed; //delta=-2.87
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<224.023042> *animAmplitude)/100) / animSpeed; //delta=-7.47
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopSwimming() {
	animSpeed = 10; // tune restore speed here, higher values are slower restore speeds
	move body to y-axis ([0.0]*MOVESCALE)/100 speed (([26.936901]*MOVESCALE)/100) / animSpeed;
	move body to z-axis ([0.0]*MOVESCALE)/100 speed (([147.225958]*MOVESCALE)/100) / animSpeed;
	turn body to x-axis <0.0> speed <354.065908> / animSpeed;
	turn head to x-axis <0.0> speed <434.741413> / animSpeed;
	turn head to y-axis <0.0> speed <218.152635> / animSpeed;
	turn head to z-axis <0.0> speed <34.221825> / animSpeed;
	turn lfoot to x-axis <4.456788> speed <3478.926844> / animSpeed;
	turn lfoot to y-axis <0.0> speed <3309.372990> / animSpeed;
	turn lfoot to z-axis <0.0> speed <2220.382014> / animSpeed;
	turn lknee to x-axis <-0.219470> speed <3503.564147> / animSpeed;
	turn lknee to y-axis <0.0> speed <28.610527> / animSpeed;
	turn lknee to z-axis <0.0> speed <38.610272> / animSpeed;
	turn lshin to x-axis <-5.579296> speed <1772.911776> / animSpeed;
	turn lshin to y-axis <0.0> speed <8.264109> / animSpeed;
	turn lshin to z-axis <0.0> speed <24.948077> / animSpeed;
	turn lthigh to x-axis <2.615008> speed <4194.250293> / animSpeed;
	turn lthigh to y-axis <0.0> speed <4393.865474> / animSpeed;
	turn lthigh to z-axis <0.0> speed <2496.679345> / animSpeed;
	turn rfoot to x-axis <1.615186> speed <3489.618736> / animSpeed;
	turn rfoot to y-axis <0.0> speed <2631.997773> / animSpeed;
	turn rfoot to z-axis <0.0> speed <1416.212745> / animSpeed;
	turn rknee to x-axis <1.681849> speed <3298.548250> / animSpeed;
	turn rknee to y-axis <0.0> speed <11.810490> / animSpeed;
	turn rknee to z-axis <0.0> speed <18.336451> / animSpeed;
	turn rshin to x-axis <0.0> speed <1457.471869> / animSpeed;
	turn rshin to y-axis <0.0> speed <6.510062> / animSpeed;
	turn rshin to z-axis <0.0> speed <23.274740> / animSpeed;
	turn rthigh to x-axis <-1.127649> speed <4242.805595> / animSpeed;
	turn rthigh to y-axis <0.0> speed <4601.755942> / animSpeed;
	turn rthigh to z-axis <0.0> speed <2368.175825> / animSpeed;
	turn tail to y-axis <0.0> speed <389.880474> / animSpeed;
	turn tail to z-axis <0.0> speed <42.415603> / animSpeed;
}
