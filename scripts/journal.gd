extends Node
## Journal — discovered-logs system.
##
## Autoloaded as `Journal`. Syncs discovered entries from `GameState.flags`
## (persisted via user://save.json) and builds the in-game reader overlay
## with keyboard and gamepad navigation.

signal entry_added(id: String)

const ENTRY_CATALOG := {
	"entry_skeptic": {
		"title": "Keeper's Log — Fog & Fatigue",
		"text": "Edith Vane wrote that a light off the north rocks answered hers — three flashes, then dark, not the buoy and not a ship.\n\nThree nights alone in thick fog can do strange work on a person's eyes.",
	},
	"entry_believer": {
		"title": "Keeper's Log — The Answering Light",
		"text": "Edith Vane wrote that a light off the north rocks answered hers — three flashes, then dark, keeping her rhythm.\n\nWhatever was out past the north rocks, she wasn't imagining it.",
	},
	"entry_trusted_edith": {
		"title": "Eleven Days Gone — Raise the Mainland",
		"text": "Edith relit the lamp and rowed out to meet the north light eleven days ago. The dinghy is gone from the boathouse.\n\nTom Salish ran her last supply from the mainland — he needs to hear what she left in the ledger.",
	},
	"entry_kept_quiet": {
		"title": "Eleven Days Gone — Keep It Quiet",
		"text": "Edith relit the lamp and rowed out to meet the north light eleven days ago. The dinghy is gone from the boathouse.\n\nKeep this between yourself and the ledger for now. First the lamp, then the water.",
	},
	"entry_radioed_tom": {
		"title": "Mainland Radio — Tom Salish",
		"text": "Reached harbormaster Tom Salish on the mainland wireless. Weather is turning before Thursday's supply run; keep the station steady.",
	},
}

const MANAGED_IDS: Array[String] = [
	"entry_skeptic",
	"entry_believer",
	"entry_trusted_edith",
	"entry_kept_quiet",
	"entry_radioed_tom",
]

var _entries: Array[String] = []


func _ready() -> void:
	GameState.state_changed.connect(_sync_from_flags)
	_sync_from_flags()


func discover(id: String) -> void:
	if id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


func get_entry(id: String) -> Dictionary:
	if ENTRY_CATALOG.has(id):
		return ENTRY_CATALOG[id]
	return {"title": id, "text": ""}


func create_overlay(on_close: Callable = Callable()) -> Control:
	var items: Array = []
	for id in _entries:
		var info: Dictionary = get_entry(id)
		items.append({
			"id": id,
			"title": str(info.get("title", id)),
			"text": str(info.get("text", "")),
		})
	return ReaderOverlay.new(items, on_close)


func _sync_from_flags() -> void:
	var flags: Dictionary = GameState.flags
	if flags.is_empty():
		_entries.clear()
		return

	var active: Array[String] = []
	if flags.get("skeptic", false):
		active.append("entry_skeptic")
	if flags.get("believer", false):
		active.append("entry_believer")
	if flags.has("trusted_edith"):
		if flags["trusted_edith"]:
			active.append("entry_trusted_edith")
		else:
			active.append("entry_kept_quiet")
	if flags.get("radioed_tom", false):
		active.append("entry_radioed_tom")
	for key in flags:
		var k := str(key)
		if k.begins_with("entry_") and flags[key] and not (k in active):
			active.append(k)

	var kept: Array[String] = []
	for existing in _entries:
		if existing in active or not (existing in MANAGED_IDS):
			kept.append(existing)
	_entries = kept

	for id in active:
		discover(id)


