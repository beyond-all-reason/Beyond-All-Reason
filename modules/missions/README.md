# The missions module

Mission logic is authored as dot-only, closure-free trigger chains in
missions/<name>/triggers/*.lua. The loader includes each file in an injected
environment (the env IS the API surface), the DSL builds descriptors, and the
trigger engine evaluates them — event-driven where conditions declare inputs,
polling as the fallback. Effects are lazy objects executed when a condition
fires; matchflow owns the game-over verdict.

```mermaid
flowchart TB
    LUA["missions/&lt;name&gt;/triggers/*.lua<br/>dot-only, closure-free chains"]
    subgraph SYNCED["synced runtime"]
        LOADER["mission_loader gadget<br/>injected env = the API surface;<br/>wires only watched callins"]
        DSL["DSL builder<br/>When/AndWhen/Do/Once/Register<br/>→ TriggerDescriptor"]
        ENGINE["trigger engine<br/>input→watchers index · dirty marks<br/>state tables (the save pile)"]
        BUS["event bus (engine.OnEvent)<br/>engine callins + module events<br/>('UnitFinished', 'mission.objective_changed')"]
        MF["matchflow module<br/>Victory/Defeat → pending verdict"]
        VG["verdict gadget<br/>deferred, idempotent Spring.GameOver"]
    end
    LUA -->|"VFS.Include per file<br/>(hot reload by identity)"| LOADER
    LOADER --> DSL -->|"descriptors"| ENGINE
    LOADER -->|"forward watched callins"| BUS --> ENGINE
    ENGINE -->|"execute effects"| MF
    ENGINE -->|"Objective(...).Complete() emits<br/>'mission.objective_changed'"| BUS
    MF --> VG
```
