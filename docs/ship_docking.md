# Ship docking encounter

In Main, open the developer console and enter `spawn ship_docking`. Close the console and follow the harbor waypoint. The existing cargo vessel moves 110 m offshore with a random heading offset of 12–28 degrees in either direction. Only one docking encounter can claim it at a time.

## Controls and objective

- **Push:** fly into either green circle on the seaward hull, press **E**, then hold **W/forward** to move that end toward its berth target. Press **E** to release. Flight circles appear only while the ship is stopped; after releasing, allow it to settle before changing ends.
- **Ropes:** stand at either green dock station and press **E**. Hold **S/backward** to shorten that bow/stern line; **E** releases the interaction. Reeled lines stay tied off, and slack lines do not pull. Change stations to straighten the ship. Left mouse no longer pulls.
- Both methods are always present. Contact selection uses whether the hero is currently flying, with no purchased-flight requirement in the encounter.
- Both end positions must be within **5 m** of their separate docking targets. Center position alone cannot complete the objective. The HUD reports both distances.
- Success seats the ship at its exact authored berth and awards **200 XP and $200 once**. There is no countdown. Markers/ropes disappear and the result message lasts three seconds.

The encounter suspends the normal cargo schedule. Success holds the ship at the berth until the next regular 03:00/15:00 departure. Failure or removal releases the player and restores scheduled service. Losing physical flight releases a push contact. While attached, movement input operates the ship interaction and attacks remain suppressed; mouse look remains available. The existing rig's looping `Push` clip provides a braced effort pose.

## Inspector tuning

On `scenes/encounters/ship_docking.tscn`: offshore distance, minimum/maximum starting angle, docking tolerance, push speed, reel speed, strength scaling/cap, maximum rope tension, contact radius, damping, and bow/stern push contact offsets. Movement is restricted to the water plane, with translation and yaw responding to the selected end and rope tension. A conservative hull-envelope query prevents movement into harbor collision geometry. This is a gameplay approximation, not a full nautical simulation.

Base rope shortening is **3.6 m/s**, up 20% from 3.0. The flying push target is **8 m/s**, tuned to move the actual hull faster than rope pulling despite damping. Both use `min(1 + (effective_strength - 1) * 0.05, 3.0)`: strength 1 gives 1×, strength 10 gives 1.45×, and strength 41+ gives 3×. Effective strength includes purchased bonuses and is read during movement. Rope force and turning limits also scale so they do not cancel the speed increase. These are solver rates; actual travel depends on angle, tension and slowing near the berth.

## Files added or modified

- `scripts/encounter-scripts/ship_docking.gd` and `scenes/encounters/ship_docking.tscn`: encounter, motion, contacts, ropes, HUD, rewards and cleanup.
- `scripts/player-scripts/player_ship_interaction.gd`, `player_character.gd`, `player_animation_controller.gd`, and `scenes/player.tscn`: interaction ownership, controls and effort animation.
- `scripts/cargo_ship_schedule.gd`: discovery group and continuous departure after encounter completion.
- `scripts/ui-scripts/developer_commands.gd`, `localization/powers.json`: spawn command, completion and help.
- `tests/test_ship_docking.gd`, `tests/render_ship_docking.gd`: actual-city functional checks and render capture.
- This guide, encounter index, and generated script UIDs.

## Validation and manual playtest

The docking test covers both methods across four seeds (both heading directions) at strengths 1, 10 and 41, hull clearance, motion/marker settling, E/W/S integration, rejection of LMB and forward movement for pulling, no ability gating, console spawning while paused, duplicate prevention, failure cleanup, two-end completion, exact rewards and schedule resumption. It checks actual docking times: flying beats pulling at each strength, and increasing strength improves both methods. Purchased bonuses and extreme-strength clamping are covered. At strength 10, solver runs take approximately 33 seconds pushing or 44 seconds pulling, excluding travel between contacts. The prior flight animation, flight surge, encounter console and cargo schedule/rider checks passed. Earlier Godot-rendered overview, push and rope views were inspected; this speed update was checked headlessly and still needs a player feel test.

The existing standalone rescue test cannot finish because its hospital fixture lacks `RescueDropOff`; this task does not modify that fixture or hospital scene.

Test each method separately from a fresh spawn. Check how quickly each end responds, let go midway to confirm settling, switch ends, and verify that the reward arrives only after both displayed distances qualify. Also try mixing ropes and pushing in one encounter. Screenshots/logs are in `artifacts/ship_docking/` and `artifacts/ship-docking-*`.

For the speed update, compare `set strength 1` and `set strength 10` with fresh `spawn ship_docking` encounters. Check S pulls while W and LMB do not; W still pushes at flight contacts and E still releases. Changed files for this update: `scripts/encounter-scripts/ship_docking.gd`, `scripts/player-scripts/player_ship_interaction.gd`, `tests/test_ship_docking.gd`, `tests/render_ship_docking.gd`, and this guide. Results: `artifacts/ship-docking-speed-test-output.txt`.
