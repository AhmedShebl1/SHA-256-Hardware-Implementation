# SHA‑256 Hardware Implementation

A SystemVerilog hardware implementation of the SHA‑256 cryptographic hash function with:

-  Preprocessing and control finite‑state machine (FSM)
-  Compression core implementing the SHA‑256 round logic
-  Integrated and synthesized design for ICE40 FPGAs using Yosys / nextpnr
-  Verified functionality via comprehensive simulation and testbenches

This project targets FPGA hardware and is intended as a synthesizable core for learning, research, and integration into larger systems.

# 🧠 Overview

SHA‑256 is a widely used cryptographic hash algorithm in the SHA‑2 family that takes an arbitrary‑length input and produces a fixed 256‑bit digest used for integrity, authentication, and digital signatures. 
Wikipedia

This implementation translates the standard SHA‑256 algorithm into hardware logic, enabling accelerated hash computation without software overhead — ideal for embedded and security‑critical designs.

# 🚀 Features

- SystemVerilog RTL implementation

- Preprocessing block handling message padding and partitioning into 512‑bit blocks

- Control FSM sequencing the rounds of SHA‑256

- Compression core that performs the 64‑round transform per message block

- Simulation testbenches exercising functionality for correctness

- Synthesis support with Yosys/nextpnr for ICE40 platforms

# 🧪 Testing & Verification

Testbenches are included to verify:

- Correct SHA‑256 output for known test vectors

- FSM control sequencing

- Compression core round consistency

- Run your simulator of choice with the provided testbenches to validate changes.
