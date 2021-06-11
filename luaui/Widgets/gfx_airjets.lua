--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Airjets",
		desc = "Thruster effects on air jet exhausts (auto limits and disables when low fps)",
		author = "GoogleFrog, jK, Floris",
		date = "9 May 2020",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- 'Speedups'
--------------------------------------------------------------------------------

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRotation = Spring.GetUnitRotation
local spGetUnitPieceInfo = Spring.GetUnitPieceInfo

local math_cos = math.cos
local math_sin = math.sin
local math_rad = math.rad
local math_random = math.random

local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitPieceMap = Spring.GetUnitPieceMap
local spIsUnitVisible = Spring.IsUnitVisible
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitTeam = Spring.GetUnitTeam
local spGetFPS = Spring.GetFPS

local glUseShader = gl.UseShader
local glUniform = gl.Uniform
local glBlending = gl.Blending
local glTexture = gl.Texture
local glCallList = gl.CallList

local GL_GREATER = GL.GREATER
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE

local glMultiTexCoord = gl.MultiTexCoord
local glVertex = gl.Vertex
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glBeginEnd = gl.BeginEnd
local GL_QUADS = GL.QUADS

local glAlphaTest = gl.AlphaTest
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask

local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glScale = gl.Scale
local glUnitMultMatrix = gl.UnitMultMatrix
local glUnitPieceMultMatrix = gl.UnitPieceMultMatrix

local gaiaID = Spring.GetGaiaTeamID()

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local enableLights = true

local disableAtAvgFps = 8
local limitAtAvgFps = 16	-- filter spammy units: fighters/scouts
local avgFpsThreshold = 6   -- have this more fps than disableAtAvgFps to re-enable

local lightMult = 1.4

