SchedulerHST = class(Module)

function SchedulerHST:Name()
	return "SchedulerHST"
end

function SchedulerHST:internalName()
	return "schedulerhst"
end

function SchedulerHST:Init()
	self.DebugEnabled = false
 	self.AIs={}
 	local teams = Spring.GetTeamList()
 	for index,id in pairs(teams) do
		local luaAI = Spring.GetTeamLuaAI(id)
		if luaAI == 'STAI' then
			table.insert(self.AIs,id)
		end
 	end
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
	self:EchoDebug(game:Frame(),'team',self.ai.id,'moduleS, Mteam',self.moduleUpdate, self.moduleTeam,'behaviourS, Bteam',self.behaviourUpdate, self.behaviourTeam)
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

	'EcoHST',
-- 	'OverviewHST',
	'LosHST',
	'TargetHST',
	'DamageHST',
	'ScoutHST',
	'AttackHST',
	'RaidHST',
	'BomberHST',
	'LabsHST',
	}

SchedulerHST.BScheduler = {
	'BootBST',
	'CommanderBST',
	'BuildersBST',
	'EngineerBST',
	'LabsBST',
	'ScoutBST',
	'RaidBST',
	'AttackerBST',
	--'BomberBST',
	'ReclaimBST',
	'CleanerBST',
	'AntinukeBST',
	'NukeBST',
		}
