local function removeAllLines()
	GG['MissionAPI'].Modules.MapLines.RemoveAllLines()
end

return {
	{
		type = 'RemoveAllLines',
		parameters = {},
		actionFunction = removeAllLines,
	}
}
