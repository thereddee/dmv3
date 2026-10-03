# Design questions

Ambiguities met while porting, the reading that was implemented, and why. Newest last.

## Milestone 1 — core port

1. **DM hand size.** CLAUDE.md says "hand of 3"; the prototype starts each encounter with 2 cards and draws up to 3. → Followed the prototype (`dm_start_hand = 2`, `dm_hand_size = 3`).
2. **One DM card per round.** CLAUDE.md says "play ≤ 1 per round"; the prototype has no limit. → Enforced the limit (`dm_cards_per_round = 1`). Side effect: the prototype quirk where Fudge/Crit survived a Description dramatique round can no longer happen.
3. **Healer roll.** CLAUDE.md says `heal_power + d3`; the prototype rolls `heal_power + 0..2`. → Followed the prototype.
4. **Tank hook.** CLAUDE.md says −6 "if took no damage"; the prototype gives −6 whenever the tank did not take the *most* damage. → Followed the prototype.
5. **Timeout vs flee.** Prototype naming is confusing (`fled` = 8 rounds / midnight, `retreat` = DM fled). → `timed_out` −10, `retreated` −8, matching CLAUDE.md.
6. **Out of monster cards.** If the 5 drafted cards are spent before encounter 3 the prototype soft-locks ("…ou tu sautes" but no button). → The encounter is skipped automatically with the midnight penalty (−8 all). Tracked separately in the sim (`out of monsters`).
7. **Midnight skip.** Prototype applies a single −8 however many encounters are skipped. With v0 numbers only encounter 3 can be skipped, so it does not matter yet.
8. **Hits are logged.** The prototype logs no line for a plain hit; the port emits one ("X frappe Y pour N") since the log is the payoff. Easy to mute UI-side via the event `type`.
9. **Hard-coded names in flavour lines** ("Kevin prend des notes", "Martin travaille demain") are kept as-is in `data/strings.gd`. To revisit with the generated party (milestone 5).
10. **greedy-safe bot budget.** Spec only says "targets the tank, never arms, flees at any death risk". → First version drafted the 5 cheapest and spread them 2/2/1; superseded by the balance pass below.
11. **Hesitation carries over a Monologue.** In the prototype a hesitating monster that fires Monologue keeps `hesit` for the next round. Ported as-is.

## Milestone 1 — balance pass (red flags)

Straight port, 1000 campaigns per bot: greedy-safe 0% TPK, greedy-risky 99% TPK (median 0). Both red flags.
After this pass (seeds 1..1000): random 3.9% / median 2334, greedy-safe 1.7% / 3638, greedy-risky 18.1% / 5391.

What the sim showed:
- The straight port is a death spiral: one death makes the next fight at the same budget unwinnable, so any DM who lets a player die ends in a TPK. Budget, HP, recovery and loot numbers only slide both bots up or down together (safe 0% as soon as risky drops under ~60%).
- The safe bot was invulnerable because fleeing was an instant, free exit and nothing made a quiet table dangerous.

Rules changed (all deviate from the prototype). The "without it" figures come from the exploration grid, on a rule set close to the final one, not re-measured on the final one:

