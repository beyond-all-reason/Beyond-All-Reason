--INCREMENT THIS COUNTER FOR EVERY HOUR OF YOUR LIFE WASTED HERE: 44



--Skeleton pieces
--local head, torso, luparm, biggun, ruparm, rloarm, lflare, nano, laserflare, pelvis, rthigh, lthigh, lleg, rleg, rfoot, rfootstep, lfoot, lfootstep, dish, barrel, aimy1, bigguncyl,hatpoint, crown, medalsilver, medalbronze, medalgold, cagelight, cagelight_emit = piece("head", "torso", "luparm", "biggun", "ruparm","rloarm","lflare", "nano", "laserflare", "pelvis", "rthigh", "lthigh" ,"lleg", "rleg", "rfoot", "rfootstep", "lfoot", "lfootstep", "dish", "barrel", "aimy1","bigguncyl","hatpoint", "crown", "medalsilver", "medalbronze", "medalgold", "cagelight", "cagelight_emit")
local head, torso, luparm, biggun, ruparm, rloarm, lflare, nano, laserflare, pelvis, rthigh, lthigh, lleg, rleg, rfoot, rfootstep, lfoot, lfootstep, dish, barrel, aimy1, bigguncyl,hatpoint, armhexl, armhexl2, armhexl_emit, armhexl2_emit, missileflare = piece("head", "torso", "luparm", "biggun", "ruparm","rloarm","lflare", "nano", "laserflare", "pelvis", "rthigh", "lthigh" ,"lleg", "rleg", "rfoot", "rfootstep", "lfoot", "lfootstep", "dish", "barrel", "aimy1","bigguncyl","hatpoint", "armhexl", "armhexl2", "armhexl_emit", "armhexl2_emit", "missileflare")

