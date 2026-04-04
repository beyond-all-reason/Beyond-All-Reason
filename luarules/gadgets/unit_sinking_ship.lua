local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Sinking Ship",
		desc = "Makes sinking ships go down faster",
		author = "MaDDoX",
		date = "Sep 2 2020",
		license = "PD",
		layer = 1000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local damping = 0.1

local spGetFeaturePosition = SpringShared.GetFeaturePosition
local spGetGroundHeight = SpringShared.GetGroundHeight
local spGetFeatureVelocity = SpringShared.GetFeatureVelocity
local spGetFeatureRotation = SpringShared.GetFeatureRotation
local spSetFeaturePhysics = SpringSynced.SetFeaturePhysics
local spGetGameFrame = SpringShared.GetGameFrame

function gadget:FeatureCreated(featureID)
	if spGetGameFrame() < 1 then
		return
	end
	local x, y, z = spGetFeaturePosition(featureID)
	if spGetGroundHeight(x, z) < -25 then
		local vx, vy, vz = spGetFeatureVelocity(featureID)
		local rx, ry, rz = spGetFeatureRotation(featureID) --> nil | number pitch, number yaw, number roll
		spSetFeaturePhysics(
			featureID,
			x,
			y,
			z,
			vx * damping,
			0,
			vz * damping, -- setting vanlue for Y doesnt have effect,
			rx,
			ry,
			rz
		) --, 0, 0, 0 ) --number dragx, number dragy, number dragz,
	end
end
