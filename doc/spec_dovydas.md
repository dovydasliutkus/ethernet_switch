# Specification

## Spec
1. Handle 8k MAC addresses
2. Frame size ranging from 64B to 1518B (excluding IFG and preamble)
3. GMII Interface
4. Switch must be non-blocking
5. No frame reordering of frames form the same flow

## Signals

`packet_valid` - 1-hot encoded signal. When the bit corresponding to the input Port is high, the input port will start transmitting data.
`[3:0] dst_port [0:3]` - 1-hot encoded destination port. There are 4 of these vectors for each input port.
...

## System level operation

1. A packet from Port 0 is collected in FIFO(0) and the CRC calculation is correct.
2. `FCS` extracts src and dst and issues a request to the `MAC Learner`.
3. When `MAC Learner` issues done the `FCS` grabs `dst_port` forwards it to the `Cross-bar` and sets the corresponding bit of `packet_valid`.
4. As soon as `FCS` sets a bit in `packet_valid` it starts transmiting from FIFO(0) to the `Cross-bar` FIFO.
5. Once `FCS` finishes sending a packet it sets the corresponding `packet_valid` bit back to 0.

### Notes
* MAC Learner services one address at a time.
* If multiple `CRC` modules issue a valid at the same time they will be serviced by the `MAC Learner` in a round-robin fashion.
* If the FCS is trying to write into a Cross-bar FIFO that's full then the Cross-bar will drop that data.


## Detailed operation

### FCS and control

This module will collect data on 4 ports. It will collect data into FIFOs and CRC calculators at the same time. 

The `packet_status` FIFOs will keep track of how many packets have a valid CRC and inherently the number of packets in the FIFO (based on the FIFO pointers).

The `packet_length` FIFOs will keep track of how long the packets are within the input FIFOs. This will be used to decide how many bytes have to be sent to the cross bar once the `dst_port` has been resolved.

When a full packet is collected (`rx_ctrl` goes low) record the result from the CRC calculator in `packet_status` FIFO, record the packet length in `packet_length` FIFO. 

* If the first output in `packet_status` is 0 dump the packet. 

* If the first output in `packet_status` is 1 make a request to the `MAC Learner`, then with the returned `dst_port` start transmition to `Cross-bar`


### Notes
1. To reuse `fcs_checker` from Exercise 1. `rx_ctrl` will connect to `fcs_check` module. Need to change the `start_frame` and `end_frame` to work with `rx_ctrl` instead.
    * Will need to estimate when the FCS section starts on the fly and do the bit inversion.
2. As data is coming into the `CRC calculator` in parallel it will also go to a FIFO.



### MAC Learner

#### Working principle
When a frame arrives at a switch, the switch learns the source MAC address and remembers which port it came from.
So when a destination address matching a saved address comes in from another port then the switch can direct the packet to the learned mac address instead of broadcasting (flooding).

##### Example
    A packet appears on Port 1 with Source MAC: A 
    Destination MAC: B
    Port 1 is assigned to MAC A
    When B responds on Port 2 the MAC LUT already knows that A is on Port 1 so no need for flooding.

Source address is sent to the `Mac Learner` to create a new entry into the LUT.
Destination address is sent ot the `Mac Learner` to see if there is an entry that can be used.


#### Entry aging

The MAC LUT has finite size, so eventually it can fill up. To manage this, we implement aging:

* **Option chosen:** Discard entries that haven’t been used for a while (simpler than prioritizing by access frequency).

**Implementation:**

* Generate a hash from each MAC address to index into the LUT.
* Each index holds 4 entries:

```
entry = { mac, port, valid_bit, timestamp }
```

* On new entry arrival:

  1. Check for an invalid or expired entry in the bucket and use it.
  2. If all entries are valid, replace the one with the **oldest timestamp**.

**Notes:**

* An additional **expired flag** is optional, but timestamps can be compared against a global age limit to determine expiration.