local weapons = {
	[1] = "backlauncher",
	[2] = "uwlaser",
	[3] = "dgun",
	[4] = "tachcannon",
	[5] = "laser",
	[6] = "flashbang",
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
local GetGameFrame 		= Spring.GetGameFrame
local spGetUnitStates = Spring.GetUnitStates
local spSetUnitArmored = Spring.SetUnitArmored
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitCloak = Spring.SetUnitCloak

-- for the AimPrimary script, to skip wait-for-turn if needed
local last_primary_heading = -1000000

local function BelowWater(piecename)
	local _,y,_ = Spring.GetUnitPiecePosition(unitID, piecename)
  -- this returns unit space, so why does it work for corcom?
  local _, py, _ = Spring.GetUnitPosition(unitID)
  --Spring.Echo(piecename, 'ypos', y, py)
	if (y+ py) <= 0 then
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
				turn(torso, 1, -4.288164, 60.727696/animSpeed) --delta=2.02
				turn(torso, 3,  1.713372, 51.401158/animSpeed) --delta=-1.71
				turn(torso, 2, 7.879434, 236.383029/animSpeed) --delta=7.88
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
				turn(torso, 1, -3.674753, 18.402335/animSpeed) --delta=-0.61
				turn(torso, 3,  4.188244, 74.246156/animSpeed) --delta=-2.47
				turn(torso, 2, 13.926961, 181.425790/animSpeed) --delta=6.05
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
				turn(torso, 1, -2.141225, 46.005832/animSpeed) --delta=-1.53
				turn(torso, 3,  5.140116, 28.556180/animSpeed) --delta=-0.95
				turn(torso, 2, 15.758869, 54.957239/animSpeed) --delta=1.83
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
				turn(torso, 1, -3.061342, 27.603503/animSpeed) --delta=0.92
				turn(torso, 3,  4.074019, 31.982933/animSpeed) --delta=1.07
				turn(torso, 2, 13.926961, 54.957239/animSpeed) --delta=-1.83
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:20
				if not Spring.GetUnitIsCloaked(unitID) then
					UnitScript.EmitSfx(lfootstep, 1024 + 2)
				end
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
				turn(torso, 1, -3.981459, 27.603503/animSpeed) --delta=0.92
				turn(torso, 3,  2.056047, 60.539158/animSpeed) --delta=2.02
				turn(torso, 2, 7.879434, 181.425790/animSpeed) --delta=-6.05
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
				turn(torso, 1, -4.594870, 18.402335/animSpeed) --delta=0.61
				turn(torso, 3,  -0.000000, 61.681404/animSpeed) --delta=2.06
				turn(torso, 2, 0.000000, 236.383029/animSpeed) --delta=-7.88
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
				turn(torso, 1, -4.288164, 9.201174/animSpeed) --delta=-0.31
				turn(torso, 3,  -2.053859, 61.615764/animSpeed) --delta=2.05
				turn(torso, 2, -7.879434, 236.383029/animSpeed) --delta=-7.88
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
				turn(torso, 1, -3.674753, 18.402335/animSpeed) --delta=-0.61
				turn(torso, 3,  -4.074748, 60.626684/animSpeed) --delta=2.02
				turn(torso, 2, -13.926961, 181.425790/animSpeed) --delta=-6.05
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
				turn(torso, 1, -2.141225, 46.005832/animSpeed) --delta=-1.53
				turn(torso, 3,  -5.140116, 31.961046/animSpeed) --delta=1.07
				turn(torso, 2, -15.758869, 54.957239/animSpeed) --delta=-1.83
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
				turn(torso, 1, -3.061342, 27.603503/animSpeed) --delta=0.92
				turn(torso, 3,  -4.043559, 32.896722/animSpeed) --delta=-1.10
				turn(torso, 2, -13.926961, 54.957239/animSpeed) --delta=1.83
			Sleep( (33*animSpeed) -1)
			end
			if (bMoving) then --Frame:44
				if not Spring.GetUnitIsCloaked(unitID) then
					UnitScript.EmitSfx(rfootstep, 1024 + 2)
				end
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
				turn(torso, 1, -3.981459, 27.603503/animSpeed) --delta=0.92
				turn(torso, 3,  -2.147426, 56.883980/animSpeed) --delta=-1.90
				turn(torso, 2, -7.879434, 181.425790/animSpeed) --delta=6.05
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
				turn(torso, 1, -4.594870, 18.402335/animSpeed) --delta=0.61
				turn(torso, 3,  -0.000000, 64.422792/animSpeed) --delta=-2.15
				turn(torso, 2, 0.000000, 236.383029/animSpeed) --delta=7.88
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
				turn(torso, 1, -4.288164, 9.201174/animSpeed) --delta=-0.31
				turn(torso, 3,  1.713372, 51.401158/animSpeed) --delta=-1.71
				turn(torso, 2, 7.879434, 236.383029/animSpeed) --delta=7.88
				Sleep( (33*animSpeed) -1)
			end
		end
	end
end

local isDancing = false
local function Dance1()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	local speedMult = 1/4
	local sleepTime = 33*4

	-- Frame: 6 (first step)
	Turn(head, y_axis, 0.104720, 3.141593 * speedMult) -- delta=6.00
	Turn(lfoot, x_axis, -0.034375, 2.583373 * speedMult) -- delta=4.93
	Turn(lfoot, z_axis, -0.089446, 2.779274 * speedMult) -- delta=-5.31
	Turn(lfoot, y_axis, -0.010538, 0.357694 * speedMult) -- delta=-0.68
	Turn(lleg, x_axis, 0.623476, 9.469870 * speedMult) -- delta=-18.09
	Turn(lleg, z_axis, -0.062029, 1.920557 * speedMult) -- delta=-3.67
	Turn(lleg, y_axis, -0.033957, 1.039222 * speedMult) -- delta=-1.98
	Turn(lthigh, x_axis, -0.547990, 6.484738 * speedMult) -- delta=12.38
	Turn(lthigh, z_axis, 0.358445, 5.849047 * speedMult) -- delta=11.17
	Turn(lthigh, y_axis, -0.015696, 7.280939 * speedMult) -- delta=-13.91
	Move(pelvis, x_axis, - 2.217917, 66.537516 * speedMult) -- delta=2.22
	Move(pelvis, z_axis, 0.147905, 4.437149 * speedMult) -- delta=0.15
	Move(pelvis, y_axis, -2.880190, 56.405711 * speedMult) -- delta=-1.88
	Turn(pelvis, z_axis, -0.005986, 0.179589 * speedMult) -- delta=-0.34
	Turn(pelvis, y_axis, 0.142962, 4.288851 * speedMult) -- delta=8.19
	Turn(rfoot, x_axis, -0.373382, 11.118076 * speedMult) -- delta=21.23
	Turn(rfoot, z_axis, -0.110572, 1.809677 * speedMult) -- delta=-3.46
	Turn(rfoot, y_axis, -0.002176, 0.323880 * speedMult) -- delta=0.62
	Turn(rleg, x_axis, 0.999798, 18.246797 * speedMult) -- delta=-34.85
	Turn(rleg, z_axis, -0.113808, 2.496211 * speedMult) -- delta=-4.77
	Turn(rleg, y_axis, -0.096141, 2.554709 * speedMult) -- delta=-4.88
	Turn(rloarm, x_axis, -1.454183, 15.770044 * speedMult) -- delta=30.12
	Turn(rloarm, z_axis, 0.162961, 4.888822 * speedMult) -- delta=9.34
	Turn(rloarm, y_axis, 0.180905, 5.427164 * speedMult) -- delta=10.37
	Turn(rthigh, x_axis, -0.598987, 7.256664 * speedMult) -- delta=13.86
	Turn(rthigh, z_axis, -0.031948, 3.129578 * speedMult) -- delta=5.98
	Turn(rthigh, y_axis, -0.389890, 4.697058 * speedMult) -- delta=-8.97
	Turn(ruparm, x_axis, -0.219471, 19.513449 * speedMult) -- delta=37.27
	Turn(ruparm, z_axis, -0.205374, 0.331390 * speedMult) -- delta=0.63
	Turn(ruparm, y_axis, 0.360376, 10.811294 * speedMult) -- delta=20.65
	Turn(torso, z_axis, -0.003670, 0.110091 * speedMult) -- delta=-0.21
	Turn(torso, y_axis, 0.087730, 2.631910 * speedMult) -- delta=5.03
	Sleep(sleepTime)

	while true do
		-- Frame:11
		Turn(biggun, x_axis, -0.987343, 2.389807 * speedMult) -- delta=4.56
		Turn(biggun, z_axis, 0.194777, 5.843318 * speedMult) -- delta=11.16
		Turn(biggun, y_axis, -0.296897, 8.906900 * speedMult) -- delta=-17.01
		Turn(head, x_axis, -0.071538, 1.466077 * speedMult) -- delta=2.80
		Turn(head, y_axis, 0.066710, 1.140282 * speedMult) -- delta=-2.18
		Turn(lfoot, x_axis, -0.070893, 1.095543 * speedMult) -- delta=2.09
		Turn(lfoot, z_axis, -0.051773, 1.130211 * speedMult) -- delta=2.16
		Turn(lfoot, y_axis, -0.004320, 0.186516 * speedMult) -- delta=0.36
		Turn(lleg, x_axis, 0.638559, 0.452492 * speedMult) -- delta=-0.86
		Turn(lleg, z_axis, -0.037388, 0.739218 * speedMult) -- delta=1.41
		Turn(lleg, y_axis, -0.020323, 0.409030 * speedMult) -- delta=0.78
		Turn(lthigh, x_axis, -0.531268, 0.501670 * speedMult) -- delta=-0.96
		Turn(lthigh, z_axis, 0.287272, 2.135185 * speedMult) -- delta=-4.08
		Turn(lthigh, y_axis, 0.069817, 2.565378 * speedMult) -- delta=4.90
		Turn(luparm, x_axis, 0.239702, 2.878582 * speedMult) -- delta=5.50
		Turn(luparm, z_axis, 0.308320, 0.767303 * speedMult) -- delta=1.47
		Turn(luparm, y_axis, 0.007498, 3.550799 * speedMult) -- delta=-6.78
		Move(pelvis, x_axis, - 1.298512, 27.582171 * speedMult) -- delta=-0.92
		Move(pelvis, y_axis, -2.482196, 11.939836 * speedMult) -- delta=0.40
		Turn(pelvis, z_axis, -0.003503, 0.074496 * speedMult) -- delta=0.14
		Turn(pelvis, y_axis, 0.083659, 1.779079 * speedMult) -- delta=-3.40
		Turn(rfoot, x_axis, -0.287489, 2.576805 * speedMult) -- delta=-4.92
		Turn(rfoot, z_axis, -0.078112, 0.973786 * speedMult) -- delta=1.86
		Turn(rfoot, y_axis, -0.005787, 0.108303 * speedMult) -- delta=-0.21
		Turn(rleg, x_axis, 0.887214, 3.377523 * speedMult) -- delta=6.45
		Turn(rleg, z_axis, -0.068411, 1.361919 * speedMult) -- delta=2.60
		Turn(rleg, y_axis, -0.053363, 1.283335 * speedMult) -- delta=2.45
		Turn(rloarm, x_axis, -1.201357, 7.584786 * speedMult) -- delta=-14.49
		Turn(rloarm, z_axis, 0.184737, 0.653298 * speedMult) -- delta=1.25
		Turn(rloarm, y_axis, 0.149388, 0.945526 * speedMult) -- delta=-1.81
		Turn(rthigh, x_axis, -0.569125, 0.895861 * speedMult) -- delta=-1.71
		Turn(rthigh, z_axis, -0.088142, 1.685803 * speedMult) -- delta=-3.22
		Turn(rthigh, y_axis, -0.307811, 2.462378 * speedMult) -- delta=4.70
		Turn(ruparm, x_axis, -0.193913, 0.766759 * speedMult) -- delta=-1.46
		Turn(ruparm, z_axis, -0.236640, 0.937956 * speedMult) -- delta=-1.79
		Turn(ruparm, y_axis, 0.351718, 0.259751 * speedMult) -- delta=-0.50
		Sleep(sleepTime)
		-- Frame:16
		Turn(biggun, x_axis, -1.212098, 6.742664 * speedMult) -- delta=12.88
		Turn(biggun, z_axis, 0.744327, 16.486506 * speedMult) -- delta=31.49
		Turn(biggun, y_axis, -1.134569, 25.130179 * speedMult) -- delta=-48.00
		Turn(head, x_axis, -0.120407, 1.466076 * speedMult) -- delta=2.80
		Turn(head, y_axis, -0.040530, 3.217223 * speedMult) -- delta=-6.14
		Turn(lfoot, x_axis, -0.329679, 7.763561 * speedMult) -- delta=14.83
		Turn(lfoot, z_axis, 0.045192, 2.908938 * speedMult) -- delta=5.56
		Turn(lfoot, y_axis, 0.000907, 0.156820 * speedMult) -- delta=0.30
		Turn(lleg, x_axis, 1.006559, 11.040006 * speedMult) -- delta=-21.08
		Turn(lleg, z_axis, 0.044217, 2.448153 * speedMult) -- delta=4.68
		Turn(lleg, y_axis, 0.038324, 1.759399 * speedMult) -- delta=3.36
		Turn(lthigh, x_axis, -0.648732, 3.523938 * speedMult) -- delta=6.73
		Turn(lthigh, z_axis, 0.095675, 5.747931 * speedMult) -- delta=-10.98
		Turn(lthigh, y_axis, 0.288374, 6.556719 * speedMult) -- delta=12.52
		Turn(luparm, x_axis, -0.031022, 8.121713 * speedMult) -- delta=15.51
		Turn(luparm, z_axis, 0.380483, 2.164890 * speedMult) -- delta=4.13
		Turn(luparm, y_axis, -0.326446, 10.018325 * speedMult) -- delta=-19.13
		Move(pelvis, x_axis,   1.748151, 91.399884 * speedMult) -- delta=-3.05
		Move(pelvis, y_axis, -3.133945, 19.552481 * speedMult) -- delta=-0.65
		Turn(pelvis, z_axis, 0.003503, 0.210186 * speedMult) -- delta=0.40
		Turn(pelvis, y_axis, -0.083659, 5.019544 * speedMult) -- delta=-9.59
		Turn(rfoot, x_axis, -0.149899, 4.127694 * speedMult) -- delta=-7.88
		Turn(rfoot, z_axis, 0.023681, 3.053790 * speedMult) -- delta=5.83
		Turn(rfoot, y_axis, 0.000735, 0.195655 * speedMult) -- delta=0.37
		Turn(rleg, x_axis, 0.808571, 2.359271 * speedMult) -- delta=4.51
		Turn(rleg, z_axis, 0.021656, 2.702012 * speedMult) -- delta=5.16
		Turn(rleg, y_axis, 0.013585, 2.008457 * speedMult) -- delta=3.84
		Turn(rloarm, x_axis, -0.488026, 21.399937 * speedMult) -- delta=-40.87
		Turn(rloarm, z_axis, 0.197631, 0.386821 * speedMult) -- delta=0.74
		Turn(rloarm, y_axis, 0.060464, 2.667732 * speedMult) -- delta=-5.09
		Turn(rthigh, x_axis, -0.612584, 1.303782 * speedMult) -- delta=2.49
		Turn(rthigh, z_axis, -0.313405, 6.757903 * speedMult) -- delta=-12.91
		Turn(rthigh, y_axis, -0.045035, 7.883266 * speedMult) -- delta=15.06
		Turn(ruparm, x_axis, -0.121801, 2.163356 * speedMult) -- delta=-4.13
		Turn(ruparm, z_axis, -0.324852, 2.646378 * speedMult) -- delta=-5.05
		Turn(ruparm, y_axis, 0.327289, 0.732871 * speedMult) -- delta=-1.40
		Sleep(sleepTime)
		-- Frame:21
		Turn(biggun, x_axis, -1.291758, 2.389805 * speedMult) -- delta=4.56
		Turn(biggun, z_axis, 0.939105, 5.843316 * speedMult) -- delta=11.16
		Turn(biggun, y_axis, -1.431466, 8.906901 * speedMult) -- delta=-17.01
		Turn(head, x_axis, -0.022669, 2.932153 * speedMult) -- delta=-5.60
		Turn(head, y_axis, -0.078540, 1.140281 * speedMult) -- delta=-2.18
		Turn(lfoot, x_axis, -0.341054, 0.341257 * speedMult) -- delta=0.65
		Turn(lfoot, z_axis, 0.060865, 0.470197 * speedMult) -- delta=0.90
		Turn(lleg, x_axis, 0.977672, 0.866606 * speedMult) -- delta=1.66
		Turn(lleg, z_axis, 0.058164, 0.418409 * speedMult) -- delta=0.80
		Turn(lleg, y_axis, 0.049017, 0.320781 * speedMult) -- delta=0.61
		Turn(lthigh, x_axis, -0.609187, 1.186348 * speedMult) -- delta=-2.27
		Turn(lthigh, z_axis, 0.060475, 1.055982 * speedMult) -- delta=-2.02
		Turn(lthigh, y_axis, 0.367412, 2.371146 * speedMult) -- delta=4.53
		Turn(luparm, x_axis, -0.126974, 2.878580 * speedMult) -- delta=5.50
		Turn(luparm, z_axis, 0.406060, 0.767303 * speedMult) -- delta=1.47
		Turn(luparm, y_axis, -0.444806, 3.550799 * speedMult) -- delta=-6.78
		Move(pelvis, x_axis,   2.217917, 14.092977 * speedMult) -- delta=-0.47
		Move(pelvis, y_axis, -2.880190, 7.612646 * speedMult) -- delta=0.25
		Turn(pelvis, z_axis, 0.005986, 0.074496 * speedMult) -- delta=0.14
		Turn(pelvis, y_axis, -0.142962, 1.779079 * speedMult) -- delta=-3.40
		Turn(rfoot, x_axis, -0.079087, 2.124373 * speedMult) -- delta=-4.06
		Turn(rfoot, z_axis, 0.037979, 0.428943 * speedMult) -- delta=0.82
		Turn(rfoot, y_axis, 0.002916, 0.065420 * speedMult) -- delta=0.12
		Turn(rleg, x_axis, 0.698885, 3.290602 * speedMult) -- delta=6.28
		Turn(rleg, z_axis, 0.029508, 0.235572 * speedMult) -- delta=0.45
		Turn(rleg, y_axis, 0.017087, 0.105057 * speedMult) -- delta=0.20
		Turn(rloarm, x_axis, -0.235200, 7.584786 * speedMult) -- delta=-14.49
		Turn(rloarm, z_axis, 0.201643, 0.120344 * speedMult) -- delta=0.23
		Turn(rloarm, y_axis, 0.028946, 0.945525 * speedMult) -- delta=-1.81
		Turn(rthigh, x_axis, -0.573331, 1.177593 * speedMult) -- delta=-2.25
		Turn(rthigh, z_axis, -0.333499, 0.602813 * speedMult) -- delta=-1.15
		Turn(rthigh, y_axis, 0.009676, 1.641329 * speedMult) -- delta=3.13
		Turn(ruparm, x_axis, -0.096242, 0.766759 * speedMult) -- delta=-1.46
		Turn(ruparm, z_axis, -0.356118, 0.937957 * speedMult) -- delta=-1.79
		Turn(ruparm, y_axis, 0.318631, 0.259751 * speedMult) -- delta=-0.50
		Sleep(sleepTime)
		-- Frame:26
		Turn(biggun, x_axis, -1.212098, 2.389805 * speedMult) -- delta=-4.56
		Turn(biggun, z_axis, 0.744327, 5.843318 * speedMult) -- delta=-11.16
		Turn(biggun, y_axis, -1.134569, 8.906897 * speedMult) -- delta=17.01
		Turn(head, x_axis, -0.070142, 1.424188 * speedMult) -- delta=2.72
		Turn(head, y_axis, -0.048856, 0.890506 * speedMult) -- delta=1.70
		Turn(lfoot, x_axis, -0.329679, 0.341257 * speedMult) -- delta=-0.65
		Turn(lfoot, z_axis, 0.045192, 0.470197 * speedMult) -- delta=-0.90
		Turn(lleg, x_axis, 1.006559, 0.866606 * speedMult) -- delta=-1.66
		Turn(lleg, z_axis, 0.044217, 0.418409 * speedMult) -- delta=-0.80
		Turn(lleg, y_axis, 0.038324, 0.320781 * speedMult) -- delta=-0.61
		Turn(lthigh, x_axis, -0.648732, 1.186348 * speedMult) -- delta=2.27
		Turn(lthigh, z_axis, 0.095675, 1.055982 * speedMult) -- delta=2.02
		Turn(lthigh, y_axis, 0.288374, 2.371146 * speedMult) -- delta=-4.53
		Turn(luparm, x_axis, -0.031022, 2.878582 * speedMult) -- delta=-5.50
		Turn(luparm, z_axis, 0.380483, 0.767303 * speedMult) -- delta=-1.47
		Turn(luparm, y_axis, -0.326446, 3.550799 * speedMult) -- delta=6.78
		Move(pelvis, x_axis,   1.748151, 14.092977 * speedMult) -- delta=0.47
		Move(pelvis, y_axis, -3.133945, 7.612646 * speedMult) -- delta=-0.25
		Turn(pelvis, z_axis, 0.003503, 0.074496 * speedMult) -- delta=-0.14
		Turn(pelvis, y_axis, -0.083659, 1.779079 * speedMult) -- delta=3.40
		Turn(rfoot, x_axis, -0.149899, 2.124373 * speedMult) -- delta=4.06
		Turn(rfoot, z_axis, 0.023681, 0.428943 * speedMult) -- delta=-0.82
		Turn(rfoot, y_axis, 0.000735, 0.065420 * speedMult) -- delta=-0.12
		Turn(rleg, x_axis, 0.808571, 3.290602 * speedMult) -- delta=-6.28
		Turn(rleg, z_axis, 0.021656, 0.235572 * speedMult) -- delta=-0.45
		Turn(rleg, y_axis, 0.013585, 0.105057 * speedMult) -- delta=-0.20
		Turn(rloarm, x_axis, -0.488026, 7.584788 * speedMult) -- delta=14.49
		Turn(rloarm, z_axis, 0.193620, 0.240688 * speedMult) -- delta=-0.46
		Turn(rloarm, y_axis, 0.060464, 0.945526 * speedMult) -- delta=1.81
		Turn(rthigh, x_axis, -0.612584, 1.177593 * speedMult) -- delta=2.25
		Turn(rthigh, z_axis, -0.313405, 0.602813 * speedMult) -- delta=1.15
		Turn(rthigh, y_axis, -0.045035, 1.641329 * speedMult) -- delta=-3.13
		Turn(ruparm, x_axis, -0.121801, 0.766759 * speedMult) -- delta=1.46
		Turn(ruparm, z_axis, -0.324852, 0.937957 * speedMult) -- delta=1.79
		Turn(ruparm, y_axis, 0.327289, 0.259751 * speedMult) -- delta=0.50
		Sleep(sleepTime)
		-- Frame:31
		Turn(biggun, x_axis, -0.987343, 6.742668 * speedMult) -- delta=-12.88
		Turn(biggun, z_axis, 0.194777, 16.486502 * speedMult) -- delta=-31.49
		Turn(biggun, y_axis, -0.296897, 25.130180 * speedMult) -- delta=48.00
		Turn(head, x_axis, -0.117614, 1.424188 * speedMult) -- delta=2.72
		Turn(head, y_axis, 0.042922, 2.753353 * speedMult) -- delta=5.26
		Turn(lfoot, x_axis, -0.070893, 7.763561 * speedMult) -- delta=-14.83
		Turn(lfoot, z_axis, -0.051773, 2.908938 * speedMult) -- delta=-5.56
		Turn(lfoot, y_axis, -0.004320, 0.156820 * speedMult) -- delta=-0.30
		Turn(lleg, x_axis, 0.638559, 11.040006 * speedMult) -- delta=21.08
		Turn(lleg, z_axis, -0.037388, 2.448153 * speedMult) -- delta=-4.68
		Turn(lleg, y_axis, -0.020323, 1.759399 * speedMult) -- delta=-3.36
		Turn(lthigh, x_axis, -0.531268, 3.523938 * speedMult) -- delta=-6.73
		Turn(lthigh, z_axis, 0.287272, 5.747931 * speedMult) -- delta=10.98
		Turn(lthigh, y_axis, 0.069817, 6.556719 * speedMult) -- delta=-12.52
		Turn(luparm, x_axis, 0.239702, 8.121711 * speedMult) -- delta=-15.51
		Turn(luparm, z_axis, 0.308320, 2.164890 * speedMult) -- delta=-4.13
		Turn(luparm, y_axis, 0.007498, 10.018324 * speedMult) -- delta=19.13
		Move(pelvis, x_axis, - 1.298512, 91.399884 * speedMult) -- delta=3.05
		Move(pelvis, y_axis, -2.482196, 19.552481 * speedMult) -- delta=0.65
		Turn(pelvis, z_axis, -0.003503, 0.210186 * speedMult) -- delta=-0.40
		Turn(pelvis, y_axis, 0.083659, 5.019544 * speedMult) -- delta=9.59
		Turn(rfoot, x_axis, -0.287489, 4.127694 * speedMult) -- delta=7.88
		Turn(rfoot, z_axis, -0.078112, 3.053790 * speedMult) -- delta=-5.83
		Turn(rfoot, y_axis, -0.005787, 0.195655 * speedMult) -- delta=-0.37
		Turn(rleg, x_axis, 0.887214, 2.359271 * speedMult) -- delta=-4.51
		Turn(rleg, z_axis, -0.068411, 2.702012 * speedMult) -- delta=-5.16
		Turn(rleg, y_axis, -0.053363, 2.008457 * speedMult) -- delta=-3.84
		Turn(rloarm, x_axis, -1.201357, 21.399928 * speedMult) -- delta=40.87
		Turn(rloarm, z_axis, 0.170984, 0.679086 * speedMult) -- delta=-1.30
		Turn(rloarm, y_axis, 0.149388, 2.667732 * speedMult) -- delta=5.09
		Turn(rthigh, x_axis, -0.569125, 1.303782 * speedMult) -- delta=-2.49
		Turn(rthigh, z_axis, -0.088142, 6.757903 * speedMult) -- delta=12.91
		Turn(rthigh, y_axis, -0.307811, 7.883266 * speedMult) -- delta=-15.06
		Turn(ruparm, x_axis, -0.193913, 2.163356 * speedMult) -- delta=4.13
		Turn(ruparm, z_axis, -0.236640, 2.646377 * speedMult) -- delta=5.05
		Turn(ruparm, y_axis, 0.351718, 0.732870 * speedMult) -- delta=1.40
		Sleep(sleepTime)
		-- Frame:36
		Turn(biggun, x_axis, -0.907682, 2.389804 * speedMult) -- delta=-4.56
		Turn(biggun, z_axis, 0.000000, 5.843321 * speedMult) -- delta=-11.16
		Turn(biggun, y_axis, 0.000000, 8.906903 * speedMult) -- delta=17.01
		Turn(head, x_axis, -0.022669, 2.848377 * speedMult) -- delta=-5.44
		Turn(head, y_axis, 0.104720, 1.853928 * speedMult) -- delta=3.54
		Turn(lfoot, x_axis, -0.034375, 1.095543 * speedMult) -- delta=-2.09
		Turn(lfoot, z_axis, -0.089446, 1.130211 * speedMult) -- delta=-2.16
		Turn(lfoot, y_axis, -0.010538, 0.186516 * speedMult) -- delta=-0.36
		Turn(lleg, x_axis, 0.623476, 0.452492 * speedMult) -- delta=0.86
		Turn(lleg, z_axis, -0.062029, 0.739218 * speedMult) -- delta=-1.41
		Turn(lleg, y_axis, -0.033957, 0.409030 * speedMult) -- delta=-0.78
		Turn(lthigh, x_axis, -0.547990, 0.501670 * speedMult) -- delta=0.96
		Turn(lthigh, z_axis, 0.358445, 2.135185 * speedMult) -- delta=4.08
		Turn(lthigh, y_axis, -0.015696, 2.565378 * speedMult) -- delta=-4.90
		Turn(luparm, x_axis, 0.335655, 2.878582 * speedMult) -- delta=-5.50
		Turn(luparm, z_axis, 0.282743, 0.767303 * speedMult) -- delta=-1.47
		Turn(luparm, y_axis, 0.125858, 3.550800 * speedMult) -- delta=6.78
		Move(pelvis, x_axis, - 2.217917, 27.582171 * speedMult) -- delta=0.92
		Move(pelvis, y_axis, -2.880190, 11.939836 * speedMult) -- delta=-0.40
		Turn(pelvis, z_axis, -0.005986, 0.074496 * speedMult) -- delta=-0.14
		Turn(pelvis, y_axis, 0.142962, 1.779079 * speedMult) -- delta=3.40
		Turn(rfoot, x_axis, -0.373382, 2.576805 * speedMult) -- delta=4.92
		Turn(rfoot, z_axis, -0.110572, 0.973786 * speedMult) -- delta=-1.86
		Turn(rfoot, y_axis, -0.002176, 0.108303 * speedMult) -- delta=0.21
		Turn(rleg, x_axis, 0.999798, 3.377523 * speedMult) -- delta=-6.45
		Turn(rleg, z_axis, -0.113808, 1.361919 * speedMult) -- delta=-2.60
		Turn(rleg, y_axis, -0.096141, 1.283335 * speedMult) -- delta=-2.45
		Turn(rloarm, x_axis, -1.454183, 7.584794 * speedMult) -- delta=14.49
		Turn(rloarm, z_axis, 0.162961, 0.240689 * speedMult) -- delta=-0.46
		Turn(rloarm, y_axis, 0.180905, 0.945526 * speedMult) -- delta=1.81
		Turn(rthigh, x_axis, -0.598987, 0.895861 * speedMult) -- delta=1.71
		Turn(rthigh, z_axis, -0.031948, 1.685803 * speedMult) -- delta=3.22
		Turn(rthigh, y_axis, -0.389890, 2.462378 * speedMult) -- delta=-4.70
		Turn(ruparm, x_axis, -0.219471, 0.766759 * speedMult) -- delta=1.46
		Turn(ruparm, z_axis, -0.205374, 0.937957 * speedMult) -- delta=1.79
		Turn(ruparm, y_axis, 0.360376, 0.259752 * speedMult) -- delta=0.50
		Sleep(sleepTime)
	end
end

local function StopDance1()
	isDancing = false
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)

	local speedMult = 4

	Move(pelvis, x_axis, 0.000000, 182.799768 * speedMult)
	Move(pelvis, y_axis, -1.000000, 94.009519 * speedMult)
	Move(pelvis, z_axis, 0.000000, 7.395249 * speedMult)
	Turn(biggun, x_axis, -0.907682, 13.485335 * speedMult)
	Turn(biggun, y_axis, 0.000000, 50.260359 * speedMult)
	Turn(biggun, z_axis, 0.000000, 32.973012 * speedMult)
	Turn(dish, y_axis, 0.130900, -1.090831 * speedMult)
	Turn(head, x_axis, -0.022669, 5.864306 * speedMult)
	Turn(head, y_axis, 0.000000, 6.434447 * speedMult)
	Turn(lfoot, x_axis, 0.051737, 15.527122 * speedMult)
	Turn(lfoot, y_axis, 0.000000, 0.596157 * speedMult)
	Turn(lfoot, z_axis, 0.003196, 5.817875 * speedMult)
	Turn(lleg, x_axis, 0.307814, 22.080013 * speedMult)
	Turn(lleg, y_axis, 0.000000, 3.518799 * speedMult)
	Turn(lleg, z_axis, 0.001989, 4.896306 * speedMult)
	Turn(lthigh, x_axis, -0.331832, 10.807897 * speedMult)
	Turn(lthigh, y_axis, 0.227002, 13.113438 * speedMult)
	Turn(lthigh, z_axis, 0.163477, 11.495862 * speedMult)
	Turn(luparm, x_axis, 0.335655, 16.243426 * speedMult)
	Turn(luparm, y_axis, 0.125858, 20.036650 * speedMult)
	Turn(luparm, z_axis, 0.282743, 4.329781 * speedMult)
	Turn(pelvis, y_axis, 0.000000, 10.039089 * speedMult)
	Turn(pelvis, z_axis, 0.000000, 0.420372 * speedMult)
	Turn(rfoot, x_axis, -0.002780, 18.530126 * speedMult)
	Turn(rfoot, y_axis, -0.012972, 0.539800 * speedMult)
	Turn(rfoot, z_axis, -0.050249, 6.107579 * speedMult)
	Turn(rleg, x_axis, 0.391571, 30.411328 * speedMult)
	Turn(rleg, y_axis, -0.010984, 4.257849 * speedMult)
	Turn(rleg, z_axis, -0.030601, 5.404025 * speedMult)
	Turn(rloarm, x_axis, -0.928515, 42.799873 * speedMult)
	Turn(rloarm, y_axis, 0.000000, 9.045273 * speedMult)
	Turn(rloarm, z_axis, 0.000000, 8.148036 * speedMult)
	Turn(rthigh, x_axis, -0.357098, 12.094440 * speedMult)
	Turn(rthigh, y_axis, -0.233321, 15.766531 * speedMult)
	Turn(rthigh, z_axis, -0.136268, 13.515805 * speedMult)
	Turn(ruparm, x_axis, 0.430977, 32.522415 * speedMult)
	Turn(ruparm, y_axis, 0.000000, 18.018824 * speedMult)
	Turn(ruparm, z_axis, -0.216421, 5.292757 * speedMult)
	Turn(torso, x_axis, -0.039513, -0.329272 * speedMult)
	Turn(torso, y_axis, 0.000000, 4.386516 * speedMult)
	Turn(torso, z_axis, 0.000000, 0.183485 * speedMult)
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
	turn(torso,1, -2.263907, 15.181924)
	turn(torso,2, 0.000000, 59.095757)
	turn(torso,3, 0.000000, 18.561539)
