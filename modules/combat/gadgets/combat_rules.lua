local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Combat Rules",
		desc = "Scripted combat exceptions: protected units (untargetable, damage x0) and stuns",
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

local function onAllowWeaponTarget(_, attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if protected[targetID] then
		return false, defPriority
	end
	return true, defPriority
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
		gadget.AllowWeaponTarget = wantHot and onAllowWeaponTarget or nil
		gadgetHandler:UpdateCallIn("UnitPreDamaged")
		gadgetHandler:UpdateCallIn("AllowWeaponTarget")
	end
	if guard.HasStunned() and gadget.GameFrame == nil then
		gadget.GameFrame = onGameFrame
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID)
	guard.UnitDestroyed(unitID)
	syncHooks()
end

function gadget:Initialize()
	GG.Combat = {
		---@param unitID integer
		Protect = function(unitID)
			guard.Protect(unitID)
			syncHooks()
		end,
		---@param unitID integer
		Unprotect = function(unitID)
			guard.Unprotect(unitID)
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
