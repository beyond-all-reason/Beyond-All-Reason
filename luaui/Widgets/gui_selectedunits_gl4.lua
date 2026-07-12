local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Selected Units GL4",
		desc = "Draw geometric pritives at any unit",
		author = "Beherith, Floris",
		date = "2021.05.16",
		license = "GNU GPL, v2 or later",
		layer = -50,
		enabled = true,
	}
end


-- Localized Spring API for performance
local spGetSelectedUnits = Spring.GetSelectedUnits
local spEcho = Spring.Echo
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGameRulesParam = Spring.GetGameRulesParam
local spIsGUIHidden = Spring.IsGUIHidden
local spGetGameFrame = Spring.GetGameFrame
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spValidUnitID = Spring.ValidUnitID
local spValidFeatureID = Spring.ValidFeatureID
local spSetUnitBufferUniforms = gl.SetUnitBufferUniforms
local spSetFeatureBufferUniforms = gl.SetFeatureBufferUniforms

-- Configurable Parts:
local texture = "luaui/images/solid.png"

local opacity = 0.19
local teamcolorOpacity = 0.6
local leaveFactoryFrames = Game.gameSpeed * 0.5

local selectionHighlight = true
local mouseoverHighlight = true

---- GL4 Backend Stuff----
local selectionVBOUnfinished = nil
local selectionVBOGround = nil
local selectionVBOWater = nil
local selectionVBOAir = nil

local mapHasWater = (Spring.GetGroundExtremes() < 0)
local lavaWaterLevel = nil

local selectShader = nil
local unbuiltShader = nil
local waterShader = nil
local luaShaderDir = "LuaUI/Include/"

local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance


-- Localize for speedups:
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glStencilTest         = gl.StencilTest
local glStencilMask         = gl.StencilMask
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local glClear               = gl.Clear
local GL_ALWAYS             = GL.ALWAYS
local GL_NOTEQUAL           = GL.NOTEQUAL
local GL_KEEP               = 0x1E00 --GL.KEEP
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_REPLACE            = GL.REPLACE
local GL_POINTS				= GL.POINTS

local selUnits = {}
local updateSelection = true
local selectedUnits = spGetSelectedUnits()
local drawCallinsEnabled = true

local unitTeam = {}
local unitUnitDefID = {}
local unitDoneFrame = {}
local unitWaterPass = {}
local unitBuiltByFactory = {}
local nextWaterPassCheckFrame = 0
local waterPassCheckInterval = 6

local unitScale = {}
local unitCanFly = {}
local unitBuilding = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = (7.5 * ( unitDef.xsize*unitDef.xsize + unitDef.zsize*unitDef.zsize ) ^ 0.5) + 8
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
		unitScale[unitDefID] = unitScale[unitDefID] * 0.7
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitBuilding[unitDefID] = {
			unitDef.xsize * 8.2 + 12,
			unitDef.zsize * 8.2 + 12
		}
	end
end
local unitBufferUniformCache = {0}
local widgetDrawWorld = nil
local widgetDrawWorldPreUnit = nil
local UpdateDrawCallinsEnabled = nil

local function getWaterLevel()
	if lavaWaterLevel then
		return lavaWaterLevel
	end
	local level = spGetGameRulesParam("lavaLevel")
	if level and level ~= -99999 then
		return level
	end
	return 0
end

function widget:LavaRenderState(tideLevel)
	lavaWaterLevel = tideLevel
end

local function shouldUseWaterPass(unitID, unitDefID)
	if not mapHasWater or unitCanFly[unitDefID] then return false end
	local x, y, z = spGetUnitPosition(unitID)
	if not x or not y or not z then return false end
	local waterLevel = getWaterLevel()
	local groundY = spGetGroundHeight(x, z)
	-- Route ships/submerged units to post-water pass to avoid water distortion.
	return (groundY < waterLevel + 1) and (y <= waterLevel + 20)
end

local function shouldUseWaterPassAtLevel(unitID, unitDefID, waterLevel)
	if not mapHasWater or unitCanFly[unitDefID] then return false end
	local x, y, z = spGetUnitPosition(unitID)
	if not x or not y or not z then return false end
	local groundY = spGetGroundHeight(x, z)
	-- Route ships/submerged units to post-water pass to avoid water distortion.
	return (groundY < waterLevel + 1) and (y <= waterLevel + 20)
end


