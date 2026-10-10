local ModuleHandler = require("modules/module_handler")

describe("ModuleHandler", function()
	describe("Register", function()
		local manifests

		setup(function()
			ModuleHandler.ResetCaches()
			manifests = ModuleHandler.Register()
		end)

		it("finds every directory that has a manifest, keyed by directory name", function()
			for _, dir in ipairs(VFS.SubDirs("modules/", "*")) do
				local name = dir:gsub("/+$", ""):match("([^/]+)$")
				if VFS.FileExists("modules/" .. name .. "/manifest.lua") then
					assert.is_table(
						manifests[name],
						"modules/" .. name .. "/manifest.lua exists but Register() did not load it"
					)
				end
			end
		end)

		it("skips directories that have no manifest", function()
			assert.is_nil(manifests.graphics)
			assert.is_nil(manifests.i18n)
		end)
	end)

	describe("Resolve", function()
		describe("a missing requirement", function()
			local function manifest(name, requires)
				return { name = name, dir = "modules/" .. name .. "/", requires = requires or {} }
			end

			it("reports an error for a module whose requirement is missing, and still loads the rest", function()
				local failures = {}
				local loadable = ModuleHandler.Resolve({
					base = manifest("base"),
					needy = manifest("needy", { "absent" }),
				}, function(message)
					failures[#failures + 1] = message
				end)
				assert.is_table(loadable.base)
				assert.is_nil(loadable.needy)
				assert.are.same({ 'Module "needy" requires missing module "absent"; not loaded' }, failures)
			end)

			it("doesn't load modules whose dependencies failed to load", function()
				local failures = {}
				local loadable = ModuleHandler.Resolve({
					needy = manifest("needy", { "absent" }),
					downstream = manifest("downstream", { "needy" }),
					bystander = manifest("bystander", { "downstream" }),
				}, function(message)
					failures[#failures + 1] = message
				end)
				assert.is_nil(loadable.needy)
				assert.is_nil(loadable.downstream)
				assert.is_nil(loadable.bystander)
				assert.are.equal(3, #failures)
			end)
		end)
	end)

	describe("a module's contract", function()
		local Policy = require("modules/policy")
		-- Three modules on a fake VFS. owner declares its Check policy in the policy file that builds it; friend
		-- contributes a step to owner's Check through Policies.Contract; loner's two policy files each claim the
		-- same category.
		---@type table<string, fun(env: table): any> the fake VFS: a path to what including it returns
		local FILES = {}
		local real = {}

		---@param path string
		---@param env table|nil
		local function include(path, env)
			return FILES[path](env or {})
		end

		setup(function()
			for _, fn in ipairs({ "SubDirs", "DirList", "FileExists", "Include" }) do
				real[fn] = VFS[fn]
			end
			VFS.SubDirs = function()
				return { "modules/owner/", "modules/friend/", "modules/loner/" }
			end
			VFS.DirList = function(dir)
				local found = {}
				for path in pairs(FILES) do
					if path:sub(1, #dir) == dir and not path:sub(#dir + 1):find("/") then
						found[#found + 1] = path
					end
				end
				table.sort(found)
				return found
			end
			VFS.FileExists = function(path)
				return FILES[path] ~= nil
			end
			VFS.Include = function(path, env, ...)
				if FILES[path] then
					return include(path, env)
				end
				return real.Include(path, env, ...)
			end
		end)

		teardown(function()
			for fn, original in pairs(real) do
				VFS[fn] = original
			end
			ModuleHandler.ResetCaches()
		end)

		before_each(function()
			ModuleHandler.ResetCaches()
			FILES = {
				["modules/owner/manifest.lua"] = function()
					return { name = "owner" }
				end,
				["modules/friend/manifest.lua"] = function()
					return { name = "friend" }
				end,
				["modules/loner/manifest.lua"] = function()
					return { name = "loner" }
				end,
				["modules/owner/policies/check.lua"] = function(env)
					local Check = Policy.Fold({ Shape = "Shape" })
					env.Policies.On(Check).Apply(Check.Shape, function(ctx)
						ctx.seen[#ctx.seen + 1] = "owner"
					end)
					return { Check = Check }
				end,
				["modules/friend/policies/owner.lua"] = function(env)
					local Owner = env.Policies.Contract("owner")
					local Extra = Policy.Contributes(Owner.Check, { Friendly = "Friendly", Shy = "Shy" })
					env.Policies
						.On(Extra)
						.Apply(Extra.Friendly, function(ctx)
							ctx.seen[#ctx.seen + 1] = "friend"
						end)
						.Apply(Extra.Shy, function(ctx)
							ctx.seen[#ctx.seen + 1] = "shy"
						end)
						.When(function(ctx)
							return ctx.brave == true
						end)
					return { Extra = Extra }
				end,
			}
		end)

		it("is what its policy files return, stamped by the loader", function()
			local owner = ModuleHandler.Contract("owner")
			assert.are.same({ owner = "owner", category = "check", result = "fold" }, Policy.IdentityOf(owner.Check))
			assert.is_true(rawequal(owner, ModuleHandler.Contract("owner")))
		end)

		it("takes a contribution declared in the file that builds it, opened on the contributor's own steps", function()
			local ctx = { seen = {} }
			ModuleHandler.Evaluate(ModuleHandler.LoadPolicies("owner").check, ctx)
			assert.are.same(
				{ "owner", "friend" },
				ctx.seen,
				"a step When'd on a condition that does not hold does nothing"
			)
			local brave = { seen = {}, brave = true }
			ModuleHandler.Evaluate(ModuleHandler.LoadPolicies("owner").check, brave)
			assert.are.same({ "owner", "friend", "shy" }, brave.seen)
			local friend = ModuleHandler.Contract("friend")
			assert.are.same({ "check", "owner" }, {
				Policy.IdentityOf(friend.Extra).contributes.category,
				Policy.IdentityOf(friend.Extra).contributes.owner,
			})
		end)

		it("refuses a category declared twice, and a policy file returning anything but its steps", function()
			FILES["modules/loner/policies/a.lua"] = function(env)
				local Check = Policy.Fold({ A = "A" })
				env.Policies.On(Check).Apply(Check.A, function() end)
				return { Check = Check }
			end
			FILES["modules/loner/policies/b.lua"] = function(env)
				local Check = Policy.Fold({ B = "B" })
				env.Policies.On(Check).Apply(Check.B, function() end)
				return { Check = Check }
			end
			assert.has_error(function()
				ModuleHandler.Contract("loner")
			end, "modules/loner/policies/b.lua: loner already declares Check")
			ModuleHandler.ResetCaches()
			FILES["modules/loner/policies/b.lua"] = function()
				return { Check = { B = "B" } }
			end
			assert.has_error(
				function()
					ModuleHandler.Contract("loner")
				end,
				"modules/loner/policies/b.lua: Check must declare itself: Single(...), Product(...), Fold(...) or Contributes(...)"
			)
		end)

		it("refuses a contributor's Refusal: the owner alone shapes it", function()
			FILES["modules/friend/policies/owner.lua"] = function(env)
				local Owner = env.Policies.Contract("owner")
				local Extra = Policy.Contributes(Owner.Check, { Friendly = "Friendly" })
				env.Policies.On(Extra).Apply(Extra.Friendly, function() end).Refusal(function()
					return "mine"
				end)
				return { Extra = Extra }
			end
			assert.has_error(function()
				ModuleHandler.LoadPolicies("owner")
			end, "modules/friend/policies/owner.lua: only owner may shape the refusal of owner.check")
		end)

		it("refuses two modules whose contracts need each other, naming both", function()
			FILES["modules/owner/policies/friendly.lua"] = function(env)
				env.Policies.Contract("friend")
			end
			assert.has_error(function()
				ModuleHandler.Contract("owner")
			end, "friend -> owner -> friend: contracts that need each other")
		end)
	end)
end)
