 module axi_mem_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter ID_WIDTH   = 4,
    parameter MEM_DEPTH  = 256
)(
    input wire                        ACLK,
    input wire                        ARESETN,

    // Write Address Channel
    input  wire [ID_WIDTH-1:0]        AWID,
    input  wire [ADDR_WIDTH-1:0]      AWADDR,
    input  wire [7:0]                 AWLEN,
    input  wire [2:0]                 AWSIZE,
    input  wire [1:0]                 AWBURST,
    input  wire                       AWVALID,
    output wire                       AWREADY,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]      WDATA,
    input  wire [(DATA_WIDTH/8)-1:0]  WSTRB,
    input  wire                       WVALID,
    input  wire                       WLAST,
    output wire                       WREADY,

    // Write Response Channel
    output reg  [ID_WIDTH-1:0]        BID,
    output reg  [1:0]                 BRESP,
    output reg                        BVALID,
    input  wire                       BREADY,

    // Read Address Channel
    input  wire [ID_WIDTH-1:0]        ARID,
    input  wire [ADDR_WIDTH-1:0]      ARADDR,
    input  wire [7:0]                 ARLEN,
    input  wire [2:0]                 ARSIZE,
    input  wire [1:0]                 ARBURST,
    input  wire                       ARVALID,
    output wire                       ARREADY,

    // Read Data Channel
    output reg  [ID_WIDTH-1:0]        RID,
    output reg  [DATA_WIDTH-1:0]      RDATA,
    output reg  [1:0]                 RRESP,
    output reg                        RLAST,
    output reg                        RVALID,
    input  wire                       RREADY
);

    localparam MAX_BURST = 256;

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Internal registers
    reg awready_reg, wready_reg, arready_reg;
    assign AWREADY = awready_reg;
    assign WREADY  = wready_reg;
    assign ARREADY = arready_reg;

    reg [ADDR_WIDTH-1:0] awaddr_reg, araddr_reg;
    reg [7:0] awlen_reg, arlen_reg;
    reg [ID_WIDTH-1:0] awid_reg, arid_reg;
    reg [7:0] wbeat_count, rbeat_count;

    // Write Address Handling
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            awready_reg <= 0;
        end else begin
            if (AWVALID && !awready_reg) begin
                awaddr_reg <= AWADDR >> 3;
                awlen_reg  <= AWLEN;
                awid_reg   <= AWID;
                wbeat_count <= 0;
            end
            awready_reg <= AWVALID && !awready_reg;
        end
    end

    // Write Data Handling
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            wready_reg <= 0;
            BVALID <= 0;
            BID <= 0;
            BRESP <= 2'b00;
        end else begin
            wready_reg <= WVALID && !wready_reg;

            if (WVALID && WREADY) begin
                for (int i = 0; i < DATA_WIDTH/8; i++) begin
                    if (WSTRB[i])
                        mem[awaddr_reg][8*i +: 8] <= WDATA[8*i +: 8];
                end

                if (wbeat_count == awlen_reg) begin
                    BVALID <= 1;
                    BRESP  <= 2'b00;
                    BID    <= awid_reg;
                end else begin
                    awaddr_reg <= awaddr_reg + 1;
                    wbeat_count <= wbeat_count + 1;
                end
            end

            if (BVALID && BREADY)
                BVALID <= 0;
        end
    end

    // Read Address Handling
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            arready_reg <= 0;
        end else begin
            if (ARVALID && !arready_reg) begin
                araddr_reg <= ARADDR >> 3;
                arlen_reg  <= ARLEN;
                arid_reg   <= ARID;
                rbeat_count <= 0;
            end
            arready_reg <= ARVALID && !arready_reg;
        end
    end

    // Read Data Handling
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            RVALID <= 0;
            RLAST  <= 0;
            RRESP  <= 2'b00;
            RDATA  <= 0;
            RID    <= 0;
        end else begin
            if (!RVALID && ARVALID && ARREADY) begin
                RDATA  <= mem[araddr_reg];
                RID    <= arid_reg;
                RRESP  <= 2'b00;
                RVALID <= 1;
                RLAST  <= (arlen_reg == 0);
            end else if (RVALID && RREADY) begin
                if (rbeat_count < arlen_reg) begin
                    rbeat_count <= rbeat_count + 1;
                    araddr_reg  <= araddr_reg + 1;
                    RDATA       <= mem[araddr_reg + 1];
                    RLAST       <= (rbeat_count + 1 == arlen_reg);
                end else begin
                    RVALID <= 0;
                    RLAST  <= 0;
                end
            end
        end
    end

endmodule
