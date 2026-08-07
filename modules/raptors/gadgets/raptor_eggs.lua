local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Raptor Eggs",
		desc = "A dead raptor leaves an egg worth reclaiming, and eggs rot",
		author = "Damgam, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end

if not (BAR.Utilities.Gametype.IsRaptors() and not BAR.Utilities.Gametype.IsScavengers()) then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local COLOURS = { "pink", "white", "red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen" }
-- Every sixth frame, one egg in eighteen loses 40 health: a 1000-health egg
-- lasts about a minute and a half, give or take the dice.
local DECAY_PERIOD = 6
local DECAY_CHANCE = 18
local DECAY_DAMAGE = 40

local raptorTeamID
local raptorAllyTeamID
local eggColours
local eggs = {} ---@type table<integer, boolean>

---@param x number
---@param y number
---@param z number
---@param unitDef table
local function dropEgg(x, y, z, unitDef)
	local metal = math.ceil(unitDef.metalCost or 0)
	local energy = metal
	local size, chance
	if metal <= 1500 then
		size, chance = "s", 0.33
	elseif metal <= 7500 then
		size, chance = "m", 0.66
		metal, energy = math.ceil(metal * 0.66), math.ceil(energy * 0.66)
	else
		size, chance = "l", 1
		metal, energy = math.ceil(metal * 0.33), math.ceil(energy * 0.33)
	end
	if math.random() > chance then
		return
	end
	local colour = eggColours[unitDef.name]
	if colour == nil or colour == "" then
		colour = COLOURS[math.random(1, #COLOURS)]
	end
	local egg = Spring.CreateFeature(
		"raptor_egg_" .. size .. "_" .. colour,
		x,
		y + 20,
		z,
		math.random(-999999, 999999),
		raptorTeamID
	)
	if egg then
		Spring.SetFeatureMoveCtrl(egg, false, 1, 1, 1, 1, 1, 1, 1, 1, 1)
		Spring.SetFeatureVelocity(
			egg,
			math.random(-30, 30) * 0.01,
			math.random(150, 350) * 0.01,
			math.random(-30, 30) * 0.01
		)
		Spring.SetFeatureResources(egg, metal, energy, metal * 10, 1.0, metal, energy)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam ~= raptorTeamID then
		return
	end
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x then
		dropEgg(x, y, z, UnitDefs[unitDefID])
	end
end

function gadget:FeatureCreated(featureID, featureAllyTeamID)
	if featureAllyTeamID == raptorAllyTeamID then
		local def = FeatureDefs[Spring.GetFeatureDefID(featureID)]
		if def and def.name:find("raptor_egg", 1, true) then
			eggs[featureID] = true
		end
	end
end

function gadget:FeatureDestroyed(featureID)
	eggs[featureID] = nil
end

function gadget:GameFrame(n)
	if n % DECAY_PERIOD ~= 2 then
		return
	end
	for eggID in pairs(eggs) do
		if math.random(1, DECAY_CHANCE) == 1 then
			Spring.SetFeatureHealth(eggID, Spring.GetFeatureHealth(eggID) - DECAY_DAMAGE, true)
		end
	end
end

function gadget:Initialize()
	local raptors = GG.Raptors
	if raptors == nil or not raptors.config.useEggs then
		gadgetHandler:RemoveGadget(self)
		return
	end
	raptorTeamID = raptors.teamID
	raptorAllyTeamID = raptors.allyTeamID
	eggColours = raptors.config.raptorEggs
end
