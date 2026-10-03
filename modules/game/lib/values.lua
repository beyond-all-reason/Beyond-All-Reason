---@class ModeValues
local Values = {}

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
