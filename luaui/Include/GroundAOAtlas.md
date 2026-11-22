# Ground AO plate images

The unit and feature AO widgets use their existing compressed DDS atlases plus
one engine-built atlas each for additional PNG images. Adding a PNG does not
require rebuilding or changing the precompiled atlas. Restart/reload LuaUI after
adding content; the runtime atlas is built once during widget initialization.

For automatic matching, place images in the relevant directory (subdirectories
are also searched):

```text
unittextures/decals/<model>_<x>_<z>_aoplane.png
unittextures/decals_features/<model>_<x>_<z>_aoplane.png
```

The model is the model file's basename without its extension, including `_dead`
for a wreck. The definition's internal name is tried if the model has no match.
Matching is case insensitive. Two different size-bearing images matching the
same model require an explicit texture reference to disambiguate them.

X and Z describe the **full physical plate dimensions divided by 16**, in that
order. They are independent of the PNG's pixel dimensions. For example,
`my_factory_10_8_aoplane.png` covers 160 by 128 elmos. Positive decimal values are
supported. The Blender GLB AO baker doubles its gameplay footprint when making
the plate: a 3 by 3 footprint produces a 6 by 6 plate, named
`my_model_6_6_aoplane.png`.

Use RGBA PNGs with black RGB, occlusion/darkness in alpha, and transparent edges.
Keep the existing AO plate orientation; the resolver handles the difference
between legacy DDS manifest coordinates and runtime PNG coordinates.

Explicit parameters take precedence:

| Definition | Texture | X dimension | Z dimension | Alpha |
|---|---|---|---|---|
| Unit customParams | `buildinggrounddecaltype` | `buildinggrounddecalsizex` | `buildinggrounddecalsizey` | `buildinggrounddecalalpha` |
| Feature customParams | `decalinfo_texfile` | `decalinfo_sizex` | `decalinfo_sizez` | `decalinfo_alpha` |

Unit references such as `decals/my_plate.png`, full VFS paths, and legacy feature
basename references are supported. Explicitly referenced PNGs may live outside
the conventional directories and do not need size-bearing filenames if their
dimensions are configured. An unresolved explicit reference is reported rather
than replaced with another image. Unit `usebuildinggrounddecal` values `false`,
`0`, `"false"`, and `"0"` disable automatic as well as explicit plates.

Legacy unsized prebuilt entries keep working with their configured dimensions.
Automatic matching can borrow dimensions from other explicit users of the same
image when those users agree. Otherwise physical sizes must be supplied; pixel
dimensions are never used to guess them. Legacy explicit features retain the
5 by 5 dimension default when no other size metadata exists.

An extension-equivalent image already in the prebuilt manifest is sampled from
that manifest. After an eventual offline atlas rebuild, the corresponding PNG
automatically stops entering the runtime atlas. The manifest has no source
hashes, so replacing an already baked image under the same name does not update
its baked copy; use a distinct reference or rebuild the atlas for replacements.

The runtime path uses the engine's legacy allocator (one mip level, transparent
spacing, texel-center UVs) and respects engine/GPU size limits. Existing DDS mip
chains remain unchanged. Missing APIs, invalid PNGs, or capacity failure leave
prebuilt plates available and report unavailable runtime coverage in the log.
Runtime textures are deleted when their owning widget shuts down.

For rendering verification, check a new rectangular/asymmetric image on a unit
and a feature without AO custom parameters, alongside prebuilt plates. Check
zoomed-out filtering, rotation, unit glow, feature alpha, visibility changes,
and widget reload. Repeat with the primitive renderer's geometry-shader path
disabled to exercise its vertex-only fallback.
