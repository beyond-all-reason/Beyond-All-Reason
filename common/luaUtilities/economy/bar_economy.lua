local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceType = SharedEnums.ResourceType
local BarEconomy = VFS.Include("common/luaUtilities/team_transfer/bar_economy.lua")

local RESOURCE_NAME_TO_TYPE = {
	[ResourceType.METAL] = ResourceType.METAL,
	[ResourceType.ENERGY] = ResourceType.ENERGY,
	metal = ResourceType.METAL,
	m = ResourceType.METAL,
	e = ResourceType.ENERGY,
	energy = ResourceType.ENERGY,
}

local STORAGE_NAME_TO_TYPE = {
	ms = ResourceType.METAL,
	metalStorage = ResourceType.METAL,
	es = ResourceType.ENERGY,
	energyStorage = ResourceType.ENERGY,
}

function BarEconomy.resolveResource(resource)
	if resource == nil then
		error("resource identifier is required", 3)
	end

	local storageType = STORAGE_NAME_TO_TYPE[resource]
	if storageType then
		return storageType, true
	end

	local resolved = RESOURCE_NAME_TO_TYPE[resource]
	if resolved then
		return resolved, false
	end

	error(("unsupported resource identifier '%s'"):format(tostring(resource)), 3)
end

function BarEconomy.ensureResourceType(resource)
	local resolved, isStorage = BarEconomy.resolveResource(resource)
	if isStorage then
		error("resource identifier requires a resource type (metal or energy)", 3)
	end
	return resolved
end

function BarEconomy.attachResourceAliases(metalSnapshot, energySnapshot)
	local data = {
		metal = metalSnapshot,
		energy = energySnapshot,
	}
	data[ResourceType.METAL] = data.metal
	data[ResourceType.ENERGY] = data.energy
	return data
end

function BarEconomy.getTeamResourceData(springRepo, teamID, resource)
	if resource ~= nil then
		local resolved = BarEconomy.ensureResourceType(resource)
		return springRepo.GetTeamResourceData(teamID, resolved)
	end

	return BarEconomy.attachResourceAliases(
		springRepo.GetTeamResourceData(teamID, ResourceType.METAL),
		springRepo.GetTeamResourceData(teamID, ResourceType.ENERGY)
	)
end

function BarEconomy.setTeamResourceData(springRepo, teamID, resourceData)
	return springRepo.SetTeamResourceData(teamID, resourceData)
end

function BarEconomy.setTeamResource(springRepo, teamID, resource, amount)
	local resolved, isStorage = BarEconomy.resolveResource(resource)
	local data = { resourceType = resolved }

	if isStorage then
		data.storage = amount
	else
		data.current = amount
	end

	springRepo.SetTeamResourceData(teamID, data)
end

function BarEconomy.getTeamResources(springRepo, teamID, resource)
	local resolved, isStorage = BarEconomy.resolveResource(resource)
	local snapshot = springRepo.GetTeamResourceData(teamID, resolved)

	if isStorage then
		local storage = snapshot.storage
		return storage, storage
	end

	return snapshot.current,
		snapshot.storage,
		snapshot.pull,
		snapshot.income,
		snapshot.expense,
		snapshot.shareSlider,
		snapshot.sent,
		snapshot.received
end

function BarEconomy.addTeamResource(springRepo, teamID, resource, amount)
	local resolved = BarEconomy.ensureResourceType(resource)
	local snapshot = springRepo.GetTeamResourceData(teamID, resolved)
	springRepo.SetTeamResourceData(teamID, {
		resourceType = resolved,
		current = snapshot.current + amount,
	})
end

function BarEconomy.shareTeamResource(springRepo, teamID, targetTeamID, resource, amount)
	local resolved = BarEconomy.ensureResourceType(resource)
	local donor = springRepo.GetTeamResourceData(teamID, resolved)
	local recipient = springRepo.GetTeamResourceData(targetTeamID, resolved)

	local transfer = math.min(amount, donor.current)
	if transfer <= 0 then
		return
	end

	springRepo.SetTeamResourceData(teamID, {
		resourceType = resolved,
		current = donor.current - transfer,
	})

	springRepo.SetTeamResourceData(targetTeamID, {
		resourceType = resolved,
		current = math.min(recipient.storage, recipient.current + transfer),
	})
end

function BarEconomy.setTeamShareLevel(springRepo, teamID, resource, level)
	local resolved = BarEconomy.ensureResourceType(resource)
	springRepo.SetTeamResourceData(teamID, {
		resourceType = resolved,
		shareSlider = math.max(0, math.min(1, level or 0)),
	})
end

function BarEconomy.getTeamShareLevel(springRepo, teamID, resource)
	local resolved = BarEconomy.ensureResourceType(resource)
	local snapshot = springRepo.GetTeamResourceData(teamID, resolved)
	return snapshot.shareSlider
end

return BarEconomy

