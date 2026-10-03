local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Armor Icons",
		desc = "Outlines unit icons to show armored states",
		author = "efrec",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Configuration

local armoredColor = { 0.62, 0.64, 0.67, 0.9 }
local brokenColor = { 0.58, 0.24, 0.13, 0.9 }

local armoredWidth = 1.0
local brokenWidth = 1.0 -- broken reactive armor
local borderWidth = 1.0 -- outer black outline
local pollInterval = 0.25 -- in seconds, to recheck visible units
local configInterval = 1.0 -- in seconds, to reread the engine's icon settings

-- Localization

local math_abs = math.abs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local math_clamp = math.clamp
local math_diag = math.diag

local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitIconData = Spring.GetUnitIconData
local spGetIconData = Spring.GetIconData
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local spTraceScreenRay = Spring.TraceScreenRay

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

-- Initialization

local STATE_ARMORED = 1
local STATE_BROKEN = 2

-- The engine sizes screen icons as a fraction of the larger view dimension.
local engineIconSizeMult = 0.005
local engineRayLength = 150000

local hasReactiveArmor = {}
local hasArmor = {} -- ignores units armored for invulnerability, etc.
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.reactive_armor_health and unitDef.customParams.reactive_armor_restore then
		hasReactiveArmor[unitDefID] = true
		hasArmor[unitDefID] = true
	elseif unitDef.armoredMultiple < 1 then
		hasArmor[unitDefID] = true
	end
end

local uniformInt = {
	iconAtlas0 = 0,
	iconAtlas1 = 1,
}

local uniformFloat = {
	iconSizeBase = 1,
	outlineWidth = { armoredWidth, brokenWidth },
	borderWidth = borderWidth,
	iconZoomDist = 0,
	iconFade = { 3000, 1000 },
	armoredColor = armoredColor,
	brokenColor = brokenColor,
}

local geometryShaderSource = {
	vssrcpath = "LuaUI/Shaders/UnitArmorIcons.vert.glsl",
	gssrcpath = "LuaUI/Shaders/UnitArmorIcons.geom.glsl",
	fssrcpath = "LuaUI/Shaders/UnitArmorIcons.frag.glsl",
	shaderName = "Unit Armor Icons GL4",
	uniformInt = uniformInt,
	uniformFloat = uniformFloat,
	shaderConfig = {},
}

local fallbackShaderSource = {
	vssrcpath = "LuaUI/Shaders/UnitArmorIcons_nogs.vert.glsl",
	fssrcpath = "LuaUI/Shaders/UnitArmorIcons.frag.glsl",
	shaderName = "Unit Armor Icons GL4 (NoGS)",
	uniformInt = uniformInt,
	uniformFloat = uniformFloat,
	shaderConfig = {},
}

-- Local state

local outlineVBO ---@type InstanceVBOTable?
local outlineShader
local shaderSource
local useGeometryShader = LuaShader.isGeometryShaderSupported ---@as boolean

local visibleUnits = {} -- array of unitIDs, only those with an armor def
local visibleIndex = {} -- unitID to its index in visibleUnits
local visibleDefID = {}
local visibleCount = 0
local pollCursor = 0

local outlineState = {}
local outlineOffsetX = {}
local outlineOffsetY = {}
local outlineOffsetZ = {}

local vsx, vsy = Spring.GetViewGeometry()
local iconSizeBase = 1.0
local iconFadeStart = 3000.0
local iconFadeVanish = 1000.0
local planeHeight = 0.0
local minSizeMult = 1.0
local iconZoomDist = 0.0
local iconsVisible = false
local configAge = 0
local uniformsDirty = true

local instanceCache = {}
for i = 1, 16 do
	instanceCache[i] = 0
end

local function updateIconConfig()
	iconSizeBase = math_max(1, math_max(vsx, vsy) * engineIconSizeMult * Spring.GetConfigFloat("UnitIconScaleUI", 1.0))
	iconFadeStart = Spring.GetConfigFloat("UnitIconFadeStart", 3000.0)
	iconFadeVanish = Spring.GetConfigFloat("UnitIconFadeVanish", 1000.0)
	configAge = 0
	uniformsDirty = true
end

local function removeOutline(unitID, noUpload)
	if outlineState[unitID] then
		outlineState[unitID] = nil
		outlineOffsetX[unitID] = nil
		outlineOffsetY[unitID] = nil
		outlineOffsetZ[unitID] = nil
		popElementInstance(outlineVBO, unitID, noUpload)
	end
end

