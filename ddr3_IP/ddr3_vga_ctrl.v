// 此模块用来完成config_bus的功能，即PS通过此模块给寄存器写入值或者读取寄存器的值
module ddr3_vga_ctrl   (
                            //clock
                            clk, //50MHZ
                            rst_n,
                            // avalon协议 方便hps写入数据和读取数据
                            avalon_write,
                            avalon_read,
                            avalon_addr,
                            avalon_read_data,
                            avalon_write_data,
                            // else
                            state,  //标记现在读取的是哪个buff
                            buffer_base,
                            img_size,
                            start_status,
                            buffer_status,
                            img_end  //一帧图像的结束
                       );


// 信号流向
input   clk;
input   rst_n;
input   [1:0] state;  // 确定目前要被清零的寄存器位数
input   img_end;
input   avalon_write;
input   avalon_read;
input   [3:0] avalon_addr;
input   [31:0] avalon_write_data;
output  reg [31:0] avalon_read_data;
// 寄存器定义 详情见word
output reg [31:0] buffer_base;
output reg [31:0] img_size;
output reg [31:0] start_status;
output reg [31:0] buffer_status;


// 模块的逻辑功能部分：
// PS写入数据到寄存器
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n) begin
            buffer_base <= 0;
            img_size <= 0;
            start_status <= 0;
            buffer_status <= 2; 
        end
        else if(buffer_status[1:0]==2'b11 && state==3)      //表示第一次启动程序 无数据但是要表现出读出了数据 手动清零的过程
            buffer_status <= 1;   //pl端直接开始读取buffer0 
        else if(!state && img_end)     // 两个buff的手动清零 分为两种 需要分别考虑 区分开来 貌似必须得等写了3一起清除掉
            buffer_status[0] <= 0;
        else if(state==1 && img_end)  //确定已经进入判断条件并且一帧图像传输完毕
            buffer_status[1] <= 0;
        else if(avalon_write) begin  //写信号使能
            case(avalon_addr)
                4'b0:buffer_base <= avalon_write_data;
                4'b1:img_size <= avalon_write_data;
                4'd2:start_status <= avalon_write_data;
                4'd3:buffer_status <= avalon_write_data;
                default begin
                buffer_base <= buffer_base;
                img_size <= img_size;
                start_status <= start_status;
                buffer_status <= buffer_status;
                end
            endcase
        end
        else begin
            buffer_base <= buffer_base;
            img_size <= img_size;
            start_status <= start_status;
            buffer_status <= buffer_status;  
        end
    end


// PS读取寄存器的值
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            avalon_read_data <= 0;
        else if(avalon_read) begin
            case(avalon_addr)
                4'b0:avalon_read_data <= buffer_base;
                4'b1:avalon_read_data <= img_size;
                4'd2:avalon_read_data <= start_status;
                4'd3:avalon_read_data <= buffer_status;
                default begin
                    avalon_read_data <= 0;
                end
            endcase
        end
        else begin
            avalon_read_data = 0;
        end
    end


endmodule

