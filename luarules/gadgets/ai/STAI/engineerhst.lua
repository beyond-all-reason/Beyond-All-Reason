EngineerHST = class(Module)

function EngineerHST:Name()
	return "EngineerHST"
end

function EngineerHST:internalName()
	return "engineerhst"
end

function EngineerHST:Init()
	self.DebugEnabled = false
	self.Engineers = {}
	self.Builders = {}
	self.maxEngineersPerBuilder = 1
	self.eco = 3
	self.expand = 2
	self.support = 1
	self.default = 1
	self.starter = 0
	self.metalMaker = 2
	self.nano = 0
	self.engineersNeeded = 0

end




function EngineerHST:EngineersNeeded()
	self.maxEngineersPerBuilder = math.ceil(self.ai.ecohst.Energy.income / 3000)
	local engineersNeeded = 0

	self:EchoDebug('EngineersNeeded',self.maxEngineersPerBuilder)
	for builderID, engineers in pairs(self.Builders) do
		local count = 0
		self:EchoDebug('engineers builders',builderID, engineers)
		for enginerID,_ in pairs(engineers) do
			count = count + 1

		end
		self:EchoDebug('builder',builderID,'have',count,'engineers')
		local builderRole = self.ai.buildingshst.roles[builderID]
		local add = false
		if builderRole then

			for engineerName,builderName in pairs(self.ai.armyhst.engineers) do
				if builderRole.builderName == builderName then
					add = true
					break
				end
			end
			self:EchoDebug(builderRole.role)
			if add then
				local needed = (self[builderRole.role] * self.maxEngineersPerBuilder) - count
				engineersNeeded = engineersNeeded + needed
			end
		end
	end
	self:EchoDebug('---------------------------------------------------------------------------------------------------engineersNeeded',engineersNeeded,self.maxEngineersPerBuilder)
	return engineersNeeded
end
