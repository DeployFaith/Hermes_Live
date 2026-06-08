extends "res://addons/hermes_os/scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

var _playing: bool = false
var _current_time: float = 0.0
var _volume: float = 0.75
var _active_index: int = -1
var _audio_player: AudioStreamPlayer = null
var _video_player: VideoStreamPlayer = null
var _track_duration: float = 0.0
var _mode: String = "audio"
var _playback_started: bool = false
var _updating_seek: bool = false
var _progress_timer: Timer = null

var _audio_tracks: Array = [
	{"id": "t1", "title": "Neon Skyline", "artist": "Synthwave Collective", "file": "res://addons/hermes_os/assets/audio/neon_skyline.wav", "type": "audio"},
	{"id": "t2", "title": "Digital Rain", "artist": "Cipher", "file": "res://addons/hermes_os/assets/audio/digital_rain.wav", "type": "audio"},
	{"id": "t3", "title": "Midnight Protocol", "artist": "Ghost Signal", "file": "res://addons/hermes_os/assets/audio/midnight_protocol.wav", "type": "audio"},
	{"id": "t4", "title": "Electric Dreams", "artist": "Neon Pulse", "file": "res://addons/hermes_os/assets/audio/electric_dreams.wav", "type": "audio"},
	{"id": "t5", "title": "Binary Sunset", "artist": "The Algorithms", "file": "res://addons/hermes_os/assets/audio/binary_sunset.wav", "type": "audio"},
	{"id": "t6", "title": "Chrome Horizon", "artist": "Vapor Trail", "file": "res://addons/hermes_os/assets/audio/chrome_horizon.wav", "type": "audio"},
	{"id": "t7", "title": "Quantum Drift", "artist": "Parallax", "file": "res://addons/hermes_os/assets/audio/quantum_drift.wav", "type": "audio"},
	{"id": "t8", "title": "Pixel Heart", "artist": "Low Battery", "file": "res://addons/hermes_os/assets/audio/pixel_heart.wav", "type": "audio"},
	{"id": "v1", "title": "HermesOS Boot Splash", "artist": "HermesOS", "file": "res://addons/hermes_os/assets/video/hermes_os_boot_splash_v4.ogv", "type": "video"},
]

func _app_ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "MediaPlayerAudio"
	_audio_player.bus = "Master"
	_audio_player.volume_db = linear_to_db(_volume)
	if root_control != null:
		root_control.add_child(_audio_player)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "MediaPlayerVideo"
	_video_player.expand = true
	_video_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_video_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_player.visible = false
	if ui != null:
		var art = ui.by_id("mp-art")
		if art != null:
			art.add_child(_video_player)
			_fit_video_player()
			if not art.resized.is_connected(_fit_video_player):
				art.resized.connect(_fit_video_player)
	elif root_control != null:
		root_control.add_child(_video_player)

	if state == null:
		return
	var track_dicts: Array = []
	for t in _audio_tracks:
		var dur: float = 0.0
		if t["type"] == "audio":
			var stream = load(t["file"])
			if stream != null and stream.has_method("get_length"):
				dur = stream.get_length()
		var dur_str: String = _format_time(dur) if dur > 0.0 else "—"
		track_dicts.append({"id": t["id"], "title": t["title"], "artist": t["artist"], "duration_str": dur_str})
	state.set_many({
		"tracks": track_dicts, "active_track_id": "", "track_name": "No track selected",
		"track_artist": "", "playing": false, "play_icon": "▶", "play_label": "Play",
		"time_current": "0:00", "time_total": "0:00",
		"volume": _volume, "volume_icon": _volume_icon(_volume),
		"volume_label": "%d%%" % int(_volume * 100),
		"status": "Ready", "status_text": "Select a track to begin",
	})
	_hook_seek()
	_start_tick()
	_connect_art_doubleclick()

# --- Seek slider wiring ---

func _hook_seek() -> void:
	var seek = _find_seek()
	if seek != null and seek is Range:
		seek.editable = true
		if not seek.value_changed.is_connected(_on_seek_value_changed):
			seek.value_changed.connect(_on_seek_value_changed)

func _find_seek():
	if ui != null:
		var s = ui.by_id("mp-seek")
		if s != null and s is Range:
			return s
	if root_control != null and is_instance_valid(root_control):
		var s = root_control.find_child("mp-seek", true, false)
		if s != null and s is Range:
			return s
	return null

func _on_seek_value_changed(value: float) -> void:
	if _updating_seek:
		return
	print("[seek] user dragged to ", value)
	_do_seek(value)