12. **A death stops the fight.** The encounter ends at the end of the round where a player dies, no timeout penalty. A TPK now needs a multi-kill round or the last player standing. Without it: risky 88% TPK.
13. **Dead players reroll.** Out for the rest of the night, back next night (not next encounter: Rich's call, closer to a real table) with 80% of base HP and ATK (`reroll_stat_ratio`), no loot, satisfaction 0. Death costs the loot, the satisfaction, the night and a weaker character. `death_grief` (others lose satisfaction on a death) exists but stays at 0: at −10 it brings the "risk not rewarded" flag back. Without it: risky 79% TPK.
14. **Fleeing resolves the round first.** Players and monsters act, then the monsters leave (−2 rounds, −8 all). If the players kill everything in that round it is a normal win. Fudge or Description dramatique are the only clean exits. Without it: safe 0% TPK.
15. **Bored players pull out their phone.** Every living player under 40 satisfaction (`bored_threshold`) starts the encounter 📱, and 📱 now skips rounds 1–3 (`phone_skip_rounds`, was 2). A bored table hits less, so fights last longer and get dangerous. Without it: safe 0% TPK.
16. **The tank can intercept the DM's target.** With a DM target set, taunt (50%) redirects the attack to the tank; Assassin ignores it. Without it the risky bot one-shots its target every fight, the fight stops on the death, nobody else gets a thrill: risky median 3477, below safe.

Bots:
- **greedy-safe** now drafts and spends like greedy-risky (max budget). The cheap 2/2/1 version scored below "do nothing" and was never in danger: a strawman. Only the way it runs the fight differs.
- **greedy-risky** plays Fudge on a lethal round when it holds it. Still never flees, never plays a defensive card otherwise.

Tested and rejected (no effect, or moved both bots together): one flee per night, one armed special per round, DM target limited to the strongest monster, budget scaling with living players, budget 4+1n / 5+1n / 6+1n, recovery 60–100%, party HP ×1.5.

Still open:
- The flag compares medians. On means, safe is at 86% of risky (4051 vs 4685): risk pays, but the margin is thin once the TPKs are averaged in.
- No encounter is ever skipped at midnight for any bot: the 18-round clock does not bite yet.
- The random bot runs out of monster cards 0.85 times per campaign.
- Kevin (DPS, 18 HP) survives 25% of risky campaigns: "targets lowest HP" is mostly "kills Kevin".

## Milestone 2 — playable encounter

17. **Autopilot (removed in milestone 3).** Milestone 2 shipped with draft, pick and loot played by `GreedyRiskyBot`; `ui/` no longer depends on `sim/`.
18. **`round_resolved` covers the round only.** DM cards played before "Résoudre" no longer appear in the next event list; the UI shows them right away through `log_line` and `satisfaction_changed`.
19. **Silent events added for the feed** (no log line): `player_idle` (on the phone), `monster_idle` (stunned or hesitating), `monster_healed`, `monsters_buffed`. Without them a skipped turn was invisible on screen.
20. **Target and armed specials are toggles.** Clicking the targeted player again clears the target; clicking an armed monster disarms it. Nothing is committed until "Résoudre le tour".
21. **Dev screenshots.** `godot --path . -- --seed=7 --demo=<dir>` plays one encounter alone and saves PNGs (`ui/dev/demo.gd`).

## Milestone 3 — night loop

22. **One screen, four panels.** The party stays on top; below it the same area shows the draft, the monster pick, the fight or the loot (`ui/choice_panel` is shared by the three card choices). `EncounterScreen.enter_phase()` is the only switch.
23. **Statuses are rolled before the monster pick**, as in the prototype, so the DM sees who is on their phone before choosing what to send.
24. **Loot is two clicks**: the item, then the player. Dead players are refused with a line. No confirmation step: the gift is immediate, like the prototype.
25. **Seats show the model between encounters.** Poison and statuses stay displayed on the loot and draft screens until the next encounter starts, because that is when the engine clears them.
26. **The clock turns red** when fewer rounds remain than one full encounter can last (`max_rounds_per_encounter`).
27. **Seed entry and restart are milestone 4.** The seed is displayed; `-- --seed=N` sets it from the command line.

## Milestone 4 — campaign

28. **Score screen.** One line per player (`power × satisfaction`), the total, the survivors and the seed. A TPK shows the same screen with a score of 0 instead of the encounter summary.
29. **Restart.** "Recommencer" in the top bar and the score screen share one panel: a seed field (empty = random), "Nouvelle campagne", "Rejouer la seed N", and "Annuler" when a campaign is still running. The button is ignored while a round is playing back.
30. **A seed can be text.** A non-negative integer is used as-is; anything else is hashed into 0..999999, so "pizza" is a valid seed. Same rule for `-- --seed=`.
31. **Players dead at the end do not score**, even though they would have rerolled the next night: the campaign ends before they come back.

## Milestone 5 — generated party and recap

32. **Recruit phase.** A campaign opens on `Phase.RECRUIT`: 6 candidates, the DM seats 4 (`recruit(picks)` intent). Seat order is the order they were offered. Class and archetype are rolled independently, so a table with two DPS and no tank is possible: picking around it is the decision.
33. **Base stats moved to the class.** `ClassData` now carries `hp`, `atk`, `heal_power`, `stun_chance` and a `blurb`; generated players copy them. The four `data/party/*.tres` keep their own stats and are only used when `party_candidates = 0`.
34. **Names.** 16 first names in `data/strings.gd`, drawn without repeats from the run's RNG. The flavour lines that named Kevin now name the table's Murder Hobo, or the first player still up.
35. **Balance with generated tables** (1000 campaigns, seeds 1..1000, bots seat one of each class when they can): random 5.3% TPK / median 1946, greedy-safe 1.8% / 4257, greedy-risky 18.4% / 5504. No red flag. The fixed table is unchanged (4.4% / 1.8% / 20.5%). Not measured: tables with no tank or no healer, which only a player who picks them on purpose will see.
36. **Recap.** `core/recap.gd` writes a forum post from one player about the DM, built from `core/chronicle.gd` (deaths with the killer, flees, fudges, timeouts, descriptions, monologues, skipped encounters, phone time, loot favourite). No dice: the same campaign always gives the same post. The narrator is the happiest player when the table average is 60 or more, the grumpiest otherwise. Thresholds are constants in `recap.gd`.
37. **Sim report is per class**, since seats no longer have fixed names.
