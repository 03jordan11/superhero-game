# Encounters

For the fixed seven-enemy harbor boarding fight, use `spawn pirates`. Defeat two pistol thugs, three melee thugs, one machine gunner and one super on a stationary cargo ship for **500 completion XP**. See [Pirates](pirates.md) for deck behavior, cleanup and testing.

For the harbor's push/rope objective, use `spawn ship_docking`. See [Ship docking](ship_docking.md) for controls, tuning, rewards and playtest steps.

Spawn a level-scaled gang encounter with `spawn gang_activity` in the developer console. It creates one encounter at a random clear location 60-200 meters horizontally from the hero. No encounter instance is added to the main scene. The existing waypoint shows the nearest active encounter's name, difficulty and distance; dev-spawned encounters show it even without Trouble Sense, without unlocking that power.

## Gang activity rosters

The hero's level, roster and completion bonus are captured at spawn time. Leveling up during the fight does not change them. Machine gunners use `rifle_thug`.

| Hero level | Tier | Total enemies | Composition | Completion XP |
| --- | --- | --- | --- | --- |
| 1-3 | Easy | 4 | Either 1 rifle OR 1-3 pistols; remaining enemies are melee | 100 |
| 4-6 | Mid | 5 | 1 rifle AND 2-3 pistols; remaining enemies are melee. A 2% chance replaces the rifle with 1 super | 500 |
| 7+ | Hard | 7 | 1-2 rifles AND 1-2 pistols AND 1-2 supers; remaining enemies are melee | 1,000 |

Easy chooses between its two ranged branches with equal probability. Both that probability and the medium super chance are Inspector exports. Every group has at least one normal melee thug. All participants are Mafia and retain their existing combat behavior, including shared melee/super turn coordination.

Completion XP is a bonus on top of the individual enemies' normal XP. It is awarded once after every participant dies. Removing a living participant fails the encounter and cannot award the completion bonus. Completed/failed encounters stop appearing on the waypoint immediately and clean up after 15 seconds of unpaused play. Active encounters remain until resolved or their scene is removed.

## Class responsibilities

- `BaseEncounter` owns lifecycle, signals, level-to-tier selection, the level snapshot, completion rewards, cleanup and waypoint eligibility. Subclasses implement `_prepare_encounter()` and `_activate_encounter()` and call `complete_encounter()` or `fail_encounter()` for their own objectives.
- `GangActivityEncounter` owns gang roster rules, placement, participant spawning and the all-enemies-defeated objective. It inherits the shared lifecycle rather than duplicating it.
- `scenes/encounters/gang-activity/gang_activity.tscn` is the reusable packed scene, instantiated only on demand.
- `DeveloperCommands.ENCOUNTER_SCENES` maps encounter names to scenes. Add a new subclass/scene and registry entry for another encounter type; NPC spawn handling remains separate.
- `PlayerEncounterIndicator` reuses the existing waypoint. Its ordinary Trouble Sense requirement remains in place for encounters without the dev override.

Placement plans the entire group before creating any enemies. It checks flat static ground, standing clearance, separation and consistent elevation, excluding characters from ground rays. A configurable minimum ground height (-0.15, matching this city's dry-ground range) rejects submerged terrain. This is a city-specific elevation filter, not a general water-volume system. Clear roofs may also qualify. Failed placement reports an error and leaves no partial encounter. Tuning values live on the gang encounter root in the Inspector.

## Validation and playtest

Automated tests cover 3,000 generated rosters, all tier boundaries, the rare-super replacement, exact counts/rewards, level changes during combat, distinct grounded spawn positions, failed/underwater placement, reward idempotence, waypoint gating and clearing, missing participants, cleanup and console pause behavior. The console integration test spawned all three tiers in the actual city. The existing developer-console and pistol regressions also passed. Godot editor import found no GDScript parse errors. Existing environment/settings and occasional shutdown-resource warnings remain. These are headless checks; waypoint appearance and encounter feel still need an in-game playtest.

1. Restart Play, open the console, run `spawn gang_activity`, then close the console.
2. Follow the waypoint. Confirm its tier matches the hero's displayed level and its group matches the table.
3. Defeat the group. Verify the tier's bonus is awarded after the last death, in addition to enemy XP; the waypoint disappears.
4. At levels 4 and 7, spawn another encounter to test the other tiers. Existing `add xp` grants can advance the hero for testing; no tier override changes the hero's progression implicitly.
5. Spawn two encounters to check that the waypoint selects the nearest active one and switches after it completes.

## Files changed

- `scripts/encounter-scripts/base_encounter.gd`
- `scripts/encounter-scripts/gang-activity/gang_activity.gd`
- `scenes/encounters/gang-activity/gang_activity.tscn` (restored as an on-demand scene)
- `scripts/player-scripts/player_encounter_indicator.gd`
- `scripts/ui-scripts/developer_commands.gd`
- `localization/powers.json`
- `tests/test_gang_activity_encounter.gd` and `tests/test_pistol_thug.gd`
- Added `tests/test_encounter_console.gd` and its Godot UID
- `DEVELOPER_CONSOLE.md`, `docs/hostile_enemies.md`, and this guide

## Injured civilian rescue

`spawn rescue` creates an injured-person delivery encounter with fixed rewards of 100 XP, $100 and 10 Good Will. E picks up or safely sets down the patient; the waypoint switches between the patient and the hospital's front green circle. A top-center two-minute preview countdown loses five seconds per hard landing while carrying but has no failure effect at zero. See [rescue_encounter.md](rescue_encounter.md) for behavior, implementation and testing details.

## Helicopter chase

`spawn helicopter_chase` creates one armed helicopter with 100 health and a fixed 1,000 XP completion reward. It pursues the hero on the ground, rooftops and in flight, seeking a tunable 25-meter horizontal distance and 10-meter height offset. Inaccurate sweeping bursts use the existing bullet damage/audio; solid cover blocks shots. Powers and thrown vehicles damage the aircraft. Destruction creates an explosion and a black burning physics wreck that falls and expires after 30 seconds. See [helicopter_chase.md](helicopter_chase.md) for tuning and playtest instructions.
