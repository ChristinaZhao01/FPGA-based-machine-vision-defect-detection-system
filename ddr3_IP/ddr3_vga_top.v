// 此模块作为ddr3_vga ip核的顶层模块
module ddr3_vga_top  (
        clk,      //         
		avalon_write,   //
		avalon_read,      //
		avalon_addr,       //
		avalon_read_data,  //
		avalon_write_data, //
		avl_waitrequest,  
		avl_addr,           //
		avl_rdata_valid,   //
		avl_rdata,        //
		avl_wdata,        //
		avl_be,            //
		avl_read_req,     //
		avl_write_req,     //
		avl_size,          //
		vga_clk,  //
        vga_de,   //
        vga_vsync,   // 
        vga_rgb,    //
		rst_n,  //
        vga_hsync
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
input avl_rdata_valid;
input [127:0] avl_rdata;
output [127:0] avl_wdata;
output [15:0] avl_be;
output avl_read_req;
output avl_write_req;
output [9:0] avl_size;
output vga_clk;  // vga的时钟信号 5MHZ
output vga_de;
output vga_vsync;
output vga_hsync;
output [23:0] vga_rgb;


// 中间变量
wire [31:0] buffer_base;
wire [31:0] img_size;
wire [31:0] start_status;
wire [31:0] buffer_status;
wire fifo_read;  // fifo读使能
wire [9:0] fifo_usedw;  //可读深度
wire [1:0] state;      // 用来表示现在在写的buff
wire img_end;  //一帧图像的结束信号
wire img_end_up;  //随便给给
wire end_ok; 
wire [23:0] rgb_reg;
wire [10:0] burst_num;

// 子模块的例化
// clk_gen模块的例化：
clk_gen  u0 (
                    .clk(clk),
                    .rst_n(rst_n),
                    // 给vga时序输出模块的驱动时钟
                    .vga_clk(vga_clk)  //5MHZ
                );


// vga_intf模块的例化：
vga_intf  u1 (
                    // clock
                    .vga_clk(vga_clk),  //5MHZ 应该还可以改变
                    .rst_n(rst_n),
                    // vga 时序
                    .vga_de(vga_de), // 行信号
                    // vga_rgb,
                    .vga_vsync(vga_vsync), // 帧信号
                   // data_in,   //从fifo中读出的数据 8位 需要拼接成24位然后再传输
                    .fifo_read(fifo_read),  // 从fifo中读数据的有效信号 
                    .fifo_usedw(fifo_usedw), // fifo可读深度 用来处理和判断何时开始从fifo读取数据
                    .img_end(img_end),  // 表示一帧图像的结束    
                    .read_enable(buffer_status[1:0]),  //用寄存器3的低两位 当成标志位 用来判断
                    .ip_enable(start_status[0]), // ip核是否开始工作 寄存器2
                    .state(state),
                    .vga_hsync(vga_hsync),
                    .vga_rgb(vga_rgb),
                    .rgb_reg(rgb_reg),
                    .burst_num(burst_num)
                  );


// ddr3_vga_ctrl模块的例化：
ddr3_vga_ctrl   u2 (
                            //clock
                            .clk(clk), //50MHZ
                            .rst_n(rst_n),
                            // avalon协议 方便hps写入数据和读取数据
                            .avalon_write(avalon_write),
                            .avalon_read(avalon_read),
                            .avalon_addr(avalon_addr),
                            .avalon_read_data(avalon_read_data),
                            .avalon_write_data(avalon_write_data),
                            // else
                            .state(state),  //标记现在读取的是哪个buff
                            .img_end(img_end),
                            .buffer_base(buffer_base),
                            .img_size(img_size),
                            .start_status(start_status),
                            .buffer_status(buffer_status)
                       );


// ddr3_read模块的例化
ddr3_read    u3 (
                        .rst_n(rst_n),
                        // clock
                        .clk(clk),       //50 MHZ
                        .vga_clk(vga_clk),   //5 MHZ
                        // avalon
                        .waitrequest(avl_waitrequest),	//从机发过来的等待信号
                        .address(avl_addr),		//主机输出地址
                        .write(avl_write_req),		//主机写从机信号
                        .byteenable(avl_be),	//字节使能位 全1即可
                        .writedata(avl_wdata),	//主机写入从机的数据
                        .burstcount(avl_size),	//突发一次有多少个数据包
                        .read(avl_read_req),      //主机读从机信号
                        .readdata(avl_rdata),  //主机读取的从机数据
                        .readdatavalid(avl_rdata_valid), // 读取数据有效标志位 
                        .read_enable(buffer_status[1:0]),  //用寄存器3的低两位 当成标志位 用来判断
                        .ip_enable(start_status[0]),   // ip核是否开始工作 寄存器2
                        .fifo_usedw(fifo_usedw),   //fifo可读深度 输出到vga_intf模块作为标志位
                        .state(state),      // 表明正在读的buff是谁 方便寄存器清零处理
                        .fifo_read(fifo_read), //fifo可读信号
                        .img_end(img_end),  // 一帧图像的结束标志
                        .avalon_read_data(avalon_read_data), //读取的数据
                        .rgb_reg(rgb_reg),
                        .burst_num(burst_num)
                    );




endmodule