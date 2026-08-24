-- CI fixture. Deliberately broken; delete ci_test/ before merging.
-- The filename is the point. Kept large so it stays inside the annotated ten.
local zulu = require'modules.zulu'
local bravo = require("modules.bravo")

local function  greet ( name )
        print ( 'hello '..name )
    if name == nil then return end
end

local function  farewell ( name )
        print ( 'bye '..name )
    if name == nil then return end
end

local  lookup = { a=1,b=2 ; c=3, ['d']=4, e={ 'x','y','z' } }

return {greet=greet,farewell=farewell,lookup=lookup,z=zulu,b=bravo}
