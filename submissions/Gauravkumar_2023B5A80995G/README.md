# Synchronous FIFO — Implementation & Verification

## Overview

This project implements and verifies a parameterized synchronous FIFO in Verilog.
All read/write operations are clocked on the rising edge of a shared clock.

---

## File Structure

```
rtl/
  sync_fifo_top.v   — Top-level wrapper module
  sync_fifo.v       — Core FIFO implementation

tb/
  tb_sync_fifo.v    — Self-checking testbench

docs/
  README.md         — This file
```

---

## Parameters

| Parameter    | Default | Description                     |
|-------------|---------|----------------------------------|
| `DATA_WIDTH` | 8       | Width of each data word (bits)   |
| `DEPTH`      | 16      | Number of storage locations      |
| `ADDR_WIDTH` | clog2(DEPTH) | Auto-computed pointer width |

---

## Interface

| Port       | Dir    | Width           | Description                     |
|------------|--------|-----------------|----------------------------------|
| `clk`      | input  | 1               | Clock (rising edge active)       |
| `rst_n`    | input  | 1               | Synchronous active-low reset     |
| `wr_en`    | input  | 1               | Write enable                     |
| `wr_data`  | input  | DATA_WIDTH      | Data to write                    |
| `wr_full`  | output | 1               | FIFO full flag                   |
| `rd_en`    | input  | 1               | Read enable                      |
| `rd_data`  | output | DATA_WIDTH      | Data read out (registered)       |
| `rd_empty` | output | 1               | FIFO empty flag                  |
| `count`    | output | ADDR_WIDTH+1    | Occupancy count                  |

---

## Functional Behavior

- **Reset**: Synchronous, active-low. All pointers and count reset to 0.
- **Write**: Occurs when `wr_en=1` and `wr_full=0`. Ignored if FIFO is full.
- **Read**: Occurs when `rd_en=1` and `rd_empty=0`. Ignored if FIFO is empty.
- **Simultaneous R/W**: Both pointers advance; count is unchanged.
- **Pointer wrap**: Write and read pointers wrap from `DEPTH-1` back to `0`.

---

## Testbench Design

### Golden Reference Model
An independent behavioral model updates on every clock edge using the same
rules as the DUT. It maintains its own `model_mem`, `model_wr_ptr`,
`model_rd_ptr`, and `model_count` — never reading from DUT signals.

### Scoreboard
After each cycle (with a small `#1` delay for signal settling), the
scoreboard compares:
- `rd_data` vs `model_rd_data`
- `count` vs `model_count`
- `rd_empty` vs `(model_count == 0)`
- `wr_full` vs `(model_count == DEPTH)`

On any mismatch, the simulation prints full diagnostics and calls `$finish`.

### Directed Tests

| Test                      | What it verifies                                 |
|---------------------------|--------------------------------------------------|
| Reset Test                | Pointers, count, flags after reset               |
| Single Write/Read         | Basic data integrity and counter updates         |
| Fill Test                 | Full flag assertion, overflow prevention         |
| Drain Test                | Empty flag assertion, data ordering              |
| Overflow Attempt          | No state change on write-when-full               |
| Underflow Attempt         | No state change on read-when-empty               |
| Simultaneous Read/Write   | Concurrent operation, count stability            |
| Pointer Wrap-Around       | Correct modular pointer arithmetic               |
| Random Stress (500 cycles)| Broad random coverage                            |

### Coverage Counters

| Counter        | Measures                              |
|----------------|---------------------------------------|
| `cov_full`     | Cycles FIFO was full                  |
| `cov_empty`    | Cycles FIFO was empty                 |
| `cov_wrap`     | Pointer wrap-around events            |
| `cov_simul`    | Valid simultaneous R/W cycles         |
| `cov_overflow` | Write attempts while full             |
| `cov_underflow`| Read attempts while empty             |

All counters must be non-zero for adequate coverage.

---

## How to Simulate (Icarus Verilog)

```bash
iverilog -o sim rtl/sync_fifo_top.v rtl/sync_fifo.v tb/tb_sync_fifo.v
vvp sim
```

## How to Simulate (ModelSim / Questa)

```bash
vlog rtl/sync_fifo_top.v rtl/sync_fifo.v tb/tb_sync_fifo.v
vsim -c tb_sync_fifo -do "run -all; quit"
```