local effectDefs = {

	-- scouts
	["armpeep"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 20, piece = "jet1", limit = true },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 20, piece = "jet2", limit = true },
	},
	["corfink"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 2.2, length = 15, piece = "thrusta", limit = true  },
		{ color = { 0.7, 0.4, 0.1 }, width = 2.2, length = 15, piece = "thrustb", limit = true  },
	},

	-- fighters
	["armfig"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 45, piece = "thrust", limit = true },
	},
	["corveng"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 20, piece = "thrust1", limit = true  },
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 20, piece = "thrust2", limit = true  },
	},
	["armsfig"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 25, piece = "thrust", limit = true },
	},
	["corsfig"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 32, piece = "thrust", limit = true },
	},
	["armhawk"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrust", limit = true },
	},
	["corvamp"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 35, piece = "thrusta", limit = true },
	},

	-- radar
	["armawac"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 30, piece = "thrust", light = 1 },
	},
	["corawac"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 30, piece = "lthrust", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 30, piece = "mthrust", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 30, piece = "rthrust", light = 1 },
	},
	["corhunt"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 37, piece = "thrust", light = 1 },
	},
	["armsehak"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3.5, length = 37, piece = "thrust", light = 1 },
	},

	-- transports
	["armatlas"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 12, piece = "thrustl", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 12, piece = "thrustr", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 15, piece = "thrustm", light = 1 }, --, xzVelocity = 1.5 -- removed xzVelocity else the other thrusters get disabled as well
	},
	["corvalk"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust1", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust3", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust2", emitVector = { 0, 1, 0 }, light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 17, piece = "thrust4", emitVector = { 0, 1, 0 }, light = 1 },
	},
	["armdfly"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 35, piece = "thrusta", xzVelocity = 1.5, light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 35, piece = "thrustb", xzVelocity = 1.5, light = 1 },
	},
	["corseah"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 13, length = 25, piece = "thrustrra", emitVector = { 0, 1, 0 }, light = 0.75 },
		{ color = { 0.1, 0.4, 0.6 }, width = 13, length = 25, piece = "thrustrla", emitVector = { 0, 1, 0 }, light = 0.75 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "thrustfra", emitVector = { 0, 1, 0 }, light = 0.75 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 25, piece = "thrustfla", emitVector = { 0, 1, 0 }, light = 0.75 },
	},

	-- gunships
	["armkam"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 28, piece = "thrusta", xzVelocity = 1.5, light = 1, emitVector = { 0, 1, 0 } },
		{ color = { 0.7, 0.4, 0.1 }, width = 3, length = 28, piece = "thrustb", xzVelocity = 1.5, light = 1, emitVector = { 0, 1, 0 } },
	},
	["armblade"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 25, piece = "thrust", light = 1, xzVelocity = 1.5 },
	},
	["corape"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 16, piece = "rthrust", emitVector = { 0, 0, -1 }, xzVelocity = 1.5, light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 16, piece = "lthrust", emitVector = { 0, 0, -1 }, xzVelocity = 1.5, light = 1 },
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="lhthrust1", emitVector= {1,0,0}, light=1},
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="rhthrust2", emitVector= {1,0,0}, light=1},
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="lhthrust2", emitVector= {-1,0,0}, light=1},
		--{color={0.1,0.4,0.6}, width=2.2, length=4.7, piece="rhthrust1", emitVector= {-1,0,0}, light=1},
	},
	["armseap"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 35, piece = "thrustm", light = 1 },
	},
	["corseap"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3, length = 32, piece = "thrust", light = 1 },
	},
	["corcrw"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 12, length = 36, piece = "thrustrra", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 12, length = 36, piece = "thrustrla", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 30, piece = "thrustfra", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 10, length = 30, piece = "thrustfla", emitVector = { 0, 1, 0 }, light = 0.6 },
	},
	["corcrwt4"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 19, length = 50, piece = "thrustrra", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 19, length = 50, piece = "thrustrla", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 17, length = 44, piece = "thrustfra", emitVector = { 0, 1, 0 }, light = 0.6 },
		{ color = { 0.1, 0.4, 0.6 }, width = 17, length = 44, piece = "thrustfla", emitVector = { 0, 1, 0 }, light = 0.6 },
	},
	["corcut"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.7, length = 15, piece = "thrusta", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.7, length = 15, piece = "thrustb", light = 1 },
	},
	--["armbrawl"] = {
	--	{ color = { 0.1, 0.4, 0.6 }, width = 3.7, length = 15, piece = "thrust1", light = 1 },
	--	{ color = { 0.1, 0.4, 0.6 }, width = 3.7, length = 15, piece = "thrust2", light = 1 },
	--},

	-- bombers
	["armstil"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 40, piece = "thrusta", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 40, piece = "thrustb", light = 1 },
	},
	["armthund"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust2" },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust3" },
		{ color = { 0.7, 0.4, 0.1 }, width = 2, length = 17, piece = "thrust4", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 25, piece = "thrustc", light = 1.3 },
	},
	["armthundt4"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust2" },
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust3" },
		{ color = { 0.7, 0.4, 0.1 }, width = 9, length = 60, piece = "thrust4", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 85, piece = "thrustc", light = 1.3 },
	},
	["armpnix"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 7, length = 35, piece = "thrusta", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 7, length = 35, piece = "thrustb", light = 1 },
	},
	["corshad"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 24, piece = "thrusta1", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 4, length = 24, piece = "thrusta2", light = 1 },
		{ color = { 0.7, 0.4, 0.1 }, width = 5, length = 33, piece = "thrustb", light = 1 },
	},
	["armliche"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 44, piece = "thrusta", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 44, piece = "thrustb", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 3.5, length = 44, piece = "thrustc", light = 1 },
	},
	["cortitan"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta1", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta2", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrustb1", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrustb2", light = 1 },
	},
	["armlance"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 40, piece = "thrust1", light = 1 },
	},
	["corhurc"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 8, length = 50, piece = "thrustb", light = 1 },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta1" },
		{ color = { 0.1, 0.4, 0.6 }, width = 5, length = 35, piece = "thrusta2" },
	},
	["armsb"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 4, length = 36, piece = "thrustc", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 2.2, length = 18, piece = "thrusta", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 2.2, length = 18, piece = "thrustb", light = 1 },
	},
	["corsb"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 3.3, length = 40, piece = "thrusta", light = 1 },
		{ color = { 0.2, 0.8, 0.2 }, width = 3.3, length = 40, piece = "thrustb", light = 1 },
	},

	-- construction
	["armca"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 6, length = 24, piece = "thrust", xzVelocity = 1.2 },
	},
	["armaca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 6, length = 22, piece = "thrust", xzVelocity = 1.2 },
	},
	["corca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 4, length = 15, piece = "thrust", xzVelocity = 1.2 },
	},
	["coraca"] = {
		{ color = { 0.1, 0.4, 0.6 }, width = 6, length = 22, piece = "thrust", xzVelocity = 1.2 },
	},
	["armcsa"] = {
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 17, piece = "thrusta" },
		{ color = { 0.2, 0.8, 0.2 }, width = 5, length = 17, piece = "thrustb" },
	},

	-- flying ships
	["armfepocht4"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 27, piece = "thrustl1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 13, length = 27, piece = "thrustr1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 17, length = 38, piece = "thrustl2", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 17, length = 38, piece = "thrustr2", light = 0.62 },
	},
	["corfblackhyt4"] = {
		{ color = { 0.7, 0.4, 0.1 }, width = 14, length = 27, piece = "thrustl1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 14, length = 27, piece = "thrustr1", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 19, length = 38, piece = "thrustl2", light = 0.62 },
		{ color = { 0.7, 0.4, 0.1 }, width = 19, length = 38, piece = "thrustr2", light = 0.62 },
	},
}

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

