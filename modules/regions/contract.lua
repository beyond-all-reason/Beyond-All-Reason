local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class Region a contained area of the map. Holds only the shape; the module that owns a type extends this record with the type's fields
---@field type RegionTypeKey
---@field id string|nil identity. Assigned by RegionsApi.Create and carried through the layout codec and the editor's files; nil only for regions that came from the startbox shim
---@field vertices { x: number, z: number }[]|nil in elmos. One vertex is a point, three or more a polygon (see RegionGeometry.Of). nil while the region is still being drawn
---@field tags string[]|nil free-form tags not claimed by any type
---@field name string|nil display name. When nil, derived by the type's owner (see RegionsApi.Names)

---@class RegionCheckContext the context for checking one region. Problems accumulate rather than short-circuiting, so a form can show all of them
---@field type RegionType the region's type descriptor
---@field region Region
---@field siblings Region[] the other regions of the same type
---@field names table<Region, string> display name of the region and each sibling, derived where none is set
---@field fieldsOnly boolean|nil skip the shape checks; used while the region is being drawn and has no vertices yet
---@field problems string[]

---@class RegionCheckStages: PolicyStages<RegionCheckContext, RegionCheckContext>
---@field Shape string the geometry is one the type allows, and is well-formed
---@field Fields string required fields are set; unique fields do not repeat among siblings

---@type RegionCheckStages
local Check = {
	Shape = "Shape",
	Fields = "Fields",
}

---@class RegionNamesContext the context for naming every region of one type. Stages fill in a base name for each region that has none
---@field type RegionType
---@field regions Region[]
---@field bases string[] base name per region, by index, for regions with no name of their own. Siblings that share a base are numbered afterwards

---@class RegionNamesStages: PolicyStages<RegionNamesContext, RegionNamesContext> the module that owns a type contributes the stage that names that type's regions
---@field Label string fallback: the type's label

---@type RegionNamesStages
local Names = {
	Label = "Label",
}

---@class RegionProblem one problem found in a set of regions
---@field message string
---@field region Region|nil the region the problem is about; nil when it concerns the set as a whole
---@field name string|nil display name of that region
---@field at { x: number, z: number }|nil map position of the problem, when the rule that found it has one

---@class RegionSetContext the context for checking every region of one type as a set. Problems accumulate (see RegionProblems)
---@field type RegionType
---@field regions Region[]
---@field names string[] display name per region, by index, derived where none is set
---@field env table caller-supplied map data, passed through untouched. The regions module does not read it; each type's owner documents the keys its stages expect (StartRegionEnv, MexRegionEnv)
---@field problems RegionProblem[]

---@class RegionSetStages: PolicyStages<RegionSetContext, RegionSetContext> rules over the whole set. The module that owns a type contributes its own stages, such as coverage
---@field Each string runs the type's Check on every region against its siblings; each problem is attributed to its region

---@type RegionSetStages
local CheckSet = {
	Each = "Each",
}

---@class RegionDescribeContext the context for building the label/value lines shown for one region
---@field type RegionType
---@field region Region
---@field env table caller-supplied map data, passed through untouched, as in RegionSetContext
---@field lines { [1]: string, [2]: string }[] { label, value } pairs, in the order the stages add them

---@class RegionDescribeStages: PolicyStages<RegionDescribeContext, RegionDescribeContext> the lines shown for a region. The module that owns a type adds the lines only it can compute
---@field Shape string the area (elmos squared, 0 for a point) and the centre (vertex centroid, or the point itself)

---@type RegionDescribeStages
local Describe = {
	Shape = "Shape",
}

---@class RegionsPipelines the return value of LoadPolicies("regions")
---@field check AssembledPipeline<RegionCheckContext, RegionCheckContext>
---@field check_set AssembledPipeline<RegionSetContext, RegionSetContext>
---@field names AssembledPipeline<RegionNamesContext, RegionNamesContext>
---@field describe AssembledPipeline<RegionDescribeContext, RegionDescribeContext>

---@class RegionsContract
---@field Check RegionCheckStages
---@field CheckSet RegionSetStages
---@field Names RegionNamesStages
---@field Describe RegionDescribeStages

return PolicyBuilder.Contract(Modules.Regions, {
	Check = PolicyBuilder.Fold(Check),
	CheckSet = PolicyBuilder.Fold(CheckSet),
	Names = PolicyBuilder.Fold(Names),
	Describe = PolicyBuilder.Fold(Describe),
})
