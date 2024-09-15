local separator = "||||"

return {
	SEPARATOR = separator,
	PREFIX = {
		CALL = "synced_proxy_call" .. separator,
		RUN = "synced_proxy_run" .. separator,
		RETURN = "synced_proxy_return" .. separator,
	}
}