func _do_seek(normalized: float) -> void:
	if _active_index < 0 or _active_index >= _audio_tracks.size():
		return
	var track: Dictionary = _audio_tracks[_active_index]
	var dur: float = _track_duration
	if dur <= 0.0:
		var stream = load(track["file"])
		if stream != null and stream.has_method("get_length"):
			dur = stream.get_length()
		if dur > 0.0:
			_track_duration = dur
	if dur <= 0.0:
		return

	var target: float = clampf(normalized, 0.0, 1.0) * dur

	if track["type"] == "video" and _video_player != null and is_instance_valid(_video_player):
		_video_player.stream_position = target
		if not _playing:
			_video_player.play()
			_playing = true
			_playback_started = true
			_update_play_btn()
	elif _audio_player != null:
		_audio_player.stop()
		_audio_player.play(target)
		if not _playing:
			_playing = true
			_playback_started = true
			_update_play_btn()

	_current_time = target
	state.set("time_current", _format_time(_current_time))

# --- Progress tick (Timer since controller is RefCounted, no _process) ---

func _start_tick() -> void:
	if root_control == null or not is_instance_valid(root_control):
		return
	if _progress_timer != null and is_instance_valid(_progress_timer):
		return
	_progress_timer = Timer.new()
	_progress_timer.name = "MediaProgressTick"
	_progress_timer.wait_time = 0.1
	_progress_timer.one_shot = false
	_progress_timer.autostart = true
	root_control.add_child(_progress_timer)
	_progress_timer.timeout.connect(_tick)

func _tick() -> void:
	if not _playing or _active_index < 0 or _active_index >= _audio_tracks.size():
		return

	var track: Dictionary = _audio_tracks[_active_index]
	var pos: float = 0.0
	var is_active: bool = false

	if track["type"] == "video":
		if _video_player != null and is_instance_valid(_video_player):
			is_active = _video_player.is_playing()
			if is_active:
				pos = _video_player.stream_position
			elif _playback_started:
				_on_track_finished()
				return
	else:
		if _audio_player != null:
			is_active = _audio_player.playing
			if is_active:
				pos = _audio_player.get_playback_position()
			elif _playback_started:
				_on_track_finished()
				return

	if is_active:
		_playback_started = true

	_current_time = pos
	_refresh_progress()

func _on_track_finished() -> void:
	_playing = false
	_playback_started = false
	_current_time = _track_duration
	_refresh_progress()
	_update_play_btn()

# --- Video fit ---

func _fit_video_player() -> void:
	if ui == null or _video_player == null or not is_instance_valid(_video_player):
		return
	var art = ui.by_id("mp-art")
	if art == null or not is_instance_valid(art):
		return
	_video_player.position = Vector2.ZERO
	_video_player.size = art.size
	_video_player.custom_minimum_size = art.size

# --- UI events ---

func select_track(event) -> void:
	var track_id: String = str(event.value) if event != null and event.get("value") != null else ""
	if track_id == "":
		return
	for i in range(_audio_tracks.size()):
		if _audio_tracks[i]["id"] == track_id:
			_play_track(i)
			return

func btn_play(event = null) -> void:
	if _active_index < 0:
		if _audio_tracks.size() > 0:
			_play_track(0)
		return

	if not _playing and _current_time >= _track_duration and _track_duration > 0.0:
		_play_track(_active_index)
		return

	var track: Dictionary = _audio_tracks[_active_index]
	if _playing:
		if track["type"] == "video" and _video_player != null and is_instance_valid(_video_player) and _video_player.is_playing():
			_video_player.paused = true
		elif _audio_player != null and _audio_player.playing:
			_current_time = _audio_player.get_playback_position()
			_audio_player.stop()
		_playing = false
	else:
		if track["type"] == "video" and _video_player != null and is_instance_valid(_video_player):
			_video_player.paused = false
			_playback_started = true
		elif _audio_player != null and _audio_player.stream != null:
			_audio_player.play(_current_time)
			_playback_started = true
		_playing = true
	_update_play_btn()

func btn_stop(event = null) -> void:
	_stop_playback()
	_current_time = 0.0
	_refresh_progress()
	_update_play_btn()
	_set_status_text("Stopped")

func btn_prev(event = null) -> void:
	if _audio_tracks.is_empty():
		return
	_play_track((_active_index - 1 + _audio_tracks.size()) % _audio_tracks.size())

func btn_next(event = null) -> void:
	if _audio_tracks.is_empty():
		return
	_play_track((_active_index + 1) % _audio_tracks.size())

