## @brief Simulates a day-night cycle by rotating a DirectionalLight3D and
## blending its colour between configurable day and night values.

@tool
class_name DayNightCycle extends Node

## DirectionalLight3D that acts as the sun.
@export var sun_light: DirectionalLight3D = null

## Duration of one full day in real-time minutes.
@export_range(0.1, 60.0, 0.1) var day_duration_minutes: float = 5.0

## Light colour at solar noon (sun directly overhead).
@export var day_color: Color = Color(1.0, 0.95, 0.85)

## Light colour at midnight (sun below horizon — light is very dim).
@export var night_color: Color = Color(0.05, 0.07, 0.15)

## Light energy at solar noon.
@export_range(0.0, 8.0, 0.05) var day_energy: float = 1.0

## Light energy at midnight.
@export_range(0.0, 2.0, 0.05) var night_energy: float = 0.0

## Starting time of day expressed as a fraction of a full day [0, 1).
## 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
@export_range(0.0, 1.0, 0.01) var initial_time_of_day: float = 0.25

## Whether the cycle is running.
@export var running: bool = true

## Multiplier applied to the passage of time.
## 0 = paused, 1 = normal, >1 = fast-forward, <0 = reverse.
@export_range(-10.0, 10.0, 0.1) var time_scale: float = 1.0

## Optional Curve that maps the above-horizon blend value [0,1] to a custom
## energy multiplier.  The X axis is the raw sin-based blend (0 at horizon,
## 1 at noon); the Y axis is the multiplier applied to light_energy.
## Leave null to use a plain linear blend.
## Example: a bell curve peaking at 0.5 creates a soft golden-hour effect.
@export var energy_curve: Curve = null

## Optional second DirectionalLight3D used as the moon.
## It is automatically kept 180° opposite the sun on the X axis.
@export var moon_light: DirectionalLight3D = null

## Moon light colour.
@export var moon_color: Color = Color(0.4, 0.5, 0.7)

## Moon maximum energy (reached at midnight when fully above horizon).
@export_range(0.0, 2.0, 0.05) var moon_max_energy: float = 0.2

## Optional WorldEnvironment node.  When assigned, ambient light colour and
## (if the sky uses a ShaderMaterial) the "time_of_day" uniform are updated
## every frame.
@export var world_environment: WorldEnvironment = null

## Ambient light colour during the day.
@export var ambient_day_color: Color = Color(0.6, 0.65, 0.8)

## Ambient light colour during the night.
@export var ambient_night_color: Color = Color(0.02, 0.03, 0.08)

## Ambient energy at noon.
@export_range(0.0, 4.0, 0.05) var ambient_day_energy: float = 1.0

## Ambient energy at midnight.
@export_range(0.0, 1.0, 0.05) var ambient_night_energy: float = 0.05

## Name of the sky shader uniform to receive the normalised time-of-day
## value [0,1].  Set to "" to skip sky shader updates.
@export var sky_time_uniform: String = "time_of_day"

## Current time of day as a fraction [0, 1). Read-only from outside.
var time_of_day: float = 0.0

## Emitted once per day when the sun crosses the horizon going up (sunrise).
signal sunrise
## Emitted once per day when the sun crosses the horizon going down (sunset).
signal sunset

var _prev_time_of_day: float = 0.0

const SUNRISE_FRACTION: float = 0.25
const SUNSET_FRACTION:  float = 0.75

func _ready() -> void:
	time_of_day = initial_time_of_day
	_prev_time_of_day = time_of_day
	_apply(time_of_day)


func _process(delta: float) -> void:
	if not running or Engine.is_editor_hint():
		return
	if not sun_light or not is_instance_valid(sun_light):
		return
	var day_duration_seconds: float = day_duration_minutes * 60.0
	if day_duration_seconds <= 0.0:
		return
	_prev_time_of_day = time_of_day
	time_of_day = fmod(time_of_day + (delta * time_scale) / day_duration_seconds, 1.0)
	if time_of_day < 0.0:
		time_of_day += 1.0
	_check_events()
	_apply(time_of_day)

## Apply all visual changes for the given time fraction.
func _apply(t: float) -> void:
	if not sun_light or not is_instance_valid(sun_light):
		return
	var angle_deg: float = t * 360.0 - 90.0
	sun_light.rotation_degrees.x = angle_deg
	var above_horizon: float = -cos(t * TAU)
	var blend: float = clampf(above_horizon, 0.0, 1.0)
	sun_light.light_color = night_color.lerp(day_color, blend)
	var energy_blend: float = blend
	if energy_curve:
		energy_blend = energy_curve.sample(blend)
	sun_light.light_energy = lerpf(night_energy, day_energy, energy_blend)
	if moon_light and is_instance_valid(moon_light):
		moon_light.rotation_degrees.x = angle_deg + 180.0
		var moon_above: float = clampf(-above_horizon, 0.0, 1.0)  # inverse of sun
		moon_light.light_color = moon_color
		moon_light.light_energy = moon_max_energy * moon_above
	if world_environment and is_instance_valid(world_environment):
		var env := world_environment.environment
		if env:
			env.ambient_light_color = ambient_night_color.lerp(ambient_day_color, blend)
			env.ambient_light_energy = lerpf(ambient_night_energy, ambient_day_energy, blend)
			if sky_time_uniform != "" and env.sky and env.sky.sky_material:
				var mat := env.sky.sky_material
				if mat is ShaderMaterial:
					(mat as ShaderMaterial).set_shader_parameter(sky_time_uniform, t)


## Fire sunrise / sunset signals when the time crosses the horizon fractions.
func _check_events() -> void:
	var prev := _prev_time_of_day
	var curr := time_of_day
	if curr < prev:
		_check_crossing(prev, 1.0)
		_check_crossing(0.0, curr)
	else:
		_check_crossing(prev, curr)

## Check whether a threshold is crossed within the half-open interval
## [from, to).  Works for both normal and wrap-around sub-intervals.
func _check_crossing(from: float, to: float) -> void:
	if from < SUNRISE_FRACTION and to >= SUNRISE_FRACTION:
		sunrise.emit()
	if from < SUNSET_FRACTION and to >= SUNSET_FRACTION:
		sunset.emit()

## Jump to a specific time of day without waiting for the cycle.
## @param t  Normalised time [0, 1). 0 = midnight, 0.5 = noon.
func set_time(t: float) -> void:
	time_of_day = fmod(t, 1.0)
	_prev_time_of_day = time_of_day
	_apply(time_of_day)


## Returns true when the sun is above the horizon.
func is_daytime() -> bool:
	return time_of_day > SUNRISE_FRACTION and time_of_day < SUNSET_FRACTION
