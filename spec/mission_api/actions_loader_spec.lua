require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
local actionsLoader = VFS.Include("luarules/mission_api/actions_loader.lua")

-- Load the real action definitions once for the integration section below.
-- (Real action files read GG['MissionAPI'].Modules.ParameterTypes at include time.)
GG["MissionAPI"] = { Modules = { ParameterTypes = parameterTypes } }
RegisterMissionApiModules()
local realDefinitions = actionsLoader.LoadActionDefinitions()

local function countActionFiles()
	local count = 0
	for _, subDir in ipairs(VFS.SubDirs("luarules/mission_api/actions/")) do
		count = count + #VFS.DirList(subDir, "*.lua")
	end
	return count
end
local realActionFileCount = countActionFiles()

describe("mission_api.actions_loader", function()
	before_each(function()
		-- loadActionDefinitions reads the parameter-type table from GG at call time.
		GG["MissionAPI"] = { Modules = { ParameterTypes = parameterTypes } }
		RegisterMissionApiModules()
	end)

	-- \u2500\u2500 LoadActionDefinitions (isolated, mocked action files) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

	describe("LoadActionDefinitions", function()
		-- Runs the loader against a controlled, ordered set of fake action files by
		-- stubbing the VFS calls it makes, then restores them. Unlike triggers, action
		-- files live in subfolders and each returns an array of definitions.
		local function loadWith(fakeDirs)
			local origSubDirs, origDirList, origInclude = VFS.SubDirs, VFS.DirList, VFS.Include
			local subDirs, filesByDir, defsByPath = {}, {}, {}
			for i, dir in ipairs(fakeDirs) do
				subDirs[i] = dir.path
				local paths = {}
				for j, file in ipairs(dir.files) do
					paths[j] = file.path
					defsByPath[file.path] = file.defs
				end
				filesByDir[dir.path] = paths
			end

			VFS.SubDirs = function()
				return subDirs
			end
			VFS.DirList = function(dir)
				return filesByDir[dir] or {}
			end
			VFS.Include = function(path)
				return defsByPath[path]
			end

			local ok, result = pcall(actionsLoader.LoadActionDefinitions)

			VFS.SubDirs, VFS.DirList, VFS.Include = origSubDirs, origDirList, origInclude
			assert(ok, result)
			return result
		end

		it("assigns sequential type IDs across subfolders", function()
			local definitions = loadWith({
				{ path = "units/", files = { { path = "a.lua", defs = { { type = "Alpha" } } } } },
				{ path = "game/", files = { { path = "b.lua", defs = { { type = "Beta" } } } } },
			})

			assert.are.same({ Alpha = 1, Beta = 2 }, definitions.Types)
		end)

		-- Each file returns an array, so one file may declare several actions.
		it("registers every definition in a file, not just the first", function()
			local definitions = loadWith({
				{
					path = "units/",
					files = { { path = "a.lua", defs = { { type = "Alpha" }, { type = "Beta" } } } },
				},
			})

			assert.are.same({ Alpha = 1, Beta = 2 }, definitions.Types)
		end)

		it("keeps a definition's parameters and defaults missing ones to an empty table", function()
			local alphaParameters = { { name = "a", type = parameterTypes.Types.String } }
			local definitions = loadWith({
				{
					path = "units/",
					files = {
						{ path = "a.lua", defs = { { type = "Alpha", parameters = alphaParameters } } },
						{ path = "b.lua", defs = { { type = "Beta" } } }, -- no parameters field
					},
				},
			})

			-- Kept as-is (same reference, not copied):
			assert.are.equal(alphaParameters, definitions.Parameters[1])
			-- Defaulted via `parameters or {}`:
			assert.are.same({}, definitions.Parameters[2])
		end)

		it("keeps each definition's actionFunction under its type ID", function()
			local alphaFunction = function() end
			local definitions = loadWith({
				{
					path = "units/",
					files = { { path = "a.lua", defs = { { type = "Alpha", actionFunction = alphaFunction } } } },
				},
			})

			assert.are.equal(alphaFunction, definitions.Functions[definitions.Types.Alpha])
		end)
	end)

	-- \u2500\u2500 LoadActionDefinitions with the real action files \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

	describe("LoadActionDefinitions with the real action files", function()
		it("registers every action file as a unique type", function()
			local typeCount = 0
			for _ in pairs(realDefinitions.Types) do
				typeCount = typeCount + 1
			end

			assert.are.equal(realActionFileCount, typeCount)
		end)

		it("gives every action an actionFunction to dispatch to", function()
			local missing = {}
			for actionType, typeIndex in pairs(realDefinitions.Types) do
				if type(realDefinitions.Functions[typeIndex]) ~= "function" then
					missing[#missing + 1] = actionType
				end
			end

			assert.are.same({}, missing)
		end)

		-- A parameter naming a type that parameter_types.lua does not define reads back as
		-- `type = nil`, which survives loading and only blows up later as `validators[nil]`
		-- being called, and only for a mission that supplies that one parameter. Removing a
		-- type without removing its uses is exactly what a branch merge does quietly.
		it("declares every parameter with a type that parameter_types defines", function()
			local knownTypes = {}
			for _, typeName in pairs(parameterTypes.Types) do
				knownTypes[typeName] = true
			end

			local typeNameOf = {}
			for actionType, typeIndex in pairs(realDefinitions.Types) do
				typeNameOf[typeIndex] = actionType
			end

			local undefined = {}
			for typeIndex, parameters in pairs(realDefinitions.Parameters) do
				for _, parameter in ipairs(parameters) do
					if parameter.type == nil or not knownTypes[parameter.type] then
						undefined[#undefined + 1] = (typeNameOf[typeIndex] or "?")
							.. "."
							.. tostring(parameter.name)
							.. " = "
							.. tostring(parameter.type)
					end
				end
			end

			assert.are.same({}, undefined)
		end)
	end)
end)
