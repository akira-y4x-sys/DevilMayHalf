
@tool extends EditorPlugin

const AUTOLOAD_NAME := "psx_autoload"
const AUTOLOAD_PATH := "scripts/PsxAutoload.gd"

func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

	Psx.touch_shader_globals()

func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
