# CLAUDE.md 3.0 — DM Roguelite (working title: *Derrière le paravent*)

## Project in one paragraph

A roguelite **card battler where you play the Dungeon Master** against your own table. You draft monsters, play encounters against a party of four players, and decide round by round who the monsters target, which special attacks fire, and which DM tricks you pull. The core tension: **players are satisfied when they are in real danger, and the campaign ends the moment they all die.** Loot makes them happier *and* stronger, so every reward raises the bar for the next encounter. Score = how strong *and* satisfied the party is at the end of the campaign. Players have a **class** (what they do in combat) and a **table archetype** (who they are around the table), plus random statuses (on their phone, dice tower, toxic). Tone: affectionate humour about tabletop culture, never contempt for players.

## Lessons from prototypes 1–3

Three throwaway prototypes shaped this design. Protect what they taught:

1. **Decisions over arithmetic** (dice prototype failed on this). Every choice must be a trade-off between danger and satisfaction with no single right answer. Never add a mechanic whose optimal play is a calculation.
2. **Many decisions, and they talk to each other** (early battler had only 2 per night). Draft affects encounters, encounter length affects the clock, fleeing costs time and trust. Keep that web intact.
3. **The red line must be reachable.** A tank + healer party is a damage sponge; the fix is mechanical (poison, assassins, focus targeting, special attacks), not just bigger numbers. Brute force should never be the best way to kill.
4. **Visible payoff.** Every consequence is a readable French log line. The log is a feature, not debug output.

## Working with Rich

- Talk to Rich in a familiar, mature **Québécois French** tone. He's a geek and a seasoned dev lead: skip beginner explanations.
- Code, identifiers, comments and commit messages are in **English**.
- In-game text is in **Québécois French**, kept in `data/strings.gd` and in the `.tres` content files.
- Deliver changes as **small incremental diffs**, not full-file rewrites. Explain the *why* in one or two lines.
- When a rule is ambiguous, pick the simplest reading, implement it, log it in `DESIGN_QUESTIONS.md`.
- Use English menu/option names when giving Godot editor instructions.

## Tech stack

- **Godot 4.x**, statically typed **GDScript**.
- 2D, placeholder art; emoji and ColorRect are fine. Combat feedback (hit flashes, number pops, log lines sliding in) **is in scope**: it is how the player reads consequences.
- **All randomness goes through one seeded `RandomNumberGenerator`** owned by the run. Seed is shown on screen and can be entered manually.
- The HTML prototype in `prototype/battler.html` is the **reference implementation** of the rules. When in doubt about a rule, read it. Port its logic; don't redesign it. The deliberate deviations from it are listed in `DESIGN_QUESTIONS.md`; for those, Rules v0 below wins.

## Architecture rules

```
res://
  core/        # Rules engine. RefCounted classes. NO Node, NO UI.
  data/        # Resources (.tres) + scripts: monsters, dm_cards, loot, classes, archetypes, tuning, strings
  ui/          # Scenes and Control scripts. Calls core intents, listens to core signals.
  sim/         # Headless simulation + bots
  tests/       # Unit tests on core/
  prototype/   # Reference HTML prototype (read-only)
```

1. **`core/` never touches the UI.** Intents: `draft_pick`, `start_encounter(cards)`, `set_target(player)`, `arm_special(monster)`, `play_dm_card(card, target)`, `resolve_round()`, `flee()`, `give_loot(item, player)`. Signals: `round_resolved(events)`, `player_hit`, `player_died`, `monster_died`, `satisfaction_changed`, `log_line`, `phase_changed`.
2. **Round resolution emits an ordered event list**, never mutates the UI directly. The UI animates the list; the sim ignores it.
3. **Data-driven.** Every number in this file is a starting tuning value living in Resources, never hard-coded in logic. Monster behaviours and specials are keyed strings resolved by a small registry in `core/`, so adding a monster is a `.tres`, not code.
4. **Headless-runnable** for `sim/`.

## Rules v0

