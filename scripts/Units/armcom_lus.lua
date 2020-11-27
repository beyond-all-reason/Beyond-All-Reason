--INCREMENT THIS COUNTER FOR EVERY HOUR OF YOUR LIFE WASTED HERE: 25



--Skeleton pieces
local head, torso, luparm, biggun, ruparm,rloarm,lflare, nano, laserflare, pelvis, rthigh, lthigh ,lleg ,rleg,rfoot ,lfoot, dish, barrel, aimy1, bigguncyl,hatpoint = piece("head", "torso", "luparm", "biggun", "ruparm","rloarm","lflare", "nano", "laserflare", "pelvis", "rthigh", "lthigh" ,"lleg" ,"rleg","rfoot" ,"lfoot", "dish", "barrel", "aimy1","bigguncyl","hatpoint")    

local weapons = {
	[1] = "laser",
	[2] = "uwlaser",
	[3] = "dgun",
	[4] = "dgun",
	[5] = "dgun",
	[6] = "dgun",
	[7] = "dgun",
	[8] = "dgun",
	[9] = "dgun",
	[10] = "dgun",
	[11] = "dgun",
	[12] = "dgun",
	[13] = "dgun",
	[14] = "dgun",
	[15] = "dgun",
	[16] = "dgun",
	[17] = "dgun",
	[18] = "dgun",
	[19] = "dgun",
	[20] = "dgun",
	[21] = "dgun",
	[22] = "dgun",
	[23] = "dgun",
	[24] = "dgun",
	[25] = "dgun",
	[26] = "dgun",
	[27] = "dgun",
	[28] = "dgun",
	[29] = "dgun",
	[30] = "dgun",
	[31] = "dgun",
	[32] = "dgun",
	}
	


local SIG_AIM = 2
local SIG_WALK = 4
local PlaySoundFile 	= Spring.PlaySoundFile
local GetUnitPosition 	= Spring.GetUnitPosition
local GetGameFrame 		= Spring.GetGameFrame
local HealRefreshTime	= 15
local CEGHeal = "heal"
local CEGLevelUp = "commander-levelup"
local ValidID = Spring.ValidUnitID

local function BelowWater(piecename)
	x,y,z = Spring.GetUnitPiecePosition(unitID, piecename)
	if y <= 0 then
		return true
	else
		return false
	end
end

local rad = math.rad

local function turn(piece, axis, goal, speed)
	if speed then
		if axis == 3 then
			Turn(piece, axis, -rad(goal), rad(speed))		
		else
			Turn(piece, axis, rad(goal), rad(speed))
		end
	else
		Turn(piece, axis, rad(goal))
	end
end

local function move(piece, axis, goal, speed)
	Move(piece, axis, goal, speed)
end

