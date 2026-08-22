local FactionPrefixes = { "arm", "cor", "leg" }

local FactionLookup = {}
for Index = 1, #FactionPrefixes do
	FactionLookup[FactionPrefixes[Index]] = true
end

local function GetFactionPrefix(UnitName)
	local Prefix = string.sub(UnitName, 1, 3)
	if FactionLookup[Prefix] then
		return Prefix
	end
	return nil
end

local function GetBaseName(UnitName)
	return string.sub(UnitName, 4)
end

local function IsScavengerName(UnitName)
	return string.sub(UnitName, -5) == "_scav"
end

local function IsMobileDef(UnitDef)
	return UnitDef.speed ~= nil and UnitDef.speed > 0
end

local function IsCommanderDef(UnitDef)
	local CustomParams = UnitDef.customparams
	return CustomParams ~= nil and CustomParams.iscommander == true
end

local function GetOrderedOptions(BuildOptions)
	local Keys = {}
	for Key in pairs(BuildOptions) do
		Keys[#Keys + 1] = Key
	end
	table.sort(Keys)

	local Ordered = {}
	for Index = 1, #Keys do
		Ordered[Index] = BuildOptions[Keys[Index]]
	end
	return Ordered
end

local function ResolveOption(AllUnitDefs, OptionName, OwnPrefix)
	local OptionDef = AllUnitDefs[OptionName]
	if OptionDef == nil then
		return nil
	end

	if IsCommanderDef(OptionDef) then
		return nil
	end

	local OptionPrefix = GetFactionPrefix(OptionName)
	if OptionPrefix == nil or OptionPrefix == OwnPrefix then
		return OptionName
	end

	if IsMobileDef(OptionDef) then
		return OptionName
	end

	local OwnVariant = OwnPrefix .. GetBaseName(OptionName)
	if AllUnitDefs[OwnVariant] ~= nil then
		return OwnVariant
	end

	return OptionName
end

local function CollectBuilderGroups(AllUnitDefs)
	local BuilderGroups = {}

	for UnitName, UnitDef in pairs(AllUnitDefs) do
		if not IsScavengerName(UnitName) then
			local Prefix = GetFactionPrefix(UnitName)
			local BuildOptions = UnitDef.buildoptions

			if Prefix ~= nil and BuildOptions ~= nil and next(BuildOptions) ~= nil then
				local BaseName = GetBaseName(UnitName)
				if BuilderGroups[BaseName] == nil then
					BuilderGroups[BaseName] = {}
				end
				BuilderGroups[BaseName][Prefix] = UnitName
			end
		end
	end

	return BuilderGroups
end

local function BuildMergedOptions(AllUnitDefs, GroupMembers, OwnPrefix)
	local MergedOptions = {}
	local SeenOptions = {}

	local function AppendFrom(SourceName)
		local SourceDef = AllUnitDefs[SourceName]
		if SourceDef == nil then
			return
		end

		for _, OptionName in ipairs(GetOrderedOptions(SourceDef.buildoptions)) do
			local Resolved = ResolveOption(AllUnitDefs, OptionName, OwnPrefix)
			if Resolved ~= nil and not SeenOptions[Resolved] then
				SeenOptions[Resolved] = true
				MergedOptions[#MergedOptions + 1] = Resolved
			end
		end
	end

	AppendFrom(GroupMembers[OwnPrefix])

	for Index = 1, #FactionPrefixes do
		local OtherPrefix = FactionPrefixes[Index]
		if OtherPrefix ~= OwnPrefix and GroupMembers[OtherPrefix] ~= nil then
			AppendFrom(GroupMembers[OtherPrefix])
		end
	end

	return MergedOptions
end

local function ApplyUnifiedFactions(AllUnitDefs)
	local BuilderGroups = CollectBuilderGroups(AllUnitDefs)
	local MergedResults = {}

	for _, GroupMembers in pairs(BuilderGroups) do
		for OwnPrefix, BuilderName in pairs(GroupMembers) do
			MergedResults[BuilderName] = BuildMergedOptions(AllUnitDefs, GroupMembers, OwnPrefix)
		end
	end

	for BuilderName, MergedOptions in pairs(MergedResults) do
		AllUnitDefs[BuilderName].buildoptions = MergedOptions
	end
end

return {
	Apply = ApplyUnifiedFactions,
}
