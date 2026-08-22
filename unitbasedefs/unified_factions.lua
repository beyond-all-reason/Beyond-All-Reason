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

local function NormalizeDisplayName(Display)
	if string.sub(Display, 1, 7) == "Legion " then
		return string.sub(Display, 8)
	end
	return Display
end

local function LoadDisplayNames()
	local Loaded, Raw = pcall(VFS.LoadFile, "language/en/units.json")
	if not Loaded or type(Raw) ~= "string" then
		return {}
	end

	local Decoded, Parsed = pcall(function()
		return VFS.Include("common/luaUtilities/json.lua").decode(Raw)
	end)
	if not Decoded or type(Parsed) ~= "table" then
		return {}
	end

	local Units = Parsed.units
	if type(Units) ~= "table" or type(Units.names) ~= "table" then
		return {}
	end
	return Units.names
end

local function BuildDisplayIndex(AllUnitDefs, DisplayNames)
	local Index = { Mobile = {}, Static = {} }

	for UnitName, UnitDef in pairs(AllUnitDefs) do
		local Prefix = GetFactionPrefix(UnitName)
		local Display = DisplayNames[UnitName]

		if Prefix ~= nil and Display ~= nil and not IsScavengerName(UnitName) and not IsCommanderDef(UnitDef) then
			local Kind = IsMobileDef(UnitDef) and Index.Mobile or Index.Static
			local Key = NormalizeDisplayName(Display)

			if Kind[Prefix] == nil then
				Kind[Prefix] = {}
			end

			if Kind[Prefix][Key] == nil then
				Kind[Prefix][Key] = UnitName
			else
				Kind[Prefix][Key] = false
			end
		end
	end

	return Index
end

local function FindOwnByDisplay(Context, OptionName, OptionDef, OwnPrefix)
	local Display = Context.DisplayNames[OptionName]
	if Display == nil then
		return nil
	end

	local Kind = IsMobileDef(OptionDef) and Context.DisplayIndex.Mobile or Context.DisplayIndex.Static
	local OwnBucket = Kind[OwnPrefix]
	if OwnBucket == nil then
		return nil
	end

	local Match = OwnBucket[NormalizeDisplayName(Display)]
	if Match then
		return Match
	end
	return nil
end

local function ResolveOption(Context, OptionName, OwnPrefix)
	local AllUnitDefs = Context.UnitDefs
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
		return FindOwnByDisplay(Context, OptionName, OptionDef, OwnPrefix) or OptionName
	end

	local OwnVariant = OwnPrefix .. GetBaseName(OptionName)
	if AllUnitDefs[OwnVariant] ~= nil then
		return OwnVariant
	end

	return FindOwnByDisplay(Context, OptionName, OptionDef, OwnPrefix) or OptionName
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

local function BuildMergedOptions(Context, GroupMembers, OwnPrefix)
	local MergedOptions = {}
	local SeenOptions = {}

	local function AppendFrom(SourceName)
		local SourceDef = Context.UnitDefs[SourceName]
		if SourceDef == nil then
			return
		end

		for _, OptionName in ipairs(GetOrderedOptions(SourceDef.buildoptions)) do
			local Resolved = ResolveOption(Context, OptionName, OwnPrefix)
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
	local DisplayNames = LoadDisplayNames()
	local Context = {
		UnitDefs = AllUnitDefs,
		DisplayNames = DisplayNames,
		DisplayIndex = BuildDisplayIndex(AllUnitDefs, DisplayNames),
	}

	local BuilderGroups = CollectBuilderGroups(AllUnitDefs)
	local MergedResults = {}

	for _, GroupMembers in pairs(BuilderGroups) do
		for OwnPrefix, BuilderName in pairs(GroupMembers) do
			MergedResults[BuilderName] = BuildMergedOptions(Context, GroupMembers, OwnPrefix)
		end
	end

	for BuilderName, MergedOptions in pairs(MergedResults) do
		AllUnitDefs[BuilderName].buildoptions = MergedOptions
	end
end

return {
	Apply = ApplyUnifiedFactions,
}
