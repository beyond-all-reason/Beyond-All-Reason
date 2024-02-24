// For N:\animations\Raptors\raptor_death_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5))
//#define DEATHSCALE 100 \Higher values are bigger, 100 is default
//#define DEATHAMPLIDUTE 100 \Higher values are bigger, 100 is default
//#define DEATHSPEED 10;
//use call-script DeathAnim(); from Killed()

DeathAnim() {// For N:\animations\Raptors\raptor_death_remaster_v2.blend Created by https://github.com/Beherith/Skeletor_S3O V((0, 3, 5)) 
	signal SIGNAL_MOVE;
	call-script StopWalking();
		if (TRUE) { //Frame:10
			move body to z-axis (((([-5.896167] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([176.885018] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-5.90
			move body to y-axis (((([-1.441285] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([43.238561] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-1.44
			turn body to x-axis ((<-9.304783> *DEATHAMPLIDUTE)/100) speed ((<279.143488> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=9.30
			turn head to x-axis ((<-19.105139> *DEATHAMPLIDUTE)/100) speed ((<628.946809> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=20.96
			turn head to y-axis ((<4.586712> *DEATHAMPLIDUTE)/100) speed ((<137.601371> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=4.59
			turn lfoot to x-axis ((<7.732979> *DEATHAMPLIDUTE)/100) speed ((<231.989353> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-7.73
			turn lknee to x-axis ((<1.343733> *DEATHAMPLIDUTE)/100) speed ((<40.312002> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-1.34
			turn lshin to x-axis ((<2.315936> *DEATHAMPLIDUTE)/100) speed ((<69.478071> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-2.32
			turn lthigh to x-axis ((<-2.087863> *DEATHAMPLIDUTE)/100) speed ((<62.635891> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=2.09
			turn rfoot to x-axis ((<8.309232> *DEATHAMPLIDUTE)/100) speed ((<232.595149> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-7.75
			turn rknee to x-axis ((<1.609173> *DEATHAMPLIDUTE)/100) speed ((<39.721312> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-1.32
			turn rshin to x-axis ((<2.400634> *DEATHAMPLIDUTE)/100) speed ((<69.685727> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-2.32
			turn rthigh to x-axis ((<-2.339066> *DEATHAMPLIDUTE)/100) speed ((<62.858696> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=2.10
		sleep ((33*DEATHSPEED) -1);
		}
		if (TRUE) { //Frame:20
			move body to x-axis (((([1.131520] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([33.945587] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=1.13
			move body to z-axis (((([-14.731052] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([265.046554] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-8.83
			move body to y-axis (((([-7.554072] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([183.383610] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-6.11
			turn head to x-axis ((<-9.821228> *DEATHAMPLIDUTE)/100) speed ((<278.517322> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-9.28
			turn head to z-axis ((<3.671175> *DEATHAMPLIDUTE)/100) speed ((<32.023222> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-1.07
			turn head to y-axis ((<4.114485> *DEATHAMPLIDUTE)/100) speed ((<14.166820> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-0.47
			turn lfoot to x-axis ((<23.358043> *DEATHAMPLIDUTE)/100) speed ((<468.751930> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-15.63
			turn lfoot to z-axis ((<1.982422> *DEATHAMPLIDUTE)/100) speed ((<59.472675> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-1.98
			turn lfoot to y-axis ((<-0.639766> *DEATHAMPLIDUTE)/100) speed ((<19.192967> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-0.64
			turn lknee to x-axis ((<11.511464> *DEATHAMPLIDUTE)/100) speed ((<305.031927> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-10.17
			turn lshin to x-axis ((<-3.886780> *DEATHAMPLIDUTE)/100) speed ((<186.081477> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=6.20
			turn lthigh to x-axis ((<-21.681607> *DEATHAMPLIDUTE)/100) speed ((<587.812321> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=19.59
			turn lthigh to z-axis ((<-1.936734> *DEATHAMPLIDUTE)/100) speed ((<58.102009> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=1.94
			turn lthigh to y-axis ((<-0.414694> *DEATHAMPLIDUTE)/100) speed ((<12.440831> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-0.41
			turn rfoot to x-axis ((<12.995790> *DEATHAMPLIDUTE)/100) speed ((<140.596746> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-4.69
			turn rfoot to z-axis ((<-24.022209> *DEATHAMPLIDUTE)/100) speed ((<720.666271> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=24.02
			turn rfoot to y-axis ((<6.169877> *DEATHAMPLIDUTE)/100) speed ((<185.096304> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=6.17
			turn rknee to x-axis ((<16.762550> *DEATHAMPLIDUTE)/100) speed ((<454.601304> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-15.15
			turn rshin to x-axis ((<-5.406542> *DEATHAMPLIDUTE)/100) speed ((<234.215280> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=7.81
			turn rthigh to x-axis ((<-14.786289> *DEATHAMPLIDUTE)/100) speed ((<373.416696> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=12.45
			turn rthigh to z-axis ((<24.097288> *DEATHAMPLIDUTE)/100) speed ((<722.918645> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-24.10
			turn rthigh to y-axis ((<4.200525> *DEATHAMPLIDUTE)/100) speed ((<126.015735> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=4.20
		sleep ((33*DEATHSPEED) -1);
		}
		if (TRUE) { //Frame:40
			move body to x-axis (((([1.682695] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([16.535268] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=0.55
			move body to z-axis (((([-21.583813] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([205.582809] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-6.85
			move body to y-axis (((([-36.223907] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) speed (((([860.095053] *DEATHSCALE)/100) *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-28.67
			turn body to x-axis ((<-10.474956> *DEATHAMPLIDUTE)/100) speed ((<35.105183> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=1.17
			turn body to z-axis ((<-4.614926> *DEATHAMPLIDUTE)/100) speed ((<138.447772> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=4.61
			turn body to y-axis ((<-14.876774> *DEATHAMPLIDUTE)/100) speed ((<446.303207> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-14.88
			turn head to x-axis ((<16.704232> *DEATHAMPLIDUTE)/100) speed ((<795.763791> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-26.53
			turn head to z-axis ((<6.721006> *DEATHAMPLIDUTE)/100) speed ((<91.494943> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-3.05
			turn head to y-axis ((<2.765265> *DEATHAMPLIDUTE)/100) speed ((<40.476587> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-1.35
			turn lfoot to x-axis ((<75.523273> *DEATHAMPLIDUTE)/100) speed ((<1564.956900> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-52.17
			turn lfoot to z-axis ((<63.446529> *DEATHAMPLIDUTE)/100) speed ((<1843.923189> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-61.46
			turn lfoot to y-axis ((<-45.770395> *DEATHAMPLIDUTE)/100) speed ((<1353.918894> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-45.13//WARNING: possible gimbal lock issue detected in frame 40 bone lfoot

			turn lknee to x-axis ((<-21.401705> *DEATHAMPLIDUTE)/100) speed ((<987.395062> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=32.91
			turn lshin to x-axis ((<8.285068> *DEATHAMPLIDUTE)/100) speed ((<365.155450> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-12.17
			turn lthigh to x-axis ((<-53.704698> *DEATHAMPLIDUTE)/100) speed ((<960.692727> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=32.02
			turn lthigh to z-axis ((<-31.973167> *DEATHAMPLIDUTE)/100) speed ((<901.093011> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=30.04
			turn lthigh to y-axis ((<-5.176470> *DEATHAMPLIDUTE)/100) speed ((<142.853274> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-4.76
			turn rfoot to x-axis ((<53.717928> *DEATHAMPLIDUTE)/100) speed ((<1221.664155> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-40.72
			turn rfoot to z-axis ((<-74.054905> *DEATHAMPLIDUTE)/100) speed ((<1500.980891> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=50.03
			turn rfoot to y-axis ((<53.222798> *DEATHAMPLIDUTE)/100) speed ((<1411.587627> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=47.05//WARNING: possible gimbal lock issue detected in frame 40 bone rfoot

			turn rknee to x-axis ((<52.245736> *DEATHAMPLIDUTE)/100) speed ((<1064.495586> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-35.48
			turn rshin to x-axis ((<-32.213139> *DEATHAMPLIDUTE)/100) speed ((<804.197926> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=26.81
			turn rthigh to x-axis ((<-59.212884> *DEATHAMPLIDUTE)/100) speed ((<1332.797848> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=44.43
			turn rthigh to z-axis ((<88.289190> *DEATHAMPLIDUTE)/100) speed ((<1925.757066> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=-64.19
			turn rthigh to y-axis ((<76.328225> *DEATHAMPLIDUTE)/100) speed ((<2163.831002> *DEATHAMPLIDUTE)/100) / DEATHSPEED; //delta=72.13//WARNING: possible gimbal lock issue detected in frame 40 bone rthigh

		sleep ((33*DEATHSPEED) -1);
		sleep ((33*DEATHSPEED) -1);
		}
}
