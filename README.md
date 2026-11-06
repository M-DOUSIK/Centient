# Centient: Hardware Accelerators for Nano-Drone Swarms

**Team Centient** · *Towards a nano-drone flight-controller SoC*

Deterministic RTL accelerators that take swarm-intelligence tasks off a nano-drone's flight-controller CPU: leader (*Queen*) election, failure-triggered succession and IMU pre-filtering.

![Verilog](https://img.shields.io/badge/HDL-Verilog_%2F_SystemVerilog-blue)
![Vivado](https://img.shields.io/badge/Synthesis-Vivado_(Zynq--7020)-orange)
![Cadence Genus](https://img.shields.io/badge/Power_reports-Cadence_Genus-red)
![Icarus](https://img.shields.io/badge/sim-Icarus_Verilog-lightgrey)
![License](https://img.shields.io/badge/license-Unlicense-green)

---

## Why Hardware?

In software, swarm leader election has jitter that depends on the scheduler, cache state and interrupt load. A dedicated datapath gives a **fixed, predictable latency** for a given swarm size and does the job at a fraction of the energy, freeing the CPU for flight control.

```
               ┌────────────────────────── Drone SoC ──────────────────────────┐
 IMU ─────────►│  IMU pre-filter ──► Flight controller CPU                     │
               │                          │                                    │
 Battery / ───►│  QSTU (health monitor) ──┴─► elec_trigger ──► QSSE (election) ├──► new Queen ID
 temp / link   │                                                ▲              │
               │                       neighbour table (RAM) ───┘              │
               └───────────────────────────────────────────────────────────────┘
```

## Modules

### QSSE: Queen Successor Selection Engine
Chooses the best new leader using the score **battery / distance²** computed over the 3D positions of neighbouring drones. All arithmetic is fixed-point, with no floating point.

| | **v1**: combinational | **v2**: sequential, RAM-backed |
|---|---|---|
| Swarm size | Fixed, 4 drones | Up to **256** (parameter `N`) |
| Inputs | Flat ports with an SNR matrix | 64-bit records in dual-port RAM: `{id, battery, z, y, x}` |
| Datapath | Fully unrolled | Multi-cycle score unit with an FSM-driven candidate × neighbour loop |
| Slice LUTs | 7,699 | **1,252 (−84 %)** |
| DSP48 | 36 | **1** |
| Registers / BRAM | 0 / 0 | 288 / 1 |
| Verification | Directed test | **13 scenarios**: negative coordinates, zero battery, geometric ties, crowd, … |

*Post-synthesis utilisation on xc7z020 (Vivado). The full reports are in [`reports/`](reports).*

### QSTU: Queen Successor Trigger Unit
A watchdog that decides **when** to run an election. It combines two kinds of signal:

- **Fast failures** (event-driven): battery under-voltage, thermal trip, comm timeout. These trigger immediately.
- **Slow health score** (periodic): a weighted, fixed-point sum of battery SoC, SoH, clamped temperature and link quality. Falling below a threshold triggers an election.

Elections are suppressed while `flight_stable` is low, which rejects transient false positives.

| | v1 | v2 |
|---|---|---|
| Language | SystemVerilog (`QSTU` + area-optimised `opt_qstu`) | Verilog-2001 |
| Structure | Single module | `qstu_compute` (combinational) + `qstu_trigger` (registered), with shared widths in `qstu_config.vh` |
| Configuration | Hard-coded weights | Weights, thresholds and temperature limits are runtime inputs |
| Slice LUTs / DSP | 64 / 1 | 131 / 5 |
| Verification | 2 DUTs, directed | 10 directed tests: fast fails, clamping, red threshold, recovery |

### IMU pre-filter
A first-order IIR low-pass filter (α ≈ 0.1, Q8 fixed-point) on all six accelerometer and gyro axes. It smooths raw IMU data before state estimation and fault detection. 739 LUTs and 6 DSPs.

## Repository Structure

```
.
├── rtl/
│   ├── qsse_v1/        Combinational 4-drone selector (top_nopipe)
│   ├── qsse_v2/        centient_top · processor · score_calc · ram
│   ├── qstu_v1/        QSTU, opt_qstu (SystemVerilog)
│   ├── qstu_v2/        qstu_subsystem · qstu_compute · qstu_trigger · qstu_config.vh
│   └── imu_filter/     iir_filter
├── tb/                 One self-checking / directed testbench per module
├── reports/            Vivado post-synthesis utilisation reports
├── docs/               QSSE v1 schematic
└── Makefile            Icarus Verilog simulation flow
```

## Simulation

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) 12+ (or the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)).

```sh
make sim          # run every testbench
make qsse_v2      # run one: qsse_v1 | qsse_v2 | qstu_v1 | qstu_v2 | imu_filter
make clean
```

To use **Vivado** instead, create a project, add `rtl/<module>/` as design sources and the matching `tb/tb_<module>.v` as the simulation source. For `qstu_v2`, also add `rtl/qstu_v2` to the include path.

## Results at a Glance

- **QSSE v2 uses 84 % fewer LUTs and 35 fewer DSPs than v1** while scaling from 4 to 256 drones.
- Election latency is **deterministic**, a function of swarm size only, with no software jitter.
- Power reports for the QSSE were generated in Cadence Genus.

## License

Released into the public domain under [The Unlicense](LICENSE).
