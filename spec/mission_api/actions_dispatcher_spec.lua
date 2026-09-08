require("spec_helper")

require("mission_api.spec_helper")

local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
local Types = parameterTypes.Types
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")

---Builds the dispatcher against one action definition and one action instance.
---actions_dispatcher captures the definitions and the action table at include
---time, so both have to be on GG before it is loaded. The schema is given its
---value keys the way the real loaders do, so the fixture cannot drift away from
---what production hands the dispatcher.
local function loadDispatcher(schemaParameters, actionFunction, actionParameters)
	local received
	GG["MissionAPI"] = {
		Modules = { ParameterTypes = parameterTypes },
		ActionDefinitions = {
			Parameters = { [1] = schemaParameters },
			Functions = {
				[1] = function(...)
					received = { ... }
					if actionFunction then
						actionFunction(...)
					end
				end,
			},
		},
		Actions = { onlyAction = { type = 1, parameters = actionParameters } },
	}
	schemaUtils.AssignValueKeys(GG["MissionAPI"].ActionDefinitions.Parameters)
	local dispatcher = VFS.Include("luarules/mission_api/actions_dispatcher.lua")
	return dispatcher, function()
		return received
	end
end

describe("mission_api.actions_dispatcher", function()
	describe("Invoke", function()
		it("passes the resolved team ID, not the authored name", function()
			local schema = {
				{ name = "teamName", required = true, type = Types.TeamName },
			}
			local dispatcher, received = loadDispatcher(schema, nil, { teamName = "theEnemyTeam", teamID = 5 })

			dispatcher.Invoke("onlyAction")

			assert.are.same({ 5 }, received())
		end)

		it("passes team ID 0 rather than treating it as absent", function()
			local schema = {
				{ name = "teamName", required = true, type = Types.TeamName },
			}
			local dispatcher, received = loadDispatcher(schema, nil, { teamName = "thePlayerTeam", teamID = 0 })

			dispatcher.Invoke("onlyAction")

			assert.are.same({ 0 }, received())
		end)

		it("uses the authored name for parameters that are not resolved", function()
			local schema = { { name = "unitName", required = true, type = Types.UnitName } }
			local dispatcher, received = loadDispatcher(schema, nil, { unitName = "scout" })

			dispatcher.Invoke("onlyAction")

			assert.are.same({ "scout" }, received())
		end)

		it("keeps parameters in schema order when mixing resolved and plain ones", function()
			local schema = {
				{ name = "unitName", required = true, type = Types.UnitName },
				{ name = "newTeamName", required = true, type = Types.TeamName },
			}
			local dispatcher, received =
				loadDispatcher(schema, nil, { unitName = "scout", newTeamName = "theEnemyTeam", newTeamID = 5 })

			dispatcher.Invoke("onlyAction")

			assert.are.same({ "scout", 5 }, received())
		end)
	end)
end)
