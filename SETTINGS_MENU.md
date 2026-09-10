# Settings menu

The main menu and pause menu use the same settings panel, with a solid background and four tabs: **Graphics, Audio, Gameplay, Controls**. Controls now contains keyboard/mouse and Xbox rebinding; see [CONTROLS.md](CONTROLS.md) for defaults, extension guidance, and verification. Tab buttons support mouse, keyboard, and Xbox navigation; tab contents scroll if needed. Back returns to the originating menu. In the pause menu, Back keeps the game paused; Esc/B from the pause actions resumes play.

## Graphics

- Display Mode: Windowed, Borderless Windowed, Fullscreen.
- Resolution: 1280×720, 1600×900, 1920×1080, 2560×1440, 3840×2160, plus the current saved/custom window size if necessary.
- Crowd Density, Vehicle Density, Population View Distance: existing Low/Medium/High behavior, moved into this tab.

Display mode and window resolution now persist. Fullscreen uses the display's native resolution, so the window-resolution dropdown is disabled there. Borderless Windowed retains the chosen window size, matching the previous mode's behavior. The existing population settings still apply immediately and settle in the world after unpausing; building visibility is unchanged.

## Audio

Master, Sound Effects, Music, and Voice sliders control independent named audio buses. All default to 100%; zero mutes the bus. Master controls all three categories. Sliders preview changes immediately and save 0.25 seconds after the last adjustment, avoiding a file write every frame while dragging. A pending audio save is also flushed when the settings panel leaves the scene tree.

- **Sound Effects:** impacts, footsteps, punches, jump charge, player wind, gunfire, city ambience/horns/wind, engines, and vehicle explosions.
- **Voice:** the player's death and heavy-lift vocal cues, plus future dialogue assigned to this bus.
- **Music:** a functioning bus and saved volume preference ready for future music; no music content was added.

Existing effect buses retain their EQ/reverb/limiter settings and send into SFX. SFX, Music, and Voice send to Master. New audio sources should explicitly select their category or an appropriate effect bus in the Inspector. No runtime scene-wide audio-node scanning is used.

## Gameplay

All HUD settings use checkboxes:

- **Show Control Hints:** immediately shows/hides the existing hints.
- **Always Show Health:** enabled by default. When disabled, health appears while below maximum and for four seconds after a health/max-health change.
- **Always Show Level / XP:** enabled by default. When disabled, progression appears for four seconds after an XP or level change.
- **Always Show Stamina:** enabled by default and now connected to the live stamina HUD. When off, stamina is visible while below capacity and hides when fully recovered.

HUD timers follow pause state. Health and progression remain event-driven; disabling hints still stops their binding-refresh polling.

Accessibility controls remain in Gameplay, as requested:

- **Boost / Sprint: Hold or Toggle.** Hold preserves the existing behavior. Toggle lets one press activate boosted running/flight and a second press stop it. It uses the `sprint` input action (Shift / Xbox L3 by default), so it respects rebinding. It does not change the jump button's charge behavior.
- Sprint toggle resets on pause, focus loss, death, knockdown, opening the developer menu during gameplay, or changing accessibility preferences. This avoids resuming with a latched boost.
- **Power Activation (Right Click): Hold or Toggle.** The preference is saved for future held powers such as Laser Eyes. No right-click power is implemented by this menu change.

## Preferences and compatibility

`GameSettings` stores preferences in `user://settings.cfg`, independently of gameplay save files. Sections are `population`, `display`, `audio`, `hud`, `accessibility`, `bindings_keyboard`, and `bindings_controller`. Missing/invalid values use defaults; old population and control-hint settings continue to load. Old files without display preferences retain the current window configuration. Both menus synchronize immediately through the settings signals, including while paused.

Save failures appear beside the affected settings; changes still apply for the current session. No power unlocks, attribute rules, stamina consumption, or heat mechanics were implemented in this pass.

## Verification

- 41 relevant headless regression scripts passed: player states/input/audio, settings persistence/UI, gameplay HUD, population, powers menu/save/localization, camera, ambience, and vehicle audio.
- `tests/test_settings_tabs.gd` covers all four tabs, populated Controls, background, checkbox types, paused/main-menu synchronization, display preferences, independent audio buses, debounced saves, future preferences, contextual HUD timers, invalid settings, and save failures. It writes only isolated test preferences. The later controls pass ran 42 scripts, including `test_control_bindings.gd`; see its guide for details.
- `tests/test_player_toggle_sprint.gd` checks actual input-event routing, hold/toggle behavior, key repeat, ground/flight acceleration, rebindings, and pause/focus/developer-menu/knockdown/death resets.
- Rendered all four tabs using Direct3D 12 / Forward+ and inspected screenshots at 1280×720. Gameplay's current controls fit without scrolling at this size.
- Headless tests emit environment warnings about restricted user logs/settings and the certificate store. Some audio tests also report dummy-driver playback resources at shutdown. No GDScript failures occurred in the passing suite.

### Test in Godot

1. Open Settings from the main menu. Click through all four tabs; try keyboard/mouse and Xbox rebinding in Controls. Use Tab/arrows or D-pad/A, LB/RB for tabs, and Back/Esc/B. Repeat from the paused game.
2. Change display mode/resolution and each population option, then restart to verify preferences. Check fullscreen on your actual display; automated checks exercised its preference/UI path, not physical fullscreen transitions.
3. Lower Master, mute SFX, and adjust Voice independently. Compare wind/footsteps with a lift grunt or death cue. Restart to verify levels. Music will become audible when a music source is added.
4. Disable Always Show Health and Level / XP. Take damage, restore health through your testing tools, and earn XP. Verify the contextual readouts and their four-second visibility. Toggle control hints independently.
5. Select Toggle for Boost / Sprint, resume, and press Shift once while moving. Verify acceleration persists after release, then stops on the next press. Try flight, pause/resume, and switching focus away from the game. Return to Hold and verify release stops boosting again.
6. Change Stamina visibility and Right Click activation, then reopen/restart to verify the saved choices. Their future gameplay hooks are intentionally pending.

## Files added or changed

- Added `scenes/ui/settings_menu.tscn` and `scripts/ui-scripts/settings_menu.gd` (plus UID): shared tabbed panel, background, controls, and persistence feedback.
- Updated `scenes/main_menu.tscn`, `scenes/main.tscn`, `scripts/ui-scripts/main_menu.gd`, and `pause_menu.gd`: shared settings integration, Back/Esc behavior; removes duplicate display-menu logic.
- Updated `scripts/game_settings.gd`: display/audio/HUD/accessibility preferences, validation, application, and signals.
- Updated `scripts/ui-scripts/gameplay_hud.gd`: contextual health and XP visibility.
- Added `scripts/player-scripts/player_input_controller.gd` (plus UID); updated `player_character.gd` and `scenes/player.tscn`: per-player sprint-toggle state feeding the existing input snapshot.
- Updated `default_bus_layout.tres`, `scenes/player.tscn`, `scenes/npcs/hostile.tscn`, `scenes/vehicles/engine_sound.tscn`, and `scenes/super_city.tscn`: audio category routing.
- Updated `scenes/ui/population_settings.tscn`: align its label widths with Graphics controls.
- Added `tests/test_settings_tabs.gd` and `tests/test_player_toggle_sprint.gd` (plus UIDs); updated menu references in `tests/test_gameplay_hud.gd` and `tests/test_population_settings.gd`.
- Added this guide; updated `GAMEPLAY_HUD.md`, `POPULATION_SETTINGS.md`, and `PLAYER_AUDIO_AND_SPEED_FEEDBACK.md`.
