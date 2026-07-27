local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Combat Rules",
		desc = "Scripted combat exceptions: protected units (neutral to auto-targeting, damage x0) and stuns",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		-- layer 100: handler loops are last-writer-wins; exceptions must outrank tuning gadgets.
		layer = 100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local Guard = VFS.Include("modules/combat/lib/guard.lua")

local guard = Guard.New()
local protected = guard.protected -- flat lookup for the hot callins

-- Protection is neutrality plus a damage floor. Neutrality is what makes
-- attackers advance instead of parking: Weapon::AutoTarget and
-- MobileCAI::AutoGenerateTarget skip neutral units below fire-at-neutral.
-- Restored on release, so a unit that was already neutral stays neutral.
local neutralBefore = {} ---@type table<integer, boolean>

-- AllowWeaponTarget is deliberately NOT used. It fires only for weaponDefIDs
-- some gadget passed to Script.SetWatchAllowTarget — a per-handle flag with no
-- refcount (LuaHandleSynced.cpp SetWatchDef), which unit_defend_firestate
-- clears as its own units die — and gadgetHandler:AllowWeaponTarget is
-- last-writer-wins with no nil filter, so participating at layer 100 would
-- discard every other gadget's priority while anything is protected.

-- Stun rides EMP paralysis, topped up above max health so decay can't end it early; release zeroes it.
local STUN_TOPUP_PERIOD = 15 -- frames
local STUN_PARALYZE_FACTOR = 1.5

--------------------------------------------------------------------------------
-- Hot callins exist only while an exception is active; syncHooks adds/removes
-- this gadget's callins on ledger transitions.
--------------------------------------------------------------------------------

local function onUnitPreDamaged(_, unitID)
	if protected[unitID] then
		return 0, 0
	end
end

local function onGameFrame(_, frame)
	if frame % STUN_TOPUP_PERIOD == 0 then
		for unitID in pairs(guard.stunned) do
			if Spring.ValidUnitID(unitID) then
				local _, maxHealth = Spring.GetUnitHealth(unitID)
				Spring.SetUnitHealth(unitID, { paralyze = maxHealth * STUN_PARALYZE_FACTOR })
			end
		end
	end
	for _, unitID in ipairs(guard.Tick(frame)) do
		if Spring.ValidUnitID(unitID) then
			Spring.SetUnitHealth(unitID, { paralyze = 0 })
		end
	end
	if not guard.HasStunned() then
		gadget.GameFrame = nil
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

local function syncHooks()
	local wantHot = guard.HasProtected()
	if wantHot ~= (gadget.UnitPreDamaged ~= nil) then
		gadget.UnitPreDamaged = wantHot and onUnitPreDamaged or nil
		gadgetHandler:UpdateCallIn("UnitPreDamaged")
	end
	if guard.HasStunned() and gadget.GameFrame == nil then
		gadget.GameFrame = onGameFrame
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID)
	guard.UnitDestroyed(unitID)
	neutralBefore[unitID] = nil
	syncHooks()
end

function gadget:Initialize()
	GG.Combat = {
		---@param unitID integer
		Protect = function(unitID)
			if guard.Protect(unitID) and Spring.ValidUnitID(unitID) then
				neutralBefore[unitID] = Spring.GetUnitNeutral(unitID) == true
				Spring.SetUnitNeutral(unitID, true)
			end
			syncHooks()
		end,
		---@param unitID integer
		Unprotect = function(unitID)
			if guard.Unprotect(unitID) then
				if Spring.ValidUnitID(unitID) then
					Spring.SetUnitNeutral(unitID, neutralBefore[unitID] == true)
				end
				neutralBefore[unitID] = nil
			end
			syncHooks()
		end,
		IsProtected = guard.IsProtected,
		---@param unitID integer
		---@param seconds number
		Stun = function(unitID, seconds)
			if not Spring.ValidUnitID(unitID) then
				return
			end
			guard.Stun(unitID, Spring.GetGameFrame() + math.floor(seconds * Game.gameSpeed))
			local _, maxHealth = Spring.GetUnitHealth(unitID)
			Spring.SetUnitHealth(unitID, { paralyze = maxHealth * STUN_PARALYZE_FACTOR })
			syncHooks()
		end,
	}
end

function gadget:Shutdown()
	GG.Combat = nil
end
