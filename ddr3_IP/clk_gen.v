// 此模块用来给 vga_intf模块提供分频时钟 可以根据实际情况酌情修改 
module clk_gen  (
                    clk,
                    rst_n,
                    // 给vga时序输出模块的驱动时钟
                    vga_clk  //5MHZ
                );


// 信号流向
input clk;
input rst_n;
output reg vga_clk;


// 中间变量
reg [25:0] cnt;  //用来计数 方便分频 最大计数50/000/000


// 随着clk进行计数 最大计数50/000/000次 超过则清零
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            cnt <= 0;
        else if(cnt==26'd50_000_000)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end


// 根据cnt的数值 进行判断  得到分频后的时钟 vga_clk
always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            vga_clk <= 0;
        else if(cnt % 5 == 0 && cnt!= 0)
            vga_clk <= ~vga_clk;
        else 
            vga_clk <= vga_clk;
    end


endmodule