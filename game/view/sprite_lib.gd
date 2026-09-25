extends RefCounted
## Carrega os assets processados de `game/assets/` (tiras PNG + JSON de tools/art/process_sheets.py)
## em tempo de execução, sem depender da importação do editor. Asset ausente → null, e a view usa
## o placeholder.

const ROOT := "res://assets/"
const CHAR_OF := {"leve": "faisca", "medio": "brasa", "pesado": "bloco"}

var _tex := {}    # caminho → ImageTexture (ou null)
var _meta := {}   # caminho → Dictionary (ou {})


func texture(rel: String) -> Texture2D:
	if _tex.has(rel):
		return _tex[rel]
	var t: Texture2D = null
	var path := ROOT + rel
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_tex[rel] = t
	return t


func meta(rel: String) -> Dictionary:
	if _meta.has(rel):
		return _meta[rel]
	var d := {}
	var path := ROOT + rel
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			d = parsed
	_meta[rel] = d
	return d


func anim(def: String, name: String) -> Dictionary:
	## {tex, frames, w, h, pivot: Vector2, fps, loop, scale} ou {} se não houver.
	var key := "chr/%s/%s" % [CHAR_OF.get(def, def), name]
	var m := meta(key + ".json")
	var t := texture(key + ".png")
	if m.is_empty() or t == null:
		return {}
	var frames: int = int(m.get("frames", 1))
	var w: int = int(m.get("frame_w", t.get_width() / maxi(1, frames)))
	var h: int = int(m.get("frame_h", t.get_height()))
	var pv: Array = m.get("pivot", [w / 2, h])
	return {"tex": t, "frames": frames, "w": w, "h": h, "pivot": Vector2(pv[0], pv[1]),
		"fps": float(m.get("fps", 12)), "loop": bool(m.get("loop", false)),
		"scale": 1.0 / float(m.get("px_per_world_px", 4)), "cols": int(m.get("cols", frames))}


static func frame_rect(a: Dictionary, idx: int) -> Rect2:
	## Região do frame `idx` numa tira (cols = frames) ou numa grade (cols < frames).
	var cols: int = maxi(1, int(a.get("cols", a.frames)))
	return Rect2((idx % cols) * a.w, (idx / cols) * a.h, a.w, a.h)


func strip(rel: String) -> Dictionary:
	## Tira genérica (props, fx): mesma forma de anim().
	var m := meta(rel + ".json")
	var t := texture(rel + ".png")
	if t == null:
		return {}
	var frames: int = int(m.get("frames", 1))
	var w: int = int(m.get("frame_w", t.get_width() / maxi(1, frames)))
	var h: int = int(m.get("frame_h", t.get_height()))
	var pv: Array = m.get("pivot", [w / 2, h])
	return {"tex": t, "frames": frames, "w": w, "h": h, "pivot": Vector2(pv[0], pv[1]),
		"fps": float(m.get("fps", 12)), "loop": bool(m.get("loop", false)),
		"scale": 1.0 / float(m.get("px_per_world_px", 4)), "cols": int(m.get("cols", frames))}
