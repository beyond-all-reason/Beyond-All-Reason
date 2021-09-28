function gadget:GetInfo()
	return {
		name = "Scenario Loadout",
		desc = "Places initial units defined in scenariooptions.loadout",
		author = "Beherith",
		date = "2021.03.20",
		license = "CC BY NC ND",
		layer = 1000000,
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

function gadget:Initialize()
	local gaiateamid = Spring.GetGaiaTeamID()
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
			scenariooptions = Spring.Utilities.json.decode(scenariooptions)
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
							end
							if unit.name == "armnanotc" or unit.name == "cornanotc" or unit.name == "armnanotcplat" or unit.name == "cornanotcplat" then
								nanoturretunitIDs[unitID] = true
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
							local featureID = Spring.CreateFeature(feature.name, feature.x, Spring.GetGroundHeight(feature.x, feature.z), feature.z, rot, gaiateamid)
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
	if n > 1 then
		gadgetHandler:RemoveGadget(self)
	end

	if n == 1 and next(nanoturretunitIDs) then
		for unitID, _ in pairs(nanoturretunitIDs) do
			Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		end
	end
end
