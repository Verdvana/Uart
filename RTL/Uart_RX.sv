//=============================================================================
//
//Module Name:              Uart_RX
//Department:               Xidian Unversity
//Function Description:     Uart串口接收模块
//
//------------------------------------------------------------------------------
//
//Version       Design      Coding      Simulate    Review      Rel Date
//V1.0          Verdverd    Verdvana    Verdvana    Verdvana    2020-4-24
//V1.1          Verdverd    Verdvana    Verdvana    Verdvana    2020-10-20
//V1.2          Verdverd    Verdvana    Verdvana    Verdvana    2020-10-23
//
//------------------------------------------------------------------------------
//
//Version       Modified History
//V1.0          Uart接收；
//              波特率可定制。
//V1.1          数据位数可定制；
//              加入校验位；
//              停止位数可定制。       
//V1.2          缩短STOP状态以消除波特率累积误差
//
//=============================================================================

`timescale  1ns/1ps

module Uart_RX#(
    parameter           SYS_CLK     = 50_000_000,   //时钟频率（单位Hz）
                        BAUD        = 115200,       //波特率
                        DATA_BIT    = 8,            //数据位，支持5-9数据位
                        PARITY_BIT  = 2'b00,        //校验，00：none；01：odd；10：even
                        STOP_BIT    = 0             //停止位，0为一位停止位；1为两位停止位
)(
    input  logic        clk,                    //时钟
    input  logic        rst_n,                  //异步复位

    input  logic        rx,                     //串行信号输入

    output logic [8:0]  data_out,               //并行数据输出
    output logic        jitter_error,           //数据抖动错误
    output logic        parity_error,           //奇偶校验错误
    output logic        rx_done                 //接收字节完成
);

    //==========================================================================
    //参数声明
    parameter           TCO =   1,                  //寄存器延迟
                        BPS =   SYS_CLK/BAUD/16 -1; //波特率计数值

    //==========================================================================
    //信号声明
    logic [1:0]         rx_r;                   //串行输入信号同步寄存器
    logic [1:0]         rx_buf;                 //下降沿判断buf
    logic               rx_fall;                //下降沿判断标志位，下降沿出现保持一个周期高电平

    logic               en;                     //使能

    logic [15:0]        bps_cnt;                //波特率时钟产生计数器    
    logic               bps_clk;                //波特率时钟

    logic [3:0]         accu_cnt;               //16次累计计数器

    logic [3:0]         start_bit;              //起始位累加
    logic [3:0]         stop_bit    [2];        //停止位累加
    logic [3:0]         parity_bit;             //校验位累加
    logic [3:0]         data_byte   [9];        //每一bit数据累加

    logic [8:0]         data_accu;              //累计后的数据
    logic               parity_accu;            //累计后的校验位
    logic               stop_accu;              //累计后的停止位

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
    //两级同步消除亚稳态
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            rx_r        <= #TCO '0;
        else
            rx_r        <= #TCO {rx_r[0],rx};
    end

    //==========================================================================
    //检测下降沿
    always_ff@(posedge clk)begin
        rx_buf          <= #TCO {rx_buf[0],rx_r[1]};
    end

    assign rx_fall  = rx_buf[1] && !rx_buf[0];


    //==========================================================================
    //使能
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            en          <= #TCO '0;
        else if(rx_fall)
            en          <= #TCO '1;
        else if((state==STOP_1)&&stop_accu)
            en          <= #TCO '0;
        else
            en          <= #TCO en;
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
    //累加计数器
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            accu_cnt    <= #TCO '0;
        else
            case(state)
                IDLE:
                    accu_cnt    <= #TCO '0;
                default:
                    if(bps_clk)
                        accu_cnt    <= #TCO accu_cnt + 1;
                    else
                        accu_cnt    <= #TCO accu_cnt;
            endcase
    end

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
                if(bps_clk && &accu_cnt)
                    next_state  = DATA_0;
                else
                    next_state  = START;
            DATA_0:
                if(bps_clk && &accu_cnt)
                    next_state  = DATA_1;
                else
                    next_state  = DATA_0;
            DATA_1:
                if(bps_clk && &accu_cnt)
                    next_state  = DATA_2;
                else
                    next_state  = DATA_1;
            DATA_2:
                if(bps_clk && &accu_cnt)
                    next_state  = DATA_3;
                else
                    next_state  = DATA_2;
            DATA_3:
                if(bps_clk && &accu_cnt)
                    next_state  = DATA_4;
                else
                    next_state  = DATA_3;
            DATA_4:
                if(bps_clk && &accu_cnt)
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
                if(bps_clk && &accu_cnt)
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
                if(bps_clk && &accu_cnt)
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
                if(bps_clk && &accu_cnt)
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
                if(bps_clk && &accu_cnt)
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
                if(bps_clk && &accu_cnt)
                    if(STOP_BIT)
                        next_state  = STOP_0;
                    else
                        next_state  = STOP_1;
                else
                    next_state  = PARITY;
            STOP_0:
                if(bps_clk && &accu_cnt)
                    next_state  = STOP_1;
                else
                    next_state  = STOP_0;
            STOP_1:
                if(stop_accu)
                    next_state  = IDLE;
                else
                    next_state  = STOP_1;              
        endcase
    end

    //==========================================================================
    //数据累加

    //--------------------------------------------------------------------------
    //起始位累加
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            start_bit   <= #TCO '0;
        else
            case(state)
                IDLE:
                    start_bit   <= #TCO '0;
                START:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        start_bit   <= #TCO start_bit + rx_r[1];
                    else
                        start_bit   <= #TCO start_bit;
                default:
                    start_bit   <= #TCO start_bit;
            endcase
    end


    //--------------------------------------------------------------------------
    //停止位累加
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            stop_bit[0] <= #TCO '0;
        else
            case(state)
                IDLE:
                    stop_bit[0] <= #TCO '0;
                STOP_0:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        stop_bit[0] <= #TCO stop_bit[0] + rx_r[1];
                    else
                        stop_bit[0] <= #TCO stop_bit[0];
                default:
                    stop_bit[0] <= #TCO stop_bit[0];
            endcase
    end
    
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            stop_bit[1] <= #TCO '0;
        else
            case(state)
                IDLE:
                    stop_bit[1] <= #TCO '0;
                STOP_1:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        stop_bit[1] <= #TCO stop_bit[1] + rx_r[1];
                    else
                        stop_bit[1] <= #TCO stop_bit[1];
                default:
                    stop_bit[1] <= #TCO stop_bit[1];
            endcase
    end

    //--------------------------------------------------------------------------
    //校验位累加
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            parity_bit  <= #TCO '0;
        else
            case(state)
                IDLE:
                    parity_bit  <= #TCO '0;
                PARITY:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        parity_bit  <= #TCO parity_bit + rx_r[1];
                    else
                        parity_bit  <= #TCO parity_bit;
                default:
                    parity_bit  <= #TCO parity_bit;
            endcase
    end

    //--------------------------------------------------------------------------
    //数据位累加
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[0]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[0]    <= #TCO '0;
                DATA_0:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[0]    <= #TCO data_byte[0] + rx_r[1];
                    else
                        data_byte[0]    <= #TCO data_byte[0];
                default:
                    data_byte[0]    <= #TCO data_byte[0];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[1]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[1]    <= #TCO '0;
                DATA_1:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[1]    <= #TCO data_byte[1] + rx_r[1];
                    else
                        data_byte[1]    <= #TCO data_byte[1];
                default:
                    data_byte[1]    <= #TCO data_byte[1];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[2]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[2]    <= #TCO '0;
                DATA_2:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[2]    <= #TCO data_byte[2] + rx_r[1];
                    else
                        data_byte[2]    <= #TCO data_byte[2];
                default:
                    data_byte[2]    <= #TCO data_byte[2];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[3]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[3]    <= #TCO '0;
                DATA_3:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[3]    <= #TCO data_byte[3] + rx_r[1];
                    else
                        data_byte[3]    <= #TCO data_byte[3];
                default:
                    data_byte[3]    <= #TCO data_byte[3];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[4]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[4]    <= #TCO '0;
                DATA_4:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[4]    <= #TCO data_byte[4] + rx_r[1];
                    else
                        data_byte[4]    <= #TCO data_byte[4];
                default:
                    data_byte[4]    <= #TCO data_byte[4];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[5]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[5]    <= #TCO '0;
                DATA_5:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[5]    <= #TCO data_byte[5] + rx_r[1];
                    else
                        data_byte[5]    <= #TCO data_byte[5];
                default:
                    data_byte[5]    <= #TCO data_byte[5];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[6]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[6]    <= #TCO '0;
                DATA_6:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[6]    <= #TCO data_byte[6] + rx_r[1];
                    else
                        data_byte[6]    <= #TCO data_byte[6];
                default:
                    data_byte[6]    <= #TCO data_byte[6];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[7]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[7]    <= #TCO '0;
                DATA_7:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[7]    <= #TCO data_byte[7] + rx_r[1];
                    else
                        data_byte[7]    <= #TCO data_byte[7];
                default:
                    data_byte[7]    <= #TCO data_byte[7];
            endcase
    end
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_byte[8]    <= #TCO '0;
        else
            case(state)
                IDLE:
                    data_byte[8]    <= #TCO '0;
                DATA_8:
                    if(bps_clk && (accu_cnt>3 && accu_cnt<12))
                        data_byte[8]    <= #TCO data_byte[8] + rx_r[1];
                    else
                        data_byte[8]    <= #TCO data_byte[8];
                default:
                    data_byte[8]    <= #TCO data_byte[8];
            endcase
    end

    //==========================================================================
    //数据累加结果

    //--------------------------------------------------------------------------
    //停止位累计结果
    assign  stop_accu   = stop_bit[1][3]|(stop_bit[1][2]&&(stop_bit[1][1]||stop_bit[1][0]));

    //--------------------------------------------------------------------------
    //data累计结果
    assign  data_accu   = { (data_byte[8][3]|(data_byte[8][2]&&(data_byte[8][1]||data_byte[8][0]))),
                            (data_byte[7][3]|(data_byte[7][2]&&(data_byte[7][1]||data_byte[7][0]))),
                            (data_byte[6][3]|(data_byte[6][2]&&(data_byte[6][1]||data_byte[6][0]))),
                            (data_byte[5][3]|(data_byte[5][2]&&(data_byte[5][1]||data_byte[5][0]))),
                            (data_byte[4][3]|(data_byte[4][2]&&(data_byte[4][1]||data_byte[4][0]))),
                            (data_byte[3][3]|(data_byte[3][2]&&(data_byte[3][1]||data_byte[3][0]))),
                            (data_byte[2][3]|(data_byte[2][2]&&(data_byte[2][1]||data_byte[2][0]))),
                            (data_byte[1][3]|(data_byte[1][2]&&(data_byte[1][1]||data_byte[1][0]))),
                            (data_byte[0][3]|(data_byte[0][2]&&(data_byte[0][1]||data_byte[0][0])))};

    //--------------------------------------------------------------------------
    //校验位累计结果
    assign  parity_accu   = parity_bit[3]|(parity_bit[2]&&(parity_bit[1]||parity_bit[0]));


    //==========================================================================
    //抖动错误判断
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            jitter_error    <= #TCO '0;
        else
            case(state)
                START:
                    if((&accu_cnt)&&(start_bit==3 || start_bit==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_0:
                    if((&accu_cnt)&&(data_byte[0]==3 || data_byte[0]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_1:
                    if((&accu_cnt)&&(data_byte[1]==3 || data_byte[1]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_2:
                    if((&accu_cnt)&&(data_byte[2]==3 || data_byte[2]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_3:
                    if((&accu_cnt)&&(data_byte[3]==3 || data_byte[3]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_4:
                    if((&accu_cnt)&&(data_byte[4]==3 || data_byte[4]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_5:
                    if((&accu_cnt)&&(data_byte[5]==3 || data_byte[5]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_6:
                    if((&accu_cnt)&&(data_byte[6]==3 || data_byte[6]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_7:
                    if((&accu_cnt)&&(data_byte[7]==3 || data_byte[7]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                DATA_8:
                    if((&accu_cnt)&&(data_byte[8]==3 || data_byte[8]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                PARITY:
                    if((&accu_cnt)&&(parity_bit==3 || parity_bit==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                STOP_0:
                    if((&accu_cnt)&&(stop_bit[0]==3 || stop_bit[0]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                STOP_1:
                    if((&accu_cnt)&&(stop_bit[1]==3 || stop_bit[1]==4))
                        jitter_error    <= #TCO '1;
                    else
                        jitter_error    <= #TCO '0;
                default:
                    jitter_error    <= #TCO '0;
            endcase
    end

    //==========================================================================
    //数据输出
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            data_out    <= #TCO '0;
        else if((state==STOP_1)&&stop_accu)
            data_out    <= #TCO data_accu;
        else
            data_out    <= #TCO data_out;
    end


    //==========================================================================
    //生成接收完成信号
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            rx_done     <= #TCO '0;
        else if((state==STOP_1)&&stop_accu)
            rx_done     <= #TCO '1;
        else
            rx_done     <= #TCO '0;
    end

    //==========================================================================
    //奇偶校验
    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            even_parity <= #TCO '0;
        else if((state==PARITY)&&(bps_clk)&&(&accu_cnt))
            case(DATA_BIT)
                5:
                    even_parity <= #TCO ^data_accu[4:0];
                6:
                    even_parity <= #TCO ^data_accu[5:0];
                7:
                    even_parity <= #TCO ^data_accu[6:0];
                8:
                    even_parity <= #TCO ^data_accu[7:0];
                9:
                    even_parity <= #TCO ^data_accu[8:0];
                default:
                    even_parity <= #TCO '0;
            endcase
    end

    assign  odd_parity = ~even_parity;

    always_ff@(posedge clk, negedge rst_n)begin
        if(!rst_n)
            parity_error    <= #TCO '0;
        else if((state==STOP_1)&&(bps_clk)&&(&accu_cnt))
            case(PARITY_BIT)
                2'b00:  parity_error    <= #TCO '0;
                2'b01:  parity_error    <= #TCO (parity_accu==odd_parity)  ? '0 :'1;
                2'b10:  parity_error    <= #TCO (parity_accu==even_parity) ? '0 :'1;
                default:parity_error    <= #TCO '0;
            endcase
        else
            parity_error    <= #TCO '0;
    end


endmodule