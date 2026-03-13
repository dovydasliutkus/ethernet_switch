# Specification

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
This module will collect data on 4 ports. It will collect data into FIFOs and CRC calculators at the same time. When a full packet is collected and the CRC is valid for one of the ports it will issue a request to the `MAC Learner`. Once it gets a valid value back from the `MAC Learner` it will start transmitting the corresponding port's data to the `Cross-bar`.

### Notes
1. To reuse `fcs_checker` from Exercise 1. rx_ctrl` will connect to `fcs_check` module. Need to change the `start_frame` and `end_frame` to work with `rx_ctrl` instead.
    * Will need to estimate when the FCS section starts on the fly and do the bit inversion.
2. As data is coming into the `fcs_check` in parallel it will also go to a FIFO.
3. Once `rx_ctrl` goes low check the result from `fcs_check`. If no CRC error assert required signals for crossbar and MAC learning modules. If CRC error just don't assert anything for the following modules (next frame will just overwrite).


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

