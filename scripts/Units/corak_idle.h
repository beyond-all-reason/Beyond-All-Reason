
static-var bAnimate;
Animate() {//Created by https://github.com/Beherith/Skeletor_S3O from N:\animations\corak_anim_lookaround.blend
	set-signal-mask IDLE_ANIMATION_SIGNAL_MASK; //you might need this
	bAnimate = TRUE;
	if (RAND(1,100) > 10) return; // reduce probs to only 10%
	sleep 10000 + 100*RAND(1,200); // 10-30 secs
	//sleep 5000;//1000* RAND(10, 256);
		if (bAnimate) { //Frame:2
			turn lfoot to x-axis <3.534240> speed <4.158589> ; //delta=-0.28 
			turn lknee to x-axis <-3.894629> speed <3.847424> ; //delta=0.26 
			turn lknee to z-axis <-0.646573> speed <1.870839> ; //delta=-0.12 
			turn lknee to y-axis <-1.466135> speed <1.668904> ; //delta=-0.11 
			turn lleg to x-axis <-0.168082> speed <2.147614> ; //delta=-0.14 
			turn lleg to z-axis <-0.297593> speed <1.825001> ; //delta=-0.12 
			turn lleg to y-axis <0.371215> speed <1.797273> ; //delta=-0.12 
			turn lloarm to x-axis <4.810642> speed <2.180555> ; //delta=0.15 
			turn lthigh to x-axis <-5.598619> speed <4.146254> ; //delta=0.28 
			turn lthigh to z-axis <-1.735319> speed <2.555043> ; //delta=-0.17 
			turn lthigh to y-axis <-0.764644> speed <2.313933> ; //delta=-0.15 
			turn luparm to x-axis <1.347384> speed <7.720674> ; //delta=-0.51 
			turn luparm to z-axis <-8.611279> speed <10.524839> ; //delta=-0.70 
			turn luparm to y-axis <7.284953> speed <6.893783> ; //delta=-0.46 
			turn pelvis to x-axis <5.997371> speed <6.979798> ; //delta=0.47 
			turn pelvis to y-axis <1.177375> speed <17.419473> ; //delta=1.16 
			turn rfoot to x-axis <2.194652> speed <5.789491> ; //delta=0.39 
			turn rknee to x-axis <-4.332868> speed <8.980375> ; //delta=-0.60 
			turn rknee to y-axis <1.574258> speed <3.805298> ; //delta=-0.25 
			turn rleg to z-axis <0.778252> speed <1.680217> ; //delta=-0.11 
			turn rleg to y-axis <-2.443210> speed <2.790540> ; //delta=-0.19 
			turn rloarm to x-axis <4.406768> speed <2.893723> ; //delta=0.19 
			turn rthigh to x-axis <-5.381994> speed <13.595728> ; //delta=-0.91 
			turn rthigh to y-axis <-0.391285> speed <4.798773> ; //delta=-0.32 
			turn ruparm to z-axis <9.348749> speed <10.032246> ; //delta=0.67 
			turn ruparm to y-axis <-7.058618> speed <7.970658> ; //delta=0.53 
			turn torso to x-axis <4.860305> speed <1.760870> ; //delta=0.12 
			turn torso to y-axis <0.953563> speed <17.232400> ; //delta=1.15 
		sleep 65;
		}
		if (bAnimate) { //Frame:8
			turn lfoot to x-axis <6.470205> speed <14.679822> ; //delta=-2.94 
			turn lknee to x-axis <-7.195961> speed <16.506659> ; //delta=3.30 
			turn lknee to z-axis <0.291522> speed <4.690476> ; //delta=-0.94 
			turn lknee to y-axis <-2.768790> speed <6.513275> ; //delta=-1.30 
			turn lleg to x-axis <0.926014> speed <5.470480> ; //delta=-1.09 
			turn lleg to z-axis <0.739874> speed <5.187335> ; //delta=-1.04 
			turn lleg to y-axis <-0.734857> speed <5.530362> ; //delta=-1.11 
			turn lloarm to x-axis <5.136905> speed <1.631314> ; //delta=-0.33 
			turn lthigh to x-axis <-9.797599> speed <20.994898> ; //delta=4.20 
			turn lthigh to z-axis <-0.519363> speed <6.079783> ; //delta=-1.22 
			turn lthigh to y-axis <-2.435915> speed <8.356356> ; //delta=-1.67 
			turn luparm to x-axis <3.715868> speed <11.842419> ; //delta=-2.37 
			turn luparm to z-axis <-8.503504> speed <0.538872> ; //delta=-0.11 
			turn luparm to y-axis <7.126280> speed <0.793363> ; //delta=-0.16 
			turn pelvis to x-axis <5.813659> speed <0.918564> ; //delta=0.18 
			turn pelvis to y-axis <10.288783> speed <45.557036> ; //delta=9.11 
			turn rfoot to x-axis <-0.175812> speed <11.852319> ; //delta=2.37 
			turn rknee to x-axis <-0.864861> speed <17.340035> ; //delta=-3.47 
			turn rknee to z-axis <2.420650> speed <3.008926> ; //delta=-0.60 
			turn rknee to y-axis <0.070199> speed <7.520293> ; //delta=-1.50 
			turn rleg to x-axis <1.884935> speed <1.042496> ; //delta=0.21 
			turn rleg to z-axis <1.578545> speed <4.001468> ; //delta=-0.80 
			turn rleg to y-axis <-3.733579> speed <6.451846> ; //delta=-1.29 
			turn rloarm to x-axis <4.589667> speed <0.914494> ; //delta=-0.18 
			turn rthigh to x-axis <-0.298835> speed <25.415798> ; //delta=-5.08 
			turn rthigh to z-axis <5.205578> speed <4.064560> ; //delta=-0.81 
			turn rthigh to y-axis <-2.389612> speed <9.991637> ; //delta=-2.00 
			turn ruparm to x-axis <-2.494518> speed <13.207081> ; //delta=2.64 
			turn ruparm to z-axis <9.833183> speed <2.422169> ; //delta=-0.48 
			turn ruparm to y-axis <-6.390737> speed <3.339403> ; //delta=0.67 
			turn torso to z-axis <0.794337> speed <1.086805> ; //delta=-0.22 
			turn torso to y-axis <9.859543> speed <44.529901> ; //delta=8.91 
		sleep 197;
		}
		if (bAnimate) { //Frame:10
			turn lfoot to x-axis <6.899492> speed <6.439302> ; //delta=-0.43 
			turn lknee to x-axis <-7.760892> speed <8.473964> ; //delta=0.56 
			turn lknee to y-axis <-2.976033> speed <3.108656> ; //delta=-0.21 
			turn lleg to z-axis <0.849896> speed <1.650325> ; //delta=-0.11 
			turn lleg to y-axis <-0.870387> speed <2.032949> ; //delta=-0.14 
			turn lloarm to x-axis <5.335406> speed <2.977510> ; //delta=-0.20 
			turn lthigh to x-axis <-10.622088> speed <12.367338> ; //delta=0.82 
			turn lthigh to y-axis <-2.690372> speed <3.816858> ; //delta=-0.25 
			turn luparm to x-axis <3.834842> speed <1.784620> ; //delta=-0.12 
			turn luparm to z-axis <-9.196864> speed <10.400397> ; //delta=0.69 
			turn luparm to y-axis <7.549902> speed <6.354336> ; //delta=0.42 
			turn pelvis to x-axis <6.244518> speed <6.462891> ; //delta=-0.43 
			turn pelvis to y-axis <11.450779> speed <17.429943> ; //delta=1.16 
			turn rfoot to x-axis <-0.351429> speed <2.634261> ; //delta=0.18 
			turn rknee to x-axis <-0.595154> speed <4.045603> ; //delta=-0.27 
			turn rknee to y-axis <-0.047572> speed <1.766577> ; //delta=-0.12 
			turn rleg to y-axis <-3.838771> speed <1.577876> ; //delta=-0.11 
			turn rloarm to x-axis <4.809717> speed <3.300742> ; //delta=-0.22 
			turn rthigh to x-axis <0.103039> speed <6.028109> ; //delta=-0.40 
			turn rthigh to y-axis <-2.550800> speed <2.417817> ; //delta=-0.16 
			turn ruparm to x-axis <-3.084121> speed <8.844046> ; //delta=0.59 
			turn ruparm to z-axis <10.602476> speed <11.539404> ; //delta=-0.77 
			turn ruparm to y-axis <-6.756676> speed <5.489090> ; //delta=-0.37 
			turn torso to x-axis <5.037473> speed <2.163631> ; //delta=-0.14 
			turn torso to y-axis <10.991285> speed <16.976128> ; //delta=1.13 
		sleep 65;
		}
		if (bAnimate) { //Frame:15
		sleep 164;
		}
		if (bAnimate) { //Frame:18
			turn lfoot to x-axis <6.584882> speed <3.146100> ; //delta=0.31 
			turn lknee to x-axis <-6.954585> speed <8.063068> ; //delta=-0.81 
			turn lknee to z-axis <0.500055> speed <1.341195> ; //delta=-0.13 
			turn lknee to y-axis <-2.676515> speed <2.995187> ; //delta=0.30 
			turn lleg to x-axis <1.260909> speed <2.356316> ; //delta=-0.24 
			turn lloarm to x-axis <4.548856> speed <7.865496> ; //delta=0.79 
			turn lthigh to x-axis <-9.181955> speed <14.401334> ; //delta=-1.44 
			turn lthigh to z-axis <-0.161528> speed <2.698264> ; //delta=-0.27 
			turn lthigh to y-axis <-2.405681> speed <2.846919> ; //delta=0.28 
			turn luparm to x-axis <4.275590> speed <4.407474> ; //delta=-0.44 
			turn luparm to z-axis <-9.407545> speed <2.106806> ; //delta=0.21 
			turn luparm to y-axis <7.841717> speed <2.918147> ; //delta=0.29 
			turn pelvis to x-axis <4.053852> speed <21.906658> ; //delta=2.19 
			turn rfoot to x-axis <-0.594228> speed <2.427987> ; //delta=0.24 
			turn rknee to x-axis <0.175960> speed <7.711140> ; //delta=-0.77 
			turn rknee to y-axis <-0.362661> speed <3.150888> ; //delta=-0.32 
			turn rleg to x-axis <2.195906> speed <3.163910> ; //delta=-0.32 
			turn rleg to y-axis <-3.982816> speed <1.440453> ; //delta=-0.14 
			turn rloarm to x-axis <4.132042> speed <6.776743> ; //delta=0.68 
			turn rthigh to x-axis <1.457909> speed <13.548700> ; //delta=-1.35 
			turn rthigh to z-axis <5.127607> speed <1.506573> ; //delta=0.15 
			turn rthigh to y-axis <-2.899522> speed <3.487215> ; //delta=-0.35 
			turn ruparm to x-axis <-2.543800> speed <5.403215> ; //delta=-0.54 
			turn ruparm to z-axis <10.471438> speed <1.310380> ; //delta=0.13 
			turn ruparm to y-axis <-6.900505> speed <1.438288> ; //delta=-0.14 
			turn torso to x-axis <4.336888> speed <7.005853> ; //delta=0.70 
			turn torso to z-axis <0.570906> speed <2.561485> ; //delta=0.26 
			turn torso to y-axis <11.158042> speed <1.667574> ; //delta=0.17 
		sleep 98;
		}
		if (bAnimate) { //Frame:27
			turn lfoot to x-axis <4.356557> speed <7.427750> ; //delta=2.23 
			turn lknee to x-axis <-1.180810> speed <19.245917> ; //delta=-5.77 
			turn lknee to z-axis <1.013019> speed <1.709880> ; //delta=-0.51 
			turn lknee to y-axis <-0.571167> speed <7.017827> ; //delta=2.11 
			turn lleg to x-axis <2.893748> speed <5.442794> ; //delta=-1.63 
			turn lleg to z-axis <1.025237> speed <0.403481> ; //delta=-0.12 
			turn lleg to y-axis <-0.214974> speed <2.034718> ; //delta=0.61 
			turn lloarm to x-axis <-2.489793> speed <23.462165> ; //delta=7.04 
			turn lthigh to x-axis <0.098732> speed <30.935624> ; //delta=-9.28 
			turn lthigh to z-axis <1.120297> speed <4.272751> ; //delta=-1.28 
			turn lthigh to y-axis <-0.509242> speed <6.321462> ; //delta=1.90 
			turn luparm to x-axis <5.003712> speed <2.427074> ; //delta=-0.73 
			turn luparm to z-axis <-11.161598> speed <5.846844> ; //delta=1.75 
			turn luparm to y-axis <9.705288> speed <6.211903> ; //delta=1.86 
			turn pelvis to x-axis <-10.477352> speed <48.437348> ; //delta=14.53 
			turn pelvis to z-axis <0.619227> speed <2.630906> ; //delta=-0.79 
			turn pelvis to y-axis <11.952207> speed <1.538110> ; //delta=0.46 
			turn rfoot to x-axis <-1.880219> speed <4.286638> ; //delta=1.29 
			turn rknee to x-axis <5.103957> speed <16.426654> ; //delta=-4.93 
			turn rknee to z-axis <1.872667> speed <1.724473> ; //delta=0.52 
			turn rknee to y-axis <-2.223323> speed <6.202207> ; //delta=-1.86 
			turn rleg to x-axis <4.448077> speed <7.507236> ; //delta=-2.25 
			turn rleg to z-axis <1.420373> speed <0.667499> ; //delta=0.20 
			turn rleg to y-axis <-5.032338> speed <3.498406> ; //delta=-1.05 
			turn rloarm to x-axis <-1.665251> speed <19.324312> ; //delta=5.80 
			turn rthigh to x-axis <10.670823> speed <30.709714> ; //delta=-9.21 
			turn rthigh to z-axis <4.598118> speed <1.764962> ; //delta=0.53 
			turn rthigh to y-axis <-5.222216> speed <7.742314> ; //delta=-2.32 
			turn ruparm to x-axis <-0.612564> speed <6.437453> ; //delta=-1.93 
			turn ruparm to z-axis <10.010417> speed <1.536736> ; //delta=0.46 
			turn ruparm to y-axis <-7.569542> speed <2.230122> ; //delta=-0.67 
			turn torso to x-axis <-2.210076> speed <21.823212> ; //delta=6.55 
			turn torso to z-axis <-1.309957> speed <6.269543> ; //delta=1.88 
			turn torso to y-axis <12.063422> speed <3.017933> ; //delta=0.91 
		sleep 296;
		}
		if (bAnimate) { //Frame:30
			turn lfoot to x-axis <4.101123> speed <2.554333> ; //delta=0.26 
			turn lknee to x-axis <-0.566101> speed <6.147091> ; //delta=-0.61 
			turn lknee to y-axis <-0.340623> speed <2.305437> ; //delta=0.23 
			turn lleg to x-axis <3.051597> speed <1.578497> ; //delta=-0.16 
			turn lloarm to x-axis <-3.480128> speed <9.903347> ; //delta=0.99 
			turn lthigh to x-axis <1.047264> speed <9.485322> ; //delta=-0.95 
			turn lthigh to y-axis <-0.299521> speed <2.097210> ; //delta=0.21 
			turn luparm to x-axis <4.723171> speed <2.805406> ; //delta=0.28 
			turn luparm to z-axis <-11.402264> speed <2.406660> ; //delta=0.24 
			turn luparm to y-axis <9.933002> speed <2.277142> ; //delta=0.23 
			turn pelvis to x-axis <-11.978097> speed <15.007445> ; //delta=1.50 
			turn pelvis to z-axis <0.773276> speed <1.540491> ; //delta=-0.15 
			turn rknee to x-axis <5.582104> speed <4.781474> ; //delta=-0.48 
			turn rknee to y-axis <-2.381932> speed <1.586089> ; //delta=-0.16 
			turn rleg to x-axis <4.697113> speed <2.490368> ; //delta=-0.25 
			turn rleg to y-axis <-5.137731> speed <1.053932> ; //delta=-0.11 
			turn rloarm to x-axis <-2.487686> speed <8.224346> ; //delta=0.82 
			turn rthigh to x-axis <11.654928> speed <9.841048> ; //delta=-0.98 
			turn rthigh to y-axis <-5.459691> speed <2.374750> ; //delta=-0.24 
			turn torso to x-axis <-3.189015> speed <9.789388> ; //delta=0.98 
			turn torso to z-axis <-1.517823> speed <2.078661> ; //delta=0.21 
		sleep 98;
		}
		if (bAnimate) { //Frame:35
		sleep 164;
		}
		if (bAnimate) { //Frame:38
			turn lfoot to x-axis <2.765751> speed <13.353726> ; //delta=1.34 
			turn lknee to x-axis <1.169989> speed <17.360901> ; //delta=-1.74 
			turn lknee to z-axis <0.540563> speed <4.770867> ; //delta=0.48 
			turn lknee to y-axis <0.378143> speed <7.187654> ; //delta=0.72 
			turn lleg to x-axis <2.764715> speed <2.868820> ; //delta=0.29 
			turn lleg to z-axis <0.522894> speed <4.818658> ; //delta=0.48 
			turn lleg to y-axis <0.473052> speed <5.888107> ; //delta=0.59 
			turn lloarm to x-axis <-3.889635> speed <4.095070> ; //delta=0.41 
			turn lthigh to x-axis <3.276871> speed <22.296063> ; //delta=-2.23 
			turn lthigh to z-axis <0.615645> speed <5.727805> ; //delta=0.57 
			turn lthigh to y-axis <0.551764> speed <8.512850> ; //delta=0.85 
			turn luparm to x-axis <5.535507> speed <8.123357> ; //delta=-0.81 
			turn luparm to z-axis <-6.567044> speed <48.352203> ; //delta=-4.84 
			turn luparm to y-axis <6.280217> speed <36.527856> ; //delta=-3.65 
			turn pelvis to x-axis <-13.698462> speed <17.203650> ; //delta=1.72 
			turn pelvis to z-axis <1.169214> speed <3.959381> ; //delta=-0.40 
			turn pelvis to y-axis <9.374154> speed <26.545180> ; //delta=-2.65 
			turn rfoot to x-axis <-1.405361> speed <5.577428> ; //delta=-0.56 
			turn rknee to x-axis <5.162809> speed <4.192946> ; //delta=0.42 
			turn rknee to z-axis <1.483962> speed <3.208825> ; //delta=0.32 
			turn rknee to y-axis <-2.183713> speed <1.982189> ; //delta=0.20 
			turn rleg to x-axis <5.101344> speed <4.042302> ; //delta=-0.40 
			turn rleg to z-axis <1.086600> speed <2.936487> ; //delta=0.29 
			turn rleg to y-axis <-4.759314> speed <3.784168> ; //delta=0.38 
			turn rloarm to x-axis <-3.143605> speed <6.559193> ; //delta=0.66 
			turn rthigh to x-axis <11.260678> speed <3.942505> ; //delta=0.39 
			turn rthigh to z-axis <3.936033> speed <6.435447> ; //delta=0.64 
			turn rthigh to y-axis <-5.0> speed <4.596167> ; //delta=0.46 
			turn ruparm to x-axis <1.606455> speed <22.719155> ; //delta=-2.27 
			turn ruparm to z-axis <4.974051> speed <50.126788> ; //delta=5.01 
			turn ruparm to y-axis <-4.252391> speed <33.535119> ; //delta=3.35 
			turn torso to z-axis <-1.251510> speed <2.663131> ; //delta=-0.27 
			turn torso to y-axis <9.538754> speed <25.913558> ; //delta=-2.59 
		sleep 98;
		}
		if (bAnimate) { //Frame:47
			turn lfoot to x-axis <-5.555122> speed <27.736242> ; //delta=8.32 
			turn lknee to x-axis <9.015325> speed <26.151122> ; //delta=-7.85 
			turn lknee to z-axis <-4.116952> speed <15.525050> ; //delta=4.66 
			turn lknee to y-axis <4.332357> speed <13.180716> ; //delta=3.95 
			turn lleg to x-axis <-1.593205> speed <14.526400> ; //delta=4.36 
			turn lleg to z-axis <-3.363714> speed <12.955358> ; //delta=3.89 
			turn lleg to y-axis <5.450850> speed <16.592663> ; //delta=4.98 
			turn lloarm to x-axis <2.296969> speed <20.622015> ; //delta=-6.19 
			turn lthigh to x-axis <11.798727> speed <28.406186> ; //delta=-8.52 
			turn lthigh to z-axis <-7.128840> speed <25.814948> ; //delta=7.74 
			turn lthigh to y-axis <7.094858> speed <21.810314> ; //delta=6.54 
			turn luparm to x-axis <1.563043> speed <13.241547> ; //delta=3.97 
			turn luparm to z-axis <-8.593805> speed <6.755872> ; //delta=2.03 
			turn luparm to y-axis <7.294350> speed <3.380444> ; //delta=1.01 
			turn pelvis to x-axis <-9.079421> speed <15.396803> ; //delta=-4.62 
			turn pelvis to z-axis <6.840551> speed <18.904454> ; //delta=-5.67 
			turn pelvis to y-axis <-15.104682> speed <81.596118> ; //delta=-24.48 
			turn rfoot to x-axis <9.154631> speed <35.199973> ; //delta=-10.56 
			turn rknee to x-axis <-6.436439> speed <38.664160> ; //delta=11.60 
			turn rknee to z-axis <-2.473911> speed <13.192912> ; //delta=3.96 
			turn rknee to y-axis <2.382798> speed <15.221706> ; //delta=4.57 
			turn rleg to x-axis <9.358297> speed <14.189843> ; //delta=-4.26 
			turn rleg to z-axis <-3.459774> speed <15.154581> ; //delta=4.55 
			turn rleg to y-axis <1.022977> speed <19.274303> ; //delta=5.78 
			turn rloarm to x-axis <1.557571> speed <15.670588> ; //delta=-4.70 
			turn rthigh to x-axis <-3.770439> speed <50.103724> ; //delta=15.03 
			turn rthigh to z-axis <-2.894030> speed <22.766876> ; //delta=6.83 
			turn rthigh to y-axis <2.226706> speed <24.089266> ; //delta=7.23 
			turn ruparm to x-axis <13.132353> speed <38.419659> ; //delta=-11.53 
			turn ruparm to z-axis <1.838401> speed <10.452166> ; //delta=3.14 
			turn ruparm to y-axis <-2.830730> speed <4.738871> ; //delta=1.42 
			turn torso to x-axis <4.147990> speed <24.566648> ; //delta=-7.37 
			turn torso to z-axis <0.578974> speed <6.101612> ; //delta=-1.83 
			turn torso to y-axis <-13.885411> speed <78.080551> ; //delta=-23.42 
		sleep 296;
		}
		if (bAnimate) { //Frame:50
			turn lknee to x-axis <8.655353> speed <3.599723> ; //delta=0.36 
			turn lknee to z-axis <-4.291411> speed <1.744593> ; //delta=0.17 
			turn lknee to y-axis <4.222936> speed <1.094209> ; //delta=-0.11 
			turn lleg to x-axis <-1.967980> speed <3.747749> ; //delta=0.37 
			turn lleg to z-axis <-3.505480> speed <1.417661> ; //delta=0.14 
			turn lloarm to x-axis <4.204562> speed <19.075922> ; //delta=-1.91 
			turn lthigh to x-axis <11.010641> speed <7.880852> ; //delta=0.79 
			turn lthigh to z-axis <-7.397993> speed <2.691534> ; //delta=0.27 
			turn luparm to x-axis <-0.548581> speed <21.116236> ; //delta=2.11 
			turn luparm to z-axis <-12.708528> speed <41.147228> ; //delta=4.11 
			turn luparm to y-axis <10.451489> speed <31.571388> ; //delta=3.16 
			turn pelvis to x-axis <-5.541023> speed <35.383979> ; //delta=-3.54 
			turn pelvis to y-axis <-17.899361> speed <27.946795> ; //delta=-2.79 
			turn rfoot to x-axis <10.490686> speed <13.360550> ; //delta=-1.34 
			turn rknee to x-axis <-8.684208> speed <22.477696> ; //delta=2.25 
			turn rknee to y-axis <3.117345> speed <7.345463> ; //delta=0.73 
			turn rleg to z-axis <-3.753011> speed <2.932369> ; //delta=0.29 
			turn rleg to y-axis <1.598012> speed <5.750355> ; //delta=0.58 
			turn rloarm to x-axis <4.042539> speed <24.849675> ; //delta=-2.48 
			turn rthigh to x-axis <-7.227670> speed <34.572309> ; //delta=3.46 
			turn rthigh to y-axis <3.111921> speed <8.852156> ; //delta=0.89 
			turn ruparm to x-axis <13.859950> speed <7.275970> ; //delta=-0.73 
			turn ruparm to z-axis <6.847225> speed <50.088245> ; //delta=-5.01 
			turn ruparm to y-axis <-5.979700> speed <31.489699> ; //delta=-3.15 
			turn torso to x-axis <6.345194> speed <21.972044> ; //delta=-2.20 
			turn torso to z-axis <0.038718> speed <5.402552> ; //delta=0.54 
			turn torso to y-axis <-16.467969> speed <25.825577> ; //delta=-2.58 
		sleep 98;
		}
		if (bAnimate) { //Frame:55
		sleep 164;
		}
		if (bAnimate) { //Frame:58
			turn lfoot to x-axis <-5.503340> speed <1.292477> ; //delta=-0.13 
			turn lknee to x-axis <8.403736> speed <2.516173> ; //delta=0.25 
			turn lknee to y-axis <4.119345> speed <1.035913> ; //delta=-0.10 
			turn lleg to y-axis <5.396214> speed <1.071695> ; //delta=-0.11 
			turn lloarm to x-axis <4.768658> speed <5.640964> ; //delta=-0.56 
			turn lthigh to x-axis <10.639509> speed <3.711328> ; //delta=0.37 
			turn lthigh to z-axis <-7.269730> speed <1.282633> ; //delta=-0.13 
			turn lthigh to y-axis <6.850700> speed <1.790543> ; //delta=-0.18 
			turn luparm to x-axis <-0.310551> speed <2.380299> ; //delta=-0.24 
			turn pelvis to x-axis <-4.938349> speed <6.026737> ; //delta=-0.60 
			turn pelvis to z-axis <6.726435> speed <1.519504> ; //delta=0.15 
			turn rknee to x-axis <-8.851658> speed <1.674498> ; //delta=0.17 
			turn rleg to x-axis <9.177226> speed <1.607955> ; //delta=0.16 
			turn rloarm to x-axis <4.705855> speed <6.633160> ; //delta=-0.66 
			turn rthigh to x-axis <-7.606103> speed <3.784326> ; //delta=0.38 
			turn rthigh to z-axis <-2.842691> speed <1.460164> ; //delta=-0.15 
			turn ruparm to x-axis <14.055008> speed <1.950582> ; //delta=-0.20 
			turn torso to x-axis <6.982145> speed <6.369506> ; //delta=-0.64 
			turn torso to z-axis <-0.062434> speed <1.011520> ; //delta=0.10 
		sleep 98;
		}
		if (bAnimate) { //Frame:64
			turn lfoot to x-axis <-4.803150> speed <3.500950> ; //delta=-0.70 
			turn lknee to x-axis <7.097762> speed <6.529868> ; //delta=1.31 
			turn lknee to z-axis <-4.006197> speed <1.212566> ; //delta=-0.24 
			turn lknee to y-axis <3.564338> speed <2.775033> ; //delta=-0.56 
			turn lleg to z-axis <-3.310146> speed <0.837020> ; //delta=-0.17 
			turn lleg to y-axis <4.847789> speed <2.742122> ; //delta=-0.55 
			turn lloarm to x-axis <7.551911> speed <13.916267> ; //delta=-2.78 
			turn lthigh to x-axis <8.732962> speed <9.532733> ; //delta=1.91 
			turn lthigh to z-axis <-6.638979> speed <3.153754> ; //delta=-0.63 
			turn lthigh to y-axis <5.946769> speed <4.519656> ; //delta=-0.90 
			turn luparm to x-axis <0.482096> speed <3.963235> ; //delta=-0.79 
			turn luparm to y-axis <9.993301> speed <1.951581> ; //delta=-0.39 
			turn pelvis to x-axis <-1.782308> speed <15.780204> ; //delta=-3.16 
			turn pelvis to z-axis <5.893577> speed <4.164289> ; //delta=0.83 
			turn pelvis to y-axis <-18.033472> speed <0.587746> ; //delta=-0.12 
			turn rknee to x-axis <-9.749589> speed <4.489654> ; //delta=0.90 
			turn rknee to z-axis <-2.002985> speed <2.127123> ; //delta=-0.43 
			turn rknee to y-axis <3.530293> speed <1.733202> ; //delta=0.35 
			turn rleg to x-axis <8.341027> speed <4.180994> ; //delta=0.84 
			turn rleg to z-axis <-3.384579> speed <1.556382> ; //delta=-0.31 
			turn rloarm to x-axis <7.837972> speed <15.660589> ; //delta=-3.13 
			turn rthigh to x-axis <-9.617791> speed <10.058440> ; //delta=2.01 
			turn rthigh to z-axis <-2.063675> speed <3.895078> ; //delta=-0.78 
			turn rthigh to y-axis <3.387133> speed <1.166908> ; //delta=0.23 
			turn ruparm to x-axis <14.447525> speed <1.962587> ; //delta=-0.39 
			turn ruparm to z-axis <6.605916> speed <0.986452> ; //delta=0.20 
			turn ruparm to y-axis <-5.366374> speed <2.573634> ; //delta=0.51 
			turn torso to x-axis <9.836777> speed <14.273162> ; //delta=-2.85 
			turn torso to z-axis <-0.575537> speed <2.565516> ; //delta=0.51 
			turn torso to y-axis <-16.252102> speed <0.895873> ; //delta=0.18 
		sleep 197;
		}
		if (bAnimate) { //Frame:67
			turn lfoot to x-axis <-4.614133> speed <1.890169> ; //delta=-0.19 
			turn lknee to x-axis <6.756939> speed <3.408230> ; //delta=0.34 
			turn lknee to y-axis <3.415577> speed <1.487611> ; //delta=-0.15 
			turn lleg to y-axis <4.708145> speed <1.396441> ; //delta=-0.14 
			turn lloarm to x-axis <8.262436> speed <7.105249> ; //delta=-0.71 
			turn lthigh to x-axis <8.239311> speed <4.936511> ; //delta=0.49 
			turn lthigh to z-axis <-6.486320> speed <1.526586> ; //delta=-0.15 
			turn lthigh to y-axis <5.718600> speed <2.281693> ; //delta=-0.23 
			turn luparm to x-axis <0.594842> speed <1.127460> ; //delta=-0.11 
			turn luparm to y-axis <9.879860> speed <1.134409> ; //delta=-0.11 
			turn pelvis to x-axis <-0.952012> speed <8.302960> ; //delta=-0.83 
			turn pelvis to z-axis <5.668926> speed <2.246513> ; //delta=0.22 
			turn rknee to x-axis <-9.990626> speed <2.410374> ; //delta=0.24 
			turn rknee to z-axis <-1.886510> speed <1.164741> ; //delta=-0.12 
			turn rleg to x-axis <8.125105> speed <2.159219> ; //delta=0.22 
			turn rloarm to x-axis <8.604304> speed <7.663319> ; //delta=-0.77 
			turn rthigh to x-axis <-10.155486> speed <5.376947> ; //delta=0.54 
			turn rthigh to z-axis <-1.856060> speed <2.076156> ; //delta=-0.21 
			turn ruparm to y-axis <-5.228156> speed <1.382183> ; //delta=0.14 
			turn torso to x-axis <10.493584> speed <6.568072> ; //delta=-0.66 
			turn torso to z-axis <-0.707569> speed <1.320320> ; //delta=0.13 
		sleep 98;
		}
		if (bAnimate) { //Frame:73
		sleep 197;
		}
		if (bAnimate) { //Frame:76
			turn lfoot to x-axis <-4.032899> speed <5.812346> ; //delta=-0.58 
			turn lknee to x-axis <5.888729> speed <8.682101> ; //delta=0.87 
			turn lknee to z-axis <-3.682300> speed <2.569620> ; //delta=-0.26 
			turn lknee to y-axis <3.018729> speed <3.968487> ; //delta=-0.40 
			turn lleg to z-axis <-3.066770> speed <1.949951> ; //delta=-0.19 
			turn lleg to y-axis <4.294094> speed <4.140508> ; //delta=-0.41 
			turn lloarm to x-axis <7.111818> speed <11.506179> ; //delta=1.15 
			turn lthigh to x-axis <7.066641> speed <11.726696> ; //delta=1.17 
			turn lthigh to z-axis <-5.971037> speed <5.152836> ; //delta=-0.52 
			turn lthigh to y-axis <5.093203> speed <6.253965> ; //delta=-0.63 
			turn luparm to x-axis <1.241857> speed <6.470147> ; //delta=-0.65 
			turn luparm to z-axis <-10.540274> speed <20.927443> ; //delta=-2.09 
			turn luparm to y-axis <8.312291> speed <15.675694> ; //delta=-1.57 
			turn pelvis to x-axis <-1.253958> speed <3.019461> ; //delta=0.30 
			turn pelvis to z-axis <5.299168> speed <3.697583> ; //delta=0.37 
			turn pelvis to y-axis <-15.522503> speed <25.472337> ; //delta=2.55 
			turn rfoot to x-axis <9.239115> speed <11.191359> ; //delta=1.12 
			turn rknee to x-axis <-8.861999> speed <11.286273> ; //delta=-1.13 
			turn rknee to z-axis <-1.605960> speed <2.805509> ; //delta=-0.28 
			turn rknee to y-axis <3.294650> speed <3.267543> ; //delta=-0.33 
			turn rleg to x-axis <7.522218> speed <6.028871> ; //delta=0.60 
			turn rleg to z-axis <-2.881130> speed <4.194014> ; //delta=-0.42 
			turn rleg to y-axis <1.003595> speed <4.759662> ; //delta=-0.48 
			turn rloarm to x-axis <7.078073> speed <15.262310> ; //delta=1.53 
			turn rthigh to x-axis <-8.794000> speed <13.614855> ; //delta=-1.36 
			turn rthigh to z-axis <-1.278242> speed <5.778179> ; //delta=-0.58 
			turn rthigh to y-axis <2.904180> speed <5.489735> ; //delta=-0.55 
			turn ruparm to x-axis <12.632654> speed <17.816472> ; //delta=1.78 
			turn ruparm to z-axis <3.782270> speed <27.791519> ; //delta=2.78 
			turn ruparm to y-axis <-3.785364> speed <14.427921> ; //delta=1.44 
			turn torso to x-axis <8.894727> speed <15.988576> ; //delta=1.60 
			turn torso to y-axis <-13.700081> speed <25.073829> ; //delta=2.51 
		sleep 98;
		}
		if (bAnimate) { //Frame:82
			turn lfoot to x-axis <1.539990> speed <27.864444> ; //delta=-5.57 
			turn lknee to x-axis <-1.532627> speed <37.106783> ; //delta=7.42 
			turn lknee to z-axis <-1.371551> speed <11.553744> ; //delta=-2.31 
			turn lknee to y-axis <-0.439211> speed <17.289699> ; //delta=-3.46 
			turn lleg to x-axis <-0.781799> speed <5.749154> ; //delta=-1.15 
			turn lleg to z-axis <-1.034995> speed <10.158873> ; //delta=-2.03 
			turn lleg to y-axis <1.220412> speed <15.368411> ; //delta=-3.07 
			turn lloarm to x-axis <4.768920> speed <11.714494> ; //delta=2.34 
			turn lthigh to x-axis <-2.627452> speed <48.470467> ; //delta=9.69 
			turn lthigh to z-axis <-2.619854> speed <16.755913> ; //delta=-3.35 
			turn lthigh to y-axis <0.504795> speed <22.942040> ; //delta=-4.59 
			turn luparm to z-axis <-7.933753> speed <13.032603> ; //delta=-2.61 
			turn luparm to y-axis <6.715553> speed <7.983689> ; //delta=-1.60 
			turn pelvis to x-axis <4.277929> speed <27.659439> ; //delta=-5.53 
			turn pelvis to z-axis <1.074746> speed <21.122110> ; //delta=4.22 
			turn pelvis to y-axis <-2.866850> speed <63.278266> ; //delta=12.66 
			turn rfoot to x-axis <3.733102> speed <27.530064> ; //delta=5.51 
			turn rknee to x-axis <-5.384665> speed <17.386667> ; //delta=-3.48 
			turn rknee to z-axis <1.008973> speed <13.074662> ; //delta=-2.61 
			turn rknee to y-axis <2.040674> speed <6.269879> ; //delta=-1.25 
			turn rleg to x-axis <3.200418> speed <21.609001> ; //delta=4.32 
			turn rleg to z-axis <-0.041016> speed <14.200571> ; //delta=-2.84 
			turn rleg to y-axis <-1.624358> speed <13.139765> ; //delta=-2.63 
			turn rloarm to x-axis <4.649917> speed <12.140781> ; //delta=2.43 
			turn rthigh to x-axis <-6.274795> speed <12.596024> ; //delta=-2.52 
			turn rthigh to z-axis <3.109397> speed <21.938195> ; //delta=-4.39 
			turn rthigh to y-axis <0.441829> speed <12.311754> ; //delta=-2.46 
			turn ruparm to x-axis <2.850591> speed <48.910319> ; //delta=9.78 
			turn ruparm to z-axis <6.462509> speed <13.401192> ; //delta=-2.68 
			turn ruparm to y-axis <-5.656216> speed <9.354262> ; //delta=-1.87 
			turn torso to x-axis <5.183302> speed <18.557122> ; //delta=3.71 
			turn torso to z-axis <-0.111645> speed <3.191789> ; //delta=-0.64 
			turn torso to y-axis <-2.487674> speed <56.062032> ; //delta=11.21 
		sleep 197;
		}
		if (bAnimate) { //Frame:85
			turn lfoot to x-axis <3.257001> speed <17.170112> ; //delta=-1.72 
			turn lknee to x-axis <-3.638134> speed <21.055070> ; //delta=2.11 
			turn lknee to z-axis <-0.771296> speed <6.002551> ; //delta=-0.60 
			turn lknee to y-axis <-1.354874> speed <9.156632> ; //delta=-0.92 
			turn lleg to x-axis <-0.311256> speed <4.705434> ; //delta=-0.47 
			turn lleg to z-axis <-0.419260> speed <6.157352> ; //delta=-0.62 
			turn lleg to y-axis <0.491033> speed <7.293786> ; //delta=-0.73 
			turn lloarm to x-axis <4.956013> speed <1.870930> ; //delta=-0.19 
			turn lthigh to x-axis <-5.322203> speed <26.947504> ; //delta=2.69 
			turn lthigh to z-axis <-1.905655> speed <7.141987> ; //delta=-0.71 
			turn lthigh to y-axis <-0.610382> speed <11.151771> ; //delta=-1.12 
			turn luparm to x-axis <0.832672> speed <4.202195> ; //delta=0.42 
			turn luparm to z-axis <-9.312935> speed <13.791817> ; //delta=1.38 
			turn luparm to y-axis <7.744538> speed <10.289851> ; //delta=1.03 
			turn pelvis to x-axis <6.462691> speed <21.847619> ; //delta=-2.18 
			turn pelvis to z-axis <-0.315834> speed <13.905801> ; //delta=1.39 
			turn pelvis to y-axis <0.016077> speed <28.829270> ; //delta=2.88 
			turn rfoot to x-axis <2.580618> speed <11.524843> ; //delta=1.15 
			turn rknee to x-axis <-4.931559> speed <4.531062> ; //delta=-0.45 
			turn rknee to z-axis <1.755459> speed <7.464866> ; //delta=-0.75 
			turn rknee to y-axis <1.827945> speed <2.127297> ; //delta=-0.21 
			turn rleg to x-axis <2.101993> speed <10.984244> ; //delta=1.10 
			turn rleg to z-axis <0.666237> speed <7.072530> ; //delta=-0.71 
			turn rleg to y-axis <-2.257174> speed <6.328155> ; //delta=-0.63 
			turn rthigh to z-axis <4.331624> speed <12.222271> ; //delta=-1.22 
			turn rthigh to y-axis <-0.071367> speed <5.131962> ; //delta=-0.51 
			turn ruparm to x-axis <0.228506> speed <26.220848> ; //delta=2.62 
			turn ruparm to z-axis <10.017565> speed <35.550567> ; //delta=-3.56 
			turn ruparm to y-axis <-7.589995> speed <19.337785> ; //delta=-1.93 
			turn torso to x-axis <4.977696> speed <2.056058> ; //delta=0.21 
			turn torso to z-axis <0.546937> speed <6.585820> ; //delta=-0.66 
			turn torso to y-axis <-0.195264> speed <22.924103> ; //delta=2.29 
		sleep 98;
		}
}
// Call this from StopMoving()!
StopAnimation() {
	turn lfoot to x-axis <3.257001> speed <27.864444>;
	turn lfoot to y-axis <18.400267> speed <-6.494212>;
	turn lknee to x-axis <-3.638134> speed <37.106783>;
	turn lknee to y-axis <-1.354874> speed <17.289699>;
	turn lknee to z-axis <-0.771296> speed <15.525050>;
	turn lleg to x-axis <-0.311256> speed <14.526400>;
	turn lleg to y-axis <0.491033> speed <16.592663>;
	turn lleg to z-axis <-0.419260> speed <12.955358>;
	turn lloarm to x-axis <4.956013> speed <23.462165>;
	turn lthigh to x-axis <-5.322203> speed <48.470467>;
	turn lthigh to y-axis <-0.610382> speed <22.942040>;
	turn lthigh to z-axis <-1.905655> speed <25.814948>;
	turn luparm to x-axis <0.832672> speed <21.116236>;
	turn luparm to y-axis <7.744538> speed <36.527856>;
	turn luparm to z-axis <-9.312935> speed <48.352203>;
	turn pelvis to x-axis <6.462691> speed <48.437348>;
	turn pelvis to y-axis <0.0> speed <81.596118>;
	turn pelvis to z-axis <-0.315834> speed <21.122110>;
	turn rfoot to x-axis <2.580618> speed <35.199973>;
	turn rfoot to y-axis <-18.801545> speed <-6.635840>;
	turn rknee to x-axis <-4.931559> speed <38.664160>;
	turn rknee to y-axis <1.827945> speed <15.221706>;
	turn rknee to z-axis <1.755459> speed <13.192912>;
	turn rleg to x-axis <2.101993> speed <21.609001>;
	turn rleg to y-axis <-2.257174> speed <19.274303>;
	turn rleg to z-axis <0.666237> speed <15.154581>;
	turn rloarm to x-axis <4.599683> speed <24.849675>;
	turn rthigh to x-axis <-6.288376> speed <50.103724>;
	turn rthigh to y-axis <0.0> speed <24.089266>;
	turn rthigh to z-axis <4.331624> speed <22.766876>;
	turn ruparm to x-axis <0.228506> speed <48.910319>;
	turn ruparm to y-axis <-7.589995> speed <33.535119>;
	turn ruparm to z-axis <10.017565> speed <50.126788>;
	turn torso to x-axis <4.977696> speed <24.566648>;
	turn torso to y-axis <-0.195264> speed <78.080551>;
	turn torso to z-axis <0.546937> speed <6.585820>;
}
