// For C:\Users\Peti\Downloads\raptor_death_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5))
//#define DEATHSCALE 100 \Higher values are bigger, 100 is default
//static-var DEATHAMPLIDUTE; \Higher values are bigger, 100 is default

static-var DEATHSPEEDPTAQ;
//use call-script DeathAnim(); from Killed()
DeathAnimPtaq() {// For C:\Users\Peti\Downloads\raptor_death_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	signal SIGNAL_MOVE;
	call-script StopWalking();
	turn aimy1 to y-axis <0> speed <120>;
		if (TRUE) { //Frame:3
		DEATHSPEEDPTAQ = 3;
			move head to x-axis (((([0.215508] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([6.465226] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.22//Failed to find previous position for boneheadaxislocation0
			move head to z-axis (((([-9.852928] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([295.587845] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-9.85//Failed to find previous position for boneheadaxislocation1
			move head to y-axis (((([0.822275] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([24.668237] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.82//Failed to find previous position for boneheadaxislocation2
			turn head to x-axis ((<17.437032> *DEATHAMPLIDUTE)/100) speed ((<467.318326> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-15.58
			turn head to z-axis ((<2.380987> *DEATHAMPLIDUTE)/100) speed ((<8.618506> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.29
			turn head to y-axis ((<3.303111> *DEATHAMPLIDUTE)/100) speed ((<99.093345> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.30
			turn lfoot to x-axis ((<10.398518> *DEATHAMPLIDUTE)/100) speed ((<311.955535> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.40
			turn lfoot to z-axis ((<7.518241> *DEATHAMPLIDUTE)/100) speed ((<225.547232> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.52
			turn lfoot to y-axis ((<1.542553> *DEATHAMPLIDUTE)/100) speed ((<46.276596> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.54
			turn lknee to x-axis ((<11.804953> *DEATHAMPLIDUTE)/100) speed ((<354.148598> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.80
			turn lshin to x-axis ((<0.237261> *DEATHAMPLIDUTE)/100) speed ((<7.117843> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.24
			turn lthigh to x-axis ((<-5.375080> *DEATHAMPLIDUTE)/100) speed ((<161.252382> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.38
			turn lthigh to z-axis ((<-7.897132> *DEATHAMPLIDUTE)/100) speed ((<236.913965> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.90
			turn lthigh to y-axis ((<2.692402> *DEATHAMPLIDUTE)/100) speed ((<80.772056> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.69
			turn rfoot to x-axis ((<14.470543> *DEATHAMPLIDUTE)/100) speed ((<417.434488> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-13.91
			turn rfoot to z-axis ((<-3.871269> *DEATHAMPLIDUTE)/100) speed ((<116.138078> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.87
			turn rfoot to y-axis ((<0.682048> *DEATHAMPLIDUTE)/100) speed ((<20.461444> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.68
			turn rknee to x-axis ((<-29.871785> *DEATHAMPLIDUTE)/100) speed ((<904.707405> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=30.16
			turn rshin to x-axis ((<14.539979> *DEATHAMPLIDUTE)/100) speed ((<433.866056> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-14.46
			turn rthigh to x-axis ((<1.490916> *DEATHAMPLIDUTE)/100) speed ((<52.040749> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.73
			turn rthigh to z-axis ((<3.707690> *DEATHAMPLIDUTE)/100) speed ((<111.230689> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.71
			turn rthigh to y-axis ((<-0.716085> *DEATHAMPLIDUTE)/100) speed ((<21.482564> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.72
			turn tail to x-axis ((<-6.204690> *DEATHAMPLIDUTE)/100) speed ((<186.140695> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.20
			turn tail to z-axis ((<-0.120991> *DEATHAMPLIDUTE)/100) speed ((<3.629729> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.12
			turn tail to y-axis ((<0.694459> *DEATHAMPLIDUTE)/100) speed ((<71.337066> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.38
		//sleep ((33*DEATHSPEEDPTAQ) -1);
		sleep ((33*DEATHSPEEDPTAQ) -1);
		signal SIGNAL_MOVE;
		}
		if (TRUE) { //Frame:4
		DEATHSPEEDPTAQ = 1;
			move head to y-axis (((([-0.275233] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([32.925235] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.10
			turn head to x-axis ((<18.512094> *DEATHAMPLIDUTE)/100) speed ((<32.251846> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.08
			turn head to z-axis ((<2.514515> *DEATHAMPLIDUTE)/100) speed ((<4.005848> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.13
			turn head to y-axis ((<3.759815> *DEATHAMPLIDUTE)/100) speed ((<13.701108> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.46
			turn lfoot to x-axis ((<14.388963> *DEATHAMPLIDUTE)/100) speed ((<119.713349> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.99
			turn lfoot to z-axis ((<10.686792> *DEATHAMPLIDUTE)/100) speed ((<95.056537> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.17
			turn lfoot to y-axis ((<1.247136> *DEATHAMPLIDUTE)/100) speed ((<8.862516> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.30
			turn lknee to x-axis ((<14.561028> *DEATHAMPLIDUTE)/100) speed ((<82.682232> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.76
			turn lshin to x-axis ((<1.001598> *DEATHAMPLIDUTE)/100) speed ((<22.930110> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.76
			turn lthigh to x-axis ((<-6.976983> *DEATHAMPLIDUTE)/100) speed ((<48.057091> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.60
			turn lthigh to z-axis ((<-10.900110> *DEATHAMPLIDUTE)/100) speed ((<90.089341> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.00
			turn lthigh to y-axis ((<2.851305> *DEATHAMPLIDUTE)/100) speed ((<4.767079> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.16
			turn rfoot to x-axis ((<17.812990> *DEATHAMPLIDUTE)/100) speed ((<100.273410> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.34
			turn rfoot to z-axis ((<-4.981614> *DEATHAMPLIDUTE)/100) speed ((<33.310337> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.11
			turn rfoot to y-axis ((<1.042337> *DEATHAMPLIDUTE)/100) speed ((<10.808664> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.36
			turn rknee to x-axis ((<-43.835434> *DEATHAMPLIDUTE)/100) speed ((<418.909470> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=13.96
			turn rshin to x-axis ((<22.435375> *DEATHAMPLIDUTE)/100) speed ((<236.861893> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.90
			turn rthigh to x-axis ((<4.166721> *DEATHAMPLIDUTE)/100) speed ((<80.274171> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.68
			turn rthigh to z-axis ((<4.684070> *DEATHAMPLIDUTE)/100) speed ((<29.291420> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.98
			turn rthigh to y-axis ((<-1.283467> *DEATHAMPLIDUTE)/100) speed ((<17.021434> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.57
			turn tail to x-axis ((<-8.272920> *DEATHAMPLIDUTE)/100) speed ((<62.046898> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.07
			turn tail to y-axis ((<-0.098175> *DEATHAMPLIDUTE)/100) speed ((<23.779019> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.79
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:5
		DEATHSPEEDPTAQ = 1;
			move body to x-axis (((([-0.220614] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([6.618435] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.22
			move body to z-axis (((([-8.953876] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([268.616295] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-8.95
			move body to y-axis (((([6.589003] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([197.670078] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.59
			turn head to x-axis ((<17.068438> *DEATHAMPLIDUTE)/100) speed ((<43.309683> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.44
			turn head to y-axis ((<3.160448> *DEATHAMPLIDUTE)/100) speed ((<17.981024> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.60
			turn lfoot to x-axis ((<18.585571> *DEATHAMPLIDUTE)/100) speed ((<125.898247> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.20
			turn lfoot to z-axis ((<14.249051> *DEATHAMPLIDUTE)/100) speed ((<106.867761> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.56
			turn lfoot to y-axis ((<0.283872> *DEATHAMPLIDUTE)/100) speed ((<28.897915> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.96
			turn lknee to x-axis ((<16.714197> *DEATHAMPLIDUTE)/100) speed ((<64.595080> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.15
			turn lshin to x-axis ((<2.093658> *DEATHAMPLIDUTE)/100) speed ((<32.761776> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.09
			turn lthigh to x-axis ((<-8.434144> *DEATHAMPLIDUTE)/100) speed ((<43.714833> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.46
			turn lthigh to z-axis ((<-14.073437> *DEATHAMPLIDUTE)/100) speed ((<95.199791> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.17
			turn rfoot to x-axis ((<20.103267> *DEATHAMPLIDUTE)/100) speed ((<68.708305> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.29
			turn rfoot to z-axis ((<-5.998347> *DEATHAMPLIDUTE)/100) speed ((<30.501990> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.02
			turn rfoot to y-axis ((<1.432483> *DEATHAMPLIDUTE)/100) speed ((<11.704385> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.39
			turn rknee to x-axis ((<-61.354913> *DEATHAMPLIDUTE)/100) speed ((<525.584389> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=17.52
			turn rshin to x-axis ((<33.368445> *DEATHAMPLIDUTE)/100) speed ((<327.992104> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.93
			turn rthigh to x-axis ((<8.387362> *DEATHAMPLIDUTE)/100) speed ((<126.619221> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.22
			turn rthigh to z-axis ((<5.578361> *DEATHAMPLIDUTE)/100) speed ((<26.828723> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.89
			turn rthigh to y-axis ((<-2.104993> *DEATHAMPLIDUTE)/100) speed ((<24.645786> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.82
			turn tail to x-axis ((<-10.469271> *DEATHAMPLIDUTE)/100) speed ((<65.890545> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.20
			turn tail to z-axis ((<-0.742678> *DEATHAMPLIDUTE)/100) speed ((<17.440716> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.58
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:7
		DEATHSPEEDPTAQ = 2;
			move body to x-axis (((([-0.970310] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([22.490863] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.75
			move body to z-axis (((([-12.780678] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([114.804039] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.83
			move body to y-axis (((([3.711570] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([86.322985] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.88
			move head to z-axis (((([-4.548446] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([159.134474] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.30
			turn head to x-axis ((<14.181124> *DEATHAMPLIDUTE)/100) speed ((<86.619417> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.89
			turn head to z-axis ((<2.217785> *DEATHAMPLIDUTE)/100) speed ((<5.934600> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.20
			turn head to y-axis ((<1.961713> *DEATHAMPLIDUTE)/100) speed ((<35.962054> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.20
			turn lfoot to x-axis ((<17.002224> *DEATHAMPLIDUTE)/100) speed ((<47.500414> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.58
			turn lfoot to z-axis ((<15.202847> *DEATHAMPLIDUTE)/100) speed ((<28.613874> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.95
			turn lfoot to y-axis ((<3.635318> *DEATHAMPLIDUTE)/100) speed ((<100.543370> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.35
			turn lknee to x-axis ((<15.894923> *DEATHAMPLIDUTE)/100) speed ((<24.578231> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.82
			turn lknee to z-axis ((<5.436792> *DEATHAMPLIDUTE)/100) speed ((<163.260193> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.44
			turn lknee to y-axis ((<-5.432801> *DEATHAMPLIDUTE)/100) speed ((<162.845433> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.43
			turn lshin to x-axis ((<0.232251> *DEATHAMPLIDUTE)/100) speed ((<55.842201> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.86
			turn lthigh to x-axis ((<-10.410918> *DEATHAMPLIDUTE)/100) speed ((<59.303237> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.98
			turn lthigh to z-axis ((<-18.302807> *DEATHAMPLIDUTE)/100) speed ((<126.881103> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.23
			turn lthigh to y-axis ((<5.184412> *DEATHAMPLIDUTE)/100) speed ((<72.938589> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.43
			turn rfoot to x-axis ((<25.476860> *DEATHAMPLIDUTE)/100) speed ((<161.207798> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.37
			turn rfoot to z-axis ((<-0.785964> *DEATHAMPLIDUTE)/100) speed ((<156.371485> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.21
			turn rfoot to y-axis ((<-5.391582> *DEATHAMPLIDUTE)/100) speed ((<204.721948> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.82
			turn rknee to x-axis ((<-53.283576> *DEATHAMPLIDUTE)/100) speed ((<242.140110> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-8.07
			turn rknee to z-axis ((<5.714095> *DEATHAMPLIDUTE)/100) speed ((<171.265321> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.71
			turn rknee to y-axis ((<8.337550> *DEATHAMPLIDUTE)/100) speed ((<249.904443> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.33
			turn rshin to x-axis ((<28.621549> *DEATHAMPLIDUTE)/100) speed ((<142.406883> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.75
			turn rshin to z-axis ((<-1.143040> *DEATHAMPLIDUTE)/100) speed ((<34.295803> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.14
			turn rshin to y-axis ((<-0.115279> *DEATHAMPLIDUTE)/100) speed ((<3.428263> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.11
			turn rthigh to x-axis ((<-0.602710> *DEATHAMPLIDUTE)/100) speed ((<269.702179> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.99
			turn rthigh to z-axis ((<2.580390> *DEATHAMPLIDUTE)/100) speed ((<89.939120> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.00
			turn rthigh to y-axis ((<-5.881801> *DEATHAMPLIDUTE)/100) speed ((<113.304252> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.78
			turn tail to x-axis ((<-14.861973> *DEATHAMPLIDUTE)/100) speed ((<131.781038> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.39
			turn tail to z-axis ((<-1.905393> *DEATHAMPLIDUTE)/100) speed ((<34.881432> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.16
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:8
		DEATHSPEEDPTAQ = 1;
			turn head to x-axis ((<11.895466> *DEATHAMPLIDUTE)/100) speed ((<68.569738> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.29
			turn head to y-axis ((<1.362345> *DEATHAMPLIDUTE)/100) speed ((<17.981024> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.60
			turn lfoot to x-axis ((<15.886728> *DEATHAMPLIDUTE)/100) speed ((<33.464887> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.12
			turn lfoot to z-axis ((<15.915707> *DEATHAMPLIDUTE)/100) speed ((<21.385800> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.71
			turn lfoot to y-axis ((<5.306775> *DEATHAMPLIDUTE)/100) speed ((<50.143723> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.67
			turn lknee to x-axis ((<16.583860> *DEATHAMPLIDUTE)/100) speed ((<20.668118> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.69
			turn lknee to z-axis ((<8.178197> *DEATHAMPLIDUTE)/100) speed ((<82.242146> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.74
			turn lknee to y-axis ((<-8.083848> *DEATHAMPLIDUTE)/100) speed ((<79.531410> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.65
			turn lshin to x-axis ((<-1.271550> *DEATHAMPLIDUTE)/100) speed ((<45.114038> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.50
			turn lthigh to x-axis ((<-11.792352> *DEATHAMPLIDUTE)/100) speed ((<41.443018> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.38
			turn lthigh to z-axis ((<-20.701853> *DEATHAMPLIDUTE)/100) speed ((<71.971377> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.40
			turn lthigh to y-axis ((<6.045672> *DEATHAMPLIDUTE)/100) speed ((<25.837786> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.86
			turn rfoot to x-axis ((<28.065802> *DEATHAMPLIDUTE)/100) speed ((<77.668267> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.59
			turn rfoot to z-axis ((<2.290394> *DEATHAMPLIDUTE)/100) speed ((<92.290741> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.08
			turn rfoot to y-axis ((<-8.757161> *DEATHAMPLIDUTE)/100) speed ((<100.967387> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.37
			turn rknee to x-axis ((<-47.537099> *DEATHAMPLIDUTE)/100) speed ((<172.394316> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.75
			turn rknee to z-axis ((<7.432993> *DEATHAMPLIDUTE)/100) speed ((<51.566959> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.72
			turn rknee to y-axis ((<10.667867> *DEATHAMPLIDUTE)/100) speed ((<69.909488> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.33
			turn rshin to x-axis ((<25.395804> *DEATHAMPLIDUTE)/100) speed ((<96.772340> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.23
			turn rshin to z-axis ((<-1.669798> *DEATHAMPLIDUTE)/100) speed ((<15.802742> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.53
			turn rshin to y-axis ((<-0.281159> *DEATHAMPLIDUTE)/100) speed ((<4.976409> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.17
			turn rthigh to x-axis ((<-5.853753> *DEATHAMPLIDUTE)/100) speed ((<157.531264> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.25
			turn rthigh to z-axis ((<0.765262> *DEATHAMPLIDUTE)/100) speed ((<54.453861> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.82
			turn rthigh to y-axis ((<-7.412972> *DEATHAMPLIDUTE)/100) speed ((<45.935140> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.53
			turn tail to x-axis ((<-17.058324> *DEATHAMPLIDUTE)/100) speed ((<65.890545> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.20
			turn tail to z-axis ((<-2.486750> *DEATHAMPLIDUTE)/100) speed ((<17.440713> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.58
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:11
		DEATHSPEEDPTAQ = 3;
			move body to x-axis (((([-2.373288] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([42.089347] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.40
			move body to z-axis (((([-19.628941] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([205.447884] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.85
			move body to y-axis (((([-3.784833] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([224.892082] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.50
			move head to z-axis (((([-2.992519] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([46.677797] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.56
			turn head to x-axis ((<5.038492> *DEATHAMPLIDUTE)/100) speed ((<205.709213> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.86
			turn head to z-axis ((<1.822145> *DEATHAMPLIDUTE)/100) speed ((<8.901903> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.30
			turn head to y-axis ((<-0.435758> *DEATHAMPLIDUTE)/100) speed ((<53.943079> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.80
			turn lfoot to x-axis ((<-1.121795> *DEATHAMPLIDUTE)/100) speed ((<510.255677> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=17.01
			turn lfoot to z-axis ((<23.469525> *DEATHAMPLIDUTE)/100) speed ((<226.614561> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.55
			turn lfoot to y-axis ((<14.324051> *DEATHAMPLIDUTE)/100) speed ((<270.518265> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.02
			turn lknee to x-axis ((<-8.500687> *DEATHAMPLIDUTE)/100) speed ((<752.536403> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=25.08
			turn lknee to z-axis ((<15.732315> *DEATHAMPLIDUTE)/100) speed ((<226.623525> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.55
			turn lshin to x-axis ((<2.543340> *DEATHAMPLIDUTE)/100) speed ((<114.446709> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.81
			turn lthigh to x-axis ((<-1.417383> *DEATHAMPLIDUTE)/100) speed ((<311.249076> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.37
			turn lthigh to z-axis ((<-34.070493> *DEATHAMPLIDUTE)/100) speed ((<401.059214> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=13.37
			turn lthigh to y-axis ((<13.324660> *DEATHAMPLIDUTE)/100) speed ((<218.369656> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.28
			turn rfoot to x-axis ((<36.474344> *DEATHAMPLIDUTE)/100) speed ((<252.256252> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-8.41
			turn rfoot to z-axis ((<14.540375> *DEATHAMPLIDUTE)/100) speed ((<367.499423> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.25
			turn rfoot to y-axis ((<-19.248045> *DEATHAMPLIDUTE)/100) speed ((<314.726511> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.49
			turn rknee to x-axis ((<-37.667038> *DEATHAMPLIDUTE)/100) speed ((<296.101814> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-9.87
			turn rknee to z-axis ((<11.274810> *DEATHAMPLIDUTE)/100) speed ((<115.254499> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.84
			turn rknee to y-axis ((<14.683235> *DEATHAMPLIDUTE)/100) speed ((<120.461050> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.02
			turn rshin to x-axis ((<17.730985> *DEATHAMPLIDUTE)/100) speed ((<229.944585> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.66
			turn rshin to z-axis ((<-3.172349> *DEATHAMPLIDUTE)/100) speed ((<45.076543> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.50
			turn rshin to y-axis ((<-1.045848> *DEATHAMPLIDUTE)/100) speed ((<22.940657> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.76
			turn rthigh to x-axis ((<-17.787640> *DEATHAMPLIDUTE)/100) speed ((<358.016613> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=11.93
			turn rthigh to z-axis ((<-4.853617> *DEATHAMPLIDUTE)/100) speed ((<168.566360> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.62
			turn rthigh to y-axis ((<-11.933742> *DEATHAMPLIDUTE)/100) speed ((<135.623071> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.52
			turn tail to x-axis ((<5.549416> *DEATHAMPLIDUTE)/100) speed ((<678.232188> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-22.61
			turn tail to z-axis ((<-0.474934> *DEATHAMPLIDUTE)/100) speed ((<60.354480> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.01
			turn tail to y-axis ((<4.749024> *DEATHAMPLIDUTE)/100) speed ((<143.839691> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.79
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:13
		DEATHSPEEDPTAQ = 2;
			move body to x-axis (((([-1.970684] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([12.078112] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.40
			move body to z-axis (((([-20.287838] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([19.766922] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.66
			move body to y-axis (((([-8.870679] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([152.575378] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.09
			turn body to x-axis ((<0.142197> *DEATHAMPLIDUTE)/100) speed ((<4.265917> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.14
			turn body to z-axis ((<0.586428> *DEATHAMPLIDUTE)/100) speed ((<17.592836> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.59
			turn body to y-axis ((<1.289704> *DEATHAMPLIDUTE)/100) speed ((<38.691119> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.29
			move head to x-axis (((([-0.066417] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([7.521461] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.25
			move head to z-axis (((([-1.808644] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([35.516249] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.18
			move head to y-axis (((([0.050978] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([9.786329] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.33
			turn head to x-axis ((<2.162288> *DEATHAMPLIDUTE)/100) speed ((<86.286138> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.88
			turn head to z-axis ((<3.148171> *DEATHAMPLIDUTE)/100) speed ((<39.780785> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.33
			turn head to y-axis ((<2.779239> *DEATHAMPLIDUTE)/100) speed ((<96.449910> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.21
			turn lfoot to x-axis ((<1.644590> *DEATHAMPLIDUTE)/100) speed ((<82.991530> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.77
			turn lfoot to z-axis ((<24.292934> *DEATHAMPLIDUTE)/100) speed ((<24.702250> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.82
			turn lfoot to y-axis ((<18.367787> *DEATHAMPLIDUTE)/100) speed ((<121.312100> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.04
			turn lknee to x-axis ((<8.649358> *DEATHAMPLIDUTE)/100) speed ((<514.501348> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-17.15
			turn lknee to z-axis ((<20.854632> *DEATHAMPLIDUTE)/100) speed ((<153.669523> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.12
			turn lknee to y-axis ((<-16.178842> *DEATHAMPLIDUTE)/100) speed ((<244.334829> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-8.14
			turn lshin to x-axis ((<-6.368086> *DEATHAMPLIDUTE)/100) speed ((<267.342778> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.91
			turn lthigh to x-axis ((<-10.158182> *DEATHAMPLIDUTE)/100) speed ((<262.223959> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.74
			turn lthigh to z-axis ((<-39.229161> *DEATHAMPLIDUTE)/100) speed ((<154.760031> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.16
			turn lthigh to y-axis ((<11.966017> *DEATHAMPLIDUTE)/100) speed ((<40.759299> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.36
			turn rfoot to x-axis ((<43.756323> *DEATHAMPLIDUTE)/100) speed ((<218.459366> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.28
			turn rfoot to z-axis ((<17.587112> *DEATHAMPLIDUTE)/100) speed ((<91.402121> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.05
			turn rfoot to y-axis ((<-23.509149> *DEATHAMPLIDUTE)/100) speed ((<127.833120> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.26
			turn rknee to x-axis ((<-22.048276> *DEATHAMPLIDUTE)/100) speed ((<468.562879> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-15.62
			turn rknee to y-axis ((<12.523126> *DEATHAMPLIDUTE)/100) speed ((<64.803264> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.16
			turn rshin to x-axis ((<1.505640> *DEATHAMPLIDUTE)/100) speed ((<486.760356> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=16.23
			turn rshin to z-axis ((<-4.041368> *DEATHAMPLIDUTE)/100) speed ((<26.070552> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.87
			turn rshin to y-axis ((<-2.590896> *DEATHAMPLIDUTE)/100) speed ((<46.351447> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.55
			turn rthigh to x-axis ((<-25.352144> *DEATHAMPLIDUTE)/100) speed ((<226.935135> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.56
			turn rthigh to z-axis ((<-6.994625> *DEATHAMPLIDUTE)/100) speed ((<64.230245> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.14
			turn rthigh to y-axis ((<-12.522963> *DEATHAMPLIDUTE)/100) speed ((<17.676649> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.59
			turn tail to x-axis ((<19.384806> *DEATHAMPLIDUTE)/100) speed ((<415.061712> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-13.84
			turn tail to z-axis ((<-3.120358> *DEATHAMPLIDUTE)/100) speed ((<79.362709> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.65
			turn tail to y-axis ((<2.513582> *DEATHAMPLIDUTE)/100) speed ((<67.063252> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.24
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:15
		DEATHSPEEDPTAQ = 2;
			turn body to x-axis ((<0.497690> *DEATHAMPLIDUTE)/100) speed ((<10.664791> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.36
			turn body to z-axis ((<2.052497> *DEATHAMPLIDUTE)/100) speed ((<43.982087> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.47
			turn body to y-axis ((<4.513964> *DEATHAMPLIDUTE)/100) speed ((<96.727789> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.22
			move head to x-axis (((([0.315649] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([11.461956] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.38
			move head to z-axis (((([-0.573176] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([37.064055] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.24
			move head to y-axis (((([-0.248741] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([8.991561] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.30
			turn head to x-axis ((<-0.663976> *DEATHAMPLIDUTE)/100) speed ((<84.787911> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.83
			turn head to z-axis ((<4.550211> *DEATHAMPLIDUTE)/100) speed ((<42.061174> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.40
			turn head to y-axis ((<6.826491> *DEATHAMPLIDUTE)/100) speed ((<121.417549> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.05
			turn lfoot to x-axis ((<4.737414> *DEATHAMPLIDUTE)/100) speed ((<92.784715> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.09
			turn lfoot to z-axis ((<27.451063> *DEATHAMPLIDUTE)/100) speed ((<94.743876> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.16
			turn lfoot to y-axis ((<21.638184> *DEATHAMPLIDUTE)/100) speed ((<98.111911> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.27
			turn lknee to x-axis ((<14.205175> *DEATHAMPLIDUTE)/100) speed ((<166.674502> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.56
			turn lknee to z-axis ((<26.384642> *DEATHAMPLIDUTE)/100) speed ((<165.900292> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.53
			turn lknee to y-axis ((<-21.758942> *DEATHAMPLIDUTE)/100) speed ((<167.403019> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.58
			turn lshin to x-axis ((<-9.536162> *DEATHAMPLIDUTE)/100) speed ((<95.042296> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.17
			turn lthigh to x-axis ((<-13.478840> *DEATHAMPLIDUTE)/100) speed ((<99.619760> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.32
			turn lthigh to z-axis ((<-48.079092> *DEATHAMPLIDUTE)/100) speed ((<265.497922> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.85
			turn lthigh to y-axis ((<9.416459> *DEATHAMPLIDUTE)/100) speed ((<76.486729> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.55
			turn rfoot to x-axis ((<48.225015> *DEATHAMPLIDUTE)/100) speed ((<134.060767> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.47
			turn rfoot to z-axis ((<23.356120> *DEATHAMPLIDUTE)/100) speed ((<173.070249> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.77
			turn rfoot to y-axis ((<-29.347817> *DEATHAMPLIDUTE)/100) speed ((<175.160031> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.84
			turn rknee to x-axis ((<-12.344584> *DEATHAMPLIDUTE)/100) speed ((<291.110748> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-9.70
			turn rknee to z-axis ((<10.918455> *DEATHAMPLIDUTE)/100) speed ((<8.557604> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.29
			turn rknee to y-axis ((<10.537674> *DEATHAMPLIDUTE)/100) speed ((<59.563570> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.99
			turn rshin to x-axis ((<-15.189507> *DEATHAMPLIDUTE)/100) speed ((<500.854415> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=16.70
			turn rshin to z-axis ((<-5.261485> *DEATHAMPLIDUTE)/100) speed ((<36.603505> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.22
			turn rshin to y-axis ((<-4.769167> *DEATHAMPLIDUTE)/100) speed ((<65.348127> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.18
			turn rthigh to x-axis ((<-24.770086> *DEATHAMPLIDUTE)/100) speed ((<17.461754> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.58
			turn rthigh to z-axis ((<-9.507437> *DEATHAMPLIDUTE)/100) speed ((<75.384362> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.51
			turn rthigh to y-axis ((<-14.535536> *DEATHAMPLIDUTE)/100) speed ((<60.377173> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.01
			turn tail to x-axis ((<22.449394> *DEATHAMPLIDUTE)/100) speed ((<91.937642> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.06
			turn tail to z-axis ((<-2.786057> *DEATHAMPLIDUTE)/100) speed ((<10.029012> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.33
			turn tail to y-axis ((<3.422606> *DEATHAMPLIDUTE)/100) speed ((<27.270711> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.91
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:17
		DEATHSPEEDPTAQ = 2;
			move body to x-axis (((([1.458268] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([102.868577] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.43
			move body to z-axis (((([-18.840889] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([43.408470] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.45
			move body to y-axis (((([-15.090000] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([186.579638] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.22
			turn body to x-axis ((<0.853183> *DEATHAMPLIDUTE)/100) speed ((<10.664793> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.36
			turn body to z-axis ((<3.518567> *DEATHAMPLIDUTE)/100) speed ((<43.982094> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.47
			turn body to y-axis ((<7.738224> *DEATHAMPLIDUTE)/100) speed ((<96.727799> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.22
			turn head to x-axis ((<-4.459112> *DEATHAMPLIDUTE)/100) speed ((<113.854066> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.80
			turn head to z-axis ((<5.249654> *DEATHAMPLIDUTE)/100) speed ((<20.983289> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.70
			turn head to y-axis ((<5.424794> *DEATHAMPLIDUTE)/100) speed ((<42.050909> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.40
			turn lfoot to x-axis ((<8.726163> *DEATHAMPLIDUTE)/100) speed ((<119.662468> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.99
			turn lfoot to z-axis ((<31.988696> *DEATHAMPLIDUTE)/100) speed ((<136.128983> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.54
			turn lfoot to y-axis ((<24.646526> *DEATHAMPLIDUTE)/100) speed ((<90.250244> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.01
			turn lknee to x-axis ((<17.124532> *DEATHAMPLIDUTE)/100) speed ((<87.580732> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.92
			turn lknee to z-axis ((<31.804564> *DEATHAMPLIDUTE)/100) speed ((<162.597673> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.42
			turn lknee to y-axis ((<-26.462591> *DEATHAMPLIDUTE)/100) speed ((<141.109471> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.70
			turn lshin to x-axis ((<-11.711976> *DEATHAMPLIDUTE)/100) speed ((<65.274393> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.18
			turn lthigh to x-axis ((<-14.837669> *DEATHAMPLIDUTE)/100) speed ((<40.764857> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.36
			turn lthigh to z-axis ((<-58.349302> *DEATHAMPLIDUTE)/100) speed ((<308.106316> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=10.27
			turn lthigh to y-axis ((<5.503976> *DEATHAMPLIDUTE)/100) speed ((<117.374491> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.91
			turn rfoot to x-axis ((<55.852772> *DEATHAMPLIDUTE)/100) speed ((<228.832716> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.63
			turn rfoot to z-axis ((<37.435280> *DEATHAMPLIDUTE)/100) speed ((<422.374783> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-14.08
			turn rfoot to y-axis ((<-41.013749> *DEATHAMPLIDUTE)/100) speed ((<349.977971> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.67
			turn rknee to x-axis ((<-12.237788> *DEATHAMPLIDUTE)/100) speed ((<3.203880> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.11
			turn rknee to z-axis ((<9.841144> *DEATHAMPLIDUTE)/100) speed ((<32.319337> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.08
			turn rknee to y-axis ((<9.907325> *DEATHAMPLIDUTE)/100) speed ((<18.910463> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.63
			turn rshin to x-axis ((<-35.799453> *DEATHAMPLIDUTE)/100) speed ((<618.298367> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=20.61
			turn rshin to z-axis ((<-7.576643> *DEATHAMPLIDUTE)/100) speed ((<69.454764> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.32
			turn rshin to y-axis ((<-8.528891> *DEATHAMPLIDUTE)/100) speed ((<112.791712> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.76
			turn rthigh to x-axis ((<-16.159335> *DEATHAMPLIDUTE)/100) speed ((<258.322536> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-8.61
			turn rthigh to z-axis ((<-10.776515> *DEATHAMPLIDUTE)/100) speed ((<38.072320> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.27
			turn rthigh to y-axis ((<-15.992466> *DEATHAMPLIDUTE)/100) speed ((<43.707917> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.46
			turn tail to x-axis ((<25.513982> *DEATHAMPLIDUTE)/100) speed ((<91.937642> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.06
			turn tail to z-axis ((<-2.451757> *DEATHAMPLIDUTE)/100) speed ((<10.029006> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.33
			turn tail to y-axis ((<4.331629> *DEATHAMPLIDUTE)/100) speed ((<27.270704> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.91
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:18
		DEATHSPEEDPTAQ = 1;
			turn body to x-axis ((<1.325040> *DEATHAMPLIDUTE)/100) speed ((<14.155713> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.47
			turn body to z-axis ((<3.365067> *DEATHAMPLIDUTE)/100) speed ((<4.605012> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.15
			turn body to y-axis ((<9.120340> *DEATHAMPLIDUTE)/100) speed ((<41.463483> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.38
			move head to x-axis (((([0.184299] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([3.940495] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.13
			move head to z-axis (((([-3.455219] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([86.461287] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.88
			turn head to x-axis ((<-6.356679> *DEATHAMPLIDUTE)/100) speed ((<56.927036> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.90
			turn head to z-axis ((<5.599375> *DEATHAMPLIDUTE)/100) speed ((<10.491644> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.35
			turn head to y-axis ((<4.723946> *DEATHAMPLIDUTE)/100) speed ((<21.025448> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.70
			turn lfoot to x-axis ((<-0.434445> *DEATHAMPLIDUTE)/100) speed ((<274.818238> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.16
			turn lfoot to z-axis ((<38.774304> *DEATHAMPLIDUTE)/100) speed ((<203.568256> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.79
			turn lfoot to y-axis ((<24.382611> *DEATHAMPLIDUTE)/100) speed ((<7.917453> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.26
			turn lknee to x-axis ((<19.914651> *DEATHAMPLIDUTE)/100) speed ((<83.703558> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.79
			turn lknee to z-axis ((<34.869236> *DEATHAMPLIDUTE)/100) speed ((<91.940152> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.06
			turn lknee to y-axis ((<-29.877536> *DEATHAMPLIDUTE)/100) speed ((<102.448330> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.41
			turn lshin to x-axis ((<-10.376667> *DEATHAMPLIDUTE)/100) speed ((<40.059264> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.34
			turn lthigh to x-axis ((<-10.815174> *DEATHAMPLIDUTE)/100) speed ((<120.674843> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.02
			turn lthigh to z-axis ((<-64.611465> *DEATHAMPLIDUTE)/100) speed ((<187.864900> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.26
			turn lthigh to y-axis ((<-0.171938> *DEATHAMPLIDUTE)/100) speed ((<170.277418> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.68
			turn rfoot to x-axis ((<63.079891> *DEATHAMPLIDUTE)/100) speed ((<216.813564> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.23
			turn rfoot to z-axis ((<42.320904> *DEATHAMPLIDUTE)/100) speed ((<146.568722> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.89
			turn rfoot to y-axis ((<-47.434650> *DEATHAMPLIDUTE)/100) speed ((<192.627010> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.42
			turn rknee to x-axis ((<-10.360073> *DEATHAMPLIDUTE)/100) speed ((<56.331464> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.88
			turn rknee to y-axis ((<9.590583> *DEATHAMPLIDUTE)/100) speed ((<9.502270> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.32
			turn rshin to x-axis ((<-43.115293> *DEATHAMPLIDUTE)/100) speed ((<219.475186> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.32
			turn rshin to z-axis ((<-9.154810> *DEATHAMPLIDUTE)/100) speed ((<47.344993> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.58
			turn rshin to y-axis ((<-10.712350> *DEATHAMPLIDUTE)/100) speed ((<65.503785> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.18
			turn rthigh to x-axis ((<-19.071942> *DEATHAMPLIDUTE)/100) speed ((<87.378234> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.91
			turn rthigh to z-axis ((<-8.740129> *DEATHAMPLIDUTE)/100) speed ((<61.091551> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.04
			turn rthigh to y-axis ((<-15.226151> *DEATHAMPLIDUTE)/100) speed ((<22.989443> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.77
			turn tail to x-axis ((<29.035312> *DEATHAMPLIDUTE)/100) speed ((<105.639889> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.52
			turn tail to z-axis ((<-2.135840> *DEATHAMPLIDUTE)/100) speed ((<9.477502> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.32
			turn tail to y-axis ((<4.561978> *DEATHAMPLIDUTE)/100) speed ((<6.910470> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.23
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:20
		DEATHSPEEDPTAQ = 2;
			move body to x-axis (((([2.354667] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([26.891963] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.90
			move body to z-axis (((([-22.903246] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([121.870708] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.06
			move body to y-axis (((([-25.146818] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([301.704540] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.06
			turn body to x-axis ((<2.268755> *DEATHAMPLIDUTE)/100) speed ((<28.311433> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.94
			turn body to z-axis ((<3.058066> *DEATHAMPLIDUTE)/100) speed ((<9.210023> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.31
			turn body to y-axis ((<11.884572> *DEATHAMPLIDUTE)/100) speed ((<82.926966> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.76
			move head to x-axis (((([0.394045] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([6.292389] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.21
			move head to z-axis (((([-1.001043] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([73.625278] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.45
			move head to y-axis (((([1.625202] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([57.013067] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.90
			turn head to x-axis ((<-16.282679> *DEATHAMPLIDUTE)/100) speed ((<297.779992> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.93
			turn head to z-axis ((<16.719492> *DEATHAMPLIDUTE)/100) speed ((<333.603510> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.12
			turn head to y-axis ((<4.077515> *DEATHAMPLIDUTE)/100) speed ((<19.392939> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.65
			turn lfoot to x-axis ((<-22.360004> *DEATHAMPLIDUTE)/100) speed ((<657.766758> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=21.93
			turn lfoot to z-axis ((<52.089379> *DEATHAMPLIDUTE)/100) speed ((<399.452241> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-13.32
			turn lfoot to y-axis ((<27.926869> *DEATHAMPLIDUTE)/100) speed ((<106.327758> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.54
			turn lknee to x-axis ((<18.943021> *DEATHAMPLIDUTE)/100) speed ((<29.148908> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.97
			turn lknee to z-axis ((<39.320426> *DEATHAMPLIDUTE)/100) speed ((<133.535697> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.45
			turn lknee to y-axis ((<-31.799486> *DEATHAMPLIDUTE)/100) speed ((<57.658510> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.92
			turn lshin to x-axis ((<-0.021807> *DEATHAMPLIDUTE)/100) speed ((<310.645802> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.35
			turn lshin to z-axis ((<-0.152139> *DEATHAMPLIDUTE)/100) speed ((<3.394168> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.11
			turn lthigh to x-axis ((<0.229776> *DEATHAMPLIDUTE)/100) speed ((<331.348511> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.04
			turn lthigh to z-axis ((<-75.040160> *DEATHAMPLIDUTE)/100) speed ((<312.860845> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=10.43
			turn lthigh to y-axis ((<-8.477721> *DEATHAMPLIDUTE)/100) speed ((<249.173502> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-8.31
			turn rfoot to x-axis ((<75.471159> *DEATHAMPLIDUTE)/100) speed ((<371.738032> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.39
			turn rfoot to z-axis ((<70.520078> *DEATHAMPLIDUTE)/100) speed ((<845.975209> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-28.20
			turn rfoot to y-axis ((<-80.070390> *DEATHAMPLIDUTE)/100) speed ((<979.072203> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-32.64
			turn rknee to x-axis ((<-10.669630> *DEATHAMPLIDUTE)/100) speed ((<9.286709> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.31
			turn rshin to x-axis ((<-52.666889> *DEATHAMPLIDUTE)/100) speed ((<286.547882> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.55
			turn rshin to z-axis ((<-12.783882> *DEATHAMPLIDUTE)/100) speed ((<108.872174> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.63
			turn rshin to y-axis ((<-15.356693> *DEATHAMPLIDUTE)/100) speed ((<139.330301> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.64
			turn rthigh to x-axis ((<-26.090848> *DEATHAMPLIDUTE)/100) speed ((<210.567168> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.02
			turn rthigh to z-axis ((<-4.179325> *DEATHAMPLIDUTE)/100) speed ((<136.824125> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.56
			turn rthigh to y-axis ((<-14.650850> *DEATHAMPLIDUTE)/100) speed ((<17.259051> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.58
			turn tail to x-axis ((<36.077971> *DEATHAMPLIDUTE)/100) speed ((<211.279778> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.04
			turn tail to z-axis ((<-1.504007> *DEATHAMPLIDUTE)/100) speed ((<18.955001> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.63
			turn tail to y-axis ((<5.022676> *DEATHAMPLIDUTE)/100) speed ((<13.820926> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.46
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:23
		DEATHSPEEDPTAQ = 3;
			move body to x-axis (((([3.240692] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([26.580741] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.89
			move body to z-axis (((([-23.522875] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([18.588867] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.62
			move body to y-axis (((([-30.994991] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([175.445194] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.85
			turn body to x-axis ((<5.079919> *DEATHAMPLIDUTE)/100) speed ((<84.334924> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.81
			turn body to z-axis ((<25.221698> *DEATHAMPLIDUTE)/100) speed ((<664.908952> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-22.16
			turn body to y-axis ((<13.147587> *DEATHAMPLIDUTE)/100) speed ((<37.890440> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.26
			move head to x-axis (((([0.184299] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([6.292382] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.21
			move head to z-axis (((([-3.455219] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([73.625278] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.45
			move head to y-axis (((([-0.275233] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([57.013068] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.90
			turn head to x-axis ((<-24.519961> *DEATHAMPLIDUTE)/100) speed ((<247.118447> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.24
			turn head to z-axis ((<15.932692> *DEATHAMPLIDUTE)/100) speed ((<23.604007> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.79
			turn head to y-axis ((<-0.653011> *DEATHAMPLIDUTE)/100) speed ((<141.915775> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.73
			turn lfoot to x-axis ((<-36.626319> *DEATHAMPLIDUTE)/100) speed ((<427.989455> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=14.27
			turn lfoot to z-axis ((<108.122578> *DEATHAMPLIDUTE)/100) speed ((<1680.995957> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-56.03
			turn lfoot to y-axis ((<74.499346> *DEATHAMPLIDUTE)/100) speed ((<1397.174293> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=46.57
			turn lknee to x-axis ((<7.445522> *DEATHAMPLIDUTE)/100) speed ((<344.924971> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=11.50
			turn lknee to z-axis ((<37.442329> *DEATHAMPLIDUTE)/100) speed ((<56.342913> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.88
			turn lknee to y-axis ((<-24.732501> *DEATHAMPLIDUTE)/100) speed ((<212.009550> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.07
			turn lshin to x-axis ((<32.451940> *DEATHAMPLIDUTE)/100) speed ((<974.212391> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-32.47
			turn lshin to z-axis ((<-1.478546> *DEATHAMPLIDUTE)/100) speed ((<39.792212> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.33
			turn lshin to y-axis ((<0.724901> *DEATHAMPLIDUTE)/100) speed ((<20.265546> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.68
			turn lthigh to x-axis ((<30.264708> *DEATHAMPLIDUTE)/100) speed ((<901.047963> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-30.03
			turn lthigh to z-axis ((<-101.354004> *DEATHAMPLIDUTE)/100) speed ((<789.415301> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=26.31
			turn lthigh to y-axis ((<1.122567> *DEATHAMPLIDUTE)/100) speed ((<288.008661> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.60
			turn rfoot to x-axis ((<76.345075> *DEATHAMPLIDUTE)/100) speed ((<26.217476> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.87
			turn rfoot to z-axis ((<26.173713> *DEATHAMPLIDUTE)/100) speed ((<1330.390923> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=44.35
			turn rfoot to y-axis ((<-60.487247> *DEATHAMPLIDUTE)/100) speed ((<587.494282> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=19.58
			turn rknee to x-axis ((<-21.473181> *DEATHAMPLIDUTE)/100) speed ((<324.106529> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=10.80
			turn rknee to z-axis ((<10.325953> *DEATHAMPLIDUTE)/100) speed ((<16.506433> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.55
			turn rknee to y-axis ((<11.662450> *DEATHAMPLIDUTE)/100) speed ((<59.952583> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.00
			turn rshin to x-axis ((<-43.446010> *DEATHAMPLIDUTE)/100) speed ((<276.626350> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-9.22
			turn rshin to y-axis ((<-15.087160> *DEATHAMPLIDUTE)/100) speed ((<8.085988> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.27
			turn rthigh to x-axis ((<-21.938919> *DEATHAMPLIDUTE)/100) speed ((<124.557857> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.15
			turn rthigh to z-axis ((<-0.996377> *DEATHAMPLIDUTE)/100) speed ((<95.488459> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.18
			turn rthigh to y-axis ((<-11.255919> *DEATHAMPLIDUTE)/100) speed ((<101.847930> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.39
			turn tail to x-axis ((<33.942652> *DEATHAMPLIDUTE)/100) speed ((<64.059559> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.14
			turn tail to z-axis ((<-1.287237> *DEATHAMPLIDUTE)/100) speed ((<6.503098> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.22
			turn tail to y-axis ((<3.806219> *DEATHAMPLIDUTE)/100) speed ((<36.493701> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.22
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:24
		DEATHSPEEDPTAQ = 1;
			turn head to x-axis ((<-25.218165> *DEATHAMPLIDUTE)/100) speed ((<20.946124> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.70
			turn head to z-axis ((<15.786591> *DEATHAMPLIDUTE)/100) speed ((<4.383035> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.15
			turn head to y-axis ((<-1.209139> *DEATHAMPLIDUTE)/100) speed ((<16.683839> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.56
			turn lfoot to z-axis ((<121.055227> *DEATHAMPLIDUTE)/100) speed ((<387.979470> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.93
			turn lfoot to y-axis ((<86.874276> *DEATHAMPLIDUTE)/100) speed ((<371.247897> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=12.37
			turn lknee to x-axis ((<10.022503> *DEATHAMPLIDUTE)/100) speed ((<77.309451> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.58
			turn lknee to z-axis ((<38.186898> *DEATHAMPLIDUTE)/100) speed ((<22.337075> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.74
			turn lknee to y-axis ((<-28.196585> *DEATHAMPLIDUTE)/100) speed ((<103.922524> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.46
			turn lshin to x-axis ((<39.959014> *DEATHAMPLIDUTE)/100) speed ((<225.212237> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.51
			turn lshin to z-axis ((<-2.437542> *DEATHAMPLIDUTE)/100) speed ((<28.769874> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.96
			turn lshin to y-axis ((<1.253163> *DEATHAMPLIDUTE)/100) speed ((<15.847840> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.53
			turn lthigh to x-axis ((<31.941841> *DEATHAMPLIDUTE)/100) speed ((<50.313974> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.68
			turn lthigh to z-axis ((<-96.772374> *DEATHAMPLIDUTE)/100) speed ((<137.448883> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.58
			turn lthigh to y-axis ((<-0.257203> *DEATHAMPLIDUTE)/100) speed ((<41.393100> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.38
			turn rfoot to x-axis ((<81.694745> *DEATHAMPLIDUTE)/100) speed ((<160.490116> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.35
			turn rfoot to z-axis ((<38.136225> *DEATHAMPLIDUTE)/100) speed ((<358.875334> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.96
			turn rfoot to y-axis ((<-75.205239> *DEATHAMPLIDUTE)/100) speed ((<441.539765> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-14.72
			turn rknee to x-axis ((<-19.952063> *DEATHAMPLIDUTE)/100) speed ((<45.633518> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.52
			turn rknee to z-axis ((<10.220101> *DEATHAMPLIDUTE)/100) speed ((<3.175551> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.11
			turn rknee to y-axis ((<11.376142> *DEATHAMPLIDUTE)/100) speed ((<8.589236> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.29
			turn rshin to x-axis ((<-47.021304> *DEATHAMPLIDUTE)/100) speed ((<107.258798> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.58
			turn rshin to z-axis ((<-13.472159> *DEATHAMPLIDUTE)/100) speed ((<20.892234> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.70
			turn rshin to y-axis ((<-17.463750> *DEATHAMPLIDUTE)/100) speed ((<71.297698> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.38
			turn rthigh to x-axis ((<-24.353586> *DEATHAMPLIDUTE)/100) speed ((<72.439996> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.41
			turn rthigh to z-axis ((<2.973458> *DEATHAMPLIDUTE)/100) speed ((<119.095027> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.97
			turn rthigh to y-axis ((<-12.059700> *DEATHAMPLIDUTE)/100) speed ((<24.113428> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.80
			turn tail to x-axis ((<33.230878> *DEATHAMPLIDUTE)/100) speed ((<21.353220> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.71
			turn tail to y-axis ((<3.400733> *DEATHAMPLIDUTE)/100) speed ((<12.164571> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.41
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:25
		DEATHSPEEDPTAQ = 1;
			move body to x-axis (((([0.483160] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([82.725950] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.76
			move body to z-axis (((([-23.823124] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([9.007473] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.30
			move body to y-axis (((([-37.769985] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([203.249817] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.77
			turn head to x-axis ((<-17.743853> *DEATHAMPLIDUTE)/100) speed ((<224.229356> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.47
			turn head to z-axis ((<16.857771> *DEATHAMPLIDUTE)/100) speed ((<32.135408> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.07
			turn head to y-axis ((<2.600558> *DEATHAMPLIDUTE)/100) speed ((<114.290908> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.81
			turn lfoot to x-axis ((<-145.074079> *DEATHAMPLIDUTE)/100) speed ((<3254.366744> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=108.48
			turn lfoot to z-axis ((<-45.123737> *DEATHAMPLIDUTE)/100) speed ((<4985.368906> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=166.18//WARNING: possible gimbal lock issue detected in frame 25 bone lfoot

			turn lfoot to y-axis ((<-77.968440> *DEATHAMPLIDUTE)/100) speed ((<4945.281467> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-164.84//WARNING: possible gimbal lock issue detected in frame 25 bone lfoot

			move lknee to x-axis (((([0.287747] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([8.632405] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.29
			move lknee to z-axis (((([0.307983] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([9.239489] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.31
			move lknee to y-axis (((([-2.048783] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([61.463499] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.05
			turn lknee to x-axis ((<10.471643> *DEATHAMPLIDUTE)/100) speed ((<13.474187> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.45
			turn lknee to z-axis ((<40.236825> *DEATHAMPLIDUTE)/100) speed ((<61.497828> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.05
			turn lknee to y-axis ((<-34.878419> *DEATHAMPLIDUTE)/100) speed ((<200.455021> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.68
			turn lshin to x-axis ((<52.750299> *DEATHAMPLIDUTE)/100) speed ((<383.738537> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.79
			turn lshin to z-axis ((<-6.736756> *DEATHAMPLIDUTE)/100) speed ((<128.976417> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.30
			turn lshin to y-axis ((<3.409636> *DEATHAMPLIDUTE)/100) speed ((<64.694193> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.16
			turn lthigh to x-axis ((<26.505814> *DEATHAMPLIDUTE)/100) speed ((<163.080790> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.44
			turn lthigh to z-axis ((<-89.478463> *DEATHAMPLIDUTE)/100) speed ((<218.817336> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.29
			turn lthigh to y-axis ((<-0.836519> *DEATHAMPLIDUTE)/100) speed ((<17.379501> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.58
			turn rfoot to x-axis ((<94.213396> *DEATHAMPLIDUTE)/100) speed ((<375.559522> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.52
			turn rfoot to z-axis ((<-105.437091> *DEATHAMPLIDUTE)/100) speed ((<4307.199458> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=143.57//WARNING: possible gimbal lock issue detected in frame 25 bone rfoot

			turn rfoot to y-axis ((<65.296233> *DEATHAMPLIDUTE)/100) speed ((<4215.044155> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=140.50//WARNING: possible gimbal lock issue detected in frame 25 bone rfoot

			turn rknee to x-axis ((<-19.026976> *DEATHAMPLIDUTE)/100) speed ((<27.752630> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.93
			turn rknee to y-axis ((<11.206141> *DEATHAMPLIDUTE)/100) speed ((<5.100025> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.17
			turn rshin to x-axis ((<-48.963362> *DEATHAMPLIDUTE)/100) speed ((<58.261753> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.94
			turn rshin to z-axis ((<-13.834371> *DEATHAMPLIDUTE)/100) speed ((<10.866353> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.36
			turn rshin to y-axis ((<-19.340681> *DEATHAMPLIDUTE)/100) speed ((<56.307926> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.88
			turn rthigh to x-axis ((<-27.274004> *DEATHAMPLIDUTE)/100) speed ((<87.612544> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.92
			turn rthigh to z-axis ((<7.068205> *DEATHAMPLIDUTE)/100) speed ((<122.842438> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.09
			turn rthigh to y-axis ((<-12.998172> *DEATHAMPLIDUTE)/100) speed ((<28.154168> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.94
			turn tail to x-axis ((<26.498740> *DEATHAMPLIDUTE)/100) speed ((<201.964152> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.73
			turn tail to z-axis ((<-1.791261> *DEATHAMPLIDUTE)/100) speed ((<17.288423> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.58
			turn tail to y-axis ((<0.478683> *DEATHAMPLIDUTE)/100) speed ((<87.661510> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.92
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:27
		DEATHSPEEDPTAQ = 2;
			move body to x-axis (((([0.651489] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([5.049869] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.17
			move body to y-axis (((([-35.568081] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([66.057129] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.20
			turn head to x-axis ((<-10.618054> *DEATHAMPLIDUTE)/100) speed ((<213.773967> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.13
			turn head to z-axis ((<18.780488> *DEATHAMPLIDUTE)/100) speed ((<57.681511> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.92
			turn head to y-axis ((<5.999969> *DEATHAMPLIDUTE)/100) speed ((<101.982355> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.40
			turn lfoot to x-axis ((<-35.233510> *DEATHAMPLIDUTE)/100) speed ((<3295.217047> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-109.84
			turn lfoot to z-axis ((<123.566728> *DEATHAMPLIDUTE)/100) speed ((<5060.713952> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-168.69//WARNING: possible gimbal lock issue detected in frame 27 bone lfoot

			turn lfoot to y-axis ((<87.640801> *DEATHAMPLIDUTE)/100) speed ((<4968.277212> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=165.61//WARNING: possible gimbal lock issue detected in frame 27 bone lfoot

			turn lknee to x-axis ((<10.331390> *DEATHAMPLIDUTE)/100) speed ((<4.207584> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.14
			turn lknee to z-axis ((<38.301867> *DEATHAMPLIDUTE)/100) speed ((<58.048753> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.93
			turn lknee to y-axis ((<-28.548724> *DEATHAMPLIDUTE)/100) speed ((<189.890853> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.33
			turn lshin to x-axis ((<39.262571> *DEATHAMPLIDUTE)/100) speed ((<404.631847> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=13.49
			turn lshin to z-axis ((<-2.477870> *DEATHAMPLIDUTE)/100) speed ((<127.766571> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.26
			turn lshin to y-axis ((<1.248544> *DEATHAMPLIDUTE)/100) speed ((<64.832754> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.16
			turn lthigh to x-axis ((<33.242715> *DEATHAMPLIDUTE)/100) speed ((<202.107022> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.74
			turn lthigh to z-axis ((<-97.785831> *DEATHAMPLIDUTE)/100) speed ((<249.221035> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.31
			turn lthigh to y-axis ((<2.192606> *DEATHAMPLIDUTE)/100) speed ((<90.873759> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.03
			turn rfoot to x-axis ((<84.698444> *DEATHAMPLIDUTE)/100) speed ((<285.448564> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.51
			turn rfoot to z-axis ((<12.115283> *DEATHAMPLIDUTE)/100) speed ((<3526.571204> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-117.55
			turn rfoot to y-axis ((<-50.428844> *DEATHAMPLIDUTE)/100) speed ((<3471.752302> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-115.73//WARNING: possible gimbal lock issue detected in frame 27 bone rfoot

			turn rknee to x-axis ((<-17.836406> *DEATHAMPLIDUTE)/100) speed ((<35.717108> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.19
			turn rknee to y-axis ((<10.991054> *DEATHAMPLIDUTE)/100) speed ((<6.452608> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.22
			turn rshin to x-axis ((<-46.773965> *DEATHAMPLIDUTE)/100) speed ((<65.681899> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.19
			turn rshin to z-axis ((<-12.921386> *DEATHAMPLIDUTE)/100) speed ((<27.389537> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.91
			turn rshin to y-axis ((<-20.890704> *DEATHAMPLIDUTE)/100) speed ((<46.500679> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.55
			turn rthigh to x-axis ((<-25.677205> *DEATHAMPLIDUTE)/100) speed ((<47.903976> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.60
			turn rthigh to z-axis ((<6.789980> *DEATHAMPLIDUTE)/100) speed ((<8.346769> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.28
			turn rthigh to y-axis ((<-9.803575> *DEATHAMPLIDUTE)/100) speed ((<95.837893> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.19
			turn tail to x-axis ((<5.654864> *DEATHAMPLIDUTE)/100) speed ((<625.316284> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=20.84
			turn tail to z-axis ((<-5.427102> *DEATHAMPLIDUTE)/100) speed ((<109.075235> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.64
			turn tail to y-axis ((<-12.173201> *DEATHAMPLIDUTE)/100) speed ((<379.556521> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.65
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:29
		DEATHSPEEDPTAQ = 2;
			move body to x-axis (((([0.455658] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([5.874942] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.20
			move body to z-axis (((([-23.922760] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([4.906597] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.16
			move body to y-axis (((([-38.870575] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([99.074821] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.30
			turn head to x-axis ((<3.059847> *DEATHAMPLIDUTE)/100) speed ((<410.337023> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-13.68
			turn head to z-axis ((<21.170928> *DEATHAMPLIDUTE)/100) speed ((<71.713196> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.39
			turn head to y-axis ((<12.997754> *DEATHAMPLIDUTE)/100) speed ((<209.933548> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=7.00
			turn lfoot to x-axis ((<-31.911702> *DEATHAMPLIDUTE)/100) speed ((<99.654236> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.32
			turn lfoot to z-axis ((<134.246166> *DEATHAMPLIDUTE)/100) speed ((<320.383137> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-10.68
			turn lfoot to y-axis ((<96.295320> *DEATHAMPLIDUTE)/100) speed ((<259.635571> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.65
			turn lknee to x-axis ((<5.281286> *DEATHAMPLIDUTE)/100) speed ((<151.503132> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.05
			turn lknee to z-axis ((<39.437536> *DEATHAMPLIDUTE)/100) speed ((<34.070076> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.14
			turn lknee to y-axis ((<-30.649733> *DEATHAMPLIDUTE)/100) speed ((<63.030266> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.10
			turn lshin to x-axis ((<50.858169> *DEATHAMPLIDUTE)/100) speed ((<347.867955> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.60
			turn lshin to z-axis ((<-6.560612> *DEATHAMPLIDUTE)/100) speed ((<122.482258> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.08
			turn lshin to y-axis ((<3.132871> *DEATHAMPLIDUTE)/100) speed ((<56.529810> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.88
			turn lthigh to x-axis ((<30.977476> *DEATHAMPLIDUTE)/100) speed ((<67.957172> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.27
			turn lthigh to z-axis ((<-97.597591> *DEATHAMPLIDUTE)/100) speed ((<5.647200> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.19
			turn lthigh to y-axis ((<4.831506> *DEATHAMPLIDUTE)/100) speed ((<79.167011> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.64
			turn rfoot to x-axis ((<90.474072> *DEATHAMPLIDUTE)/100) speed ((<173.268854> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.78
			turn rfoot to z-axis ((<-67.293681> *DEATHAMPLIDUTE)/100) speed ((<2382.268904> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=79.41
			turn rfoot to y-axis ((<27.518733> *DEATHAMPLIDUTE)/100) speed ((<2338.427312> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=77.95//WARNING: possible gimbal lock issue detected in frame 29 bone rfoot

			turn rknee to x-axis ((<-15.531283> *DEATHAMPLIDUTE)/100) speed ((<69.153668> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.31
			turn rknee to z-axis ((<9.951339> *DEATHAMPLIDUTE)/100) speed ((<3.922381> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.13
			turn rknee to y-axis ((<10.581786> *DEATHAMPLIDUTE)/100) speed ((<12.278051> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.41
			turn rshin to x-axis ((<-48.982958> *DEATHAMPLIDUTE)/100) speed ((<66.269774> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.21
			turn rshin to z-axis ((<-13.163141> *DEATHAMPLIDUTE)/100) speed ((<7.252636> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.24
			turn rshin to y-axis ((<-23.966219> *DEATHAMPLIDUTE)/100) speed ((<92.265440> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.08
			turn rthigh to x-axis ((<-29.518995> *DEATHAMPLIDUTE)/100) speed ((<115.253705> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.84
			turn rthigh to z-axis ((<10.231033> *DEATHAMPLIDUTE)/100) speed ((<103.231582> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.44
			turn rthigh to y-axis ((<-8.620187> *DEATHAMPLIDUTE)/100) speed ((<35.501650> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.18
			turn tail to x-axis ((<-14.249778> *DEATHAMPLIDUTE)/100) speed ((<597.139243> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=19.90
			turn tail to z-axis ((<-17.107184> *DEATHAMPLIDUTE)/100) speed ((<350.402446> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=11.68
			turn tail to y-axis ((<-25.357120> *DEATHAMPLIDUTE)/100) speed ((<395.517566> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-13.18
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:31
		DEATHSPEEDPTAQ = 2;
			turn head to x-axis ((<-0.928497> *DEATHAMPLIDUTE)/100) speed ((<119.650312> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.99
			turn head to z-axis ((<20.397042> *DEATHAMPLIDUTE)/100) speed ((<23.216581> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.77
			turn head to y-axis ((<10.981901> *DEATHAMPLIDUTE)/100) speed ((<60.475605> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.02
			turn lfoot to x-axis ((<-30.363886> *DEATHAMPLIDUTE)/100) speed ((<46.434495> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.55
			turn lfoot to z-axis ((<134.688585> *DEATHAMPLIDUTE)/100) speed ((<13.272560> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.44
			turn lfoot to y-axis ((<94.664564> *DEATHAMPLIDUTE)/100) speed ((<48.922664> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.63
			turn lknee to x-axis ((<2.534500> *DEATHAMPLIDUTE)/100) speed ((<82.403566> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.75
			turn lknee to y-axis ((<-29.548126> *DEATHAMPLIDUTE)/100) speed ((<33.048212> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.10
			turn lshin to x-axis ((<51.180431> *DEATHAMPLIDUTE)/100) speed ((<9.667860> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.32
			turn lshin to z-axis ((<-7.192113> *DEATHAMPLIDUTE)/100) speed ((<18.945041> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.63
			turn lshin to y-axis ((<3.296136> *DEATHAMPLIDUTE)/100) speed ((<4.897937> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.16
			turn lthigh to x-axis ((<31.534198> *DEATHAMPLIDUTE)/100) speed ((<16.701657> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.56
			turn lthigh to z-axis ((<-100.935299> *DEATHAMPLIDUTE)/100) speed ((<100.131256> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.34
			turn lthigh to y-axis ((<7.639984> *DEATHAMPLIDUTE)/100) speed ((<84.254332> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.81
			turn rfoot to x-axis ((<92.065862> *DEATHAMPLIDUTE)/100) speed ((<47.753677> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.59
			turn rfoot to z-axis ((<63.829791> *DEATHAMPLIDUTE)/100) speed ((<3933.704155> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-131.12//WARNING: possible gimbal lock issue detected in frame 31 bone rfoot

			turn rfoot to y-axis ((<-103.665449> *DEATHAMPLIDUTE)/100) speed ((<3935.525459> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-131.18//WARNING: possible gimbal lock issue detected in frame 31 bone rfoot

			turn rknee to x-axis ((<-13.002187> *DEATHAMPLIDUTE)/100) speed ((<75.872883> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.53
			turn rknee to z-axis ((<9.827020> *DEATHAMPLIDUTE)/100) speed ((<3.729565> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.12
			turn rknee to y-axis ((<10.142944> *DEATHAMPLIDUTE)/100) speed ((<13.165241> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.44
			turn rshin to x-axis ((<-48.743809> *DEATHAMPLIDUTE)/100) speed ((<7.174465> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.24
			turn rshin to z-axis ((<-12.763988> *DEATHAMPLIDUTE)/100) speed ((<11.974585> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.40
			turn rshin to y-axis ((<-26.167129> *DEATHAMPLIDUTE)/100) speed ((<66.027319> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.20
			turn rthigh to x-axis ((<-31.284944> *DEATHAMPLIDUTE)/100) speed ((<52.978465> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.77
			turn rthigh to z-axis ((<12.098981> *DEATHAMPLIDUTE)/100) speed ((<56.038449> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.87
			turn rthigh to y-axis ((<-6.344336> *DEATHAMPLIDUTE)/100) speed ((<68.275519> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.28
			turn tail to x-axis ((<-7.351175> *DEATHAMPLIDUTE)/100) speed ((<206.958087> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.90
			turn tail to z-axis ((<-13.720123> *DEATHAMPLIDUTE)/100) speed ((<101.611828> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.39
			turn tail to y-axis ((<-20.182567> *DEATHAMPLIDUTE)/100) speed ((<155.236591> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.17
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:35
		DEATHSPEEDPTAQ = 4;
			move body to x-axis (((([0.208722] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([7.408059] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.25
			move body to z-axis (((([-24.040394] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([3.529015] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.12
			move body to y-axis (((([-41.156643] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([68.582039] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.29
			turn head to x-axis ((<2.734002> *DEATHAMPLIDUTE)/100) speed ((<109.874985> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.66
			turn head to z-axis ((<21.375270> *DEATHAMPLIDUTE)/100) speed ((<29.346847> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.98
			turn head to y-axis ((<12.784047> *DEATHAMPLIDUTE)/100) speed ((<54.064388> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.80
			turn lfoot to x-axis ((<-27.338276> *DEATHAMPLIDUTE)/100) speed ((<90.768296> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.03
			turn lfoot to z-axis ((<135.395509> *DEATHAMPLIDUTE)/100) speed ((<21.207737> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.71
			turn lfoot to y-axis ((<91.526468> *DEATHAMPLIDUTE)/100) speed ((<94.142888> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.14
			turn lknee to x-axis ((<-3.146690> *DEATHAMPLIDUTE)/100) speed ((<170.435706> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.68
			turn lknee to z-axis ((<40.097220> *DEATHAMPLIDUTE)/100) speed ((<17.694015> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.59
			turn lknee to y-axis ((<-27.739925> *DEATHAMPLIDUTE)/100) speed ((<54.246011> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.81
			turn lshin to x-axis ((<51.954090> *DEATHAMPLIDUTE)/100) speed ((<23.209768> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.77
			turn lshin to z-axis ((<-8.751178> *DEATHAMPLIDUTE)/100) speed ((<46.771949> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.56
			turn lshin to y-axis ((<3.654072> *DEATHAMPLIDUTE)/100) speed ((<10.738101> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.36
			turn lthigh to z-axis ((<-107.398468> *DEATHAMPLIDUTE)/100) speed ((<193.895069> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.46
			turn lthigh to y-axis ((<13.051688> *DEATHAMPLIDUTE)/100) speed ((<162.351121> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.41
			turn rfoot to x-axis ((<81.901201> *DEATHAMPLIDUTE)/100) speed ((<304.939806> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=10.16
			turn rfoot to z-axis ((<-100.472363> *DEATHAMPLIDUTE)/100) speed ((<4929.064618> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=164.30//WARNING: possible gimbal lock issue detected in frame 35 bone rfoot

			turn rfoot to y-axis ((<60.522347> *DEATHAMPLIDUTE)/100) speed ((<4925.633882> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=164.19//WARNING: possible gimbal lock issue detected in frame 35 bone rfoot

			turn rknee to x-axis ((<-5.819495> *DEATHAMPLIDUTE)/100) speed ((<215.480755> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-7.18
			turn rknee to z-axis ((<9.587084> *DEATHAMPLIDUTE)/100) speed ((<7.198080> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.24
			turn rknee to y-axis ((<8.940346> *DEATHAMPLIDUTE)/100) speed ((<36.077947> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.20
			turn rshin to x-axis ((<-46.546585> *DEATHAMPLIDUTE)/100) speed ((<65.916721> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.20
			turn rshin to z-axis ((<-11.608979> *DEATHAMPLIDUTE)/100) speed ((<34.650267> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.16
			turn rshin to y-axis ((<-30.023244> *DEATHAMPLIDUTE)/100) speed ((<115.683443> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.86
			turn rthigh to x-axis ((<-36.526561> *DEATHAMPLIDUTE)/100) speed ((<157.248508> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.24
			turn rthigh to z-axis ((<16.418544> *DEATHAMPLIDUTE)/100) speed ((<129.586882> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-4.32
			turn rthigh to y-axis ((<-0.856267> *DEATHAMPLIDUTE)/100) speed ((<164.642073> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=5.49
			turn tail to x-axis ((<-20.914733> *DEATHAMPLIDUTE)/100) speed ((<406.906735> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=13.56
			turn tail to z-axis ((<-22.031468> *DEATHAMPLIDUTE)/100) speed ((<249.340367> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=8.31
			turn tail to y-axis ((<-32.036688> *DEATHAMPLIDUTE)/100) speed ((<355.623635> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-11.85
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:63
		DEATHSPEEDPTAQ = 28;
			move body to x-axis (((([-1.225996] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([43.041545] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.43
			move body to z-axis (((([-21.948654] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([62.752190] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.09
			move body to y-axis (((([-63.077984] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([657.640228] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-21.92
			turn head to x-axis ((<-15.369722> *DEATHAMPLIDUTE)/100) speed ((<543.111732> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=18.10
			turn head to z-axis ((<24.189134> *DEATHAMPLIDUTE)/100) speed ((<84.415913> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.81
			turn head to y-axis ((<6.546401> *DEATHAMPLIDUTE)/100) speed ((<187.129391> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.24
			turn lfoot to x-axis ((<-156.808726> *DEATHAMPLIDUTE)/100) speed ((<3884.113498> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=129.47
			turn lfoot to z-axis ((<-50.250917> *DEATHAMPLIDUTE)/100) speed ((<5569.392803> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=185.65//WARNING: possible gimbal lock issue detected in frame 63 bone lfoot

			turn lfoot to y-axis ((<-38.237971> *DEATHAMPLIDUTE)/100) speed ((<3892.933151> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-129.76//WARNING: possible gimbal lock issue detected in frame 63 bone lfoot

			turn lknee to x-axis ((<148.177484> *DEATHAMPLIDUTE)/100) speed ((<4539.725227> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-151.32//WARNING: possible gimbal lock issue detected in frame 63 bone lknee

			turn lknee to z-axis ((<-50.059385> *DEATHAMPLIDUTE)/100) speed ((<2704.698152> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=90.16//WARNING: possible gimbal lock issue detected in frame 63 bone lknee

			turn lknee to y-axis ((<10.659781> *DEATHAMPLIDUTE)/100) speed ((<1151.991206> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=38.40//WARNING: possible gimbal lock issue detected in frame 63 bone lknee

			turn lshin to x-axis ((<82.920798> *DEATHAMPLIDUTE)/100) speed ((<929.001247> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-30.97
			turn lshin to z-axis ((<-26.204296> *DEATHAMPLIDUTE)/100) speed ((<523.593525> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=17.45
			turn lshin to y-axis ((<24.987207> *DEATHAMPLIDUTE)/100) speed ((<639.994049> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=21.33
			turn lthigh to x-axis ((<-53.234802> *DEATHAMPLIDUTE)/100) speed ((<2540.877807> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=84.70
			turn lthigh to z-axis ((<69.602940> *DEATHAMPLIDUTE)/100) speed ((<5310.042256> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-177.00//WARNING: possible gimbal lock issue detected in frame 63 bone lthigh

			turn lthigh to y-axis ((<91.059221> *DEATHAMPLIDUTE)/100) speed ((<2340.225999> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=78.01//WARNING: possible gimbal lock issue detected in frame 63 bone lthigh

			turn rfoot to x-axis ((<98.315635> *DEATHAMPLIDUTE)/100) speed ((<492.433007> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-16.41
			turn rfoot to z-axis ((<-76.874899> *DEATHAMPLIDUTE)/100) speed ((<707.923904> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-23.60
			turn rfoot to y-axis ((<23.455648> *DEATHAMPLIDUTE)/100) speed ((<1112.0> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-37.07
			turn rknee to x-axis ((<-53.300167> *DEATHAMPLIDUTE)/100) speed ((<1424.420140> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=47.48
			turn rknee to z-axis ((<16.245854> *DEATHAMPLIDUTE)/100) speed ((<199.763106> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.66
			turn rknee to y-axis ((<20.983205> *DEATHAMPLIDUTE)/100) speed ((<361.285768> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=12.04
			turn rshin to x-axis ((<-25.634801> *DEATHAMPLIDUTE)/100) speed ((<627.353507> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-20.91
			turn rshin to z-axis ((<-8.470927> *DEATHAMPLIDUTE)/100) speed ((<94.141556> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.14
			turn rshin to y-axis ((<-25.247845> *DEATHAMPLIDUTE)/100) speed ((<143.261954> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.78
			move rthigh to x-axis (((([-3.179730] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([95.391898] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.18
			move rthigh to z-axis (((([0.817386] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([24.521567] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.82
			move rthigh to y-axis (((([-3.417902] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([102.537074] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.42
			turn rthigh to x-axis ((<-56.071782> *DEATHAMPLIDUTE)/100) speed ((<586.356646> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=19.55
			turn rthigh to z-axis ((<22.422292> *DEATHAMPLIDUTE)/100) speed ((<180.112447> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.00
			turn rthigh to y-axis ((<-27.153637> *DEATHAMPLIDUTE)/100) speed ((<788.921099> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-26.30
			turn tail to x-axis ((<34.457526> *DEATHAMPLIDUTE)/100) speed ((<1661.167747> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-55.37
			turn tail to z-axis ((<3.268904> *DEATHAMPLIDUTE)/100) speed ((<759.011160> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-25.30
			turn tail to y-axis ((<-12.369886> *DEATHAMPLIDUTE)/100) speed ((<590.004069> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=19.67
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:91
		DEATHSPEEDPTAQ = 28;
			move body to x-axis (((([-2.041451] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([24.463652] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.82
			move body to z-axis (((([-17.247305] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([141.040478] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.70
			move body to y-axis (((([-94.520775] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([943.283730] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-31.44
			turn lfoot to x-axis ((<-32.780028> *DEATHAMPLIDUTE)/100) speed ((<3720.860946> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-124.03
			turn lfoot to z-axis ((<97.907237> *DEATHAMPLIDUTE)/100) speed ((<4444.744646> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-148.16//WARNING: possible gimbal lock issue detected in frame 91 bone lfoot

			turn lfoot to y-axis ((<64.081552> *DEATHAMPLIDUTE)/100) speed ((<3069.585675> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=102.32//WARNING: possible gimbal lock issue detected in frame 91 bone lfoot

			turn lknee to x-axis ((<17.173927> *DEATHAMPLIDUTE)/100) speed ((<3930.106729> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=131.00//WARNING: possible gimbal lock issue detected in frame 91 bone lknee

			turn lknee to z-axis ((<38.994984> *DEATHAMPLIDUTE)/100) speed ((<2671.631089> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-89.05//WARNING: possible gimbal lock issue detected in frame 91 bone lknee

			turn lknee to y-axis ((<-31.401200> *DEATHAMPLIDUTE)/100) speed ((<1261.829459> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-42.06//WARNING: possible gimbal lock issue detected in frame 91 bone lknee

			turn lshin to x-axis ((<17.531275> *DEATHAMPLIDUTE)/100) speed ((<1961.685688> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=65.39
			turn lshin to z-axis ((<-0.742088> *DEATHAMPLIDUTE)/100) speed ((<763.866241> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-25.46
			turn lshin to y-axis ((<0.304060> *DEATHAMPLIDUTE)/100) speed ((<740.494415> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-24.68
			turn lthigh to x-axis ((<24.078541> *DEATHAMPLIDUTE)/100) speed ((<2319.400283> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-77.31
			turn lthigh to z-axis ((<-95.161235> *DEATHAMPLIDUTE)/100) speed ((<4942.925257> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=164.76//WARNING: possible gimbal lock issue detected in frame 91 bone lthigh

			turn lthigh to y-axis ((<0.539601> *DEATHAMPLIDUTE)/100) speed ((<2715.588607> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-90.52//WARNING: possible gimbal lock issue detected in frame 91 bone lthigh

			turn rfoot to x-axis ((<32.534486> *DEATHAMPLIDUTE)/100) speed ((<1973.434467> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=65.78
			turn rfoot to z-axis ((<-29.596330> *DEATHAMPLIDUTE)/100) speed ((<1418.357083> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-47.28
			turn rfoot to y-axis ((<-39.869973> *DEATHAMPLIDUTE)/100) speed ((<1899.768623> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-63.33//WARNING: possible gimbal lock issue detected in frame 91 bone rfoot

			turn rknee to x-axis ((<-115.470618> *DEATHAMPLIDUTE)/100) speed ((<1865.113541> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=62.17
			turn rknee to z-axis ((<-21.875269> *DEATHAMPLIDUTE)/100) speed ((<1143.633692> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=38.12
			turn rknee to y-axis ((<-12.661723> *DEATHAMPLIDUTE)/100) speed ((<1009.347836> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-33.64//WARNING: possible gimbal lock issue detected in frame 91 bone rknee

			turn rshin to x-axis ((<73.912086> *DEATHAMPLIDUTE)/100) speed ((<2986.406624> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-99.55
			turn rshin to z-axis ((<16.655555> *DEATHAMPLIDUTE)/100) speed ((<753.794447> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-25.13
			turn rshin to y-axis ((<-18.768598> *DEATHAMPLIDUTE)/100) speed ((<194.377417> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=6.48//WARNING: possible gimbal lock issue detected in frame 91 bone rshin

			turn rthigh to x-axis ((<-108.387268> *DEATHAMPLIDUTE)/100) speed ((<1569.464568> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=52.32
			turn rthigh to z-axis ((<85.912244> *DEATHAMPLIDUTE)/100) speed ((<1904.698551> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-63.49
			turn rthigh to y-axis ((<39.424692> *DEATHAMPLIDUTE)/100) speed ((<1997.349880> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=66.58//WARNING: possible gimbal lock issue detected in frame 91 bone rthigh

		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:98
		DEATHSPEEDPTAQ = 7;
			move body to x-axis (((([-3.792118] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([52.519999] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.75
			move body to z-axis (((([-19.034067] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([53.602867] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.79
			move body to y-axis (((([-104.090286] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([287.085342] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-9.57
			turn lfoot to x-axis ((<-146.502148> *DEATHAMPLIDUTE)/100) speed ((<3411.663610> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=113.72
			turn lfoot to z-axis ((<-52.846434> *DEATHAMPLIDUTE)/100) speed ((<4522.610135> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=150.75//WARNING: possible gimbal lock issue detected in frame 98 bone lfoot

			turn lfoot to y-axis ((<-56.590409> *DEATHAMPLIDUTE)/100) speed ((<3620.158823> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-120.67//WARNING: possible gimbal lock issue detected in frame 98 bone lfoot

			turn lknee to x-axis ((<44.693257> *DEATHAMPLIDUTE)/100) speed ((<825.579923> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-27.52
			turn lknee to z-axis ((<72.157732> *DEATHAMPLIDUTE)/100) speed ((<994.882418> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-33.16
			turn lknee to y-axis ((<-95.529266> *DEATHAMPLIDUTE)/100) speed ((<1923.841967> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-64.13
			turn lshin to x-axis ((<76.033126> *DEATHAMPLIDUTE)/100) speed ((<1755.055527> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-58.50
			turn lshin to z-axis ((<-21.658388> *DEATHAMPLIDUTE)/100) speed ((<627.489015> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=20.92
			turn lshin to y-axis ((<17.239652> *DEATHAMPLIDUTE)/100) speed ((<508.067756> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=16.94
			turn lthigh to x-axis ((<-46.316411> *DEATHAMPLIDUTE)/100) speed ((<2111.848558> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=70.39
			turn lthigh to z-axis ((<-21.776187> *DEATHAMPLIDUTE)/100) speed ((<2201.551448> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-73.39//WARNING: possible gimbal lock issue detected in frame 98 bone lthigh

			turn lthigh to y-axis ((<9.588029> *DEATHAMPLIDUTE)/100) speed ((<271.452840> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=9.05//WARNING: possible gimbal lock issue detected in frame 98 bone lthigh

			turn rfoot to x-axis ((<20.421174> *DEATHAMPLIDUTE)/100) speed ((<363.399344> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=12.11
			turn rfoot to z-axis ((<-27.600656> *DEATHAMPLIDUTE)/100) speed ((<59.870211> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.00
			turn rfoot to y-axis ((<-42.346848> *DEATHAMPLIDUTE)/100) speed ((<74.306277> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.48
			turn rshin to z-axis ((<16.260708> *DEATHAMPLIDUTE)/100) speed ((<11.845392> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.39
			turn rshin to y-axis ((<-18.305885> *DEATHAMPLIDUTE)/100) speed ((<13.881386> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.46
			turn rthigh to x-axis ((<-110.616416> *DEATHAMPLIDUTE)/100) speed ((<66.874450> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.23
			turn rthigh to z-axis ((<81.439317> *DEATHAMPLIDUTE)/100) speed ((<134.187809> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=4.47
			turn rthigh to y-axis ((<36.712496> *DEATHAMPLIDUTE)/100) speed ((<81.365892> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-2.71
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
		if (TRUE) { //Frame:115
		DEATHSPEEDPTAQ = 17;
			move body to x-axis (((([-4.643464] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([25.540380] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.85
			move body to z-axis (((([-16.055605] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([89.353867] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=2.98
			move body to y-axis (((([-132.481125] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([851.725159] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-28.39
			turn lfoot to x-axis ((<-165.688792> *DEATHAMPLIDUTE)/100) speed ((<575.599302> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=19.19
			turn lfoot to z-axis ((<-10.526844> *DEATHAMPLIDUTE)/100) speed ((<1269.587700> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-42.32
			turn lfoot to y-axis ((<25.759326> *DEATHAMPLIDUTE)/100) speed ((<2470.492042> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=82.35//WARNING: possible gimbal lock issue detected in frame 115 bone lfoot

			turn lknee to x-axis ((<162.275459> *DEATHAMPLIDUTE)/100) speed ((<3527.466053> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-117.58
			turn lknee to z-axis ((<-40.474919> *DEATHAMPLIDUTE)/100) speed ((<3378.979516> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=112.63//WARNING: possible gimbal lock issue detected in frame 115 bone lknee

			turn lknee to y-axis ((<-2.796283> *DEATHAMPLIDUTE)/100) speed ((<2781.989495> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=92.73//WARNING: possible gimbal lock issue detected in frame 115 bone lknee

			turn lshin to x-axis ((<81.575121> *DEATHAMPLIDUTE)/100) speed ((<166.259850> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-5.54
			turn lshin to z-axis ((<-5.458531> *DEATHAMPLIDUTE)/100) speed ((<485.995703> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-16.20
			turn lshin to y-axis ((<5.053129> *DEATHAMPLIDUTE)/100) speed ((<365.595689> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-12.19
			turn lthigh to x-axis ((<-63.670853> *DEATHAMPLIDUTE)/100) speed ((<520.633253> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=17.35
			turn lthigh to z-axis ((<46.150062> *DEATHAMPLIDUTE)/100) speed ((<2037.787451> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-67.93
			turn lthigh to y-axis ((<125.565897> *DEATHAMPLIDUTE)/100) speed ((<3479.336040> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=115.98//WARNING: possible gimbal lock issue detected in frame 115 bone lthigh

			turn rfoot to x-axis ((<26.684817> *DEATHAMPLIDUTE)/100) speed ((<187.909262> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-6.26
			turn rfoot to z-axis ((<-24.139407> *DEATHAMPLIDUTE)/100) speed ((<103.837488> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-3.46
			turn rfoot to y-axis ((<-42.493814> *DEATHAMPLIDUTE)/100) speed ((<4.408955> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-0.15
			turn rknee to x-axis ((<-115.661194> *DEATHAMPLIDUTE)/100) speed ((<5.938166> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.20
			turn rknee to z-axis ((<-22.762627> *DEATHAMPLIDUTE)/100) speed ((<27.130485> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.90
			turn rknee to y-axis ((<-13.910268> *DEATHAMPLIDUTE)/100) speed ((<38.872399> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-1.30
			turn rshin to z-axis ((<15.230760> *DEATHAMPLIDUTE)/100) speed ((<30.898444> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=1.03
			turn rshin to y-axis ((<-17.840181> *DEATHAMPLIDUTE)/100) speed ((<13.971135> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=0.47
			turn rthigh to x-axis ((<-114.085230> *DEATHAMPLIDUTE)/100) speed ((<104.064421> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=3.47
			turn rthigh to z-axis ((<65.403289> *DEATHAMPLIDUTE)/100) speed ((<481.080822> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=16.04
			turn rthigh to y-axis ((<18.883484> *DEATHAMPLIDUTE)/100) speed ((<534.870355> *DEATHAMPLIDUTE)/100) / DEATHSPEEDPTAQ; //delta=-17.83
		sleep ((33*DEATHSPEEDPTAQ) -1);
		}
}
