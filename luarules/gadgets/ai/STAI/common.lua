if not CommonFunctionsLoaded then
	shard_include ("commonfunctions")
end
if not ai.data.unitTable or not featureTable then
	ai.data.unitTable, featureTable = shard_include("getunitfeaturetable")
end

if not UnitListsLoaded then
	shard_include ("unitlists")
end
