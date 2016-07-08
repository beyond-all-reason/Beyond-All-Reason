class(AIBase)

function AI:Init()
	ai = self
	self.api = shard_include("preload/api")
	self.game = self.api.game
	self.map = self.api.map
	self.game.ai = self
	self.map.ai = self
	self.game.map = self.map
	self.game:SendToConsole("Shard by AF - playing:"..self.game:GameName().." on:"..self.map:MapName())

	ai = self
	game = self.game
	map = self.map

	if not ShardSpringLua then
		shard_include("behaviourfactory")
		shard_include("unit")
		shard_include("module")
		shard_include("modules")
	end

	self.modules = {}
	if next(modules) ~= nil then
		for i,m in ipairs(modules) do
			newmodule = m()
			self.game:SendToConsole("adding "..newmodule:Name().." module")
			local internalname = newmodule:internalName()
			self[internalname] = newmodule
			table.insert(self.modules,newmodule)
			newmodule:SetAI(self)
			newmodule:Init()
		end
	end
end

function AI:Update()
	if self.gameend == true then
		return
	end
	for i,m in ipairs(self.modules) do
		if m == nil then
			self.game:SendToConsole("nil module!")
		else
			m:Update()
		end
	end
end

function AI:GameMessage(text)
	if self.gameend == true then
		return
	end
	for i,m in ipairs(self.modules) do
		if m == nil then
			self.game:SendToConsole("nil module!")
		else
			m:GameMessage(text)
		end
	end
end

function AI:UnitCreated(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self.game:SendToConsole("shard found nil engineunit")
		return
	end
	for i,m in ipairs(self.modules) do
		m:UnitCreated(engineunit)
	end
end

function AI:UnitBuilt(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self.game:SendToConsole("shard-warning: unitbuilt engineunit nil ")
		return
	end
	for i,m in ipairs(self.modules) do
		m:UnitBuilt(engineunit)
	end
end

function AI:UnitDead(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		return
	end
	for i,m in ipairs(self.modules) do
		m:UnitDead(engineunit)
	end
end

function AI:UnitIdle(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self.game:SendToConsole("shard-warning: idle engineunit nil")
		return
	end	
	for i,m in ipairs(self.modules) do
		m:UnitIdle(engineunit)
	end
end

function AI:UnitDamaged(engineunit,engineattacker,enginedamage)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		return
	end
	-- self.game:SendToConsole("UnitDamage for " .. enginedamage:Damage())
	for i,m in ipairs(self.modules) do
		m:UnitDamaged(engineunit,engineattacker,enginedamage)
	end
end

function AI:UnitMoveFailed(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		return
	end
	for i,m in ipairs(self.modules) do
		m:UnitMoveFailed(engineunit)
	end
end

function AI:GameEnd()
	self.gameend = true
	for i,m in ipairs(self.modules) do
		m:GameEnd()
	end
end

function AI:AddModule( newmodule )
	local internalname = newmodule:internalName()
	self[internalname] = newmodule
	table.insert(self.modules,newmodule)
	newmodule:Init()
end
