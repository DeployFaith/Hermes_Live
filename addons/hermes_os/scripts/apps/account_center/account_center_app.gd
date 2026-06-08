class_name AccountCenterApp
extends "res://addons/hermes_os/scripts/ui/hermes_ui/hermes_app.gd"

var _shell: Node
var _fs: Object

var _accounts_list: ScrollContainer
var _selected_username: String = ""
var _detail_column: VBoxContainer

var _create_username_input: LineEdit
var _create_display_input: LineEdit
var _create_password_input: LineEdit

var _rename_input: LineEdit
var _duplicate_input: LineEdit
var _set_password_input: LineEdit
var _display_name_input: LineEdit
var _custom_avatar_path_input: LineEdit
var _custom_avatar_file_dropdown: OptionButton
var _avatar_dropdown: OptionButton
var _avatar_preview: TextureRect
var _avatar_meta_label: Label

# Root auth modal state (added for root-gated actions)
var _root_auth_modal: Control
var _root_auth_password_input: LineEdit
var _root_auth_pending_action: Callable
var _root_auth_status_label: Label

func setup(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs

func render() -> void:
	custom_minimum_size = Vector2(760, 520)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_meta("window_default_size", Vector2(980, 640))
	set_meta("window_min_size", Vector2(760, 520))
	var toolbar: Control = _build_toolbar()
	var sidebar: Control = _build_accounts_sidebar()
	var content: Control = _build_detail_content()
	var status_bar: Control = ui.status_bar("Account Center ready", "info", {"name": "AccountCenterStatusBar"})
	set_status_control(status_bar)
	set_root(layout.sidebar_app(toolbar, sidebar, content, status_bar, {"sidebar_width": 300}))
	_refresh_accounts()

func get_state() -> Dictionary:
	return {"selected": _selected_username}

func restore_state(state: Dictionary) -> void:
	_selected_username = str(state.get("selected", _selected_username)).strip_edges()
	_refresh_accounts()

func _build_toolbar() -> Control:
	var title: Control = ui.label("Account Center", {"variant": "heading", "name": "AccountCenterTitle"})
	var subtitle: Control = ui.label("Manage accounts. Root auth modal for privileged actions; display name self-editable.", {"variant": "muted", "name": "AccountCenterSubtitle"})
	var block: Control = ui.vbox([title, subtitle], hermes_theme.spacing("space_1"), {"expand_h": true})
	var role: String = "Root session" if _fs != null and _fs.current_user() == "root" else "User session"
	var role_label: Control = ui.label(role, {"variant": "muted", "name": "AccountCenterRole", "min_size": Vector2(120, 0)})
	return ui.toolbar([block, role_label], {"name": "AccountCenterToolbar"})

func _build_accounts_sidebar() -> Control:
	_accounts_list = ui.list_view([], {"name": "AccountCenterList", "on_select": Callable(self, "_on_select_account"), "expand_h": true, "expand_v": true})
	return ui.sidebar([
		ui.section_header("Accounts", "Login-visible users"),
		_accounts_list
	], 260, {"name": "AccountCenterSidebar"})

func _build_detail_content() -> Control:
	_detail_column = ui.vbox([], hermes_theme.spacing("space_3"), {"name": "AccountCenterDetail", "expand_h": true, "expand_v": true})
	return ui.scroll_container(_detail_column, {"name": "AccountCenterScroll", "expand_h": true, "expand_v": true})

func _refresh_accounts() -> void:
	if _fs == null or _accounts_list == null:
		return
	var entries: Array = []
	if _fs.has_method("list_login_users"):
		entries = _fs.list_login_users()
	if entries.is_empty():
		for username in _fs.get_users():
			if username == "root":
				continue
			entries.append({"username": username, "display_name": username, "home": _fs.home_path(username), "locked": false})
	var items: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var account: Dictionary = entry
		var username := str(account.get("username", "")).strip_edges()
		if username == "":
			continue
		var display := str(account.get("display_name", username))
		var locked := bool(account.get("locked", false))
		var text := "%s  @%s%s" % [display, username, "  (locked)" if locked else ""]
		items.append({"id": username, "text": text})
	if _selected_username == "" and not items.is_empty():
		_selected_username = str((items[0] as Dictionary).get("id", ""))
	ui.set_list_items(_accounts_list, items, {"selected_id": _selected_username, "on_select": Callable(self, "_on_select_account")})
	_rebuild_detail()

func _on_select_account(username: String) -> void:
	_selected_username = username
	_rebuild_detail()

func _rebuild_detail() -> void:
	if _detail_column == null:
		return
	ui.clear_children(_detail_column)
	_detail_column.add_child(_build_selected_account_card())
	_detail_column.add_child(_build_avatar_card())
	_detail_column.add_child(_build_account_actions_card())

func _build_selected_account_card() -> Control:
	var username := _selected_username
	if username == "":
		return ui.card([ui.empty_state("No account selected", "Choose an account from the left list")], 16, {"name": "AccountCenterSelectedCard"})
	var account := _find_account(username)
	var display_name := str(account.get("display_name", username))
	var home := str(account.get("home", _fs.home_path(username)))
	var locked := bool(account.get("locked", false))
	_display_name_input = ui.input({"value": display_name, "placeholder": "Display name", "name": "AccountCenterDisplayName"})
	var save_display_button: Button = ui.button("Save display name", {"variant": "secondary", "on_pressed": Callable(self, "_save_display_name")})
	var status_text := "Locked account" if locked else "Active account"
	return ui.card([
		ui.section_header("Selected account", "Identity and profile fields"),
		ui.settings_row("Username", ui.label("@" + username, {"variant": "body", "expand_h": true}), {"expand_h": true}),
		ui.settings_row("Home", ui.label(home, {"variant": "muted", "expand_h": true}), {"expand_h": true}),
		ui.settings_row("Status", ui.label(status_text, {"variant": "body", "expand_h": true}), {"expand_h": true}),
		ui.settings_row("Display name", _display_name_input, {"expand_h": true}),
		save_display_button,
		ui.label("Self-editable: any user can update their own display name. Root auth required only for username changes and account lifecycle actions.", {"variant": "muted", "name": "AccountCenterDisplayHelper"})
	], 16, {"name": "AccountCenterSelectedCard", "expand_h": true})

func _build_avatar_card() -> Control:
	var builtins: Array = []
	if _fs != null and _fs.has_method("list_builtin_avatars"):
		builtins = _fs.list_builtin_avatars()
	var options: Array = []
	for path in builtins:
		options.append({"id": str(path), "text": str(path).trim_prefix("res://addons/hermes_os/assets/avatars/")})
	if options.is_empty():
		options = [{"id": "", "text": "(no built-in avatars)"}]
	_avatar_dropdown = ui.dropdown(options, {"name": "AccountCenterAvatarDropdown"})

	var custom_files: Array = _candidate_custom_avatar_files()
	var custom_options: Array = []
	for file_path in custom_files:
		custom_options.append({"id": str(file_path), "text": str(file_path)})
	if custom_options.is_empty():
		custom_options = [{"id": "", "text": "(no image files found in home/Pictures)"}]
	_custom_avatar_file_dropdown = ui.dropdown(custom_options, {"name": "AccountCenterAvatarFileDropdown"})
	_custom_avatar_path_input = ui.input({"value": "", "placeholder": "/home/user/Pictures/avatar.png", "name": "AccountCenterAvatarPath"})

	_avatar_preview = TextureRect.new()
	_avatar_preview.name = "AccountCenterAvatarPreview"
	_avatar_preview.custom_minimum_size = Vector2(88, 88)
	_avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_meta_label = ui.label("Avatar: initials", {"variant": "muted", "name": "AccountCenterAvatarMeta"})

	var card: Control = ui.card([
		ui.section_header("Profile picture", "Choose built-in avatar or custom image from Hermes_OS filesystem"),
		ui.hbox([_avatar_preview, _avatar_meta_label], hermes_theme.spacing("space_3"), {"expand_h": true}),
		ui.settings_row("Built-in", _avatar_dropdown, {"expand_h": true}),
		ui.flow_row([
			ui.button("Apply built-in", {"variant": "secondary", "on_pressed": Callable(self, "_apply_builtin_avatar")}),
			ui.button("Reset avatar", {"variant": "ghost", "on_pressed": Callable(self, "_reset_avatar")})
		], {"expand_h": true}),
		ui.settings_row("Custom picker", _custom_avatar_file_dropdown, {"expand_h": true}),
		ui.button("Use selected file", {"variant": "secondary", "on_pressed": Callable(self, "_apply_custom_avatar_from_dropdown")}),
		ui.settings_row("Custom path", _custom_avatar_path_input, {"expand_h": true}),
		ui.button("Use custom path", {"variant": "secondary", "on_pressed": Callable(self, "_apply_custom_avatar")})
	], 16, {"name": "AccountCenterAvatarCard", "expand_h": true})
	_refresh_avatar_preview()
	return card

func _build_account_actions_card() -> Control:
	_create_username_input = ui.input({"value": "", "placeholder": "new_username", "name": "AccountCenterCreateUsername"})
	_create_display_input = ui.input({"value": "", "placeholder": "Display Name", "name": "AccountCenterCreateDisplay"})
	_create_password_input = ui.input({"value": "", "placeholder": "password (optional)", "name": "AccountCenterCreatePassword"})
	_create_password_input.secret = true
	_rename_input = ui.input({"value": "", "placeholder": "new username", "name": "AccountCenterRenameInput"})
	_duplicate_input = ui.input({"value": "", "placeholder": "copy username", "name": "AccountCenterDuplicateInput"})
	_set_password_input = ui.input({"value": "", "placeholder": "new password", "name": "AccountCenterSetPassword"})
	_set_password_input.secret = true
	return ui.card([
		ui.section_header("Account actions", "Create/duplicate/delete/lock require root via modal; username change root-gated; display name self-editable"),
		ui.form_group("Create", [
			ui.settings_row("Username", _create_username_input, {"expand_h": true}),
			ui.settings_row("Display", _create_display_input, {"expand_h": true}),
			ui.settings_row("Password", _create_password_input, {"expand_h": true}),
			ui.button("Create account", {"variant": "primary", "on_pressed": Callable(self, "_create_account")})
		], {"expand_h": true}),
		ui.form_group("Manage selected", [
			ui.settings_row("Change username (root auth)", _rename_input, {"expand_h": true}),
			ui.flow_row([
				ui.button("Change username", {"variant": "secondary", "on_pressed": Callable(self, "_rename_selected")}),
				ui.button("Delete", {"variant": "ghost", "on_pressed": Callable(self, "_delete_selected")})
			], {"expand_h": true}),
			ui.settings_row("Duplicate", _duplicate_input, {"expand_h": true}),
			ui.button("Duplicate", {"variant": "secondary", "on_pressed": Callable(self, "_duplicate_selected")}),
			ui.settings_row("Password", _set_password_input, {"expand_h": true}),
			ui.button("Set password", {"variant": "secondary", "on_pressed": Callable(self, "_set_selected_password")}),
			ui.flow_row([
				ui.button("Lock", {"variant": "secondary", "on_pressed": Callable(self, "_lock_selected")}),
				ui.button("Unlock", {"variant": "secondary", "on_pressed": Callable(self, "_unlock_selected")}),
				ui.button("Hide from login", {"variant": "ghost", "on_pressed": Callable(self, "_hide_selected_from_login")}),
				ui.button("Show in login", {"variant": "ghost", "on_pressed": Callable(self, "_show_selected_in_login")})
			], {"expand_h": true})
		], {"expand_h": true})
	], 16, {"name": "AccountCenterActionsCard", "expand_h": true})

func _find_account(username: String) -> Dictionary:
	if _fs == null:
		return {}
	var users: Array = _fs.list_login_users() if _fs.has_method("list_login_users") else []
	for item in users:
		if item is Dictionary and str((item as Dictionary).get("username", "")) == username:
			return (item as Dictionary).duplicate(true)
	return {"username": username, "display_name": username, "home": _fs.home_path(username), "locked": false}

func _refresh_avatar_preview() -> void:
	if _avatar_preview == null or _avatar_meta_label == null:
		return
	if _fs == null or _selected_username.strip_edges() == "" or not _fs.has_method("get_user_avatar"):
		_avatar_preview.texture = null
		_avatar_meta_label.text = "Avatar: initials"
		return
	var avatar: Dictionary = _fs.get_user_avatar(_selected_username)
	var avatar_type := str(avatar.get("type", "initials"))
	var avatar_value := str(avatar.get("value", ""))
	_avatar_meta_label.text = "Avatar: %s%s" % [avatar_type, " (%s)" % avatar_value if avatar_value != "" else ""]
	if avatar_type == "asset" and avatar_value.begins_with("res://"):
		var loaded := load(avatar_value)
		if loaded is Texture2D:
			_avatar_preview.texture = loaded as Texture2D
			return
	if _shell != null and _shell.has_method("_user_avatar_icon"):
		_avatar_preview.texture = _shell._user_avatar_icon(_selected_username)
	else:
		_avatar_preview.texture = null

func _require_root_for_admin() -> bool:
	if _fs == null:
		set_status("Filesystem unavailable", "error")
		return false
	if _fs.current_user() != "root":
		set_status("Root session required for account lifecycle operations", "warning")
		return false
	return true

# Root auth modal for root-gated actions (added per task)
func _show_root_auth_modal(on_success: Callable) -> void:
	if _fs == null:
		set_status("Filesystem unavailable for auth", "error")
		return
	if _fs.current_user() == "root":
		var result: Variant = on_success.call()
		if result is String and str(result) != "":
			set_status(str(result), "error")
		return
	# Build or show modal
	if _root_auth_modal == null:
		_build_root_auth_modal()
	if _root_auth_modal == null:
		set_status("Root auth modal unavailable", "error")
		return
	_root_auth_pending_action = on_success
	_root_auth_password_input.text = ""
	_root_auth_status_label.text = "Enter root password to continue"
	_root_auth_modal.visible = true
	_root_auth_password_input.grab_focus()

func _build_root_auth_modal() -> void:
	if _root_auth_modal != null:
		return
	_root_auth_password_input = ui.input({"value": "", "placeholder": "root password", "name": "RootAuthPassword"})
	_root_auth_password_input.secret = true
	_root_auth_status_label = ui.label("", {"variant": "warning", "name": "RootAuthStatus"})
	var helper_label = ui.label("Enter root password to authorize privileged actions. Display name changes are self-editable and do not require root auth.", {"variant": "muted", "name": "RootAuthHelper"})
	var cancel_btn = ui.button("Cancel", {"variant": "ghost", "on_pressed": Callable(self, "_cancel_root_auth")})
	var auth_btn = ui.button("Authenticate", {"variant": "primary", "on_pressed": Callable(self, "_submit_root_auth")})
	var card = ui.card([
		ui.section_header("Root Authentication Required", "This action requires root privileges"),
		helper_label,
		ui.settings_row("Password", _root_auth_password_input, {"expand_h": true}),
		_root_auth_status_label,
		ui.flow_row([auth_btn, cancel_btn], {"expand_h": true})
	], 16, {"name": "RootAuthModal", "expand_h": true})
	# Real modal overlay: full rect, dim backing, centered card, input trap (mouse_filter stop), not in scroll content
	_root_auth_modal = Control.new()
	_root_auth_modal.name = "RootAuthOverlay"
	_root_auth_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_auth_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_auth_modal.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	_root_auth_modal.add_child(center)
	add_child(_root_auth_modal)
	_root_auth_modal.visible = false

func _submit_root_auth() -> void:
	if _root_auth_password_input == null or _root_auth_pending_action == null or _fs == null:
		_cancel_root_auth()
		return
	var password := _root_auth_password_input.text.strip_edges()
	var auth_ok := false
	if _fs.has_method("validate_root_password"):
		auth_ok = bool(_fs.validate_root_password(password))
	elif _fs.has_method("auth_root"):
		auth_ok = bool(_fs.auth_root(password))
	else:
		auth_ok = true
	if auth_ok:
		_root_auth_modal.visible = false
		var action: Callable = _root_auth_pending_action
		_root_auth_pending_action = Callable()
		var result: Variant = null
		if _fs.has_method("with_root_authorization"):
			result = _fs.with_root_authorization(action)
		elif action.is_valid():
			result = action.call()
		if result is String and str(result) != "":
			set_status(str(result), "error")
	else:
		_root_auth_status_label.text = "Invalid root password"
		set_status("Root authentication failed", "error")

func _cancel_root_auth() -> void:
	if _root_auth_modal != null:
		_root_auth_modal.visible = false
	_root_auth_pending_action = Callable()
	_root_auth_status_label.text = ""
	set_status("Root auth cancelled", "info")

func _perform_rename(new_username: String) -> String:
	if _fs == null or _selected_username == "":
		return ""
	var clean_username := new_username.strip_edges()
	if _fs.has_method("clean_username"):
		clean_username = str(_fs.clean_username(new_username))
	var message := str(_fs.rename_user_account(_selected_username, clean_username))
	if message != "":
		set_status(message, "error")
		return message
	set_status("Username changed to @" + clean_username, "success")
	_selected_username = clean_username
	_refresh_accounts()
	return ""

func _save_display_name() -> void:
	if _selected_username == "" or _display_name_input == null:
		return
	if _fs == null or not _fs.has_method("set_user_display_name"):
		set_status("Display name API unavailable", "error")
		return
	var message := str(_fs.set_user_display_name(_selected_username, _display_name_input.text))
	if message != "":
		set_status(message, "error")
		return
	set_status("Display name updated", "success")
	_refresh_accounts()

func _apply_builtin_avatar() -> void:
	if _selected_username == "" or _avatar_dropdown == null:
		return
	if _fs == null or not _fs.has_method("set_user_avatar_asset"):
		set_status("Avatar API unavailable", "error")
		return
	var selected: String = ui.get_selected_id(_avatar_dropdown)
	if selected == "":
		set_status("No built-in avatar selected", "warning")
		return
	var message := str(_fs.set_user_avatar_asset(_selected_username, selected))
	if message != "":
		set_status(message, "error")
		return
	set_status("Built-in avatar applied", "success")
	_refresh_accounts()

func _apply_custom_avatar() -> void:
	if _selected_username == "" or _custom_avatar_path_input == null:
		return
	if _fs == null or not _fs.has_method("set_user_avatar_file"):
		set_status("Avatar API unavailable", "error")
		return
	var message := str(_fs.set_user_avatar_file(_selected_username, _custom_avatar_path_input.text))
	if message != "":
		set_status(message, "error")
		return
	set_status("Custom avatar applied", "success")
	_refresh_accounts()

func _apply_custom_avatar_from_dropdown() -> void:
	if _custom_avatar_file_dropdown == null:
		return
	var selected: String = ui.get_selected_id(_custom_avatar_file_dropdown)
	if selected.strip_edges() == "":
		set_status("No custom image selected", "warning")
		return
	if _custom_avatar_path_input != null:
		_custom_avatar_path_input.text = selected
	_apply_custom_avatar()

func _candidate_custom_avatar_files() -> Array:
	if _fs == null:
		return []
	var candidates: Array = []
	var roots: Array[String] = []
	if _selected_username.strip_edges() != "":
		roots.append("/home/%s/Pictures" % _selected_username)
	roots.append(_fs.home_path() + "/Pictures")
	roots.append(_fs.home_path())
	for root_path in roots:
		var normalized: String = _fs.normalize_path(root_path)
		if not _fs.is_dir(normalized) or not _fs.can_list_dir(normalized):
			continue
		for entry in _fs.list_dir(normalized):
			if not (entry is Dictionary):
				continue
			var item: Dictionary = entry
			if str(item.get("type", "")) != "file":
				continue
			var path_text := str(item.get("path", ""))
			var lower := path_text.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".svg"):
				if not candidates.has(path_text):
					candidates.append(path_text)
	return candidates

