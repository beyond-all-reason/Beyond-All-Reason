EngineerBST = class(Behaviour)

function EngineerBST:Name()
	return "EngineerBST"
end

function EngineerBST:Init()
	self.DebugEnabled = false
	self.active = true
	self.position = self.unit:Internal():GetPosition()
	self.name = self.unit:Internal():Name()
	self.id = self.unit:Internal():ID()
	self.mtype = self.ai.armyhst.unitTable[self.name].mtype
	self.builder = nil


end

function EngineerBST:Priority()
	return 1000
end

function EngineerBST:Update()
	local f = self.game:Frame()


	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'EngineerBST' then return end

	if not self:checkBuilder() then
		self:EchoDebug('not check builder')



		local myBuilder = self:GetBuilder()
		self:EchoDebug('myBuilder',myBuilder)
		if myBuilder  and self.ai.engineerhst.Builders[myBuilder] then
			--self.unit:Internal():Guard(myBuilder)
			self.ai.tool:GiveOrder(self.id,CMD.GUARD,myBuilder,0,'1-1')
			self:EchoDebug('guarding')
			self.ai.engineerhst.Engineers[self.id] = myBuilder
			self.builder = myBuilder
			self:EchoDebug('engineers 42 ',self.ai.engineerhst.Builders,self.ai.engineerhst.Builders[myBuilder])
			self.ai.engineerhst.Builders[myBuilder][self.id] = true
		end
	end
end


function EngineerBST:NumberCheck(id)
	local count = 0
	for _,builderID in pairs(self.ai.engineerhst.Engineers) do

		if builderID == id then
			count = count + 1
			if count >= self.ai.engineerhst.maxEngineersPerBuilder * self.ai.engineerhst[self.ai.buildingshst.roles[builderID].role] then
				self:EchoDebug('numbercheck count', builderID,'have enough engineer',count)
				return false
			end
		end
	end
	self:EchoDebug('numbercheck countid' ,id ,'fail all builders have enough engineers')
	return true


end

function EngineerBST:GetBuilder()
	for id,role in pairs(self.ai.buildingshst.roles) do
		if self.ai.armyhst.engineers[self.name] == role.builderName then
			if self:NumberCheck(id) then
				return id
			end
		end
	end
end

function EngineerBST:checkBuilder()
	if not self.builder then
		return false
	end

	local builder = game:GetUnitByID(self.builder)
	self:EchoDebug('self.builder',self.builder)
	if not builder:GetRawPos() then
		self.ai.engineerhst.Engineers[self.id] = nil
		if self.ai.engineerhst.Builders[self.builder] and self.ai.engineerhst.Builders[self.builder][self.id]then
			self.ai.engineerhst.Builders[self.builder] = nil
		end
		self.builder = nil
		return false
	end

	local currentOrder = self.unit:Internal():GetUnitCommands(1)[1]
	self:EchoDebug(self.name,'currentOrder',currentOrder,self.builder)
	if not currentOrder or not  currentOrder.id  then
		self.ai.engineerhst.Engineers[self.id] = nil
		if self.ai.engineerhst.Builders[self.builder] and self.ai.engineerhst.Builders[self.builder][self.id]then
			self.ai.engineerhst.Builders[self.builder][self.id] = nil
		end
		self.builder = nil
		return false
	end



	return true
end



function EngineerBST:OwnerDead()

	self.active = nil
	self.builder = nil
	self.ai.engineerhst.Engineers[self.id] = nil
	if self.builder then

		self.ai.engineerhst.Builders[self.builder][self.id] = nil
	end
end
