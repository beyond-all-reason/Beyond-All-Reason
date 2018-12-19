local wreck_metal = 2500
if (Spring.GetModOptions) then
    wreck_metal = Spring.GetModOptions().comm_wreck_metal or 2500
end

return {
   xmascomwreck = {
       blocking = true,
       collisionvolumeoffsets = "0 0 0",
       collisionvolumescales = "47 10 47",
       collisionvolumetype = "CylY",
       damage = 10000,
       description = "Xmas Commander Wreckage",
       energy = 0,
       featuredead = "HEAP",
       featurereclamate = "SMUDGE01",
       footprintx = 2,
       footprintz = 2,
       height = 20,
       hitdensity = 100,
       metal = wreck_metal,
       object = "gingerbread",
       reclaimable = true,
       seqnamereclamate = "TREE1RECLAMATE",
    },
}