for name, effects in pairs(effectDefs) do
	if UnitDefNames[name..'_scav'] then
		effectDefs[name..'_scav'] = deepcopy(effects)
		for i,effect in pairs(effects) do
			effectDefs[name..'_scav'][i].color = {0.6, 0.12, 0.7}
		end
	end
end

local distortion = 0.008
local animSpeed = 3
local jitterWidthScale = 3
local jitterLengthScale = 3
local drawReflectionPass = false	-- eats quite a bit extra perf

local texture1 = "bitmaps/GPL/Lups/perlin_noise.jpg"    -- noise texture
local texture2 = ":c:bitmaps/gpl/lups/jet2.bmp"        -- shape
local texture3 = ":c:bitmaps/GPL/Lups/jet.bmp"        -- jitter shape

local xzVelocityUnits = {}
local defs = {}
local limitDefs = {}
for name, effects in pairs(effectDefs) do
	for fx, data in pairs(effects) do
		if not effectDefs[name][fx].emitVector then
			effectDefs[name][fx].emitVector = { 0, 0, -1 }
		end
		if effectDefs[name][fx].xzVelocity then
			xzVelocityUnits[UnitDefNames[name].id] = effectDefs[name][fx].xzVelocity
		end
		if effectDefs[name][fx].limit then
			limitDefs[UnitDefNames[name].id] = true
		end
	end
	if UnitDefNames[name] then
		defs[UnitDefNames[name].id] = effectDefs[name]
	else
		Spring.Echo("Airjets: Error: unitdef name '"..name.."' doesnt exist")
	end
end
effectDefs = defs
defs = nil

local lightDefs = {}
for name, effects in pairs(effectDefs) do
	for fx, data in pairs(effects) do
		if data.light then
			lightDefs[name] = true
			effectDefs[name][fx].light = data.light * lightMult
		end
	end
end

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

local activePlanes = {}
local inactivePlanes = {}
local lights = {}
local unitPieceOffset = {}

local shaders
local lastGameFrame = Spring.GetGameFrame()
local sceduledFpsCheckGf = lastGameFrame + 30
local updateSec = 0

local enabled = true
local limit = false
local averageFps = 100
local lighteffectsEnabled = (enableLights and WG['lighteffects'] ~= nil and WG['lighteffects'].enableThrusters)

--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------

