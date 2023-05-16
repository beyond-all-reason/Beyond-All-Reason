function widget:GetInfo()
	return {
		name      = "Auto mapmark eraser",
		desc      = "Erases points after a period of time.",
		author    = "Floris",
		date      = "24 Sept 2022",
		license   = "",
		layer     = 0,
		enabled   = true,
	}
end

local eraseTime = 100
local frame = -1
local pointsToErase = {}
local recentlyErased = {}
local commandsThisSecond = 0

function widget:Initialize()
	WG['autoeraser'] = {}
	WG['autoeraser'].getEraseTime = function()
		return eraseTime
	end
	WG['autoeraser'].setEraseTime = function(value)
		eraseTime = value
	end
	WG['autoeraser'].getRecentlyErased = function(value)	-- so mapmarks fx widget can call this and wont active on auto erasing
		return recentlyErased
	end
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, arg1, arg2, arg3, arg4) -- cmdType can be 'erase', 'point', or 'line', arg1 is the text or line length(?)
	if cmdType ~= "erase" then
		local count = pointsToErase and #pointsToErase or -1
		if count > 0 then
			pointsToErase[frame + (eraseTime*30)][count + 1] = {px, py, pz, playerID}
		else
			pointsToErase[frame + (eraseTime*30)] = {[1] = {px, py, pz, playerID}}
		end
	end
end

function widget:GameFrame(f)
	frame = f
	if pointsToErase[f] then
		for i = 1, #pointsToErase[f] do
			local point = pointsToErase[f][i]
			if commandsThisSecond < 16 then -- prevent ratelimit
				Spring.MarkerErasePosition(point[1], point[2], point[3], nil, true, point[4])
				recentlyErased[#recentlyErased+1] = {f, point[1], point[2], point[3] }
			else
				if pointsToErase[f + 30] then
					pointsToErase[f + 30][#pointsToErase[f + 30] + 1] = {point[1], point[2], point[3], point[4]}
				else
					pointsToErase[f + 30] = {[1] = {point[1], point[2], point[3], point[4]}}
				end
			end
		end
		pointsToErase[f] = nil
	end
	if f % 30 == 0 then
		commandsThisSecond = 0
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
	}
end

function widget:SetConfigData(data)
	if data.eraseTime ~= nil then
		eraseTime = data.eraseTime
	end
	if data.pointsToErase ~= nil and Spring.GetGameFrame() > 0 then
		pointsToErase = data.pointsToErase
	end
end