### Campaign structure
| Param | Value |
|---|---|
| Nights per campaign | 3 |
| Encounters per night | 3 |
| Rounds before midnight (per night) | 18 |
| Max rounds per encounter | 8 |
| Danger budget per encounter | 5 + 2 × night |
| Draft | 7 offered, keep 5; each monster card is used once per night |
| Fleeing | the current round still resolves (parting blows), then the encounter ends; −2 extra rounds, all players −8 satisfaction |
| Midnight before encounter 3 | encounter skipped, all players −8 |
| Between encounters | players recover 35% max HP; statuses and poison cleared |

### Party (generated since milestone 5)
At campaign start 6 candidates are generated (random class × archetype, distinct names, base stats from the class) and the DM seats 4 of them. The table below is the fixed v0 party, still in `data/party/` and used when `party_candidates = 0` (tests, `run_sim.gd -- --fixed-party`).

| Name | Class | Archetype | HP | ATK |
|---|---|---|---|---|
| Max | Tank | Main Character | 32 | 4 |
| Kevin | DPS | Murder Hobo | 18 | 8 |
| Sophie | Crowd control | Rule Lawyer | 20 | 4 |
| Mathieu | Healer | Joueur discret | 20 | 3 |

Each player: `hp`, `max_hp`, `atk`, `satisfaction` 0–100 (start 50), `alive`, `status`, `poisoned`, `inspired`, `skip_turn`, `heal_power` (4), `stun_chance` (0.5).

### Classes (combat behaviour + satisfaction hook)
| Class | In combat | +6/+8 if… | −6/−8 if… |
|---|---|---|---|
| Tank | Monsters target him 50% (taunt) | took the most damage | took no damage |
| Healer | If an ally < 40% HP: heals lowest ally for `heal_power + d3` instead of attacking | healed someone | never healed |
| DPS | High ATK, low HP | dealt the most damage | didn't |
| Crowd control | Before attacking, 50% to stun the highest-ATK non-immune monster | ≥ 1 stun landed | none |

Player attack: `atk + d3 − 1`. Target: lowest-HP monster (Murder Hobo: highest-HP). Dice tower status: 25% crit ×2.

### Archetypes (table personality)
| Archetype | +6 if… | −6 if… | Extra |
|---|---|---|---|
| Murder Hobo | landed a killing blow | no kill | Description dramatique: −6 instead of +6 |
| Main Character | took the most damage | didn't | monsters target him 30% (after taunt check) |
| Rule Lawyer | ≤ 2 monsters in the encounter (+4) | — | −10 whenever Fudge saved someone |
| Joueur discret | thrill in the "good fight" band (+4) | — | — |

### Statuses (75% chance one random living player gets one per encounter)
- 📱 **Sur son cell**: skips rounds 1–3. Also given to every living player who starts an encounter under 40 satisfaction (bored players tune out).
- 🎲 **Dice tower**: 25% crit.
- ☣️ **Toxique**: at encounter end, both neighbours −6 satisfaction.

### Monsters
Fields: `name, hp, atk, cost, behaviour, special, flags, quip`. Attack: `atk + d3 − 1`.

| Monster | HP | ATK | Cost | Behaviour | Special (once per fight, armed by the DM) |
|---|---|---|---|---|---|
| Rats géants | 8 | 3 | 1 | random | Essaim: attacks twice this round |
| Gobelins | 12 | 4 | 1 | weakest | Piège: poisons target |
| Squelettes | 16 | 5 | 2 | random | Se relève: +10 HP |
| Mimic | 18 | 7 | 2 | murder hobo | Croc: ×2 damage this round |
| Araignée venimeuse | 14 | 4 | 2 | random, poisons on hit | Toile: target skips next turn |
| Assassin | 14 | 9 | 3 | healer, ignores taunt | Coup dans le dos: ×2 this round |
| Loup-garou | 22 | 7 | 3 | random | Hurlement: +2 ATK all monsters |
| Ogre | 30 | 10 | 3 | strongest | Cri: target skips next turn |
| Chevalier noir | 32 | 11 | 4 | strongest, stun-immune | Monologue: no attack, +8 satisfaction all |
| Nécromancien | 26 | 12 | 4 | weakest | Relève un mort: adds a Squelettes |
| Hydre | 40 | 9 | 5 | hits 3 players for half | Régénération: +10 HP |
| Dragon | 55 | 16 | 6 | strongest | Souffle: hits every player for half ATK |

