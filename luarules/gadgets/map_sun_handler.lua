--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Sun Handler",
		version   = "v0.00001",
		desc      = "Removes additional groundSpecularColor from older maps (Pre 101)",
		author    = "GoogleFrog, Beherith",
		date      = "2 March 2016", 
		license   = "GPL",
		layer     = -1,	--higher layer is loaded last
		enabled   = true,  
	}
end


-- unsynced only
if (gadgetHandler:IsSyncedCode()) then
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
	if (Spring.SetSunLighting ~= nil) and (gl.GetAtmosphere ~= nil) and (Spring.GetConfigInt('AdvMapShading', 1) == 1) then
		local mapSpecR, mapSpecG, mapSpecB = gl.GetSun("specular")
		if (math.abs(mapSpecR - 0.1) + math.abs(mapSpecG - 0.1) + math.abs(mapSpecB - 0.1)) < 0.0001 then --default groundSpecularColor is (0.1, 0.1, 0.1)
			Spring.Echo("Map Sun Handler: Clearing groundSpecularColor via SetSunLighting because map does not change it from default.")
			Spring.SetSunLighting({groundSpecularColor = {0,0,0,0}})
		end
	end
	gadgetHandler:RemoveGadget()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
