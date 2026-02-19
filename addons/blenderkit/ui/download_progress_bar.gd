@tool 
extends ProgressBar

@onready var label : Label = $Label

@export var file_path := '/path/to/file_name.blend'
@export var file_size := 1024

func _ready() -> void:
	_on_value_changed(value)
	
func _on_value_changed(_new_value : float) -> void:
	var r := (value - min_value) / (max_value - min_value)
	var p := int(r * 100)
	var s : String
	
	if p < 100:
		label.text = "%d %% of %s B" % [p, file_size]
	else:
		label.text = "DONE %s" % file_path
