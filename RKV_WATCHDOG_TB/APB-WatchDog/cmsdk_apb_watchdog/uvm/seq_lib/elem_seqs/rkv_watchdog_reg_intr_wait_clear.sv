`ifndef RKV_WATCHDOG_REG_INTR_WAIT_CLEAR_SV
`define RKV_WATCHDOG_REG_INTR_WAIT_CLEAR_SV

class rkv_watchdog_reg_intr_wait_clear extends rkv_watchdog_base_element_sequence;
  rand bit intval; 
  rand bit delay;
  constraint cstr {
    soft intval inside {[10:100]};
	soft delay inside {[1:10]};
  }
  `uvm_object_utils(rkv_watchdog_reg_intr_wait_clear)

  function new (string name = "rkv_watchdog_reg_intr_wait_clear");
    super.new(name);
  endfunction

  task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
	// wait for interrupt status registers triggered
	forever begin
	  rgm.WDOGMIS.mirror(status); //can read do the same thing 
	  if(rgm.WDOGMIS.INT.get()) break;
	  repeat(intval) @(posedge vif.apb_clk);
	end
	repeat(delay) @(posedge vif.wdg_clk);
    rgm.WDOGINTCLR.write(status, 1'b1);
	//Note::Avoid this way in case multiple INTR clear operation
	//in a case due to RGM's update issue
	//rgm.WDOGINTCLR.INTCLR.set(1'b1);
	//rgm.WDOGINTCLR.update(status);
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask

endclass

`endif
