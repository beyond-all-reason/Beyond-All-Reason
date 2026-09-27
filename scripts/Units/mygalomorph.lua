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
	Move(base, y_axis, -0.151672, 3.791800 * speedMult)
	Turn(base, x_axis, -0.006419, 0.160474 * speedMult)
	Turn(base, y_axis, 0.013202, 0.330057 * speedMult)
	Turn(footbl, x_axis, 0.078093, 1.952335 * speedMult)
	Turn(footbl, z_axis, 0.479028, 11.975701 * speedMult)
	Turn(footbl, y_axis, 0.040885, 1.022114 * speedMult)
	Turn(footbr, x_axis, -0.040087, 1.002185 * speedMult)
	Turn(footbr, z_axis, 0.291183, 7.279570 * speedMult)
	Turn(footbr, y_axis, -0.012081, 0.302031 * speedMult)
	Turn(footfl, x_axis, 0.009558, 1.048452 * speedMult)
	Turn(footfl, z_axis, 0.996329, 24.908219 * speedMult)
	Turn(footfl, y_axis, 0.068858, 1.721461 * speedMult)
	Turn(footfr, x_axis, 0.030997, 0.774917 * speedMult)
	Turn(footfr, z_axis, 0.623534, 15.588351 * speedMult)
	Turn(footfr, y_axis, 0.022250, 0.556249 * speedMult)
	Turn(legbl, x_axis, 0.231822, 5.795542 * speedMult)
	Turn(legbl, z_axis, -0.423049, 10.576222 * speedMult)
	Turn(legbl, y_axis, 0.056553, 1.413820 * speedMult)
	Turn(legbr, x_axis, 0.159218, 3.980437 * speedMult)
	Turn(legbr, z_axis, 0.145618, 3.640445 * speedMult)
	Turn(legbr, y_axis, 0.073770, 1.844259 * speedMult)
	Turn(legfl, x_axis, 0.071024, 1.730338 * speedMult)
	Turn(legfl, z_axis, -0.489563, 12.194460 * speedMult)
	Turn(legfl, y_axis, 0.028166, 0.711348 * speedMult)
	Turn(legfr, x_axis, 0.030267, 0.756679 * speedMult)
	Turn(legfr, z_axis, 0.045282, 1.132056 * speedMult)
	Turn(legfr, y_axis, -0.016596, 0.414906 * speedMult)
	Turn(thighbl, x_axis, 0.105756, 2.643893 * speedMult)
	Turn(thighbl, z_axis, 0.293968, 7.349211 * speedMult)
	Turn(thighbl, y_axis, 0.686566, 2.470796 * speedMult)
	Turn(thighbr, x_axis, -0.353384, 8.834596 * speedMult)
	Turn(thighbr, z_axis, -0.150241, 3.756037 * speedMult)
	Turn(thighbr, y_axis, -0.163140, 15.556462 * speedMult)
	Turn(thighfl, x_axis, -0.216046, 5.468982 * speedMult)
	Turn(thighfl, z_axis, -0.086812, 1.964656 * speedMult)
	Turn(thighfl, y_axis, -0.939240, 3.859687 * speedMult)
	Turn(thighfr, x_axis, 0.392149, 9.803732 * speedMult)
	Turn(thighfr, z_axis, -0.148568, 3.714209 * speedMult)
	Turn(thighfr, y_axis, 0.322422, 11.574412 * speedMult)
	if not isAiming then
		Turn(lforearm, x_axis, 0.872665, 4.363325 * speedMult)
		Turn(lshoulder, x_axis, 0.436332, 0.872665 * speedMult)
		Turn(lshoulder, z_axis, 0.610865, 2.181663 * speedMult)
		Turn(rforearm, x_axis, 0.610865, 2.181654 * speedMult)
		Turn(rshoulder, x_axis, -0.174533, 14.398965 * speedMult)
		Turn(rshoulder, z_axis, -0.610865, 2.181664 * speedMult)
		Turn(torso, y_axis, 0.087266, 2.181661 * speedMult)
	end
	Sleep(sleepTime)
	while true do
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 6
		Move(base, x_axis, 0.476045, 4.536825 * speedMult)
		Move(base, z_axis, -1.436337, 35.218200 * speedMult)
		Move(base, y_axis, -0.697014, 13.633549 * speedMult)
		Turn(base, x_axis, 0.005783, 0.305052 * speedMult)
		Turn(base, y_axis, -0.007150, 0.508814 * speedMult)
		Turn(footbl, x_axis, -0.108485, 4.664460 * speedMult)
		Turn(footbl, z_axis, -0.318711, 19.943484 * speedMult)
		Turn(footbl, y_axis, 0.036115, 0.119227 * speedMult)
		Turn(footbr, x_axis, -0.018189, 0.547466 * speedMult)
		Turn(footbr, z_axis, 0.312245, 0.526555 * speedMult)
		Turn(footbr, y_axis, -0.005893, 0.154697 * speedMult)
		Turn(footfl, x_axis, -0.020864, 0.760540 * speedMult)
		Turn(footfl, z_axis, 0.443505, 13.820600 * speedMult)
		Turn(footfl, y_axis, 0.006638, 1.555494 * speedMult)
		Turn(footfr, x_axis, 0.033190, 0.054844 * speedMult)
		Turn(footfr, z_axis, 0.717511, 2.349429 * speedMult)
		Turn(footfr, y_axis, 0.029003, 0.168838 * speedMult)
		Turn(legbl, x_axis, 0.319077, 2.181385 * speedMult)
		Turn(legbl, z_axis, -0.341920, 2.028230 * speedMult)
		Turn(legbl, y_axis, 0.082515, 0.649054 * speedMult)
		Turn(legbr, x_axis, 0.157738, 0.036999 * speedMult)
		Turn(legbr, z_axis, 0.041022, 2.614886 * speedMult)
		Turn(legbr, y_axis, 0.099860, 0.652241 * speedMult)
		Turn(legfl, x_axis, 0.010849, 1.504381 * speedMult)
		Turn(legfl, z_axis, -0.048555, 11.025206 * speedMult)
		Turn(legfl, y_axis, -0.010986, 0.978806 * speedMult)
		Turn(legfr, x_axis, -0.077213, 2.686996 * speedMult)
		Turn(legfr, z_axis, -0.226094, 6.784402 * speedMult)
		Turn(legfr, y_axis, 0.007510, 0.602646 * speedMult)
		Turn(thighbl, x_axis, 0.070705, 0.876265 * speedMult)
		Turn(thighbl, z_axis, 0.538806, 6.120934 * speedMult)
		Turn(thighbl, y_axis, 0.584066, 2.562504 * speedMult)
		Turn(thighbr, x_axis, -0.221436, 3.298685 * speedMult)
		Turn(thighbr, z_axis, -0.146649, 0.089811 * speedMult)
		Turn(thighbr, y_axis, -0.230696, 1.688922 * speedMult)
		Turn(thighfl, x_axis, -0.089257, 3.169713 * speedMult)
		Turn(thighfl, z_axis, -0.139153, 1.308532 * speedMult)
		Turn(thighfl, y_axis, -0.809601, 3.240979 * speedMult)
		Turn(thighfr, x_axis, 0.051189, 8.523999 * speedMult)
		Turn(thighfr, z_axis, -0.473570, 8.125037 * speedMult)
		Turn(thighfr, y_axis, 0.520353, 4.948292 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.845437, 0.680679 * speedMult)
			Turn(lshoulder, x_axis, 0.374617, 1.542871 * speedMult)
			Turn(lshoulder, z_axis, 0.654498, 1.090829 * speedMult)
			Turn(rforearm, x_axis, 0.638092, 0.680672 * speedMult)
			Turn(rshoulder, x_axis, -0.095365, 1.979203 * speedMult)
			Turn(rshoulder, z_axis, -0.654498, 1.090834 * speedMult)
			Turn(torso, y_axis, 0.069115, 0.453785 * speedMult)
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
		Turn(footbr, x_axis, 0.009872, 0.701530 * speedMult)
		Turn(footbr, z_axis, 0.039677, 6.814206 * speedMult)
		Turn(footbr, y_axis, 0.000450, 0.158583 * speedMult)
		Turn(footfl, x_axis, -0.024991, 0.103176 * speedMult)
		Turn(footfl, z_axis, -0.006574, 11.251969 * speedMult)
		Turn(footfl, y_axis, -0.000089, 0.168175 * speedMult)
		Turn(footfr, x_axis, 0.008277, 0.622834 * speedMult)
		Turn(footfr, z_axis, 0.475449, 6.051546 * speedMult)
		Turn(footfr, y_axis, 0.004311, 0.617320 * speedMult)
		Turn(legbl, x_axis, 0.213653, 2.635602 * speedMult)
		Turn(legbl, z_axis, -0.209513, 3.310171 * speedMult)
		Turn(legbl, y_axis, 0.056203, 0.657804 * speedMult)
		Turn(legbr, x_axis, 0.110462, 1.181896 * speedMult)
		Turn(legbr, z_axis, -0.066394, 2.685400 * speedMult)
		Turn(legbr, y_axis, 0.123940, 0.602006 * speedMult)
		Turn(legfl, x_axis, -0.012035, 0.572081 * speedMult)
		Turn(legfl, z_axis, 0.058244, 2.669982 * speedMult)
		Turn(legfl, y_axis, -0.007491, 0.087382 * speedMult)
		Turn(legfr, x_axis, -0.039859, 0.933839 * speedMult)
		Turn(legfr, z_axis, -0.293098, 1.675095 * speedMult)
		Turn(legfr, y_axis, 0.027712, 0.505063 * speedMult)
		Turn(thighbl, x_axis, -0.035729, 2.660854 * speedMult)
		Turn(thighbl, z_axis, 0.508184, 0.765552 * speedMult)
		Turn(thighbl, y_axis, 0.495203, 2.221581 * speedMult)
		Turn(thighbr, x_axis, -0.075254, 3.654558 * speedMult)
		Turn(thighbr, z_axis, 0.052274, 4.973069 * speedMult)
		Turn(thighbr, y_axis, -0.420668, 4.749285 * speedMult)
		Turn(thighfl, x_axis, 0.021278, 2.763377 * speedMult)
		Turn(thighfl, z_axis, 0.013979, 3.828301 * speedMult)
		Turn(thighfl, y_axis, -0.672925, 3.416894 * speedMult)
		Turn(thighfr, x_axis, -0.099864, 3.776339 * speedMult)
		Turn(thighfr, z_axis, -0.479205, 0.140883 * speedMult)
		Turn(thighfr, y_axis, 0.807217, 7.171598 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.780511, 1.623157 * speedMult)
			Turn(lshoulder, x_axis, 0.227451, 3.679155 * speedMult)
			Turn(lshoulder, z_axis, 0.698132, 1.090834 * speedMult)
			Turn(rforearm, x_axis, 0.703019, 1.623160 * speedMult)
			Turn(rshoulder, x_axis, 0.051801, 3.679154 * speedMult)
			Turn(rshoulder, z_axis, -0.698132, 1.090831 * speedMult)
			Turn(torso, y_axis, 0.025831, 1.082104 * speedMult)
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
		Turn(footbr, x_axis, -0.029865, 0.993430 * speedMult)
		Turn(footbr, z_axis, -0.654462, 17.353478 * speedMult)
		Turn(footbr, y_axis, 0.023066, 0.565412 * speedMult)
		Turn(footfl, x_axis, -0.060545, 0.888842 * speedMult)
		Turn(footfl, z_axis, -0.187783, 4.530224 * speedMult)
		Turn(footfl, y_axis, 0.004886, 0.124376 * speedMult)
		Turn(footfr, x_axis, -0.000767, 0.226106 * speedMult)
		Turn(footfr, z_axis, 0.105063, 9.259653 * speedMult)
		Turn(footfr, y_axis, -0.000066, 0.109410 * speedMult)
		Turn(legbl, x_axis, 0.080383, 3.331745 * speedMult)
		Turn(legbl, z_axis, -0.016072, 4.836033 * speedMult)
		Turn(legbl, y_axis, -0.003597, 1.494985 * speedMult)
		Turn(legbr, x_axis, 0.060146, 1.257888 * speedMult)
		Turn(legbr, z_axis, 0.036859, 2.581312 * speedMult)
		Turn(legbr, y_axis, 0.145620, 0.542002 * speedMult)
		Turn(legfl, x_axis, -0.041895, 0.746504 * speedMult)
		Turn(legfl, z_axis, -0.016374, 1.865452 * speedMult)
		Turn(legfl, y_axis, 0.031278, 0.969216 * speedMult)
		Turn(legfr, x_axis, -0.000069, 0.994750 * speedMult)
		Turn(legfr, z_axis, -0.187355, 2.643579 * speedMult)
		Turn(legfr, y_axis, 0.014816, 0.322392 * speedMult)
		Turn(thighbl, x_axis, -0.153797, 2.951696 * speedMult)
		Turn(thighbl, z_axis, 0.371347, 3.420915 * speedMult)
		Turn(thighbl, y_axis, 0.435157, 1.501156 * speedMult)
		Turn(thighbr, x_axis, 0.070608, 3.646555 * speedMult)
		Turn(thighbr, z_axis, 0.344616, 7.308565 * speedMult)
		Turn(thighbr, y_axis, -0.613425, 4.818930 * speedMult)
		Turn(thighfl, x_axis, 0.185789, 4.112782 * speedMult)
		Turn(thighfl, z_axis, 0.084716, 1.768435 * speedMult)
		Turn(thighfl, y_axis, -0.468654, 5.106775 * speedMult)
		Turn(thighfr, x_axis, -0.164092, 1.605707 * speedMult)
		Turn(thighfr, z_axis, -0.318228, 4.024430 * speedMult)
		Turn(thighfr, y_axis, 0.928727, 3.037734 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.703018, 1.937318 * speedMult)
			Turn(lshoulder, x_axis, 0.051801, 4.391248 * speedMult)
			Turn(rforearm, x_axis, 0.780511, 1.937315 * speedMult)
			Turn(rshoulder, x_axis, 0.227451, 4.391249 * speedMult)
			Turn(torso, y_axis, -0.025831, 1.291543 * speedMult)
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
		Turn(footbr, x_axis, -0.009372, 0.512316 * speedMult)
		Turn(footbr, z_axis, -1.217969, 14.087661 * speedMult)
		Turn(footbr, y_axis, 0.025710, 0.066095 * speedMult)
		Turn(footfl, x_axis, -0.111099, 1.263856 * speedMult)
		Turn(footfl, z_axis, -0.151251, 0.913311 * speedMult)
		Turn(footfl, y_axis, 0.011698, 0.170305 * speedMult)
		Turn(footfr, x_axis, 0.013011, 0.344463 * speedMult)
		Turn(footfr, z_axis, -0.568719, 16.844544 * speedMult)
		Turn(footfr, y_axis, -0.008354, 0.207201 * speedMult)
		Turn(legbl, x_axis, -0.027001, 2.684604 * speedMult)
		Turn(legbl, z_axis, 0.225706, 6.044428 * speedMult)
		Turn(legbl, y_axis, -0.112953, 2.733902 * speedMult)
		Turn(legbr, x_axis, 0.016606, 1.088506 * speedMult)
		Turn(legbr, z_axis, 0.813338, 19.411984 * speedMult)
		Turn(legbr, y_axis, 0.109239, 0.909522 * speedMult)
		Turn(legfl, x_axis, -0.022336, 0.488967 * speedMult)
		Turn(legfl, z_axis, -0.174177, 3.945089 * speedMult)
		Turn(legfl, y_axis, 0.076985, 1.142677 * speedMult)
		Turn(legfr, x_axis, 0.031994, 0.801571 * speedMult)
		Turn(legfr, z_axis, 0.122803, 7.753951 * speedMult)
		Turn(legfr, y_axis, -0.004436, 0.481309 * speedMult)
		Turn(thighbl, x_axis, -0.268561, 2.869112 * speedMult)
		Turn(thighbl, z_axis, 0.087772, 7.089388 * speedMult)
		Turn(thighbl, y_axis, 0.388999, 1.153954 * speedMult)
		Turn(thighbr, x_axis, 0.203074, 3.311637 * speedMult)
		Turn(thighbr, z_axis, 0.004724, 8.497319 * speedMult)
		Turn(thighbr, y_axis, -0.764860, 3.785874 * speedMult)
		Turn(thighfl, x_axis, 0.361465, 4.391903 * speedMult)
		Turn(thighfl, z_axis, 0.107755, 0.575968 * speedMult)
		Turn(thighfl, y_axis, -0.348237, 3.010429 * speedMult)
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
			Turn(torso, y_axis, -0.069115, 1.082104 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 18
		Move(base, x_axis, -0.297958, 7.343850 * speedMult)
		Move(base, z_axis, -0.052822, 36.597949 * speedMult)
		Move(base, y_axis, -0.163141, 17.304325 * speedMult)
		Turn(base, x_axis, -0.006584, 0.775734 * speedMult)
		Turn(base, y_axis, -0.012948, 0.384932 * speedMult)
		Turn(footbl, x_axis, 0.073901, 0.472783 * speedMult)
		Turn(footbl, z_axis, -0.293038, 4.300873 * speedMult)
		Turn(footbl, y_axis, -0.022525, 0.129696 * speedMult)
		Turn(footbr, x_axis, 0.040868, 1.255990 * speedMult)
		Turn(footbr, z_axis, -0.473630, 18.608473 * speedMult)
		Turn(footbr, y_axis, -0.020834, 1.163601 * speedMult)
		Turn(footfl, x_axis, -0.002434, 2.716609 * speedMult)
		Turn(footfl, z_axis, -0.624013, 11.819053 * speedMult)
		Turn(footfl, y_axis, -0.023353, 0.876280 * speedMult)
		Turn(footfr, x_axis, 0.045835, 0.820595 * speedMult)
		Turn(footfr, z_axis, -1.001944, 10.830635 * speedMult)
		Turn(footfr, y_axis, -0.071682, 1.583193 * speedMult)
		Turn(legbl, x_axis, 0.064371, 2.284295 * speedMult)
		Turn(legbl, z_axis, 0.264704, 0.974967 * speedMult)
		Turn(legbl, y_axis, -0.214206, 2.531341 * speedMult)
		Turn(legbr, x_axis, 0.054595, 0.949729 * speedMult)
		Turn(legbr, z_axis, 0.014017, 19.983023 * speedMult)
		Turn(legbr, y_axis, 0.037470, 1.794246 * speedMult)
		Turn(legfl, x_axis, 0.032506, 1.371044 * speedMult)
		Turn(legfl, z_axis, -0.048231, 3.148665 * speedMult)
		Turn(legfl, y_axis, 0.016631, 1.508853 * speedMult)
		Turn(legfr, x_axis, 0.072050, 1.001408 * speedMult)
		Turn(legfr, z_axis, 0.494071, 9.281692 * speedMult)
		Turn(legfr, y_axis, -0.030961, 0.663131 * speedMult)
		Turn(thighbl, x_axis, -0.292579, 0.600443 * speedMult)
		Turn(thighbl, z_axis, -0.104639, 4.810265 * speedMult)
		Turn(thighbl, y_axis, 0.228948, 4.001275 * speedMult)
		Turn(thighbr, x_axis, 0.264183, 1.527737 * speedMult)
		Turn(thighbr, z_axis, -0.057537, 1.556514 * speedMult)
		Turn(thighbr, y_axis, -0.921233, 3.909317 * speedMult)
		Turn(thighfl, x_axis, 0.393275, 0.795245 * speedMult)
		Turn(thighfl, z_axis, 0.141497, 0.843544 * speedMult)
		Turn(thighfl, y_axis, -0.322604, 0.640840 * speedMult)
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
			Turn(torso, y_axis, -0.087266, 0.453786 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 21
		Move(base, x_axis, -0.477314, 4.483900 * speedMult)
		Move(base, z_axis, -1.443403, 34.764525 * speedMult)
		Move(base, y_axis, -0.698002, 13.371525 * speedMult)
		Turn(base, x_axis, 0.006237, 0.320527 * speedMult)
		Turn(base, y_axis, 0.007421, 0.509210 * speedMult)
		Turn(footbl, x_axis, 0.066101, 0.194980 * speedMult)
		Turn(footbl, z_axis, -0.312765, 0.493179 * speedMult)
		Turn(footbl, y_axis, -0.021545, 0.024485 * speedMult)
		Turn(footbr, x_axis, 0.003814, 0.926334 * speedMult)
		Turn(footbr, z_axis, 0.317190, 19.770499 * speedMult)
		Turn(footbr, y_axis, 0.001280, 0.552849 * speedMult)
		Turn(footfl, x_axis, -0.000800, 0.040867 * speedMult)
		Turn(footfl, z_axis, -0.716644, 2.315785 * speedMult)
		Turn(footfl, y_axis, -0.029778, 0.160629 * speedMult)
		Turn(footfr, x_axis, 0.012493, 0.833562 * speedMult)
		Turn(footfr, z_axis, -0.444328, 13.940392 * speedMult)
		Turn(footfr, y_axis, -0.005912, 1.644226 * speedMult)
		Turn(legbl, x_axis, 0.093730, 0.733978 * speedMult)
		Turn(legbl, z_axis, 0.248176, 0.413217 * speedMult)
		Turn(legbl, y_axis, -0.195355, 0.471296 * speedMult)
		Turn(legbr, x_axis, -0.021814, 1.910223 * speedMult)
		Turn(legbr, z_axis, -0.239973, 6.349769 * speedMult)
		Turn(legbr, y_axis, 0.015934, 0.538378 * speedMult)
		Turn(legfl, x_axis, -0.074316, 2.670552 * speedMult)
		Turn(legfl, z_axis, 0.221118, 6.733717 * speedMult)
		Turn(legfl, y_axis, -0.006030, 0.566517 * speedMult)
		Turn(legfr, x_axis, 0.009356, 1.567356 * speedMult)
		Turn(legfr, z_axis, 0.048083, 11.149703 * speedMult)
		Turn(legfr, y_axis, 0.010256, 1.030423 * speedMult)
		Turn(thighbl, x_axis, -0.179433, 2.828649 * speedMult)
		Turn(thighbl, z_axis, -0.042055, 1.564590 * speedMult)
		Turn(thighbl, y_axis, 0.285331, 1.409585 * speedMult)
		Turn(thighbr, x_axis, 0.066671, 4.937792 * speedMult)
		Turn(thighbr, z_axis, -0.384342, 8.170121 * speedMult)
		Turn(thighbr, y_axis, -0.791890, 3.233556 * speedMult)
		Turn(thighfl, x_axis, 0.052492, 8.519577 * speedMult)
		Turn(thighfl, z_axis, 0.464893, 8.084917 * speedMult)
		Turn(thighfl, y_axis, -0.519707, 4.927583 * speedMult)
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
			Turn(torso, y_axis, -0.069115, 0.453785 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 24
		Move(base, z_axis, -0.830013, 15.334751 * speedMult)
		Move(base, y_axis, -0.263781, 10.855524 * speedMult)
		Turn(base, x_axis, 0.045108, 0.971780 * speedMult)
		Turn(base, y_axis, 0.024940, 0.437981 * speedMult)
		Turn(footbl, x_axis, 0.020912, 1.129746 * speedMult)
		Turn(footbl, z_axis, -0.036953, 6.895303 * speedMult)
		Turn(footbl, y_axis, -0.000883, 0.516572 * speedMult)
		Turn(footbr, x_axis, 0.004154, 0.008495 * speedMult)
		Turn(footbr, z_axis, 0.565224, 6.200843 * speedMult)
		Turn(footbr, y_axis, 0.002662, 0.034552 * speedMult)
		Turn(footfl, x_axis, -0.024037, 0.580934 * speedMult)
		Turn(footfl, z_axis, -0.476120, 6.013110 * speedMult)
		Turn(footfl, y_axis, -0.005657, 0.603041 * speedMult)
		Turn(footfr, x_axis, 0.007488, 0.125129 * speedMult)
		Turn(footfr, z_axis, 0.007082, 11.285263 * speedMult)
		Turn(footfr, y_axis, 0.000078, 0.149754 * speedMult)
		Turn(legbl, x_axis, 0.092297, 0.035812 * speedMult)
		Turn(legbl, z_axis, 0.137342, 2.770841 * speedMult)
		Turn(legbl, y_axis, -0.146322, 1.225815 * speedMult)
		Turn(legbr, x_axis, 0.001247, 0.576524 * speedMult)
		Turn(legbr, z_axis, -0.193497, 1.161899 * speedMult)
		Turn(legbr, y_axis, 0.026434, 0.262499 * speedMult)
		Turn(legfl, x_axis, -0.037558, 0.918963 * speedMult)
		Turn(legfl, z_axis, 0.290099, 1.724533 * speedMult)
		Turn(legfl, y_axis, -0.026808, 0.519449 * speedMult)
		Turn(legfr, x_axis, -0.014771, 0.603169 * speedMult)
		Turn(legfr, z_axis, -0.061945, 2.750697 * speedMult)
		Turn(legfr, y_axis, 0.008022, 0.055848 * speedMult)
		Turn(thighbl, x_axis, -0.060843, 2.964757 * speedMult)
		Turn(thighbl, z_axis, -0.103313, 1.531432 * speedMult)
		Turn(thighbl, y_axis, 0.438337, 3.825156 * speedMult)
		Turn(thighbr, x_axis, -0.047804, 2.861874 * speedMult)
		Turn(thighbr, z_axis, -0.431259, 1.172939 * speedMult)
		Turn(thighbr, y_axis, -0.603172, 4.717958 * speedMult)
		Turn(thighfl, x_axis, -0.097475, 3.749185 * speedMult)
		Turn(thighfl, z_axis, 0.470353, 0.136486 * speedMult)
		Turn(thighfl, y_axis, -0.804147, 7.110988 * speedMult)
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
			Turn(torso, y_axis, -0.025831, 1.082104 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 27
		Move(base, x_axis, -0.287738, 4.739400 * speedMult)
		Move(base, z_axis, 0.935739, 44.143799 * speedMult)
		Move(base, y_axis, 0.536665, 20.011151 * speedMult)
		Turn(base, x_axis, 0.056062, 0.273846 * speedMult)
		Turn(base, y_axis, 0.032884, 0.198590 * speedMult)
		Turn(footbl, x_axis, 0.025992, 0.127013 * speedMult)
		Turn(footbl, z_axis, 0.658147, 17.377501 * speedMult)
		Turn(footbl, y_axis, 0.020161, 0.526082 * speedMult)
		Turn(footbr, x_axis, 0.000673, 0.087021 * speedMult)
		Turn(footbr, z_axis, 0.592014, 0.669758 * speedMult)
		Turn(footbr, y_axis, 0.000463, 0.054986 * speedMult)
		Turn(footfl, x_axis, -0.032495, 0.211452 * speedMult)
		Turn(footfl, z_axis, -0.106256, 9.246597 * speedMult)
		Turn(footfl, y_axis, -0.000273, 0.134586 * speedMult)
		Turn(footfr, x_axis, -0.027537, 0.875603 * speedMult)
		Turn(footfr, z_axis, 0.187176, 4.502343 * speedMult)
		Turn(footfr, y_axis, -0.005225, 0.132578 * speedMult)
		Turn(legbl, x_axis, 0.133858, 1.039003 * speedMult)
		Turn(legbl, z_axis, -0.272143, 10.237116 * speedMult)
		Turn(legbl, y_axis, -0.081625, 1.617411 * speedMult)
		Turn(legbr, x_axis, 0.033588, 0.808525 * speedMult)
		Turn(legbr, z_axis, -0.090447, 2.576261 * speedMult)
		Turn(legbr, y_axis, 0.031834, 0.134997 * speedMult)
		Turn(legfl, x_axis, 0.001884, 0.986040 * speedMult)
		Turn(legfl, z_axis, 0.185820, 2.606988 * speedMult)
		Turn(legfl, y_axis, -0.014761, 0.301173 * speedMult)
		Turn(legfr, x_axis, -0.044273, 0.737551 * speedMult)
		Turn(legfr, z_axis, 0.012972, 1.872924 * speedMult)
		Turn(legfr, y_axis, -0.031171, 0.979825 * speedMult)
		Turn(thighbl, x_axis, -0.005803, 1.376009 * speedMult)
		Turn(thighbl, z_axis, -0.164259, 1.523659 * speedMult)
		Turn(thighbl, y_axis, 0.543645, 2.632701 * speedMult)
		Turn(thighbr, x_axis, -0.152709, 2.622631 * speedMult)
		Turn(thighbr, z_axis, -0.352146, 1.977827 * speedMult)
		Turn(thighbr, y_axis, -0.457124, 3.651191 * speedMult)
		Turn(thighfl, x_axis, -0.160879, 1.585085 * speedMult)
		Turn(thighfl, z_axis, 0.308816, 4.038410 * speedMult)
		Turn(thighfl, y_axis, -0.925596, 3.036241 * speedMult)
		Turn(thighfr, x_axis, 0.184474, 4.128601 * speedMult)
		Turn(thighfr, z_axis, -0.091934, 1.758869 * speedMult)
		Turn(thighfr, y_axis, 0.468024, 5.114298 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.780511, 1.937316 * speedMult)
			Turn(lshoulder, x_axis, 0.227451, 4.391249 * speedMult)
			Turn(rforearm, x_axis, 0.703019, 1.937313 * speedMult)
			Turn(rshoulder, x_axis, 0.040492, 4.520403 * speedMult)
			Turn(torso, y_axis, 0.025831, 1.291543 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 30
		Move(base, x_axis, 0.008407, 7.403625 * speedMult)
		Move(base, z_axis, 1.402343, 11.665101 * speedMult)
		Turn(base, x_axis, 0.023890, 0.804287 * speedMult)
		Turn(base, y_axis, 0.028202, 0.117048 * speedMult)
		Turn(footbl, x_axis, -0.022833, 1.220630 * speedMult)
		Turn(footbl, z_axis, 1.215967, 13.945509 * speedMult)
		Turn(footbl, y_axis, -0.061941, 2.052545 * speedMult)
		Turn(footbr, x_axis, -0.006032, 0.167639 * speedMult)
		Turn(footbr, z_axis, 0.465478, 3.163406 * speedMult)
		Turn(footbr, y_axis, -0.003053, 0.087899 * speedMult)
		Turn(footfl, x_axis, -0.020708, 0.294671 * speedMult)
		Turn(footfl, z_axis, 0.569406, 16.891555 * speedMult)
		Turn(footfl, y_axis, 0.009129, 0.235046 * speedMult)
		Turn(footfr, x_axis, -0.078355, 1.270468 * speedMult)
		Turn(footfr, z_axis, 0.151580, 0.889900 * speedMult)
		Turn(footfr, y_axis, -0.012049, 0.170579 * speedMult)
		Turn(legbl, x_axis, -0.001251, 3.377708 * speedMult)
		Turn(legbl, z_axis, -0.762455, 12.257819 * speedMult)
		Turn(legbl, y_axis, -0.126957, 1.133299 * speedMult)
		Turn(legbr, x_axis, 0.061489, 0.697529 * speedMult)
		Turn(legbr, z_axis, 0.040288, 3.268365 * speedMult)
		Turn(legbr, y_axis, 0.025103, 0.168271 * speedMult)
		Turn(legfl, x_axis, 0.033329, 0.786124 * speedMult)
		Turn(legfl, z_axis, -0.124020, 7.745999 * speedMult)
		Turn(legfl, y_axis, 0.003432, 0.454829 * speedMult)
		Turn(legfr, x_axis, -0.022609, 0.541607 * speedMult)
		Turn(legfr, z_axis, 0.173539, 4.014184 * speedMult)
		Turn(legfr, y_axis, -0.078373, 1.180045 * speedMult)
		Turn(thighbl, x_axis, 0.219992, 5.644865 * speedMult)
		Turn(thighbl, z_axis, -0.039364, 3.122369 * speedMult)
		Turn(thighbl, y_axis, 0.789196, 6.138766 * speedMult)
		Turn(thighbr, x_axis, -0.285602, 3.322334 * speedMult)
		Turn(thighbr, z_axis, -0.156812, 4.883361 * speedMult)
		Turn(thighbr, y_axis, -0.351952, 2.629314 * speedMult)
		Turn(thighfl, x_axis, -0.225285, 1.610171 * speedMult)
		Turn(thighfl, z_axis, 0.050711, 6.452627 * speedMult)
		Turn(thighfl, y_axis, -0.976048, 1.261283 * speedMult)
		Turn(thighfr, x_axis, 0.359491, 4.375435 * speedMult)
		Turn(thighfr, z_axis, -0.115419, 0.587123 * speedMult)
		Turn(thighfr, y_axis, 0.348623, 2.985021 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.845438, 1.623155 * speedMult)
			Turn(lshoulder, x_axis, 0.374617, 3.679154 * speedMult)
			Turn(lshoulder, z_axis, 0.654498, 1.090831 * speedMult)
			Turn(rforearm, x_axis, 0.638093, 1.623155 * speedMult)
			Turn(rshoulder, x_axis, -0.111003, 3.787364 * speedMult)
			Turn(rshoulder, z_axis, -0.654498, 1.090835 * speedMult)
			Turn(torso, y_axis, 0.069115, 1.082104 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 3 (loop)
		Move(base, x_axis, 0.294572, 7.154125 * speedMult)
		Move(base, y_axis, -0.151672, 17.208425 * speedMult)
		Move(base, z_axis, -0.027609, 35.748800 * speedMult)
		Turn(base, x_axis, -0.006419, 0.757725 * speedMult)
		Turn(base, y_axis, 0.013202, 0.375000 * speedMult)
		Turn(footbl, x_axis, 0.078093, 2.523150 * speedMult)
		Turn(footbl, y_axis, 0.040885, 2.570650 * speedMult)
		Turn(footbl, z_axis, 0.479028, 18.423475 * speedMult)
		Turn(footbr, x_axis, -0.040087, 0.851375 * speedMult)
		Turn(footbr, y_axis, -0.012081, 0.225700 * speedMult)
		Turn(footbr, z_axis, 0.291183, 4.357375 * speedMult)
		Turn(footfl, x_axis, 0.009558, 0.756650 * speedMult)
		Turn(footfl, y_axis, 0.068858, 1.493225 * speedMult)
		Turn(footfl, z_axis, 0.996329, 10.673075 * speedMult)
		Turn(footfr, x_axis, 0.030997, 2.733800 * speedMult)
		Turn(footfr, y_axis, 0.022250, 0.857475 * speedMult)
		Turn(footfr, z_axis, 0.623534, 11.798850 * speedMult)
		Turn(legbl, x_axis, 0.231822, 5.826825 * speedMult)
		Turn(legbl, y_axis, 0.056553, 4.587750 * speedMult)
		Turn(legbl, z_axis, -0.423049, 8.485150 * speedMult)
		Turn(legbr, x_axis, 0.159218, 2.443225 * speedMult)
		Turn(legbr, y_axis, 0.073770, 1.216675 * speedMult)
		Turn(legbr, z_axis, 0.145618, 2.633250 * speedMult)
		Turn(legfl, x_axis, 0.071024, 0.942375 * speedMult)
		Turn(legfl, y_axis, 0.028166, 0.618350 * speedMult)
		Turn(legfl, z_axis, -0.489563, 9.138575 * speedMult)
		Turn(legfr, x_axis, 0.030267, 1.321900 * speedMult)
		Turn(legfr, y_axis, -0.016596, 1.544425 * speedMult)
		Turn(legfr, z_axis, 0.045282, 3.206425 * speedMult)
		Turn(thighbl, x_axis, 0.105756, 2.855900 * speedMult)
		Turn(thighbl, y_axis, 0.686566, 2.565750 * speedMult)
		Turn(thighbl, z_axis, 0.293968, 8.333300 * speedMult)
		Turn(thighbr, x_axis, -0.353384, 1.694550 * speedMult)
		Turn(thighbr, y_axis, -0.163140, 4.720300 * speedMult)
		Turn(thighbr, z_axis, -0.150241, 0.164275 * speedMult)
		Turn(thighfl, x_axis, -0.216046, 0.230975 * speedMult)
		Turn(thighfl, y_axis, -0.939240, 0.920200 * speedMult)
		Turn(thighfl, z_axis, -0.086812, 3.438075 * speedMult)
		Turn(thighfr, x_axis, 0.392149, 0.816450 * speedMult)
		Turn(thighfr, y_axis, 0.322422, 0.655025 * speedMult)
		Turn(thighfr, z_axis, -0.148568, 0.828725 * speedMult)
		if not isAiming then
			Turn(lforearm, x_axis, 0.872665, 0.680675 * speedMult)
			Turn(lshoulder, x_axis, 0.436332, 1.542875 * speedMult)
			Turn(lshoulder, z_axis, 0.610865, 1.090825 * speedMult)
			Turn(rforearm, x_axis, 0.610865, 0.680700 * speedMult)
			Turn(rshoulder, x_axis, -0.174533, 1.588250 * speedMult)
			Turn(rshoulder, z_axis, -0.610865, 1.090825 * speedMult)
			Turn(torso, y_axis, 0.087266, 0.453775 * speedMult)
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
	Turn(footbl, x_axis, 0.000000, 15.548199 * speedMult)
	Turn(footbl, y_axis, 0.000000, 8.568808 * speedMult)
	Turn(footbl, z_axis, 0.000000, 66.478280 * speedMult)
	Turn(footbr, x_axis, 0.000000, 4.186635 * speedMult)
	Turn(footbr, y_axis, 0.000000, 3.878669 * speedMult)
	Turn(footbr, z_axis, 0.000000, 65.901662 * speedMult)
	Turn(footfl, x_axis, -0.032380, 9.055364 * speedMult)
	Turn(footfl, y_axis, 0.000000, 5.738203 * speedMult)
	Turn(footfl, z_axis, 0.000000, 83.027395 * speedMult)
	Turn(footfr, x_axis, 0.000000, 9.112668 * speedMult)
	Turn(footfr, y_axis, 0.000000, 5.480753 * speedMult)
	Turn(footfr, z_axis, 0.000000, 56.148480 * speedMult)
	Turn(legbl, x_axis, 0.000000, 19.422701 * speedMult)
	Turn(legbl, y_axis, 0.000000, 15.292518 * speedMult)
	Turn(legbl, z_axis, 0.000000, 40.859396 * speedMult)
	Turn(legbr, x_axis, 0.000000, 13.268122 * speedMult)
	Turn(legbr, y_axis, 0.000000, 6.147531 * speedMult)
	Turn(legbr, z_axis, 0.000000, 66.610075 * speedMult)
	Turn(legfl, x_axis, 0.001810, 8.901839 * speedMult)
	Turn(legfl, y_axis, -0.000288, 5.029512 * speedMult)
	Turn(legfl, z_axis, -0.001785, 40.648201 * speedMult)
	Turn(legfr, x_axis, 0.000000, 8.956655 * speedMult)
	Turn(legfr, y_axis, 0.000000, 5.148058 * speedMult)
	Turn(legfr, z_axis, 0.000000, 37.165676 * speedMult)
	Turn(thighbl, x_axis, 0.000000, 18.816216 * speedMult)
	Turn(thighbl, y_axis, 0.785398, 20.462553 * speedMult)
	Turn(thighbl, z_axis, 0.000000, 27.777730 * speedMult)
	Turn(thighbr, x_axis, 0.000000, 29.448652 * speedMult)
	Turn(thighbr, y_axis, -0.785398, 51.854874 * speedMult)
	Turn(thighbr, z_axis, 0.000000, 28.324396 * speedMult)
	Turn(thighfl, x_axis, 0.002714, 28.398589 * speedMult)
	Turn(thighfl, y_axis, -0.784853, 23.703292 * speedMult)
	Turn(thighfl, z_axis, -0.008226, 26.949722 * speedMult)
	Turn(thighfr, x_axis, 0.000000, 32.679107 * speedMult)
	Turn(thighfr, y_axis, 0.785398, 38.581374 * speedMult)
	Turn(thighfr, z_axis, 0.000000, 27.083455 * speedMult)
	if not isAiming then
		Turn(lforearm, x_axis, 0.698132, 14.544417 * speedMult)
		Turn(lshoulder, x_axis, 0.401426, 14.637495 * speedMult)
		Turn(lshoulder, z_axis, 0.698132, 7.272209 * speedMult)
		Turn(rforearm, x_axis, 0.698132, 7.272179 * speedMult)
		Turn(rshoulder, x_axis, 0.401426, 47.996551 * speedMult)
		Turn(rshoulder, z_axis, -0.698132, 7.272214 * speedMult)
		Turn(torso, y_axis, 0.000000, 7.272204 * speedMult)
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
