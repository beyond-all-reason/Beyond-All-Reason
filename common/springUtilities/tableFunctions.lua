local function customKeyToUsefulTable(dataRaw)
	if not dataRaw then
		return
	end
	if not type(dataRaw) == 'string' then
		Spring.Echo("Customkey data error! type == " .. type(dataRaw))
	else
		dataRaw = string.gsub(dataRaw, '_', '=')
		dataRaw = string.base64Decode(dataRaw)
		local dataFunc, err = loadstring("return " .. dataRaw)
		if dataFunc then
			local success, usefulTable = pcall(dataFunc)
			if success then
				if collectgarbage then
					collectgarbage("collect")
				end
				return usefulTable
			end
		end
		if err then
			Spring.Echo("Customkey error", err)
		end
	end
	if collectgarbage then
		collectgarbage("collect")
	end
end

return {
	CustomKeyToUsefulTable = customKeyToUsefulTable,
}