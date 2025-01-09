function widget:GetInfo()
   return {
      name      = "Toggle metal view",
      desc      = "Toggles metal view when active command changes",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end

VFS.Include("luarules/configs/customcmds.h.lua")

local isMex = {}

local function initMexes()
	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.extractsMetal > 0 then
			isMex[uDefID] = true
		end
	end
end

function widget:Initialize()
	if Spring.SetAutoShowMetal then
		Spring.SetAutoShowMetal(false)
	end

	local success, mapinfo = pcall(VFS.Include, "mapinfo.lua")

	if mapinfo and mapinfo["autoshowmetal"] then
		initMexes()
	else
		widgetHandler:RemoveWidget()
	end
end

function widget:ActiveCommandChanged(cmdID)
	local wantsMetal = (cmdID == CMD_AREA_MEX) or (cmdID and isMex[-cmdID]) or false
	local onoff = wantsMetal and "1" or "0"

	Spring.SendCommands("showinfometal " .. onoff)
end
