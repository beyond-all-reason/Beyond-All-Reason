local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Flanking Icons GL4",
		desc = "Draws circles to show flank direction. Red is +90% damage, blue is -10% damage",
		author = "Beherith",
		date = "2021.12.17",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = false,
	}
end

-- Localized Spring API for performance
local spGetSpectatingState = Spring.GetSpectatingState

-- Configurable Parts:
local texture = "luaui/images/flank_icon.tga"
local fadespeed = 0.005
-- the shader fades an icon out (alpha = 1 - age * fadespeed); past this age it is invisible and gets dropped
local fadeFrames = math.ceil(1 / fadespeed)

---- GL4 Backend Stuff----

local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance
local uploadAllElements = InstanceVBOTable.uploadAllElements

---@type InstanceVBOTable?
local flankingVBO = nil
local flankingShader = nil
local luaShaderDir = "LuaUI/Include/"
local glTexture = gl.Texture

local udefHasFlankingIcon = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	udefHasFlankingIcon[unitDefID] = (unitDef.speed and unitDef.speed > 0) or #unitDef.weapons > 0
end

local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetLocalAllyTeamID()

local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitFlanking = Spring.GetUnitFlanking
local spGetGameFrame = Spring.GetGameFrame
local spIsUnitAllied = Spring.IsUnitAllied

local flankedUnits = {} -- [unitID] = true for the visible units that show an icon when hit
local lastHitFrame = {} -- [unitID] = frame of the last hit, for every unit with an icon

local instanceCache = {
	0,
	0,
	0,
	2, -- length,width,cornersize (0), extraheight
	0,
	4, -- teamID, vertices
	0,
	0,
	0,
	0, -- the gameFrame (for fading), the direction to rotate the circle, 0,0
	0,
	1,
	0,
	1, -- These are our default UV atlas transformations
	0,
	0,
	0,
	0,
} -- these are just padding zeros, that will get filled in

-- DrawWorldPreUnit and GameFrame only run while there are icons
local callInsActive = true

local function updateCallIns()
	local active = flankingVBO.usedElements > 0
	if active ~= callInsActive then
		callInsActive = active
		if active then
			widgetHandler:UpdateCallIn("DrawWorldPreUnit")
			widgetHandler:UpdateCallIn("GameFrame")
		else
			widgetHandler:RemoveCallIn("DrawWorldPreUnit")
			widgetHandler:RemoveCallIn("GameFrame")
		end
	end
end

local function AddPrimitiveAtUnit(unitID, gameframe) -- since the icon fades, gameframe specifies last update
	local radius = spGetUnitRadius(unitID) * 3 or 64
	local _, _, _, _, dirX, _, dirZ, _ = spGetUnitFlanking(unitID)

	local flankingangle = 0
	if dirX then
		flankingangle = math.atan2(dirX, -1.0 * dirZ)
	end
	--Spring.Echo(math.deg(flankingangle), "Flank angle = ", unitID, flankingangle, dirX, dirZ)
	instanceCache[1] = radius
	instanceCache[2] = radius
	instanceCache[7] = gameframe
	instanceCache[8] = flankingangle

	pushElementInstance(
		flankingVBO, -- push into this Instance VBO Table
		instanceCache, -- used the cached instance
		unitID, -- this is the key inside the VBO TAble, should be unique per unit
		true, -- update existing element
		true, -- noupload: hits come in bursts, the draw uploads once
		unitID
	) -- last one should be UNITID!
	lastHitFrame[unitID] = gameframe
end

local function removeIcon(unitID, noUpload)
	popElementInstance(flankingVBO, unitID, noUpload)
	lastHitFrame[unitID] = nil
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	-- because we allow updating, we are going to set these every time damage is taken (thus changing flank angle)
	if flankedUnits[unitID] then
		AddPrimitiveAtUnit(unitID, spGetGameFrame())
		updateCallIns()
	end
end

-- only registered while there are icons
function widget:GameFrame(n)
	if n % 30 == 0 then
		for unitID, hitFrame in pairs(lastHitFrame) do
			if n - hitFrame > fadeFrames then
				removeIcon(unitID, true)
			end
		end
		updateCallIns()
	end
end

-- only registered while there are icons
function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end
	if flankingVBO.dirty then
		uploadAllElements(flankingVBO)
	end
	if flankingVBO.usedElements > 0 then
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		glTexture(0, texture)
		flankingShader:Activate()
		flankingShader:SetUniform("iconDistance", disticon)
		-- addRadius stays at its default of 0
		flankingVBO.VAO:DrawArrays(GL.POINTS, flankingVBO.usedElements)
		flankingShader:Deactivate()
		glTexture(0, false)
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if not spec and fullview then
		if not spIsUnitAllied(unitID) then
			return
		end
	end
	if udefHasFlankingIcon[unitDefID] then
		flankedUnits[unitID] = true
	end
end

function widget:VisibleUnitRemoved(unitID)
	flankedUnits[unitID] = nil
	if flankingVBO.instanceIDtoIndex[unitID] then
		removeIcon(unitID)
		updateCallIns()
	end
end

local function init()
	InstanceVBOTable.clearInstanceTable(flankingVBO)
	flankedUnits = {}
	lastHitFrame = {}
	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		local visibleUnits = WG.unittrackerapi.visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
		end
	end
	updateCallIns()
end

function widget:Initialize()
	local DPatUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 1
	shaderConfig.TRANSPARENCY = 1.0 -- transparency of the stuff drawn
	shaderConfig.POST_ANIM = "v_color = vec4(vec3(1.0), 1.0 - (timeInfo.x - parameters.x)*"
		.. tostring(fadespeed)
		.. "); v_rotationY = parameters.y;" -- fading with time, and rotation passthrough
	shaderConfig.POST_SHADING = "fragColor.a = fragColor.a * g_color.a;" -- alpha blend
	shaderConfig.ANIMATION = nil
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CORNERRECT = nil
	flankingVBO, flankingShader = InitDrawPrimitiveAtUnit(shaderConfig, "FlankingIcons")
	if flankingVBO == nil then
		widgetHandler:RemoveWidget()
		return
	end

	spec, fullview = spGetSpectatingState()
	init()
end

function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetLocalAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		init()
	end
end
