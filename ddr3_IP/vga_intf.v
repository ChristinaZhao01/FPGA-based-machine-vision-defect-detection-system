// 此模块用来将ddr3中读取的数据 通过VGA时序进行输出
module vga_intf  (
                    // clock
                    vga_clk,  //5MHZ 应该还可以改变
                    rst_n,
                    // vga 时序
                    vga_de, //
                    vga_vsync, // 帧信号
                    fifo_read,  // 从fifo中读数据的有效信号 
                    fifo_usedw,  // fifo可读深度 用来处理和判断何时开始从fifo读取数据
                    img_end,     //一帧图像的结束
                    read_enable,  //用寄存器3的低两位 当成标志位 用来判断
                    ip_enable,   // ip核是否开始工作 寄存器2
                    state,      //输入的标志位 判断buffer的状态
                    vga_hsync, // 行有效信号 保留信号 用来形成vga_de
                    vga_rgb, //rgb输入
                    rgb_reg, //rbg输入 寄存器
                    burst_num //作为标志位输入
                  );


// 信号流向
input vga_clk;
input rst_n; 
output vga_de;
output reg vga_vsync;  //帧有效信号 高有效
output fifo_read;
input [9:0] fifo_usedw;
output reg img_end;  
input [1:0] read_enable;   // 寄存器的低两位 用来判断是否某时刻某个buff可读 
input ip_enable;     // ip核是否开始工作
input [1:0] state;  //输入的标志位
output reg vga_hsync;   //行有效信号 作为保留信号处理 高有效
input [23:0] rgb_reg;
output reg[23:0] vga_rgb;
input [10:0] burst_num;  //用作标志位输入


// 一些参数定义 //27 75 400 425
parameter vsync_time = 346; //以周期为单位 4 12 332 346  图像有效时间可能略长于12-332 导致346也会往后推移 补充成360好了
parameter hsync_time = 479; //以周期为单位 29 51 451 479 


// 一些中间变量
wire de_start;  //为高电平表示一行数据的传输即将开始
// reg  vsync_visual; //vsync图像有效的区域
// reg  hsync_visual; //hsync图像有效的区域
reg [8:0] de_counter;  //用来对一行中的像素点计数 最大400
reg [8:0] de_num;  //用来行计数 最大320
// reg [2:0] vga_state;  //用来表征vga_vsync的状态 0：低电平 1：高却无效传输数据前  2：有效传输数据阶段 3:高却无效传输后
reg [8:0] cnt_h;  //行计数 最多346
reg [8:0] cnt_w;  //列计数 最多479
wire hsync_vld;  //表示行有效信号处于有效阶段
wire vsync_vld;  //表示帧有效信号处于有效阶段
reg [3:0] clk_cnt;  //大概15左右 用来结束帧信号高电平
reg [16:0] rgb_num; //用来测试
wire de_start0; //表示第一次触发 很重要 对于对齐时序
reg fifo_read_d0; //打一拍方便同步数据


// // 变量的赋值处理
// assign hsync_vld = cnt_w>=52 && cnt_w<=451;
// assign vsync_vld = cnt_h>=13 && cnt_h<=332;

// 有效信号 表示帧有效和行有效
assign hsync_vld = de_counter!=0 && (de_num>=1 && de_num<=320);  //已经启动 并且de_num处于有效范围
assign vsync_vld = cnt_h>=13 && !img_end;  //大于13的时间点 并且img_end还未置1  可能需要修改给个cnt_h的值作为结束 

// 启动信号 用于启动不同的情况 很重要 若处理不当 程序会卡死 此处的处理是必须先搞定0 才能进行正常de_start 否则de_num一直为0等待
assign de_start =(fifo_usedw>=400 && de_counter==0 && de_num<320 && de_num>=1 && vsync_vld && cnt_w==51); //表示数据足够可以开启一行传输且恰好在52的时间点
assign de_start0 =(fifo_usedw>=400 && de_counter==0 && de_num==0 && vsync_vld && cnt_w==51 && cnt_h==14); //很重要

// 同步信号 同步数据和有效信号 符合vga的时序
assign fifo_read = hsync_vld && vsync_vld;   //跟vga_de同步 确保数据和vga_de同步
assign vga_de = fifo_read_d0; //这两同时出现表示出现高电平



// 模块的逻辑功能实现部分：
// 对rgb_reg打拍 实现通过vga_clk来同步控制vga_rgb的输出 无有效信号时即为0
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      vga_rgb <= 0;
    else if(fifo_read)
      vga_rgb <= rgb_reg;
    else
      vga_rgb <= 0;
  end


// 对fifo_read信号进行打拍 同步数据
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      fifo_read_d0 <= 0;
    else
      fifo_read_d0 <= fifo_read;
  end


// rgb_num 用来测试总的数据量
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      rgb_num <= 0;
    else if(fifo_read)
      rgb_num <= rgb_num  + 1;
    else
      rgb_num <= rgb_num;
  end


// de_counter 行计数变量的处理 数据足够的时候开始从fifo读出数据然后传输行数据 可读的时候递减
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      de_counter <= 0;
    else if(de_start || de_start0)
      de_counter <= 400;
    else if(fifo_read)
      de_counter <= de_counter - 1;
    else
      de_counter <= de_counter; //每次400个计数完 保持在0 等待下一次de_start
  end


// 列计数变量de_num的处理 每传输完一列递增 及时清零
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      de_num <= 0;
    else if(de_start || de_start0) //确保在有效范围内的de_start才能让计数变量递增
      de_num <= de_num + 1;
    else if(img_end) //时钟不一致会导致漏采 如此操作不会漏采
      de_num <= 0; 
    else
      de_num <= de_num;
  end


// assign img_end = ((de_num==320)&&(de_counter==0))? 1:0; //同时满足表示一帧图像读取完成
// Img_end 通过always 语句块赋值 方便控制
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      img_end <= 0;
    else if(!de_num)  //用这个做标志位 一定会保证img_end在合适的时间被清零掉
      img_end <= 0;
    else if(de_num==320 && de_counter==1 && fifo_read) //跟之前的img_end在同一时间为1
      img_end <= 1;
    else
      img_end <= img_end;
  end


//行计数的处理  479 无关
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      cnt_w <= 0;
    else if(cnt_w==479)
      cnt_w <= 0;
    else
      cnt_w <= cnt_w + 1;
  end


//列计数的处理  346
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      cnt_h <= 0;
    else if(cnt_w==479 && cnt_h==346)
      cnt_h <= 0;
    else if(cnt_w==479)
      cnt_h <= cnt_h + 1;
    else
      cnt_h <= cnt_h;
  end


// vga_hsync的处理 无关
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      vga_hsync <= 0;
    else if(cnt_w>=29 && cnt_w<=479)
      vga_hsync <= 1;
    else
      vga_hsync <= 0;
  end


// vga_vsync的处理
always @(posedge vga_clk or negedge rst_n)
  begin
    if(!rst_n)
      vga_vsync <= 0;
    else if(cnt_h>=4 && cnt_h<=346)
      vga_vsync <= 1;
    else 
      vga_vsync <= 0;
  end


endmodule