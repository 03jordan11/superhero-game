# Helicopter chase

Start Play, open the developer console and run `spawn helicopter_chase`. Close the console to begin. This spawns one encounter on demand; the existing ambient helicopter remains separate.

## Behavior

- One attack helicopter starts with **100 health** at every hero level.
- It pursues the player's current position, including rooftops and flight, using the existing helicopter acceleration, heading and banking controller.
- It seeks **25 m horizontal separation** and **10 m above the player**. Clear-air probes, lookahead braking/climbing and solid collision protect against buildings. Tight spaces can force a higher approach. Guidance is local obstacle avoidance, not a citywide route planner; very fast players can temporarily outrun it.
- The gun fires at **650 rounds/minute**, with **1.6-second bursts** and **2-second pauses**, within **95 m**. Each bullet has **4 base damage** through the same bullet damage pipeline as thugs.
- Each burst locks an imperfect aim point, then sweeps a **24-degree arc**. Base horizontal/vertical error is 4/2 degrees, increasing with helicopter speed. Moving after the burst begins can evade it. A ray through each angular slice catches crossings between rounds; the real player collider must be hit before cover.
- The existing gunshot clip, a visible tracer and muzzle flash mark individual rounds. Frame hitches never discharge multiple accumulated rounds at once.
- Existing powers and armed thrown-vehicle impacts can damage the solid aircraft body.
- At zero health, firing stops immediately. An explosion and sound accompany a black burning physics wreck, carrying horizontal flight momentum and falling under gravity. It disappears after **30 seconds of unpaused play**.
- Destruction completes the encounter and awards **1,000 XP exactly once**, immediately. The waypoint clears. Removing a living helicopter fails the encounter without XP. Player death ends the pursuit.

## Inspector controls

Open `scenes/encounters/helicopter-chase/helicopter_chase.tscn` to edit the encounter defaults. Health, engagement distance, height offset, spawn distance and wreck lifetime are exported on its root. Engagement distance and height also update the live helicopter when changed in the Remote Inspector.

The live `AttackHelicopter` exposes pursuit speed and orbit speed. Its `Flight/Helicopter/SweepingGun` exposes damage, range, cadence, burst timing, sweep width and aim error. Script defaults can be changed in `scripts/encounter-scripts/helicopter-chase/helicopter_gun.gd`.

650 RPM uses the lower end of the M240's 650–950 cyclic range as a game tuning starting point: [U.S. Marine Corps reference](https://www.marines.mil/Photos/igphoto/2000951723/?igsearch=120mm+mortar+round).

## Validation

- `tests/test_helicopter_chase.gd`: chase on foot/in air, swept hit/near miss/cover, real bullet damage, power-compatible body rays, health, one-time XP, falling black wreck and 30-second cleanup, missing-enemy failure.
- `tests/test_helicopter_chase_integration.gd`: actual console spawn and pause, a real thrown car explosion damaging the aircraft, actual laser-eye ray targeting, solid-wall avoidance and climbing.
- `tests/render_helicopter_chase.gd`: actual city render of the attacking helicopter and falling burning wreck. Screenshots are in `artifacts/helicopter_chase/`.

## In-game playtest

1. Run `spawn helicopter_chase` and close the console. Check the waypoint, health label, audible bursts and tracer sweeps.
2. Run, jump to a roof and fly; check that pursuit catches up and settles at an engageable distance. Move through alleys and around tall towers to assess local avoidance.
3. Stand briefly in the sweep, then dodge or put solid cover between you and the gun. Compare health changes and the pauses between bursts.
4. Hit the helicopter with a thrown car and with your unlocked powers. Check damage registration on the fuselage.
5. Destroy it: verify a single 1,000 XP reward, stopped gunfire, explosion, black tumbling wreck with fire/smoke and removal after 30 unpaused seconds. Pause during the wreck lifetime to check that the countdown pauses too.

Gameplay balance and sustained pursuit in the densest city blocks still need player testing.

### Ground-clearance protection

`ground_clearance` on the encounter root defaults to 12 meters, measured from the aircraft flight root to terrain or rooftops, leaving space for skids and banking. Footprint and forward probes override unsafe pursuit descent. Descent speed is limited by remaining braking distance; a final movement guard prevents crossing the safety height and slows lateral travel onto rising ground until the helicopter can climb. A diving player's velocity cannot override this protection. Destroyed wrecks continue to fall normally.

`tests/test_helicopter_ground_clearance.gd` covers a 35 m/s dive following a falling player, a long frame near the ground, an elevated roof, recovery from a low starting position and a fast hillside approach.

This fix changes `scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd`, `scripts/encounter-scripts/helicopter-chase/helicopter_chase.gd`, adds `tests/test_helicopter_ground_clearance.gd` (and its Godot UID), and updates this guide. Ground-clearance, encounter and integration tests pass; editor import reports no GDScript parse errors. Manual flight feel has not been visually rechecked for this fix.

## Files added or modified for this encounter

- `scenes/encounters/helicopter-chase/helicopter_chase.tscn`
- `scripts/encounter-scripts/helicopter-chase/helicopter_chase.gd`
- `scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd`
- `scripts/encounter-scripts/helicopter-chase/helicopter_gun.gd`
- `scripts/encounter-scripts/helicopter-chase/helicopter_wreck.gd`
- `effects/helicopter_explosion.gd` and `effects/helicopter_wreck_fire.gdshader`
- `scripts/ui-scripts/developer_commands.gd` and `localization/powers.json`
- `tests/test_helicopter_chase.gd`, `tests/test_helicopter_chase_integration.gd` and `tests/render_helicopter_chase.gd`
- `DEVELOPER_CONSOLE.md`, `docs/encounters.md` and this guide
- Godot-generated UID sidecars for the new scripts/shader; validation logs and preview images under `artifacts/helicopter_chase/`

Godot 4.7.2 editor import reported no GDScript parse errors. Existing certificate/user-directory and road-resource UID fallback warnings remain in the validation environment.
