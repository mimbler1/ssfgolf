class_name PerfStat
extends RefCounted
## Tiny named timing accumulator for the perf probe. Callers do:
##   var t := PerfStat.begin()  ...  PerfStat.end("name", t)
## and the probe prints the totals per phase. Off (zero cost beyond one bool check) unless enabled.

static var enabled := false
static var totals: Dictionary = {}   ## name -> [usec total, calls]


static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func end(name: String, t0: int) -> void:
	if not enabled:
		return
	var row: Array = totals.get(name, [0, 0])
	row[0] += Time.get_ticks_usec() - t0
	row[1] += 1
	totals[name] = row


static func reset() -> void:
	totals.clear()


## Rows sorted by total time: [name, total ms, calls].
static func report() -> Array:
	var out: Array = []
	for k: String in totals:
		out.append([k, totals[k][0] / 1000.0, totals[k][1]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out
