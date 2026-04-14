module ahb_sram_32x32 (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [2:0]  HSIZE,
    input  logic [2:0]  HBURST,
    input  logic [31:0] HWDATA,
    input  logic        HREADY,
    input  logic        sleep_i,
    output logic [31:0] HRDATA,
    output logic        HREADYOUT,
    output logic        HRESP
);

    logic [31:0] mem [0:31];
    logic        pending_valid;
    logic        pending_write;
    logic [2:0]  pending_size;
    logic [1:0]  pending_addr_lsb;
    logic [4:0]  pending_word_idx;
    integer i;

    function automatic [31:0] apply_write_mask(
        input [31:0] old_word,
        input [31:0] write_word,
        input [2:0]  size,
        input [1:0]  addr_lsb
    );
        begin
            apply_write_mask = old_word;
            unique case (size)
                3'b000: begin
                    unique case (addr_lsb)
                        2'b00: apply_write_mask[7:0]   = write_word[7:0];
                        2'b01: apply_write_mask[15:8]  = write_word[7:0];
                        2'b10: apply_write_mask[23:16] = write_word[7:0];
                        2'b11: apply_write_mask[31:24] = write_word[7:0];
                    endcase
                end
                3'b001: begin
                    if (addr_lsb[1] == 1'b0) begin
                        apply_write_mask[15:0]  = write_word[15:0];
                    end else begin
                        apply_write_mask[31:16] = write_word[15:0];
                    end
                end
                3'b010: apply_write_mask = write_word;
                default: apply_write_mask = old_word;
            endcase
        end
    endfunction

    wire addr_phase_valid = HSEL && HREADY && HTRANS[1];

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            for (i = 0; i < 32; i = i + 1) begin
                mem[i] <= 32'h0;
            end
            pending_valid    <= 1'b0;
            pending_write    <= 1'b0;
            pending_size     <= 3'b010;
            pending_addr_lsb <= 2'b00;
            pending_word_idx <= 5'b0;
            HRDATA           <= 32'h0;
            HREADYOUT        <= 1'b1;
            HRESP            <= 1'b0;
        end else begin
            HREADYOUT <= 1'b1;
            HRESP     <= 1'b0;

            if (pending_valid && !sleep_i) begin
                if (pending_write) begin
                    mem[pending_word_idx] <= apply_write_mask(
                        mem[pending_word_idx],
                        HWDATA,
                        pending_size,
                        pending_addr_lsb
                    );
                end else begin
                    HRDATA <= mem[pending_word_idx];
                end
            end

            pending_valid    <= addr_phase_valid;
            pending_write    <= HWRITE;
            pending_size     <= HSIZE;
            pending_addr_lsb <= HADDR[1:0];
            pending_word_idx <= HADDR[6:2];

            if (sleep_i) begin
                HRDATA <= 32'h0;
            end
        end
    end

endmodule
