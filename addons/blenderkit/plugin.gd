@tool
extends EditorPlugin

const SERVER = "https://www.blenderkit.com"
const CLIENT_PORTS = ["62485", "65425", "55428"]
#const CLIENT_PORTS = ["62485", "65425", "55428", "49452", "35452", "25152", "5152", "1234"]
const WAIT_OK: float = 0.5
const WAIT_EXPLORING: float = 0.2
const WAIT_STARTING: float = 1
const REQUEST_TIMEOUT: int = 3000


enum LogLevel { ERROR, WARNING, INFO, VERBOSE, DEBUG, TRACE }

const LOG_LEVEL_NAMES = {
	LogLevel.ERROR: "ERROR",
	LogLevel.WARNING: "WARNING",
	LogLevel.INFO: "INFO",
	LogLevel.VERBOSE: "VERBOSE",
	LogLevel.DEBUG: "DEBUG",
	LogLevel.TRACE: "TRACE",
}

var log_level: int = LogLevel.DEBUG

func bk_log(level: LogLevel, msg: String) -> void:
	if level > log_level:
		return
	var prefix = "BlenderKit %s: " % LOG_LEVEL_NAMES[level]
	var log_msg = prefix + msg
	match level:
		LogLevel.ERROR:
			push_error(log_msg)
		LogLevel.WARNING:
			push_warning(log_msg)
		_:
			print(log_msg)


enum State { DISABLED, EXPLORING, STARTING, CONNECTED, FAILED }

const STATE_NAMES = {
	State.DISABLED: "DISABLED",
	State.EXPLORING: "EXPLORING",
	State.STARTING: "STARTING",
	State.CONNECTED: "CONNECTED",
	State.FAILED: "FAILED",
}

static func state_name(s: State) -> String:
	return STATE_NAMES.get(s, str(s))


const HTTP_CLIENT_STATUS_NAMES = {
	HTTPClient.STATUS_DISCONNECTED: "DISCONNECTED",
	HTTPClient.STATUS_RESOLVING: "RESOLVING",
	HTTPClient.STATUS_CANT_RESOLVE: "CANT_RESOLVE",
	HTTPClient.STATUS_CONNECTING: "CONNECTING",
	HTTPClient.STATUS_CANT_CONNECT: "CANT_CONNECT",
	HTTPClient.STATUS_CONNECTED: "CONNECTED",
	HTTPClient.STATUS_REQUESTING: "REQUESTING",
	HTTPClient.STATUS_BODY: "BODY",
	HTTPClient.STATUS_CONNECTION_ERROR: "CONNECTION_ERROR",
	HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: "TLS_HANDSHAKE_ERROR",
}

static func http_status_name(status: int) -> String:
	return HTTP_CLIENT_STATUS_NAMES.get(status, str(status))


const HTTP_REQUEST_RESULT_NAMES = {
	HTTPRequest.RESULT_SUCCESS: "SUCCESS",
	HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "CHUNKED_BODY_SIZE_MISMATCH",
	HTTPRequest.RESULT_CANT_CONNECT: "CANT_CONNECT",
	HTTPRequest.RESULT_CANT_RESOLVE: "CANT_RESOLVE",
	HTTPRequest.RESULT_CONNECTION_ERROR: "CONNECTION_ERROR",
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "TLS_HANDSHAKE_ERROR",
	HTTPRequest.RESULT_NO_RESPONSE: "NO_RESPONSE",
	HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "BODY_SIZE_LIMIT_EXCEEDED",
	HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "BODY_DECOMPRESS_FAILED",
	HTTPRequest.RESULT_REQUEST_FAILED: "REQUEST_FAILED",
	HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "REDIRECT_LIMIT_REACHED",
	HTTPRequest.RESULT_TIMEOUT: "TIMEOUT",
}

static func http_result_name(result: int) -> String:
	return HTTP_REQUEST_RESULT_NAMES.get(result, str(result))


var state: State = State.DISABLED
var fail_reason: String = ""

var download_dir: String = "res://bk_assets/"
var absolute_download_path: String
var port: String = CLIENT_PORTS[0]
var failed_requests: int = 0
var max_failed_requests: int = 3
var request_start_time: int = 0
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
var log_level_option_button: OptionButton
var version_label: Label
var browse_assets_button: Button
var download_directory: LineEdit


func _enter_tree():
	bk_log(LogLevel.INFO, "Plugin enabled")
	init_paths()
	bk_log(LogLevel.INFO, "Download path: %s" % absolute_download_path)
	bk_log(LogLevel.INFO, "Client data dir: %s" % client_data_dir)

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
		enter_state(State.EXPLORING)


func _exit_tree():
	timer.queue_free()
	http_request.queue_free()
	cleanup_ui()
	bk_log(LogLevel.INFO, "Plugin exited")


