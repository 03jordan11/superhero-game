# Combat and wind audio

## Player bullet impacts

`assets/audio/player/superhero_bullet_hit.wav` is an original synthesized 0.42-second impact: a dry snap, deep thud, and short metallic tail. It is a mono, 48 kHz, 16-bit PCM one-shot with a -3 dBFS peak. Regenerate it using `assets/audio/player/tools/generate_bullet_hit.py` with Python 3; no recordings or external packages are required.

Select **Player → PlayerSoundManager → Bullet Hits** to replace the stream, tune **Bullet Hit Volume Db** (default -6 dB), or adjust **Bullet Hit Pitch Variation** (default ±8%). The BulletHit child plays through Master with up to four overlapping impacts. Sounds Enabled also mutes this feedback.

Hostile pistol hits mark DamageInfo's `damage_type` as `bullet`. PlayerDamageReceiver emits `damage_received` only for accepted damage; PlayerSoundManager filters that event for bullets. Fatal hits sound once; misses, zero damage, other damage types, and hits after death do not trigger the clip. Future bullet weapons should set the same damage type.

Run `tests/test_player_bullet_hit_audio.gd` with Godot's headless script runner to check the real hostile shot path, playback, tuning, mute, missing-stream handling, and fatal/rejected hits. In Godot, let a nearby hostile shoot the hero, compare hits and misses, then test several shooters and adjust the level against pistol fire. Listening and gameplay appearance still require a manual playtest.

## Player combo

Select **Player → PlayerSoundManager → Combo Punches**.

- Punch Sounds entries 0, 1, and 2 use `punch_1.mp3`, `punch_2.mp3`, and `punch_3.mp3`.
- **Punch Sound Delays** X/Y/Z control seconds into the first/second/third attacks: 0.12 / 0.16 / 0.18 seconds by default.
- **Punch Volume Db** defaults to -6 dB.

Only the existing combo controller triggers these sounds. A swing plays once whether it hits or misses; a cancelled attack cannot produce a pending sound afterward. Kick and charged-punch clips are not wired yet. The sounds use the combo's own clock, so pausing does not let a delayed sound fire ahead of its attack.

## Hostile pistol

Select **Hostile → PistolShot** in `scenes/npcs/hostile.tscn` to change the stream, volume, pitch, and 3D attenuation. Defaults are -6 dB, Unit Size 16 m, and Max Distance 120 m.

`pistol_shot_single.wav` plays when a hostile expends a pistol round, including shots that miss. It does not play for reloading or rifle/melee behavior. All instances of the hostile scene inherit the audio node.

## Wind above the city

Select **SuperCity → Sound → SkyWind**.

- **Start Height / Full Height:** 20 / 200 metres above the street, matching the city noise fade by default.
- **Base Volume Db:** -22 dB for a gentle background layer.
- **Fade In / Out Seconds:** 1.8 / 1.2 seconds for a full volume change.
- **Wind Enabled:** independent layer toggle. Disabling CityAmbiances also mutes this layer.

SkyWind uses CityAmbiances' hero, street height, city coordinate system, and city boundary fade. It grows with altitude as street noise recedes, including over the park. It does not require the hero to be moving or flying. It stops playback at street level or outside the audible city range.

## Wind around the hero

The flight-only wind has been replaced by the player speed-feedback implementation. Running and flight now share an actual-speed threshold, with a separate falling threshold. It no longer requires Sprint or an unlocked-power flag.

See [Player audio and speed feedback](PLAYER_AUDIO_AND_SPEED_FEEDBACK.md) for the new `_AI` sounds, Inspector controls, subtle trails/distortion, replacement instructions, and tests. `PlayerSoundManager/SpeedWind` uses the renamed **PlayerSpeedWind** bus. The old `hero_flying.wav` asset remains available but is no longer the default player loop.

## Checks and manual testing

`tests/test_combat_and_wind_audio.gd` covers the combo sequence and cancellation, pistol firing/miss/reload behavior, the player wind bus, sky altitude fades, city transforms, and stopping inaudible loops. Existing player audio, combat, and city fade tests provide regressions.

In Godot, test a full three-hit combo and an interrupted punch; let a hostile fire and reload; fly upward through 20–200 m, hover, then accelerate and stop. Compare sky wind while hovering with the added speed wind while moving. The dedicated power-feedback test covers the new speed thresholds and audio lifecycle. Use the Remote Inspector for live tuning, then save preferred values in the normal Inspector. Automated checks do not replace listening to the mix.

## Files changed

- `scripts/player-scripts/player_combat_controller.gd` and `player_sound_manager.gd`: combo event, timing, and speed-based flight audio.
- `scripts/npc-scripts/hostile.gd` and `scenes/npcs/hostile.tscn`: pistol playback on firing.
- `scripts/sound_manager.gd`, new `scripts/city_sky_wind.gd`, and `scenes/super_city.tscn`: shared boundary fade and altitude wind.
- `scenes/player.tscn`: ComboPunch and speed-feedback audio nodes (the original FlightWind node was subsequently replaced by SpeedWind).
- `assets/audio/player/hero_flying.wav.import` and `assets/audio/ambiance/ambient_wind.wav.import`: normalization settings.
- New `tests/test_combat_and_wind_audio.gd` and this tuning guide.
