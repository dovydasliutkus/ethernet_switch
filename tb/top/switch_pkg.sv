package switch_pkg;

  class frame;

      int src_port;
      int dst_port;

      byte data[$];
      int  len;

      function new(int src_port, int dst_port);
          this.src_port = src_port;
          this.dst_port = dst_port;
      endfunction

  endclass

  class tx_monitor #(parameter PORTS=4, DATA_W=8);

    virtual switch_if #(PORTS,DATA_W) vif;

    mailbox #(frame) act_q[PORTS];

    function new(virtual switch_if vif,
                 mailbox #(frame) act_q[PORTS]);
        this.vif   = vif;
        this.act_q = act_q;
    endfunction

  endclass

endpackage