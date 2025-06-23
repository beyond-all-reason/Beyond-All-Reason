// For N:\animations\raptor_allterrain_death_V1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5))
//#define DEATHSCALE 100 \Higher values are bigger, 100 is default
//#define DEATHAMPLIDUTE 100 \Higher values are bigger, 100 is default
//#define DEATHSPEED 10;
//use call-script DeathAnim(); from Killed()

//use call-script DeathAnim(); from Killed()
static-var death_speed;
DeathAnim() {// For N:\animations\raptor_allterrain_death_V1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 

	signal SIGNAL_MOVE;
	call-script StopWalking();
	//turn aimy1 to y-axis <0> speed <120>;
	//turn aimx1 to x-axis <0> speed <120>;
		if (TRUE) { //Frame:5
			death_speed = (DEATHSPEED * 5) /10;
			move body to x-axis (((([-0.817180] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([24.515392] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.82
			move body to z-axis (((([-3.299798] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([98.993940] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.30
			move body to y-axis (((([-2.633106] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([78.993180] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.63
			turn body to x-axis ((<-8.535503> *DEATHAMPLIDUTE)/100) speed ((<256.065090> *DEATHAMPLIDUTE)/100) / death_speed; //delta=8.54
			turn body to z-axis ((<-0.631129> *DEATHAMPLIDUTE)/100) speed ((<18.933877> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.63
			turn body to y-axis ((<1.158035> *DEATHAMPLIDUTE)/100) speed ((<34.741056> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.16
			turn head to x-axis ((<-7.203127> *DEATHAMPLIDUTE)/100) speed ((<216.093807> *DEATHAMPLIDUTE)/100) / death_speed; //delta=7.20
			turn head to z-axis ((<-0.259161> *DEATHAMPLIDUTE)/100) speed ((<7.774835> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.26
			turn head to y-axis ((<2.264532> *DEATHAMPLIDUTE)/100) speed ((<67.935971> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.26
			turn lbfoot to x-axis ((<1.882216> *DEATHAMPLIDUTE)/100) speed ((<56.466484> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.88
			turn lbfoot to z-axis ((<-5.276784> *DEATHAMPLIDUTE)/100) speed ((<158.303529> *DEATHAMPLIDUTE)/100) / death_speed; //delta=5.28
			turn lbknee to x-axis ((<25.162559> *DEATHAMPLIDUTE)/100) speed ((<754.876759> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-25.16
			turn lbknee to z-axis ((<8.962694> *DEATHAMPLIDUTE)/100) speed ((<268.880813> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-8.96
			turn lbknee to y-axis ((<1.084326> *DEATHAMPLIDUTE)/100) speed ((<32.529778> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.08
			turn lbshin to x-axis ((<-6.222250> *DEATHAMPLIDUTE)/100) speed ((<186.667495> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.22
			turn lbshin to z-axis ((<-3.651275> *DEATHAMPLIDUTE)/100) speed ((<109.538258> *DEATHAMPLIDUTE)/100) / death_speed; //delta=3.65
			turn lbshin to y-axis ((<-1.716410> *DEATHAMPLIDUTE)/100) speed ((<51.492310> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.72
			turn lbthigh to x-axis ((<-12.314238> *DEATHAMPLIDUTE)/100) speed ((<369.427131> *DEATHAMPLIDUTE)/100) / death_speed; //delta=12.31
			turn lbthigh to z-axis ((<1.940956> *DEATHAMPLIDUTE)/100) speed ((<58.228673> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.94
			turn lbthigh to y-axis ((<-0.373026> *DEATHAMPLIDUTE)/100) speed ((<11.190794> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.37
			turn lffoot to x-axis ((<4.903403> *DEATHAMPLIDUTE)/100) speed ((<147.102104> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-4.90
			turn lffoot to z-axis ((<-4.400268> *DEATHAMPLIDUTE)/100) speed ((<132.008035> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.40
			turn lffoot to y-axis ((<0.193715> *DEATHAMPLIDUTE)/100) speed ((<5.811440> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.19
			turn lfknee to x-axis ((<4.347352> *DEATHAMPLIDUTE)/100) speed ((<130.420554> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-4.35
			turn lfknee to z-axis ((<1.583284> *DEATHAMPLIDUTE)/100) speed ((<47.498509> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.58
			turn lfknee to y-axis ((<2.808940> *DEATHAMPLIDUTE)/100) speed ((<84.268189> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.81
			turn lfshin to x-axis ((<1.386127> *DEATHAMPLIDUTE)/100) speed ((<41.583811> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.39
			turn lfshin to z-axis ((<-0.306196> *DEATHAMPLIDUTE)/100) speed ((<9.185869> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.31
			turn lfshin to y-axis ((<-1.589980> *DEATHAMPLIDUTE)/100) speed ((<47.699397> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.59
			turn lfthigh to x-axis ((<-2.373853> *DEATHAMPLIDUTE)/100) speed ((<71.215576> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.37
			turn lfthigh to z-axis ((<5.328648> *DEATHAMPLIDUTE)/100) speed ((<159.859429> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-5.33
			turn lfthigh to y-axis ((<-1.255276> *DEATHAMPLIDUTE)/100) speed ((<37.658292> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.26
			turn rbfoot to x-axis ((<0.243752> *DEATHAMPLIDUTE)/100) speed ((<7.312546> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.24
			turn rbfoot to z-axis ((<1.563406> *DEATHAMPLIDUTE)/100) speed ((<46.902166> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.56
			turn rbknee to x-axis ((<27.882654> *DEATHAMPLIDUTE)/100) speed ((<836.479624> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-27.88
			turn rbknee to z-axis ((<-5.441792> *DEATHAMPLIDUTE)/100) speed ((<163.253756> *DEATHAMPLIDUTE)/100) / death_speed; //delta=5.44
			turn rbknee to y-axis ((<0.331217> *DEATHAMPLIDUTE)/100) speed ((<9.936515> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.33
			turn rbshin to x-axis ((<-7.322188> *DEATHAMPLIDUTE)/100) speed ((<219.665646> *DEATHAMPLIDUTE)/100) / death_speed; //delta=7.32
			turn rbshin to z-axis ((<5.490011> *DEATHAMPLIDUTE)/100) speed ((<164.700339> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-5.49
			turn rbshin to y-axis ((<-0.472046> *DEATHAMPLIDUTE)/100) speed ((<14.161369> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.47
			turn rbthigh to x-axis ((<-12.009456> *DEATHAMPLIDUTE)/100) speed ((<360.283676> *DEATHAMPLIDUTE)/100) / death_speed; //delta=12.01
			turn rbthigh to z-axis ((<5.858793> *DEATHAMPLIDUTE)/100) speed ((<175.763785> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-5.86
			turn rbthigh to y-axis ((<0.751533> *DEATHAMPLIDUTE)/100) speed ((<22.545999> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.75
			turn rffoot to x-axis ((<3.494307> *DEATHAMPLIDUTE)/100) speed ((<104.829225> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.49
			turn rffoot to z-axis ((<-0.394271> *DEATHAMPLIDUTE)/100) speed ((<11.828129> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.39
			turn rfknee to x-axis ((<5.625234> *DEATHAMPLIDUTE)/100) speed ((<168.757010> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-5.63
			turn rfknee to z-axis ((<2.387849> *DEATHAMPLIDUTE)/100) speed ((<71.635472> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.39
			turn rfknee to y-axis ((<0.825583> *DEATHAMPLIDUTE)/100) speed ((<24.767485> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.83
			turn rfshin to x-axis ((<0.905462> *DEATHAMPLIDUTE)/100) speed ((<27.163855> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.91
			turn rfshin to z-axis ((<1.507023> *DEATHAMPLIDUTE)/100) speed ((<45.210680> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.51
			turn rfshin to y-axis ((<-1.108829> *DEATHAMPLIDUTE)/100) speed ((<33.264868> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.11
			turn rfthigh to x-axis ((<-1.224178> *DEATHAMPLIDUTE)/100) speed ((<36.725343> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.22
			turn rfthigh to z-axis ((<4.070678> *DEATHAMPLIDUTE)/100) speed ((<122.120350> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-4.07
			turn rfthigh to y-axis ((<-0.914094> *DEATHAMPLIDUTE)/100) speed ((<27.422811> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.91
			turn tail to x-axis ((<-4.371183> *DEATHAMPLIDUTE)/100) speed ((<131.135483> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.37
			turn tail to z-axis ((<-0.426509> *DEATHAMPLIDUTE)/100) speed ((<12.795280> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.43
			turn tail to y-axis ((<-3.525698> *DEATHAMPLIDUTE)/100) speed ((<105.770946> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.53
		sleep ((33*death_speed) -1);
		}
		if (TRUE) { //Frame:8
			death_speed = (DEATHSPEED * 3) /10;
			turn body to x-axis ((<-8.151769> *DEATHAMPLIDUTE)/100) speed ((<11.512011> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.38
			turn body to z-axis ((<1.765504> *DEATHAMPLIDUTE)/100) speed ((<71.898994> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.40
			turn body to y-axis ((<2.070996> *DEATHAMPLIDUTE)/100) speed ((<27.388836> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.91
			turn head to x-axis ((<-11.525003> *DEATHAMPLIDUTE)/100) speed ((<129.656269> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.32
			turn head to z-axis ((<-0.414658> *DEATHAMPLIDUTE)/100) speed ((<4.664902> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.16
			turn head to y-axis ((<3.623252> *DEATHAMPLIDUTE)/100) speed ((<40.761585> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.36
			turn lbfoot to x-axis ((<1.006050> *DEATHAMPLIDUTE)/100) speed ((<26.284986> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.88
			turn lbfoot to z-axis ((<-9.637801> *DEATHAMPLIDUTE)/100) speed ((<130.830493> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.36
			turn lbfoot to y-axis ((<-0.329633> *DEATHAMPLIDUTE)/100) speed ((<7.913390> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.26
			turn lbknee to x-axis ((<33.702609> *DEATHAMPLIDUTE)/100) speed ((<256.201506> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-8.54
			turn lbknee to z-axis ((<12.215564> *DEATHAMPLIDUTE)/100) speed ((<97.586097> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.25
			turn lbknee to y-axis ((<1.491860> *DEATHAMPLIDUTE)/100) speed ((<12.226011> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.41
			turn lbshin to x-axis ((<-9.137425> *DEATHAMPLIDUTE)/100) speed ((<87.455266> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.92
			turn lbshin to z-axis ((<-6.536272> *DEATHAMPLIDUTE)/100) speed ((<86.549890> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.88
			turn lbshin to y-axis ((<-2.803797> *DEATHAMPLIDUTE)/100) speed ((<32.621598> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.09
			turn lbthigh to x-axis ((<-17.261281> *DEATHAMPLIDUTE)/100) speed ((<148.411311> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.95
			turn lbthigh to z-axis ((<4.337814> *DEATHAMPLIDUTE)/100) speed ((<71.905756> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.40
			turn lbthigh to y-axis ((<0.280857> *DEATHAMPLIDUTE)/100) speed ((<19.616497> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.65
			turn lffoot to x-axis ((<4.126426> *DEATHAMPLIDUTE)/100) speed ((<23.309314> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.78
			turn lffoot to z-axis ((<-8.354473> *DEATHAMPLIDUTE)/100) speed ((<118.626158> *DEATHAMPLIDUTE)/100) / death_speed; //delta=3.95
			turn lfknee to x-axis ((<15.109439> *DEATHAMPLIDUTE)/100) speed ((<322.862611> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-10.76
			turn lfknee to z-axis ((<1.706513> *DEATHAMPLIDUTE)/100) speed ((<3.696889> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.12
			turn lfknee to y-axis ((<4.572094> *DEATHAMPLIDUTE)/100) speed ((<52.894633> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.76
			turn lfshin to x-axis ((<-2.855735> *DEATHAMPLIDUTE)/100) speed ((<127.255860> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.24
			turn lfshin to z-axis ((<-1.692099> *DEATHAMPLIDUTE)/100) speed ((<41.577107> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.39
			turn lfshin to y-axis ((<-2.667564> *DEATHAMPLIDUTE)/100) speed ((<32.327514> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.08
			turn lfthigh to x-axis ((<-8.591037> *DEATHAMPLIDUTE)/100) speed ((<186.515525> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.22
			turn lfthigh to z-axis ((<8.492351> *DEATHAMPLIDUTE)/100) speed ((<94.911092> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.16
			turn lfthigh to y-axis ((<-1.039785> *DEATHAMPLIDUTE)/100) speed ((<6.464748> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.22
			turn rbfoot to x-axis ((<-0.996795> *DEATHAMPLIDUTE)/100) speed ((<37.216390> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.24
			turn rbfoot to z-axis ((<1.333449> *DEATHAMPLIDUTE)/100) speed ((<6.898700> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.23
			turn rbknee to x-axis ((<33.734058> *DEATHAMPLIDUTE)/100) speed ((<175.542128> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-5.85
			turn rbknee to z-axis ((<-6.500710> *DEATHAMPLIDUTE)/100) speed ((<31.767539> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.06
			turn rbknee to y-axis ((<0.634442> *DEATHAMPLIDUTE)/100) speed ((<9.096755> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.30
			turn rbshin to x-axis ((<-9.462505> *DEATHAMPLIDUTE)/100) speed ((<64.209498> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.14
			turn rbshin to z-axis ((<6.721690> *DEATHAMPLIDUTE)/100) speed ((<36.950359> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.23
			turn rbshin to y-axis ((<-0.918888> *DEATHAMPLIDUTE)/100) speed ((<13.405257> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.45
			turn rbthigh to x-axis ((<-14.547173> *DEATHAMPLIDUTE)/100) speed ((<76.131500> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.54
			turn rbthigh to z-axis ((<7.492330> *DEATHAMPLIDUTE)/100) speed ((<49.006112> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.63
			turn rbthigh to y-axis ((<1.026174> *DEATHAMPLIDUTE)/100) speed ((<8.239219> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.27
			turn rffoot to x-axis ((<2.438910> *DEATHAMPLIDUTE)/100) speed ((<31.661929> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.06
			turn rffoot to z-axis ((<-1.760776> *DEATHAMPLIDUTE)/100) speed ((<40.995142> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.37
			turn rfknee to x-axis ((<11.985175> *DEATHAMPLIDUTE)/100) speed ((<190.798252> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-6.36
			turn rfknee to z-axis ((<3.307399> *DEATHAMPLIDUTE)/100) speed ((<27.586502> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.92
			turn rfknee to y-axis ((<1.146173> *DEATHAMPLIDUTE)/100) speed ((<9.617714> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.32
			turn rfshin to x-axis ((<-1.595070> *DEATHAMPLIDUTE)/100) speed ((<75.015955> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.50
			turn rfshin to z-axis ((<1.698931> *DEATHAMPLIDUTE)/100) speed ((<5.757264> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.19
			turn rfshin to y-axis ((<-1.872786> *DEATHAMPLIDUTE)/100) speed ((<22.918725> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.76
			turn rfthigh to x-axis ((<-4.034169> *DEATHAMPLIDUTE)/100) speed ((<84.299722> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.81
			turn rfthigh to z-axis ((<5.960246> *DEATHAMPLIDUTE)/100) speed ((<56.687027> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.89
			turn rfthigh to y-axis ((<-1.137368> *DEATHAMPLIDUTE)/100) speed ((<6.698226> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.22
			turn tail to x-axis ((<-6.993892> *DEATHAMPLIDUTE)/100) speed ((<78.681282> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.62
			turn tail to z-axis ((<-0.682415> *DEATHAMPLIDUTE)/100) speed ((<7.677169> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.26
			turn tail to y-axis ((<-5.641117> *DEATHAMPLIDUTE)/100) speed ((<63.462560> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.12
		sleep ((33*death_speed) -1);
		}
		if (TRUE) { //Frame:12
			death_speed = (DEATHSPEED * 4) /10;
			turn body to x-axis ((<-6.688513> *DEATHAMPLIDUTE)/100) speed ((<43.897686> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.46
			turn body to z-axis ((<10.904354> *DEATHAMPLIDUTE)/100) speed ((<274.165513> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-9.14
			turn body to y-axis ((<3.200936> *DEATHAMPLIDUTE)/100) speed ((<33.898186> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.13
			turn head to x-axis ((<-4.307429> *DEATHAMPLIDUTE)/100) speed ((<216.527195> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-7.22
			turn head to z-axis ((<17.109651> *DEATHAMPLIDUTE)/100) speed ((<525.729273> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-17.52
			turn head to y-axis ((<5.105140> *DEATHAMPLIDUTE)/100) speed ((<44.456655> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.48
			turn lbfoot to x-axis ((<-1.112460> *DEATHAMPLIDUTE)/100) speed ((<63.555305> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.12
			turn lbfoot to z-axis ((<-17.282658> *DEATHAMPLIDUTE)/100) speed ((<229.345723> *DEATHAMPLIDUTE)/100) / death_speed; //delta=7.64
			turn lbfoot to y-axis ((<-1.200701> *DEATHAMPLIDUTE)/100) speed ((<26.132045> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.87
			turn lbknee to x-axis ((<46.043251> *DEATHAMPLIDUTE)/100) speed ((<370.219271> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-12.34
			turn lbknee to z-axis ((<14.434462> *DEATHAMPLIDUTE)/100) speed ((<66.566964> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.22
			turn lbknee to y-axis ((<3.407300> *DEATHAMPLIDUTE)/100) speed ((<57.463226> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.92
			turn lbshin to x-axis ((<-13.498240> *DEATHAMPLIDUTE)/100) speed ((<130.824436> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.36
			turn lbshin to z-axis ((<-13.627252> *DEATHAMPLIDUTE)/100) speed ((<212.729409> *DEATHAMPLIDUTE)/100) / death_speed; //delta=7.09
			turn lbshin to y-axis ((<-4.295593> *DEATHAMPLIDUTE)/100) speed ((<44.753897> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.49
			turn lbthigh to x-axis ((<-24.113351> *DEATHAMPLIDUTE)/100) speed ((<205.562090> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.85
			turn lbthigh to z-axis ((<8.201965> *DEATHAMPLIDUTE)/100) speed ((<115.924528> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.86
			turn lbthigh to y-axis ((<1.780183> *DEATHAMPLIDUTE)/100) speed ((<44.979776> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.50
			turn lffoot to x-axis ((<2.466850> *DEATHAMPLIDUTE)/100) speed ((<49.787277> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.66
			turn lffoot to z-axis ((<-15.094370> *DEATHAMPLIDUTE)/100) speed ((<202.196899> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.74
			turn lffoot to y-axis ((<-0.222385> *DEATHAMPLIDUTE)/100) speed ((<12.520778> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.42
			turn lfknee to x-axis ((<31.126630> *DEATHAMPLIDUTE)/100) speed ((<480.515744> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-16.02
			turn lfknee to z-axis ((<-0.915210> *DEATHAMPLIDUTE)/100) speed ((<78.651686> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.62
			turn lfknee to y-axis ((<8.407740> *DEATHAMPLIDUTE)/100) speed ((<115.069379> *DEATHAMPLIDUTE)/100) / death_speed; //delta=3.84
			turn lfshin to x-axis ((<-9.256840> *DEATHAMPLIDUTE)/100) speed ((<192.033155> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.40
			turn lfshin to z-axis ((<-6.594717> *DEATHAMPLIDUTE)/100) speed ((<147.078537> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.90
			turn lfshin to y-axis ((<-4.156373> *DEATHAMPLIDUTE)/100) speed ((<44.664289> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.49
			turn lfthigh to x-axis ((<-18.035690> *DEATHAMPLIDUTE)/100) speed ((<283.339597> *DEATHAMPLIDUTE)/100) / death_speed; //delta=9.44
			turn lfthigh to z-axis ((<12.903166> *DEATHAMPLIDUTE)/100) speed ((<132.324474> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-4.41
			turn lfthigh to y-axis ((<0.501601> *DEATHAMPLIDUTE)/100) speed ((<46.241576> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.54
			turn rbfoot to x-axis ((<-1.201435> *DEATHAMPLIDUTE)/100) speed ((<6.139211> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.20
			turn rbfoot to z-axis ((<0.939179> *DEATHAMPLIDUTE)/100) speed ((<11.828100> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.39
			turn rbknee to x-axis ((<32.855119> *DEATHAMPLIDUTE)/100) speed ((<26.368184> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.88
			turn rbknee to z-axis ((<-7.614521> *DEATHAMPLIDUTE)/100) speed ((<33.414340> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.11
			turn rbknee to y-axis ((<0.807462> *DEATHAMPLIDUTE)/100) speed ((<5.190597> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.17
			turn rbshin to z-axis ((<5.491564> *DEATHAMPLIDUTE)/100) speed ((<36.903768> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.23
			turn rbshin to y-axis ((<-1.224329> *DEATHAMPLIDUTE)/100) speed ((<9.163238> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.31
			turn rbthigh to x-axis ((<-14.146391> *DEATHAMPLIDUTE)/100) speed ((<12.023455> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.40
			turn rbthigh to z-axis ((<6.425856> *DEATHAMPLIDUTE)/100) speed ((<31.994215> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.07
			turn rbthigh to y-axis ((<0.130877> *DEATHAMPLIDUTE)/100) speed ((<26.858900> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.90
			turn rffoot to x-axis ((<2.076134> *DEATHAMPLIDUTE)/100) speed ((<10.883277> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.36
			turn rffoot to z-axis ((<-3.528411> *DEATHAMPLIDUTE)/100) speed ((<53.029073> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.77
			turn rfknee to x-axis ((<12.705845> *DEATHAMPLIDUTE)/100) speed ((<21.620084> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.72
			turn rfknee to z-axis ((<2.528397> *DEATHAMPLIDUTE)/100) speed ((<23.370062> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.78
			turn rfknee to y-axis ((<1.443169> *DEATHAMPLIDUTE)/100) speed ((<8.909859> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.30
			turn rfshin to x-axis ((<-2.060894> *DEATHAMPLIDUTE)/100) speed ((<13.974718> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.47
			turn rfshin to z-axis ((<0.531186> *DEATHAMPLIDUTE)/100) speed ((<35.032349> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.17
			turn rfshin to y-axis ((<-2.473454> *DEATHAMPLIDUTE)/100) speed ((<18.020020> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.60
			turn rfthigh to x-axis ((<-4.453800> *DEATHAMPLIDUTE)/100) speed ((<12.588944> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.42
			turn rfthigh to y-axis ((<-1.689443> *DEATHAMPLIDUTE)/100) speed ((<16.562263> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.55
			turn tail to x-axis ((<-10.490838> *DEATHAMPLIDUTE)/100) speed ((<104.908389> *DEATHAMPLIDUTE)/100) / death_speed; //delta=3.50
			turn tail to z-axis ((<-1.023622> *DEATHAMPLIDUTE)/100) speed ((<10.236223> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.34
			turn tail to y-axis ((<-8.461675> *DEATHAMPLIDUTE)/100) speed ((<84.616759> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.82
		sleep ((33*death_speed) -1);
		}
		if (TRUE) { //Frame:30
			death_speed = (DEATHSPEED * 18) /10;
			move body to x-axis (((([-8.589146] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([233.158978] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) / death_speed; //delta=-7.77
			move body to z-axis (((([-2.222166] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([32.328951] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.08
			move body to y-axis (((([-16.997599] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([430.934780] *MOVESCALE)/100) *DEATHAMPLIDUTE)/100) / death_speed; //delta=-14.36
			turn body to x-axis ((<1.119639> *DEATHAMPLIDUTE)/100) speed ((<234.244556> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-7.81
			turn body to z-axis ((<59.670629> *DEATHAMPLIDUTE)/100) speed ((<1462.988254> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-48.77
			turn body to y-axis ((<5.931963> *DEATHAMPLIDUTE)/100) speed ((<81.930798> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.73
			turn head to x-axis ((<18.622699> *DEATHAMPLIDUTE)/100) speed ((<687.903838> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-22.93
			turn head to z-axis ((<-0.839385> *DEATHAMPLIDUTE)/100) speed ((<538.471087> *DEATHAMPLIDUTE)/100) / death_speed; //delta=17.95
			turn head to y-axis ((<11.337064> *DEATHAMPLIDUTE)/100) speed ((<186.957705> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.23
			turn lbfoot to x-axis ((<-5.267728> *DEATHAMPLIDUTE)/100) speed ((<124.658043> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.16
			turn lbfoot to z-axis ((<-46.517328> *DEATHAMPLIDUTE)/100) speed ((<877.040088> *DEATHAMPLIDUTE)/100) / death_speed; //delta=29.23
			turn lbfoot to y-axis ((<-4.267642> *DEATHAMPLIDUTE)/100) speed ((<92.008235> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-3.07
			turn lbknee to x-axis ((<47.410170> *DEATHAMPLIDUTE)/100) speed ((<41.007568> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-1.37
			turn lbknee to z-axis ((<-6.484042> *DEATHAMPLIDUTE)/100) speed ((<627.555147> *DEATHAMPLIDUTE)/100) / death_speed; //delta=20.92
			turn lbknee to y-axis ((<30.544702> *DEATHAMPLIDUTE)/100) speed ((<814.122033> *DEATHAMPLIDUTE)/100) / death_speed; //delta=27.14
			turn lbshin to x-axis ((<-19.374504> *DEATHAMPLIDUTE)/100) speed ((<176.287934> *DEATHAMPLIDUTE)/100) / death_speed; //delta=5.88
			turn lbshin to z-axis ((<-38.144855> *DEATHAMPLIDUTE)/100) speed ((<735.528079> *DEATHAMPLIDUTE)/100) / death_speed; //delta=24.52
			turn lbshin to y-axis ((<-3.569864> *DEATHAMPLIDUTE)/100) speed ((<21.771881> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.73
			turn lbthigh to x-axis ((<-28.961498> *DEATHAMPLIDUTE)/100) speed ((<145.444405> *DEATHAMPLIDUTE)/100) / death_speed; //delta=4.85
			turn lbthigh to z-axis ((<29.244923> *DEATHAMPLIDUTE)/100) speed ((<631.288746> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-21.04
			turn lbthigh to y-axis ((<-4.580960> *DEATHAMPLIDUTE)/100) speed ((<190.834293> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-6.36
			turn lffoot to x-axis ((<2.975471> *DEATHAMPLIDUTE)/100) speed ((<15.258608> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.51
			turn lffoot to z-axis ((<-47.762915> *DEATHAMPLIDUTE)/100) speed ((<980.056365> *DEATHAMPLIDUTE)/100) / death_speed; //delta=32.67
			turn lffoot to y-axis ((<0.010496> *DEATHAMPLIDUTE)/100) speed ((<6.986412> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.23
			turn lfknee to x-axis ((<33.871690> *DEATHAMPLIDUTE)/100) speed ((<82.351796> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-2.75
			turn lfknee to z-axis ((<-17.772285> *DEATHAMPLIDUTE)/100) speed ((<505.712274> *DEATHAMPLIDUTE)/100) / death_speed; //delta=16.86
			turn lfknee to y-axis ((<33.736360> *DEATHAMPLIDUTE)/100) speed ((<759.858605> *DEATHAMPLIDUTE)/100) / death_speed; //delta=25.33
			turn lfshin to x-axis ((<-15.310320> *DEATHAMPLIDUTE)/100) speed ((<181.604391> *DEATHAMPLIDUTE)/100) / death_speed; //delta=6.05
			turn lfshin to z-axis ((<-31.286880> *DEATHAMPLIDUTE)/100) speed ((<740.764892> *DEATHAMPLIDUTE)/100) / death_speed; //delta=24.69
			turn lfshin to y-axis ((<-12.640809> *DEATHAMPLIDUTE)/100) speed ((<254.533061> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-8.48
			turn lfthigh to x-axis ((<-27.347615> *DEATHAMPLIDUTE)/100) speed ((<279.357742> *DEATHAMPLIDUTE)/100) / death_speed; //delta=9.31
			turn lfthigh to z-axis ((<33.963037> *DEATHAMPLIDUTE)/100) speed ((<631.796118> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-21.06
			turn lfthigh to y-axis ((<-4.832649> *DEATHAMPLIDUTE)/100) speed ((<160.027493> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-5.33
			turn rbfoot to x-axis ((<3.200369> *DEATHAMPLIDUTE)/100) speed ((<132.054120> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-4.40
			turn rbfoot to z-axis ((<1.051066> *DEATHAMPLIDUTE)/100) speed ((<3.356624> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.11
			turn rbknee to x-axis ((<-14.647949> *DEATHAMPLIDUTE)/100) speed ((<1425.092025> *DEATHAMPLIDUTE)/100) / death_speed; //delta=47.50
			turn rbknee to z-axis ((<-1.114730> *DEATHAMPLIDUTE)/100) speed ((<194.993725> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-6.50
			turn rbknee to y-axis ((<-7.565526> *DEATHAMPLIDUTE)/100) speed ((<251.189662> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-8.37
			turn rbshin to x-axis ((<9.149909> *DEATHAMPLIDUTE)/100) speed ((<557.610198> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-18.59
			turn rbshin to z-axis ((<-5.347738> *DEATHAMPLIDUTE)/100) speed ((<325.179082> *DEATHAMPLIDUTE)/100) / death_speed; //delta=10.84
			turn rbshin to y-axis ((<-0.596358> *DEATHAMPLIDUTE)/100) speed ((<18.839137> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.63
			turn rbthigh to x-axis ((<10.553798> *DEATHAMPLIDUTE)/100) speed ((<741.005669> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-24.70
			turn rbthigh to z-axis ((<-14.578486> *DEATHAMPLIDUTE)/100) speed ((<630.130248> *DEATHAMPLIDUTE)/100) / death_speed; //delta=21.00
			turn rbthigh to y-axis ((<1.733097> *DEATHAMPLIDUTE)/100) speed ((<48.066605> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.60
			turn rffoot to x-axis ((<6.350584> *DEATHAMPLIDUTE)/100) speed ((<128.233500> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-4.27
			turn rffoot to z-axis ((<-6.446713> *DEATHAMPLIDUTE)/100) speed ((<87.549055> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.92
			turn rffoot to y-axis ((<0.418317> *DEATHAMPLIDUTE)/100) speed ((<11.461334> *DEATHAMPLIDUTE)/100) / death_speed; //delta=0.38
			turn rfknee to x-axis ((<-42.722628> *DEATHAMPLIDUTE)/100) speed ((<1662.854197> *DEATHAMPLIDUTE)/100) / death_speed; //delta=55.43
			turn rfknee to z-axis ((<-5.222420> *DEATHAMPLIDUTE)/100) speed ((<232.524508> *DEATHAMPLIDUTE)/100) / death_speed; //delta=7.75
			turn rfknee to y-axis ((<-6.812523> *DEATHAMPLIDUTE)/100) speed ((<247.670745> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-8.26
			turn rfshin to x-axis ((<22.771402> *DEATHAMPLIDUTE)/100) speed ((<744.968865> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-24.83
			turn rfshin to z-axis ((<-2.178893> *DEATHAMPLIDUTE)/100) speed ((<81.302394> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.71
			turn rfshin to y-axis ((<-2.652233> *DEATHAMPLIDUTE)/100) speed ((<5.363387> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-0.18
			turn rfthigh to x-axis ((<23.067137> *DEATHAMPLIDUTE)/100) speed ((<825.628114> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-27.52
			turn rfthigh to z-axis ((<-7.133854> *DEATHAMPLIDUTE)/100) speed ((<393.120477> *DEATHAMPLIDUTE)/100) / death_speed; //delta=13.10
			turn rfthigh to y-axis ((<1.132300> *DEATHAMPLIDUTE)/100) speed ((<84.652313> *DEATHAMPLIDUTE)/100) / death_speed; //delta=2.82
			turn tail to x-axis ((<-26.227095> *DEATHAMPLIDUTE)/100) speed ((<472.087692> *DEATHAMPLIDUTE)/100) / death_speed; //delta=15.74
			turn tail to z-axis ((<-2.559056> *DEATHAMPLIDUTE)/100) speed ((<46.063010> *DEATHAMPLIDUTE)/100) / death_speed; //delta=1.54
			turn tail to y-axis ((<-21.154189> *DEATHAMPLIDUTE)/100) speed ((<380.775396> *DEATHAMPLIDUTE)/100) / death_speed; //delta=-12.69
		sleep ((33*death_speed) -1);
		}
}
