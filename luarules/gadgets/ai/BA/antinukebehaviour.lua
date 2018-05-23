AntinukeBehaviour = class(Behaviour)

function AntinukeBehaviour:Name()
	return "AntinukeBehaviour"
end

local cmdId = 100

function AntinukeBehaviour:Init()
    self.lastStockpileFrame = 0
    self.finished = false
end

function AntinukeBehaviour:OwnerBuilt()
	self.finished = true
end

function AntinukeBehaviour:Update()
	params_list = params_list or {}
	options = options or {}
	if Spring.GetGameFrame() % 3000 == 4 and params_list and params_list.push_back then
		-- handle fake vectorFloat object
		params_list = params_list.values
		Spring.GiveOrderToUnit(self.unit:Internal():ID(), cmdId, params_list, options)
end

function AntinukeBehaviour:Activate()
		self.active = true
end

function AntinukeBehaviour:Deactivate()
		self.active = false
end

function AntinukeBehaviour:Priority()
	return 51
end

end