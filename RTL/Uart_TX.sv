//=============================================================================
//
//Module Name:              Uart_TX
//Department:               Xidian Unversity
//Function Description:     Uart串口发送模块
//
//------------------------------------------------------------------------------
//
//Version       Design      Coding      Simulate    Review      Rel Date
//V1.0          Verdverd    Verdvana    Verdvana    Verdvana    2020-6-1
//V1.1          Verdverd    Verdvana    Verdvana    Verdvana    2020-10-19
//
//------------------------------------------------------------------------------
//
//Version       Modified History
//V1.0          Uart发送；
//              波特率可定制。
//V1.1          数据位数可定制；
//              加入校验位；
//              停止位数可定制。           
//
//=============================================================================

`timescale  1ns/1ps

module Uart_TX#(
    parameter           SYS_CLK     = 50_000_000,   //时钟频率（单位Hz）
                        BAUD        = 115200,       //波特率
                        DATA_BIT    = 8,            //数据位，支持5-9数据位
                        PARITY_BIT  = 2'b00,        //校验，00：none；01：odd；10：even
                        STOP_BIT    = 0             //停止位，0为一位停止位；1为两位停止位
)(
    input  logic        clk,                    //时钟
    input  logic        rst_n,                  //异步复位

    input  logic        send_en,                //发送使能
    input  logic [8:0]  data_in,                //并行信号输入

    output logic        tx,                     //串行数据输出
    output logic        tx_done                 //接收字节完成
);

    //==========================================================================
    //参数声明
    parameter           TCO =   1,              //寄存器延迟
                        BPS =   SYS_CLK/BAUD-1; //波特率计数值


    logic               en;                     //使能
    logic [8:0]         data_r;                 //数据寄存
    
    logic [15:0]        bps_cnt;                //波特率时钟产生计数器    
    logic               bps_clk;                //波特率时钟

    logic               odd_parity;             //奇数校验
    logic               even_parity;            //偶数校验

    //==========================================================================
    //状态机状态声明
    enum logic [3:0]{
        IDLE,
        START,
        DATA_0,
        DATA_1,
        DATA_2,
        DATA_3,
        DATA_4,
        DATA_5,
        DATA_6,
        DATA_7,
        DATA_8,
        PARITY,
        STOP_0,
        STOP_1
    }state,next_state; 

    //==========================================================================
    //输入数据寄存
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_r      <= #TCO '0;
        else if(send_en)
            data_r      <= #TCO data_in;
        else
            data_r      <= #TCO data_r;
    end

    //==========================================================================
    //波特率时钟产生计数
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            bps_cnt     <= #TCO '0;
        else if(en)
            if(bps_cnt==BPS)
                bps_cnt <= #TCO '0;
            else
                bps_cnt <= #TCO bps_cnt + 1;
        else
            bps_cnt     <= #TCO '0;
    end


    //==========================================================================
    //生成波特率时钟
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            bps_clk     <= #TCO '0;
        else if(bps_cnt==(BPS-1))
            bps_clk     <= #TCO '1;
        else
            bps_clk     <= #TCO '0;
    end

    //==========================================================================
    //奇偶校验
    always_comb begin
        case(DATA_BIT)
            5:
                even_parity = ^data_r[4:0];
            6:
                even_parity = ^data_r[5:0];
            7:
                even_parity = ^data_r[6:0];
            8:
                even_parity = ^data_r[7:0];
            9:
                even_parity = ^data_r[8:0];
            default:
                even_parity = '0;
        endcase
    end

    assign  odd_parity = ~even_parity;


    //==========================================================================
    //状态跳转
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            state   <= #TCO IDLE;
        else
            state   <= #TCO next_state;
    end

    always_comb begin
        case(state)
            IDLE:
                if(en)
                    next_state  = START;
                else
                    next_state  = IDLE;
            START:
                if(bps_clk)
                    next_state  = DATA_0;
                else
                    next_state  = START;
            DATA_0:
                if(bps_clk)
                    next_state  = DATA_1;
                else
                    next_state  = DATA_0;
            DATA_1:
                if(bps_clk)
                    next_state  = DATA_2;
                else
                    next_state  = DATA_1;
            DATA_2:
                if(bps_clk)
                    next_state  = DATA_3;
                else
                    next_state  = DATA_2;
            DATA_3:
                if(bps_clk)
                    next_state  = DATA_4;
                else
                    next_state  = DATA_3;
            DATA_4:
                if(bps_clk)
                    if(DATA_BIT==5)
                        if(PARITY_BIT=='0)
                            next_state  = STOP_0;
                        else
                            next_state  = PARITY;
                    else
                        next_state  = DATA_5;
                else
                    next_state  = DATA_4;
            DATA_5:
                if(bps_clk)
                    if(DATA_BIT==6)
                        if(PARITY_BIT=='0)
                            if(STOP_BIT)
                                next_state  = STOP_0;
                            else
                                next_state  = STOP_1;
                        else
                            next_state  = PARITY;
                    else
                        next_state  = DATA_6;
                else
                    next_state  = DATA_5;
            DATA_6:
                if(bps_clk)
                    if(DATA_BIT==7)
                        if(PARITY_BIT=='0)
                            if(STOP_BIT)
                                next_state  = STOP_0;
                            else
                                next_state  = STOP_1;
                        else
                            next_state  = PARITY;
                    else
                        next_state  = DATA_7;
                else
                    next_state  = DATA_6;
            DATA_7:
                if(bps_clk)
                    if(DATA_BIT==8)
                        if(PARITY_BIT=='0)
                            if(STOP_BIT)
                                next_state  = STOP_0;
                            else
                                next_state  = STOP_1;
                        else
                            next_state  = PARITY;
                    else
                        next_state  = DATA_8;
                else
                    next_state  = DATA_7;
            DATA_8:
                if(bps_clk)
                    if(PARITY_BIT=='0)
                        if(STOP_BIT)
                            next_state  = STOP_0;
                        else
                            next_state  = STOP_1;
                    else
                        next_state  = PARITY;
                else
                    next_state  = DATA_8;
            PARITY:
                if(bps_clk)
                    if(STOP_BIT)
                        next_state  = STOP_0;
                    else
                        next_state  = STOP_1;
                else
                    next_state  = PARITY;
            STOP_0:
                if(bps_clk)
                    next_state  = STOP_1;
                else
                    next_state  = STOP_0;
            STOP_1:
                if(bps_clk)
                    next_state  = IDLE;
                else
                    next_state  = STOP_1;              
        endcase
    end


    //==========================================================================
    //使能
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            en          <= #TCO '0;
        else if(send_en)
            en          <= #TCO '1;
        else if((state==STOP_1)&&(bps_clk))
            en          <= #TCO '0;
        else
            en          <= #TCO en;
    end

    //==========================================================================
    //生成发送完成信号
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            tx_done     <= #TCO '0;
        else if((state==STOP_1)&&(bps_clk))
            tx_done     <= #TCO '1;
        else
            tx_done     <= #TCO '0;
    end

    //==========================================================================
    //输出
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            tx  <= #TCO '0;
        else
            case(state)
                IDLE,STOP_0,STOP_1:
                    tx <= #TCO '1;
                START:
                    tx <= #TCO '0;
                DATA_0:
                    tx <= #TCO data_r[0];
                DATA_1:
                    tx <= #TCO data_r[1];
                DATA_2:
                    tx <= #TCO data_r[2];
                DATA_3:
                    tx <= #TCO data_r[3];
                DATA_4:
                    tx <= #TCO data_r[4];
                DATA_5:
                    tx <= #TCO data_r[5];
                DATA_6:
                    tx <= #TCO data_r[6];
                DATA_7:
                    tx <= #TCO data_r[7];
                DATA_8:
                    tx <= #TCO data_r[8];
                PARITY:
                    if(PARITY_BIT==2'b01)
                        tx <= #TCO odd_parity;
                    else if(PARITY_BIT==2'b10)
                        tx <= #TCO even_parity;
                    else
                        tx <= #TCO '0;
                default:
                    tx <= #TCO '1;
            endcase
    end

endmodule