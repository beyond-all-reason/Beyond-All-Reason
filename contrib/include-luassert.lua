--local oldrequire = require
require = VFS.Include("contrib/require.lua")

assert = require("luassert")

--require = oldrequire

return assert
