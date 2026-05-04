extends RefCounted
class_name HushlingStateMachine

enum State {
	WANDER,
	REGROUP,
	OBSERVE,
	FOLLOW,
	FLEE,
	STARTLED,
}

const WANDER: int = State.WANDER
const REGROUP: int = State.REGROUP
const OBSERVE: int = State.OBSERVE
const FOLLOW: int = State.FOLLOW
const FLEE: int = State.FLEE
const STARTLED: int = State.STARTLED

const STATE_NAMES: Dictionary = {
	State.WANDER: "WANDER",
	State.REGROUP: "REGROUP",
	State.OBSERVE: "OBSERVE",
	State.FOLLOW: "FOLLOW",
	State.FLEE: "FLEE",
	State.STARTLED: "STARTLED",
}


static func state_name(state: int) -> String:
	return String(STATE_NAMES.get(state, "WANDER"))


static func choose_state(current_state: int, facts: Dictionary) -> int:
	if should_flee(facts):
		return State.FLEE

	if current_state == State.FLEE and not is_safe_to_stop_fleeing(facts):
		return State.FLEE

	if current_state == State.STARTLED and not is_startle_finished(facts):
		return State.STARTLED

	if should_startle(facts):
		return State.STARTLED

	if should_follow(facts, current_state):
		return State.FOLLOW

	if should_observe(facts):
		return State.OBSERVE

	if should_regroup(facts, current_state):
		return State.REGROUP

	return State.WANDER


static func should_flee(facts: Dictionary) -> bool:
	if bool(facts.get("player_hand_flee_active", false)):
		return true

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


static func should_startle(facts: Dictionary) -> bool:
	return bool(facts.get("player_gaze_startle_active", false))


static func is_startle_finished(facts: Dictionary) -> bool:
	return float(facts.get("startled_time_remaining", 0.0)) <= 0.0


static func is_safe_to_stop_fleeing(facts: Dictionary) -> bool:
	var flee_target_distance: float = float(facts.get("flee_target_distance", -1.0))
	var flee_safe_radius: float = float(facts.get("flee_safe_radius", 0.0))
	if flee_target_distance < 0.0:
		return true

	return flee_target_distance >= flee_safe_radius


static func should_follow(facts: Dictionary, current_state: int = -1) -> bool:
	if not _can_watch_interest(facts):
		return false

	var curiosity: float = float(facts.get("curiosity", 0.0))
	var follow_curiosity_threshold: float = float(facts.get(
		"follow_curiosity_threshold",
		facts.get("curiosity_observe_threshold", 1.0)
	))
	if curiosity < follow_curiosity_threshold:
		return false

	var confidence: float = float(facts.get("confidence", 0.0))
	var follow_confidence_threshold: float = float(facts.get("follow_confidence_threshold", 1.0))
	if confidence < follow_confidence_threshold:
		return false

	var interest_distance: float = float(facts.get("interest_distance", -1.0))
	var follow_distance: float = float(facts.get("follow_distance", 0.0))
	var follow_start_margin: float = float(facts.get("follow_start_margin", 0.0))
	var follow_start_distance: float = float(facts.get(
		"follow_start_distance",
		follow_distance + follow_start_margin
	))
	if current_state == State.FOLLOW:
		return interest_distance > follow_distance + follow_start_margin

	return interest_distance >= follow_start_distance


static func should_observe(facts: Dictionary) -> bool:
	if not _can_watch_interest(facts):
		return false

	var curiosity: float = float(facts.get("curiosity", 0.0))
	var curiosity_observe_threshold: float = float(facts.get("curiosity_observe_threshold", 1.0))
	return curiosity >= curiosity_observe_threshold


static func should_regroup(facts: Dictionary, current_state: int = -1) -> bool:
	if not bool(facts.get("has_regroup_target", false)):
		return false

	var loneliness: float = float(facts.get("loneliness", 0.0))
	var enter_threshold: float = float(facts.get("regroup_loneliness_threshold", 1.0))
	var exit_threshold: float = float(facts.get(
		"regroup_exit_loneliness",
		max(enter_threshold * 0.55, 0.0)
	))

	if current_state == State.REGROUP:
		return loneliness > exit_threshold

	return loneliness >= enter_threshold


static func _can_watch_interest(facts: Dictionary) -> bool:
	if not bool(facts.get("has_interest", false)):
		return false
	if not bool(facts.get("interest_visible", false)):
		return false

	var interest_distance: float = float(facts.get("interest_distance", -1.0))
	var awareness_radius: float = float(facts.get("awareness_radius", 0.0))
	if interest_distance < 0.0 or interest_distance > awareness_radius:
		return false

	var effective_fear: float = float(facts.get("effective_fear", facts.get("fear", 0.0)))
	var fear_flee_threshold: float = float(facts.get("fear_flee_threshold", 1.0))
	return effective_fear < fear_flee_threshold
