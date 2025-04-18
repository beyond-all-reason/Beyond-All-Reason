local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Metalspots",
		desc    = "Displays rotating circles around metal spots",
		author  = "Floris, Beherith GL4",
		date    = "October 2019",
		license  = "Lua: GNU GPL, v2 or later,  GLSL: (c) Beherith (mysterme@gmail.com)",
		layer   = 2,
		enabled = true,
	}
end
--2023.05.21 TODO list
-- Add occupied circle to center
-- Add text billboard vertices at end (exploit vertex index)
-- Add a vertex type field to indicate outer circle, inner circle, billboard
-- Add UV coordinates field to instances
-- Add options to control the display of all of these.
-- Add income multiplier gating for individual players (well thats a doozy!)
-- GL4 stuff
-- Notes:
-- 1. Could a prerendered texture be better at conveying metal spot value?
-- 2. VertexVBO contains: x, y pos, rotdir and radians in angle?
-- 3. InstanceVBO contains:
	--x,y,z offsets, radius,
	-- visibility, and gameframe num of the last change teamid of occupier?
-- 4. the way the updates are handled are far from ideal, the construction and destruction of any mex will trigger a full update
-- 2023.05.12
-- Add atlas text to all this
-- Add a cyan circle to visible spots anyway
-- Fix height changing on noox
-- totally nuke the fucking F4 view, its terrible!
-- move font init into initialize instead of load
-- untie from os.clock thats stupid too

if Spring.GetModOptions().unit_restrictions_noextractorDefs then
	return
end

local needsInit			= true
local showValue			= false
local metalViewOnly		= false

local circleSpaceUsage	= 0.62
local circleInnerOffset	= 0.28
local opacity			= 0.5

local innersize			= 1.8		-- outersize-innersize = circle width
local outersize			= 1.98		-- outersize-innersize = circle width
local centersize 		= 1.3
local billboardsize 	= 0.5

local maxValue			= 15		-- ignore spots above this metal value (probably metalmap)
local maxScale			= 4			-- ignore spots above this scale (probably metalmap)

local extractorRadius = Game.extractorRadius * 1.2

local spIsSphereInView = Spring.IsSphereInView
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapDrawMode  = Spring.GetMapDrawMode
local spIsUnitAllied  = Spring.IsUnitAllied

local mySpots = {} -- {spotKey  = {x = spot.x, y= spGetGroundHeight(spot.x, spot.z), z = spot.z, value = value, scale = scale, occupied = occupied, t = currentClock, ally = false, enemy = false, instanceID = "1024_1023"}}

local valueList = {}
local previousOsClock = os.clock()
local checkspots = true
local sceduledCheckedSpotsFrame = Spring.GetGameFrame()

local isSpec, fullview = Spring.GetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local incomeMultiplier = select(7, Spring.GetTeamInfo(Spring.GetMyTeamID(), false))

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = math.min(1.5, (0.5 + (vsx*vsy / 5700000)))
local fontfileSize = 80
local fontfileOutlineSize = 26
local fontfileOutlineStrength = 1.6
--Spring.Echo("Loading Font",fontfile,fontfileSize*fontfileScale,fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local chobbyInterface

local extractorDefs = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		extractorDefs[uDefID] = true
	end
end

local teamIncomeMultipliers = {} -- {key teamID value Multiplier number}

local spotVBO = nil
local spotInstanceVBO = nil
local spotShader = nil

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local shaderConfig = {}
local vsSrcPath = "LuaUI/Shaders/metalspots_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/metalspots_gl4.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "Metalspots GL4",
		uniformInt = {
			heightMap = 0,
			textAtlas = 1,
			},
		uniformFloat = {
			visibilitycontrols = {0,0,0,0},
		  },
		shaderConfig = shaderConfig,
	}

local MetalSpotTextAtlas
local AtlasTextureID
local MakeAtlasOnDemand = VFS.Include("LuaUI/Include/AtlasOnDemand.lua")
local valueToUVs = {} -- key value string to uvCoords object from atlas in xXyYwh array

local function goodbye(reason)
	Spring.Echo("Metalspots GL4 widget exiting with reason: "..reason)
	widgetHandler:RemoveWidget()
end

local function arrayAppend(target, source)
	for _,v in ipairs(source) do
		table.insert(target,v)
	end
end

