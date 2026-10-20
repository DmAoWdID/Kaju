# Technical Architecture

Rojo project: `default.project.json` (Rojo 7.7.1).

| Source | Roblox location | Contents |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Config, species data, pure rules, remotes list, visuals |
| `src/server` | `ServerScriptService.Server` | `Main` script, services, world builder |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | `Main` LocalScript, controllers, UI |
| `tests` | (not synced) | Pure-Luau unit tests run with the `luau` CLI |

## Layers

```
shared/  (no server secrets; safe to replicate)
  Types.luau                   Species vs OwnedKaiju vs PlayerData types
  Config/GameConfig.luau       ALL tunable numbers (provisional), one file
  Data/KaijuSpecies.luau       18 species, verbatim from Docs/Kaju game.pdf
  Data/KaijuValidator.luau     Reports missing fields, bad types, duplicates, total mismatches
  Data/KaijuRegistry.luau      Validated, frozen lookup: get / all / byKL
  Progression/Progression.luau KL economy, chains, enclosure fit, level costs, spawn rolls
  Combat/CombatEngine.luau     Deterministic turn resolution + AI (no Roblox APIs)
  PlayerData/PlayerDataSchema  Defaults, reconcile/migrate, id allocation
  Net/Remotes.luau             Endpoint names (server creates, client waits)
  Visual/                      Palette, KaijuModelFactory (placeholder models)

server/Services/
  NetService       one RemoteFunction "Request" -> action handlers; rate limit; error isolation
  DataService      load/save (DataStore + session lock, or memory in Studio), replication
  KaijuCollection  starter grant, leveling with Kaiju Cells
  ParkService      plots, enclosure placement, housing kaijus, passive income, travel
  ShopService      chain upgrades
  WildKaijuService spawns/wander, ProximityPrompt (E), engage/release/remove locks
  BattleService    battle sessions: select -> fight -> reward -> ended
server/World/WorldBuilder  hub, bridge, wilds, park plots (placeholder geometry)

client/
  Controllers/ClientState      read-only mirror of player data; request() helper
  Controllers/BuildController  enclosure placement mode (mouse + touch raycast)
  UI/ Hud, BattleUI, CollectionUI, ShopUI, Toasts, KaijuViewport, UIKit
```

Pure modules (`shared/Config`, `Data`, `Progression`, `Combat`, `PlayerData`, `Types`) use only relative string requires (`require("../Config/GameConfig")`). They run unchanged in Roblox and under the standalone `luau` CLI, which is how `tests/` covers them. Roblox-side modules use instance requires (`require(Shared.Config.GameConfig)`).

## Species vs owned instances

- **Species** (`KaijuSpecies`): documented, immutable, frozen data keyed by a stable id (`"kragmor"`, `"obio_16"`, …).
- **Owned kaiju** (`PlayerData.kaijus[instanceId]`): `{ instanceId, speciesId, level, capturedAt }`. Stats are always read from the species via the registry, never copied into saves.
- **KL** belongs to the species; **level** (1–40) belongs to the owned instance.

## Data flow

```
Client button -> Request(action, payload) -> NetService (shape check, rate limit)
              -> Service handler (validate ids, ownership, phase, price from config)
              -> mutate PlayerData -> DataService.replicate(player, "full"|"currency")
              -> StateSync -> ClientState -> UI refresh
Battles additionally push BattleSync snapshots (display values only).
```

The server is authoritative for battle outcomes, rewards, captures, money, Kaiju Cells, ownership, placement, prices and progression. Clients only send intents (`{action = "Attack"}`, `{choice = "capture"}`, `{sizeId, slot}`).

Double-reward protection: a battle session's `resolved` flag is set before any reward is applied, and the session is then removed. A wild kaiju can be engaged by only one player at a time.

## Persistence

`DataService` keys: `player_<UserId>` in DataStore `KaijuPark_PlayerData_v1`. Record: `{ data, lock = {jobId, time}, savedAt }`.
- Load claims the lock. If another live server holds it (newer than 30 min), the player is retried, then kicked with a message.
- Saves refuse to write if another server owns the lock.
- `PlayerDataSchema.reconcile` sanitises loaded data. If the save comes from a newer schema version, the session is marked non-persistent.
- Autosave every 90 s, on leave, and on `BindToClose`.

## Placeholder models

Each species has a hand-built part model in `src/shared/Visual/KaijuDesigns.luau`, drawn from its concept sheet using the primitives in `ModelKit.luau` (tapered tubes along curves, 3D triangles for wings/fins/crests, spikes, flat blades, eyes, teeth). The factory rescales every design so size follows KL (`GameConfig.KL[n].modelScale` x `species.visual.scale`). Species without a design fall back to a generic body plan (`visual.archetype`), which is also the only thing that decides whether a wild kaiju hovers.

### Replacing placeholder models

Add `ReplicatedStorage.KaijuModels.<speciesId>` (a Model with its pivot at the feet, facing −Z). `KaijuModelFactory.build` will clone it instead of generating parts. The world, park and UI portraits all use the factory.
