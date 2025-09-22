

# Gossip & Push-Sum Simulation

## Team Members

* Saiesh Prabhu
* Pranav Anne


---

## What is Working

* Implemented **Gossip** and **Push-Sum** algorithms.
* Supported topologies: **Line, Full, 3D, Imperfect 3D**.
* Measured convergence time as a function of network size.
* Generated comparative plots for both algorithms across topologies.
* Report with interesting findings has been prepared (`Report.pdf`).

---

## Largest Network Size Tested

### Gossip Algorithm

* **Line:** 6400 nodes
* **Full:** 6400 nodes
* **3D:** 6400 nodes
* **Imperfect 3D:** 6400 nodes

### Push-Sum Algorithm

* **Line:** 800 nodes
* **Full:** 3200 nodes
* **3D:** 6400 nodes
* **Imperfect 3D:** 1600 nodes

---

argest Network Size Tested
Gossip Algorithm

Line: 6400 nodes

Full: 6400 nodes

3D: 6400 nodes

Imperfect 3D: 6400 nodes

Push-Sum Algorithm

Line: 800 nodes

Full: 3200 nodes

3D: 6400 nodes

Imperfect 3D: 1600 nodes

How It Is Implemented

Language & Framework: Implemented in Gleam using Erlang’s lightweight processes and message-passing model.

Actor Model: Each node is represented as an actor with its own state and mailbox. Nodes exchange messages according to the algorithm (rumor or (s, w) values).

Topology Wiring: Neighbor lists are built programmatically for each topology before the simulation begins. For imperfect 3D, an additional pseudo-random neighbor is added deterministically.

Coordinator Process: A central coordinator actor monitors termination conditions and records convergence times.

Non-CLI Design:

The code is written as a library-style module, not dependent on command-line arguments.

To run an experiment, function calls (e.g., run_gossip(line, 1000)) are made directly in the main module.

This makes it easy to script multiple runs programmatically without manual CLI input.

Notes

Plots in Report.pdf use log-log axes for clarity.

Some anomalies in Push-Sum results (e.g., Line topology at 400 vs 800 nodes) are due to stochastic convergence criteria, not algorithmic errors.

Full topology shows overhead at very large network sizes due to runtime and scheduling costs, consistent with expected simulation artifacts.
