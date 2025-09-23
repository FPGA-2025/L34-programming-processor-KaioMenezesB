module Core #(
    parameter BOOT_ADDRESS = 32'h00000000
) (
    // Control signal
    input wire clk,
    // input wire halt,
    input wire rst_n,

    // Memory BUS
    // input  wire ack_i,
    output wire rd_en_o,
    output wire wr_en_i,
    // output wire [3:0]  byte_enable,
    input  wire [31:0] data_i,
    output wire [31:0] addr_o,
    output wire [31:0] data_o
);

    reg        rd_en_r;
    reg        wr_en_r;
    reg [31:0] addr_r;
    reg [31:0] data_r;

    reg [31:0] GPR [0:31];
    reg [31:0] PC_reg;
    reg [2:0]  cpu_phase;
    reg [31:0] inst_reg;

    reg [31:0] mem_addr_buf;
    reg [31:0] mem_write_buf;

    integer k;

    localparam PH_FETCH     = 3'd0;
    localparam PH_CAPTURE   = 3'd1;
    localparam PH_EXECUTE   = 3'd2;
    localparam PH_DO_STORE  = 3'd3;
    localparam PH_END_STORE = 3'd4;
    localparam PH_WAIT_LOAD = 3'd5;
    localparam PH_HALT      = 3'd6;

    wire [6:0]  opcode = inst_reg[6:0];
    wire [2:0]  funct3 = inst_reg[14:12];
    wire [6:0]  funct7 = inst_reg[31:25];
    wire [4:0]  rd     = inst_reg[11:7];
    wire [4:0]  rs1    = inst_reg[19:15];
    wire [4:0]  rs2    = inst_reg[24:20];

    wire [31:0] imm_i = {{20{inst_reg[31]}}, inst_reg[31:20]};
    wire [31:0] imm_u = {inst_reg[31:12], 12'b0};
    wire [31:0] imm_s = {{20{inst_reg[31]}}, inst_reg[31:25], inst_reg[11:7]};
    wire [31:0] imm_b = {{19{inst_reg[31]}}, inst_reg[31], inst_reg[7], inst_reg[30:25], inst_reg[11:8], 1'b0};
    wire [31:0] imm_j = {{11{inst_reg[31]}}, inst_reg[31], inst_reg[19:12], inst_reg[20], inst_reg[30:21], 1'b0};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC_reg    <= BOOT_ADDRESS;
            cpu_phase <= PH_FETCH;

            rd_en_r <= 1'b0;
            wr_en_r <= 1'b0;
            addr_r  <= 32'd0;
            data_r  <= 32'd0;

            for (k = 0; k < 32; k = k + 1) begin
                GPR[k] <= 32'd0;
            end

            mem_addr_buf  <= 32'd0;
            mem_write_buf <= 32'd0;
        end else begin
            GPR[0] <= 32'd0;
            case (cpu_phase)
                PH_FETCH: begin
                    addr_r  <= PC_reg;
                    rd_en_r <= 1'b1;
                    wr_en_r <= 1'b0;
                    data_r  <= 32'd0;
                    cpu_phase <= PH_CAPTURE;
                end

                PH_CAPTURE: begin
                    rd_en_r <= 1'b0;
                    inst_reg <= data_i;
                    PC_reg <= PC_reg + 4;
                    cpu_phase <= PH_EXECUTE;
                end

                PH_EXECUTE: begin
                    rd_en_r <= 1'b0;
                    wr_en_r <= 1'b0;
                    addr_r  <= 32'd0;
                    data_r  <= 32'd0;

                    case (opcode)
                        7'b0010011: begin
                            if (funct3 == 3'b000) begin
                                GPR[rd] <= GPR[rs1] + imm_i;
                            end else if (funct3 == 3'b101) begin
                                GPR[rd] <= GPR[rs1] >> inst_reg[24:20];
                            end
                            cpu_phase <= PH_FETCH;
                        end

                        7'b0110011: begin
                            if (funct3 == 3'b000) begin
                                GPR[rd] <= GPR[rs1] + GPR[rs2];
                            end else if (funct3 == 3'b100) begin
                                GPR[rd] <= GPR[rs1] ^ GPR[rs2];
                            end
                            cpu_phase <= PH_FETCH;
                        end

                        7'b0100011: begin
                            mem_addr_buf  <= GPR[rs1] + imm_s;
                            mem_write_buf <= GPR[rs2];
                            cpu_phase <= PH_DO_STORE;
                        end

                        7'b0000011: begin
                            addr_r  <= GPR[rs1] + imm_i;
                            rd_en_r <= 1'b1;
                            cpu_phase <= PH_WAIT_LOAD;
                        end

                        7'b0110111: begin
                            GPR[rd] <= imm_u;
                            cpu_phase <= PH_FETCH;
                        end

                        7'b0010111: begin
                            GPR[rd] <= (PC_reg - 4) + imm_u;
                            cpu_phase <= PH_FETCH;
                        end

                        7'b1101111: begin
                            GPR[rd] <= PC_reg;
                            PC_reg <= (PC_reg - 4) + imm_j;
                            cpu_phase <= PH_FETCH;
                        end
                        
                        7'b1100111: begin
                            GPR[rd] <= PC_reg;
                            PC_reg <= (GPR[rs1] + imm_i) & ~32'd1;
                            cpu_phase <= PH_FETCH;
                        end

                        7'b1100011: begin
                            if (GPR[rs1] == GPR[rs2]) begin
                                PC_reg <= (PC_reg - 4) + imm_b;
                            end
                            cpu_phase <= PH_FETCH;
                        end

                        default: begin
                            cpu_phase <= PH_FETCH;
                        end
                    endcase
                end

                PH_DO_STORE: begin
                    addr_r  <= mem_addr_buf;
                    data_r  <= mem_write_buf;
                    wr_en_r <= 1'b1;
                    cpu_phase <= PH_END_STORE;
                end

                PH_END_STORE: begin
                    wr_en_r <= 1'b0;
                    cpu_phase <= PH_FETCH;
                end

                PH_WAIT_LOAD: begin
                    rd_en_r <= 1'b0;
                    GPR[rd] <= data_i;
                    cpu_phase <= PH_FETCH;
                end
                
                PH_HALT: begin
                    // parada — sem ação
                    cpu_phase <= PH_HALT;
                end

                default: cpu_phase <= PH_FETCH;
            endcase
        end
    end

    assign rd_en_o = rd_en_r;
    assign wr_en_i = wr_en_r;
    assign addr_o   = addr_r;
    assign data_o   = data_r;

endmodule