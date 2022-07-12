RaidHST = class(Module)

function RaidHST:Name()
	return "RaidHST"
end

function RaidHST:internalName()
	return "raidhst"
end

local minRaidCount = 6
function RaidHST:Init()
	self.visualdbg = true
	self.DebugEnabled = false
	self.raiders = {}
	self.squads = {}
	self.pathValidFuncs = {}
	self.wave = 5

end



function RaidHST:Update()
-- 	local f = self.game:Frame()
-- 	if f % 97 ~=0 then return end
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
	self.wave = 5 + math.min(math.ceil(self.ai.Energy.income/1000),20)
	self:EchoDebug('start update')
	self:doSquads()
	for squadID,squad in pairs(self.squads) do
		if #squad.members < 1 then
			self:resetSquad(squad)
			return
		end

		self:EchoDebug('update squad',squadID)
		self:getSquadPosition(squad)
		local run = self:running(squad)
		self:EchoDebug('RUN',run)
		self:visualDBG(squad)
		if run then
			if self:squadOnTarget(squad) then
				self:doAttack(squad)
				self:EchoDebug('squad on target')
				self:targeting(squad,'nearest')
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
			self.squads[squadID].formation = {}
			self.squads[squadID].membersPos = {}
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

function RaidHST:targeting(squad,targetType)
	if squad.target and squad.path then
		self:EchoDebug('have already a target')
		return
	end
	local target = nil
	if targetType == 'nearest' then
		target = self:getRaidCell1(squad)
	else
		target = self.getRaidCell3(squad) or self:getRaidCell2(squad)
	end
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

function RaidHST:getRaidCell3(squad)
	if not squad then return end
	if not self.ai.targethst.distals then return end
	local leader = self.game:GetUnitByID(squad.members[1])
	local bestDist = math.huge
	local bestTarget = nil
	for i, cell in pairs(self.ai.targethst.distals) do
		--local cell = self.ai.targethst.CELLS[G.x][G.z]
		if self.ai.maphst:UnitCanGoHere(leader, cell.pos) then
			local dist = self.ai.tool:Distance(cell.pos,squad.position) < bestDist
			if dist < bestDist  then
				bestTarget = cell
				bestDist = dist
			end
		end
	end
	self:EchoDebug('best distals Target',bestTarget)
	return bestTarget
end

function RaidHST:getRaidCell1(squad)
	if not squad then return end
	local leader = self.game:GetUnitByID(squad.members[1])
	local bestDist = math.huge
	local bestTarget = nil
	for i, G in pairs(self.ai.targethst.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.x][G.z]
		if self.ai.maphst:UnitCanGoHere(leader, cell.pos) then
			local dist = self.ai.tool:Distance(cell.pos,squad.position) < bestDist
			if dist < bestDist  then
				bestTarget = cell
				bestDist = dist
			end
		end
	end
	self:EchoDebug('bestTarget',bestTarget)
	return bestTarget
end

function RaidHST:getRaidCell2(squad)
	if not squad then return end
	local leader = self.game:GetUnitByID(squad.members[1])
	local raidPower = self.ai.armyhst.unitTable[squad.unitName].metalCost * #squad.members
	self:EchoDebug('raidPower',raidPower)
	local topDist = self.ai.tool:DistanceXZ(0,0, Game.mapSizeX, Game.mapSizeZ)
	local bestValue = math.huge
	local bestTarget = nil
	for i, G in pairs(self.ai.targethst.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.x][G.z]
		if cell.armed < raidPower and cell.MOBILE <= 0 then
			self:EchoDebug('power',cell.armed,G.x,G.z)
			if self.ai.maphst:UnitCanGoHere(leader, cell.pos) then
-- 				local Relativedistance = self.ai.tool:Distance(cell.pos,squad.position) / topDist
				local Relativedistance = self.ai.tool:Distance(cell.pos, self.ai.targethst.enemyBasePositionor or squad.position) / topDist
				local RelativeValue = Relativedistance * cell.IMMOBILE
				if RelativeValue < bestValue  then
					bestTarget = cell
					bestValue = RelativeValue
				end
			end
		end
	end
	self:EchoDebug('bestTarget',bestTarget)
	return bestTarget
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
	squad.membersPos = {}
	for index,id in pairs(members) do
		local unit = self.game:GetUnitByID(id)
		if unit:IsAlive() then
			local unitPos = unit:GetPosition()
			squad.membersPos[index] = unitPos
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
	local squadToPath1 = 0
	local arrival = true
	for index,mPos in pairs(squad.membersPos) do
		if not squad.formation[index] then
			self:EchoDebug('set start at',squad.path[1].x,squad.path[1].z)
			squad.formation[index] = squad.path[1]
		end

		self:EchoDebug(index,mPos,squad.formation[index].x,squad.formation[index].y,squad.formation[index].z,squadToPath1)
		squadToPath1 = squadToPath1 + self.ai.tool:Distance(mPos ,squad.formation[index])
		if self.ai.tool:Distance(mPos ,squad.formation[index]) > 128 then
			arrival = false
		end


	end
	if arrival then
		table.remove(squad.path,1)
	end
 	if squad.path[1] then
		self:EchoDebug('in moving')
 		self:squadMove(squad)
	else
		self:EchoDebug('end path??')
 	end
end

function RaidHST:squadMove(squad)
	squad.formation = {}
	local pos = squad.path[1]
	local X
	local Z
	local range = self.ai.armyhst.unitTable[squad.unitName].losRadius / 2
	for index,id in pairs(squad.members) do
		ref = index/10

		if squad.position.x < pos.x then
			X = range * math.sin(ref) * -1
		else
			X = (range * math.sin(ref))
		end
		if squad.position.z < pos.z then
			Z = range * math.cos(ref) * -1
		else
			Z = (range * math.cos(ref))
		end

		local unit = self.game:GetUnitByID(id)

		local arch = api.Position()
		arch.x = pos.x + X
		arch.z = pos.z + Z
		arch.y = Spring.GetGroundHeight(arch.x,arch.z)
		self:EchoDebug('arch',arch.x,arch.z)
		self:EchoDebug('go to next node',index,arch.x,arch.z)
		squad.formation[index] = arch
		unit:Move(arch)
--  		unit:Move(pos)
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
	local vulnerable =  self:nearestEnemy(squad) --self:nearbyVulnerable(squad.members) or
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
			self:resetSquad(squad)
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
	squad.formation = {}
	squad.membersPos = {}
	squad.lock = false
	squad.onTarget = false
	squad.position = nil
	squad.target = nil
	squad.path = nil
end

function RaidHST:nearestEnemy(squad) --TEST control this function can give false
	local members = squad.members
	for _,id in pairs(members) do

		local enemy = Spring.GetUnitNearestEnemy(id,self.ai.armyhst.unitTable[squad.unitName].losRadius,true)
		if enemy then
			enemy = self.game:GetUnitByID(enemy)
			if enemy:IsAlive() and Spring.GetGaiaTeamID() ~= enemy:isNeutral() then
				self.map:DrawPoint(enemy:GetPosition(),{1,1,1,1},nil,6)
				return enemy:GetPosition()

			end
		end
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

function RaidHST:visualDBG(squad)
	if not self.visualdbg then return end
	self.map:EraseAll(6)
	if squad.position then
		self.map:DrawPoint(squad.position, squad.colour, squad.squadID, 6)
	end
	if squad.path then
		for i , p in pairs(squad.path) do
			self.map:DrawPoint(p, squad.colour, i, 6)
		end
	end
	if squad.target then
		self.map:DrawPoint(squad.target.pos, squad.colour, squad.squadID .. 'target', 6)
	end
end
