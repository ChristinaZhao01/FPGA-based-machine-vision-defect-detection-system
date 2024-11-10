`timescale 1ns / 1ns
`define    CLOCK  80
// 仿真模块
module dvp_ddr3_test(
);

// 信号流向
reg clk;
reg rst_n;
reg cfg_write;
reg cfg_read;
reg [3:0] cfg_adress;
wire [31:0] cfg_read_data;
reg [31:0] cfg_write_data;
reg data_waitrequest;
wire [31:0] data_addr;
reg data_valid;
reg [127:0] data_redata;
wire [127:0] data_wrdata;
wire [15:0] byte;
wire data_write;
wire [9:0] data_size;
reg [7:0] dvp_data;
reg dvp_href;
reg dvp_vsync;
reg dvp_pclk;




// 信号给初值
initial begin
    clk <= 0;
    rst_n <= 0;
    cfg_write <= 0;
    cfg_read <= 0;
    cfg_adress <= 0;
    cfg_write_data <= 0;
    data_waitrequest <= 1;
    data_valid <= 0;
    data_redata <= 0;
    dvp_data <= 0;
    dvp_href <= 0;
    dvp_vsync <= 1;
    dvp_pclk <= 0;


    #(10*`CLOCK)
    rst_n <= 1;
    // 开始任务
    repeat(12)begin
        #(500*`CLOCK)
        dvp_data_task();
    end
end


// 时钟信号定期反转
always  #(`CLOCK/2)     dvp_pclk =  ~dvp_pclk;
always  #(`CLOCK/8)     clk  = ~clk;


  
task dvp_data_task;
    integer     i,j;
    begin
    // Ip核配置过程 给地址2 3 分别写1
       cfg_write   = 1;
       #(1*`CLOCK);
       cfg_adress  = 2;
       #(1*`CLOCK);
       cfg_write_data = 1;
       #(1*`CLOCK);
       cfg_adress  = 3;
       #(1*`CLOCK);
       cfg_write_data = 1;
       #(1*`CLOCK);
       cfg_write   = 0;
       data_waitrequest = 0;
       
       #(10*`CLOCK);
       dvp_vsync = 0;
       dvp_href = 1;


    // 开始获取dvp_data 
       for(i=0;i<100;i=i+1)begin
            for(j=0;j<256;j=j+1)begin
             if(i%2==1 && j==128) begin
                dvp_href <= 0;
                dvp_data <= 0;
                #(80*`CLOCK); 
                dvp_href = 1;
             end
             else begin
               #(1*`CLOCK);
               dvp_data = dvp_data + 1; 
             end
            end   
            dvp_data  = 0;
        end
    end
endtask


// 例化顶层模块 
dvp_ddr3_top dvp2data_inst 
                            (
        .clk    (clk),                
		.avalon_write (cfg_write) ,   
		.avalon_read  (cfg_read),      
		.avalon_addr   (cfg_adress),       
		.avalon_read_data   (cfg_read_data),  
		.avalon_write_data  (cfg_write_data), 
		.avl_waitrequest    (data_waitrequest),  
		.avl_addr   (data_addr),          
		// .avl_rdata_valid    (data_valid),   
		// .avl_rdata  (data_redata),        
		.avl_wdata  (data_wrdata),        
		.avl_be (byte),           
		// .avl_read_req (data_read),     
		.avl_write_req (data_write),     
		.avl_size (data_size),          
		.dvp_data   (dvp_data),        
		.dvp_href   (dvp_href),         
		.dvp_pclk   (dvp_pclk),         
		.dvp_vsync  (dvp_vsync),         
		.rst_n (rst_n)             
                           );

endmodule