class ReaderOverlay extends Control:
	var _items: Array = []
	var _on_close: Callable
	var _buttons: Array[Button] = []
	var _entry_title: Label
	var _entry_body: RichTextLabel
	var _back_button: Button
	var _closing: bool = false

	func _init(items: Array = [], on_close: Callable = Callable()) -> void:
		_items = items
		_on_close = on_close

	func _ready() -> void:
		name = "JournalOverlay"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_build_ui()

	func _process(delta: float) -> void:
		if _entry_body != null:
			var joy_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
			if absf(joy_y) > 0.25:
				var vbar := _entry_body.get_v_scroll_bar()
				if vbar != null:
					vbar.value += joy_y * 260.0 * delta

	func _build_ui() -> void:
		var dim := ColorRect.new()
		dim.color = Color(0.04, 0.07, 0.09, 0.88)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(840, 460)
		center.add_child(panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_bottom", 20)
		panel.add_child(margin)

		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation", 14)
		margin.add_child(outer)

		var header := HBoxContainer.new()
		outer.add_child(header)

		var title := Label.new()
		title.text = "Keeper's Journal"
		title.add_theme_font_size_override("font_size", 26)
		title.modulate = Color("#ffd466")
		header.add_child(title)

		var count := Label.new()
		count.text = "%d recorded" % _items.size()
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 16)
		count.modulate = Color(1, 1, 1, 0.55)
		header.add_child(count)

		if _items.is_empty():
			var empty := Label.new()
			empty.text = "No entries recorded yet.\nExamine the station's ledger or wireless set to record notes."
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_font_size_override("font_size", 18)
			empty.modulate = Color(1, 1, 1, 0.65)
			outer.add_child(empty)
		else:
			var split := HBoxContainer.new()
			split.size_flags_vertical = Control.SIZE_EXPAND_FILL
			split.add_theme_constant_override("separation", 20)
			outer.add_child(split)

			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(270, 0)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.follow_focus = true
			split.add_child(scroll)

			var list := VBoxContainer.new()
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list.add_theme_constant_override("separation", 6)
			scroll.add_child(list)

			for i in _items.size():
				var item: Dictionary = _items[i]
				var btn := Button.new()
				btn.text = str(item.get("title", "Untitled"))
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				btn.custom_minimum_size = Vector2(250, 40)
				btn.add_theme_font_size_override("font_size", 16)
				btn.pressed.connect(_select.bind(i))
				btn.focus_entered.connect(_select.bind(i))
				list.add_child(btn)
				_buttons.append(btn)

			var reader := VBoxContainer.new()
			reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
			reader.add_theme_constant_override("separation", 10)
			split.add_child(reader)

			_entry_title = Label.new()
			_entry_title.add_theme_font_size_override("font_size", 21)
			_entry_title.modulate = Color("#ffd466")
			_entry_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reader.add_child(_entry_title)

			_entry_body = RichTextLabel.new()
			_entry_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_entry_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_entry_body.add_theme_font_size_override("normal_font_size", 18)
			reader.add_child(_entry_body)

		var footer := HBoxContainer.new()
		outer.add_child(footer)

		var hint := Label.new()
		hint.text = "Up / Down: Select   ·   Esc / B: Back"
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.add_theme_font_size_override("font_size", 15)
		hint.modulate = Color(1, 1, 1, 0.5)
		footer.add_child(hint)

		_back_button = Button.new()
		_back_button.text = "Back"
		_back_button.custom_minimum_size = Vector2(120, 36)
		_back_button.add_theme_font_size_override("font_size", 18)
		_back_button.pressed.connect(_close)
		footer.add_child(_back_button)

		for i in _buttons.size():
			var b: Button = _buttons[i]
			b.focus_neighbor_right = _back_button.get_path()
			if i > 0:
				b.focus_neighbor_top = _buttons[i - 1].get_path()
			if i + 1 < _buttons.size():
				b.focus_neighbor_bottom = _buttons[i + 1].get_path()
			else:
				b.focus_neighbor_bottom = _back_button.get_path()

		if not _buttons.is_empty():
			_select(0)
			_buttons[0].grab_focus()
		else:
			_back_button.grab_focus()

	func _select(index: int) -> void:
		if index < 0 or index >= _items.size():
			return
		var item: Dictionary = _items[index]
		if _entry_title != null:
			_entry_title.text = str(item.get("title", ""))
		if _entry_body != null:
			_entry_body.text = str(item.get("text", ""))
		if _back_button != null and index < _buttons.size():
			var active_path := _buttons[index].get_path()
			_back_button.focus_neighbor_left = active_path
			_back_button.focus_neighbor_top = active_path

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close()

	func _close() -> void:
		if _closing:
			return
		_closing = true
		if _on_close.is_valid():
			_on_close.call()
		queue_free()
