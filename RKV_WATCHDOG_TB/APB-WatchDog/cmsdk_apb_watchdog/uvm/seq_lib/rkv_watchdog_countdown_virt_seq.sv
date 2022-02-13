`ifndef RKV_WATCHDOG_COUNTDOWN_VIRT_SEQ_SV
`define RKV_WATCHDOG_COUNTDOWN_VIRT_SEQ_SV

class rkv_watchdog_countdown_virt_seq extends rkv_watchdog_base_virtual_sequence;
  `uvm_object_utils(rkv_watchdog_countdown_virt_seq)

  function new (string name = "rkv_watchdog_countdown_virt_seq");
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
	end
	//#1us; 
   // rgm.WDOGLOAD.write(status, 'hFF);
	// repeat(10) begin
	  // rgm.WDOGCONTROL.INTEN.set(1'b1);
	  // rgm.WDOGCONTROL.update(status); //inside count?
	  // rgm.WDOGLOAD.read(status, rd_val);
	  // `uvm_info("REGREAD", $sformatf("WDOGLOAD READ value is %0x.", rd_val), UVM_LOW)
	  // rgm.WDOGVALUE.read(status, rd_val);
	  // `uvm_info("REGREAD", $sformatf("WDOGVALUE READ value is %0x.", rd_val), UVM_LOW)
	// end
    // #100us;
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

endclass

`endif 
