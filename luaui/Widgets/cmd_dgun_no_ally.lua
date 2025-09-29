local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name         = "DGun no ally",
      desc         = "Prevents dgun aim to snap onto ally units",
      author       = "Ceddral",
      date         = "2018-04-27",
      license      = "GPL",
      layer        = 0,
      enabled      = true
   }
end


function widget:Initialize()
	WG['dgunnoally'] = true
end

function widget:Shutdown()
	WG['dgunnoally'] = nil
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD.MANUALFIRE then
		return false
	end -- only hook dgun commands

	-- number of cmdParams should either be
	-- 1 (unitID) or
	-- 3 (map coordinates)
	if #cmdParams ~= 1 then
		return false
	end -- dgun is already aimed at ground
	if cmdParams[1] > 0 and not Spring.IsUnitAllied(cmdParams[1]) then
		return false
	end -- still snap aim at enemy units

	-- get map position behind cursor
	local mouseX, mouseY = Spring.GetMouseState()
	local desc, cmdParams = Spring.TraceScreenRay(mouseX, mouseY, true)
	if nil == desc then
		return false
	end -- off map, can not handle this properly here

	-- replace dgun order
	Spring.GiveOrder(cmdID, cmdParams, cmdOptions)
	return true
end
