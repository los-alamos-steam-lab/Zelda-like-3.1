extends KinematicBody2D

class_name Entity

# ATTRIBUTES
# These are settable in the inspector
export(String, "ENEMY", "PLAYER")	var TYPE 		= "ENEMY"
# (float, min, max, increment)
export(float, 0.5, 20, 0.5) 		var MAX_HEALTH 	= 1
export(int) 						var SPEED 		= 70
export(float, 0, 20, 0.5) 		var DAMAGE 		= 0.5
export(String, FILE) 			var HURT_SOUND 	= "res://enemies/enemy_hurt.wav"

# MOVEMENT
var movedir = Vector2.ZERO
var knockdir = Vector2.ZERO
var spritedir = "Down"

# COMBAT
var health = MAX_HEALTH
var hitstun = 0

var state = "default"

var home_position = Vector2.ZERO

# This makes it so not every entity class has to name these 
# nodes the same thing.  These get loaded a moment after the entity
onready var anim = $AnimationPlayer
onready var sprite = $Sprite
onready var hitbox = $Hitbox

onready var camera = get_parent().get_node("Camera")

var texture_default = null
var texture_hurt = null

func _ready():
	texture_default = sprite.texture
	texture_hurt = load(sprite.texture.get_path().replace(".png","_hurt.png"))
	add_to_group("entity")
	health = MAX_HEALTH
	home_position = position
	
	# the camera sends these signals
	camera.connect("screen_change_started", self, "screen_change_started")
	camera.connect("screen_change_completed", self, "screen_change_completed")

func loop_movement():
	var motion
	if hitstun == 0:
		motion = movedir.normalized() * SPEED
	else:
		motion = knockdir.normalized() * 125
	move_and_slide(motion)

func loop_spritedir():
	match movedir:
		Vector2.LEFT:
			spritedir = "Left"
		Vector2.RIGHT:
			spritedir = "Right"
		Vector2.UP:
			spritedir = "Up"
		Vector2.DOWN:
			spritedir = "Down"
	# This is a unary if statement.  sprite.flip_h is  set to the 
	# return of spritedir == "Left" (true or false)
	# This lets us not need separate anims for left and right
	sprite.flip_h = spritedir == "Left"

func loop_damage():
	health = min(health, MAX_HEALTH)
	
	if hitstun > 0:
		hitstun -= 1
		sprite.texture = texture_hurt
	else:
		sprite.texture = texture_default
		if TYPE == "ENEMY" && health <= 0:
			var drop = randi() % 4
			if drop == 0:
				instance_scene(preload("res://pickups/heart.tscn"))
			enemy_death()
	
	for area in hitbox.get_overlapping_areas():
		var body = area.get_parent()
		
		# if the entity isn't in hitstun, and the overlapping body gives damage
		# and the overlapping body is of a different type
		if hitstun == 0 && body.get("DAMAGE") && body.get("DAMAGE") > 0 && body.get("TYPE") != TYPE:
			health -= body.DAMAGE
			hitstun = 10
			knockdir = global_position - body.global_position
			sfx.play(load(HURT_SOUND))
			
			if body.get("delete_on_hit") == true:
				body.delete()

func anim_switch(animation):
	var newanim = str(animation,spritedir)
	
	# if sprite dir is Left or Right
	if spritedir in ["Left","Right"]:
		newanim = str(animation,"Side")
	if anim.current_animation != newanim:
		anim.play(newanim)

func use_item(item, input):
	var newitem = item.instance()
	var itemgroup = str(item,self)
	newitem.add_to_group(itemgroup)
	add_child(newitem)
	if get_tree().get_nodes_in_group(itemgroup).size() > newitem.MAX_AMOUNT:
		newitem.queue_free()
		return
	newitem.input = input
	newitem.start()

func instance_scene(scene):
	var new_scene = scene.instance()
	new_scene.global_position = global_position
	get_parent().add_child(new_scene)

func enemy_death():
	instance_scene(preload("res://enemies/enemy_death.tscn"))
	queue_free()

func screen_change_started():
	set_physics_process(false)
	
	# if the entity is an entity and no longer on camera then reset it
	if TYPE == "ENEMY":
		if !camera.camera_rect.has_point(position):
			reset()

func screen_change_completed():
	set_physics_process(true)
	
	# If the entity is an enemy and not on camera don't run physics_process
	if TYPE == "ENEMY":
		if !camera.camera_rect.has_point(position):
			set_physics_process(false)

# creates a new identical entity with it's original position
# deletes the current entity
# this also resets health
func reset():
	var new_instance = load(filename).instance()
	get_parent().add_child(new_instance)
	new_instance.position = home_position
	new_instance.home_position = home_position
	new_instance.set_physics_process(false)
	queue_free()

# put into helper script pls
static func rand_direction():
	var new_direction = randi() % 4
	match new_direction:
		0:
			return Vector2.LEFT
		1:
			return Vector2.RIGHT
		2:
			return Vector2.UP
		3:
			return Vector2.DOWN
