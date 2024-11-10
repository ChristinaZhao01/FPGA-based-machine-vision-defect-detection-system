// 此模块用来处理写入数据到ddr3的部分 需要调用quartus 的fifo ip实现异步时钟的缓冲区功能
module ddr3_write (
                            // reset
                            rst_n,
                            // clock
                            dvp_pclk,  //12.5 MHZ
                            clk,       //50 MHZ
                            // avalon
                            waitrequest,	//从机发过来的等待信号
                            address,		//主机输出地址
                            write,		//主机写从机信号
                            byteenable,	//字节使能位 全1即可
                            writedata,	//主机写入从机的数据
                            burstcount,	//突发一次有多少个数据包
                            // read,       //读有效信号
                            // readdata,   //读取的数据
                            // readdatavalid, //读数据有效信号
                            // else
                            img_start, //一帧图像传输开始的标志位
                            data_in,  //表示dvp_data的输出 8位
                            fifo_write, //capture给的信号 表示fifo写有效
                            ip_enable,  //ip工作标志位
                            capture_enable, // 开始采集标志位
                            img_end  // 一帧图像结束标志
                   );


// 一些参数设置
// fifo in and fifo out
parameter wrdatawidth = 8;		//FIFO输入数据的位宽
parameter redatawidth = 128;	//fifo的输出位宽

// fifo depth and log
parameter wrdatadepth = 1024;     //写FIFO深度
parameter redatadepth = 64;	//读FIFO深度
parameter wrdatadepth_log = 10;	
parameter redatadepth_log = 6;	

// avalon 
parameter address_base = 32'h30880000;  //突发传输的基地址
parameter burstsize = 16;	//表示突发传输的数据长度
parameter burstwidth = 10;	//突发传输长度的位宽
parameter bytewidth = 16;	//byteenable的位宽 全为1 即表示全部有效即可
parameter addwidth = 32;	//地址位宽


// 信号流向
input rst_n;
input dvp_pclk;
input clk;
input waitrequest;
// input [redatawidth-1:0] readdata; //avalon 读数据 
// input readdatavalid; // avalon 读数据有效
// output read;      // avalon 读有效信号
output write;     // avalon 写使能信号
output reg [addwidth-1:0] address;  // avalon 地址信号
output reg [bytewidth-1:0] byteenable; // avalon byteenable
output [redatawidth-1:0] writedata;
output reg [burstwidth-1:0] burstcount;


input img_start;  // 表示一帧图像的开始（帧有效信号的下降沿）
output img_end;  //表示一帧图像的结束（burst_num==1500 && 最后一个burst传输完成）
input [7:0] data_in;    //dvp_data的输出
input fifo_write;    //fifo 写有效信号
input ip_enable;    // ip是否开始工作
input capture_enable;  // 是否开始采集一帧图像写入到ddr3


// 一些中间变量
reg [burstwidth-1:0] burst_counter;	//用于计算突发传输中还未传输的字数目的寄存器,非0表示正在发布的突发传输还未传输完毕
wire [redatadepth_log-1:0] fifo_usedw;  // fifo的可读深度 即还可以读出多少个数据通过avalon协议写入到ddr3 128位为一个数据
wire burst_data_already;   //表示是否有足够的数据来完成一次突发传输  置1表示有效 有足够的数据进行突发传输
wire burst_start;   // 表示一个突发传输的起始时刻 置1有效 需要考虑多个方面 例如数据是否足够  上一次突发传输是否完成等等
wire fifo_read;  // 表示fifo读的有效信号 其实与avalon写有效信号一致即可
wire write_ddr3_ok; // 表示可以写入数据到ddr3之内（waitrequest为0 并且avalon写为高信号）
reg [10:0] burst_num;  // 每一次突发传输加1 最大值为1500
wire img_flag;   // 表示一帧图像是否传输完毕


