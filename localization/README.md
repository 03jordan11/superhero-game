# Powers text and localization

**Edit `localization/powers.json` to change the Powers menu's text.** Each top-level key is a locale code. The `en` object contains stable message keys and the current English wording. Save as UTF-8 JSON and restart the game after editing; the catalog loads once per run.

| Key prefix | Content |
| --- | --- |
| `power.<id>.name` | Power names on cards and in details |
| `power.<id>.description` | Power descriptions |
| `powers.category.*` | Category names and unlocked counts |
| `powers.upgrade.*` | Upgrade row states and the placeholder text |
| `powers.action.*` | Unlock and upgrade buttons |
| `powers.error.*` | Purchase restrictions |
| `powers.feedback.*` | Purchase confirmation messages |
| `console.*` | Developer console help, command feedback and interface text |
| `hud.*` | Gameplay health/stamina/XP formats, key hint labels, and the hint visibility setting |
| `powers.title`, `powers.tokens`, `powers.back`, `powers.open` | Header, wallet, footer Back button, and pause-menu entry |

Keep keys and placeholders such as `{power}`, `{number}`, `{owned}`, `{total}`, and `{count}` unchanged. Translations may reorder the placeholders. Translate whole messages rather than joining sentence fragments in code.

## Adding a language

1. Add another top-level object using a Godot locale code, such as `fr`, `es`, or `pt_BR`.
2. Add translated messages using the same keys as English. Omit untranslated keys or leave their values empty for English fallback.
3. Restart the game to load the edited catalog. No translation imports or registration in Project Settings are needed.
4. Select the language using `TranslationServer.set_locale("fr")`. There is no new language-picker UI yet; future locale settings should call this native API. The open Powers page refreshes automatically when the locale changes.

For example, add a `fr` object alongside `en`:

```json
{
  "en": {
    "powers.back": "Back",
    "power.ice.name": "Ice"
  },
  "fr": {
    "powers.back": "Retour",
    "power.ice.name": "Glace"
  }
}
```

This is a small structural example; retain all existing English messages in the real file. The loader registers every locale with Godot's TranslationServer. Godot handles regional matching and English fallback. `export_presets.cfg` includes `localization/*.json` so the catalog ships with the game. There are no generated `.translation` files to maintain.

## Lookup function

`scripts/ui-scripts/powers_text.gd` provides the common entry point:

```gdscript
const POWERS_TEXT = preload("res://scripts/ui-scripts/powers_text.gd")

POWERS_TEXT.text("powers.back")
POWERS_TEXT.power_name("ice")
POWERS_TEXT.text("powers.action.upgrade", {"number": 2})
```

On first use, it loads the JSON catalog and registers its locale dictionaries. It then calls `TranslationServer.translate()` using the current locale and substitutes named fields. Power IDs, category grouping, costs, prerequisites, and saved upgrade levels remain in `power_menu_progression.gd` and are independent of the display language.

The Powers page binds static labels to keys and refreshes both static and dynamic text on `NOTIFICATION_TRANSLATION_CHANGED`. New page labels should use `_localized_label()` or `POWERS_TEXT.text()` during refresh. The gameplay tabs and developer console also use this catalog. Console keywords remain stable English identifiers; only their descriptions and feedback are translated.

Run `godot --headless --path . --script res://tests/test_powers_localization.gd` to check JSON loading, live locale changes, fallback, pips, and locked/owned visuals. The test uses a temporary JSON catalog; it does not change the real text or saved preferences.
