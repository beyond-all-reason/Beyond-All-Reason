local function sendMessage(message)
	Spring.Echo(message)
end

return {
	SendMessage = sendMessage,
}