func _reset_avatar() -> void:
	if _selected_username == "":
		return
	if _fs == null or not _fs.has_method("clear_user_avatar"):
		set_status("Avatar API unavailable", "error")
		return
	var message := str(_fs.clear_user_avatar(_selected_username))
	if message != "":
		set_status(message, "error")
		return
	set_status("Avatar reset to initials", "success")
	_refresh_accounts()

func _create_account() -> void:
	_show_root_auth_modal(Callable(self, "_perform_create_account"))

func _perform_create_account() -> void:
	if _create_username_input == null:
		return
	var message := str(_fs.create_user_account(_create_username_input.text, _create_display_input.text if _create_display_input != null else "", _create_password_input.text if _create_password_input != null else ""))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account created", "success")
	_selected_username = _create_username_input.text.strip_edges()
	_refresh_accounts()

func _rename_selected() -> void:
	if _selected_username == "" or _rename_input == null:
		return
	var new_username := _rename_input.text.strip_edges()
	if new_username == "":
		set_status("Enter a new username", "warning")
		return
	# Use per-action root auth modal for this root-gated action
	_show_root_auth_modal(Callable(self, "_perform_rename").bind(new_username))

func _duplicate_selected() -> void:
	_show_root_auth_modal(Callable(self, "_perform_duplicate_selected"))

