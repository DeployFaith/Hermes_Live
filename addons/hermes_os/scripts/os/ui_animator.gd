class_name UIAnimator
extends RefCounted

const Tokens := preload("res://addons/hermes_os/scripts/os/design_tokens.gd")

# ── Internal ──
var _active_tweens: Dictionary = {}

func _kill_existing(node: Node) -> void:
	if _active_tweens.has(node.get_instance_id()):
		var old: Tween = _active_tweens[node.get_instance_id()]
		if is_instance_valid(old):
			old.kill()
		_active_tweens.erase(node.get_instance_id())

func _store_tween(node: Node, tween: Tween) -> void:
	_active_tweens[node.get_instance_id()] = tween
	tween.finished.connect(func() -> void:
		if _active_tweens.has(node.get_instance_id()):
			_active_tweens.erase(node.get_instance_id())
	)

# ── Fade ──
func fade_in(node: CanvasItem, duration: float = Tokens.TIME["normal"]) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	_store_tween(node, tween)

func fade_out(node: CanvasItem, duration: float = Tokens.TIME["fast"], then_free: bool = false) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	_store_tween(node, tween)
	if then_free:
		tween.finished.connect(func() -> void:
			if is_instance_valid(node):
				node.queue_free()
		)

# ── Scale Pop ──
func scale_pop(node: CanvasItem, duration: float = Tokens.TIME["normal"]) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	node.scale = Vector2(0.94, 0.94)
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration)
	_store_tween(node, tween)

# ── Slide From Bottom ──
func slide_from_bottom(node: Control, distance: float = 24.0, duration: float = Tokens.TIME["normal"]) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	var base_y: float = node.position.y
	node.position.y = base_y + distance
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(node, "position:y", base_y, duration)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	_store_tween(node, tween)

# ── Tint Hover ──
func tint_hover(node: CanvasItem, from_color: Color, to_color: Color, duration: float = Tokens.TIME["fast"]) -> Tween:
	if node == null or not is_instance_valid(node):
		return null
	_kill_existing(node)
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate", to_color, duration).from(from_color)
	_store_tween(node, tween)
	return tween

# ── Shadow Lift ──
func shadow_lift(stylebox: StyleBoxFlat, from_shadow: Dictionary, to_shadow: Dictionary, duration: float = Tokens.TIME["fast"]) -> void:
	if stylebox == null:
		return
	var tween: Tween = Engine.get_main_loop().root.create_tween()
	# StyleBoxFlat properties are not directly tweenable objects in all Godot versions.
	# Use a callback approach.
	var elapsed: float = 0.0
	var timer: Timer = Timer.new()
	timer.wait_time = 0.016
	timer.one_shot = false
	Engine.get_main_loop().root.add_child(timer)
	timer.timeout.connect(func() -> void:
		elapsed += timer.wait_time
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - t, 2.0)
		stylebox.shadow_size = int(lerpf(float(from_shadow["size"]), float(to_shadow["size"]), ease_t))
		stylebox.shadow_color = from_shadow["color"].lerp(to_shadow["color"], ease_t)
		stylebox.shadow_offset = from_shadow["offset"].lerp(to_shadow["offset"], ease_t)
		if t >= 1.0:
			timer.stop()
			timer.queue_free()
	)
	timer.start()

# ── Scale In / Out ──
func scale_in(node: CanvasItem, duration: float = Tokens.TIME["normal"]) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	node.scale = Vector2(0.92, 0.92)
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	_store_tween(node, tween)

func scale_out(node: CanvasItem, duration: float = Tokens.TIME["fast"], then_free: bool = false) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.set_parallel()
	tween.tween_property(node, "scale", Vector2(0.95, 0.95), duration)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	_store_tween(node, tween)
	if then_free:
		tween.finished.connect(func() -> void:
			if is_instance_valid(node):
				node.queue_free()
		)

# ── Pulse ──
func pulse(node: CanvasItem, intensity: float = 0.05, duration: float = 0.6) -> Tween:
	if node == null or not is_instance_valid(node):
		return null
	_kill_existing(node)
	var base_scale: Vector2 = node.scale
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", base_scale * (1.0 + intensity), duration * 0.5)
	tween.tween_property(node, "scale", base_scale, duration * 0.5)
	tween.set_loops()
	_store_tween(node, tween)
	return tween

# ── Stop all on node ──
func stop(node: CanvasItem) -> void:
	_kill_existing(node)

# ── New helpers for window/menu polish (new Tweens only, reuse _kill/store) ──
# Snappy 90-180ms: open (fade + scale 0.95->1.0 + y-offset)
func window_open(node: CanvasItem, duration: float = 0.14) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	node.modulate.a = 0.0
	node.scale = Vector2(0.95, 0.95)
	if node is Control:
		var base_y = node.position.y
		node.position.y = base_y + 12
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration)
	if node is Control:
		tween.tween_property(node, "position:y", node.position.y - 12, duration)
	_store_tween(node, tween)

# Close (fade + scale 1.0->0.95)
func window_close(node: CanvasItem, duration: float = 0.10, then_free: bool = false) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.set_parallel()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_property(node, "scale", Vector2(0.95, 0.95), duration)
	_store_tween(node, tween)
	if then_free:
		tween.finished.connect(func() -> void:
			if is_instance_valid(node):
				node.queue_free()
		)

# Hover lift for dock/icons (subtle elevation)
func hover_lift(node: CanvasItem, lift: float = 4.0, duration: float = 0.08) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	var base_y = node.position.y if node is Control else 0.0
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:y", base_y - lift, duration)
	_store_tween(node, tween)

# Menu pop for start menu
func menu_pop(node: CanvasItem, duration: float = 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	_kill_existing(node)
	node.modulate.a = 0.0
	node.scale = Vector2(0.96, 0.96)
	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(node, "modulate:a", 1.0, duration)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration)
	_store_tween(node, tween)
