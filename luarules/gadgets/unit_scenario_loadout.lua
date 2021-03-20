function gadget:GetInfo()
	return {
		name      = "Scenario Loadout",
		desc      = "Places initial units defined in scenariooptions.loadout",
		author    = "Beherith",
		date      = "2021.03.20",
		license   = "CC BY NC ND",
		layer     = 1000000,
		enabled   = true,
	}
end
  
if (not gadgetHandler:IsSyncedCode()) then
	return
end


function gadget:Initialize()
  local gaiateamid = Spring.GetGaiaTeamID()
	if Spring.GetGameFrame() < 1 then -- so that loaded savegames dont re-place
    if Spring.GetModOptions and Spring.GetModOptions().scenariooptions then
      Spring.Echo("Scenario: Spawning on frame", Spring.GetGameFrame())
      local scenariooptions = Spring.Utilities.Base64Decode(Spring.GetModOptions().scenariooptions)
      scenariooptions = Spring.Utilities.json.decode(scenariooptions)
      if scenariooptions  and scenariooptions.unitloadout then
        Spring.Echo("Scenario: Creating unit loadout")
        unitloadout = scenariooptions.unitloadout
        if next(unitloadout) then
          for k, unit in pairs(unitloadout) do
            -- make sure unitdefname is valid
            if UnitDefNames[unit.name] then
              local rot = tonumber(unit.rot) or 0
              local unitID = Spring.CreateUnit(unit.name, unit.x, Spring.GetGroundHeight(unit.x, unit.z), unit.z, rot, unit.team)
            else
              Spring.Echo("Scenario: UnitDef name is invalid:",unit.name)
            end
          end
        end
      end
      if scenariooptions and scenariooptions.featureloadout then
        Spring.Echo("Scenario: Creating feature loadout")
        featureloadout = scenariooptions.featureloadout
        if next(featureloadout) then
          for k, feature in pairs(featureloadout) do  
            if FeatureDefNames[feature.name] then
              local rot = tonumber(feature.rot) or 0
              local featureID = Spring.CreateFeature(feature.name, feature.x, Spring.GetGroundHeight(feature.x, feature.z), feature.z, rot, gaiateamid)
              if feature.resurrectas and UnitDefNames[feature.resurrectas] then
                Spring.SetFeatureResurrect(featureID,feature.resurrectas)
              end
            else
              Spring.Echo("Scenario: FeatureDef name is invalid:",feature.name)
            end
          end
        end
      end
    end
  end
  gadgetHandler:RemoveGadget(self)
end


