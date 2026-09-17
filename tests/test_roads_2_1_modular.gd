extends "res://tests/test_city_modular_roads.gd"
## Keep this regression entry point after pavement moved into road modules.
func include_chunk(name: String) -> bool: return name == "roads_2_1"
