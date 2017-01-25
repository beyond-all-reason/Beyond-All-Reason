
function widget:GetInfo()
  return {
    name      = "Mexspot Fetcher",
    desc      = "Fetches metal spot data from synced.",
    author    = "Google Frog", -- 
    date      = "22 April 2012",
    license   = "GNU GPL, v2 or later",
    layer     = -30000,
    enabled   = true,  --  loaded by default?
    alwaysStart = true,
	hidden    = true,
  }
end

local spGetGameRulesParam = Spring.GetGameRulesParam

local function GetSpotsByPos(spots)
	local spotPos = {}
	for i = 1, #spots do
		local spot = spots[i]
		local x = spot.x
		local z = spot.z
		--Spring.MarkerAddPoint(x,0,z,x .. ", " .. z)
		spotPos[x] = spotPos[x] or {}
		spotPos[x][z] = i
	end
	return spotPos
end

local function GetMexSpotsFromGameRules()
	local mexCount = spGetGameRulesParam("mex_count")
	if (not mexCount) or mexCount == -1 then
		WG.metalSpots = false
		WG.metalSpotsByPos = false
		return
	end
	
	local metalSpots = {}
	
	for i = 1, mexCount do
		metalSpots[i] = {
			x = spGetGameRulesParam("mex_x" .. i),
			y = spGetGameRulesParam("mex_y" .. i),
			z = spGetGameRulesParam("mex_z" .. i),
			metal = spGetGameRulesParam("mex_metal" .. i),
		}
	end
	
	local metalSpotsByPos = GetSpotsByPos(metalSpots)
	
	WG.metalSpots = metalSpots
	WG.metalSpotsByPos = metalSpotsByPos
end

function widget:Initialize()
	Spring.Echo("Mexspot Fetcher fetching")
	GetMexSpotsFromGameRules()
end