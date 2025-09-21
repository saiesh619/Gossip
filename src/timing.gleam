@external(erlang, "erlang", "monotonic_time")
fn erlang_monotonic_time(unit: TimeUnit) -> Int

@external(erlang, "erlang", "system_time")
fn erlang_system_time(unit: TimeUnit) -> Int

@external(erlang, "erlang", "statistics")
fn erlang_statistics(item: StatisticsItem) -> #(Int, Int)

// --------------------
// Types
// --------------------

pub type TimeUnit {
  Microsecond
  Millisecond
  Nanosecond
  Second
}

pub type StatisticsItem {
  Runtime
  // CPU time used
  WallClock
  // Elapsed real time
}

// --------------------
// Helpers
// --------------------

/// Monotonic clock (safe for measuring elapsed time).
pub fn monotonic_time(unit: TimeUnit) -> Int {
  erlang_monotonic_time(unit)
}

/// System time (wall clock).
pub fn system_time(unit: TimeUnit) -> Int {
  erlang_system_time(unit)
}

/// CPU runtime stats (#total, #since_last_call)
pub fn runtime_statistics() -> #(Int, Int) {
  erlang_statistics(Runtime)
}

/// Wall clock stats (#total, #since_last_call)
pub fn wall_clock_statistics() -> #(Int, Int) {
  erlang_statistics(WallClock)
}

/// Measure execution time in ms.
pub fn time_function(func: fn() -> a) -> #(a, Int) {
  let start = monotonic_time(Millisecond)
  let result = func()
  let stop = monotonic_time(Millisecond)
  #(result, stop - start)
}

/// Measure execution time in μs.
pub fn time_function_microseconds(func: fn() -> a) -> #(a, Int) {
  let start = monotonic_time(Microsecond)
  let result = func()
  let stop = monotonic_time(Microsecond)
  #(result, stop - start)
}
