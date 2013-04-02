function widget:GetInfo()
	return {
		name      = "Adv. Unit Marker",
		version   = "1.0",
		desc      = "Marks spotted units of interest now with old-mark auto-remover",
		author    = "LEDZ",
		date      = "2012.10.01",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = false
	}
end
--------------------------------------------------------------------------------
--This unit marker is a culmination of previous work by Pako (this method of
--setting units of interest and their names with multi-language support) and
--enhancements by LEDZ. The amount of units/events it marks has been reduced 
--substanially by Bluestone (by popular request).
--Features:
--{x}Multilanguage support
--{x}Marks units of interest with the colour of the unit's owner.
--{x}Auto-deletes previous marks for units that have moved since.

local unitList = {}
--MARKER LIST ------------------------------------
unitList["BA"] = {
--[UnitDefNames["armcom"].id] = true,
--[UnitDefNames["corcom"].id] = true,

[UnitDefNames["armamd"].id] = {["en"]="Anti-Nuke", ["de"]="Anti-Atomwaffe", ["fr"]="Contre l'Arme Nucléaire" },
[UnitDefNames["corfmd"].id] = {["en"]="Anti-Nuke" , ["de"]="Anti-Atomwaffe", ["fr"]="Contre l'Arme Nucléaire" },

[UnitDefNames["cormabm"].id] = {["en"]="Mobile Anti-Nuke", ["de"]="Mobile Anti-Atomwaffe", ["fr"]="Mobile Contre l'Arme Nucléaire" },
[UnitDefNames["armscab"].id] = {["en"]="Mobile Anti-Nuke", ["de"]="Mobile Anti-Atomwaffe", ["fr"]="Mobile Contre l'Arme Nucléaire" },

[UnitDefNames["armsilo"].id] = 	{["en"]="Nuke Missile Silo", ["de"]="Atom-Raketensilo", ["fr"]="l'Arme Nucléaire" },
[UnitDefNames["corsilo"].id] = 	{["en"]="Nuke Missile Silo", ["de"]="Atom-Raketensilo", ["fr"]="l'Arme Nucléaire" },

--[UnitDefNames["armfus"].id] = 	{["en"]="Fusion", ["de"]="Fusion", ["fr"]="Fusion" },
--[UnitDefNames["corfus"].id] = 	{["en"]="Fusion", ["de"]="Fusion", ["fr"]="Fusion" },
--[UnitDefNames["armckfus"].id] = {["en"]="Cloakable Fusion", 	["de"]="Unsichtbar Fusion", ["fr"]="Camouflée Fusion" },

--[UnitDefNames["aafus"].id] = 	{["en"]="Adv. Fusion", ["de"]="Fortgeschrittene Fusion", ["fr"]="Supérieur Fusion" },
--[UnitDefNames["cafus"].id] = 	{["en"]="Adv. Fusion", ["de"]="Fortgeschrittene Fusion", ["fr"]="Supérieur Fusion" },

--[UnitDefNames["amgeo"].id] = 	{["en"]="Moho Geo", ["de"]="Moho Geo", ["fr"]="Moho Géo" },
--[UnitDefNames["cmgeo"].id] = 	{["en"]="Moho Geo", ["de"]="Moho Geo", ["fr"]="Moho Géo" },

--[UnitDefNames["armbrtha"].id] = {["en"]="LRPC", ["de"]="Große Reichweite Plasmakanone", ["fr"]="Canon Plasma Longue Portée" },
--[UnitDefNames["corint"].id] = 	{["en"]="LRPC", ["de"]="Große Reichweite Plasmakanone", ["fr"]="Canon Plasma Longue Portée" },

[UnitDefNames["armemp"].id] = 	{["en"]="EMP Silo", ["de"]="EMP-Raketensilo", ["fr"]="EMP Silo" },
[UnitDefNames["cortron"].id] = 	{["en"]="Tactical Nuke Silo", ["de"]="Taktische Atom-Raketensilo", ["fr"]="l'Arme Tactiques Nucléaire" },

[UnitDefNames["armvulc"].id] = 	{["en"]="Vulcan", ["de"]="Schnellfeuer-Plasmakanone", ["fr"]="Cadence de Tir Élevé Plasma Canon" },
[UnitDefNames["corbuzz"].id] = 	{["en"]="Buzzsaw", ["de"]="Schnellfeuer-Plasmakanone", ["fr"]="Cadence de Tir Élevé Plasma Canon" },

--[UnitDefNames["armshltx"].id] = {["en"]="Gantry", ["de"]="Experimentelle Fabrik", ["fr"]="Usine Expérimentale" },
--[UnitDefNames["corgant"].id] = 	{["en"]="Gantry", ["de"]="Experimentelle Fabrik", ["fr"]="Usine Expérimentale" },

--[UnitDefNames["corkrog"].id] = 	{["en"]="Krogoth", ["de"]="Krogoth", ["fr"]="Krogoth" },
--[UnitDefNames["armbanth"].id] = 	{["en"]="Bantha", ["de"]="Bantha", ["fr"]="Bantha" },

--[UnitDefNames["corshroud"].id] = 	{["en"]="Adv. Jammer", ["de"]="Fortgeschrittene Radarstörsender", ["fr"]="" },
--[UnitDefNames["armveil"].id] = 	{["en"]="Adv. Jammer", ["de"]="Fortgeschrittene Radarstörsender", ["fr"]="" },
--[UnitDefNames["armjamt"].id] = 	{["en"]="Cloakable Jammer", ["de"]="Unsichtbar Radarstörsender", ["fr"]="" },
--[UnitDefNames["coreter"].id] = 	{["en"]="Jammer", ["de"]="Radarstörsender", ["fr"]="" },

--[UnitDefNames["corspy"].id] = 	{["en"]="Spy", ["de"]="Spion", ["fr"]="" },
--[UnitDefNames["armspy"].id] = 	{["en"]="Spy", ["de"]="Spion", ["fr"]="" },

--[UnitDefNames["corblackhy"].id]={["en"]="Black Hydra", ["de"]="Flaggschiff", ["fr"]="" },
--[UnitDefNames["aseadragon"].id]={["en"]="Epoch", ["de"]="Flaggschiff", ["fr"]="" }
}

