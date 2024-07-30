@tool
extends EditorPlugin

const CLIENT_PORTS = ["65425", "55428", "49452", "35452", "25152", "5152", "1234", "62485"]
const LOG_LEVEL = 1
const WAIT_OK: float = 1
const WAIT_EXPLORING: float = 0.1
const WAIT_FAILING: float = 10

var download_dir: String = "res://bk_assets/"
var absolute_download_path: String
var ports_index: int = 0
var failed_requests: int = 0
var http_request: HTTPRequest
var timer: Timer


func _enter_tree():
	print("BlenderKit plugin enabled")
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	print("Assets will be downloaded to:", absolute_download_path)
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "on_request_completed"))

	start_periodic_request()

func _exit_tree():
	if !timer:
		return
	timer.stop()
	timer.queue_free()
	http_request.queue_free()
	print("BlenderKit plugin exited")

func start_periodic_request():
	if timer:
		timer.stop()
		timer.queue_free()
	
	timer = Timer.new()
	timer.wait_time = WAIT_EXPLORING
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "on_timer_timeout"))

func on_timer_timeout():
	var url = "http://localhost:" + CLIENT_PORTS[ports_index] + "/godot/report"
	var headers = ["Content-Type: application/json"]
	var data = {
		"name": "Godot",
		"appID": OS.get_process_id(),
		"version": get_godot_version(),
		"addonVersion": get_addon_version(),
		"assetsPath": absolute_download_path,
		}
	var json = JSON.stringify(data)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json)

func on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var text = body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		var msg = data["message"]
		var level = data["message_level"]
		var client_version = data["client_version"]
		failed_requests = 0
		timer.wait_time = WAIT_OK
		if !msg || level < LOG_LEVEL:
			return
		print("BlenderKit: %s" % msg)
		return
	
	print("Request to Client on port %s failed with response code: %d" % [CLIENT_PORTS[ports_index], response_code])
	ports_index += 1
	if ports_index >= len(CLIENT_PORTS):
		ports_index = 0
		
	failed_requests += 1
	if failed_requests < 2*len(CLIENT_PORTS):
		timer.wait_time = WAIT_EXPLORING
	else:
		timer.wait_time = WAIT_FAILING

	print("Response: %s" % body.get_string_from_utf8())


func get_addon_version():
	var config = ConfigFile.new()
	var err = config.load("res://addons/blenderkit/plugin.cfg")
	if err == OK:
		var addon_version: String = config.get_value("plugin", "version", "unknown")
		return addon_version
	return "unknown"

func get_godot_version():
	var godot_version: String = str(Engine.get_version_info()["major"]) + "." + str(Engine.get_version_info()["minor"]) + "." + str(Engine.get_version_info()["patch"])
	return godot_version
