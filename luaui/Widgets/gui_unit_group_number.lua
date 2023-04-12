function widget:GetInfo()
	return {
		name = "Unit Group Number",
		desc = "Display which group all units belongs to",
		author = "Floris, Beherith",
		date = "May 2022",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end


local cutoffDistance = 3500
local falloffDistance = 2500
local hideBelowGameframe = 100
local fontSize = 13

local GetGroupList = Spring.GetGroupList
local GetGroupUnits = Spring.GetGroupUnits
local GetGameFrame = Spring.GetGameFrame
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetCameraPosition = Spring.GetCameraPosition
local diag = math.diag
local min = math.min

local vsx, vsy = Spring.GetViewGeometry()
local existingGroups = GetGroupList()
local existingGroupsFrame = 0
local gameStarted = (Spring.GetGameFrame() > 0)
local font, dlists

local crashing = {}

local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local unitCanFly = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
	end
end

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

local numbersToUvs = {}

local unitGroupVBO = nil
local unitGroupShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"
local vbocachetable = {}
for i = 1, 18 do vbocachetable[i] = 0 end -- init this caching table to preserve mem allocs

local function initGL4()
	local grid = 1/16
	for i=0,9 do
		numbersToUvs[i] = {grid,0,  1.0 - i*grid, 1.0 - (i+1)* grid} --xXyY
	end
	
	
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 1
	shaderConfig.INITIALSIZE = 0.5
	shaderConfig.BREATHERATE = 0.0
	shaderConfig.BREATHESIZE = 0.0
	shaderConfig.GROWTHRATE = 5.0
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin((timeInfo.x + timeInfo.w) * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	--shaderConfig.POST_GEOMETRY = "g_uv.w = dataIn[0].v_parameters.w; gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb* vec3(0.8, 1.0, 0.8), fragColor.a);" -- tint it greenish
	--shaderConfig.POST_VERTEX = "v_lengthwidthcornerheight.xy *= parameters.y * 4.5 + (1250 - abs(cameraDistance-1250))*0.016;"
	shaderConfig.PRE_OFFSET = "primitiveCoords.xz += vec2(20, -5);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil

	unitGroupVBO, unitGroupShader = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit(shaderConfig, "unitGroups")
	if unitGroupVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	if debugmode then unitGroupVBO.debug = true end
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

local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead


local function AddPrimitiveAtUnit(unitID, noUpload, reason, groupNumber, gf)
	if spValidUnitID(unitID) ~= true or spGetUnitIsDead(unitID) == true then
		if debugmode then Spring.Echo("Warning: Unit Groups GL4 attempted to add an invalid unitID:", unitID) end
		return nil
	end
	--Spring.Echo (rank, rankTextures[rank], unitIconMult[unitDefID])
	do 
		vbocachetable[1] = groupNumberSize -- length
		vbocachetable[2] = groupNumberSize -- widgth
		vbocachetable[3] = 0 -- cornersize
		vbocachetable[4] = groupNumberHeight	  -- height
		--vbocachetable[5] = 0 -- Spring.GetUnitTeam(unitID)
		vbocachetable[6] = 4 -- numvertices, 4 is a quad

		vbocachetable[7] = gf -- could prove useful?
		vbocachetable[8] = 1  -- size mult
		vbocachetable[9] = 1.0 -- alpha
		--vbocachetable[10] = 0 -- unused
		
		local uvset = numbersToUvs[groupNumber]
		vbocachetable[11] = uvset[1] -- uv's of the atlas
		vbocachetable[12] = uvset[2]
		vbocachetable[13] = uvset[3]
		vbocachetable[14] = uvset[4]
	end
	
	unitIDtoGroup[unitID] = groupNumber

	return pushElementInstance(
		unitGroupVBO, -- push into this Instance VBO Table
		vbocachetable, -- yes we save 1 table alloc this way
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		unitID) -- last one should be UNITID!
end


------------------------------------------- End GL4 Stuff -------------------------------------------

function widget:GameStart()
	gameStarted = true
	widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	font = WG['fonts'].getFont(nil, 1.4, 0.35, 1.4)

	if dlists then
		for i, _ in ipairs(dlists) do
			gl.DeleteList(dlists[i])
		end
	end
	dlists = {}
	for i = 0, 9 do
		dlists[i] = gl.CreateList(function()
			font:Begin()
			font:Print("\255\200\255\200" .. i, 20.0, -10.0, fontSize, "cno")
			font:End()
		end)
	end
end

function widget:Initialize()
	initGL4()
	for i = 0,9 do grouptounitID[i] = {} end
	unitIDtoGroup = {}
	widget:ViewResize()
end

function widget:Shutdown()
	if dlists then
		for i, _ in ipairs(dlists) do
			gl.DeleteList(dlists[i])
		end
		dlists = {}
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	crashing[unitID] = nil
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitCanFly[unitDefID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		crashing[unitID] = true
		RemovePrimitive(unitID)
	end
end

local drawFrame = 0

local newdraw = true
local olddraw = false

function widget:DrawWorld()
	drawFrame = drawFrame + 1
	local gf = GetGameFrame()
	if Spring.IsGUIHidden() or GetGameFrame() < hideBelowGameframe then
		return
	end
	
	if olddraw then 
	existingGroupsFrame = existingGroupsFrame + 1
	if existingGroupsFrame % 10 == 0 then
		existingGroups = GetGroupList()
	end
	local camX, camY, camZ = spGetCameraPosition()
	local camDistance
	for inGroup, _ in pairs(existingGroups) do
		local units = GetGroupUnits(inGroup)
		for i = 1, #units do
			local unitID = units[i]
			if spIsUnitInView(unitID) and not crashing[unitID] then
				local ux, uy, uz = spGetUnitViewPosition(unitID)
				camDistance = diag(camX - ux, camY - uy, camZ - uz)
				if camDistance < cutoffDistance then
					local scale = min(1, 1 - (camDistance - falloffDistance) / cutoffDistance)
					gl.PushMatrix()
					gl.Translate(ux, uy, uz)
					if scale <=1 then
						gl.Scale(scale, scale, scale)
					end
					gl.Billboard()
					gl.CallList(dlists[inGroup])
					gl.PopMatrix()
				end
			end
			---- GL4 Drawing ---
		end
	end
	end
	-- GL4 management --
	-- one important thing to note, is that we dont ever expect this change for two different groups in one frame.
	-- only update 1 group at a time
	if newdraw then 
		local groupList = GetGroupList()
		for inGroup, _ in pairs(groupList) do
			if inGroup == drawFrame %10 then 
				local units = GetGroupUnits(inGroup)
				local thisGroupFrames = grouptounitID[inGroup]
				for i=1, #units do
					local unitID = units[i]
					if not crashing[unitID] and unitIDtoGroup[unitID] ~= inGroup then -- not same as previous
						-- remove from old
						if unitIDtoGroup[unitID] then 
							grouptounitID[unitIDtoGroup[unitID]][unitID] = nil
						end
						AddPrimitiveAtUnit(unitID, false, "", inGroup, gf)
					end
					-- mark as updated
					thisGroupFrames[unitID] = drawFrame
				end
				
				for unitID, lastupdate in pairs(thisGroupFrames) do
					if lastupdate < drawFrame then 
						RemovePrimitive(unitID)
						thisGroupFrames[unitID] = nil
					end
				end
			end
		end
		if unitGroupVBO.usedElements > 0 then 
			-- note that unitGroupVBO.VAO:DrawArrays can be display-list wrapped, but then the #usedElements doesnt update :/
			gl.Texture(0, healthbartexture)
			unitGroupShader:Activate()
			unitGroupVBO.VAO:DrawArrays(GL.POINTS,unitGroupVBO.usedElements)
			unitGroupShader:Deactivate()
			gl.Texture(0, false)
		end
	end
end
