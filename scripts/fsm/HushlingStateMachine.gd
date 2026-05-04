extends RefCounted
class_name HushlingStateMachine

enum State {
	WANDER,
	OBSERVE,
	FLEE,
}

const WANDER: int = State.WANDER
const OBSERVE: int = State.OBSERVE
const FLEE: int = State.FLEE

const STATE_NAMES: Dictionary = {
	State.WANDER: "WANDER",
	State.OBSERVE: "OBSERVE",
	State.FLEE: "FLEE",
}


static func state_name(state: int) -> String:
	return String(STATE_NAMES.get(state, "WANDER"))


static func choose_state(current_state: int, facts: Dictionary) -> int:
	if should_flee(facts):
		return State.FLEE

	if current_state == State.FLEE and not is_safe_to_stop_fleeing(facts):
		return State.FLEE

	if should_observe(facts):
		return State.OBSERVE

	return State.WANDER


static func should_flee(facts: Dictionary) -> bool:
	var threat_distance: float = float(facts.get("threat_distance", -1.0))
	var threat_flee_radius: float = float(facts.get("threat_flee_radius", 0.0))
	if threat_distance >= 0.0 and threat_distance <= threat_flee_radius:
		return true

	var interest_distance: float = float(facts.get("interest_distance", -1.0))
	var interest_flee_radius: float = float(facts.get("interest_flee_radius", 0.0))
	var interest_visible: bool = bool(facts.get("interest_visible", true))
	if interest_visible and interest_distance >= 0.0 and interest_distance <= interest_flee_radius:
		return true

	var interest_sees_agent: bool = bool(facts.get("interest_sees_agent", false))
	var effective_fear: float = float(facts.get("effective_fear", facts.get("fear", 0.0)))
	var fear_flee_threshold: float = float(facts.get("fear_flee_threshold", 1.0))
	if interest_sees_agent and effective_fear >= fear_flee_threshold:
		return true

	return bool(facts.get("group_flee_active", false))


static func is_safe_to_stop_fleeing(facts: Dictionary) -> bool:
	var flee_target_distance: float = float(facts.get("flee_target_distance", -1.0))
	var flee_safe_radius: float = float(facts.get("flee_safe_radius", 0.0))
	if flee_target_distance < 0.0:
		return true

	return flee_target_distance >= flee_safe_radius


static func should_observe(facts: Dictionary) -> bool:
	if not bool(facts.get("has_interest", false)):
		return false
	if not bool(facts.get("interest_visible", false)):
		return false

	var interest_distance: float = float(facts.get("interest_distance", -1.0))
	var awareness_radius: float = float(facts.get("awareness_radius", 0.0))
	if interest_distance < 0.0 or interest_distance > awareness_radius:
		return false

	var curiosity: float = float(facts.get("curiosity", 0.0))
	var curiosity_observe_threshold: float = float(facts.get("curiosity_observe_threshold", 1.0))
	if curiosity < curiosity_observe_threshold:
		return false

	var effective_fear: float = float(facts.get("effective_fear", facts.get("fear", 0.0)))
	var fear_flee_threshold: float = float(facts.get("fear_flee_threshold", 1.0))
	return effective_fear < fear_flee_threshold
