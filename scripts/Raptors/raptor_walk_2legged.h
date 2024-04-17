// this animation uses the static-var animFramesPerKeyframe which contains how many frames each keyframe takes
// For N:\animations\Raptors\raptor_2legged_fast_anim_walk_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3))

static-var animAmplitude, animSpeed;

Walk() {// For N:\animations\Raptors\raptor_2legged_fast_anim_walk_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:6
			move body to x-axis (((([0.716533] *MOVESCALE)/100) *animAmplitude)/100) speed (((([21.495981] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([1.053885] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.616560] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<-3.245854> *animAmplitude)/100) speed ((<97.375627> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<2.900000> *animAmplitude)/100) speed ((<86.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<-4.099999> *animAmplitude)/100) speed ((<122.999985> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<-48.846962> *animAmplitude)/100) speed ((<1574.547663> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<2.875108> *animAmplitude)/100) speed ((<86.253251> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<3.305139> *animAmplitude)/100) speed ((<99.154183> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<-13.008917> *animAmplitude)/100) speed ((<357.512919> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<18.877087> *animAmplitude)/100) speed ((<731.961120> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<38.760142> *animAmplitude)/100) speed ((<1068.736154> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<-5.120454> *animAmplitude)/100) speed ((<153.613622> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<3.469185> *animAmplitude)/100) speed ((<104.075550> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<28.097928> *animAmplitude)/100) speed ((<842.937841> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<-0.843501> *animAmplitude)/100) speed ((<25.305041> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<1.842895> *animAmplitude)/100) speed ((<55.286862> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<-1.565746> *animAmplitude)/100) speed ((<46.972391> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<-20.056572> *animAmplitude)/100) speed ((<601.697165> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<-27.605579> *animAmplitude)/100) speed ((<828.167370> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<-6.221558> *animAmplitude)/100) speed ((<186.646735> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<0.717343> *animAmplitude)/100) speed ((<21.520297> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<0.747393> *animAmplitude)/100) speed ((<22.421803> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<6.100000> *animAmplitude)/100) speed ((<182.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		//animAmplitude = animAmplitude + 5;
		//if (animAmplitude > 170) animAmplitude = 40;
		if (isMoving) { //Frame:12
			move body to x-axis (((([1.368846] *MOVESCALE)/100) *animAmplitude)/100) speed (((([19.569397] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([2.107771] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.616560] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([-2.756316] *MOVESCALE)/100) *animAmplitude)/100) speed (((([82.696016] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<-0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<-4.999999> *animAmplitude)/100) speed ((<52.624356> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<11.999999> *animAmplitude)/100) speed ((<272.999967> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<-6.099999> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<-44.270339> *animAmplitude)/100) speed ((<137.298687> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<1.253975> *animAmplitude)/100) speed ((<48.634010> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<1.423578> *animAmplitude)/100) speed ((<56.446852> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<-12.475915> *animAmplitude)/100) speed ((<15.990070> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<23.747625> *animAmplitude)/100) speed ((<146.116137> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<63.270214> *animAmplitude)/100) speed ((<735.302171> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<-3.053752> *animAmplitude)/100) speed ((<62.001051> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<2.631929> *animAmplitude)/100) speed ((<25.117671> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<37.775085> *animAmplitude)/100) speed ((<290.314715> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<-0.225574> *animAmplitude)/100) speed ((<18.537829> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<2.256788> *animAmplitude)/100) speed ((<12.416772> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<-44.679310> *animAmplitude)/100) speed ((<1293.406915> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<23.827443> *animAmplitude)/100) speed ((<1316.520448> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<-39.489763> *animAmplitude)/100) speed ((<356.525527> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<-7.962845> *animAmplitude)/100) speed ((<52.238627> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<-1.406630> *animAmplitude)/100) speed ((<64.620693> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<10.599999> *animAmplitude)/100) speed ((<134.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:18
			move body to x-axis (((([0.884679] *MOVESCALE)/100) *animAmplitude)/100) speed (((([14.525004] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([2.594179] *MOVESCALE)/100) *animAmplitude)/100) speed (((([14.592261] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([-1.511768] *MOVESCALE)/100) *animAmplitude)/100) speed (((([37.336428] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<-3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<-3.457541> *animAmplitude)/100) speed ((<46.273765> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<6.799999> *animAmplitude)/100) speed ((<155.999992> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<-4.0> *animAmplitude)/100) speed ((<62.999992> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<-48.343963> *animAmplitude)/100) speed ((<122.208716> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<-0.170319> *animAmplitude)/100) speed ((<42.728804> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<-0.213311> *animAmplitude)/100) speed ((<49.106656> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<12.765100> *animAmplitude)/100) speed ((<757.230459> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<3.288396> *animAmplitude)/100) speed ((<613.776860> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<49.067048> *animAmplitude)/100) speed ((<426.094999> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<0.390141> *animAmplitude)/100) speed ((<103.316810> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<-0.299007> *animAmplitude)/100) speed ((<87.928080> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<10.599999> *animAmplitude)/100) speed ((<167.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<10.599999> *animAmplitude)/100) speed ((<167.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<42.434265> *animAmplitude)/100) speed ((<139.775382> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<5.670194> *animAmplitude)/100) speed ((<176.873039> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<0.962420> *animAmplitude)/100) speed ((<38.831025> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<-6.539543> *animAmplitude)/100) speed ((<1144.193008> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<-12.793380> *animAmplitude)/100) speed ((<1098.624675> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<-22.525213> *animAmplitude)/100) speed ((<508.936520> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<-2.985205> *animAmplitude)/100) speed ((<149.329218> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<0.342836> *animAmplitude)/100) speed ((<14.005360> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<10.599999> *animAmplitude)/100) speed ((<167.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<10.599999> *animAmplitude)/100) speed ((<167.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<-13.999999> *animAmplitude)/100) speed ((<377.801088> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<5.600000> *animAmplitude)/100) speed ((<149.999983> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:24
			move body to x-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([26.540374] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([77.825382] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([-0.620183] *MOVESCALE)/100) *animAmplitude)/100) speed (((([26.747559] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<-5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<-0.0> *animAmplitude)/100) speed ((<103.726217> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<3.199999> *animAmplitude)/100) speed ((<107.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<0.200000> *animAmplitude)/100) speed ((<125.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<0.576282> *animAmplitude)/100) speed ((<1467.607337> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<0.314161> *animAmplitude)/100) speed ((<14.534403> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<-1.044645> *animAmplitude)/100) speed ((<24.940011> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<32.920798> *animAmplitude)/100) speed ((<604.670935> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<-41.149110> *animAmplitude)/100) speed ((<1333.125191> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<1.397293> *animAmplitude)/100) speed ((<1430.092633> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<3.317986> *animAmplitude)/100) speed ((<87.835347> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<-1.610578> *animAmplitude)/100) speed ((<39.347128> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<5.300000> *animAmplitude)/100) speed ((<158.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<5.300000> *animAmplitude)/100) speed ((<158.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<1.677194> *animAmplitude)/100) speed ((<1222.712107> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<1.403425> *animAmplitude)/100) speed ((<128.003077> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<-1.092581> *animAmplitude)/100) speed ((<61.650044> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<19.298607> *animAmplitude)/100) speed ((<775.144517> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<-17.251765> *animAmplitude)/100) speed ((<133.751565> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<-4.160830> *animAmplitude)/100) speed ((<550.931464> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<3.881124> *animAmplitude)/100) speed ((<205.989863> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<-1.190465> *animAmplitude)/100) speed ((<45.999023> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<5.300000> *animAmplitude)/100) speed ((<158.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<5.300000> *animAmplitude)/100) speed ((<158.999991> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<-7.0> *animAmplitude)/100) speed ((<209.999989> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<0.0> *animAmplitude)/100) speed ((<167.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:30
			move body to x-axis (((([-1.020784] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.623506] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([1.053885] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.616560] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.012741] *MOVESCALE)/100) *animAmplitude)/100) speed (((([18.987735] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<-3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<3.386979> *animAmplitude)/100) speed ((<101.609356> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<7.349999> *animAmplitude)/100) speed ((<124.499997> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<4.400000> *animAmplitude)/100) speed ((<125.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<34.008615> *animAmplitude)/100) speed ((<1002.969996> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<0.900907> *animAmplitude)/100) speed ((<17.602359> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<-2.078645> *animAmplitude)/100) speed ((<31.020004> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<-17.190068> *animAmplitude)/100) speed ((<1503.325985> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<-13.257932> *animAmplitude)/100) speed ((<836.735347> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<-26.823562> *animAmplitude)/100) speed ((<846.625644> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<6.350107> *animAmplitude)/100) speed ((<90.963616> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<2.100000> *animAmplitude)/100) speed ((<95.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<2.100000> *animAmplitude)/100) speed ((<95.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<-48.895176> *animAmplitude)/100) speed ((<1517.171116> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<-2.218353> *animAmplitude)/100) speed ((<108.653335> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<-3.613208> *animAmplitude)/100) speed ((<75.618819> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<-9.034194> *animAmplitude)/100) speed ((<849.984035> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<23.253111> *animAmplitude)/100) speed ((<1215.146285> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<35.341444> *animAmplitude)/100) speed ((<1185.068245> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<6.092889> *animAmplitude)/100) speed ((<66.352953> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<-3.650148> *animAmplitude)/100) speed ((<73.790478> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<2.100000> *animAmplitude)/100) speed ((<95.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<2.100000> *animAmplitude)/100) speed ((<95.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<-0.0> *animAmplitude)/100) speed ((<209.999989> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<-7.599999> *animAmplitude)/100) speed ((<227.999992> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:36
			move body to x-axis (((([-1.354285] *MOVESCALE)/100) *animAmplitude)/100) speed (((([10.005037] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([2.107771] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.616560] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([-2.756316] *MOVESCALE)/100) *animAmplitude)/100) speed (((([83.071722] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<0.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<4.899999> *animAmplitude)/100) speed ((<45.390628> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<11.499999> *animAmplitude)/100) speed ((<124.499997> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<7.399999> *animAmplitude)/100) speed ((<89.999990> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<40.334623> *animAmplitude)/100) speed ((<189.780255> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<0.387602> *animAmplitude)/100) speed ((<15.399136> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<-2.301330> *animAmplitude)/100) speed ((<6.680553> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<-43.392957> *animAmplitude)/100) speed ((<786.086659> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<19.251964> *animAmplitude)/100) speed ((<975.296867> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<-39.280623> *animAmplitude)/100) speed ((<373.711837> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<7.223171> *animAmplitude)/100) speed ((<26.191927> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<-1.443272> *animAmplitude)/100) speed ((<7.036768> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<-0.0> *animAmplitude)/100) speed ((<62.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<-0.0> *animAmplitude)/100) speed ((<62.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<-42.036358> *animAmplitude)/100) speed ((<205.764537> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<-0.424411> *animAmplitude)/100) speed ((<53.818245> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<-1.185119> *animAmplitude)/100) speed ((<72.842690> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<-5.846317> *animAmplitude)/100) speed ((<95.636304> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<28.440843> *animAmplitude)/100) speed ((<155.631956> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<58.506082> *animAmplitude)/100) speed ((<694.939134> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<2.713115> *animAmplitude)/100) speed ((<101.393232> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<-2.128098> *animAmplitude)/100) speed ((<45.661482> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<-0.0> *animAmplitude)/100) speed ((<62.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<-0.0> *animAmplitude)/100) speed ((<62.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<2.300000> *animAmplitude)/100) speed ((<68.999995> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<-10.999999> *animAmplitude)/100) speed ((<101.999996> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:42
			move body to x-axis (((([-1.003146] *MOVESCALE)/100) *animAmplitude)/100) speed (((([10.534172] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([2.594179] *MOVESCALE)/100) *animAmplitude)/100) speed (((([14.592261] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([-1.502549] *MOVESCALE)/100) *animAmplitude)/100) speed (((([37.613018] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<3.0> *animAmplitude)/100) speed ((<90.0> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<3.386979> *animAmplitude)/100) speed ((<45.390628> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<7.499999> *animAmplitude)/100) speed ((<119.999986> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<4.900000> *animAmplitude)/100) speed ((<74.999985> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<45.522323> *animAmplitude)/100) speed ((<155.630983> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<-5.549231> *animAmplitude)/100) speed ((<178.104998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<-1.104711> *animAmplitude)/100) speed ((<35.898562> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<-8.861569> *animAmplitude)/100) speed ((<1035.941647> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<-18.474103> *animAmplitude)/100) speed ((<1131.781999> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<-18.890353> *animAmplitude)/100) speed ((<611.708088> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<3.070430> *animAmplitude)/100) speed ((<124.582241> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<-0.759400> *animAmplitude)/100) speed ((<20.516176> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<11.099999> *animAmplitude)/100) speed ((<332.999973> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<11.099999> *animAmplitude)/100) speed ((<332.999973> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<-51.897522> *animAmplitude)/100) speed ((<295.834925> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<-0.799132> *animAmplitude)/100) speed ((<11.579604> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<27.074615> *animAmplitude)/100) speed ((<987.627975> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<3.934454> *animAmplitude)/100) speed ((<735.191676> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<38.804770> *animAmplitude)/100) speed ((<591.039355> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<1.305489> *animAmplitude)/100) speed ((<42.228780> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<-0.825458> *animAmplitude)/100) speed ((<39.079218> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<11.099999> *animAmplitude)/100) speed ((<332.999973> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<11.099999> *animAmplitude)/100) speed ((<332.999973> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<-13.999999> *animAmplitude)/100) speed ((<488.999972> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<-7.899999> *animAmplitude)/100) speed ((<93.0> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:48
			move body to x-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([30.094371] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([77.825382] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([-0.551277] *MOVESCALE)/100) *animAmplitude)/100) speed (((([28.538139] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<5.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<-0.141124> *animAmplitude)/100) speed ((<105.843080> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<2.500000> *animAmplitude)/100) speed ((<149.999983> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<0.0> *animAmplitude)/100) speed ((<146.999997> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<5.189632> *animAmplitude)/100) speed ((<1209.980741> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<-1.428018> *animAmplitude)/100) speed ((<123.636399> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<1.139851> *animAmplitude)/100) speed ((<67.336875> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<15.866224> *animAmplitude)/100) speed ((<741.833770> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<-24.693239> *animAmplitude)/100) speed ((<186.574096> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<1.802795> *animAmplitude)/100) speed ((<620.794451> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<-3.848457> *animAmplitude)/100) speed ((<207.566606> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<1.798164> *animAmplitude)/100) speed ((<76.726925> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<182.999978> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<182.999978> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<-0.825809> *animAmplitude)/100) speed ((<1532.151403> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<1.053146> *animAmplitude)/100) speed ((<55.568328> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<37.626389> *animAmplitude)/100) speed ((<316.553194> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<-30.561920> *animAmplitude)/100) speed ((<1034.891224> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<-8.002054> *animAmplitude)/100) speed ((<1404.204735> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<-3.504265> *animAmplitude)/100) speed ((<144.292617> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<0.913148> *animAmplitude)/100) speed ((<52.158181> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<182.999978> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<5.0> *animAmplitude)/100) speed ((<182.999978> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<-7.919867> *animAmplitude)/100) speed ((<182.403958> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<0.800000> *animAmplitude)/100) speed ((<260.999987> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:54
			move body to x-axis (((([0.716533] *MOVESCALE)/100) *animAmplitude)/100) speed (((([21.495981] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to z-axis (((([1.053885] *MOVESCALE)/100) *animAmplitude)/100) speed (((([31.616560] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.000218] *MOVESCALE)/100) *animAmplitude)/100) speed (((([16.544859] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to z-axis ((<3.0> *animAmplitude)/100) speed ((<59.999993> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to y-axis ((<-3.245854> *animAmplitude)/100) speed ((<93.141903> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to x-axis ((<2.900000> *animAmplitude)/100) speed ((<11.999994> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn head to y-axis ((<-4.099999> *animAmplitude)/100) speed ((<122.999985> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to x-axis ((<-48.846962> *animAmplitude)/100) speed ((<1621.097802> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to z-axis ((<1.675109> *animAmplitude)/100) speed ((<93.093793> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lfoot to y-axis ((<3.305140> *animAmplitude)/100) speed ((<64.958653> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lknee to x-axis ((<-13.008917> *animAmplitude)/100) speed ((<866.254212> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lshin to x-axis ((<18.877087> *animAmplitude)/100) speed ((<1307.109796> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to x-axis ((<38.760142> *animAmplitude)/100) speed ((<1108.720403> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to z-axis ((<-5.120454> *animAmplitude)/100) speed ((<38.159904> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lthigh to y-axis ((<3.469185> *animAmplitude)/100) speed ((<50.130622> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LUHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn LLHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to x-axis ((<28.097928> *animAmplitude)/100) speed ((<867.712111> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to z-axis ((<-0.843501> *animAmplitude)/100) speed ((<15.650256> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rfoot to y-axis ((<1.842895> *animAmplitude)/100) speed ((<23.692494> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rknee to x-axis ((<-1.565746> *animAmplitude)/100) speed ((<1175.764048> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rshin to x-axis ((<-20.056572> *animAmplitude)/100) speed ((<315.160450> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to x-axis ((<-27.605579> *animAmplitude)/100) speed ((<588.105746> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to z-axis ((<-6.221558> *animAmplitude)/100) speed ((<81.518777> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rthigh to y-axis ((<0.717343> *animAmplitude)/100) speed ((<5.874148> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RUHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn RLHAND to z-axis ((<2.500000> *animAmplitude)/100) speed ((<74.999998> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to x-axis ((<0.747393> *animAmplitude)/100) speed ((<260.017823> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn tail to y-axis ((<6.100000> *animAmplitude)/100) speed ((<158.999978> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
	animSpeed = MOVESPEED * 5; // tune restore speed here, higher values are slower restore speeds
	move body to x-axis ([0.0]*MOVESCALE)/100 speed (([51.039177]*MOVESCALE)/100) / animSpeed;
	move body to y-axis ([0.0]*MOVESCALE)/100 speed (([138.452870]*MOVESCALE)/100) / animSpeed;
	move body to z-axis ([0.0]*MOVESCALE)/100 speed (([129.708970]*MOVESCALE)/100) / animSpeed;
	turn body to y-axis <0.0> speed <176.405134> / animSpeed;
	turn body to z-axis <0.0> speed <150.0> / animSpeed;
	turn head to x-axis <0.0> speed <454.999946> / animSpeed;
	turn head to y-axis <0.0> speed <244.999995> / animSpeed;
	turn lfoot to x-axis <3.637960> speed <2701.829669> / animSpeed;
	turn lfoot to y-axis <0.0> speed <165.256971> / animSpeed;
	turn lfoot to z-axis <0.0> speed <296.841664> / animSpeed;
	turn lknee to x-axis <-1.091820> speed <2505.543309> / animSpeed;
	turn lshin to x-axis <-5.521617> speed <2221.875318> / animSpeed;
	turn lthigh to x-axis <3.135603> speed <2383.487722> / animSpeed;
	turn lthigh to y-axis <0.0> speed <173.459249> / animSpeed;
	turn lthigh to z-axis <0.0> speed <345.944343> / animSpeed;
	turn LUHAND to z-axis <0.0> speed <554.999956> / animSpeed;
	turn LLHAND to z-axis <0.0> speed <554.999956> / animSpeed;
	turn rfoot to x-axis <0.0> speed <2553.585672> / animSpeed;
	turn rfoot to y-axis <0.0> speed <126.031366> / animSpeed;
	turn rfoot to z-axis <0.0> speed <294.788398> / animSpeed;
	turn rknee to x-axis <0.0> speed <2155.678192> / animSpeed;
	turn rshin to x-axis <0.0> speed <2194.200747> / animSpeed;
	turn rthigh to x-axis <0.0> speed <2340.341225> / animSpeed;
	turn rthigh to y-axis <0.0> speed <122.984130> / animSpeed;
	turn rthigh to z-axis <0.0> speed <343.316438> / animSpeed;
	turn RLHAND to z-axis <0.0> speed <554.999956> / animSpeed;
	turn RUHAND to z-axis <0.0> speed <554.999956> / animSpeed;
	turn tail to x-axis <0.0> speed <814.999954> / animSpeed;
	turn tail to y-axis <0.0> speed <434.999978> / animSpeed;
}