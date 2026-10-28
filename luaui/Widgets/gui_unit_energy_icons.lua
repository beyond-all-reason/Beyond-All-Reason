local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Energy Icons", -- GL4
		desc = "Shows the lack of energy symbol above units",
		author = "Floris, Beherith",
		date = "October 2019",
		license = "GNU GPL, v2 or later",
		layer = -40,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitTeam = Spring.GetUnitTeam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamResources = Spring.GetTeamResources
local spGetUnitResources = Spring.GetUnitResources
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead = Spring.GetUnitIsDead
local spIsGUIHidden = Spring.IsGUIHidden

local weaponEnergyCostFloor = 6

local teamEnergy = {} -- table of teamid to current energy amount
local teamUnits = {} -- table of teamid to table of stallable unitID : unitDefID
---@type table<integer, number>
local teamMaxNeeded = {} -- [teamID] = highest neededEnergy of the units added to teamUnits[teamID]
---@type table<integer, integer>
local teamIconCount = {} -- [teamID] = number of icons shown for units of that team
---@type table<integer, integer>
local iconTeam = {} -- [unitID] = teamID, for every unit with an icon
local teamList = {} -- {team1, team2, team3....}

local chobbyInterface

-- "UnitIconDistance" is not an engine setting, so this is the default unless someone sets it
local iconDistance = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
local shaderIconDistance

---@type table<integer, table>
local unitConf = {} -- table of unitid to {iconsize, iconheight, neededEnergy, bool needsUpkeep, bool sensorUpkeep}
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6 * (xsize * xsize + zsize * zsize) ^ 0.5
	local needsUpkeep = false
	local sensorUpkeep = false
	local neededEnergy = 0
	local weapons = unitDef.weapons
	if #weapons > 0 then
		for i = 1, #weapons do
			local weaponDefID = weapons[i].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef then
				if weaponDef.stockpile then
					neededEnergy = math.floor(weaponDef.energyCost / (weaponDef.stockpileTime / 30))
				elseif weaponDef.energyCost > neededEnergy and weaponDef.energyCost >= weaponEnergyCostFloor then
					neededEnergy = weaponDef.energyCost --ToDO: Check if there is reloadtime < 1 sec else adjust similar to stockpile
				end
			end
		end
	elseif unitDef.energyUpkeep and unitDef.energyUpkeep > 0 and unitDef.energyUpkeep > unitDef.energyMake then
		neededEnergy = unitDef.energyUpkeep
		needsUpkeep = true
		-- jammers and other sensors: they keep working unpaid unless sensors require their upkeep
		sensorUpkeep = unitDef.radarDistance > 0
			or unitDef.sonarDistance > 0
			or unitDef.seismicDistance > 0
			or unitDef.radarDistanceJam > 0
			or unitDef.sonarDistanceJam > 0
	end
	if neededEnergy > 0 then
		unitConf[udid] = { 7.5 + (scale / 2.2), unitDef.height, neededEnergy, needsUpkeep, sensorUpkeep }
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- how shit should work
-- init
--stallable unitdefs
--count maxstall amount
--unitdefheights
--unitdefscales

-- on unitcreated:
-- per team
-- if unit is stallable, add to watch list
-- update maxstall
-- on destroyed:
-- per team
-- if unit in stallable list, remove from it
-- if unit in stalling list, pop it
-- update maxstall?
-- on slow update:
-- for each team
-- check if energy < maxstall
-- check if unit is under construction
-- check all stalling units if they are still stalling
-- pop if not stalling any more
-- check stallable units if they now stall
-- push if stalling
-- additional smartness for global stall/unstall

-- GL4 Backend stuff:
---@type InstanceVBOTable?
local energyIconVBO = nil
local energyIconShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable = gl.InstanceVBOTable

local uploadAllElements = InstanceVBOTable.uploadAllElements
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 0.75
	shaderConfig.ANIMATION = 1
	shaderConfig.FULL_ROTATION = 0
	shaderConfig.CLIPTOLERANCE = 1.2
	shaderConfig.INITIALSIZE = 0.22
	shaderConfig.BREATHESIZE = 0.1
	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 32 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	energyIconVBO, energyIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "energy icons")
	if energyIconVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function UpdateTeamEnergy()
	for _, teamID in ipairs(teamList) do
		teamEnergy[teamID] = spGetTeamResources(teamID, "energy")
	end
end

---@type number[]
local instanceData = { 0, 0, 0, 0, 0, 4, 0, 0, 0.75, 0, 0, 1, 0, 1, 0, 0, 0, 0 }

local function addIcon(unitID, unitDefID, teamID, gf)
	local conf = unitConf[unitDefID]
	instanceData[1] = conf[1]
	instanceData[2] = conf[1]
	instanceData[4] = conf[2] -- lengthwidthcornerheight
	instanceData[7] = gf -- the gameFrame (for animations)
	pushElementInstance(energyIconVBO, instanceData, unitID, false, true, unitID)
	iconTeam[unitID] = teamID
	teamIconCount[teamID] = (teamIconCount[teamID] or 0) + 1
