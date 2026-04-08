# FCS and Control module RTL

## Directory Structure

### **FIFOs/**

This directory contains FIFO IP cores used by the FCS and Control module. All FIFOs are generated using Quartus Prime Lite.

Subdirectories:

* **data/** - buffers incoming packet bytes. Size: 2048x8
* **packet_length/** - stores length of each packet. Size: 32x11
* **packet_status/** - stores CRC result (1=valid, 0=invalid). Size: 32x1
* **src_mac/** - stores extracted SRC MAC. Size: 32x48
* **dst_mac/** - stores extracted DST MAC. Size: 32x48

#### Notes
1. Currently FIFOs were generated for MAX 10 FPGA family. Might need to regenerate for the one we test on.
2. Depth for `packet_length` and `packet_status` FIFOs is derived from the data FIFO size divided by the minimum Ethernet packet size (64 bytes).
3. All FIFOs operate in a **single clock domain**.