// 变量赋值的处理
assign burst_data_already = (fifo_usedw>=burstsize) && (burst_counter==0); //表示此时未进行任何突发传输 且数据已经满足了一次的阈值
assign burst_start = burst_data_already && ip_enable && capture_enable;  // 数据准备好了且ip核处于采集图像的工作阶段
assign write = burst_counter!=0;  //正常开始工作后 burst_counter回到0之前
assign write_ddr3_ok = ~waitrequest && write; // 表示可写入数据到ddr3
assign fifo_read = write_ddr3_ok;  //跟写入信号同步 即同步实现从fifo读取并且写入到ddr3


// dcfifo的例化 主要用到了输入输出和可读深度
dcfifo_mixed_widths	dcfifo_mixed_widths_component 
           (
                // reset 
                .aclr (~rst_n),
                // clock 
                .rdclk (clk),
                .wrclk (dvp_pclk),
                // data in
				.data (data_in),
                // enable
				.rdreq (fifo_read),
				.wrreq (fifo_write),
                // data out
				.q (writedata),
                // read depth use
				.rdusedw (fifo_usedw)
           );
				
	defparam
		dcfifo_mixed_widths_component.intended_device_family = "Cyclone V",
		dcfifo_mixed_widths_component.lpm_numwords = wrdatadepth,   // 指定fifo的深度
		dcfifo_mixed_widths_component.lpm_showahead = "OFF",
		dcfifo_mixed_widths_component.lpm_type = "dcfifo_mixed_widths",
		dcfifo_mixed_widths_component.lpm_width = wrdatawidth,  // 输入端口的位宽
		dcfifo_mixed_widths_component.lpm_widthu = wrdatadepth_log,  //fifo wrusedw位宽设置
		dcfifo_mixed_widths_component.lpm_widthu_r = redatadepth_log, // fifo 读rdusedw的位宽设置
		dcfifo_mixed_widths_component.lpm_width_r = redatawidth,  // 输出端口的位宽 
		dcfifo_mixed_widths_component.overflow_checking = "ON",  // 是否使能保护电路进行上溢写检查
		dcfifo_mixed_widths_component.rdsync_delaypipe = 4,
		dcfifo_mixed_widths_component.underflow_checking = "ON", // 是否进行下溢读检查
		dcfifo_mixed_widths_component.use_eab = "ON",          // 是否使用RAM模块构建IP核
		dcfifo_mixed_widths_component.wrsync_delaypipe = 4;



// 该模块的主要逻辑部分
// burst_counter的计算 用于记录某个突发传输中的进程 不为0即表示一个突发传输正在继续
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            burst_counter <= 0;
        // else if(img_start)
        //     burst_counter <= 0;
        else if(burst_start)
            burst_counter <= burstsize;
        else if(write_ddr3_ok)
            burst_counter <= burst_counter - 1;
        else 
            burst_counter <= burst_counter;
    end


// 突发传输的次数计算 方便计算地址 以及记录整个传输进程 非正常工作时为0 其余情况保持 每一个burst开始时递增
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            burst_num <= 0;
        else if(burst_start)
            burst_num <= burst_num + 1;
        else if((!capture_enable) | (!ip_enable))
            burst_num <= 0;
        else 
            burst_num <= burst_num;     
    end

// assign img_end = ((burst_num==1500)&&(burst_counter==0))? 1:0;
assign img_end = ((burst_num==1500)&&(burst_counter==0))? 1:0;


// 突发传输的地址计算 每次递增地址为burstsize(16)*每一个数据包的字节数（128/8=16）即bytewidth
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            address <= 0;
        else if(burst_start)
            address <= address_base + burst_num*burstsize*bytewidth;
        else 
            address <= address;
    end


// 突发传输的byteenable 处理 考虑实际情况 直接全部给1即可
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            byteenable <= 0;
        else if(ip_enable && capture_enable)
            byteenable <= 16'hffff;
        else
            byteenable <= 0;
    end


// 突发传输的burstcount计算 需要的时候直接给16即可
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            burstcount <= 0;
        else if(ip_enable && capture_enable)
            burstcount <= 16;
        else
            burstcount <= 0;
    end


endmodule



	