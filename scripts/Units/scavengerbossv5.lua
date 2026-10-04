local P = {
	base = piece("base"),
	bbarrel = piece("bbarrel"),
	bflare = piece("bflare"),
	blfoot = piece("blfoot"),
	blhinge = piece("blhinge"),
	blleg = piece("blleg"),
	brfoot = piece("brfoot"),
	brhinge = piece("brhinge"),
	brleg = piece("brleg"),
	bturret = piece("bturret"),
	eaterbeam = piece("eaterbeam"),
	eaterbeamflare = piece("eaterbeamflare"),
	fbarrel = piece("fbarrel"),
	fflare = piece("fflare"),
	fldeco = piece("fldeco"),
	flfoot = piece("flfoot"),
	flhinge = piece("flhinge"),
	flleg = piece("flleg"),
	frdeco = piece("frdeco"),
	frfoot = piece("frfoot"),
	frhinge = piece("frhinge"),
	frleg = piece("frleg"),
	fturret = piece("fturret"),
	larm = piece("larm"),
	lbarrel = piece("lbarrel"),
	lbarrel1 = piece("lbarrel1"),
	lcannon = piece("lcannon"),
	lflare = piece("lflare"),
	lflare1 = piece("lflare1"),
	lhead = piece("lhead"),
	lpodflare = piece("lpodflare"),
	lrocketpod = piece("lrocketpod"),
	lshoulder = piece("lshoulder"),
	lturret = piece("lturret"),
	mlfoot = piece("mlfoot"),
	mlhinge = piece("mlhinge"),
	mlleg = piece("mlleg"),
	mrfoot = piece("mrfoot"),
	mrhinge = piece("mrhinge"),
	mrleg = piece("mrleg"),
	rarm = piece("rarm"),
	rbarrel = piece("rbarrel"),
	rbarrel1 = piece("rbarrel1"),
	rcannon = piece("rcannon"),
	rflare = piece("rflare"),
	rflare1 = piece("rflare1"),
	rgbarrel = piece("rgbarrel"),
	rgflare = piece("rgflare"),
	rgsleeve = piece("rgsleeve"),
	rgturret = piece("rgturret"),
	rhead = piece("rhead"),
	rpodflare = piece("rpodflare"),
	rrocketpod = piece("rrocketpod"),
	rshoulder = piece("rshoulder"),
	rturret = piece("rturret"),
	sleevedeco2 = piece("sleevedeco2"),
	spine1 = piece("spine1"),
	spine2 = piece("spine2"),
	spine3 = piece("spine3"),
	torso = piece("torso"),
	torsobase = piece("torsobase"),
}
local pieceMap = Spring.GetUnitPieceMap(unitID)
P.lflare2 = pieceMap.lflare2 and piece("lflare2") or P.lflare1
P.rflare2 = pieceMap.rflare2 and piece("rflare2") or P.rflare1

local SIG_WALK = 1
local ANIM_FRAMES = 5
local EXPORT_FPS = 30 -- Blender scene frame rate the turn speeds below were exported at
local STRIDE = 150 -- elmos per walk cycle; lower it if planted feet slide backwards, raise it if they slip forwards
local CYCLE_SECONDS = 4.0000 -- length of the exported cycle; rate 1 = Blender speed
local RESTORE_TURN, RESTORE_MOVE = 1.5, 30
local FRAME_MS = 1000 / Game.gameSpeed + 0.01 -- Sleep floors to whole frames
local RATE_MIN, RATE_MAX = 0.3, 3
local walking = false
local isAiming = false
local posed = false
local frameDebt = 0.0
local TURN_AMP = 0.5 -- step size while turning in place, 1 = full steps
local TURN_RATE = 1.0 -- cycle speed while turning in place, 1 = Blender speed
local GetUnitVelocity, GetUnitHeading, GetGameFrame = Spring.GetUnitVelocity, Spring.GetUnitHeading, Spring.GetGameFrame
local lastHeading, lastFrame = 0, 0
local amp = 1.0

local function A(value, mid)
	return mid + (value - mid) * amp
end

local function GetSpeedParams()
	local _, _, _, speed = GetUnitVelocity(unitID)
	local heading, frame = GetUnitHeading(unitID), GetGameFrame()
	local turn = 0
	if frame > lastFrame then
		local delta = (heading - lastHeading) % 65536
		if delta > 32768 then
			delta = delta - 65536
		end
		turn = math.abs(delta) * math.pi / 32768 / (frame - lastFrame)
	end
	lastHeading, lastFrame = heading, frame
	local rate = speed * Game.gameSpeed * CYCLE_SECONDS / STRIDE
	local ampTarget = 1
	if rate < 0.5 and turn > 0.003 then
		rate, ampTarget = math.max(rate, TURN_RATE), TURN_AMP
	end
	amp = amp + math.max(-0.25, math.min(0.25, ampTarget - amp))
	rate = math.max(RATE_MIN, math.min(RATE_MAX, rate))
	frameDebt = frameDebt + ANIM_FRAMES / rate
	local frames = math.max(1, math.floor(frameDebt))
	frameDebt = frameDebt - frames
	return Game.gameSpeed / (EXPORT_FPS * frames), frames * FRAME_MS
end

