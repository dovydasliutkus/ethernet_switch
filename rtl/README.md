# Ethernet Switch RTL

This directory contains the RTL implementation of the Ethernet switch, organized into modular blocks.

## Directory Structure

* **`switchcore.v`**
  Top-level module of the Ethernet switch.
  This file serves as the integration template for instantiation in the FPGA project and connects all submodules.

* **`crossbar/`**
  Contains the Cross-Bar switch and the scheduler.
  Responsible for routing packet data from input ports to the selected output ports.

* **`fcs_control/`**
  Implements Frame Check Sequence (FCS) verification and control logic.
  Handles CRC checking, packet buffering, and coordination with the MAC learner and Cross-Bar.

* **`mac_learner/`**
  Contains the MAC learning logic.
  Maintains address tables and determines the destination port for incoming packets.