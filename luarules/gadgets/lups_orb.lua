local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Lups Orb",
		desc = "Draws energy balls/orbs for fusions and some other selective units",
		author = "",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = 1500,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

local defaults = {
	layer = -35,
	life = 600,
	light = 2.5,
	repeatEffect = true,
}

local UnitEffects = {
	["armjuno"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 15.5, precision = 22, repeatEffect = true } },
	},
	["corjuno"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 15.5, precision = 22, repeatEffect = true } },
	},

	--// FUSIONS //--------------------------
	["corafus"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 34.5, precision = 22, repeatEffect = true } },
	},
	["corafust3"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 120, 0 }, size = 74, precision = 22, repeatEffect = true } },
	},
	["corfus"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 50, 0 }, size = 25, precision = 22, repeatEffect = true } },
	},
	["armafus"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 30.5, precision = 22, repeatEffect = true } },
	},
	["armafust3"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 120, 0 }, size = 61, precision = 22, repeatEffect = true } },
	},
	["legfus"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 10.5, 0 }, size = 23, precision = 22, repeatEffect = true } },
	},
	["legafus"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0,60, 0 }, size = 39, precision = 22, repeatEffect = true } },
	},
	["legafust3"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0,120, 0 }, size = 78, precision = 22, repeatEffect = true } },
	},
	["resourcecheat"] = {
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 30.5, precision = 22, repeatEffect = true } },
	},

	--// DEFLECTORS //--------------------------
	["corgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12.5, precision = 22, repeatEffect = true } },
	},
	["corfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12.5, precision = 22, repeatEffect = true } },
	},
	["corgatet3"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 78, 0 }, size = 20, precision = 22, repeatEffect = true } },
	},
	["armgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 23.5, -5 }, size = 17, precision = 22, repeatEffect = true } },
	},
	["armfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 25, 0 }, size = 17, precision = 22, repeatEffect = true } },
	},
	["armgatet3"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 45, -5 }, size = 23, precision = 22, repeatEffect = true } },
	},
	["legdeflector"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 38, 0 }, size = 12.5, precision = 22, repeatEffect = true } },
	},	
	["leggatet3"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 45, 0 }, size = 20, precision = 22, repeatEffect = true } },
	},


	["lootboxbronze"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 34, 0 }, size = 10.5, precision = 22, repeatEffect = true } },
	},
	["lootboxsilver"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 52, 0 }, size = 15.5, precision = 22, repeatEffect = true } },
	},
	["lootboxgold"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 69, 0 }, size = 20.5, precision = 22, repeatEffect = true } },
	},
	["lootboxplatinum"] = {
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 87, 0 }, size = 25.5, precision = 22, repeatEffect = true } },
	},

}

local scavEffects = {}
if UnitDefNames['armcom_scav'] then
	for k, effect in pairs(UnitEffects) do
		if UnitDefNames[k .. '_scav'] then
			scavEffects[k .. '_scav'] = effect
			if scavEffects[k .. '_scav'].options then
				if scavEffects[k .. '_scav'].options.color then
					scavEffects[k .. '_scav'].options.color = { 0.92, 0.32, 1.0 }
				end
				if scavEffects[k .. '_scav'].options.colormap then
					scavEffects[k .. '_scav'].options.colormap = { { 0.92, 0.32, 1.0 } }
				end
				if scavEffects[k .. '_scav'].options.colormap1 then
					scavEffects[k .. '_scav'].options.colormap1 = { { 0.92, 0.32, 1.0 } }
				end
				if scavEffects[k .. '_scav'].options.colormap2 then
					scavEffects[k .. '_scav'].options.colormap2 = { { 0.92, 0.32, 1.0 } }
				end
			end
		end
	end
	for k, effect in pairs(scavEffects) do
		UnitEffects[k] = effect
	end
	scavEffects = nil
end

local newEffects = {}
for unitname, effect in pairs(UnitEffects) do
	if UnitDefNames[unitname] then
		newEffects[UnitDefNames[unitname].id] = effect
	end
end
local newEffectsCopy = table.copy(UnitEffects)
for name,effect in pairs(newEffectsCopy) do
	newEffects[name..'_scav'] = effect
end
UnitEffects = newEffects
newEffects = nil

local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local mySpec, fullview = Spring.GetSpectatingState()

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsActive = Spring.GetUnitIsActive
local IsPosInLos = Spring.IsPosInLos
local GetUnitPosition = Spring.GetUnitPosition

