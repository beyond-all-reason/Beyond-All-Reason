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

local scripts = VFS.DirList('luarules/gadgets/scavengers/','*.lua')
for i = 1,#scripts do
	VFS.Include(scripts[i])
	Spring.Echo("Scav Loader Directory: " ..scripts[i])
end