---
--- Team parameter validators: TeamID, AllyTeamID and AllyTeamIDs.
---

local validatorUtils = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua')
local getListValidator = validatorUtils.GetListValidator
local getLookupValidator = validatorUtils.GetLookupValidator

local function register(parameterValidators, context)
	local Types = context.Types
	local validateNumber = parameterValidators[Types.Number]

	parameterValidators[Types.TeamID] = getLookupValidator(validateNumber, 'teamID',
		function(teamID) return Spring.GetTeamAllyTeamID(teamID) end)

	parameterValidators[Types.AllyTeamID] = getLookupValidator(validateNumber, 'allyTeamID',
		function(allyTeamID) return table.contains(Spring.GetAllyTeamList(), allyTeamID) end)

	parameterValidators[Types.AllyTeamIDs] = getListValidator(parameterValidators[Types.AllyTeamID], "allyTeamIDs table is empty")
end

return {
	Register = register,
}
