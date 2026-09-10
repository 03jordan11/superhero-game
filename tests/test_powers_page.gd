extends SceneTree
const MODEL = preload("res://scripts/ui-scripts/power_menu_progression.gd")
var failures := 0
func _initialize() -> void:
 run.call_deferred()
func check(value: bool, copy: String) -> void:
 if not value:
  failures += 1
  push_error(copy)
func run() -> void:
 var model = MODEL.new()
 check(MODEL.CATEGORIES == ["Movement", "Body", "Elemental"], "Documented category order")
 check(model.tokens == 0 and model.level("super_leap") == 0, "New game starts with Power Jump")
 check(not model.purchase("flight"), "Unfunded purchase fails")
 model.add_tokens(35)
 check(model.purchase("flight") and model.level("super_leap") == 0, "Cores have no cross-branch prerequisite")
 for id in MODEL.POWERS:
  while model.level(id) < 3:
   var before: int = model.level(id)
   check(model.purchase(id) and model.level(id) == before + 1, "Purchases advance exactly one tier")
  check(not model.purchase(id), "Maximum tier enforced")
 check(model.tokens == 0, "Eight paid cores and 27 upgrades cost 35 test tokens")
 model.add_tokens(-5)
 check(model.tokens == 0, "Negative token grants rejected")
 var page = load("res://scenes/ui/powers_page.tscn").instantiate()
 page.progression = model
 root.add_child(page)
 page.open_page()
 for id in MODEL.POWERS:
  page.select_power(id)
  check(not page.title_label.text.begins_with("power."), "Translated power name")
  for i in 3:
   check(not page.upgrade_names[i].text.begins_with("power."), "All upgrade names resolve")
   check(not page.upgrade_descriptions[i].text.is_empty(), "All upgrade descriptions present")
 page.select_power("flight")
 check(page.upgrade_names[1].text == "Dive Bomb", "Flight upgrade two is Dive Bomb")
 check(page.upgrade_states[2].text.contains("PLANNED") and not page.upgrade_states[1].text.contains("PLANNED"), "Planned and implemented tiers distinguished")
 page.select_power("strength")
 check(page.implementation_label.text.contains("+5") and page.upgrade_names[1].text == "Vehicle Throw", "Strength describes its bonus and implemented lifting")
 page.free()
 print("Powers page: %s" % ("PASS" if failures == 0 else "FAIL"))
 quit(0 if failures == 0 else 1)