local function Walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	frameDebt = 0
	amp = 1.0
	lastHeading, lastFrame = GetUnitHeading(unitID), GetGameFrame()
	local speedMult, sleepTime = GetSpeedParams()
	-- Frame: 5 (first step)
	Move(P.base, z_axis, A(3.401280, 0.010289), 17.910440 * speedMult)
	Move(P.base, y_axis, A(-1.742935, -0.005208), 7.707367 * speedMult)
	Turn(P.base, x_axis, A(0.007518, 0.000011), 0.225546 * speedMult)
	Turn(P.base, z_axis, A(-0.014594, -0.000040), 0.011999 * speedMult)
	Turn(P.base, y_axis, A(-0.096888, -0.000266), 0.093114 * speedMult)
	Turn(P.blfoot, x_axis, A(0.259594, 0.303430), 6.746330 * speedMult)
	Turn(P.blhinge, y_axis, A(-0.226478, -0.451164), 0.817637 * speedMult)
	Turn(P.blleg, x_axis, A(-0.023881, -0.080530), 3.936769 * speedMult)
	Turn(P.brfoot, x_axis, A(0.118814, 0.372613), 31.790735 * speedMult)
	Turn(P.brhinge, y_axis, A(0.551940, 0.469086), 3.066920 * speedMult)
	Turn(P.brleg, x_axis, A(0.287553, -0.151242), 21.067366 * speedMult)
	Turn(P.fldeco, x_axis, A(0.943989, 0.358011), 1.342151 * speedMult)
	Turn(P.flfoot, x_axis, A(-1.622504, -0.610363), 2.957557 * speedMult)
	Move(P.flhinge, y_axis, A(0.000001, 3.186940), 162.906260 * speedMult)
	Turn(P.flhinge, y_axis, A(0.375310, 0.363854), 0.210741 * speedMult)
	Turn(P.flleg, x_axis, A(0.646802, 0.172704), 1.475002 * speedMult)
	Turn(P.frdeco, x_axis, A(-0.102899, 0.358842), 1.342162 * speedMult)
	Turn(P.frfoot, x_axis, A(0.224713, -0.611057), 2.377539 * speedMult)
	Move(P.frhinge, y_axis, A(0.545455, 3.186940), 16.363639 * speedMult)
	Turn(P.frhinge, y_axis, A(-0.406989, -0.363165), 1.341657 * speedMult)
	Turn(P.frleg, x_axis, A(-0.041772, 0.173199), 0.044079 * speedMult)
	Turn(P.mlfoot, z_axis, A(0.102427, 0.039098), 3.205399 * speedMult)
	Turn(P.mlhinge, y_axis, A(-0.489700, -0.283127), 2.347955 * speedMult)
	Turn(P.mlleg, z_axis, A(0.091046, 0.091969), 1.152536 * speedMult)
	Turn(P.mrfoot, z_axis, A(-0.015531, -0.086282), 0.612367 * speedMult)
	Turn(P.mrhinge, y_axis, A(0.026743, 0.270533), 3.651713 * speedMult)
	Turn(P.mrleg, z_axis, A(-0.017869, -0.058481), 0.690965 * speedMult)
	if not isAiming then
		Turn(P.lshoulder, x_axis, A(0.609578, 0.500280), 0.384266 * speedMult)
		Turn(P.lturret, x_axis, A(-0.609578, -0.500280), 0.384264 * speedMult)
		Turn(P.rcannon, x_axis, A(-0.088568, -0.000259), 0.480023 * speedMult)
		Turn(P.rshoulder, x_axis, A(0.390422, 0.499720), 0.384264 * speedMult)
		Turn(P.rturret, x_axis, A(-0.390422, -0.499720), 0.384264 * speedMult)
		Turn(P.torso, x_axis, A(-0.025516, 0.000034), 0.201644 * speedMult)
		Turn(P.torsobase, y_axis, A(0.067244, 0.000203), 0.507095 * speedMult)
	end
	if not posed then
		Turn(P.spine1, x_axis, A(0.039931, 0.000085), 0.613804 * speedMult)
		Turn(P.spine2, x_axis, A(0.010745, 0.000060), 0.690841 * speedMult)
		Turn(P.spine3, x_axis, A(-0.048874, -0.000135), 0.038822 * speedMult)
	end
	Sleep(sleepTime)
	while true do
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 10
		Move(P.base, z_axis, A(1.888124, 0.010289), 45.394685 * speedMult)
		Move(P.base, y_axis, A(-1.016560, -0.005208), 21.791267 * speedMult)
		Turn(P.base, x_axis, A(0.013011, 0.000011), 0.164795 * speedMult)
		Turn(P.base, z_axis, A(-0.013194, -0.000040), 0.041994 * speedMult)
		Turn(P.base, y_axis, A(-0.087147, -0.000266), 0.292254 * speedMult)
		Turn(P.blfoot, x_axis, A(0.489985, 0.303430), 6.911726 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.220055, -0.451164), 0.192693 * speedMult)
		Turn(P.blleg, x_axis, A(-0.174047, -0.080530), 4.504977 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.281877, 0.372613), 12.020733 * speedMult)
		Turn(P.brhinge, y_axis, A(0.736306, 0.469086), 5.530974 * speedMult)
		Turn(P.brleg, x_axis, A(0.373299, -0.151242), 2.572384 * speedMult)
		Turn(P.fldeco, x_axis, A(0.885828, 0.358011), 1.744815 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.507152, -0.610363), 3.460536 * speedMult)
		Turn(P.flhinge, y_axis, A(0.372656, 0.363854), 0.079629 * speedMult)
		Turn(P.flleg, x_axis, A(0.594744, 0.172704), 1.561739 * speedMult)
		Turn(P.frdeco, x_axis, A(-0.125269, 0.358842), 0.671082 * speedMult)
		Turn(P.frfoot, x_axis, A(0.263593, -0.611057), 1.166400 * speedMult)
		Move(P.frhinge, y_axis, A(1.090909, 3.186940), 16.363639 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.462274, -0.363165), 1.658549 * speedMult)
		Turn(P.frleg, x_axis, A(-0.004535, 0.173199), 1.117108 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.066237, 0.039098), 1.085686 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.425993, -0.283127), 1.911222 * speedMult)
		Turn(P.mlleg, z_axis, A(0.071926, 0.091969), 0.573599 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.069687, -0.086282), 1.624678 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.087409, 0.270533), 3.424567 * speedMult)
		Turn(P.mrleg, z_axis, A(0.032568, -0.058481), 1.513091 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.614879, 0.500280), 0.159041 * speedMult)
			Turn(P.lturret, x_axis, A(-0.614879, -0.500280), 0.159041 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.066500, -0.000259), 0.662061 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.385121, 0.499720), 0.159042 * speedMult)
			Turn(P.rturret, x_axis, A(-0.385121, -0.499720), 0.159042 * speedMult)
			Turn(P.torso, x_axis, A(-0.011922, 0.000034), 0.407826 * speedMult)
			Turn(P.torsobase, y_axis, A(0.045734, 0.000203), 0.645305 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.049636, 0.000085), 0.291138 * speedMult)
			Turn(P.spine2, x_axis, A(-0.015177, 0.000060), 0.777667 * speedMult)
			Turn(P.spine3, x_axis, A(-0.037004, -0.000135), 0.356109 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 15
		Move(P.base, z_axis, A(-0.133603, 0.010289), 60.651807 * speedMult)
		Move(P.base, y_axis, A(-0.016373, -0.005208), 30.005608 * speedMult)
		Turn(P.base, x_axis, A(0.015000, 0.000011), 0.059656 * speedMult)
		Turn(P.base, z_axis, A(-0.010890, -0.000040), 0.069112 * speedMult)
		Turn(P.base, y_axis, A(-0.071434, -0.000266), 0.471370 * speedMult)
		Turn(P.blfoot, x_axis, A(0.725172, 0.303430), 7.055612 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.227805, -0.451164), 0.232491 * speedMult)
		Turn(P.blleg, x_axis, A(-0.328466, -0.080530), 4.632564 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.137377, 0.372613), 4.335001 * speedMult)
		Turn(P.brhinge, y_axis, A(0.974773, 0.469086), 7.154029 * speedMult)
		Turn(P.brleg, x_axis, A(-0.185168, -0.151242), 16.754018 * speedMult)
		Turn(P.fldeco, x_axis, A(0.823194, 0.358011), 1.879030 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.419453, -0.610363), 2.630972 * speedMult)
		Turn(P.flhinge, y_axis, A(0.361940, 0.363854), 0.321490 * speedMult)
		Turn(P.flleg, x_axis, A(0.565664, 0.172704), 0.872403 * speedMult)
		Turn(P.frdeco, x_axis, A(-0.187903, 0.358842), 1.879029 * speedMult)
		Turn(P.frfoot, x_axis, A(0.368305, -0.611057), 3.141362 * speedMult)
		Move(P.frhinge, y_axis, A(1.636364, 3.186940), 16.363639 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.473316, -0.363165), 0.331259 * speedMult)
		Turn(P.frleg, x_axis, A(-0.172437, 0.173199), 5.037056 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.073373, 0.039098), 0.214059 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.371522, -0.283127), 1.634128 * speedMult)
		Turn(P.mlleg, z_axis, A(0.018395, 0.091969), 1.605945 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.178154, -0.086282), 7.435228 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.059150, 0.270533), 0.847766 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.256590, -0.058481), 8.674734 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.612310, 0.500280), 0.077074 * speedMult)
			Turn(P.lturret, x_axis, A(-0.612310, -0.500280), 0.077072 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.039875, -0.000259), 0.798739 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.387690, 0.499720), 0.077073 * speedMult)
			Turn(P.rturret, x_axis, A(-0.387690, -0.499720), 0.077072 * speedMult)
			Turn(P.torso, x_axis, A(0.004884, 0.000034), 0.504158 * speedMult)
			Turn(P.torsobase, y_axis, A(0.021090, 0.000203), 0.739303 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.045971, 0.000085), 0.109946 * speedMult)
			Turn(P.spine2, x_axis, A(-0.037011, 0.000060), 0.655027 * speedMult)
			Turn(P.spine3, x_axis, A(-0.015167, -0.000135), 0.655121 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 20
		Move(P.base, z_axis, A(-2.119344, 0.010289), 59.572218 * speedMult)
		Move(P.base, y_axis, A(0.988224, -0.005208), 30.137901 * speedMult)
		Turn(P.base, x_axis, A(0.012948, 0.000011), 0.061552 * speedMult)
		Turn(P.base, z_axis, A(-0.007840, -0.000040), 0.091495 * speedMult)
		Turn(P.base, y_axis, A(-0.050828, -0.000266), 0.618193 * speedMult)
		Turn(P.blfoot, x_axis, A(0.978826, 0.303430), 7.609597 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.243853, -0.451164), 0.481440 * speedMult)
		Turn(P.blleg, x_axis, A(-0.486142, -0.080530), 4.730283 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.070638, 0.372613), 2.002173 * speedMult)
		Turn(P.brhinge, y_axis, A(0.825213, 0.469086), 4.486803 * speedMult)
		Turn(P.brleg, x_axis, A(-0.197645, -0.151242), 0.374312 * speedMult)
		Turn(P.fldeco, x_axis, A(0.729242, 0.358011), 2.818542 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.295152, -0.610363), 3.729039 * speedMult)
		Turn(P.flhinge, y_axis, A(0.345773, 0.363854), 0.484995 * speedMult)
		Turn(P.flleg, x_axis, A(0.520327, 0.172704), 1.360116 * speedMult)
		Turn(P.frdeco, x_axis, A(-0.152112, 0.358842), 1.073731 * speedMult)
		Turn(P.frfoot, x_axis, A(0.305480, -0.611057), 1.884753 * speedMult)
		Move(P.frhinge, y_axis, A(2.181818, 3.186940), 16.363639 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.417489, -0.363165), 1.674816 * speedMult)
		Turn(P.frleg, x_axis, A(-0.324618, 0.173199), 4.565421 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.096927, 0.039098), 0.706639 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.315707, -0.283127), 1.674435 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.044890, 0.091969), 1.898526 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.287742, -0.086282), 3.287624 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.338227, 0.270533), 11.921334 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.446875, -0.058481), 5.708551 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.602047, 0.500280), 0.307909 * speedMult)
			Turn(P.lturret, x_axis, A(-0.602047, -0.500280), 0.307909 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.010518, -0.000259), 0.880699 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.397953, 0.499720), 0.307907 * speedMult)
			Turn(P.rturret, x_axis, A(-0.397953, -0.499720), 0.307907 * speedMult)
			Turn(P.torso, x_axis, A(0.019507, 0.000034), 0.438698 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.004998, 0.000203), 0.782651 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.029924, 0.000085), 0.481415 * speedMult)
			Turn(P.spine2, x_axis, A(-0.048877, 0.000060), 0.355956 * speedMult)
			Turn(P.spine3, x_axis, A(0.010756, -0.000135), 0.777675 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 25
		Move(P.base, z_axis, A(-3.534235, 0.010289), 42.446716 * speedMult)
		Move(P.base, y_axis, A(1.726643, -0.005208), 22.152557 * speedMult)
		Turn(P.base, x_axis, A(0.007409, 0.000011), 0.166180 * speedMult)
		Turn(P.base, z_axis, A(-0.004253, -0.000040), 0.107609 * speedMult)
		Turn(P.base, y_axis, A(-0.026739, -0.000266), 0.722661 * speedMult)
		Turn(P.blfoot, x_axis, A(1.271983, 0.303430), 8.794729 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.263117, -0.451164), 0.577937 * speedMult)
		Turn(P.blleg, x_axis, A(-0.655496, -0.080530), 5.080619 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.013272, 0.372613), 1.720974 * speedMult)
		Turn(P.brhinge, y_axis, A(0.675630, 0.469086), 4.487489 * speedMult)
		Turn(P.brleg, x_axis, A(-0.172307, -0.151242), 0.760144 * speedMult)
		Turn(P.fldeco, x_axis, A(0.657660, 0.358011), 2.147462 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.148969, -0.610363), 4.385476 * speedMult)
		Turn(P.flhinge, y_axis, A(0.327158, 0.363854), 0.558457 * speedMult)
		Turn(P.flleg, x_axis, A(0.467840, 0.172704), 1.574588 * speedMult)
		Turn(P.frdeco, x_axis, A(-0.058160, 0.358842), 2.818543 * speedMult)
		Turn(P.frfoot, x_axis, A(0.125698, -0.611057), 5.393469 * speedMult)
		Move(P.frhinge, y_axis, A(2.727273, 3.186940), 16.363642 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.386412, -0.363165), 0.932315 * speedMult)
		Turn(P.frleg, x_axis, A(-0.320978, 0.173199), 0.109193 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.115440, 0.039098), 0.555386 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.246308, -0.283127), 2.081994 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.096736, 0.091969), 1.555392 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.001561, -0.086282), 8.679070 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.656291, 0.270533), 9.541919 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.326768, -0.058481), 3.603197 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.584792, 0.500280), 0.517648 * speedMult)
			Turn(P.lturret, x_axis, A(-0.584792, -0.500280), 0.517650 * speedMult)
			Turn(P.rcannon, x_axis, A(0.019559, -0.000259), 0.902319 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.415208, 0.499720), 0.517654 * speedMult)
			Turn(P.rturret, x_axis, A(-0.415208, -0.499720), 0.517654 * speedMult)
			Turn(P.torso, x_axis, A(0.029962, 0.000034), 0.313649 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.030744, 0.000203), 0.772378 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.005816, 0.000085), 0.723216 * speedMult)
			Turn(P.spine2, x_axis, A(-0.047577, 0.000060), 0.038995 * speedMult)
			Turn(P.spine3, x_axis, A(0.033781, -0.000135), 0.690761 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 30
		Move(P.base, z_axis, A(-3.997171, 0.010289), 13.888099 * speedMult)
		Move(P.base, y_axis, A(1.999985, -0.005208), 8.200264 * speedMult)
		Turn(P.base, x_axis, A(-0.000126, 0.000011), 0.226047 * speedMult)
		Turn(P.base, z_axis, A(-0.000375, -0.000040), 0.116351 * speedMult)
		Turn(P.base, y_axis, A(-0.000819, -0.000266), 0.777619 * speedMult)
		Turn(P.blfoot, x_axis, A(0.901299, 0.303430), 11.120540 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.310728, -0.451164), 1.428318 * speedMult)
		Turn(P.blleg, x_axis, A(-0.310063, -0.080530), 10.362974 * speedMult)
		Turn(P.brfoot, x_axis, A(0.052867, 0.372613), 1.984165 * speedMult)
		Turn(P.brhinge, y_axis, A(0.533273, 0.469086), 4.270706 * speedMult)
		Turn(P.brleg, x_axis, A(-0.120319, -0.151242), 1.559644 * speedMult)
		Turn(P.fldeco, x_axis, A(0.554761, 0.358011), 3.086976 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.971320, -0.610363), 5.329496 * speedMult)
		Turn(P.flhinge, y_axis, A(0.309302, 0.363854), 0.535675 * speedMult)
		Turn(P.flleg, x_axis, A(0.399893, 0.172704), 2.038432 * speedMult)
		Turn(P.frdeco, x_axis, A(0.067108, 0.358842), 3.758058 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.094788, -0.611057), 6.614578 * speedMult)
		Move(P.frhinge, y_axis, A(3.272728, 3.186940), 16.363635 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.373996, -0.363165), 0.372490 * speedMult)
		Turn(P.frleg, x_axis, A(-0.251403, 0.173199), 2.087261 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.117552, 0.039098), 0.063346 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.153722, -0.283127), 2.777560 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.122199, 0.091969), 0.763890 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.817126, -0.086282), 24.466959 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.798329, 0.270533), 4.261132 * speedMult)
		Turn(P.mrleg, z_axis, A(0.397589, -0.058481), 21.730716 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.561727, 0.500280), 0.691926 * speedMult)
			Turn(P.lturret, x_axis, A(-0.561727, -0.500280), 0.691926 * speedMult)
			Turn(P.rcannon, x_axis, A(0.048296, -0.000259), 0.862115 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.438273, 0.499720), 0.691925 * speedMult)
			Turn(P.rturret, x_axis, A(-0.438273, -0.499720), 0.691925 * speedMult)
			Turn(P.torso, x_axis, A(0.032347, 0.000034), 0.071540 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.054384, 0.000203), 0.709189 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.019857, 0.000085), 0.770215 * speedMult)
			Turn(P.spine2, x_axis, A(-0.033462, 0.000060), 0.423441 * speedMult)
			Turn(P.spine3, x_axis, A(0.047708, -0.000135), 0.417788 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 35
		Move(P.base, z_axis, A(-3.383462, 0.010289), 18.411276 * speedMult)
		Move(P.base, y_axis, A(1.734627, -0.005208), 7.960739 * speedMult)
		Turn(P.base, x_axis, A(-0.007627, 0.000011), 0.225028 * speedMult)
		Turn(P.base, z_axis, A(0.003529, -0.000040), 0.117122 * speedMult)
		Turn(P.base, y_axis, A(0.025158, -0.000266), 0.779303 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.051541, 0.303430), 28.585176 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.458060, -0.451164), 4.419953 * speedMult)
		Turn(P.blleg, x_axis, A(0.345808, -0.080530), 19.676151 * speedMult)
		Turn(P.brfoot, x_axis, A(0.163216, 0.372613), 3.310480 * speedMult)
		Turn(P.brhinge, y_axis, A(0.407414, 0.469086), 3.775782 * speedMult)
		Turn(P.brleg, x_axis, A(-0.078840, -0.151242), 1.244365 * speedMult)
		Turn(P.fldeco, x_axis, A(0.438440, 0.358011), 3.489625 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.766307, -0.610363), 6.150364 * speedMult)
		Turn(P.flhinge, y_axis, A(0.295351, 0.363854), 0.418523 * speedMult)
		Turn(P.flleg, x_axis, A(0.316441, 0.172704), 2.503553 * speedMult)
		Turn(P.frdeco, x_axis, A(0.187903, 0.358842), 3.623841 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.327472, -0.611057), 6.980514 * speedMult)
		Move(P.frhinge, y_axis, A(3.818182, 3.186940), 16.363642 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.372677, -0.363165), 0.039563 * speedMult)
		Turn(P.frleg, x_axis, A(-0.157627, 0.173199), 2.813264 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.105124, 0.039098), 0.372820 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.035433, -0.283127), 3.548691 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.114868, 0.091969), 0.219944 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.526882, -0.086282), 8.707319 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.674398, 0.270533), 3.717921 * speedMult)
		Turn(P.mrleg, z_axis, A(0.243547, -0.058481), 4.621244 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.534434, 0.500280), 0.818800 * speedMult)
			Turn(P.lturret, x_axis, A(-0.534434, -0.500280), 0.818800 * speedMult)
			Turn(P.rcannon, x_axis, A(0.073724, -0.000259), 0.762853 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.465566, 0.499720), 0.818796 * speedMult)
			Turn(P.rturret, x_axis, A(-0.465566, -0.499720), 0.818796 * speedMult)
			Turn(P.torso, x_axis, A(0.026019, 0.000034), 0.189840 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.074297, 0.000203), 0.597411 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.040183, 0.000085), 0.609756 * speedMult)
			Turn(P.spine2, x_axis, A(-0.010334, 0.000060), 0.693832 * speedMult)
			Turn(P.spine3, x_axis, A(0.048784, -0.000135), 0.032284 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 40
		Move(P.base, z_axis, A(-1.858410, 0.010289), 45.751566 * speedMult)
		Move(P.base, y_axis, A(1.002041, -0.005208), 21.977577 * speedMult)
		Turn(P.base, x_axis, A(-0.013074, 0.000011), 0.163397 * speedMult)
		Turn(P.base, z_axis, A(0.007191, -0.000040), 0.109868 * speedMult)
		Turn(P.base, y_axis, A(0.049411, -0.000266), 0.727592 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.247084, 0.303430), 5.866306 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.685199, -0.451164), 6.814172 * speedMult)
		Turn(P.blleg, x_axis, A(0.349466, -0.080530), 0.109742 * speedMult)
		Turn(P.brfoot, x_axis, A(0.354359, 0.372613), 5.734266 * speedMult)
		Turn(P.brhinge, y_axis, A(0.303772, 0.469086), 3.109263 * speedMult)
		Turn(P.brleg, x_axis, A(-0.094501, -0.151242), 0.469831 * speedMult)
		Turn(P.fldeco, x_axis, A(0.322119, 0.358011), 3.489626 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.548142, -0.610363), 6.544949 * speedMult)
		Turn(P.flhinge, y_axis, A(0.288222, 0.363854), 0.213872 * speedMult)
		Turn(P.flleg, x_axis, A(0.224092, 0.172704), 2.770473 * speedMult)
		Turn(P.frdeco, x_axis, A(0.322119, 0.358842), 4.026488 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.571194, -0.611057), 7.311678 * speedMult)
		Move(P.frhinge, y_axis, A(4.363637, 3.186940), 16.363635 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.375930, -0.363165), 0.097598 * speedMult)
		Turn(P.frleg, x_axis, A(-0.050417, 0.173199), 3.216296 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.093458, 0.039098), 0.350001 * speedMult)
		Turn(P.mlhinge, y_axis, A(0.101077, -0.283127), 4.095293 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.080709, 0.091969), 1.024751 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.265861, -0.086282), 7.830631 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.520159, 0.270533), 4.627182 * speedMult)
		Turn(P.mrleg, z_axis, A(0.100233, -0.058481), 4.299423 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.504782, 0.500280), 0.889571 * speedMult)
			Turn(P.lturret, x_axis, A(-0.504782, -0.500280), 0.889571 * speedMult)
			Turn(P.rcannon, x_axis, A(0.094102, -0.000259), 0.611322 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.495218, 0.499720), 0.889572 * speedMult)
			Turn(P.rturret, x_axis, A(-0.495218, -0.499720), 0.889572 * speedMult)
			Turn(P.torso, x_axis, A(0.012683, 0.000034), 0.400084 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.089121, 0.000203), 0.444704 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.049685, 0.000085), 0.285058 * speedMult)
			Turn(P.spine2, x_axis, A(0.015577, 0.000060), 0.777339 * speedMult)
			Turn(P.spine3, x_axis, A(0.036720, -0.000135), 0.361917 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 45
		Move(P.base, z_axis, A(0.167209, 0.010289), 60.768571 * speedMult)
		Move(P.base, y_axis, A(-0.000443, -0.005208), 30.074501 * speedMult)
		Turn(P.base, x_axis, A(-0.014999, 0.000011), 0.057755 * speedMult)
		Turn(P.base, z_axis, A(0.010361, -0.000040), 0.095088 * speedMult)
		Turn(P.base, y_axis, A(0.070279, -0.000266), 0.626037 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.253808, 0.303430), 0.201705 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.930842, -0.451164), 7.369312 * speedMult)
		Turn(P.blleg, x_axis, A(-0.027824, -0.080530), 11.318713 * speedMult)
		Turn(P.brfoot, x_axis, A(0.650180, 0.372613), 8.874653 * speedMult)
		Turn(P.brhinge, y_axis, A(0.223616, 0.469086), 2.404663 * speedMult)
		Turn(P.brleg, x_axis, A(-0.201425, -0.151242), 3.207714 * speedMult)
		Turn(P.fldeco, x_axis, A(0.196851, 0.358011), 3.758060 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.333751, -0.610363), 6.431734 * speedMult)
		Turn(P.flhinge, y_axis, A(0.290334, 0.363854), 0.063367 * speedMult)
		Turn(P.flleg, x_axis, A(0.132071, 0.172704), 2.760618 * speedMult)
		Turn(P.frdeco, x_axis, A(0.474231, 0.358842), 4.563356 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.844155, -0.611057), 8.188832 * speedMult)
		Move(P.frhinge, y_axis, A(4.909091, 3.186940), 16.363635 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.378548, -0.363165), 0.078541 * speedMult)
		Turn(P.frleg, x_axis, A(0.078435, 0.173199), 3.865586 * speedMult)
		Turn(P.mlfoot, z_axis, A(-0.209268, 0.039098), 9.081761 * speedMult)
		Turn(P.mlhinge, y_axis, A(0.094970, -0.283127), 0.183216 * speedMult)
		Turn(P.mlleg, z_axis, A(0.302472, 0.091969), 11.495440 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.051438, -0.086282), 6.432694 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.339390, 0.270533), 5.423078 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.026427, -0.058481), 3.799791 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.474802, 0.500280), 0.899401 * speedMult)
			Turn(P.lturret, x_axis, A(-0.474802, -0.500280), 0.899401 * speedMult)
			Turn(P.rcannon, x_axis, A(0.108032, -0.000259), 0.417911 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.525198, 0.499720), 0.899401 * speedMult)
			Turn(P.rturret, x_axis, A(-0.525198, -0.499720), 0.899401 * speedMult)
			Turn(P.torso, x_axis, A(-0.004070, 0.000034), 0.502567 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.097839, 0.000203), 0.261531 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.045804, 0.000085), 0.116421 * speedMult)
			Turn(P.spine2, x_axis, A(0.037293, 0.000060), 0.651468 * speedMult)
			Turn(P.spine3, x_axis, A(0.014765, -0.000135), 0.658633 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 50
		Move(P.base, z_axis, A(2.147790, 0.010289), 59.417428 * speedMult)
		Move(P.base, y_axis, A(-1.002808, -0.005208), 30.070953 * speedMult)
		Turn(P.base, x_axis, A(-0.012884, 0.000011), 0.063444 * speedMult)
		Turn(P.base, z_axis, A(0.012821, -0.000040), 0.073792 * speedMult)
		Turn(P.base, y_axis, A(0.086332, -0.000266), 0.481587 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.215809, 0.303430), 1.139965 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.812917, -0.451164), 3.537764 * speedMult)
		Turn(P.blleg, x_axis, A(0.079740, -0.080530), 3.226925 * speedMult)
		Turn(P.brfoot, x_axis, A(1.065921, 0.372613), 12.472222 * speedMult)
		Turn(P.brhinge, y_axis, A(0.165654, 0.469086), 1.738878 * speedMult)
		Turn(P.brleg, x_axis, A(-0.417047, -0.151242), 6.468662 * speedMult)
		Turn(P.fldeco, x_axis, A(0.093951, 0.358011), 3.086976 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.138838, -0.610363), 5.847403 * speedMult)
		Turn(P.flhinge, y_axis, A(0.303246, 0.363854), 0.387348 * speedMult)
		Turn(P.flleg, x_axis, A(0.050315, 0.172704), 2.452691 * speedMult)
		Turn(P.frdeco, x_axis, A(0.675555, 0.358842), 6.039733 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.201184, -0.611057), 10.710856 * speedMult)
		Move(P.frhinge, y_axis, A(5.454546, 3.186940), 16.363649 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.377166, -0.363165), 0.041459 * speedMult)
		Turn(P.frleg, x_axis, A(0.282005, 0.173199), 6.107102 * speedMult)
		Turn(P.mlfoot, z_axis, A(-0.385877, 0.039098), 5.298269 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.286800, -0.283127), 11.453104 * speedMult)
		Turn(P.mlleg, z_axis, A(0.570794, 0.091969), 8.049670 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.100183, -0.086282), 4.548626 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.146519, 0.270533), 5.786124 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.127262, -0.058481), 3.025064 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.446548, 0.500280), 0.847610 * speedMult)
			Turn(P.lturret, x_axis, A(-0.446548, -0.500280), 0.847610 * speedMult)
			Turn(P.rcannon, x_axis, A(0.114561, -0.000259), 0.195867 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.553452, 0.499720), 0.847614 * speedMult)
			Turn(P.rturret, x_axis, A(-0.553452, -0.499720), 0.847614 * speedMult)
			Turn(P.torso, x_axis, A(-0.019726, 0.000034), 0.469681 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.099853, 0.000203), 0.060438 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.029586, 0.000085), 0.486542 * speedMult)
			Turn(P.spine2, x_axis, A(0.048963, 0.000060), 0.350122 * speedMult)
			Turn(P.spine3, x_axis, A(-0.011166, -0.000135), 0.777946 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 55
		Move(P.base, z_axis, A(3.549858, 0.010289), 42.062037 * speedMult)
		Move(P.base, y_axis, A(-1.735065, -0.005208), 21.967735 * speedMult)
		Turn(P.base, x_axis, A(-0.007299, 0.000011), 0.167554 * speedMult)
		Turn(P.base, z_axis, A(0.014402, -0.000040), 0.047441 * speedMult)
		Turn(P.base, y_axis, A(0.096470, -0.000266), 0.304146 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.098652, 0.303430), 3.514699 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.727132, -0.451164), 2.573546 * speedMult)
		Turn(P.blleg, x_axis, A(0.093769, -0.080530), 0.420859 * speedMult)
		Turn(P.brfoot, x_axis, A(1.525317, 0.372613), 13.781877 * speedMult)
		Turn(P.brhinge, y_axis, A(0.127443, 0.469086), 1.146338 * speedMult)
		Turn(P.brleg, x_axis, A(-0.686265, -0.151242), 8.076528 * speedMult)
		Turn(P.fldeco, x_axis, A(0.000000, 0.358011), 2.818544 * speedMult)
		Turn(P.flfoot, x_axis, A(0.023854, -0.610363), 4.880750 * speedMult)
		Turn(P.flhinge, y_axis, A(0.327377, 0.363854), 0.723940 * speedMult)
		Turn(P.flleg, x_axis, A(-0.011313, 0.172704), 1.848822 * speedMult)
		Turn(P.frdeco, x_axis, A(0.935041, 0.358842), 7.784552 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.603410, -0.611057), 12.066790 * speedMult)
		Move(P.frhinge, y_axis, A(6.000001, 3.186940), 16.363635 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.372489, -0.363165), 0.140324 * speedMult)
		Turn(P.frleg, x_axis, A(0.556583, 0.173199), 8.237338 * speedMult)
		Turn(P.mlfoot, z_axis, A(-0.181719, 0.039098), 6.124723 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.631003, -0.283127), 10.326093 * speedMult)
		Turn(P.mlleg, z_axis, A(0.514708, 0.091969), 1.682594 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.178506, -0.086282), 2.349682 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.035905, 0.270533), 5.472721 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.188023, -0.058481), 1.822817 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.421957, 0.500280), 0.737746 * speedMult)
			Turn(P.lturret, x_axis, A(-0.421957, -0.500280), 0.737746 * speedMult)
			Turn(P.rcannon, x_axis, A(0.113241, -0.000259), 0.039593 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.578043, 0.499720), 0.737743 * speedMult)
			Turn(P.rturret, x_axis, A(-0.578043, -0.499720), 0.737742 * speedMult)
			Turn(P.torso, x_axis, A(-0.030069, 0.000034), 0.310287 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.095027, 0.000203), 0.144793 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.005399, 0.000085), 0.725611 * speedMult)
			Turn(P.spine2, x_axis, A(0.047446, 0.000060), 0.045529 * speedMult)
			Turn(P.spine3, x_axis, A(-0.034090, -0.000135), 0.687718 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 60
		Move(P.base, z_axis, A(3.995765, 0.010289), 13.377221 * speedMult)
		Move(P.base, y_axis, A(-1.999981, -0.005208), 7.947464 * speedMult)
		Turn(P.base, x_axis, A(0.000252, 0.000011), 0.226533 * speedMult)
		Turn(P.base, z_axis, A(0.014997, -0.000040), 0.017840 * speedMult)
		Turn(P.base, y_axis, A(0.099999, -0.000266), 0.105866 * speedMult)
		Turn(P.blfoot, x_axis, A(0.072212, 0.303430), 5.125922 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.660353, -0.451164), 2.003378 * speedMult)
		Turn(P.blleg, x_axis, A(0.030883, -0.080530), 1.886574 * speedMult)
		Turn(P.brfoot, x_axis, A(1.317241, 0.372613), 6.242280 * speedMult)
		Turn(P.brhinge, y_axis, A(0.121429, 0.469086), 0.180413 * speedMult)
		Turn(P.brleg, x_axis, A(-0.472003, -0.151242), 6.427855 * speedMult)
		Turn(P.fldeco, x_axis, A(-0.062596, 0.358011), 1.877892 * speedMult)
		Turn(P.flfoot, x_axis, A(0.145857, -0.610363), 3.660093 * speedMult)
		Turn(P.flhinge, y_axis, A(0.362181, 0.363854), 1.044093 * speedMult)
		Turn(P.flleg, x_axis, A(-0.044050, 0.172704), 0.982126 * speedMult)
		Turn(P.frdeco, x_axis, A(0.988727, 0.358842), 1.610591 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.721081, -0.611057), 3.530130 * speedMult)
		Move(P.frhinge, y_axis, A(5.430210, 3.186940), 17.093740 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.368254, -0.363165), 0.127042 * speedMult)
		Turn(P.frleg, x_axis, A(0.695578, 0.173199), 4.169823 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.556268, 0.039098), 22.139630 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.822783, -0.283127), 5.753404 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.184520, 0.091969), 20.976823 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.184608, -0.086282), 0.183063 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.188065, 0.270533), 4.564788 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.196467, -0.058481), 0.253339 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.402712, 0.500280), 0.577337 * speedMult)
			Turn(P.lturret, x_axis, A(-0.402712, -0.500280), 0.577337 * speedMult)
			Turn(P.rcannon, x_axis, A(0.104163, -0.000259), 0.272347 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.597288, 0.499720), 0.577342 * speedMult)
			Turn(P.rturret, x_axis, A(-0.597288, -0.499720), 0.577344 * speedMult)
			Turn(P.torso, x_axis, A(-0.032312, 0.000034), 0.067315 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.083690, 0.000203), 0.340107 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.020242, 0.000085), 0.769237 * speedMult)
			Turn(P.spine2, x_axis, A(0.033148, 0.000060), 0.428918 * speedMult)
			Turn(P.spine3, x_axis, A(-0.047832, -0.000135), 0.412251 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 65
		Move(P.base, z_axis, A(3.365406, 0.010289), 18.910797 * speedMult)
		Move(P.base, y_axis, A(-1.726196, -0.005208), 8.213539 * speedMult)
		Turn(P.base, x_axis, A(0.007735, 0.000011), 0.224495 * speedMult)
		Turn(P.base, z_axis, A(0.014564, -0.000040), 0.012983 * speedMult)
		Turn(P.base, y_axis, A(0.096677, -0.000266), 0.099666 * speedMult)
		Turn(P.blfoot, x_axis, A(0.270031, 0.303430), 5.934580 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.602340, -0.451164), 1.740375 * speedMult)
		Turn(P.blleg, x_axis, A(-0.077985, -0.080530), 3.266037 * speedMult)
		Turn(P.brfoot, x_axis, A(0.097701, 0.372613), 36.586186 * speedMult)
		Turn(P.brhinge, y_axis, A(0.191861, 0.469086), 2.112954 * speedMult)
		Turn(P.brleg, x_axis, A(0.360653, -0.151242), 24.979657 * speedMult)
		Turn(P.fldeco, x_axis, A(-0.109553, 0.358011), 1.408703 * speedMult)
		Turn(P.flfoot, x_axis, A(0.224263, -0.610363), 2.352177 * speedMult)
		Move(P.flhinge, y_axis, A(0.545455, 3.186940), 16.363639 * speedMult)
		Turn(P.flhinge, y_axis, A(0.407000, 0.363854), 1.344582 * speedMult)
		Turn(P.flleg, x_axis, A(-0.042011, 0.172704), 0.061162 * speedMult)
		Turn(P.frdeco, x_axis, A(0.943989, 0.358842), 1.342151 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.622572, -0.611057), 2.955272 * speedMult)
		Move(P.frhinge, y_axis, A(0.000001, 3.186940), 162.906260 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.374927, -0.363165), 0.200183 * speedMult)
		Turn(P.frleg, x_axis, A(0.646521, 0.173199), 1.471696 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.407754, 0.039098), 4.455437 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.747045, -0.283127), 2.272149 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.115115, 0.091969), 2.082138 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.133127, -0.086282), 1.544429 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.302219, 0.270533), 3.424641 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.154805, -0.058481), 1.249867 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.390132, 0.500280), 0.377385 * speedMult)
			Turn(P.lturret, x_axis, A(-0.390132, -0.500280), 0.377385 * speedMult)
			Turn(P.rcannon, x_axis, A(0.087949, -0.000259), 0.486432 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.609867, 0.499720), 0.377380 * speedMult)
			Turn(P.rturret, x_axis, A(-0.609867, -0.499720), 0.377380 * speedMult)
			Turn(P.torso, x_axis, A(-0.025853, 0.000034), 0.193788 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.066619, 0.000203), 0.512118 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.040431, 0.000085), 0.605666 * speedMult)
			Turn(P.spine2, x_axis, A(0.009923, 0.000060), 0.696777 * speedMult)
			Turn(P.spine3, x_axis, A(-0.048690, -0.000135), 0.025743 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 70
		Move(P.base, z_axis, A(1.828565, 0.010289), 46.105227 * speedMult)
		Move(P.base, y_axis, A(-0.987457, -0.005208), 22.162170 * speedMult)
		Turn(P.base, x_axis, A(0.013135, 0.000011), 0.161989 * speedMult)
		Turn(P.base, z_axis, A(0.013133, -0.000040), 0.042917 * speedMult)
		Turn(P.base, y_axis, A(0.086731, -0.000266), 0.298372 * speedMult)
		Turn(P.blfoot, x_axis, A(0.480065, 0.303430), 6.301019 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.545761, -0.451164), 1.697375 * speedMult)
		Turn(P.blleg, x_axis, A(-0.207853, -0.080530), 3.896051 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.325715, 0.372613), 12.702482 * speedMult)
		Turn(P.brhinge, y_axis, A(0.345511, 0.469086), 4.609502 * speedMult)
		Turn(P.brleg, x_axis, A(0.468828, -0.151242), 3.245258 * speedMult)
		Turn(P.fldeco, x_axis, A(-0.134141, 0.358011), 0.737621 * speedMult)
		Turn(P.flfoot, x_axis, A(0.262502, -0.610363), 1.147169 * speedMult)
		Move(P.flhinge, y_axis, A(1.090909, 3.186940), 16.363639 * speedMult)
		Turn(P.flhinge, y_axis, A(0.462409, 0.363854), 1.662284 * speedMult)
		Turn(P.flleg, x_axis, A(-0.004240, 0.172704), 1.133126 * speedMult)
		Turn(P.frdeco, x_axis, A(0.885828, 0.358842), 1.744815 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.511550, -0.611057), 3.330678 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.371959, -0.363165), 0.089026 * speedMult)
		Turn(P.frleg, x_axis, A(0.597536, 0.173199), 1.469552 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.319563, 0.039098), 2.645721 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.666560, -0.283127), 2.414557 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.095599, 0.091969), 0.585470 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.045049, -0.086282), 2.642343 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.383055, 0.270533), 2.425079 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.079732, -0.058481), 2.252204 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.385080, 0.500280), 0.151563 * speedMult)
			Turn(P.lturret, x_axis, A(-0.385080, -0.500280), 0.151563 * speedMult)
			Turn(P.rcannon, x_axis, A(0.065709, -0.000259), 0.667202 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.614920, 0.499720), 0.151564 * speedMult)
			Turn(P.rturret, x_axis, A(-0.614920, -0.499720), 0.151564 * speedMult)
			Turn(P.torso, x_axis, A(-0.012430, 0.000034), 0.402693 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.044984, 0.000203), 0.649044 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.049730, 0.000085), 0.278958 * speedMult)
			Turn(P.spine2, x_axis, A(-0.015976, 0.000060), 0.776956 * speedMult)
			Turn(P.spine3, x_axis, A(-0.036433, -0.000135), 0.367698 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 75
		Move(P.base, z_axis, A(-0.200801, 0.010289), 60.880982 * speedMult)
		Move(P.base, y_axis, A(0.017258, -0.005208), 30.141449 * speedMult)
		Turn(P.base, x_axis, A(0.014997, 0.000011), 0.055851 * speedMult)
		Turn(P.base, z_axis, A(0.010803, -0.000040), 0.069911 * speedMult)
		Turn(P.base, y_axis, A(0.070843, -0.000266), 0.476633 * speedMult)
		Turn(P.blfoot, x_axis, A(0.701679, 0.303430), 6.648425 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.485964, -0.451164), 1.793900 * speedMult)
		Turn(P.blleg, x_axis, A(-0.344901, -0.080530), 4.111433 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.209533, 0.372613), 3.485443 * speedMult)
		Turn(P.brhinge, y_axis, A(0.594077, 0.469086), 7.457002 * speedMult)
		Turn(P.brleg, x_axis, A(-0.157182, -0.151242), 18.780301 * speedMult)
		Turn(P.fldeco, x_axis, A(-0.187903, 0.358011), 1.612870 * speedMult)
		Turn(P.flfoot, x_axis, A(0.366726, -0.610363), 3.126716 * speedMult)
		Move(P.flhinge, y_axis, A(1.636364, 3.186940), 16.363639 * speedMult)
		Turn(P.flhinge, y_axis, A(0.473734, 0.363854), 0.339733 * speedMult)
		Turn(P.flleg, x_axis, A(-0.171407, 0.172704), 5.014992 * speedMult)
		Turn(P.frdeco, x_axis, A(0.823194, 0.358842), 1.879030 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.422836, -0.611057), 2.661420 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.361017, -0.363165), 0.328259 * speedMult)
		Turn(P.frleg, x_axis, A(0.567847, 0.173199), 0.890678 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.265947, 0.039098), 1.608489 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.576224, -0.283127), 2.710086 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.106542, 0.091969), 0.328276 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.282735, -0.086282), 7.130572 * speedMult)
		Turn(P.mrhinge, y_axis, A(-0.301249, 0.270533), 2.454189 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.363193, -0.058481), 8.503854 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.387901, 0.500280), 0.084634 * speedMult)
			Turn(P.lturret, x_axis, A(-0.387901, -0.500280), 0.084634 * speedMult)
			Turn(P.rcannon, x_axis, A(0.038967, -0.000259), 0.802256 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.612099, 0.499720), 0.084633 * speedMult)
			Turn(P.rturret, x_axis, A(-0.612099, -0.499720), 0.084633 * speedMult)
			Turn(P.torso, x_axis, A(0.004341, 0.000034), 0.503133 * speedMult)
			Turn(P.torsobase, y_axis, A(-0.020268, 0.000203), 0.741501 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.045634, 0.000085), 0.122888 * speedMult)
			Turn(P.spine2, x_axis, A(-0.037571, 0.000060), 0.647861 * speedMult)
			Turn(P.spine3, x_axis, A(-0.014363, -0.000135), 0.662099 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 80
		Move(P.base, z_axis, A(-2.176081, 0.010289), 59.258392 * speedMult)
		Move(P.base, y_axis, A(1.017319, -0.005208), 30.001831 * speedMult)
		Turn(P.base, x_axis, A(0.012819, 0.000011), 0.065331 * speedMult)
		Turn(P.base, z_axis, A(0.007733, -0.000040), 0.092115 * speedMult)
		Turn(P.base, y_axis, A(0.050102, -0.000266), 0.622240 * speedMult)
		Turn(P.blfoot, x_axis, A(0.949145, 0.303430), 7.423967 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.421117, -0.451164), 1.945417 * speedMult)
		Turn(P.blleg, x_axis, A(-0.488655, -0.080530), 4.312612 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.122192, 0.372613), 2.620241 * speedMult)
		Turn(P.brhinge, y_axis, A(0.570160, 0.469086), 0.717530 * speedMult)
		Turn(P.brleg, x_axis, A(-0.163438, -0.151242), 0.187672 * speedMult)
		Turn(P.fldeco, x_axis, A(-0.152112, 0.358011), 1.073731 * speedMult)
		Turn(P.flfoot, x_axis, A(0.303891, -0.610363), 1.885047 * speedMult)
		Move(P.flhinge, y_axis, A(2.181818, 3.186940), 16.363639 * speedMult)
		Turn(P.flhinge, y_axis, A(0.418293, 0.363854), 1.663224 * speedMult)
		Turn(P.flleg, x_axis, A(-0.323115, 0.172704), 4.551242 * speedMult)
		Turn(P.frdeco, x_axis, A(0.729242, 0.358842), 2.818542 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.299060, -0.611057), 3.713257 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.344687, -0.363165), 0.489899 * speedMult)
		Turn(P.frleg, x_axis, A(0.523100, 0.173199), 1.342413 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.223863, 0.039098), 1.262512 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.467036, -0.283127), 3.275631 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.127217, 0.091969), 0.620247 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.412209, -0.086282), 3.884225 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.181031, 0.270533), 14.468409 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.554592, -0.058481), 5.741965 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.398403, 0.500280), 0.315035 * speedMult)
			Turn(P.lturret, x_axis, A(-0.398403, -0.500280), 0.315035 * speedMult)
			Turn(P.rcannon, x_axis, A(0.009555, -0.000259), 0.882342 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.601597, 0.499720), 0.315040 * speedMult)
			Turn(P.rturret, x_axis, A(-0.601597, -0.499720), 0.315038 * speedMult)
			Turn(P.torso, x_axis, A(0.019943, 0.000034), 0.468052 * speedMult)
			Turn(P.torsobase, y_axis, A(0.005838, 0.000203), 0.783160 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.029246, 0.000085), 0.491633 * speedMult)
			Turn(P.spine2, x_axis, A(-0.049047, 0.000060), 0.344264 * speedMult)
			Turn(P.spine3, x_axis, A(0.011575, -0.000135), 0.778162 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 85
		Move(P.base, z_axis, A(-3.565232, 0.010289), 41.674511 * speedMult)
		Move(P.base, y_axis, A(1.743370, -0.005208), 21.781540 * speedMult)
		Turn(P.base, x_axis, A(0.007188, 0.000011), 0.168916 * speedMult)
		Turn(P.base, z_axis, A(0.004132, -0.000040), 0.108008 * speedMult)
		Turn(P.base, y_axis, A(0.025928, -0.000266), 0.725220 * speedMult)
		Turn(P.blfoot, x_axis, A(1.248945, 0.303430), 8.994007 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.352285, -0.451164), 2.064952 * speedMult)
		Turn(P.blleg, x_axis, A(-0.651502, -0.080530), 4.885410 * speedMult)
		Turn(P.brfoot, x_axis, A(-0.039590, 0.372613), 2.478053 * speedMult)
		Turn(P.brhinge, y_axis, A(0.551322, 0.469086), 0.565122 * speedMult)
		Turn(P.brleg, x_axis, A(-0.147764, -0.151242), 0.470223 * speedMult)
		Turn(P.fldeco, x_axis, A(-0.058160, 0.358011), 2.818543 * speedMult)
		Turn(P.flfoot, x_axis, A(0.124828, -0.610363), 5.371879 * speedMult)
		Move(P.flhinge, y_axis, A(2.727273, 3.186940), 16.363642 * speedMult)
		Turn(P.flhinge, y_axis, A(0.387507, 0.363854), 0.923578 * speedMult)
		Turn(P.flleg, x_axis, A(-0.319842, 0.172704), 0.098178 * speedMult)
		Turn(P.frdeco, x_axis, A(0.657660, 0.358842), 2.147462 * speedMult)
		Turn(P.frfoot, x_axis, A(-1.151770, -0.611057), 4.418721 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.326017, -0.363165), 0.560104 * speedMult)
		Turn(P.frleg, x_axis, A(0.470037, 0.173199), 1.591878 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.176941, 0.039098), 1.407679 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.328782, -0.283127), 4.147627 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.138419, 0.091969), 0.336059 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.082694, -0.086282), 9.885440 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.586830, 0.270533), 12.173971 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.393176, -0.058481), 4.842470 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.415864, 0.500280), 0.523854 * speedMult)
			Turn(P.lturret, x_axis, A(-0.415864, -0.500280), 0.523854 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.020511, -0.000259), 0.901985 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.584135, 0.499720), 0.523852 * speedMult)
			Turn(P.rturret, x_axis, A(-0.584135, -0.499720), 0.523853 * speedMult)
			Turn(P.torso, x_axis, A(0.030173, 0.000034), 0.306900 * speedMult)
			Turn(P.torsobase, y_axis, A(0.031543, 0.000203), 0.771162 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.004981, 0.000085), 0.727958 * speedMult)
			Turn(P.spine2, x_axis, A(-0.047311, 0.000060), 0.052062 * speedMult)
			Turn(P.spine3, x_axis, A(0.034396, -0.000135), 0.684628 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 90
		Move(P.base, z_axis, A(-3.994077, 0.010289), 12.865369 * speedMult)
		Move(P.base, y_axis, A(1.999836, -0.005208), 7.693977 * speedMult)
		Turn(P.base, x_axis, A(-0.000378, 0.000011), 0.227002 * speedMult)
		Turn(P.base, z_axis, A(0.000249, -0.000040), 0.116501 * speedMult)
		Turn(P.base, y_axis, A(-0.000022, -0.000266), 0.778506 * speedMult)
		Turn(P.blfoot, x_axis, A(0.901162, 0.303430), 10.433496 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.311713, -0.451164), 1.217175 * speedMult)
		Turn(P.blleg, x_axis, A(-0.310025, -0.080530), 10.244302 * speedMult)
		Turn(P.brfoot, x_axis, A(0.050584, 0.372613), 2.705221 * speedMult)
		Turn(P.brhinge, y_axis, A(0.531867, 0.469086), 0.583649 * speedMult)
		Turn(P.brleg, x_axis, A(-0.117050, -0.151242), 0.921417 * speedMult)
		Turn(P.fldeco, x_axis, A(0.067108, 0.358011), 3.758058 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.094482, -0.610363), 6.579316 * speedMult)
		Move(P.flhinge, y_axis, A(3.272728, 3.186940), 16.363635 * speedMult)
		Turn(P.flhinge, y_axis, A(0.375257, 0.363854), 0.367517 * speedMult)
		Turn(P.flleg, x_axis, A(-0.251162, 0.172704), 2.060417 * speedMult)
		Turn(P.frdeco, x_axis, A(0.554761, 0.358842), 3.086976 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.972372, -0.611057), 5.381933 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.308196, -0.363165), 0.534633 * speedMult)
		Turn(P.frleg, x_axis, A(0.401006, 0.173199), 2.070924 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.119461, 0.039098), 1.724385 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.154752, -0.283127), 5.220895 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.124714, 0.091969), 0.411136 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.814076, -0.086282), 26.903120 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.796893, 0.270533), 6.301895 * speedMult)
		Turn(P.mrleg, z_axis, A(0.394943, -0.058481), 23.643597 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.439091, 0.500280), 0.696782 * speedMult)
			Turn(P.lturret, x_axis, A(-0.439091, -0.500280), 0.696782 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.049172, -0.000259), 0.859828 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.560909, 0.499720), 0.696784 * speedMult)
			Turn(P.rturret, x_axis, A(-0.560909, -0.499720), 0.696784 * speedMult)
			Turn(P.torso, x_axis, A(0.032276, 0.000034), 0.063085 * speedMult)
			Turn(P.torsobase, y_axis, A(0.055087, 0.000203), 0.706328 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.020626, 0.000085), 0.768203 * speedMult)
			Turn(P.spine2, x_axis, A(-0.032833, 0.000060), 0.434365 * speedMult)
			Turn(P.spine3, x_axis, A(0.047953, -0.000135), 0.406684 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 95
		Move(P.base, z_axis, A(-3.347111, 0.010289), 19.408972 * speedMult)
		Move(P.base, y_axis, A(1.717644, -0.005208), 8.465767 * speedMult)
		Turn(P.base, x_axis, A(-0.007843, 0.000011), 0.223946 * speedMult)
		Turn(P.base, z_axis, A(-0.003652, -0.000040), 0.117013 * speedMult)
		Turn(P.base, y_axis, A(-0.025971, -0.000266), 0.778466 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.050570, 0.303430), 28.551966 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.358015, -0.451164), 1.389051 * speedMult)
		Turn(P.blleg, x_axis, A(0.359396, -0.080530), 20.082628 * speedMult)
		Turn(P.brfoot, x_axis, A(0.173703, 0.372613), 3.693565 * speedMult)
		Turn(P.brhinge, y_axis, A(0.511515, 0.469086), 0.610571 * speedMult)
		Turn(P.brleg, x_axis, A(-0.096920, -0.151242), 0.603894 * speedMult)
		Turn(P.fldeco, x_axis, A(0.187903, 0.358011), 3.623841 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.325821, -0.610363), 6.940168 * speedMult)
		Move(P.flhinge, y_axis, A(3.818182, 3.186940), 16.363642 * speedMult)
		Turn(P.flhinge, y_axis, A(0.373968, 0.363854), 0.038641 * speedMult)
		Turn(P.flleg, x_axis, A(-0.158507, 0.172704), 2.779635 * speedMult)
		Turn(P.frdeco, x_axis, A(0.438440, 0.358842), 3.489625 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.765735, -0.611057), 6.199096 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.294359, -0.363165), 0.415101 * speedMult)
		Turn(P.frleg, x_axis, A(0.316442, 0.173199), 2.536916 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.058717, 0.039098), 1.822315 * speedMult)
		Turn(P.mlhinge, y_axis, A(0.051572, -0.283127), 6.189733 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.077751, 0.091969), 1.408894 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.616642, -0.086282), 5.923047 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.739061, 0.270533), 1.734976 * speedMult)
		Turn(P.mrleg, z_axis, A(0.301641, -0.058481), 2.799076 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.466489, 0.500280), 0.821967 * speedMult)
			Turn(P.lturret, x_axis, A(-0.466489, -0.500280), 0.821967 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.074464, -0.000259), 0.758763 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.533511, 0.499720), 0.821965 * speedMult)
			Turn(P.rturret, x_axis, A(-0.533511, -0.499720), 0.821965 * speedMult)
			Turn(P.torso, x_axis, A(0.025685, 0.000034), 0.197723 * speedMult)
			Turn(P.torsobase, y_axis, A(0.074857, 0.000203), 0.593105 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.040677, 0.000085), 0.601532 * speedMult)
			Turn(P.spine2, x_axis, A(-0.009510, 0.000060), 0.699670 * speedMult)
			Turn(P.spine3, x_axis, A(0.048593, -0.000135), 0.019201 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 100
		Move(P.base, z_axis, A(-1.798592, 0.010289), 46.455588 * speedMult)
		Move(P.base, y_axis, A(0.972801, -0.005208), 22.345276 * speedMult)
		Turn(P.base, x_axis, A(-0.013195, 0.000011), 0.160569 * speedMult)
		Turn(P.base, z_axis, A(-0.007302, -0.000040), 0.109508 * speedMult)
		Turn(P.base, y_axis, A(-0.050140, -0.000266), 0.725084 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.268991, 0.303430), 6.552614 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.454215, -0.451164), 2.886013 * speedMult)
		Turn(P.blleg, x_axis, A(0.382227, -0.080530), 0.684941 * speedMult)
		Turn(P.brfoot, x_axis, A(0.358025, 0.372613), 5.529669 * speedMult)
		Turn(P.brhinge, y_axis, A(0.491949, 0.469086), 0.586989 * speedMult)
		Turn(P.brleg, x_axis, A(-0.121111, -0.151242), 0.725725 * speedMult)
		Turn(P.fldeco, x_axis, A(0.322119, 0.358011), 4.026488 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.568341, -0.610363), 7.275598 * speedMult)
		Move(P.flhinge, y_axis, A(4.363637, 3.186940), 16.363635 * speedMult)
		Turn(P.flhinge, y_axis, A(0.377119, 0.363854), 0.094510 * speedMult)
		Turn(P.flleg, x_axis, A(-0.052357, 0.172704), 3.184517 * speedMult)
		Turn(P.frdeco, x_axis, A(0.322119, 0.358842), 3.489626 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.546518, -0.611057), 6.576514 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.287407, -0.363165), 0.208566 * speedMult)
		Turn(P.frleg, x_axis, A(0.223249, 0.173199), 2.795793 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.015898, 0.039098), 1.284583 * speedMult)
		Turn(P.mlhinge, y_axis, A(0.272017, -0.283127), 6.613334 * speedMult)
		Turn(P.mlleg, z_axis, A(-0.005116, 0.091969), 2.179059 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.417053, -0.086282), 5.987645 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.655175, 0.270533), 2.516586 * speedMult)
		Turn(P.mrleg, z_axis, A(0.200022, -0.058481), 3.048581 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.496184, 0.500280), 0.890848 * speedMult)
			Turn(P.lturret, x_axis, A(-0.496184, -0.500280), 0.890848 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.094654, -0.000259), 0.605712 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.503816, 0.499720), 0.890847 * speedMult)
			Turn(P.rturret, x_axis, A(-0.503816, -0.499720), 0.890847 * speedMult)
			Turn(P.torso, x_axis, A(0.012176, 0.000034), 0.405275 * speedMult)
			Turn(P.torsobase, y_axis, A(0.089499, 0.000203), 0.439250 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.049772, 0.000085), 0.272839 * speedMult)
			Turn(P.spine2, x_axis, A(0.016374, 0.000060), 0.776518 * speedMult)
			Turn(P.spine3, x_axis, A(0.036144, -0.000135), 0.373454 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 105
		Move(P.base, z_axis, A(0.234379, 0.010289), 60.989137 * speedMult)
		Move(P.base, y_axis, A(-0.034069, -0.005208), 30.206108 * speedMult)
		Turn(P.base, x_axis, A(-0.014994, 0.000011), 0.053942 * speedMult)
		Turn(P.base, z_axis, A(-0.010452, -0.000040), 0.094500 * speedMult)
		Turn(P.base, y_axis, A(-0.070875, -0.000266), 0.622028 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.344113, 0.303430), 2.253666 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.561952, -0.451164), 3.232096 * speedMult)
		Turn(P.blleg, x_axis, A(0.038810, -0.080530), 10.302527 * speedMult)
		Turn(P.brfoot, x_axis, A(0.625119, 0.372613), 8.012831 * speedMult)
		Turn(P.brhinge, y_axis, A(0.474211, 0.469086), 0.532123 * speedMult)
		Turn(P.brleg, x_axis, A(-0.217571, -0.151242), 2.893786 * speedMult)
		Turn(P.fldeco, x_axis, A(0.474231, 0.358011), 4.563356 * speedMult)
		Turn(P.flfoot, x_axis, A(-0.840568, -0.610363), 8.166804 * speedMult)
		Move(P.flhinge, y_axis, A(4.909091, 3.186940), 16.363635 * speedMult)
		Turn(P.flhinge, y_axis, A(0.379518, 0.363854), 0.071965 * speedMult)
		Turn(P.flleg, x_axis, A(0.075791, 0.172704), 3.844438 * speedMult)
		Turn(P.frdeco, x_axis, A(0.196851, 0.358842), 3.758060 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.331738, -0.611057), 6.443403 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.289733, -0.363165), 0.069766 * speedMult)
		Turn(P.frleg, x_axis, A(0.130747, 0.173199), 2.775072 * speedMult)
		Turn(P.mlfoot, z_axis, A(-0.319002, 0.039098), 10.047005 * speedMult)
		Turn(P.mlhinge, y_axis, A(0.337090, -0.283127), 1.952203 * speedMult)
		Turn(P.mlleg, z_axis, A(0.429414, 0.091969), 13.035876 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.239314, -0.086282), 5.332178 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.545265, 0.270533), 3.297277 * speedMult)
		Turn(P.mrleg, z_axis, A(0.102894, -0.058481), 2.913828 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.526141, 0.500280), 0.898688 * speedMult)
			Turn(P.lturret, x_axis, A(-0.526141, -0.500280), 0.898688 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.108360, -0.000259), 0.411167 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.473859, 0.499720), 0.898690 * speedMult)
			Turn(P.rturret, x_axis, A(-0.473859, -0.499720), 0.898690 * speedMult)
			Turn(P.torso, x_axis, A(-0.004613, 0.000034), 0.503663 * speedMult)
			Turn(P.torsobase, y_axis, A(0.098009, 0.000203), 0.255296 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.045460, 0.000085), 0.129347 * speedMult)
			Turn(P.spine2, x_axis, A(0.037847, 0.000060), 0.644210 * speedMult)
			Turn(P.spine3, x_axis, A(0.013960, -0.000135), 0.665518 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 110
		Move(P.base, z_axis, A(2.204220, 0.010289), 59.095227 * speedMult)
		Move(P.base, y_axis, A(-1.031761, -0.005208), 29.930763 * speedMult)
		Turn(P.base, x_axis, A(-0.012753, 0.000011), 0.067214 * speedMult)
		Turn(P.base, z_axis, A(-0.012886, -0.000040), 0.073018 * speedMult)
		Turn(P.base, y_axis, A(-0.086753, -0.000266), 0.476356 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.307850, 0.303430), 1.087886 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.405212, -0.451164), 4.702187 * speedMult)
		Turn(P.blleg, x_axis, A(0.180286, -0.080530), 4.244291 * speedMult)
		Turn(P.brfoot, x_axis, A(0.990558, 0.372613), 10.963168 * speedMult)
		Turn(P.brhinge, y_axis, A(0.457899, 0.469086), 0.489367 * speedMult)
		Turn(P.brleg, x_axis, A(-0.403536, -0.151242), 5.578953 * speedMult)
		Turn(P.fldeco, x_axis, A(0.675555, 0.358011), 6.039733 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.197754, -0.610363), 10.715568 * speedMult)
		Move(P.flhinge, y_axis, A(5.454546, 3.186940), 16.363649 * speedMult)
		Turn(P.flhinge, y_axis, A(0.377832, 0.363854), 0.050557 * speedMult)
		Turn(P.flleg, x_axis, A(0.279360, 0.172704), 6.107070 * speedMult)
		Turn(P.frdeco, x_axis, A(0.093951, 0.358842), 3.086976 * speedMult)
		Turn(P.frfoot, x_axis, A(-0.137016, -0.611057), 5.841661 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.302858, -0.363165), 0.393762 * speedMult)
		Turn(P.frleg, x_axis, A(0.048870, 0.173199), 2.456314 * speedMult)
		Turn(P.mlfoot, z_axis, A(-0.603104, 0.039098), 8.523046 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.004977, -0.283127), 10.262035 * speedMult)
		Turn(P.mlleg, z_axis, A(0.794988, 0.091969), 10.967228 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.103430, -0.086282), 4.076531 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.416191, 0.270533), 3.872221 * speedMult)
		Turn(P.mrleg, z_axis, A(0.022930, -0.058481), 2.398916 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.554306, 0.500280), 0.844962 * speedMult)
			Turn(P.lturret, x_axis, A(-0.554306, -0.500280), 0.844962 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.114641, -0.000259), 0.188450 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.445694, 0.499720), 0.844957 * speedMult)
			Turn(P.rturret, x_axis, A(-0.445694, -0.499720), 0.844957 * speedMult)
			Turn(P.torso, x_axis, A(-0.020159, 0.000034), 0.466389 * speedMult)
			Turn(P.torsobase, y_axis, A(0.099804, 0.000203), 0.053854 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.028904, 0.000085), 0.496690 * speedMult)
			Turn(P.spine2, x_axis, A(0.049127, 0.000060), 0.338382 * speedMult)
			Turn(P.spine3, x_axis, A(-0.011984, -0.000135), 0.778324 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 115
		Move(P.base, z_axis, A(3.580352, 0.010289), 41.283953 * speedMult)
		Move(P.base, y_axis, A(-1.751549, -0.005208), 21.593628 * speedMult)
		Turn(P.base, x_axis, A(-0.007078, 0.000011), 0.170266 * speedMult)
		Turn(P.base, z_axis, A(-0.014437, -0.000040), 0.046533 * speedMult)
		Turn(P.base, y_axis, A(-0.096688, -0.000266), 0.298050 * speedMult)
		Turn(P.blfoot, x_axis, A(-0.165472, 0.303430), 4.271339 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.308935, -0.451164), 2.888315 * speedMult)
		Turn(P.blleg, x_axis, A(0.188943, -0.080530), 0.259723 * speedMult)
		Turn(P.brfoot, x_axis, A(1.419974, 0.372613), 12.882478 * speedMult)
		Turn(P.brhinge, y_axis, A(0.441364, 0.469086), 0.496046 * speedMult)
		Turn(P.brleg, x_axis, A(-0.653654, -0.151242), 7.503561 * speedMult)
		Turn(P.fldeco, x_axis, A(0.935041, 0.358011), 7.784552 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.601010, -0.610363), 12.097685 * speedMult)
		Move(P.flhinge, y_axis, A(6.000001, 3.186940), 16.363635 * speedMult)
		Turn(P.flhinge, y_axis, A(0.372806, 0.363854), 0.150788 * speedMult)
		Turn(P.flleg, x_axis, A(0.554372, 0.172704), 8.250365 * speedMult)
		Turn(P.frdeco, x_axis, A(0.000000, 0.358842), 2.818544 * speedMult)
		Turn(P.frfoot, x_axis, A(0.025060, -0.611057), 4.862292 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.327167, -0.363165), 0.729269 * speedMult)
		Turn(P.frleg, x_axis, A(-0.012555, 0.173199), 1.842727 * speedMult)
		Turn(P.mlfoot, z_axis, A(-0.487337, 0.039098), 3.473012 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.359007, -0.283127), 10.620899 * speedMult)
		Turn(P.mlleg, z_axis, A(0.795307, 0.091969), 0.009579 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.021578, -0.086282), 2.455547 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.280224, 0.270533), 4.079015 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.027700, -0.058481), 1.518914 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.578751, 0.500280), 0.733339 * speedMult)
			Turn(P.lturret, x_axis, A(-0.578751, -0.500280), 0.733339 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.113069, -0.000259), 0.047180 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.421249, 0.499720), 0.733344 * speedMult)
			Turn(P.rturret, x_axis, A(-0.421249, -0.499720), 0.733344 * speedMult)
			Turn(P.torso, x_axis, A(-0.030275, 0.000034), 0.303493 * speedMult)
			Turn(P.torsobase, y_axis, A(0.094762, 0.000203), 0.151277 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(-0.004562, 0.000085), 0.730252 * speedMult)
			Turn(P.spine2, x_axis, A(0.047174, 0.000060), 0.058590 * speedMult)
			Turn(P.spine3, x_axis, A(-0.034700, -0.000135), 0.681488 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 120
		Move(P.base, z_axis, A(3.992107, 0.010289), 12.352645 * speedMult)
		Move(P.base, y_axis, A(-1.999550, -0.005208), 7.440033 * speedMult)
		Turn(P.base, x_axis, A(0.000504, 0.000011), 0.227456 * speedMult)
		Turn(P.base, z_axis, A(-0.014999, -0.000040), 0.016861 * speedMult)
		Turn(P.base, y_axis, A(-0.099999, -0.000266), 0.099322 * speedMult)
		Turn(P.blfoot, x_axis, A(0.036122, 0.303430), 6.047832 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.253887, -0.451164), 1.651436 * speedMult)
		Turn(P.blleg, x_axis, A(0.104796, -0.080530), 2.524418 * speedMult)
		Turn(P.brfoot, x_axis, A(1.179331, 0.372613), 7.219287 * speedMult)
		Turn(P.brhinge, y_axis, A(0.449857, 0.469086), 0.254783 * speedMult)
		Turn(P.brleg, x_axis, A(-0.416394, -0.151242), 7.117802 * speedMult)
		Turn(P.fldeco, x_axis, A(0.988727, 0.358011), 1.610591 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.721076, -0.610363), 3.601996 * speedMult)
		Move(P.flhinge, y_axis, A(5.430210, 3.186940), 17.093740 * speedMult)
		Turn(P.flhinge, y_axis, A(0.368211, 0.363854), 0.137849 * speedMult)
		Turn(P.flleg, x_axis, A(0.695188, 0.172704), 4.224474 * speedMult)
		Turn(P.frdeco, x_axis, A(-0.058160, 0.358842), 1.744813 * speedMult)
		Turn(P.frfoot, x_axis, A(0.146223, -0.611057), 3.634881 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.362098, -0.363165), 1.047912 * speedMult)
		Turn(P.frleg, x_axis, A(-0.044841, 0.173199), 0.968591 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.209697, 0.039098), 20.911012 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.568411, -0.283127), 6.282115 * speedMult)
		Turn(P.mlleg, z_axis, A(0.052610, 0.091969), 22.280920 * speedMult)
		Turn(P.mrfoot, z_axis, A(0.004403, -0.086282), 0.779449 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.149117, 0.270533), 3.933215 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.040434, -0.058481), 0.382002 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.597800, 0.500280), 0.571488 * speedMult)
			Turn(P.lturret, x_axis, A(-0.597800, -0.500280), 0.571488 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.103750, -0.000259), 0.279572 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.402200, 0.499720), 0.571484 * speedMult)
			Turn(P.rturret, x_axis, A(-0.402200, -0.499720), 0.571484 * speedMult)
			Turn(P.torso, x_axis, A(-0.032237, 0.000034), 0.058851 * speedMult)
			Turn(P.torsobase, y_axis, A(0.083227, 0.000203), 0.346044 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.021008, 0.000085), 0.767115 * speedMult)
			Turn(P.spine2, x_axis, A(0.032514, 0.000060), 0.439781 * speedMult)
			Turn(P.spine3, x_axis, A(-0.048070, -0.000135), 0.401089 * speedMult)
		end
		Sleep(sleepTime)
		speedMult, sleepTime = GetSpeedParams()
		-- Frame: 5 (loop)
		Move(P.base, y_axis, A(-1.742935, -0.005208), 7.698450 * speedMult)
		Move(P.base, z_axis, A(3.401280, 0.010289), 17.724810 * speedMult)
		Move(P.flhinge, y_axis, A(0.000001, 3.186940), 162.906270 * speedMult)
		Move(P.frhinge, y_axis, A(0.545455, 3.186940), 16.363620 * speedMult)
		Turn(P.base, x_axis, A(0.007518, 0.000011), 0.210420 * speedMult)
		Turn(P.base, y_axis, A(-0.096888, -0.000266), 0.093330 * speedMult)
		Turn(P.blfoot, x_axis, A(0.259594, 0.303430), 6.704160 * speedMult)
		Turn(P.blhinge, y_axis, A(-0.226478, -0.451164), 0.822270 * speedMult)
		Turn(P.blleg, x_axis, A(-0.023881, -0.080530), 3.860310 * speedMult)
		Turn(P.brfoot, x_axis, A(0.118814, 0.372613), 31.815510 * speedMult)
		Turn(P.brhinge, y_axis, A(0.551940, 0.469086), 3.062490 * speedMult)
		Turn(P.brleg, x_axis, A(0.287553, -0.151242), 21.118410 * speedMult)
		Turn(P.fldeco, x_axis, A(0.943989, 0.358011), 1.342140 * speedMult)
		Turn(P.flfoot, x_axis, A(-1.622504, -0.610363), 2.957160 * speedMult)
		Turn(P.flhinge, y_axis, A(0.375310, 0.363854), 0.212970 * speedMult)
		Turn(P.flleg, x_axis, A(0.646802, 0.172704), 1.451580 * speedMult)
		Turn(P.frdeco, x_axis, A(-0.102899, 0.358842), 1.342170 * speedMult)
		Turn(P.frfoot, x_axis, A(0.224713, -0.611057), 2.354700 * speedMult)
		Turn(P.frhinge, y_axis, A(-0.406989, -0.363165), 1.346730 * speedMult)
		Turn(P.frleg, x_axis, A(-0.041772, 0.173199), 0.092070 * speedMult)
		Turn(P.mlfoot, z_axis, A(0.102427, 0.039098), 3.218100 * speedMult)
		Turn(P.mlhinge, y_axis, A(-0.489700, -0.283127), 2.361330 * speedMult)
		Turn(P.mlleg, z_axis, A(0.091046, 0.091969), 1.153080 * speedMult)
		Turn(P.mrfoot, z_axis, A(-0.015531, -0.086282), 0.598020 * speedMult)
		Turn(P.mrhinge, y_axis, A(0.026743, 0.270533), 3.671220 * speedMult)
		Turn(P.mrleg, z_axis, A(-0.017869, -0.058481), 0.676950 * speedMult)
		if not isAiming then
			Turn(P.lshoulder, x_axis, A(0.609578, 0.500280), 0.353340 * speedMult)
			Turn(P.lturret, x_axis, A(-0.609578, -0.500280), 0.353340 * speedMult)
			Turn(P.rcannon, x_axis, A(-0.088568, -0.000259), 0.455460 * speedMult)
			Turn(P.rshoulder, x_axis, A(0.390422, 0.499720), 0.353340 * speedMult)
			Turn(P.rturret, x_axis, A(-0.390422, -0.499720), 0.353340 * speedMult)
			Turn(P.torso, x_axis, A(-0.025516, 0.000034), 0.201630 * speedMult)
			Turn(P.torsobase, y_axis, A(0.067244, 0.000203), 0.479490 * speedMult)
		end
		if not posed then
			Turn(P.spine1, x_axis, A(0.039931, 0.000085), 0.567690 * speedMult)
			Turn(P.spine2, x_axis, A(0.010745, 0.000060), 0.653070 * speedMult)
		end
		Sleep(sleepTime)
	end
