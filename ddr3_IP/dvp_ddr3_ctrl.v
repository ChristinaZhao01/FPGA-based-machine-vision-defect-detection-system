// 此模块用来完成config_bus的功能，即PS通过此模块给寄存器写入值或者读取寄存器的值
module dvp_ddr3_ctrl   (
                            //clock
                            clk, //50MHZ
                            rst_n,
                            // avalon协议 方便hps写入数据
                            avalon_write,
                            avalon_read,
                            avalon_addr,
                            avalon_read_data,
                            avalon_write_data,
                            // else
                            img_end,//一帧图像传输完成标志
                            buffer_base,
                            img_size,
                            start_status,
                            capture_en
                       );


// 信号流向
input   clk;
input   rst_n;
input   avalon_write;
input   avalon_read;
input   [3:0] avalon_addr;
input   [31:0] avalon_write_data;
output  reg [31:0] avalon_read_data;
input   img_end;  //一帧图像传输完成标志
// 寄存器定义 详情见word
output reg [31:0] buffer_base;
output reg [31:0] img_size;
output reg [31:0] start_status;
output reg [31:0] capture_en;


// 模块的逻辑功能部分：
// PS写入数据到寄存器
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n) begin
            buffer_base <= 0;
            img_size <= 0;
            start_status <= 0;
            capture_en <= 0;
        end
        else if(img_end) begin
            capture_en[0] <= 0;      //PL端采集完一帧图像之后自动置0，当PS端处理完一帧图像之后再重新置1
        end
        else if(avalon_write) begin  //写信号使能，使用avalon协议，读取寄存器地址，并通过avalon写数据信号使主机即HPS端对从机即PL端的IP核寄存器进行配置
            case(avalon_addr)
                4'b0:buffer_base <= avalon_write_data;
                4'b1:img_size <= avalon_write_data;
                4'd2:start_status <= avalon_write_data;
                4'd3:capture_en <= avalon_write_data;
                default begin        
                buffer_base <= buffer_base;
                img_size <= img_size;
                start_status <= start_status;
                capture_en <= capture_en;
                end
            endcase
        end
        else begin
            buffer_base <= buffer_base;
            img_size <= img_size;
            start_status <= start_status;
            capture_en <= capture_en;    
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
                4'd3:avalon_read_data <= capture_en;
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

