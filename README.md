# Centient: Deterministic and Energy-Efficient Hardware Accelerators for Nano Drone Swarms

**Team Centient** | *Towards a Nano Drone Flight Controller SoC*

## Overview

**Centient** is a hardware acceleration suite designed to offload critical swarm intelligence tasks from the main flight controller of nano drones. By implementing deterministic algorithms in dedicated hardware, this project achieves predictable latency, reduced energy consumption, and high throughput for autonomous swarm operations.

This repository contains the Verilog HDL implementation of two core accelerators:
1.  **QSSE (Queen Successor Selection Engine):** A logic-heavy accelerator for autonomous leader election.
2.  **QSTU (Queen Successor Trigger Unit):** A predictive module responsible for initiating succession based on system health.

## System Architecture

### 1. QSSE (Queen Successor Selection Engine)
The QSSE allows a drone to autonomously determine the best "Queen" (leader) for the swarm based on real-time data from neighbors.

* **Function:** Evaluates neighbor drones based on 3D proximity (Distance squared) and Battery Health.
* **Key Features:**
    * **Deterministic Latency:** Fixed computation time based on swarm size, eliminating software jitter.
    * **Custom Arithmetic Unit:** Dedicated hardware for the `(Battery / Distance^2)` metric without floating-point overhead.
    * **Dual-Port Memory:** Decouples external data loading from internal processing for continuous operation.
* **Verification:** Validated with 13 stress-test scenarios, including negative coordinates, zero battery, and geometric ties.

### 2. QSTU (Queen Successor Trigger Unit)
The QSTU acts as the system's watchdog, responsible for initiating the succession process when it predicts a leader failure.

* **Function:** Continuously monitors drone parameters to predict failure and automatically triggers the election process.
* **Key Features:**
    * **Predictive Failure Analysis:** Monitors both **fast-changing** (e.g., sudden impact, stability loss) and **slow-changing** (e.g., battery drift) parameters to forecast failure.
    * **Autonomous Triggering:** Initiates the succession protocol immediately upon detecting critical thresholds, without waiting for software timeouts.
    * **False Positive Rejection:** Filters transient noise to ensure elections are only triggered during genuine failure events.

## Repository Structure

```text
Centient_Hardware/
├── rtl/                  # Synthesizable Verilog Source Code
│   ├── qsse/             # QSSE Modules (processor.v, ram.v, centient_top.v)
│   ├── qstu/             # QSTU Modules (trigger_unit.v, monitor.v)
│   └── common/           # Shared definitions and headers
│
├── sim/                  # Simulation Files
│   ├── testbenches/      # Self-checking testbenches (tb_centient_top.v)
│   └── waves/            # Saved waveform configurations (WCFG)
│
├── docs/                 # Documentation & Block Diagrams
│   ├── architecture/     # System block diagrams and FSM charts
│   └── verification/     # Simulation logs and coverage reports
│
└── synthesis/            # Synthesis Scripts & Constraints
    ├── xilinx/           # Vivado project files and constraints (.xdc)
    └── reports/          # Area, Power, and Timing reports