end

local function StopWalking()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	Move(P.base, y_axis, 0.000000, RESTORE_MOVE)
	Move(P.base, z_axis, 0.000000, RESTORE_MOVE)
	Move(P.flhinge, y_axis, 0.000000, RESTORE_MOVE)
	Move(P.frhinge, y_axis, 0.000000, RESTORE_MOVE)
	Turn(P.base, x_axis, 0.000000, RESTORE_TURN)
	Turn(P.base, y_axis, 0.000000, RESTORE_TURN)
	Turn(P.base, z_axis, 0.000000, RESTORE_TURN)
	Turn(P.blfoot, x_axis, 0.785398, RESTORE_TURN)
	Turn(P.blhinge, y_axis, -0.523599, RESTORE_TURN)
	Turn(P.blleg, x_axis, -0.296706, RESTORE_TURN)
	Turn(P.brfoot, x_axis, 0.785398, RESTORE_TURN)
	Turn(P.brhinge, y_axis, 0.523599, RESTORE_TURN)
	Turn(P.brleg, x_axis, -0.296706, RESTORE_TURN)
	Turn(P.fldeco, x_axis, 0.000000, RESTORE_TURN)
	Turn(P.flfoot, x_axis, -0.663225, RESTORE_TURN)
	Turn(P.flhinge, y_axis, 0.523599, RESTORE_TURN)
	Turn(P.flleg, x_axis, 0.209440, RESTORE_TURN)
	Turn(P.frdeco, x_axis, 0.000000, RESTORE_TURN)
	Turn(P.frfoot, x_axis, -0.663225, RESTORE_TURN)
	Turn(P.frhinge, y_axis, -0.523599, RESTORE_TURN)
	Turn(P.frleg, x_axis, 0.209440, RESTORE_TURN)
	Turn(P.mlfoot, z_axis, 0.785398, RESTORE_TURN)
	Turn(P.mlhinge, y_axis, 0.000000, RESTORE_TURN)
	Turn(P.mlleg, z_axis, -0.314159, RESTORE_TURN)
	Turn(P.mrfoot, z_axis, -0.785398, RESTORE_TURN)
	Turn(P.mrhinge, y_axis, 0.000000, RESTORE_TURN)
	Turn(P.mrleg, z_axis, 0.314159, RESTORE_TURN)
	if not isAiming then
		Turn(P.lcannon, x_axis, 0.349066, RESTORE_TURN)
		Turn(P.lshoulder, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.lshoulder, y_axis, 0.087266, RESTORE_TURN)
		Turn(P.lshoulder, z_axis, 0.349066, RESTORE_TURN)
		Turn(P.lturret, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.rcannon, x_axis, 0.349066, RESTORE_TURN)
		Turn(P.rshoulder, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.rshoulder, y_axis, -0.087266, RESTORE_TURN)
		Turn(P.rshoulder, z_axis, -0.349066, RESTORE_TURN)
		Turn(P.rturret, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.torso, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.torsobase, y_axis, 0.000000, RESTORE_TURN)
	end
	if not posed then
		Turn(P.larm, z_axis, 0.261799, RESTORE_TURN)
		Turn(P.rarm, z_axis, -0.261799, RESTORE_TURN)
		Turn(P.spine1, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.spine2, x_axis, 0.000000, RESTORE_TURN)
		Turn(P.spine3, x_axis, 0.000000, RESTORE_TURN)
	end
