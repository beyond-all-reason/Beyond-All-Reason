local aimy = piece("aimy")
local base = piece("base")
local flarel3 = piece("flarel3")
local flarer3 = piece("flarer3")
local footbl = piece("footbl")
local footbr = piece("footbr")
local footfl = piece("footfl")
local footfr = piece("footfr")
local laimx = piece("laimx")
local lbarrel1 = piece("lbarrel1")
local lbarrel2 = piece("lbarrel2")
local legbl = piece("legbl")
local legbr = piece("legbr")
local legfl = piece("legfl")
local legfr = piece("legfr")
local lflare1 = piece("lflare1")
local lflare2 = piece("lflare2")
local lforearm = piece("lforearm")
local lhand = piece("lhand")
local lshoulder = piece("lshoulder")
local lwrist = piece("lwrist")
local raimx = piece("raimx")
local rbarrel1 = piece("rbarrel1")
local rbarrel2 = piece("rbarrel2")
local rflare1 = piece("rflare1")
local rflare2 = piece("rflare2")
local rforearm = piece("rforearm")
local rhand = piece("rhand")
local rshoulder = piece("rshoulder")
local rwrist = piece("rwrist")
local thighbl = piece("thighbl")
local thighbr = piece("thighbr")
local thighfl = piece("thighfl")
local thighfr = piece("thighfr")
local torso = piece("torso")

local SIG_WALK = 1
local ANIM_FRAMES = 3
local EXPORT_FPS = 25 -- Blender scene frame rate the turn speeds below were exported at
local STRIDE = 69 -- elmos per walk cycle; lower it if planted feet slide backwards, raise it if they slip forwards
local FRAME_MS = 1000 / Game.gameSpeed + 0.01 -- Sleep floors to whole frames
local RATE_MIN, RATE_MAX = 0.3, 3
local POSE_SPEED = math.rad(360)
local YAW_SPEED = math.rad(240)
local PITCH_SPEED = math.rad(160)
local RESTORE_SPEED = YAW_SPEED * 2
local RESTORE_PITCH_SPEED = PITCH_SPEED * 2
local TOE_MAX = math.rad(20)
local PITCH_SPLIT = math.rad(25)
local HAND_PITCH_SIGN = 1 -- flip if the guns dip instead of rising past the split
-- measured in game: the hand's y axis is nearly horizontal across the barrel, its x axis nearly vertical
local HAND_AXIS_X, HAND_AXIS_Y = -0.27, 0.96
local FIRE_ANGLE = math.rad(16)
local FIRE_ANGLE_PITCH = math.rad(6)
local RATE_FRAMES = 6
local STALL_FRAMES = 6
local RESTORE_FRAMES = 90
local RECOIL = 2
local TWO_PI = 2 * math.pi
local HEADING_TO_RAD = math.pi / 32768
local walking = false
local isAiming = false
local frameDebt = 0
local GetUnitVelocity = Spring.GetUnitVelocity
local GetUnitHeading = Spring.GetUnitHeading
local GetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local GetUnitIsStunned = Spring.GetUnitIsStunned
local GetGameFrame = Spring.GetGameFrame

local aimx = {laimx, raimx}
local hands = {lhand, rhand}
local flares = {{lflare1, lflare2}, {rflare1, rflare2}}
local barrels = {{lbarrel1, lbarrel2}, {rbarrel1, rbarrel2}}
local weaponHand = {1, 1, 2, 2}
local LIGHTNING = 5
local tubes = {flarel3, flarer3}
local tubeSide = 1
local weaponFlare = {1, 2, 1, 2}
local nextHand = 1
local handShots = {0, 0}
local handShotFrame = -1000
local lastHandFrame = -1000
local HAND_GAP = math.floor(WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].reload * Game.gameSpeed / 2)

local goalYaw, beliefYaw, goalRate, lastAimHeading, lastAimFrame = 0, 0, 0, 0, -1000
local HAND_POSE_X, HAND_POSE_Y = 0.253073, -0.031416
local pivotZ = 0
local goalPitch, pitchBelief, pitchRate, lastAimPitch, lastPitchFrame = {0, 0}, {0, 0}, {0, 0}, {0, 0}, {-1000, -1000}

local function wrap(angle)
	return angle - TWO_PI * math.floor((angle + math.pi) / TWO_PI)
end

local function ToeIn(num, hand)
	local targetType, _, target = GetUnitWeaponTarget(unitID, num)
	local tx, ty, tz
	if targetType == 1 then
		_, _, _, tx, ty, tz = GetUnitPosition(target, true)
	elseif targetType == 2 then
		tx, ty, tz = target[1], target[2], target[3]
	else
		return 0
	end
	local sx, sy, sz = GetUnitPiecePosDir(unitID, aimx[hand])
	local ux, uy, uz = GetUnitPosition(unitID)
	local hull = GetUnitHeading(unitID) * HEADING_TO_RAD
	local px, pz = ux + pivotZ * math.sin(hull), uz + pivotZ * math.cos(hull)
	local toe = wrap(math.atan2(tx - sx, tz - sz) - math.atan2(tx - px, tz - pz))
	return math.max(-TOE_MAX, math.min(TOE_MAX, toe))
end

local function stepToward(belief, goal, step)
	local delta = wrap(goal - belief)
	if math.abs(delta) > step then
		return wrap(belief + (delta > 0 and step or -step))
	end
	return goal
end

local function GetSpeedParams()
	local _, _, _, speed = GetUnitVelocity(unitID)
	local rate = math.max(RATE_MIN, math.min(RATE_MAX, speed * Game.gameSpeed / STRIDE))
	frameDebt = frameDebt + ANIM_FRAMES / rate
	local frames = math.max(1, math.floor(frameDebt))
	frameDebt = frameDebt - frames
	return Game.gameSpeed / (EXPORT_FPS * frames), frames * FRAME_MS
end

