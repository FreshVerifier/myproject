`ifndef RKV_WATCHDOG_RELOAD_VIRT_SEQ_SV
`define RKV_WATCHDOG_RELOAD_VIRT_SEQ_SV

class rkv_watchdog_reload_virt_seq extends rkv_watchdog_base_virtual_sequence;
  `uvm_object_utils(rkv_watchdog_reload_virt_seq)

  function new (string name = "rkv_watchdog_reload_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
    //Enable watchdog and its interrupt generation
	`uvm_do(reg_enable_intr)
	//load watchdog counter
	`uvm_do_with(reg_loadcount, {load_val == 'hFF;})
	//wait interrupt and clear,what will happened if donot clear?
	repeat(2) begin
	  fork
	    `uvm_do_with(reg_intr_wait_clear, {intval == 50; delay inside {[30: 40]};})
        wait_intr_signal_released();
	  join
	  `uvm_do_with(reg_loadcount, {load_val inside {['hA0:'hFF]};})
	end

    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

endclass

`endif
