RaidHST = class(Module)

function RaidHST:Name()
	return "RaidHST"
end

function RaidHST:internalName()
	return "raidhst"
end

local minRaidCount = 5
function RaidHST:Init()
	self.DebugEnabled = false
	self.raiders = {}
	self.squads = {}
	self.pathValidFuncs = {}
	self.wave = 7
end

function RaidHST:Update()
	local f = self.game:Frame()
	if f % 97 ~=0 then return end
	self.wave = 5 + math.min(math.ceil(self.ai.Energy.income/1000),20)
	self:EchoDebug('start update')
	self:doSquads()
	for squadID,squad in pairs(self.squads) do
		self:EchoDebug('update squad',squadID)
		self:getSquadPosition(squad)
		local run = self:running(squad)
		self:EchoDebug('RUN',run)
		self:visualDBG(squad)
		if run then

			if self:squadOnTarget(squad) then
				self:doAttack(squad)
				self:EchoDebug('squad on target')
				self:targeting(squad)
			else
				self:EchoDebug('next node')
				self:goToNextNode(squad)
			end
		else
			if run == false then
				self:targeting(squad)
			else
				self:EchoDebug('nil run',run)
				self:resetSquad(squad)
			end
		end
	end
	self:EchoDebug('stop update')
end

function RaidHST:visualDBG(squad)
	if not self.DebugEnabled then return end
	self.map:EraseAll(6)
	self.map:DrawPoint(squad.position, squad.colour, squad.squadID, 6)
	for i , p in pairs(squad.path) do
		self.map:DrawPoint(p, squad.colour, i, 6)
	end
	if squad.target then
		self.map:DrawPoint(squad.target.pos, squad.colour, squad.squadID .. 'target', 6)
	end
end

function RaidHST:running(squad)
	if #squad.members > 0 and squad.path and squad.target then
		squad.lock = true
		return true
	elseif #squad.members >= minRaidCount then
		squad.lock = false
		return false
	else
		squad.lock = false
		self:resetSquad(squad)
		return nil
	end
end

function RaidHST:doSquads()
	self:EchoDebug('doSquads')
	for id,raider in pairs(self.raiders) do
		local squadID = raider.squadID
		if not self.squads[squadID] then
			self:EchoDebug('new squad')
			local u = self.game:GetUnitByID(id)
			self.squads[squadID] = {}
			self.squads[squadID].members = {}
			self.squads[squadID].squadID = squadID
			self.squads[squadID].unitName = raider.name
			self.squads[squadID].mclass = raider.mclass
			self.squads[squadID].mtype = raider.mtype
			self.squads[squadID].lock = false
			self.squads[squadID].onTarget = false
			self.squads[squadID].target = nil
			self.squads[squadID].path = nil
			self.squads[squadID].graph = self.ai.maphst:GetPathGraph(raider.mtype)
			self.squads[squadID].validFunc = self:GetPathValidFunc(raider.name)
			self.squads[squadID].modifierFunc =  self.ai.targethst:GetPathModifierFunc(raider.name)
			self.squads[squadID].colour = {math.random(),math.random(),math.random(),1}
		end
		if not self.squads[squadID].lock and not raider.inSquad then
			self:EchoDebug(id,'added to ',squadID)
			table.insert(self.squads[squadID].members,id)
			raider.inSquad = squadID
		end
	end
end

function RaidHST:targeting(squad)
	if squad.target and squad.path then
		self:EchoDebug('have already a target')
		return
	end
	local target = self:getRaidCell(squad)