local function Draw(unitID, unitDefID)
	local unitEffects = effectDefs[unitDefID]

	glPushMatrix()
	glUnitMultMatrix(unitID)
	for i = 1, #unitEffects do
		local fx = unitEffects[i]
		if fx.piecenum then
			--Spring.Echo(UnitDefs[unitDefID].name)		-- echo to find out which unit is has wrongly configured piecenames
			--// enter piece space
			glPushMatrix()
			glUnitPieceMultMatrix(unitID, fx.piecenum)
			glScale(1, 1, -1)
			glTexture(1, texture1)
			glTexture(2, texture2)
			glCallList(fx.dList)
			glPopMatrix()

			-- add deferred light
			if lighteffectsEnabled and lightDefs[unitDefID] then
				local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
				if unitPosZ then
					local _, yaw = spGetUnitRotation(unitID)
					if yaw then
						local lightOffset = unitPieceOffset[unitID..'_'..fx.piecenum]

						-- still just only Y thus inacurate
						local lightOffsetRotYx = lightOffset[1]*math_cos(3.1415+math_rad( 90+(((yaw+1.571)/6.2)*360) ))- lightOffset[3]*math_sin(3.1415+math_rad(90+ (((yaw+1.571)/6.2)*360) ))
						local lightOffsetRotYz = lightOffset[1]*math_sin(3.1415+math_rad( 90+(((yaw+1.571)/6.2)*360) ))+ lightOffset[3]*math_cos(3.1415+math_rad(90+ (((yaw+1.571)/6.2)*360) ))

						if not lights[unitID] then
							if not fx.color[4] then
								fx.color[4] = fx.light * 0.66
							end
							if not lights[unitID] then
								lights[unitID] = {}
							end
							lights[unitID][i] = WG['lighteffects'].createLight('thruster',unitPosX+lightOffsetRotYx, unitPosY+lightOffset[2], unitPosZ+lightOffsetRotYz, 0.8 * fx.width * fx.length, fx.color)
						elseif lights[unitID][i] then
							if not WG['lighteffects'].editLightPos(lights[unitID][i], unitPosX+lightOffsetRotYx, unitPosY+lightOffset[2], unitPosZ+lightOffsetRotYz) then
								fx.lightID = nil
							end
						end
					end
				end
			end
		end
		--// leave piece space
	end

	--// leave unit space
	glPopMatrix()
end

