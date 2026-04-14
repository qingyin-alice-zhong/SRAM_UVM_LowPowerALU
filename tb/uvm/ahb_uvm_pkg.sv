package ahb_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class ahb_seq_item extends uvm_sequence_item;
        rand bit        write;
        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit [2:0]  size;
        bit [31:0]      rdata;
        bit             sleep_state;

        constraint c_size { size inside {3'b000, 3'b001, 3'b010}; }
        constraint c_addr_range { addr inside {[32'h0:32'h7F]}; }

        `uvm_object_utils_begin(ahb_seq_item)
            `uvm_field_int(write, UVM_ALL_ON)
            `uvm_field_int(addr,  UVM_ALL_ON)
            `uvm_field_int(data,  UVM_ALL_ON)
            `uvm_field_int(size,  UVM_ALL_ON)
            `uvm_field_int(rdata, UVM_ALL_ON)
            `uvm_field_int(sleep_state, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "ahb_seq_item");
            super.new(name);
        endfunction
    endclass

    class ahb_sequencer extends uvm_sequencer #(ahb_seq_item);
        `uvm_component_utils(ahb_sequencer)
        function new(string name = "ahb_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class ahb_driver extends uvm_driver #(ahb_seq_item);
        `uvm_component_utils(ahb_driver)
        virtual ahb_if vif;

        function new(string name = "ahb_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "ahb_driver: virtual interface not found")
            end
        endfunction

        task reset_bus();
            vif.HSEL   <= 1'b0;
            vif.HADDR  <= '0;
            vif.HTRANS <= 2'b00;
            vif.HWRITE <= 1'b0;
            vif.HSIZE  <= 3'b010;
            vif.HBURST <= 3'b000;
            vif.HWDATA <= '0;
            vif.HREADY <= 1'b1;
            vif.sleep_i <= 1'b0;
        endtask

        task drive_one(ahb_seq_item tr);
            @(posedge vif.HCLK);
            vif.HSEL   <= 1'b1;
            vif.HTRANS <= 2'b10;
            vif.HWRITE <= tr.write;
            vif.HADDR  <= tr.addr;
            vif.HSIZE  <= tr.size;
            vif.HBURST <= 3'b000;

            @(posedge vif.HCLK);
            if (tr.write) begin
                vif.HWDATA <= tr.data;
            end

            @(posedge vif.HCLK);
            if (!tr.write) begin
                tr.rdata = vif.HRDATA;
            end

            vif.HSEL   <= 1'b0;
            vif.HTRANS <= 2'b00;
            vif.HWRITE <= 1'b0;
            vif.HADDR  <= '0;
            vif.HSIZE  <= 3'b010;
            vif.HBURST <= 3'b000;
            vif.HWDATA <= '0;
        endtask

        task run_phase(uvm_phase phase);
            ahb_seq_item tr;
            wait (vif.HRESETn === 1'b1);
            reset_bus();
            forever begin
                seq_item_port.get_next_item(tr);
                drive_one(tr);
                seq_item_port.item_done();
            end
        endtask
    endclass

    class ahb_monitor extends uvm_component;
        `uvm_component_utils(ahb_monitor)
        virtual ahb_if vif;
        uvm_analysis_port #(ahb_seq_item) ap;

        bit        prev_valid;
        bit        prev_write;
        bit [31:0] prev_addr;
        bit [2:0]  prev_size;
        bit        prev_sleep;

        function new(string name = "ahb_monitor", uvm_component parent = null);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "ahb_monitor: virtual interface not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            ahb_seq_item tr;
            prev_valid = 1'b0;
            wait (vif.HRESETn === 1'b1);

            forever begin
                @(posedge vif.HCLK);

                if (prev_valid) begin
                    tr = ahb_seq_item::type_id::create("tr", this);
                    tr.write = prev_write;
                    tr.addr  = prev_addr;
                    tr.size  = prev_size;
                    tr.sleep_state = prev_sleep;
                    if (prev_write) begin
                        tr.data = vif.HWDATA;
                    end else begin
                        tr.rdata = vif.HRDATA;
                    end
                    ap.write(tr);
                end

                prev_valid = vif.HSEL && vif.HREADY && vif.HTRANS[1];
                prev_write = vif.HWRITE;
                prev_addr  = vif.HADDR;
                prev_size  = vif.HSIZE;
                prev_sleep = vif.sleep_i;
            end
        endtask
    endclass

    class ahb_scoreboard extends uvm_component;
        `uvm_component_utils(ahb_scoreboard)

        uvm_analysis_imp #(ahb_seq_item, ahb_scoreboard) analysis_export;
        bit [31:0] model_mem [int unsigned];
        int unsigned pass_cnt;
        int unsigned fail_cnt;

        function new(string name = "ahb_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
        endfunction

        function automatic [31:0] apply_write_mask(
            input [31:0] old_word,
            input [31:0] write_word,
            input [2:0]  size,
            input [1:0]  addr_lsb
        );
            begin
                apply_write_mask = old_word;
                case (size)
                    3'b000: begin
                        case (addr_lsb)
                            2'b00: apply_write_mask[7:0]   = write_word[7:0];
                            2'b01: apply_write_mask[15:8]  = write_word[7:0];
                            2'b10: apply_write_mask[23:16] = write_word[7:0];
                            2'b11: apply_write_mask[31:24] = write_word[7:0];
                        endcase
                    end
                    3'b001: begin
                        if (addr_lsb[1] == 1'b0) begin
                            apply_write_mask[15:0] = write_word[15:0];
                        end else begin
                            apply_write_mask[31:16] = write_word[15:0];
                        end
                    end
                    3'b010: apply_write_mask = write_word;
                    default: ;
                endcase
            end
        endfunction

        function void write(ahb_seq_item tr);
            int unsigned word_idx;
            bit [31:0] old_word;
            bit [31:0] exp_word;

            word_idx = tr.addr[6:2];

            if (tr.sleep_state) begin
                if (tr.write) begin
                    pass_cnt++;
                    `uvm_info("SB_SLEEP_WR", $sformatf("WRITE ignored in sleep addr=0x%08h data=0x%08h", tr.addr, tr.data), UVM_LOW)
                end else begin
                    if (tr.rdata !== 32'h0) begin
                        fail_cnt++;
                        `uvm_error("SB_SLEEP_RD", $sformatf("READ in sleep must be 0 addr=0x%08h got=0x%08h", tr.addr, tr.rdata))
                    end else begin
                        pass_cnt++;
                        `uvm_info("SB_SLEEP_RD", $sformatf("READ in sleep returns 0 addr=0x%08h", tr.addr), UVM_LOW)
                    end
                end
                return;
            end

            if (tr.write) begin
                old_word = model_mem.exists(word_idx) ? model_mem[word_idx] : 32'h0;
                model_mem[word_idx] = apply_write_mask(old_word, tr.data, tr.size, tr.addr[1:0]);
            end else begin
                exp_word = model_mem.exists(word_idx) ? model_mem[word_idx] : 32'h0;
                if (tr.rdata !== exp_word) begin
                    fail_cnt++;
                    `uvm_error("SB_MISMATCH", $sformatf("READ MISMATCH addr=0x%08h exp=0x%08h got=0x%08h", tr.addr, exp_word, tr.rdata))
                end else begin
                    pass_cnt++;
                    `uvm_info("SB_PASS", $sformatf("READ PASS addr=0x%08h data=0x%08h", tr.addr, tr.rdata), UVM_LOW)
                end
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SB_SUMMARY", $sformatf("scoreboard pass=%0d fail=%0d", pass_cnt, fail_cnt), UVM_NONE)
            if (fail_cnt > 0) begin
                `uvm_error("SB_FAIL", "Scoreboard detected mismatches")
            end
        endfunction
    endclass

    class ahb_cov_collector extends uvm_subscriber #(ahb_seq_item);
        `uvm_component_utils(ahb_cov_collector)

        covergroup ahb_cg with function sample(ahb_seq_item tr);
            option.per_instance = 1;

            cp_sleep: coverpoint tr.sleep_state {
                bins awake = {0};
                bins sleep = {1};
            }

            cp_write: coverpoint tr.write {
                bins read  = {0};
                bins write = {1};
            }

            cp_size: coverpoint tr.size {
                bins byte = {3'b000};
                bins half = {3'b001};
                bins word = {3'b010};
            }

            cp_align: coverpoint tr.addr[1:0] {
                bins a0 = {2'b00};
                bins a1 = {2'b01};
                bins a2 = {2'b10};
                bins a3 = {2'b11};
            }

            cx_sleep_rw_size: cross cp_sleep, cp_write, cp_size;
            cx_sleep_rw_align: cross cp_sleep, cp_write, cp_align;
        endgroup

        function new(string name = "ahb_cov_collector", uvm_component parent = null);
            super.new(name, parent);
            ahb_cg = new();
        endfunction

        function void write(ahb_seq_item t);
            ahb_cg.sample(t);
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("COV_SUMMARY", $sformatf("ahb_cg coverage = %0.2f%%", ahb_cg.get_inst_coverage()), UVM_NONE)
        endfunction
    endclass

    class ahb_agent extends uvm_component;
        `uvm_component_utils(ahb_agent)
        ahb_sequencer sqr;
        ahb_driver    drv;
        ahb_monitor   mon;

        function new(string name = "ahb_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = ahb_sequencer::type_id::create("sqr", this);
            drv = ahb_driver::type_id::create("drv", this);
            mon = ahb_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class ahb_env extends uvm_env;
        `uvm_component_utils(ahb_env)
        ahb_agent      agent;
        ahb_scoreboard sb;
        ahb_cov_collector cov;

        function new(string name = "ahb_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = ahb_agent::type_id::create("agent", this);
            sb    = ahb_scoreboard::type_id::create("sb", this);
            cov   = ahb_cov_collector::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.ap.connect(sb.analysis_export);
            agent.mon.ap.connect(cov.analysis_export);
        endfunction
    endclass

    class ahb_one_tx_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(ahb_one_tx_sequence)
        bit        tx_write;
        bit [31:0] tx_addr;
        bit [31:0] tx_data;
        bit [2:0]  tx_size;

        function new(string name = "ahb_one_tx_sequence");
            super.new(name);
            tx_write = 1'b0;
            tx_addr  = 32'h0;
            tx_data  = 32'h0;
            tx_size  = 3'b010;
        endfunction

        task body();
            ahb_seq_item tr;
            tr = ahb_seq_item::type_id::create("tr");
            start_item(tr);
            tr.write = tx_write;
            tr.addr  = tx_addr;
            tr.data  = tx_data;
            tr.size  = tx_size;
            finish_item(tr);
        endtask
    endclass

    class ahb_base_test extends uvm_test;
        `uvm_component_utils(ahb_base_test)
        ahb_env env;

        function new(string name = "ahb_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ahb_env::type_id::create("env", this);
        endfunction

        task send_tx(bit is_write, bit [31:0] addr, bit [2:0] size, bit [31:0] data);
            ahb_one_tx_sequence seq;
            seq = ahb_one_tx_sequence::type_id::create("seq");
            seq.tx_write = is_write;
            seq.tx_addr  = addr;
            seq.tx_size  = size;
            seq.tx_data  = data;
            seq.start(env.agent.sqr);
        endtask

        task set_sleep(bit value, int cycles = 1);
            env.agent.drv.vif.sleep_i <= value;
            repeat (cycles) @(posedge env.agent.drv.vif.HCLK);
        endtask
    endclass

    class smoke_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(smoke_sequence)

        function new(string name = "smoke_sequence");
            super.new(name);
        endfunction

        task body();
            ahb_seq_item wr;
            ahb_seq_item rd;

            wr = ahb_seq_item::type_id::create("wr");
            start_item(wr);
            wr.write = 1'b1;
            wr.addr  = 32'h0000_0010;
            wr.size  = 3'b010;
            wr.data  = 32'hA5A5_5A5A;
            finish_item(wr);

            rd = ahb_seq_item::type_id::create("rd");
            start_item(rd);
            rd.write = 1'b0;
            rd.addr  = 32'h0000_0010;
            rd.size  = 3'b010;
            rd.data  = 32'h0;
            finish_item(rd);
        endtask
    endclass

    class smoke_test extends ahb_base_test;
        `uvm_component_utils(smoke_test)

        function new(string name = "smoke_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            smoke_sequence seq;
            phase.raise_objection(this);
            seq = smoke_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            repeat (5) @(posedge env.agent.drv.vif.HCLK);
            phase.drop_objection(this);
        endtask
    endclass

    class addr_sweep_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(addr_sweep_sequence)

        function new(string name = "addr_sweep_sequence");
            super.new(name);
        endfunction

        task body();
            ahb_seq_item tr;
            int unsigned idx;

            for (idx = 0; idx < 32; idx++) begin
                tr = ahb_seq_item::type_id::create($sformatf("wr_%0d", idx));
                start_item(tr);
                tr.write = 1'b1;
                tr.addr  = idx * 4;
                tr.size  = 3'b010;
                tr.data  = 32'h1000_0000 + idx;
                finish_item(tr);
            end

            for (idx = 0; idx < 32; idx++) begin
                tr = ahb_seq_item::type_id::create($sformatf("rd_%0d", idx));
                start_item(tr);
                tr.write = 1'b0;
                tr.addr  = idx * 4;
                tr.size  = 3'b010;
                tr.data  = 32'h0;
                finish_item(tr);
            end
        endtask
    endclass

    class subword_access_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(subword_access_sequence)

        function new(string name = "subword_access_sequence");
            super.new(name);
        endfunction

        task body();
            ahb_seq_item tr;

            tr = ahb_seq_item::type_id::create("wr_word_init");
            start_item(tr);
            tr.write = 1'b1;
            tr.addr  = 32'h0000_0020;
            tr.size  = 3'b010;
            tr.data  = 32'hDEAD_BEEF;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("wr_byte");
            start_item(tr);
            tr.write = 1'b1;
            tr.addr  = 32'h0000_0021;
            tr.size  = 3'b000;
            tr.data  = 32'h0000_00AA;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("rd_after_byte");
            start_item(tr);
            tr.write = 1'b0;
            tr.addr  = 32'h0000_0020;
            tr.size  = 3'b010;
            tr.data  = 32'h0;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("wr_half");
            start_item(tr);
            tr.write = 1'b1;
            tr.addr  = 32'h0000_0022;
            tr.size  = 3'b001;
            tr.data  = 32'h0000_1234;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("rd_after_half");
            start_item(tr);
            tr.write = 1'b0;
            tr.addr  = 32'h0000_0020;
            tr.size  = 3'b010;
            tr.data  = 32'h0;
            finish_item(tr);
        endtask
    endclass

    class unaligned_access_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(unaligned_access_sequence)

        function new(string name = "unaligned_access_sequence");
            super.new(name);
        endfunction

        task body();
            ahb_seq_item tr;

            tr = ahb_seq_item::type_id::create("wr_word_base");
            start_item(tr);
            tr.write = 1'b1;
            tr.addr  = 32'h0000_0030;
            tr.size  = 3'b010;
            tr.data  = 32'h0000_0000;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("wr_byte_unaligned");
            start_item(tr);
            tr.write = 1'b1;
            tr.addr  = 32'h0000_0033;
            tr.size  = 3'b000;
            tr.data  = 32'h0000_005A;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("wr_half_unaligned");
            start_item(tr);
            tr.write = 1'b1;
            tr.addr  = 32'h0000_0031;
            tr.size  = 3'b001;
            tr.data  = 32'h0000_C3C3;
            finish_item(tr);

            tr = ahb_seq_item::type_id::create("rd_check_unaligned");
            start_item(tr);
            tr.write = 1'b0;
            tr.addr  = 32'h0000_0030;
            tr.size  = 3'b010;
            tr.data  = 32'h0;
            finish_item(tr);
        endtask
    endclass

    class pipeline_burst_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(pipeline_burst_sequence)

        function new(string name = "pipeline_burst_sequence");
            super.new(name);
        endfunction

        task body();
            ahb_seq_item tr;
            int unsigned idx;

            for (idx = 0; idx < 16; idx++) begin
                tr = ahb_seq_item::type_id::create($sformatf("pipe_wr_%0d", idx));
                start_item(tr);
                tr.write = 1'b1;
                tr.addr  = 32'h0000_0040 + idx * 4;
                tr.size  = 3'b010;
                tr.data  = 32'hABCD_0000 + idx;
                finish_item(tr);
            end

            for (idx = 0; idx < 16; idx++) begin
                tr = ahb_seq_item::type_id::create($sformatf("pipe_rd_%0d", idx));
                start_item(tr);
                tr.write = 1'b0;
                tr.addr  = 32'h0000_0040 + idx * 4;
                tr.size  = 3'b010;
                tr.data  = 32'h0;
                finish_item(tr);
            end
        endtask
    endclass

    class random_regression_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(random_regression_sequence)
        rand int unsigned num_ops;

        constraint c_num_ops { num_ops inside {[80:120]}; }

        function new(string name = "random_regression_sequence");
            super.new(name);
            num_ops = 100;
        endfunction

        task body();
            ahb_seq_item tr;
            int unsigned idx;

            if (!randomize()) begin
                `uvm_warning("RAND_SEQ", "randomize failed, using default num_ops=100")
                num_ops = 100;
            end

            for (idx = 0; idx < num_ops; idx++) begin
                tr = ahb_seq_item::type_id::create($sformatf("rand_%0d", idx));
                start_item(tr);
                if (!tr.randomize() with {
                    addr inside {[32'h0:32'h7F]};
                    size inside {3'b000, 3'b001, 3'b010};
                    write dist {1 := 55, 0 := 45};
                }) begin
                    `uvm_error("RAND_ITEM", "Failed to randomize transaction")
                    tr.write = 1'b0;
                    tr.addr  = 32'h0;
                    tr.size  = 3'b010;
                    tr.data  = 32'h0;
                end
                finish_item(tr);
            end
        endtask
    endclass

    class reset_init_sequence extends uvm_sequence #(ahb_seq_item);
        `uvm_object_utils(reset_init_sequence)

        function new(string name = "reset_init_sequence");
            super.new(name);
        endfunction

        task body();
            ahb_seq_item tr;
            int unsigned idx;

            for (idx = 0; idx < 8; idx++) begin
                tr = ahb_seq_item::type_id::create($sformatf("reset_rd_%0d", idx));
                start_item(tr);
                tr.write = 1'b0;
                tr.addr  = idx * 4;
                tr.size  = 3'b010;
                tr.data  = 32'h0;
                finish_item(tr);
            end
        endtask
    endclass

    class addr_sweep_test extends ahb_base_test;
        `uvm_component_utils(addr_sweep_test)
        function new(string name = "addr_sweep_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            addr_sweep_sequence seq;
            phase.raise_objection(this);
            seq = addr_sweep_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    class subword_access_test extends ahb_base_test;
        `uvm_component_utils(subword_access_test)
        function new(string name = "subword_access_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            subword_access_sequence seq;
            phase.raise_objection(this);
            seq = subword_access_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    class unaligned_access_test extends ahb_base_test;
        `uvm_component_utils(unaligned_access_test)
        function new(string name = "unaligned_access_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            unaligned_access_sequence seq;
            phase.raise_objection(this);
            seq = unaligned_access_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    class pipeline_burst_test extends ahb_base_test;
        `uvm_component_utils(pipeline_burst_test)
        function new(string name = "pipeline_burst_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            pipeline_burst_sequence seq;
            phase.raise_objection(this);
            seq = pipeline_burst_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    class reset_init_test extends ahb_base_test;
        `uvm_component_utils(reset_init_test)
        function new(string name = "reset_init_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            reset_init_sequence seq;
            phase.raise_objection(this);
            seq = reset_init_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    class random_regression_test extends ahb_base_test;
        `uvm_component_utils(random_regression_test)
        function new(string name = "random_regression_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            random_regression_sequence seq;
            phase.raise_objection(this);
            seq = random_regression_sequence::type_id::create("seq");
            seq.start(env.agent.sqr);
            phase.drop_objection(this);
        endtask
    endclass

    class low_power_sleep_entry_test extends ahb_base_test;
        `uvm_component_utils(low_power_sleep_entry_test)
        function new(string name = "low_power_sleep_entry_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            send_tx(1'b1, 32'h0000_0014, 3'b010, 32'h1122_3344);
            set_sleep(1'b1, 2);
            send_tx(1'b0, 32'h0000_0014, 3'b010, 32'h0);
            set_sleep(1'b0, 1);
            send_tx(1'b0, 32'h0000_0014, 3'b010, 32'h0);
            phase.drop_objection(this);
        endtask
    endclass

    class low_power_sleep_blocks_write_test extends ahb_base_test;
        `uvm_component_utils(low_power_sleep_blocks_write_test)
        function new(string name = "low_power_sleep_blocks_write_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            send_tx(1'b1, 32'h0000_0028, 3'b010, 32'hAAAA_5555);
            set_sleep(1'b1, 1);
            send_tx(1'b1, 32'h0000_0028, 3'b010, 32'hDEAD_BEEF);
            set_sleep(1'b0, 1);
            send_tx(1'b0, 32'h0000_0028, 3'b010, 32'h0);
            phase.drop_objection(this);
        endtask
    endclass

    class low_power_sleep_pipeline_interrupt_test extends ahb_base_test;
        `uvm_component_utils(low_power_sleep_pipeline_interrupt_test)
        function new(string name = "low_power_sleep_pipeline_interrupt_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction
        task run_phase(uvm_phase phase);
            ahb_one_tx_sequence seq;
            phase.raise_objection(this);

            seq = ahb_one_tx_sequence::type_id::create("pipe_int_wr");
            seq.tx_write = 1'b1;
            seq.tx_addr  = 32'h0000_003C;
            seq.tx_size  = 3'b010;
            seq.tx_data  = 32'h1234_5678;

            fork
                begin
                    seq.start(env.agent.sqr);
                end
                begin
                    @(posedge env.agent.drv.vif.HCLK);
                    env.agent.drv.vif.sleep_i <= 1'b1;
                    repeat (2) @(posedge env.agent.drv.vif.HCLK);
                    env.agent.drv.vif.sleep_i <= 1'b0;
                end
            join

            send_tx(1'b0, 32'h0000_003C, 3'b010, 32'h0);
            phase.drop_objection(this);
        endtask
    endclass

endpackage
