extends Node
## One coordinator lives on each target, shared across encounters/factions.
## Weak references avoid keeping enemies alive; FIFO gives waiting thugs a turn.
const MAX_ATTACKERS := 2
var _holders: Array[WeakRef] = []
var _waiting: Array[WeakRef] = []

func request_slot(enemy: Node) -> bool:
	_prune()
	if _contains(_holders, enemy):
		return true
	if not _contains(_waiting, enemy):
		_waiting.append(weakref(enemy))
	# An exclusive turn waits for both normal holders to finish. Once it is
	# first in line, later arrivals cannot fill the vacancies and starve it.
	for holder in _holders:
		if holder.get_ref().wants_exclusive_melee_turn():
			return false
	if enemy.wants_exclusive_melee_turn() and not _holders.is_empty():
		return false
	if _holders.size() < MAX_ATTACKERS and _waiting[0].get_ref() == enemy:
		_waiting.pop_front()
		_holders.append(weakref(enemy))
		return true
	return false

func release(enemy: Node) -> void:
	for list in [_holders, _waiting]:
		for index in range(list.size() - 1, -1, -1):
			if list[index].get_ref() == enemy:
				list.remove_at(index)
	_prune()

func active_count() -> int:
	_prune()
	return _holders.size()

func _contains(list: Array[WeakRef], enemy: Node) -> bool:
	for entry in list:
		if entry.get_ref() == enemy:
			return true
	return false

func _prune() -> void:
	for list in [_holders, _waiting]:
		for index in range(list.size() - 1, -1, -1):
			var enemy = list[index].get_ref()
			if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_dead or enemy.combat_target != get_parent():
				list.remove_at(index)
