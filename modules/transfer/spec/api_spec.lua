---@type table spec/builders is kept out of the checker (#8856), so the builders are untyped here
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = require("modules/construction/enums")
local ResourceShared = require("modules/transfer/resource/shared")
local TransferEnums = require("modules/transfer/enums")
local UnitShared = require("modules/transfer/unit/shared")
