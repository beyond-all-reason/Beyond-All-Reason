OverviewHST = class(Module)

function OverviewHST:Name()
	return "OverviewHST"
end

function OverviewHST:internalName()
	return "overviewhst"
end

function OverviewHST:Init()
	self.DebugEnabled = false
	self.maxFactoryLevel = 0
	self:EvaluateSituation()
end

function OverviewHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:EvaluateSituation()
end

function OverviewHST:LabsLevels()
	self.maxFactoryLevel = 0
	for id,lab in pairs(self.ai.labshst.labs) do
		if lab.level > self.maxFactoryLevel then
			self.maxFactoryLevel = lab.level
		end
		if lab.level == 1 then
			self.T1LAB = true
		elseif lab.level == 3 then
			self.T2LAB = true
		elseif lab.level == 5 then
			self.T3LAB = true
		end
	end
end

function OverviewHST:EvaluateSituation()
	local M = self.ai.Metal
	local E = self.ai.Energy
	local m = 10
	local e = 100
	self:LabsLevels()
	self.ECONOMY = math.floor(math.min(M.income / m,E.income / e))


-- 	self.GEO1
-- 	self.GEO2
 	self.POWERPLANT = self.ai.tool:countMyUnit({'_fus_'})
	self.X100M = self.ai.tool:countMyUnit({'extractsMetal'}) / #self.ai.maphst.METALS
	self.needT2 = ((M.income > 20 or self.X100M > 0.2) and E.income > 800 and self.T1LAB)
	self.needT3 = ((M.income > 50 or self.X100M > 0.4) and E.income > 4000 and self.T2LAB)
	self:EchoDebug('ECO',self.ECONOMY , ' M',math.floor(M.income / m), 'E',math.floor(E.income / e),'X100M',self.X100M)
end