-- 	for index,leaderID in pairs(squad.members) do
-- -- 	local leaderID = squad.members[1]
-- 		local leader = self.game:GetUnitByID(leaderID)
-- 		local leaderPos = leader:GetPosition()
-- 		target = self.ai.targethst:GetBestRaidCell(leader)
-- 		if target then break end
-- 	end

	if not target then
		self:EchoDebug('no target for ' ,squad.squadID)
		return
	end
	squad.pathfinder = squad.graph:PathfinderPosPos(squad.position, target.pos, nil, squad.validFunc, nil, squad.modifierFunc)
	if squad.pathfinder then
		self:EchoDebug('pathfinder',type(squad.pathfinder))
		self:FindPath(squad)
		if squad.path  then
			self:EchoDebug('path catch')
			squad.target = target
			table.insert(squad.path,#squad.path+1,squad.target.pos)
			self:EchoDebug('squad.target',squad.target.x,squad.target.z)
		end
	end
	if squad.target and squad.path then return true end --tell me im ready to raids
end

function RaidHST:FindPath(squad)
	if not squad.pathfinder then
		self:EchoDebug('no pathfinder??')
		return
	end
	local path, remaining, maxInvalid = squad.pathfinder:Find(10)
	self:EchoDebug(tostring(remaining) .. " remaining to find path",path,maxInvalid)
	if path then
		local pt = {}
		self:EchoDebug("got path of", #path, "nodes", maxInvalid, "maximum invalid neighbors!!!!!!!!!!!!!!!!!!")
 		for index,cell in pairs(path) do
			table.insert(pt,cell.position)
 			self:EchoDebug('path','index',index,'pos',cell.x,cell.z)
 		end
		squad.path = pt

		if maxInvalid == 0 then
			self:EchoDebug("path is entirely clear of danger, not using")
		end
		squad.pathfinder = nil
	elseif remaining == 0 then
		self:EchoDebug("no path found")
		squad.pathfinder = nil
	else
		self:EchoDebug('no path found in findPATH()')
	end
end

function RaidHST:getSquadPosition(squad)
	local members = squad.members
	self:EchoDebug(#members,'in squad',squad.squadID,'search pos')
	local squadPos = {x=0,y=0,z=0}
	for index,id in pairs(members) do
		local unit = self.game:GetUnitByID(id)
		if unit:IsAlive() then
			local unitPos = unit:GetPosition()
			squadPos.x = squadPos.x + unitPos.x
			squadPos.z = squadPos.z + unitPos.z
		else
			table.remove(self.raiders,self.id)
			table.remove(squad.members,index)
		end
	end
	squadPos.x = squadPos.x / # members
	squadPos.z = squadPos.z / # members
	squadPos.y = Spring.GetGroundHeight(squadPos.x,squadPos.z)
	squad.position = {x = squadPos.x, y = squadPos.y, z = squadPos.z}
	squad.Cell,squad.CellX,squad.CellZ = self.ai.targethst:GetCellHere(squad.position)
	self:EchoDebug('actual squad.position',squad.position.x,squad.position.z)
end

function RaidHST:goToNextNode(squad)
	if not squad.path or not squad.path[1]  then
		self:EchoDebug('no next path')
		self:resetSquad(squad)
		return
	end	self:EchoDebug('pos',squad.position.x,squad.position.z,'path1',squad.path[1].x,squad.path[1].z,'dist',self.ai.tool:Distance(squad.position,squad.path[1]))
  	if self.ai.tool:Distance(squad.position,squad.path[1]) < 256 then
  		Next = table.remove(squad.path,1)
  	end
 	if squad.path[1] then
		self:EchoDebug('in moving')
 		self:squadMove(squad.members,squad.path[1])
	else
		self:EchoDebug('end path??')
 	end
end

function RaidHST:squadMove(members,pos)
	for index,id in pairs(members) do
		self:EchoDebug('go to next node',pos.x,pos.z)
		local unit = self.game:GetUnitByID(id)
		unit:Move(pos)
	end
end

function RaidHST:squadOnTarget(squad)
	if not squad.target then
		squad.onTarget = false
		self:EchoDebug('no target on target')
		return nil
	end
	if self.ai.tool:distance(squad.position,squad.target.pos) < 256 then
		self:EchoDebug('im on target')
		squad.onTarget = true
		self:Roam(squad)
		return true
	else
		self:EchoDebug('away from target')
		squad.onTarget = false
		self:Hold(squad)
		return false
	end
end

function RaidHST:doAttack(squad)
	self:EchoDebug('do attack')
	local vulnerable = self:nearbyVulnerable(squad.members) or self:nearestEnemy(squad)
	for index,id in pairs(squad.members) do
		local unit = self.game:GetUnitByID(id)
		local rx = math.random(-50,50)
		local rz = math.random(-50,50)
		if vulnerable and vulnerable.position then
			self:EchoDebug('nearby vulnerable',vulnerable)
			local vpos = vulnerable.position
			unit:AttackMove({x=vpos.x+rx,y= Spring.GetGroundHeight(vpos.x+rx,vpos.z+rz),z=vpos.z+rz})
		elseif squad.target then
			self:EchoDebug('random attack')
			unit:AttackMove({x=squad.target.pos.x+rx,y= Spring.GetGroundHeight(squad.target.pos.x+rx,squad.target.pos.z+rz),z=squad.target.pos.z+rz})
			squad.path = nil
			squad.target = nil
		end
	end
end

function RaidHST:nearbyVulnerable(members)
	for index,id in pairs(members) do
		local unit = self.game:GetUnitByID(id)
		local vulnerable = self.ai.targethst:NearbyVulnerable(unit)
		if vulnerable then
			return vulnerable
		end
	end
end

function RaidHST:Roam(squad)
	for index,unitID in pairs(squad.members) do
		local unit = self.game:GetUnitByID(unitID)
		unit:Roam()
	end
end

function RaidHST:Hold(squad)
	for index,unitID in pairs(squad.members) do
		local unit = self.game:GetUnitByID(unitID)
		unit:HoldPosition()
	end
end

function RaidHST:resetSquad(squad)
	self:EchoDebug('reset ',squad.squadID)
	for index,unitID in pairs(squad.members) do
		self.raiders[unitID]['inSquad'] = nil
	end
	squad.members = {}
	squad.lock = false
	squad.onTarget = false
	squad.position = nil
	squad.target = nil
	squad.path = nil
end

function RaidHST:nearestEnemy(squad)
	local members = squad.members
	for _,id in pairs(members) do
		local enemy = Spring.GetUnitNearestEnemy(id,self.ai.armyhst.unitTable[squad.unitName].losRadius,true)
		if enemy then return self.game:GetUnitByID(enemy):GetPosition() end
	end
end

function RaidHST:GetPathValidFunc(unitName)
	if self.pathValidFuncs[unitName] then
		return self.pathValidFuncs[unitName]
	end
	local valid_node_func = function ( node )
		return self.ai.targethst:IsSafePosition(node.position, unitName, 1)
	end
	self.pathValidFuncs[unitName] = valid_node_func
	return valid_node_func
end

function RaidHST:getRaidCell(squad)
	if not squad then return end
	local leader = self.game:GetUnitByID(squad.members[1])
-- 	local rpos = representative:GetPosition()
	local inCell = self.ai.targethst:GetCellHere(squad.position)
	local threatReduction = 0
	local TR = self.ai.armyhst.unitTable[squad.unitName].metalCost * #squad.members
	if inCell ~= nil then
		-- if we're near more raiders, these raiders can target more threatening targets together
		if inCell.raiderHere then threatReduction = threatReduction + inCell.raiderHere end
		if inCell.raiderAdjacent then threatReduction = threatReduction + inCell.raiderAdjacent end
	end
	self:EchoDebug(threatReduction,TR)

-- 	local rname = representative:Name()
	local maxThreat = self.ai.armyhst.unitTable[squad.unitName].metalCost
	--local rthreat, rrange = self.ai.tool:ThreatRange(squad.unitName)
	local rthreat = self.ai.armyhst.unitTable[squad.unitName].threat
	local rrange = self.ai.armyhst.unitTable[squad.unitName].maxRange
	self:EchoDebug(squad.unitName .. ": " .. rthreat .. " " .. rrange)
	if rthreat > maxThreat then maxThreat = rthreat end
	local best
	local bestDist = math.huge
	local cells
	local minThreat = math.huge
 	for i,cell in pairs (self.ai.targethst.cellList) do
 		local value, threat, gas = self.ai.targethst:CellValueThreat(squad.unitName, cell)
		self:EchoDebug('cell target raid value',value,cell.pos.x,cell.pos.z	)
 		local dist = self.ai.tool:Distance(squad.position, cell.pos)
 		if value > 0 and threat < minThreat  and self.ai.maphst:UnitCanGoHere(leader, cell.pos) then
 			minThreat = threat
 			best = cell
			self:EchoDebug('have a cell')
--  			map:DrawCircle(best.pos, 100, {255,0,0,255}, 'raid', true, 3)
 		end
 	end
	--[[
  	for i, cell in pairs(self.cellList) do
  		local value, threat, gas = self:CellValueThreat(rname, cell)
  		-- cells with other raiders in or nearby are better places to go for raiders
  		if cell.raiderHere then threat = threat - cell.raiderHere end
  		if cell.raiderAdjacent then threat = threat - cell.raiderAdjacent end
  		threat = threat - threatReduction
  		if value > 0 and threat <= maxThreat then
  			if self.ai.maphst:UnitCanGoHere(representative, cell.pos) then
  				local mod = value - (threat * 3)
  				local dist = self.ai.tool:Distance(rpos, cell.pos) - mod
  				if dist < bestDist then
  					best = cell
  					bestDist = dist
  				end
  			end
  		end
  	end]]

	return best
end
-- function RaidHST:GetImmediateTargetUnit()
-- 	if self.arrived and self.unitTarget then
-- 		local utpos = self.unitTarget:GetPosition()
-- 		if utpos and utpos.x then
-- 			return self.unitTarget
-- 		end
-- 	end
-- 	local unit = self.unit:Internal()
-- 	local position
-- 	if self.arrived then position = self.target end
-- 	local safeCell = self.ai.targethst:RaidableCell(unit, position)
-- 	if safeCell then
-- 		if self.disarmer then
-- 			if safeCell.disarmTarget then
-- 				return safeCell.disarmTarget.unit
-- 			end
-- 		end
-- 		local mobTargets = safeCell.targets[self.groundAirSubmerged]
-- 		if mobTargets then
-- 			for i = 1, #self.hurtsList do
-- 				local groundAirSubmerged = self.hurtsList[i]
-- 				if mobTargets[groundAirSubmerged] then
-- 					return mobTargets[groundAirSubmerged].unit
-- 				end
-- 			end
-- 		end
-- 		local vulnerable = self.ai.targethst:NearbyVulnerable(unit)
-- 		if vulnerable then
-- 			return vulnerable.unit
-- 		end
-- 	end
-- end

-- function RaidHST:addWaypoints(squad,target)
-- 		local subWay
-- 		if math.random() > 0.5 then
-- 			subWay = {x = squad.position.x,y = Spring.GetGroundHeight(squad.position.x,target.pos.z),z = target.pos.z}
-- 		else
-- 			subWay = {x = target.pos.x,y = Spring.GetGroundHeight(target.pos.x,squad.position.z),z = squad.position.z}
-- 		end
-- 		local subt = {pos = subWay}
-- 		local path1, path2,tmpt1,tmpt2
-- 		tmpt1,  path1 = self:getSquadPath(squad.mclass, squad.position, subt)
-- 		tmpt2,  path2 = self:getSquadPath(squad.mclass, subWay, target)
-- 		if path1 and path2 then
-- 			for i,v in pairs(path2) do
-- 				table.insert(path1,#path1+1,v)
-- 			end
-- 		end
-- 		return path1
-- end

-- function RaidHST:checkProblem(path,waypoints,index)
-- 	--PASS
-- end



-- function RaidHST:getSquadPath(mclass,begin,target)
-- 	if not begin then
-- 		self:EchoDebug('no squad position for path')
-- 		return
-- 	end
-- 	if not target or not target.pos then
-- 		self:EchoDebug('no target for path')
-- 		return
-- 	end
-- 	local pos1 = begin
-- 	local pos2 = target.pos
-- 	local path = Spring.RequestPath(mclass, pos1.x,pos1.y,pos1.z,pos2.x,pos2.y,pos2.z)
-- 	if not path then
-- 		self:EchoDebug('no path')
-- 		return
-- 	end
-- 	local waypoints, pathStartIdx = path:GetPathWayPoints()
-- 	if not waypoints or #waypoints < 1 then
-- 		self:EchoDebug('no waypoints')
-- 	end
-- 	waypoints = self:pathReduction(waypoints)
-- 	return  target , waypoints
-- end


-- function RaidHST:pathReduction(path)
-- 	local newPath = {}
-- 	for index, node in pairs(path) do
-- 		local NodeToPos = {x=node[1],y=node[2], z = node[3]}
-- 		if not newPath[1] then
-- 			newPath[1] = NodeToPos
-- 		end
-- 		if self.ai.tool:distance(newPath[#newPath],NodeToPos) >= 512 then
--
-- 			table.insert(newPath,#newPath+1,NodeToPos)
-- 		end
-- 	end
-- 	return newPath
-- end

-- function RaidHST:setSquadTarget(squad)
-- 	local leaderID = squad.members[1]
-- 	local leader = self.game:GetUnitByID(leaderID)
-- 	local leaderPos = leader:GetPosition()
-- 	local target = self.ai.targethst:GetBestRaidCell(leader)
-- 	if target  then
-- 		self:EchoDebug('target', target )
-- 		--target, path = self:getSquadPath(squad.mclass, squad.position, target)
-- 		if target  then
-- 			self:EchoDebug('have a path for this target', target)
-- 			if not squad.target  then
-- 				self:EchoDebug('set a target')
-- 				local path = self:addWaypoints(squad,target)
-- 				if path then
-- 					squad.target = target
-- 					squad.path = path
-- 				end
--
-- 			else
-- 				if (squad.target.pos ~= target.pos) and self.ai.tool:distance(squad.position,target.pos) < self.ai.tool:distance(squad.position,squad.target.pos) then
-- 					self:EchoDebug('re-set a new target')
-- 					local path = self:addWaypoints(squad,target)
-- 					if path then
-- 						squad.target = target
-- 						squad.path = path
-- 					end
-- 				end
-- 			end
-- 		end
--
-- 	end
-- 	if squad.path then
-- 		for i , v in pairs(squad.path) do
-- 			self.map:DrawPoint(v, squad.colour, i, 6)
-- 		end
-- 	end
-- end
