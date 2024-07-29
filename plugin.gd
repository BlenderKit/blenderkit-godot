@tool
extends EditorPlugin

var download_dir: String = "res://bk_assets/"
var absolute_download_path: String

const CLIENT_PORTS = [62485, 65425, 55428, 49452, 35452, 25152, 5152, 1234]
var http_request: HTTPRequest
var timer: Timer

func _enter_tree():
	print("BlenderKit plugin entered tree")
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	print("Assets will be downloaded to:", absolute_download_path)
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_request_completed"))
	_start_periodic_request(1.0)

func _exit_tree():
	print("BlenderKit plugin exited tree")
	if !timer:
		return
	timer.stop()
	timer.queue_free()

func _start_periodic_request(interval: float):
	if timer:
		timer.stop()
		timer.queue_free()
	
	timer = Timer.new()
	timer.wait_time = interval
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))

func _on_timer_timeout():
	var url = "http://localhost:62485/godot/report"
	var headers = ["Content-Type: application/json"]
	var data = {
		"name": "Godot",
		"version": get_godot_version(),
		"addon_version": get_addon_version(),
		"assets_path": absolute_download_path,
		}
	var json = JSON.stringify(data)
	
	print("Making HTTP request with data", json)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json)

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		print("OK")
		return
		
	if response_code == 400:
		print("400")
		return 
	
	print("Request completed with response code: %d" % response_code)
	print("Response body: %s" % body.get_string_from_utf8())

func get_addon_version():
	var config = ConfigFile.new()
	var err = config.load("res://addons/blenderkit/plugin.cfg")
	if err == OK:
		var addon_version: String = config.get_value("plugin", "version", "unknown")
		return addon_version
	else:
		return "unknown"

func get_godot_version():
	var godot_version: String = str(Engine.get_version_info()["major"]) + "." + str(Engine.get_version_info()["minor"]) + "." + str(Engine.get_version_info()["patch"])
	return godot_version
