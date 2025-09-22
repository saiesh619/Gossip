import coordinator.{type CoordMsg, Done}
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string

// --------------------
// Gossip + Push-Sum messages
// --------------------
pub type Message {
  Rumor(String)
  PushSum(Float, Float)
  SetNeighbors(List(process.Subject(Message)))
}

@external(erlang, "rand", "uniform")
fn uniform(n: Int) -> Int

pub fn pick_one(len: Int) -> Int {
  case len <= 0 {
    True -> 0
    False -> uniform(len) - 1
  }
}

// --------------------
// Gossip actor state
// --------------------
pub type State {
  State(
    id: Int,
    heard: Int,
    neighbors: List(process.Subject(Message)),
    coord: process.Subject(CoordMsg),
    terminated: Bool,
  )
}

// --------------------
// Gossip init
// --------------------
pub fn init(id: Int, coord: process.Subject(CoordMsg)) -> State {
  State(id, 0, [], coord, False)
}

// --------------------
// Gossip update
// --------------------
pub fn update(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Rumor(rumor) -> {
      let heard2 = state.heard + 1

      // Notify coordinator the very first time this node hears rumor
      case heard2 {
        10 -> actor.send(state.coord, Done)
        _ -> Nil
      }

      io.println(
        "Node "
        <> int.to_string(state.id)
        <> " heard rumor "
        <> int.to_string(heard2)
        <> ": "
        <> rumor,
      )

      // Always forward rumor to a random neighbor
      case list.length(state.neighbors) {
        0 -> Nil
        n -> {
          let idx = pick_one(n)
          case list.drop(state.neighbors, idx) {
            [neighbor, ..] -> actor.send(neighbor, Rumor(rumor))
            _ -> Nil
          }
        }
      }

      // Keep actor alive, don’t self-stop
      actor.continue(State(
        state.id,
        heard2,
        state.neighbors,
        state.coord,
        state.terminated,
      ))
    }

    SetNeighbors(new_neighbors) ->
      actor.continue(State(
        state.id,
        state.heard,
        new_neighbors,
        state.coord,
        state.terminated,
      ))

    _ -> actor.continue(state)
  }
}

// --------------------
// Helpers: spawn actors
// --------------------
pub fn create_actors(
  num_nodes: Int,
  coord: process.Subject(CoordMsg),
) -> dict.Dict(Int, process.Subject(Message)) {
  list.range(0, num_nodes - 1)
  |> list.fold(dict.new(), fn(acc, id) {
    let builder =
      actor.new(init(id, coord))
      |> actor.on_message(update)

    case actor.start(builder) {
      Ok(started) -> dict.insert(acc, id, started.data)
      Error(_) -> acc
    }
  })
}

pub fn wire_topology(
  actors: dict.Dict(Int, process.Subject(Message)),
  topology: dict.Dict(Int, List(Int)),
) {
  list.each(dict.to_list(topology), fn(pair) {
    let #(id, neighbors) = pair
    case dict.get(actors, id) {
      Ok(inbox) -> {
        let neighbor_subjects =
          list.filter_map(neighbors, fn(nid) {
            case dict.get(actors, nid) {
              Ok(n) -> Ok(n)
              Error(_) -> Error("Neighbor not found")
            }
          })
        let neighbor_str =
          neighbors
          |> list.map(int.to_string)
          |> string.join(", ")
        io.println(
          "Node " <> int.to_string(id) <> " neighbors: [" <> neighbor_str <> "]",
        )
        io.println(
          "Node "
          <> int.to_string(id)
          <> " neighbors: ["
          <> { neighbors |> list.map(int.to_string) |> string.join(", ") }
          <> "]",
        )

        actor.send(inbox, SetNeighbors(neighbor_subjects))
      }
      Error(_) -> Nil
    }
  })
}

// ======================================================
// Push-Sum additions
// ======================================================

// Push-Sum actor state
pub type PushSumState {
  PushSumState(
    id: Int,
    s: Float,
    w: Float,
    stable_rounds: Int,
    last_ratio: Float,
    neighbors: List(process.Subject(Message)),
    coord: process.Subject(CoordMsg),
    terminated: Bool,
    me: process.Subject(Message),
  )
}

// Init push-sum actor
pub fn init_pushsum(
  id: Int,
  coord: process.Subject(CoordMsg),
  me: process.Subject(Message),
) -> PushSumState {
  let s0 = int.to_float(id)
  PushSumState(
    id,
    s0,
    // initial s
    1.0,
    // initial w
    0,
    // stable rounds
    s0 /. 1.0,
    // initial ratio
    [],
    // neighbors
    coord,
    False,
    // terminated
    me,
    // self reference
  )
}

// Update push-sum actor
pub fn update_pushsum(
  state: PushSumState,
  msg: Message,
) -> actor.Next(PushSumState, Message) {
  case msg {
    PushSum(s_in, w_in) -> {
      let s_new = state.s +. s_in
      let w_new = state.w +. w_in
      let ratio = s_new /. w_new

      // Check if ratio has stabilized
      let diff = float.absolute_value(ratio -. state.last_ratio)
      let stable_rounds2 = case diff <. 1.0e-10 {
        True -> state.stable_rounds + 1
        False -> 0
      }

      // If stable 3 times in a row → report Done
      case stable_rounds2 >= 3 && !state.terminated {
        True -> {
          actor.send(state.coord, Done)

          actor.continue(PushSumState(
            state.id,
            s_new /. 2.0,
            w_new /. 2.0,
            stable_rounds2,
            ratio,
            state.neighbors,
            state.coord,
            True,
            // <- mark terminated
            state.me,
            // <- keep self reference
          ))
        }
        False -> {
          // forward half to neighbor (if any)
          case list.length(state.neighbors) {
            0 -> Nil
            n -> {
              let idx = pick_one(n)
              case list.drop(state.neighbors, idx) {
                [neighbor, ..] ->
                  actor.send(neighbor, PushSum(s_new /. 2.0, w_new /. 2.0))
                _ -> Nil
              }
            }
          }

          // self-tick to keep alive
          actor.send(state.me, PushSum(0.0, 0.0))

          actor.continue(PushSumState(
            state.id,
            s_new /. 2.0,
            w_new /. 2.0,
            stable_rounds2,
            ratio,
            state.neighbors,
            state.coord,
            state.terminated,
            // don’t reset
            state.me,
          ))
        }
      }
    }

    SetNeighbors(new_neighbors) ->
      actor.continue(PushSumState(
        state.id,
        state.s,
        state.w,
        state.stable_rounds,
        state.last_ratio,
        new_neighbors,
        state.coord,
        state.terminated,
        // preserve termination status
        state.me,
        // preserve self reference
      ))

    _ -> actor.continue(state)
    // ignore Rumor messages
  }
}

// Spawn push-sum actors
pub fn create_pushsum_actors(
  num_nodes: Int,
  coord: process.Subject(CoordMsg),
) -> dict.Dict(Int, process.Subject(Message)) {
  list.range(0, num_nodes - 1)
  |> list.fold(dict.new(), fn(acc, node_id) {
    let builder =
      actor.new_with_initialiser(1000, fn(me) {
        // `me` is this actor’s Subject(Message)
        let state = init_pushsum(node_id, coord, me)
        actor.initialised(state)
        |> actor.returning(me)
        // so started.data = Subject(Message)
        |> Ok
      })
      |> actor.on_message(update_pushsum)

    case actor.start(builder) {
      Ok(started) -> dict.insert(acc, node_id, started.data)
      Error(_) -> acc
    }
  })
}