end

local SIG_RESTORE = 2
local SIG_ALL_AIM = 2 ^ 28 - 4
local function SigOf(num)
	return 2 ^ (num + 1)
end
local TORSO_SPEED, RESTORE_SPEED = math.rad(150), math.rad(45)
local RESTORE_DELAY = 3000
local eating = false
local myTeam = Spring.GetUnitTeam(unitID)
local ARM = {
	speed = math.rad(200), -- cannon pitch speed
	recoil = 24, -- elmos the barrel kicks back
	kick = 0, -- upward cannon kick on firing, in radians; 0 = only the barrel recoils
	shoulderKick = math.rad(5), -- upper arm swings back at the shoulder on firing
	shoulderSign = 1, -- flip if the upper arm swings forward instead of back
	shoulderJerk = math.rad(4), -- shoulder swings the whole arm back on firing
	jerkSign = 1, -- flip if the arm swings forward instead of back
	rest = { 0.349066, 0.349066 }, -- stance pitch of the left and right cannon
	gap = 2.5 * Game.gameSpeed, -- frames between two volleys of the same arm
	twinWindow = 30, -- frames within which the second laser ray may follow the first
	offset = 75, -- sideways distance of each arm from the torso axis; the arms turn inward by this much to meet at the target
	convergeSign = 1, -- flip if the arms swing outward instead of toward a near target
	laserInside = math.rad(70), -- an arm laser stops its burst when the target is further than this across the body from the torso's facing
	laserOutside = math.rad(30), -- or further than this toward the arm's own side
	toeIn = math.rad(16), -- how far an arm may swing sideways from the torso heading toward its own target
	yawSign = 1, -- flip if the arms swing away from their targets
}
ARM.Yaw = function(num, arm, offset)
	local targetType, _, target = Spring.GetUnitWeaponTarget(unitID, num)
	local distance
	if targetType == 1 then
		distance = Spring.GetUnitSeparation(unitID, target, true)
	elseif targetType == 2 then
		local x, _, z = Spring.GetUnitPosition(unitID)
		distance = math.sqrt((target[1] - x) ^ 2 + (target[3] - z) ^ 2)
	end
	local converge = distance and math.atan2(ARM.offset, distance) * (arm == 1 and -1 or 1) * ARM.convergeSign or 0
	return ARM.yawSign * math.max(-ARM.toeIn, math.min(ARM.toeIn, offset + converge))
