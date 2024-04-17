
//Needs a crapton of #defines and static-vars:

//#define MOVESCALE 100 //Higher values are bigger, 100 is default
//#define MOVESPEED 6
//#define animAmplitude 66
//#define SIGNAL_MOVE 1

Walk() {// For N:\animations\raptor_queen_walk_anim_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:5
			move body to y-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn body to x-axis ((<-0.217126> *animAmplitude)/100) speed ((<9.134978> *animAmplitude)/100) / animSpeed; //delta=-0.30
			turn body to z-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn body to y-axis ((<5.0> *animAmplitude)/100) speed ((<149.999996> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn head to x-axis ((<0.299937> *animAmplitude)/100) speed ((<17.998910> *animAmplitude)/100) / animSpeed; //delta=-0.60
			turn head to z-axis ((<-7.024838> *animAmplitude)/100) speed ((<210.745154> *animAmplitude)/100) / animSpeed; //delta=7.02
			turn head to y-axis ((<-2.966008> *animAmplitude)/100) speed ((<88.980238> *animAmplitude)/100) / animSpeed; //delta=-2.97
			turn lfootb to x-axis ((<13.399228> *animAmplitude)/100) speed ((<406.217632> *animAmplitude)/100) / animSpeed; //delta=-13.54
			turn lfootf to x-axis ((<25.395267> *animAmplitude)/100) speed ((<758.430994> *animAmplitude)/100) / animSpeed; //delta=-25.28
			turn lforearml to z-axis ((<-9.934124> *animAmplitude)/100) speed ((<298.023727> *animAmplitude)/100) / animSpeed; //delta=9.93
			turn lforearmu to z-axis ((<9.934124> *animAmplitude)/100) speed ((<298.023727> *animAmplitude)/100) / animSpeed; //delta=-9.93
			turn lkneeb to x-axis ((<20.332444> *animAmplitude)/100) speed ((<587.673164> *animAmplitude)/100) / animSpeed; //delta=-19.59
			turn lkneef to x-axis ((<-75.108223> *animAmplitude)/100) speed ((<2246.263011> *animAmplitude)/100) / animSpeed; //delta=74.88
			turn lkneef to z-axis ((<-0.168003> *animAmplitude)/100) speed ((<5.038204> *animAmplitude)/100) / animSpeed; //delta=0.17
			turn lkneef to y-axis ((<-0.184135> *animAmplitude)/100) speed ((<5.521406> *animAmplitude)/100) / animSpeed; //delta=-0.18
			turn lshinb to x-axis ((<-18.116406> *animAmplitude)/100) speed ((<540.118848> *animAmplitude)/100) / animSpeed; //delta=18.00
			turn lshinf to x-axis ((<50.562664> *animAmplitude)/100) speed ((<1504.942405> *animAmplitude)/100) / animSpeed; //delta=-50.16
			turn lthighb to x-axis ((<-17.799026> *animAmplitude)/100) speed ((<540.005936> *animAmplitude)/100) / animSpeed; //delta=18.00
			turn lthighb to z-axis ((<-6.362857> *animAmplitude)/100) speed ((<190.893402> *animAmplitude)/100) / animSpeed; //delta=6.36
			turn lthighb to y-axis ((<-2.257293> *animAmplitude)/100) speed ((<67.679166> *animAmplitude)/100) / animSpeed; //delta=-2.26
			turn lthighf to x-axis ((<-1.724737> *animAmplitude)/100) speed ((<64.589833> *animAmplitude)/100) / animSpeed; //delta=2.15
			turn lthighf to z-axis ((<1.855256> *animAmplitude)/100) speed ((<52.964493> *animAmplitude)/100) / animSpeed; //delta=-1.77
			turn lthighf to y-axis ((<-2.732909> *animAmplitude)/100) speed ((<87.001187> *animAmplitude)/100) / animSpeed; //delta=-2.90
			turn rfootb to x-axis ((<-2.695336> *animAmplitude)/100) speed ((<76.430811> *animAmplitude)/100) / animSpeed; //delta=2.55
			turn rfootf to x-axis ((<-23.660103> *animAmplitude)/100) speed ((<713.305201> *animAmplitude)/100) / animSpeed; //delta=23.78
			turn rforearml to z-axis ((<-9.934124> *animAmplitude)/100) speed ((<298.023727> *animAmplitude)/100) / animSpeed; //delta=9.93
			turn rforearmu to z-axis ((<-9.934124> *animAmplitude)/100) speed ((<298.023727> *animAmplitude)/100) / animSpeed; //delta=9.93
			turn rkneeb to x-axis ((<44.464412> *animAmplitude)/100) speed ((<1310.622232> *animAmplitude)/100) / animSpeed; //delta=-43.69
			turn rkneef to x-axis ((<15.902299> *animAmplitude)/100) speed ((<484.351065> *animAmplitude)/100) / animSpeed; //delta=-16.15
			turn rshinb to x-axis ((<-23.509885> *animAmplitude)/100) speed ((<701.773087> *animAmplitude)/100) / animSpeed; //delta=23.39
			turn rshinf to x-axis ((<-0.574512> *animAmplitude)/100) speed ((<28.963915> *animAmplitude)/100) / animSpeed; //delta=0.97
			turn rthighb to x-axis ((<-21.614620> *animAmplitude)/100) speed ((<653.695918> *animAmplitude)/100) / animSpeed; //delta=21.79
			turn rthighb to z-axis ((<-7.821142> *animAmplitude)/100) speed ((<234.648053> *animAmplitude)/100) / animSpeed; //delta=7.82
			turn rthighb to y-axis ((<-3.234374> *animAmplitude)/100) speed ((<96.975091> *animAmplitude)/100) / animSpeed; //delta=-3.23
			turn rthighf to x-axis ((<6.956811> *animAmplitude)/100) speed ((<195.418681> *animAmplitude)/100) / animSpeed; //delta=-6.51
			turn rthighf to z-axis ((<-0.604468> *animAmplitude)/100) speed ((<15.530064> *animAmplitude)/100) / animSpeed; //delta=0.52
			turn rthighf to y-axis ((<-3.128067> *animAmplitude)/100) speed ((<88.833580> *animAmplitude)/100) / animSpeed; //delta=-2.96
			turn spike1 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<3.408680> *animAmplitude)/100) / animSpeed; //delta=-0.11
			turn spike2 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<296.591309> *animAmplitude)/100) / animSpeed; //delta=9.89
			turn spike3 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn tail to x-axis ((<11.883820> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn tail to z-axis ((<-3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn tail to y-axis ((<-13.196538> *animAmplitude)/100) speed ((<395.896129> *animAmplitude)/100) / animSpeed; //delta=-13.20
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:10
			move body to y-axis (((([1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([60.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=2.00
			turn body to x-axis ((<-0.826125> *animAmplitude)/100) speed ((<18.269957> *animAmplitude)/100) / animSpeed; //delta=0.61
			turn body to z-axis ((<5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn body to y-axis ((<3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn head to x-axis ((<-0.899991> *animAmplitude)/100) speed ((<35.997822> *animAmplitude)/100) / animSpeed; //delta=1.20
			turn head to z-axis ((<-11.708064> *animAmplitude)/100) speed ((<140.496778> *animAmplitude)/100) / animSpeed; //delta=4.68
			turn head to y-axis ((<-1.779605> *animAmplitude)/100) speed ((<35.592100> *animAmplitude)/100) / animSpeed; //delta=1.19
			turn lfootb to x-axis ((<-5.778376> *animAmplitude)/100) speed ((<575.328110> *animAmplitude)/100) / animSpeed; //delta=19.18
			turn lfootf to x-axis ((<23.291010> *animAmplitude)/100) speed ((<63.127699> *animAmplitude)/100) / animSpeed; //delta=2.10
			turn lforearml to z-axis ((<-0.716974> *animAmplitude)/100) speed ((<276.514510> *animAmplitude)/100) / animSpeed; //delta=-9.22
			turn lforearmu to z-axis ((<0.716974> *animAmplitude)/100) speed ((<276.514510> *animAmplitude)/100) / animSpeed; //delta=9.22
			turn lkneeb to x-axis ((<13.994924> *animAmplitude)/100) speed ((<190.125598> *animAmplitude)/100) / animSpeed; //delta=6.34
			turn lkneef to x-axis ((<-38.111773> *animAmplitude)/100) speed ((<1109.893514> *animAmplitude)/100) / animSpeed; //delta=-37.00
			turn lkneef to z-axis ((<-0.016950> *animAmplitude)/100) speed ((<4.531581> *animAmplitude)/100) / animSpeed; //delta=-0.15
			turn lkneef to y-axis ((<-0.022296> *animAmplitude)/100) speed ((<4.855184> *animAmplitude)/100) / animSpeed; //delta=0.16
			turn lshinb to x-axis ((<-6.633100> *animAmplitude)/100) speed ((<344.499165> *animAmplitude)/100) / animSpeed; //delta=-11.48
			turn lshinf to x-axis ((<16.712812> *animAmplitude)/100) speed ((<1015.495570> *animAmplitude)/100) / animSpeed; //delta=33.85
			turn lthighb to x-axis ((<-3.698460> *animAmplitude)/100) speed ((<423.016957> *animAmplitude)/100) / animSpeed; //delta=-14.10
			turn lthighb to z-axis ((<-7.263902> *animAmplitude)/100) speed ((<27.031362> *animAmplitude)/100) / animSpeed; //delta=0.90
			turn lthighb to y-axis ((<-1.923222> *animAmplitude)/100) speed ((<10.022141> *animAmplitude)/100) / animSpeed; //delta=0.33
			turn lthighf to x-axis ((<-5.520589> *animAmplitude)/100) speed ((<113.875541> *animAmplitude)/100) / animSpeed; //delta=3.80
			turn lthighf to z-axis ((<-2.045483> *animAmplitude)/100) speed ((<117.022163> *animAmplitude)/100) / animSpeed; //delta=3.90
			turn lthighf to y-axis ((<-1.542007> *animAmplitude)/100) speed ((<35.727059> *animAmplitude)/100) / animSpeed; //delta=1.19
			turn rfootb to x-axis ((<26.328643> *animAmplitude)/100) speed ((<870.719369> *animAmplitude)/100) / animSpeed; //delta=-29.02
			turn rfootf to x-axis ((<-1.005965> *animAmplitude)/100) speed ((<679.624138> *animAmplitude)/100) / animSpeed; //delta=-22.65
			turn rforearml to z-axis ((<-0.716974> *animAmplitude)/100) speed ((<276.514510> *animAmplitude)/100) / animSpeed; //delta=-9.22
			turn rforearmu to z-axis ((<-0.716974> *animAmplitude)/100) speed ((<276.514510> *animAmplitude)/100) / animSpeed; //delta=-9.22
			turn rkneeb to x-axis ((<24.943246> *animAmplitude)/100) speed ((<585.634968> *animAmplitude)/100) / animSpeed; //delta=19.52
			turn rkneef to x-axis ((<12.749133> *animAmplitude)/100) speed ((<94.594987> *animAmplitude)/100) / animSpeed; //delta=3.15
			turn rshinb to x-axis ((<-27.400463> *animAmplitude)/100) speed ((<116.717346> *animAmplitude)/100) / animSpeed; //delta=3.89
			turn rshinf to x-axis ((<-4.388969> *animAmplitude)/100) speed ((<114.433716> *animAmplitude)/100) / animSpeed; //delta=3.81
			turn rthighb to x-axis ((<-30.690277> *animAmplitude)/100) speed ((<272.269696> *animAmplitude)/100) / animSpeed; //delta=9.08
			turn rthighb to z-axis ((<-6.471852> *animAmplitude)/100) speed ((<40.478706> *animAmplitude)/100) / animSpeed; //delta=-1.35
			turn rthighb to y-axis ((<-2.563770> *animAmplitude)/100) speed ((<20.118119> *animAmplitude)/100) / animSpeed; //delta=0.67
			turn rthighf to x-axis ((<-0.443912> *animAmplitude)/100) speed ((<222.021694> *animAmplitude)/100) / animSpeed; //delta=7.40
			turn rthighf to z-axis ((<-1.743176> *animAmplitude)/100) speed ((<34.161242> *animAmplitude)/100) / animSpeed; //delta=1.14
			turn rthighf to y-axis ((<1.067008> *animAmplitude)/100) speed ((<125.852262> *animAmplitude)/100) / animSpeed; //delta=4.20
			turn spike1 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<299.999988> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn spike2 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn spike3 to x-axis ((<-24.886378> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn tail to x-axis ((<9.883820> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn tail to z-axis ((<-5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn tail to y-axis ((<-7.917922> *animAmplitude)/100) speed ((<158.358457> *animAmplitude)/100) / animSpeed; //delta=5.28
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:15
			move body to y-axis (((([2.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to x-axis ((<-1.130624> *animAmplitude)/100) speed ((<9.134980> *animAmplitude)/100) / animSpeed; //delta=0.30
			turn body to z-axis ((<3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn body to y-axis ((<0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn head to x-axis ((<-1.499955> *animAmplitude)/100) speed ((<17.998915> *animAmplitude)/100) / animSpeed; //delta=0.60
			turn head to z-axis ((<-7.024838> *animAmplitude)/100) speed ((<140.496778> *animAmplitude)/100) / animSpeed; //delta=-4.68
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<53.388138> *animAmplitude)/100) / animSpeed; //delta=1.78
			turn lfootb to x-axis ((<-21.772765> *animAmplitude)/100) speed ((<479.831666> *animAmplitude)/100) / animSpeed; //delta=15.99
			turn lfootf to x-axis ((<9.936868> *animAmplitude)/100) speed ((<400.624251> *animAmplitude)/100) / animSpeed; //delta=13.35
			turn lforearml to z-axis ((<3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=-4.61
			turn lforearmu to z-axis ((<-3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=4.61
			turn lkneeb to x-axis ((<-1.549614> *animAmplitude)/100) speed ((<466.336137> *animAmplitude)/100) / animSpeed; //delta=15.54
			turn lkneef to x-axis ((<-13.180543> *animAmplitude)/100) speed ((<747.936885> *animAmplitude)/100) / animSpeed; //delta=-24.93
			turn lshinb to x-axis ((<7.243194> *animAmplitude)/100) speed ((<416.288816> *animAmplitude)/100) / animSpeed; //delta=-13.88
			turn lshinf to x-axis ((<2.611425> *animAmplitude)/100) speed ((<423.041604> *animAmplitude)/100) / animSpeed; //delta=14.10
			turn lthighb to x-axis ((<12.576240> *animAmplitude)/100) speed ((<488.241021> *animAmplitude)/100) / animSpeed; //delta=-16.27
			turn lthighb to z-axis ((<-2.486363> *animAmplitude)/100) speed ((<143.326167> *animAmplitude)/100) / animSpeed; //delta=-4.78
			turn lthighb to y-axis ((<-0.416394> *animAmplitude)/100) speed ((<45.204852> *animAmplitude)/100) / animSpeed; //delta=1.51
			turn lthighf to x-axis ((<-3.976909> *animAmplitude)/100) speed ((<46.310386> *animAmplitude)/100) / animSpeed; //delta=-1.54
			turn lthighf to z-axis ((<-3.058118> *animAmplitude)/100) speed ((<30.379066> *animAmplitude)/100) / animSpeed; //delta=1.01
			turn lthighf to y-axis ((<-0.363777> *animAmplitude)/100) speed ((<35.346905> *animAmplitude)/100) / animSpeed; //delta=1.18
			turn rfootb to x-axis ((<49.491452> *animAmplitude)/100) speed ((<694.884270> *animAmplitude)/100) / animSpeed; //delta=-23.16
			turn rfootf to x-axis ((<10.051183> *animAmplitude)/100) speed ((<331.714434> *animAmplitude)/100) / animSpeed; //delta=-11.06
			turn rforearml to z-axis ((<3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=-4.61
			turn rforearmu to z-axis ((<3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=-4.61
			turn rkneeb to x-axis ((<-5.0> *animAmplitude)/100) speed ((<898.317762> *animAmplitude)/100) / animSpeed; //delta=29.94
			turn rkneef to x-axis ((<3.535602> *animAmplitude)/100) speed ((<276.405916> *animAmplitude)/100) / animSpeed; //delta=9.21
			turn rshinb to x-axis ((<-15.040379> *animAmplitude)/100) speed ((<370.802535> *animAmplitude)/100) / animSpeed; //delta=-12.36
			turn rshinf to x-axis ((<-9.248699> *animAmplitude)/100) speed ((<145.791899> *animAmplitude)/100) / animSpeed; //delta=4.86
			turn rthighb to x-axis ((<-29.162695> *animAmplitude)/100) speed ((<45.827462> *animAmplitude)/100) / animSpeed; //delta=-1.53
			turn rthighb to z-axis ((<-2.950251> *animAmplitude)/100) speed ((<105.648021> *animAmplitude)/100) / animSpeed; //delta=-3.52
			turn rthighb to y-axis ((<-0.861848> *animAmplitude)/100) speed ((<51.057658> *animAmplitude)/100) / animSpeed; //delta=1.70
			turn rthighf to x-axis ((<-11.581576> *animAmplitude)/100) speed ((<334.129934> *animAmplitude)/100) / animSpeed; //delta=11.14
			turn rthighf to z-axis ((<1.712622> *animAmplitude)/100) speed ((<103.673954> *animAmplitude)/100) / animSpeed; //delta=-3.46
			turn rthighf to y-axis ((<5.133441> *animAmplitude)/100) speed ((<121.992979> *animAmplitude)/100) / animSpeed; //delta=4.07
			turn spike1 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn spike2 to x-axis ((<-24.886378> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn spike3 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn tail to x-axis ((<8.883820> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn tail to z-axis ((<-3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<237.537672> *animAmplitude)/100) / animSpeed; //delta=7.92
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:20
			move body to y-axis (((([2.500000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([15.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.50
			turn body to x-axis ((<-1.282874> *animAmplitude)/100) speed ((<4.567492> *animAmplitude)/100) / animSpeed; //delta=0.15
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn body to y-axis ((<-2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animSpeed; //delta=-2.50
			turn head to x-axis ((<-1.799937> *animAmplitude)/100) speed ((<8.999460> *animAmplitude)/100) / animSpeed; //delta=0.30
			turn head to z-axis ((<-0.0> *animAmplitude)/100) speed ((<210.745154> *animAmplitude)/100) / animSpeed; //delta=-7.02
			turn head to y-axis ((<1.483004> *animAmplitude)/100) speed ((<44.490119> *animAmplitude)/100) / animSpeed; //delta=1.48
			turn lfootb to x-axis ((<-10.737367> *animAmplitude)/100) speed ((<331.061924> *animAmplitude)/100) / animSpeed; //delta=-11.04
			turn lfootf to x-axis ((<-7.784004> *animAmplitude)/100) speed ((<531.626160> *animAmplitude)/100) / animSpeed; //delta=17.72
			turn lforearml to z-axis ((<6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=-2.30
			turn lforearmu to z-axis ((<-6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=2.30
			turn lkneeb to x-axis ((<24.897710> *animAmplitude)/100) speed ((<793.419715> *animAmplitude)/100) / animSpeed; //delta=-26.45
			turn lkneef to x-axis ((<4.111823> *animAmplitude)/100) speed ((<518.770980> *animAmplitude)/100) / animSpeed; //delta=-17.29
			turn lshinb to x-axis ((<-7.304043> *animAmplitude)/100) speed ((<436.417097> *animAmplitude)/100) / animSpeed; //delta=14.55
			turn lshinf to x-axis ((<-1.132935> *animAmplitude)/100) speed ((<112.330805> *animAmplitude)/100) / animSpeed; //delta=3.74
			turn lthighb to x-axis ((<-1.188713> *animAmplitude)/100) speed ((<412.948591> *animAmplitude)/100) / animSpeed; //delta=13.76
			turn lthighb to z-axis ((<2.522629> *animAmplitude)/100) speed ((<150.269748> *animAmplitude)/100) / animSpeed; //delta=-5.01
			turn lthighb to y-axis ((<0.735161> *animAmplitude)/100) speed ((<34.546637> *animAmplitude)/100) / animSpeed; //delta=1.15
			turn lthighf to x-axis ((<0.549638> *animAmplitude)/100) speed ((<135.796410> *animAmplitude)/100) / animSpeed; //delta=-4.53
			turn lthighf to z-axis ((<-1.587670> *animAmplitude)/100) speed ((<44.113435> *animAmplitude)/100) / animSpeed; //delta=-1.47
			turn lthighf to y-axis ((<1.160503> *animAmplitude)/100) speed ((<45.728399> *animAmplitude)/100) / animSpeed; //delta=1.52
			turn rfootb to x-axis ((<34.070292> *animAmplitude)/100) speed ((<462.634804> *animAmplitude)/100) / animSpeed; //delta=15.42
			turn rfootf to x-axis ((<16.518669> *animAmplitude)/100) speed ((<194.024595> *animAmplitude)/100) / animSpeed; //delta=-6.47
			turn rforearml to z-axis ((<6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=-2.30
			turn rforearmu to z-axis ((<6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=-2.30
			turn rkneeb to x-axis ((<7.592834> *animAmplitude)/100) speed ((<377.805378> *animAmplitude)/100) / animSpeed; //delta=-12.59
			turn rkneef to x-axis ((<-40.0> *animAmplitude)/100) speed ((<1306.085044> *animAmplitude)/100) / animSpeed; //delta=43.54
			turn rshinb to x-axis ((<-17.098766> *animAmplitude)/100) speed ((<61.751604> *animAmplitude)/100) / animSpeed; //delta=2.06
			turn rshinf to x-axis ((<17.243009> *animAmplitude)/100) speed ((<794.751250> *animAmplitude)/100) / animSpeed; //delta=-26.49
			turn rthighb to x-axis ((<-23.582934> *animAmplitude)/100) speed ((<167.392825> *animAmplitude)/100) / animSpeed; //delta=-5.58
			turn rthighb to z-axis ((<1.028992> *animAmplitude)/100) speed ((<119.377304> *animAmplitude)/100) / animSpeed; //delta=-3.98
			turn rthighb to y-axis ((<0.639935> *animAmplitude)/100) speed ((<45.053483> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn rthighf to x-axis ((<-5.541916> *animAmplitude)/100) speed ((<181.189803> *animAmplitude)/100) / animSpeed; //delta=-6.04
			turn rthighf to z-axis ((<-0.314004> *animAmplitude)/100) speed ((<60.798800> *animAmplitude)/100) / animSpeed; //delta=2.03
			turn rthighf to y-axis ((<2.953951> *animAmplitude)/100) speed ((<65.384709> *animAmplitude)/100) / animSpeed; //delta=-2.18
			turn spike1 to x-axis ((<-24.886378> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn spike2 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn spike3 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn tail to x-axis ((<8.383820> *animAmplitude)/100) speed ((<14.999992> *animAmplitude)/100) / animSpeed; //delta=0.50
			turn tail to z-axis ((<0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn tail to y-axis ((<6.598269> *animAmplitude)/100) speed ((<197.948064> *animAmplitude)/100) / animSpeed; //delta=6.60
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:25
			move body to y-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([105.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-3.50
			turn body to x-axis ((<-0.217126> *animAmplitude)/100) speed ((<31.972433> *animAmplitude)/100) / animSpeed; //delta=-1.07
			turn body to z-axis ((<-3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn body to y-axis ((<-5.0> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animSpeed; //delta=-2.50
			turn head to x-axis ((<0.299937> *animAmplitude)/100) speed ((<62.996201> *animAmplitude)/100) / animSpeed; //delta=-2.10
			turn head to z-axis ((<7.024838> *animAmplitude)/100) speed ((<210.745154> *animAmplitude)/100) / animSpeed; //delta=-7.02
			turn head to y-axis ((<2.966008> *animAmplitude)/100) speed ((<44.490119> *animAmplitude)/100) / animSpeed; //delta=1.48
			turn lfootb to x-axis ((<-4.296183> *animAmplitude)/100) speed ((<193.235516> *animAmplitude)/100) / animSpeed; //delta=-6.44
			turn lfootf to x-axis ((<-26.713918> *animAmplitude)/100) speed ((<567.897436> *animAmplitude)/100) / animSpeed; //delta=18.93
			turn lforearml to z-axis ((<-9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=16.13
			turn lforearmu to z-axis ((<9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=-16.13
			turn lkneeb to x-axis ((<44.973445> *animAmplitude)/100) speed ((<602.272079> *animAmplitude)/100) / animSpeed; //delta=-20.08
			turn lkneef to x-axis ((<21.028453> *animAmplitude)/100) speed ((<507.498914> *animAmplitude)/100) / animSpeed; //delta=-16.92
			turn lshinb to x-axis ((<-24.209669> *animAmplitude)/100) speed ((<507.168773> *animAmplitude)/100) / animSpeed; //delta=16.91
			turn lshinf to x-axis ((<-3.482568> *animAmplitude)/100) speed ((<70.488983> *animAmplitude)/100) / animSpeed; //delta=2.35
			turn lthighb to x-axis ((<-20.320151> *animAmplitude)/100) speed ((<573.943146> *animAmplitude)/100) / animSpeed; //delta=19.13
			turn lthighb to z-axis ((<7.611343> *animAmplitude)/100) speed ((<152.661445> *animAmplitude)/100) / animSpeed; //delta=-5.09
			turn lthighb to y-axis ((<3.586527> *animAmplitude)/100) speed ((<85.540989> *animAmplitude)/100) / animSpeed; //delta=2.85
			turn lthighf to x-axis ((<5.242189> *animAmplitude)/100) speed ((<140.776524> *animAmplitude)/100) / animSpeed; //delta=-4.69
			turn lthighf to z-axis ((<0.319810> *animAmplitude)/100) speed ((<57.224412> *animAmplitude)/100) / animSpeed; //delta=-1.91
			turn lthighf to y-axis ((<2.678978> *animAmplitude)/100) speed ((<45.554258> *animAmplitude)/100) / animSpeed; //delta=1.52
			turn rfootb to x-axis ((<13.621265> *animAmplitude)/100) speed ((<613.470789> *animAmplitude)/100) / animSpeed; //delta=20.45
			turn rfootf to x-axis ((<25.331720> *animAmplitude)/100) speed ((<264.391534> *animAmplitude)/100) / animSpeed; //delta=-8.81
			turn rforearml to z-axis ((<-9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=16.13
			turn rforearmu to z-axis ((<-9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=16.13
			turn rkneeb to x-axis ((<19.641566> *animAmplitude)/100) speed ((<361.461986> *animAmplitude)/100) / animSpeed; //delta=-12.05
			turn rkneef to x-axis ((<-74.425382> *animAmplitude)/100) speed ((<1032.744478> *animAmplitude)/100) / animSpeed; //delta=34.42
			turn rkneef to z-axis ((<0.145427> *animAmplitude)/100) speed ((<3.926675> *animAmplitude)/100) / animSpeed; //delta=-0.13
			turn rkneef to y-axis ((<0.161928> *animAmplitude)/100) speed ((<4.205825> *animAmplitude)/100) / animSpeed; //delta=0.14
			turn rshinb to x-axis ((<-17.246134> *animAmplitude)/100) speed ((<4.421045> *animAmplitude)/100) / animSpeed; //delta=0.15
			turn rshinf to x-axis ((<48.020540> *animAmplitude)/100) speed ((<923.325924> *animAmplitude)/100) / animSpeed; //delta=-30.78
			turn rthighb to x-axis ((<-18.174625> *animAmplitude)/100) speed ((<162.249283> *animAmplitude)/100) / animSpeed; //delta=-5.41
			turn rthighb to z-axis ((<6.481470> *animAmplitude)/100) speed ((<163.574343> *animAmplitude)/100) / animSpeed; //delta=-5.45
			turn rthighb to y-axis ((<2.558757> *animAmplitude)/100) speed ((<57.564657> *animAmplitude)/100) / animSpeed; //delta=1.92
			turn rthighf to x-axis ((<-1.347181> *animAmplitude)/100) speed ((<125.842036> *animAmplitude)/100) / animSpeed; //delta=-4.19
			turn rthighf to z-axis ((<-2.002576> *animAmplitude)/100) speed ((<50.657141> *animAmplitude)/100) / animSpeed; //delta=1.69
			turn rthighf to y-axis ((<2.598832> *animAmplitude)/100) speed ((<10.653552> *animAmplitude)/100) / animSpeed; //delta=-0.36
			turn spike1 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn spike2 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn spike3 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<299.999988> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn tail to x-axis ((<11.883820> *animAmplitude)/100) speed ((<104.999994> *animAmplitude)/100) / animSpeed; //delta=-3.50
			turn tail to z-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn tail to y-axis ((<13.196538> *animAmplitude)/100) speed ((<197.948064> *animAmplitude)/100) / animSpeed; //delta=6.60
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:30
			move body to y-axis (((([1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([60.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=2.00
			turn body to x-axis ((<-0.826125> *animAmplitude)/100) speed ((<18.269961> *animAmplitude)/100) / animSpeed; //delta=0.61
			turn body to z-axis ((<-5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn body to y-axis ((<-3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn head to x-axis ((<-0.899991> *animAmplitude)/100) speed ((<35.997826> *animAmplitude)/100) / animSpeed; //delta=1.20
			turn head to z-axis ((<11.708064> *animAmplitude)/100) speed ((<140.496778> *animAmplitude)/100) / animSpeed; //delta=-4.68
			turn head to y-axis ((<1.779605> *animAmplitude)/100) speed ((<35.592100> *animAmplitude)/100) / animSpeed; //delta=-1.19
			turn lfootb to x-axis ((<26.061792> *animAmplitude)/100) speed ((<910.739272> *animAmplitude)/100) / animSpeed; //delta=-30.36
			turn lfootf to x-axis ((<-0.998677> *animAmplitude)/100) speed ((<771.457230> *animAmplitude)/100) / animSpeed; //delta=-25.72
			turn lforearml to z-axis ((<-0.716974> *animAmplitude)/100) speed ((<276.514586> *animAmplitude)/100) / animSpeed; //delta=-9.22
			turn lforearmu to z-axis ((<0.716974> *animAmplitude)/100) speed ((<276.514586> *animAmplitude)/100) / animSpeed; //delta=9.22
			turn lkneeb to x-axis ((<25.727139> *animAmplitude)/100) speed ((<577.389205> *animAmplitude)/100) / animSpeed; //delta=19.25
			turn lkneef to x-axis ((<12.723356> *animAmplitude)/100) speed ((<249.152930> *animAmplitude)/100) / animSpeed; //delta=8.31
			turn lshinb to x-axis ((<-28.559377> *animAmplitude)/100) speed ((<130.491259> *animAmplitude)/100) / animSpeed; //delta=4.35
			turn lshinf to x-axis ((<-4.667595> *animAmplitude)/100) speed ((<35.550808> *animAmplitude)/100) / animSpeed; //delta=1.19
			turn lthighb to x-axis ((<-30.103229> *animAmplitude)/100) speed ((<293.492341> *animAmplitude)/100) / animSpeed; //delta=9.78
			turn lthighb to z-axis ((<6.630345> *animAmplitude)/100) speed ((<29.429949> *animAmplitude)/100) / animSpeed; //delta=0.98
			turn lthighb to y-axis ((<3.234614> *animAmplitude)/100) speed ((<10.557387> *animAmplitude)/100) / animSpeed; //delta=-0.35
			turn lthighf to x-axis ((<-0.180092> *animAmplitude)/100) speed ((<162.668424> *animAmplitude)/100) / animSpeed; //delta=5.42
			turn lthighf to z-axis ((<1.721869> *animAmplitude)/100) speed ((<42.061772> *animAmplitude)/100) / animSpeed; //delta=-1.40
			turn lthighf to y-axis ((<-0.967146> *animAmplitude)/100) speed ((<109.383730> *animAmplitude)/100) / animSpeed; //delta=-3.65
			turn rfootb to x-axis ((<-5.884674> *animAmplitude)/100) speed ((<585.178182> *animAmplitude)/100) / animSpeed; //delta=19.51
			turn rfootf to x-axis ((<23.992298> *animAmplitude)/100) speed ((<40.182669> *animAmplitude)/100) / animSpeed; //delta=1.34
			turn rforearml to z-axis ((<-0.716974> *animAmplitude)/100) speed ((<276.514586> *animAmplitude)/100) / animSpeed; //delta=-9.22
			turn rforearmu to z-axis ((<-0.716974> *animAmplitude)/100) speed ((<276.514586> *animAmplitude)/100) / animSpeed; //delta=-9.22
			turn rkneeb to x-axis ((<14.581820> *animAmplitude)/100) speed ((<151.792382> *animAmplitude)/100) / animSpeed; //delta=5.06
			turn rkneef to x-axis ((<-40.336461> *animAmplitude)/100) speed ((<1022.667627> *animAmplitude)/100) / animSpeed; //delta=-34.09
			turn rkneef to z-axis ((<0.018432> *animAmplitude)/100) speed ((<3.809849> *animAmplitude)/100) / animSpeed; //delta=0.13
			turn rkneef to y-axis ((<0.024405> *animAmplitude)/100) speed ((<4.125676> *animAmplitude)/100) / animSpeed; //delta=-0.14
			turn rshinb to x-axis ((<-6.600571> *animAmplitude)/100) speed ((<319.366882> *animAmplitude)/100) / animSpeed; //delta=-10.65
			turn rshinf to x-axis ((<17.750649> *animAmplitude)/100) speed ((<908.096719> *animAmplitude)/100) / animSpeed; //delta=30.27
			turn rthighb to x-axis ((<-4.217072> *animAmplitude)/100) speed ((<418.726566> *animAmplitude)/100) / animSpeed; //delta=-13.96
			turn rthighb to z-axis ((<7.357347> *animAmplitude)/100) speed ((<26.276310> *animAmplitude)/100) / animSpeed; //delta=-0.88
			turn rthighb to y-axis ((<1.940276> *animAmplitude)/100) speed ((<18.554427> *animAmplitude)/100) / animSpeed; //delta=-0.62
			turn rthighf to x-axis ((<-3.929098> *animAmplitude)/100) speed ((<77.457492> *animAmplitude)/100) / animSpeed; //delta=2.58
			turn rthighf to z-axis ((<1.589499> *animAmplitude)/100) speed ((<107.762225> *animAmplitude)/100) / animSpeed; //delta=-3.59
			turn rthighf to y-axis ((<0.924679> *animAmplitude)/100) speed ((<50.224597> *animAmplitude)/100) / animSpeed; //delta=-1.67
			turn spike1 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn spike2 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<299.999988> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn spike3 to x-axis ((<5.113623> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn tail to x-axis ((<9.883820> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn tail to z-axis ((<5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn tail to y-axis ((<7.917922> *animAmplitude)/100) speed ((<158.358457> *animAmplitude)/100) / animSpeed; //delta=-5.28
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:35
			move body to y-axis (((([2.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to x-axis ((<-1.130624> *animAmplitude)/100) speed ((<9.134980> *animAmplitude)/100) / animSpeed; //delta=0.30
			turn body to z-axis ((<-3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn body to y-axis ((<0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn head to x-axis ((<-1.499955> *animAmplitude)/100) speed ((<17.998915> *animAmplitude)/100) / animSpeed; //delta=0.60
			turn head to z-axis ((<7.024838> *animAmplitude)/100) speed ((<140.496778> *animAmplitude)/100) / animSpeed; //delta=4.68
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<53.388138> *animAmplitude)/100) / animSpeed; //delta=-1.78
			turn lfootb to x-axis ((<49.334637> *animAmplitude)/100) speed ((<698.185352> *animAmplitude)/100) / animSpeed; //delta=-23.27
			turn lfootf to x-axis ((<10.261771> *animAmplitude)/100) speed ((<337.813448> *animAmplitude)/100) / animSpeed; //delta=-11.26
			turn lforearml to z-axis ((<3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=-4.61
			turn lforearmu to z-axis ((<-3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=4.61
			turn lkneeb to x-axis ((<-4.300301> *animAmplitude)/100) speed ((<900.823182> *animAmplitude)/100) / animSpeed; //delta=30.03
			turn lkneef to x-axis ((<2.720801> *animAmplitude)/100) speed ((<300.076652> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn lshinb to x-axis ((<-15.747536> *animAmplitude)/100) speed ((<384.355252> *animAmplitude)/100) / animSpeed; //delta=-12.81
			turn lshinf to x-axis ((<-8.945357> *animAmplitude)/100) speed ((<128.332873> *animAmplitude)/100) / animSpeed; //delta=4.28
			turn lthighb to x-axis ((<-29.548481> *animAmplitude)/100) speed ((<16.642439> *animAmplitude)/100) / animSpeed; //delta=-0.55
			turn lthighb to z-axis ((<3.247463> *animAmplitude)/100) speed ((<101.486458> *animAmplitude)/100) / animSpeed; //delta=3.38
			turn lthighb to y-axis ((<1.514638> *animAmplitude)/100) speed ((<51.599293> *animAmplitude)/100) / animSpeed; //delta=-1.72
			turn lthighf to x-axis ((<-11.009863> *animAmplitude)/100) speed ((<324.893116> *animAmplitude)/100) / animSpeed; //delta=10.83
			turn lthighf to z-axis ((<-1.743071> *animAmplitude)/100) speed ((<103.948217> *animAmplitude)/100) / animSpeed; //delta=3.46
			turn lthighf to y-axis ((<-5.055849> *animAmplitude)/100) speed ((<122.661067> *animAmplitude)/100) / animSpeed; //delta=-4.09
			turn rfootb to x-axis ((<-21.838287> *animAmplitude)/100) speed ((<478.608379> *animAmplitude)/100) / animSpeed; //delta=15.95
			turn rfootf to x-axis ((<11.420309> *animAmplitude)/100) speed ((<377.159656> *animAmplitude)/100) / animSpeed; //delta=12.57
			turn rforearml to z-axis ((<3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=-4.61
			turn rforearmu to z-axis ((<3.891601> *animAmplitude)/100) speed ((<138.257236> *animAmplitude)/100) / animSpeed; //delta=-4.61
			turn rkneeb to x-axis ((<-1.108178> *animAmplitude)/100) speed ((<470.699942> *animAmplitude)/100) / animSpeed; //delta=15.69
			turn rkneef to x-axis ((<-18.692418> *animAmplitude)/100) speed ((<649.321291> *animAmplitude)/100) / animSpeed; //delta=-21.64
			turn rshinb to x-axis ((<6.892115> *animAmplitude)/100) speed ((<404.780583> *animAmplitude)/100) / animSpeed; //delta=-13.49
			turn rshinf to x-axis ((<6.310787> *animAmplitude)/100) speed ((<343.195849> *animAmplitude)/100) / animSpeed; //delta=11.44
			turn rthighb to x-axis ((<12.473834> *animAmplitude)/100) speed ((<500.727179> *animAmplitude)/100) / animSpeed; //delta=-16.69
			turn rthighb to z-axis ((<2.625499> *animAmplitude)/100) speed ((<141.955444> *animAmplitude)/100) / animSpeed; //delta=4.73
			turn rthighb to y-axis ((<0.150444> *animAmplitude)/100) speed ((<53.694957> *animAmplitude)/100) / animSpeed; //delta=-1.79
			turn rthighf to x-axis ((<-1.131574> *animAmplitude)/100) speed ((<83.925705> *animAmplitude)/100) / animSpeed; //delta=-2.80
			turn rthighf to z-axis ((<2.348060> *animAmplitude)/100) speed ((<22.756850> *animAmplitude)/100) / animSpeed; //delta=-0.76
			turn rthighf to y-axis ((<-0.733658> *animAmplitude)/100) speed ((<49.750104> *animAmplitude)/100) / animSpeed; //delta=-1.66
			turn spike1 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<299.999988> *animAmplitude)/100) / animSpeed; //delta=-10.00
			turn spike2 to x-axis ((<5.113623> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn spike3 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn tail to x-axis ((<8.883820> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn tail to z-axis ((<3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<237.537672> *animAmplitude)/100) / animSpeed; //delta=-7.92
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:40
			move body to y-axis (((([2.500000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([15.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.50
			turn body to x-axis ((<-1.282874> *animAmplitude)/100) speed ((<4.567492> *animAmplitude)/100) / animSpeed; //delta=0.15
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn body to y-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn head to x-axis ((<-1.799937> *animAmplitude)/100) speed ((<8.999460> *animAmplitude)/100) / animSpeed; //delta=0.30
			turn head to z-axis ((<-0.0> *animAmplitude)/100) speed ((<210.745154> *animAmplitude)/100) / animSpeed; //delta=7.02
			turn head to y-axis ((<-1.779605> *animAmplitude)/100) speed ((<53.388138> *animAmplitude)/100) / animSpeed; //delta=-1.78
			turn lfootb to x-axis ((<33.908997> *animAmplitude)/100) speed ((<462.769222> *animAmplitude)/100) / animSpeed; //delta=15.43
			turn lfootf to x-axis ((<16.820032> *animAmplitude)/100) speed ((<196.747842> *animAmplitude)/100) / animSpeed; //delta=-6.56
			turn lforearml to z-axis ((<6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=-2.30
			turn lforearmu to z-axis ((<-6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=2.30
			turn lkneeb to x-axis ((<8.011434> *animAmplitude)/100) speed ((<369.352033> *animAmplitude)/100) / animSpeed; //delta=-12.31
			turn lkneef to x-axis ((<-41.006496> *animAmplitude)/100) speed ((<1311.818887> *animAmplitude)/100) / animSpeed; //delta=43.73
			turn lshinb to x-axis ((<-17.910271> *animAmplitude)/100) speed ((<64.882050> *animAmplitude)/100) / animSpeed; //delta=2.16
			turn lshinf to x-axis ((<19.301609> *animAmplitude)/100) speed ((<847.408986> *animAmplitude)/100) / animSpeed; //delta=-28.25
			turn lthighb to x-axis ((<-23.679363> *animAmplitude)/100) speed ((<176.073551> *animAmplitude)/100) / animSpeed; //delta=-5.87
			turn lthighb to z-axis ((<-1.037971> *animAmplitude)/100) speed ((<128.563030> *animAmplitude)/100) / animSpeed; //delta=4.29
			turn lthighb to y-axis ((<-0.256832> *animAmplitude)/100) speed ((<53.144090> *animAmplitude)/100) / animSpeed; //delta=-1.77
			turn lthighf to x-axis ((<-5.795135> *animAmplitude)/100) speed ((<156.441833> *animAmplitude)/100) / animSpeed; //delta=-5.21
			turn lthighf to z-axis ((<0.550220> *animAmplitude)/100) speed ((<68.798744> *animAmplitude)/100) / animSpeed; //delta=-2.29
			turn lthighf to y-axis ((<-3.364737> *animAmplitude)/100) speed ((<50.733358> *animAmplitude)/100) / animSpeed; //delta=1.69
			turn rfootb to x-axis ((<-10.677420> *animAmplitude)/100) speed ((<334.826016> *animAmplitude)/100) / animSpeed; //delta=-11.16
			turn rfootf to x-axis ((<-5.146719> *animAmplitude)/100) speed ((<497.010843> *animAmplitude)/100) / animSpeed; //delta=16.57
			turn rforearml to z-axis ((<6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=-2.30
			turn rforearmu to z-axis ((<6.195891> *animAmplitude)/100) speed ((<69.128720> *animAmplitude)/100) / animSpeed; //delta=-2.30
			turn rkneeb to x-axis ((<24.873831> *animAmplitude)/100) speed ((<779.460266> *animAmplitude)/100) / animSpeed; //delta=-25.98
			turn rkneef to x-axis ((<-5.322721> *animAmplitude)/100) speed ((<401.090898> *animAmplitude)/100) / animSpeed; //delta=-13.37
			turn rshinb to x-axis ((<-6.865205> *animAmplitude)/100) speed ((<412.719615> *animAmplitude)/100) / animSpeed; //delta=13.76
			turn rshinf to x-axis ((<5.144163> *animAmplitude)/100) speed ((<34.998722> *animAmplitude)/100) / animSpeed; //delta=1.17
			turn rthighb to x-axis ((<-1.676220> *animAmplitude)/100) speed ((<424.501611> *animAmplitude)/100) / animSpeed; //delta=14.15
			turn rthighb to z-axis ((<-3.122829> *animAmplitude)/100) speed ((<172.449839> *animAmplitude)/100) / animSpeed; //delta=5.75
			turn rthighb to y-axis ((<-0.850181> *animAmplitude)/100) speed ((<30.018743> *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn rthighf to x-axis ((<4.778910> *animAmplitude)/100) speed ((<177.314521> *animAmplitude)/100) / animSpeed; //delta=-5.91
			turn rthighf to z-axis ((<1.085829> *animAmplitude)/100) speed ((<37.866931> *animAmplitude)/100) / animSpeed; //delta=1.26
			turn rthighf to y-axis ((<-2.893603> *animAmplitude)/100) speed ((<64.798348> *animAmplitude)/100) / animSpeed; //delta=-2.16
			turn spike1 to x-axis ((<5.113623> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=-5.00
			turn spike2 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn spike3 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<299.999988> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn tail to x-axis ((<8.383820> *animAmplitude)/100) speed ((<14.999992> *animAmplitude)/100) / animSpeed; //delta=0.50
			turn tail to z-axis ((<0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn tail to y-axis ((<-7.917922> *animAmplitude)/100) speed ((<237.537672> *animAmplitude)/100) / animSpeed; //delta=-7.92
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:45
			move body to y-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([105.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-3.50
			turn body to x-axis ((<-0.217126> *animAmplitude)/100) speed ((<31.972433> *animAmplitude)/100) / animSpeed; //delta=-1.07
			turn body to z-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn body to y-axis ((<5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animSpeed; //delta=2.00
			turn head to x-axis ((<0.299937> *animAmplitude)/100) speed ((<62.996201> *animAmplitude)/100) / animSpeed; //delta=-2.10
			turn head to z-axis ((<-7.024838> *animAmplitude)/100) speed ((<210.745154> *animAmplitude)/100) / animSpeed; //delta=7.02
			turn head to y-axis ((<-2.966008> *animAmplitude)/100) speed ((<35.592100> *animAmplitude)/100) / animSpeed; //delta=-1.19
			turn lfootb to x-axis ((<13.399227> *animAmplitude)/100) speed ((<615.293092> *animAmplitude)/100) / animSpeed; //delta=20.51
			turn lfootf to x-axis ((<25.395265> *animAmplitude)/100) speed ((<257.256975> *animAmplitude)/100) / animSpeed; //delta=-8.58
			turn lforearml to z-axis ((<-9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=16.13
			turn lforearmu to z-axis ((<9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=-16.13
			turn lkneeb to x-axis ((<20.332440> *animAmplitude)/100) speed ((<369.630193> *animAmplitude)/100) / animSpeed; //delta=-12.32
			turn lkneef to x-axis ((<-75.108223> *animAmplitude)/100) speed ((<1023.051825> *animAmplitude)/100) / animSpeed; //delta=34.10
			turn lkneef to z-axis ((<-0.168001> *animAmplitude)/100) speed ((<4.552209> *animAmplitude)/100) / animSpeed; //delta=0.15
			turn lkneef to y-axis ((<-0.184136> *animAmplitude)/100) speed ((<4.810455> *animAmplitude)/100) / animSpeed; //delta=-0.16
			turn lshinb to x-axis ((<-18.116402> *animAmplitude)/100) speed ((<6.183951> *animAmplitude)/100) / animSpeed; //delta=0.21
			turn lshinf to x-axis ((<50.562664> *animAmplitude)/100) speed ((<937.831657> *animAmplitude)/100) / animSpeed; //delta=-31.26
			turn lthighb to x-axis ((<-17.799026> *animAmplitude)/100) speed ((<176.410109> *animAmplitude)/100) / animSpeed; //delta=-5.88
			turn lthighb to z-axis ((<-6.362855> *animAmplitude)/100) speed ((<159.746523> *animAmplitude)/100) / animSpeed; //delta=5.32
			turn lthighb to y-axis ((<-2.257294> *animAmplitude)/100) speed ((<60.013862> *animAmplitude)/100) / animSpeed; //delta=-2.00
			turn lthighf to x-axis ((<-1.724738> *animAmplitude)/100) speed ((<122.111920> *animAmplitude)/100) / animSpeed; //delta=-4.07
			turn lthighf to z-axis ((<1.855257> *animAmplitude)/100) speed ((<39.151095> *animAmplitude)/100) / animSpeed; //delta=-1.31
			turn lthighf to y-axis ((<-2.732910> *animAmplitude)/100) speed ((<18.954806> *animAmplitude)/100) / animSpeed; //delta=0.63
			turn rfootb to x-axis ((<-4.064508> *animAmplitude)/100) speed ((<198.387357> *animAmplitude)/100) / animSpeed; //delta=-6.61
			turn rfootf to x-axis ((<-23.100034> *animAmplitude)/100) speed ((<538.599472> *animAmplitude)/100) / animSpeed; //delta=17.95
			turn rforearml to z-axis ((<-9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=16.13
			turn rforearmu to z-axis ((<-9.934127> *animAmplitude)/100) speed ((<483.900542> *animAmplitude)/100) / animSpeed; //delta=16.13
			turn rkneeb to x-axis ((<44.222951> *animAmplitude)/100) speed ((<580.473599> *animAmplitude)/100) / animSpeed; //delta=-19.35
			turn rkneef to x-axis ((<7.324603> *animAmplitude)/100) speed ((<379.419715> *animAmplitude)/100) / animSpeed; //delta=-12.65
			turn rshinb to x-axis ((<-23.417343> *animAmplitude)/100) speed ((<496.564123> *animAmplitude)/100) / animSpeed; //delta=16.55
			turn rshinf to x-axis ((<4.033745> *animAmplitude)/100) speed ((<33.312566> *animAmplitude)/100) / animSpeed; //delta=1.11
			turn rthighb to x-axis ((<-21.581864> *animAmplitude)/100) speed ((<597.169329> *animAmplitude)/100) / animSpeed; //delta=19.91
			turn rthighb to z-axis ((<-7.819440> *animAmplitude)/100) speed ((<140.898329> *animAmplitude)/100) / animSpeed; //delta=4.70
			turn rthighb to y-axis ((<-3.229447> *animAmplitude)/100) speed ((<71.377978> *animAmplitude)/100) / animSpeed; //delta=-2.38
			turn rthighf to x-axis ((<10.115962> *animAmplitude)/100) speed ((<160.111566> *animAmplitude)/100) / animSpeed; //delta=-5.34
			turn rthighf to z-axis ((<-1.041284> *animAmplitude)/100) speed ((<63.813397> *animAmplitude)/100) / animSpeed; //delta=2.13
			turn rthighf to y-axis ((<-4.203856> *animAmplitude)/100) speed ((<39.307581> *animAmplitude)/100) / animSpeed; //delta=-1.31
			turn spike1 to x-axis ((<0.113623> *animAmplitude)/100) speed ((<150.0> *animAmplitude)/100) / animSpeed; //delta=5.00
			turn spike2 to x-axis ((<-9.886377> *animAmplitude)/100) speed ((<299.999988> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn spike3 to x-axis ((<-19.886378> *animAmplitude)/100) speed ((<300.0> *animAmplitude)/100) / animSpeed; //delta=10.00
			turn tail to x-axis ((<11.883820> *animAmplitude)/100) speed ((<104.999994> *animAmplitude)/100) / animSpeed; //delta=-3.50
			turn tail to z-axis ((<-3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn tail to y-axis ((<-13.196538> *animAmplitude)/100) speed ((<158.358457> *animAmplitude)/100) / animSpeed; //delta=-5.28
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
	animSpeed = 2*MOVESPEED; // tune restore speed here, higher values are slower restore speeds
	move body to y-axis ([0.0]*MOVESCALE)/100 speed (([210.0]*MOVESCALE)/100) / animSpeed;
	turn body to x-axis <-0.521625> speed <63.944865> / animSpeed;
	turn body to y-axis <0.0> speed <299.999991> / animSpeed;
	turn body to z-axis <0.0> speed <180.0> / animSpeed;
	turn head to x-axis <-0.300027> speed <125.992402> / animSpeed;
	turn head to y-axis <0.0> speed <177.960476> / animSpeed;
	turn head to z-axis <0.0> speed <421.490308> / animSpeed;
	turn lfootb to x-axis <-0.141360> speed <1821.478545> / animSpeed;
	turn lfootf to x-axis <0.114233> speed <1542.914460> / animSpeed;
	turn lforearml to z-axis <0.0> speed <967.801085> / animSpeed;
	turn lforearmu to z-axis <0.0> speed <967.801085> / animSpeed;
	turn lkneeb to x-axis <0.743338> speed <1801.646365> / animSpeed;
	turn lkneef to x-axis <-0.232789> speed <4492.526023> / animSpeed;
	turn lkneef to y-axis <0.0> speed <11.042811> / animSpeed;
	turn lkneef to z-axis <0.0> speed <10.076409> / animSpeed;
	turn lshinb to x-axis <-0.112444> speed <1080.237697> / animSpeed;
	turn lshinf to x-axis <0.397918> speed <3009.884811> / animSpeed;
	turn lthighb to x-axis <0.201172> speed <1147.886292> / animSpeed;
	turn lthighb to y-axis <0.0> speed <171.081979> / animSpeed;
	turn lthighb to z-axis <0.0> speed <381.786804> / animSpeed;
	turn lthighf to x-axis <0.428257> speed <649.786233> / animSpeed;
	turn lthighf to y-axis <0.167130> speed <245.322135> / animSpeed;
	turn lthighf to z-axis <0.0> speed <234.044325> / animSpeed;
	turn rfootb to x-axis <-0.147643> speed <1741.438738> / animSpeed;
	turn rfootf to x-axis <0.116737> speed <1426.610402> / animSpeed;
	turn rforearml to z-axis <0.0> speed <967.801085> / animSpeed;
	turn rforearmu to z-axis <0.0> speed <967.801085> / animSpeed;
	turn rkneeb to x-axis <0.777004> speed <2621.244464> / animSpeed;
	turn rkneef to x-axis <-0.242736> speed <2612.170088> / animSpeed;
	turn rkneef to y-axis <0.0> speed <8.411650> / animSpeed;
	turn rkneef to z-axis <0.0> speed <7.853350> / animSpeed;
	turn rshinb to x-axis <-0.117449> speed <1403.546174> / animSpeed;
	turn rshinf to x-axis <0.390952> speed <1846.651847> / animSpeed;
	turn rthighb to x-axis <0.175244> speed <1307.391836> / animSpeed;
	turn rthighb to y-axis <0.0> speed <193.950181> / animSpeed;
	turn rthighb to z-axis <0.0> speed <469.296105> / animSpeed;
	turn rthighf to x-axis <0.442855> speed <668.259868> / animSpeed;
	turn rthighf to y-axis <-0.166948> speed <251.704524> / animSpeed;
	turn rthighf to z-axis <0.0> speed <215.524451> / animSpeed;
	turn spike1 to x-axis <0.0> speed <600.0> / animSpeed;
	turn spike2 to x-axis <0.0> speed <600.0> / animSpeed;
	turn spike3 to x-axis <-9.886377> speed <600.0> / animSpeed;
	turn tail to x-axis <10.883819> speed <209.999989> / animSpeed;
	turn tail to y-axis <0.0> speed <791.792258> / animSpeed;
	turn tail to z-axis <0.0> speed <180.0> / animSpeed;
}
