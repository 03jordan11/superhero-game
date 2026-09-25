# Cooldown display

Developer console: `reset cooldowns` instantly clears Thunderstorm, Lightning Strike, External Combustion and Frost Wall cooldowns. Supports Tab completion and `help reset`. Heat, active weather, and player progression stay unchanged. Modified files for this command: `scripts/ui-scripts/developer_commands.gd`, `localization/powers.json`, `tests/test_developer_console.gd`, and this document.

The gameplay HUD has a fixed, transparent text area on the left, below the Heat/charge indicators. It contains no panel, background, border, icons, or heading. Active rows show the localized ability name and remaining whole seconds, for example `Lightning Strike - 45 seconds`.

Thunderstorm and Lightning Strike read their existing authoritative remaining-time fields from the Weather autoload. The UI never runs its own countdown or changes ability timing. Values round up so an ability is not shown as ready while a fraction of a second remains; `1 second` is singular. Rows disappear at zero, and the entire area hides when empty. The rows stay visible when changing selected powers or disabling control hints. Both timers follow existing game-time slowdown/pause and scene persistence.

The area is `GameplayHUD/Cooldowns` in `scenes/ui/gameplay_hud.tscn`, aligned at x=78, y=336. The two labels share the normal HUD text color and shadow, and ignore mouse input. The ordered `COOLDOWNS` list in `gameplay_hud.gd` maps each row to its timer field and localized name; future visual replacements can keep the existing timer source.

This change does not alter Lightning Strike radius/range, time scale, audio playback, or audio buses. It adds no shaders.

Validation: existing `tests/test_gameplay_hud.gd` passes. An artifact-only integration/render check started both real cooldowns, advanced the weather clock, checked rounded values and expiry, switched elements, and disabled hints. Captures at 1280×720 and 1920×1080 were inspected, including the fireball charge indicator above the cooldown rows. Godot editor/import checks reported no script parse errors. Existing environment user-data/cache/certificate and HUD-test shutdown resource warnings remain.

Playtest: summon a storm, then use Lightning Strike. Both rows should appear and count down. Switch to Fire and charge a fireball; the timers should remain readable below the charge indicator. Pause to freeze them, resume, and confirm each row disappears when ready. Turning off control hints should not hide cooldowns.

Changed files: `scenes/ui/gameplay_hud.tscn`, `scripts/ui-scripts/gameplay_hud.gd`, `localization/powers.json`, this document, and the electricity/weather/controls documentation.

External Combustion uses the same text area and session lifetime: `Weather.external_combustion_cooldown_remaining`, set to 300 seconds by either a manual or passive eruption. It continues across scene travel, counts game time, pauses with the game, and disappears at zero.

Frost Wall uses `Weather.frost_wall_cooldown_remaining`, set to 300 seconds on a valid cast. Its text row follows the same clock, visibility and session persistence rules.
