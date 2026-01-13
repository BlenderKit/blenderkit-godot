@tool
extends EditorPlugin

const SERVER = "https://www.blenderkit.com"
const CLIENT_PORTS = ["62485", "65425", "55428", "49452", "35452", "25152", "5152", "1234"]
const CLIENT_VERSION = "v1.5.0"
const LOG_LEVEL = 1 #TODO: configurable
const WAIT_OK: float = 0.5
const WAIT_EXPLORING: float = 0.1
const WAIT_FAILING: float = 1

var status = "exploring" # exploring (check if Client runs)/starting ()/failing/running

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
var VersionLabel
var BrowseAssetsButton
var DownloadDirectory


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
	PortOptionButton = dockedMenuScene.get_node("Port/OptionButton")
	VersionLabel = dockedMenuScene.get_node("DocsContainer/HSplitContainer/Version")
	VersionLabel.text = "BlenderKit v%s" % get_addon_version()
	BrowseAssetsButton = dockedMenuScene.get_node("BrowseAssets")
	BrowseAssetsButton.pressed.connect(browse_asset_gallery_pressed)
	DownloadDirectory = dockedMenuScene.get_node("DownloadTo/LineEdit")
	DownloadDirectory.text_submitted.connect(func(text): download_dir_submitted())
	DownloadDirectory.focus_exited.connect(download_dir_submitted)
	
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
	}
	var json = JSON.stringify(data)
	http_request.cancel_request()
	http_request.request(url, headers, HTTPClient.METHOD_POST, json)


func on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		StatusLabel.text = "Connected (%s)" % CLIENT_PORTS[ports_index]
		var text = body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		var msg = data["message"]
		var level = data["message_level"]
		var client_version = data["client_version"]
		failed_requests = 0
		timer.wait_time = WAIT_OK
		if !msg or level < LOG_LEVEL:
			return
		print("BlenderKit: %s" % msg)
		return
	
	print("Request to Client on port %s failed with response code: %d" % [CLIENT_PORTS[ports_index], response_code])

	# DECIDE STATUS
	failed_requests += 1
	# EXPLORING - plugin just started and we check all possible ports if Client is not already running
	if failed_requests < len(CLIENT_PORTS):
		status = "exploring"
		timer.wait_time = WAIT_EXPLORING
		ports_index += 1
		if ports_index >= len(CLIENT_PORTS):
			ports_index = 0
	# STARTING - client not present, we try to start new Client
	else:
		status = "starting"
		timer.wait_time = WAIT_FAILING
		if failed_requests % len(CLIENT_PORTS) == 0:
			var selected_index = PortOptionButton.get_selected()
			var port = PortOptionButton.get_item_text(selected_index)
			ports_index = CLIENT_PORTS.find(port)
			start_client(port)

	StatusLabel.text = "%s (%s)..." % [status, failed_requests]

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


func ensure_dir_structure():
	var client_dir = get_client_dir()
	DirAccess.make_dir_recursive_absolute(client_dir)
	return


func get_client_dir():
	var home_path := ""
	if OS.has_feature("windows"):
		home_path = OS.get_environment("USERPROFILE")
	else:
		home_path = OS.get_environment("HOME")
	return home_path + "/blenderkit_data/client"


func get_client_binary_name():
	var arch = Engine.get_architecture_name()
	if OS.has_feature("windows"):
		return "blenderkit-client-windows-" + arch + ".exe"
	if OS.has_feature("macos"):
		return "blenderkit-client-macos-" + arch
	if OS.has_feature("linux"):
		return "blenderkit-client-linux-" + arch


func get_packed_client_binary_path():
	var plugin_dir = self.get_script().resource_path.get_base_dir()
	var client_bin_name = get_client_binary_name()
	var bin_path = plugin_dir + "/client/" + CLIENT_VERSION + "/" + client_bin_name
	return ProjectSettings.globalize_path(bin_path)


func get_client_log_path(port: String):
	# TODO: create the file if it does not exist
	var client_dir = get_client_dir()
	if port == "62485":
		return client_dir + "/default.log"
	return client_dir + "/%s.log" % port


func start_client(port: String):
	ensure_dir_structure() # so log's directory exists
	var client_bin = get_packed_client_binary_path() # we execute directly from the plugin directory
	var log_path = get_client_log_path(port)
	var godot_PID = str(OS.get_process_id())
	var client_PID: int = 0

	print("Starting Client %s (log: %s)" % [CLIENT_VERSION, log_path])
	# Godot's OS.create_process(), OS.execute() and simillar does not support redirecting pipe to file, so we do it via shells
	if OS.has_feature("windows"):
		var command_str = '"%s" -port %s -server %s -software Godot -pid %s > "%s" 2>&1' % [client_bin, port, SERVER, godot_PID, log_path]
		client_PID = OS.create_process("cmd.exe", ["/C", "start", "/B", "", command_str])
	elif OS.has_feature("macos") or OS.has_feature("linux"):
		var shell_command = '%s -port %s -server %s -software Godot -pid %s > "%s" 2>&1 &' % [client_bin, port, SERVER, godot_PID, log_path]
		client_PID = OS.create_process("/bin/sh", ["-c", shell_command])
	else:
		print("Could not start client: Unsupported OS. Only Windows, MacOS and Linux are supported.")
		return

	if client_PID == 0:
		print("Failed to start the client.")
	else:
		print("Client started (port:%s, PID=%s)" % [port, client_PID])


func browse_asset_gallery_pressed():
	OS.shell_open(SERVER)


func download_dir_submitted():
	download_dir = DownloadDirectory.text
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	print("absolute_download_path is %s" % absolute_download_path)
