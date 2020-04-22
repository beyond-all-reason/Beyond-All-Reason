

function shard_include( file )
	if type(file) ~= 'string' then
		return nil
	end
	return require( file )
end

-- load null objects
require "shard_runtime/hooks"
require "shard_runtime/class"
require "shard_runtime/aibase"
require "shard_runtime/module"
shard_include "shard_runtime/shard_null/unit"
shard_include "shard_runtime/shard_null/unittype"