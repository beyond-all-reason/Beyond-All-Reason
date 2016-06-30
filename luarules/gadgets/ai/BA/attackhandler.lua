 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("AttackHandler: " .. inStr)
	end
end

local floor = math.floor
local ceil = math.ceil

AttackHandler = class(Module)

function AttackHandler:Name()
	return "AttackHandler"
end

function AttackHandler:internalName()
	return "attackhandler"
end

function AttackHandler:Init()
	self.recruits = {}
	self.count = {}
	self.squads = {}
	self.counter = {}
	self.attackSent = {}
	self.ai.hasAttacked = 0
	self.ai.couldAttack = 0
	self.ai.IDsWeAreAttacking = {}
end

function AttackHandler:Update()
	local f = game:Frame()
	if f % 150 == 0 then
		self:DraftSquads()
	end
	if f % 60 == 0 then
		self:DoMovement()
	end
	if f % 30 == 0 then
		-- actually retargets each squad every 15 seconds
		self:ReTarget()
	end
end

function AttackHandler:GameEnd()
	--
end

function AttackHandler:UnitCreated(engineunit)
	--
end

function AttackHandler:UnitBuilt(engineunit)
	--
end

function AttackHandler:UnitIdle(engineunit)
	--
end

function AttackHandler:DraftSquads()
	-- if self.ai.incomingThreat > 0 then game:SendToConsole(self.ai.incomingThreat .. " " .. (self.ai.battleCount + self.ai.breakthroughCount) * 75) end
	if self.ai.incomingThreat > (self.ai.battleCount + self.ai.breakthroughCount) * 75 then
		EchoDebug("not a good time to attack")
		return
	end -- do not attack if we're in trouble
	local needtarget = {}
	local f = game:Frame()
	-- find which mtypes need targets
	for mtype, count in pairs(self.count) do
		if f > self.attackSent[mtype] + 1800 and count >= self.counter[mtype] then
			table.insert(needtarget, mtype)
		end
	end
	for nothing, mtype in pairs(needtarget) do
		-- prepare a squad
		local squad = { members = {}, notarget = 0, congregating = false, mtype = mtype, lastReTarget = f }
		local representative
		for _, attkbehaviour in pairs(self.recruits[mtype]) do
			if attkbehaviour ~= nil then
				if attkbehaviour.unit ~= nil then
					if representative == nil then representative = attkbehaviour.unit:Internal() end
					table.insert(squad.members, attkbehaviour)
				end
			end
		end
		if representative ~= nil then
			self.ai.couldAttack = self.ai.couldAttack + 1
			-- don't actually draft the squad unless there's something to attack
			local bestCell = self.ai.targethandler:GetBestAttackCell(representative)
			if bestCell ~= nil then
				squad.target = bestCell.pos
				self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
				squad.buildingIDs = bestCell.buildingIDs
				self.attackSent[mtype] = f
				table.insert(self.squads, squad)
				-- clear recruits
				self.count[mtype] = 0
				self.recruits[mtype] = {}
				self.ai.hasAttacked = self.ai.hasAttacked + 1
				self.counter[mtype] = math.min(maxAttackCounter, self.counter[mtype] + 1)
			end
		end
	end
end

function AttackHandler:ReTarget()
	local f = game:Frame()
	for is = #self.squads, 1, -1 do
		local squad = self.squads[is]
		if f > squad.lastReTarget + 300 then
			if squad.idle or squad.reachedTarget then
				if squad.idle or f > squad.reachedTarget + 900 then
					local representative
					for iu, member in pairs(squad.members) do
						if member ~= nil then
							if member.unit ~= nil then
								representative = member.unit:Internal()
								if representative ~= nil then
									break
								end
							end
						end
					end
					if squad.buildingIDs ~= nil then
						self:IDsWeAreNotAttacking(squad.buildingIDs)
					end
					if representative == nil then
						self.attackSent[squad.mtype] = 0
						table.remove(self.squads, is)
					else
						-- find a target
						local bestCell = self.ai.targethandler:GetBestAttackCell(representative)
						if bestCell == nil then
							-- squad.notarget = squad.notarget + 1
							-- if squad.target == nil or squad.notarget > 3 then
								-- if no target found initially, or no target for the last three targetting checks, disassemble and recruit the squad
								for iu, member in pairs(squad.members) do
									self:AddRecruit(member)
								end
								self.attackSent[squad.mtype] = 0
								table.remove(self.squads, is)
							-- end
						else
							squad.target = bestCell.pos
							self:IDsWeAreAttacking(bestCell.buildingIDs, squad.mtype)
							squad.buildingIDs = bestCell.buildingIDs
							squad.notarget = 0
							squad.reachedTarget = nil
						end
					end
				end
			end
			squad.lastReTarget = f
		end
	end
