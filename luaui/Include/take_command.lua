---@param command any
---@param multiplayer boolean
---@return any
return function(command, multiplayer)
	if not multiplayer or type(command) ~= "string" then
		return command
	end

	-- Keep the engine's optional @modifier@ prefix and any target-team argument.
	local prefix, action, args = command:match("^(@[^@]*@%s*)(%S+)(.*)$")
	if not prefix then
		prefix, action, args = command:match("^(%s*)(%S+)(.*)$")
	end
	if action and action:lower() == "take" then
		return prefix .. "luarules take2" .. args
	end
	if action and action:lower() == "giveback" then
		return prefix .. "luarules giveback" .. args
	end
	return command
end
