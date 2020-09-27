ShardAI = class(AIBase)

function ShardAI:Init()
	if self.loaded == true then
		self.game:SendToConsole("Init called multiple times")
		return
	end
	self.loaded = true
	self.game = self.api.game
	self.map = self.api.map
	self.game.ai = self
	self.map.ai = self
	self.data = {}
	self.game:SendToConsole(self.fullname.." - playing: "..self.game:GameName().." on: "..self.map:MapName())

	self.api.shard_include("behaviourfactory")
	self.api.shard_include("unit")
	local modules = self.api.shard_include("modules")
	self.modules = {}

	if next(modules) ~= nil then
		for i,m in ipairs(modules) do
			newmodule = m()
			self.game:SendToConsole("adding "..newmodule:Name().." module")
			local internalname = newmodule:internalName()
			self[internalname] = newmodule
			table.insert(self.modules,newmodule)
			newmodule:SetAI(self)
		end
		for i,m in ipairs(self.modules) do
			if m == nil then
				self.game:SendToConsole("nil module!")
			else
				m:Init()
			end
		end

	else
		self.game:SendToConsole("No modules found :(")
	end
end

function ShardAI:Prepare()
	ai = self
	game = self.api.game
	map = self.api.map
	shard_include = self.api.shard_include
	if self.loaded ~= true then
		self:Init()
	end
end

function ShardAI:Update()
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

function ShardAI:GameMessage(text)
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

function ShardAI:UnitCreated(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self.game:SendToConsole("shard found nil engineunit")
		return
	end
	if ( self.modules == nil ) or ( #self.modules == 0 )  then
		self.game:SendToConsole("No modules found in AI")
		return
	end
	for i,m in ipairs(self.modules) do
		m:UnitCreated(engineunit)
	end
end

function ShardAI:UnitBuilt(engineunit)
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

function ShardAI:UnitDead(engineunit)
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

function ShardAI:UnitIdle(engineunit)
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

function ShardAI:UnitDamaged(engineunit,engineattacker,enginedamage)
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

function ShardAI:UnitMoveFailed(engineunit)
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

function ShardAI:GameEnd()
	self.gameend = true
	for i,m in ipairs(self.modules) do
		m:GameEnd()
	end
end

function ShardAI:AddModule( newmodule )
	local internalname = newmodule:internalName()
	self[internalname] = newmodule
	table.insert(self.modules,newmodule)
	newmodule:Init()
end
