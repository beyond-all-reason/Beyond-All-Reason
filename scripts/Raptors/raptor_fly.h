// this animation uses the static-var animFramesPerKeyframe which contains how many frames each keyframe takes
// For N:\animations\Raptors\raptor_2legged_fast_anim_walk_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3))

static-var animAmplitude, animSpeed;

Walk() {// For N:\animations\Raptors\raptor_flight_2seg_anim_v1.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 3)) 
	set-signal-mask SIGNAL_MOVE;
	if (isMoving) { //Frame:6
			turn liwing to z-axis ((<-27.699998> *animAmplitude)/100) speed ((<830.999934> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<27.699998> *animAmplitude)/100) speed ((<830.999934> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
	}
	while(isMoving) {
		animAmplitude = animAmplitude +10;
		if (animAmplitude > 250) animAmplitude = 10;
		animAmplitude = RAND(40,160);
		//animSpeed = RAND(2,4);
		if (isMoving) { //Frame:9
			//move body to y-axis (((([0.120312] *MOVESCALE)/100) *animAmplitude)/100) speed (((([3.609375] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.120312] *MOVESCALE)/100) *animAmplitude)/100) speed (((([3.609375] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			
			turn body to x-axis ((<0.703125> *animAmplitude)/100) speed ((<21.093749> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-25.523659> *animAmplitude)/100) speed ((<65.290171> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-9.612499> *animAmplitude)/100) speed ((<288.374975> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<25.523659> *animAmplitude)/100) speed ((<65.290171> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<9.612499> *animAmplitude)/100) speed ((<288.374975> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:12
			move body to z-axis (((([0.323437] *MOVESCALE)/100) *animAmplitude)/100) speed (((([7.034765] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.437500] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.515625] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<2.250000> *animAmplitude)/100) speed ((<46.406246> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-21.099998> *animAmplitude)/100) speed ((<132.709824> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-25.799998> *animAmplitude)/100) speed ((<485.624964> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<21.099998> *animAmplitude)/100) speed ((<132.709824> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<25.799998> *animAmplitude)/100) speed ((<485.624964> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:15
			move body to z-axis (((([0.654961] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.945700] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.885938] *MOVESCALE)/100) *animAmplitude)/100) speed (((([13.453127] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<3.796875> *animAmplitude)/100) speed ((<46.406250> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-16.481696> *animAmplitude)/100) speed ((<138.549073> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-34.374997> *animAmplitude)/100) speed ((<257.249957> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<16.481696> *animAmplitude)/100) speed ((<138.549073> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<34.374997> *animAmplitude)/100) speed ((<257.249957> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:18
			move body to z-axis (((([1.035000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([11.401171] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([1.400000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([15.421879] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<4.500000> *animAmplitude)/100) speed ((<21.093746> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-9.299999> *animAmplitude)/100) speed ((<215.450890> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-40.299994> *animAmplitude)/100) speed ((<177.749936> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<9.299999> *animAmplitude)/100) speed ((<215.450890> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<40.299994> *animAmplitude)/100) speed ((<177.749936> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:21
			move body to z-axis (((([1.415039] *MOVESCALE)/100) *animAmplitude)/100) speed (((([11.401169] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([1.914063] *MOVESCALE)/100) *animAmplitude)/100) speed (((([15.421876] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<4.130859> *animAmplitude)/100) speed ((<11.074217> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<2.712947> *animAmplitude)/100) speed ((<360.388377> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-49.862491> *animAmplitude)/100) speed ((<286.874912> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-2.712947> *animAmplitude)/100) speed ((<360.388377> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<49.862491> *animAmplitude)/100) speed ((<286.874912> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:24
			move body to z-axis (((([1.746562] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.945703] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([2.362500] *MOVESCALE)/100) *animAmplitude)/100) speed (((([13.453124] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<3.140625> *animAmplitude)/100) speed ((<29.707033> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<16.999999> *animAmplitude)/100) speed ((<428.611580> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-55.499993> *animAmplitude)/100) speed ((<169.125046> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-16.999999> *animAmplitude)/100) speed ((<428.611580> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<55.499993> *animAmplitude)/100) speed ((<169.125046> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:27
			move body to z-axis (((([1.981054] *MOVESCALE)/100) *animAmplitude)/100) speed (((([7.034765] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([2.679688] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.515619] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<1.705078> *animAmplitude)/100) speed ((<43.066402> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<29.492412> *animAmplitude)/100) speed ((<374.772377> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-36.122494> *animAmplitude)/100) speed ((<581.324982> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-29.492412> *animAmplitude)/100) speed ((<374.772377> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<36.122494> *animAmplitude)/100) speed ((<581.324982> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:30
			move body to y-axis (((([2.800000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([3.609374] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-0.0> *animAmplitude)/100) speed ((<51.152339> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<34.899999> *animAmplitude)/100) speed ((<162.227614> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<-4.099997> *animAmplitude)/100) speed ((<960.674901> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-34.899999> *animAmplitude)/100) speed ((<162.227614> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<4.099997> *animAmplitude)/100) speed ((<960.674901> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:33
			move body to y-axis (((([2.679688] *MOVESCALE)/100) *animAmplitude)/100) speed (((([3.609374] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-1.783203> *animAmplitude)/100) speed ((<53.496092> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<29.175696> *animAmplitude)/100) speed ((<171.729090> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<10.700002> *animAmplitude)/100) speed ((<443.999965> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-29.175696> *animAmplitude)/100) speed ((<171.729090> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-10.700002> *animAmplitude)/100) speed ((<443.999965> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:36
			move body to z-axis (((([1.746562] *MOVESCALE)/100) *animAmplitude)/100) speed (((([7.034765] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([2.362500] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.515626] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-3.390625> *animAmplitude)/100) speed ((<48.222652> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<16.200001> *animAmplitude)/100) speed ((<389.270837> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<15.600002> *animAmplitude)/100) speed ((<146.999997> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-16.200001> *animAmplitude)/100) speed ((<389.270837> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-15.600002> *animAmplitude)/100) speed ((<146.999997> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:39
			move body to z-axis (((([1.415039] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.945703] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([1.914062] *MOVESCALE)/100) *animAmplitude)/100) speed (((([13.453127] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-4.552734> *animAmplitude)/100) speed ((<34.863273> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<1.709016> *animAmplitude)/100) speed ((<434.729552> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<22.872500> *animAmplitude)/100) speed ((<218.174957> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<-1.709016> *animAmplitude)/100) speed ((<434.729552> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-22.872500> *animAmplitude)/100) speed ((<218.174957> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:42
			move body to z-axis (((([1.035000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([11.401169] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([1.400000] *MOVESCALE)/100) *animAmplitude)/100) speed (((([15.421879] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-4.999999> *animAmplitude)/100) speed ((<13.417966> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-10.799996> *animAmplitude)/100) speed ((<375.270369> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<27.400001> *animAmplitude)/100) speed ((<135.825005> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<10.799996> *animAmplitude)/100) speed ((<375.270369> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-27.400001> *animAmplitude)/100) speed ((<135.825005> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:45
			move body to z-axis (((([0.654961] *MOVESCALE)/100) *animAmplitude)/100) speed (((([11.401169] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.885937] *MOVESCALE)/100) *animAmplitude)/100) speed (((([15.421874] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-4.218750> *animAmplitude)/100) speed ((<23.437495> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-19.129323> *animAmplitude)/100) speed ((<249.879807> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<25.687501> *animAmplitude)/100) speed ((<51.374975> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<19.129323> *animAmplitude)/100) speed ((<249.879807> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-25.687501> *animAmplitude)/100) speed ((<51.374975> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:48
			move body to z-axis (((([0.323438] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.945703] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.437500] *MOVESCALE)/100) *animAmplitude)/100) speed (((([13.453124] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-2.500000> *animAmplitude)/100) speed ((<51.562496> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-24.040623> *animAmplitude)/100) speed ((<147.339014> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<18.837501> *animAmplitude)/100) speed ((<205.500004> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<24.040623> *animAmplitude)/100) speed ((<147.339014> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-18.837501> *animAmplitude)/100) speed ((<205.500004> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:51
			move body to z-axis (((([0.088945] *MOVESCALE)/100) *animAmplitude)/100) speed (((([7.034768] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			move body to y-axis (((([0.120312] *MOVESCALE)/100) *animAmplitude)/100) speed (((([9.515622] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-0.781250> *animAmplitude)/100) speed ((<51.562496> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-26.796007> *animAmplitude)/100) speed ((<82.661511> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<6.850001> *animAmplitude)/100) speed ((<359.625020> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<26.796007> *animAmplitude)/100) speed ((<82.661511> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-6.850001> *animAmplitude)/100) speed ((<359.625020> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
		if (isMoving) { //Frame:54
			move body to y-axis (((([0.0] *MOVESCALE)/100) *animAmplitude)/100) speed (((([3.609373] *MOVESCALE)/100) *animAmplitude)/100) / animspeed; //delta=%.2f
			turn body to x-axis ((<-0.0> *animAmplitude)/100) speed ((<23.437495> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn liwing to z-axis ((<-27.699998> *animAmplitude)/100) speed ((<27.119727> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn lowing to z-axis ((<0.0> *animAmplitude)/100) speed ((<205.500017> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn riwing to z-axis ((<27.699998> *animAmplitude)/100) speed ((<27.119727> *animAmplitude)/100) / animspeed; //delta=%.2f
			turn rowing to z-axis ((<-0.0> *animAmplitude)/100) speed ((<205.500017> *animAmplitude)/100) / animspeed; //delta=%.2f
		sleep ((33*animSpeed) -1);
		}
	}
}
// Call this from StopMoving()!
StopWalking() {
	animSpeed = 10; // tune restore speed here, higher values are slower restore speeds
	move body to y-axis ([0.0]*MOVESCALE)/100 speed (([51.406264]*MOVESCALE)/100) / animSpeed;
	move body to z-axis ([0.0]*MOVESCALE)/100 speed (([38.003904]*MOVESCALE)/100) / animSpeed;
	turn body to x-axis <0.0> speed <178.320306> / animSpeed;
	turn liwing to z-axis <0.0> speed <1449.098505> / animSpeed;
	turn lowing to z-axis <0.0> speed <3202.249669> / animSpeed;
	turn riwing to z-axis <0.0> speed <1449.098505> / animSpeed;
	turn rowing to z-axis <0.0> speed <3202.249669> / animSpeed;
}