import coordinator.{type Algorithm, Gossip, PushSum}
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import node_manager.{
  type Message, PushSum as PushSumMsg, Rumor, create_actors,
  create_pushsum_actors, wire_topology,
}
import topology.{build_full, build_line}

// --------------------
// Main
// --------------------
pub fn main() {
  let num_nodes = 1000
  let algorithm = PushSum

  let self = process.new_subject()

  // Coordinator
  let coord_builder =
    actor.new(coordinator.init(num_nodes, self, algorithm))
    |> actor.on_message(coordinator.update)

  let coord_pid = case actor.start(coord_builder) {
    Ok(started) -> started.data
    Error(_) -> panic as "Could not start coordinator"
  }

  // Spawn actors based on algorithm
  let actors = case algorithm {
    Gossip -> create_actors(num_nodes, coord_pid)
    PushSum -> create_pushsum_actors(num_nodes, coord_pid)
  }

  let topology = topology.build_line(num_nodes)
  wire_topology(actors, topology)
  // Kick off algorithm
  case dict.get(actors, 0) {
    Ok(node0) -> {
      case algorithm {
        Gossip -> {
          io.println("Starting gossip rumor at node 0...")
          actor.send(node0, Rumor("hello world"))
        }
        PushSum -> {
          io.println("Starting push-sum at node 0...")
          actor.send(node0, PushSumMsg(int.to_float(0), 1.0))
        }
      }
    }
    Error(_) -> io.println("Could not find node 0")
  }

  // Wait for convergence
  case process.receive(self, within: 100_000) {
    Ok(coordinator.Finished(elapsed)) -> {
      io.println("Convergence in " <> int.to_string(elapsed) <> " ms")
      io.println("Simulation complete.")
    }
    Ok(coordinator.Done) -> io.println("Unexpected Done in main.")
    Error(_) -> io.println("Timed out waiting for convergence.")
  }
}
