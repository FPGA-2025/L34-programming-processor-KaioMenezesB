module core_top #(
    parameter MEMORY_FILE = "",
    parameter MEMORY_SIZE = 4096
)(
    input  wire        clk,
    input  wire        rst_n
);

    wire        mem_rd;        // leitura pedida à memória
    wire        mem_wr;        // escrita pedida à memória
    wire [31:0] mem_addr;      // endereço para memória
    wire [31:0] mem_from_mem;  // dados vindos da memória (data_o)
    wire [31:0] mem_to_mem;    // dados enviados à memória (data_i)

    Memory #(
        .MEMORY_FILE(MEMORY_FILE),
        .MEMORY_SIZE(MEMORY_SIZE)
    ) mem (
        .clk(clk),
        .rd_en_i(mem_rd),
        .wr_en_i(mem_wr),
        .addr_i(mem_addr),
        .data_i(mem_to_mem),
        .data_o(mem_from_mem),
        .ack_o() 
    );

    Core #(
        .BOOT_ADDRESS(32'h00000000)
    ) core (
        .clk(clk),
        .rst_n(rst_n),
        .rd_en_o(mem_rd),
        .wr_en_i(mem_wr),
        .data_i(mem_from_mem),
        .addr_o(mem_addr),
        .data_o(mem_to_mem)
    );

endmodule