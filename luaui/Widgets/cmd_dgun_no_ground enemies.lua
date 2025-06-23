local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name         = "DGun no ground enemies",
      desc         = "Prevents dgun aim to snap onto enemy ground units, holding SHIFT will still target units",
      author       = "Floris", -- (derivate of a Ceddral widget)
      date         = "",
	  license      = "GNU GPL, v2 or later",
      layer        = 0,
      enabled      = false
   }
end

function widget:Initialize()
	WG['dgunnoenemy'] = true
end

function widget:Shutdown()
	WG['dgunnoenemy'] = nil
end

local isAirUnit = {}
local isShip = {}
local isUnderwater = {}
local isHover = {}
for udid, ud in pairs(UnitDefs) do
	if ud.isAirUnit then
		isAirUnit[udid] = ud.isAirUnit
	end
	if ud.modCategories then
		if ud.modCategories.ship then
			isShip[udid] = true
		end
		if ud.modCategories.underwater then
			isUnderwater[udid] = true
		end
		if ud.modCategories.hover then
			isHover[udid] = true
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD.MANUALFIRE then -- only hook dgun commands
		return false
	end
	-- number of cmdParams should either be
	-- 1 (unitID) or
	-- 3 (map coordinates)
	if #cmdParams ~= 1 or select(4, Spring.GetModKeyState()) then -- dgun is already aimed at ground, or when you hold SHIFT
		return false
	end

	local mouseX, mouseY = Spring.GetMouseState()
	local desc, cmdParams2 = Spring.TraceScreenRay(mouseX, mouseY, true)
	if nil == desc then -- off map, can not handle this properly here
		return false
	end

	if cmdParams2[1] > 0 and not Spring.IsUnitAllied(cmdParams2[1]) then -- still snap aim at enemy units
		local unitDefID = Spring.GetUnitDefID(cmdParams[1])
		-- exclude air and ships, also hovers when on water
		if isAirUnit[unitDefID] or isShip[unitDefID] or isUnderwater[unitDefID] or (Spring.GetGroundHeight(cmdParams2[1],cmdParams2[3]) < 0 and isHover[unitDefID]) then
			return false
		end
	end

	-- replace dgun order
	Spring.GiveOrder(cmdID, cmdParams2, cmdOptions)
	return true
end
