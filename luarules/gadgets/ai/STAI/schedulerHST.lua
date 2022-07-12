

SchedulerHST = class(Module)

function SchedulerHST:Name()
	return "SchedulerHST"
end

function SchedulerHST:internalName()
	return "schedulerhst"
end

function SchedulerHST:Init()

 	self.AIs={}
 	local teams = Spring.GetTeamList()
 	for index,id in pairs(teams) do
		local luaAI = Spring.GetTeamLuaAI(id)
		--print(luaAI)
		if luaAI == 'STAI' then
			table.insert(self.AIs,id)
		end

 	end
	--print(#self.AIs)

	self.moduleTeamIndex = 1
	self.moduleTeam = 0
	self.moduleIndex = 1
	self.moduleUpdate = nil


	self.behaviourTeamIndex = 1
	self.behaviourTeam = 0
	self.behaviourIndex = 1
	self.behaviourUpdate = nil

end

function SchedulerHST:Update()
	local moduleS, Mteam = self:ModulesScheduler()
	local behaviourS, Bteam = self:BehavioursScheduler()
	print(game:Frame(),'team',self.ai.id,'moduleS, Mteam',self.moduleUpdate, self.moduleTeam,'behaviourS, Bteam',self.behaviourUpdate, self.behaviourTeam)





end

function SchedulerHST:ModulesScheduler()


	if self.moduleTeamIndex > #self.AIs then
		self.moduleTeamIndex = 1
		self.moduleIndex = self.moduleIndex + 1
		if self.moduleIndex > #self.MScheduler then
			self.moduleIndex = 1
		end
	end
	self.moduleUpdate = self.MScheduler[self.moduleIndex]
	self.moduleTeam = self.AIs[self.moduleTeamIndex]
	self.moduleTeamIndex = self.moduleTeamIndex + 1
end


function SchedulerHST:BehavioursScheduler()
	if self.behaviourTeamIndex > #self.AIs then
		self.behaviourTeamIndex = 1
		self.behaviourIndex = self.behaviourIndex + 1
		if self.behaviourIndex > #self.BScheduler then
			self.behaviourIndex = 1
		end
	end
	self.behaviourUpdate = self.BScheduler[self.behaviourIndex]
	self.behaviourTeam = self.AIs[self.behaviourTeamIndex]
	self.behaviourTeamIndex = self.behaviourTeamIndex + 1
end




SchedulerHST.MScheduler = {
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