end

local armData = {
	side = {
		1,
		2,
		1,
		2,
		[12] = 1,
		[13] = 2,
		[14] = 1,
		[15] = 2,
		[21] = 1,
		[22] = 2,
		[23] = 1,
		[24] = 2,
		[29] = 1,
		[30] = 2,
	},
	kind = {
		"gauss",
		"gauss",
		"napalm",
		"napalm",
		[12] = "laser",
		[13] = "laser",
		[14] = "laser",
		[15] = "laser",
		[21] = "volley",
		[22] = "volley",
		[23] = "volley",
		[24] = "volley",
		[29] = "volley",
		[30] = "volley",
	},
	weapons = { { 1, 3, 12, 14 }, { 2, 4, 13, 15 } },
	flare = {
		P.lflare1,
		P.rflare1,
		P.lflare1,
		P.rflare1,
		[12] = P.lflare1,
		[13] = P.rflare1,
		[14] = P.lflare2,
		[15] = P.rflare2,
		[21] = P.lflare1,
		[22] = P.rflare1,
		[23] = P.lflare1,
		[24] = P.rflare1,
		[29] = P.lflare1,
		[30] = P.rflare1,
	},
	cannon = { P.lcannon, P.rcannon },
	yaw = { P.larm, P.rarm },
	shoulder = { P.lshoulder, P.rshoulder },
	turret = { P.lturret, P.rturret },
	barrel = { P.lbarrel1, P.rbarrel1 },
	pitch = { 0, 0 },
	upper = { 0, 0 },
	jerkBase = { 0, 0 },
	jerkUntil = { -1000, -1000 },
	lastFire = { -1000, -1000 },
	lastKind = { "", "" },
	busyUntil = { 0, 0 },
}
do
	local laserDef = WeaponDefs[UnitDefs[unitDefID].weapons[12].weaponDef]
	ARM.laserFrames = math.ceil(math.max(laserDef.beamtime, laserDef.salvoSize * laserDef.salvoDelay) * Game.gameSpeed)
end
local OWNER_HOLD = 1.5 * Game.gameSpeed -- frames an arm keeps the torso after its last aim call
local FOLLOW_ANGLE = math.rad(12) -- the other arm may fire without turning the torso within this
local torsoOwner, torsoOwnerFrame, torsoHeading = 0, -1000, 0

local function WrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

ARM.LaserArc = function(num, heading)
	local arm = armData.side[num]
	if Spring.GetGameFrame() >= armData.busyUntil[arm] then
		return
	end
	local _, torsoYaw = Spring.UnitScript.GetPieceRotation(P.torsobase)
	local outward = WrapAngle(heading - torsoYaw) * (arm == 1 and 1 or -1) * ARM.convergeSign
	if outward > ARM.laserOutside or outward < -ARM.laserInside then
		Spring.SetUnitWeaponState(unitID, num, "salvoLeft", 0)
	end
end

local function RestoreAfterDelay()
	SetSignalMask(SIG_RESTORE)
	Sleep(RESTORE_DELAY)
	isAiming = false
	Turn(P.torsobase, y_axis, 0, RESTORE_SPEED)
	Turn(P.lcannon, x_axis, ARM.rest[1], RESTORE_SPEED)
	Turn(P.rcannon, x_axis, ARM.rest[2], RESTORE_SPEED)
	Turn(P.larm, y_axis, 0, RESTORE_SPEED)
	Turn(P.rarm, y_axis, 0, RESTORE_SPEED)
	Turn(P.larm, x_axis, 0, RESTORE_SPEED)
	Turn(P.rarm, x_axis, 0, RESTORE_SPEED)
	Turn(P.lshoulder, x_axis, 0, RESTORE_SPEED)
	Turn(P.rshoulder, x_axis, 0, RESTORE_SPEED)
	Turn(P.lturret, x_axis, 0, RESTORE_SPEED)
	Turn(P.rturret, x_axis, 0, RESTORE_SPEED)
	armData.upper[1], armData.upper[2] = 0, 0
end

local GROUP = {
	[1] = "gauss",
	[2] = "gauss",
	[3] = "napalm",
	[4] = "napalm",
	[6] = "barrage",
	[7] = "barrage",
	[8] = "rain",
	[9] = "rain",
	[10] = "stream",
	[11] = "stream",
	[12] = "laser",
	[13] = "laser",
	[14] = "laser",
	[15] = "laser",
	[16] = "turrets",
	[17] = "turrets",
	[18] = "turrets",
	[19] = "turrets",
	[20] = "railheavy",
	[25] = "railrapid",
	[26] = "beam",
	[27] = "aa",
	[28] = "aa",
	[29] = "volley",
	[30] = "volley",
	[31] = "stream",
	[32] = "stream",
	[21] = "volley",
	[22] = "volley",
	[23] = "volley",
	[24] = "volley",
	arms = { gauss = true, napalm = true, laser = true, volley = true },
	rail = { railheavy = true, railrapid = true },
	pods = { barrage = true, rain = true, stream = true },
}

local function WeaponAllowed(num)
	local only = Spring.GetUnitRulesParam(unitID, "scavboss_weapons")
	if not only or only == "all" then
		return true
	end
	local group = GROUP[num]
	return only == group or (GROUP[only] ~= nil and GROUP[only][group] == true)
end

local ACT = {
	order = { "arms", "pods", "arms", "rail" }, -- the main weapon groups take turns in this order; the beam cuts in when it is due
	time = { arms = 12, pods = 30, rail = 25, beam = 20 }, -- longest a turn may last, seconds
	idle = 2, -- seconds without a target before a turn is skipped
	gap = 1, -- seconds of quiet between two turns
	of = {
		gauss = "arms",
		napalm = "arms",
		laser = "arms",
		volley = "arms",
		arms = "arms",
		barrage = "pods",
		rain = "pods",
		stream = "pods",
		pods = "pods",
		railheavy = "rail",
		rail = "rail",
		beam = "beam",
	},
	current = "arms",
	index = 1,
	started = 0,
	done = false,
	want = {},
}

local AA = {
	weapon = 27, -- always-on anti-air missiles from the pods
	turbo = 28, -- their turbo version
	side = 1,
}

local TURBO = {
	waitBase = 10, -- seconds between turbos at zero health
	waitPerHealth = 0.2, -- extra seconds of waiting per percent of health left
	duration = { 20, 30 }, -- a turbo lasts a random time between these, seconds
	telegraph = 2, -- seconds of warning before a turbo starts
	range = 1200, -- how far the scan looks
	nearRange = 600, -- ground units inside this count as close
	heavyCost = 1500, -- far ground units costing this much metal count for the rail, cheaper ones for the pods
	luck = 3, -- random points added to every group that has targets
	stale = 5, -- seconds without a target after which a turbo ends early
	railDamage = 40, -- far turbo: the rapid rail fires without pause and each shot does this many times its normal damage
	rainRockets = 2, -- swarm turbo: rain salvos have this many times the rockets
	rainSpread = 1.5, -- swarm turbo: the rain scatters over this many times the normal area radius
	volleyDamage = 2, -- close turbo: the finale does this many times its normal damage (the alternating shots use their own turbo weapon)
	beamDamage = 2, -- beam turbo: the eater beam holds the turn and does this many times its normal damage
	volleyImpulse = 1.8, -- close turbo: knockback of the finale, same factor as the Vesuvius
	podGap = 0.5, -- seconds between pod modes in the swarm turbo
	volleyHealth = 0.75, -- the close turbo (back-to-back volleys) only below this health
	raiseHealth = 0.6, -- Raise only below this health
	raiseWrecks = 3, -- player wrecks in reach that Raise needs
	abilityChance = 0.5, -- chance that a turbo becomes an ability when one is possible
	hold = { close = "arms", far = "rapid", swarm = "pods", air = "aa", beam = "beam" },
	signal = { far = true, close = true }, -- turbos that show a warning before they start
	hinges = { P.flhinge, P.frhinge }, -- the close turbo plays its lightning and shimmer on these
	kinds = { "air", "close", "far", "swarm", "beam" },
	kind = false,
}

