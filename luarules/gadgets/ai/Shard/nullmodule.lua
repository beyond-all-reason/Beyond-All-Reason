NullModule = class(Module)

function NullModule:Name()
	return "Null Module" -- a nice developer friendly response
end

function NullModule:internalName()
	return "nullmodule" -- ai.nullmodule
end

function NullModule:Init()
	-- we should setup some variables here
end

function NullModule:Update()
	-- nothing much to do is there
end
