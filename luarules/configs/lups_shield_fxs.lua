local ShieldSphereBase = {
	layer = -34,
	life = 10000,
	radius = 350,
	-- default
	--colormap1 = {{0.2, 1, 0.2, 0.22}, {1, 0.2, 0.2, 0.22}},
	--colormap2 = {{0.2, 0.9, 1, 0.0}, {1, 0.9, 0.2, 0.0}},
	
	-- blue->red
	--colormap1 = {{0.25, 0.50, 1, 0.005}, {1, 0.25, 0.25, 0.001}},
	--colormap2 = {{0.25, 0.50, 1, 0.005}, {1, 0.25, 0.25, 0.001}},
	
	-- green->red
	--colormap1 = {{0.25, 1, 0.25, 0.001}, {1, 0.25, 0.25, 0.001}},
	--colormap2 = {{0.25, 1, 0.25, 0.001}, {1, 0.25, 0.25, 0.001}},

	-- iceXuick's white
	--colormap1 = {{0.99, 0.99, 0.99, 0.03}, {1, 0.6, 0.5, 0.70}},
    --colormap2 = {{0.95, 0.95, 0.95, 0.01}, {1, 0.7, 0.5, 0.0}},
	
	-- white->red
	colormap1 = {{1, 1, 1, 0.025}, {1, 0.15, 0.15, 0}},
	colormap2 = {{1, 1, 1, 0.025}, {1, 0.15, 0.15, 0}},
	
	repeatEffect = true,
	drawBack = 0.7,
	--
	terrainOutline = true,
	unitsOutline = true,
	impactAnimation = true,
	impactChrommaticAberrations = true,
	impactHexSwirl = false,
	impactScaleWithDistance = true,
	impactRipples = true,
	--
	vertexWobble = true,
	--
	bandedNoise = false,
}

local SEARCH_SMALL = {
	{0, 0},
	{1, 0},
	{-1, 0},
	{0, 1},
	{0, -1},
}

local SEARCH_MULT = 1
local SEARCH_BASE = 16
local DIAG = 1/math.sqrt(2)

local SEARCH_LARGE = {
	{0, 0},
	{1, 0},
	{-1, 0},
	{0, 1},
	{0, -1},
	{DIAG, DIAG},
	{-DIAG, DIAG},
	{DIAG, -DIAG},
	{-DIAG, -DIAG},
}
local searchSizes = {}

local shieldUnitDefs = {}
for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]

	if ud.customParams.shield_radius then
		local radius = tonumber(ud.customParams.shield_radius)
		--Spring.Echo(ud.name, radius)
		if not searchSizes[radius] then
			local searchType = (radius > 250 and SEARCH_LARGE) or SEARCH_SMALL
			local search = {}
			for i = 1, #searchType do
				search[i] = {SEARCH_MULT*(radius + SEARCH_BASE)*searchType[i][1], SEARCH_MULT*(radius + SEARCH_BASE)*searchType[i][2]}
			end
			searchSizes[radius] = search
		end

		local myShield = Spring.Utilities.CopyTable(ShieldSphereBase, true)
		if radius > 250 then
			myShield.shieldSize = "large"
			myShield.drawBack = 0.6
			myShield.drawBackMargin = 3
			myShield.margin = 0.35
			myShield.hitResposeMult = 0--0.6
		else
			myShield.shieldSize = "small"
			myShield.drawBack = 0.9
			myShield.drawBackMargin = 1.9
			myShield.margin = 0.2
			myShield.hitResposeMult = 0--1
		end
		myShield.radius = radius
		myShield.pos = {0, tonumber(ud.customParams.shield_emit_height) or 0, tonumber(ud.customParams.shield_emit_offset) or 0}

		local strengthMult = tonumber(ud.customParams.shield_color_mult)
		if strengthMult then
			myShield.colormap1[1][4] = strengthMult * myShield.colormap1[1][4]
			myShield.colormap1[2][4] = strengthMult * myShield.colormap1[2][4]
		end

		local fxTable = {
			{class = 'ShieldSphereColor', options = myShield},
		}

		if string.find(ud.name, "chicken_", nil, true) then
			myShield.colormap1 = {{0.3, 0.9, 0.2, 1.2}, {0.6, 0.4, 0.1, 1.2}} -- Note that alpha is multiplied by 0.26
			myShield.hitResposeMult = 0
			myShield.texture = "bitmaps/GPL/bubbleShield.png"
			fxTable[1].class = "ShieldSphereColorFallback"
		end

		shieldUnitDefs[unitDefID] = {
			fx = fxTable,
			search = searchSizes[radius],
			shieldCapacity = tonumber(ud.customParams.shield_power),
			shieldPos = myShield.pos,
			shieldRadius = radius,
		}
	end
end

return shieldUnitDefs