function walk()
	if (bMoving) then --Frame:4
				if (leftArm) then turn(biggun, 1, -48.215180, 113.735764/animSpeed) --delta=-3.79
				turn(head, 1, -2.620635, 39.654598/animSpeed) --delta=1.32
				turn(head, 2, -3.829846, 114.895376/animSpeed) --delta=-3.83
				turn(lfoot, 1, -33.266887, 1084.110406/animSpeed) --delta=36.14
				turn(lleg, 1, 55.932201, 1005.195679/animSpeed) --delta=-33.51
				turn(lthigh, 1, -55.237751, 1023.679605/animSpeed) --delta=34.12
				turn(lthigh, 3,  10.085981, 605.673206/animSpeed) --delta=-20.19
				turn(lthigh, 2, 15.046731, 118.088344/animSpeed) --delta=3.94
				if (leftArm) then turn(luparm, 1, 9.919362, 279.367450/animSpeed) end --delta=9.31
				if (leftArm) then turn(luparm, 3,  -12.399998, 114.000041/animSpeed) end--delta=-3.80
				if (leftArm) then turn(luparm, 2, 0.965138, 187.380006/animSpeed) end--delta=-6.25
				turn(pelvis, 3,  -1.666667, 49.999997/animSpeed) --delta=1.67
				turn(pelvis, 2, -2.296296, 68.888891/animSpeed) --delta=-2.30
				turn(rfoot, 1, -24.788553, 756.115081/animSpeed) --delta=25.20
				turn(rleg, 1, 21.945633, 114.672797/animSpeed) --delta=3.82
				if (rightArm) then turn(rloarm, 1, -56.129627, 87.888962/animSpeed) end--delta=2.93
				turn(rthigh, 1, 3.073465, 750.722777/animSpeed) --delta=-25.02
				turn(rthigh, 3,  1.955836, 223.218383/animSpeed) --delta=7.44
				turn(rthigh, 2, -0.370374, 346.061345/animSpeed) --delta=11.54
				if (rightArm) then turn(ruparm, 1, 21.424041, 98.073542/animSpeed) end--delta=3.27
				if (rightArm) then turn(ruparm, 2, 1.762963, 52.888889/animSpeed) end--delta=1.76
				turn(aimy1, 1, -4.288164, 60.727696/animSpeed) --delta=2.02
				turn(aimy1, 3,  1.713372, 51.401158/animSpeed) --delta=-1.71
				turn(aimy1, 2, 7.879434, 236.383029/animSpeed) --delta=7.88
			Sleep( (33*animSpeed) -1)
		end
		while(bMoving) do
			if (bMoving) then --Frame:8
				if (leftArm) then turn(biggun, 1, -46.675856, 46.179694/animSpeed) end--delta=-1.54
				turn(head, 1, -1.563179, 31.723679/animSpeed) --delta=-1.06
				turn(head, 2, -6.127755, 68.937274/animSpeed) --delta=-2.30
				turn(lfoot, 1, 3.301643, 1097.055898/animSpeed) --delta=-36.57
				turn(lleg, 1, 21.188054, 1042.324382/animSpeed) --delta=34.74
				turn(lthigh, 1, -49.309980, 177.833127/animSpeed) --delta=-5.93
				turn(lthigh, 3,  12.410994, 69.750404/animSpeed) --delta=-2.33
				turn(lthigh, 2, 17.664281, 78.526514/animSpeed) --delta=2.62
				if (leftArm) then turn(luparm, 1, 17.175860, 217.694940/animSpeed) end--delta=-7.26
				if (leftArm) then turn(luparm, 2, 2.994882, 60.892341/animSpeed) end--delta=2.03
				move (pelvis, 2,  -1.370370 , 8.888887 /animSpeed) --delta=-0.30
				turn(pelvis, 3,  -4.074074, 72.222229/animSpeed) --delta=2.41
				turn(pelvis, 2, -5.185185, 86.666661/animSpeed) --delta=-2.89
				turn(rfoot, 1, -24.385273, 12.098399/animSpeed) --delta=-0.40
				turn(rleg, 1, 2.775391, 575.107266/animSpeed) --delta=19.17
				if (rightArm) then turn(rloarm, 1, -61.570378, 163.222533/animSpeed) end--delta=5.44
				turn(rthigh, 1, 24.923063, 655.487959/animSpeed) --delta=-21.85
				turn(rthigh, 3,  7.511525, 166.670667/animSpeed) --delta=-5.56
				turn(rthigh, 2, -5.809679, 163.179149/animSpeed) --delta=-5.44
				if (rightArm) then turn(ruparm, 1, 16.696394, 141.829407/animSpeed) end--delta=4.73
				if (rightArm) then turn(ruparm, 2, 5.908277, 124.359412/animSpeed) end--delta=4.15
				turn(aimy1, 1, -3.674753, 18.402335/animSpeed) --delta=-0.61
				turn(aimy1, 3,  4.188244, 74.246156/animSpeed) --delta=-2.47
				turn(aimy1, 2, 13.926961, 181.425790/animSpeed) --delta=6.05
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:12
				if (leftArm) then turn(biggun, 1, -46.110552, 16.959121/animSpeed) end--delta=-0.57
				turn(head, 1, 0.023005, 47.585527/animSpeed) --delta=-1.59
				turn(head, 2, -7.659692, 45.958102/animSpeed) --delta=-1.53
				turn(lfoot, 1, 11.411680, 243.301125/animSpeed) --delta=-8.11
				turn(lleg, 1, -6.333642, 825.650884/animSpeed) --delta=27.52
				turn(lthigh, 1, -28.939382, 611.117960/animSpeed) --delta=-20.37
				turn(lthigh, 3,  10.100023, 69.329144/animSpeed) --delta=2.31
				turn(lthigh, 2, 14.540810, 93.704134/animSpeed) --delta=-3.12
				if (leftArm) then turn(luparm, 1, 20.474264, 98.952127/animSpeed) end--delta=-3.30
				if (leftArm) then turn(luparm, 2, 5.388938, 71.821661/animSpeed) end--delta=2.39
				move (pelvis, 2,  -2.000000 , 18.888888 /animSpeed) --delta=-0.63
				turn(pelvis, 3,  -5.000000, 27.777769/animSpeed) --delta=0.93
				turn(pelvis, 2, -6.000000, 24.444453/animSpeed) --delta=-0.81
				turn(rfoot, 1, -34.556331, 305.131751/animSpeed) --delta=10.17
				turn(rleg, 1, 32.187523, 882.363941/animSpeed) --delta=-29.41
				if (rightArm) then turn(rloarm, 1, -64.499997, 87.888552/animSpeed) end--delta=2.93
				turn(rthigh, 1, 18.715526, 186.226115/animSpeed) --delta=6.21
				turn(rthigh, 3,  9.760341, 67.464476/animSpeed) --delta=-2.25
				turn(rthigh, 2, -5.182428, 18.817525/animSpeed) --delta=0.63
				if (rightArm) then turn(ruparm, 1, 12.622570, 122.214735/animSpeed) end--delta=4.07
				if (rightArm) then turn(ruparm, 2, 6.799999, 26.751678/animSpeed) end--delta=0.89
				turn(aimy1, 1, -2.141225, 46.005832/animSpeed) --delta=-1.53
				turn(aimy1, 3,  5.140116, 28.556180/animSpeed) --delta=-0.95
				turn(aimy1, 2, 15.758869, 54.957239/animSpeed) --delta=1.83
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:16
				if (leftArm) then turn(biggun, 1, -47.068049, 28.724907/animSpeed) end--delta=0.96
				turn(head, 1, -0.505722, 15.861819/animSpeed) --delta=0.53
				turn(head, 2, -6.127755, 45.958102/animSpeed) --delta=1.53
				turn(lfoot, 1, 2.879686, 255.959826/animSpeed) --delta=8.53
				turn(lleg, 1, 40.292208, 1398.775490/animSpeed) --delta=-46.63
				turn(lthigh, 1, -49.313423, 611.221232/animSpeed) --delta=20.37
				turn(lthigh, 3,  11.258773, 34.762504/animSpeed) --delta=-1.16
				turn(lthigh, 2, 17.221502, 80.420765/animSpeed) --delta=2.68
				if (leftArm) then turn(luparm, 1, 19.047441, 42.804693/animSpeed) end--delta=1.43
				move (pelvis, 2,  -2.833333 , 25.000005 /animSpeed) --delta=-0.83
				turn(pelvis, 3,  -3.962963, 31.111110/animSpeed) --delta=-1.04
				turn(pelvis, 2, -5.026455, 29.206358/animSpeed) --delta=0.97
				turn(rfoot, 1, -27.196287, 220.801335/animSpeed) --delta=-7.36
				turn(rleg, 1, 78.322421, 1384.046960/animSpeed) --delta=-46.13
				turn(rleg, 3,  -0.165893, 4.758378/animSpeed) --delta=0.16
				turn(rleg, 2, 0.140044, 4.092714/animSpeed) --delta=0.14
				if (rightArm) then turn(rloarm, 1, -62.031478, 74.055575/animSpeed) end--delta=-2.47
				turn(rthigh, 1, -2.425270, 634.223885/animSpeed) --delta=21.14
				turn(rthigh, 3,  5.889018, 116.139691/animSpeed) --delta=3.87
				turn(rthigh, 2, 2.215249, 221.930321/animSpeed) --delta=7.40
				if (rightArm) then turn(ruparm, 1, 12.782766, 4.805883/animSpeed) end--delta=-0.16
				if (rightArm) then turn(ruparm, 2, 6.141609, 19.751703/animSpeed) end--delta=-0.66
				turn(aimy1, 1, -3.061342, 27.603503/animSpeed) --delta=0.92
				turn(aimy1, 3,  4.074019, 31.982933/animSpeed) --delta=1.07
				turn(aimy1, 2, 13.926961, 54.957239/animSpeed) --delta=-1.83
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:20
				if (leftArm) then turn(biggun, 1, -49.335727, 68.030323/animSpeed) end--delta=2.27
				turn(head, 1, -2.091907, 47.585562/animSpeed) --delta=1.59
				turn(head, 2, -3.829846, 68.937274/animSpeed) --delta=2.30
				turn(lfoot, 1, -11.362748, 427.273021/animSpeed) --delta=14.24
				turn(lleg, 1, 55.773467, 464.437769/animSpeed) --delta=-15.48
				turn(lthigh, 1, -43.832869, 164.416621/animSpeed) --delta=-5.48
				turn(lthigh, 3,  4.706604, 196.565054/animSpeed) --delta=6.55
				turn(lthigh, 2, 8.321622, 266.996423/animSpeed) --delta=-8.90
				if (leftArm) then turn(luparm, 1, 15.615877, 102.946916/animSpeed) end--delta=3.43
				if (leftArm) then turn(luparm, 2, 5.076670, 9.368019/animSpeed) end--delta=-0.31
				turn(pelvis, 3,  -2.000000, 58.888879/animSpeed) --delta=-1.96
				turn(pelvis, 2, -2.772487, 67.619039/animSpeed) --delta=2.25
				turn(rfoot, 1, -39.119034, 357.682424/animSpeed) --delta=11.92
				turn(rleg, 1, 104.636879, 789.433742/animSpeed) --delta=-26.31
				turn(rleg, 3,  0.031377, 5.918091/animSpeed) --delta=-0.20
				turn(rleg, 2, -0.045903, 5.578386/animSpeed) --delta=-0.19
				if (rightArm) then turn(rloarm, 1, -56.185181, 175.388910/animSpeed) end--delta=-5.85
				turn(rthigh, 1, -29.245227, 804.598715/animSpeed) --delta=26.82
				turn(rthigh, 3,  3.330593, 76.752755/animSpeed) --delta=2.56
				turn(rthigh, 2, -1.498384, 111.408996/animSpeed) --delta=-3.71
				if (rightArm) then turn(ruparm, 1, 13.904138, 33.641183/animSpeed) end--delta=-1.12
				if (rightArm) then turn(ruparm, 2, 2.429630, 111.359389/animSpeed) end--delta=-3.71
				turn(aimy1, 1, -3.981459, 27.603503/animSpeed) --delta=0.92
				turn(aimy1, 3,  2.056047, 60.539158/animSpeed) --delta=2.02
				turn(aimy1, 2, 7.879434, 181.425790/animSpeed) --delta=-6.05
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:24
				if (leftArm) then turn(biggun, 1, -52.006372, 80.119348/animSpeed) end--delta=2.67
				turn(head, 1, -3.149363, 31.723676/animSpeed) --delta=1.06
				turn(head, 2, 0.000000, 114.895376/animSpeed) --delta=3.83
				turn(lfoot, 1, -23.280778, 357.540911/animSpeed) --delta=11.92
				turn(lleg, 1, 46.510843, 277.878733/animSpeed) --delta=9.26
				turn(lthigh, 1, -23.415420, 612.523459/animSpeed) --delta=-20.42
				turn(lthigh, 3,  0.280779, 132.774760/animSpeed) --delta=4.43
				turn(lthigh, 2, 1.272165, 211.483711/animSpeed) --delta=-7.05
				if (leftArm) then turn(luparm, 1, 11.452920, 124.888703/animSpeed) end--delta=4.16
				if (leftArm) then turn(luparm, 2, 3.308728, 53.038265/animSpeed) end--delta=-1.77
				move (pelvis, 2,  -2.000000 , 25.555551 /animSpeed) --delta=0.85
				turn(pelvis, 3,  -0.000000, 60.000006/animSpeed) --delta=-2.00
				turn(pelvis, 2, 0.000000, 83.174607/animSpeed) --delta=2.77
				turn(rfoot, 1, -45.278120, 184.772566/animSpeed) --delta=6.16
				turn(rleg, 1, 90.786697, 415.505474/animSpeed) --delta=13.85
				turn(rleg, 3,  0.843235, 24.355743/animSpeed) --delta=-0.81
				turn(rleg, 2, -0.860075, 24.425185/animSpeed) --delta=-0.81
				if (rightArm) then turn(rloarm, 1, -49.299998, 206.555473/animSpeed) end--delta=-6.89
				turn(rthigh, 1, -43.951970, 441.202285/animSpeed) --delta=14.71
				turn(rthigh, 3,  -2.997201, 189.833832/animSpeed) --delta=6.33
				turn(rthigh, 2, -9.866792, 251.052245/animSpeed) --delta=-8.37
				if (rightArm) then turn(ruparm, 1, 16.947865, 91.311783/animSpeed) end--delta=-3.04
				if (rightArm) then turn(ruparm, 2, 0.900000, 45.888888/animSpeed) end--delta=-1.53
				turn(aimy1, 1, -4.594870, 18.402335/animSpeed) --delta=0.61
				turn(aimy1, 3,  -0.000000, 61.681404/animSpeed) --delta=2.06
				turn(aimy1, 2, 0.000000, 236.383029/animSpeed) --delta=-7.88
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:28
				if (leftArm) then turn(biggun, 1, -53.142724, 34.090567/animSpeed) end--delta=1.14
				turn(head, 1, -2.620635, 15.861851/animSpeed) --delta=-0.53
				turn(head, 2, 3.829846, 114.895376/animSpeed) --delta=3.83
				turn(lfoot, 1, -28.343677, 151.886946/animSpeed) --delta=5.06
				turn(lleg, 1, 27.564644, 568.385957/animSpeed) --delta=18.95
				turn(lthigh, 1, 1.812986, 756.852171/animSpeed) --delta=-25.23
				turn(lthigh, 3,  -2.460308, 82.232611/animSpeed) --delta=2.74
				turn(lthigh, 2, 0.746525, 15.769200/animSpeed) --delta=-0.53
				if (leftArm) then turn(luparm, 1, 8.807109, 79.374337/animSpeed) end--delta=2.65
				if (leftArm) then turn(luparm, 2, -0.396598, 111.159777/animSpeed) end--delta=-3.71
				move (pelvis, 2,  -1.129630 , 26.111112 /animSpeed) --delta=0.87
				turn(pelvis, 3,  1.997872, 59.936146/animSpeed) --delta=-2.00
				turn(pelvis, 2, 2.771879, 83.156358/animSpeed) --delta=2.77
				turn(rfoot, 1, -33.707871, 347.107447/animSpeed) --delta=-11.57
				turn(rleg, 1, 56.067203, 1041.584826/animSpeed) --delta=34.72
				turn(rleg, 3,  -0.026719, 26.098608/animSpeed) --delta=0.87
				turn(rleg, 2, 0.009522, 26.087929/animSpeed) --delta=0.87
				if (rightArm) then turn(rloarm, 1, -43.425926, 176.222159/animSpeed) end--delta=-5.87
				turn(rthigh, 1, -55.080896, 333.867775/animSpeed) --delta=11.13
				turn(rthigh, 3,  -10.747290, 232.502653/animSpeed) --delta=7.75
				turn(rthigh, 2, -16.084974, 186.545461/animSpeed) --delta=-6.22
				if (rightArm) then turn(ruparm, 1, 22.234335, 158.594124/animSpeed) end--delta=-5.29
				if (rightArm) then turn(ruparm, 2, -0.812436, 51.373077/animSpeed) end--delta=-1.71
				turn(aimy1, 1, -4.288164, 9.201174/animSpeed) --delta=-0.31
				turn(aimy1, 3,  -2.053859, 61.615764/animSpeed) --delta=2.05
				turn(aimy1, 2, -7.879434, 236.383029/animSpeed) --delta=-7.88
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:32
				if (leftArm) then turn(biggun, 1, -55.253092, 63.311038/animSpeed) end--delta=2.11
				turn(head, 1, -1.563179, 31.723670/animSpeed) --delta=-1.06
				turn(head, 2, 6.127755, 68.937274/animSpeed) --delta=2.30
				turn(lfoot, 1, -21.408024, 208.069572/animSpeed) --delta=-6.94
				turn(lleg, 1, 3.737072, 714.827163/animSpeed) --delta=23.83
				turn(lthigh, 1, 24.379452, 676.993988/animSpeed) --delta=-22.57
				turn(lthigh, 3,  -7.321217, 145.827258/animSpeed) --delta=4.86
				turn(lthigh, 2, 5.849079, 153.076646/animSpeed) --delta=5.10
				if (leftArm) then turn(luparm, 1, 2.317686, 194.682700/animSpeed) end--delta=6.49
				if (leftArm) then turn(luparm, 2, -5.045461, 139.465893/animSpeed) end--delta=-4.65
				turn(pelvis, 3,  3.963673, 58.974037/animSpeed) --delta=-1.97
				turn(pelvis, 2, 5.026658, 67.643372/animSpeed) --delta=2.25
				turn(rfoot, 1, -0.546122, 994.852480/animSpeed) --delta=-33.16
				turn(rleg, 1, 21.731893, 1030.059292/animSpeed) --delta=34.34
				if (rightArm) then turn(rloarm, 1, -39.457405, 119.055627/animSpeed) end--delta=-3.97
				turn(rthigh, 1, -48.555555, 195.760223/animSpeed) --delta=-6.53
				turn(rthigh, 3,  -12.921380, 65.222706/animSpeed) --delta=2.17
				turn(rthigh, 2, -18.341445, 67.694124/animSpeed) --delta=-2.26
				if (rightArm) then turn(ruparm, 1, 27.520808, 158.594175/animSpeed) end--delta=-5.29
				if (rightArm) then turn(ruparm, 2, -1.893975, 32.446164/animSpeed) end--delta=-1.08
				turn(aimy1, 1, -3.674753, 18.402335/animSpeed) --delta=-0.61
				turn(aimy1, 3,  -4.074748, 60.626684/animSpeed) --delta=2.02
				turn(aimy1, 2, -13.926961, 181.425790/animSpeed) --delta=-6.05
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:36
				if (leftArm) then turn(biggun, 1, -56.389444, 34.090567/animSpeed) end--delta=1.14
				turn(head, 1, 0.023005, 47.585536/animSpeed) --delta=-1.59
				turn(head, 2, 7.659692, 45.958102/animSpeed) --delta=1.53
				turn(lfoot, 1, -33.511695, 363.110120/animSpeed) --delta=12.10
				turn(lleg, 1, 32.254462, 855.521701/animSpeed) --delta=-28.52
				turn(lthigh, 1, 18.565433, 174.420577/animSpeed) --delta=5.81
				turn(lthigh, 3,  -9.818104, 74.906625/animSpeed) --delta=2.50
				turn(lthigh, 2, 5.332458, 15.498655/animSpeed) --delta=-0.52
				if (leftArm) then turn(luparm, 1, -3.274263, 167.758466/animSpeed) end--delta=5.59
				if (leftArm) then turn(luparm, 2, -6.556594, 45.333998/animSpeed) end--delta=-1.51
				move (pelvis, 2,  -2.000000 , 25.555555 /animSpeed) --delta=-0.85
				turn(pelvis, 3,  5.000000, 31.089813/animSpeed) --delta=-1.04
				turn(pelvis, 2, 6.000000, 29.200275/animSpeed) --delta=0.97
				turn(rfoot, 1, 4.673420, 156.586261/animSpeed) --delta=-5.22
				turn(rleg, 1, 17.968366, 112.905793/animSpeed) --delta=3.76
				if (rightArm) then turn(rloarm, 1, -38.000000, 43.722158/animSpeed) end--delta=-1.46
				turn(rthigh, 1, -40.972853, 227.481055/animSpeed) --delta=-7.58
				turn(rthigh, 3,  -12.483621, 13.132763/animSpeed) --delta=-0.44
				turn(rthigh, 2, -18.495587, 4.624260/animSpeed) --delta=-0.15
				if (rightArm) then turn(ruparm, 1, 29.923749, 72.088224/animSpeed) end--delta=-2.40
				if (rightArm) then turn(ruparm, 2, -2.615000, 21.630765/animSpeed) end--delta=-0.72
				turn(aimy1, 1, -2.141225, 46.005832/animSpeed) --delta=-1.53
				turn(aimy1, 3,  -5.140116, 31.961046/animSpeed) --delta=1.07
				turn(aimy1, 2, -15.758869, 54.957239/animSpeed) --delta=-1.83
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:40
				if (leftArm) then turn(biggun, 1, -55.431951, 28.724805/animSpeed) end--delta=-0.96
				turn(head, 1, -0.505722, 15.861819/animSpeed) --delta=0.53
				turn(head, 2, 6.127755, 45.958102/animSpeed) --delta=-1.53
				turn(lfoot, 1, -26.332418, 215.378302/animSpeed) --delta=-7.18
				turn(lleg, 1, 78.044494, 1373.700965/animSpeed) --delta=-45.79
				turn(lleg, 3,  0.174770, 5.001042/animSpeed) --delta=-0.17
				turn(lleg, 2, -0.146625, 4.279269/animSpeed) --delta=-0.14
				turn(lthigh, 1, -2.370128, 628.066816/animSpeed) --delta=20.94
				turn(lthigh, 3,  -5.835163, 119.488247/animSpeed) --delta=-3.98
				turn(lthigh, 2, -2.219125, 226.547492/animSpeed) --delta=-7.55
				if (leftArm) then turn(luparm, 1, -3.054371, 6.596772/animSpeed) end--delta=-0.22
				if (leftArm) then turn(luparm, 2, -6.061839, 14.842650/animSpeed) end--delta=0.49
				move (pelvis, 2,  -2.851852 , 25.555558 /animSpeed) --delta=-0.85
				turn(pelvis, 3,  3.933333, 31.999991/animSpeed) --delta=1.07
				turn(pelvis, 2, 4.992593, 30.222230/animSpeed) --delta=-1.01
				turn(rfoot, 1, 5.697123, 30.711083/animSpeed) --delta=-1.02
				turn(rleg, 1, 37.499340, 585.929212/animSpeed) --delta=-19.53
				if (rightArm) then turn(rloarm, 1, -40.468516, 74.055472/animSpeed) end--delta=2.47
				turn(rthigh, 1, -47.862042, 206.675650/animSpeed) --delta=6.89
				turn(rthigh, 3,  -11.534632, 28.469671/animSpeed) --delta=-0.95
				turn(rthigh, 2, -17.767171, 21.852473/animSpeed) --delta=0.73
				if (rightArm) then turn(ruparm, 1, 28.884286, 31.183878/animSpeed) end--delta=1.04
				if (rightArm) then turn(ruparm, 2, -1.954060, 19.828204/animSpeed) end--delta=0.66
				turn(aimy1, 1, -3.061342, 27.603503/animSpeed) --delta=0.92
				turn(aimy1, 3,  -4.043559, 32.896722/animSpeed) --delta=-1.10
				turn(aimy1, 2, -13.926961, 54.957239/animSpeed) --delta=1.83
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:44
				if (leftArm) then turn(biggun, 1, -53.164273, 68.030323/animSpeed) end--delta=-2.27
				turn(head, 1, -2.091907, 47.585562/animSpeed) --delta=1.59
				turn(head, 2, 3.829846, 68.937274/animSpeed) --delta=-2.30
				turn(lfoot, 1, -38.582946, 367.515848/animSpeed) --delta=12.25
				turn(lleg, 1, 104.269176, 786.740462/animSpeed) --delta=-26.22
				turn(lleg, 3,  -0.034635, 6.282160/animSpeed) --delta=0.21
				turn(lleg, 2, 0.050427, 5.911553/animSpeed) --delta=0.20
				turn(lthigh, 1, -29.086507, 801.491385/animSpeed) --delta=26.72
				turn(lthigh, 3,  -3.433171, 72.059742/animSpeed) --delta=-2.40
				turn(lthigh, 2, 1.068465, 98.627710/animSpeed) --delta=3.29
				if (leftArm) then turn(luparm, 1, -1.515114, 46.177713/animSpeed) end--delta=-1.54
				if (leftArm) then turn(luparm, 2, -4.161596, 57.007282/animSpeed) end--delta=1.90
				turn(pelvis, 3,  2.088889, 55.333337/animSpeed) --delta=1.84
				turn(pelvis, 2, 2.874074, 63.555555/animSpeed) --delta=-2.12
				turn(rfoot, 1, -11.381223, 512.350363/animSpeed) --delta=17.08
				turn(rleg, 1, 55.770656, 548.139483/animSpeed) --delta=-18.27
				if (rightArm) then turn(rloarm, 1, -46.314813, 175.388910/animSpeed) end--delta=5.85
				turn(rthigh, 1, -43.758461, 123.107432/animSpeed) --delta=-4.10
				turn(rthigh, 3,  -5.082535, 193.562904/animSpeed) --delta=-6.45
				turn(rthigh, 2, -9.017982, 262.475666/animSpeed) --delta=8.75
				if (rightArm) then turn(ruparm, 1, 26.384334, 74.998551/animSpeed) end--delta=2.50
				if (rightArm) then turn(ruparm, 2, -0.722308, 36.952569/animSpeed) end--delta=1.23
				turn(aimy1, 1, -3.981459, 27.603503/animSpeed) --delta=0.92
				turn(aimy1, 3,  -2.147426, 56.883980/animSpeed) --delta=-1.90
				turn(aimy1, 2, -7.879434, 181.425790/animSpeed) --delta=6.05
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:48
				if (leftArm) then turn(biggun, 1, -50.493628, 80.119348/animSpeed) end--delta=-2.67
				turn(head, 1, -3.149363, 31.723676/animSpeed) --delta=1.06
				turn(head, 2, 0.000000, 114.895376/animSpeed) --delta=-3.83
				turn(lfoot, 1, -44.880435, 188.924672/animSpeed) --delta=6.30
				turn(lleg, 1, 90.690391, 407.363547/animSpeed) --delta=13.58
				turn(lleg, 3,  -1.028354, 29.811568/animSpeed) --delta=0.99
				turn(lleg, 2, 1.046484, 29.881704/animSpeed) --delta=1.00
				turn(lthigh, 1, -43.881824, 443.859502/animSpeed) --delta=14.80
				turn(lthigh, 3,  2.753780, 185.608529/animSpeed) --delta=-6.19
				turn(lthigh, 2, 9.180887, 243.372656/animSpeed) --delta=8.11
				if (leftArm) then turn(luparm, 1, 2.662867, 125.339441/animSpeed) end--delta=-4.18
				if (leftArm) then turn(luparm, 2, -1.793232, 71.050921/animSpeed) end--delta=2.37
				move (pelvis, 2,  -2.000000 , 25.555551 /animSpeed) --delta=0.85
				turn(pelvis, 3,  -0.000000, 62.666668/animSpeed) --delta=2.09
				turn(pelvis, 2, 0.000000, 86.222221/animSpeed) --delta=-2.87
				turn(rfoot, 1, -23.519080, 364.135724/animSpeed) --delta=12.14
				turn(rleg, 1, 46.484300, 278.590678/animSpeed) --delta=9.29
				if (rightArm) then turn(rloarm, 1, -53.199999, 206.555576/animSpeed) end--delta=6.89
				turn(rthigh, 1, -23.439316, 609.574354/animSpeed) --delta=-20.32
				turn(rthigh, 3,  -0.344027, 142.155249/animSpeed) --delta=-4.74
				turn(rthigh, 2, -1.531381, 224.598052/animSpeed) --delta=7.49
				if (rightArm) then turn(ruparm, 1, 23.351554, 90.983396/animSpeed) end--delta=3.03
				if (rightArm) then turn(ruparm, 2, 0.479402, 36.051284/animSpeed) end--delta=1.20
				turn(aimy1, 1, -4.594870, 18.402335/animSpeed) --delta=0.61
				turn(aimy1, 3,  -0.000000, 64.422792/animSpeed) --delta=-2.15
				turn(aimy1, 2, 0.000000, 236.383029/animSpeed) --delta=7.88
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:52
				if (leftArm) then turn(biggun, 1, -48.215180, 68.353460/animSpeed) end--delta=-2.28
				turn(head, 1, -2.620635, 15.861851/animSpeed) --delta=-0.53
				turn(head, 2, -3.829846, 114.895376/animSpeed) --delta=-3.83
				turn(lfoot, 1, -33.266887, 348.406447/animSpeed) --delta=-11.61
				turn(lleg, 1, 55.932201, 1042.745719/animSpeed) --delta=34.76
				turn(lleg, 3,  0.028179, 31.695983/animSpeed) --delta=-1.06
				turn(lleg, 2, -0.009821, 31.689154/animSpeed) --delta=-1.06
				turn(lthigh, 1, -55.237751, 340.677815/animSpeed) --delta=11.36
				turn(lthigh, 3,  10.085981, 219.966025/animSpeed) --delta=-7.33
				turn(lthigh, 2, 15.046731, 175.975325/animSpeed) --delta=5.87
				if (leftArm) then turn(luparm, 1, 9.919362, 217.694824/animSpeed) end--delta=-7.26
				if (leftArm) then turn(luparm, 2, 0.965138, 82.751096/animSpeed) end--delta=2.76
				move (pelvis, 2,  -1.074074 , 27.777776 /animSpeed) --delta=0.93
				turn(pelvis, 3,  -1.666667, 49.999997/animSpeed) --delta=1.67
				turn(pelvis, 2, -2.296296, 68.888891/animSpeed) --delta=-2.30
				turn(rfoot, 1, -24.788553, 38.084179/animSpeed) --delta=1.27
				turn(rleg, 1, 21.945633, 736.160009/animSpeed) --delta=24.54
				if (rightArm) then turn(rloarm, 1, -56.129627, 87.888859/animSpeed) end--delta=2.93
				turn(rthigh, 1, 3.073465, 795.383403/animSpeed) --delta=-26.51
				turn(rthigh, 3,  1.955836, 68.995906/animSpeed) --delta=-2.30
				turn(rthigh, 2, -0.370374, 34.830198/animSpeed) --delta=1.16
				if (rightArm) then turn(ruparm, 1, 21.424041, 57.825406/animSpeed) end--delta=1.93
				if (rightArm) then turn(ruparm, 2, 1.762963, 38.506840/animSpeed) end--delta=1.28
				turn(aimy1, 1, -4.288164, 9.201174/animSpeed) --delta=-0.31
				turn(aimy1, 3,  1.713372, 51.401158/animSpeed) --delta=-1.71
				turn(aimy1, 2, 7.879434, 236.383029/animSpeed) --delta=7.88
				Sleep( (33*animSpeed) -1)
			end
		end
	end
