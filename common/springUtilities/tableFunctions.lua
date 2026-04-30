local function customKeyToUsefulTable(dataRaw)
	if not dataRaw then
		return
	end
	if not type(dataRaw) == "string" then
		SpringShared.Echo("Customkey data error! type == " .. type(dataRaw))
	else
		dataRaw = string.gsub(dataRaw, "_", "=")
		dataRaw = string.base64Decode(dataRaw)
		local dataFunc, err = loadstring("return " .. dataRaw)
		if dataFunc then
			local success, usefulTable = pcall(dataFunc)
			if success then
				return usefulTable
			end
		end
		if err then
			SpringShared.Echo("Customkey error", err)
		end
	end
end

return {
	CustomKeyToUsefulTable = customKeyToUsefulTable,
}
