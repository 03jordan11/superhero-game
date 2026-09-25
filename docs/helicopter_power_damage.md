# Helicopter power damage

All implemented damaging elemental attacks can damage the helicopter. NPC-only slow, freeze, Electrified damage/status, stagger, and knockback do not apply to aircraft. Summoning a thunderstorm remains cosmetic.

- Laser Eyes, Electric Shock, normal Fireball, and charged Fireball retain their existing direct damage.
- Dragon Breath targets the imported fuselage hull instead of the aircraft node origin below it.
- Frost Breath deals 5 damage per second without frost buildup or frozen damage ticks. Breath targeting uses the hull surface and still respects cover.
- Lightning Strike deals 25 direct damage to helicopters above the ground circle, within its 4.5-meter radius and 80-meter bolt height. Overhead cover blocks it; no Electrified ticks follow.
- External Combustion deals its normal 10–70 damage within the current blast radius without pushing aircraft.

## Files changed

- `scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd`
- `effects/dragon_breath.gd`
- `effects/frost_breath.gd`
- `effects/lightning_strike.gd`
- `scripts/player-scripts/player_frost.gd`
- `scripts/player-scripts/player_lightning_strike.gd`
- `scripts/player-scripts/player_external_combustion.gd`
- `tests/test_helicopter_power_damage.gd` (new, with Godot UID)
- `tests/test_lightning_strike.gd`
- `tests/test_external_combustion.gd`
- `docs/electricity.md`, `docs/fire.md`, `docs/frost.md`, and this document

No shaders changed.

## Validation

Godot 4.7.2 headless editor import completed without GDScript parse errors. These suites passed: helicopter power damage, frost, fire upgrades, lightning strike, external combustion, helicopter chase, and helicopter ground clearance. Existing environment errors about logs/certificates/settings and resource cleanup warnings remain.

The new integration test exercises the actual helicopter collision hull with beams, both breaths, and both fireballs, plus combustion, airborne lightning damage, and cover checks. Gameplay was not visually verified for this change.

In Combat Arena, spawn a helicopter and aim each beam/breath at its fuselage within range. Confirm health decreases without an ice block or electrical stun. Test Combustion within eight meters at full heat and cast Lightning Strike on the ground directly below the helicopter during a thunderstorm. Confirm it takes damage and continues flying normally until destroyed.
