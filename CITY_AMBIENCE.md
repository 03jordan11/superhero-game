# City ambience

Select **SuperCity → Sound → CityAmbiances** in `scenes/super_city.tscn`.
The attached `scripts/sound_manager.gd` controls the non-positional AudioStreamPlayer.
Use **Base Volume Db** to tune its overall loudness; the native Volume property is updated each frame.
The existing audio and 0.8 pitch are preserved. Playback starts automatically and loops a private copy of the stream.

## Inspector controls

- **Height Fade:** full volume up to 20 metres above Street Height; silent at 200 metres. Height is measured above street level, so landing on a rooftop does not restore the street ambience.
- **City Boundary Fade:** full volume inside City Bounds; fades over 200 metres outside the nearest edge, including corners.
- **Park Fade:** volume reduces across the first 60 metres inside Park Bounds, reaching Park Volume Scale (0.15 by default). Set the scale to 0 for silence in the interior.
- **Transition Timing:** Fade In Seconds (1.8) and Fade Out Seconds (1.2) smooth changes, including teleports. These are durations for a full 0–1 volume change; smaller changes take proportionally less time. Set either to 0 for an instant response in that direction.
- Each fade can be independently disabled. **Ambience Enabled** smoothly mutes/restores the sound.
- **Hero Path** is optional; an empty path follows the current `player` group member. Missing heroes produce silence.
- **City Root Path** defaults to SuperCity. Rectangles use its local X/Z coordinates; Street Height uses its local Y coordinate. Defaults match `assets/super-city/layout.json`. Update these exports if the city layout changes.

The three volume multipliers combine, so flying over the park remains quiet. Playback continues while silent to avoid restarting the recording when returning to town.
Edit the normal scene Inspector to save tuning values. The Remote Inspector can tune values live, but those runtime edits are not saved by Godot.

## Distant background horns

**SuperCity → Sound → CityHorns** uses both supplied car horn recordings as occasional positional background sounds. Its first horn is due after 8 seconds, with random 45–120 second gaps after subsequent horns finish. Only one horn plays at a time. Outside the audible city range, only the countdown advances: no clips are selected or played. A due horn waits at zero until the hero returns; missed events never accumulate. An active horn stops decoding when its environmental fade becomes inaudible. Missing heroes and ordinary game pause pause this layer.

Inspector controls on CityHorns:

- **Horns Enabled:** toggle this layer independently.
- **Horn Sounds:** the one-beep and two-beep recordings, selected randomly.
- **Base Volume Db / Volume Variation Db:** default -8 dB with ±2 dB variation, before spatial attenuation.
- **Minimum / Maximum Interval:** 45–120 seconds of silence. Runtime edits reschedule immediately.
- **First Horn Delay:** 8 seconds after scene startup; separate from the later random intervals.
- **Minimum / Maximum Distance:** 120–220 metres around the hero, in a new random horizontal direction for each horn. The source retains that offset throughout playback so fast traversal cannot turn it into a nearby horn.
- **Minimum / Maximum Pitch:** 0.75–1.2, varying tone and playback duration together.
- Native **Unit Size** (60 m) controls distance attenuation. The native attenuation filter softens high frequencies to help the horns sound distant.

CityHorns reads the already-smoothed fade multiplier from **CityAmbiances**, including its hero override, height, city boundary, park, enable toggle, and fade times. Tune those rules once on CityAmbiances. Each layer retains its own base volume. Horns are background effects, independent of actual traffic vehicles.

For a quick test, temporarily set both intervals to 2–3 seconds in the Remote Inspector. Listen for changing directions and tones, then enter the park, fly high, and leave the city to compare fades. Restore the infrequent interval afterward. Save lasting tuning in the normal scene Inspector.

The temporary developer horn-preview button and bypass logic were removed in the console redesign. Normal city horn ambience remains available with its Inspector tuning.

## Verification

Run `tests/test_sound_manager.gd` with Godot's `--headless --path . --script` options. It checks the fade calculations, combined effects, city transforms, smoothing, missing/replaced heroes, and the actual scene's sound setup.

In gameplay, listen at street level, fly from 20 to 200 metres above the street, move from a park edge 60 metres inward, and travel 200 metres beyond the city edge. Return to the street after each to check the fade back in. Adjust the corresponding exports to taste.
