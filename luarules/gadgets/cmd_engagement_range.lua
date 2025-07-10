local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Unit Engagement Range",
		desc    = "Cycle through a unit's weapon- and engage-ranges with a command",
		version = "1.0",
		author  = "efrec",
		license = "GNU GPL, v2 or later",
		date    = "2025",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() or not (
		Spring.GetModOptions().experimentalextraunits or
		Spring.GetModOptions().experimentallegionfaction
	) then
	return false
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local minSplitDifference = 16 ---@type integer the smallest difference to split ranges

--------------------------------------------------------------------------------
-- Global variables ------------------------------------------------------------

local ARMORTYPE_DEFAULT = Game.armorTypes.default
local ARMORTYPE_VTOL = Game.armorTypes.vtol

local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_ENGAGE_STATE = GameCMD.ENGAGE_STATE

--------------------------------------------------------------------------------
-- Local variables -------------------------------------------------------------

---Units can have their own params but share this base table in their cmdDescs.
---@type CommandDescription
local engageStateCmdDesc = {
	id       = CMD_ENGAGE_STATE,
	type     = CMDTYPE.ICON_MODE,
	name     = "engage_state",
	action   = "engage_state",
	tooltip  = "Cycle between weapon engage ranges",
	cursor   = "cursornormal",
	queueing = false,
}

local ENGAGESTATE_DEFAULT = 0

-- Labels support mixing and matching to create param sets but add complexity.
local labels = {
	default   = "Engage Default",
	close     = "Engage Close Range",
	secondary = "Engage Secondary",
}

for _, label in ipairs({ "default", "close", "secondary" }) do
	labels[labels[label]] = label -- reverse lookup
end

-- This is specifically to offset the CMD_FIGHT leash.
-- Different commands may use a different leash radius.
local moveStateLeashRadius = {
	[CMD.MOVESTATE_NONE]     = 0,
	[CMD.MOVESTATE_HOLDPOS]  = 0,
	[CMD.MOVESTATE_MANEUVER] = 100,
	[CMD.MOVESTATE_ROAM]     = 400,
}

-- Create up to three pseudo-weapons per unit:
-- - The default engagement range weapon.
-- - The close-range engagement weapon.
-- - The secondary-role engagement weapon.
local unitEngageRangeInfo = {}

local function ignoreWeapon(weaponDef)
	local custom = weaponDef.customParams

	return custom.bogus or
		-- These cases are redundant with the `bogus` manual category:
		custom.nofire or -- kicks, stomps, prime/arm/launch effects
		weaponDef.range < 10 or -- self-detonators, fake aim points
		(
			-- non-damaging with no valid secondary effect
			weaponDef.damages[ARMORTYPE_DEFAULT] <= 1 and
			weaponDef.damages[ARMORTYPE_VTOL] <= 1 and
			not weaponDef.name:find("juno_pulse") and -- hardcoded :/ rip
			not (custom.carried_unit and tonumber(custom.maxunits or 1) >= 1)
		) or
		-- This is a true weapon but is not used for automatic ranging:
		weaponDef.commandfire
end

---@return number? [nil] := ignore unit
local function getUnitEngageRange(unitDef)
	if unitDef.customParams.engage_range ~= nil then
		local engageRange = unitDef.customParams.engage_range

		if engageRange == "false" then
			return
		elseif tonumber(engageRange) ~= nil then
			return tonumber(engageRange)
		elseif WeaponDefNames[unitDef.customParams.engage_range] ~= nil then
			return WeaponDefNames[unitDef.customParams.engage_range].range
		end
	end

	return tonumber(unitDef.customParams.maxrange or unitDef.maxWeaponRange or 0)
end

---@return number? [nil] := ignore weapon
local function getWeaponEngageRange(weaponDef)
	if not ignoreWeapon(weaponDef) then
		if weaponDef.customParams.engage_range then
			return tonumber(weaponDef.customParams.engage_range)
		else
			return weaponDef.range
		end
	end
end

