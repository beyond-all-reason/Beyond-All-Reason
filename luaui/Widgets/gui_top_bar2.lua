function widget:GetInfo()
	return {
		name = "Top Bar 2",
		desc = "Shows Resources and wind speed. RmlUi edition",
		author = "Floris & lov",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		handler = true,
		enabled = true
	}
end

local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMouseState = Spring.GetMouseState
local spGetWind = Spring.GetWind
local floor = math.floor
local sformat = string.format

local windMax = Game.windMax
local document
local context
local dm

local dataModel = {

}

local myAllyTeamID
local myAllyTeamList
local myTeamID
local myPlayerID

local function checkSelfStatus()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
end

local metalbar
local energybar
local mmSlider
local blades
function widget:Initialize()
	checkSelfStatus()
	context = rmlui.GetContext("overlay")

	dataModel.resources = {
		energy = {
			current = 0,
			storage = 0,
			pull = 0,
			income = 0,
			expense = 0
		},
		metal = {
			current = 0,
			storage = 0,
			pull = 0,
			income = 0,
			expense = 0
		},
		wind = {
			min = Game.windMin,
			max = windMax,
			current = 0
		},
		tidal = {
			current = Game.tidal
		}
	}
	dm = context:OpenDataModel("data", dataModel)

	document = context:LoadDocument("luaui/rml/gui_top_bar2.rml", widget)
	metalbar = document:GetElementById("metalstorage")
	energybar = document:GetElementById("energystorage")
	mmSlider = document:GetElementById("energy")
	blades = document:GetElementById("blades")
	document:Show()
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if context then
		context:RemoveDataModel("data")
	end
end

function widget:adjustConversion(element, event)
	-- Spring.Echo("adjusting", event.parameters.value)
	local convValue = event.parameters.value
	Spring.SendLuaRulesMsg(sformat(string.char(137) .. '%i', convValue))
end

local function short(n, f)
	if f == nil then
		f = 0
	end
	if n > 9999999 then
		return sformat("%." .. f .. "fm", n / 1000000)
	elseif n > 9999 then
		return sformat("%." .. f .. "fk", n / 1000)
	else
		return sformat("%." .. f .. "f", n)
	end
end

local sec = 0
local sec2 = 0
local windspeed = 0
local bladerotation = 0
local lastbladetime = 0
function widget:Update(dt)
	local prevMyTeamID = myTeamID
	if spec and spGetMyTeamID() ~= prevMyTeamID then
		-- check if the team that we are spectating changed
		checkSelfStatus()
		init()
	end

	sec = sec + dt
	if sec > 0.033 then
		sec = 0
		local currentLevel, storage, pull, income, expense, share, sent, received = spGetTeamResources(myTeamID, 'metal')
		local metal = {
			current = short(currentLevel),
			storage = short(storage),
			pull = short(pull),
			income = short(income),
			expense = short(expense)
		}
		metalbar:SetAttribute("max", "" .. storage)
		metalbar:SetAttribute("value", "" .. currentLevel)
		currentLevel, storage, pull, income, expense, share, sent, received = spGetTeamResources(myTeamID, 'energy')
		local energy = {
			current = short(currentLevel),
			storage = short(storage),
			pull = short(pull),
			income = short(income),
			expense = short(expense)
		}
		energybar:SetAttribute("max", "" .. storage)
		energybar:SetAttribute("value", "" .. currentLevel)

		local mmLevel = Spring.GetTeamRulesParam(myTeamID, 'mmLevel')
		mmSlider:SetAttribute("value", "" .. (mmLevel * 100))

		windspeed                 = select(4, spGetWind())
		dm.resources.wind.current = sformat('%.1f', windspeed)
		dm.resources              = {
			metal = metal,
			energy = energy,
			wind = dm.resources.wind,
			tidal = dm.resources.tidal
		}
		-- windspeed                 = 19
		-- bladerotation             = (bladerotation + windspeed / 4) % 360
		-- blades.style.transform    = "rotate(" .. bladerotation .. "deg)";

		-- dm:__SetDirty("resources")
	end

	sec2 = sec2 + dt
	if sec2 >= lastbladetime then
		lastbladetime = floor((1 - (windspeed / windMax) + .05) * 14 + 3)
		if windspeed == 0 then
			lastbladetime = 1
			blades.style.animation = "1s linear infinite a";
		else
			blades.style.animation = lastbladetime .. "s linear infinite spin";
		end
		sec2 = 0
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		document:Show()
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		document:Hide()
	end
end
