

SchedulerHST = class(Module)

function SchedulerHST:Name()
	return "SchedulerHST"
end

function SchedulerHST:internalName()
	return "schedulerhst"
end

function SchedulerHST:Init()
	print(self.ai.id)
	if not Shard.schedulerAI then
		Shard.schedulerAI = self.ai.id

		Shard.moduleTeam = nil
		Shard.moduleUpdate = nil

		Shard.behaviourTeam = nil
		Shard.behaviourUpdate = nil

	end
end

function SchedulerHST:Update()

	if Shard.schedulerAI and self.ai.id ~= Shard.schedulerAI then return end
	local moduleS, Mteam = self:ModuleScheduler()
	local behaviourS, Bteam = self:BehaviourScheduler()
	--print(game:Frame(),'moduleS, Mteam',Shard.moduleUpdate, Shard.moduleTeam,'behaviourS, Bteam',Shard.behaviourUpdate, Shard.behaviourTeam)





end

function SchedulerHST:ModuleScheduler()
	self.moduleIndex = self.moduleIndex or 1
	self.moduleTeam = self.moduleTeam or 0
	self.moduleUpdate = nil
	for idx,module in pairs(self.ModuleScheda2) do
		if self.moduleIndex > #self.ModuleScheda2 then
			self.moduleIndex = 1
		end
		if self.moduleIndex == idx then
			self.moduleUpdate = module
			if self.moduleTeam >= #Shard.AIs then
				self.moduleTeam = 0
				self.moduleIndex = self.moduleIndex + 1
			end
			for n,t in pairs (Shard.AIs) do

				--print('mt',n,t,t.id)
				if t.id == self.moduleTeam then
					Shard.moduleTeam = self.moduleTeam
					Shard.moduleUpdate = self.moduleUpdate
					self.moduleTeam = self.moduleTeam + 1
					--self.moduleTeam = t.id + 1
					--print(game:Frame(),'module',self.moduleIndex,self.moduleUpdate,'T',self.moduleTeam)
					return self.moduleUpdate, self.moduleTeam
				end
			end
		end
	end
end

function SchedulerHST:BehaviourScheduler()
	self.behaviourIndex = self.behaviourIndex or 1
	self.behaviourTeam = self.behaviourTeam or 0
	self.behaviourUpdate = nil
	for idx,behaviour in pairs(self.BScheduler) do
		if self.behaviourIndex > #self.BScheduler then
			self.behaviourIndex = 1
		end
		if self.behaviourIndex == idx then
			self.behaviourUpdate = behaviour
			if self.behaviourTeam >= #Shard.AIs then
				self.behaviourTeam = 0
				self.behaviourIndex = self.behaviourIndex + 1
			end
			for n,t in pairs (Shard.AIs) do
				--print('bt',n,t,t.id,self.behaviourTeam,#Shard.AIs)
				if t.id == self.behaviourTeam then
					Shard.behaviourUpdate = self.behaviourUpdate
					Shard.behaviourTeam = self.behaviourTeam
					self.behaviourTeam = self.behaviourTeam + 1
					--self.behaviourTeam = t.id + 1
					--print(game:Frame(),'behaviour',self.behaviourIndex,self.behaviourUpdate,'T',self.behaviourTeam)
					return self.behaviourUpdate,self.behaviourTeam
				end
			end
		end
	end
end

function SchedulerHST:updater()
	self.behaviourIndex = self.behaviourIndex or 1
	self.behaviourTeam = self.behaviourTeam or 0
	self.behaviourUpdate = nil
	for idx,behaviour in pairs(self.BScheduler) do
		if self.behaviourIndex > #self.BScheduler then
			self.behaviourIndex = 1
		end
		if self.behaviourIndex == idx then
			self.behaviourUpdate = behaviour
			if self.behaviourTeam >= #Shard.AIs then
				self.behaviourTeam = 0
				self.behaviourIndex = self.behaviourIndex + 1
			end
			for n,t in pairs (Shard.AIs) do
				--print('bt',n,t,t.id,self.behaviourTeam,#Shard.AIs)
				if t.id == self.behaviourTeam then
					Shard.behaviourUpdate = self.behaviourUpdate
					Shard.behaviourTeam = self.behaviourTeam
					self.behaviourTeam = self.behaviourTeam + 1
					--print(game:Frame(),'behaviour',self.behaviourIndex,self.behaviourUpdate,'T',self.behaviourTeam)
					return self.behaviourUpdate,self.behaviourTeam
				end
			end
		end
	end
end

SchedulerHST.ModuleScheda2 = {
	'AttackHST',
	'BomberHST',
	'RaidHST',
	'LosHST',
	'TargetHST',
	'DamageHST',
	'OverviewHST',
	'LabBuildHST',
	'DefendHST',
	}

SchedulerHST.BScheduler = {
		'AttackerBST',
		'TaskQueueBST',
		'TaskLabBST',
		'RaidBST',
		'BomberBST',
		'WardBST',
		'MexupBST',
		'ReclaimBST',
		'CleanerBST',
		'DefendBST',
		'LabregisterBST',
		'ScoutBST',
		'AntinukeBST',
		'NukeBST',
		'BombardBST',
		'CommanderBST',
		'BootBST',
		}

--[[
SchedulerHST.ModuleScheda = {
	SleepST = true,
	ArmyHST = false,
	MapHST = false,
	EcoHST = true,

	BuildSiteHST = false,

	TurtleHST = false,

	ScoutHST = false,

	CleanHST = false,
	NanoHST = false,

	UnitHST = true,
	TasksHST = false,
	Tool = false,

}]]
