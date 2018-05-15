-- because often os.time is used to seed randomseed

local fakeos = {}

function fakeos.time()
	if not Shard then return 1 end
	return Shard.randomseed or 1
end

return fakeos