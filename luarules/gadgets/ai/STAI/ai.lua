STAI = class(ShardAI)

function STAI:Name()
	return 'STAI'
end

function STAI:internalName()
	return "stai"
end

function STAI:test()
	Spring:Echo('test')

	for i,v in pairs(STAI) do
		print(i,v)
	end
end
