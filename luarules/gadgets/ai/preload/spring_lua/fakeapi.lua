local api = {}

function api.Position()
	return { x=0, y=0, z=0 }
end

function api.vectorFloat()
	local floats = { values = {} }
	function floats:push_back(value)
		self.values[#self.values+1] = value
	end
	return floats
end

return api