func set_volume(event) -> void:
	var vol: float = 0.75
	if event != null:
		if event.get("value") != null:
			vol = float(event.value)
		elif event.get("raw_event") != null:
			vol = float(event.raw_event)
	_volume = clampf(vol, 0.0, 1.0)
	if _audio_player != null:
		_audio_player.volume_db = linear_to_db(_volume)
	if state != null:
		state.set_many({"volume": _volume, "volume_icon": _volume_icon(_volume), "volume_label": "%d%%" % int(_volume * 100)})

# --- Track playback ---

func _play_track(index: int) -> void:
	if index < 0 or index >= _audio_tracks.size():
		return
	_stop_playback()
	_active_index = index
	_current_time = 0.0
	_playback_started = false

	var track: Dictionary = _audio_tracks[index]
	var stream = load(track["file"])

	if track["type"] == "video":
		_mode = "video"
		if stream != null and _video_player != null and is_instance_valid(_video_player):
			_video_player.stream = stream
			_video_player.visible = true
			_video_player.play()
			_playback_started = true
			_playing = true
			_track_duration = stream.get_length() if stream.has_method("get_length") else 0.0
			if ui != null:
				var icon = ui.by_id("mp-art-icon")
				if icon != null: icon.visible = false
	else:
		_mode = "audio"
		if _video_player != null and is_instance_valid(_video_player):
			_video_player.stop()
			_video_player.visible = false
		if ui != null:
			var icon = ui.by_id("mp-art-icon")
			if icon != null: icon.visible = true
		if stream != null and _audio_player != null:
			_audio_player.stream = stream
			_audio_player.volume_db = linear_to_db(_volume)
			_audio_player.play()
			_playback_started = true
			_playing = true
			_track_duration = stream.get_length() if stream.has_method("get_length") else 0.0
		else:
			_playing = false
			_track_duration = 0.0

	if state != null:
		state.set_many({
			"active_track_id": track["id"], "track_name": track["title"], "track_artist": track["artist"],
			"time_total": _format_time(_track_duration) if _track_duration > 0.0 else "--:--",
			"time_current": "0:00", "status": _mode.to_upper(),
			"status_text": "%s — %s" % [track["title"], track["artist"]],
		})
	_reset_seek()
	_update_play_btn()

func _stop_playback() -> void:
	if _audio_player != null and _audio_player.playing:
		_audio_player.stop()
	if _video_player != null and is_instance_valid(_video_player) and _video_player.is_playing():
		_video_player.stop()
	_playing = false
	_playback_started = false

# --- UI updates ---

func _refresh_progress() -> void:
	if state == null:
		return
	if _track_duration > 0.0:
		var progress: float = clampf(_current_time / _track_duration, 0.0, 1.0)
		state.set("time_total", _format_time(_track_duration))
		var seek = _find_seek()
		if seek != null and seek is Range:
			_updating_seek = true
			seek.value = progress
			_updating_seek = false
	else:
		state.set("time_total", "--:--")
	state.set("time_current", _format_time(_current_time))

func _reset_seek() -> void:
	var seek = _find_seek()
	if seek != null and seek is Range:
		_updating_seek = true
		seek.value = 0.0
		_updating_seek = false

func _update_play_btn() -> void:
	if state == null:
		return
	state.set_many({"playing": _playing, "play_icon": "⏸" if _playing else "▶", "play_label": "Pause" if _playing else "Play"})
	if ui != null:
		var btn = ui.by_id("mp-btn-play")
		if btn != null and btn is Button:
			btn.text = "⏸" if _playing else "▶"

func _set_status_text(text: String) -> void:
	if ui != null:
		var el = ui.by_id("mp-status-text")
		if el != null and el is Label:
			el.text = text

func _format_time(seconds: float) -> String:
	var s: int = int(seconds)
	return "%d:%02d" % [s / 60, s % 60]

func _volume_icon(vol: float) -> String:
	if vol <= 0.0: return "🔇"
	elif vol < 0.33: return "🔈"
	elif vol < 0.66: return "🔉"
	return "🔊"

# --- Fullscreen ---

func _connect_art_doubleclick() -> void:
	if ui == null:
		return
	var art = ui.by_id("mp-art")
	if art != null and is_instance_valid(art) and not art.gui_input.is_connected(_on_art_input):
		art.gui_input.connect(_on_art_input)

func _on_art_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click:
		toggle_fullscreen()

func toggle_fullscreen(event = null) -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
