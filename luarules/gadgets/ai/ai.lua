AI = class(AIBase)

function AI:Init()
	self.EnableDebugTimers = false

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
			if self.EnableDebugTimers then
				self:AddDebugTimers(m)
			end
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
			-- if self.EnableDebugTimers then self.game:StartTimer(m:Name() .. ":Update") end
			m:Update()
			-- if self.EnableDebugTimers then self.game:StopTimer(m:Name() .. ":Update") end
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

function AI:AddDebugTimers(module, name)
	local badKeys = {
			is_a = true,
			__index = true,
			init = true,
			internalName = true,
			Name = true,
	}
	local moduleName = name or module:Name()
	for k, v in pairs(module) do
		if type(v) == 'function' and not badKeys[k] then
			local passthroughStopTimer = function(...)
				self.game:StopTimer(moduleName .. ":" .. k)
				return ...
			end
			local newV = function(...)
				self.game:StartTimer(moduleName .. ":" .. k)
				return passthroughStopTimer(v(...))
			end
			module[k] = newV
		end
	end
	return module
end