local function Walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	frameDebt = 0
	local speedMult, sleepTime = GetSpeedParams()
	-- Frame: 3 (first step)
	Move(base, x_axis, 0.294572, 7.364300 * speedMult)
	Move(base, z_axis, -0.027609, 0.690225 * speedMult)
	Move(base, y_axis, -0.163141, 4.078525 * speedMult)
	Turn(base, x_axis, -0.006419, 0.160474 * speedMult)
	Turn(base, y_axis, 0.013202, 0.330057 * speedMult)
	Turn(footbl, x_axis, 0.071411, 1.785281 * speedMult)
	Turn(footbl, z_axis, 0.478768, 11.969192 * speedMult)
	Turn(footbl, y_axis, 0.037500, 0.937503 * speedMult)
	Turn(footbr, x_axis, -0.043958, 1.098940 * speedMult)
	Turn(footbr, z_axis, 0.291231, 7.280774 * speedMult)
	Turn(footbr, y_axis, -0.013221, 0.330534 * speedMult)
	Turn(footfl, x_axis, 0.047492, 1.187301 * speedMult)
	Turn(footfl, z_axis, 0.998955, 24.973877 * speedMult)
	Turn(footfl, y_axis, 0.073773, 1.844327 * speedMult)
	Turn(footfr, x_axis, -0.001691, 0.042275 * speedMult)
	Turn(footfr, z_axis, 0.623191, 15.579765 * speedMult)
	Turn(footfr, y_axis, -0.001243, 0.031074 * speedMult)
	Turn(legbl, x_axis, 0.221104, 5.527601 * speedMult)
	Turn(legbl, z_axis, -0.452967, 11.324174 * speedMult)
	Turn(legbl, y_axis, 0.088436, 2.210900 * speedMult)
	Turn(legbr, x_axis, 0.057215, 1.430384 * speedMult)
	Turn(legbr, z_axis, 0.102636, 2.565902 * speedMult)
	Turn(legbr, y_axis, 0.013433, 0.335829 * speedMult)
	Turn(legfl, x_axis, 0.074620, 1.865511 * speedMult)
	Turn(legfl, z_axis, -0.497791, 12.444769 * speedMult)
	Turn(legfl, y_axis, 0.032185, 0.804628 * speedMult)
	Turn(legfr, x_axis, -0.012468, 0.311694 * speedMult)
	Turn(legfr, z_axis, 0.027397, 0.684923 * speedMult)
	Turn(legfr, y_axis, -0.038014, 0.950354 * speedMult)
	Turn(thighbl, x_axis, 0.087478, 2.186957 * speedMult)
	Turn(thighbl, z_axis, 0.401002, 10.025049 * speedMult)
	Turn(thighbl, y_axis, 0.702733, 2.066623 * speedMult)
	Turn(thighbr, x_axis, -0.340564, 8.514108 * speedMult)
	Turn(thighbr, z_axis, -0.126084, 3.152101 * speedMult)
	Turn(thighbr, y_axis, -0.344254, 11.028608 * speedMult)
	Turn(thighfl, x_axis, -0.217744, 5.443589 * speedMult)
	Turn(thighfl, z_axis, -0.081980, 2.049501 * speedMult)
	Turn(thighfl, y_axis, -0.939146, 3.843684 * speedMult)
	Turn(thighfr, x_axis, 0.346556, 8.663890 * speedMult)
	Turn(thighfr, z_axis, -0.276569, 6.914217 * speedMult)
	Turn(thighfr, y_axis, 0.304059, 12.033480 * speedMult)
	if not isAiming then
		Turn(lforearm, x_axis, 0.872665, 4.363325 * speedMult)
		Turn(lshoulder, x_axis, 0.436332, 0.872665 * speedMult)
		Turn(lshoulder, z_axis, 0.610865, 2.181663 * speedMult)
		Turn(rforearm, x_axis, 0.610865, 2.181660 * speedMult)
		Turn(rshoulder, x_axis, -0.157080, 13.962633 * speedMult)
		Turn(rshoulder, z_axis, -0.610865, 2.181663 * speedMult)
		Turn(torso, y_axis, 0.174533, 4.363323 * speedMult)
	end
	Sleep(sleepTime)
	while true do
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 6
		Move(base, x_axis, 0.476045, 4.536825 * speedMult)
		Move(base, z_axis, -1.436337, 35.218200 * speedMult)
		Move(base, y_axis, -0.697014, 13.346824 * speedMult)
		Turn(base, x_axis, 0.005783, 0.305052 * speedMult)
		Turn(base, y_axis, -0.007150, 0.508814 * speedMult)
		Turn(footbl, x_axis, -0.108485, 4.497406 * speedMult)
		Turn(footbl, z_axis, -0.318711, 19.936974 * speedMult)
		Turn(footbl, y_axis, 0.036115, 0.034616 * speedMult)
		Turn(footbr, x_axis, -0.034550, 0.235180 * speedMult)
		Turn(footbr, z_axis, 0.312384, 0.528837 * speedMult)
		Turn(footbr, y_axis, -0.011193, 0.050697 * speedMult)
		Turn(footfl, x_axis, 0.012448, 0.876110 * speedMult)
		Turn(footfl, z_axis, 0.443726, 13.880719 * speedMult)
		Turn(footfl, y_axis, 0.005881, 1.697292 * speedMult)
		Turn(footfr, x_axis, 0.017903, 0.489860 * speedMult)
		Turn(footfr, z_axis, 0.717170, 2.349485 * speedMult)
		Turn(footfr, y_axis, 0.015655, 0.422447 * speedMult)
		Turn(legbl, x_axis, 0.319077, 2.449327 * speedMult)
		Turn(legbl, z_axis, -0.341920, 2.776182 * speedMult)
		Turn(legbl, y_axis, 0.082515, 0.148026 * speedMult)
		Turn(legbr, x_axis, 0.028281, 0.723360 * speedMult)
		Turn(legbr, z_axis, 0.054258, 1.209442 * speedMult)
		Turn(legbr, y_axis, -0.004283, 0.442901 * speedMult)
		Turn(legfl, x_axis, 0.009286, 1.633358 * speedMult)
		Turn(legfl, z_axis, -0.047547, 11.256093 * speedMult)
		Turn(legfl, y_axis, -0.010544, 1.068227 * speedMult)
		Turn(legfr, x_axis, -0.052950, 1.012056 * speedMult)
		Turn(legfr, z_axis, -0.211094, 5.962268 * speedMult)
		Turn(legfr, y_axis, 0.011025, 1.225973 * speedMult)
		Turn(thighbl, x_axis, 0.070705, 0.419330 * speedMult)
		Turn(thighbl, z_axis, 0.538806, 3.445096 * speedMult)
		Turn(thighbl, y_axis, 0.584066, 2.966677 * speedMult)
		Turn(thighbr, x_axis, -0.214718, 3.146157 * speedMult)
		Turn(thighbr, z_axis, -0.146044, 0.498995 * speedMult)
		Turn(thighbr, y_axis, -0.481677, 3.435583 * speedMult)
		Turn(thighfl, x_axis, -0.092005, 3.143470 * speedMult)
		Turn(thighfl, z_axis, -0.130482, 1.212544 * speedMult)
		Turn(thighfl, y_axis, -0.809841, 3.232606 * speedMult)
		Turn(thighfr, x_axis, 0.055573, 7.274577 * speedMult)
		Turn(thighfr, z_axis, -0.513642, 5.926828 * speedMult)
		Turn(thighfr, y_axis, 0.568374, 6.607880 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.845437, 0.680679 * speedMult)
			Turn(lshoulder, x_axis, 0.374617, 1.542871 * speedMult)
			Turn(lshoulder, z_axis, 0.654498, 1.090829 * speedMult)
			Turn(rforearm, x_axis, 0.638092, 0.680678 * speedMult)
			Turn(rshoulder, x_axis, -0.095365, 1.542871 * speedMult)
			Turn(rshoulder, z_axis, -0.654498, 1.090832 * speedMult)
			Turn(torso, y_axis, 0.138230, 0.907571 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 9
		Move(base, z_axis, -0.850903, 14.635850 * speedMult)
		Move(base, y_axis, -0.274645, 10.559224 * speedMult)
		Turn(base, x_axis, 0.044665, 0.972055 * speedMult)
		Turn(base, y_axis, -0.024758, 0.440182 * speedMult)
		Turn(footbl, x_axis, -0.090338, 0.453665 * speedMult)
		Turn(footbl, z_axis, -0.569695, 6.274585 * speedMult)
		Turn(footbl, y_axis, 0.057946, 0.545758 * speedMult)
		Turn(footbr, x_axis, -0.005058, 0.737320 * speedMult)
		Turn(footbr, z_axis, 0.039675, 6.817732 * speedMult)
		Turn(footbr, y_axis, -0.000221, 0.274325 * speedMult)
		Turn(footfl, x_axis, 0.007419, 0.125728 * speedMult)
		Turn(footfl, z_axis, -0.006577, 11.257581 * speedMult)
		Turn(footfl, y_axis, -0.000072, 0.148845 * speedMult)
		Turn(footfr, x_axis, 0.008277, 0.240658 * speedMult)
		Turn(footfr, z_axis, 0.475449, 6.043017 * speedMult)
		Turn(footfr, y_axis, 0.004311, 0.283607 * speedMult)
		Turn(legbl, x_axis, 0.213653, 2.635602 * speedMult)
		Turn(legbl, z_axis, -0.209513, 3.310171 * speedMult)
		Turn(legbl, y_axis, 0.056203, 0.657804 * speedMult)
		Turn(legbr, x_axis, 0.011805, 0.411890 * speedMult)
		Turn(legbr, z_axis, 0.040735, 0.338098 * speedMult)
		Turn(legbr, y_axis, -0.007192, 0.072726 * speedMult)
		Turn(legfl, x_axis, -0.014053, 0.583468 * speedMult)
		Turn(legfl, z_axis, 0.060525, 2.701797 * speedMult)
		Turn(legfl, y_axis, -0.007602, 0.073546 * speedMult)
		Turn(legfr, x_axis, -0.039859, 0.327270 * speedMult)
		Turn(legfr, z_axis, -0.293098, 2.050096 * speedMult)
		Turn(legfr, y_axis, 0.027712, 0.417185 * speedMult)
		Turn(thighbl, x_axis, -0.035729, 2.660854 * speedMult)
		Turn(thighbl, z_axis, 0.508184, 0.765552 * speedMult)
		Turn(thighbl, y_axis, 0.495203, 2.221581 * speedMult)
		Turn(thighbr, x_axis, -0.048660, 4.151452 * speedMult)
		Turn(thighbr, z_axis, -0.000819, 3.630632 * speedMult)
		Turn(thighbr, y_axis, -0.651629, 4.248807 * speedMult)
		Turn(thighfl, x_axis, 0.018617, 2.765554 * speedMult)
		Turn(thighfl, z_axis, 0.022315, 3.819913 * speedMult)
		Turn(thighfl, y_axis, -0.673574, 3.406690 * speedMult)
		Turn(thighfr, x_axis, -0.099864, 3.885918 * speedMult)
		Turn(thighfr, z_axis, -0.479205, 0.860917 * speedMult)
		Turn(thighfr, y_axis, 0.807217, 5.971079 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.780511, 1.623157 * speedMult)
			Turn(lshoulder, x_axis, 0.227451, 3.679155 * speedMult)
			Turn(lshoulder, z_axis, 0.698132, 1.090834 * speedMult)
			Turn(rforearm, x_axis, 0.703019, 1.623160 * speedMult)
			Turn(rshoulder, x_axis, 0.051801, 3.679154 * speedMult)
			Turn(rshoulder, z_axis, -0.698132, 1.090831 * speedMult)
			Turn(torso, y_axis, 0.051662, 2.164208 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 12
		Move(base, x_axis, 0.291165, 4.622000 * speedMult)
		Move(base, z_axis, 0.915896, 44.169974 * speedMult)
		Move(base, y_axis, 0.529032, 20.091925 * speedMult)
		Turn(base, x_axis, 0.056245, 0.289489 * speedMult)
		Turn(base, y_axis, -0.032859, 0.202543 * speedMult)
		Turn(footbl, x_axis, -0.024654, 1.642102 * speedMult)
		Turn(footbl, z_axis, -0.592972, 0.581931 * speedMult)
		Turn(footbl, y_axis, 0.016667, 1.031980 * speedMult)
		Turn(footbr, x_axis, 0.017050, 0.552678 * speedMult)
		Turn(footbr, z_axis, -0.654229, 17.347599 * speedMult)
		Turn(footbr, y_axis, -0.013092, 0.321785 * speedMult)
		Turn(footfl, x_axis, -0.024228, 0.791165 * speedMult)
		Turn(footfl, z_axis, -0.187606, 4.525719 * speedMult)
		Turn(footfl, y_axis, 0.004611, 0.117078 * speedMult)
		Turn(footfr, x_axis, -0.000767, 0.226106 * speedMult)
		Turn(footfr, z_axis, 0.105063, 9.259653 * speedMult)
		Turn(footfr, y_axis, -0.000066, 0.109410 * speedMult)
		Turn(legbl, x_axis, 0.080383, 3.331745 * speedMult)
		Turn(legbl, z_axis, -0.016072, 4.836033 * speedMult)
		Turn(legbl, y_axis, -0.003597, 1.494985 * speedMult)
		Turn(legbr, x_axis, 0.018927, 0.178031 * speedMult)
		Turn(legbr, z_axis, 0.225093, 4.608958 * speedMult)
		Turn(legbr, y_axis, -0.015487, 0.207369 * speedMult)
		Turn(legfl, x_axis, -0.039778, 0.643139 * speedMult)
		Turn(legfl, z_axis, -0.016825, 1.933747 * speedMult)
		Turn(legfl, y_axis, 0.030643, 0.956120 * speedMult)
		Turn(legfr, x_axis, -0.000069, 0.994750 * speedMult)
		Turn(legfr, z_axis, -0.187355, 2.643579 * speedMult)
		Turn(legfr, y_axis, 0.014816, 0.322392 * speedMult)
		Turn(thighbl, x_axis, -0.153797, 2.951696 * speedMult)
		Turn(thighbl, z_axis, 0.371347, 3.420915 * speedMult)
		Turn(thighbl, y_axis, 0.435157, 1.501156 * speedMult)
		Turn(thighbr, x_axis, 0.115571, 4.105768 * speedMult)
		Turn(thighbr, z_axis, 0.196543, 4.934042 * speedMult)
		Turn(thighbr, y_axis, -0.795731, 3.602546 * speedMult)
		Turn(thighfl, x_axis, 0.187116, 4.212473 * speedMult)
		Turn(thighfl, z_axis, 0.081706, 1.484771 * speedMult)
		Turn(thighfl, y_axis, -0.470069, 5.087622 * speedMult)
		Turn(thighfr, x_axis, -0.164092, 1.605707 * speedMult)
		Turn(thighfr, z_axis, -0.318228, 4.024430 * speedMult)
		Turn(thighfr, y_axis, 0.928727, 3.037734 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.703018, 1.937318 * speedMult)
			Turn(lshoulder, x_axis, 0.051801, 4.391248 * speedMult)
			Turn(rforearm, x_axis, 0.780511, 1.937315 * speedMult)
			Turn(rshoulder, x_axis, 0.227451, 4.391249 * speedMult)
			Turn(torso, y_axis, -0.051662, 2.583088 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 15
		Move(base, x_axis, -0.004204, 7.384225 * speedMult)
		Move(base, z_axis, 1.411096, 12.379999 * speedMult)
		Turn(base, x_axis, 0.024445, 0.794993 * speedMult)
		Turn(base, y_axis, -0.028345, 0.112860 * speedMult)
		Turn(footbl, x_axis, 0.054989, 1.991092 * speedMult)
		Turn(footbl, z_axis, -0.465073, 3.197468 * speedMult)
		Turn(footbl, y_axis, -0.027713, 1.109483 * speedMult)
		Turn(footbr, x_axis, 0.064704, 1.191354 * speedMult)
		Turn(footbr, z_axis, -1.223605, 14.234400 * speedMult)
		Turn(footbr, y_axis, -0.177410, 4.107961 * speedMult)
		Turn(footfl, x_axis, -0.028227, 0.099963 * speedMult)
		Turn(footfl, z_axis, -0.150457, 0.928723 * speedMult)
		Turn(footfl, y_axis, 0.004289, 0.008040 * speedMult)
		Turn(footfr, x_axis, 0.013011, 0.344463 * speedMult)
		Turn(footfr, z_axis, -0.568719, 16.844544 * speedMult)
		Turn(footfr, y_axis, -0.008354, 0.207201 * speedMult)
		Turn(legbl, x_axis, -0.027001, 2.684604 * speedMult)
		Turn(legbl, z_axis, 0.225706, 6.044428 * speedMult)
		Turn(legbl, y_axis, -0.112953, 2.733902 * speedMult)
		Turn(legbr, x_axis, 0.119533, 2.515165 * speedMult)
		Turn(legbr, z_axis, 1.043663, 20.464249 * speedMult)
		Turn(legbr, y_axis, -0.085605, 1.752950 * speedMult)
		Turn(legfl, x_axis, -0.073271, 0.837317 * speedMult)
		Turn(legfl, z_axis, -0.080050, 1.580613 * speedMult)
		Turn(legfl, y_axis, 0.058892, 0.706228 * speedMult)
		Turn(legfr, x_axis, 0.031994, 0.801571 * speedMult)
		Turn(legfr, z_axis, 0.122803, 7.753951 * speedMult)
		Turn(legfr, y_axis, -0.004436, 0.481309 * speedMult)
		Turn(thighbl, x_axis, -0.268561, 2.869112 * speedMult)
		Turn(thighbl, z_axis, 0.087772, 7.089388 * speedMult)
		Turn(thighbl, y_axis, 0.388999, 1.153954 * speedMult)
		Turn(thighbr, x_axis, 0.180914, 1.633589 * speedMult)
		Turn(thighbr, z_axis, -0.276630, 11.829337 * speedMult)
		Turn(thighbr, y_axis, -0.865271, 1.738496 * speedMult)
		Turn(thighfl, x_axis, 0.420630, 5.837843 * speedMult)
		Turn(thighfl, z_axis, 0.006511, 1.879866 * speedMult)
		Turn(thighfl, y_axis, -0.265003, 5.126660 * speedMult)
		Turn(thighfr, x_axis, -0.228544, 1.611284 * speedMult)
		Turn(thighfr, z_axis, -0.060247, 6.449534 * speedMult)
		Turn(thighfr, y_axis, 0.977411, 1.217107 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.638092, 1.623155 * speedMult)
			Turn(lshoulder, x_axis, -0.095365, 3.679154 * speedMult)
			Turn(lshoulder, z_axis, 0.654498, 1.090832 * speedMult)
			Turn(rforearm, x_axis, 0.845438, 1.623158 * speedMult)
			Turn(rshoulder, x_axis, 0.374617, 3.679154 * speedMult)
			Turn(rshoulder, z_axis, -0.654498, 1.090834 * speedMult)
			Turn(torso, y_axis, -0.138230, 2.164208 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 18
		Move(base, x_axis, -0.297958, 7.343850 * speedMult)
		Move(base, z_axis, -0.052822, 36.597949 * speedMult)
		Move(base, y_axis, -0.163141, 17.304325 * speedMult)
		Turn(base, x_axis, -0.006584, 0.775734 * speedMult)
		Turn(base, y_axis, -0.012948, 0.384932 * speedMult)
		Turn(footbl, x_axis, 0.070153, 0.379086 * speedMult)
		Turn(footbl, z_axis, -0.292957, 4.302903 * speedMult)
		Turn(footbl, y_axis, -0.021408, 0.157617 * speedMult)
		Turn(footbr, x_axis, 0.010421, 1.357058 * speedMult)
		Turn(footbr, z_axis, -0.473230, 18.759369 * speedMult)
		Turn(footbr, y_axis, -0.005283, 4.303195 * speedMult)
		Turn(footfl, x_axis, -0.001787, 0.660979 * speedMult)
		Turn(footfl, z_axis, -0.624450, 11.849837 * speedMult)
		Turn(footfl, y_axis, 0.001316, 0.074317 * speedMult)
		Turn(footfr, x_axis, 0.045835, 0.820595 * speedMult)
		Turn(footfr, z_axis, -1.001944, 10.830635 * speedMult)
		Turn(footfr, y_axis, -0.071682, 1.583193 * speedMult)
		Turn(legbl, x_axis, -0.025145, 0.046410 * speedMult)
		Turn(legbl, z_axis, 0.312607, 2.172526 * speedMult)
		Turn(legbl, y_axis, -0.187116, 1.854084 * speedMult)
		Turn(legbr, x_axis, 0.004199, 2.883344 * speedMult)
		Turn(legbr, z_axis, -0.010523, 26.354636 * speedMult)
		Turn(legbr, y_axis, 0.015191, 2.519883 * speedMult)
		Turn(legfl, x_axis, -0.011395, 1.546899 * speedMult)
		Turn(legfl, z_axis, -0.028411, 1.290974 * speedMult)
		Turn(legfl, y_axis, 0.038074, 0.520455 * speedMult)
		Turn(legfr, x_axis, 0.072050, 1.001408 * speedMult)
		Turn(legfr, z_axis, 0.494071, 9.281692 * speedMult)
		Turn(legfr, y_axis, -0.030961, 0.663131 * speedMult)
		Turn(thighbl, x_axis, -0.270869, 0.057694 * speedMult)
		Turn(thighbl, z_axis, -0.124787, 5.313953 * speedMult)
		Turn(thighbl, y_axis, 0.365403, 0.589899 * speedMult)
		Turn(thighbr, x_axis, 0.209399, 0.712125 * speedMult)
		Turn(thighbr, z_axis, -0.225499, 1.278282 * speedMult)
		Turn(thighbr, y_axis, -0.935237, 1.749140 * speedMult)
		Turn(thighfl, x_axis, 0.345621, 1.875215 * speedMult)
		Turn(thighfl, z_axis, 0.276769, 6.756445 * speedMult)
		Turn(thighfl, y_axis, -0.305726, 1.018083 * speedMult)
		Turn(thighfr, x_axis, -0.219518, 0.225637 * speedMult)
		Turn(thighfr, z_axis, 0.075789, 3.400890 * speedMult)
		Turn(thighfr, y_axis, 0.940364, 0.926176 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.610865, 0.680678 * speedMult)
			Turn(lshoulder, x_axis, -0.157080, 1.542871 * speedMult)
			Turn(lshoulder, z_axis, 0.610865, 1.090832 * speedMult)
			Turn(rforearm, x_axis, 0.872665, 0.680681 * speedMult)
			Turn(rshoulder, x_axis, 0.436332, 1.542871 * speedMult)
			Turn(rshoulder, z_axis, -0.610865, 1.090829 * speedMult)
			Turn(torso, y_axis, -0.174533, 0.907571 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 21
		Move(base, x_axis, -0.477314, 4.483900 * speedMult)
		Move(base, z_axis, -1.443403, 34.764525 * speedMult)
		Move(base, y_axis, -0.698002, 13.371525 * speedMult)
		Turn(base, x_axis, 0.006237, 0.320527 * speedMult)
		Turn(base, y_axis, 0.007421, 0.509210 * speedMult)
		Turn(footbl, x_axis, 0.028165, 1.049700 * speedMult)
		Turn(footbl, z_axis, -0.312183, 0.480659 * speedMult)
		Turn(footbl, y_axis, -0.009234, 0.304349 * speedMult)
		Turn(footbr, x_axis, 0.003814, 0.165180 * speedMult)
		Turn(footbr, z_axis, 0.317190, 19.760502 * speedMult)
		Turn(footbr, y_axis, 0.001280, 0.164069 * speedMult)
		Turn(footfl, x_axis, 0.017748, 0.488394 * speedMult)
		Turn(footfl, z_axis, -0.717314, 2.321586 * speedMult)
		Turn(footfl, y_axis, -0.015524, 0.421003 * speedMult)
		Turn(footfr, x_axis, 0.012493, 0.833562 * speedMult)
		Turn(footfr, z_axis, -0.444328, 13.940392 * speedMult)
		Turn(footfr, y_axis, -0.005912, 1.644226 * speedMult)
		Turn(legbl, x_axis, -0.082235, 1.427270 * speedMult)
		Turn(legbl, z_axis, 0.235484, 1.928058 * speedMult)
		Turn(legbl, y_axis, -0.090477, 2.415986 * speedMult)
		Turn(legbr, x_axis, -0.021814, 0.650333 * speedMult)
		Turn(legbr, z_axis, -0.239973, 5.736270 * speedMult)
		Turn(legbr, y_axis, 0.015934, 0.018596 * speedMult)
		Turn(legfl, x_axis, -0.052455, 1.026512 * speedMult)
		Turn(legfl, z_axis, 0.210447, 5.971452 * speedMult)
		Turn(legfl, y_axis, -0.010729, 1.220054 * speedMult)
		Turn(legfr, x_axis, 0.009356, 1.567356 * speedMult)
		Turn(legfr, z_axis, 0.048083, 11.149703 * speedMult)
		Turn(legfr, y_axis, 0.010256, 1.030423 * speedMult)
		Turn(thighbl, x_axis, -0.177022, 2.346177 * speedMult)
		Turn(thighbl, z_axis, 0.021609, 3.659896 * speedMult)
		Turn(thighbl, y_axis, 0.555883, 4.762021 * speedMult)
		Turn(thighbr, x_axis, 0.066671, 3.568199 * speedMult)
		Turn(thighbr, z_axis, -0.384342, 3.971067 * speedMult)
		Turn(thighbr, y_axis, -0.791890, 3.583655 * speedMult)
		Turn(thighfl, x_axis, 0.054876, 7.268636 * speedMult)
		Turn(thighfl, z_axis, 0.514070, 5.932538 * speedMult)
		Turn(thighfl, y_axis, -0.569405, 6.591979 * speedMult)
		Turn(thighfr, x_axis, -0.092203, 3.182877 * speedMult)
		Turn(thighfr, z_axis, 0.129552, 1.344077 * speedMult)
		Turn(thighfr, y_axis, 0.809873, 3.262272 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.638092, 0.680678 * speedMult)
			Turn(lshoulder, x_axis, -0.095365, 1.542871 * speedMult)
			Turn(lshoulder, z_axis, 0.654498, 1.090832 * speedMult)
			Turn(rforearm, x_axis, 0.845438, 0.680681 * speedMult)
			Turn(rshoulder, x_axis, 0.372802, 1.588250 * speedMult)
			Turn(rshoulder, z_axis, -0.654499, 1.090834 * speedMult)
			Turn(torso, y_axis, -0.138230, 0.907571 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 24
		Move(base, z_axis, -0.830013, 15.334751 * speedMult)
		Move(base, y_axis, -0.263781, 10.855524 * speedMult)
		Turn(base, x_axis, 0.045108, 0.971780 * speedMult)
		Turn(base, y_axis, 0.024940, 0.437981 * speedMult)
		Turn(footbl, x_axis, 0.001051, 0.677834 * speedMult)
		Turn(footbl, z_axis, -0.036944, 6.880976 * speedMult)
		Turn(footbl, y_axis, -0.000067, 0.229171 * speedMult)
		Turn(footbr, x_axis, 0.004154, 0.008495 * speedMult)
		Turn(footbr, z_axis, 0.565224, 6.200843 * speedMult)
		Turn(footbr, y_axis, 0.002662, 0.034552 * speedMult)
		Turn(footfl, x_axis, 0.008520, 0.230704 * speedMult)
		Turn(footfl, z_axis, -0.476305, 6.025211 * speedMult)
		Turn(footfl, y_axis, -0.004446, 0.276944 * speedMult)
		Turn(footfr, x_axis, 0.007488, 0.125129 * speedMult)
		Turn(footfr, z_axis, 0.007082, 11.285263 * speedMult)
		Turn(footfr, y_axis, 0.000078, 0.149754 * speedMult)
		Turn(legbl, x_axis, -0.020382, 1.546330 * speedMult)
		Turn(legbl, z_axis, 0.030547, 5.123440 * speedMult)
		Turn(legbl, y_axis, -0.012657, 1.945486 * speedMult)
		Turn(legbr, x_axis, 0.001247, 0.576524 * speedMult)
		Turn(legbr, z_axis, -0.193497, 1.161899 * speedMult)
		Turn(legbr, y_axis, 0.026434, 0.262499 * speedMult)
		Turn(legfl, x_axis, -0.040538, 0.297944 * speedMult)
		Turn(legfl, z_axis, 0.294659, 2.105287 * speedMult)
		Turn(legfl, y_axis, -0.028328, 0.439981 * speedMult)
		Turn(legfr, x_axis, -0.014771, 0.603169 * speedMult)
		Turn(legfr, z_axis, -0.061945, 2.750697 * speedMult)
		Turn(legfr, y_axis, 0.008022, 0.055848 * speedMult)
		Turn(thighbl, x_axis, -0.034894, 3.553200 * speedMult)
		Turn(thighbl, z_axis, -0.033159, 1.369212 * speedMult)
		Turn(thighbl, y_axis, 0.674662, 2.969462 * speedMult)
		Turn(thighbr, x_axis, -0.047804, 2.861874 * speedMult)
		Turn(thighbr, z_axis, -0.431259, 1.172939 * speedMult)
		Turn(thighbr, y_axis, -0.603172, 4.717958 * speedMult)
		Turn(thighfl, x_axis, -0.099640, 3.862904 * speedMult)
		Turn(thighfl, z_axis, 0.479106, 0.874107 * speedMult)
		Turn(thighfl, y_axis, -0.806632, 5.930683 * speedMult)
		Turn(thighfr, x_axis, 0.019330, 2.788329 * speedMult)
		Turn(thighfr, z_axis, -0.021580, 3.778292 * speedMult)
		Turn(thighfr, y_axis, 0.672596, 3.431927 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.703019, 1.623160 * speedMult)
			Turn(lshoulder, x_axis, 0.051801, 3.679154 * speedMult)
			Turn(lshoulder, z_axis, 0.698132, 1.090832 * speedMult)
			Turn(rforearm, x_axis, 0.780511, 1.623158 * speedMult)
			Turn(rshoulder, x_axis, 0.221308, 3.787366 * speedMult)
			Turn(rshoulder, z_axis, -0.698132, 1.090829 * speedMult)
			Turn(torso, y_axis, -0.051662, 2.164208 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 27
		Move(base, x_axis, -0.287738, 4.739400 * speedMult)
		Move(base, z_axis, 0.935739, 44.143799 * speedMult)
		Move(base, y_axis, 0.536665, 20.011151 * speedMult)
		Turn(base, x_axis, 0.056062, 0.273846 * speedMult)
		Turn(base, y_axis, 0.032884, 0.198590 * speedMult)
		Turn(footbl, x_axis, 0.077918, 1.921674 * speedMult)
		Turn(footbl, z_axis, 0.660249, 17.429843 * speedMult)
		Turn(footbl, y_axis, 0.060634, 1.517543 * speedMult)
		Turn(footbr, x_axis, 0.000673, 0.087021 * speedMult)
		Turn(footbr, z_axis, 0.592014, 0.669758 * speedMult)
		Turn(footbr, y_axis, 0.000463, 0.054986 * speedMult)
		Turn(footfl, x_axis, -0.000649, 0.229226 * speedMult)
		Turn(footfl, z_axis, -0.106265, 9.251011 * speedMult)
		Turn(footfl, y_axis, 0.000053, 0.112475 * speedMult)
		Turn(footfr, x_axis, -0.024034, 0.788050 * speedMult)
		Turn(footfr, z_axis, 0.187159, 4.501914 * speedMult)
		Turn(footfr, y_axis, -0.004562, 0.115984 * speedMult)
		Turn(legbl, x_axis, 0.135500, 3.897065 * speedMult)
		Turn(legbl, z_axis, -0.471970, 12.562911 * speedMult)
		Turn(legbl, y_axis, 0.063923, 1.914513 * speedMult)
		Turn(legbr, x_axis, 0.033588, 0.808525 * speedMult)
		Turn(legbr, z_axis, -0.090447, 2.576261 * speedMult)
		Turn(legbr, y_axis, 0.031834, 0.134997 * speedMult)
		Turn(legfl, x_axis, -0.000738, 0.994979 * speedMult)
		Turn(legfl, z_axis, 0.189089, 2.639238 * speedMult)
		Turn(legfl, y_axis, -0.015469, 0.321462 * speedMult)
		Turn(legfr, x_axis, -0.040560, 0.644719 * speedMult)
		Turn(legfr, z_axis, 0.015433, 1.934449 * speedMult)
		Turn(legfr, y_axis, -0.030033, 0.951369 * speedMult)
		Turn(thighbl, x_axis, 0.033258, 1.703794 * speedMult)
		Turn(thighbl, z_axis, -0.030311, 0.071194 * speedMult)
		Turn(thighbl, y_axis, 0.704629, 0.749189 * speedMult)
		Turn(thighbr, x_axis, -0.152709, 2.622631 * speedMult)
		Turn(thighbr, z_axis, -0.352146, 1.977827 * speedMult)
		Turn(thighbr, y_axis, -0.457124, 3.651191 * speedMult)
		Turn(thighfl, x_axis, -0.163440, 1.595001 * speedMult)
		Turn(thighfl, z_axis, 0.317244, 4.046556 * speedMult)
		Turn(thighfl, y_axis, -0.927609, 3.024414 * speedMult)
		Turn(thighfr, x_axis, 0.188042, 4.217799 * speedMult)
		Turn(thighfr, z_axis, -0.080526, 1.473655 * speedMult)
		Turn(thighfr, y_axis, 0.469337, 5.081479 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.780511, 1.937316 * speedMult)
			Turn(lshoulder, x_axis, 0.227451, 4.391249 * speedMult)
			Turn(rforearm, x_axis, 0.703019, 1.937313 * speedMult)
			Turn(rshoulder, x_axis, 0.040492, 4.520403 * speedMult)
			Turn(torso, y_axis, 0.051662, 2.583088 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 30
		Move(base, x_axis, 0.008407, 7.403625 * speedMult)
		Move(base, z_axis, 1.402343, 11.665101 * speedMult)
		Turn(base, x_axis, 0.023890, 0.804287 * speedMult)
		Turn(base, y_axis, 0.028202, 0.117048 * speedMult)
		Turn(footbl, x_axis, 0.047621, 0.757424 * speedMult)
		Turn(footbl, z_axis, 1.218337, 13.952193 * speedMult)
		Turn(footbl, y_axis, 0.129098, 1.711593 * speedMult)
		Turn(footbr, x_axis, -0.006032, 0.167639 * speedMult)
		Turn(footbr, z_axis, 0.465478, 3.163406 * speedMult)
		Turn(footbr, y_axis, -0.003053, 0.087899 * speedMult)
		Turn(footfl, x_axis, 0.013135, 0.344606 * speedMult)
		Turn(footfl, z_axis, 0.569716, 16.899518 * speedMult)
		Turn(footfl, y_axis, 0.008451, 0.209959 * speedMult)
		Turn(footfr, x_axis, -0.028058, 0.100594 * speedMult)
		Turn(footfr, z_axis, 0.151167, 0.899789 * speedMult)
		Turn(footfr, y_axis, -0.004284, 0.006941 * speedMult)
		Turn(legbl, x_axis, 0.089028, 1.161802 * speedMult)
		Turn(legbl, z_axis, -0.985975, 12.850133 * speedMult)
		Turn(legbl, y_axis, 0.071874, 0.198770 * speedMult)
		Turn(legbr, x_axis, 0.061489, 0.697529 * speedMult)
		Turn(legbr, z_axis, 0.040288, 3.268365 * speedMult)
		Turn(legbr, y_axis, 0.025103, 0.168271 * speedMult)
		Turn(legfl, x_axis, 0.032083, 0.820540 * speedMult)
		Turn(legfl, z_axis, -0.123588, 7.816936 * speedMult)
		Turn(legfl, y_axis, 0.004511, 0.499508 * speedMult)
		Turn(legfr, x_axis, -0.072833, 0.806825 * speedMult)
		Turn(legfr, z_axis, 0.080130, 1.617416 * speedMult)
		Turn(legfr, y_axis, -0.058653, 0.715491 * speedMult)
		Turn(thighbl, x_axis, 0.197036, 4.094459 * speedMult)
		Turn(thighbl, z_axis, 0.239435, 6.743670 * speedMult)
		Turn(thighbl, y_axis, 0.898921, 4.857278 * speedMult)
		Turn(thighbr, x_axis, -0.285602, 3.322334 * speedMult)
		Turn(thighbr, z_axis, -0.156812, 4.883361 * speedMult)
		Turn(thighbr, y_axis, -0.351952, 2.629314 * speedMult)
		Turn(thighfl, x_axis, -0.228235, 1.619870 * speedMult)
		Turn(thighfl, z_axis, 0.059501, 6.443574 * speedMult)
		Turn(thighfl, y_axis, -0.976970, 1.234031 * speedMult)
		Turn(thighfr, x_axis, 0.420650, 5.815215 * speedMult)
		Turn(thighfr, z_axis, -0.005895, 1.865756 * speedMult)
		Turn(thighfr, y_axis, 0.265654, 5.092078 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.845438, 1.623155 * speedMult)
			Turn(lshoulder, x_axis, 0.374617, 3.679154 * speedMult)
			Turn(lshoulder, z_axis, 0.654498, 1.090831 * speedMult)
			Turn(rforearm, x_axis, 0.638093, 1.623155 * speedMult)
			Turn(rshoulder, x_axis, -0.111003, 3.787364 * speedMult)
			Turn(rshoulder, z_axis, -0.654498, 1.090835 * speedMult)
			Turn(torso, y_axis, 0.138230, 2.164208 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 3 (loop)
		Move(base, x_axis, 0.294572, 7.154125 * speedMult)
		Move(base, y_axis, -0.163141, 17.495150 * speedMult)
		Move(base, z_axis, -0.027609, 35.748800 * speedMult)
		Turn(base, x_axis, -0.006419, 0.757725 * speedMult)
		Turn(base, y_axis, 0.013202, 0.375000 * speedMult)
		Turn(footbl, x_axis, 0.071411, 0.594750 * speedMult)
		Turn(footbl, y_axis, 0.037500, 2.289950 * speedMult)
		Turn(footbl, z_axis, 0.478768, 18.489225 * speedMult)
		Turn(footbr, x_axis, -0.043958, 0.948150 * speedMult)
		Turn(footbr, y_axis, -0.013221, 0.254200 * speedMult)
		Turn(footbr, z_axis, 0.291231, 4.356175 * speedMult)
		Turn(footfl, x_axis, 0.047492, 0.858925 * speedMult)
		Turn(footfl, y_axis, 0.073773, 1.633050 * speedMult)
		Turn(footfl, z_axis, 0.998955, 10.730975 * speedMult)
		Turn(footfr, x_axis, -0.001691, 0.659175 * speedMult)
		Turn(footfr, y_axis, -0.001243, 0.076025 * speedMult)
		Turn(footfr, z_axis, 0.623191, 11.800600 * speedMult)
		Turn(legbl, x_axis, 0.221104, 3.301900 * speedMult)
		Turn(legbl, y_axis, 0.088436, 0.414050 * speedMult)
		Turn(legbl, z_axis, -0.452967, 13.325200 * speedMult)
		Turn(legbr, x_axis, 0.057215, 0.106850 * speedMult)
		Turn(legbr, y_axis, 0.013433, 0.291750 * speedMult)
		Turn(legbr, z_axis, 0.102636, 1.558700 * speedMult)
		Turn(legfl, x_axis, 0.074620, 1.063425 * speedMult)
		Turn(legfl, y_axis, 0.032185, 0.691850 * speedMult)
		Turn(legfl, z_axis, -0.497791, 9.355075 * speedMult)
		Turn(legfr, x_axis, -0.012468, 1.509125 * speedMult)
		Turn(legfr, y_axis, -0.038014, 0.515975 * speedMult)
		Turn(legfr, z_axis, 0.027397, 1.318325 * speedMult)
		Turn(thighbl, x_axis, 0.087478, 2.738950 * speedMult)
		Turn(thighbl, y_axis, 0.702733, 4.904700 * speedMult)
		Turn(thighbl, z_axis, 0.401002, 4.039175 * speedMult)
		Turn(thighbr, x_axis, -0.340564, 1.374050 * speedMult)
		Turn(thighbr, y_axis, -0.344254, 0.192450 * speedMult)
		Turn(thighbr, z_axis, -0.126084, 0.768200 * speedMult)
		Turn(thighfl, x_axis, -0.217744, 0.262275 * speedMult)
		Turn(thighfl, y_axis, -0.939146, 0.945600 * speedMult)
		Turn(thighfl, z_axis, -0.081980, 3.537025 * speedMult)
		Turn(thighfr, x_axis, 0.346556, 1.852350 * speedMult)
		Turn(thighfr, y_axis, 0.304059, 0.960125 * speedMult)
		Turn(thighfr, z_axis, -0.276569, 6.766850 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.872665, 0.680675 * speedMult)
			Turn(lshoulder, x_axis, 0.436332, 1.542875 * speedMult)
			Turn(lshoulder, z_axis, 0.610865, 1.090825 * speedMult)
			Turn(rforearm, x_axis, 0.610865, 0.680700 * speedMult)
			Turn(rshoulder, x_axis, -0.157080, 1.151925 * speedMult)
			Turn(rshoulder, z_axis, -0.610865, 1.090825 * speedMult)
			Turn(torso, y_axis, 0.174533, 0.907575 * speedMult)
		end
		Sleep(sleepTime)
	end
end

local function StopWalking()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)

	local speedMult = 15 / (EXPORT_FPS * ANIM_FRAMES)

	Move(base, x_axis, 0.000000, 24.678750 * speedMult)
	Move(base, y_axis, 0.000000, 66.973083 * speedMult)
	Move(base, z_axis, 0.000000, 147.233248 * speedMult)
	Turn(base, x_axis, 0.000000, 3.240182 * speedMult)
	Turn(base, y_axis, 0.000000, 1.697368 * speedMult)
	Turn(footbl, x_axis, 0.000000, 14.991354 * speedMult)
	Turn(footbl, y_axis, 0.000000, 5.705310 * speedMult)
	Turn(footbl, z_axis, 0.000000, 66.456581 * speedMult)
	Turn(footbr, x_axis, 0.000000, 4.523525 * speedMult)
	Turn(footbr, y_axis, 0.000000, 14.343983 * speedMult)
	Turn(footbr, z_axis, 0.000000, 65.868340 * speedMult)
	Turn(footfl, x_axis, 0.000000, 3.957670 * speedMult)
	Turn(footfl, y_axis, 0.000000, 6.147758 * speedMult)
	Turn(footfl, z_axis, 0.000000, 83.246256 * speedMult)
	Turn(footfr, x_axis, 0.000000, 2.778540 * speedMult)
	Turn(footfr, y_axis, 0.000000, 5.480753 * speedMult)
	Turn(footfr, z_axis, 0.000000, 56.148480 * speedMult)
	Turn(legbl, x_axis, 0.000000, 18.425335 * speedMult)
	Turn(legbl, y_axis, 0.000000, 9.113008 * speedMult)
	Turn(legbl, z_axis, 0.000000, 42.833778 * speedMult)
	Turn(legbr, x_axis, 0.000000, 9.611148 * speedMult)
	Turn(legbr, y_axis, 0.000000, 8.399610 * speedMult)
	Turn(legbr, z_axis, 0.000000, 87.848788 * speedMult)
	Turn(legfl, x_axis, 0.000000, 6.218370 * speedMult)
	Turn(legfl, y_axis, 0.000000, 4.066846 * speedMult)
	Turn(legfl, z_axis, 0.000000, 41.482563 * speedMult)
	Turn(legfr, x_axis, 0.000000, 5.224521 * speedMult)
	Turn(legfr, y_axis, 0.000000, 4.086577 * speedMult)
	Turn(legfr, z_axis, 0.000000, 37.165676 * speedMult)
	Turn(thighbl, x_axis, 0.000000, 13.648197 * speedMult)
	Turn(thighbl, y_axis, 0.785398, 16.190926 * speedMult)
	Turn(thighbl, z_axis, 0.000000, 33.416829 * speedMult)
	Turn(thighbr, x_axis, 0.000000, 28.380361 * speedMult)
	Turn(thighbr, y_axis, -0.785398, 36.762026 * speedMult)
	Turn(thighbr, z_axis, 0.000000, 39.431122 * speedMult)
	Turn(thighfl, x_axis, 0.000000, 24.228786 * speedMult)
	Turn(thighfl, y_axis, -0.785398, 21.973265 * speedMult)
	Turn(thighfl, z_axis, 0.000000, 22.521484 * speedMult)
	Turn(thighfr, x_axis, 0.000000, 28.879634 * speedMult)
	Turn(thighfr, y_axis, 0.785398, 40.111601 * speedMult)
	Turn(thighfr, z_axis, 0.000000, 23.047391 * speedMult)
	if not isAiming then
		Turn(lforearm, x_axis, 0.698132, 14.544417 * speedMult)
		Turn(lshoulder, x_axis, 0.401426, 14.637495 * speedMult)
		Turn(lshoulder, z_axis, 0.698132, 7.272209 * speedMult)
		Turn(rforearm, x_axis, 0.698132, 7.272199 * speedMult)
		Turn(rshoulder, x_axis, 0.401426, 46.542111 * speedMult)
		Turn(rshoulder, z_axis, -0.698132, 7.272209 * speedMult)
		Turn(torso, y_axis, 0.000000, 14.544410 * speedMult)
	end
end


local function PoseArms()
	Turn(torso, y_axis, 0, POSE_SPEED)
	Turn(lforearm, x_axis, 0.872665, POSE_SPEED)
	Turn(rforearm, x_axis, 0.872665, POSE_SPEED)
	Turn(lhand, x_axis, 0.253073, POSE_SPEED)
	Turn(rhand, x_axis, 0.253073, POSE_SPEED)
	Turn(lhand, y_axis, -0.031416, POSE_SPEED)
	Turn(rhand, y_axis, 0.031416, POSE_SPEED)
	Turn(lshoulder, x_axis, -0.261799, POSE_SPEED)
	Turn(rshoulder, x_axis, -0.261799, POSE_SPEED)
	Turn(lshoulder, z_axis, 1.466077, POSE_SPEED)
	Turn(rshoulder, z_axis, -1.466077, POSE_SPEED)
	Turn(lshoulder, y_axis, -1.186824, POSE_SPEED)
	Turn(rshoulder, y_axis, 1.186824, POSE_SPEED)
	Turn(lwrist, x_axis, 0.052360, POSE_SPEED)
	Turn(rwrist, x_axis, 0.052360, POSE_SPEED)
end

local function RestArms()
	Turn(lforearm, x_axis, 0.698132, POSE_SPEED / 2)
	Turn(lshoulder, x_axis, 0.401426, POSE_SPEED / 2)
	Turn(lshoulder, z_axis, 0.698132, POSE_SPEED / 2)
	Turn(rforearm, x_axis, 0.698132, POSE_SPEED / 2)
	Turn(rshoulder, x_axis, 0.401426, POSE_SPEED / 2)
	Turn(rshoulder, z_axis, -0.698132, POSE_SPEED / 2)
	Turn(lhand, x_axis, 0, POSE_SPEED / 2)
	Turn(rhand, x_axis, 0, POSE_SPEED / 2)
	Turn(lhand, y_axis, 0, POSE_SPEED / 2)
	Turn(rhand, y_axis, 0, POSE_SPEED / 2)
	Turn(lshoulder, y_axis, 0, POSE_SPEED / 2)
	Turn(rshoulder, y_axis, 0, POSE_SPEED / 2)
	Turn(lwrist, x_axis, 0, POSE_SPEED / 2)
	Turn(rwrist, x_axis, 0, POSE_SPEED / 2)
end

local function AimController()
	local lastHull = GetUnitHeading(unitID) * HEADING_TO_RAD
	while true do
		local frame = GetGameFrame()
		local hull = GetUnitHeading(unitID) * HEADING_TO_RAD
		local hullDelta = wrap(hull - lastHull)
		lastHull = hull
		if not GetUnitIsStunned(unitID) then
			if frame - lastAimFrame > RATE_FRAMES then
				goalRate = 0
			end
			if isAiming and frame - lastAimFrame > RESTORE_FRAMES then
				isAiming = false
				RestArms()
			end
			if isAiming then
				goalYaw = wrap(goalYaw - hullDelta + goalRate)
				lastAimHeading = wrap(lastAimHeading - hullDelta)
				beliefYaw = stepToward(wrap(beliefYaw - hullDelta), goalYaw, YAW_SPEED / Game.gameSpeed)
			else
				goalYaw = 0
				beliefYaw = stepToward(beliefYaw, 0, RESTORE_SPEED / Game.gameSpeed)
			end
			Turn(aimy, y_axis, beliefYaw)
			if handShots[nextHand] > 0 and frame - handShotFrame > STALL_FRAMES then
				handShots[nextHand] = 0
				nextHand = 3 - nextHand
				lastHandFrame = frame
			end
			for i = 1, 2 do
				if frame - lastPitchFrame[i] > RATE_FRAMES then
					pitchRate[i] = 0
				end
				if isAiming then
					goalPitch[i] = goalPitch[i] + pitchRate[i]
					pitchBelief[i] = stepToward(pitchBelief[i], goalPitch[i], PITCH_SPEED / Game.gameSpeed)
				else
					goalPitch[i] = 0
					pitchBelief[i] = stepToward(pitchBelief[i], 0, RESTORE_PITCH_SPEED / Game.gameSpeed)
				end
				Turn(aimx[i], x_axis, -math.min(pitchBelief[i], PITCH_SPLIT))
				if isAiming then
					local extra = HAND_PITCH_SIGN * math.max(0, pitchBelief[i] - PITCH_SPLIT)
					local mirror = (i == 1) and 1 or -1
					Turn(hands[i], x_axis, HAND_POSE_X + HAND_AXIS_X * extra, PITCH_SPEED)
					Turn(hands[i], y_axis, mirror * (HAND_POSE_Y + HAND_AXIS_Y * extra), PITCH_SPEED)
				else
					Turn(aimx[i], y_axis, 0, RESTORE_SPEED)
				end
			end
		end
		Sleep(33)
	end
end

function script.StartMoving()
	if not walking then
		walking = true
		StartThread(Walk)
	end
end

function script.StopMoving()
	walking = false
	StartThread(StopWalking)
end

function script.Create()
	local _, _, z = Spring.GetUnitPiecePosition(unitID, aimy)
	pivotZ = z
	StartThread(StopWalking)
	StartThread(AimController)
end

function script.AimFromWeapon(num)
	if num == LIGHTNING then
		return base
	end
	return torso
end

function script.QueryWeapon(num)
	if num == LIGHTNING then
		return tubes[tubeSide]
	end
	return flares[weaponHand[num]][weaponFlare[num]]
end

function script.AimWeapon(num, heading, pitch)
	if num == LIGHTNING then
		return true
	end
	local hand = weaponHand[num]
	local frame = GetGameFrame()
	local frames = frame - lastAimFrame
	if frames > 0 then
		goalRate = 0
		if frames <= RATE_FRAMES then
			goalRate = wrap(heading - lastAimHeading) / frames
			if math.abs(goalRate) > YAW_SPEED / Game.gameSpeed then
				goalRate = 0
			end
		end
		lastAimHeading = heading
		lastAimFrame = frame
	end
	frames = frame - lastPitchFrame[hand]
	if frames > 0 then
		pitchRate[hand] = 0
		if frames <= RATE_FRAMES then
			pitchRate[hand] = (pitch - lastAimPitch[hand]) / frames
			if math.abs(pitchRate[hand]) > PITCH_SPEED / Game.gameSpeed then
				pitchRate[hand] = 0
			end
		end
		lastAimPitch[hand] = pitch
		lastPitchFrame[hand] = frame
	end
	if not isAiming then
		isAiming = true
		PoseArms()
	end
	goalYaw = heading
	goalPitch[hand] = pitch
	Turn(aimx[hand], y_axis, ToeIn(num, hand), YAW_SPEED)
	if hand ~= nextHand or frame - lastHandFrame < HAND_GAP then
		return false
	end
	return math.abs(wrap(heading - beliefYaw)) <= FIRE_ANGLE and math.abs(pitch - pitchBelief[hand]) <= FIRE_ANGLE_PITCH
end

function script.FireWeapon(num)
	if num == LIGHTNING then
		tubeSide = 3 - tubeSide
		return
	end
	local hand, side = weaponHand[num], weaponFlare[num]
	local frame = GetGameFrame()
	handShots[hand] = handShots[hand] + 1
	handShotFrame = frame
	if handShots[hand] >= 2 then
		handShots[hand] = 0
		nextHand = 3 - hand
		lastHandFrame = frame
	end
	if side == 1 then
		EmitSfx(flares[hand][side], SFX.CEG)
	end
	Move(barrels[hand][side], z_axis, -RECOIL, RECOIL * Game.gameSpeed)
	Sleep(33)
	Move(barrels[hand][side], z_axis, 0, RECOIL * 4)
end

function script.Killed(recentDamage, maxHealth)
	return 1
end
