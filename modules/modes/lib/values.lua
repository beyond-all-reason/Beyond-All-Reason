---@class ModeValues
local Values = {}

---A modoption on the wire is a string. Booleans are the engine's "1"/"0".
---Engine Lua numbers are float32, so a plain tostring leaks precision noise
---("0.60000002"); round at float32's seven digits with %.7f, then strip the
---trailing zeros the engine's %g would keep. Yields "0.6", "30", "-1".
---
---Every producer of a mode value string reads this one function: the CI
---export that bakes modes.json, and the lobby, which includes it out of the
---game archive. A client's "did the user deviate from the preset" compares
---strings, so two formatters would be a bug waiting for a value.
---@param v any
---@return string
function Values.ToModOption(v)
	if type(v) == "boolean" then
		return v and "1" or "0"
	end
	if type(v) == "number" then
		return (string.format("%.7f", v):gsub("0+$", ""):gsub("%.$", ""))
	end
	return tostring(v)
end

return Values
