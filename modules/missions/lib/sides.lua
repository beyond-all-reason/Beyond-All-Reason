
local Sides = {}

---@param prefix string a sides_enum value, e.g. SIDES.CORTEX
---@return { name: string, index: integer }|nil
function Sides.Resolve(prefix)
	if type(prefix) ~= "string" or prefix == "" then
		return nil
	end
	local ok, sideOptions = pcall(VFS.Include, "gamedata/sidedata.lua")
	if not ok or type(sideOptions) ~= "table" then
		return nil
	end
	for i, side in ipairs(sideOptions) do
		if type(side.startunit) == "string" and side.startunit == prefix .. "com" then
			return { name = side.name, index = i - 1 }
		end
	end
	return nil
end

return Sides