--END OF MARKER LIST---------------------------------------

local myLang = "en" -- --set this if you want to bypass lobby country
local myPlayerID
local curModID
local spEcho = Spring.Echo
local spMarkerAddPoint = Spring.MarkerAddPoint--(x,y,z,"text",local? (1 or 0))
local spMarkerErasePosition = Spring.MarkerErasePosition
local spGetUnitTeam = Spring.GetUnitTeam
local IsUnitAllied = Spring.IsUnitAllied
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitHealth = Spring.GetUnitHealth
local spGetTeamColor	= Spring.GetTeamColor
local spSendCommands = Spring.SendCommands
local spGetSpectatingState = Spring.GetSpectatingState
local lastUpdate = 0
local addedMarksTable = {}
local addToTable = {}
local markTime = 0
local lastUpdate = 0
local prevX,prevY,prevZ = 0,0,0
local prevMarkX = {}
local prevMarkY = {}
local prevMarkZ = {}
local x,y,z = 0,0,0

local knownUnits = {} --all units that have been marked already, so they wont get marked again
local teamNames = {}

local function GetTeamName(teamID) --need to rewrite this sloppy functionality
  local name = teamNames[teamID]
  if (name) then
    return name
  end

  local teamNum, teamLeader = Spring.GetTeamInfo(teamID)
  if (teamLeader == nil) then
    return "Not sure what purpose this originally served" -- nor I -LEDZ -- I do but its effect is lost in time -Bluestone
  end

  name = Spring.GetPlayerInfo(teamLeader)
  teamNames[teamID] = name
  return name or "Gaia"
end

function widget:Update()
		_, fullView, _ = spGetSpectatingState()
	if fullView then
		spec = true
	else
		spec = false
	end
end

function widget:Initialize()

	myColour = colourNames(Spring.GetMyTeamID())
	markerLocal = nil --note: this name of this here and on the lua wiki is a misnomer
	curModID = string.upper(Game.modShortName or "")
	if ( unitList[curModID] == nil ) then
		spEcho("<Unit Marker> Unsupported Game, shutting down...")
		widgetHandler:RemoveWidget()
		return
	else	
		curUnitList = unitList[curModID] or {}
	end
	myLang = myLang or string.lower(select(8,Spring.GetPlayerInfo(Spring.GetMyPlayerID())))
end

function colourNames(teamID) 
	nameColourR,nameColourG,nameColourB,nameColourA = spGetTeamColor(teamID)
	R255 = math.floor(nameColourR*255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
	G255 = math.floor(nameColourG*255)
	B255 = math.floor(nameColourB*255)
	if ( R255%10 == 0) then
		R255 = R255+1
	end
	if( G255%10 == 0) then
		G255 = G255+1
	end
	if ( B255%10 == 0) then
		B255 = B255+1
	end
  return "\255"..string.char(R255)..string.char(G255)..string.char(B255) --works thanks to zwzsg
end 

function widget:UnitEnteredLos(unitID, allyTeam)
	if ( IsUnitAllied( unitID ) ) then return end

	local udefID = spGetUnitDefID(unitID)
	local x, y, z = spGetUnitPosition(unitID)  --x and z on map floor, y is height
	
	if udefID and x then
	  if curUnitList[udefID] then
			prevX, prevY, prevZ = prevMarkX[unitID],prevMarkY[unitID],prevMarkZ[unitID]
			if prevX == nil then
				prevX, prevY, prevZ = 0,0,0
			end
			
			if (math.sqrt(math.pow((prevX - x), 2)+(math.pow((prevZ - z), 2)))) >= 100 then -- marker only really uses x and z
				markColour = colourNames(spGetUnitTeam(unitID))
				if UnitDefs[udefID].customParams.iscommander == "1" then
					markName = GetTeamName(spGetUnitTeam(unitID))
					colouredMarkName = markColour..markName
				else
					markName = curUnitList[udefID]
					markName = markName[myLang] or markName["en"]
					colouredMarkName = markColour..markName
				end
				spMarkerErasePosition(prevX,prevY,prevZ)
				spMarkerAddPoint(x,y,z,colouredMarkName,markerLocal)
				prevX, prevY, prevZ = x, y, z
				prevMarkX[unitID] = prevX
				prevMarkY[unitID] = prevY
				prevMarkZ[unitID] = prevZ
			end
	  end
	end
end
	






