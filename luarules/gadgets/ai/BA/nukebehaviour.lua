NukeBehaviour = class(Behaviour)

function NukeBehaviour:Name()
	return "NukeBehaviour"
end

local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("NukeBehaviour: " .. inStr)
	end
end

local CMD_STOCKPILE = 100
local CMD_ATTACK = 20

function NukeBehaviour:Init()
	local uname = self.unit:Internal():Name()
	if uname == "armemp" then
		self.stunning = true
	elseif uname == "cortron" then
		self.tactical = true
	end
	self.stockpileTime = nukeList[uname]
	self.position = self.unit:Internal():GetPosition()
	self.range = unitTable[uname].groundRange
    self.lastStockpileFrame = 0
    self.lastLaunchFrame = 0
    self.gotTarget = false
    self.finished = false
end

function NukeBehaviour:OwnerBuilt()
	self.finished = true
end

function NukeBehaviour:Update()
	if not self.active then return end

	local f = game:Frame()

	if self.finished then
		if f > self.lastLaunchFrame + 100 then
			self.gotTarget = false
			if ai.needNukes and ai.canNuke then
				local bestCell
				if self.tactical then
					bestCell = ai.targethandler:GetBestBombardCell(self.position, self.range, 2500)
				elseif self.stunning then
					bestCell = ai.targethandler:GetBestBombardCell(self.position, self.range, 3000, true) -- only targets threats
				else
					bestCell = ai.targethandler:GetBestNukeCell()
				end
				if bestCell ~= nil then
					local position = bestCell.pos
					local floats = api.vectorFloat()
					-- populate with x, y, z of the position
					floats:push_back(position.x)
					floats:push_back(position.y)
					floats:push_back(position.z)
					self.unit:Internal():ExecuteCustomCommand(CMD_ATTACK, floats)
					self.gotTarget = true
					EchoDebug("got target")
				end
			end
			self.lastLaunchFrame = f
		end
		if self.gotTarget then
			if self.lastStockpileFrame == 0 or f > self.lastStockpileFrame + self.stockpileTime then
				local floats = api.vectorFloat()
				floats:push_back(1)
				self.unit:Internal():ExecuteCustomCommand(CMD_STOCKPILE, floats)
				self.lastStockpileFrame = f
			end
		end
	end
end

function NukeBehaviour:Activate()
	self.active = true
end

function NukeBehaviour:Deactivate()
	self.active = false
end

function NukeBehaviour:Priority()
	return 100
end
