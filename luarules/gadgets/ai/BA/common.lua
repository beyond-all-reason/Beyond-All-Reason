shard_include "unitlists"
if ShardSpringLua then
	if not unitTable or not featureTable then
		unitTable, featureTable = shard_include("getunitfeaturetable")
	end
	if not CommonFunctionsLoaded then
		shard_include "commonfunctions"
	end
	if not UnitListsLoaded then
		shard_include "unitlists"
	end
else
	shard_include "unitlists"
	shard_include("unittable-" .. game:GameName())
	shard_include("featuretable-" .. game:GameName())
	shard_include "commonfunctions"
end
