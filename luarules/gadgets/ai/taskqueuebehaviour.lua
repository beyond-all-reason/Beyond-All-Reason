TaskQueueBehaviour = class(Behaviour)

function TaskQueueBehaviour:Init()
	self.active = false
	u = self.unit
	u = u:Internal()
	self.name = u:Name()
	self.countdown = 0
	if self:HasQueues() then
		self.queue = self:GetQueue()
	end

	self.waiting = {}
	self:OnToNextTask()

end

function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then
				k = '"'..k..'"'
			end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

function TaskQueueBehaviour:HasQueues()
	return (taskqueues[self.name] ~= nil)
end

function TaskQueueBehaviour:OwnerBuilt(unit)
	if not self:IsActive() then
		return
	end
	self:OnToNextTask()
end

function TaskQueueBehaviour:OwnerIdle(unit)
	if not self:IsActive() then
		return
	end
	self.countdown = 0
	self:OnToNextTask()
end

function TaskQueueBehaviour:OwnerMoveFailed(unit)
	if not self:IsActive() then
		return
	end
	self:OwnerIdle(unit)
end

function TaskQueueBehaviour:OwnerDead()
	if self.waiting ~= nil then
		for k,v in pairs(self.waiting) do
			self.ai.modules.sleep.Kill(self.waiting[k])
		end
	end
	self.waiting = nil
	self.unit = nil
end

function TaskQueueBehaviour:GetQueue()
	q = taskqueues[self.name]
	if type(q) == "function" then
		q = q(self)
	end
	return q
end

function TaskQueueBehaviour:Update()
	if not self:IsActive() then
		self:DebugPoint("nothing")
		return
	end
	local f = self.game:Frame()
	if self.progress == true then
		if self.countdown > 14 then
			self:ProgressQueue()
		else
			if self.countdown == nil then
				self.countdown = 1
			else
				self.countdown = self.countdown + 1
			end
		end
	end
end

TaskQueueWakeup = class(function(a,tqb)
	a.tqb = tqb
end)
function TaskQueueWakeup:wakeup()
	self.tqb:ProgressQueue()
end

function TaskQueueBehaviour:ProgressQueue()
	unit = self.unit:Internal()
	if self:IsWaitingForPosition() then
		self:DebugPoint("waiting")
		return
	end
	if self.queue == nil then
		if self:HasQueues() then
			self.queue = self:GetQueue()
		else
			self:DebugPoint("nothing")
			return
		end
	end
	self.countdown = 0
	self.progress = false

	if self.queue == nil then
		self.game:SendToConsole("Warning: A "..self.name.." unit, has an empty task queue")
		self:OnToNextTask()
		self:DebugPoint("nothing")
		return
	end
	local idx, val = next(self.queue,self.idx)
	self.idx = idx
	if idx == nil then
		self:DebugPoint("nothing")
		self.queue = self:GetQueue(name)
		self:OnToNextTask()
		return
	end

	local utype = nil
	local value = val
	if type(val) == "function" then
		value = val(self, self.ai, unit)
	end
	if value == "next" then
		self:DebugPoint("nothing")
		self:OnToNextTask()
		return
	end
	if type(val) == "table" then
		self:HandleActionTask( value )
		return
	end

	success = self:TryToBuild( value )
	if success ~= true then
		self:DebugPoint("nothing")
		self:OnToNextTask()
		return
	end
end

function TaskQueueBehaviour:TryToBuild( unit_name )
	utype = self.game:GetTypeByName(unit_name)
	if not utype then
		self.game:SendToConsole("Cannot build:"..unit_name..", could not grab the unit type from the engine")
		return false
	end
	if unit:CanBuild(utype) ~= true then
		return false
	end
	local success = false
	if utype:Extractor() then
		success = self:BuildExtractor(utype)
	elseif utype:Geothermal() then
		success = self:BuildGeothermal(utype)
	elseif unit:Type():IsFactory() then
		success = self.unit:Internal():Build(utype)
	else
		success = self:BuildOnMap(utype)
	end
	return success
end

