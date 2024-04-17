// this animation uses the static-var animFramesPerKeyframe which contains how many frames each keyframe takes
// For N:\animations\Raptors\raptor_2legged_fast_anim_walk_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3))

//Needs a crapton of #defines and static-vars:

//#define MOVESCALE 100 //Higher values are bigger, 100 is default
//#define MOVESPEED 6
//#define animAmplitude 66
//#define LUHAND lsack  //define these as the left and right head thingies
//#define RUHAND rsack  
//#define LLHAND lsack  //define these as the left and right head thingies
//#define RLHAND rsack  
//#define SIGNAL_MOVE 1


Walk() {// For N:\animations\Raptors\raptor_walk_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:6
			move body to x-axis (((([-2.055556] *MOVESCALE)/100) *animAmplitude)/100) speed (((([61.666667] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-2.06
			move body to y-axis (((([3.468679] *MOVESCALE)/100) *animAmplitude)/100) speed (((([104.060361] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=3.47
			turn body to x-axis ((<0.453704> *animAmplitude)/100) speed ((<13.611109> *animAmplitude)/100) / animSpeed; //delta=-0.45
			turn body to z-axis ((<4.878467> *animAmplitude)/100) speed ((<146.354007> *animAmplitude)/100) / animSpeed; //delta=-4.88
			turn head to y-axis ((<-5.859878> *animAmplitude)/100) speed ((<175.796339> *animAmplitude)/100) / animSpeed; //delta=-5.86
			turn lfoot to x-axis ((<-31.240947> *animAmplitude)/100) speed ((<937.228426> *animAmplitude)/100) / animSpeed; //delta=31.24
			turn lfoot to z-axis ((<-6.102885> *animAmplitude)/100) speed ((<183.086538> *animAmplitude)/100) / animSpeed; //delta=6.10
			turn lfoot to y-axis ((<-0.384868> *animAmplitude)/100) speed ((<11.546034> *animAmplitude)/100) / animSpeed; //delta=-0.38
			turn lknee to x-axis ((<-35.750450> *animAmplitude)/100) speed ((<1072.513491> *animAmplitude)/100) / animSpeed; //delta=35.75
			turn lshin to x-axis ((<20.084443> *animAmplitude)/100) speed ((<602.533282> *animAmplitude)/100) / animSpeed; //delta=-20.08
			turn lthigh to x-axis ((<47.358790> *animAmplitude)/100) speed ((<1420.763709> *animAmplitude)/100) / animSpeed; //delta=-47.36
			turn lthigh to z-axis ((<1.515213> *animAmplitude)/100) speed ((<45.456390> *animAmplitude)/100) / animSpeed; //delta=-1.52
			turn lthigh to y-axis ((<-0.739342> *animAmplitude)/100) speed ((<22.180268> *animAmplitude)/100) / animSpeed; //delta=-0.74
			turn LUHAND to z-axis ((<-3.277195> *animAmplitude)/100) speed ((<98.315837> *animAmplitude)/100) / animSpeed; //delta=3.28
			turn LLHAND to z-axis ((<-3.277195> *animAmplitude)/100) speed ((<98.315837> *animAmplitude)/100) / animSpeed; //delta=3.28
			turn rfoot to x-axis ((<32.983660> *animAmplitude)/100) speed ((<972.827991> *animAmplitude)/100) / animSpeed; //delta=-32.43
			turn rfoot to z-axis ((<-1.802275> *animAmplitude)/100) speed ((<54.068243> *animAmplitude)/100) / animSpeed; //delta=1.80
			turn rfoot to y-axis ((<-1.186515> *animAmplitude)/100) speed ((<35.595455> *animAmplitude)/100) / animSpeed; //delta=-1.19
			turn rknee to x-axis ((<-18.311023> *animAmplitude)/100) speed ((<557.884571> *animAmplitude)/100) / animSpeed; //delta=18.60
			turn rshin to x-axis ((<1.293042> *animAmplitude)/100) speed ((<36.457960> *animAmplitude)/100) / animSpeed; //delta=-1.22
			turn rthigh to x-axis ((<-32.556213> *animAmplitude)/100) speed ((<969.373108> *animAmplitude)/100) / animSpeed; //delta=32.31
			turn rthigh to z-axis ((<-2.662400> *animAmplitude)/100) speed ((<79.871995> *animAmplitude)/100) / animSpeed; //delta=2.66
			turn rthigh to y-axis ((<-1.181967> *animAmplitude)/100) speed ((<35.459017> *animAmplitude)/100) / animSpeed; //delta=-1.18
			turn RUHAND to z-axis ((<4.102677> *animAmplitude)/100) speed ((<123.080308> *animAmplitude)/100) / animSpeed; //delta=-4.10
			turn RLHAND to z-axis ((<4.102677> *animAmplitude)/100) speed ((<123.080308> *animAmplitude)/100) / animSpeed; //delta=-4.10
			turn tail to x-axis ((<-2.0> *animAmplitude)/100) speed ((<60.0> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn tail to y-axis ((<11.292191> *animAmplitude)/100) speed ((<338.765737> *animAmplitude)/100) / animSpeed; //delta=11.29
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:12
			//call-script lua_UnitScriptDecal(1, (get PIECE_XZ(lfoot) & 0xffff0000) / 0x00010000 , (get PIECE_XZ(lfoot) & 0x0000ffff),   get HEADING(0));
			move body to x-axis (((([-4.111111] *MOVESCALE)/100) *animAmplitude)/100) speed (((([61.666667] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-2.06
			move body to z-axis (((([1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			move body to y-axis (((([2.098039] *MOVESCALE)/100) *animAmplitude)/100) speed (((([41.119187] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.37
			turn body to x-axis ((<1.462963> *animAmplitude)/100) speed ((<30.277778> *animAmplitude)/100) / animSpeed; //delta=-1.01
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<146.354007> *animAmplitude)/100) / animSpeed; //delta=4.88
			turn head to y-axis ((<-8.585334> *animAmplitude)/100) speed ((<81.763691> *animAmplitude)/100) / animSpeed; //delta=-2.73
			turn lfoot to x-axis ((<-21.861574> *animAmplitude)/100) speed ((<281.381186> *animAmplitude)/100) / animSpeed; //delta=-9.38
			turn lfoot to z-axis ((<-7.791813> *animAmplitude)/100) speed ((<50.667859> *animAmplitude)/100) / animSpeed; //delta=1.69
			turn lfoot to y-axis ((<-7.422752> *animAmplitude)/100) speed ((<211.136541> *animAmplitude)/100) / animSpeed; //delta=-7.04
			turn lknee to x-axis ((<-76.768697> *animAmplitude)/100) speed ((<1230.547406> *animAmplitude)/100) / animSpeed; //delta=41.02
			turn lknee to z-axis ((<2.292941> *animAmplitude)/100) speed ((<68.820661> *animAmplitude)/100) / animSpeed; //delta=-2.29
			turn lknee to y-axis ((<2.486017> *animAmplitude)/100) speed ((<74.526258> *animAmplitude)/100) / animSpeed; //delta=2.48
			turn lshin to x-axis ((<46.562431> *animAmplitude)/100) speed ((<794.339645> *animAmplitude)/100) / animSpeed; //delta=-26.48
			turn lshin to z-axis ((<0.581841> *animAmplitude)/100) speed ((<17.519623> *animAmplitude)/100) / animSpeed; //delta=-0.58
			turn lshin to y-axis ((<-0.406837> *animAmplitude)/100) speed ((<12.226702> *animAmplitude)/100) / animSpeed; //delta=-0.41
			turn lthigh to x-axis ((<-0.990000> *animAmplitude)/100) speed ((<29.700000> *animAmplitude)/100) / animSpeed; //delta=0.99
			turn lthigh to x-axis ((<-0.403714> *animAmplitude)/100) speed ((<12.111430> *animAmplitude)/100) / animSpeed; //delta=0.40
			turn lthigh to x-axis ((<84.826646> *animAmplitude)/100) speed ((<1124.035694> *animAmplitude)/100) / animSpeed; //delta=-37.47
			turn lthigh to z-axis ((<3.882873> *animAmplitude)/100) speed ((<71.029797> *animAmplitude)/100) / animSpeed; //delta=-2.37
			turn lthigh to y-axis ((<4.010293> *animAmplitude)/100) speed ((<142.489060> *animAmplitude)/100) / animSpeed; //delta=4.75
			turn LLHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<110.209066> *animAmplitude)/100) / animSpeed; //delta=-3.67
			turn LUHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<110.209066> *animAmplitude)/100) / animSpeed; //delta=-3.67
			turn rfoot to x-axis ((<13.510800> *animAmplitude)/100) speed ((<584.185798> *animAmplitude)/100) / animSpeed; //delta=19.47
			turn rfoot to z-axis ((<-1.645305> *animAmplitude)/100) speed ((<4.709101> *animAmplitude)/100) / animSpeed; //delta=-0.16
			turn rfoot to y-axis ((<-0.105101> *animAmplitude)/100) speed ((<32.442429> *animAmplitude)/100) / animSpeed; //delta=1.08
			turn rknee to x-axis ((<-91.244326> *animAmplitude)/100) speed ((<2187.999089> *animAmplitude)/100) / animSpeed; //delta=72.93
			turn rshin to x-axis ((<54.203353> *animAmplitude)/100) speed ((<1587.309336> *animAmplitude)/100) / animSpeed; //delta=-52.91
			turn rthigh to x-axis ((<-10.943401> *animAmplitude)/100) speed ((<648.384360> *animAmplitude)/100) / animSpeed; //delta=-21.61
			turn rthigh to z-axis ((<1.460696> *animAmplitude)/100) speed ((<123.692883> *animAmplitude)/100) / animSpeed; //delta=-4.12
			turn rthigh to y-axis ((<-0.583955> *animAmplitude)/100) speed ((<17.940364> *animAmplitude)/100) / animSpeed; //delta=0.60
			turn RLHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<111.187092> *animAmplitude)/100) / animSpeed; //delta=3.71
			turn RUHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<111.187092> *animAmplitude)/100) / animSpeed; //delta=3.71
			turn tail to x-axis ((<5.0> *animAmplitude)/100) speed ((<209.999995> *animAmplitude)/100) / animSpeed; //delta=-7.00
			turn tail to y-axis ((<16.544243> *animAmplitude)/100) speed ((<157.561553> *animAmplitude)/100) / animSpeed; //delta=5.25
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:18
			move body to x-axis (((([-3.433333] *MOVESCALE)/100) *animAmplitude)/100) speed (((([20.333333] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.68
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			move body to y-axis (((([-3.468679] *MOVESCALE)/100) *animAmplitude)/100) speed (((([167.001536] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-5.57
			turn body to x-axis ((<2.816049> *animAmplitude)/100) speed ((<40.592570> *animAmplitude)/100) / animSpeed; //delta=-1.35
			turn body to z-axis ((<-4.878467> *animAmplitude)/100) speed ((<146.354007> *animAmplitude)/100) / animSpeed; //delta=4.88
			turn head to x-axis ((<3.117471> *animAmplitude)/100) speed ((<93.524130> *animAmplitude)/100) / animSpeed; //delta=-3.12
			turn head to y-axis ((<-5.859878> *animAmplitude)/100) speed ((<81.763691> *animAmplitude)/100) / animSpeed; //delta=2.73
			turn lfoot to x-axis ((<-36.196072> *animAmplitude)/100) speed ((<430.034926> *animAmplitude)/100) / animSpeed; //delta=14.33
			turn lfoot to y-axis ((<-1.945396> *animAmplitude)/100) speed ((<164.320693> *animAmplitude)/100) / animSpeed; //delta=5.48
			turn lknee to x-axis ((<14.741666> *animAmplitude)/100) speed ((<2745.310867> *animAmplitude)/100) / animSpeed; //delta=-91.51
			turn lknee to z-axis ((<0.005278> *animAmplitude)/100) speed ((<68.629891> *animAmplitude)/100) / animSpeed; //delta=2.29
			turn lknee to y-axis ((<0.007469> *animAmplitude)/100) speed ((<74.356422> *animAmplitude)/100) / animSpeed; //delta=-2.48
			turn lshin to x-axis ((<4.679953> *animAmplitude)/100) speed ((<1256.474351> *animAmplitude)/100) / animSpeed; //delta=41.88
			turn lshin to z-axis ((<0.004816> *animAmplitude)/100) speed ((<17.310761> *animAmplitude)/100) / animSpeed; //delta=0.58
			turn lshin to y-axis ((<-0.001056> *animAmplitude)/100) speed ((<12.173444> *animAmplitude)/100) / animSpeed; //delta=0.41
			turn lthigh to x-axis ((<-0.0> *animAmplitude)/100) speed ((<29.700000> *animAmplitude)/100) / animSpeed; //delta=-0.99
			turn lthigh to x-axis ((<-0.0> *animAmplitude)/100) speed ((<12.111430> *animAmplitude)/100) / animSpeed; //delta=-0.40
			turn lthigh to x-axis ((<33.883254> *animAmplitude)/100) speed ((<1528.301784> *animAmplitude)/100) / animSpeed; //delta=50.94
			turn lthigh to z-axis ((<12.996131> *animAmplitude)/100) speed ((<273.397753> *animAmplitude)/100) / animSpeed; //delta=-9.11
			turn lthigh to y-axis ((<-3.815288> *animAmplitude)/100) speed ((<234.767424> *animAmplitude)/100) / animSpeed; //delta=-7.83
			turn LLHAND to z-axis ((<7.743712> *animAmplitude)/100) speed ((<220.418118> *animAmplitude)/100) / animSpeed; //delta=-7.35
			turn LUHAND to z-axis ((<7.743712> *animAmplitude)/100) speed ((<220.418118> *animAmplitude)/100) / animSpeed; //delta=-7.35
			turn rfoot to x-axis ((<37.991524> *animAmplitude)/100) speed ((<734.421717> *animAmplitude)/100) / animSpeed; //delta=-24.48
			turn rfoot to z-axis ((<-1.014552> *animAmplitude)/100) speed ((<18.922578> *animAmplitude)/100) / animSpeed; //delta=-0.63
			turn rfoot to y-axis ((<1.813068> *animAmplitude)/100) speed ((<57.545071> *animAmplitude)/100) / animSpeed; //delta=1.92
			turn rknee to x-axis ((<-18.809716> *animAmplitude)/100) speed ((<2173.038311> *animAmplitude)/100) / animSpeed; //delta=-72.43
			turn rshin to x-axis ((<5.716030> *animAmplitude)/100) speed ((<1454.619689> *animAmplitude)/100) / animSpeed; //delta=48.49
			turn rthigh to x-axis ((<-27.743880> *animAmplitude)/100) speed ((<504.014378> *animAmplitude)/100) / animSpeed; //delta=16.80
			turn rthigh to z-axis ((<5.311678> *animAmplitude)/100) speed ((<115.529466> *animAmplitude)/100) / animSpeed; //delta=-3.85
			turn rthigh to y-axis ((<1.053385> *animAmplitude)/100) speed ((<49.120189> *animAmplitude)/100) / animSpeed; //delta=1.64
			turn RLHAND to z-axis ((<-7.016032> *animAmplitude)/100) speed ((<222.374182> *animAmplitude)/100) / animSpeed; //delta=7.41
			turn RUHAND to z-axis ((<-7.016032> *animAmplitude)/100) speed ((<222.374182> *animAmplitude)/100) / animSpeed; //delta=7.41
			turn tail to x-axis ((<-8.0> *animAmplitude)/100) speed ((<389.999994> *animAmplitude)/100) / animSpeed; //delta=13.00
			turn tail to y-axis ((<11.292191> *animAmplitude)/100) speed ((<157.561553> *animAmplitude)/100) / animSpeed; //delta=-5.25
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:24
			move body to x-axis (((([0.102778] *MOVESCALE)/100) *animAmplitude)/100) speed (((([106.083333] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=3.54
			move body to z-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			move body to y-axis (((([-1.775264] *MOVESCALE)/100) *animAmplitude)/100) speed (((([50.802444] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.69
			turn body to x-axis ((<1.444444> *animAmplitude)/100) speed ((<41.148124> *animAmplitude)/100) / animSpeed; //delta=1.37
			turn body to z-axis ((<-7.317701> *animAmplitude)/100) speed ((<73.177016> *animAmplitude)/100) / animSpeed; //delta=2.44
			turn head to x-axis ((<1.312619> *animAmplitude)/100) speed ((<54.145550> *animAmplitude)/100) / animSpeed; //delta=1.80
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<175.796339> *animAmplitude)/100) / animSpeed; //delta=5.86
			turn lfoot to x-axis ((<-0.843251> *animAmplitude)/100) speed ((<1060.584612> *animAmplitude)/100) / animSpeed; //delta=-35.35
			turn lfoot to z-axis ((<0.689679> *animAmplitude)/100) speed ((<255.047251> *animAmplitude)/100) / animSpeed; //delta=-8.50
			turn lfoot to y-axis ((<0.369165> *animAmplitude)/100) speed ((<69.436830> *animAmplitude)/100) / animSpeed; //delta=2.31
			turn lknee to x-axis ((<25.892762> *animAmplitude)/100) speed ((<334.532898> *animAmplitude)/100) / animSpeed; //delta=-11.15
			turn lshin to x-axis ((<-13.168734> *animAmplitude)/100) speed ((<535.460586> *animAmplitude)/100) / animSpeed; //delta=17.85
			turn lthigh to x-axis ((<-13.762760> *animAmplitude)/100) speed ((<1429.380419> *animAmplitude)/100) / animSpeed; //delta=47.65
			turn lthigh to z-axis ((<6.808503> *animAmplitude)/100) speed ((<185.628841> *animAmplitude)/100) / animSpeed; //delta=6.19
			turn lthigh to y-axis ((<1.277308> *animAmplitude)/100) speed ((<152.777876> *animAmplitude)/100) / animSpeed; //delta=5.09
			turn LLHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<220.418118> *animAmplitude)/100) / animSpeed; //delta=7.35
			turn LUHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<220.418118> *animAmplitude)/100) / animSpeed; //delta=7.35
			turn rfoot to x-axis ((<0.179849> *animAmplitude)/100) speed ((<1134.350247> *animAmplitude)/100) / animSpeed; //delta=37.81
			turn rfoot to z-axis ((<4.590677> *animAmplitude)/100) speed ((<168.156883> *animAmplitude)/100) / animSpeed; //delta=-5.61
			turn rfoot to y-axis ((<0.097719> *animAmplitude)/100) speed ((<51.460468> *animAmplitude)/100) / animSpeed; //delta=-1.72
			turn rknee to x-axis ((<14.026091> *animAmplitude)/100) speed ((<985.074198> *animAmplitude)/100) / animSpeed; //delta=-32.84
			turn rshin to x-axis ((<-7.695155> *animAmplitude)/100) speed ((<402.335559> *animAmplitude)/100) / animSpeed; //delta=13.41
			turn rthigh to x-axis ((<-8.659607> *animAmplitude)/100) speed ((<572.528202> *animAmplitude)/100) / animSpeed; //delta=-19.08
			turn rthigh to z-axis ((<2.750917> *animAmplitude)/100) speed ((<76.822839> *animAmplitude)/100) / animSpeed; //delta=2.56
			turn rthigh to y-axis ((<0.490890> *animAmplitude)/100) speed ((<16.874821> *animAmplitude)/100) / animSpeed; //delta=-0.56
			turn RLHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<222.374182> *animAmplitude)/100) / animSpeed; //delta=-7.41
			turn RUHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<222.374182> *animAmplitude)/100) / animSpeed; //delta=-7.41
			turn tail to x-axis ((<-2.0> *animAmplitude)/100) speed ((<179.999999> *animAmplitude)/100) / animSpeed; //delta=-6.00
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<338.765737> *animAmplitude)/100) / animSpeed; //delta=-11.29
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:30
			move body to x-axis (((([2.775000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([80.166671] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=2.67
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			move body to y-axis (((([3.468679] *MOVESCALE)/100) *animAmplitude)/100) speed (((([157.318279] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=5.24
			turn body to x-axis ((<0.444444> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<-4.878467> *animAmplitude)/100) speed ((<73.177016> *animAmplitude)/100) / animSpeed; //delta=-2.44
			turn head to x-axis ((<-0.0> *animAmplitude)/100) speed ((<39.378581> *animAmplitude)/100) / animSpeed; //delta=1.31
			turn head to y-axis ((<5.518260> *animAmplitude)/100) speed ((<165.547803> *animAmplitude)/100) / animSpeed; //delta=5.52
			turn lfoot to x-axis ((<31.102144> *animAmplitude)/100) speed ((<958.361865> *animAmplitude)/100) / animSpeed; //delta=-31.95
			turn lfoot to z-axis ((<2.472932> *animAmplitude)/100) speed ((<53.497601> *animAmplitude)/100) / animSpeed; //delta=-1.78
			turn lfoot to y-axis ((<1.109419> *animAmplitude)/100) speed ((<22.207615> *animAmplitude)/100) / animSpeed; //delta=0.74
			turn lknee to x-axis ((<-27.632806> *animAmplitude)/100) speed ((<1605.767041> *animAmplitude)/100) / animSpeed; //delta=53.53
			turn lshin to x-axis ((<6.933426> *animAmplitude)/100) speed ((<603.064782> *animAmplitude)/100) / animSpeed; //delta=-20.10
			turn lthigh to x-axis ((<-29.377839> *animAmplitude)/100) speed ((<468.452358> *animAmplitude)/100) / animSpeed; //delta=15.62
			turn lthigh to z-axis ((<1.934362> *animAmplitude)/100) speed ((<146.224250> *animAmplitude)/100) / animSpeed; //delta=4.87
			turn lthigh to y-axis ((<1.045563> *animAmplitude)/100) speed ((<6.952366> *animAmplitude)/100) / animSpeed; //delta=-0.23
			turn LLHAND to z-axis ((<-3.277195> *animAmplitude)/100) speed ((<110.209066> *animAmplitude)/100) / animSpeed; //delta=3.67
			turn LUHAND to z-axis ((<-3.277195> *animAmplitude)/100) speed ((<110.209066> *animAmplitude)/100) / animSpeed; //delta=3.67
			turn rfoot to x-axis ((<-31.118946> *animAmplitude)/100) speed ((<938.963853> *animAmplitude)/100) / animSpeed; //delta=31.30
			turn rfoot to z-axis ((<7.119058> *animAmplitude)/100) speed ((<75.851432> *animAmplitude)/100) / animSpeed; //delta=-2.53
			turn rfoot to y-axis ((<0.588139> *animAmplitude)/100) speed ((<14.712594> *animAmplitude)/100) / animSpeed; //delta=0.49
			turn rknee to x-axis ((<-36.191485> *animAmplitude)/100) speed ((<1506.527278> *animAmplitude)/100) / animSpeed; //delta=50.22
			turn rshin to x-axis ((<20.213347> *animAmplitude)/100) speed ((<837.255064> *animAmplitude)/100) / animSpeed; //delta=-27.91
			turn rthigh to x-axis ((<47.544332> *animAmplitude)/100) speed ((<1686.118163> *animAmplitude)/100) / animSpeed; //delta=-56.20
			turn rthigh to z-axis ((<-2.869607> *animAmplitude)/100) speed ((<168.615734> *animAmplitude)/100) / animSpeed; //delta=5.62
			turn rthigh to y-axis ((<1.560222> *animAmplitude)/100) speed ((<32.079959> *animAmplitude)/100) / animSpeed; //delta=1.07
			turn RLHAND to z-axis ((<4.102677> *animAmplitude)/100) speed ((<111.187092> *animAmplitude)/100) / animSpeed; //delta=-3.71
			turn RUHAND to z-axis ((<4.102677> *animAmplitude)/100) speed ((<111.187092> *animAmplitude)/100) / animSpeed; //delta=-3.71
			turn tail to x-axis ((<-0.0> *animAmplitude)/100) speed ((<60.0> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn tail to y-axis ((<-10.633881> *animAmplitude)/100) speed ((<319.016442> *animAmplitude)/100) / animSpeed; //delta=-10.63
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:36
			//call-script lua_UnitScriptDecal(2, (get PIECE_XZ(rfoot) & 0xffff0000) / 0x00010000 , (get PIECE_XZ(rfoot) & 0x0000ffff),   get HEADING(0));
			move body to x-axis (((([4.111111] *MOVESCALE)/100) *animAmplitude)/100) speed (((([40.083332] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.34
			move body to z-axis (((([1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			move body to y-axis (((([1.936651] *MOVESCALE)/100) *animAmplitude)/100) speed (((([45.960817] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.53
			turn body to x-axis ((<2.222223> *animAmplitude)/100) speed ((<53.333350> *animAmplitude)/100) / animSpeed; //delta=-1.78
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<146.354007> *animAmplitude)/100) / animSpeed; //delta=-4.88
			turn head to y-axis ((<8.585334> *animAmplitude)/100) speed ((<92.012227> *animAmplitude)/100) / animSpeed; //delta=3.07
			turn lfoot to x-axis ((<13.977338> *animAmplitude)/100) speed ((<513.744196> *animAmplitude)/100) / animSpeed; //delta=17.12
			turn lfoot to z-axis ((<1.650734> *animAmplitude)/100) speed ((<24.665940> *animAmplitude)/100) / animSpeed; //delta=0.82
			turn lfoot to y-axis ((<0.115008> *animAmplitude)/100) speed ((<29.832320> *animAmplitude)/100) / animSpeed; //delta=-0.99
			turn lknee to x-axis ((<-89.380955> *animAmplitude)/100) speed ((<1852.444479> *animAmplitude)/100) / animSpeed; //delta=61.75
			turn lshin to x-axis ((<52.655052> *animAmplitude)/100) speed ((<1371.648783> *animAmplitude)/100) / animSpeed; //delta=-45.72
			turn lthigh to x-axis ((<-12.483842> *animAmplitude)/100) speed ((<506.819921> *animAmplitude)/100) / animSpeed; //delta=-16.89
			turn lthigh to z-axis ((<-1.469845> *animAmplitude)/100) speed ((<102.126195> *animAmplitude)/100) / animSpeed; //delta=3.40
			turn lthigh to y-axis ((<0.559750> *animAmplitude)/100) speed ((<14.574379> *animAmplitude)/100) / animSpeed; //delta=-0.49
			turn LLHAND to z-axis ((<-6.950829> *animAmplitude)/100) speed ((<110.209036> *animAmplitude)/100) / animSpeed; //delta=3.67
			turn LUHAND to z-axis ((<-6.950829> *animAmplitude)/100) speed ((<110.209036> *animAmplitude)/100) / animSpeed; //delta=3.67
			turn rfoot to x-axis ((<-21.824372> *animAmplitude)/100) speed ((<278.837231> *animAmplitude)/100) / animSpeed; //delta=-9.29
			turn rfoot to z-axis ((<7.789743> *animAmplitude)/100) speed ((<20.120533> *animAmplitude)/100) / animSpeed; //delta=-0.67
			turn rfoot to y-axis ((<7.539747> *animAmplitude)/100) speed ((<208.548232> *animAmplitude)/100) / animSpeed; //delta=6.95
			turn rknee to x-axis ((<-75.756306> *animAmplitude)/100) speed ((<1186.944605> *animAmplitude)/100) / animSpeed; //delta=39.56
			turn rknee to z-axis ((<-2.071599> *animAmplitude)/100) speed ((<62.165426> *animAmplitude)/100) / animSpeed; //delta=2.07
			turn rknee to y-axis ((<-2.252145> *animAmplitude)/100) speed ((<67.485375> *animAmplitude)/100) / animSpeed; //delta=-2.25
			turn rshin to x-axis ((<45.657608> *animAmplitude)/100) speed ((<763.327837> *animAmplitude)/100) / animSpeed; //delta=-25.44
			turn rshin to z-axis ((<-0.557217> *animAmplitude)/100) speed ((<16.777581> *animAmplitude)/100) / animSpeed; //delta=0.56
			turn rshin to y-axis ((<0.384529> *animAmplitude)/100) speed ((<11.553788> *animAmplitude)/100) / animSpeed; //delta=0.39
			turn rthigh to x-axis ((<-0.990000> *animAmplitude)/100) speed ((<29.700000> *animAmplitude)/100) / animSpeed; //delta=0.99
			turn rthigh to x-axis ((<-0.356143> *animAmplitude)/100) speed ((<10.684285> *animAmplitude)/100) / animSpeed; //delta=0.36
			turn rthigh to x-axis ((<83.931905> *animAmplitude)/100) speed ((<1091.627198> *animAmplitude)/100) / animSpeed; //delta=-36.39
			turn rthigh to z-axis ((<-3.428724> *animAmplitude)/100) speed ((<16.773508> *animAmplitude)/100) / animSpeed; //delta=0.56
			turn rthigh to y-axis ((<-4.547011> *animAmplitude)/100) speed ((<183.216992> *animAmplitude)/100) / animSpeed; //delta=-6.11
			turn RLHAND to z-axis ((<7.808913> *animAmplitude)/100) speed ((<111.187096> *animAmplitude)/100) / animSpeed; //delta=-3.71
			turn RUHAND to z-axis ((<7.808913> *animAmplitude)/100) speed ((<111.187096> *animAmplitude)/100) / animSpeed; //delta=-3.71
			turn tail to x-axis ((<5.0> *animAmplitude)/100) speed ((<149.999996> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn tail to y-axis ((<-16.544243> *animAmplitude)/100) speed ((<177.310849> *animAmplitude)/100) / animSpeed; //delta=-5.91
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:42
			move body to x-axis (((([2.877778] *MOVESCALE)/100) *animAmplitude)/100) speed (((([37.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.23
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			move body to y-axis (((([-3.468679] *MOVESCALE)/100) *animAmplitude)/100) speed (((([162.159905] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-5.41
			turn body to x-axis ((<3.0> *animAmplitude)/100) speed ((<23.333320> *animAmplitude)/100) / animSpeed; //delta=-0.78
			turn body to z-axis ((<4.878467> *animAmplitude)/100) speed ((<146.354007> *animAmplitude)/100) / animSpeed; //delta=-4.88
			turn head to x-axis ((<2.953393> *animAmplitude)/100) speed ((<88.601803> *animAmplitude)/100) / animSpeed; //delta=-2.95
			turn head to y-axis ((<5.518260> *animAmplitude)/100) speed ((<92.012227> *animAmplitude)/100) / animSpeed; //delta=-3.07
			turn lfoot to x-axis ((<38.025866> *animAmplitude)/100) speed ((<721.455849> *animAmplitude)/100) / animSpeed; //delta=-24.05
			turn lfoot to z-axis ((<0.066021> *animAmplitude)/100) speed ((<47.541375> *animAmplitude)/100) / animSpeed; //delta=1.58
			turn lfoot to y-axis ((<-1.476878> *animAmplitude)/100) speed ((<47.756584> *animAmplitude)/100) / animSpeed; //delta=-1.59
			turn lknee to x-axis ((<-18.783225> *animAmplitude)/100) speed ((<2117.931900> *animAmplitude)/100) / animSpeed; //delta=-70.60
			turn lshin to x-axis ((<5.650113> *animAmplitude)/100) speed ((<1410.148165> *animAmplitude)/100) / animSpeed; //delta=47.00
			turn lthigh to x-axis ((<-27.906743> *animAmplitude)/100) speed ((<462.687029> *animAmplitude)/100) / animSpeed; //delta=15.42
			turn lthigh to z-axis ((<-4.492210> *animAmplitude)/100) speed ((<90.670950> *animAmplitude)/100) / animSpeed; //delta=3.02
			turn lthigh to y-axis ((<-0.987735> *animAmplitude)/100) speed ((<46.424562> *animAmplitude)/100) / animSpeed; //delta=-1.55
			turn LLHAND to z-axis ((<7.743712> *animAmplitude)/100) speed ((<440.836221> *animAmplitude)/100) / animSpeed; //delta=-14.69
			turn LUHAND to z-axis ((<7.743712> *animAmplitude)/100) speed ((<440.836221> *animAmplitude)/100) / animSpeed; //delta=-14.69
			turn rfoot to x-axis ((<-36.254566> *animAmplitude)/100) speed ((<432.905808> *animAmplitude)/100) / animSpeed; //delta=14.43
			turn rfoot to z-axis ((<6.807730> *animAmplitude)/100) speed ((<29.460377> *animAmplitude)/100) / animSpeed; //delta=0.98
			turn rfoot to y-axis ((<1.878263> *animAmplitude)/100) speed ((<169.844528> *animAmplitude)/100) / animSpeed; //delta=-5.66
			turn rknee to x-axis ((<14.976496> *animAmplitude)/100) speed ((<2721.984046> *animAmplitude)/100) / animSpeed; //delta=-90.73
			turn rknee to z-axis ((<-0.004960> *animAmplitude)/100) speed ((<61.999179> *animAmplitude)/100) / animSpeed; //delta=-2.07
			turn rknee to y-axis ((<-0.006667> *animAmplitude)/100) speed ((<67.364325> *animAmplitude)/100) / animSpeed; //delta=2.25
			turn rshin to x-axis ((<4.515720> *animAmplitude)/100) speed ((<1234.256659> *animAmplitude)/100) / animSpeed; //delta=41.14
			turn rshin to z-axis ((<-0.004625> *animAmplitude)/100) speed ((<16.577786> *animAmplitude)/100) / animSpeed; //delta=-0.55
			turn rshin to y-axis ((<0.001053> *animAmplitude)/100) speed ((<11.504297> *animAmplitude)/100) / animSpeed; //delta=-0.38
			turn rthigh to x-axis ((<-0.0> *animAmplitude)/100) speed ((<29.700000> *animAmplitude)/100) / animSpeed; //delta=-0.99
			turn rthigh to x-axis ((<-0.0> *animAmplitude)/100) speed ((<10.684285> *animAmplitude)/100) / animSpeed; //delta=-0.36
			turn rthigh to x-axis ((<33.711123> *animAmplitude)/100) speed ((<1506.623481> *animAmplitude)/100) / animSpeed; //delta=50.22
			turn rthigh to z-axis ((<-11.888106> *animAmplitude)/100) speed ((<253.781467> *animAmplitude)/100) / animSpeed; //delta=8.46
			turn rthigh to y-axis ((<3.515142> *animAmplitude)/100) speed ((<241.864589> *animAmplitude)/100) / animSpeed; //delta=8.06
			turn RLHAND to z-axis ((<-7.016032> *animAmplitude)/100) speed ((<444.748370> *animAmplitude)/100) / animSpeed; //delta=14.82
			turn RUHAND to z-axis ((<-7.016032> *animAmplitude)/100) speed ((<444.748370> *animAmplitude)/100) / animSpeed; //delta=14.82
			turn tail to x-axis ((<-8.0> *animAmplitude)/100) speed ((<389.999994> *animAmplitude)/100) / animSpeed; //delta=13.00
			turn tail to y-axis ((<-10.633881> *animAmplitude)/100) speed ((<177.310849> *animAmplitude)/100) / animSpeed; //delta=5.91
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:48
			move body to x-axis (((([-0.205555] *MOVESCALE)/100) *animAmplitude)/100) speed (((([92.499998] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-3.08
			move body to z-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			move body to y-axis (((([-2.259427] *MOVESCALE)/100) *animAmplitude)/100) speed (((([36.277556] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.21
			turn body to x-axis ((<1.666667> *animAmplitude)/100) speed ((<40.0> *animAmplitude)/100) / animSpeed; //delta=1.33
			turn body to z-axis ((<7.317701> *animAmplitude)/100) speed ((<73.177016> *animAmplitude)/100) / animSpeed; //delta=-2.44
			turn head to x-axis ((<1.148542> *animAmplitude)/100) speed ((<54.145547> *animAmplitude)/100) / animSpeed; //delta=1.80
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<165.547803> *animAmplitude)/100) / animSpeed; //delta=-5.52
			turn lfoot to x-axis ((<0.058231> *animAmplitude)/100) speed ((<1139.029043> *animAmplitude)/100) / animSpeed; //delta=37.97
			turn lfoot to z-axis ((<-4.823758> *animAmplitude)/100) speed ((<146.693392> *animAmplitude)/100) / animSpeed; //delta=4.89
			turn lfoot to y-axis ((<-0.093912> *animAmplitude)/100) speed ((<41.488969> *animAmplitude)/100) / animSpeed; //delta=1.38
			turn lknee to x-axis ((<15.959362> *animAmplitude)/100) speed ((<1042.277612> *animAmplitude)/100) / animSpeed; //delta=-34.74
			turn lshin to x-axis ((<-8.697853> *animAmplitude)/100) speed ((<430.438987> *animAmplitude)/100) / animSpeed; //delta=14.35
			turn lthigh to x-axis ((<-9.688829> *animAmplitude)/100) speed ((<546.537403> *animAmplitude)/100) / animSpeed; //delta=-18.22
			turn lthigh to z-axis ((<-2.523526> *animAmplitude)/100) speed ((<59.060526> *animAmplitude)/100) / animSpeed; //delta=-1.97
			turn lthigh to y-axis ((<-0.532756> *animAmplitude)/100) speed ((<13.649390> *animAmplitude)/100) / animSpeed; //delta=0.45
			turn LLHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<220.418118> *animAmplitude)/100) / animSpeed; //delta=7.35
			turn LUHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<220.418118> *animAmplitude)/100) / animSpeed; //delta=7.35
			turn rfoot to x-axis ((<-0.979774> *animAmplitude)/100) speed ((<1058.243754> *animAmplitude)/100) / animSpeed; //delta=-35.27
			turn rfoot to z-axis ((<-0.885694> *animAmplitude)/100) speed ((<230.802735> *animAmplitude)/100) / animSpeed; //delta=7.69
			turn rfoot to y-axis ((<-0.365730> *animAmplitude)/100) speed ((<67.319773> *animAmplitude)/100) / animSpeed; //delta=-2.24
			turn rknee to x-axis ((<27.789581> *animAmplitude)/100) speed ((<384.392545> *animAmplitude)/100) / animSpeed; //delta=-12.81
			turn rshin to x-axis ((<-14.253648> *animAmplitude)/100) speed ((<563.081026> *animAmplitude)/100) / animSpeed; //delta=18.77
			turn rthigh to x-axis ((<-14.657038> *animAmplitude)/100) speed ((<1451.044815> *animAmplitude)/100) / animSpeed; //delta=48.37
			turn rthigh to z-axis ((<-6.632762> *animAmplitude)/100) speed ((<157.660343> *animAmplitude)/100) / animSpeed; //delta=-5.26
			turn rthigh to y-axis ((<-1.349493> *animAmplitude)/100) speed ((<145.939069> *animAmplitude)/100) / animSpeed; //delta=-4.86
			turn RLHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<222.374182> *animAmplitude)/100) / animSpeed; //delta=-7.41
			turn RUHAND to z-axis ((<0.396441> *animAmplitude)/100) speed ((<222.374182> *animAmplitude)/100) / animSpeed; //delta=-7.41
			turn tail to x-axis ((<-6.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<319.016442> *animAmplitude)/100) / animSpeed; //delta=10.63
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:54
			move body to x-axis (((([-2.466667] *MOVESCALE)/100) *animAmplitude)/100) speed (((([67.833338] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-2.26
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			move body to y-axis (((([3.468679] *MOVESCALE)/100) *animAmplitude)/100) speed (((([171.843166] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=5.73
			turn body to x-axis ((<0.555556> *animAmplitude)/100) speed ((<33.333330> *animAmplitude)/100) / animSpeed; //delta=1.11
			turn body to z-axis ((<4.878467> *animAmplitude)/100) speed ((<73.177016> *animAmplitude)/100) / animSpeed; //delta=2.44
			turn head to x-axis ((<-0.0> *animAmplitude)/100) speed ((<34.456256> *animAmplitude)/100) / animSpeed; //delta=1.15
			turn head to y-axis ((<-6.868268> *animAmplitude)/100) speed ((<206.048037> *animAmplitude)/100) / animSpeed; //delta=-6.87
			turn lfoot to x-axis ((<-31.194130> *animAmplitude)/100) speed ((<937.570821> *animAmplitude)/100) / animSpeed; //delta=31.25
			turn lfoot to z-axis ((<-6.685563> *animAmplitude)/100) speed ((<55.854149> *animAmplitude)/100) / animSpeed; //delta=1.86
			turn lfoot to y-axis ((<-0.513852> *animAmplitude)/100) speed ((<12.598177> *animAmplitude)/100) / animSpeed; //delta=-0.42
			turn lknee to x-axis ((<-35.967373> *animAmplitude)/100) speed ((<1557.802054> *animAmplitude)/100) / animSpeed; //delta=51.93
			turn lshin to x-axis ((<20.174745> *animAmplitude)/100) speed ((<866.177936> *animAmplitude)/100) / animSpeed; //delta=-28.87
			turn lthigh to x-axis ((<47.331090> *animAmplitude)/100) speed ((<1710.597578> *animAmplitude)/100) / animSpeed; //delta=-57.02
			turn lthigh to z-axis ((<2.276099> *animAmplitude)/100) speed ((<143.988755> *animAmplitude)/100) / animSpeed; //delta=-4.80
			turn lthigh to y-axis ((<-1.195640> *animAmplitude)/100) speed ((<19.886514> *animAmplitude)/100) / animSpeed; //delta=-0.66
			turn LLHAND to z-axis ((<-3.277195> *animAmplitude)/100) speed ((<110.209066> *animAmplitude)/100) / animSpeed; //delta=3.67
			turn LUHAND to z-axis ((<-3.277195> *animAmplitude)/100) speed ((<110.209066> *animAmplitude)/100) / animSpeed; //delta=3.67
			turn rfoot to x-axis ((<31.144044> *animAmplitude)/100) speed ((<963.714529> *animAmplitude)/100) / animSpeed; //delta=-32.12
			turn rfoot to z-axis ((<-2.011291> *animAmplitude)/100) speed ((<33.767900> *animAmplitude)/100) / animSpeed; //delta=1.13
			turn rfoot to y-axis ((<-1.191012> *animAmplitude)/100) speed ((<24.758460> *animAmplitude)/100) / animSpeed; //delta=-0.83
			turn rknee to x-axis ((<-27.573366> *animAmplitude)/100) speed ((<1660.888409> *animAmplitude)/100) / animSpeed; //delta=55.36
			turn rshin to x-axis ((<6.829033> *animAmplitude)/100) speed ((<632.480414> *animAmplitude)/100) / animSpeed; //delta=-21.08
			turn rthigh to x-axis ((<-29.493132> *animAmplitude)/100) speed ((<445.082840> *animAmplitude)/100) / animSpeed; //delta=14.84
			turn rthigh to z-axis ((<-2.365037> *animAmplitude)/100) speed ((<128.031751> *animAmplitude)/100) / animSpeed; //delta=-4.27
			turn rthigh to y-axis ((<-1.064668> *animAmplitude)/100) speed ((<8.544756> *animAmplitude)/100) / animSpeed; //delta=0.28
			turn RLHAND to z-axis ((<4.102677> *animAmplitude)/100) speed ((<111.187092> *animAmplitude)/100) / animSpeed; //delta=-3.71
			turn RUHAND to z-axis ((<4.102677> *animAmplitude)/100) speed ((<111.187092> *animAmplitude)/100) / animSpeed; //delta=-3.71
			turn tail to x-axis ((<-2.0> *animAmplitude)/100) speed ((<120.0> *animAmplitude)/100) / animSpeed; //delta=-4.00
			turn tail to y-axis ((<13.235395> *animAmplitude)/100) speed ((<397.061837> *animAmplitude)/100) / animSpeed; //delta=13.24
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
	animSpeed = 2*MOVESPEED; // tune restore speed here, higher values are slower restore speeds
	move body to x-axis ([0.0]*MOVESCALE)/100 speed (([176.805556]*MOVESCALE)/100) / animSpeed;
	move body to y-axis ([0.0]*MOVESCALE)/100 speed (([286.405277]*MOVESCALE)/100) / animSpeed;
	move body to z-axis ([0.0]*MOVESCALE)/100 speed (([50.0]*MOVESCALE)/100) / animSpeed;
	turn body to x-axis <0.0> speed <88.888917> / animSpeed;
	turn body to y-axis <0.0> speed <88.888917> / animSpeed;
	turn body to z-axis <0.0> speed <243.923344> / animSpeed;
	turn head to x-axis <0.0> speed <155.873551> / animSpeed;
	turn head to y-axis <0.0> speed <343.413395> / animSpeed;
	turn lfoot to x-axis <0.0> speed <1898.381738> / animSpeed;
	turn lfoot to y-axis <0.0> speed <351.894234> / animSpeed;
	turn lfoot to z-axis <0.0> speed <425.078752> / animSpeed;
	turn lknee to x-axis <0.0> speed <4575.518112> / animSpeed;
	turn lknee to y-axis <0.0> speed <124.210430> / animSpeed;
	turn lknee to z-axis <0.0> speed <114.701101> / animSpeed;
	turn lshin to x-axis <0.0> speed <2350.246941> / animSpeed;
	turn lshin to y-axis <0.0> speed <20.377837> / animSpeed;
	turn lshin to z-axis <0.0> speed <29.199371> / animSpeed;
	turn lthigh to x-axis <0.0> speed <2850.995964> / animSpeed;
	turn lthigh to y-axis <0.0> speed <391.279041> / animSpeed;
	turn lthigh to z-axis <0.0> speed <455.662922> / animSpeed;
	turn LLHAND to z-axis <0.0> speed <734.727035> / animSpeed;
	turn LUHAND to z-axis <0.0> speed <734.727035> / animSpeed;
	turn rfoot to x-axis <0.556060> speed <1890.583744> / animSpeed;
	turn rfoot to y-axis <0.0> speed <347.580387> / animSpeed;
	turn rfoot to z-axis <0.0> speed <384.671225> / animSpeed;
	turn rknee to x-axis <0.285129> speed <4536.640077> / animSpeed;
	turn rknee to y-axis <0.0> speed <112.475626> / animSpeed;
	turn rknee to z-axis <0.0> speed <103.609043> / animSpeed;
	turn rshin to x-axis <0.0> speed <2645.515560> / animSpeed;
	turn rshin to y-axis <0.0> speed <19.256314> / animSpeed;
	turn rshin to z-axis <0.0> speed <27.962635> / animSpeed;
	turn rthigh to x-axis <-0.243776> speed <2810.196938> / animSpeed;
	turn rthigh to y-axis <0.0> speed <403.107648> / animSpeed;
	turn rthigh to z-axis <0.0> speed <422.969112> / animSpeed;
	turn RUHAND to z-axis <0.0> speed <741.247283> / animSpeed;
	turn RLHAND to z-axis <0.0> speed <741.247283> / animSpeed;
	turn tail to x-axis <0.0> speed <649.999990> / animSpeed;
	turn tail to y-axis <0.0> speed <661.769729> / animSpeed;
}