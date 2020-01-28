
function gadget:GetInfo()
  return {
    name      = "loader for DamgamAI",
    desc      = "123",
    author    = "Damgam",
    date      = "2020",
    layer     = -100,
    enabled   = true,
	}
end

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

VFS.Include("luarules/gadgets/newAI/DamgamAI/boot.lua")


