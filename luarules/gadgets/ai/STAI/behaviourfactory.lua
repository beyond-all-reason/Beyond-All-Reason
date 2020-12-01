shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

function BehaviourFactory:Init()
	self.behaviours = shard_include( "behaviours" )
	self.scoutslist = {}
end

function BehaviourFactory:AddBehaviours(unit)
	if unit == nil then
		self.game:SendToConsole("Warning: Shard BehaviourFactory:AddBehaviours was asked to provide behaviours to a nil unit")
		return
	end
	if not unit:Internal():IsMine(self.game:GetTeamID()) then
		self.game:SendToConsole('caution BehaviourFactory:AddBehaviours was asked to provide behaviour to not my unit',unit:Internal():Name())
	end
	-- add behaviours here
	-- unit:AddBehaviour(behaviour)
	local b = self.behaviours[unit:Internal():Name()]
	if b == nil then
		b = self:defaultBehaviours(unit)
	end
	for i,behaviour in ipairs(b) do
		t = behaviour()
		t:SetAI(self.ai)
		t:SetUnit(unit)
		t:Init()
		unit:AddBehaviour(t)
	end
end

function BehaviourFactory:defaultBehaviours(unit)
	local b = {}
	local u = unit:Internal()
	local un = u:Name()
	-- game:SendToConsole(un, "getting default behaviours")

	-- keep track of how many of each kind of unit we have
	table.insert(b, CountBST)
	table.insert(b, BootBST)

	if self.ai.armyhst.commanderList[un] then
		table.insert(b, CommanderBST)
	end

	if self.ai.armyhst.nanoTurretList[un] then
		table.insert(b, AssistBST)
		table.insert(b, WardBST)
		table.insert(b, CleanerBST)
	end

	if self.ai.armyhst.unitTable[un].isBuilding then
		table.insert(b, WardBST) --tells defending units to rush to threatened buildings
		if self.ai.armyhst.nukeList[un] then
			table.insert(b, NukeBST)
		elseif self.ai.armyhst.antinukeList[un] then
			table.insert(b, AntinukeBST)
		elseif self.ai.armyhst.bigPlasmaList[un] then
			table.insert(b, BombardBST)
		end
	end


	if u:CanBuild() then
		-- game:SendToConsole(u:Name() .. " can build")
		-- moho engineer doesn't need the queue!
		if self.ai.armyhst.advConList[un] then
			-- game:SendToConsole(u:Name() .. " is advanced construction unit")
			-- half advanced engineers upgrade mexes instead of building things
			if self.ai.advCons == nil then self.ai.advCons = 0 end
			if self.ai.advCons == 0 then
				-- game:SendToConsole(u:Name() .. " taskqueuing")
				table.insert(b, MexUpBST)
				self.ai.advCons = 1
			else
				-- game:SendToConsole(u:Name() .. " mexupgrading")
				self.ai.advCons = 0
			end
			table.insert(b,TaskQueueBST)

		else
			if un == 'armlab' then
				table.insert(b,TaskLabBST)
				table.insert(b, LabRegisterBST)
			else
				table.insert(b,TaskQueueBST)
				if self.ai.armyhst.unitTable[un].isBuilding then
					table.insert(b, LabRegisterBST)
				else
					--table.insert(b, AssistBST)
					table.insert(b, ReclaimBST)
					table.insert(b, CleanerBST)
				end
			end
		end
		table.insert(b, WardBST)
	elseif self.ai.armyhst.reclaimerList[un] then
		table.insert(b, ReclaimBST)
		table.insert(b, WardBST)
	else
		if self.ai.tool:dictHasKey(un,self.ai.armyhst.attackerlist)then
			table.insert(b, AttackerBST)
			-- if self.ai.armyhst.battleList[un] or self.ai.armyhst.breakthroughList[un] then
				-- arty and merl don't make good defense
				table.insert(b, DefendBST)
			-- end
		end
		if self.ai.tool:dictHasKey(un,self.ai.armyhst.raiderList) then
			table.insert(b, RaiderBST)
			table.insert(b, ScoutBST)
			if self.ai.armyhst.unitTable[un].mtype ~= "air" then
				table.insert(b, DefendBST)
			end -- will only defend when scrambled by danger
		end
		if self.ai.tool:dictHasKey(un,self.ai.armyhst.bomberList) then
			table.insert(b, BomberBST)
		end
		if self.ai.tool:dictHasKey(un,self.ai.armyhst.scoutList)then
			table.insert(b, ScoutBST)
			table.insert(b, WardBST)
		end
		if self.ai.armyhst.defenderList[un]  then
			table.insert(b, DefendBST)
		end
	end

	local alreadyHave = {}
	for i = #b, 1, -1 do
		local behaviour = b[i]
		if alreadyHave[behaviour] then
			-- game:SendToConsole(self.ai.id, "duplicate behaviour", u:ID(), u:Name())
			table.remove(b, i)
		else
			alreadyHave[behaviour] = true
		end
	end
	--game:SendToConsole(self.ai.id, #b, "behaviours", u:ID(), u:Name())

	return b
end
