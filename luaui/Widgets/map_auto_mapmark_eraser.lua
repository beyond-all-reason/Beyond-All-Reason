local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Auto mapmark eraser",
		desc      = "Erases points after a period of time.",
		author    = "Shaman, Floris",
		date      = "24 Sept 2022",
		license   = "",
		layer     = 0,
		enabled   = true,
	}
end

local eraseTime = 60
local frame = -1
local pointsToErase = {}
local recentlyErased = {}

function widget:Initialize()
	WG['autoeraser'] = {}
	WG['autoeraser'].getEraseTime = function()
		return eraseTime
	end
	WG['autoeraser'].setEraseTime = function(value)
		eraseTime = value
	end
	WG['autoeraser'].getRecentlyErased = function(value)	-- so mapmarks fx widget can call this and wont activate on auto erasing
		return recentlyErased
	end
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, arg1, arg2, arg3, arg4) -- cmdType can be 'erase', 'point', or 'line', arg1 is the text or line length(?)
	if cmdType ~= "erase" then
		local f = frame + (eraseTime*30)
		local count = pointsToErase[f] and #pointsToErase[f] or 0
		if count == 0 then
			pointsToErase[f] = {[1] = {px, py, pz, playerID}}
		else
			pointsToErase[f][count+1] = {px, py, pz, playerID}
		end
	end
end

function widget:GameFrame(f)
	frame = f
	if pointsToErase[f] then
		for i = 1, #pointsToErase[f] do
			local point = pointsToErase[f][i]
			Spring.MarkerErasePosition(point[1], point[2], point[3], nil, true, point[4], true)
			recentlyErased[#recentlyErased+1] = {f, point[1], point[2], point[3] }
		end
		pointsToErase[f] = nil
	end
	if f % 30 == 0 then
		local newRecentlyErased = {}
		for i, params in ipairs(recentlyErased) do
			if params[1] + 10 > f then
				newRecentlyErased[#newRecentlyErased+1] = params
			end
		end
		recentlyErased = newRecentlyErased
	end
end


function widget:GetConfigData()
	return {
		eraseTime = eraseTime,
		pointsToErase = pointsToErase,
		version = 1
	}
end

function widget:SetConfigData(data)
	if data.version and data.eraseTime ~= nil then
		eraseTime = data.eraseTime
	end
	if data.pointsToErase ~= nil and Spring.GetGameFrame() > 0 then
		pointsToErase = data.pointsToErase
	end
end

function widget:ClearMapMarks()
	pointsToErase = {}
	recentlyErased = {}
end
