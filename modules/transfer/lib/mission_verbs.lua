--- Transfer's mission-sandbox adapter. The actions are declared in
--- lib/actions.lua and shared with the mode grammar; this adds only what a
--- trigger file needs on top of them: the roster group is checked at load,
--- and the call becomes the lazy effect the engine arms.
---
--- Nothing here decides what transfer means. An action that gains a mission
--- facet appears in trigger files the moment it has a Perform, and one that
--- loses it disappears — there is no second list to keep in step.

local Actions = VFS.Include("modules/transfer/lib/actions.lua")

local TransferVerbs = {}

---Build one trigger file's Transfer verbs: every action that can be performed.
---@param groups table<string, boolean> the roster's declared group names
---@return TransferActions
function TransferVerbs.MakeTransfer(groups)
	local verbs = {}
	for name, action in pairs(Actions.Transfer) do
		if type(action) == "table" and type(action.Perform) == "function" then
			local label = "Transfer." .. name
			---@param group MissionUnitGroup
			---@param team MissionTeam
			---@return MissionEffect
			verbs[name] = function(group, team)
				assert(type(group) == "string", label .. " expects a group name string")
				assert(groups[group],
					label .. '("' .. group .. '"): no such group — units.lua Grouped(...) declares the mission\'s groups')
				assert(type(team) == "table" and type(team.teamID) == "number",
					label .. " expects a Team handle (e.g. Team.Player)")
				return {
					---@param ctx MissionContext
					execute = function(ctx)
						action.Perform(ctx, group, team.teamID)
					end,
				}
			end
		end
	end
	return verbs
end

return TransferVerbs
