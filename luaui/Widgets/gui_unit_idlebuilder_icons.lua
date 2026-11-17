local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Idle Builder Icons",
		desc = "Shows the sleeping icon above workers that are idle",
		author = "Floris, Beherith",
		date = "June 2024",
		license = "GNU GPL, v2 or later",
		layer = -40,
		enabled = true,
	}
end

local onlyOwnTeam = true

local idleUnitDelay = 8 -- how long a unit must be idle before the icon shows up

local iconSequenceImages = "Luaui/Images/idleicon/idlecon_" -- must be png's
local iconSequenceNum = 59 -- always starts at 1
local iconSequenceFrametime = 0.02 -- duration per frame

local iconSequenceTextures = {}
for i = 1, iconSequenceNum do
	iconSequenceTextures[i] = iconSequenceImages .. (i < 100 and "0" or "") .. (i < 10 and "0" or "") .. i .. ".png"
end

-- "UnitIconDistance" is not an engine setting, so this is the default unless someone sets it
local iconDistance = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
local shaderIconDistance

local unitScope = {} -- table of teamid to table of stallable unitID : unitDefID
local idleUnitList = {}
local inIdleWorkerTask = table.ensureTable(WG, "InIdleWorkerTask")

local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetFactoryCommandCount = Spring.GetFactoryCommandCount
local spGetUnitTeam = Spring.GetUnitTeam
local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetLocalTeamID()
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spIsGUIHidden = Spring.IsGUIHidden

---@type table<integer, table>
local unitConf = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams
	if not (cp.virtualunit == "1") then
		if
			unitDef.buildSpeed > 0
			and not string.find(unitDef.name, "spy")
			and not string.find(unitDef.name, "infestor")
			and (unitDef.canAssist or unitDef.buildOptions[1])
			and not unitDef.customParams.isairbase
		then
			local xsize, zsize = unitDef.xsize, unitDef.zsize
			local scale = 3.3 * ((xsize + 2) ^ 2 + (zsize + 2) ^ 2) ^ 0.5
			unitConf[unitDefID] = { 7.5 + (scale / 2.2), unitDef.height - 0.1, unitDef.isFactory }
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- GL4 Backend stuff:

local InstanceVBOTable = gl.InstanceVBOTable

local uploadAllElements = InstanceVBOTable.uploadAllElements
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

---@type InstanceVBOTable?
local iconVBO = nil
local energyIconShader = nil
local luaShaderDir = "LuaUI/Include/"

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
	shaderConfig.BREATHESIZE = 0 --0.1
	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	iconVBO, energyIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "energy icons")
	if iconVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(iconVBO) -- clear all instances
	unitScope = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
	end
	uploadAllElements(iconVBO) -- upload them all
end

function widget:Initialize()
	if spec or not gl.CreateShader or not initGL4() then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	-- load every animation frame now: loading one inside a draw stalls ~10 ms, which hit each frame of the first cycle
	for i = 1, iconSequenceNum do
		gl.TextureInfo(iconSequenceTextures[i])
	end
	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
	end
end

local function isWorkerUnitIdle(unitID, unitDefID)
	return inIdleWorkerTask[unitID]
		or (unitConf[unitDefID][3] and spGetFactoryCommandCount(unitID) or spGetUnitCommandCount(unitID)) == 0
end

---@type number[]
local instanceData = { 0, 0, 0, 0, 0, 4, 0, 0, 0.8, 0, 1, 0, 1, 0, 0, 0, 0, 0 }

local function updateIcons(gf)
	local now = os.clock()
	for unitID, unitDefID in pairs(unitScope) do
		if isWorkerUnitIdle(unitID, unitDefID) then
			if not iconVBO.instanceIDtoIndex[unitID] then -- not already being drawn
				-- GetUnitIsDead is nil for invalid units
				if spGetUnitIsDead(unitID) == false and not spGetUnitIsBeingBuilt(unitID) then
					local idleSince = idleUnitList[unitID]
					if not idleSince then
						idleUnitList[unitID] = now
					elseif idleSince < now - idleUnitDelay then
						local conf = unitConf[unitDefID]
						instanceData[1] = conf[1]
						instanceData[2] = conf[1]
						instanceData[4] = conf[2] -- lengthwidthcornerheight
						instanceData[7] = gf -- the gameFrame (for animations)
						pushElementInstance(iconVBO, instanceData, unitID, false, true, unitID)
					end
				end
			end
		else
			if iconVBO.instanceIDtoIndex[unitID] then
				popElementInstance(iconVBO, unitID, true)
			end
			idleUnitList[unitID] = nil
		end
	end
	if iconVBO.dirty then
		uploadAllElements(iconVBO)
	end
end

function widget:GameFrame(n)
	if n % 25 == 0 then
		updateIcons(n)
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam) -- remove the corresponding ground plate if it exists
	if (not onlyOwnTeam or myTeamID == unitTeam) and unitConf[unitDefID] then
		unitScope[unitID] = unitDefID
	end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	unitScope[unitID] = nil
	if iconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(iconVBO, unitID)
	end
	idleUnitList[unitID] = nil
end

function widget:DrawScreenEffects()
	-- DrawScreenEffects so icons render after deferred lighting/distortion/bloom/tonemap;
	-- shader still uses engine cameraViewProj UBO and depth-test for terrain occlusion.
	-- Stays registered while empty: re-registering moves a widget behind the others of its layer,
	-- which would change which icon is on top when several of them overlap.
	if iconVBO.usedElements == 0 or spIsGUIHidden() then
		return
	end

	gl.DepthTest(true)
	gl.DepthMask(false)
	local clock = os.clock() * (1 * (iconSequenceFrametime * iconSequenceNum)) -- adjust speed relative to anim frame speed of 0.02sec per frame (59 frames in total)
	local animFrame = math.max(1, math.ceil(iconSequenceNum * (clock - math.floor(clock))))
	gl.Texture(iconSequenceTextures[animFrame])
	energyIconShader:Activate()
	-- addRadius stays at its default of 0
	if shaderIconDistance ~= iconDistance then
		shaderIconDistance = iconDistance
		energyIconShader:SetUniform("iconDistance", iconDistance)
	end
	iconVBO.VAO:DrawArrays(GL.POINTS, iconVBO.usedElements)
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