end

local function removeIcon(unitID, noUpload)
	popElementInstance(energyIconVBO, unitID, noUpload)
	local teamID = iconTeam[unitID]
	iconTeam[unitID] = nil
	teamIconCount[teamID] = teamIconCount[teamID] - 1
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	local _, fullview = spGetSpectatingState()
	if not fullview then
		teamList = Spring.GetTeamList(Spring.GetLocalAllyTeamID())
	else
		teamList = Spring.GetTeamList()
	end

	teamEnergy = {} -- teams outside teamList must not keep their last known energy, see updateStalling
	UpdateTeamEnergy()
	InstanceVBOTable.clearInstanceTable(energyIconVBO) -- clear all instances
	teamUnits = {}
	teamMaxNeeded = {}
	teamIconCount = {}
	iconTeam = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
	end
	uploadAllElements(energyIconVBO) -- upload them all
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then
		return
	end

	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
	end
end

local function updateStalling()
	UpdateTeamEnergy()
	local gf = spGetGameFrame()
	-- the engine's sensors.requireUpkeep modrule, or a game-side rule announcing itself with this rules param
	local sensorsRequireUpkeep = Game.sensorsRequireUpkeep == true or spGetGameRulesParam("sensorsRequireUpkeep") == 1
	for teamID, units in pairs(teamUnits) do
		local energy = teamEnergy[teamID]
		if energy then
			if energy >= teamMaxNeeded[teamID] then
				-- no unit of this team needs more energy than it has: only drop the icons it still shows
				if (teamIconCount[teamID] or 0) > 0 then
					for unitID in pairs(units) do
						if energyIconVBO.instanceIDtoIndex[unitID] then
							removeIcon(unitID, true)
						end
					end
				end
			else
				for unitID, unitDefID in pairs(units) do
					local conf = unitConf[unitDefID]
					local neededEnergy = conf[3]
					-- more neededEnergy than we have
					local stalling = neededEnergy > energy and (sensorsRequireUpkeep or not conf[5])
					if stalling and conf[4] then
						local _, _, _, unitEnergy = spGetUnitResources(unitID)
						stalling = (unitEnergy or 999999) < neededEnergy
					end
					if stalling then
						if
							energyIconVBO.instanceIDtoIndex[unitID] == nil -- not already being drawn
							and not spGetUnitIsBeingBuilt(unitID)
							and spGetUnitIsDead(unitID) == false -- nil for invalid units
						then
							addIcon(unitID, unitDefID, teamID, gf)
						end
					elseif energyIconVBO.instanceIDtoIndex[unitID] then
						removeIcon(unitID, true)
					end
				end
			end
		end
	end
	if energyIconVBO.dirty then
		uploadAllElements(energyIconVBO)
	end
end

function widget:GameFrame(n)
	if n % 9 == 0 then
		updateStalling()
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam) -- remove the corresponding ground plate if it exists
	local conf = unitConf[unitDefID]
	if conf and not spGetUnitIsBeingBuilt(unitID) then
		local units = teamUnits[unitTeam]
		if units == nil then
			units = {}
			teamUnits[unitTeam] = units
			teamMaxNeeded[unitTeam] = 0
		end
		units[unitID] = unitDefID
		if conf[3] > teamMaxNeeded[unitTeam] then
			teamMaxNeeded[unitTeam] = conf[3]
		end
	end
end

function widget:VisibleUnitRemoved(unitID, unitDefID, unitTeam)
	if teamUnits[unitTeam] then
		teamUnits[unitTeam][unitID] = nil
	end
	if energyIconVBO.instanceIDtoIndex[unitID] then
		removeIcon(unitID)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:DrawScreenEffects()
	-- DrawScreenEffects so icons render after deferred lighting/distortion/bloom/tonemap;
	-- shader still uses engine cameraViewProj UBO and depth-test for terrain occlusion.
	-- Stays registered while empty: re-registering moves a widget behind the others of its layer,
	-- which would change which icon is on top when several of them overlap.
	if energyIconVBO.usedElements == 0 or chobbyInterface or spIsGUIHidden() then
		return
	end

	gl.DepthTest(true)
	gl.DepthMask(false)
	gl.Texture("LuaUI/Images/energy-red.png")
	energyIconShader:Activate()
	-- addRadius stays at its default of 0
	if shaderIconDistance ~= iconDistance then
		shaderIconDistance = iconDistance
		energyIconShader:SetUniform("iconDistance", iconDistance)
	end
	energyIconVBO.VAO:DrawArrays(GL.POINTS, energyIconVBO.usedElements)
	energyIconShader:Deactivate()
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(true)
end

function widget:Shutdown()
	if type(energyIconShader) == "table" then
		energyIconShader:Finalize()
		energyIconShader = nil
	end
end
