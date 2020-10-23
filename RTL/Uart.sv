//=============================================================================
//
//Module Name:              Uart
//Department:               Xidian Unversity
//Function Description:     Uart串口发送接受顶层
//
//------------------------------------------------------------------------------
//
//Version       Design      Coding      Simulate    Review      Rel Date
//V1.0          Verdverd    Verdvana    Verdvana    Verdvana    2020-10-17
//
//------------------------------------------------------------------------------
//
//Version       Modified History
//V1.0          Uart接受发送。
//
//=============================================================================

`timescale  1ns/1ps

module Uart#(
    parameter           SYS_CLK = 50_000_000,       //系统时钟频率（Hz）
                        BAUD        = 115200,       //波特率
                        DATA_BIT    = 8,            //数据位
                        PARITY_BIT  = 2'b00,        //校验，00：none；01：odd；10：even
                        STOP_BIT    = 0             //停止位，0为一位停止位；1为两位停止位
)(
    input  logic        clk,                        //系统时钟
    input  logic        rst_n,                      //异步复位

    input  logic        send_en,                    //开始发送

    input  logic [8:0]  data_in,                    //发送数据
    output logic [8:0]  data_out,                   //接收数据

    output logic        tx_done,                    //发送完成
    output logic        rx_done,                    //接收完成

    output logic        jitter_error,               //接收数据时抖动错误
    output logic        parity_error,               //接收数据时奇偶校验错误

    output logic        tx,                         //Uart发送接口
    input  logic        rx                          //Uart接收接口
);


    Uart_TX#(
        .SYS_CLK    (SYS_CLK    ),   //时钟频率（单位Hz）
        .BAUD       (BAUD       ),   //波特率
        .DATA_BIT   (DATA_BIT   ),   //数据位数
        .PARITY_BIT (PARITY_BIT ),   //校验位
        .STOP_BIT   (STOP_BIT   )    //停止位
    )u_Uart_TX(
        .*
    );

    Uart_RX#(
        .SYS_CLK    (SYS_CLK    ),   //时钟频率（单位Hz）
        .BAUD       (BAUD       ),   //波特率
        .DATA_BIT   (DATA_BIT   ),   //数据位数
        .PARITY_BIT (PARITY_BIT ),   //校验位
        .STOP_BIT   (STOP_BIT   )    //停止位
    )u_Uart_RX(
        .*
);

endmodule