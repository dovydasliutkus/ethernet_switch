package voq_buffer_pkg;

    class voq_buffer_class #(parameter DATA_W = 8, PORTS = 4);

        virtual voq_buffer_if #(DATA_W, PORTS) vif;

        function new(virtual voq_buffer_if #(DATA_W, PORTS) vif);
            this.vif = vif;
        endfunction


        //////////////// Reset sequence ////////////////
        task reset_sequence();
            vif.rst = 0; // assert reset

            vif.data = '0;
            vif.write_enable = '0;
            vif.read_enable  = '0;

            repeat (3) @(vif.cb);

            vif.rst = 1; // release reset

            repeat (2) @(vif.cb);
        endtask
        
        //////////////// Write task //////////////////
        task automatic write(input int i, input int j, input byte data);
            vif.data = '0;
            vif.data[i*DATA_W +: DATA_W] = data;
            vif.write_enable = 1 << (i*PORTS+j);

            @(vif.cb);

            vif.write_enable = 0;
        endtask

        //////////////// Read task ///////////////////
        task automatic read( input int i, input int j);
            vif.read_enable = 1 << (i*PORTS+j);

            @(vif.cb);

            vif.read_enable = 0;
        endtask

    endclass
endpackage