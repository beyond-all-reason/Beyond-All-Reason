-- Transfer's api in the synced handle: what a gadget may ask of the module that touches the synced engine.
local Synced = {}

Synced.Units = require("modules/transfer/unit/synced")
Synced.Resources = require("modules/transfer/resource/synced")

return Synced
