local telescope = require 'telescope'

local function same(t1, t2)
  if type(t1) ~= 'table' or type(t2) ~= 'table' then return t1 == t2 end

  for k,v in pairs(t1) do
    if not same(v, t2[k]) then return false end
  end

  for k,v in pairs(t2) do
    if not same(v, t1[k]) then return false end
  end

  return true
end

telescope.make_assertion("same", "%s to be identical to %s", same)
