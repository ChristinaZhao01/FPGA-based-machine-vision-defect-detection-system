module ov7670_data_16rgb565(
	input				clk				,//输入为摄像头输入时钟pclk 25MHz
	input				rst_n			,//系统复位
	input				vsync			,//场同步信号
	input				href			,//行同步信号
	input	[7:0]		din				,//ov7670摄像头数据输入
	input				init_done		,//ov7670摄像头初始化结束标志
	output	reg[15:0]	data_rgb565		,//转换成16位RGB565图像数据
	output	reg			data_rgb565_vld	 //16位RGB565图像数据有效标志
	);
	reg			vsync_r			;
	reg			href_r			;
	reg	[7:0]	din_r			;
	reg			vsync_r_ff0		;
	reg			vsync_r_ff1		;
	reg			data_start		;
	reg	[3:0]	frame_cnt		;
	reg			frame_vaild		;
	wire		vsync_r_pos		;
	reg			data_en			;
	
	//外部信号打一拍
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			vsync_r <= 0;
			href_r <= 0;
			din_r <= 8'd0;
		end
		else begin
			vsync_r <= vsync;
			href_r <= href;
			din_r <= din;
		end
	end
 
	//场同步信号上升沿检测
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			vsync_r_ff0 <= 0;
			vsync_r_ff1 <= 0;
		end
		else begin
			vsync_r_ff0 <= vsync_r;
			vsync_r_ff1 <= vsync_r_ff0;
		end
	end
	assign vsync_r_pos = (vsync_r_ff0 && ~vsync_r_ff1);
 
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data_start <= 0;
		end
		else if (init_done) begin
			data_start <= 1;
		end
		else begin
			data_start <= data_start;
		end
	end
 
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			frame_cnt <= 0;
		end
		else if (data_start && frame_vaild==0 && vsync_r_pos) begin
			frame_cnt <= frame_cnt + 1'b1;
		end
		else begin
			frame_cnt <= frame_cnt;
		end
	end
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			frame_vaild <= 0;
		end
		else if (frame_cnt >= 10) begin
			frame_vaild <= 1;
		end
		else begin
			frame_vaild <= frame_vaild;
		end
	end
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data_en <= 0;
		end
		else if (href_r && frame_vaild) begin
			data_en <= ~data_en;
		end
		else begin
			data_en <= 0;
		end
	end
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data_rgb565_vld <= 0;
		end
		else if (data_en) begin
			data_rgb565_vld <= 1;
		end
		else begin
			data_rgb565_vld <= 0;
		end
	end
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data_rgb565 <= 16'd0;
		end
		else if (data_en) begin
			data_rgb565 <= {data_rgb565[15:8],din_r};
		end
		else begin
			data_rgb565 <= {din_r,data_rgb565[7:0]};
		end
	end
 
endmodule