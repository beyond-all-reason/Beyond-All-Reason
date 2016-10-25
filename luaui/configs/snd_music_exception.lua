-- Exceptions list for music, it will not check these units for a switch between war and peace

local exceptions = {
--	"terraunit",
}

local array = {}

for unit, data in pairs(exceptions) do
	if UnitDefNames[data] then
		array[UnitDefNames[data].id] = true
	end
end


return array