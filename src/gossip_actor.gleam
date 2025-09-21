import gleam/erlang/process.{type Pid}

pub type GossipState {
  GossipState(id: Int, rumor_count: Int, neighbors: List(Pid))
}
