extends CharacterBody2D
## Movement follows the Godot 4 CharacterBody2D pattern: velocity has pixels/s,
## acceleration is integrated with delta, move_and_slide() takes no delta.
## https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html

signal fuel_changed(value: float)
signal damaged(remaining_health: int, cause: String)
signal died
signal rescued(refueled: bool)

const Balance = preload("res://scripts/game_balance.gd")

var fuel: float = Balance.MAX_FUEL
var health: int = Balance.MAX_HEALTH
var protection_left: float = 0.0
var thrusting: bool = false
var visual: Node2D
var death_emitted: bool = false
var touching_hazards: Dictionary = {}

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Balance.CAR_HALF_WIDTH * 2.0, 30.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	visual = load("res://visuals/roadster_visual.gd").new()
	add_child(visual)
	reset_flight()

func reset_flight() -> void:
	position = Vector2(Balance.PLAYER_X, Balance.START_Y)
	velocity = Vector2.ZERO
	fuel = Balance.MAX_FUEL
	health = Balance.MAX_HEALTH
	protection_left = 0.0
	thrusting = false
	death_emitted = false
	touching_hazards.clear()
	update_visual()

func simulate(delta: float, wants_thrust: bool) -> void:
	if health <= 0:
		return
	protection_left = maxf(0.0, protection_left - delta)
	thrusting = wants_thrust and fuel > 0.0
	consume_fuel(delta, thrusting)
	var acceleration := Balance.GRAVITY
	if thrusting:
		acceleration -= Balance.THRUST_ACCELERATION
	velocity.y = clampf(velocity.y + acceleration * delta, -Balance.MAX_VERTICAL_SPEED, Balance.MAX_VERTICAL_SPEED)
	velocity.x = 0.0
	move_and_slide()
	position.x = Balance.PLAYER_X
	if position.y < Balance.TOP_Y:
		position.y = Balance.TOP_Y
		velocity.y = maxf(0.0, velocity.y)
	if position.y >= Balance.GROUND_Y:
		hit_ground()
	update_visual()

func consume_fuel(delta: float, active_thrust: bool) -> void:
	var rate: float = Balance.THRUST_FUEL_PER_SECOND if active_thrust else Balance.IDLE_FUEL_PER_SECOND
	fuel = maxf(0.0, fuel - rate * delta)
	fuel_changed.emit(fuel)

func add_fuel(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, Balance.MAX_FUEL)
	fuel_changed.emit(fuel)

func enter_hazard(hazard_id: int) -> bool:
	if touching_hazards.has(hazard_id):
		return false
	touching_hazards[hazard_id] = true
	if protection_left > 0.0:
		return false
	return take_damage("碰撞障碍")

func leave_hazard(hazard_id: int) -> void:
	touching_hazards.erase(hazard_id)

func take_damage(cause: String, bypass_protection: bool = false) -> bool:
	if health <= 0 or (protection_left > 0.0 and not bypass_protection):
		return false
	health -= 1
	protection_left = Balance.HURT_PROTECTION
	damaged.emit(health, cause)
	if health == 0 and not death_emitted:
		death_emitted = true
		thrusting = false
		died.emit()
	update_visual()
	return true

func hit_ground() -> void:
	# Each separate fall costs one life, even during obstacle protection.
	if health <= 0:
		return
	var ran_out_of_fuel := fuel <= 0.0
	take_damage("氮气耗尽坠落" if ran_out_of_fuel else "触地坠落", true)
	if health > 0:
		position.y = Balance.RESCUE_Y
		velocity.y = 0.0
		if ran_out_of_fuel:
			fuel = Balance.MAX_FUEL * 0.5
			fuel_changed.emit(fuel)
		rescued.emit(ran_out_of_fuel)

func update_visual() -> void:
	if not is_instance_valid(visual):
		return
	visual.set("thrusting", thrusting)
	visual.set("vertical_speed", velocity.y)
	visual.set("invulnerable", protection_left > 0.0)

