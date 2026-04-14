module ahb_sva (
    ahb_if vif
);

    property p_no_x_on_valid;
        @(posedge vif.HCLK)
        disable iff (!vif.HRESETn)
        (vif.HSEL && vif.HREADY && vif.HTRANS[1]) |->
            (!$isunknown(vif.HADDR) && !$isunknown(vif.HWRITE) && !$isunknown(vif.HSIZE));
    endproperty

    property p_htrans_not_idle_when_selected;
        @(posedge vif.HCLK)
        disable iff (!vif.HRESETn)
        (vif.HSEL && vif.HREADY) |-> (vif.HTRANS != 2'b00);
    endproperty

    property p_reset_outputs_known;
        @(posedge vif.HCLK)
        (!vif.HRESETn) |-> (!$isunknown(vif.HRDATA) && !$isunknown(vif.HREADYOUT) && !$isunknown(vif.HRESP));
    endproperty

    a_no_x_on_valid: assert property (p_no_x_on_valid)
        else $error("AHB_SVA: Unknown detected on valid transfer control/address");

    a_htrans_not_idle_when_selected: assert property (p_htrans_not_idle_when_selected)
        else $error("AHB_SVA: HSEL active with IDLE transfer");

    a_reset_outputs_known: assert property (p_reset_outputs_known)
        else $error("AHB_SVA: Output has X/Z during reset");

endmodule
