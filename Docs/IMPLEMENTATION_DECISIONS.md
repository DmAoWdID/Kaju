# Implementation Decisions & Open Questions

Source documents: `Docs/message.txt` (game design document, Swedish) and `Docs/Kaju game.pdf` (kaiju reference, 18 pages).
Everything below is **provisional** unless marked otherwise. All numbers live in `src/shared/Config/GameConfig.luau`; change them there.

## Source document notes

- **`Docs/message.txt` is truncated.** It ends mid-sentence in section 15 ("Steg 3: Interaktion och strid … Gör så att spelaren kan gå fram till kaij"). The rest of the recommended development order is missing. **Please supply the full text.**
- Kaiju data was extracted from the PDF text layer and cross-checked against rendered pages. For all 18 species, the five stats add up exactly to the documented "Total" (automated test).

### Kaiju data uncertainties (values preserved as written, not corrected)

| Species | Note |
|---|---|
| Popcorn | Page shows a small unexplained label **"supergiant star"** above the name. Not stored as data; recorded in `notes`. |
| Eye bat | PDF spells **"Eye bat"**; the GDD table spells "Eye Bat". `displayName` uses the PDF; "Eye Bat" is in `nameVariants`. Trait **"Comp"** may be a typo (for "Chomp"?), kept as written. |
| Great tusk | PDF **"Great tusk"** vs GDD "Great Tusk". Same handling as Eye bat. |
| Wormhole | Mobility written **"50 (150)"**. `stats.mobility = 50` (matches the Total 360); the raw text is kept in `statAnnotations.mobility`. Meaning of 150 is unknown (burrowing speed?). Trait **"Distance Traveling\*"** has an asterisk with no footnote. |
| Obio 16 | Biohazard icon next to the name (recorded in `notes`). Trait "Het detector" kept as written (heat?). |
| Night Angel | Length given as Body ~17m / Tail ~15m rather than one value. Stored as two dimensions. |
| Spellings kept verbatim | "Tung trap", "Hed stab", "Arme slash", "Atomic breathe", "Scretche", "Horne tackel", "Pinche", "Telepathic(hive mind)", "Cutsie", "Jellqouia". |
| Threat vs KL | Cataboulder (KL4) has threat 4.2, which is lower than Obio 16 (KL3, 4.8). Not an error; threat rating and KL are independent values. |

Real-world dimensions are informational only. In-game model scale comes from `GameConfig.KL[n].modelScale` × `species.visual.scale`.

## Provisional gameplay decisions

### D-01 Starter kaiju (not in GDD)
The GDD has players fight with their own kaijus but doesn't say how the first one is obtained. New players get **one Kragmor (level 1)** housed in **one free Small enclosure** at park slot 1 (`GameConfig.Starter`). This lets the first battle and the park/income loop work immediately.
*Open question:* intended way to get the first kaiju (starter choice? tutorial capture?).

### D-02 Battle team size = 1
The GDD says the team size "should be decided during development". Each side uses one kaiju (`Combat.teamSize`, not yet used beyond 1). Before each battle the player picks which owned kaiju fights.

### D-03 Stat → combat mapping (GDD says stats should matter, gives no formula)
| Stat | Provisional use |
|---|---|
| Durability | `maxHp = 20 + 3 × Durability` |
| Damage | damage per AP = `4 + 0.5 × Damage` |
| Mobility | turn order within a round (higher acts first; ties go to the player) |
| Stamina | max AP = `min(5, 3 + floor(Stamina / 50))` |
| Intelligence | wild AI only: chance of picking the "smart" action = `min(0.95, 0.3 + Int/200)` |
| Traits | **no combat effect yet**; displayed only |

Level scaling: combat values × `1 + 0.05 × (level − 1)`. KL never changes with level (documented).

### D-04 Action points & actions (GDD: Attack / Defend / Save with action points)
- Both sides start with 1 AP and gain +1 AP each round, capped at max AP.
- **Attack** spends *all* current AP. Damage = per-AP damage × AP × (1 + 0.25 × (AP − 1)), so saving up pays off.
- **Defend** costs 1 AP and blocks 50% of incoming damage this round.
- **Save** does nothing and keeps AP for a bigger attack later.
- Both sides choose simultaneously. Defend/Save resolve first, then attacks in Mobility order. A kaiju knocked out before its attack does not attack.
- 30 rounds without a winner = draw (no reward, wild kaiju released).
- **Retreat** (not in GDD) is available during kaiju selection and fighting, so players can't get stuck.
- Idle battles time out after 120 s. A timed-out *won* battle automatically awards Kaiju Cells, so a victory is never lost.

Measured: Kragmor vs Kragmor with a simple "save to 2 AP then attack" policy wins ~73% of 200 simulated fights (test output).

### D-05 Losing
Losing or drawing has no penalty. The wild kaiju is released back into the world. Player kaiju HP is not persistent between battles.

### D-06 Capture & chains
- Four chain tiers (the GDD lists four steps, the last one handling KL5): Starter (KL1, free), Reinforced (≤KL2, $600), Advanced (≤KL4, $6,000), Titan (≤KL5, $40,000). Lengths (10/25/60/150 m) are display-only. **Names, limits and prices are placeholders.**
- Chains must be bought in order.
- Capture chance is 100% for all KLs (`KL[n].captureChance`), so both outcomes are reliably testable. If a capture fails, the kaiju escapes with no reward.
- If the chain is too short, the Capture button is disabled and shows which chain is needed. The player can still take Kaiju Cells.

### D-07 Kaiju Cells per defeat
KL1 10, KL2 25, KL3 60, KL4 150, KL5 400.

### D-08 Leveling
Level L → L+1 costs `10 + 10 × (L − 1)` Kaiju Cells, for every level except the fusion gates (D-14). Max level 40 (documented).

