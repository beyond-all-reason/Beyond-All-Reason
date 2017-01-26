
ShardSpringControlPoint = class(function(a)
   --
end)


function ShardSpringControlPoint:Init( rawPoint, id )
	self.rawPoint = rawPoint
	self.position = {x=rawPoint.x, y=rawPoint.y, z=rawPoint.z}
	self.id = id
end

function ShardSpringControlPoint:ID()
	return self.id
end

function ShardSpringControlPoint:GetPosition()
	return self.position
end

function ShardSpringControlPoint:GetOwner()
	return self.rawPoint.owner
	-- local rawPoints = {}
	-- if Script.LuaRules('ControlPoints') then
	-- 	rawPoints = Script.LuaRules.ControlPoints() or {}
	-- end
	-- local rawPoint = rawPoints[self.id]
	-- return rawPoint.owner
end