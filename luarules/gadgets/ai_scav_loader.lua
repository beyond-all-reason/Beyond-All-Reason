function gadget:GetInfo()
  return {
    name      = "loader for Scavenger mod",
    desc      = "123",
    author    = "Damgam",
    date      = "2019",
    layer     = -100,
    enabled   = true,
	}
end

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

if Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0 then
	VFS.Include('luarules/gadgets/scavengers/boot.lua')
end