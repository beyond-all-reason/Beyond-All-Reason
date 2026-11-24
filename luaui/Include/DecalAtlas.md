# Incremental normalmapped decals

`gfx_decals_gl4.lua` keeps the prebuilt diffuse and normal DDS atlases and builds
two additional atlases for PNG pairs absent from the baked manifests. Place pairs
anywhere under `luaui/images/decals_gl4/`, including subdirectories:

```text
groundScars/my_scar_a.png
groundScars/my_scar_n.png
footprints/my_footprint_a.png
footprints/my_footprint_n.png
```

Each albedo (`_a.png`) must have a normal (`_n.png`) with the same pixel dimensions.
The normal image's alpha channel supplies emission. Auxiliary height, ORM and AO
images are ignored. Paths are matched case insensitively, with subdirectories
preserved. Existing baked PNG and TGA entries remain available; an
extension-equivalent baked pair takes precedence over loose PNGs.

The resolver sorts pairs once and inserts their images into two engine atlases
in the same order, with identical settings. This relies on the engine placing
equal-sized inputs in matching positions. Both atlases must build successfully
before any runtime entries are exposed. Failures retain baked coverage and log
the unavailable runtime coverage. Atlases respect engine/GPU limits and use the
legacy allocator's single mip level, transparent gutters and texel-center UVs.

Reload LuaUI after adding files. Registering an image does not automatically add
it to explosion choices or unit footprints: reference its full albedo path in
the relevant configuration or pass it to `WG.decalsgl4.AddDecalGL4`. Physical
decal dimensions continue to come from the caller, independently of pixel size.

Both images use the same UVs, orientation and proportional edge inset. Baked UVs
are copied, so widget reloads never repeatedly modify the cached manifests.
Reload saves include texture identities and footprint flips, allowing fresh UVs
to be resolved after repacking or a later offline atlas rebuild. Old UV-only
saves continue to refer to the baked atlas.

Legacy consumers, including PIP, receive only baked decals from `GetVBOData` and
`RebuildActiveDecalData`. The world renderer retains mixed baked/runtime instance
order. Filtered export buffers are allocated only on demand for VBOs containing
runtime decals, and are released with the widget's runtime atlases on shutdown.