end

function AttackHandler:DoMovement()
	local f = game:Frame()
	for is = #self.squads, 1, -1 do
		local squad = self.squads[is]
		-- get a representative and midpoint
		local representative
		local totalx = 0
		local totalz = 0
		local totalSize = 0
		if squad.hasCongregated then
			for iu = #squad.members, 1, -1 do
				local member = squad.members[iu]
				local unit
				if member ~= nil then
					if member.unit ~= nil then
						unit = member.unit:Internal()
					end
				end
				if unit ~= nil then
					if representative == nil then representative = unit end
					local tmpPos = unit:GetPosition()
					totalx = totalx + tmpPos.x
					totalz = totalz + tmpPos.z
					totalSize = totalSize + member.size
				else 
					table.remove(squad.members, iu)
				end
			end
		end

		if #squad.members == 0 then
			self.attackSent[squad.mtype] = 0
			table.remove(self.squads, is)
		else
			-- determine distances from midpoint
			local midPos
			if squad.hasCongregated then
				midPos = api.Position()
				midPos.x = totalx / #squad.members
	 			midPos.z = totalz / #squad.members
				midPos.y = 0
			else
				local representativeBehaviour = squad.members[#squad.members]
				representative = representativeBehaviour.unit:Internal()
				midPos = self.ai.frontPosition[representativeBehaviour.hits] or representative:GetPosition()
			end
			local congDist = sqrt(pi * totalSize) * 2
			local stragglers = 0
			local damaged = 0
			local idle = 0
			local maxRange = 0
			for iu = #squad.members, 1, -1 do
				local member = squad.members[iu]
				if member.damaged then damaged = damaged + 1 end
				if member.idle then idle = idle + 1 end
				if member.range > maxRange then maxRange = member.range end
				local unit = member.unit:Internal()
				if unit then
					local upos = unit:GetPosition()
					local cdist = Distance(upos, midPos)
					if cdist > congDist then
						if member.straggler == nil then
							member.straggler = 1
						else
							member.straggler = member.straggler + 1
						end
						if member.straggler > 20 then
							-- remove from squad if the unit is taking longer than 40 seconds
							EchoDebug("leaving slowpoke behind")
							self:AddRecruit(member)
							table.remove(squad.members, iu)
						else
							stragglers = stragglers + 1
						end
						if member.lastpos ~= nil and member.straggler ~= nil and member.straggler ~= 0 then
							if math.abs(upos.x - member.lastpos.x) < 3 and math.abs(upos.z - member.lastpos.z) < 3 then
								if member.stuck == nil then
									member.stuck = 1
								else
									member.stuck = member.stuck + 1
								end
								if member.stuck > 5 then
									-- remove from squad if the unit is pathfinder-stuck
									EchoDebug("leaving stuck behind")
									self:AddRecruit(member)
									table.remove(squad.members, iu)
								end
							else
								member.stuck = 0
							end
						end
					else
						member.straggler = 0
					end
					if member.lastpos == nil then
						member.lastpos = api.Position()
						member.lastpos.y = 0
					end
					member.lastpos.x = upos.x
					member.lastpos.z = upos.z
				end
			end
			local congregate = false
			EchoDebug("attack squad of " .. #squad.members .. " members, " .. stragglers .. " stragglers")
			local tenth = math.ceil(#squad.members * 0.1)
			local half = math.ceil(#squad.members * 0.5)
			if stragglers >= tenth and damaged < tenth then -- don't congregate if we're being shot
				congregate = true
			end
			local twiceMaxRange = maxRange * 2
			local distToTarget = Distance(midPos, squad.target)
			local reached = distToTarget < twiceMaxRange
			if reached then
				squad.reachedTarget = f
			else
				squad.reachedTarget = nil
			end
			squad.idle = idle > half
			local realClose = false
			if stragglers < half and squad.reachedTarget then
				congregate = false
				realClose = true
			end
			if not realClose and damaged > tenth then
				realClose = true
			end
			-- attack or congregate
			if congregate then
				if not squad.congregating then
					-- congregate squad
					squad.congregating = true
					for iu, member in pairs(squad.members) do
						local ordered = member:Congregate(midPos)
						if not ordered and squad.congregating then squad.congregating = false end
					end
					squad.hasCongregated = true
				end
				squad.attacking = nil
				squad.close = nil
			else
				if squad.attacking ~= squad.target or squad.close ~= realClose then
					-- squad attacks if that wasn't the last order
					if squad.target ~= nil then
						for iu, member in pairs(squad.members) do
							member:Attack(squad.target, realClose)
						end
						squad.attacking = squad.target
						squad.close = realClose
					end
				end
				squad.congregating = false
			end
		end
	end
end

function AttackHandler:IDsWeAreAttacking(unitIDs, mtype)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = mtype
	end
end

function AttackHandler:IDsWeAreNotAttacking(unitIDs)
	for i, unitID in pairs(unitIDs) do
		self.ai.IDsWeAreAttacking[unitID] = nil
	end
end

function AttackHandler:TargetDied(mtype)
	EchoDebug("target died")
	self:NeedLess(mtype, 0.75)
end

function AttackHandler:IsMember(attkbehaviour)
	if attkbehaviour == nil then return false end
	for is, squad in pairs(self.squads) do
		for iu, member in pairs(squad.members) do
			if member == attkbehaviour then return true end
		end
	end
	return false
end

function AttackHandler:RemoveMember(attkbehaviour)
	if attkbehaviour == nil then return false end
	local found = false
	for is = #self.squads, 1, -1 do
		local squad = self.squads[is]
		for iu = #squad.members, 1, -1 do
			local member = squad.members[iu]
			if member == attkbehaviour then
				table.remove(squad.members, iu)
				found = true
				break
			end
		end
		if found then
			if #squad.members == 0 then
				self.attackSent[squad.mtype] = 0
				table.remove(self.squads, is)
			end
			break
		end
	end
	if found then return true end
	return false
end

function AttackHandler:IsRecruit(attkbehaviour)
	if attkbehaviour.unit == nil then return false end
	local mtype = self.ai.maphandler:MobilityOfUnit(attkbehaviour.unit:Internal())
	if self.recruits[mtype] ~= nil then
		for i,v in pairs(self.recruits[mtype]) do
			if v == attkbehaviour then
				return true
			end
		end
	end
	return false
end

function AttackHandler:AddRecruit(attkbehaviour)
	if not self:IsRecruit(attkbehaviour) then
		if attkbehaviour.unit ~= nil then
			-- EchoDebug("adding attack recruit")
			local mtype = self.ai.maphandler:MobilityOfUnit(attkbehaviour.unit:Internal())
			if self.recruits[mtype] == nil then self.recruits[mtype] = {} end
			if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
			if self.attackSent[mtype] == nil then self.attackSent[mtype] = 0 end
			if self.count[mtype] == nil then self.count[mtype] = 0 end
			local level = attkbehaviour.level
			self.count[mtype] = self.count[mtype] + level
			table.insert(self.recruits[mtype], attkbehaviour)
			attkbehaviour:SetMoveState()
			attkbehaviour:Free()
		else
			EchoDebug("unit is nil!")
		end
	end
end

function AttackHandler:RemoveRecruit(attkbehaviour)
	for mtype, recruits in pairs(self.recruits) do
		for i,v in ipairs(recruits) do
			if v == attkbehaviour then
				local level = attkbehaviour.level
				self.count[mtype] = self.count[mtype] - level
				table.remove(self.recruits[mtype], i)
				return true
			end
		end
	end
	return false
end

function AttackHandler:NeedMore(attkbehaviour)
	local mtype = attkbehaviour.mtype
	local level = attkbehaviour.level
	self.counter[mtype] = math.min(maxAttackCounter, self.counter[mtype] + (level * 0.7) ) -- 0.75
	EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
end

function AttackHandler:NeedLess(mtype, subtract)
	if subtract == nil then subtract = 0.1 end
	if mtype == nil then
		for mtype, count in pairs(self.counter) do
			if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
			self.counter[mtype] = math.max(self.counter[mtype] - subtract, minAttackCounter)
			EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
		end
	else
		if self.counter[mtype] == nil then self.counter[mtype] = baseAttackCounter end
		self.counter[mtype] = math.max(self.counter[mtype] - subtract, minAttackCounter)
		EchoDebug(mtype .. " attack counter: " .. self.counter[mtype])
	end
end

function AttackHandler:GetCounter(mtype)
	if mtype == nil then
		local highestCounter = 0
		for mtype, counter in pairs(self.counter) do
			if counter > highestCounter then highestCounter = counter end
		end
		return highestCounter
	end
	if self.counter[mtype] == nil then
		return baseAttackCounter
	else
		return self.counter[mtype]
	end
end