end

local boredTime = 0
function AmIBored()
	if bMoving == false and isAiming == false and isBuilding == false and isDancing == false then
		boredTime = boredTime + 1
	end
	if boredTime > (600 * (1000/131)) and not isDancing then
		isDancing = true
		StartThread(Dance1)
		boredTime = 0
	end
end


function GameOverAnim()
	if not isDancing then
		isDancing = true
		StartThread(Dance1)
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
		StartThread(AmIBored)

	end
end

function ResumeBuilding()
	Show(nano)
	Sleep(800)
	if isBuilding and not isAiming then
		Turn(aimy1, 2, buildHeading, rad(150.000000))
		Turn(luparm, 1, rad(-55) - buildPitch, rad(45.000000))
	end
	return (0)
end

local unitStates = {}
local wasHitTriggerWindow = 0
local flashbangReloadFrame = 0
local flashbangArmorDurationFrame = 0
local lastFrameCheckHealth = 0
function TimerCheck()
	while true do
		local health = spGetUnitHealth(unitID)
		local frame = GetGameFrame()
		unitStates = spGetUnitStates(unitID)
		if health < (lastFrameCheckHealth - 50) then
			wasHitTriggerWindow = frame + 150
			if frame < wasHitTriggerWindow and flashbangReloadFrame < frame then
				if unitStates.cloak == true then
					spSetUnitArmored(unitID, true)
					flashbangReloadFrame = frame+570
					flashbangArmorDurationFrame = frame+120
					EmitSfx(nano, 2048+5)
					EmitSfx(nano, SFX.CEG+3)
					Sleep(1000)
					spSetUnitCloak(unitID, true)
				end
			end
		end
		if flashbangArmorDurationFrame < frame then
			spSetUnitArmored(unitID, false)
		end
		lastFrameCheckHealth = health
		Sleep(500)
	end
