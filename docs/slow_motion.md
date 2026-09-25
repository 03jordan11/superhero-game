# Shared slow motion

`SlowMotion` is a global autoload available to any scene script:

```gdscript
SlowMotion.start(self, 0.5) # Game and all audio at 50% of the starting game speed.
# At impact, expiry, or cancellation:
SlowMotion.stop(self)
```

Transitions use smoothstep interpolation over real time: `ease_in_seconds = 0.1` when slowing and `ease_out_seconds = 0.5` when recovering. Both are exported on the autoload script. `stop(self, true)` is reserved for scene teardown and restores immediately when no other requests remain. Pause/focus loss/global cancellation also restore immediately. Ordinary impact, expiry and cancellation use the recovery fade. A new request arriving during that fade keeps the original baseline.

Each source node owns one request. Calling `start` again updates that request rather than multiplying it. Overlapping powers use the smallest requested multiplier; stopping one power keeps other active requests running. When the last request ends, the helper restores the game speed captured before the first request. The global audio playback multiplier always matches the resulting game multiplier exactly. For example, a baseline of 0.8 and a 0.5 request produce 0.4 for both, then restore both to 0.8.

Deleting/removing the source releases its request automatically. Pause, application focus loss, and helper teardown clear active requests and restore speeds. Start is rejected while paused or for invalid/off-tree sources. Speeds are constrained to 0.01–1.0; powers own their duration and trigger/release timing. New slow-motion powers should call this helper rather than assigning Engine/AudioServer speeds directly. `cancel_all()` is available for global cancellation.

External Combustion, Lightning Strike and Anticipation use this helper. External Combustion requests 0.5 during its explosion. Their existing Inspector strengths remain: Lightning Strike 0.5 and Anticipation 0.4. Global playback slowdown includes music, voices, UI, rain/thunder, and combat sounds, lowering pitch along with playback speed. Existing per-sound pitch variation is retained. No additional sounds, muffling, pitch-shift bus effects, or separate audio strength have been introduced.

Lightning Strike's area is now 9m in diameter (4.5m radius) for both hold-targeted strikes and quick-tap pulses, with a 50m cast range. Damage, cooldown, and Heat cost are unchanged.

Validation: `tests/test_slow_motion.gd` checks overlap, repeated updates, release order, prior-speed restoration, source deletion, pause, focus loss, and invalid/late releases. Lightning Strike and Anticipation tests verify matching audio/game rates and cleanup at impact, cancellation, expiry, pause, death, and scene teardown. Strike checks cover a target in the newly expanded radius, out-of-radius exclusion, valid 35m/49m targeting, rejection at 51m, and a 9m preview mesh. A graphical audio probe measured actual playback advancement at approximately 1.004× normally, 0.499× during a 0.5 request, and 1.005× after restoration. This is a playback timing measurement, not a subjective sound-quality assessment.

Playtest: during a thunderstorm, hold Q while grounded with Electricity tier 3 selected. Listen for the entire soundscape slowing alongside the world, then easing back after strike impact. Pause or cancel mid-aim and confirm audio is restored. Trigger an Anticipation counter and check the same behavior at its 40% game speed. Change the existing Inspector speed on either power and verify both world and sound follow it. Aim between 30m and 50m and test enemies up to 4.5m from the strike center.

Files changed: new `scripts/slow_motion.gd` and `tests/test_slow_motion.gd` with generated UIDs; `project.godot`; `scripts/player-scripts/player_lightning_strike.gd` and `player_anticipation.gd`; the Lightning Strike/Anticipation tests; `localization/powers.json`; `CONTROLS.md`, `CURRENT_CONTROLS.md`, and the electricity/weather/anticipation/shader documentation. No audio assets or bus layout changed.

The helper tests also check transition midpoints, overlap recovery, and restarting during a fade. Action-specific counter/lightning regression tests set transition durations to zero for deterministic existing hit timing; the helper and live combustion render test exercise the default eased timings.
