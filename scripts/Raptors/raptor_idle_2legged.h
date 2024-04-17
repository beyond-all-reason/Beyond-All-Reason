// For N:\animations\Raptors\raptor_2legged_Idle_v1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3))

//static-var IDLEAMPLITUDE, IDLESPEED;

Idle() {// For N:\animations\Raptors\raptor_2legged_Idle_v1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3)) 
	set-signal-mask SIGNAL_MOVE;
	sleep 500;
	if (!isMoving) { //Frame:10
			move body to x-axis (((([-1.425531] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([42.765920] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<-2.451753> *IDLEAMPLITUDE)/100) speed ((<73.552602> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-1.408065> *IDLEAMPLITUDE)/100) speed ((<223.445268> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-2.643995> *IDLEAMPLITUDE)/100) speed ((<79.319858> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<1.901339> *IDLEAMPLITUDE)/100) speed ((<57.040169> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<1.041694> *IDLEAMPLITUDE)/100) speed ((<57.629673> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.906096> *IDLEAMPLITUDE)/100) speed ((<27.182883> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<0.857514> *IDLEAMPLITUDE)/100) speed ((<25.725426> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<2.671514> *IDLEAMPLITUDE)/100) speed ((<318.899236> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-1.404595> *IDLEAMPLITUDE)/100) speed ((<42.137837> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<-0.192709> *IDLEAMPLITUDE)/100) speed ((<5.781270> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<-1.214630> *IDLEAMPLITUDE)/100) speed ((<158.558979> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<5.301297> *IDLEAMPLITUDE)/100) speed ((<159.038897> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<0.101104> *IDLEAMPLITUDE)/100) speed ((<3.033121> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-4.870579> *IDLEAMPLITUDE)/100) speed ((<195.233621> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-2.555600> *IDLEAMPLITUDE)/100) speed ((<76.668007> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<2.438007> *IDLEAMPLITUDE)/100) speed ((<73.140203> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<1.934274> *IDLEAMPLITUDE)/100) speed ((<7.748069> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.875785> *IDLEAMPLITUDE)/100) speed ((<26.273561> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.689679> *IDLEAMPLITUDE)/100) speed ((<20.690384> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<14.360329> *IDLEAMPLITUDE)/100) speed ((<429.875962> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-1.382209> *IDLEAMPLITUDE)/100) speed ((<41.466262> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<-9.355771> *IDLEAMPLITUDE)/100) speed ((<247.452200> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<5.267374> *IDLEAMPLITUDE)/100) speed ((<158.021220> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.393361> *IDLEAMPLITUDE)/100) speed ((<11.800832> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
	}
	while(!isMoving) {
		if (!isMoving) { //Frame:20
			move body to x-axis (((([-0.568341] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([25.715677] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([-0.677028] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([18.344586] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.195946] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([5.878395] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<0.730108> *IDLEAMPLITUDE)/100) speed ((<21.903235> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<-0.395863> *IDLEAMPLITUDE)/100) speed ((<61.676723> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-1.605118> *IDLEAMPLITUDE)/100) speed ((<48.920509> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<0.689307> *IDLEAMPLITUDE)/100) speed ((<20.679218> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<7.972041> *IDLEAMPLITUDE)/100) speed ((<281.403184> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-0.789894> *IDLEAMPLITUDE)/100) speed ((<55.623049> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<0.433761> *IDLEAMPLITUDE)/100) speed ((<44.027328> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-2.187853> *IDLEAMPLITUDE)/100) speed ((<96.886392> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.259550> *IDLEAMPLITUDE)/100) speed ((<19.396374> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<0.203075> *IDLEAMPLITUDE)/100) speed ((<19.633177> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-6.876856> *IDLEAMPLITUDE)/100) speed ((<286.451116> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-0.411708> *IDLEAMPLITUDE)/100) speed ((<29.786606> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<2.395997> *IDLEAMPLITUDE)/100) speed ((<108.318791> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<1.501236> *IDLEAMPLITUDE)/100) speed ((<114.001808> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.126171> *IDLEAMPLITUDE)/100) speed ((<6.818242> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<4.284403> *IDLEAMPLITUDE)/100) speed ((<274.649471> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-0.764165> *IDLEAMPLITUDE)/100) speed ((<53.743061> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<0.530209> *IDLEAMPLITUDE)/100) speed ((<57.233923> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-1.394237> *IDLEAMPLITUDE)/100) speed ((<99.855338> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.258065> *IDLEAMPLITUDE)/100) speed ((<18.531604> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.178952> *IDLEAMPLITUDE)/100) speed ((<15.321822> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<1.494345> *IDLEAMPLITUDE)/100) speed ((<385.979527> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-0.404901> *IDLEAMPLITUDE)/100) speed ((<29.319229> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<-2.122392> *IDLEAMPLITUDE)/100) speed ((<217.001360> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<1.494049> *IDLEAMPLITUDE)/100) speed ((<113.199753> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<-0.083638> *IDLEAMPLITUDE)/100) speed ((<14.309961> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<-1.596847> *IDLEAMPLITUDE)/100) speed ((<47.905423> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:30
			move body to x-axis (((([-0.680736] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([3.371826] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<1.460216> *IDLEAMPLITUDE)/100) speed ((<21.903238> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-2.489556> *IDLEAMPLITUDE)/100) speed ((<26.533156> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<2.342608> *IDLEAMPLITUDE)/100) speed ((<49.599029> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-0.953363> *IDLEAMPLITUDE)/100) speed ((<4.904089> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-1.577328> *IDLEAMPLITUDE)/100) speed ((<18.315747> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-7.148951> *IDLEAMPLITUDE)/100) speed ((<8.162840> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<2.112543> *IDLEAMPLITUDE)/100) speed ((<8.503630> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<1.264397> *IDLEAMPLITUDE)/100) speed ((<7.105178> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<4.495917> *IDLEAMPLITUDE)/100) speed ((<6.345404> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-0.924999> *IDLEAMPLITUDE)/100) speed ((<4.825026> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-2.412816> *IDLEAMPLITUDE)/100) speed ((<30.557346> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<1.812056> *IDLEAMPLITUDE)/100) speed ((<9.531328> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<-1.575612> *IDLEAMPLITUDE)/100) speed ((<16.403416> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<1.246953> *IDLEAMPLITUDE)/100) speed ((<7.412873> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<-3.193695> *IDLEAMPLITUDE)/100) speed ((<47.905423> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:40
			move body to x-axis (((([0.152805] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([25.006224] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([1.320841] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([60.480444] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.587839] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([11.243320] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<2.190324> *IDLEAMPLITUDE)/100) speed ((<21.903235> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<0.977462> *IDLEAMPLITUDE)/100) speed ((<40.057323> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<0.025566> *IDLEAMPLITUDE)/100) speed ((<75.453665> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<4.337972> *IDLEAMPLITUDE)/100) speed ((<59.860907> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<2.255302> *IDLEAMPLITUDE)/100) speed ((<171.634577> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<0.163690> *IDLEAMPLITUDE)/100) speed ((<33.511610> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-0.778423> *IDLEAMPLITUDE)/100) speed ((<35.884344> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-2.687029> *IDLEAMPLITUDE)/100) speed ((<33.291035> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<0.052935> *IDLEAMPLITUDE)/100) speed ((<11.119819> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<-0.057245> *IDLEAMPLITUDE)/100) speed ((<9.217018> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-6.849146> *IDLEAMPLITUDE)/100) speed ((<8.994168> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<0.085635> *IDLEAMPLITUDE)/100) speed ((<17.634386> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<0.019208> *IDLEAMPLITUDE)/100) speed ((<6.446571> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<8.720428> *IDLEAMPLITUDE)/100) speed ((<198.236559> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<-2.675914> *IDLEAMPLITUDE)/100) speed ((<118.209319> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<0.243840> *IDLEAMPLITUDE)/100) speed ((<11.364207> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-1.762497> *IDLEAMPLITUDE)/100) speed ((<187.752394> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<0.102273> *IDLEAMPLITUDE)/100) speed ((<30.818152> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-0.837328> *IDLEAMPLITUDE)/100) speed ((<40.595683> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-5.108336> *IDLEAMPLITUDE)/100) speed ((<80.865615> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<0.039828> *IDLEAMPLITUDE)/100) speed ((<10.573006> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<-0.039568> *IDLEAMPLITUDE)/100) speed ((<7.503506> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<2.244597> *IDLEAMPLITUDE)/100) speed ((<12.976228> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<0.065738> *IDLEAMPLITUDE)/100) speed ((<16.775274> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to y-axis ((<0.008270> *IDLEAMPLITUDE)/100) speed ((<4.779464> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<7.032332> *IDLEAMPLITUDE)/100) speed ((<258.238307> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<-2.603698> *IDLEAMPLITUDE)/100) speed ((<115.519528> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.203774> *IDLEAMPLITUDE)/100) speed ((<9.688819> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<-2.497657> *IDLEAMPLITUDE)/100) speed ((<20.881143> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:50
			move body to x-axis (((([0.678917] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([15.783359] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([2.019850] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([20.970250] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([1.228185] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([19.210358] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<2.920431> *IDLEAMPLITUDE)/100) speed ((<21.903232> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<2.120533> *IDLEAMPLITUDE)/100) speed ((<34.292149> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<6.053466> *IDLEAMPLITUDE)/100) speed ((<51.464814> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-1.201757> *IDLEAMPLITUDE)/100) speed ((<103.711784> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<1.045179> *IDLEAMPLITUDE)/100) speed ((<26.444651> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-1.477802> *IDLEAMPLITUDE)/100) speed ((<20.981365> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-6.282583> *IDLEAMPLITUDE)/100) speed ((<107.866618> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<0.365987> *IDLEAMPLITUDE)/100) speed ((<9.391545> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<-0.378533> *IDLEAMPLITUDE)/100) speed ((<9.638660> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-1.185151> *IDLEAMPLITUDE)/100) speed ((<169.919840> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<0.597709> *IDLEAMPLITUDE)/100) speed ((<15.362212> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<10.085515> *IDLEAMPLITUDE)/100) speed ((<40.952602> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<-5.436920> *IDLEAMPLITUDE)/100) speed ((<82.830186> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<0.556101> *IDLEAMPLITUDE)/100) speed ((<9.367817> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-5.652872> *IDLEAMPLITUDE)/100) speed ((<116.711263> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<0.879762> *IDLEAMPLITUDE)/100) speed ((<23.324667> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-1.603311> *IDLEAMPLITUDE)/100) speed ((<22.979493> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-10.911246> *IDLEAMPLITUDE)/100) speed ((<174.087298> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<0.319637> *IDLEAMPLITUDE)/100) speed ((<8.394256> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<-0.299542> *IDLEAMPLITUDE)/100) speed ((<7.799236> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<8.421761> *IDLEAMPLITUDE)/100) speed ((<185.314912> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<0.540983> *IDLEAMPLITUDE)/100) speed ((<14.257362> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<10.522774> *IDLEAMPLITUDE)/100) speed ((<104.713267> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<-5.281799> *IDLEAMPLITUDE)/100) speed ((<80.343035> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.645554> *IDLEAMPLITUDE)/100) speed ((<13.253399> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<74.929702> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:60
			turn body to z-axis ((<3.020446> *IDLEAMPLITUDE)/100) speed ((<3.0> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<6.867158> *IDLEAMPLITUDE)/100) speed ((<24.410784> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-1.290280> *IDLEAMPLITUDE)/100) speed ((<3.153879> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-11.060145> *IDLEAMPLITUDE)/100) speed ((<4.466969> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<10.702883> *IDLEAMPLITUDE)/100) speed ((<5.403286> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<4.108279> *IDLEAMPLITUDE)/100) speed ((<123.248356> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:70
			move body to x-axis (((([0.823057] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([4.931175] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([1.254589] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([23.465928] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.837470] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([11.766472] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<3.120461> *IDLEAMPLITUDE)/100) speed ((<3.0> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<2.433704> *IDLEAMPLITUDE)/100) speed ((<8.852636> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<5.945594> *IDLEAMPLITUDE)/100) speed ((<27.646924> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-0.411168> *IDLEAMPLITUDE)/100) speed ((<24.408643> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<1.371438> *IDLEAMPLITUDE)/100) speed ((<10.847956> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-1.885537> *IDLEAMPLITUDE)/100) speed ((<11.604602> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-2.469349> *IDLEAMPLITUDE)/100) speed ((<111.648831> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<0.465544> *IDLEAMPLITUDE)/100) speed ((<3.344371> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-0.678147> *IDLEAMPLITUDE)/100) speed ((<18.363981> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<0.742237> *IDLEAMPLITUDE)/100) speed ((<4.923919> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<4.979114> *IDLEAMPLITUDE)/100) speed ((<154.608260> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<-6.057064> *IDLEAMPLITUDE)/100) speed ((<17.900560> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<0.252462> *IDLEAMPLITUDE)/100) speed ((<9.222251> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-5.209873> *IDLEAMPLITUDE)/100) speed ((<12.375688> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<1.141850> *IDLEAMPLITUDE)/100) speed ((<9.020039> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-1.979037> *IDLEAMPLITUDE)/100) speed ((<10.597059> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-7.445007> *IDLEAMPLITUDE)/100) speed ((<108.454141> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<9.207871> *IDLEAMPLITUDE)/100) speed ((<25.120949> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<0.674717> *IDLEAMPLITUDE)/100) speed ((<4.642120> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<5.833174> *IDLEAMPLITUDE)/100) speed ((<146.091292> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<-5.874018> *IDLEAMPLITUDE)/100) speed ((<17.125491> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.369765> *IDLEAMPLITUDE)/100) speed ((<8.750879> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<6.414939> *IDLEAMPLITUDE)/100) speed ((<69.199810> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:80
			move body to x-axis (((([1.316263] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([14.796172] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([0.883710] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([11.126384] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<3.220476> *IDLEAMPLITUDE)/100) speed ((<3.0> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<2.711478> *IDLEAMPLITUDE)/100) speed ((<8.333245> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<1.303856> *IDLEAMPLITUDE)/100) speed ((<38.348699> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<3.569675> *IDLEAMPLITUDE)/100) speed ((<71.277585> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-1.815652> *IDLEAMPLITUDE)/100) speed ((<42.134530> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<2.338251> *IDLEAMPLITUDE)/100) speed ((<29.004392> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-2.029090> *IDLEAMPLITUDE)/100) speed ((<4.306605> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-2.180229> *IDLEAMPLITUDE)/100) speed ((<8.673612> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<0.786477> *IDLEAMPLITUDE)/100) speed ((<9.627999> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<-0.732996> *IDLEAMPLITUDE)/100) speed ((<8.172994> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<4.037679> *IDLEAMPLITUDE)/100) speed ((<141.474785> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<1.253670> *IDLEAMPLITUDE)/100) speed ((<15.342983> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<1.330216> *IDLEAMPLITUDE)/100) speed ((<109.466945> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<-7.960540> *IDLEAMPLITUDE)/100) speed ((<57.104279> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.019572> *IDLEAMPLITUDE)/100) speed ((<8.161013> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-7.118088> *IDLEAMPLITUDE)/100) speed ((<57.246432> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<2.029415> *IDLEAMPLITUDE)/100) speed ((<26.626961> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-2.113993> *IDLEAMPLITUDE)/100) speed ((<4.048667> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-7.548215> *IDLEAMPLITUDE)/100) speed ((<3.096253> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<0.698327> *IDLEAMPLITUDE)/100) speed ((<8.831659> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<-0.599827> *IDLEAMPLITUDE)/100) speed ((<6.966518> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<14.455421> *IDLEAMPLITUDE)/100) speed ((<157.426494> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<1.185252> *IDLEAMPLITUDE)/100) speed ((<15.316054> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<2.544817> *IDLEAMPLITUDE)/100) speed ((<98.650704> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<-7.693861> *IDLEAMPLITUDE)/100) speed ((<54.595273> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.164040> *IDLEAMPLITUDE)/100) speed ((<6.171769> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<4.751806> *IDLEAMPLITUDE)/100) speed ((<49.893981> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:90
			turn body to z-axis ((<3.320490> *IDLEAMPLITUDE)/100) speed ((<3.0> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<1.124215> *IDLEAMPLITUDE)/100) speed ((<73.363781> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<4.161894> *IDLEAMPLITUDE)/100) speed ((<3.726466> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-7.869519> *IDLEAMPLITUDE)/100) speed ((<9.639122> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<14.577666> *IDLEAMPLITUDE)/100) speed ((<3.667351> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<2.704506> *IDLEAMPLITUDE)/100) speed ((<4.790675> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<1.663132> *IDLEAMPLITUDE)/100) speed ((<92.660216> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:100
			move body to x-axis (((([-1.425531] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([81.714166] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([-0.065542] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([28.294366] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.0] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([26.734618] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<8.312128> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<99.614715> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<-2.451753> *IDLEAMPLITUDE)/100) speed ((<155.958813> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<0.025566> *IDLEAMPLITUDE)/100) speed ((<39.882646> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to z-axis ((<-0.0> *IDLEAMPLITUDE)/100) speed ((<33.726462> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-1.408065> *IDLEAMPLITUDE)/100) speed ((<12.284111> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-2.643995> *IDLEAMPLITUDE)/100) speed ((<148.277181> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<1.901339> *IDLEAMPLITUDE)/100) speed ((<119.263325> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<1.041694> *IDLEAMPLITUDE)/100) speed ((<99.329175> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.906096> *IDLEAMPLITUDE)/100) speed ((<50.325484> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<0.857514> *IDLEAMPLITUDE)/100) speed ((<47.233147> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<2.671514> *IDLEAMPLITUDE)/100) speed ((<44.711404> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-1.404595> *IDLEAMPLITUDE)/100) speed ((<79.053986> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<-0.192709> *IDLEAMPLITUDE)/100) speed ((<10.021438> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<-1.214630> *IDLEAMPLITUDE)/100) speed ((<75.650468> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<5.301297> *IDLEAMPLITUDE)/100) speed ((<398.395594> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<0.101104> *IDLEAMPLITUDE)/100) speed ((<3.720366> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-4.870579> *IDLEAMPLITUDE)/100) speed ((<65.964426> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-2.555600> *IDLEAMPLITUDE)/100) speed ((<136.145638> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<2.438007> *IDLEAMPLITUDE)/100) speed ((<137.960769> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<1.934274> *IDLEAMPLITUDE)/100) speed ((<294.113800> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.875785> *IDLEAMPLITUDE)/100) speed ((<46.740803> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.689679> *IDLEAMPLITUDE)/100) speed ((<38.142260> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<14.360329> *IDLEAMPLITUDE)/100) speed ((<6.520099> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-1.382209> *IDLEAMPLITUDE)/100) speed ((<76.260725> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<-9.355771> *IDLEAMPLITUDE)/100) speed ((<361.808315> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<5.267374> *IDLEAMPLITUDE)/100) speed ((<389.233352> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.393361> *IDLEAMPLITUDE)/100) speed ((<6.278157> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn tail to y-axis ((<0.0> *IDLEAMPLITUDE)/100) speed ((<49.893968> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:123
			move body to x-axis (((([1.205029] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([78.916790] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([1.010473] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([32.280450] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.979732] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([29.391972] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<-0.304611> *IDLEAMPLITUDE)/100) speed ((<9.138334> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<3.650539> *IDLEAMPLITUDE)/100) speed ((<109.516179> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<3.263605> *IDLEAMPLITUDE)/100) speed ((<171.460747> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-4.560936> *IDLEAMPLITUDE)/100) speed ((<137.595057> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-2.857468> *IDLEAMPLITUDE)/100) speed ((<43.482095> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<2.062943> *IDLEAMPLITUDE)/100) speed ((<141.208146> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-2.589240> *IDLEAMPLITUDE)/100) speed ((<134.717362> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-2.336528> *IDLEAMPLITUDE)/100) speed ((<101.346645> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<0.685454> *IDLEAMPLITUDE)/100) speed ((<47.746501> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<-0.645021> *IDLEAMPLITUDE)/100) speed ((<45.076050> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<5.729275> *IDLEAMPLITUDE)/100) speed ((<91.732826> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<1.096747> *IDLEAMPLITUDE)/100) speed ((<75.040255> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<0.088772> *IDLEAMPLITUDE)/100) speed ((<8.444440> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<0.878019> *IDLEAMPLITUDE)/100) speed ((<62.779454> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<-7.858700> *IDLEAMPLITUDE)/100) speed ((<394.799884> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.114407> *IDLEAMPLITUDE)/100) speed ((<6.465343> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-7.959335> *IDLEAMPLITUDE)/100) speed ((<92.662662> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<1.692681> *IDLEAMPLITUDE)/100) speed ((<127.448436> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-2.668824> *IDLEAMPLITUDE)/100) speed ((<153.204938> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-8.847220> *IDLEAMPLITUDE)/100) speed ((<323.444818> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<0.590084> *IDLEAMPLITUDE)/100) speed ((<43.976091> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<-0.509580> *IDLEAMPLITUDE)/100) speed ((<35.977793> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<15.673836> *IDLEAMPLITUDE)/100) speed ((<39.405205> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<1.012966> *IDLEAMPLITUDE)/100) speed ((<71.855230> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<3.501682> *IDLEAMPLITUDE)/100) speed ((<385.723606> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<-7.594622> *IDLEAMPLITUDE)/100) speed ((<385.859887> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.225220> *IDLEAMPLITUDE)/100) speed ((<5.044241> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:133
			move body to x-axis (((([-1.088171] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([68.795993] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([0.151469] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([25.770117] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.306168] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([20.206924] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<0.047583> *IDLEAMPLITUDE)/100) speed ((<10.565815> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<-0.412239> *IDLEAMPLITUDE)/100) speed ((<121.883364> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<-0.368265> *IDLEAMPLITUDE)/100) speed ((<108.956108> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-6.555068> *IDLEAMPLITUDE)/100) speed ((<59.823954> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<6.227317> *IDLEAMPLITUDE)/100) speed ((<272.543546> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-1.598491> *IDLEAMPLITUDE)/100) speed ((<109.843033> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<0.144289> *IDLEAMPLITUDE)/100) speed ((<82.005866> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-4.245171> *IDLEAMPLITUDE)/100) speed ((<57.259303> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.548155> *IDLEAMPLITUDE)/100) speed ((<37.008280> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<0.467178> *IDLEAMPLITUDE)/100) speed ((<33.365960> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-7.117983> *IDLEAMPLITUDE)/100) speed ((<385.417752> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-0.882382> *IDLEAMPLITUDE)/100) speed ((<59.373870> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<-0.298598> *IDLEAMPLITUDE)/100) speed ((<11.621115> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<6.327385> *IDLEAMPLITUDE)/100) speed ((<163.480988> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<4.693370> *IDLEAMPLITUDE)/100) speed ((<376.562088> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.470367> *IDLEAMPLITUDE)/100) speed ((<10.678782> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<1.388008> *IDLEAMPLITUDE)/100) speed ((<280.420290> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-1.609516> *IDLEAMPLITUDE)/100) speed ((<99.065897> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<0.361947> *IDLEAMPLITUDE)/100) speed ((<90.923159> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-0.485141> *IDLEAMPLITUDE)/100) speed ((<250.862357> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.565908> *IDLEAMPLITUDE)/100) speed ((<34.679783> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.464181> *IDLEAMPLITUDE)/100) speed ((<29.212850> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<1.260444> *IDLEAMPLITUDE)/100) speed ((<432.401769> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-0.883482> *IDLEAMPLITUDE)/100) speed ((<56.893425> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to y-axis ((<-0.201958> *IDLEAMPLITUDE)/100) speed ((<3.728700> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<-0.022742> *IDLEAMPLITUDE)/100) speed ((<105.732730> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<4.702355> *IDLEAMPLITUDE)/100) speed ((<368.909322> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<-0.178440> *IDLEAMPLITUDE)/100) speed ((<12.109795> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:143
			move body to x-axis (((([-1.263918] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([5.272411] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([1.718241] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([47.003156] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([2.081936] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([53.273036] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<-0.268466> *IDLEAMPLITUDE)/100) speed ((<9.481474> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<3.043550> *IDLEAMPLITUDE)/100) speed ((<103.673685> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<2.720703> *IDLEAMPLITUDE)/100) speed ((<92.669040> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-8.549199> *IDLEAMPLITUDE)/100) speed ((<59.823941> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<16.917458> *IDLEAMPLITUDE)/100) speed ((<320.704237> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-1.902620> *IDLEAMPLITUDE)/100) speed ((<9.123870> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-2.909431> *IDLEAMPLITUDE)/100) speed ((<91.611607> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-24.857767> *IDLEAMPLITUDE)/100) speed ((<618.377857> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.697369> *IDLEAMPLITUDE)/100) speed ((<4.476406> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-16.166834> *IDLEAMPLITUDE)/100) speed ((<271.465519> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-1.146948> *IDLEAMPLITUDE)/100) speed ((<7.936988> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<-0.564060> *IDLEAMPLITUDE)/100) speed ((<7.963868> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<25.774400> *IDLEAMPLITUDE)/100) speed ((<583.410448> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<1.926513> *IDLEAMPLITUDE)/100) speed ((<83.005720> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.764526> *IDLEAMPLITUDE)/100) speed ((<8.824790> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<11.327987> *IDLEAMPLITUDE)/100) speed ((<298.199347> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-2.091782> *IDLEAMPLITUDE)/100) speed ((<14.467983> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-2.818564> *IDLEAMPLITUDE)/100) speed ((<95.415332> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-27.696250> *IDLEAMPLITUDE)/100) speed ((<816.333249> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.725436> *IDLEAMPLITUDE)/100) speed ((<4.785830> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.361291> *IDLEAMPLITUDE)/100) speed ((<3.086703> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<-7.159743> *IDLEAMPLITUDE)/100) speed ((<252.605600> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-1.152820> *IDLEAMPLITUDE)/100) speed ((<8.080151> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to y-axis ((<-0.412091> *IDLEAMPLITUDE)/100) speed ((<6.303990> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<26.157446> *IDLEAMPLITUDE)/100) speed ((<785.405629> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<1.843852> *IDLEAMPLITUDE)/100) speed ((<85.755100> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<-0.754851> *IDLEAMPLITUDE)/100) speed ((<17.292317> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:153
			move body to y-axis (((([0.643779] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([43.144727] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<-3.971439> *IDLEAMPLITUDE)/100) speed ((<111.089168> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<2.850252> *IDLEAMPLITUDE)/100) speed ((<5.798939> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<2.506169> *IDLEAMPLITUDE)/100) speed ((<6.436004> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-10.543331> *IDLEAMPLITUDE)/100) speed ((<59.823954> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<15.716069> *IDLEAMPLITUDE)/100) speed ((<36.041679> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-2.331673> *IDLEAMPLITUDE)/100) speed ((<12.871573> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-2.492257> *IDLEAMPLITUDE)/100) speed ((<12.515235> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-12.569748> *IDLEAMPLITUDE)/100) speed ((<368.640549> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.820835> *IDLEAMPLITUDE)/100) speed ((<3.703979> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<0.683151> *IDLEAMPLITUDE)/100) speed ((<8.914814> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-23.506393> *IDLEAMPLITUDE)/100) speed ((<220.186772> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-1.441699> *IDLEAMPLITUDE)/100) speed ((<8.842519> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<-0.761969> *IDLEAMPLITUDE)/100) speed ((<5.937244> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<2.865869> *IDLEAMPLITUDE)/100) speed ((<28.180697> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-1.006471> *IDLEAMPLITUDE)/100) speed ((<7.258335> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<9.590372> *IDLEAMPLITUDE)/100) speed ((<52.128439> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-2.497067> *IDLEAMPLITUDE)/100) speed ((<12.158565> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-2.352724> *IDLEAMPLITUDE)/100) speed ((<13.975188> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-14.108388> *IDLEAMPLITUDE)/100) speed ((<407.635841> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.836788> *IDLEAMPLITUDE)/100) speed ((<3.340569> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.671285> *IDLEAMPLITUDE)/100) speed ((<9.299821> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<-13.740528> *IDLEAMPLITUDE)/100) speed ((<197.423557> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-1.413070> *IDLEAMPLITUDE)/100) speed ((<7.807483> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to y-axis ((<-0.557481> *IDLEAMPLITUDE)/100) speed ((<4.361703> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<24.577700> *IDLEAMPLITUDE)/100) speed ((<47.392377> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<2.752408> *IDLEAMPLITUDE)/100) speed ((<27.256675> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<-1.001838> *IDLEAMPLITUDE)/100) speed ((<7.409625> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:163
			move body to x-axis (((([-1.088171] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([7.673042] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([0.151469] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([46.767805] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.306168] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([10.128309] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<0.047583> *IDLEAMPLITUDE)/100) speed ((<120.570641> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<-0.412239> *IDLEAMPLITUDE)/100) speed ((<97.874745> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<-0.368265> *IDLEAMPLITUDE)/100) speed ((<86.233036> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-12.537462> *IDLEAMPLITUDE)/100) speed ((<59.823928> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<6.227317> *IDLEAMPLITUDE)/100) speed ((<284.662558> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<-1.598491> *IDLEAMPLITUDE)/100) speed ((<21.995443> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<0.144289> *IDLEAMPLITUDE)/100) speed ((<79.096372> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-4.245171> *IDLEAMPLITUDE)/100) speed ((<249.737308> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<-0.548155> *IDLEAMPLITUDE)/100) speed ((<8.180385> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<0.467178> *IDLEAMPLITUDE)/100) speed ((<6.479202> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<-7.117983> *IDLEAMPLITUDE)/100) speed ((<491.652290> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<-0.882382> *IDLEAMPLITUDE)/100) speed ((<16.779506> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<-0.298598> *IDLEAMPLITUDE)/100) speed ((<13.901112> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<6.327385> *IDLEAMPLITUDE)/100) speed ((<581.727148> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<4.693370> *IDLEAMPLITUDE)/100) speed ((<54.825023> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.470367> *IDLEAMPLITUDE)/100) speed ((<16.083125> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<1.388008> *IDLEAMPLITUDE)/100) speed ((<246.070908> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<-1.609516> *IDLEAMPLITUDE)/100) speed ((<26.626548> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<0.361947> *IDLEAMPLITUDE)/100) speed ((<81.440144> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-0.485141> *IDLEAMPLITUDE)/100) speed ((<408.697408> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<-0.565908> *IDLEAMPLITUDE)/100) speed ((<8.126399> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<0.464181> *IDLEAMPLITUDE)/100) speed ((<6.213118> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<1.260444> *IDLEAMPLITUDE)/100) speed ((<450.029157> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<-0.883482> *IDLEAMPLITUDE)/100) speed ((<15.887634> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to y-axis ((<-0.201958> *IDLEAMPLITUDE)/100) speed ((<10.665693> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<-0.022742> *IDLEAMPLITUDE)/100) speed ((<738.013252> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<4.702355> *IDLEAMPLITUDE)/100) speed ((<58.498425> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<-0.178440> *IDLEAMPLITUDE)/100) speed ((<24.701941> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
		if (!isMoving) { //Frame:173
			move body to x-axis (((([1.205029] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([68.795993] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to z-axis (((([1.010473] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([25.770117] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			move body to y-axis (((([0.979732] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) speed (((([20.206924] *IDLEMOVESCALE)/100) *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to x-axis ((<-0.304611> *IDLEAMPLITUDE)/100) speed ((<10.565815> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to z-axis ((<3.650539> *IDLEAMPLITUDE)/100) speed ((<121.883364> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn body to y-axis ((<3.263605> *IDLEAMPLITUDE)/100) speed ((<108.956108> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn head to x-axis ((<-14.531593> *IDLEAMPLITUDE)/100) speed ((<59.823928> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to x-axis ((<-2.857468> *IDLEAMPLITUDE)/100) speed ((<272.543546> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to z-axis ((<2.062943> *IDLEAMPLITUDE)/100) speed ((<109.843033> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lfoot to y-axis ((<-2.589240> *IDLEAMPLITUDE)/100) speed ((<82.005866> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to x-axis ((<-2.336528> *IDLEAMPLITUDE)/100) speed ((<57.259303> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to z-axis ((<0.685454> *IDLEAMPLITUDE)/100) speed ((<37.008280> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lknee to y-axis ((<-0.645021> *IDLEAMPLITUDE)/100) speed ((<33.365960> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to x-axis ((<5.729275> *IDLEAMPLITUDE)/100) speed ((<385.417752> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to z-axis ((<1.096747> *IDLEAMPLITUDE)/100) speed ((<59.373870> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lshin to y-axis ((<0.088772> *IDLEAMPLITUDE)/100) speed ((<11.621115> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to x-axis ((<0.878019> *IDLEAMPLITUDE)/100) speed ((<163.480988> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to z-axis ((<-7.858700> *IDLEAMPLITUDE)/100) speed ((<376.562088> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn lthigh to y-axis ((<-0.114407> *IDLEAMPLITUDE)/100) speed ((<10.678782> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to x-axis ((<-7.959335> *IDLEAMPLITUDE)/100) speed ((<280.420290> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to z-axis ((<1.692681> *IDLEAMPLITUDE)/100) speed ((<99.065897> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rfoot to y-axis ((<-2.668824> *IDLEAMPLITUDE)/100) speed ((<90.923159> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to x-axis ((<-8.847220> *IDLEAMPLITUDE)/100) speed ((<250.862357> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to z-axis ((<0.590084> *IDLEAMPLITUDE)/100) speed ((<34.679783> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rknee to y-axis ((<-0.509580> *IDLEAMPLITUDE)/100) speed ((<29.212850> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to x-axis ((<15.673836> *IDLEAMPLITUDE)/100) speed ((<432.401769> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to z-axis ((<1.012966> *IDLEAMPLITUDE)/100) speed ((<56.893425> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rshin to y-axis ((<-0.077668> *IDLEAMPLITUDE)/100) speed ((<3.728700> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to x-axis ((<3.501682> *IDLEAMPLITUDE)/100) speed ((<105.732730> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to z-axis ((<-7.594622> *IDLEAMPLITUDE)/100) speed ((<368.909322> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
			turn rthigh to y-axis ((<0.225220> *IDLEAMPLITUDE)/100) speed ((<12.109795> *IDLEAMPLITUDE)/100) / IDLESPEED; //delta=%.2f
		sleep ((33*IDLESPEED) -1);
		}
	}
}
// Call this from StopMoving()!
StopIdle() {
	//IDLESPEED = 10; // tune restore speed here, higher values are slower restore speeds
	move body to x-axis ([0.0]*IDLEMOVESCALE)/100 speed (([81.714166]*IDLEMOVESCALE)/100) / IDLESPEED;
	move body to y-axis ([0.0]*IDLEMOVESCALE)/100 speed (([53.273036]*IDLEMOVESCALE)/100) / IDLESPEED;
	move body to z-axis ([0.0]*IDLEMOVESCALE)/100 speed (([60.480444]*IDLEMOVESCALE)/100) / IDLESPEED;
	turn body to x-axis <0.0> speed <120.570641> / IDLESPEED;
	turn body to y-axis <0.0> speed <155.958813> / IDLESPEED;
	turn body to z-axis <0.0> speed <121.883364> / IDLESPEED;
	turn head to x-axis <0.0> speed <75.453665> / IDLESPEED;
	turn head to z-axis <0.0> speed <73.363781> / IDLESPEED;
	turn lfoot to x-axis <6.040111> speed <320.704237> / IDLESPEED;
	turn lfoot to y-axis <0.0> speed <119.263325> / IDLESPEED;
	turn lfoot to z-axis <0.0> speed <148.277181> / IDLESPEED;
	turn lknee to x-axis <-0.879296> speed <618.377857> / IDLESPEED;
	turn lknee to y-axis <0.0> speed <47.233147> / IDLESPEED;
	turn lknee to z-axis <0.0> speed <50.325484> / IDLESPEED;
	turn lshin to x-axis <-7.958460> speed <491.652290> / IDLESPEED;
	turn lshin to y-axis <0.0> speed <13.901112> / IDLESPEED;
	turn lshin to z-axis <0.0> speed <79.053986> / IDLESPEED;
	turn lthigh to x-axis <4.070670> speed <583.410448> / IDLESPEED;
	turn lthigh to y-axis <0.0> speed <16.083125> / IDLESPEED;
	turn lthigh to z-axis <0.0> speed <398.395594> / IDLESPEED;
	turn rfoot to x-axis <1.637208> speed <298.199347> / IDLESPEED;
	turn rfoot to y-axis <0.0> speed <137.960769> / IDLESPEED;
	turn rfoot to z-axis <0.0> speed <136.145638> / IDLESPEED;
	turn rknee to x-axis <1.676005> speed <816.333249> / IDLESPEED;
	turn rknee to y-axis <0.0> speed <38.142260> / IDLESPEED;
	turn rknee to z-axis <0.0> speed <46.740803> / IDLESPEED;
	turn rshin to x-axis <0.0> speed <450.029157> / IDLESPEED;
	turn rshin to y-axis <0.0> speed <10.665693> / IDLESPEED;
	turn rshin to z-axis <0.0> speed <76.260725> / IDLESPEED;
	turn rthigh to x-axis <-1.107364> speed <785.405629> / IDLESPEED;
	turn rthigh to y-axis <0.0> speed <24.701941> / IDLESPEED;
	turn rthigh to z-axis <0.0> speed <389.233352> / IDLESPEED;
	turn tail to y-axis <0.0> speed <123.248356> / IDLESPEED;
}

