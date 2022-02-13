`ifndef RKV_WATCHDOG_INTEGRATION_VIRT_SEQ_SV
`define RKV_WATCHDOG_INTEGRATION_VIRT_SEQ_SV

class rkv_watchdog_integration_virt_seq extends rkv_watchdog_base_virtual_sequence;
  `uvm_object_utils(rkv_watchdog_integration_virt_seq)
  function new (string name = "rkv_watchdog_integration_virt_seq");
    super.new(name);
  endfunction

  task body();
    super.body();
    `uvm_info("body", "Entered...", UVM_LOW)
	//check WODGINT & WDOGRES reset value
	`uvm_info("Integration test", "check WODGINT & WDOGRES reset value", UVM_LOW)
	compare_data(vif.wdogint, 1'b0);
	compare_data(vif.wdogres, 1'b0);
	// enables integration test mode
	rgm.WDOGITCR.ITME.set(1'b1);
	rgm.WDOGITCR.update(status);
	
	// check WODGINT & WDOGRES value,which contriled by WDOGITCR
	`uvm_info("Integration test", "check WODGINT & WDOGRES value,which contriled by WDOGITCR", UVM_LOW)
	rgm.WDOGITOP.WDOGINT.set(1'b1);
	rgm.WDOGITOP.WDOGRES.set(1'b1);
	rgm.WDOGITOP.update(status);
	compare_data(vif.wdogint, 1'b1);
	compare_data(vif.wdogres, 1'b1);
	
	rgm.WDOGITOP.WDOGINT.set(1'b0);
	rgm.WDOGITOP.WDOGRES.set(1'b0);
	rgm.WDOGITOP.update(status);
	compare_data(vif.wdogint, 1'b0);
	compare_data(vif.wdogres, 1'b0);
	
	//check integration test exit
	`uvm_info("Integration test", "check integration test exit", UVM_LOW)
	rgm.WDOGITOP.WDOGINT.set(1'b1);
	rgm.WDOGITOP.WDOGRES.set(1'b1);
	rgm.WDOGITOP.update(status);
	compare_data(vif.wdogint, 1'b1);
	compare_data(vif.wdogres, 1'b1);
	
	rgm.WDOGITCR.ITME.set(1'b1);
	rgm.WDOGITCR.update(status);
	
    `uvm_info("body", "Exiting...", UVM_LOW)
  endtask
endclass

`endif 
