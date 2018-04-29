function widget:GetInfo()
   return {
      name         = "Attack no ally",
      desc         = "Prevents attack-aim to snap onto ally units (targets ground instead)",
      author       = "Ceddral, Floris",
      date         = "April 2018",
      license      = "GPL",
      layer        = 0,
      enabled      = true
   }
end


function widget:Initialize()
	WG['attacknoally'] = true
end

function widget:Shutdown()
	WG['attacknoally'] = nil
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD.ATTACK then
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


	-- get map position behind cursor
	local mouseX, mouseY = Spring.GetMouseState()
	local desc, cmdParams = Spring.TraceScreenRay(mouseX, mouseY, true)
	if nil == desc then
		return false
	end -- off map, can not handle this properly here
	--cmdParams[4] = nil	-- not a clue why ther is a 4th parameter

	-- replace order
	Spring.GiveOrder(cmdID, {cmdParams[1], cmdParams[2], cmdParams[3]}, cmdOptions)
	return true
end