local function AddPrimitiveAtUnit(unitID)
	if Spring.ValidUnitID(unitID) ~= true or Spring.GetUnitIsDead(unitID) == true or Spring.IsGUIHidden() then return end
	local gf = Spring.GetGameFrame()
	local _, _, isPaused = Spring.GetGameSpeed()
	if isPaused then
		gf = gf - 10
	end

	if not unitUnitDefID[unitID] then
		unitUnitDefID[unitID] = Spring.GetUnitDefID(unitID)
	end
	local unitDefID = unitUnitDefID[unitID]
	if unitDefID == nil then return end -- these cant be selected

	local numVertices = 64 -- default to cornered rectangle
	local cornersize = 0

	local radius = unitScale[unitDefID]

	if not unitTeam[unitID] then
		unitTeam[unitID] = spGetUnitTeam(unitID)
	end

	local buildingDims = unitBuilding[unitDefID]
	local useUnfinishedRenderPath = false
	local useUnfinishedGeometry = false
	if not buildingDims then
		if Spring.GetUnitIsBeingBuilt(unitID) or unitDoneFrame[unitID] ~= nil then
			useUnfinishedRenderPath = true
			if not unitBuiltByFactory[unitID] then
				useUnfinishedGeometry = true
			end
		end
	end

	local additionalheight = 0
	local width, length
	if buildingDims then
		width = buildingDims[1]
		length = buildingDims[2]
		cornersize = (width + length) * 0.075
		numVertices = 2
	elseif useUnfinishedGeometry then
		-- The cornered square will be replaced by a circle later.
		-- Use the same or similar size for the swap to look good:
		width = radius * 0.88
		length = radius * 0.88
		cornersize = (width + length) * 0.075
		numVertices = 2
	elseif unitCanFly[unitDefID] then
		numVertices = 3 -- triangles for planes
		width = radius
		length = radius
	else
		width = radius
		length = radius
	end
	if selectionHighlight then
		unitBufferUniformCache[1] = 1
		gl.SetUnitBufferUniforms(unitID, unitBufferUniformCache, 6)
	end
	--spEcho(unitID,radius,radius, spGetUnitTeam(unitID), numvertices, 1, gf)
	local targetVBO
	if useUnfinishedRenderPath then
		targetVBO = selectionVBOUnfinished
	elseif unitCanFly[unitDefID] then
		-- Keep air on the same pre-unit path as ground for reliable visibility.
		targetVBO = selectionVBOGround
		unitWaterPass[unitID] = false
	else
		local useWaterPass = shouldUseWaterPass(unitID, unitDefID)
		unitWaterPass[unitID] = useWaterPass
		targetVBO = (useWaterPass and selectionVBOWater) or selectionVBOGround
	end

	pushElementInstance(
		targetVBO, -- push into this Instance VBO Table
		{
			length, width, cornersize, additionalheight,  -- lengthwidthcornerheight
			unitTeam[unitID], -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you
		unitID -- last one should be UNITID?
	)
end


local function DrawSelections(selectionVBO, shader)
	if selectionVBO.usedElements > -1 then
		-- DrawWorld can inherit culling state from other render passes/widgets.
		-- Force culling off so platter winding/order differences cannot hide them.
		gl.Culling(false)

		shader = shader or selectShader

		glTexture(0, texture)
		shader:Activate()
		shader:SetUniform("iconDistance", 99999) -- pass
		glStencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		glDepthTest(true) -- One really interesting thing is that the depth test does not seem to be obeyed within DrawWorldPreUnit
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon		this to the shader
		glClear(GL_STENCIL_BUFFER_BIT) -- set stencil buffer to 0

		glStencilFunc(GL_NOTEQUAL, 1, 1) -- use NOTEQUAL instead of ALWAYS to ensure that overlapping transparent fragments dont get written multiple times
		glStencilMask(1)

		shader:SetUniform("addRadius", 0)
		selectionVBO.VAO:DrawArrays(GL_POINTS, selectionVBO.usedElements)

		glStencilFunc(GL_NOTEQUAL, 1, 1)
		glStencilMask(0)
		glDepthTest(true)

		shader:SetUniform("addRadius", 1.3)
		selectionVBO.VAO:DrawArrays(GL_POINTS, selectionVBO.usedElements)

		glStencilMask(1)
		glStencilFunc(GL_ALWAYS, 1, 1)
		glDepthTest(true)

		shader:Deactivate()
		glTexture(0, false)

		-- This is the correct way to exit out of the stencil mode, to not break drawing of area commands:
		glStencilTest(false)
		glStencilMask(255)
		glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
		glClear(GL_STENCIL_BUFFER_BIT)
		-- All the above are needed :(
	end
end

if mapHasWater then
	widgetDrawWorld = function()
		-- Water-affected ground platters are drawn post-water to avoid refraction distortion.
		DrawSelections(selectionVBOWater, waterShader)
		DrawSelections(selectionVBOUnfinished, unbuiltShader)
	end
else
	widgetDrawWorld = function()
		DrawSelections(selectionVBOUnfinished, unbuiltShader)
	end
end

widgetDrawWorldPreUnit = function()
	-- Keep ground platters in pre-unit so units always overlap/occlude them.
	DrawSelections(selectionVBOGround, false)
end

function widget:DrawWorld()
	widgetDrawWorld()
end

function widget:DrawWorldPreUnit()
	widgetDrawWorldPreUnit()
end

local function RefreshWidgetCallIn(name)
	if not widgetHandler then
		return
	end
	if widgetHandler.UpdateWidgetCallInRaw then
		widgetHandler:UpdateWidgetCallInRaw(name, widget)
	elseif widgetHandler.UpdateWidgetCallIn then
		widgetHandler:UpdateWidgetCallIn(name, widget)
	elseif widgetHandler.UpdateCallIn then
		widgetHandler:UpdateCallIn(name)
	end
end

UpdateDrawCallinsEnabled = function()
	local shouldEnable = next(selUnits) ~= nil
	if shouldEnable == drawCallinsEnabled then
		return
	end
	drawCallinsEnabled = shouldEnable

	if shouldEnable then
		widget.DrawWorld = widgetDrawWorld
		widget.DrawWorldPreUnit = widgetDrawWorldPreUnit
	else
		widget.DrawWorld = nil
		widget.DrawWorldPreUnit = nil
	end

	RefreshWidgetCallIn("DrawWorld")
	RefreshWidgetCallIn("DrawWorldPreUnit")
end

local function removeFromVBO(unitID, selectionVBO)
	if selectionVBO then
		if selectionHighlight then
			unitBufferUniformCache[1] = 0
			if spValidUnitID(unitID) then
				spSetUnitBufferUniforms(unitID, unitBufferUniformCache, 6)
			end
		end
		popElementInstance(selectionVBO, unitID)
	end
end

local function RemovePrimitive(unitID)
	if selectionVBOGround.instanceIDtoIndex[unitID] then
		removeFromVBO(unitID, selectionVBOGround)
	end
	if selectionVBOUnfinished.instanceIDtoIndex[unitID] then
		removeFromVBO(unitID, selectionVBOUnfinished)
	end
	if mapHasWater and selectionVBOWater.instanceIDtoIndex[unitID] then
		removeFromVBO(unitID, selectionVBOWater)
	end
	if selectionVBOAir.instanceIDtoIndex[unitID] then
		removeFromVBO(unitID, selectionVBOAir)
	end
	unitWaterPass[unitID] = nil
	if UpdateDrawCallinsEnabled then
		UpdateDrawCallinsEnabled()
	end
end

function widget:SelectionChanged(sel)
	updateSelection = true
end


local lastMouseOverUnitID = nil
local lastMouseOverFeatureID = nil
local cleanedForHiddenUI = false
local mouseOverUnitUniform = {0}
local mouseOverFeatureUniform = {0}
local lastMouseX, lastMouseY = -1, -1
local lastMouseP1, lastMouseMMB = false, false
local nextMouseOverCheckFrame = 0
local mouseOverIdleCheckInterval = 4

local function ClearLastMouseOver()
	if lastMouseOverUnitID then
		if spValidUnitID(lastMouseOverUnitID) then
			mouseOverUnitUniform[1] = selUnits[lastMouseOverUnitID] and 1 or 0
			spSetUnitBufferUniforms(lastMouseOverUnitID, mouseOverUnitUniform, 6)
		end
		lastMouseOverUnitID = nil
	end
	if lastMouseOverFeatureID then
		if spValidFeatureID(lastMouseOverFeatureID) then
			mouseOverFeatureUniform[1] = 0
			spSetFeatureBufferUniforms(lastMouseOverFeatureID, mouseOverFeatureUniform, 6)
		end
		lastMouseOverFeatureID = nil
	end
end



function widget:Update(dt)
	local guiHidden = spIsGUIHidden()
	-- Handle UI visibility: clear selections when hidden, resync on show
	if guiHidden then
		if not cleanedForHiddenUI then
			ClearLastMouseOver()
			for unitID, _ in pairs(selUnits) do
				RemovePrimitive(unitID)
			end
			-- Reset drawn selection state so we can rebuild when UI becomes visible
			selUnits = {}
			UpdateDrawCallinsEnabled()
			cleanedForHiddenUI = true
		end
		-- Skip further processing while UI is hidden
		return
	else
		-- UI just became visible again, trigger a resync to redraw selections
		if cleanedForHiddenUI then
			updateSelection = true
			cleanedForHiddenUI = false
		end
	end

	if updateSelection then
		selectedUnits = spGetSelectedUnits()
		updateSelection = false

		local newSelUnits = {}
		-- add to selection
		for i, unitID in ipairs(selectedUnits) do
			newSelUnits[unitID] = true
			if not selUnits[unitID] then
				AddPrimitiveAtUnit(unitID)
			end
		end
		-- remove from selection
		for unitID, _ in pairs(selUnits) do
			if not newSelUnits[unitID] then
				RemovePrimitive(unitID)
				unitDoneFrame[unitID] = nil
			end
		end
		selUnits = newSelUnits
		UpdateDrawCallinsEnabled()
	end

	local hasSelectedUnits = next(selUnits) ~= nil

	if mapHasWater and hasSelectedUnits then
		local gf = spGetGameFrame()
		if gf >= nextWaterPassCheckFrame then
			nextWaterPassCheckFrame = gf + waterPassCheckInterval
			local waterLevel = getWaterLevel()
			-- Keep selected naval/submerged units in the post-water VBO as they move.
			for unitID, _ in pairs(selUnits) do
				local unitDefID = unitUnitDefID[unitID]
				if unitDefID and not unitCanFly[unitDefID] and not Spring.GetUnitIsBeingBuilt(unitID) and unitDoneFrame[unitID] == nil then
					local desiredWaterPass = shouldUseWaterPassAtLevel(unitID, unitDefID, waterLevel)
					if desiredWaterPass ~= unitWaterPass[unitID] then
						RemovePrimitive(unitID)
						AddPrimitiveAtUnit(unitID)
					end
				end
			end
		end
	end

	if not hasSelectedUnits and not mouseoverHighlight then
		return
	end

	-- We move the check for mouseovered units here,
	-- as this widget is the ground truth for our unitbufferuniform[2].z (#6)
	-- 0 means unit is un selected
	-- +1 means unit is selected
	-- +0.5 means ally also selected unit
	-- +2 means its mouseovered
	if mouseoverHighlight then
		local mx, my, p1, mmb, _, mouseOffScreen, cameraPanMode  = spGetMouseState()
		if mouseOffScreen or cameraPanMode or mmb or p1 then
			ClearLastMouseOver()
		else
			local shouldTraceMouse = true
			if not hasSelectedUnits and not lastMouseOverUnitID and not lastMouseOverFeatureID then
				local gf = spGetGameFrame()
				if mx == lastMouseX and my == lastMouseY and p1 == lastMouseP1 and mmb == lastMouseMMB and gf < nextMouseOverCheckFrame then
					shouldTraceMouse = false
				else
					nextMouseOverCheckFrame = gf + mouseOverIdleCheckInterval
				end
			end

			lastMouseX, lastMouseY = mx, my
			lastMouseP1, lastMouseMMB = p1, mmb

			if not shouldTraceMouse then
				return
			end

			local result, data = spTraceScreenRay(mx, my)
			--spEcho(result, (type(data) == 'table') or data, lastMouseOverUnitID, lastMouseOverFeatureID)
			if result == 'unit' and not guiHidden then
				local unitID = data
				if lastMouseOverUnitID ~= unitID then
					ClearLastMouseOver()
					local newUniform = (selUnits[unitID] and 1 or 0 ) + 2
					mouseOverUnitUniform[1] = newUniform
					spSetUnitBufferUniforms(unitID, mouseOverUnitUniform, 6)
					lastMouseOverUnitID = unitID
				end
			elseif result == 'feature' and not guiHidden then
				local featureID = data
				if lastMouseOverFeatureID ~= featureID then
					ClearLastMouseOver()
					mouseOverFeatureUniform[1] = 2
					spSetFeatureBufferUniforms(featureID, mouseOverFeatureUniform, 6)
					lastMouseOverFeatureID = featureID
				end
			else
				ClearLastMouseOver()
			end
		end
	end
end

function widget:GameFrame(frame)
	if next(unitDoneFrame) == nil then
		return
	end

	local swapFrame = frame - leaveFactoryFrames
	for unitID, doneFrame in pairs(unitDoneFrame) do
		if doneFrame <= swapFrame then
			unitDoneFrame[unitID] = nil
			if selUnits[unitID] then
				RemovePrimitive(unitID)
				AddPrimitiveAtUnit(unitID)
			end
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeamID, builderID)
	if type(unitID) ~= "number" then
		return
	end

	if type(builderID) == "number" then
		local builderDefID = Spring.GetUnitDefID(builderID)
		if builderDefID and UnitDefs[builderDefID] and UnitDefs[builderDefID].isFactory then
			unitBuiltByFactory[unitID] = true
		end
	end

end

function widget:UnitFinished(unitID)
	if selUnits[unitID] then
		unitDoneFrame[unitID] = Spring.GetGameFrame()
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	if unitTeam[unitID] then
		unitTeam[unitID] = newTeamID
	end
end

function widget:UnitDestroyed(unitID)
	--spEcho("UnitDestroyed(unitID)",unitID, selectedUnits[unitID])
	if selUnits[unitID] then
		RemovePrimitive(unitID)
	end
	unitTeam[unitID] = nil
	unitUnitDefID[unitID] = nil
	unitDoneFrame[unitID] = nil
	unitWaterPass[unitID] = nil
	unitBuiltByFactory[unitID] = nil
	UpdateDrawCallinsEnabled()
end

local function init()
	updateSelection = true
	selUnits = {}
	drawCallinsEnabled = true
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.BILLBOARD = 0
	shaderConfig.TRANSPARENCY = opacity
	shaderConfig.INITIALSIZE = 0.75
	shaderConfig.GROWTHRATE = 4		-- higher = slower
	shaderConfig.TEAMCOLORIZATION = teamcolorOpacity	-- not implemented, doing it via POST_SHADING below instead
	shaderConfig.HEIGHTOFFSET = 4
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(mix(g_color.rgb * texcolor.rgb + addRadius, vec3(1.0), "..(1-teamcolorOpacity)..") , texcolor.a * TRANSPARENCY + addRadius);"
	selectionVBOGround, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "selectedUnitsGround")

	local unbuiltConfig = table.copy(shaderConfig)
	-- Unbuilt platters may depend on the animated unbuilt unit model and shader, so seem to re-init repeatedly.
	unbuiltConfig.INITIALSIZE = 0.9999 -- So don't animate init growth. This value does not work if set to 1.0.
	selectionVBOUnfinished, unbuiltShader = InitDrawPrimitiveAtUnit(unbuiltConfig, "selectedUnitsUnfinished")

	if mapHasWater then
		selectionVBOWater, waterShader = InitDrawPrimitiveAtUnit(shaderConfig, "selectedUnitsWater")
		selectionVBOAir = selectionVBOGround
	else
		selectionVBOWater = selectionVBOGround
		waterShader = selectShader
		selectionVBOAir = selectionVBOGround
	end
	ClearLastMouseOver()
	if selectionVBOGround == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	if selectionVBOAir == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	if selectionVBOWater == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	UpdateDrawCallinsEnabled()
	return true
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not init() then return end
	WG.selectedunits = {}
	WG.selectedunits.getOpacity = function()
		return opacity
	end
	WG.selectedunits.setOpacity = function(value)
		opacity = value
		init()
	end
	WG.selectedunits.getTeamcolorOpacity = function()
		return teamcolorOpacity
	end
	WG.selectedunits.setTeamcolorOpacity = function(value)
		teamcolorOpacity = value
		init()
	end

	WG.selectedunits.setSelectionHighlight = function(value)
		selectionHighlight = value
		init()
	end
	WG.selectedunits.getSelectionHighlight = function()
		return selectionHighlight
	end

	WG.selectedunits.setMouseoverHighlight = function(value)
		mouseoverHighlight = value
		init()
	end
	WG.selectedunits.getMouseoverHighlight = function()
		return mouseoverHighlight
	end

	Spring.LoadCmdColorsConfig('unitBox  0 1 0 0')

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		widget:UnitCreated(unitID)
	end
end

function widget:Shutdown()
	if not (WG.teamplatter or WG.highlightselunits) then
		Spring.LoadCmdColorsConfig('unitBox  0 1 0 1')
	end
	WG.selectedunits = nil
end

function widget:GetConfigData(data)
	return {
		opacity = opacity,
		teamcolorOpacity = teamcolorOpacity,
		selectionHighlight = selectionHighlight,
		mouseoverHighlight = mouseoverHighlight,
	}
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.teamcolorOpacity ~= nil then
		teamcolorOpacity = data.teamcolorOpacity
	end
	if data.selectionHighlight ~= nil then
		selectionHighlight = data.selectionHighlight
	end
	if data.mouseoverHighlight ~= nil then
		mouseoverHighlight = data.mouseoverHighlight
	end
end
