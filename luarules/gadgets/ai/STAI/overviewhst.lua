OverviewHST = class(Module)

function OverviewHST:Name()
	return "OverviewHST"
end

function OverviewHST:internalName()
	return "overviewhst"
end

function OverviewHST:Init()
	self.DebugEnabled = false
	self.ai.maxFactoryLevel = 0
	self:EvaluateSituation()
end

function OverviewHST:Update()
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self:EvaluateSituation()
end

function OverviewHST:EvaluateSituation()
	local M = self.ai.Metal
	local E = self.ai.Energy
	local m = 10
	local e = 80
 	self.T1LAB = self.ai.factoriesAtLevel[1] and #self.ai.factoriesAtLevel[1] ~= 0
 	self.T2LAB = self.ai.factoriesAtLevel[3] and #self.ai.factoriesAtLevel[3] ~= 0
 	self.T3LAB = self.ai.factoriesAtLevel[5] and #self.ai.factoriesAtLevel[5] ~= 0
	self.ECONOMY = math.floor(math.min(M.income / m,E.income / e))
	print('ECONOMY STAGE',self.ECONOMY ,math.floor(M.income / m), math.floor(E.income / e))

-- 	self.GEO1
-- 	self.GEO2
 	self.POWERPLANT = self.ai.tool:countMyUnit({'_fus_'})
	self.X100M = self.ai.tool:countMyUnit({'extractsMetal'}) / #self.ai.maphst.METALS
	self.needT2 = ((M.income > 20 or self.X100M > 0.2) and E.income > 800 and self.T1LAB)
	self.needT3 = ((M.income > 50 or self.X100M > 0.4) and E.income > 4000 and self.T2LAB)
end
