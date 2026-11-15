class_name ScriptErrorCounter
extends Logger
## Self-test helper: counts every SCRIPT ERROR the engine logs (any thread), and keeps the last one's text, so the
## self-test can turn a crashed check into a FAIL instead of skipping it silently. Added with OS.add_logger().

var _mutex := Mutex.new()
var _count: int = 0
var _last: String = ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	_count += 1
	_last = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
	_mutex.unlock()


func count() -> int:
	_mutex.lock()
	var n: int = _count
	_mutex.unlock()
	return n


func last() -> String:
	_mutex.lock()
	var s: String = _last
	_mutex.unlock()
	return s
