function widget:GetInfo()
	return {
		name = "Unit Marker",
		version = "1.1",
		desc = "Marks spotted units of interest now with old-mark auto-remover",
		author = "LEDZ",
		date = "2012.10.01",
		license = "GNU GPL v2",
		layer = 0,
		enabled = false
	}
end
--------------------------------------------------------------------------------
--This unit marker is a culmination of previous work by Pako (this method of
--setting units of interest and their names with multi-language support) and
--enhancements by LEDZ. The amount of units/events it marks has been reduced
--substanially by Bluestone (by popular request).
--Features:
--{x}Marks units of interest with the colour of the unit's owner.
--{x}Auto-deletes previous marks for units that have moved since.

local unitsOfInterest = {
	-- Anti-Nukes
	[UnitDefNames["armamd"].id] = true,
	[UnitDefNames["corfmd"].id] = true,
	[UnitDefNames["cormabm"].id] = true,
	[UnitDefNames["armscab"].id] = true,
	[UnitDefNames["corantiship"].id] = true,
	[UnitDefNames["armantiship"].id] = true,

	-- Missile Silos
	[UnitDefNames["armsilo"].id] = true,
	[UnitDefNames["corsilo"].id] = true,
	[UnitDefNames["armemp"].id] = true,
	[UnitDefNames["cortron"].id] = true,

	-- Rapid Artilleries
	[UnitDefNames["armvulc"].id] = true,
	[UnitDefNames["corbuzz"].id] = true,
}

-- Units previously tracked, but disabled because they were too annoying:
-- Commanders, Fusion Plants, Advanced Geothermals, LRPCs, T3 Gantries, T3 Assault Bots, Jammers, Spy Bots, Flagships

local spMarkerAddPoint = Spring.MarkerAddPoint--(x,y,z,"text",local? (1 or 0))
local spMarkerErasePosition = Spring.MarkerErasePosition
local spGetUnitTeam = Spring.GetUnitTeam
local IsUnitAllied = Spring.IsUnitAllied
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamColor = Spring.GetTeamColor
local prevX, prevY, prevZ = 0, 0, 0
local prevMarkX = {}
local prevMarkY = {}
local prevMarkZ = {}

local gameStarted

local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

local function colourNames(teamID)
	local nameColourR, nameColourG, nameColourB, nameColourA = spGetTeamColor(teamID)
	local R255 = math.floor(nameColourR * 255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
	local G255 = math.floor(nameColourG * 255)
	local B255 = math.floor(nameColourB * 255)
	if R255 % 10 == 0 then
		R255 = R255 + 1
	end
	if G255 % 10 == 0 then
		G255 = G255 + 1
	end
	if B255 % 10 == 0 then
		B255 = B255 + 1
	end
	return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255) --works thanks to zwzsg
end

function widget:UnitEnteredLos(unitID, unitTeam)
	if IsUnitAllied(unitID) then
		return
	end

	local udefID = spGetUnitDefID(unitID)
	local x, y, z = spGetUnitPosition(unitID)  --x and z on map floor, y is height

	if udefID and x then
		if unitsOfInterest[udefID] then
			prevX, prevY, prevZ = prevMarkX[unitID], prevMarkY[unitID], prevMarkZ[unitID]
			if prevX == nil then
				prevX, prevY, prevZ = 0, 0, 0
			end

			if (math.sqrt(math.pow((prevX - x), 2) + (math.pow((prevZ - z), 2)))) >= 100 then
				-- marker only really uses x and z
				local markName
				local colouredMarkName
				local markColour = colourNames(spGetUnitTeam(unitID))

				markName = UnitDefs[udefID].translatedTooltip
				colouredMarkName = markColour .. markName
				spMarkerErasePosition(prevX, prevY, prevZ)
				spMarkerAddPoint(x, y, z, colouredMarkName)
				prevX, prevY, prevZ = x, y, z
				prevMarkX[unitID] = prevX
				prevMarkY[unitID] = prevY
				prevMarkZ[unitID] = prevZ
			end
		end
	end
end
