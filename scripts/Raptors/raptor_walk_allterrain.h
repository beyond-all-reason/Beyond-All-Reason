// For N:\animations\raptor_allterrain_walk_v3.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5))

//Needs a crapton of #defines and static-vars:

//#define MOVESCALE 100 //Higher values are bigger, 100 is default
//#define MOVESPEED 6
//#define animAmplitude 66
//#define LUHAND lsack  //define these as the left and right head thingies
//#define RUHAND rsack  
//#define LLHAND lsack  //define these as the left and right head thingies
//#define RLHAND rsack  
//#define SIGNAL_MOVE 1

Walk() {// For N:\animations\raptor_allterrain_walk_v3.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:4
			move body to x-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn body to x-axis ((<-1.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<3.866804> *animAmplitude)/100) speed ((<116.004134> *animAmplitude)/100) / animSpeed; //delta=-3.87
			turn head to x-axis ((<-1.497920> *animAmplitude)/100) speed ((<44.937601> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<2.995840> *animAmplitude)/100) speed ((<89.875202> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn lbfoot to x-axis ((<-1.038083> *animAmplitude)/100) speed ((<31.142496> *animAmplitude)/100) / animSpeed; //delta=1.04
			turn lbfoot to z-axis ((<-1.347733> *animAmplitude)/100) speed ((<40.431988> *animAmplitude)/100) / animSpeed; //delta=1.35
			turn lbknee to x-axis ((<6.439735> *animAmplitude)/100) speed ((<193.192050> *animAmplitude)/100) / animSpeed; //delta=-6.44
			turn lbknee to z-axis ((<0.894888> *animAmplitude)/100) speed ((<26.846641> *animAmplitude)/100) / animSpeed; //delta=-0.89
			turn lbshin to x-axis ((<-2.423438> *animAmplitude)/100) speed ((<72.703146> *animAmplitude)/100) / animSpeed; //delta=2.42
			turn lbshin to z-axis ((<-1.828183> *animAmplitude)/100) speed ((<54.845501> *animAmplitude)/100) / animSpeed; //delta=1.83
			turn lbthigh to x-axis ((<-1.979248> *animAmplitude)/100) speed ((<59.377445> *animAmplitude)/100) / animSpeed; //delta=1.98
			turn lbthigh to z-axis ((<-1.586812> *animAmplitude)/100) speed ((<47.604352> *animAmplitude)/100) / animSpeed; //delta=1.59
			turn lffoot to x-axis ((<-25.122923> *animAmplitude)/100) speed ((<753.687691> *animAmplitude)/100) / animSpeed; //delta=25.12
			turn lffoot to z-axis ((<-1.182264> *animAmplitude)/100) speed ((<35.467911> *animAmplitude)/100) / animSpeed; //delta=1.18
			turn lffoot to y-axis ((<-0.566773> *animAmplitude)/100) speed ((<17.003185> *animAmplitude)/100) / animSpeed; //delta=-0.57
			turn lfknee to x-axis ((<-8.899382> *animAmplitude)/100) speed ((<266.981465> *animAmplitude)/100) / animSpeed; //delta=8.90
			turn lfknee to z-axis ((<-0.722958> *animAmplitude)/100) speed ((<21.688747> *animAmplitude)/100) / animSpeed; //delta=0.72
			turn lfknee to y-axis ((<0.332272> *animAmplitude)/100) speed ((<9.968156> *animAmplitude)/100) / animSpeed; //delta=0.33
			turn lfshin to x-axis ((<2.041949> *animAmplitude)/100) speed ((<61.258460> *animAmplitude)/100) / animSpeed; //delta=-2.04
			turn lfshin to z-axis ((<-0.653646> *animAmplitude)/100) speed ((<19.609371> *animAmplitude)/100) / animSpeed; //delta=0.65
			turn lfshin to y-axis ((<0.633994> *animAmplitude)/100) speed ((<19.019807> *animAmplitude)/100) / animSpeed; //delta=0.63
			turn lfthigh to x-axis ((<32.952005> *animAmplitude)/100) speed ((<988.560155> *animAmplitude)/100) / animSpeed; //delta=-32.95
			turn lfthigh to z-axis ((<-1.487056> *animAmplitude)/100) speed ((<44.611667> *animAmplitude)/100) / animSpeed; //delta=1.49
			turn lfthigh to y-axis ((<1.063586> *animAmplitude)/100) speed ((<31.907582> *animAmplitude)/100) / animSpeed; //delta=1.06
			turn rbfoot to x-axis ((<-3.311221> *animAmplitude)/100) speed ((<99.336638> *animAmplitude)/100) / animSpeed; //delta=3.31
			turn rbfoot to z-axis ((<-0.263967> *animAmplitude)/100) speed ((<7.919009> *animAmplitude)/100) / animSpeed; //delta=0.26
			turn rbknee to x-axis ((<23.032253> *animAmplitude)/100) speed ((<690.967601> *animAmplitude)/100) / animSpeed; //delta=-23.03
			turn rbknee to z-axis ((<-8.592465> *animAmplitude)/100) speed ((<257.773952> *animAmplitude)/100) / animSpeed; //delta=8.59
			turn rbknee to y-axis ((<2.308514> *animAmplitude)/100) speed ((<69.255422> *animAmplitude)/100) / animSpeed; //delta=2.31
			turn rbshin to x-axis ((<-9.113940> *animAmplitude)/100) speed ((<273.418193> *animAmplitude)/100) / animSpeed; //delta=9.11
			turn rbshin to z-axis ((<1.521576> *animAmplitude)/100) speed ((<45.647279> *animAmplitude)/100) / animSpeed; //delta=-1.52
			turn rbshin to y-axis ((<0.101727> *animAmplitude)/100) speed ((<3.051805> *animAmplitude)/100) / animSpeed; //delta=0.10
			turn rbthigh to x-axis ((<-9.734253> *animAmplitude)/100) speed ((<292.027598> *animAmplitude)/100) / animSpeed; //delta=9.73
			turn rbthigh to z-axis ((<2.912264> *animAmplitude)/100) speed ((<87.367919> *animAmplitude)/100) / animSpeed; //delta=-2.91
			turn rffoot to x-axis ((<24.236998> *animAmplitude)/100) speed ((<727.109940> *animAmplitude)/100) / animSpeed; //delta=-24.24
			turn rffoot to z-axis ((<-1.413493> *animAmplitude)/100) speed ((<42.404797> *animAmplitude)/100) / animSpeed; //delta=1.41
			turn rffoot to y-axis ((<0.612280> *animAmplitude)/100) speed ((<18.368395> *animAmplitude)/100) / animSpeed; //delta=0.61
			turn rfknee to x-axis ((<-7.870398> *animAmplitude)/100) speed ((<236.111939> *animAmplitude)/100) / animSpeed; //delta=7.87
			turn rfknee to z-axis ((<-0.806023> *animAmplitude)/100) speed ((<24.180675> *animAmplitude)/100) / animSpeed; //delta=0.81
			turn rfknee to y-axis ((<-0.565015> *animAmplitude)/100) speed ((<16.950463> *animAmplitude)/100) / animSpeed; //delta=-0.57
			turn rfshin to x-axis ((<2.269928> *animAmplitude)/100) speed ((<68.097840> *animAmplitude)/100) / animSpeed; //delta=-2.27
			turn rfshin to z-axis ((<-0.880305> *animAmplitude)/100) speed ((<26.409141> *animAmplitude)/100) / animSpeed; //delta=0.88
			turn rfshin to y-axis ((<-0.824357> *animAmplitude)/100) speed ((<24.730724> *animAmplitude)/100) / animSpeed; //delta=-0.82
			turn rfthigh to x-axis ((<-29.197686> *animAmplitude)/100) speed ((<875.930575> *animAmplitude)/100) / animSpeed; //delta=29.20
			turn rfthigh to z-axis ((<-0.788687> *animAmplitude)/100) speed ((<23.660615> *animAmplitude)/100) / animSpeed; //delta=0.79
			turn rfthigh to y-axis ((<-0.985651> *animAmplitude)/100) speed ((<29.569531> *animAmplitude)/100) / animSpeed; //delta=-0.99
			turn tail to x-axis ((<-3.562133> *animAmplitude)/100) speed ((<106.863996> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<0.380573> *animAmplitude)/100) speed ((<11.417184> *animAmplitude)/100) / animSpeed; //delta=-0.38
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		if (isMoving) { //Frame:8
			move body to x-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			move body to y-axis (((([-1.060000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.799998] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.06
			turn body to x-axis ((<2.0> *animAmplitude)/100) speed ((<89.999999> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<116.004134> *animAmplitude)/100) / animSpeed; //delta=3.87
			turn body to y-axis ((<-4.077731> *animAmplitude)/100) speed ((<122.331915> *animAmplitude)/100) / animSpeed; //delta=-4.08
			turn head to x-axis ((<2.995840> *animAmplitude)/100) speed ((<134.812803> *animAmplitude)/100) / animSpeed; //delta=-4.49
			turn head to z-axis ((<-0.0> *animAmplitude)/100) speed ((<89.875202> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn head to y-axis ((<4.957617> *animAmplitude)/100) speed ((<148.728518> *animAmplitude)/100) / animSpeed; //delta=4.96
			turn lbfoot to x-axis ((<-24.859732> *animAmplitude)/100) speed ((<714.649462> *animAmplitude)/100) / animSpeed; //delta=23.82
			turn lbfoot to z-axis ((<-3.599897> *animAmplitude)/100) speed ((<67.564919> *animAmplitude)/100) / animSpeed; //delta=2.25
			turn lbfoot to y-axis ((<-0.474821> *animAmplitude)/100) speed ((<13.776341> *animAmplitude)/100) / animSpeed; //delta=-0.46
			turn lbknee to x-axis ((<-14.484210> *animAmplitude)/100) speed ((<627.718354> *animAmplitude)/100) / animSpeed; //delta=20.92
			turn lbknee to z-axis ((<-5.071202> *animAmplitude)/100) speed ((<178.982714> *animAmplitude)/100) / animSpeed; //delta=5.97
			turn lbknee to y-axis ((<-1.230064> *animAmplitude)/100) speed ((<37.609687> *animAmplitude)/100) / animSpeed; //delta=-1.25
			turn lbshin to x-axis ((<3.676674> *animAmplitude)/100) speed ((<183.003372> *animAmplitude)/100) / animSpeed; //delta=-6.10
			turn lbshin to z-axis ((<1.682411> *animAmplitude)/100) speed ((<105.317832> *animAmplitude)/100) / animSpeed; //delta=-3.51
			turn lbshin to y-axis ((<1.939439> *animAmplitude)/100) speed ((<58.210693> *animAmplitude)/100) / animSpeed; //delta=1.94
			turn lbthigh to x-axis ((<33.598086> *animAmplitude)/100) speed ((<1067.320038> *animAmplitude)/100) / animSpeed; //delta=-35.58
			turn lbthigh to z-axis ((<8.108557> *animAmplitude)/100) speed ((<290.861070> *animAmplitude)/100) / animSpeed; //delta=-9.70
			turn lbthigh to y-axis ((<0.093900> *animAmplitude)/100) speed ((<4.105905> *animAmplitude)/100) / animSpeed; //delta=0.14
			turn lffoot to x-axis ((<-34.306172> *animAmplitude)/100) speed ((<275.497473> *animAmplitude)/100) / animSpeed; //delta=9.18
			turn lffoot to z-axis ((<0.927760> *animAmplitude)/100) speed ((<63.300723> *animAmplitude)/100) / animSpeed; //delta=-2.11
			turn lffoot to y-axis ((<0.219286> *animAmplitude)/100) speed ((<23.581756> *animAmplitude)/100) / animSpeed; //delta=0.79
			turn lfknee to x-axis ((<-39.915902> *animAmplitude)/100) speed ((<930.495599> *animAmplitude)/100) / animSpeed; //delta=31.02
			turn lfknee to z-axis ((<1.020293> *animAmplitude)/100) speed ((<52.297531> *animAmplitude)/100) / animSpeed; //delta=-1.74
			turn lfknee to y-axis ((<2.456786> *animAmplitude)/100) speed ((<63.735436> *animAmplitude)/100) / animSpeed; //delta=2.12
			turn lfshin to x-axis ((<19.099437> *animAmplitude)/100) speed ((<511.724658> *animAmplitude)/100) / animSpeed; //delta=-17.06
			turn lfshin to z-axis ((<-0.009587> *animAmplitude)/100) speed ((<19.321765> *animAmplitude)/100) / animSpeed; //delta=-0.64
			turn lfshin to y-axis ((<1.492077> *animAmplitude)/100) speed ((<25.742503> *animAmplitude)/100) / animSpeed; //delta=0.86
			turn lfthigh to x-axis ((<64.805026> *animAmplitude)/100) speed ((<955.590627> *animAmplitude)/100) / animSpeed; //delta=-31.85
			turn lfthigh to z-axis ((<3.088133> *animAmplitude)/100) speed ((<137.255663> *animAmplitude)/100) / animSpeed; //delta=-4.58
			turn lfthigh to y-axis ((<-1.854661> *animAmplitude)/100) speed ((<87.547426> *animAmplitude)/100) / animSpeed; //delta=-2.92
			turn rbfoot to x-axis ((<26.736267> *animAmplitude)/100) speed ((<901.424638> *animAmplitude)/100) / animSpeed; //delta=-30.05
			turn rbfoot to z-axis ((<-4.723036> *animAmplitude)/100) speed ((<133.772062> *animAmplitude)/100) / animSpeed; //delta=4.46
			turn rbfoot to y-axis ((<0.716476> *animAmplitude)/100) speed ((<22.815881> *animAmplitude)/100) / animSpeed; //delta=0.76
			turn rbknee to x-axis ((<-7.066819> *animAmplitude)/100) speed ((<902.972182> *animAmplitude)/100) / animSpeed; //delta=30.10
			turn rbknee to z-axis ((<-0.456288> *animAmplitude)/100) speed ((<244.085324> *animAmplitude)/100) / animSpeed; //delta=-8.14
			turn rbknee to y-axis ((<-1.862437> *animAmplitude)/100) speed ((<125.128526> *animAmplitude)/100) / animSpeed; //delta=-4.17
			turn rbshin to x-axis ((<1.043455> *animAmplitude)/100) speed ((<304.721854> *animAmplitude)/100) / animSpeed; //delta=-10.16
			turn rbshin to z-axis ((<-0.773325> *animAmplitude)/100) speed ((<68.847044> *animAmplitude)/100) / animSpeed; //delta=2.29
			turn rbshin to y-axis ((<3.164039> *animAmplitude)/100) speed ((<91.869360> *animAmplitude)/100) / animSpeed; //delta=3.06
			turn rbthigh to x-axis ((<-34.415834> *animAmplitude)/100) speed ((<740.447429> *animAmplitude)/100) / animSpeed; //delta=24.68
			turn rbthigh to z-axis ((<5.037037> *animAmplitude)/100) speed ((<63.743178> *animAmplitude)/100) / animSpeed; //delta=-2.12
			turn rbthigh to y-axis ((<3.624741> *animAmplitude)/100) speed ((<107.491344> *animAmplitude)/100) / animSpeed; //delta=3.58
			turn rffoot to x-axis ((<40.927928> *animAmplitude)/100) speed ((<500.727896> *animAmplitude)/100) / animSpeed; //delta=-16.69
			turn rffoot to z-axis ((<0.706088> *animAmplitude)/100) speed ((<63.587432> *animAmplitude)/100) / animSpeed; //delta=-2.12
			turn rffoot to y-axis ((<-0.889502> *animAmplitude)/100) speed ((<45.053440> *animAmplitude)/100) / animSpeed; //delta=-1.50
			turn rfknee to x-axis ((<-69.689561> *animAmplitude)/100) speed ((<1854.574884> *animAmplitude)/100) / animSpeed; //delta=61.82
			turn rfknee to z-axis ((<0.195723> *animAmplitude)/100) speed ((<30.052378> *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn rfknee to y-axis ((<0.840018> *animAmplitude)/100) speed ((<42.151010> *animAmplitude)/100) / animSpeed; //delta=1.41
			turn rfshin to x-axis ((<37.289141> *animAmplitude)/100) speed ((<1050.576395> *animAmplitude)/100) / animSpeed; //delta=-35.02
			turn rfshin to z-axis ((<-1.352237> *animAmplitude)/100) speed ((<14.157966> *animAmplitude)/100) / animSpeed; //delta=0.47
			turn rfshin to y-axis ((<2.624614> *animAmplitude)/100) speed ((<103.469136> *animAmplitude)/100) / animSpeed; //delta=3.45
			turn rfthigh to x-axis ((<-19.716915> *animAmplitude)/100) speed ((<284.423113> *animAmplitude)/100) / animSpeed; //delta=-9.48
			turn rfthigh to z-axis ((<-2.048593> *animAmplitude)/100) speed ((<37.797173> *animAmplitude)/100) / animSpeed; //delta=1.26
			turn rfthigh to y-axis ((<2.378334> *animAmplitude)/100) speed ((<100.919544> *animAmplitude)/100) / animSpeed; //delta=3.36
			turn tail to x-axis ((<7.124266> *animAmplitude)/100) speed ((<320.591987> *animAmplitude)/100) / animSpeed; //delta=-10.69
			turn tail to z-axis ((<-0.0> *animAmplitude)/100) speed ((<11.417184> *animAmplitude)/100) / animSpeed; //delta=0.38
			turn tail to y-axis ((<8.694870> *animAmplitude)/100) speed ((<260.846103> *animAmplitude)/100) / animSpeed; //delta=8.69
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:12
			move body to x-axis (((([1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			move body to y-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.799998] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.06
			turn body to x-axis ((<1.0> *animAmplitude)/100) speed ((<29.999997> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<-3.866804> *animAmplitude)/100) speed ((<116.004134> *animAmplitude)/100) / animSpeed; //delta=3.87
			turn body to y-axis ((<-6.116596> *animAmplitude)/100) speed ((<61.165970> *animAmplitude)/100) / animSpeed; //delta=-2.04
			turn head to x-axis ((<1.497920> *animAmplitude)/100) speed ((<44.937598> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<-2.995840> *animAmplitude)/100) speed ((<89.875202> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn head to y-axis ((<7.436426> *animAmplitude)/100) speed ((<74.364252> *animAmplitude)/100) / animSpeed; //delta=2.48
			turn lbfoot to x-axis ((<-21.961271> *animAmplitude)/100) speed ((<86.953824> *animAmplitude)/100) / animSpeed; //delta=-2.90
			turn lbknee to x-axis ((<-29.629408> *animAmplitude)/100) speed ((<454.355949> *animAmplitude)/100) / animSpeed; //delta=15.15
			turn lbknee to z-axis ((<-11.257854> *animAmplitude)/100) speed ((<185.599552> *animAmplitude)/100) / animSpeed; //delta=6.19
			turn lbknee to y-axis ((<-3.522808> *animAmplitude)/100) speed ((<68.782318> *animAmplitude)/100) / animSpeed; //delta=-2.29
			turn lbshin to x-axis ((<18.696017> *animAmplitude)/100) speed ((<450.580293> *animAmplitude)/100) / animSpeed; //delta=-15.02
			turn lbshin to z-axis ((<5.236239> *animAmplitude)/100) speed ((<106.614840> *animAmplitude)/100) / animSpeed; //delta=-3.55
			turn lbshin to y-axis ((<1.768294> *animAmplitude)/100) speed ((<5.134350> *animAmplitude)/100) / animSpeed; //delta=-0.17
			turn lbthigh to x-axis ((<60.173646> *animAmplitude)/100) speed ((<797.266774> *animAmplitude)/100) / animSpeed; //delta=-26.58
			turn lbthigh to z-axis ((<22.036253> *animAmplitude)/100) speed ((<417.830872> *animAmplitude)/100) / animSpeed; //delta=-13.93
			turn lbthigh to y-axis ((<-9.153623> *animAmplitude)/100) speed ((<277.425684> *animAmplitude)/100) / animSpeed; //delta=-9.25
			turn lffoot to x-axis ((<-26.697937> *animAmplitude)/100) speed ((<228.247044> *animAmplitude)/100) / animSpeed; //delta=-7.61
			turn lffoot to z-axis ((<3.584558> *animAmplitude)/100) speed ((<79.703928> *animAmplitude)/100) / animSpeed; //delta=-2.66
			turn lffoot to y-axis ((<1.333322> *animAmplitude)/100) speed ((<33.421079> *animAmplitude)/100) / animSpeed; //delta=1.11
			turn lfknee to x-axis ((<9.141045> *animAmplitude)/100) speed ((<1471.708399> *animAmplitude)/100) / animSpeed; //delta=-49.06
			turn lfknee to y-axis ((<0.505641> *animAmplitude)/100) speed ((<58.534359> *animAmplitude)/100) / animSpeed; //delta=-1.95
			turn lfshin to x-axis ((<0.030490> *animAmplitude)/100) speed ((<572.068428> *animAmplitude)/100) / animSpeed; //delta=19.07
			turn lfshin to z-axis ((<1.267234> *animAmplitude)/100) speed ((<38.304617> *animAmplitude)/100) / animSpeed; //delta=-1.28
			turn lfshin to y-axis ((<1.317575> *animAmplitude)/100) speed ((<5.235068> *animAmplitude)/100) / animSpeed; //delta=-0.17
			turn lfthigh to x-axis ((<33.373527> *animAmplitude)/100) speed ((<942.944976> *animAmplitude)/100) / animSpeed; //delta=31.43
			turn lfthigh to z-axis ((<1.128406> *animAmplitude)/100) speed ((<58.791812> *animAmplitude)/100) / animSpeed; //delta=1.96
			turn lfthigh to y-axis ((<0.649488> *animAmplitude)/100) speed ((<75.124494> *animAmplitude)/100) / animSpeed; //delta=2.50
			turn rbfoot to x-axis ((<33.478186> *animAmplitude)/100) speed ((<202.257577> *animAmplitude)/100) / animSpeed; //delta=-6.74
			turn rbfoot to z-axis ((<-5.540730> *animAmplitude)/100) speed ((<24.530821> *animAmplitude)/100) / animSpeed; //delta=0.82
			turn rbfoot to y-axis ((<0.294394> *animAmplitude)/100) speed ((<12.662476> *animAmplitude)/100) / animSpeed; //delta=-0.42
			turn rbknee to x-axis ((<-58.510952> *animAmplitude)/100) speed ((<1543.323983> *animAmplitude)/100) / animSpeed; //delta=51.44
			turn rbknee to z-axis ((<25.600227> *animAmplitude)/100) speed ((<781.695435> *animAmplitude)/100) / animSpeed; //delta=-26.06
			turn rbknee to y-axis ((<12.556452> *animAmplitude)/100) speed ((<432.566650> *animAmplitude)/100) / animSpeed; //delta=14.42
			turn rbshin to x-axis ((<28.916415> *animAmplitude)/100) speed ((<836.188796> *animAmplitude)/100) / animSpeed; //delta=-27.87
			turn rbshin to z-axis ((<-12.455048> *animAmplitude)/100) speed ((<350.451676> *animAmplitude)/100) / animSpeed; //delta=11.68
			turn rbshin to y-axis ((<8.998483> *animAmplitude)/100) speed ((<175.033328> *animAmplitude)/100) / animSpeed; //delta=5.83
			turn rbthigh to x-axis ((<-21.850043> *animAmplitude)/100) speed ((<376.973730> *animAmplitude)/100) / animSpeed; //delta=-12.57
			turn rbthigh to z-axis ((<-0.930080> *animAmplitude)/100) speed ((<179.013490> *animAmplitude)/100) / animSpeed; //delta=5.97
			turn rbthigh to y-axis ((<6.373171> *animAmplitude)/100) speed ((<82.452904> *animAmplitude)/100) / animSpeed; //delta=2.75
			turn rffoot to x-axis ((<30.815577> *animAmplitude)/100) speed ((<303.370536> *animAmplitude)/100) / animSpeed; //delta=10.11
			turn rffoot to z-axis ((<2.988306> *animAmplitude)/100) speed ((<68.466537> *animAmplitude)/100) / animSpeed; //delta=-2.28
			turn rffoot to y-axis ((<-1.712992> *animAmplitude)/100) speed ((<24.704725> *animAmplitude)/100) / animSpeed; //delta=-0.82
			turn rfknee to x-axis ((<-21.106229> *animAmplitude)/100) speed ((<1457.499958> *animAmplitude)/100) / animSpeed; //delta=-48.58
			turn rfknee to y-axis ((<1.535184> *animAmplitude)/100) speed ((<20.854975> *animAmplitude)/100) / animSpeed; //delta=0.70
			turn rfshin to x-axis ((<12.093260> *animAmplitude)/100) speed ((<755.876442> *animAmplitude)/100) / animSpeed; //delta=25.20
			turn rfshin to z-axis ((<0.216269> *animAmplitude)/100) speed ((<47.055189> *animAmplitude)/100) / animSpeed; //delta=-1.57
			turn rfshin to y-axis ((<3.642081> *animAmplitude)/100) speed ((<30.524017> *animAmplitude)/100) / animSpeed; //delta=1.02
			turn rfthigh to x-axis ((<-22.324851> *animAmplitude)/100) speed ((<78.238058> *animAmplitude)/100) / animSpeed; //delta=2.61
			turn rfthigh to z-axis ((<-1.682249> *animAmplitude)/100) speed ((<10.990305> *animAmplitude)/100) / animSpeed; //delta=-0.37
			turn rfthigh to y-axis ((<3.163278> *animAmplitude)/100) speed ((<23.548317> *animAmplitude)/100) / animSpeed; //delta=0.78
			turn tail to x-axis ((<3.562134> *animAmplitude)/100) speed ((<106.863983> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<-0.380573> *animAmplitude)/100) speed ((<11.417184> *animAmplitude)/100) / animSpeed; //delta=0.38
			turn tail to y-axis ((<13.042306> *animAmplitude)/100) speed ((<130.423077> *animAmplitude)/100) / animSpeed; //delta=4.35
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:16
			move body to x-axis (((([1.650000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([19.499999] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.65
			move body to y-axis (((([1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to x-axis ((<-0.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<-5.800206> *animAmplitude)/100) speed ((<58.002060> *animAmplitude)/100) / animSpeed; //delta=1.93
			turn body to y-axis ((<-4.077731> *animAmplitude)/100) speed ((<61.165970> *animAmplitude)/100) / animSpeed; //delta=2.04
			turn head to x-axis ((<-0.0> *animAmplitude)/100) speed ((<44.937604> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<-4.493760> *animAmplitude)/100) speed ((<44.937595> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to y-axis ((<4.957617> *animAmplitude)/100) speed ((<74.364252> *animAmplitude)/100) / animSpeed; //delta=-2.48
			turn lbfoot to x-axis ((<-23.380246> *animAmplitude)/100) speed ((<42.569256> *animAmplitude)/100) / animSpeed; //delta=1.42
			turn lbfoot to z-axis ((<-2.591650> *animAmplitude)/100) speed ((<27.631607> *animAmplitude)/100) / animSpeed; //delta=-0.92
			turn lbfoot to y-axis ((<-0.004638> *animAmplitude)/100) speed ((<13.175163> *animAmplitude)/100) / animSpeed; //delta=0.44
			turn lbknee to x-axis ((<4.734891> *animAmplitude)/100) speed ((<1030.928976> *animAmplitude)/100) / animSpeed; //delta=-34.36
			turn lbknee to z-axis ((<1.040695> *animAmplitude)/100) speed ((<368.956469> *animAmplitude)/100) / animSpeed; //delta=-12.30
			turn lbknee to y-axis ((<-1.794294> *animAmplitude)/100) speed ((<51.855402> *animAmplitude)/100) / animSpeed; //delta=1.73
			turn lbshin to x-axis ((<2.003211> *animAmplitude)/100) speed ((<500.784187> *animAmplitude)/100) / animSpeed; //delta=16.69
			turn lbshin to z-axis ((<1.253112> *animAmplitude)/100) speed ((<119.493808> *animAmplitude)/100) / animSpeed; //delta=3.98
			turn lbshin to y-axis ((<1.263583> *animAmplitude)/100) speed ((<15.141306> *animAmplitude)/100) / animSpeed; //delta=-0.50
			turn lbthigh to x-axis ((<33.303961> *animAmplitude)/100) speed ((<806.090525> *animAmplitude)/100) / animSpeed; //delta=26.87
			turn lbthigh to z-axis ((<7.521609> *animAmplitude)/100) speed ((<435.439313> *animAmplitude)/100) / animSpeed; //delta=14.51
			turn lbthigh to y-axis ((<-0.242445> *animAmplitude)/100) speed ((<267.335342> *animAmplitude)/100) / animSpeed; //delta=8.91
			turn lffoot to x-axis ((<-4.322329> *animAmplitude)/100) speed ((<671.268264> *animAmplitude)/100) / animSpeed; //delta=-22.38
			turn lffoot to y-axis ((<0.185484> *animAmplitude)/100) speed ((<34.435119> *animAmplitude)/100) / animSpeed; //delta=-1.15
			turn lfknee to x-axis ((<16.490747> *animAmplitude)/100) speed ((<220.491082> *animAmplitude)/100) / animSpeed; //delta=-7.35
			turn lfknee to z-axis ((<1.201714> *animAmplitude)/100) speed ((<7.519571> *animAmplitude)/100) / animSpeed; //delta=-0.25
			turn lfknee to y-axis ((<-0.419719> *animAmplitude)/100) speed ((<27.760802> *animAmplitude)/100) / animSpeed; //delta=-0.93
			turn lfshin to x-axis ((<-6.914445> *animAmplitude)/100) speed ((<208.348031> *animAmplitude)/100) / animSpeed; //delta=6.94
			turn lfshin to z-axis ((<2.276372> *animAmplitude)/100) speed ((<30.274164> *animAmplitude)/100) / animSpeed; //delta=-1.01
			turn lfshin to y-axis ((<1.978898> *animAmplitude)/100) speed ((<19.839701> *animAmplitude)/100) / animSpeed; //delta=0.66
			turn lfthigh to x-axis ((<-4.860828> *animAmplitude)/100) speed ((<1147.030644> *animAmplitude)/100) / animSpeed; //delta=38.23
			turn lfthigh to z-axis ((<-0.828749> *animAmplitude)/100) speed ((<58.714669> *animAmplitude)/100) / animSpeed; //delta=1.96
			turn lfthigh to y-axis ((<1.867426> *animAmplitude)/100) speed ((<36.538136> *animAmplitude)/100) / animSpeed; //delta=1.22
			turn rbfoot to x-axis ((<29.170604> *animAmplitude)/100) speed ((<129.227452> *animAmplitude)/100) / animSpeed; //delta=4.31
			turn rbfoot to z-axis ((<-2.505467> *animAmplitude)/100) speed ((<91.057866> *animAmplitude)/100) / animSpeed; //delta=-3.04
			turn rbfoot to y-axis ((<-0.639718> *animAmplitude)/100) speed ((<28.023366> *animAmplitude)/100) / animSpeed; //delta=-0.93
			turn rbknee to x-axis ((<-20.903801> *animAmplitude)/100) speed ((<1128.214540> *animAmplitude)/100) / animSpeed; //delta=-37.61
			turn rbknee to z-axis ((<6.376539> *animAmplitude)/100) speed ((<576.710634> *animAmplitude)/100) / animSpeed; //delta=19.22
			turn rbknee to y-axis ((<0.889317> *animAmplitude)/100) speed ((<350.014028> *animAmplitude)/100) / animSpeed; //delta=-11.67
			turn rbshin to x-axis ((<11.967063> *animAmplitude)/100) speed ((<508.480579> *animAmplitude)/100) / animSpeed; //delta=16.95
			turn rbshin to z-axis ((<-2.952427> *animAmplitude)/100) speed ((<285.078626> *animAmplitude)/100) / animSpeed; //delta=-9.50
			turn rbshin to y-axis ((<4.817362> *animAmplitude)/100) speed ((<125.433637> *animAmplitude)/100) / animSpeed; //delta=-4.18
			turn rbthigh to x-axis ((<-20.199175> *animAmplitude)/100) speed ((<49.526060> *animAmplitude)/100) / animSpeed; //delta=-1.65
			turn rbthigh to z-axis ((<3.102549> *animAmplitude)/100) speed ((<120.978862> *animAmplitude)/100) / animSpeed; //delta=-4.03
			turn rbthigh to y-axis ((<4.027966> *animAmplitude)/100) speed ((<70.356169> *animAmplitude)/100) / animSpeed; //delta=-2.35
			turn rffoot to x-axis ((<1.636001> *animAmplitude)/100) speed ((<875.387268> *animAmplitude)/100) / animSpeed; //delta=29.18
			turn rffoot to y-axis ((<-0.042792> *animAmplitude)/100) speed ((<50.106012> *animAmplitude)/100) / animSpeed; //delta=1.67
			turn rfknee to x-axis ((<1.285734> *animAmplitude)/100) speed ((<671.758882> *animAmplitude)/100) / animSpeed; //delta=-22.39
			turn rfknee to z-axis ((<1.089608> *animAmplitude)/100) speed ((<27.017732> *animAmplitude)/100) / animSpeed; //delta=-0.90
			turn rfknee to y-axis ((<0.507852> *animAmplitude)/100) speed ((<30.819952> *animAmplitude)/100) / animSpeed; //delta=-1.03
			turn rfshin to x-axis ((<-0.244249> *animAmplitude)/100) speed ((<370.125261> *animAmplitude)/100) / animSpeed; //delta=12.34
			turn rfshin to z-axis ((<1.710951> *animAmplitude)/100) speed ((<44.840438> *animAmplitude)/100) / animSpeed; //delta=-1.49
			turn rfshin to y-axis ((<1.860021> *animAmplitude)/100) speed ((<53.461812> *animAmplitude)/100) / animSpeed; //delta=-1.78
			turn rfthigh to x-axis ((<-2.298727> *animAmplitude)/100) speed ((<600.783708> *animAmplitude)/100) / animSpeed; //delta=-20.03
			turn rfthigh to z-axis ((<0.011521> *animAmplitude)/100) speed ((<50.813125> *animAmplitude)/100) / animSpeed; //delta=-1.69
			turn rfthigh to y-axis ((<1.809004> *animAmplitude)/100) speed ((<40.628204> *animAmplitude)/100) / animSpeed; //delta=-1.35
			turn tail to x-axis ((<-0.0> *animAmplitude)/100) speed ((<106.864009> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<-0.570859> *animAmplitude)/100) speed ((<5.708584> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn tail to y-axis ((<8.694870> *animAmplitude)/100) speed ((<130.423077> *animAmplitude)/100) / animSpeed; //delta=-4.35
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:20
			move body to x-axis (((([0.990000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([19.800001] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-0.66
			move body to y-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn body to x-axis ((<-1.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<-3.866804> *animAmplitude)/100) speed ((<58.002060> *animAmplitude)/100) / animSpeed; //delta=-1.93
			turn body to y-axis ((<0.0> *animAmplitude)/100) speed ((<122.331915> *animAmplitude)/100) / animSpeed; //delta=4.08
			turn head to x-axis ((<-1.497920> *animAmplitude)/100) speed ((<44.937601> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<-2.995840> *animAmplitude)/100) speed ((<44.937595> *animAmplitude)/100) / animSpeed; //delta=-1.50
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<148.728518> *animAmplitude)/100) / animSpeed; //delta=-4.96
			turn lbfoot to x-axis ((<-3.324097> *animAmplitude)/100) speed ((<601.684467> *animAmplitude)/100) / animSpeed; //delta=-20.06
			turn lbfoot to z-axis ((<0.243361> *animAmplitude)/100) speed ((<85.050336> *animAmplitude)/100) / animSpeed; //delta=-2.84
			turn lbknee to x-axis ((<23.098043> *animAmplitude)/100) speed ((<550.894581> *animAmplitude)/100) / animSpeed; //delta=-18.36
			turn lbknee to z-axis ((<8.620271> *animAmplitude)/100) speed ((<227.387279> *animAmplitude)/100) / animSpeed; //delta=-7.58
			turn lbknee to y-axis ((<-2.311568> *animAmplitude)/100) speed ((<15.518230> *animAmplitude)/100) / animSpeed; //delta=-0.52
			turn lbshin to x-axis ((<-9.139291> *animAmplitude)/100) speed ((<334.275057> *animAmplitude)/100) / animSpeed; //delta=11.14
			turn lbshin to z-axis ((<-1.533213> *animAmplitude)/100) speed ((<83.589759> *animAmplitude)/100) / animSpeed; //delta=2.79
			turn lbshin to y-axis ((<-0.107527> *animAmplitude)/100) speed ((<41.133319> *animAmplitude)/100) / animSpeed; //delta=-1.37
			turn lbthigh to x-axis ((<-9.761825> *animAmplitude)/100) speed ((<1291.973593> *animAmplitude)/100) / animSpeed; //delta=43.07
			turn lbthigh to z-axis ((<-2.905786> *animAmplitude)/100) speed ((<312.821855> *animAmplitude)/100) / animSpeed; //delta=10.43
			turn lbthigh to y-axis ((<-0.043304> *animAmplitude)/100) speed ((<5.974247> *animAmplitude)/100) / animSpeed; //delta=0.20
			turn lffoot to x-axis ((<24.237227> *animAmplitude)/100) speed ((<856.786660> *animAmplitude)/100) / animSpeed; //delta=-28.56
			turn lffoot to z-axis ((<1.397348> *animAmplitude)/100) speed ((<66.550667> *animAmplitude)/100) / animSpeed; //delta=2.22
			turn lffoot to y-axis ((<-0.607392> *animAmplitude)/100) speed ((<23.786277> *animAmplitude)/100) / animSpeed; //delta=-0.79
			turn lfknee to x-axis ((<-7.868760> *animAmplitude)/100) speed ((<730.785230> *animAmplitude)/100) / animSpeed; //delta=24.36
			turn lfknee to z-axis ((<0.809995> *animAmplitude)/100) speed ((<11.751566> *animAmplitude)/100) / animSpeed; //delta=0.39
			turn lfknee to y-axis ((<0.572576> *animAmplitude)/100) speed ((<29.768860> *animAmplitude)/100) / animSpeed; //delta=0.99
			turn lfshin to x-axis ((<2.268865> *animAmplitude)/100) speed ((<275.499285> *animAmplitude)/100) / animSpeed; //delta=-9.18
			turn lfshin to z-axis ((<0.878348> *animAmplitude)/100) speed ((<41.940729> *animAmplitude)/100) / animSpeed; //delta=1.40
			turn lfshin to y-axis ((<0.817516> *animAmplitude)/100) speed ((<34.841476> *animAmplitude)/100) / animSpeed; //delta=-1.16
			turn lfthigh to x-axis ((<-29.198553> *animAmplitude)/100) speed ((<730.131760> *animAmplitude)/100) / animSpeed; //delta=24.34
			turn lfthigh to z-axis ((<0.802387> *animAmplitude)/100) speed ((<48.934085> *animAmplitude)/100) / animSpeed; //delta=-1.63
			turn lfthigh to y-axis ((<0.985494> *animAmplitude)/100) speed ((<26.457975> *animAmplitude)/100) / animSpeed; //delta=-0.88
			turn rbfoot to x-axis ((<-1.026945> *animAmplitude)/100) speed ((<905.926473> *animAmplitude)/100) / animSpeed; //delta=30.20
			turn rbfoot to z-axis ((<1.328951> *animAmplitude)/100) speed ((<115.032560> *animAmplitude)/100) / animSpeed; //delta=-3.83
			turn rbfoot to y-axis ((<0.015189> *animAmplitude)/100) speed ((<19.647219> *animAmplitude)/100) / animSpeed; //delta=0.65
			turn rbknee to x-axis ((<6.371076> *animAmplitude)/100) speed ((<818.246311> *animAmplitude)/100) / animSpeed; //delta=-27.27
			turn rbknee to z-axis ((<-0.871396> *animAmplitude)/100) speed ((<217.438049> *animAmplitude)/100) / animSpeed; //delta=7.25
			turn rbknee to y-axis ((<-0.015567> *animAmplitude)/100) speed ((<27.146516> *animAmplitude)/100) / animSpeed; //delta=-0.90
			turn rbshin to x-axis ((<-2.394824> *animAmplitude)/100) speed ((<430.856591> *animAmplitude)/100) / animSpeed; //delta=14.36
			turn rbshin to z-axis ((<1.815340> *animAmplitude)/100) speed ((<143.033023> *animAmplitude)/100) / animSpeed; //delta=-4.77
			turn rbshin to y-axis ((<-0.003950> *animAmplitude)/100) speed ((<144.639360> *animAmplitude)/100) / animSpeed; //delta=-4.82
			turn rbthigh to x-axis ((<-1.950509> *animAmplitude)/100) speed ((<547.459958> *animAmplitude)/100) / animSpeed; //delta=-18.25
			turn rbthigh to z-axis ((<1.594336> *animAmplitude)/100) speed ((<45.246378> *animAmplitude)/100) / animSpeed; //delta=1.51
			turn rbthigh to y-axis ((<0.038383> *animAmplitude)/100) speed ((<119.687497> *animAmplitude)/100) / animSpeed; //delta=-3.99
			turn rffoot to x-axis ((<-25.123502> *animAmplitude)/100) speed ((<802.785089> *animAmplitude)/100) / animSpeed; //delta=26.76
			turn rffoot to z-axis ((<1.166373> *animAmplitude)/100) speed ((<52.677711> *animAmplitude)/100) / animSpeed; //delta=1.76
			turn rffoot to y-axis ((<0.561813> *animAmplitude)/100) speed ((<18.138139> *animAmplitude)/100) / animSpeed; //delta=0.60
			turn rfknee to x-axis ((<-8.897785> *animAmplitude)/100) speed ((<305.505560> *animAmplitude)/100) / animSpeed; //delta=10.18
			turn rfknee to z-axis ((<0.726907> *animAmplitude)/100) speed ((<10.881040> *animAmplitude)/100) / animSpeed; //delta=0.36
			turn rfknee to y-axis ((<-0.322356> *animAmplitude)/100) speed ((<24.906255> *animAmplitude)/100) / animSpeed; //delta=-0.83
			turn rfshin to x-axis ((<2.041561> *animAmplitude)/100) speed ((<68.574306> *animAmplitude)/100) / animSpeed; //delta=-2.29
			turn rfshin to z-axis ((<0.652493> *animAmplitude)/100) speed ((<31.753717> *animAmplitude)/100) / animSpeed; //delta=1.06
			turn rfshin to y-axis ((<-0.636492> *animAmplitude)/100) speed ((<74.895371> *animAmplitude)/100) / animSpeed; //delta=-2.50
			turn rfthigh to x-axis ((<32.951203> *animAmplitude)/100) speed ((<1057.497891> *animAmplitude)/100) / animSpeed; //delta=-35.25
			turn rfthigh to z-axis ((<1.505538> *animAmplitude)/100) speed ((<44.820493> *animAmplitude)/100) / animSpeed; //delta=-1.49
			turn rfthigh to y-axis ((<-1.076057> *animAmplitude)/100) speed ((<86.551840> *animAmplitude)/100) / animSpeed; //delta=-2.89
			turn tail to x-axis ((<-3.562133> *animAmplitude)/100) speed ((<106.863996> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<-0.380573> *animAmplitude)/100) speed ((<5.708584> *animAmplitude)/100) / animSpeed; //delta=-0.19
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<260.846103> *animAmplitude)/100) / animSpeed; //delta=-8.69
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:24
			move body to x-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([29.699998] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-0.99
			move body to y-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn body to x-axis ((<2.0> *animAmplitude)/100) speed ((<89.999999> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<116.004134> *animAmplitude)/100) / animSpeed; //delta=-3.87
			turn body to y-axis ((<4.077731> *animAmplitude)/100) speed ((<122.331915> *animAmplitude)/100) / animSpeed; //delta=4.08
			turn head to x-axis ((<2.995840> *animAmplitude)/100) speed ((<134.812803> *animAmplitude)/100) / animSpeed; //delta=-4.49
			turn head to z-axis ((<-0.0> *animAmplitude)/100) speed ((<89.875202> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn head to y-axis ((<-4.957617> *animAmplitude)/100) speed ((<148.728518> *animAmplitude)/100) / animSpeed; //delta=-4.96
			turn lbfoot to x-axis ((<26.664656> *animAmplitude)/100) speed ((<899.662590> *animAmplitude)/100) / animSpeed; //delta=-29.99
			turn lbfoot to z-axis ((<4.841198> *animAmplitude)/100) speed ((<137.935095> *animAmplitude)/100) / animSpeed; //delta=-4.60
			turn lbfoot to y-axis ((<-0.754674> *animAmplitude)/100) speed ((<23.940607> *animAmplitude)/100) / animSpeed; //delta=-0.80
			turn lbknee to x-axis ((<-7.391590> *animAmplitude)/100) speed ((<914.688996> *animAmplitude)/100) / animSpeed; //delta=30.49
			turn lbknee to z-axis ((<0.320859> *animAmplitude)/100) speed ((<248.982355> *animAmplitude)/100) / animSpeed; //delta=8.30
			turn lbknee to y-axis ((<1.803597> *animAmplitude)/100) speed ((<123.454958> *animAmplitude)/100) / animSpeed; //delta=4.12
			turn lbshin to x-axis ((<1.195198> *animAmplitude)/100) speed ((<310.034664> *animAmplitude)/100) / animSpeed; //delta=-10.33
			turn lbshin to z-axis ((<0.842451> *animAmplitude)/100) speed ((<71.269930> *animAmplitude)/100) / animSpeed; //delta=-2.38
			turn lbshin to y-axis ((<-3.108542> *animAmplitude)/100) speed ((<90.030457> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn lbthigh to x-axis ((<-34.181463> *animAmplitude)/100) speed ((<732.589143> *animAmplitude)/100) / animSpeed; //delta=24.42
			turn lbthigh to z-axis ((<-5.066657> *animAmplitude)/100) speed ((<64.826130> *animAmplitude)/100) / animSpeed; //delta=2.16
			turn lbthigh to y-axis ((<-3.612230> *animAmplitude)/100) speed ((<107.067796> *animAmplitude)/100) / animSpeed; //delta=-3.57
			turn lffoot to x-axis ((<40.844405> *animAmplitude)/100) speed ((<498.215342> *animAmplitude)/100) / animSpeed; //delta=-16.61
			turn lffoot to z-axis ((<-0.700844> *animAmplitude)/100) speed ((<62.945759> *animAmplitude)/100) / animSpeed; //delta=2.10
			turn lffoot to y-axis ((<0.885078> *animAmplitude)/100) speed ((<44.774088> *animAmplitude)/100) / animSpeed; //delta=1.49
			turn lfknee to x-axis ((<-70.030940> *animAmplitude)/100) speed ((<1864.865400> *animAmplitude)/100) / animSpeed; //delta=62.16
			turn lfknee to z-axis ((<-0.214728> *animAmplitude)/100) speed ((<30.741691> *animAmplitude)/100) / animSpeed; //delta=1.02
			turn lfknee to y-axis ((<-0.857447> *animAmplitude)/100) speed ((<42.900701> *animAmplitude)/100) / animSpeed; //delta=-1.43
			turn lfshin to x-axis ((<37.509644> *animAmplitude)/100) speed ((<1057.223362> *animAmplitude)/100) / animSpeed; //delta=-35.24
			turn lfshin to z-axis ((<1.360892> *animAmplitude)/100) speed ((<14.476303> *animAmplitude)/100) / animSpeed; //delta=-0.48
			turn lfshin to y-axis ((<-2.629483> *animAmplitude)/100) speed ((<103.409965> *animAmplitude)/100) / animSpeed; //delta=-3.45
			turn lfthigh to x-axis ((<-19.512804> *animAmplitude)/100) speed ((<290.572486> *animAmplitude)/100) / animSpeed; //delta=-9.69
			turn lfthigh to z-axis ((<2.045857> *animAmplitude)/100) speed ((<37.304098> *animAmplitude)/100) / animSpeed; //delta=-1.24
			turn lfthigh to y-axis ((<-2.385612> *animAmplitude)/100) speed ((<101.133184> *animAmplitude)/100) / animSpeed; //delta=-3.37
			turn rbfoot to x-axis ((<-24.829228> *animAmplitude)/100) speed ((<714.068500> *animAmplitude)/100) / animSpeed; //delta=23.80
			turn rbfoot to z-axis ((<3.483464> *animAmplitude)/100) speed ((<64.635376> *animAmplitude)/100) / animSpeed; //delta=-2.15
			turn rbfoot to y-axis ((<0.439199> *animAmplitude)/100) speed ((<12.720315> *animAmplitude)/100) / animSpeed; //delta=0.42
			turn rbknee to x-axis ((<-14.556197> *animAmplitude)/100) speed ((<627.818195> *animAmplitude)/100) / animSpeed; //delta=20.93
			turn rbknee to z-axis ((<5.124900> *animAmplitude)/100) speed ((<179.888866> *animAmplitude)/100) / animSpeed; //delta=-6.00
			turn rbknee to y-axis ((<1.301417> *animAmplitude)/100) speed ((<39.509510> *animAmplitude)/100) / animSpeed; //delta=1.32
			turn rbshin to x-axis ((<3.719969> *animAmplitude)/100) speed ((<183.443797> *animAmplitude)/100) / animSpeed; //delta=-6.11
			turn rbshin to z-axis ((<-1.701824> *animAmplitude)/100) speed ((<105.514942> *animAmplitude)/100) / animSpeed; //delta=3.52
			turn rbshin to y-axis ((<-1.956256> *animAmplitude)/100) speed ((<58.569184> *animAmplitude)/100) / animSpeed; //delta=-1.95
			turn rbthigh to x-axis ((<33.609981> *animAmplitude)/100) speed ((<1066.814715> *animAmplitude)/100) / animSpeed; //delta=-35.56
			turn rbthigh to z-axis ((<-7.984101> *animAmplitude)/100) speed ((<287.353120> *animAmplitude)/100) / animSpeed; //delta=9.58
			turn rbthigh to y-axis ((<-0.181190> *animAmplitude)/100) speed ((<6.587178> *animAmplitude)/100) / animSpeed; //delta=-0.22
			turn rffoot to x-axis ((<-34.231481> *animAmplitude)/100) speed ((<273.239361> *animAmplitude)/100) / animSpeed; //delta=9.11
			turn rffoot to z-axis ((<-0.924000> *animAmplitude)/100) speed ((<62.711183> *animAmplitude)/100) / animSpeed; //delta=2.09
			turn rffoot to y-axis ((<-0.218205> *animAmplitude)/100) speed ((<23.400526> *animAmplitude)/100) / animSpeed; //delta=-0.78
			turn rfknee to x-axis ((<-40.171597> *animAmplitude)/100) speed ((<938.214370> *animAmplitude)/100) / animSpeed; //delta=31.27
			turn rfknee to z-axis ((<-1.028318> *animAmplitude)/100) speed ((<52.656752> *animAmplitude)/100) / animSpeed; //delta=1.76
			turn rfknee to y-axis ((<-2.464582> *animAmplitude)/100) speed ((<64.266767> *animAmplitude)/100) / animSpeed; //delta=-2.14
			turn rfshin to x-axis ((<19.235689> *animAmplitude)/100) speed ((<515.823841> *animAmplitude)/100) / animSpeed; //delta=-17.19
			turn rfshin to z-axis ((<0.013050> *animAmplitude)/100) speed ((<19.183291> *animAmplitude)/100) / animSpeed; //delta=0.64
			turn rfshin to y-axis ((<-1.491211> *animAmplitude)/100) speed ((<25.641586> *animAmplitude)/100) / animSpeed; //delta=-0.85
			turn rfthigh to x-axis ((<64.849696> *animAmplitude)/100) speed ((<956.954787> *animAmplitude)/100) / animSpeed; //delta=-31.90
			turn rfthigh to z-axis ((<-3.090682> *animAmplitude)/100) speed ((<137.886593> *animAmplitude)/100) / animSpeed; //delta=4.60
			turn rfthigh to y-axis ((<1.857428> *animAmplitude)/100) speed ((<88.004564> *animAmplitude)/100) / animSpeed; //delta=2.93
			turn tail to x-axis ((<7.124266> *animAmplitude)/100) speed ((<320.591987> *animAmplitude)/100) / animSpeed; //delta=-10.69
			turn tail to z-axis ((<-0.0> *animAmplitude)/100) speed ((<11.417184> *animAmplitude)/100) / animSpeed; //delta=-0.38
			turn tail to y-axis ((<-8.694870> *animAmplitude)/100) speed ((<260.846103> *animAmplitude)/100) / animSpeed; //delta=-8.69
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:28
			move body to x-axis (((([-1.069000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([32.070000] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.07
			move body to y-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.0] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to x-axis ((<1.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<3.866804> *animAmplitude)/100) speed ((<116.004134> *animAmplitude)/100) / animSpeed; //delta=-3.87
			turn body to y-axis ((<6.116596> *animAmplitude)/100) speed ((<61.165970> *animAmplitude)/100) / animSpeed; //delta=2.04
			turn head to x-axis ((<1.497920> *animAmplitude)/100) speed ((<44.937604> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<2.995840> *animAmplitude)/100) speed ((<89.875202> *animAmplitude)/100) / animSpeed; //delta=-3.00
			turn head to y-axis ((<-7.436426> *animAmplitude)/100) speed ((<74.364252> *animAmplitude)/100) / animSpeed; //delta=-2.48
			turn lbfoot to x-axis ((<33.452173> *animAmplitude)/100) speed ((<203.625527> *animAmplitude)/100) / animSpeed; //delta=-6.79
			turn lbfoot to z-axis ((<5.592863> *animAmplitude)/100) speed ((<22.549972> *animAmplitude)/100) / animSpeed; //delta=-0.75
			turn lbfoot to y-axis ((<-0.317945> *animAmplitude)/100) speed ((<13.101864> *animAmplitude)/100) / animSpeed; //delta=0.44
			turn lbknee to x-axis ((<-58.564146> *animAmplitude)/100) speed ((<1535.176677> *animAmplitude)/100) / animSpeed; //delta=51.17
			turn lbknee to z-axis ((<-25.701087> *animAmplitude)/100) speed ((<780.658365> *animAmplitude)/100) / animSpeed; //delta=26.02
			turn lbknee to y-axis ((<-12.657402> *animAmplitude)/100) speed ((<433.829958> *animAmplitude)/100) / animSpeed; //delta=-14.46
			turn lbshin to x-axis ((<28.960405> *animAmplitude)/100) speed ((<832.956214> *animAmplitude)/100) / animSpeed; //delta=-27.77
			turn lbshin to z-axis ((<12.466458> *animAmplitude)/100) speed ((<348.720202> *animAmplitude)/100) / animSpeed; //delta=-11.62
			turn lbshin to y-axis ((<-8.977982> *animAmplitude)/100) speed ((<176.083195> *animAmplitude)/100) / animSpeed; //delta=-5.87
			turn lbthigh to x-axis ((<-21.801877> *animAmplitude)/100) speed ((<371.387592> *animAmplitude)/100) / animSpeed; //delta=-12.38
			turn lbthigh to z-axis ((<0.903874> *animAmplitude)/100) speed ((<179.115914> *animAmplitude)/100) / animSpeed; //delta=-5.97
			turn lbthigh to y-axis ((<-6.356784> *animAmplitude)/100) speed ((<82.336607> *animAmplitude)/100) / animSpeed; //delta=-2.74
			turn lffoot to x-axis ((<30.810505> *animAmplitude)/100) speed ((<301.016989> *animAmplitude)/100) / animSpeed; //delta=10.03
			turn lffoot to z-axis ((<-3.101303> *animAmplitude)/100) speed ((<72.013783> *animAmplitude)/100) / animSpeed; //delta=2.40
			turn lffoot to y-axis ((<1.756211> *animAmplitude)/100) speed ((<26.133998> *animAmplitude)/100) / animSpeed; //delta=0.87
			turn lfknee to x-axis ((<-21.123595> *animAmplitude)/100) speed ((<1467.220376> *animAmplitude)/100) / animSpeed; //delta=-48.91
			turn lfknee to y-axis ((<-1.477993> *animAmplitude)/100) speed ((<18.616379> *animAmplitude)/100) / animSpeed; //delta=-0.62
			turn lfshin to x-axis ((<12.105785> *animAmplitude)/100) speed ((<762.115743> *animAmplitude)/100) / animSpeed; //delta=25.40
			turn lfshin to z-axis ((<-0.218493> *animAmplitude)/100) speed ((<47.381524> *animAmplitude)/100) / animSpeed; //delta=1.58
			turn lfshin to y-axis ((<-3.686055> *animAmplitude)/100) speed ((<31.697166> *animAmplitude)/100) / animSpeed; //delta=-1.06
			turn lfthigh to x-axis ((<-22.310033> *animAmplitude)/100) speed ((<83.916865> *animAmplitude)/100) / animSpeed; //delta=2.80
			turn lfthigh to z-axis ((<1.766168> *animAmplitude)/100) speed ((<8.390657> *animAmplitude)/100) / animSpeed; //delta=0.28
			turn lfthigh to y-axis ((<-3.170157> *animAmplitude)/100) speed ((<23.536343> *animAmplitude)/100) / animSpeed; //delta=-0.78
			turn rbfoot to x-axis ((<-21.984183> *animAmplitude)/100) speed ((<85.351359> *animAmplitude)/100) / animSpeed; //delta=-2.85
			turn rbfoot to z-axis ((<3.269794> *animAmplitude)/100) speed ((<6.410090> *animAmplitude)/100) / animSpeed; //delta=0.21
			turn rbknee to x-axis ((<-29.477495> *animAmplitude)/100) speed ((<447.638936> *animAmplitude)/100) / animSpeed; //delta=14.92
			turn rbknee to z-axis ((<11.300767> *animAmplitude)/100) speed ((<185.276006> *animAmplitude)/100) / animSpeed; //delta=-6.18
			turn rbknee to y-axis ((<3.742183> *animAmplitude)/100) speed ((<73.222989> *animAmplitude)/100) / animSpeed; //delta=2.44
			turn rbshin to x-axis ((<18.646435> *animAmplitude)/100) speed ((<447.793972> *animAmplitude)/100) / animSpeed; //delta=-14.93
			turn rbshin to z-axis ((<-5.214862> *animAmplitude)/100) speed ((<105.391121> *animAmplitude)/100) / animSpeed; //delta=3.51
			turn rbshin to y-axis ((<-1.782429> *animAmplitude)/100) speed ((<5.214808> *animAmplitude)/100) / animSpeed; //delta=0.17
			turn rbthigh to x-axis ((<60.198665> *animAmplitude)/100) speed ((<797.660500> *animAmplitude)/100) / animSpeed; //delta=-26.59
			turn rbthigh to z-axis ((<-21.435394> *animAmplitude)/100) speed ((<403.538803> *animAmplitude)/100) / animSpeed; //delta=13.45
			turn rbthigh to y-axis ((<8.638314> *animAmplitude)/100) speed ((<264.585110> *animAmplitude)/100) / animSpeed; //delta=8.82
			turn rffoot to x-axis ((<-26.691249> *animAmplitude)/100) speed ((<226.206952> *animAmplitude)/100) / animSpeed; //delta=-7.54
			turn rffoot to z-axis ((<-3.701542> *animAmplitude)/100) speed ((<83.326241> *animAmplitude)/100) / animSpeed; //delta=2.78
			turn rffoot to y-axis ((<-1.375829> *animAmplitude)/100) speed ((<34.728725> *animAmplitude)/100) / animSpeed; //delta=-1.16
			turn rfknee to x-axis ((<9.119317> *animAmplitude)/100) speed ((<1478.727418> *animAmplitude)/100) / animSpeed; //delta=-49.29
			turn rfknee to y-axis ((<-0.426746> *animAmplitude)/100) speed ((<61.135086> *animAmplitude)/100) / animSpeed; //delta=2.04
			turn rfshin to x-axis ((<0.035423> *animAmplitude)/100) speed ((<576.007991> *animAmplitude)/100) / animSpeed; //delta=19.20
			turn rfshin to z-axis ((<-1.273639> *animAmplitude)/100) speed ((<38.600696> *animAmplitude)/100) / animSpeed; //delta=1.29
			turn rfshin to y-axis ((<-1.323635> *animAmplitude)/100) speed ((<5.027303> *animAmplitude)/100) / animSpeed; //delta=0.17
			turn rfthigh to x-axis ((<33.390975> *animAmplitude)/100) speed ((<943.761628> *animAmplitude)/100) / animSpeed; //delta=31.46
			turn rfthigh to z-axis ((<-0.991959> *animAmplitude)/100) speed ((<62.961684> *animAmplitude)/100) / animSpeed; //delta=-2.10
			turn rfthigh to y-axis ((<-0.730931> *animAmplitude)/100) speed ((<77.650792> *animAmplitude)/100) / animSpeed; //delta=-2.59
			turn tail to x-axis ((<3.562133> *animAmplitude)/100) speed ((<106.864002> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<0.380573> *animAmplitude)/100) speed ((<11.417184> *animAmplitude)/100) / animSpeed; //delta=-0.38
			turn tail to y-axis ((<-13.042306> *animAmplitude)/100) speed ((<130.423077> *animAmplitude)/100) / animSpeed; //delta=-4.35
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:32
			move body to x-axis (((([-1.478000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([12.270001] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-0.41
			move body to y-axis (((([1.090000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([32.700001] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=1.09
			turn body to x-axis ((<-0.0> *animAmplitude)/100) speed ((<29.999997> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<5.800206> *animAmplitude)/100) speed ((<58.002060> *animAmplitude)/100) / animSpeed; //delta=-1.93
			turn body to y-axis ((<4.077731> *animAmplitude)/100) speed ((<61.165970> *animAmplitude)/100) / animSpeed; //delta=-2.04
			turn head to x-axis ((<-0.0> *animAmplitude)/100) speed ((<44.937598> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<4.493760> *animAmplitude)/100) speed ((<44.937595> *animAmplitude)/100) / animSpeed; //delta=-1.50
			turn head to y-axis ((<-4.957617> *animAmplitude)/100) speed ((<74.364252> *animAmplitude)/100) / animSpeed; //delta=2.48
			turn lbfoot to x-axis ((<29.148372> *animAmplitude)/100) speed ((<129.114037> *animAmplitude)/100) / animSpeed; //delta=4.30
			turn lbfoot to z-axis ((<2.904403> *animAmplitude)/100) speed ((<80.653813> *animAmplitude)/100) / animSpeed; //delta=2.69
			turn lbfoot to y-axis ((<0.495671> *animAmplitude)/100) speed ((<24.408481> *animAmplitude)/100) / animSpeed; //delta=0.81
			turn lbknee to x-axis ((<-21.268859> *animAmplitude)/100) speed ((<1118.858598> *animAmplitude)/100) / animSpeed; //delta=-37.30
			turn lbknee to z-axis ((<-6.621939> *animAmplitude)/100) speed ((<572.374420> *animAmplitude)/100) / animSpeed; //delta=-19.08
			turn lbknee to y-axis ((<-1.141703> *animAmplitude)/100) speed ((<345.470978> *animAmplitude)/100) / animSpeed; //delta=11.52
			turn lbshin to x-axis ((<12.131142> *animAmplitude)/100) speed ((<504.877902> *animAmplitude)/100) / animSpeed; //delta=16.83
			turn lbshin to z-axis ((<3.038673> *animAmplitude)/100) speed ((<282.833557> *animAmplitude)/100) / animSpeed; //delta=9.43
			turn lbshin to y-axis ((<-4.676175> *animAmplitude)/100) speed ((<129.054230> *animAmplitude)/100) / animSpeed; //delta=4.30
			turn lbthigh to x-axis ((<-19.982328> *animAmplitude)/100) speed ((<54.586462> *animAmplitude)/100) / animSpeed; //delta=-1.82
			turn lbthigh to z-axis ((<-3.344867> *animAmplitude)/100) speed ((<127.462216> *animAmplitude)/100) / animSpeed; //delta=4.25
			turn lbthigh to y-axis ((<-3.984942> *animAmplitude)/100) speed ((<71.155263> *animAmplitude)/100) / animSpeed; //delta=2.37
			turn lffoot to x-axis ((<1.678077> *animAmplitude)/100) speed ((<873.972836> *animAmplitude)/100) / animSpeed; //delta=29.13
			turn lffoot to z-axis ((<-2.656071> *animAmplitude)/100) speed ((<13.356969> *animAmplitude)/100) / animSpeed; //delta=-0.45
			turn lffoot to y-axis ((<0.039496> *animAmplitude)/100) speed ((<51.501451> *animAmplitude)/100) / animSpeed; //delta=-1.72
			turn lfknee to x-axis ((<0.953697> *animAmplitude)/100) speed ((<662.318756> *animAmplitude)/100) / animSpeed; //delta=-22.08
			turn lfknee to z-axis ((<-1.147274> *animAmplitude)/100) speed ((<29.707190> *animAmplitude)/100) / animSpeed; //delta=0.99
			turn lfknee to y-axis ((<-0.668873> *animAmplitude)/100) speed ((<24.273610> *animAmplitude)/100) / animSpeed; //delta=0.81
			turn lfshin to x-axis ((<-0.106925> *animAmplitude)/100) speed ((<366.381326> *animAmplitude)/100) / animSpeed; //delta=12.21
			turn lfshin to z-axis ((<-1.657126> *animAmplitude)/100) speed ((<43.159010> *animAmplitude)/100) / animSpeed; //delta=1.44
			turn lfshin to y-axis ((<-1.777931> *animAmplitude)/100) speed ((<57.243740> *animAmplitude)/100) / animSpeed; //delta=1.91
			turn lfthigh to x-axis ((<-2.156870> *animAmplitude)/100) speed ((<604.594877> *animAmplitude)/100) / animSpeed; //delta=-20.15
			turn lfthigh to z-axis ((<-0.265085> *animAmplitude)/100) speed ((<60.937601> *animAmplitude)/100) / animSpeed; //delta=2.03
			turn lfthigh to y-axis ((<-1.743002> *animAmplitude)/100) speed ((<42.814669> *animAmplitude)/100) / animSpeed; //delta=1.43
			turn rbfoot to x-axis ((<-23.237069> *animAmplitude)/100) speed ((<37.586565> *animAmplitude)/100) / animSpeed; //delta=1.25
			turn rbfoot to z-axis ((<2.731589> *animAmplitude)/100) speed ((<16.146157> *animAmplitude)/100) / animSpeed; //delta=0.54
			turn rbfoot to y-axis ((<0.056471> *animAmplitude)/100) speed ((<9.244144> *animAmplitude)/100) / animSpeed; //delta=-0.31
			turn rbknee to x-axis ((<4.430283> *animAmplitude)/100) speed ((<1017.233324> *animAmplitude)/100) / animSpeed; //delta=-33.91
			turn rbknee to z-axis ((<-0.976171> *animAmplitude)/100) speed ((<368.308138> *animAmplitude)/100) / animSpeed; //delta=12.28
			turn rbknee to y-axis ((<1.658356> *animAmplitude)/100) speed ((<62.514823> *animAmplitude)/100) / animSpeed; //delta=-2.08
			turn rbshin to x-axis ((<2.113226> *animAmplitude)/100) speed ((<495.996284> *animAmplitude)/100) / animSpeed; //delta=16.53
			turn rbshin to z-axis ((<-1.274253> *animAmplitude)/100) speed ((<118.218258> *animAmplitude)/100) / animSpeed; //delta=-3.94
			turn rbshin to y-axis ((<-1.256616> *animAmplitude)/100) speed ((<15.774398> *animAmplitude)/100) / animSpeed; //delta=0.53
			turn rbthigh to x-axis ((<33.343457> *animAmplitude)/100) speed ((<805.656227> *animAmplitude)/100) / animSpeed; //delta=26.86
			turn rbthigh to z-axis ((<-7.759617> *animAmplitude)/100) speed ((<410.273336> *animAmplitude)/100) / animSpeed; //delta=-13.68
			turn rbthigh to y-axis ((<0.378903> *animAmplitude)/100) speed ((<247.782311> *animAmplitude)/100) / animSpeed; //delta=-8.26
			turn rffoot to x-axis ((<-4.263326> *animAmplitude)/100) speed ((<672.837700> *animAmplitude)/100) / animSpeed; //delta=-22.43
			turn rffoot to z-axis ((<-3.325700> *animAmplitude)/100) speed ((<11.275242> *animAmplitude)/100) / animSpeed; //delta=-0.38
			turn rffoot to y-axis ((<-0.168784> *animAmplitude)/100) speed ((<36.211353> *animAmplitude)/100) / animSpeed; //delta=1.21
			turn rfknee to x-axis ((<16.193084> *animAmplitude)/100) speed ((<212.213021> *animAmplitude)/100) / animSpeed; //delta=-7.07
			turn rfknee to z-axis ((<-1.242935> *animAmplitude)/100) speed ((<9.324812> *animAmplitude)/100) / animSpeed; //delta=0.31
			turn rfknee to y-axis ((<0.248139> *animAmplitude)/100) speed ((<20.246543> *animAmplitude)/100) / animSpeed; //delta=0.67
			turn rfshin to x-axis ((<-6.799814> *animAmplitude)/100) speed ((<205.057097> *animAmplitude)/100) / animSpeed; //delta=6.84
			turn rfshin to z-axis ((<-2.195943> *animAmplitude)/100) speed ((<27.669111> *animAmplitude)/100) / animSpeed; //delta=0.92
			turn rfshin to y-axis ((<-1.893830> *animAmplitude)/100) speed ((<17.105865> *animAmplitude)/100) / animSpeed; //delta=-0.57
			turn rfthigh to x-axis ((<-4.747068> *animAmplitude)/100) speed ((<1144.141269> *animAmplitude)/100) / animSpeed; //delta=38.14
			turn rfthigh to z-axis ((<0.538404> *animAmplitude)/100) speed ((<45.910882> *animAmplitude)/100) / animSpeed; //delta=-1.53
			turn rfthigh to y-axis ((<-1.827440> *animAmplitude)/100) speed ((<32.895263> *animAmplitude)/100) / animSpeed; //delta=-1.10
			turn tail to x-axis ((<-0.0> *animAmplitude)/100) speed ((<106.863989> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<0.570859> *animAmplitude)/100) speed ((<5.708584> *animAmplitude)/100) / animSpeed; //delta=-0.19
			turn tail to y-axis ((<-8.694870> *animAmplitude)/100) speed ((<130.423077> *animAmplitude)/100) / animSpeed; //delta=4.35
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:36
			move body to x-axis (((([-1.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([14.340001] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=0.48
			move body to y-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([32.700001] *MOVESCALE)/100) *animAmplitude)/100) / animSpeed; //delta=-1.09
			turn body to x-axis ((<-1.0> *animAmplitude)/100) speed ((<30.0> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn body to z-axis ((<3.866804> *animAmplitude)/100) speed ((<58.002060> *animAmplitude)/100) / animSpeed; //delta=1.93
			turn body to y-axis ((<0.0> *animAmplitude)/100) speed ((<122.331915> *animAmplitude)/100) / animSpeed; //delta=-4.08
			turn head to x-axis ((<-1.497920> *animAmplitude)/100) speed ((<44.937601> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to z-axis ((<2.995840> *animAmplitude)/100) speed ((<44.937595> *animAmplitude)/100) / animSpeed; //delta=1.50
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<148.728518> *animAmplitude)/100) / animSpeed; //delta=4.96
			turn lbfoot to x-axis ((<-1.038083> *animAmplitude)/100) speed ((<905.593652> *animAmplitude)/100) / animSpeed; //delta=30.19
			turn lbfoot to z-axis ((<-1.347733> *animAmplitude)/100) speed ((<127.564073> *animAmplitude)/100) / animSpeed; //delta=4.25
			turn lbfoot to y-axis ((<-0.015610> *animAmplitude)/100) speed ((<15.338440> *animAmplitude)/100) / animSpeed; //delta=-0.51
			turn lbknee to x-axis ((<6.439735> *animAmplitude)/100) speed ((<831.257821> *animAmplitude)/100) / animSpeed; //delta=-27.71
			turn lbknee to z-axis ((<0.894888> *animAmplitude)/100) speed ((<225.504819> *animAmplitude)/100) / animSpeed; //delta=-7.52
			turn lbknee to y-axis ((<0.023593> *animAmplitude)/100) speed ((<34.958854> *animAmplitude)/100) / animSpeed; //delta=1.17
			turn lbshin to x-axis ((<-2.423438> *animAmplitude)/100) speed ((<436.637396> *animAmplitude)/100) / animSpeed; //delta=14.55
			turn lbshin to z-axis ((<-1.828183> *animAmplitude)/100) speed ((<146.005680> *animAmplitude)/100) / animSpeed; //delta=4.87
			turn lbshin to y-axis ((<-0.0> *animAmplitude)/100) speed ((<140.257704> *animAmplitude)/100) / animSpeed; //delta=4.68
			turn lbthigh to x-axis ((<-1.979248> *animAmplitude)/100) speed ((<540.092395> *animAmplitude)/100) / animSpeed; //delta=-18.00
			turn lbthigh to z-axis ((<-1.586812> *animAmplitude)/100) speed ((<52.741658> *animAmplitude)/100) / animSpeed; //delta=-1.76
			turn lbthigh to y-axis ((<-0.042964> *animAmplitude)/100) speed ((<118.259330> *animAmplitude)/100) / animSpeed; //delta=3.94
			turn lffoot to x-axis ((<-25.122923> *animAmplitude)/100) speed ((<804.030012> *animAmplitude)/100) / animSpeed; //delta=26.80
			turn lffoot to z-axis ((<-1.182264> *animAmplitude)/100) speed ((<44.214220> *animAmplitude)/100) / animSpeed; //delta=-1.47
			turn lffoot to y-axis ((<-0.566773> *animAmplitude)/100) speed ((<18.188074> *animAmplitude)/100) / animSpeed; //delta=-0.61
			turn lfknee to x-axis ((<-8.899382> *animAmplitude)/100) speed ((<295.592384> *animAmplitude)/100) / animSpeed; //delta=9.85
			turn lfknee to z-axis ((<-0.722958> *animAmplitude)/100) speed ((<12.729474> *animAmplitude)/100) / animSpeed; //delta=-0.42
			turn lfknee to y-axis ((<0.332272> *animAmplitude)/100) speed ((<30.034335> *animAmplitude)/100) / animSpeed; //delta=1.00
			turn lfshin to x-axis ((<2.041949> *animAmplitude)/100) speed ((<64.466223> *animAmplitude)/100) / animSpeed; //delta=-2.15
			turn lfshin to z-axis ((<-0.653646> *animAmplitude)/100) speed ((<30.104415> *animAmplitude)/100) / animSpeed; //delta=-1.00
			turn lfshin to y-axis ((<0.633994> *animAmplitude)/100) speed ((<72.357731> *animAmplitude)/100) / animSpeed; //delta=2.41
			turn lfthigh to x-axis ((<32.952005> *animAmplitude)/100) speed ((<1053.266256> *animAmplitude)/100) / animSpeed; //delta=-35.11
			turn lfthigh to z-axis ((<-1.487056> *animAmplitude)/100) speed ((<36.659107> *animAmplitude)/100) / animSpeed; //delta=1.22
			turn lfthigh to y-axis ((<1.063586> *animAmplitude)/100) speed ((<84.197628> *animAmplitude)/100) / animSpeed; //delta=2.81
			turn rbfoot to x-axis ((<-3.311221> *animAmplitude)/100) speed ((<597.775418> *animAmplitude)/100) / animSpeed; //delta=-19.93
			turn rbfoot to z-axis ((<-0.263967> *animAmplitude)/100) speed ((<89.866673> *animAmplitude)/100) / animSpeed; //delta=3.00
			turn rbfoot to y-axis ((<-0.044053> *animAmplitude)/100) speed ((<3.015716> *animAmplitude)/100) / animSpeed; //delta=-0.10
			turn rbknee to x-axis ((<23.032253> *animAmplitude)/100) speed ((<558.059121> *animAmplitude)/100) / animSpeed; //delta=-18.60
			turn rbknee to z-axis ((<-8.592465> *animAmplitude)/100) speed ((<228.488810> *animAmplitude)/100) / animSpeed; //delta=7.62
			turn rbknee to y-axis ((<2.308514> *animAmplitude)/100) speed ((<19.504744> *animAmplitude)/100) / animSpeed; //delta=0.65
			turn rbshin to x-axis ((<-9.113940> *animAmplitude)/100) speed ((<336.814965> *animAmplitude)/100) / animSpeed; //delta=11.23
			turn rbshin to z-axis ((<1.521576> *animAmplitude)/100) speed ((<83.874876> *animAmplitude)/100) / animSpeed; //delta=-2.80
			turn rbshin to y-axis ((<0.101727> *animAmplitude)/100) speed ((<40.750287> *animAmplitude)/100) / animSpeed; //delta=1.36
			turn rbthigh to x-axis ((<-9.734253> *animAmplitude)/100) speed ((<1292.331308> *animAmplitude)/100) / animSpeed; //delta=43.08
			turn rbthigh to z-axis ((<2.912264> *animAmplitude)/100) speed ((<320.156415> *animAmplitude)/100) / animSpeed; //delta=-10.67
			turn rbthigh to y-axis ((<0.041696> *animAmplitude)/100) speed ((<10.116202> *animAmplitude)/100) / animSpeed; //delta=-0.34
			turn rffoot to x-axis ((<24.236998> *animAmplitude)/100) speed ((<855.009706> *animAmplitude)/100) / animSpeed; //delta=-28.50
			turn rffoot to z-axis ((<-1.413493> *animAmplitude)/100) speed ((<57.366209> *animAmplitude)/100) / animSpeed; //delta=-1.91
			turn rffoot to y-axis ((<0.612280> *animAmplitude)/100) speed ((<23.431912> *animAmplitude)/100) / animSpeed; //delta=0.78
			turn rfknee to x-axis ((<-7.870398> *animAmplitude)/100) speed ((<721.904465> *animAmplitude)/100) / animSpeed; //delta=24.06
			turn rfknee to z-axis ((<-0.806023> *animAmplitude)/100) speed ((<13.107387> *animAmplitude)/100) / animSpeed; //delta=-0.44
			turn rfknee to y-axis ((<-0.565015> *animAmplitude)/100) speed ((<24.394639> *animAmplitude)/100) / animSpeed; //delta=-0.81
			turn rfshin to x-axis ((<2.269928> *animAmplitude)/100) speed ((<272.092248> *animAmplitude)/100) / animSpeed; //delta=-9.07
			turn rfshin to z-axis ((<-0.880305> *animAmplitude)/100) speed ((<39.469154> *animAmplitude)/100) / animSpeed; //delta=-1.32
			turn rfshin to y-axis ((<-0.824357> *animAmplitude)/100) speed ((<32.084177> *animAmplitude)/100) / animSpeed; //delta=1.07
			turn rfthigh to x-axis ((<-29.197686> *animAmplitude)/100) speed ((<733.518544> *animAmplitude)/100) / animSpeed; //delta=24.45
			turn rfthigh to z-axis ((<-0.788687> *animAmplitude)/100) speed ((<39.812723> *animAmplitude)/100) / animSpeed; //delta=1.33
			turn rfthigh to y-axis ((<-0.985651> *animAmplitude)/100) speed ((<25.253674> *animAmplitude)/100) / animSpeed; //delta=0.84
			turn tail to x-axis ((<-3.562133> *animAmplitude)/100) speed ((<106.863996> *animAmplitude)/100) / animSpeed; //delta=3.56
			turn tail to z-axis ((<0.380573> *animAmplitude)/100) speed ((<5.708584> *animAmplitude)/100) / animSpeed; //delta=0.19
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<260.846103> *animAmplitude)/100) / animSpeed; //delta=8.69
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
	animSpeed = 10; // tune restore speed here, higher values are slower restore speeds
	move body to x-axis ([0.0]*MOVESCALE)/100 speed (([80.175000]*MOVESCALE)/100) / animSpeed;
	move body to y-axis ([0.0]*MOVESCALE)/100 speed (([81.750003]*MOVESCALE)/100) / animSpeed;
	turn body to x-axis <0.0> speed <224.999998> / animSpeed;
	turn body to y-axis <0.0> speed <305.829788> / animSpeed;
	turn body to z-axis <0.0> speed <290.010334> / animSpeed;
	turn head to x-axis <0.0> speed <337.032008> / animSpeed;
	turn head to y-axis <0.0> speed <371.821294> / animSpeed;
	turn head to z-axis <0.0> speed <224.688005> / animSpeed;
	turn lbfoot to x-axis <0.0> speed <2263.984131> / animSpeed;
	turn lbfoot to y-axis <0.0> speed <61.021202> / animSpeed;
	turn lbfoot to z-axis <0.0> speed <344.837738> / animSpeed;
	turn lbknee to x-axis <0.0> speed <3837.941693> / animSpeed;
	turn lbknee to y-axis <0.0> speed <1084.574895> / animSpeed;
	turn lbknee to z-axis <0.0> speed <1951.645914> / animSpeed;
	turn lbshin to x-axis <0.0> speed <2082.390534> / animSpeed;
	turn lbshin to y-axis <0.0> speed <440.207987> / animSpeed;
	turn lbshin to z-axis <0.0> speed <871.800506> / animSpeed;
	turn lbthigh to x-axis <0.0> speed <3229.933984> / animSpeed;
	turn lbthigh to y-axis <0.0> speed <693.564210> / animSpeed;
	turn lbthigh to z-axis <0.0> speed <1088.598282> / animSpeed;
	turn lffoot to x-axis <0.0> speed <2184.932089> / animSpeed;
	turn lffoot to y-axis <0.0> speed <128.753628> / animSpeed;
	turn lffoot to z-axis <0.0> speed <199.259819> / animSpeed;
	turn lfknee to x-axis <0.0> speed <4662.163501> / animSpeed;
	turn lfknee to y-axis <0.0> speed <159.338589> / animSpeed;
	turn lfknee to z-axis <0.0> speed <130.743828> / animSpeed;
	turn lfshin to x-axis <0.0> speed <2643.058405> / animSpeed;
	turn lfshin to y-axis <0.0> speed <258.524912> / animSpeed;
	turn lfshin to z-axis <0.0> speed <118.453810> / animSpeed;
	turn lfthigh to x-axis <0.0> speed <2867.576611> / animSpeed;
	turn lfthigh to y-axis <0.0> speed <252.832960> / animSpeed;
	turn lfthigh to z-axis <0.0> speed <343.139158> / animSpeed;
	turn rbfoot to x-axis <0.0> speed <2264.816184> / animSpeed;
	turn rbfoot to y-axis <0.0> speed <70.058415> / animSpeed;
	turn rbfoot to z-axis <0.0> speed <334.430154> / animSpeed;
	turn rbknee to x-axis <0.0> speed <3858.309957> / animSpeed;
	turn rbknee to y-axis <0.0> speed <1081.416626> / animSpeed;
	turn rbknee to z-axis <0.0> speed <1954.238587> / animSpeed;
	turn rbshin to x-axis <0.0> speed <2090.471990> / animSpeed;
	turn rbshin to y-axis <0.0> speed <437.583321> / animSpeed;
	turn rbshin to z-axis <0.0> speed <876.129190> / animSpeed;
	turn rbthigh to x-axis <0.0> speed <3230.828269> / animSpeed;
	turn rbthigh to y-axis <0.0> speed <661.462774> / animSpeed;
	turn rbthigh to z-axis <0.0> speed <1025.683339> / animSpeed;
	turn rffoot to x-axis <0.0> speed <2188.468169> / animSpeed;
	turn rffoot to y-axis <0.0> speed <125.265029> / animSpeed;
	turn rffoot to z-axis <0.0> speed <208.315602> / animSpeed;
	turn rfknee to x-axis <0.0> speed <4636.437209> / animSpeed;
	turn rfknee to y-axis <0.0> speed <160.666918> / animSpeed;
	turn rfknee to z-axis <0.0> speed <131.641879> / animSpeed;
	turn rfshin to x-axis <0.0> speed <2626.440987> / animSpeed;
	turn rfshin to y-axis <0.0> speed <258.672840> / animSpeed;
	turn rfshin to z-axis <0.0> speed <117.637972> / animSpeed;
	turn rfthigh to x-axis <0.0> speed <2860.353173> / animSpeed;
	turn rfthigh to y-axis <0.0> speed <252.298861> / animSpeed;
	turn rfthigh to z-axis <0.0> speed <344.716483> / animSpeed;
	turn tail to x-axis <0.0> speed <801.479968> / animSpeed;
	turn tail to y-axis <0.0> speed <652.115257> / animSpeed;
	turn tail to z-axis <0.0> speed <28.542960> / animSpeed;
}

