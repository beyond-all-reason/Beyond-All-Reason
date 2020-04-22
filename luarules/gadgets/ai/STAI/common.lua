	if not CommonFunctionsLoaded then
		shard_include ("commonfunctions",subf)
	end
	if not unitTable or not featureTable then
		unitTable, featureTable = shard_include("getunitfeaturetable",subf)
	end

	if not UnitListsLoaded then
		shard_include ("unitlists",subf)
	end
