local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name         = "Manual Fire no ally",
      desc         = "Prevents manual fire aim to snap onto ally units (cancels command instead)",
      author       = "Ceddral, Floris",
      date         = "April 2018",
	  license      = "GNU GPL, v2 or later",
      layer        = 0,
      enabled      = true
   }
end


function widget:Initialize()
	WG['manualfirennoally'] = true
end

function widget:Shutdown()
	WG['manualfirennoally'] = nil
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD.MANUALFIRE then
		return false
	end

	-- number of cmdParams should either be
	-- 1 (unitID) or
	-- 3 (map coordinates)
	if #cmdParams ~= 1 then
		return false
	end
	if not Spring.IsUnitAllied(cmdParams[1]) then
		return false
	end -- still snap aim at enemy units


	-- replace order with stop to cancel
	Spring.GiveOrder(CMD.STOP, {}, cmdOptions)
	return true
end
