---
--- Flattens an action/trigger definition into one comparable table, so specs can
--- assert a whole schema in a single `assert.are.same`. A trailing '!' marks a
--- required parameter.
---
---     --> { type = 'AddMarker', position = 'Position!', label = 'String' }
---
return function(definition)
	local summary = { type = definition.type }
	for _, parameter in ipairs(definition.parameters) do
		summary[parameter.name] = parameter.type .. (parameter.required and '!' or '')
	end
	summary.requiresOneOf = definition.parameters.requiresOneOf
	return summary
end
