--- Squad AI: the back half of a wave's life.
---
--- A PORT, and deliberately still inside waves. Squads are BORN from the
--- drain's batch boundaries, their lifetime is measured in waves, and 0 means
--- self-destruct — the anti-stalemate mechanism that clears units stuck in a
--- corner of the map. Cutting a module seam through the middle of that is the
--- riskiest place to put one, and a waves module whose units stand around is
--- not independently shippable.
---
--- The discipline that keeps the eventual lift cheap: this file reads plain
--- squad state plus two injected providers — `behaviourOf` and `targetsOf`,
--- both already WaveSpec hooks — and never reaches into director internals.
--- When a tactics module wants to command non-wave units, this lifts out.

local Squads = {}

local REGROUP_SPREAD = 512
local ORDER_JITTER = 256

---@param spec WaveSpec
---@param state WaveDirectorState
---@return WaveSquad
function Squads.NewPending(spec, state)
	return {
		units = {},
		role = false,
		life = math.ceil((state.params.squadLife or 10) * (state.params.spawnTimeMultiplier or 1)),
		regroupEnabled = true,
		regrouping = false,
		needsRegroup = false,
		needsRefresh = true,
		burrow = nil,
	}
end

---@return table
function Squads.New()
	local mRandom = math.random
	local squads = {}

	---@param units integer[]
	---@return integer
	local function livingCount(units)
		local count = 0
		for _, unitID in ipairs(units) do
			if unitID and Spring.ValidUnitID(unitID) then
				count = count + 1
			end
		end
		return count
	end

	---Somewhere worth attacking. High-value targets get a rising share of the
	---picks as more of them exist, so a base full of fusions pulls waves onto
	---itself; failing everything, a random map position keeps units moving.
	---@param spec WaveSpec
	---@return { x: number, y: number, z: number }, integer|nil target
	squads.RandomTarget = function(spec)
		local targets, highValue = {}, {}
		if spec.hooks.targetsOf then
			targets, highValue = spec.hooks.targetsOf()
		end
		local highValueChance = math.min(0.75, #highValue * 0.15)

		for _ = 1, 10 do
			local pool = (#highValue > 0 and mRandom() <= highValueChance) and highValue or targets
			if #pool > 0 then
				local target = pool[mRandom(1, #pool)]
				if Spring.ValidUnitID(target) and not Spring.GetUnitIsDead(target) and not Spring.GetUnitNeutral(target) then
					local x, y, z = Spring.GetUnitPosition(target)
					if x then
						return { x = x + mRandom(-32, 32), y = y, z = z + mRandom(-32, 32) }, target
					end
				end
			end
		end

		local x = mRandom(16, Game.mapSizeX - 16)
		local z = mRandom(16, Game.mapSizeZ - 16)
		return { x = x, y = Spring.GetGroundHeight(x, z), z = z }, nil
	end

	---Give a squad a fresh target.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param squadID integer
	squads.Refresh = function(spec, state, squadID)
		local squad = state.squads[squadID]
		if squad == nil then
			return
		end
		local pos, target = squads.RandomTarget(spec)
		state.targetPool[squadID] = target
		squad.target = pos
		squad.needsRefresh = true
	end

	---Assemble the pending batch into a squad, recycling an emptied slot
	---where one exists so the squad table does not grow without bound.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param pending WaveSquad
	---@return integer squadID
	squads.Create = function(spec, state, pending)
		local squadID = #state.squads + 1
		for i = 1, #state.squads do
			if livingCount(state.squads[i].units) == 0 then
				squadID = i
				break
			end
		end

		local role = pending.role
		if not role then
			-- Unroled squads lean raiding: most of a wave should be going
			-- around your defences, not into them.
			role = mRandom(0, 100) <= 60 and "raid" or "assault"
		end

		state.squads[squadID] = {
			units = pending.units,
			life = pending.life,
			role = role,
			regroupEnabled = pending.regroupEnabled,
			regrouping = pending.regrouping,
			needsRegroup = pending.needsRegroup,
			needsRefresh = pending.needsRefresh,
			burrow = pending.burrow,
		}
		for _, unitID in ipairs(pending.units) do
			state.unitSquad[unitID] = squadID
		end

		state.pendingSquad = Squads.NewPending(spec, state)
		squads.Refresh(spec, state, squadID)
		return squadID
	end

	---One wave of ageing. A squad at zero that still has units — on a map
	---with burrows left to replace it — destroys itself: that is the
	---anti-stalemate valve, and the only reason a stuck squad ever clears.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	squads.AgeAll = function(spec, state)
		local burrowCount = 0
		for _ in pairs(state.burrows) do
			burrowCount = burrowCount + 1
		end

		for i = 1, #state.squads do
			local squad = state.squads[i]
			squad.life = squad.life - 1
			if squad.life < 3 and squad.regroupEnabled then
				-- Near the end, stop regrouping: a squad down to three lives
				-- should be spending them attacking.
				squad.regroupEnabled = false
			end
			if squad.life == 0 and burrowCount > 2 and livingCount(squad.units) > 0 then
				if squad.burrow and state.boss.spawned == 0 and Spring.GetUnitIsDead(squad.burrow) == false then
					squad.burrow = nil
				end
				for _, unitID in ipairs(squad.units) do
					if unitID and Spring.ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == spec.teamID then
						Spring.DestroyUnit(unitID, true, false)
					end
				end
			end
		end
	end

	---@param spec WaveSpec
	---@param unitID integer
	---@param role string
	---@param target { x: number, y: number, z: number }
	local function orderUnit(spec, unitID, role, target)
		local defID = Spring.GetUnitDefID(unitID)
		local behaviour = spec.hooks.behaviourOf and defID and spec.hooks.behaviourOf(defID) or nil
		local jitter = function()
			return mRandom(-ORDER_JITTER, ORDER_JITTER)
		end

		-- A def that always moves (or always fights) overrides its squad's
		-- role: some units simply cannot be told to hold a line.
		if behaviour and behaviour.order == "move" then
			local pos = squads.RandomTarget(spec)
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, { pos.x + jitter(), pos.y, pos.z + jitter() }, { "shift" })
			return
		end
		if behaviour and behaviour.order == "fight" then
			local pos = squads.RandomTarget(spec)
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { pos.x + jitter(), pos.y, pos.z + jitter() }, { "shift" })
			return
		end

		if role == "assault" or role == "artillery" then
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { target.x + jitter(), target.y, target.z + jitter() }, {})
		elseif role == "raid" or role == "kamikaze" then
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, { target.x + jitter(), target.y, target.z + jitter() }, {})
		elseif role == "aircraft" then
			local pos = squads.RandomTarget(spec)
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { pos.x + jitter(), pos.y, pos.z + jitter() }, {})
		elseif role == "healer" then
			squads.GiveHealerOrders(spec, unitID)
		end
	end

	---A healer's order stack: resurrect, capture, repair, then fight. Each of
	---the first three is a coin, so a group of healers fans out across jobs
	---instead of all doing the same one.
	---@param spec WaveSpec
	---@param unitID integer
	squads.GiveHealerOrders = function(spec, unitID)
		local pos = squads.RandomTarget(spec)
		local function at()
			return { pos.x + mRandom(-ORDER_JITTER, ORDER_JITTER), pos.y, pos.z + mRandom(-ORDER_JITTER, ORDER_JITTER), 20000 }
		end
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
		if mRandom() < 0.75 then
			Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, at(), { "shift" })
		end
		if mRandom() < 0.75 then
			Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, at(), { "shift" })
		end
		if mRandom() < 0.75 then
			Spring.GiveOrderToUnit(unitID, CMD.REPAIR, at(), { "shift" })
		end
		Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, at(), { "shift" })
		Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {
			pos.x + mRandom(-ORDER_JITTER, ORDER_JITTER), pos.y, pos.z + mRandom(-ORDER_JITTER, ORDER_JITTER),
		}, { "shift" })
	end

	---Push orders to a squad, but only when something actually changed —
	---re-issuing every tick would cancel the pathing the units are doing.
	---
	---Regrouping is measured, not guessed: if the squad's bounding box has
	---drifted more than half a kilometre from its centre it is strung out,
	---and the whole squad is told to raid toward its own average position
	---until it is a squad again.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param squadID integer
	squads.GiveOrders = function(spec, state, squadID)
		local squad = state.squads[squadID]
		if squad == nil or squad.target == nil or squad.target.x == nil then
			return
		end
		local target = squad.target
		local targetX, targetY, targetZ = target.x, target.y, target.z
		local role = squad.role

		if squad.regroupEnabled then
			local xmin, xmax, zmin, zmax = 999999, 0, 999999, 0
			local xsum, zsum, count = 0, 0, 0
			for _, unitID in ipairs(squad.units) do
				if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) and not Spring.GetUnitNeutral(unitID) then
					local x, _, z = Spring.GetUnitPosition(unitID)
					if x then
						xmin, xmax = math.min(xmin, x), math.max(xmax, x)
						zmin, zmax = math.min(zmin, z), math.max(zmax, z)
						xsum, zsum, count = xsum + x, zsum + z, count + 1
					end
				end
			end
			if count > 0 then
				local xaverage, zaverage = xsum / count, zsum / count
				local strungOut = xmin < xaverage - REGROUP_SPREAD or xmax > xaverage + REGROUP_SPREAD
					or zmin < zaverage - REGROUP_SPREAD or zmax > zaverage + REGROUP_SPREAD
				if strungOut then
					targetX, targetZ = xaverage, zaverage
					targetY = Spring.GetGroundHeight(targetX, targetZ)
					role = "raid"
				end
				squad.needsRegroup = strungOut
			end
		else
			squad.needsRegroup = false
		end

		local changed = squad.needsRefresh
			or (squad.needsRegroup and not squad.regrouping)
			or (not squad.needsRegroup and squad.regrouping)
		if not changed then
			return
		end

		for _, unitID in ipairs(squad.units) do
			if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) and not Spring.GetUnitNeutral(unitID)
				and not state.cowardCooldown[unitID]
			then
				orderUnit(spec, unitID, role, { x = targetX, y = targetY, z = targetZ })
			end
		end
		squad.needsRefresh = false
		squad.regrouping = squad.needsRegroup
	end

	---Occasionally hand a targetless squad a new target. Rare on purpose:
	---this runs every frame across every squad.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	squads.ManageAll = function(spec, state)
		for i = 1, #state.squads do
			if mRandom(1, 100) == 1 and state.targetPool[i] == nil then
				squads.Refresh(spec, state, i)
			end
		end
	end

	---The per-frame pulse: one squad, rate-limited by three.
	---
	---The divide-by-three is the rate limit AND the selector: only every
	---third frame lands on a whole number, and a fractional index finds no
	---squad. Kept exactly as it was — the cost of orders per frame is what it
	---buys, and "fix" it and every squad gets three times the commands.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param frame integer
	squads.Pulse = function(spec, state, frame)
		local count = #state.squads
		if count == 0 then
			return
		end
		local squadID = ((frame % (count * 3)) + 1) / 3
		local squad = state.squads[squadID]
		if squad and squad.regroupEnabled then
			if squad.target and squad.target.x then
				squads.GiveOrders(spec, state, squadID)
			else
				squads.Refresh(spec, state, squadID)
			end
		end
	end

	---An idle unit is a wasted unit. Anything with an empty command queue
	---gets pointed somewhere — at its squad's target if it has a squad, at
	---something worth hitting if it does not.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param unitID integer
	---@param frame integer
	squads.NudgeIdle = function(spec, state, unitID, frame)
		if state.cowardCooldown[unitID] then
			state.cowardCooldown[unitID] = nil
		end
		local squadID = state.unitSquad[unitID]
		local squad = squadID and state.squads[squadID] or nil
		if squad ~= nil then
			if squad.target and squad.target.x then
				squad.needsRefresh = true
				squads.GiveOrders(spec, state, squadID)
			else
				squads.Refresh(spec, state, squadID)
			end
			return
		end

		local defID = Spring.GetUnitDefID(unitID)
		local behaviour = spec.hooks.behaviourOf and defID and spec.hooks.behaviourOf(defID) or nil
		local pos = squads.RandomTarget(spec)
		local function jitter()
			return mRandom(-ORDER_JITTER, ORDER_JITTER)
		end
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
		if behaviour and behaviour.role == "healer" then
			squads.GiveHealerOrders(spec, unitID)
			return
		end
		if behaviour and behaviour.order == "move" then
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, { pos.x + jitter(), pos.y, pos.z + jitter() }, { "shift" })
		elseif behaviour and behaviour.order == "fight" then
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { pos.x + jitter(), pos.y, pos.z + jitter() }, { "shift" })
		elseif behaviour and behaviour.prefersFight and mRandom() <= 0.5 then
			-- Meta: fight, but keep the unit's own firestate discipline.
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { pos.x + jitter(), pos.y, pos.z + jitter() }, { "shift", "meta" })
		else
			Spring.GiveOrderToUnit(unitID, CMD.MOVE, { pos.x + jitter(), pos.y, pos.z + jitter() }, { "shift" })
		end
	end

	---A unit left the roster: drop it from its squad and from any target it
	---was standing in for.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param unitID integer
	squads.Forget = function(spec, state, unitID)
		local squadID = state.unitSquad[unitID]
		if squadID and state.squads[squadID] then
			local units = state.squads[squadID].units
			for index, id in ipairs(units) do
				if id == unitID then
					table.remove(units, index)
					break
				end
			end
			state.unitSquad[unitID] = nil
		end
		for i, squad in ipairs(state.squads) do
			if squad.burrow == unitID then
				squad.burrow = nil
			end
			if state.targetPool[i] == unitID then
				state.targetPool[i] = nil
				squads.Refresh(spec, state, i)
			end
		end
		state.cowardCooldown[unitID] = nil
		state.teleportCooldown[unitID] = nil
	end

	---A unit was damaged and its squad was nearly out of life: a squad in a
	---fight is not a squad that is stuck, so give it its life back.
	---@param state WaveDirectorState
	---@param unitID integer
	squads.ResetLifetime = function(state, unitID)
		local squadID = state.unitSquad[unitID]
		local squad = squadID and state.squads[squadID] or nil
		if squad and squad.life and squad.life < 2 then
			squad.life = 10
		end
	end

	return squads
end

return Squads
