
--Skeleton pieces
local torso, lfirept, rbigflash, nanospray, nanolathe, luparm, ruparm, pelvis, rthigh, lthigh, biggun, lleg, l_foot, rleg, r_foot, head, teleport, aimx1, aimy1,hatpoint, crown, medalsilver, medalbronze, medalgold = piece("torso", "lfirept", "rbigflash", "nanospray", "nanolathe", "luparm", "ruparm", "pelvis", "rthigh", "lthigh", "biggun", "lleg", "l_foot", "rleg", "r_foot", "head", "teleport", "aimx1", "aimy1","hatpoint", "crown", "medalsilver", "medalbronze", "medalgold")



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

local function BelowWater(piecename)
	local _,y,_ = Spring.GetUnitPiecePosition(unitID, piecename)
  -- this returns unit space, so why does it work for corcom?
  local _, py, _ = Spring.GetUnitPosition(unitID)
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
	SetSignalMask(SIG_WALK)
		if (bMoving) then --Frame:6
			if (rightArm) then turn(biggun, 1, 7.000000, 474.333919 / animSpeed) end
			if (rightArm) then turn(biggun, 3, -0.000000, 59.118463 / animSpeed)  end
			if (rightArm) then turn(biggun, 2, 0.000000, 4.555160 / animSpeed)  end
			turn(head, 1, -0.927302, 27.819048 / animSpeed)
			turn(head, 2, 9.458549, 283.756478 / animSpeed)
			turn(l_foot, 1, -10.561878, 244.413750 / animSpeed)
			turn(l_foot, 3, 3.674625, 126.014557 / animSpeed)
			turn(l_foot, 2, 0.417197, 19.723897 / animSpeed)
			turn(lleg, 1, -21.193560, 635.806788 / animSpeed)
			turn(lleg, 3, -5.208681, 156.260440 / animSpeed)
			turn(lleg, 2, -2.267315, 68.019463 / animSpeed)
			turn(lthigh, 1, 32.834741, 985.042232 / animSpeed)
			turn(lthigh, 3, 2.299529, 68.985869 / animSpeed)
			turn(lthigh, 2, -9.494972, 729.974777 / animSpeed)
			if (leftArm) then turn(luparm, 1, -8.891101, 475.860825 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, -9.391724, 738.230529 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, -7.000000, 413.857033 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 3, -0.000000, 55.718905 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 2, 0.000000, 3.308265 / animSpeed)  end
			move(pelvis, 2, 0.000000, 9.036713 / animSpeed)
			turn(pelvis, 1, 0.500000, 15.000000 / animSpeed)
			turn(pelvis, 2, 10.000000, 299.999991 / animSpeed)
			turn(r_foot, 1, -13.659087, 362.223883 / animSpeed)
			turn(r_foot, 3, -1.655717, 49.672541 / animSpeed)
			turn(r_foot, 2, -10.105174, 303.223681 / animSpeed)
			turn(rleg, 1, 53.029196, 1590.875879 / animSpeed)
			turn(rleg, 3, -16.484759, 494.542767 / animSpeed)
			turn(rleg, 2, 6.317234, 189.517028 / animSpeed)
			turn(rthigh, 1, -61.264912, 1837.947352 / animSpeed)
			turn(rthigh, 3, 14.864373, 445.931201 / animSpeed)
			turn(rthigh, 2, 3.324302, 867.983501 / animSpeed)
			if (rightArm) then turn(ruparm, 1, 27.254234, 557.381267 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, -7.659001, 145.469864 / animSpeed)  end
			turn(torso, 1, 0.527975, 15.839238 / animSpeed)
			turn(torso, 2, -16.999999, 509.999980 / animSpeed)
			Sleep(197)
		end
	while (bMoving) do
		if (bMoving) then --Frame:12
			if (rightArm) then turn(biggun, 1, -0.000000, 210.000014 / animSpeed)  end
			turn(head, 1, -2.018726, 32.742739 / animSpeed)
			turn(head, 2, 6.502752, 88.673904 / animSpeed)
			turn(l_foot, 3, 0.690912, 89.511375 / animSpeed)
			turn(l_foot, 2, -0.097163, 15.430812 / animSpeed)
			turn(lleg, 1, 35.516424, 1701.299496 / animSpeed)
			turn(lleg, 3, -3.345941, 55.882202 / animSpeed)
			turn(lleg, 2, 1.271344, 106.159793 / animSpeed)
			turn(lthigh, 1, 15.193594, 529.234425 / animSpeed)
			turn(lthigh, 3, -3.177570, 164.312977 / animSpeed)
			turn(lthigh, 2, -6.287450, 96.225652 / animSpeed)
			if (leftArm) then turn(luparm, 1, -15.000002, 183.267021 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, -7.060122, 69.948061 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, -4.812500, 65.625000 / animSpeed)  end
			move(pelvis, 1, 1.424151, 42.600518 / animSpeed)
			move(pelvis, 2, -1.300000, 38.999999 / animSpeed)
			turn(pelvis, 1, 3.000000, 75.000003 / animSpeed)
			turn(pelvis, 2, 6.875000, 93.749994 / animSpeed)
			turn(r_foot, 1, 2.905055, 496.924251 / animSpeed)
			turn(r_foot, 3, 0.000162, 49.676377 / animSpeed)
			turn(r_foot, 2, 0.004918, 303.302750 / animSpeed)
			turn(rleg, 1, -19.644176, 2180.201147 / animSpeed)
			turn(rleg, 3, 6.272890, 682.729471 / animSpeed)
			turn(rleg, 2, 0.965251, 160.559493 / animSpeed)
			turn(rthigh, 1, -38.695983, 677.067876 / animSpeed)
			turn(rthigh, 3, -7.830160, 680.835989 / animSpeed)
			turn(rthigh, 2, -7.258941, 317.497309 / animSpeed)
			if (rightArm) then turn(ruparm, 1, 17.856785, 281.923469 / animSpeed)  end
			turn(torso, 1, 0.011484, 15.494713 / animSpeed)
			turn(torso, 3, -2.604197, 78.125917 / animSpeed)
			turn(torso, 2, -11.687500, 159.374994 / animSpeed)
		Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:18

			if (rightArm) then turn(biggun, 1, 14.962093, 448.862786 / animSpeed)  end
			turn(head, 1, 6.002970, 240.650875 / animSpeed)
			turn(head, 2, -0.000000, 195.082586 / animSpeed)
			turn(l_foot, 1, -13.296228, 81.595514 / animSpeed)
			turn(l_foot, 3, -0.003109, 20.820630 / animSpeed)
			turn(lleg, 1, 76.570164, 1231.612198 / animSpeed)
			turn(lleg, 3, 10.958114, 429.121655 / animSpeed)
			turn(lleg, 2, -6.826730, 242.942220 / animSpeed)
			turn(lthigh, 1, -4.003060, 575.899605 / animSpeed)
			turn(lthigh, 3, -3.570822, 11.797560 / animSpeed)
			turn(lthigh, 2, -3.398772, 86.660360 / animSpeed)
			if (leftArm) then turn(luparm, 1, -5.933402, 271.998004 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, -5.390060, 50.101832 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, 0.000000, 144.375003 / animSpeed)  end
			move(pelvis, 1, 0.676773, 22.421322 / animSpeed)
			move(pelvis, 3, 0.677474, 20.324208 / animSpeed)
			move(pelvis, 2, -2.000000, 21.000001 / animSpeed)
			turn(pelvis, 1, 1.500000, 45.000001 / animSpeed)
			turn(pelvis, 2, 0.000000, 206.249997 / animSpeed)
			turn(r_foot, 1, 17.020208, 423.454591 / animSpeed)
			turn(r_foot, 3, -0.952274, 28.573097 / animSpeed)
			turn(r_foot, 2, 1.028123, 30.696158 / animSpeed)
			turn(rleg, 1, 18.579177, 1146.700567 / animSpeed)
			turn(rleg, 3, -7.987204, 427.802811 / animSpeed)
			turn(rleg, 2, 1.523459, 16.746224 / animSpeed)
			turn(rthigh, 1, -36.737764, 58.746560 / animSpeed)
			turn(rthigh, 3, 2.700298, 315.913722 / animSpeed)
			turn(rthigh, 2, -1.187645, 182.138894 / animSpeed)
			if (rightArm) then turn(ruparm, 1, 24.848809, 209.760710 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, -5.247890, 72.333343 / animSpeed)  end
			turn(torso, 1, 7.182205, 215.121631 / animSpeed)
			turn(torso, 3, -1.177850, 42.790427 / animSpeed)
			turn(torso, 2, 0.000001, 350.625002 / animSpeed)
			Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:24
			if not Spring.GetUnitIsCloaked(unitID) then
				UnitScript.EmitSfx(r_foot, 1024 + 2)
			end
			if (rightArm) then turn(biggun, 1, -1.500000, 493.862787 / animSpeed)  end
			turn(head, 1, 1.940259, 121.881321 / animSpeed)
			turn(head, 2, -6.502753, 195.082587 / animSpeed)
			turn(l_foot, 1, -3.417831, 296.351915 / animSpeed)
			turn(l_foot, 3, 0.743487, 22.397871 / animSpeed)
			turn(l_foot, 2, 5.655822, 170.494319 / animSpeed)
			turn(lleg, 1, 82.760282, 185.703554 / animSpeed)
			turn(lleg, 3, 1.830733, 273.821434 / animSpeed)
			turn(lleg, 2, 3.172775, 299.985148 / animSpeed)
			turn(lthigh, 1, -52.264461, 1447.842024 / animSpeed)
			turn(lthigh, 3, -8.297404, 141.797461 / animSpeed)
			turn(lthigh, 2, -4.035460, 19.100654 / animSpeed)
			if (leftArm) then turn(luparm, 1, 17.338307, 698.151274 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, 2.367461, 232.725648 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, 4.812500, 144.375000 / animSpeed)  end
			move(pelvis, 1, 0.378759, 8.940423 / animSpeed)
			move(pelvis, 3, 0.000000, 20.324208 / animSpeed)
			move(pelvis, 2, -0.700000, 39.000000 / animSpeed)
			turn(pelvis, 1, -1.000000, 75.000001 / animSpeed)
			turn(pelvis, 2, -6.874999, 206.249972 / animSpeed)
			turn(r_foot, 1, -4.390164, 642.311173 / animSpeed)
			turn(r_foot, 3, -0.230726, 21.646450 / animSpeed)
			turn(r_foot, 2, 0.079215, 28.467254 / animSpeed)
			turn(rleg, 1, 18.245039, 10.024139 / animSpeed)
			turn(rleg, 3, -4.378021, 108.275463 / animSpeed)
			turn(rleg, 2, 0.665185, 25.748213 / animSpeed)
			turn(rthigh, 1, -11.751762, 749.580050 / animSpeed)
			turn(rthigh, 3, 1.829745, 26.116573 / animSpeed)
			turn(rthigh, 2, 7.757604, 268.357477 / animSpeed)
			if (rightArm) then turn(ruparm, 1, 2.805339, 661.304091 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, 6.888889, 364.103349 / animSpeed)  end
			turn(torso, 1, 2.661677, 135.615854 / animSpeed)
			turn(torso, 3, -0.344737, 24.993395 / animSpeed)
			turn(torso, 2, 11.687500, 350.624996 / animSpeed)
			Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:30
			if (rightArm) then turn(biggun, 1, -7.000000, 165.000000 / animSpeed)  end
			turn(head, 1, -1.322678, 97.888103 / animSpeed)
			turn(head, 2, -9.458549, 88.673879 / animSpeed)
			turn(l_foot, 1, -1.066570, 70.537812 / animSpeed)
			turn(l_foot, 2, 9.992719, 130.106907 / animSpeed)
			turn(lleg, 1, 60.873228, 656.611630 / animSpeed)
			turn(lleg, 3, 1.143846, 20.606595 / animSpeed)
			turn(lleg, 2, 3.514866, 10.262720 / animSpeed)
			turn(lthigh, 1, -67.429260, 454.943977 / animSpeed)
			turn(lthigh, 3, -11.475603, 95.345966 / animSpeed)
			turn(lthigh, 2, -5.140474, 33.150409 / animSpeed)
			if (leftArm) then turn(luparm, 1, 27.578395, 307.202631 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, 4.673861, 69.191991 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, 9.511417, 140.967523 / animSpeed)  end
			move(pelvis, 1, 0.004134, 11.238773 / animSpeed)
			move(pelvis, 2, 0.000000, 21.000000 / animSpeed)
			turn(pelvis, 1, 0.500000, 45.000000 / animSpeed)
			turn(pelvis, 2, -9.999998, 93.749968 / animSpeed)
			turn(r_foot, 1, -9.321513, 147.940450 / animSpeed)
			turn(r_foot, 3, -3.660134, 102.882224 / animSpeed)
			turn(r_foot, 2, -0.335323, 12.436143 / animSpeed)
			turn(rleg, 1, -19.376746, 1128.653551 / animSpeed)
			turn(rleg, 3, 6.333295, 321.339483 / animSpeed)
			turn(rleg, 2, 1.919279, 37.622821 / animSpeed)
			turn(rthigh, 1, 31.823764, 1307.265781 / animSpeed)
			turn(rthigh, 3, -3.081961, 147.351186 / animSpeed)
			turn(rthigh, 2, 9.309497, 46.556798 / animSpeed)
			if (rightArm) then turn(ruparm, 1, -13.287716, 482.791638 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, 9.299999, 72.333317 / animSpeed)  end
			turn(torso, 1, 0.614511, 61.414985 / animSpeed)
			turn(torso, 3, -0.000000, 10.342095 / animSpeed)
			turn(torso, 2, 16.999999, 159.374968 / animSpeed)
			Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:36
			if (rightArm) then turn(biggun, 1, -4.812500, 65.625000 / animSpeed)  end
			turn(head, 1, -2.018726, 20.881451 / animSpeed)
			turn(head, 2, -6.502752, 88.673904 / animSpeed)
			turn(l_foot, 1, 2.869804, 118.091213 / animSpeed)
			turn(l_foot, 3, -0.000076, 20.252671 / animSpeed)
			turn(l_foot, 2, -0.000060, 299.783359 / animSpeed)
			turn(lleg, 1, -21.464800, 2470.140833 / animSpeed)
			turn(lleg, 3, -5.991945, 214.073744 / animSpeed)
			turn(lleg, 2, -2.714477, 186.880277 / animSpeed)
			turn(lthigh, 1, -37.186538, 907.281656 / animSpeed)
			turn(lthigh, 3, 10.356607, 654.966314 / animSpeed)
			turn(lthigh, 2, 10.497377, 469.135539 / animSpeed)
			if (leftArm) then turn(luparm, 1, 16.214065, 340.929900 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, 5.641061, 29.016001 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, 7.246843, 67.937245 / animSpeed)  end
			move(pelvis, 1, -1.440796, 43.347901 / animSpeed)
			move(pelvis, 2, -1.300000, 38.999999 / animSpeed)
			turn(pelvis, 1, 3.000000, 75.000003 / animSpeed)
			turn(pelvis, 2, -6.874998, 93.750007 / animSpeed)
			turn(r_foot, 1, -11.212004, 56.714740 / animSpeed)
			turn(r_foot, 3, -0.692164, 89.039097 / animSpeed)
			turn(r_foot, 2, 0.090245, 12.767050 / animSpeed)
			turn(rleg, 1, 35.289221, 1639.979014 / animSpeed)
			turn(rleg, 3, -1.040834, 221.223864 / animSpeed)
			turn(rleg, 2, 0.383076, 46.086094 / animSpeed)
			turn(rthigh, 1, 15.440428, 491.500071 / animSpeed)
			turn(rthigh, 3, 5.573259, 259.656606 / animSpeed)
			turn(rthigh, 2, 5.974292, 100.056158 / animSpeed)
			if (rightArm) then turn(ruparm, 1, -15.000002, 51.368598 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, 8.332799, 29.016001 / animSpeed)  end
			turn(torso, 1, -0.000000, 18.435316 / animSpeed)
			turn(torso, 3, 2.154603, 64.638097 / animSpeed)
			turn(torso, 2, 11.687500, 159.374994 / animSpeed)
		Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:42
			if (rightArm) then turn(biggun, 1, 0.000000, 144.375003 / animSpeed)  end
			turn(head, 1, 5.974242, 239.789054 / animSpeed)
			turn(head, 2, 0.000000, 195.082586 / animSpeed)
			turn(l_foot, 1, 18.425190, 466.661591 / animSpeed)
			turn(l_foot, 3, 0.957857, 28.737983 / animSpeed)
			turn(l_foot, 2, -1.046884, 31.404727 / animSpeed)
			turn(lleg, 1, 19.863959, 1239.862776 / animSpeed)
			turn(lleg, 3, -0.569878, 162.662028 / animSpeed)
			turn(lleg, 2, 0.784288, 104.962948 / animSpeed)
			turn(lthigh, 1, -37.840279, 19.612239 / animSpeed)
			turn(lthigh, 3, 2.732531, 228.722291 / animSpeed)
			turn(lthigh, 2, 1.933653, 256.911741 / animSpeed)
			if (leftArm) then turn(luparm, 1, 21.500320, 158.587669 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, 3.229950, 72.333330 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, 15.006779, 232.798102 / animSpeed)  end
			move(pelvis, 1, -0.668506, 23.168705 / animSpeed)
			move(pelvis, 3, 0.587918, 17.637532 / animSpeed)
			move(pelvis, 2, -2.000000, 21.000001 / animSpeed)
			turn(pelvis, 1, 1.500000, 45.000001 / animSpeed)
			turn(pelvis, 2, 0.000002, 206.250000 / animSpeed)
			turn(r_foot, 1, -14.533147, 99.634283 / animSpeed)
			turn(r_foot, 3, 0.003766, 20.877902 / animSpeed)
			turn(rleg, 1, 76.774892, 1244.570125 / animSpeed)
			turn(rleg, 3, -25.785241, 742.332216 / animSpeed)
			turn(rleg, 2, 19.529427, 574.390529 / animSpeed)
			turn(rthigh, 1, -3.921700, 580.863829 / animSpeed)
			turn(rthigh, 3, 7.907695, 70.033071 / animSpeed)
			turn(rthigh, 2, 3.933801, 61.214738 / animSpeed)
			if (rightArm) then turn(ruparm, 1, -10.312501, 140.625023 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, 6.026399, 69.191998 / animSpeed)  end
			turn(torso, 1, 7.296131, 218.883930 / animSpeed)
			turn(torso, 3, 0.804385, 40.506543 / animSpeed)
			turn(torso, 2, -0.000001, 350.625002 / animSpeed)
		Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:48
			if not Spring.GetUnitIsCloaked(unitID) then
				UnitScript.EmitSfx(l_foot, 1024 + 2)
			end
			if (rightArm) then turn(biggun, 1, 4.812500, 144.375000 / animSpeed) end
			turn(head, 1, 1.854076, 123.605001 / animSpeed)
			turn(head, 2, 6.502753, 195.082587 / animSpeed)
			turn(l_foot, 1, -4.058518, 674.511255 / animSpeed)
			turn(l_foot, 3, 0.230657, 21.815989 / animSpeed)
			turn(l_foot, 2, -0.080290, 28.997827 / animSpeed)
			turn(lleg, 1, 18.159385, 51.137234 / animSpeed)
			turn(lleg, 3, 2.210097, 83.399234 / animSpeed)
			turn(lleg, 2, -0.149947, 28.027061 / animSpeed)
			turn(lthigh, 1, -11.734723, 783.166677 / animSpeed)
			turn(lthigh, 3, -1.010202, 112.281987 / animSpeed)
			turn(lthigh, 2, -7.724249, 289.737054 / animSpeed)
			if (leftArm) then turn(luparm, 1, 10.662637, 325.130494 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, -6.888889, 303.565158 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, -1.500000, 495.203383 / animSpeed)  end
			move(pelvis, 1, -0.247683, 12.624712 / animSpeed)
			move(pelvis, 3, 0.000000, 17.637532 / animSpeed)
			move(pelvis, 2, -0.700000, 39.000000 / animSpeed)
			turn(pelvis, 1, -1.000000, 75.000001 / animSpeed)
			turn(pelvis, 2, 6.875002, 206.249994 / animSpeed)
			turn(r_foot, 1, -5.256663, 278.294500 / animSpeed)
			turn(r_foot, 3, -0.935032, 28.163964 / animSpeed)
			turn(r_foot, 2, -6.076239, 183.160630 / animSpeed)
			turn(rleg, 1, 83.229823, 193.647952 / animSpeed)
			turn(rleg, 3, -23.938133, 55.413256 / animSpeed)
			turn(rleg, 2, 17.301380, 66.841409 / animSpeed)
			turn(rthigh, 1, -52.243014, 1449.639431 / animSpeed)
			turn(rthigh, 3, 9.159658, 37.558877 / animSpeed)
			turn(rthigh, 2, 2.585700, 40.443027 / animSpeed)
			if (rightArm) then turn(ruparm, 1, 5.305341, 468.535280 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, 3.273600, 82.583992 / animSpeed)  end
			turn(torso, 1, 2.755654, 136.214300 / animSpeed)
			turn(torso, 3, 0.258552, 16.374982 / animSpeed)
			turn(torso, 2, -11.687500, 350.624996 / animSpeed)
		Sleep((33*animSpeed) -1)
		end
		if (bMoving) then --Frame:54
			if (rightArm) then turn(biggun, 1, 7.000000, 65.625012 / animSpeed)  end
			turn(head, 1, -0.920485, 83.236809 / animSpeed)
			turn(head, 2, 9.458549, 88.673879 / animSpeed)
			turn(l_foot, 1, -10.560809, 195.068730 / animSpeed)
			turn(l_foot, 3, 3.674688, 103.320920 / animSpeed)
			turn(l_foot, 2, 0.417471, 14.932822 / animSpeed)
			turn(lleg, 1, -21.155517, 1179.447055 / animSpeed)
			turn(lleg, 3, -5.055147, 217.957321 / animSpeed)
			turn(lleg, 2, -2.028407, 56.353797 / animSpeed)
			turn(lthigh, 1, 32.776360, 1335.332505 / animSpeed)
			turn(lthigh, 3, 2.172518, 95.481604 / animSpeed)
			turn(lthigh, 2, -9.099435, 41.255581 / animSpeed)
			if (leftArm) then turn(luparm, 1, -8.891101, 586.612163 / animSpeed)  end
			if (leftArm) then turn(luparm, 2, -9.299999, 72.333317 / animSpeed)  end
			if (leftArm) then turn(nanolathe, 1, -7.000000, 165.000000 / animSpeed)  end
			move(pelvis, 1, 0.004134, 7.554485 / animSpeed)
			move(pelvis, 2, 0.000000, 21.000000 / animSpeed)
			turn(pelvis, 1, 0.500000, 45.000000 / animSpeed)
			turn(pelvis, 2, 10.000000, 93.749930 / animSpeed)
			turn(r_foot, 1, -13.659087, 252.072695 / animSpeed)
			turn(r_foot, 3, -1.655717, 21.620542 / animSpeed)
			turn(r_foot, 2, -10.105174, 120.868044 / animSpeed)
			turn(rleg, 1, 53.029196, 906.018822 / animSpeed)
			turn(rleg, 3, -16.484759, 223.601218 / animSpeed)
			turn(rleg, 2, 6.317234, 329.524363 / animSpeed)
			turn(rthigh, 1, -61.264912, 270.656935 / animSpeed)
			turn(rthigh, 3, 14.864373, 171.141472 / animSpeed)
			turn(rthigh, 2, 3.324302, 22.158064 / animSpeed)
			if (rightArm) then turn(ruparm, 1, 27.254234, 658.466782 / animSpeed)  end
			if (rightArm) then turn(ruparm, 2, -7.659001, 327.978017 / animSpeed)  end
			turn(torso, 1, 0.527975, 66.830393 / animSpeed)
			turn(torso, 3, -0.000000, 7.756572 / animSpeed)
			turn(torso, 2, -16.999999, 159.374968 / animSpeed)
		Sleep((33*animSpeed) -1)
		end
	end
