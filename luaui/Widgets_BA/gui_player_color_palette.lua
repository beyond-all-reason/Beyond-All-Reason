function widget:GetInfo()
	return {
		name = "Player Color Palette",
		desc = "Applies an evenly distributed color palette among players. Toggle randomized colors with /shufflecolors, order by hue with /ordercolors",
		author = "Floris",
		date = "March 2017",
		license = "GPL v2",
		layer = -10001,
		enabled = true,
	}
end

local randomize = false					-- randomize player colors
local offsetstartcolor = true		-- when false it will always use red as start color, when true it starts with an offset towards center of rgb hue palette more in effect with small playernumbers

local GaiaTeam = Spring.GetGaiaTeamID()
local GaiaTeamColor = {255,0,0 }

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
	local h = 0
	--if i > (teams * 0.33) then l = 0.7 end
	--if i > (teams * 0.66) then l = 0.3 end
	if teams > 10 then
		if i%3==0 then
			l = 0.88
		end
		if i%3==2 then
			l = 0.25
		end
	else
		if teams > 6 then
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
	if teams > 7 then
		hueteams = hueteams - 1
		if i == teams then
			r,g,b = 0.5, 0.5, 0.5
			useHueRGB = false
		end
	end
	if teams > 11 then
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
		local offset = 0
		if offsetstartcolor then
			offset = 1 / (hueteams*6)
		end
		h = ((i-1)/(hueteams*(1.035+offset))) + offset
		r,g,b = hslToRgb(h, s, l)  -- teams *1.1 so last teamcolor isnt very similar to first teamcolor
	end
	return r,g,b
end

local colorOrder = {}
local function GetShuffledNumber(i, numteams)
	local n
	while true do
		n = math.floor((math.random() * numteams) + 1.5)
		if colorOrder[n] == nil then
			colorOrder[n] = i
			return n
		end
	end
end

local function SetNewTeamColors() 
	local allyTeamList = Spring.GetAllyTeamList()
	local numteams = #Spring.GetTeamList() - 1 -- minus gaia
	--local numallyteams = #Spring.GetAllyTeamList() - 1 -- minus gaia
	
	colorOrder = {}
	local i = 0
	for _, allyID in ipairs(allyTeamList) do
		for _, teamID in ipairs(Spring.GetTeamList(allyID)) do
			if teamID == GaiaTeam then
				Spring.SetTeamColor(teamID, GaiaTeamColor[1],GaiaTeamColor[2],GaiaTeamColor[3])
			else
				if randomize then
					i = GetShuffledNumber(i, numteams)
				else
					i = i + 1
				end
				local r,g,b = GetColor(i, numteams, numallyteams)

				local _, playerID = Spring.GetTeamInfo(teamID)
				local name = playerID and Spring.GetPlayerInfo(playerID) or 'noname'
				Spring.SetTeamColor(teamID, r,g,b)
			end
		end
	end
end

local function ResetOldTeamColors()
	for _,team in ipairs(Spring.GetTeamList()) do
		Spring.SetTeamColor(team,Spring.GetTeamOrigColor(team))
	end
end


function ordercolors(_,_,params)
	local oldRandomize = randomize
	randomize = false
	if oldRandomize == randomize then
		Spring.Echo("Player Color Palette:  Player colors are already ordered by hue")
	else
  	SetNewTeamColors()
  	Spring.SendCommands("luarules reloadluaui")	-- cause several widgets are still using old colors
  end
end

function shufflecolors(_,_,params)
	randomize = true
	SetNewTeamColors()
	Spring.SendCommands("luarules reloadluaui")	-- cause several widgets are still using old colors
end

function widget:Initialize()
  WG['playercolorpalette'] = {}
  WG['playercolorpalette'].getRandomize = function()
  	return randomize
  end
  WG['playercolorpalette'].setRandomize = function(value)
  	randomize = value
  	SetNewTeamColors()
  end
  
	widgetHandler:AddAction("shufflecolors", shufflecolors, nil, "t")
	widgetHandler:AddAction("ordercolors", ordercolors, nil, "t")
  
	SetNewTeamColors()
end

function widget:Shutdown()
	ResetOldTeamColors()
end


function widget:GetConfigData(data)
    savedTable = {}
    savedTable.randomize = randomize
    return savedTable
end

function widget:SetConfigData(data)
	if data.randomize ~= nil then
		randomize = data.randomize
	end
end