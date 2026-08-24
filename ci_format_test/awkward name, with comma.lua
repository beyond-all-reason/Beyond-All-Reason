-- Same purpose as horrible.lua, but the file name carries a space and a comma
-- so the NUL-separated file list and the annotation escaping get exercised too.
local function  greet ( name )
	print ( 'hello '..name )
end

return {greet=greet}