local function getArmorDamages(weaponDef)
	local damages = weaponDef.damages
	local damageDefault = damages[ARMORTYPE_DEFAULT] or 0
	local damageAntiAir = damages[ARMORTYPE_VTOL] or 0
	local damageMax = math.max(damageDefault, damageAntiAir, 0)

	local damageRate = damageMax * (weaponDef.burst or 1) * (weaponDef.projectiles or 1) /
		math.max(
			math.max(weaponDef.burstRate, 1 / Game.gameSpeed) * weaponDef.burst,
			weaponDef.reload,
			weaponDef.stockpile and weaponDef.stockpileTime or 0,
			0.0001
		)
	local armorTarget = damageDefault == damageMax and ARMORTYPE_DEFAULT or ARMORTYPE_VTOL

	if damageRate == 0 then
		if weaponDef.customParams.carried_unit ~= nil then
			local unitDef = UnitDefNames[weaponDef.customParams.carried_unit]

			if unitDef ~= nil and #unitDef.weapons >= 1 then
				local count = tonumber(weaponDef.customParams.maxunits or 1) or 1

				for _, weapon in ipairs(unitDef.weapons) do
					local droneWeaponDef = WeaponDefs[weapon.weaponDef]
					if not ignoreWeapon(droneWeaponDef) then
						damageRate, armorTarget = getArmorDamages(WeaponDefs[weapon.weaponDef])
						damageRate = damageRate * count

						if damageRate > 0 then
							break
						end
					end
				end
			end
		end
	end

	return damageRate, armorTarget
end

