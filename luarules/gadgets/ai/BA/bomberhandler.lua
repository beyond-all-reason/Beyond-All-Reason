 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("BomberHandler: " .. inStr)
	end
end

BomberHandler = class(Module)

function BomberHandler:Name()
	return "BomberHandler"
end

function BomberHandler:internalName()
	return "bomberhandler"
end

function BomberHandler:Init()
	self.recruits = {}
	self.counter = baseBomberCounter
	ai.hasBombed = 0
	ai.couldBomb = 0
end

function BomberHandler:Update()
	local f = game:Frame()
	if f % 90 == 0 then
		self:DoTargetting()
	end
end

function BomberHandler:GameEnd()
	--
end

function BomberHandler:UnitCreated(engineunit)
	--
end

function BomberHandler:UnitBuilt(engineunit)
	--
end

function BomberHandler:UnitIdle(engineunit)
	--
end

function BomberHandler:DoTargetting()
	for weapon, recruits in pairs(self.recruits) do
		if #recruits >= self.counter then
			ai.couldBomb = ai.couldBomb + 1
			-- find somewhere to attack
			local bombTarget
			EchoDebug("getting target for " .. weapon)
			if weapon == "torpedo" then
				bombTarget = ai.targethandler:GetBestBomberTarget(true)
			else
				bombTarget = ai.targethandler:GetBestBomberTarget()
			end
			if bombTarget ~= nil then
				EchoDebug("got target for " .. weapon)
				for i = 1, #recruits do
					local recruit = recruits[i]
					recruit:BombTarget(bombTarget)
				end
				self.recruits[weapon] = {}
				ai.hasBombed = ai.hasBombed + 1
			end
		end
	end
end

function BomberHandler:IsRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour.weapon] == nil then self.recruits[bmbrbehaviour.weapon] = {} end
	for i,v in ipairs(self.recruits[bmbrbehaviour.weapon]) do
		if v == bmbrbehaviour then
			return true
		end
	end
	return false
end

function BomberHandler:AddRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour.weapon] == nil then self.recruits[bmbrbehaviour.weapon] = {} end
	if not self:IsRecruit(bmbrbehaviour) then
		table.insert(self.recruits[bmbrbehaviour.weapon],bmbrbehaviour)
	end
end

function BomberHandler:RemoveRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour.weapon] == nil then self.recruits[bmbrbehaviour.weapon] = {} end
	for i,v in ipairs(self.recruits[bmbrbehaviour.weapon]) do
		if v == bmbrbehaviour then
			table.remove(self.recruits[bmbrbehaviour.weapon], i)
			return true
		end
	end
	return false
end

function BomberHandler:NeedMore()
	self.counter = self.counter + 1
	self.counter = math.min(self.counter, maxBomberCounter)
	-- EchoDebug("bomber counter: " .. self.counter .. " (bomber died)")
end

function BomberHandler:NeedLess()
	self.counter = self.counter - 1
	self.counter = math.max(self.counter, minBomberCounter)
	EchoDebug("bomber counter: " .. self.counter .. " (AA died)")
end

function BomberHandler:GetCounter()
	return self.counter
end