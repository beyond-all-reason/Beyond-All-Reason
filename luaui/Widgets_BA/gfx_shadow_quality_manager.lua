
function widget:GetInfo()
return {
    name      = "Shadow Quality Manager",
    desc      = "Because quality shadows are CPU heavy, it will reduce quality when fps gets low.",
    author    = "Floris",
    date      = "22 february 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -10000,
    enabled   = true
}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local maxQuality			= 8192
local minQuality			= 2048		-- I dont think a value below 2048 looks acceptable enough... wont free that much extra cpu power too
local disableFps			= 0
local skipGameframes		= 60--1611		-- dont check if quality change is needed for X gameframes
local fpsDifference			= 7			-- if fps differs X amount, then shadow quality will be allowed to change. (we dont want frequent changes because these are causing extra cpu load)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetVisibleUnits		= Spring.GetVisibleUnits
local spGetVisibleFeatures	= Spring.GetVisibleFeatures
local spGetFPS				= Spring.GetFPS
local spHaveShadows			= Spring.HaveShadows
local averageFps			= spGetFPS() + 8

local previousQuality		= maxQuality
local previousQualityFps	= 30

local shadowsAtInit			= spHaveShadows()
local turnedShadowsOff		= false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	if spHaveShadows() and Spring.GetGameFrame() < 1 then
		Spring.SendCommands({"shadows 1 "..maxQuality})
	end

	WG['shadowmanager'] = {}
	WG['shadowmanager'].getMaxQuality = function()
		return maxQuality
	end
	WG['shadowmanager'].setMaxQuality = function(value)
		maxQuality = value
		if spHaveShadows() or turnedShadowsOff then
			updateShadows(true)
		end
	end
	WG['shadowmanager'].getMinQuality = function()
		return minQuality
	end
	WG['shadowmanager'].setMinQuality = function(value)
		minQuality = value
		if spHaveShadows() or turnedShadowsOff then
			updateShadows(true)
		end
	end
	WG['shadowmanager'].getDisableFps = function()
		return disableFps
	end
	WG['shadowmanager'].setDisableFps = function(value)
		disableFps = value
		if spHaveShadows() or turnedShadowsOff then
			updateShadows(true)
		end
	end
end

function widget:Shutdown()

	-- enable shadows again when the widget has turned these off
	if not spHaveShadows() and turnedShadowsOff then
		Spring.SendCommands({"shadows 1 "..((maxQuality+minQuality)/2)})
	end
end

function updateShadows(force)
	quality = math.floor((maxQuality+minQuality) - (maxQuality / (averageFps/20)))

	if averageFps > previousQualityFps + fpsDifference  or  averageFps < previousQualityFps - fpsDifference or force then  -- weight fps values with more rendered models heavier

		if quality > maxQuality then
			quality = maxQuality
		end
		if quality < minQuality then
			quality = minQuality
		end
		if previousQuality ~= quality or force then
			previousQuality = quality
			previousQualityFps = averageFps
			if averageFps < disableFps  then
				turnedShadowsOff = true
				Spring.SendCommands({"shadows 0"})
				--Spring.Echo("Shadow quality: off   avgfps: "..math.floor(averageFps))
			else
				Spring.SendCommands({"shadows 1 "..quality})
				--Spring.Echo("Shadow quality: "..quality.."   avgfps: "..math.floor(averageFps))
			end
		end
	end
end

function widget:GameFrame(gameFrame)
	if spHaveShadows() or shadowsAtInit and turnedShadowsOff then
		
		if gameFrame%109==0 then
			local modelCount = #spGetVisibleUnits(-1,nil,false) + #spGetVisibleFeatures(-1,nil,false,false) -- expensive)
			local modelCountWeight = modelCount/1700
			if modelCountWeight > 1 then modelCountWeight = 1 end
			if modelCountWeight < 0.05 then modelCountWeight = 0.05 end
			local newAvgFps = ((spGetFPS() + (averageFps*14)) / 15)
			averageFps = averageFps + ((newAvgFps - averageFps) * modelCountWeight)	-- make it so that high model count impact avg fps changes more
			--local dquality = math.floor((maxQuality+minQuality) - (maxQuality / (averageFps/20)))
			--Spring.Echo(averageFps..'   '..dquality)
		end
		if gameFrame%skipGameframes==0 then
			updateShadows()
		end
	end
end
	
-- preserve data in case of a /luaui reload
function widget:GetConfigData(data)
    savedTable = {}
    savedTable.averageFps			= averageFps
	savedTable.previousQuality		= previousQuality
	savedTable.previousQualityFps	= previousQualityFps
	savedTable.maxQuality			= maxQuality
	savedTable.minQuality			= minQuality
	savedTable.disableFps			= disableFps
    return savedTable
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 then
		if data.averageFps ~= nil 			then  averageFps			= data.averageFps end
		if data.previousQuality ~= nil	 	then  previousQuality		= data.previousQuality end
		if data.previousQualityFps ~= nil	then  previousQualityFps	= data.previousQualityFps end
	end
	if data.maxQuality ~= nil 			then  maxQuality			= data.maxQuality end
	if data.minQuality ~= nil 			then  minQuality			= data.minQuality end
	if data.disableFps ~= nil			then  disableFps			= data.disableFps end
end
