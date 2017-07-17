function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end
function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    if k == "else" then k = "default" end -- handles deprecated ["else"] damage class
    return string.lower(k) -- make all key values lower case
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end
function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end
function SaveDefToCustomParams(defType, name, def)
    -- save def as a string
    local def_string = table.tostring(def)
    def.customparams = def.customparams or {}
    def.customparams.__def = table.tostring(def)
    Spring.Echo("saved " .. defType .. "." .. name .. " to customparams.__def as string")
end
function MarkDefOmittedInCustomParams(defType, name, def)
    -- mark that this def is saved elsewhere as part of another def
    def.customparams = def.customparams or {}
    def.customparams.__def = "omitted"
    Spring.Echo("marked omitted " .. defType .. "." .. name .. " in customparams.__def")
end