local function addUnitEngageState(unitDefID, unitDef)
	if unitDef.canAttack and unitDef.canMove then
		---@class EngageRangeInfo
		---@field default number the preset unit maximum range
		---@field close number? the close-range engagement distance
		---@field secondary number? the auxiliary weapon engagement distance
		---@field params string[] the init state and all available states
		local info = {}

		local weapons = {}
		local unitArmorDamage = 0
		local unitArmorTarget = ARMORTYPE_DEFAULT
		local unitEngageRange = getUnitEngageRange(unitDef)

		if unitEngageRange == nil then
			return
		end

		for i = 1, #unitDef.weapons do
			local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
			local engageRange = getWeaponEngageRange(weaponDef)

			if engageRange ~= nil then
				local armorDamage, armorTarget = getArmorDamages(weaponDef)

				if armorDamage > 10 then
					if armorDamage > unitArmorDamage then
						unitArmorDamage = armorDamage
						unitArmorTarget = armorTarget
					end

					weapons[#weapons + 1] = {
						targets = armorTarget,
						range   = engageRange,
					}
				end
			end
		end

		if #weapons > 0 then
			local close, secondary

			for _, weapon in ipairs(weapons) do
				-- We want units to stick close to their designed effective range
				-- but they can have secondary weapons that are long-er or near-er ranged
				-- and their closer-ranged primaries can fall within our minimum diff, too
				-- which means I would have to do a lot more than just this to be correct:
				if weapon.targets ~= unitArmorTarget then
					-- The unit should remain near to its effective range
					-- without over-dedicating to its alternate function:
					if weapon.range <= unitEngageRange - minSplitDifference then
						secondary = math.max(weapon.range, secondary or 0)
					elseif weapon.range >= unitEngageRange + minSplitDifference then
						secondary = math.min(weapon.range, secondary or math.huge)
					end
				elseif weapon.range <= unitEngageRange - minSplitDifference then
					-- This one, at least, is straightforward:
					close = math.min(weapon.range, close or math.huge)
				end
			end

			if close ~= nil and secondary ~= nil and secondary < unitEngageRange then
				if math.abs(close - secondary) < minSplitDifference then
					secondary = nil
				end
			end

			if close ~= nil or secondary ~= nil then
				-- Each def gets its own base params table
				-- so that each def can have default state
				local params = { tostring(ENGAGESTATE_DEFAULT), labels.default }

				info.default = unitEngageRange

				if close then
					params[#params + 1] = labels.close
					info.close = close
				end

				if secondary then
					params[#params + 1] = labels.secondary
					info.secondary = secondary
				end

				info.params = params

				unitEngageRangeInfo[unitDefID] = info
			end
		end
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	addUnitEngageState(unitDefID, unitDef)
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

---@param info EngageRangeInfo
---@param params number[]
---@param state integer
---@return number engageRange
local function getEngageRange(info, params, state)
	local label = params[state + 2] -- +1 for lua index, +1 since `state` is first
	local category = labels[label] -- "default" | "close" | "secondary"
	return info[category]
end

---@return number leashRadius
local function getLeashRadius(unitID)
	local _, moveState = Spring.GetUnitStates(unitID, false)
	return moveStateLeashRadius[moveState]
end

---@param unitID integer
---@param unitDefID integer
---@param commandOptions CommandOptions?
local function changeEngageState(unitID, unitDefID, commandParams, commandOptions)
	local info = unitEngageRangeInfo[unitDefID]
	local index = Spring.FindUnitCmdDesc(unitID, CMD_ENGAGE_STATE)
	local cmdDesc = Spring.GetUnitCmdDescs(unitID, index, index)[1]

	local engageState, engageRange

	if commandOptions ~= nil and commandOptions.alt then
		-- OPT_ALT override restores the default range.
		-- Only really useful for three-state loadouts.
		engageState = ENGAGESTATE_DEFAULT
		engageRange = info.default
	elseif commandParams[1] ~= nil then
		-- Assume that params are correct, e.g. from the gui handler.
		engageState = tonumber(commandParams[1])
		engageRange = getEngageRange(info, cmdDesc.params, engageState) - getLeashRadius(unitID)
	else
		-- Use options instead of params to change the engage state via script
		-- of a unit without having to check the unit def or its descriptions.
		local state = tonumber(cmdDesc.params[1] or ENGAGESTATE_DEFAULT)
		local countStates = #cmdDesc.params - 1

		-- Though, in that case, we can only cycle forward or backward.
		if commandOptions ~= nil and not commandOptions.right then
			engageState = (state + 1) % countStates
		else
			engageState = state >= 1 and state - 1 or countStates
		end

		engageRange = getEngageRange(info, cmdDesc.params, engageState) - getLeashRadius(unitID)
	end

	cmdDesc.params[1] = tostring(engageState)
	Spring.EditUnitCmdDesc(unitID, index, cmdDesc)
	Spring.SetUnitMaxRange(unitID, engageRange)
end

local function updateLeashRadius(unitID, unitDefID)
	local index = Spring.FindUnitCmdDesc(unitID, CMD_ENGAGE_STATE)
	local command = Spring.GetUnitCmdDescs(unitID, index, index)[1]
	local engageState = tonumber(command.params[1] or ENGAGESTATE_DEFAULT)

	if engageState ~= ENGAGESTATE_DEFAULT then
		local range = getEngageRange(unitEngageRangeInfo[unitDefID], command.params, engageState)
		local leash = getLeashRadius(unitID)
		Spring.SetUnitMaxRange(unitID, range - leash)
	end
end

local function addUnitCommand(unitID, unitDefID)
	if Spring.FindUnitCmdDesc(unitID, CMD_ENGAGE_STATE) == nil then
		local desc = engageStateCmdDesc
		desc.params = unitEngageRangeInfo[unitDefID].params
		Spring.InsertUnitCmdDesc(unitID, desc)

		if tonumber(desc.params[1]) ~= ENGAGESTATE_DEFAULT then
			changeEngageState(unitID, unitDefID, desc.params, nil)
		end
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)

		if unitEngageRangeInfo[unitDefID] then
			addUnitCommand(unitID, unitDefID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitEngageRangeInfo[unitDefID] then
		addUnitCommand(unitID, unitDefID)
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if cmdID == CMD_ENGAGE_STATE then
		changeEngageState(unitID, unitDefID, cmdParams, cmdOpts)
	elseif cmdID == CMD_MOVE_STATE and unitEngageRangeInfo[unitDefID] then
		updateLeashRadius(unitID, unitDefID)
	end
end
