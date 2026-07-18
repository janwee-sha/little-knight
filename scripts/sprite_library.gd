extends RefCounted

## Runtime loader for normalized, bottom-centered animation frames.

static func create_animated_sprite(
	character: String,
	animations: Array,
	canvas_size := 128,
	display_scale := 0.52
) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for definition in animations:
		var animation_name := StringName(definition["name"])
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(definition["fps"]))
		frames.set_animation_loop(animation_name, bool(definition["loop"]))
		var frame_count := int(definition["frames"])
		for frame_number in range(1, frame_count + 1):
			var path := "res://assets/sprites/runtime/%s/%s/%02d.png" % [
				character, String(animation_name), frame_number
			]
			var texture := load(path) as Texture2D
			if texture:
				frames.add_frame(animation_name, texture)
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.position = Vector2(0.0, -float(canvas_size) * display_scale * 0.5)
	sprite.scale = Vector2.ONE * display_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 2
	return sprite


static func play(sprite: AnimatedSprite2D, animation_name: StringName, restart := false) -> void:
	if not is_instance_valid(sprite) or not sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or sprite.animation != animation_name:
		sprite.play(animation_name)
