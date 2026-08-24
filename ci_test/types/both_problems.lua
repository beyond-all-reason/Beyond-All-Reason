-- CI fixture. Deliberately broken; delete ci_test/ before merging.
-- Misformatted and mistyped, so both checks should annotate this same file.
---@type number
local  wrong = "a string, not a number"

---@param n number
local function  compute ( n,factor )
	return  {n*factor, 'result' }
end

local function  restate ( value )
        print ( 'value is '..value )
    if value == nil then return end
end

return {compute=compute,wrong=wrong,restate=restate}
