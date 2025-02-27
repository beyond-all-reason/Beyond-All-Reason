STAI = class(ShardAI)

function STAI:Name()
	return 'STAI'
end

function STAI:internalName()
	return "stai"
end

function STAI:test()
	for i,v in pairs(STAI) do
		Spring.Echo('STAI AI module:',i,v)
	end
end
