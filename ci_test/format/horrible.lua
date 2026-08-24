-- CI fixture. Deliberately broken; delete ci_test/ before merging.
-- Hits sort_requires, quote_style, call_parentheses, indent_type,
-- space_after_function_names, collapse_simple_statement and column_width.
local zebra = require("modules.zebra")
local alpha = require("modules.alpha")
local mango = require'modules.mango'

local  t = { 1,2 , 3;4, ['key']='value' , nested={a=1,b=2,c={'deep','deeper','deepest'}} }

local function  greet ( name )
        print ( 'hello '..name )
    if name == nil then return end
        return {greet=greet,name=name,upper=string.upper(name),lower=string.lower(name),len=#name}
end

local function veryLongSignature(argumentNumberOne, argumentNumberTwo, argumentNumberThree, argumentNumberFour, argumentNumberFive)
	return argumentNumberOne
end

return { t = t, greet = greet, long = veryLongSignature, z = zebra, a = alpha, m = mango }