local function DrawParticles()
	if not enabled then return false end

	glDepthTest(true)
	glAlphaTest(false)

	glAlphaTest(GL_GREATER, 0)

	glUseShader(shaders.jet)
	glUniform(shaders.timerUniform, spGetGameSeconds())
	glBlending(GL_ONE, GL_ONE)
	for unitID, unitDefID in pairs(activePlanes) do
		Draw(unitID, unitDefID)
	end
	glUseShader(0)
	glTexture(1, false)
	glTexture(2, false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	glAlphaTest(false)
	glDepthTest(false)
end


--------------------------------------------------------------------------------
-- Unit Handling
--------------------------------------------------------------------------------

local function RemoveLights(unitID)
	if lighteffectsEnabled and lights[unitID] then
		for i,v in pairs(lights[unitID]) do
			WG['lighteffects'].removeLight(lights[unitID][i], 3)
		end
		lights[unitID] = nil
	end
end

local function Activate(unitID, unitDefID)
	activePlanes[unitID] = unitDefID
	inactivePlanes[unitID] = nil
end

local function Deactivate(unitID, unitDefID)
	activePlanes[unitID] = nil
	inactivePlanes[unitID] = unitDefID
	RemoveLights(unitID)
end

local function RemoveUnit(unitID, unitDefID, unitTeamID)
	if effectDefs[unitDefID] then
		activePlanes[unitID] = nil
		inactivePlanes[unitID] = nil
		RemoveLights(unitID)
		for i = 1, #effectDefs[unitDefID] do
			if effectDefs[unitDefID][i].piecenum then
				unitPieceOffset[unitID..'_'..effectDefs[unitDefID][i].piecenum] = nil
			end
		end
	end
end

local function FinishInitialization(unitID, effectDef)
	local pieceMap = spGetUnitPieceMap(unitID)
	for i = 1, #effectDef do
		local fx = effectDef[i]
		if fx.piece then
			fx.piecenum = pieceMap[fx.piece]
		end
	end
	effectDef.finishedInit = true
end

local function AddUnit(unitID, unitDefID, unitTeamID)
	if not effectDefs[unitDefID] then
		return false
	end
	if not effectDefs[unitDefID].finishedInit then
		FinishInitialization(unitID, effectDefs[unitDefID])
	end
	if spGetUnitIsActive(unitID) and not spGetUnitIsStunned(unitID) and (not limit or not limitDefs[unitDefID]) then
		local uvx,_,uvz = spGetUnitVelocity(unitID)
		if xzVelocityUnits[unitDefID] and math.abs(uvx)+math.abs(uvz) < xzVelocityUnits[unitDefID] then
			Deactivate(unitID, unitDefID)
		else
			Activate(unitID, unitDefID)
		end
	else
		Deactivate(unitID, unitDefID)
	end
	if lighteffectsEnabled and lightDefs[unitDefID] then
		for i = 1, #effectDefs[unitDefID] do
			if effectDefs[unitDefID][i].piecenum then
				unitPieceOffset[unitID..'_'..effectDefs[unitDefID][i].piecenum] = spGetUnitPieceInfo(unitID, effectDefs[unitDefID][i].piecenum).offset
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Widget Interface
--------------------------------------------------------------------------------

function widget:Update(dt)
	updateSec = updateSec + dt
	local gf = Spring.GetGameFrame()
	if gf ~= lastGameFrame and updateSec > 0.22 then		-- to limit the number of unit status checks
		lastGameFrame = gf
		updateSec = 0
		for unitID, unitDefID in pairs(inactivePlanes) do
			if not limit or not limitDefs[unitDefID] then
				if spGetUnitIsActive(unitID) then
					Activate(unitID, unitDefID)
				end
			end
		end
		for unitID, unitDefID in pairs(activePlanes) do
			if not limit or not limitDefs[unitDefID] then
				if not spGetUnitIsActive(unitID) or not spIsUnitVisible(unitID, 50, true) or spGetUnitIsStunned(unitID) then
					Deactivate(unitID, unitDefID)
				elseif xzVelocityUnits[unitDefID] then
					local uvx,_,uvz = spGetUnitVelocity(unitID)
					if math.abs(uvx)+math.abs(uvz) < xzVelocityUnits[unitDefID] then
						Deactivate(unitID, unitDefID)
					end
				end
			end
		end
	end

	local prevLighteffectsEnabled = lighteffectsEnabled
	lighteffectsEnabled = (enableLights and WG['lighteffects'] ~= nil and WG['lighteffects'].enableThrusters)
	if lighteffectsEnabled ~= prevLighteffectsEnabled then
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			RemoveUnit(unitID, unitDefID, spGetUnitTeam(unitID))
			AddUnit(unitID, unitDefID, spGetUnitTeam(unitID))
		end
	end

	if gf >= sceduledFpsCheckGf then
		sceduledFpsCheckGf = gf + 30
		averageFps = ((averageFps * 19) + spGetFPS()) / 20
		if enabled then
			if averageFps < disableAtAvgFps then
				enabled = false
			end
			if not limit then
				if averageFps < limitAtAvgFps then
					limit = true
					for unitID, unitDefID in pairs(activePlanes) do
						if limitDefs[unitDefID] then
							Deactivate(unitID, unitDefID)
						end
					end
				end
			else
				if averageFps >= limitAtAvgFps + avgFpsThreshold then
					limit = false
				end
			end
		else
			if averageFps >= disableAtAvgFps + avgFpsThreshold then
				enabled = true
			end
		end
	end
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	AddUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	RemoveUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	AddUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	RemoveUnit(unitID, unitDefID, unitTeam)
end

-- wont be called for enemy units nor can it read spGetUnitMoveTypeData(unitID).aircraftState anyway
function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if effectDefs[unitDefID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		RemoveUnit(unitID, unitDefID, unitTeam)
	end
end


widget.DrawWorld = DrawParticles

if drawReflectionPass then
	widget.DrawWorldReflection = DrawParticles
	widget.DrawWorldRefraction = DrawParticles
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function CreateShader()
	local jetShader = gl.CreateShader({
		vertex = [[
			uniform float timer;

			varying float distortion;
			varying vec4 texCoords;

			const vec4 centerPos = vec4(0.0,0.0,0.0,1.0);

			#define WIDTH  gl_Vertex.x
			#define LENGTH gl_Vertex.y
			#define TEXCOORD gl_Vertex.zw
			// gl_MultiTexCoord0.xy := jitter width/length scale (i.e jitter quad length = gl_vertex.x * gl_MultiTexCoord0.x)
			// gl_MultiTexCoord0.z  := (quad_width) / (quad_length) (used to normalize the texcoord dimensions)
			#define DISTORTION_STRENGTH gl_MultiTexCoord0.w
			#define EMITDIR gl_MultiTexCoord1
			#define COLOR gl_MultiTexCoord2.rgb
			#define ANIMATION_SPEED gl_MultiTexCoord2.w

			void main()
			{
				texCoords.st = TEXCOORD;
				texCoords.pq = TEXCOORD;
				texCoords.q += timer * ANIMATION_SPEED;

				gl_Position = gl_ModelViewMatrix * centerPos ;
				vec3 dir3   = vec3(gl_ModelViewMatrix * EMITDIR) - gl_Position.xyz;
				vec3 v = normalize( dir3 );
				vec3 w = normalize( -vec3(gl_Position) );
				vec3 u = normalize( cross(w,v) );
				gl_Position.xyz += WIDTH*v + LENGTH*u;
				gl_Position      = gl_ProjectionMatrix * gl_Position;

				gl_FrontColor.rgb = COLOR;

				distortion = DISTORTION_STRENGTH;
			}
		]],
		fragment = [[
			uniform sampler2D noiseMap;
			uniform sampler2D mask;

			varying float distortion;
			varying vec4 texCoords;

			void main(void)
			{
					vec2 displacement = texCoords.pq;

					vec2 txCoord = texCoords.st;
					txCoord.s += (texture2D(noiseMap, displacement * distortion * 20.0).y - 0.5) * 40.0 * distortion;
					txCoord.t +=  texture2D(noiseMap, displacement).x * (1.0-texCoords.t)        * 15.0 * distortion;
					float opac = texture2D(mask,txCoord.st).r;

					gl_FragColor.rgb  = opac * gl_Color.rgb; //color
					gl_FragColor.rgb += pow(opac, 5.0 );     //white flame
					gl_FragColor.a    = opac*1.5;
			}

		]],
		uniformInt = {
			noiseMap = 1,
			mask = 2,
		},
		uniform = {
			timer = 0,
		}
	})

	if jetShader == nil then
		print( "airjets: (color-)shader error: " .. gl.GetShaderLog() )
		return false
	end

	local jitterShader = gl.CreateShader({
		vertex = [[
			uniform float timer;

			varying float distortion;
			varying vec4 texCoords;

			const vec4 centerPos = vec4(0.0,0.0,0.0,1.0);

			#define WIDTH  gl_Vertex.x
			#define LENGTH gl_Vertex.y
			#define TEXCOORD gl_Vertex.zw
			// gl_MultiTexCoord0.xy := jitter width/length scale (i.e jitter quad length = gl_vertex.x * gl_MultiTexCoord0.x)
			// gl_MultiTexCoord0.z  := (quad_width) / (quad_length) (used to normalize the texcoord dimensions)
			#define DISTORTION_STRENGTH gl_MultiTexCoord0.w
			#define EMITDIR gl_MultiTexCoord1
			#define COLOR gl_MultiTexCoord2.rgb
			#define ANIMATION_SPEED gl_MultiTexCoord2.w

			void main()
			{
				texCoords.st  = TEXCOORD;
				texCoords.pq  = TEXCOORD*0.8;
				texCoords.p  *= gl_MultiTexCoord0.z;
				texCoords.pq += 0.2*timer*ANIMATION_SPEED;

				gl_Position = gl_ModelViewMatrix * centerPos;
				vec3 dir3   = vec3(gl_ModelViewMatrix * EMITDIR) - gl_Position.xyz;
				vec3 v = normalize( dir3 );
				vec3 w = normalize( -vec3(gl_Position) );
				vec3 u = normalize( cross(w,v) );
				float length = LENGTH * gl_MultiTexCoord0.x;
				float width  = WIDTH * gl_MultiTexCoord0.y;
				gl_Position.xyz += width*v + length*u;
				gl_Position      = gl_ProjectionMatrix * gl_Position;

				distortion = DISTORTION_STRENGTH;
			}
		]],
		fragment = [[
			uniform sampler2D noiseMap;
			uniform sampler2D mask;

			varying float distortion;
			varying vec4 texCoords;

			void main(void)
			{
					float opac    = texture2D(mask,texCoords.st).r;
					vec2 noiseVec = (texture2D(noiseMap, texCoords.pq).st - 0.5) * distortion * opac;
					gl_FragColor  = vec4(noiseVec.xy,0.0,gl_FragCoord.z);
			}

		]],
		uniformInt = {
			noiseMap = 1,
			mask = 2,
		},
		uniform = {
			timer = 0,
		}
	})

	if jitterShader == nil then
		print( "airjets: (jitter-)shader error: " .. gl.GetShaderLog() )
		return false
	end

	local timerUniform = gl.GetUniformLocation(jetShader, 'timer')
	local timer2Uniform = gl.GetUniformLocation(jitterShader, 'timer')

	return {
		jet = jetShader,
		jitter = jitterShader,
		timerUniform = timerUniform,
		timer2Uniform = timer2Uniform,
	}
end

local function BeginEndDrawList(self)
	local color = self.color
	local ev = self.emitVector
	glMultiTexCoord(0, jitterWidthScale, jitterLengthScale, self.width / self.length, distortion)
	glMultiTexCoord(1, ev[1], ev[2], ev[3], 1)
	glMultiTexCoord(2, color[1], color[2], color[3], animSpeed)

	--// xy = width/length ; zw = texcoord
	local w = self.width
	local l = self.length
	glVertex(-l, -w, 1, 0)
	glVertex(0, -w, 1, 1)
	glVertex(0, w, 0, 1)
	glVertex(-l, w, 0, 0)
end

local function InitializeParticleLists()
	for unitDefID, data in pairs(effectDefs) do
		for i = 1, #data do
			data[i].dList = glCreateList(glBeginEnd, GL_QUADS, BeginEndDrawList, data[i])
		end
	end
end

function widget:Initialize()
	shaders = CreateShader()
	InitializeParticleLists()

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		AddUnit(unitID, unitDefID, spGetUnitTeam(unitID))
	end

	WG['airjets'] = {}
	WG['airjets'].getLimitFps = function()
		return limitAtAvgFps
	end
	WG['airjets'].setLimitFps = function(value)
		limitAtAvgFps = value
	end
	WG['airjets'].getDisableFps = function()
		return disableAtAvgFps
	end
	WG['airjets'].setDisableFps = function(value)
		disableAtAvgFps = value
	end
end


function widget:Shutdown()
	for unitID, unitDefID in pairs(activePlanes) do
		RemoveUnit(unitID, unitDefID, spGetUnitTeam(unitID))
	end
	for unitDefID, data in pairs(effectDefs) do
		for i = 1, #data do
			gl.DeleteList(data[i].dList)
		end
	end
	if shaders then
		gl.DeleteShader(shaders.jet)
		gl.DeleteShader(shaders.jitter)
	end
end


function widget:GetConfigData(data)
	return {
		averageFps = math.floor(averageFps),
		disableAtAvgFps = disableAtAvgFps,
		limitAtAvgFps = limitAtAvgFps
	}
end

function widget:SetConfigData(data)
	if data.disableAtAvgFps ~= nil then
		disableAtAvgFps = data.disableAtAvgFps
	end
	if data.disableAtAvgFps ~= nil then
		limitAtAvgFps = data.limitAtAvgFps
	end
	if Spring.GetGameFrame() > 0 then
		if data.averageFps ~= nil then
			averageFps = data.averageFps
		end
	end
end
