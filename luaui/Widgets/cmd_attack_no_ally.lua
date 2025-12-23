local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name         = "Attack and Manual Fire no ally",
      desc         = "Prevents attack and manual fire aim to snap onto ally units (blocks command)",
      author       = "Ceddral, Floris",
      date         = "April 2018",
	  license      = "GNU GPL, v2 or later",
      layer        = 0,
      enabled      = true
   }
end


function widget:Initialize()
	WG['attacknoally'] = true
	WG['manualfirennoally'] = true
end

function widget:Shutdown()
	WG['attacknoally'] = nil
	WG['manualfirennoally'] = nil
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID == CMD.MANUALFIRE then
		-- cancel manual fire commands on allies by blocking, on others by stop
		if #cmdParams == 1 and Spring.IsUnitAllied(cmdParams[1]) then
			Spring.Echo("Manual fire on allied unit blocked")
			return true -- block the command
		else
			Spring.Echo("Manual fire command intercepted and canceled")
			Spring.GiveOrder(CMD.STOP, {}, cmdOptions)
			return true
		end
	elseif cmdID == CMD.ATTACK then
		-- number of cmdParams should either be
		-- 1 (unitID) or
		-- 3 (map coordinates)
		if #cmdParams ~= 1 then
			return false
		end
		if not Spring.IsUnitAllied(cmdParams[1]) then
			return false
		end -- still snap aim at enemy units

		-- for attack on allies, block the command
		Spring.Echo("Attack on allied unit blocked")
		return true
	else
		return false
	end
end
