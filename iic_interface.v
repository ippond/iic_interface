`timescale 1ns/100ps
module iic_interface
#(
parameter C_CLK_FREQ = 50000000,
parameter C_IIC_FREQ = 200000,
parameter C_DATA_WE_LEN = 1,
parameter C_DATA_RD_LEN = 1,
parameter C_BYTE_ADDR_LEN = 1
)
(
input                                 I_clk         ,
input                                 I_rst         ,
input      [6:0]                      I_iic_addr    ,
input      [C_DATA_WE_LEN*8-1:0]      I_wdata       ,
input      [C_BYTE_ADDR_LEN*8-1:0]    I_word_addr   ,
input                                 I_data_we     ,
input      [7:0]                      I_data_we_len ,
input      [7:0]                      I_addr_we_len ,
input      [7:0]                      I_data_rd_len ,
input      [7:0]                      I_addr_rd_len ,
input                                 I_data_rd     ,
output reg [C_DATA_RD_LEN*8-1:0]      O_data_rd     ,
output reg                            O_data_rd_v   ,
output reg                            O_iic_ready   ,
output                                O_iic_scl     ,
inout                                 IO_iic_sda    
);

localparam C_BIT_PERIOD = C_CLK_FREQ/C_IIC_FREQ-1;
localparam C_BIT_HALF_PERIOD = C_CLK_FREQ/C_IIC_FREQ/2-1;
localparam C_BIT_QUAR_PERIOD = C_CLK_FREQ/C_IIC_FREQ/4-1;
localparam C_PERIOD_WIDTH = F_width(C_BIT_PERIOD);
localparam C_IDLE = 0;
localparam C_START = 1;
localparam C_DEVICE_ADDR = 2;
localparam C_RECEIVE_ACK = 3;
localparam C_BYTE_ADDR = 4;
localparam C_WDATA = 5;
localparam C_RDATA = 6;
localparam C_SEND_ACK = 7;
localparam C_STOP = 8;
localparam C_PRO = 9;
localparam C_PRO_LEN = 128;
localparam C_PRO_WIDTH = 8;

reg [7:0] S_data_we_len_latch = 0;
reg [C_DATA_WE_LEN*8-1:0] S_wdata_latch = 0;
reg [C_DATA_WE_LEN*8-1:0] S_wdata_latch_shift = 0;
reg [C_DATA_WE_LEN*8-1:0] S_wdata = 0;
reg [7:0] S_waddr_shift = 0;
reg [C_BYTE_ADDR_LEN*8-1:0] S_word_addr_latch = 0;
reg [6:0] S_iic_addr_latch = 0;
reg [10:0] S_addr_shiftbit = 0;
reg S_we_id = 0;
reg [C_BYTE_ADDR_LEN*8-1:0] S_waddr_latch_shift = 0;
reg [7:0] S_data_rd_len_latch = 0;
reg [7:0] S_raddr_shift = 0;
reg [7:0] S_addr_wr_len_latch = 0;
reg [C_PERIOD_WIDTH-1:0] S_clk_cnt = 0;
reg S_iic_scl = 0;
reg S_iic_scl_d = 0;
reg S_clk_pos = 0;
reg S_clk_neg = 0;
reg [3:0] S_byte_cnt = 0;
reg S_byte_over = 0;
reg S_ack = 0;
reg [7:0] S_byte_addr_cnt = 0;
reg S_byte_addr_id = 0;
reg [7:0] S_byte_wdata_cnt = 0;
reg S_wdata_id = 0;
reg S_wstop_id = 0;
reg S_start_id = 0;
reg S_rdata_id = 0;
reg [7:0] S_byte_rdata_cnt = 0;
reg S_rstop_id = 0;
reg S_iic_ready = 0;
reg [3:0] S_state_cur = 0;
reg [3:0] S_state_next = 0;
reg [3:0] S_state_cur_d = 0;
reg S_iic_sda_v = 0;
reg S_iic_scl_v = 0;
reg S_iic_sda = 0;
reg [7:0] S_device_addr = 0;
reg [C_BYTE_ADDR_LEN*8-1:0] S_byte_addr = 0;
reg [7:0] S_wdata_shift = 0;
reg [7:0] S_data_shiftbit = 0;
reg S_iic_stop_id = 0;
reg [C_PRO_WIDTH-1:0] S_pro_cnt = 0;
reg S_pro_over = 0;
reg S_iic_start_id = 0;
reg S_clk_neg_d = 0;
reg S_clk_neg_2d = 0;

always @(posedge I_clk)
begin
    if(I_data_we)
    begin
        S_data_we_len_latch <= I_data_we_len;
        S_wdata_latch <= I_wdata;
        S_waddr_shift <= C_BYTE_ADDR_LEN - I_addr_we_len;
        S_wdata_shift <= C_DATA_WE_LEN - I_data_we_len;
    end
    
    if(I_data_we || I_data_rd)
    begin
        S_word_addr_latch <= I_word_addr;
        S_iic_addr_latch <= I_iic_addr;
    end
    
    S_addr_shiftbit <= S_we_id ? (S_waddr_shift<<3) : (S_raddr_shift<<3);
    S_waddr_latch_shift <= S_word_addr_latch<<S_addr_shiftbit;
    S_data_shiftbit <= S_wdata_shift << 3;
    S_wdata_latch_shift <= S_wdata_latch << S_data_shiftbit;
    if(I_data_we)
        S_we_id <= 1'b1; 
    else if(S_state_cur == C_IDLE)
        S_we_id <= 1'b0; 

    if(I_data_rd)    
    begin
        S_data_rd_len_latch <= I_data_rd_len;
        S_raddr_shift <= C_BYTE_ADDR_LEN - I_addr_rd_len;
    end
    
    if(I_data_we)
        S_addr_wr_len_latch <= I_addr_we_len;
    else if(I_data_rd)
        S_addr_wr_len_latch <= I_addr_rd_len;
end

always @(posedge I_clk)
begin
    if(S_state_cur == C_IDLE || S_clk_cnt == C_BIT_PERIOD)
        S_clk_cnt <= 'd0;
    else
        S_clk_cnt <= S_clk_cnt + 'd1;
    if(S_state_cur == C_IDLE)
        S_iic_scl <= 1'b1;
    else if(S_clk_cnt == C_BIT_HALF_PERIOD)
        S_iic_scl <= !S_iic_scl;
    S_iic_scl_d <= S_iic_scl;
    S_clk_pos <= S_iic_scl && (!S_iic_scl_d);
    S_clk_neg <= S_iic_scl_d && (!S_iic_scl);
    S_clk_neg_d <= S_clk_neg;
    S_clk_neg_2d <= S_clk_neg_d;
    S_iic_stop_id <= S_iic_scl && (S_clk_cnt == C_BIT_PERIOD) && (S_state_cur == C_STOP);
    if(S_iic_scl && (S_clk_cnt == C_BIT_QUAR_PERIOD) && (S_state_cur == C_START))
        S_iic_start_id <= 1'b1;
    else if(S_state_cur != C_START)
        S_iic_start_id <= 1'b0;
    if(S_state_cur == C_DEVICE_ADDR || S_state_cur == C_WDATA || S_state_cur == C_BYTE_ADDR || S_state_cur == C_RDATA)
    begin
        if(S_clk_neg)
            S_byte_cnt <= S_byte_cnt + 'd1;
    end
    else
    begin
        S_byte_cnt <= 'd0;
    end
    S_byte_over <= (S_byte_cnt == 'd8);
    if(S_clk_pos)
        S_ack <= IO_iic_sda;
end

always @(posedge I_clk)
begin
    if(S_state_cur == C_IDLE)
        S_byte_addr_cnt <= 'd0;
    else if(S_state_cur == C_BYTE_ADDR && S_state_cur_d != C_BYTE_ADDR)
        S_byte_addr_cnt <= S_byte_addr_cnt + 'd1;
    S_byte_addr_id <= S_byte_addr_cnt != S_addr_wr_len_latch;

    if(S_state_cur == C_IDLE)
        S_byte_wdata_cnt <= 'd0;
    else if(S_state_cur == C_WDATA && S_state_cur_d != C_WDATA)
        S_byte_wdata_cnt <= S_byte_wdata_cnt + 'd1;
    S_wdata_id <= (!S_wstop_id) && (!S_byte_addr_id) && S_we_id;
    S_wstop_id <= (S_byte_wdata_cnt == S_data_we_len_latch);
end

reg [1:0] S_start_cnt = 0;

always @(posedge I_clk)
begin
    if(S_state_cur == C_IDLE)
        S_start_id <= 1'b0;
    else 
        S_start_id <= (S_start_cnt < 2'd2) && !S_we_id && (S_addr_wr_len_latch != 'd0);
    
    if(S_state_cur == C_START && S_state_cur_d != C_START)
        S_start_cnt <= S_start_cnt + 'd1;
    else if(S_state_cur == C_IDLE)
        S_start_cnt <= 'd0;
    
    if(S_state_cur == C_IDLE)
        S_rdata_id <= 1'b0;
    else if(S_start_cnt == 'd2 || S_addr_wr_len_latch == 'd0)
        S_rdata_id <= !S_we_id;

    if(S_state_cur == C_IDLE)
        S_byte_rdata_cnt <= 'd0;
    else if(S_state_cur == C_RDATA && S_state_cur_d != C_RDATA)
        S_byte_rdata_cnt <= S_byte_rdata_cnt + 'd1; 
    S_rstop_id <= (S_byte_rdata_cnt == S_data_rd_len_latch);
end

always @(posedge I_clk)
begin
    if((I_data_we || I_data_rd) && S_iic_ready)
        S_iic_ready <= 1'b0;
    else if(S_state_cur == C_IDLE)
        S_iic_ready <= 1'b1;
    O_iic_ready <= S_iic_ready;
end

always @(posedge I_clk)
begin
    if(I_rst)
        S_state_cur <= C_IDLE;
    else
        S_state_cur <= S_state_next;
    S_state_cur_d <= S_state_cur;
end

always @(posedge I_clk)
begin
    S_iic_sda_v <= (((S_state_cur_d == C_DEVICE_ADDR) || (S_state_cur_d == C_BYTE_ADDR) || (S_state_cur_d == C_WDATA) || (S_state_cur_d == C_SEND_ACK)) && (!S_iic_sda)) || (S_state_cur == C_STOP) || S_iic_start_id;
    S_iic_scl_v <= (S_state_cur != C_IDLE) && (!S_iic_scl) && (S_state_cur != C_PRO);
end

always @(posedge I_clk)
begin
    if(S_state_cur == C_DEVICE_ADDR)
        S_iic_sda <= S_device_addr[7];
    else if(S_state_cur == C_BYTE_ADDR)
        S_iic_sda <= S_byte_addr[C_BYTE_ADDR_LEN*8-1];
    else if(S_state_cur == C_WDATA)
        S_iic_sda <= S_wdata[C_DATA_WE_LEN*8-1];
    else if(S_state_cur == C_SEND_ACK)
        S_iic_sda <= S_rstop_id;
    
    if(S_state_cur == C_START)
        S_device_addr <= {S_iic_addr_latch,S_rdata_id};
    else if(S_state_cur == C_DEVICE_ADDR && S_clk_neg_2d)
        S_device_addr <= S_device_addr << 1;
    
    if(S_state_cur == C_START)
        S_byte_addr <= S_waddr_latch_shift;
    else if(S_state_cur == C_BYTE_ADDR && S_clk_neg_2d)
        S_byte_addr <= S_byte_addr << 1;
    
    if(S_state_cur == C_START)
        S_wdata <= S_wdata_latch_shift;
    else if(S_state_cur == C_WDATA && S_clk_neg_2d)
        S_wdata <= S_wdata << 1;
    
    if(S_state_cur == C_IDLE)
        O_data_rd <= 'd0;
    else if(S_state_cur == C_RDATA && S_clk_pos)
        O_data_rd <= {O_data_rd[C_DATA_RD_LEN*8-2:0],IO_iic_sda};
    O_data_rd_v <= S_iic_stop_id && (!S_we_id);
end

assign IO_iic_sda = S_iic_sda_v ? 1'b0 : 1'bz;
assign O_iic_scl = S_iic_scl_v ? 1'b0 : 1'bz;

always @(*)
begin
    case(S_state_cur)
    C_IDLE:
        if((I_data_we || I_data_rd) && S_iic_ready)
            S_state_next = C_START;
        else
            S_state_next = C_IDLE;
    C_START:
        if(S_clk_neg_2d)
            S_state_next = C_DEVICE_ADDR;
        else
            S_state_next = C_START;
    C_DEVICE_ADDR:
        if(S_byte_over)
            S_state_next = C_RECEIVE_ACK;
        else
            S_state_next = C_DEVICE_ADDR;
    C_RECEIVE_ACK:
        if(S_clk_neg_2d)
        begin
            if(S_ack)
                S_state_next = C_IDLE;
            else if(S_byte_addr_id)
                S_state_next = C_BYTE_ADDR;
            else if(S_wdata_id)
                S_state_next = C_WDATA;
            else if(S_start_id)
                S_state_next = C_START;
            else if(S_rdata_id)
                S_state_next = C_RDATA;
            else if(S_wstop_id)
                S_state_next = C_STOP;
        end
        else
            S_state_next = C_RECEIVE_ACK;
    C_BYTE_ADDR:
        if(S_byte_over)
            S_state_next = C_RECEIVE_ACK;
        else
            S_state_next = C_BYTE_ADDR;
    C_WDATA:
        if(S_byte_over)
            S_state_next = C_RECEIVE_ACK;
        else
            S_state_next = C_WDATA;
    C_RDATA:
        if(S_byte_over)
            S_state_next = C_SEND_ACK;
        else
            S_state_next = C_RDATA;
    C_SEND_ACK:
        if(S_clk_neg_2d)
            S_state_next = S_rstop_id ? C_STOP : C_RDATA;
        else
            S_state_next = C_SEND_ACK;
    C_STOP:
        if(S_iic_stop_id)   
            S_state_next = C_PRO;
        else
            S_state_next = C_STOP;
    C_PRO:
        if(S_pro_over)
            S_state_next = C_IDLE;
        else
            S_state_next = C_PRO;
    default:
        S_state_next = C_IDLE;
    endcase     
end

always @(posedge I_clk)
begin
    if(S_state_cur == C_PRO)
        S_pro_cnt <= S_pro_cnt + 'd1;
    else
        S_pro_cnt <= 'd0;
    S_pro_over <= S_pro_cnt == C_PRO_LEN;
end

function integer F_width;
input integer I_num;
integer i;
begin
    for(i=0;2**i<=I_num;i=i+1)
    F_width = i;
    F_width = i;
end
endfunction

endmodule
