local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Repeat Icons", -- GL4
		desc = "Shows a repeat icon above units that have the repeat order enabled",
		author = "Floris",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -38,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized Spring API
--------------------------------------------------------------------------------
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitIsDead = Spring.GetUnitIsDead
local spIsGUIHidden = Spring.IsGUIHidden

local repeatTexture = "LuaUI/Images/repeat.png"

-- "UnitIconDistance" is not an engine setting, so this is the default unless someone sets it
local iconDistance = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5
local shaderIconDistance

--------------------------------------------------------------------------------
-- GL4 Backend
--------------------------------------------------------------------------------

---@type InstanceVBOTable?
local repeatVBO = nil
local repeatShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable = gl.InstanceVBOTable
local uploadAllElements = InstanceVBOTable.uploadAllElements
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- Per-UnitDef config: [unitDefID] = {iconSize, iconHeight}
-- Only populated for units that can receive repeatable orders:
-- mobile units, factories, and buildings with stockpile weapons
--------------------------------------------------------------------------------
---@type table<integer, table>
local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	local hasStockpile = false
	if unitDef.weapons then
		for _, w in ipairs(unitDef.weapons) do
			local wd = w.weaponDef and WeaponDefs[w.weaponDef]
			if wd and wd.stockpile and not (wd.interceptor and wd.interceptor > 0) then
				hasStockpile = true
				break
			end
		end
	end
	if unitDef.canMove or unitDef.isFactory or hasStockpile then
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 1 * (xsize * xsize + zsize * zsize) ^ 0.5
		unitConf[udid] = { 10 + (scale / 2.2), unitDef.height }
	end
end

-- Visible units that can receive repeatable orders: [unitID] = unitDefID
local visibleUnits = {}
local crashingUnits = {} -- unitIDs currently crashing; skip icon for these
local chobbyInterface = false
local unitRepeat = {} -- [unitID] = cached repeat bool; avoids GetUnitStates every frame

-- Pre-allocated and reused for every pushElementInstance call to avoid per-push table allocation
---@type number[]
local instanceData = { 0, 0, 0, 0, 0, 4, 0, 0, 0.85, 0, 0, 1, 0, 1, 0, 0, 0, 0 }

--------------------------------------------------------------------------------
-- GL4 Initialization
--------------------------------------------------------------------------------
local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig

	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 0.85
	shaderConfig.ANIMATION = 1
	shaderConfig.FULL_ROTATION = 0
	shaderConfig.CLIPTOLERANCE = 1.2
	shaderConfig.INITIALSIZE = 0.22
	shaderConfig.BREATHESIZE = 0.05
	shaderConfig.ZPULL = 512.0
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil

	repeatVBO, repeatShader = InitDrawPrimitiveAtUnit(shaderConfig, "repeat icons")
	if repeatVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Push a unit into the repeat VBO
--------------------------------------------------------------------------------
local function pushToVBO(unitID, unitDefID, gf)
	if repeatVBO.instanceIDtoIndex[unitID] then
		return
	end
	if spGetUnitIsDead(unitID) ~= false then -- nil for invalid units
		return
	end
	local conf = unitConf[unitDefID]
	instanceData[1] = conf[1] -- width
	instanceData[2] = conf[1] -- height
	instanceData[4] = conf[2] -- unit height offset
	instanceData[7] = gf -- gameframe for animation
	pushElementInstance(repeatVBO, instanceData, unitID, false, true, unitID)
end

local drawCallInActive = true

-- DrawScreenEffects is only registered while there are icons. It also uploads what pushes left dirty:
-- a group order reaches every unit separately, one full upload each would grow with the square of the group.
local function updateDrawCallIn()
	local active = repeatVBO.usedElements > 0
	if active ~= drawCallInActive then
		drawCallInActive = active
		if active then
			widgetHandler:UpdateCallIn("DrawScreenEffects")
		else
			widgetHandler:RemoveCallIn("DrawScreenEffects")
		end
	end
end

--------------------------------------------------------------------------------
-- Widget callbacks
--------------------------------------------------------------------------------
function widget:Initialize()
	widgetHandler:RegisterUnitCommand(CMD.REPEAT)
	if not gl.CreateShader then
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then
		return
	end

	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
	end
	updateDrawCallIn()
end

-- only units that can receive repeatable orders are tracked
function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(repeatVBO)
	visibleUnits = {}
	unitRepeat = {}
	local gf = spGetGameFrame()
	for unitID, unitDefID in pairs(extVisibleUnits) do
		if unitConf[unitDefID] then
			visibleUnits[unitID] = unitDefID
			if not crashingUnits[unitID] then
				-- the 4th value is the repeat state (no table built), all nil for units that are not ours to read
				local fireState, _, _, rep = spGetUnitStates(unitID, false, true)
				if fireState then
					unitRepeat[unitID] = rep
					if rep then
						pushToVBO(unitID, unitDefID, gf)
					end
				end
			end
		end
	end
	updateDrawCallIn()
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if not unitConf[unitDefID] then
		return
	end
	visibleUnits[unitID] = unitDefID
	if crashingUnits[unitID] then
		return
	end
	local fireState, _, _, rep = spGetUnitStates(unitID, false, true)
	if not fireState then
		return
	end
	unitRepeat[unitID] = rep
	if rep then
		pushToVBO(unitID, unitDefID, spGetGameFrame())
		updateDrawCallIn()
	end
end

function widget:VisibleUnitRemoved(unitID)
	visibleUnits[unitID] = nil
	unitRepeat[unitID] = nil
	crashingUnits[unitID] = nil
	if repeatVBO.instanceIDtoIndex[unitID] then
		popElementInstance(repeatVBO, unitID)
		updateDrawCallIn()
	end
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	crashingUnits[unitID] = true
	unitRepeat[unitID] = nil
	if repeatVBO.instanceIDtoIndex[unitID] then
		popElementInstance(repeatVBO, unitID)
		updateDrawCallIn()
	end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts)
	if cmdID ~= CMD.REPEAT then
		return
	end
	if not visibleUnits[unitID] or crashingUnits[unitID] then
		return
	end
	local rep = (cmdParams[1] == 1)
	if unitRepeat[unitID] == rep then
		return
	end
	unitRepeat[unitID] = rep
	if rep then
		pushToVBO(unitID, unitDefID, spGetGameFrame())
	else
		if repeatVBO.instanceIDtoIndex[unitID] then
			popElementInstance(repeatVBO, unitID, true)
		end
	end
	updateDrawCallIn()
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

-- only registered while there are icons
function widget:DrawScreenEffects()
	if chobbyInterface or repeatVBO.usedElements == 0 or spIsGUIHidden() then
		return
	end
	if repeatVBO.dirty then
		uploadAllElements(repeatVBO)
	end

	gl.DepthTest(true)
	gl.DepthMask(false)
	gl.Texture(repeatTexture)
	repeatShader:Activate()
	-- addRadius stays at its default of 0
	if shaderIconDistance ~= iconDistance then
		shaderIconDistance = iconDistance
		repeatShader:SetUniform("iconDistance", iconDistance)
	end
	repeatVBO.VAO:DrawArrays(GL.POINTS, repeatVBO.usedElements)
	repeatShader:Deactivate()
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(true)
end

function widget:Shutdown()
	if type(repeatShader) == "table" then
		repeatShader:Finalize()
		repeatShader = nil
	end
end
