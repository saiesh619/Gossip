import gleam/dict
import gleam/list

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

/// Creates a 3D grid topology where each node has up to 6 neighbors.
/// The grid dimensions are calculated to best fit the number of nodes.
///
pub fn build_3d_grid(num_nodes: Int) -> dict.Dict(Int, List(Int)) {
  case num_nodes <= 0 {
    True -> dict.new()
    False -> {
      // Calculate cube root to get grid dimensions
      let side_length = get_cube_root(num_nodes)
      let node_ids = list.range(0, num_nodes - 1)

      list.fold(over: node_ids, from: dict.new(), with: fn(acc, id) {
        let neighbors = get_3d_neighbors(id, side_length, num_nodes)
        dict.insert(acc, id, neighbors)
      })
    }
  }
}

/// Helper function to get approximate cube root for grid sizing
fn get_cube_root(n: Int) -> Int {
  case n {
    0 -> 0
    1 -> 1
    _ -> {
      // Simple iteration to find cube root
      find_cube_root_helper(n, 1)
    }
  }
}

/// Helper to find cube root by iteration
fn find_cube_root_helper(n: Int, candidate: Int) -> Int {
  let cubed = candidate * candidate * candidate
  case cubed {
    _ if cubed >= n -> candidate
    _ -> find_cube_root_helper(n, candidate + 1)
  }
}

/// Get neighbors for a node in a 3D grid
fn get_3d_neighbors(id: Int, side_length: Int, num_nodes: Int) -> List(Int) {
  // Convert 1D id to 3D coordinates
  let z = id / { side_length * side_length }
  let y = { id % { side_length * side_length } } / side_length
  let x = id % side_length

  // Check all 6 possible directions
  let possible_neighbors = [
    // Left (-x)
    case x > 0 {
      True -> [id - 1]
      False -> []
    },
    // Right (+x)
    case x < side_length - 1 {
      True -> [id + 1]
      False -> []
    },
    // Down (-y)
    case y > 0 {
      True -> [id - side_length]
      False -> []
    },
    // Up (+y)
    case y < side_length - 1 {
      True -> [id + side_length]
      False -> []
    },
    // Back (-z)
    case z > 0 {
      True -> [id - side_length * side_length]
      False -> []
    },
    // Front (+z)
    case z < side_length - 1 {
      True -> [id + side_length * side_length]
      False -> []
    },
  ]

  possible_neighbors
  |> list.flatten()
  |> list.filter(fn(neighbor_id) { neighbor_id >= 0 && neighbor_id < num_nodes })
}

/// Creates an imperfect 3D grid topology where each node has its 3D grid neighbors
/// plus one additional randomly selected neighbor from anywhere in the network.
///
pub fn build_imperfect_3d_grid(num_nodes: Int) -> dict.Dict(Int, List(Int)) {
  case num_nodes <= 0 {
    True -> dict.new()
    False -> {
      // Start with regular 3D grid
      let side_length = get_cube_root(num_nodes)
      let node_ids = list.range(0, num_nodes - 1)

      list.fold(over: node_ids, from: dict.new(), with: fn(acc, id) {
        // Get regular 3D neighbors
        let grid_neighbors = get_3d_neighbors(id, side_length, num_nodes)

        // Add one additional random neighbor
        let random_neighbor =
          get_pseudo_random_neighbor(id, num_nodes, grid_neighbors)
        let all_neighbors = case random_neighbor {
          -1 -> grid_neighbors
          // No additional neighbor found
          _ -> [random_neighbor, ..grid_neighbors]
        }

        dict.insert(acc, id, all_neighbors)
      })
    }
  }
}

/// Get a pseudo-random additional neighbor for imperfect grid
/// Uses deterministic selection based on node ID to avoid true randomization
fn get_pseudo_random_neighbor(
  id: Int,
  num_nodes: Int,
  existing_neighbors: List(Int),
) -> Int {
  // Use a simple hash-like function based on node ID
  let candidate = { id * 7 + 13 } % num_nodes

  // Make sure it's not the node itself or already a neighbor
  case candidate == id || list.contains(existing_neighbors, candidate) {
    True -> {
      // Try a different candidate
      let alternative = { id * 11 + 23 } % num_nodes
      case alternative == id || list.contains(existing_neighbors, alternative) {
        True -> -1
        // No valid additional neighbor found
        False -> alternative
      }
    }
    False -> candidate
  }
}
