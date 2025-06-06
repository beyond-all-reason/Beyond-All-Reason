
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Factory Guard Default On",
		desc      = "Sets factory guard state to on by default",
		author    = "Hobo Joe",
		date      = "Feb 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true
	}
end

local CMD_FACTORY_GUARD = GameCMD.FACTORY_GUARD

local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		local buildOptions = unitDef.buildOptions

		for i = 1, #buildOptions do
			local buildOptDefID = buildOptions[i]
			local buildOpt = UnitDefs[buildOptDefID]

			if (buildOpt and buildOpt.isBuilder and buildOpt.canAssist) then
				isFactory[unitDefID] = true  -- only factories that can build builders are included
				break
			end
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if isFactory[unitDefID] then
		Spring.GiveOrderToUnit(unitID, CMD_FACTORY_GUARD, { 1 }, 0)
	end
end
