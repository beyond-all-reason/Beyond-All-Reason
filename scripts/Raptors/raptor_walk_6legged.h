// this animation uses the static-var animFramesPerKeyframe which contains how many frames each keyframe takes
//Needs a crapton of #defines and static-vars:



// For N:\animations\Raptors\Kremenchuk\kremenraptor_ik_walk.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 7))
//#define MOVESCALE 100 //Higher values are bigger, 100 is default
//static-var animAmplitude; //Higher values are bigger, 100 is default
// this animation uses the static-var animFramesPerKeyframe which contains how many frames each keyframe takes
//static-var animSpeed, maxSpeed, animFramesPerKeyframe, isMoving;
Walk() {// For N:\animations\Raptors\Kremenchuk\kremenraptor_ik_walk.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 7)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:6
			turn foot1l to z-axis ((<-0.971251> *animAmplitude)/100) speed ((<748.423405> *animAmplitude)/100) / animSpeed; //delta=24.95
			turn foot1r to z-axis ((<-44.049437> *animAmplitude)/100) speed ((<609.039448> *animAmplitude)/100) / animSpeed; //delta=20.30
			turn foot2l to z-axis ((<5.346900> *animAmplitude)/100) speed ((<160.406988> *animAmplitude)/100) / animSpeed; //delta=-5.35
			turn foot2r to z-axis ((<0.532721> *animAmplitude)/100) speed ((<15.981633> *animAmplitude)/100) / animSpeed; //delta=-0.53
			turn foot3l to z-axis ((<-9.202014> *animAmplitude)/100) speed ((<836.086282> *animAmplitude)/100) / animSpeed; //delta=27.87
			turn foot3r to z-axis ((<-44.062869> *animAmplitude)/100) speed ((<609.374827> *animAmplitude)/100) / animSpeed; //delta=20.31
			turn leg1l to z-axis ((<1.040571> *animAmplitude)/100) speed ((<249.022165> *animAmplitude)/100) / animSpeed; //delta=-8.30
			turn leg1r to z-axis ((<11.848949> *animAmplitude)/100) speed ((<148.781332> *animAmplitude)/100) / animSpeed; //delta=-4.96
			turn leg2l to z-axis ((<-3.579697> *animAmplitude)/100) speed ((<107.390904> *animAmplitude)/100) / animSpeed; //delta=3.58
			turn leg2r to z-axis ((<0.806456> *animAmplitude)/100) speed ((<24.193666> *animAmplitude)/100) / animSpeed; //delta=-0.81
			turn leg3l to z-axis ((<4.010737> *animAmplitude)/100) speed ((<296.346792> *animAmplitude)/100) / animSpeed; //delta=-9.88
			turn leg3r to z-axis ((<11.850483> *animAmplitude)/100) speed ((<148.622786> *animAmplitude)/100) / animSpeed; //delta=-4.95
			turn thigh1l to z-axis ((<1.269835> *animAmplitude)/100) speed ((<247.164032> *animAmplitude)/100) / animSpeed; //delta=-8.24
			turn thigh1l to y-axis ((<-46.722988> *animAmplitude)/100) speed ((<357.736212> *animAmplitude)/100) / animSpeed; //delta=-11.92
			turn thigh1r to z-axis ((<16.230577> *animAmplitude)/100) speed ((<273.423840> *animAmplitude)/100) / animSpeed; //delta=-9.11
			turn thigh1r to y-axis ((<0.076046> *animAmplitude)/100) speed ((<1043.237430> *animAmplitude)/100) / animSpeed; //delta=-34.77
			turn thigh2l to z-axis ((<-6.730049> *animAmplitude)/100) speed ((<201.901463> *animAmplitude)/100) / animSpeed; //delta=6.73
			turn thigh2r to z-axis ((<1.289046> *animAmplitude)/100) speed ((<38.671390> *animAmplitude)/100) / animSpeed; //delta=-1.29
			turn thigh3l to z-axis ((<3.182355> *animAmplitude)/100) speed ((<253.122081> *animAmplitude)/100) / animSpeed; //delta=-8.44
			turn thigh3l to y-axis ((<49.004145> *animAmplitude)/100) speed ((<329.521828> *animAmplitude)/100) / animSpeed; //delta=10.98
			turn thigh3r to z-axis ((<16.236265> *animAmplitude)/100) speed ((<273.729841> *animAmplitude)/100) / animSpeed; //delta=-9.12
			turn thigh3r to y-axis ((<-0.069410> *animAmplitude)/100) speed ((<1043.295221> *animAmplitude)/100) / animSpeed; //delta=34.78
			turn torso to z-axis ((<-2.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:12
			turn foot1l to z-axis ((<23.805265> *animAmplitude)/100) speed ((<743.295487> *animAmplitude)/100) / animSpeed; //delta=-24.78
			turn foot1r to z-axis ((<-28.886806> *animAmplitude)/100) speed ((<454.878919> *animAmplitude)/100) / animSpeed; //delta=-15.16
			turn foot2l to z-axis ((<-22.001016> *animAmplitude)/100) speed ((<820.437469> *animAmplitude)/100) / animSpeed; //delta=27.35
			turn foot2r to z-axis ((<5.010677> *animAmplitude)/100) speed ((<134.338682> *animAmplitude)/100) / animSpeed; //delta=-4.48
			turn foot3l to z-axis ((<-61.932023> *animAmplitude)/100) speed ((<1581.900268> *animAmplitude)/100) / animSpeed; //delta=52.73
			turn foot3r to z-axis ((<-39.126264> *animAmplitude)/100) speed ((<148.098138> *animAmplitude)/100) / animSpeed; //delta=-4.94
			turn leg1l to z-axis ((<-7.418698> *animAmplitude)/100) speed ((<253.778077> *animAmplitude)/100) / animSpeed; //delta=8.46
			turn leg1r to z-axis ((<10.974079> *animAmplitude)/100) speed ((<26.246086> *animAmplitude)/100) / animSpeed; //delta=0.87
			turn leg2l to z-axis ((<8.468175> *animAmplitude)/100) speed ((<361.436162> *animAmplitude)/100) / animSpeed; //delta=-12.05
			turn leg2r to z-axis ((<-2.095475> *animAmplitude)/100) speed ((<87.057901> *animAmplitude)/100) / animSpeed; //delta=2.90
			turn leg3l to z-axis ((<31.850077> *animAmplitude)/100) speed ((<835.180189> *animAmplitude)/100) / animSpeed; //delta=-27.84
			turn leg3r to z-axis ((<9.555689> *animAmplitude)/100) speed ((<68.843825> *animAmplitude)/100) / animSpeed; //delta=2.29
			turn thigh1l to z-axis ((<-6.846813> *animAmplitude)/100) speed ((<243.499448> *animAmplitude)/100) / animSpeed; //delta=8.12
			turn thigh1l to y-axis ((<-34.208702> *animAmplitude)/100) speed ((<375.428588> *animAmplitude)/100) / animSpeed; //delta=12.51
			turn thigh1r to z-axis ((<15.546311> *animAmplitude)/100) speed ((<20.527963> *animAmplitude)/100) / animSpeed; //delta=0.68
			turn thigh1r to y-axis ((<34.804807> *animAmplitude)/100) speed ((<1041.862821> *animAmplitude)/100) / animSpeed; //delta=34.73
			turn thigh2l to z-axis ((<4.315498> *animAmplitude)/100) speed ((<331.366401> *animAmplitude)/100) / animSpeed; //delta=-11.05
			turn thigh2l to y-axis ((<-25.423310> *animAmplitude)/100) speed ((<762.699289> *animAmplitude)/100) / animSpeed; //delta=-25.42
			turn thigh2r to z-axis ((<-1.814149> *animAmplitude)/100) speed ((<93.095862> *animAmplitude)/100) / animSpeed; //delta=3.10
			turn thigh2r to y-axis ((<-14.034954> *animAmplitude)/100) speed ((<421.048608> *animAmplitude)/100) / animSpeed; //delta=-14.03
			turn thigh3l to z-axis ((<5.314684> *animAmplitude)/100) speed ((<63.969861> *animAmplitude)/100) / animSpeed; //delta=-2.13
			turn thigh3l to y-axis ((<55.835652> *animAmplitude)/100) speed ((<204.945222> *animAmplitude)/100) / animSpeed; //delta=6.83
			turn thigh3r to z-axis ((<12.620379> *animAmplitude)/100) speed ((<108.476578> *animAmplitude)/100) / animSpeed; //delta=3.62
			turn thigh3r to y-axis ((<-19.840318> *animAmplitude)/100) speed ((<593.127237> *animAmplitude)/100) / animSpeed; //delta=-19.77
			turn torso to x-axis ((<-1.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn torso to z-axis ((<1.0> *animAmplitude)/100) speed ((<89.999990> *animAmplitude)/100) / animSpeed; //delta=-3.00
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:18
			turn foot1l to z-axis ((<39.391156> *animAmplitude)/100) speed ((<467.576719> *animAmplitude)/100) / animSpeed; //delta=-15.59
			turn foot1r to z-axis ((<43.847588> *animAmplitude)/100) speed ((<2182.031826> *animAmplitude)/100) / animSpeed; //delta=-72.73
			turn foot2l to z-axis ((<-5.048070> *animAmplitude)/100) speed ((<508.588372> *animAmplitude)/100) / animSpeed; //delta=-16.95
			turn foot2r to z-axis ((<21.920650> *animAmplitude)/100) speed ((<507.299195> *animAmplitude)/100) / animSpeed; //delta=-16.91
			turn foot3l to z-axis ((<23.829729> *animAmplitude)/100) speed ((<2572.852569> *animAmplitude)/100) / animSpeed; //delta=-85.76
			turn foot3r to z-axis ((<-23.615939> *animAmplitude)/100) speed ((<465.309745> *animAmplitude)/100) / animSpeed; //delta=-15.51
			turn leg1l to z-axis ((<-10.051384> *animAmplitude)/100) speed ((<78.980585> *animAmplitude)/100) / animSpeed; //delta=2.63
			turn leg1r to z-axis ((<-18.826330> *animAmplitude)/100) speed ((<894.012297> *animAmplitude)/100) / animSpeed; //delta=29.80
			turn leg2l to z-axis ((<2.183875> *animAmplitude)/100) speed ((<188.529012> *animAmplitude)/100) / animSpeed; //delta=6.28
			turn leg2r to z-axis ((<-8.100519> *animAmplitude)/100) speed ((<180.151334> *animAmplitude)/100) / animSpeed; //delta=6.01
			turn leg3l to z-axis ((<-9.864379> *animAmplitude)/100) speed ((<1251.433697> *animAmplitude)/100) / animSpeed; //delta=41.71
			turn leg3r to z-axis ((<7.055961> *animAmplitude)/100) speed ((<74.991840> *animAmplitude)/100) / animSpeed; //delta=2.50
			turn thigh1l to z-axis ((<-12.412455> *animAmplitude)/100) speed ((<166.969259> *animAmplitude)/100) / animSpeed; //delta=5.57
			turn thigh1l to y-axis ((<-19.769714> *animAmplitude)/100) speed ((<433.169624> *animAmplitude)/100) / animSpeed; //delta=14.44
			turn thigh1r to z-axis ((<-6.345408> *animAmplitude)/100) speed ((<656.751580> *animAmplitude)/100) / animSpeed; //delta=21.89
			turn thigh1r to y-axis ((<54.246858> *animAmplitude)/100) speed ((<583.261545> *animAmplitude)/100) / animSpeed; //delta=19.44
			turn thigh2l to z-axis ((<1.766251> *animAmplitude)/100) speed ((<76.477413> *animAmplitude)/100) / animSpeed; //delta=2.55
			turn thigh2l to y-axis ((<-14.034952> *animAmplitude)/100) speed ((<341.650732> *animAmplitude)/100) / animSpeed; //delta=11.39
			turn thigh2r to z-axis ((<-4.560150> *animAmplitude)/100) speed ((<82.380034> *animAmplitude)/100) / animSpeed; //delta=2.75
			turn thigh2r to y-axis ((<-25.423310> *animAmplitude)/100) speed ((<341.650681> *animAmplitude)/100) / animSpeed; //delta=-11.39
			turn thigh3l to z-axis ((<-13.288866> *animAmplitude)/100) speed ((<558.106518> *animAmplitude)/100) / animSpeed; //delta=18.60
			turn thigh3l to y-axis ((<37.988713> *animAmplitude)/100) speed ((<535.408181> *animAmplitude)/100) / animSpeed; //delta=-17.85
			turn thigh3r to z-axis ((<7.006146> *animAmplitude)/100) speed ((<168.426997> *animAmplitude)/100) / animSpeed; //delta=5.61
			turn thigh3r to y-axis ((<-34.267302> *animAmplitude)/100) speed ((<432.809502> *animAmplitude)/100) / animSpeed; //delta=-14.43
			turn torso to x-axis ((<1.0> *animAmplitude)/100) speed ((<60.0> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn torso to z-axis ((<-1.0> *animAmplitude)/100) speed ((<59.999996> *animAmplitude)/100) / animSpeed; //delta=2.00
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:24
			turn foot1l to z-axis ((<44.381015> *animAmplitude)/100) speed ((<149.695788> *animAmplitude)/100) / animSpeed; //delta=-4.99
			turn foot1r to z-axis ((<1.041741> *animAmplitude)/100) speed ((<1284.175405> *animAmplitude)/100) / animSpeed; //delta=42.81
			turn foot2l to z-axis ((<-0.503263> *animAmplitude)/100) speed ((<136.344230> *animAmplitude)/100) / animSpeed; //delta=-4.54
			turn foot2r to z-axis ((<-5.202115> *animAmplitude)/100) speed ((<813.682959> *animAmplitude)/100) / animSpeed; //delta=27.12
			turn foot3l to z-axis ((<44.049471> *animAmplitude)/100) speed ((<606.592259> *animAmplitude)/100) / animSpeed; //delta=-20.22
			turn foot3r to z-axis ((<1.018392> *animAmplitude)/100) speed ((<739.029930> *animAmplitude)/100) / animSpeed; //delta=-24.63
			turn leg1l to z-axis ((<-12.445942> *animAmplitude)/100) speed ((<71.836728> *animAmplitude)/100) / animSpeed; //delta=2.39
			turn leg1r to z-axis ((<-1.043452> *animAmplitude)/100) speed ((<533.486342> *animAmplitude)/100) / animSpeed; //delta=-17.78
			turn leg2l to z-axis ((<-0.815092> *animAmplitude)/100) speed ((<89.969015> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn leg2r to z-axis ((<3.472031> *animAmplitude)/100) speed ((<347.176513> *animAmplitude)/100) / animSpeed; //delta=-11.57
			turn leg3l to z-axis ((<-12.402514> *animAmplitude)/100) speed ((<76.144050> *animAmplitude)/100) / animSpeed; //delta=2.54
			turn leg3r to z-axis ((<-1.021348> *animAmplitude)/100) speed ((<242.319271> *animAmplitude)/100) / animSpeed; //delta=8.08
			turn thigh1l to z-axis ((<-16.005442> *animAmplitude)/100) speed ((<107.789606> *animAmplitude)/100) / animSpeed; //delta=3.59
			turn thigh1l to y-axis ((<0.0> *animAmplitude)/100) speed ((<593.092178> *animAmplitude)/100) / animSpeed; //delta=19.77
			turn thigh1r to z-axis ((<-1.302798> *animAmplitude)/100) speed ((<151.278312> *animAmplitude)/100) / animSpeed; //delta=-5.04
			turn thigh1r to y-axis ((<46.767507> *animAmplitude)/100) speed ((<224.380525> *animAmplitude)/100) / animSpeed; //delta=-7.48
			turn thigh2l to z-axis ((<-1.298019> *animAmplitude)/100) speed ((<91.928085> *animAmplitude)/100) / animSpeed; //delta=3.06
			turn thigh2l to y-axis ((<-0.0> *animAmplitude)/100) speed ((<421.048557> *animAmplitude)/100) / animSpeed; //delta=14.03
			turn thigh2r to z-axis ((<6.732324> *animAmplitude)/100) speed ((<338.774215> *animAmplitude)/100) / animSpeed; //delta=-11.29
			turn thigh2r to y-axis ((<-0.0> *animAmplitude)/100) speed ((<762.699289> *animAmplitude)/100) / animSpeed; //delta=25.42
			turn thigh3l to z-axis ((<-15.859872> *animAmplitude)/100) speed ((<77.130159> *animAmplitude)/100) / animSpeed; //delta=2.57
			turn thigh3l to y-axis ((<4.882142> *animAmplitude)/100) speed ((<993.197120> *animAmplitude)/100) / animSpeed; //delta=-33.11
			turn thigh3r to z-axis ((<-1.307457> *animAmplitude)/100) speed ((<249.408069> *animAmplitude)/100) / animSpeed; //delta=8.31
			turn thigh3r to y-axis ((<-46.768723> *animAmplitude)/100) speed ((<375.042648> *animAmplitude)/100) / animSpeed; //delta=-12.50
			turn torso to x-axis ((<-0.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn torso to z-axis ((<2.0> *animAmplitude)/100) speed ((<89.999999> *animAmplitude)/100) / animSpeed; //delta=-3.00
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:30
			turn foot1l to z-axis ((<29.245405> *animAmplitude)/100) speed ((<454.068312> *animAmplitude)/100) / animSpeed; //delta=15.14
			turn foot1r to z-axis ((<-23.601836> *animAmplitude)/100) speed ((<739.307325> *animAmplitude)/100) / animSpeed; //delta=24.64
			turn foot2l to z-axis ((<-5.048159> *animAmplitude)/100) speed ((<136.346894> *animAmplitude)/100) / animSpeed; //delta=4.54
			turn foot2r to z-axis ((<21.927310> *animAmplitude)/100) speed ((<813.882742> *animAmplitude)/100) / animSpeed; //delta=-27.13
			turn foot3l to z-axis ((<36.496371> *animAmplitude)/100) speed ((<226.592994> *animAmplitude)/100) / animSpeed; //delta=7.55
			turn foot3r to z-axis ((<43.808560> *animAmplitude)/100) speed ((<1283.705048> *animAmplitude)/100) / animSpeed; //delta=-42.79
			turn leg1l to z-axis ((<-11.425575> *animAmplitude)/100) speed ((<30.610987> *animAmplitude)/100) / animSpeed; //delta=-1.02
			turn leg1r to z-axis ((<7.050876> *animAmplitude)/100) speed ((<242.829838> *animAmplitude)/100) / animSpeed; //delta=-8.09
			turn leg2l to z-axis ((<2.182811> *animAmplitude)/100) speed ((<89.937114> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn leg2r to z-axis ((<-8.110661> *animAmplitude)/100) speed ((<347.480773> *animAmplitude)/100) / animSpeed; //delta=11.58
			turn leg3l to z-axis ((<-9.648715> *animAmplitude)/100) speed ((<82.613998> *animAmplitude)/100) / animSpeed; //delta=-2.75
			turn leg3r to z-axis ((<-18.793540> *animAmplitude)/100) speed ((<533.165774> *animAmplitude)/100) / animSpeed; //delta=17.77
			turn thigh1l to z-axis ((<-15.406019> *animAmplitude)/100) speed ((<17.982676> *animAmplitude)/100) / animSpeed; //delta=-0.60
			turn thigh1l to y-axis ((<-34.745220> *animAmplitude)/100) speed ((<1042.357348> *animAmplitude)/100) / animSpeed; //delta=-34.75
			turn thigh1r to z-axis ((<7.003518> *animAmplitude)/100) speed ((<249.189467> *animAmplitude)/100) / animSpeed; //delta=-8.31
			turn thigh1r to y-axis ((<34.267909> *animAmplitude)/100) speed ((<374.987938> *animAmplitude)/100) / animSpeed; //delta=-12.50
			turn thigh2l to z-axis ((<1.767101> *animAmplitude)/100) speed ((<91.953592> *animAmplitude)/100) / animSpeed; //delta=-3.07
			turn thigh2l to y-axis ((<14.034953> *animAmplitude)/100) speed ((<421.048582> *animAmplitude)/100) / animSpeed; //delta=14.03
			turn thigh2r to z-axis ((<-4.555985> *animAmplitude)/100) speed ((<338.649248> *animAmplitude)/100) / animSpeed; //delta=11.29
			turn thigh2r to y-axis ((<25.423311> *animAmplitude)/100) speed ((<762.699340> *animAmplitude)/100) / animSpeed; //delta=25.42
			turn thigh3l to z-axis ((<-11.331485> *animAmplitude)/100) speed ((<135.851592> *animAmplitude)/100) / animSpeed; //delta=-4.53
			turn thigh3l to y-axis ((<24.086915> *animAmplitude)/100) speed ((<576.143173> *animAmplitude)/100) / animSpeed; //delta=19.20
			turn thigh3r to z-axis ((<-6.351280> *animAmplitude)/100) speed ((<151.314690> *animAmplitude)/100) / animSpeed; //delta=5.04
			turn thigh3r to y-axis ((<-54.248678> *animAmplitude)/100) speed ((<224.398659> *animAmplitude)/100) / animSpeed; //delta=-7.48
			turn torso to x-axis ((<-1.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn torso to z-axis ((<-1.0> *animAmplitude)/100) speed ((<89.999999> *animAmplitude)/100) / animSpeed; //delta=3.00
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:36
			turn foot1l to z-axis ((<-43.654860> *animAmplitude)/100) speed ((<2187.007960> *animAmplitude)/100) / animSpeed; //delta=72.90
			turn foot1r to z-axis ((<-39.103502> *animAmplitude)/100) speed ((<465.049976> *animAmplitude)/100) / animSpeed; //delta=15.50
			turn foot2l to z-axis ((<-21.993288> *animAmplitude)/100) speed ((<508.353857> *animAmplitude)/100) / animSpeed; //delta=16.95
			turn foot2r to z-axis ((<5.010598> *animAmplitude)/100) speed ((<507.501347> *animAmplitude)/100) / animSpeed; //delta=16.92
			turn foot3l to z-axis ((<18.507916> *animAmplitude)/100) speed ((<539.653673> *animAmplitude)/100) / animSpeed; //delta=17.99
			turn foot3r to z-axis ((<-28.902253> *animAmplitude)/100) speed ((<2181.324389> *animAmplitude)/100) / animSpeed; //delta=72.71
			turn leg1l to z-axis ((<19.410940> *animAmplitude)/100) speed ((<925.095463> *animAmplitude)/100) / animSpeed; //delta=-30.84
			turn leg1r to z-axis ((<9.527147> *animAmplitude)/100) speed ((<74.288130> *animAmplitude)/100) / animSpeed; //delta=-2.48
			turn leg2l to z-axis ((<8.457716> *animAmplitude)/100) speed ((<188.247125> *animAmplitude)/100) / animSpeed; //delta=-6.27
			turn leg2r to z-axis ((<-2.096520> *animAmplitude)/100) speed ((<180.424230> *animAmplitude)/100) / animSpeed; //delta=-6.01
			turn leg3l to z-axis ((<-5.989909> *animAmplitude)/100) speed ((<109.764167> *animAmplitude)/100) / animSpeed; //delta=-3.66
			turn leg3r to z-axis ((<10.967188> *animAmplitude)/100) speed ((<892.821846> *animAmplitude)/100) / animSpeed; //delta=-29.76
			turn thigh1l to z-axis ((<5.777777> *animAmplitude)/100) speed ((<635.513901> *animAmplitude)/100) / animSpeed; //delta=-21.18
			turn thigh1l to y-axis ((<-54.213687> *animAmplitude)/100) speed ((<584.054018> *animAmplitude)/100) / animSpeed; //delta=-19.47
			turn thigh1r to z-axis ((<12.627099> *animAmplitude)/100) speed ((<168.707423> *animAmplitude)/100) / animSpeed; //delta=-5.62
			turn thigh1r to y-axis ((<19.843600> *animAmplitude)/100) speed ((<432.729282> *animAmplitude)/100) / animSpeed; //delta=-14.42
			turn thigh2l to z-axis ((<4.319306> *animAmplitude)/100) speed ((<76.566140> *animAmplitude)/100) / animSpeed; //delta=-2.55
			turn thigh2l to y-axis ((<25.423308> *animAmplitude)/100) speed ((<341.650656> *animAmplitude)/100) / animSpeed; //delta=11.39
			turn thigh2r to z-axis ((<-1.813317> *animAmplitude)/100) speed ((<82.280021> *animAmplitude)/100) / animSpeed; //delta=-2.74
			turn thigh2r to y-axis ((<14.034954> *animAmplitude)/100) speed ((<341.650707> *animAmplitude)/100) / animSpeed; //delta=-11.39
			turn thigh3l to z-axis ((<-5.090610> *animAmplitude)/100) speed ((<187.226273> *animAmplitude)/100) / animSpeed; //delta=-6.24
			turn thigh3l to y-axis ((<37.447926> *animAmplitude)/100) speed ((<400.830334> *animAmplitude)/100) / animSpeed; //delta=13.36
			turn thigh3r to z-axis ((<15.559932> *animAmplitude)/100) speed ((<657.336368> *animAmplitude)/100) / animSpeed; //delta=-21.91
			turn thigh3r to y-axis ((<-34.804301> *animAmplitude)/100) speed ((<583.331316> *animAmplitude)/100) / animSpeed; //delta=19.44
			turn torso to x-axis ((<1.0> *animAmplitude)/100) speed ((<60.0> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn torso to z-axis ((<1.0> *animAmplitude)/100) speed ((<60.0> *animAmplitude)/100) / animSpeed; //delta=-2.00
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:42
			turn foot1l to z-axis ((<-0.971251> *animAmplitude)/100) speed ((<1280.508279> *animAmplitude)/100) / animSpeed; //delta=-42.68
			turn foot1r to z-axis ((<-44.049437> *animAmplitude)/100) speed ((<148.378039> *animAmplitude)/100) / animSpeed; //delta=4.95
			turn foot2l to z-axis ((<5.346900> *animAmplitude)/100) speed ((<820.205619> *animAmplitude)/100) / animSpeed; //delta=-27.34
			turn foot2r to z-axis ((<0.532721> *animAmplitude)/100) speed ((<134.336313> *animAmplitude)/100) / animSpeed; //delta=4.48
			turn foot3l to z-axis ((<-9.202014> *animAmplitude)/100) speed ((<831.297893> *animAmplitude)/100) / animSpeed; //delta=27.71
			turn foot3r to z-axis ((<-44.062869> *animAmplitude)/100) speed ((<454.818472> *animAmplitude)/100) / animSpeed; //delta=15.16
			turn leg1l to z-axis ((<1.040571> *animAmplitude)/100) speed ((<551.111060> *animAmplitude)/100) / animSpeed; //delta=18.37
			turn leg1r to z-axis ((<11.848949> *animAmplitude)/100) speed ((<69.654073> *animAmplitude)/100) / animSpeed; //delta=-2.32
			turn leg2l to z-axis ((<-3.579697> *animAmplitude)/100) speed ((<361.122374> *animAmplitude)/100) / animSpeed; //delta=12.04
			turn leg2r to z-axis ((<0.806456> *animAmplitude)/100) speed ((<87.089265> *animAmplitude)/100) / animSpeed; //delta=-2.90
			turn leg3l to z-axis ((<4.010737> *animAmplitude)/100) speed ((<300.019393> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn leg3r to z-axis ((<11.850483> *animAmplitude)/100) speed ((<26.498863> *animAmplitude)/100) / animSpeed; //delta=-0.88
			turn thigh1l to z-axis ((<1.269835> *animAmplitude)/100) speed ((<135.238264> *animAmplitude)/100) / animSpeed; //delta=4.51
			turn thigh1l to y-axis ((<-46.722988> *animAmplitude)/100) speed ((<224.720976> *animAmplitude)/100) / animSpeed; //delta=7.49
			turn thigh1r to z-axis ((<16.230577> *animAmplitude)/100) speed ((<108.104341> *animAmplitude)/100) / animSpeed; //delta=-3.60
			turn thigh1r to y-axis ((<0.076046> *animAmplitude)/100) speed ((<593.026621> *animAmplitude)/100) / animSpeed; //delta=-19.77
			turn thigh2l to z-axis ((<-6.730049> *animAmplitude)/100) speed ((<331.480636> *animAmplitude)/100) / animSpeed; //delta=11.05
			turn thigh2l to y-axis ((<0.0> *animAmplitude)/100) speed ((<762.699238> *animAmplitude)/100) / animSpeed; //delta=-25.42
			turn thigh2r to z-axis ((<1.289046> *animAmplitude)/100) speed ((<93.070908> *animAmplitude)/100) / animSpeed; //delta=-3.10
			turn thigh2r to y-axis ((<-0.0> *animAmplitude)/100) speed ((<421.048634> *animAmplitude)/100) / animSpeed; //delta=-14.03
			turn thigh3l to z-axis ((<3.182355> *animAmplitude)/100) speed ((<248.188951> *animAmplitude)/100) / animSpeed; //delta=-8.27
			turn thigh3l to y-axis ((<49.004145> *animAmplitude)/100) speed ((<346.686571> *animAmplitude)/100) / animSpeed; //delta=11.56
			turn thigh3r to z-axis ((<16.236265> *animAmplitude)/100) speed ((<20.289965> *animAmplitude)/100) / animSpeed; //delta=-0.68
			turn thigh3r to y-axis ((<-0.069410> *animAmplitude)/100) speed ((<1042.046731> *animAmplitude)/100) / animSpeed; //delta=34.73
			turn torso to x-axis ((<-0.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn torso to z-axis ((<-2.0> *animAmplitude)/100) speed ((<89.999993> *animAmplitude)/100) / animSpeed; //delta=3.00
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
	animSpeed = 10; // tune restore speed here, higher values are slower restore speeds
	turn foot1l to z-axis <23.976196> speed <3645.013267> / animSpeed;
	turn foot1r to z-axis <-23.748122> speed <3636.719709> / animSpeed;
	turn foot2l to z-axis <0.0> speed <1367.395782> / animSpeed;
	turn foot2r to z-axis <0.0> speed <1356.471236> / animSpeed;
	turn foot3l to z-axis <18.667529> speed <4288.087615> / animSpeed;
	turn foot3r to z-axis <-23.750374> speed <3635.540648> / animSpeed;
	turn leg1l to z-axis <-7.260168> speed <1541.825772> / animSpeed;
	turn leg1r to z-axis <6.889571> speed <1490.020495> / animSpeed;
	turn leg2l to z-axis <0.0> speed <602.393603> / animSpeed;
	turn leg2r to z-axis <0.0> speed <579.134621> / animSpeed;
	turn leg3l to z-axis <-5.867489> speed <2085.722829> / animSpeed;
	turn leg3r to z-axis <6.896390> speed <1488.036410> / animSpeed;
	turn thigh1l to y-axis <-34.798448> speed <1737.262246> / animSpeed;
	turn thigh1l to z-axis <-6.968966> speed <1059.189835> / animSpeed;
	turn thigh1r to y-axis <34.850627> speed <1738.729050> / animSpeed;
	turn thigh1r to z-axis <7.116449> speed <1094.585967> / animSpeed;
	turn thigh2l to y-axis <0.0> speed <1271.165482> / animSpeed;
	turn thigh2l to z-axis <0.0> speed <552.467727> / animSpeed;
	turn thigh2r to y-axis <0.0> speed <1271.165567> / animSpeed;
	turn thigh2r to z-axis <0.0> speed <564.623692> / animSpeed;
	turn thigh3l to y-axis <38.020084> speed <1655.328533> / animSpeed;
	turn thigh3l to z-axis <-5.255047> speed <930.177530> / animSpeed;
	turn thigh3r to y-axis <-34.845918> speed <1738.825369> / animSpeed;
	turn thigh3r to z-axis <7.111937> speed <1095.560614> / animSpeed;
	turn torso to x-axis <0.0> speed <99.999999> / animSpeed;
	turn torso to z-axis <0.0> speed <149.999999> / animSpeed;
	
	// tail
	turn flare to x-axis <13.049453> speed <-93.210378> / animSpeed;
	turn thor1 to x-axis <-35.725175> speed <-255.179819> / animSpeed;
	turn thor2 to x-axis <-21.799876> speed <-155.713396> / animSpeed;
	turn thor3 to x-axis <-6.812812> speed <-48.662942> / animSpeed;
	turn thor4 to x-axis <4.699225> speed <-33.565894> / animSpeed;
	turn thor5 to x-axis <15.162363> speed <-108.302590> / animSpeed;
	turn thor6 to x-axis <19.165533> speed <-136.896664> / animSpeed;
}
