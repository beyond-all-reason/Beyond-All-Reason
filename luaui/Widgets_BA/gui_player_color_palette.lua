function widget:GetInfo()
	return {
		name = "Player Color Palette",
		desc = "Applies an evenly distributed color palette among players",
		author = "Floris",
		date = "March 2017",
		license = "GPL v2",
		layer = -10001,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function hue2rgb(p, q, t)
  if (t < 0) then t = t + 1 end
  if (t > 1) then t = t - 1 end
  if (t < 1/6) then return p + (q - p) * 6 * t end
  if (t < 1/2) then return q end
  if (t < 2/3) then return p + (q - p) * (2/3 - t) * 6 end
  return p
end

local function hslToRgb(h, s, l)
  local r, g, b
  if s == 0 then
      r = l
      g = l
      b = l
  else
    local q = l + s - l * s
    if l < 0.5 then
    	q = l * (1 + s)
    end
    local p = 2 * l - q
    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  end
  return r,g,b
end

local function GetColor(i, teams)
	local s = 1
	local l = 0.53
	--if i > (teams * 0.33) then l = 0.7 end
	--if i > (teams * 0.66) then l = 0.3 end
	if teams > 12 then
		if i%3==0 then
			l = 0.88
		end
		if i%3==2 then
			l = 0.25
		end
	else
		if teams > 8 then
			if i%2==0 then
				l = 0.8
			end
			if i%2==1 then
				l = 0.42
			end
		end
	end
	
	local r,g,b = 0,0,0
	local hueteams = teams
	local useHueRGB = true
	if teams > 9 then
		hueteams = hueteams - 1
		if i == teams then
			r,g,b = 0.5, 0.5, 0.5
			useHueRGB = false
		end
	end
	if teams > 13 then
		hueteams = hueteams - 1
	 	if i == teams-1 then
			r,g,b = 0.9, 0.9, 0.9
			useHueRGB = false
		end
	end
	if teams > 15 then
		hueteams = hueteams - 1
		if i == teams-2 then
			r,g,b = 0, 0, 0
			useHueRGB = false
		end
	end
	if useHueRGB then
		r,g,b = hslToRgb((i/(hueteams*1.1)) - (1/hueteams), s, l)  -- teams *1.1 so last teamcolor isnt very similar to first teamcolor
	end
	return r,g,b
end

local function SetNewTeamColors() 
	local allyTeamList = Spring.GetAllyTeamList()
	local numteams = #Spring.GetTeamList() - 1 -- minus gaia
	--local numallyteams = #Spring.GetAllyTeamList() - 1 -- minus gaia
	
	local i = 0
	for _, allyID in ipairs(allyTeamList) do
		for _, teamID in ipairs(Spring.GetTeamList(allyID)) do
			i = i + 1
			local r,g,b = GetColor(i, numteams, numallyteams)
			
			local _, playerID = Spring.GetTeamInfo(teamID)
			local name = playerID and Spring.GetPlayerInfo(playerID) or 'noname'
			Spring.SetTeamColor(teamID, r,g,b)
		end
	end
end

local function ResetOldTeamColors()
	for _,team in ipairs(Spring.GetTeamList()) do
		Spring.SetTeamColor(team,Spring.GetTeamOrigColor(team))
	end
end

function widget:Initialize()
	SetNewTeamColors()
end

function widget:Shutdown()
	ResetOldTeamColors()
end