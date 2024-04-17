// For N:\animations\raptor_allterrain_idle_V1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5))
//#define IDLEIDLEMOVESCALE 100 //Higher values are bigger, 100 is default
//#define IDLEAMPLITUDE
//#deine IDLESPEED
//Animframes spacing is 12.500000, THIS SHOULD BE AN INTEGER, SPACE YOUR KEYFRAMES EVENLY!
Idle() {// For N:\animations\raptor_allterrain_idle_V1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	set-signal-mask SIGNAL_MOVE;
	sleep 100;
	if (!isMoving) { //Frame:10
			turn body to x-axis ((<1.633554> *IDLEAMPLITUDE)/100) speed ((<49.006618> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.63
			turn body to z-axis ((<-1.827850> *IDLEAMPLITUDE)/100) speed ((<54.835506> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.83
			turn body to y-axis ((<-1.973542> *IDLEAMPLITUDE)/100) speed ((<59.206272> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.97
			move head to x-axis (((([1.845191] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([55.355726] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.85
			move head to z-axis (((([1.845191] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([55.355726] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.85
			move head to y-axis (((([1.845191] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([55.355726] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.85
			turn head to x-axis ((<-4.994708> *IDLEAMPLITUDE)/100) speed ((<149.841245> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.99
			turn head to z-axis ((<1.678933> *IDLEAMPLITUDE)/100) speed ((<50.367982> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.68
			turn head to y-axis ((<5.650211> *IDLEAMPLITUDE)/100) speed ((<169.506337> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.65
			turn lbfoot to x-axis ((<-0.147008> *IDLEAMPLITUDE)/100) speed ((<4.410246> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.15
			turn lbfoot to z-axis ((<-1.370876> *IDLEAMPLITUDE)/100) speed ((<41.126295> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.37
			turn lbknee to x-axis ((<-5.885673> *IDLEAMPLITUDE)/100) speed ((<176.570191> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.89
			turn lbknee to z-axis ((<-0.715815> *IDLEAMPLITUDE)/100) speed ((<21.474448> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.72
			turn lbknee to y-axis ((<1.706505> *IDLEAMPLITUDE)/100) speed ((<51.195142> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.71
			turn lbshin to x-axis ((<1.942969> *IDLEAMPLITUDE)/100) speed ((<58.289069> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.94
			turn lbshin to z-axis ((<0.834585> *IDLEAMPLITUDE)/100) speed ((<25.037546> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.83
			turn lbthigh to x-axis ((<2.416685> *IDLEAMPLITUDE)/100) speed ((<72.500558> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.42
			turn lbthigh to z-axis ((<3.206378> *IDLEAMPLITUDE)/100) speed ((<96.191343> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.21
			turn lffoot to x-axis ((<-0.511837> *IDLEAMPLITUDE)/100) speed ((<15.355117> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.51
			turn lffoot to z-axis ((<0.389737> *IDLEAMPLITUDE)/100) speed ((<11.692120> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.39
			turn lfknee to x-axis ((<-1.074028> *IDLEAMPLITUDE)/100) speed ((<32.220848> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.07
			turn lfknee to z-axis ((<0.490067> *IDLEAMPLITUDE)/100) speed ((<14.702006> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.49
			turn lfknee to y-axis ((<0.714515> *IDLEAMPLITUDE)/100) speed ((<21.435461> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.71
			turn lfshin to x-axis ((<-0.120511> *IDLEAMPLITUDE)/100) speed ((<3.615340> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			turn lfshin to z-axis ((<0.452587> *IDLEAMPLITUDE)/100) speed ((<13.577604> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.45
			turn lfshin to y-axis ((<0.641595> *IDLEAMPLITUDE)/100) speed ((<19.247859> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.64
			turn lfthigh to x-axis ((<0.118934> *IDLEAMPLITUDE)/100) speed ((<3.568021> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.12
			turn lfthigh to z-axis ((<0.541842> *IDLEAMPLITUDE)/100) speed ((<16.255250> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.54
			turn lfthigh to y-axis ((<0.641267> *IDLEAMPLITUDE)/100) speed ((<19.238010> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.64
			turn rbfoot to x-axis ((<1.496971> *IDLEAMPLITUDE)/100) speed ((<44.909126> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.50
			turn rbfoot to z-axis ((<-1.695840> *IDLEAMPLITUDE)/100) speed ((<50.875194> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.70
			turn rbknee to x-axis ((<-1.786186> *IDLEAMPLITUDE)/100) speed ((<53.585594> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.79
			turn rbknee to z-axis ((<1.244129> *IDLEAMPLITUDE)/100) speed ((<37.323873> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.24
			turn rbknee to y-axis ((<1.551697> *IDLEAMPLITUDE)/100) speed ((<46.550923> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.55
			turn rbshin to x-axis ((<0.349530> *IDLEAMPLITUDE)/100) speed ((<10.485897> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.35
			turn rbshin to y-axis ((<0.201589> *IDLEAMPLITUDE)/100) speed ((<6.047656> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.20
			turn rbthigh to x-axis ((<-1.705471> *IDLEAMPLITUDE)/100) speed ((<51.164140> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.71
			turn rbthigh to z-axis ((<2.350453> *IDLEAMPLITUDE)/100) speed ((<70.513594> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.35
			turn rbthigh to y-axis ((<0.292358> *IDLEAMPLITUDE)/100) speed ((<8.770737> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.29
			turn rffoot to x-axis ((<0.841180> *IDLEAMPLITUDE)/100) speed ((<25.235394> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.84
			turn rffoot to z-axis ((<0.387326> *IDLEAMPLITUDE)/100) speed ((<11.619785> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.39
			turn rfknee to x-axis ((<2.637804> *IDLEAMPLITUDE)/100) speed ((<79.134111> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.64
			turn rfknee to z-axis ((<0.456059> *IDLEAMPLITUDE)/100) speed ((<13.681770> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.46
			turn rfknee to y-axis ((<0.702721> *IDLEAMPLITUDE)/100) speed ((<21.081639> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.70
			turn rfshin to x-axis ((<-1.559106> *IDLEAMPLITUDE)/100) speed ((<46.773185> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.56
			turn rfshin to z-axis ((<0.455910> *IDLEAMPLITUDE)/100) speed ((<13.677292> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.46
			turn rfshin to y-axis ((<0.661226> *IDLEAMPLITUDE)/100) speed ((<19.836786> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.66
			turn rfthigh to x-axis ((<-3.507186> *IDLEAMPLITUDE)/100) speed ((<105.215581> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.51
			turn rfthigh to z-axis ((<0.532593> *IDLEAMPLITUDE)/100) speed ((<15.977778> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.53
			turn rfthigh to y-axis ((<0.682998> *IDLEAMPLITUDE)/100) speed ((<20.489929> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.68
			move tail to x-axis (((([-0.916380] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([27.491391] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.92
			move tail to z-axis (((([-0.916380] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([27.491391] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.92
			move tail to y-axis (((([-0.916380] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([27.491391] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.92
			turn tail to x-axis ((<4.925357> *IDLEAMPLITUDE)/100) speed ((<147.760710> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.93
			turn tail to z-axis ((<-3.569429> *IDLEAMPLITUDE)/100) speed ((<107.082867> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.57
			turn tail to y-axis ((<-5.759738> *IDLEAMPLITUDE)/100) speed ((<172.792153> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.76
		sleep ((33*IDLESPEED) -1);
	}
	while(!isMoving) {
		if (!isMoving) { //Frame:20
			turn body to x-axis ((<-0.866543> *IDLEAMPLITUDE)/100) speed ((<75.002894> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.50
			turn body to z-axis ((<-3.174584> *IDLEAMPLITUDE)/100) speed ((<40.402001> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.35
			turn body to y-axis ((<-2.651666> *IDLEAMPLITUDE)/100) speed ((<20.343695> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.68
			turn head to x-axis ((<-0.174483> *IDLEAMPLITUDE)/100) speed ((<144.606744> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.82
			turn head to z-axis ((<4.275456> *IDLEAMPLITUDE)/100) speed ((<77.895709> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.60
			turn head to y-axis ((<6.957643> *IDLEAMPLITUDE)/100) speed ((<39.222942> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.31
			turn lbfoot to x-axis ((<-1.399680> *IDLEAMPLITUDE)/100) speed ((<37.580162> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.25
			turn lbfoot to z-axis ((<-2.193067> *IDLEAMPLITUDE)/100) speed ((<24.665729> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.82
			turn lbknee to x-axis ((<-1.516243> *IDLEAMPLITUDE)/100) speed ((<131.082902> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.37
			turn lbknee to z-axis ((<0.851598> *IDLEAMPLITUDE)/100) speed ((<47.022395> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.57
			turn lbknee to y-axis ((<2.274208> *IDLEAMPLITUDE)/100) speed ((<17.031091> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.57
			turn lbshin to x-axis ((<0.791806> *IDLEAMPLITUDE)/100) speed ((<34.534892> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.15
			turn lbshin to z-axis ((<0.521012> *IDLEAMPLITUDE)/100) speed ((<9.407196> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.31
			turn lbthigh to x-axis ((<2.961357> *IDLEAMPLITUDE)/100) speed ((<16.340152> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.54
			turn lbthigh to z-axis ((<4.080664> *IDLEAMPLITUDE)/100) speed ((<26.228567> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.87
			turn lffoot to x-axis ((<-0.792441> *IDLEAMPLITUDE)/100) speed ((<8.418103> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.28
			turn lfknee to x-axis ((<-3.780890> *IDLEAMPLITUDE)/100) speed ((<81.205867> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.71
			turn lfknee to z-axis ((<0.907845> *IDLEAMPLITUDE)/100) speed ((<12.533358> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.42
			turn lfknee to y-axis ((<1.117916> *IDLEAMPLITUDE)/100) speed ((<12.102011> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.40
			turn lfshin to x-axis ((<1.842022> *IDLEAMPLITUDE)/100) speed ((<58.876012> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.96
			turn lfshin to z-axis ((<0.710220> *IDLEAMPLITUDE)/100) speed ((<7.729005> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.26
			turn lfthigh to x-axis ((<3.694517> *IDLEAMPLITUDE)/100) speed ((<107.267495> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.58
			turn lfthigh to z-axis ((<1.152954> *IDLEAMPLITUDE)/100) speed ((<18.333356> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.61
			turn rbfoot to x-axis ((<0.687984> *IDLEAMPLITUDE)/100) speed ((<24.269604> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.81
			turn rbfoot to z-axis ((<-2.087124> *IDLEAMPLITUDE)/100) speed ((<11.738524> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.39
			turn rbknee to x-axis ((<5.144980> *IDLEAMPLITUDE)/100) speed ((<207.935007> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-6.93
			turn rbknee to z-axis ((<-0.206967> *IDLEAMPLITUDE)/100) speed ((<43.532883> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.45
			turn rbknee to y-axis ((<2.391581> *IDLEAMPLITUDE)/100) speed ((<25.196518> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.84
			turn rbshin to x-axis ((<-1.800246> *IDLEAMPLITUDE)/100) speed ((<64.493270> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.15
			turn rbshin to z-axis ((<0.892892> *IDLEAMPLITUDE)/100) speed ((<28.939373> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.96
			turn rbthigh to x-axis ((<-3.204655> *IDLEAMPLITUDE)/100) speed ((<44.975515> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.50
			turn rbthigh to z-axis ((<4.413180> *IDLEAMPLITUDE)/100) speed ((<61.881815> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.06
			turn rbthigh to y-axis ((<0.413982> *IDLEAMPLITUDE)/100) speed ((<3.648727> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			turn rffoot to x-axis ((<0.716973> *IDLEAMPLITUDE)/100) speed ((<3.726198> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			turn rfknee to x-axis ((<2.803156> *IDLEAMPLITUDE)/100) speed ((<4.960581> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.17
			turn rfknee to z-axis ((<0.836166> *IDLEAMPLITUDE)/100) speed ((<11.403219> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.38
			turn rfknee to y-axis ((<1.068176> *IDLEAMPLITUDE)/100) speed ((<10.963649> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.37
			turn rfshin to x-axis ((<-0.786479> *IDLEAMPLITUDE)/100) speed ((<23.178818> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.77
			turn rfshin to z-axis ((<0.725301> *IDLEAMPLITUDE)/100) speed ((<8.081739> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.27
			turn rfshin to y-axis ((<0.780416> *IDLEAMPLITUDE)/100) speed ((<3.575700> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			turn rfthigh to x-axis ((<-1.769901> *IDLEAMPLITUDE)/100) speed ((<52.118543> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.74
			turn rfthigh to z-axis ((<1.125454> *IDLEAMPLITUDE)/100) speed ((<17.785856> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.59
			turn rfthigh to y-axis ((<0.816765> *IDLEAMPLITUDE)/100) speed ((<4.013033> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.13
			turn tail to x-axis ((<-1.210241> *IDLEAMPLITUDE)/100) speed ((<184.067933> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=6.14
			turn tail to z-axis ((<-6.874507> *IDLEAMPLITUDE)/100) speed ((<99.152339> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.31
			turn tail to y-axis ((<-7.423950> *IDLEAMPLITUDE)/100) speed ((<49.926356> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.66
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:30
			turn body to y-axis ((<4.155212> *IDLEAMPLITUDE)/100) speed ((<204.206319> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=6.81
			turn head to y-axis ((<-6.166123> *IDLEAMPLITUDE)/100) speed ((<393.712961> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-13.12
			turn lbfoot to x-axis ((<2.170617> *IDLEAMPLITUDE)/100) speed ((<107.108919> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.57
			turn lbfoot to z-axis ((<2.817963> *IDLEAMPLITUDE)/100) speed ((<150.330925> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.01
			turn lbknee to x-axis ((<-2.296662> *IDLEAMPLITUDE)/100) speed ((<23.412570> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.78
			turn lbknee to z-axis ((<-0.249629> *IDLEAMPLITUDE)/100) speed ((<33.036828> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.10
			turn lbknee to y-axis ((<-2.115414> *IDLEAMPLITUDE)/100) speed ((<131.688658> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.39
			turn lbshin to x-axis ((<1.353755> *IDLEAMPLITUDE)/100) speed ((<16.858477> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.56
			turn lbshin to z-axis ((<1.474731> *IDLEAMPLITUDE)/100) speed ((<28.611580> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.95
			turn lbshin to y-axis ((<-0.980517> *IDLEAMPLITUDE)/100) speed ((<33.027839> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.10
			turn lbthigh to x-axis ((<-0.637995> *IDLEAMPLITUDE)/100) speed ((<107.980557> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.60
			turn lbthigh to z-axis ((<-0.692139> *IDLEAMPLITUDE)/100) speed ((<143.184092> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.77
			turn lbthigh to y-axis ((<-1.027710> *IDLEAMPLITUDE)/100) speed ((<32.854133> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.10
			turn lffoot to x-axis ((<2.257035> *IDLEAMPLITUDE)/100) speed ((<91.484282> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.05
			turn lffoot to z-axis ((<-1.406452> *IDLEAMPLITUDE)/100) speed ((<55.231328> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.84
			turn lfknee to x-axis ((<-4.323683> *IDLEAMPLITUDE)/100) speed ((<16.283790> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.54
			turn lfknee to z-axis ((<1.329581> *IDLEAMPLITUDE)/100) speed ((<12.652071> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.42
			turn lfknee to y-axis ((<-0.006884> *IDLEAMPLITUDE)/100) speed ((<33.743979> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.12
			turn lfshin to x-axis ((<2.312524> *IDLEAMPLITUDE)/100) speed ((<14.115043> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.47
			turn lfshin to z-axis ((<0.461549> *IDLEAMPLITUDE)/100) speed ((<7.460151> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.25
			turn lfshin to y-axis ((<-2.074083> *IDLEAMPLITUDE)/100) speed ((<84.306958> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.81
			turn lfthigh to x-axis ((<0.547356> *IDLEAMPLITUDE)/100) speed ((<94.414844> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.15
			turn lfthigh to z-axis ((<3.033632> *IDLEAMPLITUDE)/100) speed ((<56.420352> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.88
			turn lfthigh to y-axis ((<-2.023404> *IDLEAMPLITUDE)/100) speed ((<81.599204> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.72
			turn rbfoot to x-axis ((<-3.106988> *IDLEAMPLITUDE)/100) speed ((<113.849166> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.79
			turn rbfoot to z-axis ((<2.769446> *IDLEAMPLITUDE)/100) speed ((<145.697105> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.86
			turn rbknee to x-axis ((<5.308165> *IDLEAMPLITUDE)/100) speed ((<4.895530> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.16
			turn rbknee to z-axis ((<-0.928880> *IDLEAMPLITUDE)/100) speed ((<21.657384> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.72
			turn rbknee to y-axis ((<-1.986475> *IDLEAMPLITUDE)/100) speed ((<131.341688> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.38
			turn rbshin to x-axis ((<-2.299609> *IDLEAMPLITUDE)/100) speed ((<14.980884> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.50
			turn rbshin to z-axis ((<1.705081> *IDLEAMPLITUDE)/100) speed ((<24.365672> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.81
			turn rbshin to y-axis ((<-1.134743> *IDLEAMPLITUDE)/100) speed ((<37.767169> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.26
			turn rbthigh to x-axis ((<0.690727> *IDLEAMPLITUDE)/100) speed ((<116.861457> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.90
			turn rbthigh to z-axis ((<-0.408339> *IDLEAMPLITUDE)/100) speed ((<144.645575> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.82
			turn rbthigh to y-axis ((<-1.169397> *IDLEAMPLITUDE)/100) speed ((<47.501381> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.58
			turn rffoot to x-axis ((<-2.406843> *IDLEAMPLITUDE)/100) speed ((<93.714491> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.12
			turn rffoot to z-axis ((<-1.643156> *IDLEAMPLITUDE)/100) speed ((<62.094626> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.07
			turn rfknee to x-axis ((<3.188039> *IDLEAMPLITUDE)/100) speed ((<11.546467> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.38
			turn rfknee to z-axis ((<1.314912> *IDLEAMPLITUDE)/100) speed ((<14.362370> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.48
			turn rfknee to y-axis ((<-0.035308> *IDLEAMPLITUDE)/100) speed ((<33.104526> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.10
			turn rfshin to x-axis ((<-1.273232> *IDLEAMPLITUDE)/100) speed ((<14.602587> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.49
			turn rfshin to z-axis ((<0.306418> *IDLEAMPLITUDE)/100) speed ((<12.566502> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.42
			turn rfshin to y-axis ((<-2.163307> *IDLEAMPLITUDE)/100) speed ((<88.311690> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.94
			turn rfthigh to x-axis ((<1.291821> *IDLEAMPLITUDE)/100) speed ((<91.851677> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.06
			turn rfthigh to z-axis ((<3.135065> *IDLEAMPLITUDE)/100) speed ((<60.288327> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.01
			turn rfthigh to y-axis ((<-2.103995> *IDLEAMPLITUDE)/100) speed ((<87.622804> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.92
			turn tail to z-axis ((<-6.990942> *IDLEAMPLITUDE)/100) speed ((<3.493053> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			turn tail to y-axis ((<9.281112> *IDLEAMPLITUDE)/100) speed ((<501.151871> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=16.71
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:40
			turn body to x-axis ((<-1.533031> *IDLEAMPLITUDE)/100) speed ((<19.916305> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.66
			turn body to y-axis ((<3.678333> *IDLEAMPLITUDE)/100) speed ((<14.306348> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.48
			turn head to x-axis ((<1.110517> *IDLEAMPLITUDE)/100) speed ((<38.398942> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.28
			turn head to y-axis ((<-5.246693> *IDLEAMPLITUDE)/100) speed ((<27.582878> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.92
			turn lbfoot to x-axis ((<1.684142> *IDLEAMPLITUDE)/100) speed ((<14.594259> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.49
			turn lbfoot to z-axis ((<2.406275> *IDLEAMPLITUDE)/100) speed ((<12.350651> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.41
			turn lbknee to x-axis ((<-0.694741> *IDLEAMPLITUDE)/100) speed ((<48.057636> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.60
			turn lbknee to z-axis ((<0.271298> *IDLEAMPLITUDE)/100) speed ((<15.627824> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.52
			turn lbknee to y-axis ((<-1.857982> *IDLEAMPLITUDE)/100) speed ((<7.722965> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.26
			turn lbshin to x-axis ((<0.868508> *IDLEAMPLITUDE)/100) speed ((<14.557424> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.49
			turn lbshin to z-axis ((<1.233592> *IDLEAMPLITUDE)/100) speed ((<7.234169> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.24
			turn lbthigh to z-axis ((<-0.521240> *IDLEAMPLITUDE)/100) speed ((<5.126982> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.17
			turn lffoot to x-axis ((<1.996938> *IDLEAMPLITUDE)/100) speed ((<7.802923> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.26
			turn lffoot to z-axis ((<-1.282502> *IDLEAMPLITUDE)/100) speed ((<3.718484> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.12
			turn lfknee to x-axis ((<-4.654644> *IDLEAMPLITUDE)/100) speed ((<9.928820> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.33
			turn lfshin to x-axis ((<2.643967> *IDLEAMPLITUDE)/100) speed ((<9.943304> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.33
			turn lfshin to y-axis ((<-1.888147> *IDLEAMPLITUDE)/100) speed ((<5.578058> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.19
			turn lfthigh to x-axis ((<1.471203> *IDLEAMPLITUDE)/100) speed ((<27.715406> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.92
			turn lfthigh to y-axis ((<-1.874992> *IDLEAMPLITUDE)/100) speed ((<4.452389> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.15
			turn rbfoot to z-axis ((<2.507546> *IDLEAMPLITUDE)/100) speed ((<7.857012> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.26
			turn rbknee to x-axis ((<6.853580> *IDLEAMPLITUDE)/100) speed ((<46.362445> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.55
			turn rbknee to z-axis ((<-1.235576> *IDLEAMPLITUDE)/100) speed ((<9.200899> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.31
			turn rbknee to y-axis ((<-1.625238> *IDLEAMPLITUDE)/100) speed ((<10.837103> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.36
			turn rbshin to x-axis ((<-2.694116> *IDLEAMPLITUDE)/100) speed ((<11.835224> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.39
			turn rbshin to z-axis ((<1.852893> *IDLEAMPLITUDE)/100) speed ((<4.434373> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.15
			turn rbthigh to x-axis ((<0.334093> *IDLEAMPLITUDE)/100) speed ((<10.699027> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.36
			turn rbthigh to z-axis ((<0.084296> *IDLEAMPLITUDE)/100) speed ((<14.779050> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.49
			turn rffoot to x-axis ((<-2.266321> *IDLEAMPLITUDE)/100) speed ((<4.215678> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.14
			turn rffoot to z-axis ((<-1.497138> *IDLEAMPLITUDE)/100) speed ((<4.380550> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.15
			turn rfknee to x-axis ((<2.898719> *IDLEAMPLITUDE)/100) speed ((<8.679574> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.29
			turn rfshin to x-axis ((<-0.921478> *IDLEAMPLITUDE)/100) speed ((<10.552613> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.35
			turn rfshin to y-axis ((<-1.967102> *IDLEAMPLITUDE)/100) speed ((<5.886159> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.20
			turn rfthigh to x-axis ((<1.751899> *IDLEAMPLITUDE)/100) speed ((<13.802341> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.46
			turn rfthigh to y-axis ((<-1.926807> *IDLEAMPLITUDE)/100) speed ((<5.315625> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.18
			turn tail to x-axis ((<-2.845901> *IDLEAMPLITUDE)/100) speed ((<48.877489> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.63
			turn tail to y-axis ((<8.110781> *IDLEAMPLITUDE)/100) speed ((<35.109921> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.17
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:60
			turn body to x-axis ((<0.285069> *IDLEAMPLITUDE)/100) speed ((<54.543022> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.82
			turn body to z-axis ((<1.568513> *IDLEAMPLITUDE)/100) speed ((<144.858967> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.83
			turn body to y-axis ((<-1.799690> *IDLEAMPLITUDE)/100) speed ((<164.340710> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.48
			turn head to x-axis ((<-2.394809> *IDLEAMPLITUDE)/100) speed ((<105.159795> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.51
			turn head to z-axis ((<-4.869308> *IDLEAMPLITUDE)/100) speed ((<279.290354> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=9.31
			turn head to y-axis ((<5.315021> *IDLEAMPLITUDE)/100) speed ((<316.851447> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=10.56
			turn lbfoot to x-axis ((<-1.025079> *IDLEAMPLITUDE)/100) speed ((<81.276611> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.71
			turn lbfoot to z-axis ((<-1.174380> *IDLEAMPLITUDE)/100) speed ((<107.419652> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.58
			turn lbknee to x-axis ((<1.112107> *IDLEAMPLITUDE)/100) speed ((<54.205421> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.81
			turn lbknee to z-axis ((<0.083567> *IDLEAMPLITUDE)/100) speed ((<5.631926> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.19
			turn lbknee to y-axis ((<0.883362> *IDLEAMPLITUDE)/100) speed ((<82.240324> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.74
			turn lbshin to x-axis ((<-0.674838> *IDLEAMPLITUDE)/100) speed ((<46.300369> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.54
			turn lbshin to z-axis ((<-0.654808> *IDLEAMPLITUDE)/100) speed ((<56.651993> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.89
			turn lbshin to y-axis ((<0.453832> *IDLEAMPLITUDE)/100) speed ((<40.553831> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.35
			turn lbthigh to x-axis ((<0.248382> *IDLEAMPLITUDE)/100) speed ((<24.262795> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.81
			turn lbthigh to z-axis ((<0.201331> *IDLEAMPLITUDE)/100) speed ((<21.677120> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.72
			turn lbthigh to y-axis ((<0.471733> *IDLEAMPLITUDE)/100) speed ((<42.338667> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.41
			turn lffoot to x-axis ((<-1.005706> *IDLEAMPLITUDE)/100) speed ((<90.079330> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.00
			turn lffoot to z-axis ((<0.704211> *IDLEAMPLITUDE)/100) speed ((<59.601397> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.99
			turn lfknee to x-axis ((<1.923986> *IDLEAMPLITUDE)/100) speed ((<197.358909> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-6.58
			turn lfknee to z-axis ((<-0.627981> *IDLEAMPLITUDE)/100) speed ((<58.095795> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.94
			turn lfknee to y-axis ((<-0.019145> *IDLEAMPLITUDE)/100) speed ((<3.220919> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.11
			turn lfshin to x-axis ((<-0.995477> *IDLEAMPLITUDE)/100) speed ((<109.183317> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.64
			turn lfshin to z-axis ((<-0.176668> *IDLEAMPLITUDE)/100) speed ((<19.935297> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.66
			turn lfshin to y-axis ((<0.938892> *IDLEAMPLITUDE)/100) speed ((<84.811173> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.83
			turn lfthigh to x-axis ((<-0.223979> *IDLEAMPLITUDE)/100) speed ((<50.855443> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.70
			turn lfthigh to z-axis ((<-1.430893> *IDLEAMPLITUDE)/100) speed ((<131.414215> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.38
			turn lfthigh to y-axis ((<0.893170> *IDLEAMPLITUDE)/100) speed ((<83.044857> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.77
			turn rbfoot to x-axis ((<1.226084> *IDLEAMPLITUDE)/100) speed ((<132.633343> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.42
			turn rbfoot to z-axis ((<-1.202051> *IDLEAMPLITUDE)/100) speed ((<111.287890> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.71
			turn rbknee to x-axis ((<-2.588086> *IDLEAMPLITUDE)/100) speed ((<283.249964> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=9.44
			turn rbknee to z-axis ((<0.477300> *IDLEAMPLITUDE)/100) speed ((<51.386280> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.71
			turn rbknee to y-axis ((<0.818352> *IDLEAMPLITUDE)/100) speed ((<73.307704> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.44
			turn rbshin to x-axis ((<1.089850> *IDLEAMPLITUDE)/100) speed ((<113.518967> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.78
			turn rbshin to z-axis ((<-0.835314> *IDLEAMPLITUDE)/100) speed ((<80.646220> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.69
			turn rbshin to y-axis ((<0.475435> *IDLEAMPLITUDE)/100) speed ((<46.870987> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.56
			turn rbthigh to x-axis ((<-0.065355> *IDLEAMPLITUDE)/100) speed ((<11.983432> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.40
			turn rbthigh to z-axis ((<-0.021821> *IDLEAMPLITUDE)/100) speed ((<3.183526> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.11
			turn rbthigh to y-axis ((<0.486543> *IDLEAMPLITUDE)/100) speed ((<47.871244> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.60
			turn rffoot to x-axis ((<1.052739> *IDLEAMPLITUDE)/100) speed ((<99.571787> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.32
			turn rffoot to z-axis ((<0.655526> *IDLEAMPLITUDE)/100) speed ((<64.579912> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.15
			turn rfknee to x-axis ((<-1.693622> *IDLEAMPLITUDE)/100) speed ((<137.770242> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.59
			turn rfknee to z-axis ((<-0.630117> *IDLEAMPLITUDE)/100) speed ((<57.984627> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.93
			turn rfshin to x-axis ((<0.712820> *IDLEAMPLITUDE)/100) speed ((<49.028938> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.63
			turn rfshin to z-axis ((<-0.207403> *IDLEAMPLITUDE)/100) speed ((<16.929554> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.56
			turn rfshin to y-axis ((<0.920233> *IDLEAMPLITUDE)/100) speed ((<86.620042> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.89
			turn rfthigh to x-axis ((<-0.373671> *IDLEAMPLITUDE)/100) speed ((<63.767099> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.13
			turn rfthigh to z-axis ((<-1.410427> *IDLEAMPLITUDE)/100) speed ((<133.447837> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.45
			turn rfthigh to y-axis ((<0.879601> *IDLEAMPLITUDE)/100) speed ((<84.192244> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.81
			turn tail to x-axis ((<1.615981> *IDLEAMPLITUDE)/100) speed ((<133.856460> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.46
			turn tail to z-axis ((<4.765737> *IDLEAMPLITUDE)/100) speed ((<355.504853> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-11.85
			turn tail to y-axis ((<-5.333079> *IDLEAMPLITUDE)/100) speed ((<403.315815> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-13.44
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:70
			turn body to x-axis ((<0.508595> *IDLEAMPLITUDE)/100) speed ((<6.705769> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.22
			turn body to z-axis ((<-0.246760> *IDLEAMPLITUDE)/100) speed ((<54.458181> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.82
			turn body to y-axis ((<1.127313> *IDLEAMPLITUDE)/100) speed ((<87.810096> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.93
			turn head to x-axis ((<-2.825770> *IDLEAMPLITUDE)/100) speed ((<12.928818> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.43
			turn head to z-axis ((<-1.369434> *IDLEAMPLITUDE)/100) speed ((<104.996216> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.50
			turn head to y-axis ((<-0.328286> *IDLEAMPLITUDE)/100) speed ((<169.299231> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.64
			turn lbfoot to x-axis ((<0.833034> *IDLEAMPLITUDE)/100) speed ((<55.743388> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.86
			turn lbfoot to z-axis ((<0.862397> *IDLEAMPLITUDE)/100) speed ((<61.103313> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.04
			turn lbknee to x-axis ((<-1.547743> *IDLEAMPLITUDE)/100) speed ((<79.795498> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.66
			turn lbknee to z-axis ((<-0.490796> *IDLEAMPLITUDE)/100) speed ((<17.230909> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.57
			turn lbknee to y-axis ((<-0.656647> *IDLEAMPLITUDE)/100) speed ((<46.200275> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.54
			turn lbshin to x-axis ((<0.554424> *IDLEAMPLITUDE)/100) speed ((<36.877867> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.23
			turn lbshin to z-axis ((<0.367589> *IDLEAMPLITUDE)/100) speed ((<30.671897> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.02
			turn lbshin to y-axis ((<-0.224331> *IDLEAMPLITUDE)/100) speed ((<20.344891> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.68
			turn lbthigh to x-axis ((<-0.362582> *IDLEAMPLITUDE)/100) speed ((<18.328935> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.61
			turn lbthigh to z-axis ((<-0.490906> *IDLEAMPLITUDE)/100) speed ((<20.767094> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.69
			turn lbthigh to y-axis ((<-0.243046> *IDLEAMPLITUDE)/100) speed ((<21.443368> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.71
			turn lffoot to x-axis ((<0.593354> *IDLEAMPLITUDE)/100) speed ((<47.971799> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.60
			turn lffoot to z-axis ((<-0.346239> *IDLEAMPLITUDE)/100) speed ((<31.513499> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.05
			turn lfknee to x-axis ((<-0.090127> *IDLEAMPLITUDE)/100) speed ((<60.423408> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.01
			turn lfknee to z-axis ((<0.153871> *IDLEAMPLITUDE)/100) speed ((<23.455557> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.78
			turn lfknee to y-axis ((<-0.137593> *IDLEAMPLITUDE)/100) speed ((<3.553429> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.12
			turn lfshin to x-axis ((<-0.075608> *IDLEAMPLITUDE)/100) speed ((<27.596063> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.92
			turn lfshin to z-axis ((<-0.012974> *IDLEAMPLITUDE)/100) speed ((<4.910832> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.16
			turn lfshin to y-axis ((<-0.501524> *IDLEAMPLITUDE)/100) speed ((<43.212484> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.44
			turn lfthigh to x-axis ((<-0.934614> *IDLEAMPLITUDE)/100) speed ((<21.319066> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.71
			turn lfthigh to z-axis ((<0.453337> *IDLEAMPLITUDE)/100) speed ((<56.526911> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.88
			turn lfthigh to y-axis ((<-0.482862> *IDLEAMPLITUDE)/100) speed ((<41.280971> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.38
			turn rbfoot to x-axis ((<-0.409699> *IDLEAMPLITUDE)/100) speed ((<49.073468> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.64
			turn rbfoot to z-axis ((<0.726292> *IDLEAMPLITUDE)/100) speed ((<57.850275> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.93
			turn rbknee to x-axis ((<-0.830489> *IDLEAMPLITUDE)/100) speed ((<52.727920> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.76
			turn rbknee to z-axis ((<0.137949> *IDLEAMPLITUDE)/100) speed ((<10.180507> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.34
			turn rbknee to y-axis ((<-0.695411> *IDLEAMPLITUDE)/100) speed ((<45.412894> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.51
			turn rbshin to x-axis ((<0.137171> *IDLEAMPLITUDE)/100) speed ((<28.580349> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.95
			turn rbshin to z-axis ((<0.084286> *IDLEAMPLITUDE)/100) speed ((<27.587987> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.92
			turn rbshin to y-axis ((<-0.202197> *IDLEAMPLITUDE)/100) speed ((<20.328964> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.68
			turn rbthigh to x-axis ((<0.578922> *IDLEAMPLITUDE)/100) speed ((<19.328311> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.64
			turn rbthigh to z-axis ((<-0.718058> *IDLEAMPLITUDE)/100) speed ((<20.887084> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.70
			turn rbthigh to y-axis ((<-0.217503> *IDLEAMPLITUDE)/100) speed ((<21.121379> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.70
			turn rffoot to x-axis ((<-0.500162> *IDLEAMPLITUDE)/100) speed ((<46.587026> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.55
			turn rffoot to z-axis ((<-0.355035> *IDLEAMPLITUDE)/100) speed ((<30.316847> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.01
			turn rfknee to x-axis ((<0.580093> *IDLEAMPLITUDE)/100) speed ((<68.211441> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.27
			turn rfknee to z-axis ((<0.151461> *IDLEAMPLITUDE)/100) speed ((<23.447362> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.78
			turn rfknee to y-axis ((<-0.136786> *IDLEAMPLITUDE)/100) speed ((<3.298967> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.11
			turn rfshin to x-axis ((<-0.457011> *IDLEAMPLITUDE)/100) speed ((<35.094928> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.17
			turn rfshin to z-axis ((<-0.019798> *IDLEAMPLITUDE)/100) speed ((<5.628150> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.19
			turn rfshin to y-axis ((<-0.504111> *IDLEAMPLITUDE)/100) speed ((<42.730336> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.42
			turn rfthigh to x-axis ((<-0.129828> *IDLEAMPLITUDE)/100) speed ((<7.315268> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.24
			turn rfthigh to z-axis ((<0.456453> *IDLEAMPLITUDE)/100) speed ((<56.006375> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.87
			turn rfthigh to y-axis ((<-0.487761> *IDLEAMPLITUDE)/100) speed ((<41.020868> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.37
			turn tail to x-axis ((<2.164545> *IDLEAMPLITUDE)/100) speed ((<16.456919> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.55
			turn tail to z-axis ((<0.310796> *IDLEAMPLITUDE)/100) speed ((<133.648250> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.45
			turn tail to y-axis ((<1.850209> *IDLEAMPLITUDE)/100) speed ((<215.498652> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=7.18
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:80
			turn body to x-axis ((<-1.663825> *IDLEAMPLITUDE)/100) speed ((<65.172603> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.17
			turn body to z-axis ((<-0.392649> *IDLEAMPLITUDE)/100) speed ((<4.376681> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.15
			turn body to y-axis ((<0.788730> *IDLEAMPLITUDE)/100) speed ((<10.157486> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.34
			turn head to x-axis ((<1.362690> *IDLEAMPLITUDE)/100) speed ((<125.653788> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.19
			turn head to z-axis ((<-1.088157> *IDLEAMPLITUDE)/100) speed ((<8.438313> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.28
			turn head to y-axis ((<0.324507> *IDLEAMPLITUDE)/100) speed ((<19.583793> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.65
			turn lbfoot to x-axis ((<-0.251553> *IDLEAMPLITUDE)/100) speed ((<32.537622> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.08
			turn lbfoot to z-axis ((<0.394230> *IDLEAMPLITUDE)/100) speed ((<14.045023> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.47
			turn lbknee to x-axis ((<3.302629> *IDLEAMPLITUDE)/100) speed ((<145.511181> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.85
			turn lbknee to z-axis ((<0.890672> *IDLEAMPLITUDE)/100) speed ((<41.444046> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.38
			turn lbshin to x-axis ((<-0.854905> *IDLEAMPLITUDE)/100) speed ((<42.279883> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.41
			turn lbshin to z-axis ((<-0.197043> *IDLEAMPLITUDE)/100) speed ((<16.938953> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.56
			turn lbthigh to x-axis ((<-0.544001> *IDLEAMPLITUDE)/100) speed ((<5.442550> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.18
			turn lbthigh to z-axis ((<-0.671882> *IDLEAMPLITUDE)/100) speed ((<5.429296> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.18
			turn lffoot to x-axis ((<0.274388> *IDLEAMPLITUDE)/100) speed ((<9.568962> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.32
			turn lfknee to x-axis ((<-1.308425> *IDLEAMPLITUDE)/100) speed ((<36.548917> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.22
			turn lfshin to x-axis ((<1.126359> *IDLEAMPLITUDE)/100) speed ((<36.059012> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.20
			turn lfshin to y-axis ((<-0.375984> *IDLEAMPLITUDE)/100) speed ((<3.766216> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.13
			turn lfthigh to x-axis ((<1.570547> *IDLEAMPLITUDE)/100) speed ((<75.154855> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.51
			turn lfthigh to y-axis ((<-0.369779> *IDLEAMPLITUDE)/100) speed ((<3.392475> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.11
			turn rbfoot to x-axis ((<-1.212480> *IDLEAMPLITUDE)/100) speed ((<24.083455> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.80
			turn rbknee to x-axis ((<4.148366> *IDLEAMPLITUDE)/100) speed ((<149.365630> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.98
			turn rbknee to z-axis ((<-1.055621> *IDLEAMPLITUDE)/100) speed ((<35.807123> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.19
			turn rbknee to y-axis ((<-0.297012> *IDLEAMPLITUDE)/100) speed ((<11.951986> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.40
			turn rbshin to x-axis ((<-1.286664> *IDLEAMPLITUDE)/100) speed ((<42.715056> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.42
			turn rbshin to z-axis ((<0.637682> *IDLEAMPLITUDE)/100) speed ((<16.601907> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.55
			turn rbthigh to x-axis ((<0.005626> *IDLEAMPLITUDE)/100) speed ((<17.198875> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.57
			turn rbthigh to z-axis ((<0.112712> *IDLEAMPLITUDE)/100) speed ((<24.923075> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.83
			turn rfknee to x-axis ((<-0.355053> *IDLEAMPLITUDE)/100) speed ((<28.054382> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.94
			turn rfshin to x-axis ((<0.650260> *IDLEAMPLITUDE)/100) speed ((<33.218136> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.11
			turn rfshin to y-axis ((<-0.378211> *IDLEAMPLITUDE)/100) speed ((<3.777021> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.13
			turn rfthigh to x-axis ((<1.920992> *IDLEAMPLITUDE)/100) speed ((<61.524611> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.05
			turn rfthigh to y-axis ((<-0.372846> *IDLEAMPLITUDE)/100) speed ((<3.447454> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.11
			turn tail to x-axis ((<-3.166887> *IDLEAMPLITUDE)/100) speed ((<159.942979> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.33
			turn tail to z-axis ((<-0.047238> *IDLEAMPLITUDE)/100) speed ((<10.741009> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.36
			turn tail to y-axis ((<1.019278> *IDLEAMPLITUDE)/100) speed ((<24.927934> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.83
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:100
			turn body to x-axis ((<2.894842> *IDLEAMPLITUDE)/100) speed ((<136.760019> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.56
			turn body to z-axis ((<0.231848> *IDLEAMPLITUDE)/100) speed ((<18.734915> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.62
			turn body to y-axis ((<0.443825> *IDLEAMPLITUDE)/100) speed ((<10.347155> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.34
			turn head to x-axis ((<-7.426493> *IDLEAMPLITUDE)/100) speed ((<263.675479> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=8.79
			turn head to z-axis ((<-2.292197> *IDLEAMPLITUDE)/100) speed ((<36.121205> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.20
			turn head to y-axis ((<0.989489> *IDLEAMPLITUDE)/100) speed ((<19.949474> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.66
			turn lbfoot to x-axis ((<1.362842> *IDLEAMPLITUDE)/100) speed ((<48.431864> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.61
			turn lbfoot to z-axis ((<0.617633> *IDLEAMPLITUDE)/100) speed ((<6.702101> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.22
			turn lbknee to x-axis ((<-6.572111> *IDLEAMPLITUDE)/100) speed ((<296.242207> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=9.87
			turn lbknee to z-axis ((<-1.876753> *IDLEAMPLITUDE)/100) speed ((<83.022739> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.77
			turn lbknee to y-axis ((<-0.266493> *IDLEAMPLITUDE)/100) speed ((<9.193585> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.31
			turn lbshin to x-axis ((<1.984308> *IDLEAMPLITUDE)/100) speed ((<85.176392> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.84
			turn lbshin to z-axis ((<0.772515> *IDLEAMPLITUDE)/100) speed ((<29.086734> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.97
			turn lbthigh to x-axis ((<0.329769> *IDLEAMPLITUDE)/100) speed ((<26.213092> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.87
			turn lbthigh to z-axis ((<0.239025> *IDLEAMPLITUDE)/100) speed ((<27.327222> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.91
			turn lffoot to x-axis ((<0.441086> *IDLEAMPLITUDE)/100) speed ((<5.0> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.17
			turn lffoot to z-axis ((<-0.106414> *IDLEAMPLITUDE)/100) speed ((<4.725204> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.16
			turn lfknee to x-axis ((<1.656483> *IDLEAMPLITUDE)/100) speed ((<88.947242> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.96
			turn lfknee to z-axis ((<-0.047297> *IDLEAMPLITUDE)/100) speed ((<6.856678> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.23
			turn lfshin to x-axis ((<-1.619780> *IDLEAMPLITUDE)/100) speed ((<82.384177> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.75
			turn lfshin to z-axis ((<-0.071020> *IDLEAMPLITUDE)/100) speed ((<3.247547> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.11
			turn lfshin to y-axis ((<-0.167056> *IDLEAMPLITUDE)/100) speed ((<6.267844> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.21
			turn lfthigh to x-axis ((<-3.370983> *IDLEAMPLITUDE)/100) speed ((<148.245917> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.94
			turn lfthigh to z-axis ((<-0.017621> *IDLEAMPLITUDE)/100) speed ((<14.267450> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.48
			turn lfthigh to y-axis ((<-0.165782> *IDLEAMPLITUDE)/100) speed ((<6.119929> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.20
			turn rbfoot to x-axis ((<0.936105> *IDLEAMPLITUDE)/100) speed ((<64.457569> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.15
			turn rbfoot to z-axis ((<0.051315> *IDLEAMPLITUDE)/100) speed ((<19.533267> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.65
			turn rbknee to x-axis ((<-6.851075> *IDLEAMPLITUDE)/100) speed ((<329.983224> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=11.00
			turn rbknee to z-axis ((<1.664520> *IDLEAMPLITUDE)/100) speed ((<81.604229> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.72
			turn rbknee to y-axis ((<-0.405269> *IDLEAMPLITUDE)/100) speed ((<3.247709> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.11
			turn rbshin to x-axis ((<2.065849> *IDLEAMPLITUDE)/100) speed ((<100.575396> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.35
			turn rbshin to z-axis ((<-0.795618> *IDLEAMPLITUDE)/100) speed ((<42.999019> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.43
			turn rbshin to y-axis ((<0.052426> *IDLEAMPLITUDE)/100) speed ((<8.607738> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.29
			turn rbthigh to x-axis ((<0.946067> *IDLEAMPLITUDE)/100) speed ((<28.213240> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.94
			turn rbthigh to z-axis ((<-1.179572> *IDLEAMPLITUDE)/100) speed ((<38.768522> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.29
			turn rbthigh to y-axis ((<0.050899> *IDLEAMPLITUDE)/100) speed ((<8.756207> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.29
			turn rffoot to x-axis ((<0.085837> *IDLEAMPLITUDE)/100) speed ((<19.173822> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.64
			turn rffoot to z-axis ((<-0.106763> *IDLEAMPLITUDE)/100) speed ((<4.902674> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.16
			turn rfknee to x-axis ((<1.210438> *IDLEAMPLITUDE)/100) speed ((<46.964746> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.57
			turn rfknee to z-axis ((<-0.048432> *IDLEAMPLITUDE)/100) speed ((<6.867405> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.23
			turn rfshin to x-axis ((<-1.464053> *IDLEAMPLITUDE)/100) speed ((<63.429402> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.11
			turn rfshin to z-axis ((<-0.071257> *IDLEAMPLITUDE)/100) speed ((<3.120670> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.10
			turn rfshin to y-axis ((<-0.166547> *IDLEAMPLITUDE)/100) speed ((<6.349905> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.21
			turn rfthigh to x-axis ((<-2.725416> *IDLEAMPLITUDE)/100) speed ((<139.392234> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.65
			turn rfthigh to z-axis ((<-0.017817> *IDLEAMPLITUDE)/100) speed ((<14.353755> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.48
			turn rfthigh to y-axis ((<-0.165059> *IDLEAMPLITUDE)/100) speed ((<6.233618> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.21
			turn tail to x-axis ((<8.020742> *IDLEAMPLITUDE)/100) speed ((<335.628862> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-11.19
			turn tail to z-axis ((<1.485368> *IDLEAMPLITUDE)/100) speed ((<45.978185> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.53
			turn tail to y-axis ((<0.172831> *IDLEAMPLITUDE)/100) speed ((<25.393416> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.85
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:110
			turn body to x-axis ((<1.633554> *IDLEAMPLITUDE)/100) speed ((<37.838650> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.26
			turn body to z-axis ((<-1.827850> *IDLEAMPLITUDE)/100) speed ((<61.790946> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.06
			turn body to y-axis ((<-1.973542> *IDLEAMPLITUDE)/100) speed ((<72.521021> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.42
			turn head to x-axis ((<-4.994708> *IDLEAMPLITUDE)/100) speed ((<72.953541> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.43
			turn head to z-axis ((<1.678933> *IDLEAMPLITUDE)/100) speed ((<119.133898> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.97
			turn head to y-axis ((<5.650211> *IDLEAMPLITUDE)/100) speed ((<139.821658> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.66
			turn lbfoot to x-axis ((<-0.147008> *IDLEAMPLITUDE)/100) speed ((<45.295517> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.51
			turn lbfoot to z-axis ((<-1.370876> *IDLEAMPLITUDE)/100) speed ((<59.655284> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.99
			turn lbknee to x-axis ((<-5.885673> *IDLEAMPLITUDE)/100) speed ((<20.593136> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.69
			turn lbknee to z-axis ((<-0.715815> *IDLEAMPLITUDE)/100) speed ((<34.828138> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.16
			turn lbknee to y-axis ((<1.706505> *IDLEAMPLITUDE)/100) speed ((<59.189939> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.97
			turn lbshin to y-axis ((<0.060985> *IDLEAMPLITUDE)/100) speed ((<6.210214> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.21
			turn lbthigh to x-axis ((<2.416685> *IDLEAMPLITUDE)/100) speed ((<62.607485> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.09
			turn lbthigh to z-axis ((<3.206378> *IDLEAMPLITUDE)/100) speed ((<89.020591> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.97
			turn lbthigh to y-axis ((<0.011024> *IDLEAMPLITUDE)/100) speed ((<4.570783> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.15
			turn lffoot to x-axis ((<-0.511837> *IDLEAMPLITUDE)/100) speed ((<28.587697> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.95
			turn lffoot to z-axis ((<0.389737> *IDLEAMPLITUDE)/100) speed ((<14.884533> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.50
			turn lfknee to x-axis ((<-1.074028> *IDLEAMPLITUDE)/100) speed ((<81.915350> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.73
			turn lfknee to z-axis ((<0.490067> *IDLEAMPLITUDE)/100) speed ((<16.120922> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.54
			turn lfknee to y-axis ((<0.714515> *IDLEAMPLITUDE)/100) speed ((<25.125489> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.84
			turn lfshin to x-axis ((<-0.120511> *IDLEAMPLITUDE)/100) speed ((<44.978060> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.50
			turn lfshin to z-axis ((<0.452587> *IDLEAMPLITUDE)/100) speed ((<15.708207> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.52
			turn lfshin to y-axis ((<0.641595> *IDLEAMPLITUDE)/100) speed ((<24.259530> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.81
			turn lfthigh to x-axis ((<0.118934> *IDLEAMPLITUDE)/100) speed ((<104.697514> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.49
			turn lfthigh to z-axis ((<0.541842> *IDLEAMPLITUDE)/100) speed ((<16.783880> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.56
			turn lfthigh to y-axis ((<0.641267> *IDLEAMPLITUDE)/100) speed ((<24.211464> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.81
			turn rbfoot to x-axis ((<1.496971> *IDLEAMPLITUDE)/100) speed ((<16.825970> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.56
			turn rbfoot to z-axis ((<-1.695840> *IDLEAMPLITUDE)/100) speed ((<52.414642> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.75
			turn rbknee to x-axis ((<-1.786186> *IDLEAMPLITUDE)/100) speed ((<151.946657> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.06
			turn rbknee to z-axis ((<1.244129> *IDLEAMPLITUDE)/100) speed ((<12.611714> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.42
			turn rbknee to y-axis ((<1.551697> *IDLEAMPLITUDE)/100) speed ((<58.708980> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.96
			turn rbshin to x-axis ((<0.349530> *IDLEAMPLITUDE)/100) speed ((<51.489579> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.72
			turn rbshin to z-axis ((<-0.071754> *IDLEAMPLITUDE)/100) speed ((<21.715928> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.72
			turn rbshin to y-axis ((<0.201589> *IDLEAMPLITUDE)/100) speed ((<4.474869> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.15
			turn rbthigh to x-axis ((<-1.705471> *IDLEAMPLITUDE)/100) speed ((<79.546160> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.65
			turn rbthigh to z-axis ((<2.350453> *IDLEAMPLITUDE)/100) speed ((<105.900766> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.53
			turn rbthigh to y-axis ((<0.292358> *IDLEAMPLITUDE)/100) speed ((<7.243756> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.24
			turn rffoot to x-axis ((<0.841180> *IDLEAMPLITUDE)/100) speed ((<22.660279> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.76
			turn rffoot to z-axis ((<0.387326> *IDLEAMPLITUDE)/100) speed ((<14.822686> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.49
			turn rfknee to x-axis ((<2.637804> *IDLEAMPLITUDE)/100) speed ((<42.820964> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.43
			turn rfknee to z-axis ((<0.456059> *IDLEAMPLITUDE)/100) speed ((<15.134740> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.50
			turn rfknee to y-axis ((<0.702721> *IDLEAMPLITUDE)/100) speed ((<24.772846> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.83
			turn rfshin to z-axis ((<0.455910> *IDLEAMPLITUDE)/100) speed ((<15.815001> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.53
			turn rfshin to y-axis ((<0.661226> *IDLEAMPLITUDE)/100) speed ((<24.833200> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.83
			turn rfthigh to x-axis ((<-3.507186> *IDLEAMPLITUDE)/100) speed ((<23.453107> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.78
			turn rfthigh to z-axis ((<0.532593> *IDLEAMPLITUDE)/100) speed ((<16.512289> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.55
			turn rfthigh to y-axis ((<0.682998> *IDLEAMPLITUDE)/100) speed ((<25.441698> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.85
			turn tail to x-axis ((<4.925357> *IDLEAMPLITUDE)/100) speed ((<92.861536> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.10
			turn tail to z-axis ((<-3.569429> *IDLEAMPLITUDE)/100) speed ((<151.643909> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.05
			turn tail to y-axis ((<-5.759738> *IDLEAMPLITUDE)/100) speed ((<177.977081> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.93
		sleep ((33*IDLESPEED) -1);
		}
	}
}
// Call this from StopMoving()!
StopIdle() {
	//IDLESPEED = 10; // tune restore speed here, higher values are slower restore speeds
	move head to x-axis ([0.0]*IDLEMOVESCALE)/100 speed (([55.355726]*IDLEMOVESCALE)/100) / IDLESPEED;
	move head to y-axis ([0.0]*IDLEMOVESCALE)/100 speed (([55.355726]*IDLEMOVESCALE)/100) / IDLESPEED;
	move head to z-axis ([0.0]*IDLEMOVESCALE)/100 speed (([55.355726]*IDLEMOVESCALE)/100) / IDLESPEED;
	move tail to x-axis ([0.0]*IDLEMOVESCALE)/100 speed (([27.491391]*IDLEMOVESCALE)/100) / IDLESPEED;
	move tail to y-axis ([0.0]*IDLEMOVESCALE)/100 speed (([27.491391]*IDLEMOVESCALE)/100) / IDLESPEED;
	move tail to z-axis ([0.0]*IDLEMOVESCALE)/100 speed (([27.491391]*IDLEMOVESCALE)/100) / IDLESPEED;
	turn body to x-axis <0.0> speed <75.002894> / IDLESPEED;
	turn body to y-axis <0.0> speed <204.206319> / IDLESPEED;
	turn body to z-axis <0.0> speed <72.429483> / IDLESPEED;
	turn head to x-axis <0.0> speed <149.841245> / IDLESPEED;
	turn head to y-axis <0.0> speed <393.712961> / IDLESPEED;
	turn head to z-axis <0.0> speed <139.645177> / IDLESPEED;
	turn lbfoot to x-axis <0.0> speed <107.108919> / IDLESPEED;
	turn lbfoot to z-axis <0.0> speed <150.330925> / IDLESPEED;
	turn lbknee to x-axis <0.0> speed <176.570191> / IDLESPEED;
	turn lbknee to y-axis <0.0> speed <131.688658> / IDLESPEED;
	turn lbknee to z-axis <0.0> speed <47.022395> / IDLESPEED;
	turn lbshin to x-axis <0.0> speed <58.289069> / IDLESPEED;
	turn lbshin to y-axis <0.0> speed <33.027839> / IDLESPEED;
	turn lbshin to z-axis <0.0> speed <30.671897> / IDLESPEED;
	turn lbthigh to x-axis <0.0> speed <107.980557> / IDLESPEED;
	turn lbthigh to y-axis <0.0> speed <32.854133> / IDLESPEED;
	turn lbthigh to z-axis <0.0> speed <143.184092> / IDLESPEED;
	turn lffoot to x-axis <0.0> speed <91.484282> / IDLESPEED;
	turn lffoot to z-axis <0.0> speed <55.231328> / IDLESPEED;
	turn lfknee to x-axis <0.0> speed <98.679455> / IDLESPEED;
	turn lfknee to y-axis <0.0> speed <33.743979> / IDLESPEED;
	turn lfknee to z-axis <0.0> speed <29.047898> / IDLESPEED;
	turn lfshin to x-axis <0.0> speed <58.876012> / IDLESPEED;
	turn lfshin to y-axis <0.0> speed <84.306958> / IDLESPEED;
	turn lfshin to z-axis <0.0> speed <15.708207> / IDLESPEED;
	turn lfthigh to x-axis <0.0> speed <107.267495> / IDLESPEED;
	turn lfthigh to y-axis <0.0> speed <81.599204> / IDLESPEED;
	turn lfthigh to z-axis <0.0> speed <65.707108> / IDLESPEED;
	turn rbfoot to x-axis <0.0> speed <113.849166> / IDLESPEED;
	turn rbfoot to z-axis <0.0> speed <145.697105> / IDLESPEED;
	turn rbknee to x-axis <0.0> speed <207.935007> / IDLESPEED;
	turn rbknee to y-axis <0.0> speed <131.341688> / IDLESPEED;
	turn rbknee to z-axis <0.0> speed <43.532883> / IDLESPEED;
	turn rbshin to x-axis <0.0> speed <64.493270> / IDLESPEED;
	turn rbshin to y-axis <0.0> speed <37.767169> / IDLESPEED;
	turn rbshin to z-axis <0.0> speed <40.323110> / IDLESPEED;
	turn rbthigh to x-axis <0.0> speed <116.861457> / IDLESPEED;
	turn rbthigh to y-axis <0.0> speed <47.501381> / IDLESPEED;
	turn rbthigh to z-axis <0.0> speed <144.645575> / IDLESPEED;
	turn rffoot to x-axis <0.0> speed <93.714491> / IDLESPEED;
	turn rffoot to z-axis <0.0> speed <62.094626> / IDLESPEED;
	turn rfknee to x-axis <0.0> speed <79.134111> / IDLESPEED;
	turn rfknee to y-axis <0.0> speed <33.104526> / IDLESPEED;
	turn rfknee to z-axis <0.0> speed <28.992314> / IDLESPEED;
	turn rfshin to x-axis <0.0> speed <46.773185> / IDLESPEED;
	turn rfshin to y-axis <0.0> speed <88.311690> / IDLESPEED;
	turn rfshin to z-axis <0.0> speed <15.815001> / IDLESPEED;
	turn rfthigh to x-axis <0.0> speed <105.215581> / IDLESPEED;
	turn rfthigh to y-axis <0.0> speed <87.622804> / IDLESPEED;
	turn rfthigh to z-axis <0.0> speed <66.723918> / IDLESPEED;
	turn tail to x-axis <0.0> speed <184.067933> / IDLESPEED;
	turn tail to y-axis <0.0> speed <501.151871> / IDLESPEED;
	turn tail to z-axis <0.0> speed <177.752427> / IDLESPEED;
}

