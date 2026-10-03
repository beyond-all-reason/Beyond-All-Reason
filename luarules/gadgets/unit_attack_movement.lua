-- This file is part of Beyond All Reason (GPL v2 or later).
local gadget = gadget ---@type Gadget
local mode = Spring.GetModOptions().attackmovementmode

function gadget:GetInfo()
	return {
		name = "Lua attack movement",
		desc = "Native attack movement decisions expressed in Lua",
		author = "Aron, OpenAI Codex",
		date = "2026-09-08",
		license = "GNU GPL, v2 or later",
		layer = 100000,
		enabled = mode == "lua" or mode == "fallback",
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local getMovementState = Spring.GetUnitAttackMovementState
local getWeaponState = Spring.GetUnitAttackWeaponState
local setMovement = Spring.SetUnitAttackMovement

function gadget:Initialize()
	if not (getMovementState and getWeaponState and setMovement) then
		gadgetHandler:RemoveGadget(self)
	end
end

-- Preserve the native decisions so this port can be compared against the engine.
-- getWeaponState additionally returns rotate/heading failure reasons, including
-- terrain and friendly blockers, for subsequent changes to BAR's movement policy.
function gadget:AttackCommandMovement(unitID)
	if mode == "fallback" then
		return false
	end
	local s = getMovementState(unitID)
	if s.object then
		if s.skipParalyze then
			setMovement(unitID, "finish")
			return true
		end
		local rotate, heading, ownerRotation, edge = false, false, false, 0
		for w = 1, s.numWeapons do
			local eligible, r, h, wantRotation, border = getWeaponState(unitID, w)
			if eligible then
				rotate, heading, edge = r, h, border
				if rotate then
					break
				end
				ownerRotation = ownerRotation or wantRotation
			end
		end
		if rotate then
			if not s.stopToAttack and not s.holdPosition and heading and s.targetBehind and not s.hovering then
				setMovement(unitID, "chase")
			else
				setMovement(unitID, "stop")
				if s.frame > s.lastCloseInTry + s.retryTicks then
					setMovement(unitID, "point")
				end
			end
			setMovement(unitID, "attack")
			return true
		end
		if s.temporary and s.holdPosition then
			setMovement(unitID, "finish")
			return true
		end
		if s.distance < s.range90 then
			if s.hovering or s.distanceSq < 1024 or ownerRotation then
				setMovement(unitID, "stop")
				setMovement(unitID, "point")
				return true
			end
			if s.strafeToAttack then
				setMovement(unitID, "strafe")
			end
			return true
		end
		if s.goalDistanceSq > s.goalThresholdSq then
			setMovement(unitID, "approach", edge)
			if s.lastCloseInTry < s.frame + s.retryTicks then
				if ownerRotation then
					setMovement(unitID, "point")
				end
				setMovement(unitID, "closeInFrame")
			end
		end
		return true
	end

	if s.manual then
		if setMovement(unitID, "attack") then
			setMovement(unitID, "point")
			setMovement(unitID, "stop")
		end
		return true
	end
	for w = 1, s.numWeapons do
		local _, _, heading = getWeaponState(unitID, w)
		if heading then
			if setMovement(unitID, "attack") then
				setMovement(unitID, "stopPoint")
				return true
			end
			setMovement(unitID, "point")
		end
	end
	if s.distanceSq >= s.range90Sq then
		return true
	end
	setMovement(unitID, "attack")
	setMovement(unitID, "stopPoint")
	return true
end
