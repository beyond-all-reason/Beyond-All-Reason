local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scenario Loadout",
		desc = "Places initial units defined in scenariooptions.loadout",
		author = "Beherith",
		date = "2021.03.20",
		license = "GNU GPL, v2 or later",
		layer = 999999,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local nanoturretunitIDs = {}

local loadoutcomplete = false

local function rot_to_facing(rotation)
	--[[
	"south" | "s" | 0 == 0
	"east" | "e" | 1  == 16384
	"north" | "n" | 2 == +32 or -32k
	"west" | "w" | 3 == -16384
	]]--
	if rotation < 8192 and rotation > -8192 then
		return 0
	end
	if rotation > 8192 and rotation < 24576 then
		return 1
	end
	if rotation < -8192 and rotation > -24576 then
		return 3
	end
	return 2
end

local startMetal = 1000
local startEnergy = 1000
local teamList = {}
local additionalStorage = {}
local gaiaTeamID = Spring.GetGaiaTeamID()

function gadget:Initialize()
	gaiaTeamID = Spring.GetGaiaTeamID()
end

function gadget:GamePreload()
  if Spring.GetGameRulesParam("loadedGame") == 1 then
    Spring.Echo("Scenario: Loading saved game, skipping loadout")
		gadgetHandler:RemoveGadget(self)
  end

	if Spring.GetGameFrame() < 1 and not loadoutcomplete then
		-- so that loaded savegames dont re-place
		if Spring.GetModOptions().scenariooptions then
			Spring.Echo("Scenario: Spawning on frame", Spring.GetGameFrame())
			local scenariooptions = string.base64Decode(Spring.GetModOptions().scenariooptions)
			scenariooptions = Json.decode(scenariooptions)
			if scenariooptions and scenariooptions.unitloadout then
				Spring.Echo("Scenario: Creating unit loadout")
				local unitloadout = scenariooptions.unitloadout
				if unitloadout then
					for k, unit in pairs(unitloadout) do
						-- make sure unitdefname is valid
						if UnitDefNames[unit.name] then

							local rot = rot_to_facing(unit.rot)
							local unitID = Spring.CreateUnit(unit.name, unit.x, Spring.GetGroundHeight(unit.x, unit.z), unit.z, rot, unit.team)
							if unitID then
								Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
								if UnitDefNames[unit.name].energyStorage > 0 or UnitDefNames[unit.name].metalStorage > 0 then
									if additionalStorage[unit.team] == nil then
										additionalStorage[unit.team] = {metal = 0, energy = 0}
									end
									additionalStorage[unit.team].metal  = additionalStorage[unit.team].metal + (UnitDefNames[unit.name].metalStorage  or 0 )
									additionalStorage[unit.team].energy  = additionalStorage[unit.team].energy + (UnitDefNames[unit.name].energyStorage or 0 )
								end
							end
							if string.find(unit.name, "nanotc") then
								nanoturretunitIDs[unitID] = true
							end
							if unit.neutral == true or unit.neutral == 'true' then
								Spring.SetUnitNeutral(unitID, true)
							end
						else
							Spring.Echo("Scenario: UnitDef name is invalid:", unit.name)
						end
					end
				end
			end
			if scenariooptions and scenariooptions.featureloadout then
				Spring.Echo("Scenario: Creating feature loadout")
				local featureloadout = scenariooptions.featureloadout
				if featureloadout and next(featureloadout) then
					for k, feature in pairs(featureloadout) do
						if FeatureDefNames[feature.name] then
							local rot = tonumber(feature.rot) or 0
							local featureID = Spring.CreateFeature(feature.name, feature.x, Spring.GetGroundHeight(feature.x, feature.z), feature.z, rot, gaiaTeamID)
							if feature.resurrectas and UnitDefNames[feature.resurrectas] then
								Spring.SetFeatureResurrect(featureID, feature.resurrectas)
							end
						else
							Spring.Echo("Scenario: FeatureDef name is invalid:", feature.name)
						end
					end
				end
			end
		end
	end
  loadoutcomplete = true
	--gadgetHandler:RemoveGadget(self)
end


function gadget:GameFrame(n)
	if n == 1 then
		if next(nanoturretunitIDs) then
			for unitID, _ in pairs(nanoturretunitIDs) do
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
			end
		end
		if next(additionalStorage) then
			for teamID, additionalstorage in pairs(additionalStorage) do
				local m, mstore = Spring.GetTeamResources(teamID, "metal")
				local e, estore = Spring.GetTeamResources(teamID, "energy")
				Spring.SetTeamResource(teamID, 'ms', mstore + additionalstorage.metal)
				Spring.SetTeamResource(teamID, 'es', estore + additionalstorage.energy)
			end
			additionalStorage = nil
		end
		gadgetHandler:RemoveGadget()
	end
	--[[ periodic checking isnt very good
	if n %17 == 7 then
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			local m, mstore = Spring.GetTeamResources(teamID, "metal")
			local e, estore = Spring.GetTeamResources(teamID, "energy")
			if mstore < 500 then Spring.SetTeamResource(teamID, 'ms', 500) end
			if estore < 500 then Spring.SetTeamResource(teamID, 'es', 500) end
		end
	end
	]]--
end
