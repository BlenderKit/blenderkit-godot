@tool
extends EditorPlugin

const SERVER = "https://www.blenderkit.com"
const CLIENT_PORTS = ["62485", "65425", "55428", "49452", "35452", "25152", "5152", "1234"]
const LOG_LEVEL = 1 # TODO: configurable
const WAIT_OK: float = 0.5
const WAIT_EXPLORING: float = 0.1
const WAIT_STARTING: float = 1

const STATE_DISABLED = "disabled"
const STATE_EXPLORING = "exploring"
const STATE_STARTING = "starting"
const STATE_CONNECTED = "connected"
const STATE_FAILED = "failed"

var state = STATE_DISABLED
var fail_reason: String = ""

var download_dir: String = "res://bk_assets/"
var absolute_download_path: String
var port: String = CLIENT_PORTS[0]
var failed_requests: int = 0
var max_failed_requests: int = 5
var http_request: HTTPRequest
var timer: Timer

# paths
var bk_plugin_dir: String
var client_data_dir: String
var client_version: String
var client_base_dir: String
var client_bin_name: String
var client_bin_path: String

# GUI
const menu_scene = preload("res://addons/blenderkit/menu.tscn")
var docked_menu_scene: Control
var enabled_check_button: CheckButton
var status_label: Label
var port_option_button: OptionButton
var version_label: Label
var browse_assets_button: Button
var download_directory: LineEdit


func _enter_tree():
	print("BlenderKit: Plugin enabled")
	init_paths()
	print("BlenderKit: Download path: %s" % absolute_download_path)
	print("BlenderKit: Client data dir: %s" % client_data_dir)

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(on_request_completed)

	timer = Timer.new()
	timer.one_shot = false
	timer.autostart = false
	add_child(timer)
	timer.timeout.connect(on_timer_timeout)

	init_ui()
	if enabled_check_button.is_pressed():
		enter_state(STATE_EXPLORING)


func _exit_tree():
	timer.queue_free()
	http_request.queue_free()
	cleanup_ui()
	print("BlenderKit: Plugin exited")


func fail(reason: String):
	fail_reason = reason
	state = STATE_FAILED
	timer.stop()
	http_request.cancel_request()
	push_error("BlenderKit Client failed: %s. Please consider reporting this with your Output." % fail_reason)
	update_status()


func enter_state(new_state: String):
	# Centralized state transition code
	state = new_state
	failed_requests = 0
	match new_state:
		STATE_DISABLED:
			print("BlenderKit: Disabled")
			timer.stop()
			http_request.cancel_request()
		STATE_EXPLORING:
			port = CLIENT_PORTS[0]
			timer.wait_time = WAIT_EXPLORING
			timer.start()
			print("BlenderKit: Searching for running Client...")
		STATE_STARTING:
			timer.wait_time = WAIT_STARTING
			timer.start()
			start_client(port)
		STATE_CONNECTED:
			timer.wait_time = WAIT_OK
			timer.start()
			print("BlenderKit: Connected to Client v%s on port %s" % [client_version, port])
		_:
			fail("invalid state %s" % new_state)

	update_status()


func update_status():
	match state:
		STATE_DISABLED:
			status_label.text = "Disabled"
		STATE_EXPLORING:
			status_label.text = "Exploring..."
		STATE_STARTING:
			if failed_requests > 0:
				status_label.text = "Starting (#%s)..." % failed_requests
			else:
				status_label.text = "Starting..."
		STATE_CONNECTED:
			if failed_requests > 0:
				status_label.text = "Reconnecting (#%s)..." % failed_requests
			else:
				status_label.text = "Connected (port %s)" % port
		STATE_FAILED:
			status_label.text = "Failed (%s)" % fail_reason


func start_client(port: String):
	# look for client binaries again in case they were added
	find_packed_client()
	if not FileAccess.file_exists(client_bin_path):
		push_error("BlenderKit Client binary not found. The plugin cannot work without the Client :(")
		print("BlenderKit: Expected Client binary path: %s" % client_bin_path)
		fail("Client binary not found")
		return

	ensure_dir_structure() # so log's directory exists
	var log_path = get_client_log_path(port)
	var godot_pid = str(OS.get_process_id())
	var client_pid: int = 0
	var command_str: String = ""

	print("BlenderKit: Starting Client v%s on port %s" % [client_version, port])
	# Godot's OS.create_process(), OS.execute() and similar does not support redirecting pipe to file, so we do it via shells

	if OS.has_feature("windows"):
		command_str = '"%s" -port %s -server %s -software Godot -pid %s > "%s" 2>&1' % [client_bin_path, port, SERVER, godot_pid, log_path]
		client_pid = OS.create_process("cmd.exe", ["/C", "start", "/B", "", command_str])
	elif OS.has_feature("macos") or OS.has_feature("linux"):
		command_str = '%s -port %s -server %s -software Godot -pid %s > "%s" 2>&1 &' % [client_bin_path, port, SERVER, godot_pid, log_path]
		client_pid = OS.create_process("/bin/sh", ["-c", command_str])
	else:
		push_error("Could not start BlenderKit client: Unsupported OS. Only Windows, MacOS and Linux are supported.")
		fail("unsupported OS")
		return

	if client_pid == 0:
		push_error("Failed to start the BlenderKit Client.")
		print("BlenderKit: Failed command: %s" % command_str)
		fail("client start failed")
		return


func on_timer_timeout():
	if state in [STATE_FAILED, STATE_DISABLED]:
		push_warning("BlenderKit: timer fired in %s state - shouldn't happen" % state)
		return

	var url = "http://localhost:" + port + "/godot/report"
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