func fail(reason: String):
	fail_reason = reason
	state = State.FAILED
	timer.stop()
	http_request.cancel_request()
	bk_log(LogLevel.ERROR, "Client failed: %s. Please consider reporting this with your Output." % fail_reason)
	update_status()


func enter_state(new_state: State):
	# Centralized state transition code
	state = new_state
	failed_requests = 0
	match new_state:
		State.DISABLED:
			bk_log(LogLevel.INFO, "Disabled")
			timer.stop()
			http_request.cancel_request()
		State.EXPLORING:
			port = CLIENT_PORTS[0]
			timer.wait_time = WAIT_EXPLORING
			timer.start()
			bk_log(LogLevel.INFO, "Searching for running Client...")
		State.STARTING:
			timer.wait_time = WAIT_STARTING
			timer.start()
			start_client(port)
		State.CONNECTED:
			timer.wait_time = WAIT_OK
			timer.start()
			bk_log(LogLevel.INFO, "Connected to Client v%s on port %s" % [client_version, port])
		_:
			fail("invalid state %s" % state_name(new_state))

	update_status()


func update_status():
	match state:
		State.DISABLED:
			status_label.text = "Disabled"
		State.EXPLORING:
			status_label.text = "Exploring..."
		State.STARTING:
			if failed_requests > 0:
				status_label.text = "Starting (#%s)..." % failed_requests
			else:
				status_label.text = "Starting..."
		State.CONNECTED:
			if failed_requests > 0:
				status_label.text = "Reconnecting (#%s)..." % failed_requests
			else:
				status_label.text = "Connected (port %s)" % port
		State.FAILED:
			status_label.text = "Failed (%s)" % fail_reason


func start_client(port: String):
	# look for client binaries again in case they were added
	find_packed_client()
	if not FileAccess.file_exists(client_bin_path):
		bk_log(LogLevel.ERROR, "Client binary not found. The plugin cannot work without the Client :(")
		bk_log(LogLevel.DEBUG, "Expected Client binary path: %s" % client_bin_path)
		fail("Client binary not found")
		return

	ensure_dir_structure() # so log's directory exists
	var log_path = get_client_log_path(port)
	var godot_pid = str(OS.get_process_id())
	var client_pid: int = 0
	var command_str: String = ""

	bk_log(LogLevel.INFO, "Starting Client v%s on port %s" % [client_version, port])
	# Godot's OS.create_process(), OS.execute() and similar does not support redirecting pipe to file, so we do it via shells

	if OS.has_feature("windows"):
		var win_log_path = log_path.replace("/", "\\")
		command_str = 'start /B "" "%s" -port %s -server %s -software Godot -pid %s > "%s" 2>&1' % [client_bin_path, port, SERVER, godot_pid, win_log_path]
		client_pid = OS.create_process("cmd.exe", ["/C", command_str])
	elif OS.has_feature("macos") or OS.has_feature("linux"):
		command_str = '%s -port %s -server %s -software Godot -pid %s > "%s" 2>&1 &' % [client_bin_path, port, SERVER, godot_pid, log_path]
		client_pid = OS.create_process("/bin/sh", ["-c", command_str])
	else:
		bk_log(LogLevel.ERROR, "Could not start client: Unsupported OS. Only Windows, MacOS and Linux are supported.")
		fail("unsupported OS")
		return

	if client_pid == 0:
		bk_log(LogLevel.ERROR, "Failed to start the BlenderKit Client.")
		bk_log(LogLevel.DEBUG, "Failed command: %s" % command_str)
		fail("client start failed")
		return


func on_timer_timeout():
	if state in [State.FAILED, State.DISABLED]:
		bk_log(LogLevel.WARNING, "Timer fired in %s state - shouldn't happen" % state_name(state))
		return

	var http_client_status := http_request.get_http_client_status()
	var prev_request_failed := false
	if http_client_status != HTTPClient.STATUS_DISCONNECTED:
		bk_log(LogLevel.TRACE, "HTTP client: %s" % http_status_name(http_client_status))

	match http_client_status:
		HTTPClient.STATUS_CONNECTING:
			# Probably no-one listening on that port
			bk_log(LogLevel.DEBUG, "CONNECTING for too long on port %s" % port)
			prev_request_failed = true
		HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_BODY, HTTPClient.STATUS_REQUESTING:
			# Waiting for response - check timeout
			var elapsed := Time.get_ticks_msec() - request_start_time
			if elapsed >= REQUEST_TIMEOUT:
				bk_log(LogLevel.WARNING, "Request timeout in %s after %dms" % [http_status_name(http_client_status), elapsed])
				prev_request_failed = true
			else:
				bk_log(LogLevel.DEBUG, "Waiting in %s (%d ms)" % [http_status_name(http_client_status), elapsed])
				return
		HTTPClient.STATUS_DISCONNECTED:
			# Ready to request
			pass
		_:
			# Other states are unexpected errors
			prev_request_failed = true
			bk_log(LogLevel.WARNING, "HTTP client: %s" % http_status_name(http_client_status))

	if prev_request_failed:
		bk_log(LogLevel.TRACE, "HTTP request: cancelling request after client fail")
		http_request.cancel_request()
		request_failed()
		if state in [State.FAILED, State.DISABLED]:
			return

	if state == State.EXPLORING:
		bk_log(LogLevel.VERBOSE, "Exploring port %s..." % port)

	var url = "http://127.0.0.1:" + port + "/godot/report"
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
	request_start_time = Time.get_ticks_msec()
	bk_log(LogLevel.TRACE, "POST %s  %s" % [url, json])
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	if error != OK:
		bk_log(LogLevel.ERROR, "Error sending request to %s, error=%s" % [url, error])


