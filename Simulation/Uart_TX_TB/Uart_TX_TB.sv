//=============================================================================
//
//Module Name:              Uart_TX_TB
//Department:               Xidian Unversity
//Function Description:     串口发送测试模块
//
//------------------------------------------------------------------------------
//
//Version       Design      Coding      Simulate    Review      Rel Date
//V1.0          Verdverd    Verdvana    Verdvana    Verdvana    2020-6-1
//
//------------------------------------------------------------------------------
//
//Version       Modified History
//V1.0
//
//=============================================================================

`timescale  1ns/1ps

module Uart_TX_TB;

    logic           clk;
    logic           rst_n;

    logic           send_en;
    logic   [8:0]   data_in;

    logic           tx;
    logic           tx_done;

    parameter       PERIOD  = 20,       //时钟周期（单位ns）
                    SYS_CLK = 50_000_000,//时钟频率（单位Hz）
                    BAUD    = 115200;   //波特率   



    Uart_TX#(
        .SYS_CLK    (SYS_CLK    ),   //时钟频率（单位Hz）
        .BAUD       (BAUD       ),   //波特率
        .DATA_BIT   (6          ),   //数据位数
        .PARITY_BIT (2'b01      ),   //校验位
        .STOP_BIT   (0          )    //停止位
    )u_Uart_TX(.*);

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
        send_en = 0;
        data_in = '0;
    end
    endtask

    initial begin
        task_rst;
        task_init;
        #(PERIOD/2);
        #(PERIOD*50);

        send_en = 1;
        data_in = 9'h1a;
        
        #(PERIOD);
        send_en = 0;        


        #200000;
        

        #2000;
        $finish();

    end    


	//=========================================================
    //后仿真
	`ifdef POST_SIM
    //=========================================================
    //back annotate the SDF file
    initial begin
        $sdf_annotate(	"../synthesis/mapped/Uart_TX_TB.sdf",
                        Uart_TX_TB.u_Uart_TX,,,
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