function TaskQueueBehaviour:HandleActionTask( task )
	local action = task.action
	if action == "wait" then
		t = TaskQueueWakeup(self)
		tqb = self
		self.ai.sleep:Wait({ wakeup = function() tqb:ProgressQueue() end, },task.frames)
	elseif action == "move" then
		self.unit:Internal():Move(task.position)
	elseif action == "moverelative" then
		local upos = unit:GetPosition()
		local newpos = api.Position()
		newpos.x = upos.x + task.position.x
		newpos.y = upos.y + task.position.y
		newpos.z = upos.z + task.position.z
		self.unit:Internal():Move(newpos)
	elseif action == "fight" then
		self.unit:Internal():MoveAndFire(task.position)
	elseif action == "fightrelative" then
		local upos = self.unit:Internal():GetPosition()
		local newpos = api.Position()
		newpos.x = upos.x + task.position.x
		newpos.y = upos.y + task.position.y
		newpos.z = upos.z + task.position.z
		self.unit:Internal():MoveAndFire(newpos)
	elseif action == "patrol" then
		self.unit:Internal():MoveAndPatrol(task.position)
	elseif action == "patrolrelative" then
		local upos = self.unit:Internal():GetPosition()
		local newpos = api.Position()
		newpos.x = upos.x + task.position.x
		newpos.y = upos.y + task.position.y
		newpos.z = upos.z + task.position.z
		self.unit:Internal():MoveAndPatrol(newpos)
	else
		self.game:SendToConsole("Error: Unknown action task "..value.." given to a "..self.name)
		self:DebugPoint("nothing")
		self:OnToNextTask()
	end
end

function onsuccess( job, pos )
	job.tqb:OnBuildingPlacementSuccess( job, pos )
end

function onfail( job )
	job.tqb:OnBuildingPlacementFailure( job )
end

function TaskQueueBehaviour:IsWaitingForPosition()
	return self.placementInProgress
end


function TaskQueueBehaviour:BeginWaitingForPosition()
	self.placementInProgress = true
end

function TaskQueueBehaviour:StopWaitingForPosition()
	self.placementInProgress = false
end

function TaskQueueBehaviour:BuildOnMap(utype)
	--p = self.map:FindClosestBuildSite(utype, unit:GetPosition())
	--self.progress = not self.unit:Internal():Build(utype,p)
	unit = self.unit:Internal()

	local job = {
		start_position=unit:GetPosition(),
		max_radius=1500,
		onSuccess=onsuccess,
		onFail=onfail,
		unittype=utype,
		cleanup_on_unit_death=self.unit.engineID,
		tqb=self
	}
	local success = self.ai.placementhandler:NewJob( job )
	if success ~= true then
		self:StopWaitingForPosition()
		return false
	end
	self:BeginWaitingForPosition()
	return true
end

function TaskQueueBehaviour:BuildExtractor(utype)
	-- find a free spot!
	unit = self.unit:Internal()
	p = unit:GetPosition()
	p = self.ai.metalspothandler:ClosestFreeSpot(utype,p)
	if p == nil then
		return false
	end
	return self.unit:Internal():Build(utype,p)
end

function TaskQueueBehaviour:OnToNextTask()
	self.progress = true
end

function TaskQueueBehaviour:IsDoingSomething()
	return ( self.progress == false )
end

function TaskQueueBehaviour:OnBuildingPlacementSuccess( job, pos )
	self:StopWaitingForPosition()
	local p = dump( pos )
	local success self.unit:Internal():Build( job.unittype, pos )
	if success == false then
		self:OnToNextTask()
	end
end

function TaskQueueBehaviour:OnBuildingPlacementFailure( job )
	self:StopWaitingForPosition()
	self:OnToNextTask()
end

function TaskQueueBehaviour:Activate()
	self.progress = true
	self.active = true
end

function TaskQueueBehaviour:Deactivate()
	self.active = false
end

function TaskQueueBehaviour:Priority()
	return 50
end

function TaskQueueBehaviour:DebugPoint( type )
	local unit = self.unit:Internal()
	local p = unit:GetPosition()
	SendToUnsynced("shard_debug_position",p.x,p.z,type)
end
