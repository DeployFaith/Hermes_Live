class_name HermesRefs
extends RefCounted

const META_KEY := "hermes_ui_meta"

static func make_ref(app_id: String, local_ref: String, window_id: String = "") -> String:
	var clean_app := app_id.strip_edges().to_lower()
	var clean_local := local_ref.strip_edges().to_lower()
	clean_app = clean_app.replace(" ", "_")
	clean_local = clean_local.replace(" ", "_")
	var ref := clean_app + "." + clean_local
	if window_id.strip_edges() != "":
		ref = window_id.strip_edges() + ":" + ref
	return ref

static func attach_meta(control: Control, meta: Dictionary) -> void:
	if control == null:
		return
	var clean := meta.duplicate(true)
	var has_ref := str(clean.get("ref", "")).strip_edges() != ""
	var has_role := str(clean.get("role", clean.get("mcp_role", ""))).strip_edges() != ""
	if not has_ref and not has_role:
		push_warning("HermesRefs.attach_meta expected at least ref or role")
	var default_enabled := true
	if control is BaseButton:
		default_enabled = not (control as BaseButton).disabled
	clean["enabled"] = bool(clean.get("enabled", default_enabled))
	clean["visible"] = bool(clean.get("visible", control.visible))
	control.set_meta(META_KEY, clean)

static func get_attached_meta(control: Control) -> Dictionary:
	if control == null or not control.has_meta(META_KEY):
		return {}
	var meta: Variant = control.get_meta(META_KEY)
	if meta is Dictionary:
		return (meta as Dictionary).duplicate(true)
	return {}

static func validate_ref(ref: String) -> bool:
	var clean := ref.strip_edges()
	if clean == "":
		return false
	var scoped := clean
	if clean.contains(":"):
		var parts := clean.split(":", false, 1)
		if parts.size() != 2 or str(parts[0]).strip_edges() == "":
			return false
		scoped = str(parts[1])
	if not scoped.contains("."):
		return false
	var chunks := scoped.split(".", false, 1)
	if chunks.size() != 2:
		return false
	return str(chunks[0]).strip_edges() != "" and str(chunks[1]).strip_edges() != ""
