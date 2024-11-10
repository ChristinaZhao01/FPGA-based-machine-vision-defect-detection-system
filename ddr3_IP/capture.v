// 该模块实现了dvp时序的解析 并且每八位地将数据输出（写入到fifo)
module capture (
                            //reset 
                            rst_n,
                            //dvp
                            dvp_data,
                            dvp_href,
                            dvp_pclk, //12.5MHZ
                            dvp_vsync,
                            // else
                            capture_enable,
                            ip_enable,
                            my_data,
                            fifo_write,
                            img_start
               );


// 信号流向
input   rst_n;
input   [7:0] dvp_data;
input   dvp_href;        //行有效信号
input   dvp_pclk;				 //dvp时序时钟节拍信号
input   dvp_vsync;       //下降沿有效，对该帧信号进行读取
input   capture_enable;  // capture_en寄存器的最低位 用来表征信号可以开始采集信号的标志位 为1表示可以开始采集，表示上一帧信号数据已经采集传输完成
input   ip_enable;       // start_status寄存器的最低位 表示ip核是否已经开始工作
output  [7:0] my_data;   // dvp_data输出的值    
output  reg fifo_write;  //fifo的写使能信号，通过FIFO对数据进行整合，因为后面DDR3的时钟是快的，24位数据整合有问题
output  img_start;   // 表示一帧图片开始传输 

assign my_data = dvp_data;  // 将dvp_data输出


// 中间变量 用来辅助逻辑功能的实现
wire vsync_down;  //用来表征帧有效信号的下降沿
reg vsync_en;     //表示帧有效信号下降沿出现但是还未出现上升沿


// 信号打拍 方便边沿检测 边沿检测用来实现找到一帧图像的起始
reg vsync_d0;
reg vsync_en_d0;


// 模块的主要逻辑
// 信号打拍 方便边沿检测
always @(posedge dvp_pclk or negedge rst_n)
    begin
        if(!rst_n) begin
            vsync_d0 = 0;       //为什么不用非阻塞赋值？
        end
        else begin
            vsync_d0 <= dvp_vsync;
        end     
    end

//检测dvp_vsync由高变低的下降沿，检测到则vsync_down置1
assign vsync_down = ~dvp_vsync && vsync_d0;   //vsync_d0保存的是帧检测信号的上一个时钟节拍的状态


// vsync_en的处理 下降沿来了置1 上升沿来了置0 其余情况不变 如果为1表示在一帧图像的传输过程中
always @(posedge dvp_pclk or negedge rst_n)
    begin
        if(!rst_n)
            vsync_en <= 0;
        else if(vsync_down && ip_enable && capture_enable)
            vsync_en <= 1;
        else if(capture_enable==0 | ip_enable==0)
            vsync_en <= 0;
        else 
            vsync_en <= vsync_en;
    end


// vsync_en打拍 检测一帧图像的起始点 即vsync_en信号的上升沿
always @(posedge dvp_pclk or negedge rst_n)
    begin
        if(!rst_n)
            vsync_en_d0 <= 0;
        else 
            vsync_en_d0 <= vsync_en;
    end

assign img_start = ~vsync_en_d0 && vsync_en;


// 将数据写入到fifo中 即处理fifo写使能信号
always @(posedge dvp_pclk or negedge rst_n)
    begin
        if(!rst_n)
            fifo_write <= 0;
        else if(capture_enable && ip_enable && vsync_en)
            fifo_write <= dvp_href;     //每行数据开始传输时置1，该行数据传输完毕时会有节拍间隔（dvp时序规定）
        else 
            fifo_write <= 0;
    end


endmodule 




