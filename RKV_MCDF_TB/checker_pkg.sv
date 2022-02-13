`include "param_def.v"

package checker_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import fmt_pkg::*;
  import reg_pkg::*;
  import chnl_pkg::*;
  import arb_pkg::*;
  import mcdf_rgm_pkg::*;

  typedef struct packed {
    bit[2:0] len;
    bit[1:0] prio;
    bit en;
    bit[7:0] avail;
  } mcdf_reg_t;

  typedef enum {RW_LEN, RW_PRIO, RW_EN, RD_AVAIL} mcdf_field_t;

  // MCDF reference model
  class mcdf_refmod extends uvm_component;
    
    local virtual mcdf_intf intf;
    mcdf_reg_t regs[3];

    uvm_blocking_get_port #(reg_trans) reg_bg_port;
    uvm_blocking_get_peek_port #(mon_data_t) in_bgpk_ports[3];

    uvm_tlm_fifo #(fmt_trans) out_tlm_fifos[3];

    `uvm_component_utils(mcdf_refmod)

    function new (string name = "mcdf_refmod", uvm_component parent);
      super.new(name, parent);
      reg_bg_port = new("reg_bg_port", this);
      foreach(in_bgpk_ports[i]) in_bgpk_ports[i] = new($sformatf("in_bgpk_ports[%0d]", i), this);
      foreach(out_tlm_fifos[i]) out_tlm_fifos[i] = new($sformatf("out_tlm_fifos[%0d]", i), this);
    endfunction

    task run_phase(uvm_phase phase);
      fork
        do_reset();
        this.do_reg_update();
        do_packet(0);
        do_packet(1);
        do_packet(2);
      join
    endtask

    task do_reg_update();
      reg_trans t;
      forever begin
        this.reg_bg_port.get(t);
        if(t.addr[7:4] == 0 && t.cmd == `WRITE) begin
          this.regs[t.addr[3:2]].en = t.data[0];
          this.regs[t.addr[3:2]].prio = t.data[2:1];
          this.regs[t.addr[3:2]].len = t.data[5:3];
        end
        else if(t.addr[7:4] == 1 && t.cmd == `READ) begin
          this.regs[t.addr[3:2]].avail = t.data[7:0];
        end
      end
    endtask

    task do_packet(int id);
      fmt_trans ot;
      mon_data_t it;
      forever begin
        this.in_bgpk_ports[id].peek(it);
        ot = new();
        ot.length = 4 << (this.get_field_value(id, RW_LEN) & 'b11);
        ot.data = new[ot.length];
        ot.ch_id = id;
        foreach(ot.data[m]) begin
          this.in_bgpk_ports[id].get(it);
          ot.data[m] = it.data;
        end
        this.out_tlm_fifos[id].put(ot);
      end
    endtask

    function int get_field_value(int id, mcdf_field_t f);
      case(f)
        RW_LEN: return regs[id].len;
        RW_PRIO: return regs[id].prio;
        RW_EN: return regs[id].en;
        RD_AVAIL: return regs[id].avail;
      endcase
    endfunction 

    task do_reset();
      forever begin
        @(negedge intf.rstn); 
        foreach(regs[i]) begin
          regs[i].len = 'h0;
          regs[i].prio = 'h3;
          regs[i].en = 'h1;
          regs[i].avail = 'h20;
        end
      end
    endtask

    function void set_interface(virtual mcdf_intf intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction
  endclass: mcdf_refmod

  // MCDF checker (scoreboard)

  `uvm_blocking_put_imp_decl(_chnl0)
  `uvm_blocking_put_imp_decl(_chnl1)
  `uvm_blocking_put_imp_decl(_chnl2)
  `uvm_blocking_put_imp_decl(_fmt)
  `uvm_blocking_put_imp_decl(_reg)

  `uvm_blocking_get_peek_imp_decl(_chnl0)
  `uvm_blocking_get_peek_imp_decl(_chnl1)
  `uvm_blocking_get_peek_imp_decl(_chnl2)

  `uvm_blocking_get_imp_decl(_reg)

  class mcdf_checker extends uvm_scoreboard;
    local int err_count;
    local int total_count;
    local int chnl_count[3];
    local virtual chnl_intf chnl_vifs[3]; 
    local virtual arb_intf arb_vif; 
    local virtual mcdf_intf mcdf_vif;
    local mcdf_refmod refmod;

    uvm_blocking_put_imp_chnl0 #(mon_data_t, mcdf_checker)   chnl0_bp_imp;
    uvm_blocking_put_imp_chnl1 #(mon_data_t, mcdf_checker)   chnl1_bp_imp;
    uvm_blocking_put_imp_chnl2 #(mon_data_t, mcdf_checker)   chnl2_bp_imp;
    uvm_blocking_put_imp_fmt   #(fmt_trans , mcdf_checker)   fmt_bp_imp  ;
    uvm_blocking_put_imp_reg   #(reg_trans , mcdf_checker)   reg_bp_imp  ;

    uvm_blocking_get_peek_imp_chnl0 #(mon_data_t, mcdf_checker)  chnl0_bgpk_imp;
    uvm_blocking_get_peek_imp_chnl1 #(mon_data_t, mcdf_checker)  chnl1_bgpk_imp;
    uvm_blocking_get_peek_imp_chnl2 #(mon_data_t, mcdf_checker)  chnl2_bgpk_imp;

    uvm_blocking_get_imp_reg    #(reg_trans , mcdf_checker)  reg_bg_imp  ;

    mailbox #(mon_data_t) chnl_mbs[3];
    mailbox #(fmt_trans)  fmt_mb;
    mailbox #(reg_trans)  reg_mb;

    uvm_blocking_get_port #(fmt_trans) exp_bg_ports[3];

    `uvm_component_utils(mcdf_checker)

    function new (string name = "mcdf_checker", uvm_component parent);
      super.new(name, parent);
      this.err_count = 0;
      this.total_count = 0;
      foreach(this.chnl_count[i]) this.chnl_count[i] = 0;

      chnl0_bp_imp = new("chnl0_bp_imp", this);
      chnl1_bp_imp = new("chnl1_bp_imp", this);
      chnl2_bp_imp = new("chnl2_bp_imp", this);
      fmt_bp_imp   = new("fmt_bp_imp", this);  
      reg_bp_imp   = new("reg_bp_imp", this);  

      chnl0_bgpk_imp = new("chnl0_bgpk_imp", this);
      chnl1_bgpk_imp = new("chnl1_bgpk_imp", this);
      chnl2_bgpk_imp = new("chnl2_bgpk_imp", this);

      reg_bg_imp    = new("reg_bg_imp", this);  

      foreach(exp_bg_ports[i]) exp_bg_ports[i] = new($sformatf("exp_bg_ports[%0d]", i), this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      foreach(this.chnl_mbs[i]) this.chnl_mbs[i] = new();
      this.fmt_mb = new();
      this.reg_mb = new();
      this.refmod = mcdf_refmod::type_id::create("refmod", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      refmod.in_bgpk_ports[0].connect(chnl0_bgpk_imp);
      refmod.in_bgpk_ports[1].connect(chnl1_bgpk_imp);
      refmod.in_bgpk_ports[2].connect(chnl2_bgpk_imp);

      refmod.reg_bg_port.connect(reg_bg_imp);

      foreach(exp_bg_ports[i]) begin
        exp_bg_ports[i].connect(refmod.out_tlm_fifos[i].blocking_get_export);
      end
    endfunction

    function void set_interface(virtual mcdf_intf mcdf_vif, virtual chnl_intf chnl_vifs[3], virtual arb_intf arb_vif);
      if(mcdf_vif == null)
        $error("mcdf interface handle is NULL, please check if target interface has been intantiated");
      else begin
        this.mcdf_vif = mcdf_vif;
        this.refmod.set_interface(mcdf_vif);
      end
      if(chnl_vifs[0] == null || chnl_vifs[1] == null || chnl_vifs[2] == null)
        $error("chnl interface handle is NULL, please check if target interface has been intantiated");
      else begin
        this.chnl_vifs = chnl_vifs;
      end
      if(arb_vif == null)
        $error("arb interface handle is NULL, please check if target interface has been intantiated");
      else begin
        this.arb_vif = arb_vif;
      end
    endfunction

    task run_phase(uvm_phase phase);
      fork
        this.do_channel_disable_check(0);
        this.do_channel_disable_check(1);
        this.do_channel_disable_check(2);
        this.do_arbiter_priority_check();
        this.do_data_compare();
        this.refmod.run();
      join
    endtask

    task do_data_compare();
      fmt_trans expt, mont;
      bit cmp;
      forever begin
        this.fmt_mb.get(mont);
        this.exp_bg_ports[mont.ch_id].get(expt);
        cmp = mont.compare(expt);   
        this.total_count++;
        this.chnl_count[mont.ch_id]++;
        if(cmp == 0) begin
          this.err_count++;
          `uvm_error("[CMPERR]", $sformatf("%0dth times comparing but failed! MCDF monitored output packet is different with reference model output", this.total_count))
        end
        else begin
          `uvm_info("[CMPSUC]",$sformatf("%0dth times comparing and succeeded! MCDF monitored output packet is the same with reference model output", this.total_count), UVM_LOW)
        end
      end
    endtask

    task do_channel_disable_check(int id);
      forever begin
        @(posedge this.mcdf_vif.clk iff (this.mcdf_vif.rstn && this.mcdf_vif.mon_ck.chnl_en[id]===0));
        if(this.chnl_vifs[id].mon_ck.ch_valid===1 && this.chnl_vifs[id].mon_ck.ch_ready===1)
          `uvm_error("[CHKERR]", "ERROR! when channel disabled, ready signal raised when valid high") 
      end
    endtask

    task do_arbiter_priority_check();
      int id;
      forever begin
        @(posedge this.arb_vif.clk iff (this.arb_vif.rstn && this.arb_vif.mon_ck.f2a_id_req===1));
        id = this.get_slave_id_with_prio();
        if(id >= 0) begin
          @(posedge this.arb_vif.clk);
          if(this.arb_vif.mon_ck.a2s_acks[id] !== 1)
            `uvm_error("[CHKERR]", $sformatf("ERROR! arbiter received f2a_id_req===1 and channel[%0d] raising request with high priority, but is not granted by arbiter", id))
        end
      end
    endtask

    function int get_slave_id_with_prio();
      int id=-1;
      int prio=999;
      foreach(this.arb_vif.mon_ck.slv_prios[i]) begin
        if(this.arb_vif.mon_ck.slv_prios[i] < prio && this.arb_vif.mon_ck.slv_reqs[i]===1) begin
          id = i;
          prio = this.arb_vif.mon_ck.slv_prios[i];
        end
      end
      return id;
    endfunction

    function void report_phase(uvm_phase phase);
      string s;
      super.report_phase(phase);
      s = "\n---------------------------------------------------------------\n";
      s = {s, "CHECKER SUMMARY \n"}; 
      s = {s, $sformatf("total comparison count: %0d \n", this.total_count)}; 
      foreach(this.chnl_count[i]) s = {s, $sformatf(" channel[%0d] comparison count: %0d \n", i, this.chnl_count[i])};
      s = {s, $sformatf("total error count: %0d \n", this.err_count)}; 
      foreach(this.chnl_mbs[i]) begin
        if(this.chnl_mbs[i].num() != 0)
          s = {s, $sformatf("WARNING:: chnl_mbs[%0d] is not empty! size = %0d \n", i, this.chnl_mbs[i].num())}; 
      end
      if(this.fmt_mb.num() != 0)
          s = {s, $sformatf("WARNING:: fmt_mb is not empty! size = %0d \n", this.fmt_mb.num())}; 
      s = {s, "---------------------------------------------------------------\n"};
      `uvm_info(get_type_name(), s, UVM_LOW)
    endfunction

    task put_chnl0(mon_data_t t);
      chnl_mbs[0].put(t);
    endtask
    task put_chnl1(mon_data_t t);
      chnl_mbs[1].put(t);
    endtask
    task put_chnl2(mon_data_t t);
      chnl_mbs[2].put(t);
    endtask
    task put_fmt(fmt_trans t);
      fmt_mb.put(t);
    endtask
    task put_reg(reg_trans t);
      reg_mb.put(t);
    endtask
    task peek_chnl0(output mon_data_t t);
      chnl_mbs[0].peek(t);
    endtask
    task peek_chnl1(output mon_data_t t);
      chnl_mbs[1].peek(t);
    endtask
    task peek_chnl2(output mon_data_t t);
      chnl_mbs[2].peek(t);
    endtask
    task get_chnl0(output mon_data_t t);
      chnl_mbs[0].get(t);
    endtask
    task get_chnl1(output mon_data_t t);
      chnl_mbs[1].get(t);
    endtask
    task get_chnl2(output mon_data_t t);
      chnl_mbs[2].get(t);
    endtask
    task get_reg(output reg_trans t);
      reg_mb.get(t);
    endtask
  endclass: mcdf_checker

endpackage
