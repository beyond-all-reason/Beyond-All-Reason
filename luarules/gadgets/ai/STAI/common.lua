	if not CommonFunctionsLoaded then
		shard_include ("commonfunctions")
	end
	if not unitTable or not featureTable then
		unitTable, featureTable = shard_include("getunitfeaturetable")
	end

	if not UnitListsLoaded then
		shard_include ("unitlists")
	end