func _perform_duplicate_selected() -> void:
	if _selected_username == "" or _duplicate_input == null:
		return
	var target := _duplicate_input.text.strip_edges()
	if target == "":
		set_status("Enter duplicate username", "warning")
		return
	var message := str(_fs.duplicate_user_account(_selected_username, target, ""))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account duplicated", "success")
	_selected_username = target
	_refresh_accounts()

func _set_selected_password() -> void:
	_show_root_auth_modal(Callable(self, "_perform_set_selected_password"))

func _perform_set_selected_password() -> void:
	if _selected_username == "" or _set_password_input == null:
		return
	var password := _set_password_input.text
	if password.strip_edges() == "":
		set_status("Enter a new password", "warning")
		return
	var message := str(_fs.set_user_password(_selected_username, password, ""))
	if message != "":
		set_status(message, "error")
		return
	_set_password_input.text = ""
	set_status("Password updated", "success")

func _hide_selected_from_login() -> void:
	_show_root_auth_modal(Callable(self, "_perform_hide_selected_from_login"))

func _perform_hide_selected_from_login() -> void:
	if _selected_username == "":
		return
	var message := str(_fs.set_user_login_visible(_selected_username, false))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account hidden from login", "success")
	_refresh_accounts()

func _show_selected_in_login() -> void:
	_show_root_auth_modal(Callable(self, "_perform_show_selected_in_login"))

func _perform_show_selected_in_login() -> void:
	if _selected_username == "":
		return
	var message := str(_fs.set_user_login_visible(_selected_username, true))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account visible in login", "success")
	_refresh_accounts()

func _delete_selected() -> void:
	_show_root_auth_modal(Callable(self, "_perform_delete_selected"))

func _perform_delete_selected() -> void:
	if _selected_username == "":
		return
	var message := str(_fs.delete_user_account(_selected_username, false))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account deleted", "success")
	_selected_username = ""
	_refresh_accounts()

func _lock_selected() -> void:
	_show_root_auth_modal(Callable(self, "_perform_lock_selected"))

func _perform_lock_selected() -> void:
	if _selected_username == "":
		return
	var message := str(_fs.set_user_locked(_selected_username, true))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account locked", "success")
	_refresh_accounts()

func _unlock_selected() -> void:
	_show_root_auth_modal(Callable(self, "_perform_unlock_selected"))

func _perform_unlock_selected() -> void:
	if _selected_username == "":
		return
	var message := str(_fs.set_user_locked(_selected_username, false))
	if message != "":
		set_status(message, "error")
		return
	set_status("Account unlocked", "success")
	_refresh_accounts()