func on_request_completed(result, response_code, _headers, body):
	var elapsed := Time.get_ticks_msec() - request_start_time
	if result != OK:
		bk_log(LogLevel.DEBUG, "Request %s, response_code=%d, state=%s, port=%s" % [http_result_name(result), response_code, state_name(state), port])
	if state == State.FAILED:
		bk_log(LogLevel.WARNING, "Request completed in failed state - strange")

	var body_text: String = body.get_string_from_utf8()
	bk_log(LogLevel.TRACE, "HTTP response (%d ms): %s" % [elapsed, body_text])

	# Success - connected to client
	if response_code == 200:
		if state != State.CONNECTED:
			enter_state(State.CONNECTED)

		var data = JSON.parse_string(body_text)
		var msg = data.get("message", "")
		var level: int = int(data.get("message_level", LogLevel.INFO))
		if msg and level <= log_level:
			bk_log(level, "Client: %s" % msg)
		return

	if state == State.EXPLORING:
		bk_log(LogLevel.VERBOSE, "Client not found on port %s" % port)
	else:
		bk_log(LogLevel.WARNING, "Request on port %s failed (response_code=%d)" % [port, response_code])
	if body_text != "":
		bk_log(LogLevel.TRACE, "Response body: %s" % body_text)

	request_failed()


func request_failed():
	failed_requests += 1

	if state == State.EXPLORING:
		var port_index = CLIENT_PORTS.find(port)
		port_index += 1
		if port_index < CLIENT_PORTS.size():
			port = CLIENT_PORTS[port_index]
		else:
			var selected_index = port_option_button.get_selected()
			port = port_option_button.get_item_text(selected_index)
			bk_log(LogLevel.VERBOSE, "No running Client found")
			enter_state(State.STARTING)

	elif state == State.STARTING:
		if failed_requests > max_failed_requests:
			bk_log(LogLevel.ERROR, "Failed to connect to Client on port %s after %s tries." % [port, failed_requests])
			fail("connection timeout")
			return
		update_status()

	elif state == State.CONNECTED:
		if failed_requests >= max_failed_requests:
			bk_log(LogLevel.WARNING, "Lost connection to BlenderKit Client on port %s." % port)
			enter_state(State.EXPLORING)
			return
		update_status()

	else:
		bk_log(LogLevel.ERROR, "Unexpected state: %s" % state_name(state))
		fail("unexpected state")


func on_enabled_toggled(enabled: bool):
	if enabled:
		enter_state(State.EXPLORING)
	else:
		enter_state(State.DISABLED)


func on_browse_assets_pressed():
	OS.shell_open(SERVER)


func on_download_dir_submitted(_text: String = ""):
	download_dir = download_directory.text
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	bk_log(LogLevel.INFO, "Download path set to: %s" % absolute_download_path)


func on_log_level_changed(index: int):
	log_level = index
	bk_log(LogLevel.INFO, "Log level set to %s" % LOG_LEVEL_NAMES[log_level])


func init_paths():
	absolute_download_path = ProjectSettings.globalize_path(download_dir)
	client_bin_name = get_client_binary_name()
	client_data_dir = get_client_data_dir()
	bk_plugin_dir = self.get_script().resource_path.get_base_dir()
	client_base_dir = bk_plugin_dir.path_join("client")
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
	log_level_option_button = docked_menu_scene.get_node("LogLevel/OptionButton")
	log_level_option_button.selected = log_level
	log_level_option_button.item_selected.connect(on_log_level_changed)


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
	var bin_path = client_base_dir.path_join("v" + client_version).path_join(client_bin_name)
	return ProjectSettings.globalize_path(bin_path)


func get_client_log_path(log_port: String) -> String:
	# TODO: create the file if it does not exist
	if log_port == CLIENT_PORTS[0]:
		return client_data_dir.path_join("default.log")
	return client_data_dir.path_join("%s.log" % log_port)


static func get_client_data_dir():
	var home_path := ""
	if OS.has_feature("windows"):
		home_path = OS.get_environment("USERPROFILE")
	else:
		home_path = OS.get_environment("HOME")
	return home_path.path_join("blenderkit_data").path_join("client")


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
