describe("Command batch callbacks", function()
	it("loads optional callbacks in synced and unsynced handlers", function()
		local root = "."
		local file = assert(io.open(root .. "/luarules/gadgets.lua"))
		local source = file:read("*a")
		file:close()
		local first = assert(source:find("if Script.CommandBatchCallbacks then", 1, true))
		local last = assert(source:find("synthetic.install(gadgetHandler)", first, true))
		local bootstrap = source:sub(first, last - 1)
		for _, supported in ipairs({ false, true }) do
			for _, synced in ipairs({ false, true }) do
				local env = setmetatable({
					Script = { CommandBatchCallbacks = supported },
					gadgetHandler = { UnitCommandList = {} }, -- real handler has NO IsSyncedCode method
					IsSyncedCode = function()
						return synced
					end,
					CMD = { ATTACK = 20 },
					CMD_ANY = "any",
					allowCommandList = { [20] = {} },
					markIdle = function() end,
					VFS = {
						Include = function(name)
							return dofile(root .. "/" .. name)
						end,
					},
				}, { __index = _G })
				local chunk = assert(loadstring(bootstrap))
				setfenv(chunk, env)
				chunk()
				if supported then
					env.gadgetHandler.UnitCommandList = { { _unitCommandIDs = { [45] = true } } }
					assert(env.WantsUnitCommandBatch(1, 1, 0, {}))
					env.gadgetHandler.UnitCommandList = { { _unitCommandIDs = { [20] = true } } }
					assert(not env.WantsUnitCommandBatch(1, 1, 0, {}))
					env.gadgetHandler.UnitCommandList = {}
				end
				assert((type(env.UnitCommandBatch) == "function") == supported)
				assert((type(env.AllowCommandBatch) == "function") == (supported and synced))
				if supported and synced then
					assert(env.AllowCommandBatch(1, 1, 0, {}, -1, true, true) == true)
				end
			end
		end
	end)
end)