end

function SprayNano(heading, pitch)
	SetSignalMask(SIG_AIM)
	Sleep(1000)
	while (true) do
		Turn(torso, 2, rad(10) + buildHeading, rad(10))
		Sleep(2000)
		Turn(torso, 2, rad(-10) + buildHeading, rad(10))
		Sleep(2000)
	end
end

function StopWalking()
	move(pelvis,2, -1.000000, 6.944444)
	if (leftArm) then turn(biggun,1, -52.006372, 28.433941) end
	turn(head,1, -1.298815, 11.896390)
	turn(head,2, 0.000000, 28.723844)
	turn(lfoot,1, 2.870126, 274.263975)
	turn(lleg,1, 22.425678, 349.693872)
	turn(lleg,2, 0.000000, 7.922289)
	turn(lleg,3, 0.000000, 7.923996)
	turn(lthigh,1, -21.115098, 255.919901)
	turn(lthigh,2, 11.110453, 66.749106)
	turn(lthigh,3, -10.103126, 151.418301)
	if (leftArm) then turn(luparm,1, 19.231610, 69.841862) end
	if (leftArm) then turn(luparm,2, 7.211138, 46.845002) end
	if (leftArm) then turn(luparm,3, -16.200000, 28.500010) end
	turn(pelvis,2, 0.000000, 21.666665)
	turn(pelvis,3, 0.000000, 18.055557)
	turn(rfoot,1, 0.415283, 248.713120)
	turn(rleg,1, 25.768060, 346.011740)
	turn(rleg,2, 0.000000, 6.521982)
	turn(rleg,3, 0.000000, 6.524652)
	if (rightArm) then turn(rloarm,1, -53.199995, 51.638894) end
	turn(rthigh,1, -21.950628, 255.149679)
	turn(rthigh,2, -11.905752, 66.515336)
	turn(rthigh,3, 9.396449, 151.125663)
	if (rightArm) then turn(ruparm,1, 24.693159, 39.648544) end
	if (rightArm) then turn(ruparm,2, 0.000000, 31.089853) end
	if (rightArm) then turn(ruparm,3, 12.399998, -7.153845) end
	turn(aimy1,1, -2.263907, 15.181924)
	turn(aimy1,2, 0.000000, 59.095757)
	turn(aimy1,3, 0.000000, 18.561539)
