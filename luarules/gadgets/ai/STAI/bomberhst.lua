BomberHST = class(Module)

function BomberHST:Name()
	return "BomberHST"
end

function BomberHST:internalName()
	return "bomberhst"
end



function BomberHST:Init()
	self.DebugEnabled = false
    self.ai.bomberhst.plans = {} --TODO why here and why called with bomberhst instead of self(changed from BomberHST to self.ai.bomberhst
	self.recruits = {}
	self.needsTargetting = {}
	self.counter = self.ai.armyhst.baseBomberCounter
	self.ai.hasBombed = 0
	self.ai.couldBomb = 0
	self.pathValidFuncs = {}

end

function BomberHST:Update()
-- 	local f = self.game:Frame()
--     self:EchoDebug(f, f % 30)
-- 	if f % 30 == 0 then self:DoTargetting() end
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	for i = #self.plans, 1, -1 do
		local plan = self.plans[i]
		local pathfinder = plan.pathfinder
		local path, remaining, maxInvalid = pathfinder:Find(1)
		if path then
			-- path = self.ai.tool:SimplifyPath(path)
			if self.DebugEnabled then
				self.map:EraseLine(nil, nil, {1,1,1}, nil, nil, 8)
				for i = 2, #path do
					local pos1 = path[i-1].position
					local pos2 = path[i].position
					local arrow = i == #path
					self.map:DrawLine(pos1, pos2, {1,1,1}, nil, arrow, 8)
				end
			end
			if maxInvalid == 0 or #path < 3 then
				self:Bomb(plan)
			else
				self:Bomb(plan, path)
			end
			table.remove(self.plans, i)
		elseif remaining == 0 then
			for _, bomber in pairs(plan.bombers) do
				self:AddRecruit(bomber)
			end
			table.remove(self.plans, i)
		end
	end
end

function BomberHST:Bomb(plan, path)
	local bombers = plan.bombers
	local target = plan.target
	for i = 1, #bombers do
		local bomber = bombers[i]
		bomber:BombTarget(target, path)
	end
	self.ai.hasBombed = self.ai.hasBombed + 1
end

function BomberHST:DoTargetting()
	for weapon, _ in pairs(self.needsTargetting) do
		local recruits = self.recruits[weapon]
		self.ai.couldBomb = self.ai.couldBomb + 1
		-- find somewhere to attack
		self:EchoDebug("getting target for " .. weapon)
		local torpedo = weapon == 'torpedo'
		local targetUnit = self:GetBestBomberTarget(torpedo)
		if targetUnit ~= nil then
			local tupos = targetUnit:GetPosition()
			if tupos and tupos.x then
				self:EchoDebug("got target for " .. weapon)
				local sumX = 0
				local sumZ = 0
				local validFunc
				for i = 1, #recruits do
					self:EchoDebug('dotarget i' , i)
					local recruit = recruits[i]
					self:EchoDebug('dotarget have recruit' , recruit)
					self:EchoDebug('dotarget unit' , recruit.unit)
					self:EchoDebug('dotarget internal' , recruit.unit:Internal())
					self:EchoDebug('dotarget internalPos we hope there are one' )
					if recruit and recruit.unit and  recruit.unit:Internal() and  recruit.unit:Internal():GetPosition() then
						local pos = recruit.unit:Internal():GetPosition()
						sumX = sumX + pos.x
						sumZ = sumZ + pos.z
						validFunc = validFunc or self:GetPathValidFunc(recruit.unit:Internal():Name())
					else
						self:EchoDebug('warning unit without internal')
					end
				end
				local midPos = api.Position()
				midPos.x = sumX / #recruits
				midPos.z = sumZ / #recruits
				midPos.y = 0
				self.graph = self.graph or self.ai.maphst:GetPathGraph('air', 512)
				local pathfinder = self.graph:PathfinderPosPos(midPos, targetUnit:GetPosition(), nil, validFunc)
				local bombers = {}
				local bombersCount = 0
				for i = 1, #recruits do
					local recruit = recruits[i]
					bombersCount = bombersCount + 1
					bombers[bombersCount] = recruit
				end
				local plan = { target = targetUnit, start = midPos, bombers = bombers, pathfinder = pathfinder }
				self.plans[#self.plans+1] = plan
				self.recruits[weapon] = {}
				self.needsTargetting[weapon] = nil
			end
		end
	end
end

function BomberHST:IsRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour.weapon] == nil then self.recruits[bmbrbehaviour.weapon] = {} end
	for i,v in ipairs(self.recruits[bmbrbehaviour.weapon]) do
		if v == bmbrbehaviour then
			return true
		end
	end
	return false
end

function BomberHST:AddRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour.weapon] == nil then self.recruits[bmbrbehaviour.weapon] = {} end
	if not self:IsRecruit(bmbrbehaviour) then
		table.insert(self.recruits[bmbrbehaviour.weapon],bmbrbehaviour)
		if #self.recruits[bmbrbehaviour.weapon] >= self.counter then
			self.needsTargetting[bmbrbehaviour.weapon] = true
		end
	end
end

function BomberHST:RemoveRecruit(bmbrbehaviour)
	if self.recruits[bmbrbehaviour.weapon] == nil then self.recruits[bmbrbehaviour.weapon] = {} end
	for i,v in ipairs(self.recruits[bmbrbehaviour.weapon]) do
		if v == bmbrbehaviour then
			table.remove(self.recruits[bmbrbehaviour.weapon], i)
			if #self.recruits[bmbrbehaviour.weapon] < self.counter then
				self.needsTargetting[bmbrbehaviour.weapon] = nil
			end
			return true
		end
	end
	return false
end

function BomberHST:NeedMore()
	self.counter = self.counter + 1
	self.counter = math.min(self.counter, self.ai.armyhst.maxBomberCounter)
	-- self:EchoDebug("bomber counter: " .. self.counter .. " (bomber died)")
end

function BomberHST:NeedLess()
	self.counter = self.counter - 1
	self.counter = math.max(self.counter, self.ai.armyhst.minBomberCounter)
	self:EchoDebug("bomber counter: " .. self.counter .. " (AA died)")
end

function BomberHST:GetCounter()
	return self.counter
end

function BomberHST:GetPathValidFunc(unitName)
	if self.pathValidFuncs[unitName] then
		return self.pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return self.ai.targethst:IsSafePosition(node.position, unitName, nil, 1)
	end
	self.pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end

function BomberHST:GetBestBomberTarget(torpedo)
	local bestCell = nil
	local bestValue = 0
	for index,G in pairs(self.ai.targethst.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.x][G.z]
		if torpedo then
			if cell.pos.y < 5 then
				if cell.economy > bestValue then
					bestValue = cell.economy
					bestCell = cell
				end
			end
		else
			if cell.pos.y > -5 then
				if cell.economy > bestValue then
					bestValue = cell.economy
					bestCell = cell
				end
			end
		end
	end
	if bestCell then
		local bu
		local bv = 0
		for id,name in pairs(bestCell.enemyUnits) do
			local ut = self.ai.armyhst.unitTable[name]
			if ut.metalCost > bv then
				bv = ut.metalCost
				bu = id
			end
		end
		if bu then return self.game:GetUnitByID(bu) end
	end


end