local function updateUnit(unitID, noUpload)
	local armored, armorMultiple = spGetUnitArmored(unitID)

	local state
	if armored then
		state = armorMultiple < 1.0 and STATE_ARMORED or nil
	elseif armored == false and hasReactiveArmor[visibleDefID[unitID]] then
		state = STATE_BROKEN
	end

	if not state then
		if outlineState[unitID] then
			removeOutline(unitID, noUpload)
		end
		return
	end

	local x, y, z, midX, midY, midZ = spGetUnitPosition(unitID, true)
	if not midX then
		removeOutline(unitID, noUpload)
		return
	end

	-- Unit midpositions move when opening/closing and shift the icon position.
	local offsetX, offsetY, offsetZ = midX - x, midY - y, midZ - z
	if
		state == outlineState[unitID]
		and math_abs(offsetX - outlineOffsetX[unitID]) < 0.5
		and math_abs(offsetY - outlineOffsetY[unitID]) < 0.5
		and math_abs(offsetZ - outlineOffsetZ[unitID]) < 0.5
	then
		return
	end

	local iconData = spGetUnitIconData(unitID, true)
	if not iconData then
		removeOutline(unitID, noUpload)
		return
	end

	local texCoords = iconData.atlasTexCoords

	instanceCache[1] = texCoords.x0
	instanceCache[2] = texCoords.y0
	instanceCache[3] = texCoords.x1
	instanceCache[4] = texCoords.y1
	instanceCache[5] = iconData.size * 0.75 + 0.25
	instanceCache[6] = state
	instanceCache[7] = texCoords.atlasIndex
	instanceCache[9] = offsetX
	instanceCache[10] = offsetY
	instanceCache[11] = offsetZ

	outlineState[unitID] = state
	outlineOffsetX[unitID] = offsetX
	outlineOffsetY[unitID] = offsetY
	outlineOffsetZ[unitID] = offsetZ

	pushElementInstance(outlineVBO, instanceCache, unitID, true, noUpload, unitID)
end

local function addVisibleUnit(unitID, unitDefID)
	if not visibleIndex[unitID] then
		visibleCount = visibleCount + 1
		visibleUnits[visibleCount] = unitID
		visibleIndex[unitID] = visibleCount
	end
	visibleDefID[unitID] = unitDefID
end

local function removeVisibleUnit(unitID)
	local index = visibleIndex[unitID]
	if index then
		local lastUnitID = visibleUnits[visibleCount]
		visibleUnits[index] = lastUnitID
		visibleIndex[lastUnitID] = index
		visibleUnits[visibleCount] = nil
		visibleIndex[unitID] = nil
		visibleDefID[unitID] = nil
		visibleCount = visibleCount - 1
	end
end

local lastCamX, lastCamY, lastCamZ, lastDirX, lastDirY, lastDirZ

local function updateIconZoomDist()
	---The engine fades icons by distance along the view direction to the ground.
	local camX, camY, camZ = spGetCameraPosition()
	local dirX, dirY, dirZ = spGetCameraDirection()
	if
		camX == lastCamX
		and camY == lastCamY
		and camZ == lastCamZ
		and dirX == lastDirX
		and dirY == lastDirY
		and dirZ == lastDirZ
	then
		return
	end

	lastCamX, lastCamY, lastCamZ = camX, camY, camZ
	lastDirX, lastDirY, lastDirZ = dirX, dirY, dirZ

	-- We avoid retracing via the camera comparison checks above.
	local _, position = spTraceScreenRay(vsx * 0.5, vsy * 0.5, true, false, false, true)
	---@cast position xyz? -- used onlyCoords=true above

	if position then
		iconZoomDist = math_diag(position[1] - camX, position[2] - camY, position[3] - camZ)
	elseif dirY < 0 then
		iconZoomDist = math_clamp((planeHeight - camY) / dirY, 0, engineRayLength)
	else
		iconZoomDist = 0
	end
end

local function initGL4()
	local layoutOffset = 0

	if useGeometryShader then
		shaderSource = geometryShaderSource
		outlineShader = LuaShader.CheckShaderUpdates(shaderSource)
	end

	if not outlineShader then
		useGeometryShader = false
		shaderSource = fallbackShaderSource
		outlineShader = LuaShader.CheckShaderUpdates(shaderSource)
		-- The template quad takes attribute 0 in this path.
		layoutOffset = 1
	end

	if not outlineShader then
		return false
	end

	outlineVBO = InstanceVBOTable.makeInstanceVBOTable({
		{ id = layoutOffset, name = "uvrect", size = 4 },
		{ id = layoutOffset + 1, name = "params", size = 4 },
		{ id = layoutOffset + 2, name = "midoffset", size = 4 },
		{ id = layoutOffset + 3, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
	}, 64, "unitArmorIconsVBO", layoutOffset + 3)

	if not outlineVBO then
		return false
	end

	if useGeometryShader then
		outlineVBO.VAO = InstanceVBOTable.makeVAOandAttach(nil, outlineVBO.instanceVBO)
	else
		local quadVBO = InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1, "unitArmorIconsQuad")
		if not quadVBO then
			return false
		end
		outlineVBO.VAO = InstanceVBOTable.makeVAOandAttach(quadVBO, outlineVBO.instanceVBO)
		outlineVBO.vertexVBO = quadVBO
	end

	return outlineVBO.VAO ~= nil
