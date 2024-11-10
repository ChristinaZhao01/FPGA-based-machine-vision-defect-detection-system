// 此模块用来从buff0 buff1中通过avalon协议读取数据 然后写入到fifo中
module ddr3_read    (
                        rst_n,
                        // clock
                        clk,       //50 MHZ
                        vga_clk,   //5 MHZ
                        // avalon
                        waitrequest,	//从机发过来的等待信号
                        address,		//主机输出地址
                        write,		//主机写从机信号
                        byteenable,	//字节使能位 全1即可
                        writedata,	//主机写入从机的数据
                        burstcount,	//突发一次有多少个数据包
                        read,      //主机读从机信号
                        readdata,  //主机读取的从机数据
                        readdatavalid, // 读取数据有效标志位 
                        read_enable,  //用寄存器3的低两位 当成标志位 用来判断
                        ip_enable,   // ip核是否开始工作 寄存器2
                        fifo_usedw,   //fifo可读深度 输出到vga_intf模块作为标志位
                        state,      // 表明正在读的buff是谁 方便寄存器清零处理
                        fifo_read, //fifo可读信号
                        img_end,  //输出到其他模块 作为一帧图像的结束标志
                        avalon_read_data, //用来读取该数值 确定何时开始进行vga-hdmi的输出
                        rgb_reg, //临时储存将要通过rbg输出的数据 方便打拍
                        burst_num
                    );


// 一些参数设置
// fifo in and fifo out
parameter wrdatawidth = 384; //FIFO输入数据的位宽
parameter redatawidth = 24;	//fifo的输出位宽

// fifo depth and log
parameter wrdatadepth = 64;     //写FIFO深度
parameter redatadepth = 1024;	//读FIFO深度
parameter wrdatadepth_log = 6;	
parameter redatadepth_log = 10;	

// avalon 
parameter address_base0 = 32'h308DDC00;  //buff0突发传输的基地址
parameter address_base1 = 32'h3093B800;  //buff1突发传输的基地址
parameter burstsize = 16;	//表示突发传输的数据长度
parameter burstwidth = 10;	//突发传输长度的位宽
parameter bytewidth = 16;	//byteenable的位宽 全为1 即表示全部有效即可
parameter addwidth = 32;	//地址位宽


// 信号流向
input rst_n;
input clk;
input vga_clk;
input waitrequest;
input fifo_read;  // fifo可读信号 
input [128-1:0] readdata; //avalon 读数据 
input readdatavalid; // avalon 读数据有效
output reg read;      // avalon 读有效信号
output write;     // avalon 写使能信号
output reg [addwidth-1:0] address;  // avalon 地址信号
output reg [bytewidth-1:0] byteenable; // avalon byteenable
output [128-1:0] writedata;
output reg [burstwidth-1:0] burstcount;
input [1:0] read_enable;   // 寄存器的低两位 用来判断是否某时刻某个buff可读 
input ip_enable;     // ip核是否开始工作
output [redatadepth_log-1:0] fifo_usedw;   // 作为输出 被其他模块使用
output reg [1:0] state;  //表示要读取的对象是buff0还是buff1
input img_end;  //表示一帧图像已经从ddr3指定的buff取出 表示结束标志
input [31:0] avalon_read_data;  //avalon 协议读取的数据
output [23:0] rgb_reg; //寄存器 先储存fifo输出的数据
output reg [10:0] burst_num;  // 用来计算突发传输的次数 用来统计整个流程


// 中间变量
reg [wrdatawidth-1:0] fifo_wrdata; //用来表示写入fifo的数据 384位
reg [5:0] burst_counter; // 用来记录某一次burst传输的进程 
wire [wrdatadepth_log-1:0] write_usedw;  // 用来确定fifo已经写入了多少数据
wire burst_start;   // 用来表示一次burst的开始
wire read_ddr3_ok; //用来表示burst启动后 ddr3数据是否可读写入fifo
reg  [14:0] with_cnt;  //总拼接次数 最大值24000
wire fifo_write;  //fifo 写有效信号 高电平有效 比较复杂 需要给rge方便处理
reg with_cnt_d0;  //with_cnt 信号打拍 方便进行fifo_write的处理
wire with_cnt_already; // 表示with_cnt准备就绪 可以进行fifo_write信号的拉高
reg [12:0] write_num; //用来计算write_num的总数目 做测试
reg [1:0] read_state; //用来确定读取哪个buffer
reg img_end_d0; //用于打拍 检测边缘
wire img_end_down; //检测img_end的下降沿



// 变量的赋值处理 
// burst_start表征一次突发传输的开始 必须满足严格的条件 burst_start会开始burst_counter计数 并且拉高read信号 开始突发读过程
assign burst_start = (write_usedw<=41) && (burst_counter==0) && burst_num<1500 &&  (state!=3) && (read_enable[0]==1 || read_enable[1]==1);
assign read_ddr3_ok = readdatavalid && burst_counter!=0;  //一次突发读取没结束 并且读数据有效信号为高 
assign fifo_write = with_cnt!=0 && with_cnt%3==0 && with_cnt_already;
assign with_cnt_already = with_cnt ^ with_cnt_d0;  //如果with_cnt未变化 则为0 否则为1 保证with_cnt每个值只作用一周期



