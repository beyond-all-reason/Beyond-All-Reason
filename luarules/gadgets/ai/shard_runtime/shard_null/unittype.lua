ShardUnitType = class(function(a, id)
	a.id = id
	a.def = { id=id}
end)

function ShardUnitType:ID()
	return self.id
end
