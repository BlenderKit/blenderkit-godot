@tool
extends EditorPlugin

const CLIENT_PORTS = ["65425", "55428", "49452", "35452", "25152", "5152", "1234", "62485"]
const CLIENT_VERSION = "v1.1.2"
const LOG_LEVEL = 1 #TODO: configurable
const WAIT_OK: float = 0.5
const WAIT_EXPLORING: float = 0.1
const WAIT_FAILING: float = 1

var port = "62485" # TODO: configurable
var server = "https://www.blenderkit.com"

var download_dir: String = "res://bk_assets/"
var absolute_download_path: String
var ports_index: int = 0
var failed_requests: int = 0
var http_request: HTTPRequest
var timer: Timer

# GUI
const menu_scene = preload("res://addons/blenderkit/menu.tscn")
var dockedMenuScene
var EnabledCheckButton
var StatusLabel
var PortOptionButton


func _enter_tree():
	print("BlenderKit plugin enabled")
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	print("Assets will be downloaded to: ", absolute_download_path)
	var client_dir = get_client_dir()
	print("Client_dir expected at: ", client_dir)
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "on_request_completed"))

	# GUI
	dockedMenuScene = menu_scene.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dockedMenuScene)
	EnabledCheckButton = dockedMenuScene.get_node("StatusRow/Enabled/CheckButton")
	EnabledCheckButton.connect("toggled", Callable(self, "EnabledCheckButtonChanged"))
	StatusLabel = dockedMenuScene.get_node("StatusRow/Status/Label")
	
	if EnabledCheckButton.is_pressed():
		start_timer()

func _exit_tree():
	if !timer:
		return
	timer.stop()
	timer.queue_free()
	http_request.queue_free()
	
	remove_control_from_docks(dockedMenuScene)
	dockedMenuScene.queue_free()
	print("BlenderKit plugin exited")
	

func start_timer():	
	failed_requests = 0
	timer = Timer.new()
	timer.wait_time = WAIT_EXPLORING
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "on_timer_timeout"))
	
func stop_timer():
	if not timer:
		return
	timer.stop()
	timer.queue_free()

func EnabledCheckButtonChanged(state: bool):
	if state:
		start_timer()
	else:
		StatusLabel.text = "Disabled"
		stop_timer()


func on_timer_timeout():
	var url = "http://localhost:" + CLIENT_PORTS[ports_index] + "/godot/report"
	var headers = ["Content-Type: application/json"]
	var data = {
		"name": "Godot",
		"appID": OS.get_process_id(),
		"version": get_godot_version(),
		"addonVersion": get_addon_version(),
		"assetsPath": absolute_download_path,
		"projectName": ProjectSettings.get_setting("application/config/name"),
	var json = JSON.stringify(data)
	http_request.cancel_request()
	http_request.request(url, headers, HTTPClient.METHOD_POST, json)


func on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		StatusLabel.text = "Connected"
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
	
	StatusLabel.text = "Connecting..."
	print("Request to Client on port %s failed with response code: %d" % [CLIENT_PORTS[ports_index], response_code])
	ports_index += 1
	if ports_index >= len(CLIENT_PORTS):
		ports_index = 0
		
	failed_requests += 1
	if failed_requests < len(CLIENT_PORTS):
		timer.wait_time = WAIT_EXPLORING
	else:
		timer.wait_time = WAIT_FAILING

	var text = body.get_string_from_utf8()
	if text != "":
		print("--> response: %s" % text)


func get_addon_version():
	var config = ConfigFile.new()
	var err = config.load("res://addons/blenderkit/plugin.cfg")
	if err != OK:
		return "unknown"	
	return config.get_value("plugin", "version", "unknown")
	
func get_godot_version():
	return str(Engine.get_version_info()["major"]) + "." + str(Engine.get_version_info()["minor"]) + "." + str(Engine.get_version_info()["patch"])




### WILL NOT BE USED PROBABLY ###

func get_client_dir():
	var home_path := ""
	if OS.has_feature("windows"):
		home_path = OS.get_environment("USERPROFILE")
	else:
		home_path = OS.get_environment("HOME")
	return home_path + "/blenderkit_data/client"

func get_client_binary():
	var client_dir = get_client_dir()
	var arch = Engine.get_architecture_name()
	var client_bin: String
	if OS.has_feature("windows"):
		client_bin = client_dir + "/bin/" + CLIENT_VERSION + "/blenderkit-client-windows-" + arch + ".exe"
	elif OS.has_feature("macos"):
		client_bin = client_dir + "/bin/" + CLIENT_VERSION + "/blenderkit-client-macos-" + arch
	elif OS.has_feature("linux"):
		client_bin = client_dir + "/bin/" + CLIENT_VERSION + "/blenderkit-client-linux-" + arch
	return client_bin 

func start_client():
	var client_dir = get_client_dir()
	var client_bin = get_client_binary()
	var log = client_dir + "/default.log"

	var output = []
	var command: String
	var args: Array
	
	OS.create_process(client_bin, args)