end

function AmIBored()
	if bMoving == false and isAiming == false and isBuilding == false then
		return true
	else
		return false
	end
end

function UnitSpeed()
	maxSpeed = UnitDefs[Spring.GetUnitDefID(unitID)].speed
	animFramesPerKeyframe = 4 --we need to calc the frames per keyframe value, from the known animtime
	maxSpeed = maxSpeed + (maxSpeed /(2*animFramesPerKeyframe)) -- add fudge
	while(true)do
		vx,vy,vz,Speed = Spring.GetUnitVelocity(unitID)
		currentSpeed = Speed * 30
		animSpeed = (currentSpeed)
		if (animSpeed<1) then
			animSpeed=1
		end
		animSpeed = (maxSpeed * 4) / animSpeed
		if (animSpeed<2) then
			animSpeed=2
		end
		if (animSpeed>8) then
			animSpeed = 8
		end
		Sleep (131)
	end
end

function ResumeBuilding()
	Sleep(800)
	if isBuilding and not isAiming then
		Turn(torso, 2, buildHeading, rad(150.000000))
		Turn(luparm, 1, rad(-55) - buildPitch, rad(45.000000))
	end
	return (0)
end

function script.Create()
	Turn(lflare, 1,math.rad(90))
	Turn(nano, 1,math.rad(90))
	Turn(laserflare, 1,math.rad(90))
	Spin(dish, 2, 2.5)
	isAiming = false
	isAimingDgun = false
	isBuilding = false
	bAiming = false
	buildHeading = 0
	buildPitch = 0
	leftArm = true
	rightArm = true
	animSpeed = 4
	StartThread(UnitSpeed)
	StartThread(StopWalking)
