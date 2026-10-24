extends Resource
## Central tuning values. Runtime state is kept on FlightController/RunController.

const VIEW_SIZE := Vector2(1280.0, 720.0)
# A wider reference car keeps its hurt box inside the visible body.
const PLAYER_X := 180.0
const START_Y := 350.0
const TOP_Y := 136.0
const GROUND_Y := 638.0
const RESCUE_Y := 397.0
const GRAVITY := 1000.0
const THRUST_ACCELERATION := 1800.0
const MAX_VERTICAL_SPEED := 430.0
const MAX_FUEL := 100.0
const THRUST_FUEL_PER_SECOND := 10.0
const IDLE_FUEL_PER_SECOND := 1.0
const TANK_FUEL := 35.0
const COIN_FUEL := 1.0
const MAX_HEALTH := 3
const HURT_PROTECTION := 1.2
const START_SPEED := 340.0
const MAX_SPEED := 620.0
const SPEED_RAMP_SECONDS := 180.0
const START_GATE_INTERVAL := 3.9
const MIN_GATE_INTERVAL := 1.7
const MIN_VISIBLE_REACTION_SECONDS := 1.5
const CAR_HALF_WIDTH := 56.0
const HAZARD_VISUAL_HALF_WIDTH := 58.0
const HAZARD_COLLISION_HALF_WIDTH := 55.0
const COUNTDOWN_SECONDS := 2.4
const METERS_PER_PIXEL := 0.08
const TRAINING_SECONDS := 10.0

static func difficulty_at(seconds: float) -> float:
	return clampf(seconds / SPEED_RAMP_SECONDS, 0.0, 1.0)

static func speed_at(seconds: float) -> float:
	return lerpf(START_SPEED, MAX_SPEED, difficulty_at(seconds))

static func gate_interval_at(seconds: float) -> float:
	var progress := clampf((seconds - TRAINING_SECONDS) / (SPEED_RAMP_SECONDS - TRAINING_SECONDS), 0.0, 1.0)
	return lerpf(START_GATE_INTERVAL, MIN_GATE_INTERVAL, progress)

static func gate_opening_at(seconds: float) -> float:
	return lerpf(224.0, 184.0, difficulty_at(seconds))

static func visible_reaction_time_at(seconds: float) -> float:
	# Count only after the entire pillar is visible, until hurt boxes touch.
	return (VIEW_SIZE.x - HAZARD_VISUAL_HALF_WIDTH - PLAYER_X - CAR_HALF_WIDTH - HAZARD_COLLISION_HALF_WIDTH) / speed_at(seconds)

