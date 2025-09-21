import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result

/// Creates a line topology where each node has at most two neighbors.
///
pub fn build_line(num_nodes: Int) -> dict.Dict(Int, List(Int)) {
  let node_ids = list.range(0, num_nodes - 1)

  case num_nodes <= 1 {
    // If there's 1 node, it has no neighbors. If 0, it's an empty map.
    True -> {
      let list_of_nodes = list.range(0, num_nodes - 1)

      list.fold(list_of_nodes, dict.new(), fn(acc, id) {
        // Use dict.new()
        dict.insert(acc, id, [])
        // Use dict.insert()
      })
    }

    _ -> {
      list.fold(over: node_ids, from: dict.new(), with: fn(acc, id) {
        // Use dict.new()
        let neighbors = case id {
          0 -> [1]
          _ if id < num_nodes - 1 -> [id - 1, id + 1]
          _ -> [id - 1]
        }

        dict.insert(acc, id, neighbors)
        // Use dict.insert()
      })
    }
  }
}

pub fn build_full(num_nodes: Int) -> dict.Dict(Int, List(Int)) {
  let node_ids = list.range(0, num_nodes - 1)

  list.fold(over: node_ids, from: dict.new(), with: fn(acc, id) {
    // neighbors = all nodes except this one
    let neighbors = list.filter(node_ids, fn(n) { n != id })

    dict.insert(acc, id, neighbors)
  })
}