end

function script.Create()
	--Turn(lflare, 1,math.rad(90)) -- WHY?
	--Turn(nano, 1,math.rad(90)) -- WHY?
	--Turn(laserflare, 1,math.rad(90)) -- WHY?
	Hide(missileflare)
	Hide(nano)
	Hide(armhexl_emit)
	Hide(armhexl2_emit)
	Spin(dish, 2, 2.5)
	isAiming = false
	isAimingDgun = false
    isAimingTach = false
	isBuilding = false
	isDancing = false
	bAiming = false
	buildHeading = 0
	buildPitch = 0
	leftArm = true
	rightArm = true
	animSpeed = 4
	StartThread(UnitSpeed)
	StartThread(StopWalking)
	StartThread(TimerCheck)
end

function script.StartMoving()
	if isDancing then StartThread(StopDance1) end
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
    elseif weapons[weapon] == "tachcannon" then
        return luparm
	elseif weapons[weapon] == "flashbang" then
        return nano
	elseif weapons[weapon] == "backlauncher" then
		return torso
	end
end

function script.AimWeapon(weapon, heading, pitch)
  --Spring.Echo("Armcom aiming:",weapons[weapon])
  local reloadingFrameTach =  Spring.GetUnitWeaponState(unitID, 4, 'reloadFrame')
    if weapons[weapon] == "laser" then
		if isAimingDgun == true or isAimingTach == true then
			return false
		else
			leftArm = false
			SetSignalMask(SIG_AIM)
			Signal(SIG_AIM)
			Turn(aimy1, 2, heading, rad(300.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
			Turn(rloarm, 1, rad(-55), rad(390.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
			Turn(ruparm, 1, rad(-40)-pitch, rad(390.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
			-- if the turret cannot turn to its new heading in one frame, wait for turn
			if math.abs(last_primary_heading-heading)>rad(10.0000) then
				-- seems to take 1 frame for WaitForTurn to process
				WaitForTurn(aimy1,2)
			end
			last_primary_heading=heading;
			isAiming = true
			if isBuilding == true then
				StartThread(ResumeBuilding)
			end
			StartThread(Restore)
			return true
		end
	elseif weapons[weapon] == "uwlaser" then
		if isAimingDgun == true or isAimingTach == true then
			return false
		elseif not BelowWater(rloarm) then
			return false
		else
			leftArm = false
			SetSignalMask(SIG_AIM)
			Signal(SIG_AIM)

			Turn(aimy1, 2, heading, rad(300.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
			Turn(rloarm, 1, rad(-55), rad(390.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
			Turn(ruparm, 1, rad(-40)-pitch, rad(390.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))

			WaitForTurn(aimy1,2)
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
		Turn(aimy1, 2, heading, rad(360.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
		Turn(biggun, 1, rad(-105), rad(900.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
		Turn(luparm, 1, rad(15)-pitch, rad(900.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
		WaitForTurn(aimy1,2)
		return true
    elseif weapons[weapon] == "tachcannon" then
        if reloadingFrameTach < GetGameFrame() then
            isAimingTach = true 
		    Turn(aimy1, 2, heading, rad(360.0000)) -- Turn(torso, y-axis, heading, math.rad(300))
		    Turn(biggun, 1, rad(-105), rad(900.0000)) -- Turn(rloarm, x-axis, math.rad(-55), math.rad(390))
		    Turn(luparm, 1, rad(15)-pitch, rad(900.0000)) -- Turn(ruparm,	x-axis, math.rad(-55) - pitch, math.rad(390))
		    WaitForTurn(aimy1,2)
		    return true
        end
	elseif weapons[weapon] == "flashbang" then
		return false
	elseif weapons[weapon] == "backlauncher" then
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
    elseif weapons[weapon] == "tachcannon" then
        isAimingTach = false
		turn(luparm, 1, 20)
		turn(biggun, 1, -100)
		move(barrel, 2, -1.5)
		turn(luparm, 1, 5, 100)
		turn(biggun, 1, -85, 100)
		move(barrel, 2, 0, 5)
		return true
	elseif weapons[weapon] == "flashbang" then
		Sleep(100)
		return false
	elseif weapons[weapon] == "backlauncher" then
		Sleep(100)
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
    elseif weapons[weapon] == "tachcannon" then
		return lflare
	elseif weapons[weapon] == "flashbang" then
		return nano
	elseif weapons[weapon] == "backlauncher" then
		return missileflare
	end
end

function script.StartBuilding(heading, pitch)
	Show(nano)
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
	Show (armhexl_emit)
	Show (armhexl2_emit)
	--Show (cagelight_emit);
	--Spin (cagelight, z_axis,-8);
	return true
end

function script.StopBuilding()
	Hide(nano)
	leftArm = true
	isBuilding = false
	Spring.UnitScript.SetUnitValue(COB.INBUILDSTANCE, false)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	StartThread(Restore)
	Hide (armhexl_emit)
	Hide (armhexl2_emit)
	--Turn (cagelight, z_axis,0,15);
	return true
end

function script.QueryNanoPiece()
	local piecenum;
	piecenum = nano;
	return piecenum
end

function Restore()
	SetSignalMask(SIG_AIM)
	isAiming = false
	isAimingDgun = false
    isAimingTach = false
	Sleep(3000)
	turn(aimy1, 2, 0, 105)
	turn(biggun, 1, -38, 95.0000)
	turn(luparm, 1, 0, 95.0000)
	turn(rloarm, 1, -38, 95.0000)
	turn(ruparm, 1, 0, 95.0000)
	rightArm = true
	leftArm = true
	-- for the AimPrimary script, to ensure wait-for-turn is called at least on the first aim
	last_primary_heading = -1000000
	Spin(dish, 2, 2.5)
end



function script.Killed()
	return 1
end