end

function SprayNano(heading, pitch)
	SetSignalMask(SIG_AIM)
	Sleep(1000)
	while (true) do
		Sleep(1000)
	end
end

function StopWalking()
	move(pelvis, 1, 0.000000, 7.224650)
	move(pelvis, 2, -0.301224, 6.500000)
	move(pelvis, 3, 0.000000, 3.387368)
	if (rightArm) then turn(biggun, 1, -8.811130, 82.310465) end
	if (rightArm) then turn(biggun, 2, 0.151839, 0.759193) end
	if (rightArm) then turn(biggun, 3, -1.970615, 9.853077) end
	turn(head, 1, 0.000000, 40.108479)
	turn(head, 2, 0.000000, 47.292746)
	turn(l_foot, 1, -2.414753, 112.418542)
	turn(l_foot, 2, -0.240266, 49.963893)
	turn(l_foot, 3, -0.525861, 21.002426)
	turn(lleg, 1, 0.000000, 411.690139)
	turn(lleg, 2, 0.000000, 49.997525)
	turn(lleg, 3, 0.000000, 71.520276)
	turn(lthigh, 1, 0.000000, 241.307004)
	turn(lthigh, 2, 14.837520, 121.662463)
	turn(lthigh, 3, 0.000000, 109.161052)
	if (leftArm) then turn(luparm, 1, 6.970926, 116.358546) end
	if (leftArm) then turn(luparm, 2, 15.215961, 123.038422) end
	if (leftArm) then turn(nanolathe, 1, 6.795234, 82.533897) end
	if (leftArm) then turn(nanolathe, 2, -0.110275, 0.551377) end
	if (leftArm) then turn(nanolathe, 3, -1.857297, 9.286484) end
	turn(pelvis, 1, 0.000000, 12.500000)
	turn(pelvis, 2, 0.000000, 49.999999)
	turn(r_foot, 1, -1.584957, 107.051862)
	turn(r_foot, 2, 0.000000, 50.550458)
	turn(r_foot, 3, 0.000000, 17.147037)
	turn(rleg, 1, 0.000000, 363.366858)
	turn(rleg, 2, 0.000000, 95.731755)
	turn(rleg, 3, 0.000000, 123.722036)
	turn(rthigh, 1, 0.000000, 306.324559)
	turn(rthigh, 2, -25.608481, 144.663917)
	turn(rthigh, 3, 0.000000, 113.472665)
	if (rightArm) then turn(ruparm, 1, 8.674858, 110.217349) end
	if (rightArm) then turn(ruparm, 2, -12.507997, 60.683891) end
	turn(torso, 1, 0.000000, 36.480655)
	turn(torso, 2, 0.000000, 84.999997)
	turn(torso, 3, 0.000000, 13.020986)