Targeting order with a DM target: taunt 50% intercepts (Assassin ignores it) → DM target. Without one: assassin rule → taunt 50% → Main Character 30% → behaviour. Poison: 3 damage per round at the start of the player phase, not healable.

### DM cards (hand of 3, draw 1 per round, play ≤ 1 per round)
| Card | Effect | Social cost |
|---|---|---|
| Fudge | This round nobody dies (survives at 1 HP) | Rule Lawyer −10 if it triggers |
| Renforts | Adds a random cost 1–2 monster | — |
| Description dramatique | Monsters skip attacking; +6 satisfaction all | Murder Hobo −6 instead |
| Inspiration | Chosen player doubles next attack, +5 satisfaction | — |
| Coup critique | Monsters deal ×1.5 this round | — |
| Le monstre hésite | Highest-ATK monster skips this round | — |

### Round resolution order
1. Poison ticks.
2. Players act in seat order (skip if 📱 and round ≤ 2, or `skip_turn`).
3. Monsters act: armed specials resolve first, then the normal attack unless stunned, hesitating, or Monologue/Description dramatique.
4. Draw a DM card. Check deaths, TPK, encounter end (all monsters dead, 8 rounds, or midnight).

### Satisfaction at encounter end (per living player)
`thrill = damage_taken / max_hp`
- thrill < 0.15 → −15 ("C'est tout ?")
- 0.15–0.6 → +12
- ≥ 0.6 → +25 ("Meilleure soirée à vie")
- monsters survived 8 rounds → −10; DM fled → −8
- then class hook, archetype hook, Toxique neighbours.
A player who died this encounter: satisfaction 0, out for the rest of the night. A death stops the fight at the end of that round (no timeout penalty). At the start of the next night the player is back with a new character: 80% of base HP and ATK, no loot, satisfaction still 0. TPK (everyone dead in the same round, or the last one standing dies) → campaign over, score 0.

### Loot (after every encounter, 3 offered, give exactly 1)
| Item | Class | Stats | Satisfaction |
|---|---|---|---|
| Épée +1 | DPS | +2 ATK | +10 |
| Bouclier gravé | Tank | +12 HP | +10 |
| Bâton de soins | Healer | +1 ATK, +4 HP, heal +2 | +10 |
| Baguette de givre | CC | +1 ATK, +4 HP, stun +20% | +10 |
| Hache de guerre | DPS | +4 ATK | +14 |
| Armure de plates | Tank | +18 HP | +14 |
| Potion de force | any | +2 ATK, +4 HP | +8 |
| Épée vorpale ★ | DPS | +6 ATK, +4 HP | +22 (night ≥ 2) |
| Anneau de vie ★ | Healer | +16 HP, heal +4 | +22 (night ≥ 2) |

Off-class gift: half satisfaction, stats still apply. Every other living player −4 (jealousy).

### Score
`power = atk × 2 + max_hp / 5`. **Final score = Σ power × satisfaction** over living players.

## Character generation and asset pipeline

The party is generated per campaign. A player is **data + appearance + table flavour**, and each part is built so adding content means adding files, not code.

### Generation
- `PlayerGenerator.generate(rng) -> PlayerData` picks: race, class, archetype, body type (A/B), appearance (see below), a name from `data/names.tres` (per body type), and a one-line **table quirk** from `data/quirks.tres` ("apporte toujours ses propres dés", "connaît le PHB par cœur, pas les règles de la table"). The quirk is flavour only in v0; it may become a status later.
- A party is 4 of 6 generated candidates, shown in an LFG-style list the DM picks from (Milestone 5). Class coverage is **not** enforced: a party with no healer is a valid, harder run.
- Race is **cosmetic in v0** (appearance only). Any future race mechanic goes through a keyed behaviour string, like monsters.

