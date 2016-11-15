function widget:GetInfo()
	return {
		name = "Common Team Colors",
		desc = "v0.004 Makes neat team color scheme and everyone using this widget will see the same colors",
		author = "CarRepairer",
		date = "2013-09-24",
		license = "GPL v2",
		layer = -10001,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

options_path = 'Settings/Interface/Common Team Colors'
options = {
	simpleColors = {
		name = "Simple Colors",
		type = 'bool',
		value = false,
		desc = 'All allies are green, all enemies are red.',
		OnChange = function() widget:Initialize() end
	},
}

local echo = Spring.Echo
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- HTML color names, colors should be a "wheel"
colors = {

-- Car's per player randomizer kinda sucks, so we randomize the shit out of the lines. Sad, but effective.

--[[
	{'Coffee',			'#6F4E37'};
	{'Teal', 			'#009B95'};
	{'Salmon', 			'#FA8072'};
	{'Plum', 			'#DDA0DD'};
	{'Aquamarine', 		'#7FFFD4'};
	{'Yellow', 			'#FFFF00'};
	{'SkyBlue', 		'#87CEEB'};
	{'Navy',			'#000080'};
	{'NeonPink',		'#F535AA'};
	{'Blue',			'#1144AA'};
	{'Cyan', 			'#00FFFF'};
	{'Parchment',		'#ffda61'};
	{'Indigo', 			'#4B0082'};
	{'Red', 			'#FF0000'};
	{'Orange', 			'#ff6600'};
	{'Lime', 			'#00FF00'};
	{'Maroon', 			'#800000'};
	{'DarkGreen',		'#006400'};
	{'Green',			'#00CC00'};
	{'Mustard', 		'#FFDB58'};
	{'Sienna', 			'#A0522D'};
	{'Purple',			'#3914AF'};
	{'Pink',			'#C9007A'};
]]--

--These are the original colors used for teams in evo
	-- {'Orange',			'#ff6600'};
	-- {'Fake Parchment',	'#ffda61'};
	-- {'Teal',			'#009B95'};
	-- {'Red',				'#FF0000'};
	-- {'Purple',			'#3914AF'};
	-- {'Yellow', 			'#FFFF00'};
	-- {'Blue',			'#1144AA'};
	-- {'Pink',			'#C9007A'};
	-- {'Green',			'#00CC00'};
	
	{'Color1',			'#fe0000'};
	{'Color2',			'#cc0098'};
	{'Color3',			'#990099'};
	{'Color4',			'#670099'};
	{'Color5',			'#0051d4'};
	{'Color6',			'#0ab4c3'};
	{'Color7',			'#009900'};
	{'Color8',			'#66cc00'};
	{'Color9',			'#ffff00'};
	{'Color10',			'#ffcc00'};
	{'Color11',			'#fe9900'};
	{'Color12',			'#ff6600'};
	{'Color13',			'#9b0300'};
	{'Color14',			'#660032'};
	{'Color15',			'#673266'};
	{'Color16',			'#64339c'};
	{'Color17',			'#003399'};
	{'Color18',			'#006766'};
	{'Color19',			'#006600'};
	{'Color20',			'#679801'};
	{'Color21',			'#999a01'};
	{'Color22',			'#cf9800'};
	{'Color23',			'#cd6601'};
	{'Color24',			'#9a3501'};
}

local colorNames = {}
for _,v in ipairs(colors) do
	colorNames[v[1]] = v[2]
end

local myColor		= colorNames.Green
local allyColor 	= colorNames.Yellow
local gaiaColor		= '#CCCCCC'
local enemyColor 	= colorNames.Red

WG.LocalColor = (type(WG.LocalColor) == "table" and WG.LocalColor) or {}
WG.LocalColor.listeners = WG.LocalColor.listeners or {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local function color2incolor(r,g,b,a)
	if type(r) == 'table' then
		r,g,b,a = unpack4(r)
	end
	r = math.max(r, 0.01)
	g = math.max(g, 0.01)
	b = math.max(b, 0.01)

	local inColor = '\255\255\255\255'
	if r then
		inColor = string.char(255, r*255, g*255, b*255)
	end
	return inColor
end
local function HexToColor(hex)

	hex = hex:gsub('#', '')
	local r = hex:sub(1,2)
	local g = hex:sub(3,4)
	local b = hex:sub(5,6)
	
	r = tonumber(r, 16)
	g = tonumber(g, 16)
	b = tonumber(b, 16)
	
	r = r / 255
	g = g / 255
	b = b / 255
	
	return r,g,b

end

local function NumFromStr(str)
	local num = 0
	for i = 1, #str do
		local byteNum = string.byte(str,i,i);
		num = math.bit_xor(num*2, byteNum)
	end
	return num
end

local function RandomGameNumber()
	--[[
	local strTable = {}
	local players = Spring.GetPlayerList()
	for i, playerID in ipairs(players) do
		local name, _, spec = Spring.GetPlayerInfo(playerID)
		if not spec then
			strTable[#strTable+1] = name
			strTable[#strTable+1] = playerID
		end
	end
	local str = table.concat( strTable )
	--]]
	local teams = Spring.GetTeamList()
	local str = #teams .. Game.mapName
	--echo (str)
	return NumFromStr(str)
end



local function SetNewTeamColors(offset) 
	local gaia = Spring.GetGaiaTeamID()
	--Spring.SetTeamColor(gaia, unpack(gaiaColor))

	local allyTeamList = Spring.GetAllyTeamList()
	
	local teams = Spring.GetTeamList()
	local numTeams = #teams
	local numColors = #colors
	local skippable = numColors - numTeams
	
	
	local i = offset
	echo( '*** Common Colors ***' )
	for _, allianceID in ipairs(allyTeamList) do
				
		for _, teamID in ipairs(Spring.GetTeamList(allianceID)) do
			if (teamID ~= gaia) then
				i = (i % #colors) + 1
				
				local r,g,b = HexToColor(colors[i][2])
				
				local _, playerID = Spring.GetTeamInfo(teamID)
				local name = playerID and Spring.GetPlayerInfo(playerID) or 'noname'
				echo( ' - ' .. color2incolor(r,g,b,1) .. name .. ' (' .. colors[i][1] ..')' )
				Spring.SetTeamColor(teamID, r,g,b)
			end
		end --team
		
		if skippable > 0 then
			i = (i % #colors) + 1
			skippable = skippable - 1
		end
		
	end --alliance
	
end

local function SetNewSimpleTeamColors() 
	local gaia = Spring.GetGaiaTeamID()
	Spring.SetTeamColor(gaia, HexToColor(gaiaColor))
	
	local myAlly = Spring.GetMyAllyTeamID()
	local myTeam = Spring.GetMyTeamID()

	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _,_,_,_,_,allyID = Spring.GetTeamInfo(teamID)
		if (allyID == myAlly) then
			Spring.SetTeamColor(teamID, HexToColor(allyColor))
		elseif (teamID ~= gaia) then
			Spring.SetTeamColor(teamID, HexToColor(enemyColor))
		end
	end
	Spring.SetTeamColor(myTeam, HexToColor(myColor))	-- overrides previously defined color
end

local function ResetOldTeamColors()
	for _,team in ipairs(Spring.GetTeamList()) do
		Spring.SetTeamColor(team,Spring.GetTeamOrigColor(team))
	end
end

local function NotifyColorChange()
	for name,func in pairs(WG.LocalColor.listeners) do
		if type(func) == "function" then	-- because we don't trust other widget writers to not give us random junk
			func()				-- yeah we wouldn't even need to do this with static typing :(
		else
			Spring.Echo("<Local Team Colors> ERROR: Listener '" .. name .. "' is not a function!" )
		end
	end
end

function WG.LocalColor.localTeamColorToggle()
	options.simpleColors.value = not options.simpleColors.value
	widget:Initialize()
end

function WG.LocalColor.RegisterListener(name, func)
	WG.LocalColor.listeners[name] = func
end

function WG.LocalColor.UnregisterListener(name)
	WG.LocalColor.listeners[name] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	if options.simpleColors.value then
		SetNewSimpleTeamColors()
	else
		SetNewTeamColors( RandomGameNumber() )
	end
	
	NotifyColorChange()
end

function widget:Shutdown()
	ResetOldTeamColors()
	NotifyColorChange()
	WG.LocalColor.localTeamColorToggle = nil
end


function widget:TextCommand(command)
	--[[
    if (string.find(command, 'tc') == 1) then
        SetNewTeamColors( command:sub(4,5) + 0 )
		NotifyColorChange()
    end
	--]]
	if (string.find(command, 'commoncolors') == 1) then
        SetNewTeamColors( RandomGameNumber() )
    end
	
end