end

---The smallest size multiplier of any unit icon, which is the last icon to vanish while zooming in.
local function getMinSizeMult()
	local sizeByIcon = {}
	local minSize = math.huge

	for _, unitDef in pairs(UnitDefs) do
		local iconName = unitDef.iconType or "default"
		if sizeByIcon[iconName] == nil then
			local iconData = spGetIconData(iconName, true)
			sizeByIcon[iconName] = iconData and iconData.size or 1
			minSize = math_min(minSize, sizeByIcon[iconName])
		end
	end

	return minSize * 0.75 + 0.25
end

-- Engine callins

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	lastCamX = nil
	updateIconConfig()
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if not hasArmor[unitDefID] then
		return
	end
	addVisibleUnit(unitID, unitDefID)
	if iconsVisible then
		updateUnit(unitID)
	end
end

function widget:VisibleUnitRemoved(unitID)
	removeVisibleUnit(unitID)
	removeOutline(unitID)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	outlineVBO:clearInstanceTable()

	visibleUnits = {}
	visibleIndex = {}
	visibleDefID = {}
	visibleCount = 0
	pollCursor = 0

	outlineState = {}
	outlineOffsetX = {}
	outlineOffsetY = {}
	outlineOffsetZ = {}

	for unitID, unitDefID in pairs(extVisibleUnits) do
		if hasArmor[unitDefID] then
			addVisibleUnit(unitID, unitDefID)
		end
	end

	-- Every unit is rechecked when icons next come into view.
	iconsVisible = false
end

function widget:Update(dt)
	configAge = configAge + dt
	if configAge >= configInterval then
		updateIconConfig()
	end

	updateIconZoomDist()

	-- Closer than this no icon is on screen, so there is nothing to outline and no reason to poll.
	if iconZoomDist < iconFadeVanish * minSizeMult then
		iconsVisible = false
		return
	end

	local steps = visibleCount

	-- The engine has no call-in for armored state, so the visible units are rechecked in rotation,
	-- or all at once when icons come back into view with stale states.
	if iconsVisible then
		steps = math_ceil(visibleCount * dt / pollInterval)
		if steps > visibleCount then
			steps = visibleCount
		end
	end
	iconsVisible = true

	for _ = 1, steps do
		pollCursor = pollCursor % visibleCount + 1
		updateUnit(visibleUnits[pollCursor])
	end
end

function widget:DrawScreenEffects()
	if not iconsVisible or outlineVBO.usedElements == 0 or Spring.IsGUIHidden() then
		return
	end

	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Texture(0, "$icons0")
	gl.Texture(1, "$icons1")

	outlineShader:Activate()
	if uniformsDirty then
		uniformsDirty = false
		local widthScale = math_max(1, vsy / 1080)
		outlineShader:SetUniform("iconSizeBase", iconSizeBase)
		outlineShader:SetUniform("outlineWidth", armoredWidth * widthScale, brokenWidth * widthScale)
		outlineShader:SetUniform("borderWidth", borderWidth * widthScale)
		outlineShader:SetUniform("iconFade", iconFadeStart, iconFadeVanish)
	end
	outlineShader:SetUniform("iconZoomDist", iconZoomDist)
	if useGeometryShader then
		outlineVBO.VAO:DrawArrays(GL.POINTS, outlineVBO.usedElements)
	else
		outlineVBO.VAO:DrawArrays(GL.TRIANGLES, 6, 0, outlineVBO.usedElements)
	end
	outlineShader:Deactivate()

	gl.Texture(0, false)
	gl.Texture(1, false)
end

-- Lifecycle

function widget:Initialize()
	if not gl.CreateShader or not spGetUnitIconData or not spGetIconData then
		widgetHandler:RemoveWidget()
		return
	end

	if not initGL4() then
		Spring.Echo("Unit Armor Icons: could not create the outline shader or buffers")
		widgetHandler:RemoveWidget()
		return
	end

	local minHeight, maxHeight = Spring.GetGroundExtremes()
	planeHeight = (minHeight + maxHeight) * 0.5

	minSizeMult = getMinSizeMult()
	updateIconConfig()

	if WG["unittrackerapi"] and WG["unittrackerapi"].visibleUnits then
		widget:VisibleUnitsChanged(WG["unittrackerapi"].visibleUnits, nil)
	end
end

function widget:Shutdown()
	if outlineVBO and outlineVBO.VAO then
		outlineVBO.VAO:Delete()
	end
	if outlineShader then
		outlineShader:Finalize()
	end
end
