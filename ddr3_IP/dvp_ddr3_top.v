// 此模块为顶层模块 用来例化各个功能模块
module dvp_ddr3_top (
        clk,              
		avalon_write,  
		avalon_read,      
		avalon_addr,       
		avalon_read_data,  
		avalon_write_data, 
		avl_waitrequest,  
		avl_addr,          
		// avl_rdata_valid,   
		// avl_rdata,        
		avl_wdata,        
		avl_be,           
		// avl_read_req,     
		avl_write_req,     
		avl_size,          
		dvp_data,        
		dvp_href,         
		dvp_pclk,         
		dvp_vsync,         
		rst_n    
                   );


// 信号流向
input clk;
input rst_n;
input avalon_write;
input avalon_read;
input [3:0] avalon_addr;
output [31:0] avalon_read_data;
input [31:0] avalon_write_data;
input avl_waitrequest;
output [31:0] avl_addr;
// input avl_rdata_valid;
// input [127:0] avl_rdata;
output [127:0] avl_wdata;
output [15:0] avl_be;
// output avl_read_req;
output avl_write_req;
output [9:0] avl_size;
input [7:0] dvp_data;
input dvp_href;
input dvp_pclk;
input dvp_vsync;


// 中间变量
wire [31:0] buffer_base;
wire [31:0] img_size;
wire [31:0] start_status;
wire [31:0] capture_en;
wire [7:0] my_data; //capture捕获的数据
wire fifo_write; //fifo 写使能
wire img_start;  // 一帧图像的开始信号
wire img_end;  //一帧图像的结束信号



// 子模块的例化：
// dvp数据获取模块 capture的例化
capture u0 (
                            .rst_n   (rst_n),
                            //dvp
                            .dvp_data   (dvp_data),
                            .dvp_href   (dvp_href),
                            .dvp_pclk   (dvp_pclk), //12.5MHZ
                            .dvp_vsync  (dvp_vsync),
                            // else
                            .capture_enable (capture_en[0]),
                            .ip_enable  (start_status[0]),
                            .my_data    (my_data),
                            .fifo_write (fifo_write),
                            .img_start  (img_start)
           );


// dvp_ddr3_ctrl控制模块的例化
dvp_ddr3_ctrl u1  (
                            //clock
                            .clk    (clk), //50MHZ
                            .rst_n  (rst_n),
                            //else
                            .avalon_write  (avalon_write),
                            .avalon_read   (avalon_read),
                            .avalon_addr    (avalon_addr),
                            .avalon_read_data   (avalon_read_data),
                            .avalon_write_data  (avalon_write_data), 
                            .img_end    (img_end),
                            .buffer_base    (buffer_base),
                            .img_size   (img_size),
                            .start_status   (start_status),
                            .capture_en (capture_en)
                  );


// ddr3_write模块的例化
ddr3_write u2 (  
                            //clock
                            .clk    (clk), //50MHZ
                            .dvp_pclk   (dvp_pclk),  //12.5 MHZ
                            .rst_n  (rst_n),
                            //avalon
                            .waitrequest    (avl_waitrequest),
                            .address    (avl_addr),
                            // .readdatavalid  (avl_rdata_valid),
                            // .readdata   (avl_rdata),
                            .writedata  (avl_wdata),
                            .byteenable (avl_be),
                            // .read   (avl_read_req),
                            .write  (avl_write_req),
                            .burstcount (avl_size),
                             // else
                            .img_start  (img_start), //一帧图像传输开始的标志位
                            .data_in    (my_data),  //表示dvp_data的输出 8位
                            .fifo_write (fifo_write), //capture给的信号 表示fifo写有效
                            .ip_enable  (start_status[0]),  //ip工作标志位
                            .capture_enable (capture_en[0]), // 开始采集标志位 
                            .img_end    (img_end)  //一帧图像的终止信号  
              );


endmodule