### D-14 Fusion
Documented: a level-10 kaiju fuses with an identical level-10 kaiju to become one level-11 kaiju, and "the same basic progression with leveling and fusion" continues to 40.
- **Interpretation (provisional):** fusion gates at levels **10, 20 and 30**, so 10→11, 20→21 and 30→31 each need fusion. Cells raise every other level, up to 40.
- "Identical" = same species. Both kaijus must be at the same gate level.
- The kaiju you fuse *from* keeps its identity, enclosure and capture date and gains +1 level. The duplicate is consumed and leaves its enclosure. Cells spent on the duplicate are not refunded.
- When picking the duplicate automatically, the UI prefers one that is **not** housed in the park, so income isn't lost.
- No extra cost for fusing. Blocked during a battle. Needs a second tap to confirm.
- The Studio-only DEV cheats panel (`DevCommand`, handled by `DevService`, registered only in Studio) grants Cells/money, all kaijus and all chains, and spawns any wild kaiju, so this is testable without grinding about 900 Cells.

### D-09 Enclosures
Sizes and KL ranges are documented (Small KL1–2, Medium KL3–4, Large KL5). Prices are provisional: $100 / $1,500 / $12,000. Placement uses a 3×3 slot grid per plot, not free placement yet. One kaiju per enclosure. You buy an enclosure by placing it (Shop → Build → tap a glowing slot).

### D-10 Income
Each housed kaiju earns per second: KL1 1, KL2 3, KL3 8, KL4 20, KL5 50. Level has no effect yet. **No offline income.** Unhoused kaijus earn nothing. Starting money is $250.

### D-11 Spawning (test area only)
The documented target is ~20 wild kaijus over seven islands. The test area has **one Wilds island** with one guaranteed Kragmor spawn (closest to the bridge) plus 3 random spawns. Random spawns are weighted by KL (60/25/10/4/1). Removed kaijus respawn at the same point after 8 s; the Kragmor point always respawns Kragmor.

### D-12 World layout
Hub island (spawn) → bridge → Wilds island. The 8 personal park plots per server sit in a **ring around the Wilds** (radius 340 studs, `Park.ringRadius`). The ring leaves an 80° gap facing the hub and bridge (`Park.ringGapDegrees`). Each plot is rotated so its entrance and spawn face the Wilds, and its 3×3 slot grid and enclosures rotate with it. You reach a plot with the **My Park** button (server-validated teleport); the **Wilds** button teleports back. Plots are identical apart from their position, as the GDD requires. The sea is solid, so players can also walk across the water between islands.

### D-13 Persistence
DataStore persistence with a session lock (`UpdateAsync`). **In Studio it is disabled by default** (`Persistence.useDataStoreInStudio = false`), so test sessions never touch real data. The HUD shows "Test mode: progress is not saved". If a live load fails, the session runs on temporary data and is never saved.

### D-15 Battle presentation (inspired by Jurassic World: The Game)
The GDD says combat happens in a separate battle mode and should follow Jurassic World: The Game.
- Each battling player gets a **client-only 3D arena**: a floating stone platform far from the shared world (`BattleArena`, origin 0,250,6000). Nothing is replicated, so many battles can run at once.
- Side-on camera framed to fit both kaijus. Your kaiju is on the left, the wild one on the right; each faces the other, turned slightly towards the camera.
- The server's round events are acted out in order:
  - Defend and Save first: blue shield bubble and brace pose / gold charge ring and "+AP"
  - then attacks: wind-up (bigger with more AP), lunge, impact flash, recoil, camera shake and a floating damage number ("BLOCKED n" when it hits a shield)
- HP bars drop at the moment of impact. Action buttons are locked while a round plays.
- End states are animated too: knockout (tip over), capture (chains tighten, flash), Defeat for Cells (dissolves into cells), escape, retreat.
- Placeholder effects only (parts, Highlight, BillboardGui); no sounds or particle textures yet.

### D-16 Riding your kaijus (not in the GDD)
- Any owned kaiju can be ridden (Collection → **Ride**). Only one at a time; **Dismount** in the HUD or on the card.
- The rider sits on a per-species saddle point (on the back; on a shoulder for tall titans; on the head for Wormhole) and steers with the normal movement controls. No jumping while riding.
- Ride speed uses the documented **Mobility** stat: `min(32, 14 + 0.1 × Mobility)` (Popcorn 14.5, Kragmor 17, Emperor 30). Provisional (`GameConfig.Riding`).
- A ridden kaiju leaves its enclosure (shown as "out riding") and **earns no income** until dismounted.
- Starting a battle, dying, or fusing away the ridden kaiju dismounts automatically.
- Mounts don't collide with the world (they pass through trees and rocks). This is a simplification for the first version.

## Open questions for the designer

1. Full text of GDD section 15 onward (file is truncated).
2. How does a new player get their first kaiju? (D-01)
3. Team size and whether a team has more than one kaiju active per battle. (D-02)
4. Intended stat → combat formulas and what traits do in combat. (D-03)
5. Capture chances: should a capture be able to fail? Should a failed capture still allow taking Cells? (D-06)
6. Chain names, lengths, prices and which KLs each chain covers. (D-06)
7. Income per KL; should level affect income? Offline income? (D-10)
8. Fusion beyond level 10: is our reading of fusion gates at 10/20/30 right (D-14)? Should fusion cost anything? Should the consumed kaiju refund Cells?
9. Meaning of "supergiant star" (Popcorn), "50 (150)" (Wormhole mobility), and "\*" on "Distance Traveling".
10. Can kaijus placed in the park also be used in battles? (Currently: yes.)
11. Is riding part of the design? Should it be limited (KL, level, a saddle item)? Should mounts collide with the world? (D-16)
