`ifndef RKV_WATCHDOG_DISABLE_INTR_VIRT_SEQ_SV
`define RKV_WATCHDOG_DISABLE_INTR_VIRT_SEQ_SV

class rkv_watchdog_disable_intr_virt_seq extends rkv_watchdog_base_virtual_sequence;
  `uvm_object_utils(rkv_watchdog_disable_intr_virt_seq)

  function new (string name = "rkv_watchdog_disable_intr_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    //Enable watchdog and its interrupt generation
	`uvm_do(reg_enable_intr)
	//load watchdog counter
	`uvm_do_with(reg_loadcount, {load_val == 'hFF;})
  //disable interrupt
  wait_intr_signal_assertted();
  check_intr_ris_mis(1'b1, 1'b1);
  repeat(20) @(posedge vif.wdg_clk);
  fork
    `uvm_do(reg_disable_intr); //diasble interrupt via reg
    wait_intr_signal_released(); //wait interrupt to be released
  join
  check_intr_ris_mis(1'b1, 1'b0);
  #1us; //idle time monitoring count
  `uvm_info("body", "Exiting...", UVM_LOW)
  //Enable interrupt again to check count reload and interrupt
  `uvm_do(reg_enable_intr)
  //check immediately interrupt is assertted and also the register value
  compare_data(vif.wdogint, 1'b1);
  check_intr_ris_mis(1'b1, 1'b1);
endtask

  //ris: raw interrupt status
  //mis: interrupt status
  task check_intr_ris_mis(input bit ris, input bit mis);
    rgm.WDOGRIS.mirror(status);
    compare_data(ris, rgm.WDOGRIS.RAWINT.get());
    rgm.WDOGMIS.mirror(status);
    compare_data(mis, rgm.WDOGMIS.INT.get());
  endtask


endclass

`endif 
