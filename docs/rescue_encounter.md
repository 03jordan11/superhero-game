# Injured civilian rescue

Run `spawn rescue` in the developer console, then close it. No rescue instances are placed automatically in the scene. The existing hospital has a permanent green rescue circle in its front courtyard. Console `status` shows Money and Good Will, including rescue rewards.

## Flow

- Spawn one protected civilian on a random clear static surface, 60–200 horizontal units from the hero. Appearance varies using the existing hair randomization. Death01 is frozen near its final frame, but the patient is alive and ignores damage.
- Follow the arrow, approach within four units and press E (the rebindable pickup action; RB on controller). No Vehicle Lift unlock is needed.
- Carrying switches the arrow to the hospital and prioritizes this rescue over nearby combat encounters. The posed civilian is centered across the hero's chest; no new carrying animation was added.
- E safely sets the person down anywhere. An airborne drop falls without damage. Away from the hospital, the arrow returns to the patient, who can be picked up again.
- Complete by setting the person down inside the hospital circle. Floor contact and proximity to the zone's elevation are required; entering while still carrying does not complete it.
- Completion grants 100 XP, $100 and 10 Good Will once. The timer/arrow clear immediately; the patient disappears after two seconds. Money and Good Will are saved; old saves default Good Will to zero. No spending or sentiment system is added.

## Timer preview

The top-center timer starts at 02:00 on spawn and continues before pickup, while carrying and after set-downs. Pause/menu time does not count. Heavy/Super landings and ground slams while carrying subtract five seconds once per impact, with orange feedback. Soft landings and impacts while not carrying have no penalty.

At zero it stays at 00:00: no failure, injury or reduced reward. With multiple rescues, the HUD displays the carried rescue first, otherwise the nearest rescue belonging to the hero.

## Extension and tuning

`BaseEncounter` exposes waypoint position/label/priority hooks and awards XP, money and Good Will through its guarded completion lifecycle. `RescueEncounter` owns the patient, hospital target and timer. `HospitalRescueZone` is separate from the encounter so a future rooftop zone can use the same contract. Only the front courtyard zone exists now.

`PlayerCharacter.is_carrying()` is the common occupied-hands check. Vehicle and person pickup both use it; new grabbable types must join that check. E handles the held object first and consumes the interaction for that tick. Hero death releases the patient; deleting the encounter also cleans up a patient parented to the hero.

Tune timer/penalty/spawn radius on `scenes/encounters/rescue.tscn`, pickup range and carry offset on the player's `PlayerRescueCarrier` node, and drop-off position/radius on the hospital's `RescueDropOff` node. The marker follows hospital movement/rotation. The elevation filter rejects submerged ground in this city; clear roofs can qualify as spawn surfaces.

## Files changed

- Added `scripts/encounter-scripts/rescue_encounter.gd`, `hospital_rescue_zone.gd`, and `scenes/encounters/rescue.tscn`.
- Added `scripts/npc-scripts/rescue_patient.gd` and `scenes/npcs/rescue_patient.tscn`.
- Added `scripts/player-scripts/player_rescue_carrier.gd` and `scripts/ui-scripts/rescue_timer_hud.gd`.
- Updated `scripts/encounter-scripts/base_encounter.gd`, `scripts/player-scripts/player_character.gd`, `player_vehicle_interactor.gd`, `player_encounter_indicator.gd`, and `scenes/player.tscn` for lifecycle, carrying and dynamic destinations.
- Updated `scripts/player-scripts/player_stats.gd`, `scripts/save_manager.gd` and `scripts/ui-scripts/developer_commands.gd` for rewards, persistence and console commands/status.
- Updated `assets/buildings/hospital/hospital.tscn` and `hospital.gd` for the front drop-off and daylight-independent glow.
- Updated `localization/powers.json`, `CONTROLS.md`, `DEVELOPER_CONSOLE.md` and `docs/encounters.md`.
- Added `tests/test_rescue_encounter.gd`, `tests/test_rescue_console.gd`, `tests/render_rescue.gd` and UID sidecars. Updated `tests/test_hospital.gd` to inspect building meshes separately from the marker.

## Playtest

1. Run `spawn rescue`, follow the civilian arrow and check the countdown.
2. Pick up with E. Try grabbing a car or another patient; neither should work while occupied.
3. Sprint, jump and fly. Land softly, then hard: only the hard impact should subtract five seconds once.
4. Set down away from the hospital, follow the arrow back and pick up again.
5. Let the timer reach zero, then deliver inside the circle. Check full rewards with `status` and save/load.
6. Pick up a car first and approach a patient: E retains vehicle drop/throw behavior without also grabbing the patient.

Automated coverage includes actual-city spawning/hospital lookup, paused countdowns, E snapshot pickup/drop, protected damage/falls, landing-effect penalties, zero-time delivery, exactly-once rewards, old/new save data, occupied hands and death cleanup. Rendered previews were inspected for timer placement, patient pose, carrying and the circle; this is not an interactive city rescue playthrough.
