//=============================================================================
//
//Module Name:              Uart_RX_TB
//Department:               Xidian Unversity
//Function Description:     串口接收模块测试
//
//------------------------------------------------------------------------------
//
//Version       Design      Coding      Simulate    Review      Rel Date
//V1.0          Verdverd    Verdvana    Verdvana    Verdvana    2020-4-24
//
//------------------------------------------------------------------------------
//
//Version       Modified History
//V1.0
//
//=============================================================================

`timescale  1ns/1ps

module Uart_RX_TB;

    logic       clk;
    logic       rst_n;

    logic       rx;

    logic [8:0] data_out;
    logic       jitter_error;
    logic       parity_error;
    logic       rx_done;

    parameter           PERIOD  = 20,       //时钟周期（单位ns）
                        SYS_CLK = 50_000_000,//时钟频率（单位Hz）
                        BAUD    = 115200,   //波特率    
                        BPS =   PERIOD*SYS_CLK/BAUD; //波特率周期

    Uart_RX#(
        .SYS_CLK    (SYS_CLK    ),   //时钟频率（单位Hz）
        .BAUD       (BAUD       ),   //波特率
        .DATA_BIT   (8          ),   //数据位数
        .PARITY_BIT (2'b00      ),   //校验位
        .STOP_BIT   (0          )    //停止位
    )u_Uart_RX(.*);

    //==========================================================================
    //时钟创建
    initial begin
		clk = 0;
		forever #(PERIOD/2)
		clk = ~clk;
	end

    //==========================================================================
    //任务创建
	task task_rst;          //复位任务
	begin
		rst_n <= 1;
		#PERIOD rst_n <= 0;
		repeat(2)@(negedge clk);
		rst_n <= 1;
	end
	endtask

    task task_init;         //初始化任务
    begin
        rx = 1;
    end
    endtask

    task task_tra(input [7:0] data_in);          //正常传输模式
    begin
        rx = 0;             //起始位
        #BPS;
        rx = data_in[0];    //
        #BPS;
        rx = data_in[1];    //
        #BPS;
        rx = data_in[2];    //
        #BPS;
        rx = data_in[3];    //
        #BPS;
        rx = data_in[4];    //
        #BPS;
        rx = data_in[5];    //
        #BPS;
        rx = data_in[6];    //
        #BPS;
        rx = data_in[7];    //
        #BPS;
        rx = 1;             //停止位
        #BPS;
    end
    endtask

    task task_jit(input [7:0] data_in);       //有抖动传输模式
    begin
        rx = 0;             //起始位
        #BPS;
        rx = data_in[0];    //
        #BPS;

        rx = data_in[1];    //
        #(BPS/8);
        rx = 0;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 1;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 0;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 1;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 0;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 1;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 0;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = 1;
        #(BPS/32);
        rx = data_in[1];
        #(BPS/32);
        rx = data_in[1];
        #(BPS/4);
        rx = data_in[2];    //
        #BPS;
        rx = data_in[3];    //
        #BPS;
        rx = data_in[4];    //
        #BPS;
        rx = data_in[5];    //
        #BPS;
        rx = data_in[6];    //
        #BPS;
        rx = data_in[7];    //
        #BPS;
        rx = 1;             //停止位
        #BPS;
    end
    endtask

    initial begin
        task_rst;
        task_init;
        #(PERIOD/2);
        #(PERIOD*10);

        task_tra(8'b01011111);

        task_tra(8'b11000011);

        task_tra(8'b10101010);

        task_jit(8'b00101101);
        
        task_tra(8'b10101010);

        #2000;
        $finish();

    end


	//=========================================================
    //后仿真
	`ifdef POST_SIM
    //=========================================================
    //back annotate the SDF file
    initial begin
        $sdf_annotate(	"../synthesis/mapped/SDRAM_Init_TB.sdf",
                        Uart_RX_TB.u_Uart_RX,,,
						"TYPICAL",
						"1:1:1",
						"FROM_MTM");
		$display("\033[31;5m back annotate \033[0m",`__FILE__,`__LINE__);
    end
	`endif

    //=========================================================
    //打开VCD+文件记录
    initial begin
        $vcdpluson();
    end

endmodule