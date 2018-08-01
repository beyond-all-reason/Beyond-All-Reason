ControlPointHandler = class(Module)

function ControlPointHandler:Name()
	return "ControlPointHandler"
end

function ControlPointHandler:internalName()
	return "controlpointhandler"
end

local function distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local yd = pos1.z-pos2.z
	local dist = math.sqrt(xd*xd + yd*yd)
	return dist
end

function ControlPointHandler:Init()
	self.ally = self.ai.allyId
end

function ControlPointHandler:ClosestUncapturedPoint(position)
	local pos
	local bestDistance
	local points = self.map:GetControlPoints()
	for i = 1, #points do
		local point = points[i]
		local pointAlly = point:GetOwner()
		if pointAlly ~= self.ally then
			local pointPos = point:GetPosition()
			local dist = distance(position, pointPos)
			if not bestDistance or dist < bestDistance then
				bestDistance = dist
				pos = pointPos
			end
		end
	end
	return pos
end