TURBO.Boost = function(num, mult, impulse)
	local def = WeaponDefs[UnitDefs[unitDefID].weapons[num].weaponDef]
	local set = { impulseFactor = impulse or def.damages.impulseFactor }
	for armor = 0, #Game.armorTypes do
		if def.damages[armor] then
			set[armor] = def.damages[armor] * mult
		end
	end
	Spring.SetUnitWeaponDamages(unitID, num, set)
end

local HUNGER = {
	health = 1, -- hunger only grows below this health; 1 = always
	fillSeconds = 600, -- seconds from empty to full when the boss kills nothing big
	minSeconds = 240, -- the fastest it can fill
	killsForMin = 55, -- T3 units the boss must kill since its last meal to reach the fastest fill
	min = 80, -- Devour starts somewhere between these two hunger values, picked anew each time
	max = 100,
	missDrop = 0.3, -- a meal without a blast lowers hunger by the share of the blast amount it ate, and by at least this much
	value = 0,
	trigger = 90,
	killsAtMeal = 0,
}

local TURRET_SPEED = math.rad(180)
local TURRET_ARC = math.rad(90) -- how far a turret may swing from its rest facing
local SIDE_HEADING = math.rad(90) -- heading of the boss's +x side; flip the sign if the shoulder turrets aim at the wrong side
local SHOULDER_PITCH_SIGN = 1 -- flip if the shoulder barrels dip when they should rise
local turrets = {
	[16] = { yaw = P.fturret, pitch = P.fbarrel, flare = P.fflare, rest = 0, axis = x_axis, sign = -1 },
	[17] = { yaw = P.bturret, pitch = P.bbarrel, flare = P.bflare, rest = math.pi, axis = x_axis, sign = 1 },
	[18] = {
		yaw = P.lturret,
		pitch = P.lbarrel,
		flare = P.lflare,
		rest = SIDE_HEADING,
		axis = z_axis,
		sign = SHOULDER_PITCH_SIGN,
	},
	[19] = {
		yaw = P.rturret,
		pitch = P.rbarrel,
		flare = P.rflare,
		rest = -SIDE_HEADING,
		axis = z_axis,
		sign = -SHOULDER_PITCH_SIGN,
	},
}

local function RestoreTurret(num)
	local t = turrets[num]
	Sleep(RESTORE_DELAY)
	Turn(t.yaw, y_axis, 0, RESTORE_SPEED)
	Turn(t.pitch, t.axis, 0, RESTORE_SPEED)
end

local function AimTurret(num, heading, pitch)
	local t = turrets[num]
	local _, torsobaseYaw = Spring.UnitScript.GetPieceRotation(P.torsobase)
	local _, torsoOwnYaw = Spring.UnitScript.GetPieceRotation(P.torso)
	local torsoYaw = torsobaseYaw + torsoOwnYaw
	local swing = WrapAngle(heading - torsoYaw - t.rest)
	if math.abs(swing) > TURRET_ARC then
		return false
	end
	Signal(SigOf(num))
	SetSignalMask(SigOf(num))
	Turn(t.yaw, y_axis, swing, TURRET_SPEED)
	Turn(t.pitch, t.axis, t.sign * pitch, TURRET_SPEED)
	WaitForTurn(t.yaw, y_axis)
	WaitForTurn(t.pitch, t.axis)
	StartThread(RestoreTurret, num)
	return true
end

local RAIL = {
	heavy = 20, -- weapon slot of the heavy shot
	rapid = 25, -- weapon slot of the rapid burst
	heavyShots = 3, -- heavy shots per turn
	sparkEvery = 0.5, -- seconds between sparks while the rapid rail fires in the far turbo
	sparkSize = 0.5, -- lightning size, 1 = commander spawn
	sparkStrength = 0.5, -- lightning brightness, 1 = commander spawn
	sparkDrop = 15, -- elmos below the deco ring where the lightning is centred
	speed = math.rad(120), -- turret turn speed
	fireAngle = math.rad(8), -- how close the turret must point to the target before a burst may start
	maxDown = math.rad(30), -- how far below horizontal the barrel may dip; lower targets are not fired at
	restoreFrames = 90, -- frames without an aim call before the turret returns to rest
}
local rail = { count = 0, rapidUntil = 0, goal = 0, belief = 0, aimFrame = -1000 }

local function RailSpark()
	if GG.SpawnEnvironmentalLightning then
		local x, y, z = Spring.GetUnitPiecePosDir(unitID, P.sleevedeco2)
		GG.SpawnEnvironmentalLightning("commanderspawn", x, y - RAIL.sparkDrop, z, RAIL.sparkSize, RAIL.sparkStrength)
	end
end

local function RailLoop()
	while true do
		Sleep(RAIL.sparkEvery * 1000)
		if TURBO.kind == "far" and Spring.GetGameFrame() < rail.rapidUntil and not Spring.GetUnitIsStunned(unitID) then
			RailSpark()
		end
	end
end

local function ParentYaw()
	local _, baseYaw = Spring.UnitScript.GetPieceRotation(P.base)
	local _, torsobaseYaw = Spring.UnitScript.GetPieceRotation(P.torsobase)
	local _, torsoYaw = Spring.UnitScript.GetPieceRotation(P.torso)
	return Spring.GetUnitHeading(unitID) * math.pi / 32768 + baseYaw + torsobaseYaw + torsoYaw
end

local function RailController()
	rail.belief = ParentYaw()
	while true do
		local parent = ParentYaw()
		local aiming = Spring.GetGameFrame() - rail.aimFrame <= RAIL.restoreFrames
		local step = (aiming and RAIL.speed or RESTORE_SPEED) / Game.gameSpeed
		local delta = WrapAngle((aiming and rail.goal or parent) - rail.belief)
		rail.belief = WrapAngle(rail.belief + math.max(-step, math.min(step, delta)))
		Turn(P.rgturret, y_axis, WrapAngle(rail.belief - parent))
		if not aiming then
			Turn(P.rgsleeve, x_axis, 0, RESTORE_SPEED)
		end
		Sleep(FRAME_MS)
	end
end

local function AimRail(num, heading, pitch)
	if num == RAIL.rapid and ACT.current == "rail" and WeaponAllowed(RAIL.heavy) then
		return false
	end
	rail.goal = WrapAngle(Spring.GetUnitHeading(unitID) * math.pi / 32768 + heading)
	rail.aimFrame = Spring.GetGameFrame()
	Turn(P.rgsleeve, x_axis, -math.max(pitch, -RAIL.maxDown), RAIL.speed)
	return pitch >= -RAIL.maxDown and math.abs(WrapAngle(rail.goal - rail.belief)) <= RAIL.fireAngle
end

local function FireRail(num)
	if num == RAIL.rapid then
		local def = WeaponDefs[UnitDefs[unitDefID].weapons[num].weaponDef]
		rail.rapidUntil = Spring.GetGameFrame() + def.salvoSize * def.salvoDelay * Game.gameSpeed
		return
	end
	rail.count = rail.count + 1
	if rail.count >= RAIL.heavyShots then
		rail.count = 0
		ACT.done = true
	end
end

local BEAM = {
	weapon = 26,
	every = 70, -- seconds before the beam asks for a turn again; its turn length is ACT.time.beam
	turnSpeed = math.rad(40), -- torso speed while beaming; slow, so the beam sweeps instead of snapping
	fireAngle = math.rad(15), -- the beam keeps firing while the torso is within this angle of the target
	closeDelay = 1.5, -- seconds after the last shot before the face closes
	owner = 6, -- torso owner id for the beam
	active = false,
	due = false,
	lastShot = -1000,
}

local function AimBeam(num, heading)
	if not BEAM.active then
		return false
	end
	Signal(SigOf(num))
	SetSignalMask(SigOf(num))
	torsoOwner, torsoOwnerFrame, torsoHeading = BEAM.owner, Spring.GetGameFrame(), heading
	Signal(SIG_RESTORE)
	isAiming = true
	Turn(P.torsobase, y_axis, heading, BEAM.turnSpeed)
	local _, yaw = Spring.UnitScript.GetPieceRotation(P.torsobase)
	if math.abs(WrapAngle(heading - yaw)) > BEAM.fireAngle then
		WaitForTurn(P.torsobase, y_axis)
	end
	StartThread(RestoreAfterDelay)
	return true
end

local POD_BARRAGE, POD_RAIN, POD_STREAM = 1, 2, 3
local podSide = { [6] = 1, [7] = 2, [8] = 1, [9] = 2, [10] = 1, [11] = 2, [31] = 1, [32] = 2 }
local podModeOf = {
	[6] = POD_BARRAGE,
	[7] = POD_BARRAGE,
	[8] = POD_RAIN,
	[9] = POD_RAIN,
	[10] = POD_STREAM,
	[11] = POD_STREAM,
	[31] = POD_STREAM,
	[32] = POD_STREAM,
}
local podPiece = { P.lrocketpod, P.rrocketpod }
local podFlare = { P.lpodflare, P.rpodflare }
local POD_SPEED, POD_PITCH_SIGN = math.rad(120), -1
local POD_FORWARD = math.rad(90) -- ring angle that brings the hole from the top to the front
local RAIN_PITCH = 0 -- ring angle for the rain mode, 0 = hole on top
local RAIN_SPREAD = 300 -- elmos around the target over which the rain rockets scatter
local RAIN_WEAPON = WeaponDefNames[UnitDefs[unitDefID].name .. "_pod_rain"].id
local rainCentre, rainAssigned = {}, {}
local MODE_ORDER = { POD_BARRAGE, POD_RAIN, POD_STREAM } -- cycle order of the pod modes
local MODE_GAP = 3 -- seconds between the end of one pod mode and the next
local MODE_TIMEOUT = 40 -- seconds after which a mode that never finished its volleys is skipped
local STREAM_DURATION = 17 -- seconds the stream mode keeps firing
local STREAM_GAP = 0.2 * Game.gameSpeed -- frames between the two pods while streaming
local POD_OWNER = 3 -- torso owner id for the pods
local podMode = POD_BARRAGE
local podModeIndex = 1
local podModeSerial = 0
local podVolleys = 0
local podStreamStart = -1
local podLastFire = { -1000, -1000 }

local podModeByName = { barrage = POD_BARRAGE, rain = POD_RAIN, stream = POD_STREAM }

local function NextPodMode()
	if podModeByName[Spring.GetUnitRulesParam(unitID, "scavboss_weapons") or ""] then
		return
	end
	local swarm = TURBO.kind == "swarm"
	ACT.done = true
	Turn(podPiece[1], x_axis, 0, POD_SPEED)
	Turn(podPiece[2], x_axis, 0, POD_SPEED)
	Sleep((swarm and TURBO.podGap or MODE_GAP) * 1000)
	podModeIndex = podModeIndex % #MODE_ORDER + 1
	if swarm and MODE_ORDER[podModeIndex] == POD_BARRAGE then
		podModeIndex = podModeIndex % #MODE_ORDER + 1
	end
	podMode = MODE_ORDER[podModeIndex]
	podModeSerial = podModeSerial + 1
	podVolleys = 0
	podStreamStart = -1
end

local function ModeTimeout(serial)
	Sleep(MODE_TIMEOUT * 1000)
	if podModeSerial == serial then
		NextPodMode()
	end
end

local function PodVolleyDone()
	podVolleys = podVolleys + 1
	if podVolleys == 1 then
		StartThread(ModeTimeout, podModeSerial)
	elseif podVolleys >= 2 then
		StartThread(NextPodMode)
	end
end

local function AimPod(num, heading, pitch)
	local side, frame = podSide[num], Spring.GetGameFrame()
	local forced = podModeByName[Spring.GetUnitRulesParam(unitID, "scavboss_weapons") or ""]
	if forced and podMode ~= forced then
		podMode, podModeSerial, podVolleys, podStreamStart = forced, podModeSerial + 1, 0, -1
	end
	if podModeOf[num] ~= podMode then
		return false
	end
	Signal(SigOf(num))
	SetSignalMask(SigOf(num))
	if podMode == POD_RAIN then
		Turn(podPiece[side], x_axis, RAIN_PITCH, POD_SPEED)
		WaitForTurn(podPiece[side], x_axis)
		return true
	end
	if podMode == POD_STREAM then
		if podStreamStart >= 0 and frame - podStreamStart > STREAM_DURATION * Game.gameSpeed then
			return false
		end
		if frame - podLastFire[3 - side] < STREAM_GAP then
			return false
		end
	end
	if torsoOwner ~= POD_OWNER and frame - torsoOwnerFrame < OWNER_HOLD then
		if math.abs(WrapAngle(heading - torsoHeading)) > FOLLOW_ANGLE then
			return false
		end
	else
		torsoOwner, torsoOwnerFrame, torsoHeading = POD_OWNER, frame, heading
		Signal(SIG_RESTORE)
		isAiming = true
		Turn(P.torsobase, y_axis, heading, TORSO_SPEED)
		StartThread(RestoreAfterDelay)
	end
	Turn(podPiece[side], x_axis, POD_FORWARD + POD_PITCH_SIGN * pitch, POD_SPEED)
	WaitForTurn(P.torsobase, y_axis)
	WaitForTurn(podPiece[side], x_axis)
	return true
end

local function FirePod(num)
	local side, frame = podSide[num], Spring.GetGameFrame()
	podLastFire[side] = frame
	EmitSfx(podFlare[side], SFX.CEG)
	if podMode == POD_STREAM then
		if podStreamStart < 0 then
			podStreamStart = frame
			StartThread(function()
				Sleep(STREAM_DURATION * 1000)
				NextPodMode()
			end)
		end
		return
	end
end

local function RetargetRainRocket(side)
	Sleep(FRAME_MS)
	local centre = rainCentre[side]
	if not centre then
		return
	end
	local fx, _, fz = Spring.GetUnitPiecePosDir(unitID, podFlare[side])
	for _, proID in ipairs(Spring.GetProjectilesInRectangle(fx - 80, fz - 80, fx + 80, fz + 80)) do
		if
			not rainAssigned[proID]
			and Spring.GetProjectileOwnerID(proID) == unitID
			and Spring.GetProjectileDefID(proID) == RAIN_WEAPON
		then
			rainAssigned[proID] = true
			local angle, dist =
				math.random() * 2 * math.pi,
				math.sqrt(math.random()) * RAIN_SPREAD * (TURBO.kind == "swarm" and TURBO.rainSpread or 1)
			local x, z = centre[1] + math.cos(angle) * dist, centre[3] + math.sin(angle) * dist
			Spring.SetProjectileTarget(proID, x, Spring.GetGroundHeight(x, z), z)
			return
		end
	end
end

function script.Shot(num)
	if num == AA.weapon or num == AA.turbo then
		AA.side = 3 - AA.side
		return
	end
	if podModeOf[num] ~= POD_RAIN then
		return
	end
	local side = podSide[num]
	if not rainCentre[side] then
		local targetType, _, target = Spring.GetUnitWeaponTarget(unitID, num)
		if targetType == 1 then
			rainCentre[side] = { Spring.GetUnitPosition(target) }
		elseif targetType == 2 and type(target) == "table" then
			rainCentre[side] = target
		end
	end
	StartThread(RetargetRainRocket, side)
end

function script.EndBurst(num)
	if podModeOf[num] == POD_RAIN then
		rainCentre[podSide[num]] = nil
		rainAssigned = {}
	end
	if podSide[num] and podModeOf[num] == podMode and podMode ~= POD_STREAM then
		PodVolleyDone()
	end
end

function script.AimFromWeapon(num)
	if num == RAIL.heavy or num == RAIL.rapid then
		return P.rgsleeve
	end
	if num == BEAM.weapon then
		return P.eaterbeam
	end
	if turrets[num] then
		return turrets[num].pitch
	end
	return P.spine2
end

function script.QueryWeapon(num)
	if num == AA.weapon or num == AA.turbo then
		return podFlare[AA.side]
	end
	if num == RAIL.heavy or num == RAIL.rapid then
		return P.rgflare
	end
	if num == BEAM.weapon then
		return P.eaterbeamflare
	end
	if turrets[num] then
		return turrets[num].flare
	end
	return armData.flare[num] or podFlare[podSide[num]] or P.torso
end

local VOLLEY = {
	shots = 8, -- alternating shots before the finale
	interval = 0.4, -- seconds between two alternating shots
	finaleDelay = 1, -- seconds between the last shot and the two-arm finale
	cooldownFull = 25, -- seconds between volleys at full health
	cooldownLow = 10, -- seconds between volleys at zero health
	stall = 3, -- seconds without a shot after which a started volley gives up
	left = 21,
	right = 22,
	finaleLeft = 23,
	finaleRight = 24,
	turboLeft = 29,
	turboRight = 30,
	owner = 5, -- torso owner id for the volley
}
local volley = { phase = "cooldown", shots = 0, finale = 0, turn = 21, left = 21, right = 22, lastShot = 0 }

local function PitchArm(arm, kind, pitch)
	armData.upper[arm] = 0
	Turn(armData.yaw[arm], x_axis, 0, ARM.speed)
	if kind == "napalm" then
		armData.pitch[arm] = 0
		Turn(armData.shoulder[arm], x_axis, -pitch, ARM.speed)
		Turn(armData.turret[arm], x_axis, pitch, ARM.speed)
		Turn(armData.cannon[arm], x_axis, 0, ARM.speed)
		WaitForTurn(armData.shoulder[arm], x_axis)
	else
		armData.pitch[arm] = -pitch
		Turn(armData.shoulder[arm], x_axis, 0, ARM.speed)
		Turn(armData.turret[arm], x_axis, 0, ARM.speed)
		Turn(armData.cannon[arm], x_axis, -pitch, ARM.speed)
	end
end

local function VolleyHold(num)
	Spring.SetUnitWeaponState(unitID, num, "reloadFrame", Spring.GetGameFrame() + 100000)
end

local function VolleyCooldown()
	volley.phase, volley.shots, volley.finale = "cooldown", 0, 0
	for num = VOLLEY.left, VOLLEY.finaleRight do
		VolleyHold(num)
	end
	VolleyHold(VOLLEY.turboLeft)
	VolleyHold(VOLLEY.turboRight)
	local waited = 0
	while true do
		local health, maxHealth = Spring.GetUnitHealth(unitID)
		local need = VOLLEY.cooldownLow + (VOLLEY.cooldownFull - VOLLEY.cooldownLow) * (health or 1) / (maxHealth or 1)
		if
			waited >= need
			or Spring.GetUnitRulesParam(unitID, "scavboss_weapons") == "volley"
			or TURBO.kind == "close"
		then
			break
		end
		Sleep(1000)
		if not Spring.GetUnitIsStunned(unitID) then
			waited = waited + 1
		end
	end
	local turbo = TURBO.kind == "close"
	volley.left = turbo and VOLLEY.turboLeft or VOLLEY.left
	volley.right = turbo and VOLLEY.turboRight or VOLLEY.right
	TURBO.Boost(VOLLEY.finaleLeft, turbo and TURBO.volleyDamage or 1, turbo and TURBO.volleyImpulse)
	TURBO.Boost(VOLLEY.finaleRight, turbo and TURBO.volleyDamage or 1, turbo and TURBO.volleyImpulse)
	volley.phase, volley.turn = "armed", volley.left
	Spring.SetUnitWeaponState(unitID, volley.left, "reloadFrame", Spring.GetGameFrame())