### Appearance: layered paper doll
One `CharacterAppearance` Resource holds an index per layer plus three tint colours. `CharacterSprite.tscn` is a stack of `Sprite2D` nodes in fixed order; `apply(appearance)` assigns textures and `modulate`. All layer textures share **one canvas size and one anchor** (start at 128×192, feet at the bottom centre), so no per-layer offsets exist anywhere in code.

| # | Layer | Varies by | Tint |
|---|---|---|---|
| 1 | `hair_back` | hairstyle | hair |
| 2 | `back_item` | class (cape, staff) | accent |
| 3 | `body` | body type | skin |
| 4 | `race_traits` | race (ears, tusks, hairy feet) | skin |
| 5 | `face` | face variant | — |
| 6 | `outfit` | class | accent |
| 7 | `facial_hair` | optional | hair |
| 8 | `hair_front` | hairstyle | hair |
| 9 | `accessory` | optional | — |
| 10 | `weapon` | class | — |

- **Tint, don't draw.** Skin, hair and accent colours are `modulate` on greyscale art. One drawing, any colour. Palettes per race live in `data/races/*.tres`. If a layer needs two colours, use the small palette-swap shader in `ui/shaders/`, not a second drawing.
- **One silhouette for everyone in v0.** Race size is a uniform `scale` on the whole stack (halfling 0.8, dwarf 0.85, orc 1.1). Separate silhouettes per race are out of scope until the art budget below is done and the game is fun.
- **Body type A/B** changes the body texture and the hairstyle pool. Outfits are shared by both.

### Art budget v1 (≈45 drawings)
Body ×2, faces ×4, race traits ×5, hairstyles ×6 (back + front = 12), outfits ×4, weapons ×4, accessories ×6, facial hair ×2. Style: clean black outlines, cel-shaded, flat colours, limited palette; outlines hide seams between layers. Draw hair first (most variety per drawing), outfits last.

### Workflow for new art
1. Draw over the locked body template (`art/template.kra`), export each piece as its own PNG at the shared canvas size, greyscale where tinted.
2. Drop it in `assets/characters/<layer>/` and add a `.tres` entry; the generator picks it up with no code change.
3. Until real art exists, placeholder layers are flat shapes; the pipeline must work with them from Milestone 2 on.

## Milestones

1. **Core engine + sim.** Port `prototype/battler.html` rules into `core/` with Resources for all content. `sim/run_sim.gd` plays N campaigns with three bots: **random**, **greedy-safe** (always targets the tank, never arms specials, flees at any death risk) and **greedy-risky** (max budget, targets lowest HP, arms everything). Print per bot: TPK rate, median final score, satisfaction per player, encounters skipped at midnight. **Red flags to report first:** a bot that never TPKs (red line unreachable), or greedy-safe scoring within 15% of greedy-risky (risk not rewarded).
2. **Playable encounter.** Party, monsters, DM hand, target selection, special arming, resolve/flee buttons, animated event feed. Done when a round's consequences are readable without the log.
3. **Night loop.** Draft, clock, 3 encounters, loot, statuses.
4. **Campaign.** 3 nights, score screen, seed display, restart.
5. *(Stretch)* **Generated party** (random class × archetype combos, 4 of 6 candidates) and a **campaign recap** in r/rpghorrorstories style.

## Out of scope

Settings, venues, meta-progression between runs, real art, audio, saves, localization, player memory across campaigns. Put ideas in `IDEAS.md`.

## Definition of done for a change

- Runs from the editor with no errors or warnings in the Output panel.
- `godot --headless --script res://sim/run_sim.gd` still runs; paste its summary whenever a rules or tuning change could affect balance.
- No hard-coded tuning numbers in `core/`.
- Any new monster, card or loot is a `.tres` file, not a code change (unless it needs a new behaviour key).

## Design intent to protect

- **Danger is the currency of satisfaction.** Safe play must be visibly worse than brave play.
- **TPK is always possible and never free.** If a bot can't die, the game is broken.
- **Players are chaotic resources, not enemies.** Humour punches at the situation, not at the people.
- **Input randomness only.** Draws, draft offers, statuses, damage rolls happen before or inside a resolution the player chose; no hidden coin flip after a decision decides its outcome.
