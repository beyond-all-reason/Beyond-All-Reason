local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "UnitDamagedReplay",
		desc	= 'Expose full UnitDamaged to widgets only during replays',
		author	= 'Itanthias',
		date	= 'Sept 2022',
		license	= 'GNU GPL, v2 or later',
		layer	= 1,
		enabled	= true
	}
end

-- put gadget in unsynced space
if not gadgetHandler:IsSyncedCode() then
	local hooked = true
	local allowForwarding

	local function hookCallIn()
		-- check if game is a replay or spectating
		allowForwarding = Spring.IsReplay() or Spring.GetSpectatingState()
		if hooked and not allowForwarding then
			gadgetHandler:RemoveCallIn("UnitDamaged")
			hooked = false
		elseif not hooked and allowForwarding then
			gadgetHandler:UpdateCallIn("UnitDamaged")
			hooked = true
		end
	end

	function gadget:PlayerChanged(playerID)
		hookCallIn()
	end

	function gadget:Initialize()
		hookCallIn()
	end

	-- handle the UnitDamaged callin
	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		-- send to LuaUI, widget space, the UnitDamaged information
		if Script.LuaUI("UnitDamagedReplay") then
			Script.LuaUI.UnitDamagedReplay(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		end
	end
end

--[[
Use this widget to print UnitDamaged info to the infolog (or modify it for your purposes)
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
      name      = "UnitDamageReplayAnalysis",
      desc      = "Saves Unit Damaged Events from replays to file",
      author    = "Anon",
      date      = "The Future",
      layer     = 0,
      enabled   = true
    }
end

local function UnitDamagedReplay(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		
	Spring.Echo("UnitDamagedInfo")
	Spring.Echo(unitID)
	Spring.Echo(unitDefID)
	Spring.Echo(unitTeam)
	Spring.Echo(paralyzer)
	Spring.Echo(weaponDefID)
	Spring.Echo(projectileID)
	Spring.Echo(attackerID)
	Spring.Echo(attackerDefID)
	Spring.Echo(attackerTeam)

end

function widget:Initialize()
	
	widgetHandler:RegisterGlobal("UnitDamagedReplay",UnitDamagedReplay)

end

function widget:Shutdown()

	widgetHandler:DeregisterGlobal("UnitDamagedReplay")

end

]]--
