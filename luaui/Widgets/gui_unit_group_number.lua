local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Group Number",
		desc = "Display which group all units belongs to",
		author = "Floris, Beherith",
		date = "May 2022",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local hideBelowGameframe = 100

local GetGroupUnits = Spring.GetGroupUnits
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spIsGUIHidden = Spring.IsGUIHidden

local crashing = {}

local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local unitCanFly = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
	end
end

local gameFrame = 0
local maxNumGroups = 9
local minGroupID = 0

------------------------------------------- Begin GL4 stuff -----------------------------------------
-- GL4 notes
-- use drawprimitiveatunit!

-- Configurables:
local groupNumberSize = 13
local groupNumberHeight = 0
local healthbartexture = "LuaUI/Images/healtbars_exo4.tga"
local debugmode = false

-- Managment:
local unitIDtoGroup = {} -- keys unitID's to group numbers
local grouptounitID = {}
for i = minGroupID, maxNumGroups do
	grouptounitID[i] = {}
end

local unitGroupVBO = nil
local unitGroupShader = nil
local luaShaderDir = "LuaUI/Include/"
local vbocachetables = {} -- A table of tables for speed

local function initGL4()
	local grid = 1 / 16
	for i = minGroupID, maxNumGroups do
		local vbocachetable = {}

		-- Initialize the cache table
		for j = 1, 18 do
			vbocachetable[j] = 0
		end

		-- Fill in static things
		vbocachetable[1] = groupNumberSize -- length
		vbocachetable[2] = groupNumberSize -- widgth
		vbocachetable[3] = 0 -- cornersize
		vbocachetable[4] = groupNumberHeight -- height
		--vbocachetable[5] = 0 -- Spring.GetUnitTeam(unitID)
		vbocachetable[6] = 4 -- numvertices, 4 is a quad
		vbocachetable[8] = 1 -- size mult
		vbocachetable[9] = 1.0 -- alpha

		-- Save the UV's we just generated
		local x, X, y, Y = grid, 0, 1.0 - i * grid, 1.0 - (i + 1) * grid -- xXyY
		vbocachetable[11] = x
		vbocachetable[12] = X
		vbocachetable[13] = y
		vbocachetable[14] = Y

		vbocachetables[i] = vbocachetable
	end

	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 1
	shaderConfig.INITIALSIZE = 0.5
	shaderConfig.BREATHERATE = 0.0
	shaderConfig.BREATHESIZE = 0.0
	shaderConfig.GROWTHRATE = 5.0
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb* vec3(0.8, 1.0, 0.8), fragColor.a);" -- tint it greenish
	shaderConfig.PRE_OFFSET = "primitiveCoords.xz += vec2(20, -5);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil

	unitGroupVBO, unitGroupShader = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit(shaderConfig, "unitGroups")
	if unitGroupVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	if debugmode then
		unitGroupVBO.debug = true
	end
	return true
end

local function RemovePrimitive(unitID)
	if unitGroupVBO.instanceIDtoIndex[unitID] then
		local oldgroup = unitIDtoGroup[unitID]
		grouptounitID[oldgroup][unitID] = nil
		unitIDtoGroup[unitID] = nil
		popElementInstance(unitGroupVBO, unitID)
	end
end

function widget:VisibleUnitRemoved(unitID) -- E.g. when a unit dies
	RemovePrimitive(unitID, "VisibleUnitRemoved")
end

local function AddPrimitiveAtUnit(unitID, noUpload, groupNumber, gf)
	if spValidUnitID(unitID) ~= true or spGetUnitIsDead(unitID) == true then
		if debugmode then
			Spring.Echo("Warning: Unit Groups GL4 attempted to add an invalid unitID:", unitID)
		end
		return nil
	end

	local vbocachetable = vbocachetables[groupNumber]

	-- Save the current gameframe for animation purposes
	-- All other variables of each instance are unchanged thus can be used directly from the cached table
	vbocachetable[7] = gf

	unitIDtoGroup[unitID] = groupNumber

	return pushElementInstance(
		unitGroupVBO, -- push into this Instance VBO Table
		vbocachetable, -- yes we save 1 table alloc this way
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		unitID
	) -- last one should be UNITID!
end

------------------------------------------- End GL4 Stuff -------------------------------------------

function widget:PlayerChanged()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:GroupChanged(groupID)
	-- We need to check diff with previous group units to remove units that
	-- had their group unset
	local unitsToBeRemoved = {}

	-- Make sure to do a copy, lua references tables by value
	for unitID, _ in pairs(grouptounitID[groupID]) do
		unitsToBeRemoved[unitID] = true
	end

	for _, unitID in ipairs(GetGroupUnits(groupID)) do
		local previousUnitGroup = unitIDtoGroup[unitID]

		unitsToBeRemoved[unitID] = nil

		if not crashing[unitID] and previousUnitGroup ~= groupID then -- not same as previous
			-- remove from old
			if previousUnitGroup then
				grouptounitID[previousUnitGroup][unitID] = nil
			end

			grouptounitID[groupID][unitID] = true

			AddPrimitiveAtUnit(unitID, false, groupID, gameFrame)
		end
	end

	for unitID, _ in pairs(unitsToBeRemoved) do
		RemovePrimitive(unitID)
	end
end

function widget:Initialize()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end

	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	initGL4()

	gameFrame = Spring.GetGameFrame()
	unitIDtoGroup = {}

	if gameFrame > 0 then
		for i = minGroupID, maxNumGroups do
			widget:GroupChanged(i)
		end
	end
end

function widget:Shutdown()
	if unitGroupShader then
		unitGroupShader:Finalize()
	end

	if unitGroupVBO and unitGroupVBO.VBO then
		unitGroupVBO:Delete()
	end

	if unitGroupVBO and unitGroupVBO.VAO then
		unitGroupVBO.VAO:Delete()
	end
end

-- function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
function widget:UnitDestroyed(unitID)
	crashing[unitID] = nil
end

-- widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
function widget:UnitDamaged(unitID, unitDefID)
	if unitCanFly[unitDefID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		crashing[unitID] = true
		RemovePrimitive(unitID)
	end
end

function widget:GameFrame(gf)
	gameFrame = gf
end

function widget:DrawWorld()
	if spIsGUIHidden() or gameFrame < hideBelowGameframe then
		return
	end

	if unitGroupVBO.usedElements > 0 then
		-- note that unitGroupVBO.VAO:DrawArrays can be display-list wrapped, but then the #usedElements doesnt update :/
		gl.Texture(0, healthbartexture)
		unitGroupShader:Activate()
		unitGroupVBO.VAO:DrawArrays(GL.POINTS, unitGroupVBO.usedElements)
		unitGroupShader:Deactivate()
		gl.Texture(0, false)
	end
end
