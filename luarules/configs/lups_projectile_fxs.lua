local fx = {

}


local tbl = {
}
local tbl2 = {}

for weaponName, data in pairs(tbl) do
  local weaponDef = WeaponDefNames[weaponName] or {}
  local weaponID = weaponDef.id
  if weaponID then
    tbl2[weaponID] = data
  end
end

return tbl2