func on_request_completed(_result, response_code, _headers, body):
	if state == STATE_FAILED:
		push_warning("BlenderKit: request completed in failed state - strange")

	var body_text: String = body.get_string_from_utf8()

	# Success - connected to client
	if response_code == 200:
		if state != STATE_CONNECTED:
			enter_state(STATE_CONNECTED)

		var data = JSON.parse_string(body_text)
		var msg = data["message"]
		var level = data["message_level"]
		if msg and level >= LOG_LEVEL:
			print("BlenderKit: Client message: %s" % msg)
		return

	# Failure - log and handle based on state
	failed_requests += 1
	if state != STATE_EXPLORING:
		print("BlenderKit: Request on port %s failed (%d)" % [port, response_code])
	if body_text != "":
		print("BlenderKit: Response body: %s" % body_text)

	if state == STATE_EXPLORING:
		var port_index = CLIENT_PORTS.find(port)
		port_index += 1
		if port_index < CLIENT_PORTS.size():
			port = CLIENT_PORTS[port_index]
		else:
			var selected_index = port_option_button.get_selected()
			port = port_option_button.get_item_text(selected_index)
			print("BlenderKit: No running Client found")
			enter_state(STATE_STARTING)

	elif state == STATE_STARTING:
		if failed_requests > max_failed_requests:
			push_error("Failed to connect to BlenderKit Client on port %s after %s tries." % [port, failed_requests])
			fail("connection timeout")
			return
		update_status()

	elif state == STATE_CONNECTED:
		if failed_requests >= max_failed_requests:
			push_warning("Lost connection to BlenderKit Client on port %s." % port)
			enter_state(STATE_EXPLORING)
			return
		update_status()

	else:
		push_error("Unexpected state: %s" % state)
		fail("unexpected state")


func on_enabled_toggled(enabled: bool):
	if enabled:
		enter_state(STATE_EXPLORING)
	else:
		enter_state(STATE_DISABLED)


func on_browse_assets_pressed():
	OS.shell_open(SERVER)


func on_download_dir_submitted(_text: String = ""):
	download_dir = download_directory.text
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	print("BlenderKit: Download path set to: %s" % absolute_download_path)


func init_paths():
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	client_bin_name = get_client_binary_name()
	client_data_dir = get_client_data_dir()
	bk_plugin_dir = self.get_script().resource_path.get_base_dir()
	client_base_dir = bk_plugin_dir + "/client/"
	find_packed_client()


func find_packed_client():
	client_version = get_version_from_dir(client_base_dir)
	client_bin_path = get_packed_client_binary_path()


func init_ui():
	docked_menu_scene = menu_scene.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, docked_menu_scene)
	enabled_check_button = docked_menu_scene.get_node("StatusRow/Enabled/CheckButton")
	enabled_check_button.toggled.connect(on_enabled_toggled)
	status_label = docked_menu_scene.get_node("StatusRow/Status/Label")
	port_option_button = docked_menu_scene.get_node("Port/OptionButton")
	version_label = docked_menu_scene.get_node("DocsContainer/HSplitContainer/Version")
	version_label.text = "BlenderKit v%s" % get_addon_version()
	browse_assets_button = docked_menu_scene.get_node("BrowseAssets")
	browse_assets_button.pressed.connect(on_browse_assets_pressed)
	download_directory = docked_menu_scene.get_node("DownloadTo/LineEdit")
	download_directory.text_submitted.connect(on_download_dir_submitted)
	download_directory.focus_exited.connect(on_download_dir_submitted)


func cleanup_ui():
	remove_control_from_docks(docked_menu_scene)
	docked_menu_scene.queue_free()


func get_addon_version():
	var config = ConfigFile.new()
	var err = config.load("res://addons/blenderkit/plugin.cfg")
	if err != OK:
		return "unknown"
	return config.get_value("plugin", "version", "unknown")


func get_godot_version():
	return str(Engine.get_version_info()["major"]) + "." + str(Engine.get_version_info()["minor"]) + "." + str(Engine.get_version_info()["patch"])


func get_packed_client_binary_path():
	var bin_path = client_base_dir + "v" + client_version + "/" + client_bin_name
	return ProjectSettings.globalize_path(bin_path)


func get_client_log_path(log_port: String) -> String:
	# TODO: create the file if it does not exist
	if log_port == CLIENT_PORTS[0]:
		return client_data_dir + "/default.log"
	return client_data_dir + "/%s.log" % log_port


static func get_client_data_dir():
	var home_path := ""
	if OS.has_feature("windows"):
		home_path = OS.get_environment("USERPROFILE")
	else:
		home_path = OS.get_environment("HOME")
	return home_path + "/blenderkit_data/client"


static func get_client_binary_name() -> String:
	var arch = Engine.get_architecture_name()
	if OS.has_feature("windows"):
		return "blenderkit-client-windows-" + arch + ".exe"
	if OS.has_feature("macos"):
		return "blenderkit-client-macos-" + arch
	if OS.has_feature("linux"):
		return "blenderkit-client-linux-" + arch
	return ""


static func get_version_from_dir(base_dir: String) -> String:
	var dir = DirAccess.open(base_dir)
	if not dir:
		return ""

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name.begins_with("v"):
			var version = file_name.substr(1) # Remove 'v'
			dir.list_dir_end()
			return version
		file_name = dir.get_next()

	dir.list_dir_end()
	return ""


func ensure_dir_structure():
	DirAccess.make_dir_recursive_absolute(client_data_dir)
