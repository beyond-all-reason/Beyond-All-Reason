---@meta

--- What a reference into the world points at, as the engine names it: the string
--- `Spring.TraceScreenRay` returns alongside a hit, and the discriminator that
--- says whether an accompanying ID is a unitID, a featureID, or a position.
--- A trace called with `includeSky` can also answer `"sky"`, so those call sites
--- want `WorldObjectType|"sky"`.
---@alias WorldObjectType "unit"|"feature"|"ground"
