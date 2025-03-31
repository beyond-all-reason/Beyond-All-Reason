--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    camera_shake.lua
--  brief:   Camera shakes
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "CameraShake",
		desc = "Camera shakes",
		author = "trepan",
		date = "Jun 15, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local spSetCameraOffset = Spring.SetCameraOffset
local spSetShockFrontFactors = Spring.SetShockFrontFactors
local math_random = math.random

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local exps = 0
local shake = 0

local powerScale = 80

local decayFactor = 5

local minArea = 32  -- weapon's area of effect
local minPower = (0.02 / powerScale)
local distAdj = 100

local vsx, vsy = Spring.GetViewGeometry()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
end

function widget:Initialize()
	widget:ViewResize()

	-- required for ShockFront() call-ins
	-- (threshold uses the 1/d^2 power)
	spSetShockFrontFactors(minArea, minPower, distAdj)

	WG['camerashake'] = {}
	WG['camerashake'].getStrength = function()
		return powerScale
	end
	WG['camerashake'].setStrength = function(value)
		powerScale = value
		minPower = (0.02 / powerScale)
	end
end

function widget:Shutdown()
	spSetCameraOffset()
end

function widget:ShockFront(power, dx, dy, dz)
	if powerScale <= 0 then
		return
	end
	exps = exps + 1
	if power > 0.0004 then
		power = 0.0004
	end
	power = power * powerScale
	shake = shake + power
end

local function birand(val)
	return val * (1.0 - (0.002 * math_random(1000)))
end

function widget:Update(dt)
	if powerScale <= 0 then
		return
	end
	local t = widgetHandler:GetHourTimer()
	local pShake = shake * 0.1
	local tShake = shake * 0.025
	local px, py, pz, tx, ty, tz = birand(pShake),
	birand(pShake),
	birand(pShake),
	birand(tShake),
	birand(tShake)
	local maxOffsetPx = powerScale / 40000
	if px > maxOffsetPx then
		px = maxOffsetPx
	end
	if px < -maxOffsetPx then
		px = -maxOffsetPx
	end
	if py > maxOffsetPx then
		py = maxOffsetPx
	end
	if py < -maxOffsetPx then
		py = -maxOffsetPx
	end
	if pz > maxOffsetPx then
		pz = maxOffsetPx
	end
	if pz < -maxOffsetPx then
		pz = -maxOffsetPx
	end
	if tx > maxOffsetPx then
		tx = maxOffsetPx
	end
	if tx < -maxOffsetPx then
		tx = -maxOffsetPx
	end
	if ty > maxOffsetPx then
		ty = maxOffsetPx
	end
	if ty < -maxOffsetPx then
		ty = -maxOffsetPx
	end
	spSetCameraOffset(px, py, pz, tx, ty)

	local decay = (1 - (decayFactor * dt))
	if decay < 0 then
		decay = 0
	end
	shake = shake * decay
end

function widget:GetConfigData(data)
	return { powerScale = powerScale }
end

function widget:SetConfigData(data)
	if data.powerScale ~= nil then
		powerScale = data.powerScale
		minPower = (0.02 / powerScale)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