local function makeSpotVBO()
	spotVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if spotVBO == nil then goodbye("Failed to create spotVBO") end
	local VBOLayout = {	 {id = 0, name = "localpos_dir_angle", size = 4},}
	local VBOData = {}

	local detailPartWidth, a1,a2,a3,a4
	local width = circleSpaceUsage
	local pieces = 8
	local detail = 6
	local radstep = (2.0 * math.pi) / pieces
	for _,dir in ipairs({-1,1}) do
		for i = 1, pieces do -- pieces
			for d = 1, detail do -- detail
				detailPartWidth = ((width / detail) * d) + (dir+1)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+circleInnerOffset+detailPartWidth) * radstep)

				arrayAppend(VBOData, {math.sin(a3)*innersize, math.cos(a3)*innersize, dir, 0})

				if dir == -1 then
					arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, 0})
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, 0})
				else
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, 0})
					arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, 0})
				end

				if dir == 1 then
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, 0})
					arrayAppend(VBOData, {math.sin(a2)*outersize, math.cos(a2)*outersize, dir, 0})
				else
					arrayAppend(VBOData, {math.sin(a2)*outersize, math.cos(a2)*outersize, dir, 0})
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, 0})
				end
				arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, 0})
			end
		end
	end

	-- Add the 32 tris for the inner circle of color:
	-- TODO: FIX THIS
	--[[
	for i = 1, 32 do
		local d1 = (i/32) * math.pi * 2.0
		local d2 = ((i+1)/32) * math.pi * 2.0

		arrayAppend(VBOData, {math.sin(d1)*centersize, math.cos(d1)*centersize, 1, 1})
		arrayAppend(VBOData, {math.sin(d2)*centersize, math.cos(d2)*centersize, 1, 1})
		arrayAppend(VBOData, {0, 0, 0, 1})
	end
	]]--

	-- Add the 2 tris for the billboard:
	do
		arrayAppend(VBOData, {billboardsize, 0, 1, 2})
		arrayAppend(VBOData, {billboardsize, billboardsize, 1, 2})
		arrayAppend(VBOData, {-billboardsize, 0, 1, 2})
		arrayAppend(VBOData, {billboardsize, billboardsize, 1, 2})
		arrayAppend(VBOData, {-billboardsize, billboardsize, 1, 2})
		arrayAppend(VBOData, {-billboardsize, 0, 1, 2})
	end

	spotVBO:Define(#VBOData/4, VBOLayout)
	spotVBO:Upload(VBOData)
	return spotVBO, #VBOData/4
end

local function initGL4()
	spotShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not spotShader then goodbye("Failed to compile spotShader GL4 ") return false end
	local spotVBO,numVertices = makeSpotVBO()
	local spotInstanceVBOLayout = {
		{id = 1, name = 'worldpos_radius', size = 4},
		{id = 2, name = 'visibility', size = 4},
		{id = 3, name = 'uvcoords', size = 4},
	}
	spotInstanceVBO = makeInstanceVBOTable(spotInstanceVBOLayout, 8, "spotInstanceVBO")
	spotInstanceVBO.numVertices = numVertices
	spotInstanceVBO.vertexVBO = spotVBO
	spotInstanceVBO.VAO = makeVAOandAttach(spotInstanceVBO.vertexVBO, spotInstanceVBO.instanceVBO)
	spotInstanceVBO.primitiveType = GL.TRIANGLES
	return true
end

local function spotKey(posx,posz)
	return tostring(posx).."_"..tostring(posz)
end

-- Returns wether is occupied (Should also be allied, enemy , free), and wether that changed
local function IsSpotOccupied(spot)
	spot.y = spGetGroundHeight(spot.x, spot.z)
	local units = spGetUnitsInSphere(spot.x, spot.y, spot.z, extractorRadius * spot.scale)
	local occupied = false
	local prevOccupied = spot.occupied
	local ally = false
	local enemy = false
	local changed = false
	for j=1, #units do
		if extractorDefs[spGetUnitDefID(units[j])] then
			-- Actually check if we the ones are extracting from this spot?
			occupied = true
			if spIsUnitAllied(units[j]) then
				ally = true
			else
				enemy = true
			end
			break
		end
	end
	local changed = (occupied ~= prevOccupied)

	if occupied ~= prevOccupied then
		spot.t = os.clock()
		spot.occupied = occupied
	end
	return ally, enemy, changed
end

local function checkMetalspots()
	for i=1, #mySpots do
		local spot = mySpots[i]
		local ally, enemy, changed = IsSpotOccupied(spot)
		local occupied = ally or enemy

		if changed then
			local oldinstance = getElementInstanceData(spotInstanceVBO, spot.instanceID)
			oldinstance[5] = (occupied and 0) or 1
			oldinstance[6] = Spring.GetGameFrame()
			pushElementInstance(spotInstanceVBO, oldinstance, spot.instanceID, true)
		end
	end
	sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 151
	checkspots = false
end

local function valueToText(value)
	return string.format("%0.1f",math.round((value/1000),1))
end

local function CalcSpotScale(spot)
	return 0.77 + ((math.max(spot.maxX,spot.minX)-(math.min(spot.maxX,spot.minX))) * (math.max(spot.maxZ,spot.minZ)-(math.min(spot.maxZ,spot.minZ)))) / 10000
end


local function InitializeAtlas(mSpots)
	local multipliers = {[1] = true} -- all unique multipliers
	for i,teamID in ipairs(Spring.GetTeamList()) do
		local incomeMultiplier = select(7, Spring.GetTeamInfo(teamID, false))
		if multipliers[incomeMultiplier] == nil then
			multipliers[incomeMultiplier] = teamID
		end
		--Spring.Echo("incomeMultiplier", teamID, incomeMultiplier)
		teamIncomeMultipliers[teamID] = incomeMultiplier
	end
	local uniquevalues = {}
	local numvalues = 0
	local numMultipliers = 0
	for multiplier, _ in pairs(multipliers) do
		numMultipliers = numMultipliers + 1
		for i = 1, #mSpots do
			local spot = mSpots[i]
			local value = valueToText(spot.worth * multiplier)
			if tonumber(value) > 0.001 and tonumber(value) < maxValue then
				local scale = CalcSpotScale(spot)
				if scale < maxScale then
					if uniquevalues[value] == nil then
						uniquevalues[value] = value
						numvalues = numvalues + 1
					end
				end
			end
		end
	end

	-- Whats the size of one of these? I would say width 128, height 64
	local textheight = 96
	textheight = math.ceil(fontfileSize*fontfileScale +  fontfileOutlineSize*fontfileScale * 0.5)
	--Spring.Echo(textheight)
	local textwidth  = 2 * textheight
	-- attempt to make a square-ish, power of two-ish atlas:
	local cellcount = math.max(1, math.ceil(math.sqrt(numvalues)))
	MetalSpotTextAtlas = MakeAtlasOnDemand({sizex = textwidth * cellcount, sizey =  textheight*cellcount, xresolution = textwidth, yresolution = textheight, name = "MetalSpotAtlas", defaultfont = {font = font, options = 'o'}})
	AtlasTextureID = MetalSpotTextAtlas.textureID

	for uniqueValue, value in pairs(uniquevalues) do
		local uvcoords = MetalSpotTextAtlas:AddText(value)
		valueToUVs[uniqueValue] = uvcoords
	end

end

local function InitializeSpots(mSpots)
	local spotsCount = 0
	for i=1, #mSpots do
		local spot = mSpots[i]
		local value = valueToText(spot.worth * incomeMultiplier)

		if tonumber(value) > 0.001 and tonumber(value) < maxValue then
			local scale = CalcSpotScale(spot)
			if scale < maxScale then
				-- Create a New myspot!
				local instanceID = spotKey(spot.x, spot.z)

				local mySpot = {x = spot.x, y= spGetGroundHeight(spot.x, spot.z), z = spot.z, value = value, scale = scale, occupied = false, t = 0, ally = false, enemy = false, instanceID = instanceID, worth = spot.worth}

				spotsCount = spotsCount + 1
				mySpots[spotsCount] = mySpot

				local ally, enemy, changed = IsSpotOccupied(mySpot)
				local occupied = ally or enemy

				local uvcoords = valueToUVs[value]
				local gh = Spring.GetGroundHeight(spot.x, spot.z)
				pushElementInstance(spotInstanceVBO, -- vbo
						{spot.x, gh, spot.z, scale,
						(occupied and 0) or 1, -1000,uvcoords.w,uvcoords.h,
						uvcoords.x,uvcoords.X,uvcoords.y,uvcoords.Y}, -- instanceData
					instanceID, -- instanceID
					true, -- updateExisting
					true -- noUpload
					)
			end
		end
	end
	uploadAllElements(spotInstanceVBO)
end

local function UpdateSpotValues() -- This will only get called on playerchanged
	for k, spot in ipairs(mySpots) do
		--local spot = mSpots[i]
		local valueNumber = spot.worth * incomeMultiplier / 1000
		local value = valueToText(spot.worth * incomeMultiplier)
		spot.value = value

		if spot.scale < maxScale and valueNumber > 0.001 and valueNumber < maxValue then
			local ally, enemy, changed = IsSpotOccupied(spot)
			local occupied = ally or enemy
			local uvcoords = valueToUVs[spot.value]

			pushElementInstance(spotInstanceVBO, -- vbo
					{spot.x, spot.y, spot.z, spot.scale,
					(occupied and 0) or 1, -1000,uvcoords.w,uvcoords.h,
					uvcoords.x,uvcoords.X,uvcoords.y,uvcoords.Y}, -- instanceData
				spot.instanceID, -- instanceID
				true, -- updateExisting
				true -- noUpload
			)
		end
	end
	uploadAllElements(spotInstanceVBO)
end


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not WG['resource_spot_finder'].metalSpotsList then
		Spring.Echo("<metalspots> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget()
	end
	if WG['resource_spot_finder'].isMetalMap then
		-- no need for this widget on metal maps
		widgetHandler:RemoveWidget()
	end

	WG.metalspots = {}
	WG.metalspots.setShowValue = function(value)
		showValue = value
	end
	WG.metalspots.getShowValue = function()
		return showValue
	end
	WG.metalspots.setOpacity = function(value)
		opacity = value
	end
	WG.metalspots.getOpacity = function()
		return opacity
	end
	WG.metalspots.setMetalViewOnly = function(value)
		metalViewOnly = value
	end
	WG.metalspots.getMetalViewOnly = function()
		return metalViewOnly
	end

	if not initGL4() then return end

	local mSpots = WG['resource_spot_finder'].metalSpotsList
	if not mSpots then return end
	InitializeAtlas(mSpots)
	InitializeSpots(mSpots)

	if #mSpots <= 1 then
		goodbye("not enough spots detected")
	end
end

function widget:DrawGenesis()
	MetalSpotTextAtlas:RenderTasks()
	-- cause the atlas is done once per initialize only
	widget.widgetHandler.RemoveCallIn(widget.widget,"DrawGenesis")
end
--[[
function widget:DrawScreen()
	MetalSpotTextAtlas:DrawToScreen()
end
]]--


function widget:Shutdown()
	if MetalSpotTextAtlas then MetalSpotTextAtlas:Delete() end
	WG.metalspots = nil
	mySpots = {}
	valueList = {}
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	isSpec, fullview = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	local oldIncomeMultiplier = incomeMultiplier
	incomeMultiplier = select(7, Spring.GetTeamInfo(Spring.GetMyTeamID(), false))
	if incomeMultiplier ~= oldIncomeMultiplier then
		UpdateSpotValues()
	end
	if fullview ~= prevFullview or myAllyTeamID ~= prevMyAllyTeamID then
		checkMetalspots()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- THIS IS FUCKING RETARDED, should be unitFinished anyway
	if extractorDefs[unitDefID] then
		checkspots = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID) -- THIS IS RETARDED TOO
	if extractorDefs[unitDefID] then
		sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 3	-- delay needed, i don't know why
	end
end

function widget:GameFrame(gf)
	if checkspots or gf >= sceduledCheckedSpotsFrame then
		checkMetalspots()
	end
end

function widget:DrawWorldPreUnit()
	local mapDrawMode = spGetMapDrawMode()
	if metalViewOnly and mapDrawMode ~= 'metal' then return end
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end

	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	gl.Culling(true)
	gl.Texture(0, "$heightmap")
	gl.Texture(1, AtlasTextureID)
	gl.DepthTest(false)

	spotShader:Activate()
	drawInstanceVBO(spotInstanceVBO)
	spotShader:Deactivate()

	if needsInit and Spring.GetGameFrame() == 0 then
		checkMetalspots()
		needsInit = false
	end

	gl.Culling(false)
	gl.Texture(0, false)
	gl.Texture(1, false)
end

function widget:GetConfigData(data)
	return {
		showValue = showValue,
		opacity = opacity,
		metalViewOnly = metalViewOnly
	}
end

function widget:SetConfigData(data)
	if data.showValue ~= nil then
		showValue = data.showValue
	end
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.metalViewOnly ~= nil then
		metalViewOnly = data.metalViewOnly
	end
end


-----------------------------------------------------------------------------------------------
-- The following is a test script.txt for multiple different resource bonuses:
--[[
[Game]
{
	[allyTeam0]
	{
		startrectright = 0.2;
		startrectbottom = 1;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0;
	}

	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = NullAI-50;
		ShortName = NullAI;
		Team = 2;
		Version = 0.1;
	}

	[team1]
	{
		Side = Cortex;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[allyTeam1]
	{
		startrectright = 1;
		startrectbottom = 1;
		startrectleft = 0.80000001;
		numallies = 0;
		startrecttop = 0;
	}

	[team3]
	{
		Side = Cortex;
		Handicap = 100;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = Armada;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team2]
	{
		Side = Armada;
		Handicap = -50;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[modoptions]
	{
	}

	[ai2]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = NullAI+100;
		ShortName = NullAI;
		Team = 3;
		Version = 0.1;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = NullAI+0;
		ShortName = NullAI;
		Team = 1;
		Version = 0.1;
	}

	[player0]
	{
		IsFromDemo = 0;
		Name = Player;
		Team = 0;
		rank = 0;
	}

	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 2;
	mapname = Archsimkats_Valley_V1;
	ishost = 1;
	numusers = 4;
	gametype = Beyond All Reason $VERSION;
	GameStartDelay = 5;
	myplayername = Player;
	nohelperais = 0;
}
]]--
