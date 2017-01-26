
ShardSpringUnitType = class(function(a)
   --
end)


function ShardSpringUnitType:Init( id )
	self.id = id
	self.def = UnitDefs[id]
end

function ShardSpringUnitType:ID()
	return self.id
end

function ShardSpringUnitType:Name()
	return self.def.name
end

function ShardSpringUnitType:CanMove()
	return self.def.canMove
end

function ShardSpringUnitType:CanDeploy()
	-- what does deploy mean for Spring?
	return false
end

function ShardSpringUnitType:CanBuild(type)
	if not type then
		return self.def.buildOptions and #self.def.buildOptions > 0
	end
	-- Spring.Echo(self.def.name, "can build?", type, type:Name())
	if not self.canBuildType then
		self.canBuildType = {}
		-- Spring.Echo(self.def.name, "build options", self.def.buildOptions)
		for _, defID in pairs(self.def.buildOptions) do
			self.canBuildType[defID] = true
		end
	end
	return self.canBuildType[type:ID()]
end

function ShardSpringUnitType:WeaponCount()
	return #self.def.weapons -- test this. not sure the weapons table will give its length by the # operator
end

function ShardSpringUnitType:Extractor()
	return self.def.extractsMetal > 0
end