// dcfifo的例化 用来完成384输入 24输出
dcfifo_mixed_widths	dcfifo_mixed_widths_component
           (
                // reset  
                .aclr (~rst_n),  //
                // clock 
                .rdclk (vga_clk), //
                .wrclk (clk),   // 
                // data in
				.data (fifo_wrdata), // avalon总线从ddr3读取的数据 直接写入到fifo中
                // enable
				.rdreq (fifo_read), //
				.wrreq (fifo_write),  // 
                // data out
				.q (rgb_reg),  //
                // write depth use
                .wrusedw (write_usedw), // 计算何时可以开始一次burst传输读取数据
                // read depth use
				.rdusedw (fifo_usedw) //
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


// img_end 打拍用来检测边缘
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            img_end_d0 <= 0;
        else
            img_end_d0 <= img_end;
    end

assign img_end_down = ~img_end && img_end_d0; //用于检测下降沿


// read_state 表示要读取的buffer信息 用来帮助确定突发传输的地址等信息 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            read_state <= 2;
        else if(read_enable==3 && state==3)  //启动 不用管
            read_state <= 0;  //表示启动成功 为了仿真
        else if(!read_state && img_end_down)
            read_state <= 1;
        else if(read_state==1 && img_end_down)
            read_state <= 0;
        else
            read_state <= read_state;    
    end


// with_cnt 打拍 方便进行fifo_write的处理
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            with_cnt_d0 <= 0;
        else
            with_cnt_d0 <= with_cnt;
    end


// with_cnt 拼接次数的处理 
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            with_cnt <= 0;
        else if(img_end)  //一帧传输完毕 清零即可 下周期重新使用
            with_cnt <= 0;
        else if(read_ddr3_ok)  //来一个有效数据递增一次 方便利用移位寄存器
            with_cnt <= with_cnt + 1;
        else
            with_cnt <= with_cnt;
    end


// fifo_wrdata的处理 满足条件则拼接成384位 写入到fifo中
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            fifo_wrdata <= 0;
        else if(read_ddr3_ok && with_cnt%3==0) //0 3 6 是第一次来数据  加上第三个标志位 确保一个cnt只拼接一次
            fifo_wrdata <= {readdata,256'b0};
        else if(read_ddr3_ok && with_cnt%3!=0)
            fifo_wrdata <= {readdata,fifo_wrdata[383:128]};
        else
            fifo_wrdata <= fifo_wrdata;
    end


//burstcount的处理 有条件置16即可  ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            burstcount <= 0;
        else if(read_ddr3_ok && burst_counter==1)
            burstcount <= 0;
        else if(burst_start)
            burstcount <= burstsize;
        else
            burstcount <= burstcount;
    end


// byteeanble的处理 全部置1即可 不需要丢掉数据 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            byteenable <= 0;
        else if(read_ddr3_ok && burst_counter==1)
            byteenable <= 0;
        else if(burst_start)
            byteenable <= 16'hffff;
        else
            byteenable <= byteenable;
    end


// read信号的处理 突发传输开始的时候拉高 随着waitrequest发生变化 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            read <= 0;
        else if(waitrequest && read) //waitrequesr为高表示从机不能接收读信号 故此时read 信号保留
            read <= read;
        else if(burst_start)
            read <= 1;
        else 
            read <= 0;
    end


// burst_counter的处理 用来记录单个burst的流程 突发传输开始的时候拉高 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            burst_counter <= 0;
        else if(burst_start)
            burst_counter <= bytewidth;
        else if(read_ddr3_ok)
            burst_counter <= burst_counter - 1;
        else 
            burst_counter <= burst_counter;
    end


// burst_num的处理 用来记录一帧图片的读取流程 主要是方便用作地址计算 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            burst_num <= 0;
        else if(burst_start)
            burst_num <= burst_num + 1;
        else if(img_end_down)  //一帧图像传输完
            burst_num <= 0;
        else 
            burst_num <= burst_num;
    end


// 读取地址的处理 跟dvp-ddr3不同 得考虑buff0 buff1两种情况 可以根据标志位来判断 跟read信号同步发出 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            address <= 0;
        else if(read_ddr3_ok && burst_counter==1)
            address <= 0;  //此时地址清零 方便下次地址的进入 同时保证跟datavalid信号同时拉低
        else if(burst_start && !read_state) // 读取buff0 同时保证跟read信号同时拉高
            address <= address_base0 + (burst_num)*burstsize*bytewidth;
        else if(burst_start && read_state==1) // 读取buff1
            address <= address_base1 + (burst_num)*burstsize*bytewidth;
        else    
            address <= address;
    end


// state的处理 3是处理第一帧 2是表示不处于处理阶段 0和1 分别表示读取buff0和读取buff1 ok
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            state <= 3;  //处理第一帧无数据可读的情况
        else if(read_enable==2'b11 && state==3)  //启动 不用管
            state <= 1;  //表示启动成功
        else if(state==1 && avalon_read_data==1)    
            state <= 0;  //表示写入buff1 读取buff0
        else if(state==0 && avalon_read_data==2)
            state <= 1;  //表示写入buff0 读取buff1
        else
            state <= state;  // 其余情况保持不变
    end

endmodule

