extends RefCounted
## Purchased tiers are authoritative. Costs remain temporary prototype tuning.
signal changed
signal purchased
const STRINGS = preload("res://scripts/ui-scripts/powers_text.gd")
const SCHEMA_VERSION := 2
const CATEGORIES := ["Movement", "Body", "Elemental"]
const POWERS := {
	"super_leap": {"category": "Movement", "implemented": [0, 1, 2, 3], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"super_speed": {"category": "Movement", "implemented": [0, 1, 3], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"flight": {"category": "Movement", "implemented": [0, 1, 2, 3], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"strength": {"category": "Body", "implemented": [0, 1, 2], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"mind": {"category": "Body", "implemented": [0], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"laser_eyes": {"category": "Body", "implemented": [0], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"ice": {"category": "Elemental", "implemented": [], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"fire": {"category": "Elemental", "implemented": [0, 1, 2], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
	"electricity": {"category": "Elemental", "implemented": [0], "max_upgrades": 3, "unlock_cost": 1, "upgrade_cost": 1},
}
var tokens := 0
# -1 = locked; 0 = core purchased; 1–3 = sequential upgrades purchased.
var upgrades: Dictionary = {"super_leap": 0}

func level(id: String) -> int:
	return int(upgrades.get(id, -1))

func is_implemented(id: String, tier: int) -> bool:
	return POWERS.has(id) and tier in POWERS[id].implemented

func add_tokens(amount: int) -> void:
	if amount <= 0: return
	tokens += mini(amount, PlayerStats.MAX_PROGRESSION_VALUE - tokens)
	changed.emit()

func to_save_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "tokens": tokens, "upgrades": upgrades.duplicate()}

func apply_save_data(data: Dictionary) -> void:
	tokens = _bounded_int(data.get("tokens"), 0, PlayerStats.MAX_PROGRESSION_VALUE, 0)
	upgrades = {}
	var saved: Variant = data.get("upgrades", {})
	if saved is Dictionary:
		for id in POWERS:
			upgrades[id] = _bounded_int(saved.get(id), -1, 3, -1)
		if data.get("schema_version", 0) != SCHEMA_VERSION:
			upgrades["mind"] = maxi(level("mind"), _bounded_int(saved.get("telekinesis"), -1, 3, -1))
			if _bounded_int(saved.get("ground_slam"), -1, 3, -1) >= 0:
				upgrades["flight"] = maxi(level("flight"), 2)
	# Power Jump is the starter power, including older saves.
	upgrades["super_leap"] = maxi(level("super_leap"), 0)
	changed.emit()

func _bounded_int(value: Variant, minimum: int, maximum: int, fallback: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)): return fallback
	if value >= maximum: return maximum
	if value <= minimum: return minimum
	return int(value)

func cost(id: String) -> int:
	if not POWERS.has(id): return 0
	return POWERS[id].unlock_cost if level(id) < 0 else POWERS[id].upgrade_cost

func blocked_reason(id: String) -> String:
	if not POWERS.has(id): return STRINGS.text("powers.error.unknown")
	if level(id) >= int(POWERS[id].max_upgrades): return STRINGS.text("powers.error.maxed")
	if tokens < cost(id): return STRINGS.text("powers.error.tokens")
	return ""

func purchase(id: String) -> bool:
	if not blocked_reason(id).is_empty(): return false
	tokens -= cost(id)
	upgrades[id] = level(id) + 1
	changed.emit()
	purchased.emit()
	return true
