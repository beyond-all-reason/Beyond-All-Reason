---
--- The kinds a condition can declare. The kind decides which threshold a trigger may use:
--- an event is an occurrence, counted towards `count`; a metric is a value sampled now that
--- can move either way, compared against `atLeast` / `atMost`.
---

return {
	Event = "event",
	Metric = "metric",
}