end

local function VolleyWatch()
	while volley.phase == "firing" or volley.phase == "finale" do
		Sleep(500)
		local limit = (volley.phase == "finale" and VOLLEY.finaleDelay + VOLLEY.stall or VOLLEY.stall) * Game.gameSpeed
		if
			(volley.phase == "firing" or volley.phase == "finale")
			and Spring.GetGameFrame() - volley.lastShot > limit
		then
			VolleyCooldown()
			return
		end
	end
end

local function AimVolley(num, heading, pitch)
	if volley.phase == "cooldown" then
		return false
	end
	local frame = Spring.GetGameFrame()
	if volley.phase == "armed" and (frame < armData.busyUntil[1] or frame < armData.busyUntil[2]) then
		return false
	end
	local isFinale = num == VOLLEY.finaleLeft or num == VOLLEY.finaleRight
	if (volley.phase == "finale") ~= isFinale or (not isFinale and num ~= volley.turn) then
		return false
	end
	Signal(SigOf(num))
	SetSignalMask(SigOf(num))
	local side = armData.side[num]
	local holding = torsoOwner == VOLLEY.owner and frame - torsoOwnerFrame < OWNER_HOLD
	local offset = WrapAngle(heading - torsoHeading)
	Signal(SIG_RESTORE)
	isAiming = true
	if holding and math.abs(offset) <= ARM.toeIn then
		torsoOwnerFrame = frame
		Turn(armData.yaw[side], y_axis, ARM.Yaw(num, side, offset), ARM.speed)
	else
		torsoOwner, torsoOwnerFrame, torsoHeading = VOLLEY.owner, frame, heading
		Turn(P.torsobase, y_axis, heading, TORSO_SPEED)
		Turn(armData.yaw[side], y_axis, ARM.Yaw(num, side, 0), ARM.speed)
	end
	for arm = 1, 2 do
		PitchArm(arm, "volley", pitch)
	end
	WaitForTurn(P.torsobase, y_axis)
	WaitForTurn(armData.yaw[side], y_axis)
	WaitForTurn(armData.cannon[side], x_axis)
	StartThread(RestoreAfterDelay)
	return true
end

local function VolleyFired(num)
	local frame = Spring.GetGameFrame()
	volley.lastShot = frame
	VolleyHold(num)
	if volley.phase == "finale" then
		volley.finale = volley.finale + 1
		if volley.finale >= 2 then
			StartThread(VolleyCooldown)
		end
		return
	end
	if volley.phase == "armed" then
		volley.phase = "firing"
		StartThread(VolleyWatch)
	end
	volley.shots = volley.shots + 1
	if volley.shots >= VOLLEY.shots then
		volley.phase = "finale"
		local at = frame + math.floor(VOLLEY.finaleDelay * Game.gameSpeed)
		Spring.SetUnitWeaponState(unitID, VOLLEY.finaleLeft, "reloadFrame", at)
		Spring.SetUnitWeaponState(unitID, VOLLEY.finaleRight, "reloadFrame", at)
		return
	end
	volley.turn = (num == volley.left) and volley.right or volley.left
	Spring.SetUnitWeaponState(unitID, volley.turn, "reloadFrame", frame + math.floor(VOLLEY.interval * Game.gameSpeed))
end

local function ArmOwnerKind(arm)
	local bestKind, bestReady = nil, math.huge
	for _, w in ipairs(armData.weapons[arm]) do
		local ready = Spring.GetUnitWeaponState(unitID, w, "reloadFrame") or 0
		if ready < bestReady and WeaponAllowed(w) then
			bestKind, bestReady = armData.kind[w], ready
		end
	end
	return bestKind
end

function script.AimWeapon(num, heading, pitch)
	if armData.kind[num] == "laser" then
		ARM.LaserArc(num, heading)
	end
	if eating or not WeaponAllowed(num) then
		return false
	end
	if num == AA.weapon or num == AA.turbo then
		ACT.want.aa = Spring.GetGameFrame()
		return (num == AA.turbo) == (TURBO.kind == "air")
	end
	local act = ACT.of[GROUP[num] or ""]
	if act == "rail" and TURBO.kind == "far" then
		return false
	end
	if GROUP[num] == "stream" and (num > 11) ~= (TURBO.kind == "swarm") then
		return false
	end
	if num == RAIL.rapid then
		ACT.want.rapid = Spring.GetGameFrame()
	end
	if act then
		ACT.want[act] = Spring.GetGameFrame()
		if act ~= ACT.current then
			return false
		end
	end
	if num == RAIL.heavy or num == RAIL.rapid then
		return AimRail(num, heading, pitch)
	end
	if num == BEAM.weapon then
		return AimBeam(num, heading)
	end
	if turrets[num] then
		return AimTurret(num, heading, pitch)
	end
	if podSide[num] then
		return AimPod(num, heading, pitch)
	end
	if armData.kind[num] == "volley" then
		return AimVolley(num, heading, pitch)
	end
	if not armData.side[num] or TURBO.kind == "close" then
		return false
	end
	if
		WeaponAllowed(VOLLEY.left)
		and (
			volley.phase == "firing"
			or volley.phase == "finale"
			or (volley.phase == "armed" and armData.kind[num] == "gauss")
		)
	then
		return false
	end
	local arm, frame = armData.side[num], Spring.GetGameFrame()
	local twin = armData.kind[num] == armData.lastKind[arm] and frame - armData.lastFire[arm] <= ARM.twinWindow
	if frame - math.max(armData.lastFire[arm], armData.busyUntil[arm]) < ARM.gap and not twin then
		return false
	end
	if armData.kind[num] ~= ArmOwnerKind(arm) then
		return false
	end
	Signal(SigOf(num))
	SetSignalMask(SigOf(num))
	if torsoOwner ~= arm and frame - torsoOwnerFrame < OWNER_HOLD then
		local offset = WrapAngle(heading - torsoHeading)
		if math.abs(offset) > ARM.toeIn then
			return false
		end
		Turn(armData.yaw[arm], y_axis, ARM.Yaw(num, arm, offset), ARM.speed)
		PitchArm(arm, armData.kind[num], pitch)
		WaitForTurn(armData.yaw[arm], y_axis)
		WaitForTurn(armData.cannon[arm], x_axis)
		return true
	end
	torsoOwner, torsoOwnerFrame, torsoHeading = arm, frame, heading
	Signal(SIG_RESTORE)
	isAiming = true
	Turn(P.torsobase, y_axis, heading, TORSO_SPEED)
	Turn(armData.yaw[arm], y_axis, ARM.Yaw(num, arm, 0), ARM.speed)
	PitchArm(arm, armData.kind[num], pitch)
	WaitForTurn(P.torsobase, y_axis)
	WaitForTurn(armData.cannon[arm], x_axis)
	StartThread(RestoreAfterDelay)
	return true
end

function script.FireWeapon(num)
	if num == RAIL.heavy or num == RAIL.rapid then
		return FireRail(num)
	end
	if num == BEAM.weapon then
		BEAM.lastShot = Spring.GetGameFrame()
		return
	end
	if turrets[num] then
		return
	end
	if podSide[num] then
		return FirePod(num)
	end
	if armData.kind[num] == "volley" then
		VolleyFired(num)
	end
	if not armData.side[num] then
		return
	end
	local arm = armData.side[num]
	armData.lastFire[arm] = Spring.GetGameFrame()
	armData.lastKind[arm] = armData.kind[num]
	if armData.kind[num] == "laser" then
		armData.busyUntil[arm] = armData.lastFire[arm] + ARM.laserFrames
		return
	end
	EmitSfx(armData.flare[num], SFX.CEG)
	Move(armData.barrel[arm], z_axis, -ARM.recoil)
	Turn(armData.cannon[arm], x_axis, armData.pitch[arm] - ARM.kick)
	Turn(armData.yaw[arm], x_axis, armData.upper[arm] + ARM.shoulderSign * ARM.shoulderKick)
	local now = Spring.GetGameFrame()
	if now > armData.jerkUntil[arm] then
		armData.jerkBase[arm] = Spring.UnitScript.GetPieceRotation(armData.shoulder[arm])
	end
	armData.jerkUntil[arm] = now + math.ceil(Game.gameSpeed / 3) + 1
	local shoulderPitch = armData.jerkBase[arm]
	Turn(armData.shoulder[arm], x_axis, shoulderPitch + ARM.jerkSign * ARM.shoulderJerk)
	Sleep(FRAME_MS)
	Turn(armData.shoulder[arm], x_axis, shoulderPitch, ARM.shoulderJerk * 3)
	Move(armData.barrel[arm], z_axis, 0, ARM.recoil * 4)
	Turn(armData.cannon[arm], x_axis, armData.pitch[arm], ARM.kick * 3)
	Turn(armData.yaw[arm], x_axis, armData.upper[arm], ARM.shoulderKick * 3)
end

local FEED_GRACE = 3 -- seconds of warning before the face opens
local FEED_DURATION = 25 -- seconds the face stays open
local FEED_GOAL = 100000 -- metal pulled in that triggers the blast
local EAT_RANGE = 650 -- keep under builddistance
local BLAST_RADIUS, BLAST_DAMAGE, EVAPORATE_HEALTH = 2800, 136000, 0.35
local BLAST_WAVE_FRAMES = 8 -- frames the damage takes to reach the edge of the blast
local SHIELD_WEAPON = 5
local T_SHIELD_ON, T_AURA, T_SHIELD_OFF, T_AURA_OFF, T_BLAST = 0.5, 0.1, 6, 6, 6.5 -- seconds after the meal ends
local SHIELD_ON_LAG, SHIELD_RAMP = 1, 0 -- seconds until the game draws the bubble, then seconds of fade-in
local SHIELD_ON_PARAM = 531313 -- the shield gadget's on/off flag, cleared so the bubble vanishes with the blast
local SHIELD_POWER = WeaponDefs[UnitDefs[unitDefID].weapons[SHIELD_WEAPON].weaponDef].shieldPower
local FACE_OPEN, FACE_SPEED = math.rad(30), math.rad(60)
local DGUN = {
	count = 5, -- disruptor bolts fired outward after the blast
	delay = 0.3, -- seconds after the blast
	height = 30, -- elmos above the boss's feet where they start
}
local BLAST_WEAPON = WeaponDefNames[UnitDefs[unitDefID].name .. "_eaterblast"].id
local fedMetal = 0

local function IsPrey(otherID)
	local team = Spring.GetUnitTeam(otherID)
	if not team or team == myTeam or Spring.AreTeamsAllied(team, myTeam) or Spring.GetUnitIsDead(otherID) then
		return false
	end
	local def = UnitDefs[Spring.GetUnitDefID(otherID)]
	return def and not def.canFly and def.reclaimable
end

local function PickMeal()
	local x, y, z = Spring.GetUnitPosition(unitID)
	local best, bestMetal = nil, 0
	for _, otherID in ipairs(Spring.GetUnitsInSphere(x, y, z, EAT_RANGE)) do
		if IsPrey(otherID) then
			local cost = UnitDefs[Spring.GetUnitDefID(otherID)].metalCost
			if cost > bestMetal then
				best, bestMetal = otherID, cost
			end
		end
	end
	if best then
		return best, false, bestMetal
	end
	for _, featureID in ipairs(Spring.GetFeaturesInSphere(x, y, z, EAT_RANGE)) do
		local metal = Spring.GetFeatureResources(featureID)
		if metal and metal > bestMetal and FeatureDefs[Spring.GetFeatureDefID(featureID)].reclaimable then
			best, bestMetal = featureID, metal
		end
	end
	if best then
		return best, true, bestMetal
	end
	for _, otherID in ipairs(Spring.GetUnitsInSphere(x, y, z, EAT_RANGE, myTeam)) do
		local def = UnitDefs[Spring.GetUnitDefID(otherID)]
		local edible = otherID ~= unitID and def.canMove and not def.canFly and def.reclaimable
		edible = edible and not Spring.GetUnitIsDead(otherID)
		if edible and not def.customParams.eaterboss and def.metalCost > bestMetal then
			best, bestMetal = otherID, def.metalCost
		end
	end
	return best, false, 0, bestMetal
end

local function MealGone(target, isFeature)
	if isFeature then
		return not Spring.ValidFeatureID(target)
	end
	return not Spring.ValidUnitID(target) or Spring.GetUnitIsDead(target)
end

local function MealEscaped(target, isFeature)
	return not isFeature and (Spring.GetUnitSeparation(unitID, target, true) or 0) > EAT_RANGE * 1.2
end

local function SetFace(open)
	Turn(P.lhead, y_axis, open and FACE_OPEN or 0, FACE_SPEED)
	Turn(P.rhead, y_axis, open and -FACE_OPEN or 0, FACE_SPEED)
end

local function Blast()
	local x, y, z = Spring.GetUnitPosition(unitID)
	Spring.SpawnExplosion(x, y + 40, z, 0, 1, 0, {
		weaponDef = BLAST_WEAPON,
		owner = unitID,
		ignoreOwner = true,
		damageGround = true,
		damageAreaOfEffect = BLAST_RADIUS,
		explosionSpeed = BLAST_RADIUS / BLAST_WAVE_FRAMES,
		edgeEffectiveness = 0,
		damages = BLAST_DAMAGE,
	})
	for _, otherID in ipairs(Spring.GetUnitsInSphere(x, y, z, BLAST_RADIUS * 0.6)) do
		if IsPrey(otherID) then
			local health, maxHealth = Spring.GetUnitHealth(otherID)
			if health and health < maxHealth * EVAPORATE_HEALTH then
				Spring.DestroyUnit(otherID, false, true)
			end
		end
	end
end

local function SetShield(on)
	if GG.ScavBossShield then
		GG.ScavBossShield(unitID, on)
	end
	Spring.SetUnitShieldState(unitID, SHIELD_WEAPON, 0)
	if not on then
		Spring.SetUnitRulesParam(unitID, SHIELD_ON_PARAM, 0, { inlos = true })
	end
end

local function At(seconds, fn)
	StartThread(function()
		Sleep(seconds * 1000)
		fn()
	end)
end

local function ShieldOn()
	SetShield(true)
	Sleep(SHIELD_ON_LAG * 1000)
	local steps = math.floor(SHIELD_RAMP * 10)
	for i = 1, steps do
		Spring.SetUnitShieldState(unitID, SHIELD_WEAPON, SHIELD_POWER * i / steps)
		Sleep(100)
	end
	Spring.SetUnitShieldState(unitID, SHIELD_WEAPON, SHIELD_POWER)
end

local function ShieldOff()
	SetShield(false)
end

local function ChargeAura()
	if GG.ScavBossFeedingEffect then
		GG.ScavBossFeedingEffect(unitID, unitDefID, 2)
	end
end

local function PopAura()
	if GG.ScavBossFeedingEffect then
		GG.ScavBossFeedingEffect(unitID, unitDefID, 3)
	end
end

local function Detonate()
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_state", 3)
	At(T_SHIELD_ON, ShieldOn)
	At(T_AURA, ChargeAura)
	At(T_SHIELD_OFF, ShieldOff)
	At(T_AURA_OFF, PopAura)
	Sleep(T_BLAST * 1000)
	Blast()
	Sleep(DGUN.delay * 1000)
	local def = WeaponDefNames[UnitDefs[unitDefID].name .. "_devourdgun"]
	local x, y, z = Spring.GetUnitPosition(unitID)
	local first = math.random() * 2 * math.pi
	for i = 1, DGUN.count do
		local angle = first + i * 2 * math.pi / DGUN.count
		Spring.SpawnProjectile(def.id, {
			pos = { x, y + DGUN.height, z },
			speed = { math.sin(angle) * def.projectilespeed, 0, math.cos(angle) * def.projectilespeed },
			owner = unitID,
			team = Spring.GetUnitTeam(unitID),
			ttl = math.ceil(def.range / def.projectilespeed),
		})
	end
	Spring.PlaySoundFile("disigun1", 1, x, y, z)
end

local RAISE = {
	grace = 2, -- seconds of warning before it starts raising
	duration = 25, -- seconds it spends raising, not counting the walk to a wreck
	perWreck = 20, -- seconds before it gives up on one wreck
	search = 2000, -- how far it looks for wrecks and walks to them
	walkTime = 20, -- seconds of walking after which it gives up
	lateMinute = 15, -- from this minute of the game the raise speed grows with missing health
	lateBoost = 6.5, -- raise speed multiplier at zero health after that minute
	poseSpeed = math.rad(20), -- how fast it bends into and out of the raise pose
	energy = 1000000, -- energy an AI-owned boss's team is kept at while it raises, since resurrecting costs energy
}
local RAISE_POSE = { -- piece, axis, raise angle, stance angle
	{ P.larm, x_axis, 0.327201, 0.000000 },
	{ P.larm, z_axis, 0.369536, 0.261799 },
	{ P.larm, y_axis, 0.123848, 0.000000 },
	{ P.lcannon, x_axis, 0.872665, 0.349066 },
	{ P.lcannon, z_axis, -0.000000, 0.000000 },
	{ P.lcannon, y_axis, 0.000000, 0.000000 },
	{ P.lshoulder, x_axis, -0.000000, 0.000000 },
	{ P.lshoulder, z_axis, 0.349066, 0.349066 },
	{ P.lshoulder, y_axis, 0.087266, 0.087266 },
	{ P.rarm, x_axis, -0.000000, 0.000000 },
	{ P.rarm, z_axis, -0.349066, -0.261799 },
	{ P.rarm, y_axis, -0.000000, 0.000000 },
	{ P.rcannon, x_axis, 0.872665, 0.349066 },
	{ P.rcannon, z_axis, 0.000000, 0.000000 },
	{ P.rcannon, y_axis, -0.000000, 0.000000 },
	{ P.rshoulder, x_axis, 0.327201, 0.000000 },
	{ P.rshoulder, z_axis, -0.369536, -0.349066 },
	{ P.rshoulder, y_axis, -0.211115, -0.087266 },
	{ P.spine1, x_axis, 0.450412, 0.000000 },
	{ P.spine1, z_axis, -0.000000, 0.000000 },
	{ P.spine1, y_axis, -0.000000, 0.000000 },
	{ P.spine2, x_axis, -0.000000, 0.000000 },
	{ P.spine2, z_axis, -0.000000, 0.000000 },
	{ P.spine2, y_axis, -0.000000, 0.000000 },
	{ P.spine3, x_axis, -0.000000, 0.000000 },
	{ P.spine3, z_axis, -0.000000, 0.000000 },
	{ P.spine3, y_axis, -0.000000, 0.000000 },
	{ P.torso, x_axis, -0.046745, 0.000000 },
	{ P.torso, z_axis, -0.000000, 0.000000 },
	{ P.torso, y_axis, -0.000000, 0.000000 },
}

