function gadget:GetInfo()
	return {
		name      = "Fighter radius",
		desc      = "If collisions enabled: Set a smaller unit radius for fighters",
		author    = "Floris",
		date      = "October 2017",
		license   = "",
		layer     = 1000,
		enabled   = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local isFighter = {}
	for udid, ud in pairs(UnitDefs) do
		if ud.isFighterAirUnit and not string.find(ud.name, 'liche') then       -- liche is classified as one somehow
			isFighter[udid] = true
		end
	end
	local radiusMult = 0.25
	local heightMult = 1
	local collisionFighters = {}

	function gadget:Initialize()
		local count = 0
		for unitDefID,_ in ipairs(isFighter) do
			if UnitDefs[unitDefID].collide == true then
				local unitDimentions = Spring.GetUnitDefDimensions(unitDefID)
				collisionFighters[unitDefID] = {unitDimentions['radius'] * radiusMult, unitDimentions['height'] * heightMult }
				count = count + 1
			end
		end
		if count == 0 then
			gadgetHandler:RemoveGadget(self)
		end
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if collisionFighters[unitDefID] ~= nil then
			Spring.SetUnitRadiusAndHeight(unitID, collisionFighters[unitDefID][1], collisionFighters[unitDefID][2])
		end
	end

end
