ShardAI = class(AIBase)

function ShardAI:Name()
	return 'Shard'
end

function ShardAI:internalName()
	return "shard"
end

function ShardAI:Init()
	if self.loaded == true then
		self:Warn( self:Name() .. " Init called multiple times" )
		return
	end

	self.loaded = true
	self.game = self.api.game
	self.map = self.api.map
	self.game.ai = self
	self.map.ai = self
	self.data = {}
	self.game:DrawDisplay(false)
	self:Info(
		self.fullname .. " - playing: " .. self.game:GameName() .. " on: " .. self.map:MapName()
	)

	self.api.shard_include("behaviourfactory")
	self.api.shard_include("unit")
	local modules = self.api.shard_include("modules")
	self.modules = {}

	if next(modules) ~= nil then
		for i,m in ipairs(modules) do
			newmodule = m()
			self:Info( "adding " .. newmodule:Name() .. " module" )
			local internalname = newmodule:internalName()
			if internalname == 'error' then
				self:Warn( "CRITICAL ERROR: The module with the name " .. newmodule:Name() .. " has no internal name! Tis is necesssary and not optional, declare an internalName() function on that module immediatley." )
				self:Warn( "Skipping the loading of " .. newmodule:Name() )
			else
				if self[internalname] ~= nil then
					self:Warn( "CRITICAL ERROR: Shard tried to add a module with the internal name " .. internalname .. " but one already exists!! There cannot be duplicates! Shard will skip this module to avoid overwriting an existing module" )
				else
					self[internalname] = newmodule
					table.insert(self.modules,newmodule)
					newmodule:SetAI(self)
				end
			end
		end
		for i,m in ipairs(self.modules) do
			if m == nil then
				self:Warn("Error! Shard tried to init a nil module!")
			else
				m:Init()
			end
		end

	else
		self:Warn( "Shard found no modules :( Who will control the units now?" )
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
			self:Warn("nil module!")
		else
 			self.game:StartTimer(m:Name() .. ' ai')
			m:Update()
 			self.game:StopTimer(m:Name() .. ' ai')
		end
	end
end

function ShardAI:GameMessage(text)
	if self.gameend == true then
		return
	end
	for i,m in ipairs(self.modules) do
		if m == nil then
			self:Warn("nil module!")
		else
			--self.game:StartTimer(m:Name() .. ' M')
			m:GameMessage(text)
			--self.game:StopTimer(m:Name() .. ' M')
		end
	end
end

function ShardAI:UnitCreated(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self:Warn("shard found nil engineunit")
		return
	end
	if ( self.modules == nil ) or ( #self.modules == 0 )  then
		self:Warn("No modules found in AI")
		return
	end
	for i,m in ipairs(self.modules) do
		--self.game:StartTimer(m:Name() .. ' C')
		m:UnitCreated(engineunit)
		--self.game:StopTimer(m:Name() .. ' C')

	end
end

function ShardAI:UnitBuilt(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self:Warn("shard-warning: unitbuilt engineunit nil ")
		return
	end
	for i,m in ipairs(self.modules) do
		--self.game:StartTimer(m:Name() .. ' B')
		m:UnitBuilt(engineunit)
		--self.game:StopTimer(m:Name() .. ' B')
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
		--self.game:StartTimer(m:Name() .. ' D')
		m:UnitDead(engineunit)
		--self.game:StopTimer(m:Name() .. ' D')
	end
end

function ShardAI:UnitIdle(engineunit)
	if self.gameend == true then
		return
	end
	if engineunit == nil then
		self:Warn("shard-warning: idle engineunit nil")
		return
	end

	for i,m in ipairs(self.modules) do
		--self.game:StartTimer(m:Name() .. ' I')
		m:UnitIdle(engineunit)
		--self.game:StopTimer(m:Name() .. ' I')
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
		--self.game:StartTimer(m:Name() .. ' G')
		m:UnitDamaged(engineunit,engineattacker,enginedamage)
		--self.game:StopTimer(m:Name() .. ' G')
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
		--self.game:StartTimer(m:Name() .. ' F')
		m:UnitMoveFailed(engineunit)
		--self.game:StopTimer(m:Name() .. ' F')
	end
end

function ShardAI:GameEnd()
	self.gameend = true
	for i,m in ipairs(self.modules) do
		m:GameEnd()
	end
end

--- Adds a module after Init
--
-- Adds and initializes a module instance to
-- this instance of the AI.
--
-- Note that this function does not get called
-- by the AIs main Init, so changing this will
-- not change how the modules are loaded at startup
--
-- @param newmodule a module object to initialize and add
function ShardAI:AddModule( newmodule )
	local internalname = newmodule:internalName()
	if self[internalname] ~= nil then
		self:Warn( "CRITICAL ERROR: Shard tried to add a module with the internal name " .. internalname .. " but one already exists!! There cannot be duplicates! Shard will skip this module to avoid overwriting an existing module" )
		return
	end
	self[internalname] = newmodule
	table.insert(self.modules,newmodule)
	newmodule:SetAI(self)
	newmodule:Init()
end