local function SetRaisePose(on)
	for _, p in ipairs(RAISE_POSE) do
		Turn(p[1], p[2], on and p[3] or p[4], RAISE.poseSpeed)
	end
end

local function Feed()
	Spring.SetUnitRulesParam(unitID, "scavboss_feed", 0)
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_state", 1)
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_metal", 0)
	Sleep(FEED_GRACE * 1000)
	eating, posed, isAiming = true, true, true
	fedMetal = 0
	Spring.SetUnitRulesParam(unitID, "scavboss_eating", 1)
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_state", 2)
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_metal", 0)
	Signal(SIG_ALL_AIM)
	Signal(SIG_RESTORE)
	SetFace(true)
	SetRaisePose(true)
	if GG.ScavBossFeedingEffect then
		GG.ScavBossFeedingEffect(unitID, unitDefID, 1)
	end
	local deadline = Spring.GetGameFrame() + FEED_DURATION * Game.gameSpeed
	local blast, ownEaten = false, 0
	while Spring.GetGameFrame() < deadline and not Spring.GetUnitIsStunned(unitID) do
		local target, isFeature, startMetal, ownMetal = PickMeal()
		if target then
			Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, { isFeature and (Game.maxUnits + target) or target }, 0)
			local before = fedMetal
			while
				not MealGone(target, isFeature)
				and not MealEscaped(target, isFeature)
				and Spring.GetGameFrame() < deadline
				and not Spring.GetUnitIsStunned(unitID)
			do
				Sleep(500)
				if isFeature then
					fedMetal = before + startMetal - (Spring.GetFeatureResources(target) or 0)
					Spring.SetUnitRulesParam(unitID, "scavboss_feed_metal", fedMetal)
				end
			end
			if MealGone(target, isFeature) then
				fedMetal = before + startMetal
				ownEaten = ownEaten + (ownMetal or 0)
			end
			Spring.SetUnitRulesParam(unitID, "scavboss_feed_metal", fedMetal)
			Spring.Echo("scav boss fed " .. math.floor(fedMetal) .. " / " .. FEED_GOAL .. " metal")
			if fedMetal >= FEED_GOAL then
				blast = true
				break
			end
			Sleep(FRAME_MS)
		else
			Sleep(1000)
		end
	end
	if blast then
		HUNGER.value = 0
		HUNGER.killsAtMeal = Spring.GetUnitRulesParam(unitID, "scavboss_bigkills") or 0
	else
		local share = math.min(1, (fedMetal + ownEaten) / FEED_GOAL)
		HUNGER.value = HUNGER.value * (1 - math.max(share, HUNGER.missDrop))
	end
	HUNGER.trigger = math.random(HUNGER.min, HUNGER.max)
	posed = false
	SetRaisePose(false)
	if blast then
		Detonate()
	end
	eating = false
	Spring.SetUnitRulesParam(unitID, "scavboss_eating", 0)
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_state", 0)
	Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	SetFace(false)
	StartThread(RestoreAfterDelay)
end

local function PickWreck()
	local x, y, z = Spring.GetUnitPosition(unitID)
	local best, bestDist = nil, math.huge
	for _, featureID in ipairs(Spring.GetFeaturesInSphere(x, y, z, RAISE.search)) do
		local rezName = Spring.GetFeatureResurrect(featureID)
		if rezName and rezName ~= "" then
			local fx, _, fz = Spring.GetFeaturePosition(featureID)
			local dist = (fx - x) ^ 2 + (fz - z) ^ 2
			if dist < bestDist then
				best, bestDist = featureID, dist
			end
		end
	end
	return best
end

RAISE.Fuel = function()
	local team = Spring.GetUnitTeam(unitID)
	if (Spring.GetTeamLuaAI(team) or "") == "" then
		return
	end
	local energy, storage = Spring.GetTeamResources(team, "energy")
	if energy and energy < RAISE.energy then
		if storage < RAISE.energy then
			Spring.SetTeamResource(team, "es", RAISE.energy)
		end
		Spring.SetTeamResource(team, "e", RAISE.energy)
	end
end

local function Raise()
	Spring.SetUnitRulesParam(unitID, "scavboss_raise", 0)
	Spring.SetUnitRulesParam(unitID, "scavboss_raise_state", 1)
	Sleep(RAISE.grace * 1000)
	eating, isAiming = true, true
	Spring.SetUnitRulesParam(unitID, "scavboss_eating", 1)
	Spring.SetUnitRulesParam(unitID, "scavboss_raise_state", 2)
	Signal(SIG_ALL_AIM)
	Signal(SIG_RESTORE)
	SetFace(true)
	if GG.ScavBossFeedingEffect then
		GG.ScavBossFeedingEffect(unitID, unitDefID, 1)
	end
	local boost = 1
	if Spring.GetGameSeconds() >= RAISE.lateMinute * 60 then
		local health, maxHealth = Spring.GetUnitHealth(unitID)
		boost = 1 + (RAISE.lateBoost - 1) * (1 - (health or 1) / (maxHealth or 1))
	end
	local def = UnitDefs[unitDefID]
	Spring.SetUnitBuildSpeed(unitID, def.buildSpeed, nil, nil, def.resurrectSpeed * boost)
	local worked, walked = 0, 0
	while worked < RAISE.duration and walked < RAISE.walkTime and not Spring.GetUnitIsStunned(unitID) do
		local wreck = PickWreck()
		if not wreck then
			break
		end
		Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, { Game.maxUnits + wreck }, 0)
		local onWreck = 0
		while
			Spring.ValidFeatureID(wreck)
			and onWreck < RAISE.perWreck
			and worked < RAISE.duration
			and walked < RAISE.walkTime
			and not Spring.GetUnitIsStunned(unitID)
		do
			local fx, _, fz = Spring.GetFeaturePosition(wreck)
			local x, _, z = Spring.GetUnitPosition(unitID)
			local near = (fx - x) ^ 2 + (fz - z) ^ 2 <= EAT_RANGE ^ 2
			if near ~= posed then
				posed = near
				SetRaisePose(near)
			end
			if near then
				worked, onWreck = worked + 0.25, onWreck + 0.25
			else
				walked = walked + 0.25
			end
			RAISE.Fuel()
			Sleep(250)
		end
	end
	eating, posed = false, false
	Spring.SetUnitRulesParam(unitID, "scavboss_eating", 0)
	Spring.SetUnitRulesParam(unitID, "scavboss_raise_state", 0)
	Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	SetFace(false)
	SetRaisePose(false)
	StartThread(RestoreAfterDelay)
end

TURBO.Food = function()
	local x, y, z = Spring.GetUnitPosition(unitID)
	local wrecks, metal = 0, 0
	for _, featureID in ipairs(Spring.GetFeaturesInSphere(x, y, z, RAISE.search)) do
		local rezName = Spring.GetFeatureResurrect(featureID)
		if rezName and rezName ~= "" then
			wrecks = wrecks + 1
		end
		if FeatureDefs[Spring.GetFeatureDefID(featureID)].reclaimable then
			metal = metal + (Spring.GetFeatureResources(featureID) or 0)
		end
	end
	for _, otherID in ipairs(Spring.GetUnitsInSphere(x, y, z, EAT_RANGE)) do
		if IsPrey(otherID) then
			metal = metal + UnitDefs[Spring.GetUnitDefID(otherID)].metalCost
		end
	end
	return wrecks, metal
end

TURBO.Pick = function(health)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local score = { air = 0, close = 0, far = 0, swarm = 0, beam = 0 }
	for _, otherID in ipairs(Spring.GetUnitsInCylinder(x, z, TURBO.range)) do
		local team = Spring.GetUnitTeam(otherID)
		if team and team ~= myTeam and not Spring.AreTeamsAllied(team, myTeam) then
			local def = UnitDefs[Spring.GetUnitDefID(otherID)]
			local kind = "swarm"
			if def.canFly then
				kind = "air"
			elseif (Spring.GetUnitSeparation(unitID, otherID, true) or 0) < TURBO.nearRange then
				kind = "close"
			elseif def.metalCost >= TURBO.heavyCost then
				kind = "far"
			end
			score[kind] = score[kind] + 1
		end
	end
	score.beam = score.close
	if health > TURBO.volleyHealth then
		score.close = 0
	end
	if health <= TURBO.raiseHealth and TURBO.Food() >= TURBO.raiseWrecks and math.random() < TURBO.abilityChance then
		return "raise"
	end
	local best, bestScore = nil, 0
	for _, kind in ipairs(TURBO.kinds) do
		local points = score[kind] > 0 and score[kind] + math.random(0, TURBO.luck) or 0
		if points > bestScore then
			best, bestScore = kind, points
		end
	end
	return best
end

TURBO.Signal = function(kind)
	if kind == "far" then
		RailSpark()
	elseif kind == "close" and GG.SpawnEnvironmentalLightning then
		for _, hinge in ipairs(TURBO.hinges) do
			local x, y, z = Spring.GetUnitPiecePosDir(unitID, hinge)
			GG.SpawnEnvironmentalLightning("commanderspawn", x, y, z, RAIL.sparkSize, RAIL.sparkStrength)
		end
	end
end

TURBO.Set = function(kind, on)
	if kind == "far" then
		local def = WeaponDefs[UnitDefs[unitDefID].weapons[RAIL.rapid].weaponDef]
		TURBO.Boost(RAIL.rapid, on and TURBO.railDamage or 1)
		Spring.SetUnitWeaponState(unitID, RAIL.rapid, "reloadTime", on and def.salvoSize * def.salvoDelay or def.reload)
		if on then
			Spring.SetUnitWeaponState(unitID, RAIL.rapid, "reloadFrame", Spring.GetGameFrame())
		end
	elseif kind == "beam" then
		TURBO.Boost(BEAM.weapon, on and TURBO.beamDamage or 1)
	elseif kind == "swarm" then
		if on and podMode == POD_BARRAGE then
			StartThread(NextPodMode)
		end
		for num = 8, 9 do
			local def = WeaponDefs[UnitDefs[unitDefID].weapons[num].weaponDef]
			Spring.SetUnitWeaponState(unitID, num, "burst", def.salvoSize * (on and TURBO.rainRockets or 1))
		end
	end
end

local function TurboLoop()
	local waited = 0
	while true do
		Sleep(1000)
		local health, maxHealth = Spring.GetUnitHealth(unitID)
		health = (health or 1) / (maxHealth or 1)
		local order = Spring.GetUnitRulesParam(unitID, "scavboss_turbo") or "auto"
		local only = Spring.GetUnitRulesParam(unitID, "scavboss_weapons") or "all"
		local kind
		if order ~= "auto" and order ~= "off" then
			kind = order
			Spring.SetUnitRulesParam(unitID, "scavboss_turbo", "auto")
		elseif order == "auto" and only == "all" and not eating and not Spring.GetUnitIsStunned(unitID) then
			waited = waited + 1
			if waited >= TURBO.waitBase + TURBO.waitPerHealth * health * 100 then
				kind = TURBO.Pick(health)
				waited = waited - 3
			end
		end
		if kind then
			waited = 0
			Spring.Echo("scav boss turbo: " .. kind)
			if kind == "devour" or kind == "raise" then
				Spring.SetUnitRulesParam(unitID, kind == "devour" and "scavboss_feed" or "scavboss_raise", 1)
				Sleep(5000)
				while eating do
					Sleep(500)
				end
			else
				if TURBO.signal[kind] then
					if kind == "close" and GG.ScavBossFeedingEffect then
						GG.ScavBossFeedingEffect(unitID, unitDefID, 4)
						GG.ScavBossFeedingEffect(unitID, unitDefID, 5)
					end
					for _ = 1, TURBO.telegraph * 2 do
						TURBO.Signal(kind)
						Sleep(500)
					end
				end
				TURBO.kind = kind
				TURBO.Set(kind, true)
				local hold = TURBO.hold[kind]
				local stop = Spring.GetGameFrame() + math.random(TURBO.duration[1], TURBO.duration[2]) * Game.gameSpeed
				Sleep(2000)
				while Spring.GetGameFrame() < stop and not eating do
					if Spring.GetGameFrame() - (ACT.want[hold] or -1000) > TURBO.stale * Game.gameSpeed then
						break
					end
					if kind == "close" then
						TURBO.Signal(kind)
					end
					Sleep(500)
				end
				TURBO.Set(kind, false)
				TURBO.kind = false
				ACT.done = true
				Spring.Echo("scav boss turbo ended")
			end
		end
	end
end

local function SetBeamReady(ready)
	local frame = Spring.GetGameFrame() + (ready and 0 or 1000000)
	Spring.SetUnitWeaponState(unitID, BEAM.weapon, "reloadFrame", frame)
end

local function BeamLoop()
	local waited, faceOpen = 0, false
	SetBeamReady(false)
	while true do
		Sleep(250)
		local frame = Spring.GetGameFrame()
		local on = ACT.current == "beam" and not eating
		if on and not BEAM.active then
			BEAM.active, BEAM.due, waited = true, false, 0
			SetBeamReady(true)
		elseif BEAM.active and not on then
			BEAM.active = false
			BEAM.lastShot = frame
			SetBeamReady(false)
		elseif not BEAM.active and not eating and not Spring.GetUnitIsStunned(unitID) then
			waited = waited + 0.25
			BEAM.due = waited >= BEAM.every
		end
		local wantOpen = BEAM.active or frame - BEAM.lastShot < BEAM.closeDelay * Game.gameSpeed
		if wantOpen then
			SetFace(true)
		elseif faceOpen and not eating then
			SetFace(false)
		end
		faceOpen = wantOpen
	end
end

local function Director()
	while true do
		Sleep(500)
		local frame = Spring.GetGameFrame()
		local fresh = ACT.idle * Game.gameSpeed
		local held = TURBO.hold[TURBO.kind or ""]
		local forced = ACT.of[Spring.GetUnitRulesParam(unitID, "scavboss_weapons") or ""] or (held ~= "aa" and held)
		if Spring.GetUnitRulesParam(unitID, "scavboss_rail") == 1 then
			Spring.SetUnitRulesParam(unitID, "scavboss_rail", 0)
			ACT.done = true
		end
		if forced then
			if ACT.current ~= forced then
				ACT.current, ACT.started, ACT.done = forced, frame, false
			end
		elseif not eating then
			local idle = frame - (ACT.want[ACT.current] or -1000) > fresh
			if ACT.done or idle or frame - ACT.started > (ACT.time[ACT.current] or 0) * Game.gameSpeed then
				local nextAct
				if BEAM.due and ACT.current ~= "beam" and frame - (ACT.want.beam or -1000) <= fresh then
					nextAct = "beam"
				else
					for _ = 1, #ACT.order do
						ACT.index = ACT.index % #ACT.order + 1
						if frame - (ACT.want[ACT.order[ACT.index]] or -1000) <= fresh then
							nextAct = ACT.order[ACT.index]
							break
						end
					end
				end
				if nextAct then
					if nextAct ~= ACT.current then
						ACT.current = "none"
						Sleep(ACT.gap * 1000)
					end
					ACT.current, ACT.started, ACT.done = nextAct, Spring.GetGameFrame(), false
				end
			end
		end
	end
end

local function FeedWatch()
	while true do
		Sleep(500)
		local health, maxHealth = Spring.GetUnitHealth(unitID)
		if Spring.GetUnitIsStunned(unitID) then
			HUNGER.value = 0
		end
		if
			not eating
			and (health or 1) / (maxHealth or 1) <= HUNGER.health
			and not Spring.GetUnitIsStunned(unitID)
			and Spring.GetUnitRulesParam(unitID, "scavboss_turbo") ~= "off"
		then
			local kills = (Spring.GetUnitRulesParam(unitID, "scavboss_bigkills") or 0) - HUNGER.killsAtMeal
			local fill = HUNGER.fillSeconds
				- (HUNGER.fillSeconds - HUNGER.minSeconds) * math.min(1, kills / HUNGER.killsForMin)
			HUNGER.value = math.min(100, HUNGER.value + 50 / fill)
			if HUNGER.value >= HUNGER.trigger then
				Feed()
			end
		end
		Spring.SetUnitRulesParam(unitID, "scavboss_hunger", math.floor(HUNGER.value))
		if Spring.GetUnitRulesParam(unitID, "scavboss_feed") == 1 and not eating then
			Feed()
		end
		if Spring.GetUnitRulesParam(unitID, "scavboss_raise") == 1 and not eating then
			Raise()
		end
		if Spring.GetUnitRulesParam(unitID, "scavboss_blast") == 1 and not eating then
			Spring.SetUnitRulesParam(unitID, "scavboss_blast", 0)
			eating = true
			Spring.SetUnitRulesParam(unitID, "scavboss_eating", 1)
			Signal(SIG_ALL_AIM)
			SetFace(true)
			Detonate()
			eating = false
			Spring.SetUnitRulesParam(unitID, "scavboss_eating", 0)
			Spring.SetUnitRulesParam(unitID, "scavboss_feed_state", 0)
			SetFace(false)
		end
		if Spring.GetUnitRulesParam(unitID, "scavboss_shield") == 1 then
			Spring.SetUnitRulesParam(unitID, "scavboss_shield", 0)
			At(T_AURA - T_SHIELD_ON, ChargeAura)
			At(T_SHIELD_OFF - T_SHIELD_ON, ShieldOff)
			At(T_AURA_OFF - T_SHIELD_ON, PopAura)
			ShieldOn()
		end
	end
end

function script.QueryNanoPiece()
	return P.eaterbeamflare
end

function script.StartBuilding(heading)
	Signal(SIG_ALL_AIM)
	Signal(SIG_RESTORE)
	SetSignalMask(SIG_RESTORE)
	isAiming = true
	SetFace(true)
	Turn(P.torsobase, y_axis, heading, TORSO_SPEED)
	WaitForTurn(P.torsobase, y_axis)
	Spring.UnitScript.SetUnitValue(COB.INBUILDSTANCE, true)
end

function script.StopBuilding()
	Spring.UnitScript.SetUnitValue(COB.INBUILDSTANCE, false)
	if not eating and not BEAM.active then
		SetFace(false)
	end
	StartThread(RestoreAfterDelay)
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
	StartThread(StopWalking)
	Spring.SetUnitRulesParam(unitID, "scavboss_feed_goal", FEED_GOAL)
	StartThread(FeedWatch)
	StartThread(BeamLoop)
	StartThread(Director)
	StartThread(TurboLoop)
	StartThread(RailLoop)
	StartThread(RailController)
	StartThread(VolleyCooldown)
end

function script.Killed()
	return 1
end