end

function AmIBored()
	if bMoving == false and isAiming == false and isBuilding == false then
		return true
	else
		return false
	end
end

function bigfire()
	turn(ruparm, 1, 40)
	turn(biggun, 1, -40)
	turn(ruparm, 1, 0, 250)
	turn(biggun, 1, 0, 250)
end

function UnitSpeed()
	maxSpeed = UnitDefs[Spring.GetUnitDefID(unitID)].speed
	animFramesPerKeyframe = 6 --we need to calc the frames per keyframe value, from the known animtime
	maxSpeed = maxSpeed + (maxSpeed /(2*animFramesPerKeyframe)) -- add fudge
	while(true)do
		vx,vy,vz,Speed = Spring.GetUnitVelocity(unitID)
		currentSpeed = Speed * 30
		animSpeed = (currentSpeed)
		if (animSpeed<1) then
			animSpeed=1
		end
		animSpeed = (maxSpeed * 6) / animSpeed
		if (animSpeed<3) then
			animSpeed=3
		end
		if (animSpeed>12) then
			animSpeed = 12
		end
		Sleep (131)
	end
end

function ResumeBuilding()
	Sleep(800)
	if isBuilding and not isAiming then
		Turn(aimy1, 2, buildheading - rad(20), rad(300.000000))
		Turn(aimx1, 1, rad(-20.000000) - buildpitch, rad(90.000000))
	end
	return (0)
