-- we do not use explosions_post, see alldefs_post.lua
-- basically, DONT TOUCH this! 
-- local alldefs = VFS.Include("gamedata/alldefs_post.lua")
local savedefs = VFS.Include("gamedata/post_save_to_customparams.lua")

-- local explosionDef_Post = alldefs.ExplosionDef_Post
local saveDefToCustomParams = savedefs.SaveDefToCustomParams

-- handle unitdefs and the weapons they contain
for name, explosionDef in pairs(ExplosionDefs) do
	-- explosionDef_Post(name, explosionDef)
	if SaveDefsToCustomParams then
		saveDefToCustomParams("ExplosionDefs", name, explosionDef)
	end
end