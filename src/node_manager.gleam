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
  )
}

// --------------------
// Gossip init
// --------------------
pub fn init(id: Int, coord: process.Subject(CoordMsg)) -> State {
  State(id, 0, [], coord)
}

// --------------------
// Gossip update
// --------------------
pub fn update(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    Rumor(rumor) -> {
      let heard2 = state.heard + 1
      io.println(
        "Node "
        <> int.to_string(state.id)
        <> " heard rumor "
        <> int.to_string(heard2)
        <> ": "
        <> rumor,
      )

      case heard2 < 10 {
        True -> {
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
          actor.continue(State(state.id, heard2, state.neighbors, state.coord))
        }
        False -> {
          io.println("Node " <> int.to_string(state.id) <> " stopped gossiping")
          actor.send(state.coord, Done)
          actor.continue(State(state.id, heard2, state.neighbors, state.coord))
        }
      }
    }

    SetNeighbors(new_neighbors) ->
      actor.continue(State(state.id, state.heard, new_neighbors, state.coord))

    _ -> actor.continue(state)
  }
}

// --------------------
// Helpers: spawn + wire
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
  )
}

// Init push-sum actor
pub fn init_pushsum(id: Int, coord: process.Subject(CoordMsg)) -> PushSumState {
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
    coord,
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
      case stable_rounds2 >= 3 {
        True -> {
          io.println(
            "Node "
            <> int.to_string(state.id)
            <> " stable ratio: "
            <> float.to_string(ratio),
          )
          actor.send(state.coord, Done)
          // Keep participating, don’t stop — coordinator decides convergence
          actor.continue(PushSumState(
            state.id,
            s_new /. 2.0,
            w_new /. 2.0,
            stable_rounds2,
            ratio,
            state.neighbors,
            state.coord,
          ))
        }
        False -> {
          // Keep gossiping half to random neighbor
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
          actor.continue(PushSumState(
            state.id,
            s_new /. 2.0,
            w_new /. 2.0,
            stable_rounds2,
            ratio,
            state.neighbors,
            state.coord,
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
  |> list.fold(dict.new(), fn(acc, id) {
    let builder =
      actor.new(init_pushsum(id, coord))
      |> actor.on_message(update_pushsum)

    case actor.start(builder) {
      Ok(started) -> dict.insert(acc, id, started.data)
      Error(_) -> acc
    }
  })
}