end

function script.Create()
	Hide(crown)
	Hide(medalgold)
	Hide(medalsilver)
	Hide(medalbronze)
	Move(crown, y_axis, 100, 9999)
	Move(medalgold, y_axis, 100, 9999)
	Move(medalsilver, y_axis, 100, 9999)
	Move(medalbronze, y_axis, 100, 9999)
	isAiming = false
	isAimingDgun = false
	isBuilding = false
	bAiming = false
	buildHeading = 0
	buildPitch = 0
	leftArm = true
	rightArm = true
	animSpeed = 6
	StartThread(UnitSpeed)
	StartThread(StopWalking)
end

function ShowCrown()
	Show(crown)
end
function ShowMedalGold()
	Show(medalgold)
end
function ShowMedalSilver()
	Show(medalsilver)
end
function ShowMedalBronze()
	Show(medalbronze)
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
		return torso
	elseif weapons[weapon] == "uwlaser" then
		return torso
	elseif weapons[weapon] == "dgun" then
		return biggun
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
			Turn(aimy1, 2, heading, rad(300.000000))
			Turn(aimx1, 1, rad(-5.000000) - pitch, rad(250.000000))
			WaitForTurn(aimy1,2)
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
		elseif not BelowWater(nanolathe) then
			return false
		else
			leftArm = false
			SetSignalMask(SIG_AIM)
			Signal(SIG_AIM)
			Turn(aimy1, 2, heading, rad(300.000000))
			Turn(aimx1, 1, rad(-5.000000) - pitch, rad(250.000000))
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
		Turn(aimy1, 2, heading, rad(300.000000))
		Turn(aimx1, 1, rad(-5.000000) - pitch, rad(250.000000))
		WaitForTurn(aimy1,2)
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
		bigfire()
		return true
	end
end

function script.QueryWeapon(weapon)
	if weapons[weapon] == "laser" then
		return lfirept
	elseif weapons[weapon] == "uwlaser" then
		return lfirept
	elseif weapons[weapon] == "dgun" then
		return rbigflash
	end
end

function script.StartBuilding(heading, pitch)
	Signal(SIG_AIM)
	isBuilding = true
	leftArm = false
		Turn(aimy1, 2, heading, rad(300.000000))
		Turn(aimx1, 1, rad(-5.000000) - pitch, rad(250.000000))
		WaitForTurn(aimy1,2)
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

function Restore()
	SetSignalMask(SIG_AIM)
	Sleep(3000)
	turn(aimy1, 2, 0, 90)
	turn(aimx1, 1, 0, 90)
	isAiming = false
	isAimingDgun = false
	rightArm = true
	leftArm = true
end

function script.QueryNanoPiece()
	local piecenum;
	piecenum = nanospray;
	return piecenum
end

function script.Killed()
	return 1
end
