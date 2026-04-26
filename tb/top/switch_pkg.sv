package switch_pkg;

//////////////////// TEST CONFIGURATION TYPES ////////////////////

/*TODO
TEST CONFIGURATION TYPES
  Defines parameters used to describe test scenarios (traffic pattern,
  packet size and load). These will later be used by the testbench and
  driver to generate different traffic behaviors, enabling reusable and
 scalable regression testing (e.g. via a sanity.tl file).
 */

typedef enum {
  SINGLE,
  INDEPENDENT,
  CONTENTION,
  ALL_TO_ONE
} traffic_pattern_e;

typedef enum {
  FIXED,
  MIXED
} pkt_size_e;

typedef enum {
  LOW,
  HIGH
} load_e;

// Holds one test scenario configuration
// pattern: traffic mapping between ports
// pkt_size: fixed or mixed packet sizes
// load: low (with gaps) or high (back-to-back)
// fixed_len: packet length when pkt_size is equal to FIXED

class test_cfg;
  traffic_pattern_e pattern;
  pkt_size_e        pkt_size;
  load_e            load;
  int               fixed_len;
endclass


// FRAME CLASS
class frame;

  int src_port; 
  int dst_port;
  byte data[$]; // dynmamic queue of bytes w. push, pop

  function new(int src_port, int dst_port); // constructor for frame
    this.src_port = src_port; // TODO: THIS IS JUST FOR DEBUGGING. IT IS NOT USED. BUT CAN BE USED FOR MAC LEARNER LATER
    this.dst_port = dst_port;
  endfunction

endclass

// DRIVER
class switch_driver #(parameter PORTS=4, DATA_W=8); // todo: IT IS FIXED ANYWAY, SO WE CAN PROBABLY REMOVE THESE PARAMETERS

  virtual switch_if vif;

  mailbox #(frame) exp_q[PORTS]; // array of per-port mailboxes holding expected frame handles

  function new(  // constructor for switch_driver class
    virtual switch_if vif,
    mailbox #(frame) exp_q[PORTS]
  );
    this.vif   = vif;
    this.exp_q = exp_q;
  endfunction

  ////////////////// DRIVER TASKS ////////////////////

  // RESET
  task reset();
    vif.reset <= 0; // active low reset
    vif.cb.rx_ctrl <= '0;
    vif.cb.rx_data <= '0;
    repeat (5) @(vif.cb);

    vif.reset <= 1;
    repeat (5) @(vif.cb);

  endtask


  // SEND FRAME 
  task send_frame(int port, frame f);

    // publish expected
    exp_q[f.dst_port].put(f); // put=push_back, get=pop_front for mailbox

    // wait one cycle before start
    vif.cb.rx_ctrl[port] <= 0;
    @(vif.cb);

    // send bytes
    foreach (f.data[i]) begin // for as long as there are bytes in the frame,
                              // send them one by one on the interface
      vif.cb.rx_ctrl[port] <= 1;
      vif.cb.rx_data[port*DATA_W +: DATA_W] <= f.data[i];
      @(vif.cb);
    end

    // end of frame
    vif.cb.rx_ctrl[port] <= 0;
    @(vif.cb);

  endtask


  // SIMPLE FRAME GENERATOR
  task send_simple_frame(int src, int dst, int len);
    // generate frame with data 0,1,...,len-1
    frame f = new(src, dst);

    for (int i = 0; i < len; i++) begin
      f.data.push_back(i);
    end

    send_frame(src, f);

  endtask

endclass

// TX MONITOR
class tx_monitor #(parameter PORTS=4, DATA_W=8); // todo: IT IS FIXED ANYWAY, SO WE CAN PROBABLY REMOVE THESE PARAMETERS

  virtual switch_if vif;

  mailbox #(frame) act_q[PORTS]; // array of per-port mailboxes holding actual frame handles

  function new( // constructor for tx_monitor class
    virtual switch_if vif,
    mailbox #(frame) act_q[PORTS]
  );
    this.vif   = vif;
    this.act_q = act_q;
  endfunction


  task run(); // runs forever
    // local variables to hold incoming frame data
    frame pkt[PORTS]; 
    bit   active[PORTS];
    byte d;

    foreach (active[p]) begin // all ports start as inactive
      active[p] = 0;
    end

    forever begin
      @(vif.cb);

      for (int p = 0; p < PORTS; p++) begin

        if (vif.cb.tx_ctrl[p]) begin 
          // start of frame
          if (!active[p]) begin
            pkt[p] = new(-1, p); // -1 as src_port means unknown src_port
            active[p] = 1; // mark port as active
          end

          d = vif.cb.tx_data[p*8 +: 8]; // extract the byte for this port
          pkt[p].data.push_back(d);     // append byte to frame.data

        end else if (active[p]) begin
          // end of frame
          act_q[p].put(pkt[p]); // publish the complete frame to the monitor's mailbox
          active[p] = 0;
        end

      end
    end
  endtask
endclass

// SIMPLE SCOREBOARD
class scoreboard #(parameter PORTS=4); // todo: IT IS FIXED ANYWAY, SO WE CAN PROBABLY REMOVE THESE PARAMETER

    mailbox #(frame) exp_q[PORTS]; // expected frames from driver
    mailbox #(frame) act_q[PORTS]; // actual frames from monitor

    function new( // constructor for scoreboard class
      mailbox #(frame) exp_q[PORTS],
      mailbox #(frame) act_q[PORTS]
    );
      this.exp_q = exp_q;
      this.act_q = act_q;
    endfunction


    task run(); // runs forever
      // local variables to hold expected and actual frames for comparison
      frame exp_pkt, act_pkt;

      forever begin
        for (int p = 0; p < PORTS; p++) begin

          if (exp_q[p].num() > 0 && act_q[p].num() > 0) begin // check if data is available, else the next line will block

            exp_q[p].get(exp_pkt); // get expected frame from driver
            act_q[p].get(act_pkt); // get actual frame from monitor

            // compare length
            if (exp_pkt.data.size() != act_pkt.data.size()) begin // if exp. bytes != act. bytes
              $error("Port %0d: length mismatch exp=%0d act=%0d",p, exp_pkt.data.size(), act_pkt.data.size());
              continue; // throw error and skip data comparison
            end

            // compare data
            foreach (exp_pkt.data[i]) begin
              if (exp_pkt.data[i] != act_pkt.data[i]) begin
                $error("Port %0d: data mismatch at %0d exp=%0h act=%0h", p, i, exp_pkt.data[i], act_pkt.data[i]);
              end
            end
          end
        end
      end
    endtask
  endclass
endpackage
