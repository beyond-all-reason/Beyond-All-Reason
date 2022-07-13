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

local corafusShieldSphere = table.merge(defaults, {
	pos = { 0, 60, 0 },
	size = 32,
	light = 4,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local armafusShieldSphere = table.merge(defaults, {
	pos = { 0, 60, 0 },
	size = 28,
	light = 4.25,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
})

local corfusShieldSphere = table.merge(defaults, {
	pos = { 0, 51, 0 },
	size = 23,
	light = 3.25,
	--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
	--colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
})

local corgateShieldSphere = table.merge(defaults, {
	pos = { 0, 42, 0 },
	size = 11,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local armjunoShieldSphere = table.merge(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local corjunoShieldSphere = table.merge(defaults, {
	pos = { 0, 72, 0 },
	size = 13,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
})

local armgateShieldSphere = table.merge(defaults, {
	pos = { 0, 23.5, -5 },
	size = 14.5,
	colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
	colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
})

local UnitEffects = {
	["armjuno"] = {
		{ class = 'ShieldSphere', options = armjunoShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
	},
	["corjuno"] = {
		{ class = 'ShieldSphere', options = corjunoShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
	},

	--// FUSIONS //--------------------------
	["corafus"] = {
		{ class = 'ShieldSphere', options = corafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 32.5, precision = 22, repeatEffect = true } },
	},
	["corfus"] = {
		{ class = 'ShieldSphere', options = corfusShieldSphere },
		{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 50, 0 }, size = 23.5, precision = 22, repeatEffect = true } },
	},
	["armafus"] = {
		{ class = 'ShieldSphere', options = armafusShieldSphere },
		{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 28.5, precision = 22, repeatEffect = true } },
	},
	["corgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = corgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
		--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
	},
	["corfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = corgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
		--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
	},
	["armgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 23.5, -5 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = armgateShieldSphere },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
	},
	["armfgate"] = {
		{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 25, 0 }, size = 15, precision = 22, repeatEffect = true } },
		{ class = 'ShieldSphere', options = table.merge(armgateShieldSphere, { pos = { 0, 25, 0 } }) },
		--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,25,0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
	},

}

local scavEffects = {}
if UnitDefNames['armcom_scav'] then
	for k, effect in pairs(UnitEffects) do
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
	for k, effect in pairs(scavEffects) do
		UnitEffects[k] = effect
	end
	scavEffects = nil
end

local newEffects = {}
for unitname, effect in pairs(UnitEffects) do
	newEffects[UnitDefNames[unitname].id] = effect
end
UnitEffects = newEffects
newEffects = nil

local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local mySpec, fullview = Spring.GetSpectatingState()

local spGetUnitRulesParam = Spring.GetUnitRulesParam
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
			fx.options.under_construction = spGetUnitRulesParam(unitID, "under_construction")
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

function gadget:UnitDestroyed(unitID, unitDefID)
	if UnitEffects[unitDefID] then
		ClearFxs(unitID)
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
	gadget:UnitFinished(unitID, unitDefID, newTeam)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
	gadget:UnitFinished(unitID, unitDefID, newTeam)
end

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if UnitEffects[unitDefID] and (fullview or CallAsTeam(myTeamID, IsPosInLos, GetUnitPosition(unitID))) then
		if not particleIDs[unitID] then
			for _, fx in ipairs(UnitEffects[unitDefID]) do
				if fx.options.onActive == true and spGetUnitIsActive(unitID) == nil then
					break
				elseif not select(3, Spring.GetUnitIsStunned(unitID)) then -- not inbuild
					fx.options.unit = unitID
					fx.options.under_construction = spGetUnitRulesParam(unitID, "under_construction")
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
		if UnitEffects[unitDefID] and spGetUnitRulesParam(unitID, "under_construction") ~= 1 then
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
