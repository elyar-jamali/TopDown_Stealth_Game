class_name GameColors
extends RefCounted

enum Preset {
	RED,
	ORANGE,
	YELLOW,
	GREEN,
	BLUE,
	PURPLE,
	WHITE,
	GRAY
}

enum Opacity {
	SOLID,
	STRONG,
	NORMAL,
	SOFT
}

static func get_color(preset: Preset, opacity: Opacity = Opacity.SOLID) -> Color:
	var color: Color

	match preset:
		Preset.RED:
			color =  Color("#ff0000")
		Preset.ORANGE:
			color = Color("#ff9000")
		Preset.YELLOW:
			color = Color("#ffff00")
		Preset.GREEN:
			color = Color("#00dd00")
		Preset.BLUE:
			color = Color("#00b7ff")
		Preset.PURPLE:
			color = Color("#e600e6")
		Preset.WHITE:
			color = Color.WHITE
		Preset.GRAY:
			color = Color("#a1a1a1")
		_:
			color = Color.BLACK

	color.a = get_opacity(opacity)
	return color

static func get_opacity(opacity: Opacity) -> float:
	match opacity:
		Opacity.SOLID:
			return 1.0
		Opacity.STRONG:
			return 0.60
		Opacity.NORMAL:
			return 0.35
		Opacity.SOFT:
			return 0.20

	return 1.0