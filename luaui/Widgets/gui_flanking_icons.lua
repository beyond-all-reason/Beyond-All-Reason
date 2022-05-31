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

-- Configurable Parts:
local texture = "luaui/images/flank_icon.tga"
local fadespeed = 0.005

---- GL4 Backend Stuff----
local flankingVBO = nil
local flankingShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"
local glTexture             = gl.Texture


local spec, fullview = Spring.GetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

local function AddPrimitiveAtUnit(unitID, gameframe) -- since the icon fades, gameframe specifies last update
	if Spring.ValidUnitID(unitID) ~= true or  Spring.GetUnitIsDead(unitID) == true then return end
	local gameframe = gameframe or Spring.GetGameFrame()

	local radius = Spring.GetUnitRadius(unitID) * 3 or 64
	local mode, modilityAdd, minDamage,  maxDamage , dirX , dirY , dirZ, bonusnumber = Spring.GetUnitFlanking(unitID)

	local flankingangle = 0
	if dirX then flankingangle = math.atan2(dirX, -1.0* dirZ) end
	--Spring.Echo(math.deg(flankingangle), "Flank angle = ", unitID, flankingangle, dirX, dirZ)

	pushElementInstance(
		flankingVBO, -- push into this Instance VBO Table
			{radius, radius, 0, 2,  -- length,width,cornersize (0), extraheight
			0, -- teamID, unused
			4, -- how many vertices should we make, 4 is a rect
			gameframe, flankingangle, 0, 0, -- the gameFrame (for fading), the direction to rotate the circle
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in
		unitID, -- this is the key inside the VBO TAble, should be unique per unit
		true, -- update existing element
		nil, -- noupload, dont use unless you
		unitID) -- last one should be UNITID!
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	-- because we allow updating, we are going to set these every time damage is taking (thus changing flank angle)
	if flankingVBO.instanceIDtoIndex[unitID] then
		AddPrimitiveAtUnit(unitID)
	end
end

function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end
	if flankingVBO.usedElements > 0 then
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		glTexture(0, texture)
		flankingShader:Activate()
		flankingShader:SetUniform("iconDistance",disticon)
		flankingShader:SetUniform("addRadius",0)
		flankingVBO.VAO:DrawArrays(GL.POINTS,flankingVBO.usedElements)
		flankingShader:Deactivate()
		glTexture(0, false)
	end
end

function widget:UnitCreated(unitID)
	--Spring.Echo(spec, fullview, Spring.IsUnitAllied(unitID))
	if not (spec and fullview) then
		if not Spring.IsUnitAllied(unitID) then return end
	end
	local unitDefID = Spring.GetUnitDefID(unitID)
	if  (UnitDefs[unitDefID].speed and UnitDefs[unitDefID].speed > 0) or #UnitDefs[unitDefID].weapons > 0 then
		AddPrimitiveAtUnit(unitID, -300)
	end
end

function RemovePrimitive(unitID)
	if flankingVBO.instanceIDtoIndex[unitID] then
		popElementInstance(flankingVBO,unitID)
	end
end

function widget:UnitDestroyed(unitID)
	RemovePrimitive(unitID)
end

local function init()
	local units = Spring.GetAllUnits()
	for _, unitID in ipairs(units) do
		widget:UnitCreated(unitID)
	end
end

function widget:Initialize()
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 1
	shaderConfig.TRANSPARENCY = 1.0 -- transparency of the stuff drawn
	shaderConfig.POST_ANIM = "v_color = vec4(vec3(1.0), 1.0 - (timeInfo.x - parameters.x)*".. tostring(fadespeed).."); v_rotationY = parameters.y;" -- fading with time, and rotation passthrough
	shaderConfig.POST_SHADING = "fragColor.a = fragColor.a * g_color.a;" -- alpha blend
	shaderConfig.ANIMATION = nil
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.MAX_VERTICES = 4
	shaderConfig.USE_CORNERRECT = nil
	flankingVBO, flankingShader = InitDrawPrimitiveAtUnit(shaderConfig, "FlankingIcons")
	if flankingVBO == nil then
		widgetHandler:RemoveWidget()
		return
	end

	spec, fullview = Spring.GetSpectatingState()
	init()
end


function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = Spring.GetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		clearInstanceTable(flankingVBO)
		init()
	end
end
