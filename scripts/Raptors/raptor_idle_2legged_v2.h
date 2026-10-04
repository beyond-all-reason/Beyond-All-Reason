// For N:\animations\Raptors\raptor_idle_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5))
//#define IDLEMOVESCALE 100 //Higher values are bigger, 100 is default
//#define IDLEAMPLITUDE
//#deine IDLESPEED

Idle() {// For N:\animations\Raptors\raptor_idle_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	sleep 300;
	set-signal-mask SIGNAL_MOVE;
	if (!isMoving) { //Frame:10
			move body to z-axis (((([-0.355065] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([10.651937] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.36
			move body to y-axis (((([1.471361] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([44.140835] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.47
			turn body to x-axis ((<2.513906> *IDLEAMPLITUDE)/100) speed ((<75.417179> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.51
			turn body to z-axis ((<-1.387327> *IDLEAMPLITUDE)/100) speed ((<41.619816> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.39
			turn body to y-axis ((<-1.420203> *IDLEAMPLITUDE)/100) speed ((<42.606091> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.42
			turn head to x-axis ((<-0.718671> *IDLEAMPLITUDE)/100) speed ((<77.352786> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.58
			turn head to z-axis ((<3.930814> *IDLEAMPLITUDE)/100) speed ((<37.876315> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.26
			turn head to y-axis ((<-1.420203> *IDLEAMPLITUDE)/100) speed ((<42.606091> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.42
			turn lfoot to x-axis ((<0.954559> *IDLEAMPLITUDE)/100) speed ((<28.636767> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.95
			turn lfoot to z-axis ((<0.235100> *IDLEAMPLITUDE)/100) speed ((<7.053006> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.24
			turn lfoot to y-axis ((<0.747221> *IDLEAMPLITUDE)/100) speed ((<22.416618> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.75
			turn lknee to x-axis ((<-7.869954> *IDLEAMPLITUDE)/100) speed ((<236.098617> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=7.87
			turn lshin to x-axis ((<2.808344> *IDLEAMPLITUDE)/100) speed ((<84.250311> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.81
			turn lthigh to x-axis ((<1.612625> *IDLEAMPLITUDE)/100) speed ((<48.378770> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.61
			turn lthigh to z-axis ((<1.168209> *IDLEAMPLITUDE)/100) speed ((<35.046276> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.17
			turn lthigh to y-axis ((<0.648978> *IDLEAMPLITUDE)/100) speed ((<19.469350> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.65
			turn rfoot to x-axis ((<2.417855> *IDLEAMPLITUDE)/100) speed ((<55.853848> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.86
			turn rfoot to z-axis ((<0.218309> *IDLEAMPLITUDE)/100) speed ((<6.549268> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.22
			turn rfoot to y-axis ((<0.755482> *IDLEAMPLITUDE)/100) speed ((<22.664455> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.76
			turn rknee to x-axis ((<-4.732346> *IDLEAMPLITUDE)/100) speed ((<150.524252> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.02
			turn rshin to x-axis ((<1.393669> *IDLEAMPLITUDE)/100) speed ((<39.476762> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.32
			turn rthigh to x-axis ((<-0.898270> *IDLEAMPLITUDE)/100) speed ((<19.634824> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.65
			turn rthigh to z-axis ((<1.173693> *IDLEAMPLITUDE)/100) speed ((<35.210780> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.17
			turn rthigh to y-axis ((<0.689405> *IDLEAMPLITUDE)/100) speed ((<20.682159> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.69
			turn tail to x-axis ((<2.513906> *IDLEAMPLITUDE)/100) speed ((<75.417179> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.51
			turn tail to z-axis ((<-1.387327> *IDLEAMPLITUDE)/100) speed ((<41.619816> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.39
			turn tail to y-axis ((<7.316429> *IDLEAMPLITUDE)/100) speed ((<127.322054> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.24
		sleep ((33*IDLESPEED) -1);
	}
	while(!isMoving) {
		if (!isMoving) { //Frame:20
			move body to x-axis (((([-1.214317] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([38.176341] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.27
			move body to z-axis (((([-0.218571] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([4.094815] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.14
			move body to y-axis (((([-0.515468] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([59.604884] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.99
			turn body to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<75.417179> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.51
			turn body to z-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<41.619816> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.39
			turn body to y-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<42.606091> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.42
			turn head to x-axis ((<1.859755> *IDLEAMPLITUDE)/100) speed ((<77.352786> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.58
			turn head to z-axis ((<2.668271> *IDLEAMPLITUDE)/100) speed ((<37.876315> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.26
			turn head to y-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<42.606091> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.42
			turn lfoot to x-axis ((<0.182863> *IDLEAMPLITUDE)/100) speed ((<23.150899> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.77
			turn lfoot to z-axis ((<-1.808906> *IDLEAMPLITUDE)/100) speed ((<61.320193> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.04
			turn lfoot to y-axis ((<0.142650> *IDLEAMPLITUDE)/100) speed ((<18.137128> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.60
			turn lknee to x-axis ((<2.061758> *IDLEAMPLITUDE)/100) speed ((<297.951364> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-9.93
			turn lshin to x-axis ((<-1.018278> *IDLEAMPLITUDE)/100) speed ((<114.798664> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.83
			turn lthigh to x-axis ((<-1.230264> *IDLEAMPLITUDE)/100) speed ((<85.286669> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.84
			turn lthigh to z-axis ((<1.807956> *IDLEAMPLITUDE)/100) speed ((<19.192404> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.64
			turn lthigh to y-axis ((<-0.104811> *IDLEAMPLITUDE)/100) speed ((<22.613683> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.75
			turn rfoot to x-axis ((<0.740375> *IDLEAMPLITUDE)/100) speed ((<50.324403> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.68
			turn rfoot to z-axis ((<-1.811898> *IDLEAMPLITUDE)/100) speed ((<60.906223> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.03
			turn rfoot to y-axis ((<0.159613> *IDLEAMPLITUDE)/100) speed ((<17.876060> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.60
			turn rknee to x-axis ((<2.342362> *IDLEAMPLITUDE)/100) speed ((<212.241253> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-7.07
			turn rshin to x-axis ((<-0.938076> *IDLEAMPLITUDE)/100) speed ((<69.952339> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.33
			turn rthigh to x-axis ((<-1.473476> *IDLEAMPLITUDE)/100) speed ((<17.256179> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.58
			turn rthigh to z-axis ((<1.811272> *IDLEAMPLITUDE)/100) speed ((<19.127375> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.64
			turn rthigh to y-axis ((<-0.092681> *IDLEAMPLITUDE)/100) speed ((<23.462601> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.78
			turn tail to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<75.417179> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.51
			turn tail to z-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<41.619816> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.39
			turn tail to y-axis ((<3.072361> *IDLEAMPLITUDE)/100) speed ((<127.322054> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.24
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:30
			move body to x-axis (((([1.914894] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([93.876328] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.13
			move body to z-axis (((([-1.580380] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([40.854266] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.36
			move body to y-axis (((([-0.358933] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([4.696054] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.16
			turn body to y-axis ((<2.760414> *IDLEAMPLITUDE)/100) speed ((<82.812424> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.76
			turn head to y-axis ((<2.760414> *IDLEAMPLITUDE)/100) speed ((<82.812424> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.76
			turn lfoot to x-axis ((<3.513907> *IDLEAMPLITUDE)/100) speed ((<99.931329> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.33
			turn lfoot to z-axis ((<2.639210> *IDLEAMPLITUDE)/100) speed ((<133.443476> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.45
			turn lfoot to y-axis ((<-1.647646> *IDLEAMPLITUDE)/100) speed ((<53.708874> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.79
			turn lknee to x-axis ((<0.273393> *IDLEAMPLITUDE)/100) speed ((<53.650958> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.79
			turn lshin to x-axis ((<-0.476112> *IDLEAMPLITUDE)/100) speed ((<16.265001> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.54
			turn lthigh to x-axis ((<-3.388430> *IDLEAMPLITUDE)/100) speed ((<64.744997> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.16
			turn lthigh to z-axis ((<-2.521867> *IDLEAMPLITUDE)/100) speed ((<129.894676> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.33
			turn lthigh to y-axis ((<-1.259178> *IDLEAMPLITUDE)/100) speed ((<34.630998> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.15
			turn rfoot to x-axis ((<1.883433> *IDLEAMPLITUDE)/100) speed ((<34.291744> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.14
			turn rfoot to z-axis ((<2.591682> *IDLEAMPLITUDE)/100) speed ((<132.107427> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.40
			turn rfoot to y-axis ((<-1.624580> *IDLEAMPLITUDE)/100) speed ((<53.525799> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.78
			turn rknee to x-axis ((<1.315183> *IDLEAMPLITUDE)/100) speed ((<30.815377> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.03
			turn rshin to x-axis ((<-0.572229> *IDLEAMPLITUDE)/100) speed ((<10.975393> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.37
			turn rthigh to x-axis ((<-2.027732> *IDLEAMPLITUDE)/100) speed ((<16.627689> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.55
			turn rthigh to z-axis ((<-2.538196> *IDLEAMPLITUDE)/100) speed ((<130.484036> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.35
			turn rthigh to y-axis ((<-1.250699> *IDLEAMPLITUDE)/100) speed ((<34.740524> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.16
			turn tail to y-axis ((<-5.176731> *IDLEAMPLITUDE)/100) speed ((<247.472748> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-8.25
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:40
			move body to y-axis (((([-1.565143] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([36.186309] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.21
			turn body to x-axis ((<0.825766> *IDLEAMPLITUDE)/100) speed ((<24.603741> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.82
			turn body to z-axis ((<0.280849> *IDLEAMPLITUDE)/100) speed ((<8.978534> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.30
			turn body to y-axis ((<-1.078636> *IDLEAMPLITUDE)/100) speed ((<115.171502> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.84
			turn head to x-axis ((<1.012795> *IDLEAMPLITUDE)/100) speed ((<25.235203> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.84
			turn head to z-axis ((<2.412683> *IDLEAMPLITUDE)/100) speed ((<8.170953> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.27
			turn head to y-axis ((<-1.078636> *IDLEAMPLITUDE)/100) speed ((<115.171502> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.84
			turn lfoot to x-axis ((<1.738062> *IDLEAMPLITUDE)/100) speed ((<53.275335> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.78
			turn lfoot to z-axis ((<2.997957> *IDLEAMPLITUDE)/100) speed ((<10.762434> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.36
			turn lfoot to y-axis ((<0.240979> *IDLEAMPLITUDE)/100) speed ((<56.658745> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.89
			turn lknee to x-axis ((<6.276044> *IDLEAMPLITUDE)/100) speed ((<180.079520> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-6.00
			turn lshin to x-axis ((<-3.524170> *IDLEAMPLITUDE)/100) speed ((<91.441759> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.05
			turn lthigh to x-axis ((<-5.299787> *IDLEAMPLITUDE)/100) speed ((<57.340695> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.91
			turn lthigh to z-axis ((<-3.285790> *IDLEAMPLITUDE)/100) speed ((<22.917714> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.76
			turn lthigh to y-axis ((<0.577600> *IDLEAMPLITUDE)/100) speed ((<55.103324> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.84
			turn rfoot to x-axis ((<3.222153> *IDLEAMPLITUDE)/100) speed ((<40.161589> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.34
			turn rfoot to z-axis ((<2.983911> *IDLEAMPLITUDE)/100) speed ((<11.766868> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.39
			turn rfoot to y-axis ((<0.193068> *IDLEAMPLITUDE)/100) speed ((<54.529445> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.82
			turn rknee to x-axis ((<5.685551> *IDLEAMPLITUDE)/100) speed ((<131.111038> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.37
			turn rshin to x-axis ((<-3.110935> *IDLEAMPLITUDE)/100) speed ((<76.161168> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.54
			turn rthigh to x-axis ((<-5.932160> *IDLEAMPLITUDE)/100) speed ((<117.132837> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.90
			turn rthigh to z-axis ((<-3.276131> *IDLEAMPLITUDE)/100) speed ((<22.138035> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.74
			turn rthigh to y-axis ((<0.555137> *IDLEAMPLITUDE)/100) speed ((<54.175071> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.81
			turn tail to x-axis ((<0.825766> *IDLEAMPLITUDE)/100) speed ((<24.603741> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.82
			turn tail to z-axis ((<0.280849> *IDLEAMPLITUDE)/100) speed ((<8.978534> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.30
			turn tail to y-axis ((<6.295706> *IDLEAMPLITUDE)/100) speed ((<344.173096> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=11.47
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:50
			move body to x-axis (((([0.0] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([56.964015] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.90
			move body to z-axis (((([0.0] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([47.560805] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.59
			move body to y-axis (((([0.0] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([46.954304] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.57
			turn body to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<24.772984> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.83
			turn body to z-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<8.425473> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.28
			turn body to y-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<32.359079> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.08
			turn head to x-axis ((<1.859755> *IDLEAMPLITUDE)/100) speed ((<25.408790> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.85
			turn head to z-axis ((<2.668271> *IDLEAMPLITUDE)/100) speed ((<7.667641> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.26
			turn head to y-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<32.359079> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.08
			turn lfoot to x-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<52.141862> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.74
			turn lfoot to z-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<89.938723> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.00
			turn lfoot to y-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<7.229362> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.24
			turn lknee to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<188.281309> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=6.28
			turn lshin to x-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<105.725111> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.52
			turn lthigh to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<158.993591> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.30
			turn lthigh to z-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<98.573711> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.29
			turn lthigh to y-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<17.327992> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.58
			turn rfoot to x-axis ((<0.556060> *IDLEAMPLITUDE)/100) speed ((<79.982779> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.67
			turn rfoot to z-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<89.517341> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.98
			turn rfoot to y-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<5.792041> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.19
			turn rknee to x-axis ((<0.285129> *IDLEAMPLITUDE)/100) speed ((<162.012663> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.40
			turn rshin to x-axis ((<0.077777> *IDLEAMPLITUDE)/100) speed ((<95.661351> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.19
			turn rthigh to x-axis ((<-0.243776> *IDLEAMPLITUDE)/100) speed ((<170.651529> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.69
			turn rthigh to z-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<98.283916> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.28
			turn rthigh to y-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<16.654104> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.56
			turn tail to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<24.772984> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.83
			turn tail to z-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<8.425473> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.28
			turn tail to y-axis ((<3.072361> *IDLEAMPLITUDE)/100) speed ((<96.700348> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.22
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:60
			move body to x-axis (((([-0.342949] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([10.288472] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.34
			move body to z-axis (((([1.643847] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([49.315413] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.64
			move body to y-axis (((([-0.113032] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([3.390963] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.11
			turn body to x-axis ((<3.502149> *IDLEAMPLITUDE)/100) speed ((<105.064469> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.50
			turn body to z-axis ((<4.181248> *IDLEAMPLITUDE)/100) speed ((<125.437427> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.18
			turn body to y-axis ((<2.960870> *IDLEAMPLITUDE)/100) speed ((<88.826085> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.96
			turn head to x-axis ((<-1.732278> *IDLEAMPLITUDE)/100) speed ((<107.760980> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.59
			turn head to z-axis ((<-1.136894> *IDLEAMPLITUDE)/100) speed ((<114.154930> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.81
			turn head to y-axis ((<2.960870> *IDLEAMPLITUDE)/100) speed ((<88.826085> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.96
			turn lfoot to x-axis ((<-1.246700> *IDLEAMPLITUDE)/100) speed ((<37.401021> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.25
			turn lfoot to z-axis ((<-0.821543> *IDLEAMPLITUDE)/100) speed ((<24.646285> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.82
			turn lfoot to y-axis ((<-1.653303> *IDLEAMPLITUDE)/100) speed ((<49.599103> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.65
			turn lknee to x-axis ((<5.467680> *IDLEAMPLITUDE)/100) speed ((<164.030402> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.47
			turn lshin to x-axis ((<-3.897389> *IDLEAMPLITUDE)/100) speed ((<116.921676> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.90
			turn lthigh to x-axis ((<-3.696486> *IDLEAMPLITUDE)/100) speed ((<110.894584> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.70
			turn lthigh to z-axis ((<-3.478477> *IDLEAMPLITUDE)/100) speed ((<104.354311> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.48
			turn lthigh to y-axis ((<-1.576553> *IDLEAMPLITUDE)/100) speed ((<47.296587> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.58
			turn rfoot to x-axis ((<-2.336975> *IDLEAMPLITUDE)/100) speed ((<86.791052> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.89
			turn rfoot to z-axis ((<-0.936004> *IDLEAMPLITUDE)/100) speed ((<28.080126> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.94
			turn rfoot to y-axis ((<-1.583717> *IDLEAMPLITUDE)/100) speed ((<47.511524> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.58
			turn rknee to x-axis ((<-3.021971> *IDLEAMPLITUDE)/100) speed ((<99.213008> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.31
			turn rshin to x-axis ((<0.602640> *IDLEAMPLITUDE)/100) speed ((<15.745890> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.52
			turn rthigh to x-axis ((<2.054488> *IDLEAMPLITUDE)/100) speed ((<68.947929> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.30
			turn rthigh to z-axis ((<-3.410024> *IDLEAMPLITUDE)/100) speed ((<102.300734> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.41
			turn rthigh to y-axis ((<-1.294052> *IDLEAMPLITUDE)/100) speed ((<38.821567> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.29
			turn tail to x-axis ((<3.502149> *IDLEAMPLITUDE)/100) speed ((<105.064469> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.50
			turn tail to z-axis ((<4.181248> *IDLEAMPLITUDE)/100) speed ((<125.437427> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.18
			turn tail to y-axis ((<-5.775762> *IDLEAMPLITUDE)/100) speed ((<265.443706> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-8.85
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:70
			turn body to x-axis ((<-1.634683> *IDLEAMPLITUDE)/100) speed ((<154.104961> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.14
			turn body to z-axis ((<3.376238> *IDLEAMPLITUDE)/100) speed ((<24.150292> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.81
			turn body to y-axis ((<1.034194> *IDLEAMPLITUDE)/100) speed ((<57.800279> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.93
			turn head to x-axis ((<3.536392> *IDLEAMPLITUDE)/100) speed ((<158.060098> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.27
			turn head to z-axis ((<-0.404291> *IDLEAMPLITUDE)/100) speed ((<21.978092> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.73
			turn head to y-axis ((<1.034194> *IDLEAMPLITUDE)/100) speed ((<57.800279> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.93
			turn lfoot to x-axis ((<-2.813136> *IDLEAMPLITUDE)/100) speed ((<46.993080> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.57
			turn lfoot to z-axis ((<-0.675909> *IDLEAMPLITUDE)/100) speed ((<4.369018> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.15
			turn lfoot to y-axis ((<-0.567066> *IDLEAMPLITUDE)/100) speed ((<32.587120> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.09
			turn lknee to x-axis ((<4.329531> *IDLEAMPLITUDE)/100) speed ((<34.144483> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.14
			turn lshin to x-axis ((<-1.189874> *IDLEAMPLITUDE)/100) speed ((<81.225452> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.71
			turn lthigh to x-axis ((<1.339655> *IDLEAMPLITUDE)/100) speed ((<151.084244> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.04
			turn lthigh to z-axis ((<-2.711961> *IDLEAMPLITUDE)/100) speed ((<22.995482> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.77
			turn lthigh to y-axis ((<-0.384369> *IDLEAMPLITUDE)/100) speed ((<35.765518> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.19
			turn rfoot to z-axis ((<-0.719332> *IDLEAMPLITUDE)/100) speed ((<6.500173> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.22
			turn rfoot to y-axis ((<-0.530653> *IDLEAMPLITUDE)/100) speed ((<31.591928> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.05
			turn rknee to x-axis ((<-2.583378> *IDLEAMPLITUDE)/100) speed ((<13.157813> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.44
			turn rshin to x-axis ((<2.368885> *IDLEAMPLITUDE)/100) speed ((<52.987365> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.77
			turn rthigh to x-axis ((<4.890088> *IDLEAMPLITUDE)/100) speed ((<85.068000> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.84
			turn rthigh to z-axis ((<-2.676865> *IDLEAMPLITUDE)/100) speed ((<21.994786> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.73
			turn rthigh to y-axis ((<-0.246327> *IDLEAMPLITUDE)/100) speed ((<31.431761> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.05
			turn tail to x-axis ((<-1.634683> *IDLEAMPLITUDE)/100) speed ((<154.104961> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.14
			turn tail to z-axis ((<3.376238> *IDLEAMPLITUDE)/100) speed ((<24.150292> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.81
			turn tail to y-axis ((<-0.018174> *IDLEAMPLITUDE)/100) speed ((<172.727643> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.76
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:80
			move body to x-axis (((([0.785493] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([33.853257] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.13
			move body to z-axis (((([-2.444840] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([122.660612] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.09
			move body to y-axis (((([-0.422489] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([9.283695] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.31
			turn body to y-axis ((<-0.523414> *IDLEAMPLITUDE)/100) speed ((<46.728227> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.56
			turn head to y-axis ((<-0.523414> *IDLEAMPLITUDE)/100) speed ((<46.728227> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.56
			turn lfoot to x-axis ((<3.060434> *IDLEAMPLITUDE)/100) speed ((<176.207111> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.87
			turn lfoot to z-axis ((<1.156679> *IDLEAMPLITUDE)/100) speed ((<54.977624> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.83
			turn lfoot to y-axis ((<-0.049485> *IDLEAMPLITUDE)/100) speed ((<15.527432> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.52
			turn lknee to x-axis ((<4.152817> *IDLEAMPLITUDE)/100) speed ((<5.301396> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.18
			turn lshin to x-axis ((<-1.646708> *IDLEAMPLITUDE)/100) speed ((<13.705017> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.46
			turn lthigh to x-axis ((<-3.920835> *IDLEAMPLITUDE)/100) speed ((<157.814704> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.26
			turn lthigh to z-axis ((<-4.542785> *IDLEAMPLITUDE)/100) speed ((<54.924729> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.83
			turn lthigh to y-axis ((<0.230289> *IDLEAMPLITUDE)/100) speed ((<18.439749> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.61
			turn rfoot to x-axis ((<4.480759> *IDLEAMPLITUDE)/100) speed ((<204.515432> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-6.82
			turn rfoot to z-axis ((<1.039337> *IDLEAMPLITUDE)/100) speed ((<52.760069> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.76
			turn rfoot to y-axis ((<-0.010600> *IDLEAMPLITUDE)/100) speed ((<15.601598> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.52
			turn rknee to x-axis ((<-2.944711> *IDLEAMPLITUDE)/100) speed ((<10.839997> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.36
			turn rshin to x-axis ((<1.955589> *IDLEAMPLITUDE)/100) speed ((<12.398894> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.41
			turn rthigh to x-axis ((<-1.175852> *IDLEAMPLITUDE)/100) speed ((<181.978228> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=6.07
			turn rthigh to z-axis ((<-4.416305> *IDLEAMPLITUDE)/100) speed ((<52.183194> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.74
			turn rthigh to y-axis ((<0.402603> *IDLEAMPLITUDE)/100) speed ((<19.467888> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.65
			turn tail to y-axis ((<4.636507> *IDLEAMPLITUDE)/100) speed ((<139.640442> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.65
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:90
			move body to x-axis (((([0.909801] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([3.729245] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			move body to y-axis (((([-1.907812] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([44.559698] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.49
			turn body to y-axis ((<0.393436> *IDLEAMPLITUDE)/100) speed ((<27.505516> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.92
			turn head to y-axis ((<0.393436> *IDLEAMPLITUDE)/100) speed ((<27.505516> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.92
			turn lfoot to z-axis ((<1.309368> *IDLEAMPLITUDE)/100) speed ((<4.580682> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.15
			turn lfoot to y-axis ((<-0.548106> *IDLEAMPLITUDE)/100) speed ((<14.958630> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.50
			turn lknee to x-axis ((<10.155775> *IDLEAMPLITUDE)/100) speed ((<180.088729> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-6.00
			turn lshin to x-axis ((<-4.525688> *IDLEAMPLITUDE)/100) speed ((<86.369401> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.88
			turn lthigh to x-axis ((<-7.096973> *IDLEAMPLITUDE)/100) speed ((<95.284123> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.18
			turn lthigh to z-axis ((<-4.686872> *IDLEAMPLITUDE)/100) speed ((<4.322588> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.14
			turn lthigh to y-axis ((<-0.460889> *IDLEAMPLITUDE)/100) speed ((<20.735350> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.69
			turn rfoot to x-axis ((<3.840326> *IDLEAMPLITUDE)/100) speed ((<19.212968> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.64
			turn rfoot to z-axis ((<1.185467> *IDLEAMPLITUDE)/100) speed ((<4.383893> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.15
			turn rfoot to y-axis ((<-0.520756> *IDLEAMPLITUDE)/100) speed ((<15.304688> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.51
			turn rknee to x-axis ((<3.540607> *IDLEAMPLITUDE)/100) speed ((<194.559533> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-6.49
			turn rshin to x-axis ((<-1.159813> *IDLEAMPLITUDE)/100) speed ((<93.462066> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.12
			turn rthigh to x-axis ((<-3.901105> *IDLEAMPLITUDE)/100) speed ((<81.757582> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.73
			turn rthigh to z-axis ((<-4.537536> *IDLEAMPLITUDE)/100) speed ((<3.636935> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.12
			turn rthigh to y-axis ((<-0.227924> *IDLEAMPLITUDE)/100) speed ((<18.915790> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.63
			turn tail to y-axis ((<1.896634> *IDLEAMPLITUDE)/100) speed ((<82.196202> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.74
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:100
			move body to x-axis (((([0.058228] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([25.547187] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-0.85
			move body to z-axis (((([-0.355065] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([63.337378] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.11
			move body to y-axis (((([1.471361] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([101.375191] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=3.38
			turn body to x-axis ((<2.513906> *IDLEAMPLITUDE)/100) speed ((<124.844549> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.16
			turn body to z-axis ((<-1.387327> *IDLEAMPLITUDE)/100) speed ((<142.795336> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.76
			turn body to y-axis ((<-1.420203> *IDLEAMPLITUDE)/100) speed ((<54.409186> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.81
			turn head to x-axis ((<-0.718671> *IDLEAMPLITUDE)/100) speed ((<128.048723> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.27
			turn head to z-axis ((<3.930814> *IDLEAMPLITUDE)/100) speed ((<129.951579> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.33
			turn head to y-axis ((<-1.420203> *IDLEAMPLITUDE)/100) speed ((<54.409186> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-1.81
			turn lfoot to x-axis ((<0.954559> *IDLEAMPLITUDE)/100) speed ((<64.933200> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=2.16
			turn lfoot to z-axis ((<0.235100> *IDLEAMPLITUDE)/100) speed ((<32.228033> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.07
			turn lfoot to y-axis ((<0.747221> *IDLEAMPLITUDE)/100) speed ((<38.859799> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.30
			turn lknee to x-axis ((<-7.869954> *IDLEAMPLITUDE)/100) speed ((<540.771869> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=18.03
			turn lshin to x-axis ((<2.808344> *IDLEAMPLITUDE)/100) speed ((<220.020952> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-7.33
			turn lthigh to x-axis ((<1.612625> *IDLEAMPLITUDE)/100) speed ((<261.287937> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-8.71
			turn lthigh to z-axis ((<1.168209> *IDLEAMPLITUDE)/100) speed ((<175.652422> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.86
			turn lthigh to y-axis ((<0.648978> *IDLEAMPLITUDE)/100) speed ((<33.296020> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.11
			turn rfoot to x-axis ((<2.417855> *IDLEAMPLITUDE)/100) speed ((<42.674143> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.42
			turn rfoot to z-axis ((<0.218309> *IDLEAMPLITUDE)/100) speed ((<29.014740> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.97
			turn rfoot to y-axis ((<0.755482> *IDLEAMPLITUDE)/100) speed ((<38.287141> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=1.28
			turn rknee to x-axis ((<-4.732346> *IDLEAMPLITUDE)/100) speed ((<248.188592> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=8.27
			turn rshin to x-axis ((<1.393669> *IDLEAMPLITUDE)/100) speed ((<76.604467> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-2.55
			turn rthigh to x-axis ((<-0.898270> *IDLEAMPLITUDE)/100) speed ((<90.085058> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-3.00
			turn rthigh to z-axis ((<1.173693> *IDLEAMPLITUDE)/100) speed ((<171.336856> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-5.71
			turn rthigh to y-axis ((<0.689405> *IDLEAMPLITUDE)/100) speed ((<27.519867> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=0.92
			turn tail to x-axis ((<2.513906> *IDLEAMPLITUDE)/100) speed ((<124.844549> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=-4.16
			turn tail to z-axis ((<-1.387327> *IDLEAMPLITUDE)/100) speed ((<142.795336> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=4.76
			turn tail to y-axis ((<7.316429> *IDLEAMPLITUDE)/100) speed ((<162.593876> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=5.42
		sleep ((33*IDLESPEED) -1);
		}
	}
}
// Call this from StopMoving()!
StopIdle() {
	//IDLESPEED = 10; // tune restore speed here, higher values are slower restore speeds
	move body to x-axis ([0.0]*IDLEMOVESCALE)/100 speed (([93.876328]*IDLEMOVESCALE)/100) / IDLESPEED;
	move body to y-axis ([0.0]*IDLEMOVESCALE)/100 speed (([101.375191]*IDLEMOVESCALE)/100) / IDLESPEED;
	move body to z-axis ([0.0]*IDLEMOVESCALE)/100 speed (([122.660612]*IDLEMOVESCALE)/100) / IDLESPEED;
	turn body to x-axis <0.0> speed <154.104961> / IDLESPEED;
	turn body to y-axis <0.0> speed <115.171502> / IDLESPEED;
	turn body to z-axis <0.0> speed <142.795336> / IDLESPEED;
	turn head to x-axis <1.859755> speed <158.060098> / IDLESPEED;
	turn head to y-axis <0.0> speed <115.171502> / IDLESPEED;
	turn head to z-axis <2.668271> speed <129.951579> / IDLESPEED;
	turn lfoot to x-axis <0.0> speed <176.207111> / IDLESPEED;
	turn lfoot to y-axis <0.0> speed <56.658745> / IDLESPEED;
	turn lfoot to z-axis <0.0> speed <133.443476> / IDLESPEED;
	turn lknee to x-axis <0.0> speed <540.771869> / IDLESPEED;
	turn lshin to x-axis <0.0> speed <220.020952> / IDLESPEED;
	turn lthigh to x-axis <0.0> speed <261.287937> / IDLESPEED;
	turn lthigh to y-axis <0.0> speed <55.103324> / IDLESPEED;
	turn lthigh to z-axis <0.0> speed <175.652422> / IDLESPEED;
	turn rfoot to x-axis <0.556060> speed <204.515432> / IDLESPEED;
	turn rfoot to y-axis <0.0> speed <54.529445> / IDLESPEED;
	turn rfoot to z-axis <0.0> speed <132.107427> / IDLESPEED;
	turn rknee to x-axis <0.285129> speed <248.188592> / IDLESPEED;
	turn rshin to x-axis <0.0> speed <95.661351> / IDLESPEED;
	turn rthigh to x-axis <-0.243776> speed <181.978228> / IDLESPEED;
	turn rthigh to y-axis <0.0> speed <54.175071> / IDLESPEED;
	turn rthigh to z-axis <0.0> speed <171.336856> / IDLESPEED;
	turn tail to x-axis <0.0> speed <154.104961> / IDLESPEED;
	turn tail to y-axis <3.072361> speed <344.173096> / IDLESPEED;
	turn tail to z-axis <0.0> speed <142.795336> / IDLESPEED;
}

