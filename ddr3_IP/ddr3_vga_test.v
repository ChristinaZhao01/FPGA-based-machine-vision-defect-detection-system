`timescale 1ns / 1ns
`define    CLOCK 20  // 一个时钟周期的时间
// 仿真模块
module ddr3_vga_test();

// 信号流向
// register
reg clk; //
reg rst_n; //
reg cfg_write; //
reg cfg_read; //
reg [3:0] cfg_adress; //
reg [31:0] cfg_write_data; //
reg data_waitrequest; //
reg data_valid; //
reg [127:0] data_redata; //
reg [25:0] cnt; // 计数
reg [4:0] cnt1; //用来计数read信号拉高之后 到我们valid信号出现高电平的这段间隔
reg [6:0] cnt2; //表示datavalid开始计数之后 用来记录周期 方便 进行datavalid信号的处理
reg state;


// wire
wire [31:0] data_addr;
wire [127:0] data_wrdata;
wire [15:0] byte;
wire data_write;
wire data_read;
wire [9:0] data_size;
wire vga_de;
wire vga_vsync;   
wire [23:0] vga_rgb;  
wire vga_clk;
wire vga_hsync;
wire [31:0] cfg_read_data;


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
    state <= 0; //初始为0

    #(10*`CLOCK)
    // 复位信号有效
    rst_n <= 1;
    // 执行任务
    vga_data_task();
    // // 开始任务 重复12次
    // repeat(12)begin
    //     #(500*`CLOCK)
    // end
end


// 时钟信号定期反转
always  #(`CLOCK/2)  clk = ~clk;
// datavalid信号处理
always  @(posedge clk or negedge rst_n)
   begin
      if(!rst_n)
         cnt <= 0;
      else if(cnt==26'd50_000_000)
         cnt <= 0;
      else 
         cnt <= cnt + 1;
   end


always @(posedge clk or negedge rst_n)
   begin
      if(!rst_n)
         data_valid <= 0;
      else if(cnt%3==0)
         data_valid <= 0;
      else
         data_valid <= 1;
   end


// // 在特定时刻开启计数 然后周期递减 为0表示有效 作为其他变量的标志位 为0之后自己回到17 方便下一次使用
// always @(posedge clk or negedge rst_n)
//    begin
//       if(!rst_n)
//          cnt1 <= 9;
//       else if(cfg_read)
//          cnt1 <= 8;
//       else if(cnt1)
//          cnt1 <= cnt1 - 1;
//       else
//          cnt1 <= cnt1;
//    end


// //cnt2的处理 出现cnr1为0的时候开始计数 然后用来处理我们的datavalid信号  
// always @(posedge clk or negedge rst_n)
//    begin
//       if(!rst_n)
//          cnt2 <= 0;
//       else if(cfg_read)  //出现cfg_read的时候归零 即将使用该计数值
//          cnt2 <= 0;
//       else if(!cnt1)
//          cnt2 <= cnt2 + 1;
//       else        
//          cnt2 <= cnt2;
//    end


// // datavalid信号的处理 
// always @(posedge clk or negedge rst_n)
//    begin
//       if(!rst_n)
//          data_valid <= 0;
//       else if(cnt2<=23 && cnt2%3==0 && !cnt1)
//          data_valid <= 0;
//       else if(cnt2<=23 && cnt2%3!=0 && !cnt1)
//          data_valid <= 1;
//       else
//          data_valid <= 0; 
//    end



task vga_data_task;
    integer     i,j;
    begin
    // Ip核配置过程 给地址2写1
       cfg_write   = 1;
       #(1*`CLOCK);
       cfg_adress  = 2;
       #(1*`CLOCK);
       cfg_write_data = 1;
       #(1*`CLOCK);
    // 第一次进入 手动给3 正常启动
       data_waitrequest = 0;
       #(1*`CLOCK);
       cfg_adress  = 3;
       #(1*`CLOCK);
       cfg_write_data = 3;
       #(1*`CLOCK);
       cfg_write = 0;


    // 开始获取数据
       for(i=1;i<=320;i=i+1)begin
            for(j=1;j<=500;j=j+1)begin
                data_redata = j+128'h112233445566778899456789;
                #(1*`CLOCK); //延迟一个写时钟周期
            end
            if(state==0) begin
                cfg_write   = 1;
                #(1*`CLOCK);
                cfg_adress  = 3;
                #(1*`CLOCK);
                cfg_write_data = 3;
            end
       end
    end
endtask


// 例化顶层模块 
ddr3_vga_top dvp2data_inst 
                            (
      .clk    (clk),                
		.avalon_write (cfg_write) ,   
		.avalon_read  (cfg_read),      
		.avalon_addr   (cfg_adress),       
		.avalon_read_data   (cfg_read_data),  
		.avalon_write_data  (cfg_write_data), 
		.avl_waitrequest    (data_waitrequest),  
		.avl_addr   (data_addr),          
		.avl_rdata_valid    (data_valid),   
		.avl_rdata  (data_redata),        
		.avl_wdata  (data_wrdata),        
		.avl_be (byte),           
		.avl_read_req (data_read),     
		.avl_write_req (data_write),     
		.avl_size (data_size),                
		.rst_n (rst_n),
      .vga_clk (vga_clk),
      .vga_de (vga_de),
      .vga_vsync (vga_vsync),
      .vga_rgb (vga_rgb),
      .vga_hsync (vga_hsync)         
                           );
endmodule