local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function systemRules(mode, features)
	local env = SpecEnv.new({
		includes = { ["init.lua"] = true },
		Script = {
			IsEngineMinVersion = function()
				return true
			end,
		},
		Engine = { FeatureSupport = features or {} },
		Spring = {
			GetModOptions = function()
				return { restrictedspectators = mode }
			end,
		},
	})
	return SpecEnv.include(env, "gamedata/modrules.lua").system
end

describe("spectator vision after elimination", function()
	it("offers the three lobby choices in order and defaults to full view", function()
		local option
		for _, candidate in ipairs(VFS.Include("modoptions.lua")) do
			if candidate.key == "restrictedspectators" then
				option = candidate
				break
			end
		end
		assert(option, "missing restrictedspectators lobby option")
		assert.same("list", option.type)
		local keys = {}
		for _, item in ipairs(option.items) do
			keys[#keys + 1] = item.key
		end
		assert.same({ "allied", "optin", "full" }, keys)
		assert.same("full", option.def)
		assert.is_table(systemRules(option.def))
	end)

	it("requires the spectator setters for restricted lobbies, including old presets", function()
		for _, mode in ipairs({ "optin", "allied", "1", true }) do
			assert.has_error(function()
				systemRules(mode)
			end)
			assert.is_table(systemRules(mode, { gameControlledSpectators = true }))
		end
	end)

	it("latches the stricter setting until the player opts in or the game ends", function()
		for _, case in ipairs({
			{ "allied", 3, false, false },
			{ "optin", 1, false, false },
			{ "optin", 3, false, true },
			{ "full", 2, false, true },
			{ "full", 3, true, true },
		}) do
			local lobby, personal, immediate, afterClick = unpack(case)
			local spec, access, view, selection, click = false, false, false, false, false
			local env = SpecEnv.new({
				gadget = {},
				gadgetHandler = {
					IsSyncedCode = function()
						return false
					end,
				},
				Script = {
					LuaUI = setmetatable({
						BARSpectatorFullViewButton = function()
							return click
						end,
					}, {
						__call = function()
							return true
						end,
					}),
				},
				Spring = {
					GetModOptions = function()
						return { restrictedspectators = lobby }
					end,
					GetMyPlayerID = function()
						return 0
					end,
					GetSpectatingState = function()
						return spec
					end,
					GetConfigInt = function()
						return personal
					end,
					IsGameOver = function()
						return false
					end,
					GetSpectatorFullCommunications = function()
						return access
					end,
					SetSpectatorFullCommunications = function(value)
						access = value
					end,
					SetSpectatorFullView = function(value)
						view = value
					end,
					SetSpectatorFullSelect = function(value)
						selection = value
					end,
				},
			})
			SpecEnv.include(env, "luarules/gadgets/game_spectator_vision.lua")
			spec = true
			env.gadget:PlayerChanged(0)
			env.gadget:Update()
			assert.same({ immediate, immediate, immediate }, { access, view, selection })
			personal, click = 3, true
			env.gadget:PlayerChanged(0)
			env.gadget:Update()
			assert.same({ afterClick, afterClick, afterClick }, { access, view, selection })
			env.gadget:GameOver()
			assert.same({ true, true, true }, { access, view, selection })
		end
	end)

	it("checks direct widget setters against the original allyteam and the current grant", function()
		local access, view, selection, team = false, false, false, 0
		local spring = {
			GetMyPlayerID = function()
				return 0
			end,
			GetSpectatorFullCommunications = function()
				return access
			end,
			SetSpectatorFullCommunications = function(value)
				access = value
			end,
			GetPlayerInfo = function()
				return "player", true, true, 0, 0
			end,
			GetTeamInfo = function(id)
				return id, 0, false, false, "", id == 2 and 1 or 0
			end,
			SetSpectatorFullView = function(value)
				view = value
			end,
			SetSpectatorFullSelect = function(value)
				selection = value
			end,
			SetSpectatorTeam = function(id)
				team = id
				return true
			end,
		}
		VFS.Include("common/spectatorVision.lua").installWidgetControls(spring)
		assert.is_nil(spring.SetSpectatorFullCommunications)
		assert.is_true(spring.SetSpectatorTeam(1))
		assert.is_false(spring.SetSpectatorTeam(2))
		spring.SetSpectatorFullView(true)
		spring.SetSpectatorFullSelect(true)
		assert.same({ false, false, 1 }, { view, selection, team })

		access = true
		assert.is_true(spring.SetSpectatorTeam(2))
		spring.SetSpectatorFullView(true)
		spring.SetSpectatorFullSelect(true)
		assert.same({ true, true, 2 }, { view, selection, team })
	end)
end)
