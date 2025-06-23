STAI = class(ShardAI)

function STAI:Name()
	return 'STAI'
end

function STAI:internalName()
	return "stai"
end

function STAI:test()
	for i,v in pairs(STAI) do
		Spring.Echo('H.I.V.E. ST AI module:',i,v)
	end
end
