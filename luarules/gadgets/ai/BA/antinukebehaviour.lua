AntinukeBehaviour = class(Behaviour)

function AntinukeBehaviour:Name()
	return "AntinukeBehaviour"
end

cmdId = 100

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
	if params_list and params_list.push_back then
		-- handle fake vectorFloat object
		params_list = params_list.values
	end
function AntinukeBehaviour:Activate()
		self.active = true
end

function AntinukeBehaviour:Deactivate()
		self.active = false
end

function AntinukeBehaviour:Priority()
	return 100
end

end