# types/recoil

The engine as a type per Lua handle: `Recoil` (the union, what `Spring` is typed as), `Recoil.Shared`,
`Recoil.Synced : Recoil.Shared` and `Recoil.Unsynced : Recoil.Shared`. These files are not written here: they are
`rts/Lua/handles/` as RecoilEngine PR #2799's `lua_library` task writes it, vendored byte for byte, and the same
directory recoil-lua-library will carry as `handles/` once that lands. Until then `.emmyrc.json` lists this directory
as a library and ignores the submodule's flat listings.

- RecoilEngine `lua-library-types` at 8973ddeef8 (on master cd973c9cc1), 2026-10-19
- lua-doc-extractor `contexts` at fbebe26534 (rhys-vdw/lua-doc-extractor#77), on 3.3.5

The engine's docs carry `@env` tags naming the handles that register each entry; the extractor's `--env` routes
them into one file per handle, and each file opens with the engine's header that makes its functions members of
that handle's class. To refresh, from the engine checkout's root with the extractor built from #77:

```sh
lua-doc-extractor --src 'rts/{Lua,Rml/SolLua,Sim/Units/Scripts}/**/*.cpp' --dest <out> --repo https://github.com/beyond-all-reason/RecoilEngine/blob/master \
  --env synced=synced.lua --env unsynced=unsynced.lua --env synced,unsynced=shared.lua
for h in shared synced unsynced; do cat rts/Lua/handles/$h.header <out>/$h.lua > <BAR>/types/recoil/generated/$h.lua; done
cp rts/Lua/handles/Spring.lua <BAR>/types/recoil/
cd <BAR> && luajit tools/engine_handles/generate.lua
```

`modules/engine_handles.lua`, the functions and globals one handle registers alone, is derived from
`generated/synced.lua` and `generated/unsynced.lua` by that last step; `spec/modules/engine_handles_spec.lua` fails
when it drifts.