end

function script.StartMoving()
	bMoving = true
	StartThread(walk)
end
	
function script.StopMoving()
	Signal(SIG_WALK)
	bMoving = false
	StartThread(StopWalking)
end

function script.AimFromWeapon(weapon)
	if weapons[weapon] == "laser" then
		return ruparm
	elseif weapons[weapon] == "uwlaser" then
		return ruparm
	elseif weapons[weapon] == "dgun" then
		return 0 -- this is somehow the best way to ensuse dgun hits whatever target its aimed at
	end
end

function script.AimWeapon(weapon, heading, pitch)
	if weapons[weapon] == "laser" then
		if isAimingDgun == true then
			return false
		else
			leftArm = false
			SetSignalMask(SIG_AIM)
			Signal(SIG_AIM)
			Turn(torso, 2, heading, rad(300.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
			Turn(rloarm, 1, rad(-55), rad(390.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
			Turn(ruparm, 1, rad(-40)-pitch, rad(390.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
			WaitForTurn(torso,2)
			isAiming = true
			if isBuilding == true then
				StartThread(ResumeBuilding)
			end
			StartThread(Restore)
			return true
		end
	elseif weapons[weapon] == "uwlaser" then
		if isAimingDgun == true then
			return false
		elseif not BelowWater(head) then
			return false
		else
			leftArm = false
			SetSignalMask(SIG_AIM)
			Signal(SIG_AIM)
			Turn(torso, 2, heading, rad(300.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
			Turn(rloarm, 1, rad(-55), rad(390.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
			Turn(ruparm, 1, rad(-40)-pitch, rad(390.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
			WaitForTurn(torso,2)
			isAiming = true
			if isBuilding == true then
				StartThread(ResumeBuilding)
			end
			StartThread(Restore)
			return true
		end
	elseif weapons[weapon] == "dgun" then
		isAimingDgun = true
		isAiming = true
		leftArm = false
		Turn(torso, 2, heading, rad(360.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
		Turn(biggun, 1, rad(-105), rad(900.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
		Turn(luparm, 1, rad(15)-pitch, rad(900.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
		WaitForTurn(torso,2)
		return true
	end
end

function script.FireWeapon(weapon)
	if weapons[weapon] == "laser" then
		Sleep(100)
		return false
	elseif weapons[weapon] == "uwlaser" then
		Sleep(100)
		return false
	elseif weapons[weapon] == "dgun" then
		isAimingDgun = false
		turn(luparm, 1, 20)
		turn(biggun, 1, -100)
		move(barrel, 2, -1.5)
		turn(luparm, 1, 5, 100)
		turn(biggun, 1, -85, 100)
		move(barrel, 2, 0, 5)
		return true
	end
end

function script.QueryWeapon(weapon)
	if weapons[weapon] == "laser" then
		return laserflare
	elseif weapons[weapon] == "uwlaser" then
		return laserflare
	elseif weapons[weapon] == "dgun" then
		return lflare
	end
end

function script.StartBuilding(heading, pitch)
	Signal(SIG_AIM)
	isBuilding = true
	leftArm = false
	Turn(torso, 2, heading, rad(300.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
	Turn(rloarm, 1, rad(-40), rad(390.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
	Turn(ruparm, 1, rad(-55)-pitch, rad(390.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
	WaitForTurn(ruparm,1)
	Spring.UnitScript.SetUnitValue(COB.INBUILDSTANCE, true)
	buildHeading = heading
	buildPitch = pitch
	StartThread(SprayNano, heading, pitch)
	return true
end

function script.StopBuilding()
	leftArm = true
	isBuilding = false
	Spring.UnitScript.SetUnitValue(COB.INBUILDSTANCE, false)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	StartThread(Restore)
	return true
end

function script.QueryNanoPiece()
	local piecenum;
	piecenum = nano;
	return piecenum
end

function Restore()
	SetSignalMask(SIG_AIM)
	Sleep(3000)
	turn(torso, 2, 0, 105)
	turn(biggun, 1, -38, 95.0000)
	turn(luparm, 1, 0, 95.0000)
	turn(rloarm, 1, -38, 95.0000)
	turn(ruparm, 1, 0, 95.0000)
	isAiming = false
	isAimingDgun = false
	rightArm = true
	leftArm = true
end



function script.Killed()
	return 1
end
