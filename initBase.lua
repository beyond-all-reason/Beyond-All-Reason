-- This file holds common Lua functionality that should be available globally
-- Do not VFS.Include() this file, instead include init.lua, and only
-- include this file in environments where Spring is not available

VFS.Include('common/numberfunctions.lua')
VFS.Include('common/stringFunctions.lua')