local particleIDs = {}
local Lups, LupsAddFX

local spGetTeamColor = Spring.GetTeamColor
local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b = spGetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b
end
local updateTimer = 0


local function ClearFxs(unitID)
	if particleIDs[unitID] then
		for _, fxID in ipairs(particleIDs[unitID]) do
			Lups.RemoveParticles(fxID)
		end
		particleIDs[unitID] = nil
	end
end

local function AddFxs(unitID, fxID)
	if not particleIDs[unitID] then
		particleIDs[unitID] = {}
	end
	particleIDs[unitID][#particleIDs[unitID] + 1] = fxID
end

local function addUnit(unitID, unitDefID)
	if not fullview and select(6, Spring.GetTeamInfo(Spring.GetUnitTeam(unitID))) ~= myAllyTeamID and not CallAsTeam(myTeamID, IsPosInLos, GetUnitPosition(unitID)) then
		return
	end

	for _, fx in ipairs(UnitEffects[unitDefID]) do
		if fx.options.onActive == true and spGetUnitIsActive(unitID) == nil then
			break
		else
			fx.options.unit = unitID
			fx.options.under_construction = spGetUnitIsBeingBuilt(unitID)
			AddFxs(unitID, LupsAddFX(fx.class, fx.options))
			fx.options.unit = nil
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if UnitEffects[unitDefID] then
		addUnit(unitID, unitDefID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if UnitEffects[unitDefID] then
		ClearFxs(unitID)
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if not spGetUnitIsBeingBuilt(unitID) then
		gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
		gadget:UnitFinished(unitID, unitDefID, newTeam)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if not spGetUnitIsBeingBuilt(unitID) then
		gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
		gadget:UnitFinished(unitID, unitDefID, newTeam)
	end
end

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if UnitEffects[unitDefID] and (fullview or CallAsTeam(myTeamID, IsPosInLos, GetUnitPosition(unitID))) then
		if not particleIDs[unitID] then
			for _, fx in ipairs(UnitEffects[unitDefID]) do
				if fx.options.onActive == true and spGetUnitIsActive(unitID) == nil then
					break
				elseif not select(3, Spring.GetUnitIsStunned(unitID)) then -- not inbuild
					fx.options.unit = unitID
					fx.options.under_construction = spGetUnitIsBeingBuilt(unitID)
					AddFxs(unitID, LupsAddFX(fx.class, fx.options))
					fx.options.unit = nil
				end
			end
		end
	end
end

function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if UnitEffects[unitDefID] and not fullview and not CallAsTeam(myTeamID, IsPosInLos, GetUnitPosition(unitID)) then
		ClearFxs(unitID)
	end
end

local function CheckForExistingUnits()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		if UnitEffects[unitDefID] and not spGetUnitIsBeingBuilt(unitID) then
			local _, _, inBuild = Spring.GetUnitIsStunned(unitID)
			if not inBuild then
				addUnit(unitID, unitDefID)
			end
		end
	end
end

local function removeParticles()
	for _, unitFxIDs in pairs(particleIDs) do
		for _, fxID in ipairs(unitFxIDs) do
			Lups.RemoveParticles(fxID)
		end
	end
	particleIDs = {}
end

function gadget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		myTeamID = Spring.GetMyTeamID()
		myAllyTeamID = Spring.GetMyAllyTeamID()
		if fullview ~= select(2, Spring.GetSpectatingState()) then
			mySpec, fullview = Spring.GetSpectatingState()
			removeParticles()
			CheckForExistingUnits()
		end
	end
end

function gadget:Initialize()
	if not Lups then
		Lups = GG['Lups']
		LupsAddFX = Lups.AddParticles
	end
	CheckForExistingUnits()
end

function gadget:Shutdown()
	removeParticles()
end

local function CheckTeamColors()
	local detectedChanges = false
	for i = 1, #teams do
		local r, g, b = spGetTeamColor(teams[i])
		if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
			teamColorKeys[teams[i]] = r..'_'..g..'_'..b
			detectedChanges = true
		end
	end
	if detectedChanges then
		gadget:Shutdown()
		gadget:Initialize()
	end
end

function gadget:Update()
	updateTimer = updateTimer + Spring.GetLastUpdateSeconds()
	if updateTimer > 1.5 then
		updateTimer = 0
		CheckTeamColors()
	end
end
