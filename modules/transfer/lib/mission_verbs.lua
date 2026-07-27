local Actions = VFS.Include("modules/transfer/lib/actions.lua")

local TransferVerbs = {}

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
				if type(group) == "table" and type(group.group) == "string" then
					group = group.group
				end
				assert(type(group) == "string", label .. " expects a group name or a Group(...)")
				assert(
					groups[group],
					label
						.. '("'
						.. group
						.. "\"): no such group — units.lua Grouped(...) declares the mission's groups"
				)
				assert(
					type(team) == "table" and type(team.teamID) == "number",
					label .. " expects a Team handle (e.g. Team.Player)"
				)
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
