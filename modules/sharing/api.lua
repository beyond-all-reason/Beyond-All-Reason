--- Shared contract of the sharing module — the surface available in BOTH Lua
--- states. ModuleHandler.Get("sharing") merges this with the current state's
--- contract (api_unsynced.lua) into one flat api: the manifest declares the
--- partition explicitly; consumers hold exactly what exists where they stand.
--- Everything not exported by a contract is module-internal; include paths
--- under modules/sharing/ from outside are a boundary violation.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

return {
	Enums = ModuleHandler.Include("modules/sharing/enums.lua"),
	-- unit surface safe in both states: validation, mode unit types, cached pair policy
	Units = ModuleHandler.Include("modules/sharing/unit/shared.lua"),
	Take = ModuleHandler.Include("modules/sharing/take/comms.lua"),
}
