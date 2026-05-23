-- we do not use explosions_post, see alldefs_post.lua
-- basically, DONT TOUCH this!
-- local alldefs = VFS.Include("gamedata/alldefs_post.lua")
local savedefs = VFS.Include("gamedata/post_save_to_customparams.lua")

-- local explosionDef_Post = alldefs.ExplosionDef_Post
local saveDefToCustomParams = savedefs.SaveDefToCustomParams

-- Suppress the muzzle-attached flame CEGs that BAR units fire from their COB
-- scripts via SCRIPT.EmitSfx (sfxtypes.explosiongenerators on the unitdef).
-- These run independent of the weapon's projectile, so neither nulling the
-- weapondef cegtag nor disabling engine flame rendering removes them. The GL4
-- flamethrower gadget (luarules/gadgets/gfx_flamethrower_gl4.lua) handles the
-- muzzle flash itself via the head particles spawned at the projectile's
-- initial position, so these engine CEGs would otherwise visually duplicate.
local suppressFlameMuzzleCEGs = {
	["flamestream"]         = true,
	["flamestreamxm"]       = true,
	["flamestreamxl"]       = true,
	["flamestreamxxl"]      = true,
	["flamestreamthermite"] = true,
}
for name, _ in pairs(suppressFlameMuzzleCEGs) do
	if ExplosionDefs[name] then
		-- An empty CEG def behaves like the existing "blank" CEG: the engine
		-- fires it but it emits no particles, no light, no sound.
		for k in pairs(ExplosionDefs[name]) do
			ExplosionDefs[name][k] = nil
		end
	end
end

-- handle unitdefs and the weapons they contain
for name, explosionDef in pairs(ExplosionDefs) do
	-- explosionDef_Post(name, explosionDef)
	if SaveDefsToCustomParams then
		saveDefToCustomParams("ExplosionDefs", name, explosionDef)
	end
end
