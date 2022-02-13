`include "param_def.v"

package mcdf_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import chnl_pkg::*;
  import reg_pkg::*;
  import arb_pkg::*;
  import fmt_pkg::*;
  import checker_pkg::*;
  import coverage_pkg::*;
  import mcdf_rgm_pkg::*;

  class mcdf_virtual_sequencer extends uvm_sequencer;
    reg_sequencer reg_sqr;
    fmt_sequencer fmt_sqr;
    chnl_sequencer chnl_sqrs[3];
    mcdf_rgm rgm;
    virtual mcdf_intf intf;
    `uvm_component_utils(mcdf_virtual_sequencer)
    function new (string name = "mcdf_virtual_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction
    function void set_interface(virtual mcdf_intf intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction
  endclass

  // MCDF top environment
  class mcdf_env extends uvm_env;
    chnl_agent chnl_agts[3];
    reg_agent reg_agt;
    fmt_agent fmt_agt;
    mcdf_checker chker;
    mcdf_coverage cvrg;
    mcdf_virtual_sequencer virt_sqr;
    //TODO-1.2 declare the mcdf_rgm handle, reg2mcdf_adapter handle and the
    //predictory handle
    mcdf_rgm rgm;
    reg2mcdf_adapter adapter;
    uvm_reg_predictor #(reg_trans) predictor;

    `uvm_component_utils(mcdf_env)

    function new (string name = "mcdf_env", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      this.chker = mcdf_checker::type_id::create("chker", this);
      foreach(chnl_agts[i]) begin
        this.chnl_agts[i] = chnl_agent::type_id::create($sformatf("chnl_agts[%0d]",i), this);
      end
      this.reg_agt = reg_agent::type_id::create("reg_agt", this);
      this.fmt_agt = fmt_agent::type_id::create("fmt_agt", this);
      this.cvrg = mcdf_coverage::type_id::create("cvrg", this);
      virt_sqr = mcdf_virtual_sequencer::type_id::create("virt_sqr", this);
      //TODO-1.2 instantiate those objects
      //  -mcdf_rgm object
      //  -reg2mcdf_adapter object
      //  -predictory object
      //and finish necessary configuration 
      rgm = mcdf_rgm::type_id::create("rgm", this);
      rgm.build();
      adapter = reg2mcdf_adapter::type_id::create("adapter", this);
      predictor = uvm_reg_predictor#(reg_trans)::type_id::create("predictor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      chnl_agts[0].monitor.mon_bp_port.connect(chker.chnl0_bp_imp);
      chnl_agts[1].monitor.mon_bp_port.connect(chker.chnl1_bp_imp);
      chnl_agts[2].monitor.mon_bp_port.connect(chker.chnl2_bp_imp);
      reg_agt.monitor.mon_bp_port.connect(chker.reg_bp_imp);
      fmt_agt.monitor.mon_bp_port.connect(chker.fmt_bp_imp);
      virt_sqr.reg_sqr = reg_agt.sequencer;
      virt_sqr.fmt_sqr = fmt_agt.sequencer;
      foreach(virt_sqr.chnl_sqrs[i]) virt_sqr.chnl_sqrs[i] = chnl_agts[i].sequencer;
      //TODO-1.2 Link the register model with the adapter and the predictor
      rgm.map.set_sequencer(reg_agt.sequencer, adapter);
      reg_agt.monitor.mon_ana_port.connect(predictor.bus_in);
      predictor.map = rgm.map;
      predictor.adapter = adapter;
      //TODO-2.1 connect the virtual sequencer's rgm handle with rgm object
      virt_sqr.rgm = rgm;
    endfunction
  endclass: mcdf_env

  class mcdf_base_virtual_sequence extends uvm_sequence;
    idle_reg_sequence idle_reg_seq;
    write_reg_sequence write_reg_seq;
    read_reg_sequence read_reg_seq;
    chnl_data_sequence chnl_data_seq;
    fmt_config_sequence fmt_config_seq;
    mcdf_rgm rgm;

    `uvm_object_utils(mcdf_base_virtual_sequence)
    `uvm_declare_p_sequencer(mcdf_virtual_sequencer)

    function new (string name = "mcdf_base_virtual_sequence");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), "=====================STARTED=====================", UVM_LOW)
      //TODO-2.1 connect rgm handle
      rgm = p_sequencer.rgm;
      @(posedge p_sequencer.intf.rstn);
      repeat(10) @(posedge p_sequencer.intf.clk);
      rgm.reset();

      this.do_reg();
      this.do_formatter();
      this.do_data();

      `uvm_info(get_type_name(), "=====================FINISHED=====================", UVM_LOW)
    endtask

    // do register configuration
    virtual task do_reg();
      //User to implment the task in the child virtual sequence
    endtask

    // do external formatter down stream slave configuration
    virtual task do_formatter();
      //User to implment the task in the child virtual sequence
    endtask

    // do data transition from 3 channel slaves
    virtual task do_data();
      //User to implment the task in the child virtual sequence
    endtask

    virtual function bit diff_value(int val1, int val2, string id = "value_compare");
      if(val1 != val2) begin
        `uvm_error("[CMPERR]", $sformatf("ERROR! %s val1 %8x != val2 %8x", id, val1, val2)) 
        return 0;
      end
      else begin
        `uvm_info("[CMPSUC]", $sformatf("SUCCESS! %s val1 %8x == val2 %8x", id, val1, val2), UVM_LOW)
        return 1;
      end
    endfunction
  endclass

  class mcdf_reg_op_record_cb extends uvm_reg_cbs;
    `uvm_object_utils(mcdf_reg_op_record_cb)
    function new(string name = "mcdf_reg_op_record_cb");
       super.new(name);
    endfunction

    virtual task post_write(uvm_reg_item rw); 
      `uvm_info("REGCB", $sformatf("post_write REG %s, OP %s, DATA 'h%x", 
                                    rw.element.get_name(), rw.kind, rw.value[0]),UVM_LOW)
    endtask

    virtual task post_read(uvm_reg_item rw); 
      `uvm_info("REGCB", $sformatf("post_read REG %s, OP %s, DATA 'h%x",
                                    rw.element.get_name(), rw.kind, rw.value[0]),UVM_LOW)
    endtask

  endclass

  // MCDF base test
  class mcdf_base_test extends uvm_test;
    mcdf_env env;
    mcdf_reg_op_record_cb reg_cb;
    virtual chnl_intf ch0_vif ;
    virtual chnl_intf ch1_vif ;
    virtual chnl_intf ch2_vif ;
    virtual reg_intf reg_vif  ;
    virtual arb_intf arb_vif  ;
    virtual fmt_intf fmt_vif  ;
    virtual mcdf_intf mcdf_vif;

    `uvm_component_utils(mcdf_base_test)

    function new(string name = "mcdf_base_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      reg_cb = mcdf_reg_op_record_cb::type_id::create("reg_cb");

      // get virtual interface from top TB
      if(!uvm_config_db#(virtual chnl_intf)::get(this,"","ch0_vif", ch0_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      if(!uvm_config_db#(virtual chnl_intf)::get(this,"","ch1_vif", ch1_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      if(!uvm_config_db#(virtual chnl_intf)::get(this,"","ch2_vif", ch2_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      if(!uvm_config_db#(virtual reg_intf)::get(this,"","reg_vif", reg_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      if(!uvm_config_db#(virtual arb_intf)::get(this,"","arb_vif", arb_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      if(!uvm_config_db#(virtual fmt_intf)::get(this,"","fmt_vif", fmt_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end
      if(!uvm_config_db#(virtual mcdf_intf)::get(this,"","mcdf_vif", mcdf_vif)) begin
        `uvm_fatal("GETVIF","cannot get vif handle from config DB")
      end

      this.env = mcdf_env::type_id::create("env", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      // After get virtual interface from config_db, and then set them to
      // child components
      this.set_interface(ch0_vif, ch1_vif, ch2_vif, reg_vif, arb_vif, fmt_vif, mcdf_vif);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_callbacks#(uvm_reg)::add(env.rgm.chnl0_ctrl_reg, reg_cb);
      uvm_callbacks#(uvm_reg)::add(env.rgm.chnl1_ctrl_reg, reg_cb);
      uvm_callbacks#(uvm_reg)::add(env.rgm.chnl2_ctrl_reg, reg_cb);
      uvm_callbacks#(uvm_reg)::add(env.rgm.chnl0_stat_reg, reg_cb);
      uvm_callbacks#(uvm_reg)::add(env.rgm.chnl1_stat_reg, reg_cb);
      uvm_callbacks#(uvm_reg)::add(env.rgm.chnl2_stat_reg, reg_cb);
      uvm_root::get().set_report_verbosity_level_hier(UVM_HIGH);
      uvm_root::get().set_report_max_quit_count(1);
      uvm_root::get().set_timeout(10ms);
    endfunction

    task run_phase(uvm_phase phase);
      // NOTE:: raise objection to prevent simulation stopping
      phase.raise_objection(this);

      this.run_top_virtual_sequence();

      // NOTE:: drop objection to request simulation stopping
      phase.drop_objection(this);
    endtask

    virtual task run_top_virtual_sequence();
      // User to implement this task in the child tests
    endtask

    virtual function void set_interface(virtual chnl_intf ch0_vif 
                                        ,virtual chnl_intf ch1_vif 
                                        ,virtual chnl_intf ch2_vif 
                                        ,virtual reg_intf reg_vif
                                        ,virtual arb_intf arb_vif
                                        ,virtual fmt_intf fmt_vif
                                        ,virtual mcdf_intf mcdf_vif
                                      );
      this.env.chnl_agts[0].set_interface(ch0_vif);
      this.env.chnl_agts[1].set_interface(ch1_vif);
      this.env.chnl_agts[2].set_interface(ch2_vif);
      this.env.reg_agt.set_interface(reg_vif);
      this.env.fmt_agt.set_interface(fmt_vif);
      this.env.chker.set_interface(mcdf_vif, '{ch0_vif, ch1_vif, ch2_vif}, arb_vif);
      this.env.cvrg.set_interface('{ch0_vif, ch1_vif, ch2_vif}, reg_vif, arb_vif, fmt_vif, mcdf_vif);
      this.env.virt_sqr.set_interface(mcdf_vif);
    endfunction
  endclass: mcdf_base_test

  //TODO-2.2 replace the register bus sequence with uvm_reg::write()/read()
  class mcdf_data_consistence_basic_virtual_sequence extends mcdf_base_virtual_sequence;
    `uvm_object_utils(mcdf_data_consistence_basic_virtual_sequence)
    function new (string name = "mcdf_data_consistence_basic_virtual_sequence");
      super.new(name);
    endfunction
    task do_reg();
      bit[31:0] wr_val, rd_val;
      uvm_status_e status;
      // slv0 with len=8,  prio=0, en=1
      wr_val = (1<<3)+(0<<1)+1;
      rgm.chnl0_ctrl_reg.write(status, wr_val);
      rgm.chnl0_ctrl_reg.read(status, rd_val);
      void'(this.diff_value(wr_val, rd_val, "SLV0_WR_REG"));

      rgm.chnl0_ctrl_reg.pkt_len.set(1);
      rgm.chnl0_ctrl_reg.prio_level.set(0);
      rgm.chnl0_ctrl_reg.chnl_en.set(1);
      rgm.chnl0_ctrl_reg.update(status);

      // slv1 with len=16, prio=1, en=1
      wr_val = (2<<3)+(1<<1)+1;
      rgm.chnl1_ctrl_reg.write(status, wr_val);
      rgm.chnl1_ctrl_reg.read(status, rd_val);
      void'(this.diff_value(wr_val, rd_val, "SLV1_WR_REG"));

      // slv2 with len=32, prio=2, en=1
      wr_val = (3<<3)+(2<<1)+1;
      rgm.chnl2_ctrl_reg.write(status, wr_val);
      rgm.chnl2_ctrl_reg.read(status, rd_val);
      void'(this.diff_value(wr_val, rd_val, "SLV2_WR_REG"));

      // send IDLE command
      `uvm_do_on(idle_reg_seq, p_sequencer.reg_sqr)
    endtask
    task do_formatter();
      `uvm_do_on_with(fmt_config_seq, p_sequencer.fmt_sqr, {fifo == LONG_FIFO; bandwidth == HIGH_WIDTH;})
    endtask
    task do_data();
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0], {ntrans==100; ch_id==0; data_nidles==0; pkt_nidles==1; data_size==8; })
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1], {ntrans==100; ch_id==1; data_nidles==1; pkt_nidles==4; data_size==16;})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2], {ntrans==100; ch_id==2; data_nidles==2; pkt_nidles==8; data_size==32;})
      join
      #10us; // wait until all data haven been transfered through MCDF
    endtask
  endclass: mcdf_data_consistence_basic_virtual_sequence

  class mcdf_data_consistence_basic_test extends mcdf_base_test;

    `uvm_component_utils(mcdf_data_consistence_basic_test)

    function new(string name = "mcdf_data_consistence_basic_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdf_data_consistence_basic_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdf_data_consistence_basic_test

  //TODO-2.3 Follow the instructions below
  //  -reset the register block
  //  -set all value of WR registers via uvm_reg::set()
  //  -update them via uvm_reg_block::update()
  //  -compare the register value via uvm_reg::mirror() with backdoor access
  class mcdf_full_random_virtual_sequence extends mcdf_base_virtual_sequence;
    `uvm_object_utils(mcdf_base_virtual_sequence)
    function new (string name = "mcdf_base_virtual_sequence");
      super.new(name);
    endfunction

    task do_reg();
      bit[31:0] ch0_wr_val;
      bit[31:0] ch1_wr_val;
      bit[31:0] ch2_wr_val;
      uvm_status_e status;

      //reset the register block
      rgm.reset();

      //slv0 with len={4,8,16,32},  prio={[0:3]}, en={[0:1]}
      ch0_wr_val = ($urandom_range(0,3)<<3)+($urandom_range(0,3)<<1)+$urandom_range(0,1);
      ch1_wr_val = ($urandom_range(0,3)<<3)+($urandom_range(0,3)<<1)+$urandom_range(0,1);
      ch2_wr_val = ($urandom_range(0,3)<<3)+($urandom_range(0,3)<<1)+$urandom_range(0,1);

      //set all value of WR registers via uvm_reg::set() 
      rgm.chnl0_ctrl_reg.set(ch0_wr_val);
      rgm.chnl1_ctrl_reg.set(ch1_wr_val);
      rgm.chnl2_ctrl_reg.set(ch2_wr_val);

      //update them via uvm_reg_block::update()
      rgm.update(status);

      //wait until the registers in DUT have been updated
      #100ns;

      //compare all of write value and read value
      rgm.chnl0_ctrl_reg.mirror(status, UVM_CHECK, UVM_BACKDOOR);
      rgm.chnl1_ctrl_reg.mirror(status, UVM_CHECK, UVM_BACKDOOR);
      rgm.chnl2_ctrl_reg.mirror(status, UVM_CHECK, UVM_BACKDOOR);

      // send IDLE command
      `uvm_do_on(idle_reg_seq, p_sequencer.reg_sqr)
    endtask
    task do_formatter();
      `uvm_do_on_with(fmt_config_seq, p_sequencer.fmt_sqr, {fifo inside {SHORT_FIFO, ULTRA_FIFO}; bandwidth inside {LOW_WIDTH, ULTRA_WIDTH};})
    endtask
    task do_data();
      fork
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[0], 
          {ntrans inside {[400:600]}; ch_id==0; data_nidles inside {[0:3]}; pkt_nidles inside {1,2,4,8}; data_size inside {8,16,32};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[1], 
          {ntrans inside {[400:600]}; ch_id==0; data_nidles inside {[0:3]}; pkt_nidles inside {1,2,4,8}; data_size inside {8,16,32};})
        `uvm_do_on_with(chnl_data_seq, p_sequencer.chnl_sqrs[2], 
          {ntrans inside {[400:600]}; ch_id==0; data_nidles inside {[0:3]}; pkt_nidles inside {1,2,4,8}; data_size inside {8,16,32};})
      join
      #10us; // wait until all data haven been transfered through MCDF
    endtask
  endclass: mcdf_full_random_virtual_sequence

  class mcdf_full_random_test extends mcdf_base_test;

    `uvm_component_utils(mcdf_full_random_test)

    function new(string name = "mcdf_full_random_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdf_full_random_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdf_full_random_test


  //TODO-3.1 Use build-in uvm register sequence
  //  -uvm_reg_hw_reset_seq
  //  -uvm_reg_bit_bash_seq
  //  -uvm_reg_access_seq
  class mcdf_reg_builtin_virtual_sequence extends mcdf_base_virtual_sequence;
    `uvm_object_utils(mcdf_reg_builtin_virtual_sequence)
    function new (string name = "mcdf_reg_builtin_virtual_sequence");
      super.new(name);
    endfunction

    task do_reg();
      uvm_reg_hw_reset_seq reg_rst_seq = new(); 
      uvm_reg_bit_bash_seq reg_bit_bash_seq = new();
      uvm_reg_access_seq reg_acc_seq = new();

      // wait reset asserted and release
      @(negedge p_sequencer.intf.rstn);
      @(posedge p_sequencer.intf.rstn);

      `uvm_info("BLTINSEQ", "register reset sequence started", UVM_LOW)
      rgm.reset();
      reg_rst_seq.model = rgm;
      reg_rst_seq.start(p_sequencer.reg_sqr);
      `uvm_info("BLTINSEQ", "register reset sequence finished", UVM_LOW)

      `uvm_info("BLTINSEQ", "register bit bash sequence started", UVM_LOW)
      // reset hardware register and register model
      p_sequencer.intf.rstn <= 'b0;
      repeat(5) @(posedge p_sequencer.intf.clk);
      p_sequencer.intf.rstn <= 'b1;
      rgm.reset();
      reg_bit_bash_seq.model = rgm;
      reg_bit_bash_seq.start(p_sequencer.reg_sqr);
      `uvm_info("BLTINSEQ", "register bit bash sequence finished", UVM_LOW)

      `uvm_info("BLTINSEQ", "register access sequence started", UVM_LOW)
      // reset hardware register and register model
      p_sequencer.intf.rstn <= 'b0;
      repeat(5) @(posedge p_sequencer.intf.clk);
      p_sequencer.intf.rstn <= 'b1;
      rgm.reset();
      reg_acc_seq.model = rgm;
      reg_acc_seq.start(p_sequencer.reg_sqr);
      `uvm_info("BLTINSEQ", "register access sequence finished", UVM_LOW)
    endtask
  endclass: mcdf_reg_builtin_virtual_sequence

  class mcdf_reg_builtin_test extends mcdf_base_test;

    `uvm_component_utils(mcdf_reg_builtin_test)

    function new(string name = "mcdf_reg_builtin_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      mcdf_reg_builtin_virtual_sequence top_seq = new();
      top_seq.start(env.virt_sqr);
    endtask
  endclass: mcdf_reg_builtin_test

endpackage
