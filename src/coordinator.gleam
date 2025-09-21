import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import timing

// --------------------
// Coordinator messages
// --------------------
pub type CoordMsg {
  Done
  Finished(Int)
}

// --------------------
// Algorithm type
// --------------------
pub type Algorithm {
  Gossip
  PushSum
}

// --------------------
// Coordinator state
// --------------------
pub type CoordState {
  CoordState(
    start: Int,
    total: Int,
    finished: Int,
    main: process.Subject(CoordMsg),
    algorithm: Algorithm,
  )
}

// --------------------
// Init
// --------------------
pub fn init(
  total: Int,
  main: process.Subject(CoordMsg),
  algo: Algorithm,
) -> CoordState {
  CoordState(timing.monotonic_time(timing.Millisecond), total, 0, main, algo)
}

// --------------------
// Update
// --------------------
pub fn update(
  state: CoordState,
  msg: CoordMsg,
) -> actor.Next(CoordState, CoordMsg) {
  case msg {
    Done -> {
      let finished2 = state.finished + 1

      case state.algorithm {
        Gossip -> {
          // progress tracking
          //io.println(
          //"[Gossip] Progress: "
          //<> int.to_string(finished2)
          //<> "/"
          //<> int.to_string(state.total)
          //<> " nodes done",
          //)

          case finished2 == state.total {
            True -> {
              let stop = timing.monotonic_time(timing.Millisecond)
              let elapsed = stop - state.start
              process.send(state.main, Finished(elapsed))
              actor.stop()
            }
            False ->
              actor.continue(CoordState(
                state.start,
                state.total,
                finished2,
                state.main,
                state.algorithm,
              ))
          }
        }

        PushSum -> {
          // progress tracking

          case finished2 == state.total {
            True -> {
              let stop = timing.monotonic_time(timing.Millisecond)
              let elapsed = stop - state.start
              process.send(state.main, Finished(elapsed))
              actor.stop()
            }
            False ->
              actor.continue(CoordState(
                state.start,
                state.total,
                finished2,
                state.main,
                state.algorithm,
              ))
          }
        }
      }
    }

    Finished(_) -> actor.continue(state)
    // ignore extra Finished
  }
}
