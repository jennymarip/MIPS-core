`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //from es,ms,ws data dependence
    input                          es_inst_mfc0     ,
    input                          ms_inst_mfc0     ,
    input                          ws_inst_mfc0     ,
    input  [ 4:0]                  EXE_dest         ,
    input  [ 4:0]                  MEM_dest         ,
    input  [ 4:0]                  WB_dest          ,
    input                          es_load_op       ,
    input                          ms_load_op       ,
    input                          data_sram_data_ok,
    // forward
    input  [31:0]                  EXE_dest_data,
    input  [31:0]                  MEM_dest_data,
    input  [31:0]                  WB_dest_data ,
    // word of div and mul (div / divu / mult / multu)
    output [ 3:0]                  dm_word      ,
    // ld_word (LB / LBU / LH / LHU / LWL / LWR)
    output [`LD_WORD_LEN - 1 :0]   ld_word      ,
    // mv_word (MFLO / MFHI / MTHI / MTLO)
    output [`MV_WORD_LEN - 1 :0]   mv_word      ,
    // st_word (SB / SH / SWL / SWR)
    output [`ST_WORD_LEN -1 :0]    st_word      ,
    // EX
    input                          WS_EX        ,
    input                          MS_EX        ,
    input                          ES_EX        ,
    output                         DS_EX        ,
    input                          ERET         ,
    input                          ES_ERET      ,
    input                          MS_ERET      ,
    output [ 2:0]                  of_test
);

reg         ds_valid   ;
wire        ds_ready_go;

assign DS_EX = (ex_code != `NO_EX) & ds_valid;
// mfc0 wait
wire   mfc0_stall;
assign mfc0_stall = (rs_wait && ((es_inst_mfc0 && (rs == EXE_dest)) || (ms_inst_mfc0 && (rs == MEM_dest)) || (ws_inst_mfc0 && (rs == WB_dest)))) ||
                    (rt_wait && ((es_inst_mfc0 && (rt == EXE_dest)) || (ms_inst_mfc0 && (rt == MEM_dest)) || (ws_inst_mfc0 && (rt == WB_dest))));
// branch
wire   br_stall;
wire   load_stall;
assign br_stall   = br_taken & load_stall & {5{ds_valid}};
assign load_stall = ((rs_wait & (rs == EXE_dest) & es_load_op ) | (rs_wait & (rs == MEM_dest) & ms_load_op & ~data_sram_data_ok)) |
                    ((rt_wait & (rt == EXE_dest) & es_load_op ) | (rt_wait & (rt == MEM_dest) & ms_load_op & ~data_sram_data_ok));

wire [31                 :0] fs_pc         ;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst ;
wire [31:0] ds_pc   ;
wire [31:0] BadVAddr;
wire        pc_error;
wire        slot    ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;
assign {slot    ,
        pc_error,
        BadVAddr} = fs_to_ds_bus_r[102:69];

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken ;
wire [31:0] br_target;


wire [13:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src1_is_rd;
wire        src2_is_imm;
wire        src2_is_imm_zero;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [ 2:0] sel;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

/* 所有实现的指令 */
wire        inst_addu, inst_add, inst_subu, inst_sub;
wire        inst_and, inst_andi, inst_or, inst_ori, inst_xor, inst_xori, inst_nor;
wire        inst_slt, inst_slti, inst_sltu, inst_sltiu, inst_sll, inst_sllv, inst_srl, inst_srlv, inst_sra, inst_srav;
wire        inst_addiu, inst_addi;
wire        inst_lui;
wire        inst_lw, inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lwl, inst_lwr;
wire        inst_sw, inst_sb, inst_sh, inst_swl, inst_swr;
wire        inst_beq, inst_bne, inst_bgez, inst_bgtz, inst_blez, inst_bltz, inst_bgezal, inst_bltzal;
wire        inst_j, inst_jal, inst_jr, inst_jalr;
wire        inst_div, inst_divu, inst_mult, inst_multu;
wire        inst_mflo, inst_mfhi, inst_mtlo, inst_mthi;
wire        inst_syscall, inst_break;
wire        inst_mtc0, inst_mfc0;
wire        inst_eret;
wire        inst_tlbp, inst_tlbwi, inst_tlbr;
wire        inst_no;
/* ************ */

wire        not_in_alu;
wire        dst_is_r31;  
wire        dst_is_rt ;  

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt  ;
wire        rs_ge_zero;
wire        rs_gt_zero;
wire        rs_le_zero;
wire        rs_lt_zero;

wire [ 4:0] ex_code;
wire        eret   ;

assign br_bus       = {is_branch, br_stall,br_taken,br_target};

assign ds_to_es_bus = {inst_tlbr       ,  //188:188
                       inst_tlbwi      ,  //187:187
                       inst_tlbp       ,  //186:186
                       inst_mfc0       ,  //185:185
                       inst_mtc0       ,  //184:184
                       pc_error        ,  //183:183
                       BadVAddr        ,  //182:151
                       ex_code         ,  //150:146
                       eret            ,  //145:145
                       slot            ,  //144:144
                       rd              ,  //143:139
                       alu_op          ,  //138:125
                       load_op         ,  //124:124
                       src1_is_sa      ,  //123:123
                       src1_is_pc      ,  //122:122 
                       src2_is_imm     ,  //121:121
                       src2_is_imm_zero,  //120:120
                       src2_is_8       ,  //119:119
                       gr_we           ,  //118:118
                       mem_we          ,  //117:117
                       dest            ,  //116:112
                       imm             ,  //111: 96
                       rs_value        ,  //95 : 64
                       rt_value        ,  //63 : 32
                       ds_pc              //31 :  0
                      };
// data dependence
wire   src1_no_rs;    //指令 rs 域非 0，且不是从寄存器堆读 rs 的数据
wire   src2_no_rt;    //指令 rt 域非 0，且不是从寄存器堆读 rt 的数据
assign src1_no_rs = 1'b0;
assign src2_no_rt = inst_addiu | (load_op & ~inst_lwl & ~inst_lwr) | inst_jal | inst_lui | inst_j | inst_syscall | inst_break;
wire   rs_wait;       // the value of rs has not ready in rs
wire   rt_wait;		  // the value of rt has not ready in rt
assign rs_wait    = ~src1_no_rs & (rs!=5'd0) 
                 & ( (rs==EXE_dest) | (rs==MEM_dest) | (rs==WB_dest) );
assign rt_wait    = ~src2_no_rt & (rt!=5'd0)
                 & ( (rt==EXE_dest) | (rt==MEM_dest) | (rt==WB_dest) );
                 
wire   inst_no_dest; // GPR
assign inst_no_dest = inst_beq | inst_bgez | inst_bne | inst_bgtz | inst_blez | inst_bltz | 
                      inst_j | inst_jr | inst_sw | inst_sb | inst_sh | inst_swl | inst_swr |
                      inst_div | inst_divu | inst_mult | inst_multu | 
                      inst_mthi | inst_mtlo |
                      inst_syscall | inst_break;

assign ds_ready_go    = ds_valid && ~load_stall && ~mfc0_stall;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset | WS_EX | ERET) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];
assign sel  = ds_inst[ 2: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

// 1 : not in alu_op
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_sltiu  = op_d[6'h0b];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_andi   = op_d[6'h0c];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori    = op_d[6'h0d];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_xori   = op_d[6'h0e];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_addi   = op_d[6'h08];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sw     = op_d[6'h2b];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];
assign inst_beq    = op_d[6'h04]; // 1
assign inst_bne    = op_d[6'h05]; // 1
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01]; // 1
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00]; // 1 
assign inst_blez   = op_d[6'h06] & rt_d[5'h00]; // 1
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00]; // 1
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_j      = op_d[6'h02];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00]; // 1
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00]; // 1
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00]; // 1
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00]; // 1
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00]; // 1
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00]; // 1
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00]; // 1
assign inst_syscall= op_d[6'h00] & func_d[6'h0c]; // 1
assign inst_break  = op_d[6'h00] & func_d[6'h0d]; // 1
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & (ds_inst[10: 3] == 8'b0); // 1
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & (ds_inst[10: 3] == 8'b0); // 1
assign inst_eret   = (ds_inst[31:0] == 32'h42000018); // 1
assign inst_tlbp   = (ds_inst[31:0] == 32'h42000008);
assign inst_tlbwi  = (ds_inst[31:0] == 32'h42000002);
assign inst_tlbr   = (ds_inst[31:0] == 32'h42000001);

assign not_in_alu  = inst_beq | inst_bne | inst_bgez | inst_bgtz | inst_blez | inst_bltz |
                     inst_jr  |
                     inst_mult | inst_multu |
                     inst_mflo | inst_mfhi | inst_mtlo | inst_mthi |
                     inst_syscall | inst_break | inst_eret |
                     inst_mtc0 | inst_mfc0;

assign inst_no     = (alu_op[13:0] == 14'b0) & ~not_in_alu & ~(inst_tlbwi || inst_tlbr || inst_tlbp);
                     

assign ld_word     = {inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lwl, inst_lwr};
assign mv_word     = {inst_mflo, inst_mfhi, inst_mtlo, inst_mthi};
assign st_word     = {inst_sb, inst_sh, inst_swl, inst_swr} ;
assign of_test     = {inst_sub, inst_addi, inst_add}        ;

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sw | inst_sb | inst_sh | inst_swl | inst_swr | inst_j | inst_jal | inst_jalr | inst_bgezal | inst_bltzal | inst_add | inst_addi;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_div;
assign alu_op[13] = inst_divu;

assign load_op   = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;
assign dm_word   = {inst_div   && ds_valid ,
                    inst_divu  && ds_valid ,
                    inst_mult  && ds_valid ,
                    inst_multu && ds_valid
                   };

assign src1_is_sa       = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc       = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;
assign src2_is_imm      = inst_addiu | inst_addi | inst_lui | inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_sw | inst_sb | inst_sh | inst_swl | inst_swr | inst_slti | inst_sltiu;
assign src2_is_imm_zero = inst_andi | inst_ori | inst_xori;
assign src2_is_8        = inst_jal | inst_jalr | inst_bltzal | inst_bgezal;
assign res_from_mem     = inst_lw | inst_lb | inst_lbu;
assign dst_is_r31       = inst_jal | inst_bltzal | inst_bgezal;
assign dst_is_rt        = inst_addiu | inst_addi | inst_lui | inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_mfc0;
assign gr_we            = ~inst_sw & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr & ~inst_beq & ~inst_bne & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & 
                          ~inst_jr & ~inst_j & 
                          ~inst_div & ~inst_divu & ~inst_mult & ~inst_multu & 
                          ~inst_mthi & ~inst_mtlo &
                          ~inst_mtc0;
assign mem_we           = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;

assign dest             = dst_is_r31   ? 5'd31 :
                          dst_is_rt    ? rt    : 
                          inst_no_dest ? 5'd0  : rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

// forward
assign rs_value = rs_wait ? (rs == EXE_dest ?  EXE_dest_data :
                             rs == MEM_dest ?  MEM_dest_data : WB_dest_data)
                            : rf_rdata1;
assign rt_value = rt_wait ? (rt == EXE_dest ?  EXE_dest_data :
                             rt == MEM_dest ?  MEM_dest_data : WB_dest_data)
                            : rf_rdata2;

// BU

assign is_branch = (inst_beq | inst_bne | inst_bgez | inst_bgtz | inst_blez | inst_bltz | inst_bltzal | inst_bgezal | inst_jal | inst_jalr | inst_j | inst_jr) & ds_valid;

assign rs_eq_rt   = (rs_value == rt_value);
assign rs_ge_zero = ($signed(rs_value) >= 0);
assign rs_gt_zero = ($signed(rs_value)  > 0);
assign rs_le_zero = ($signed(rs_value) <= 0);
assign rs_lt_zero = ($signed(rs_value)  < 0);

assign br_taken   = (  inst_beq    &  rs_eq_rt
                     | inst_bne    & !rs_eq_rt
                     | inst_bgez   &  rs_ge_zero
                     | inst_bgtz   &  rs_gt_zero
                     | inst_blez   &  rs_le_zero
                     | inst_bltz   &  rs_lt_zero
                     | inst_bltzal &  rs_lt_zero
                     | inst_bgezal &  rs_ge_zero
                     | inst_jal
                     | inst_jalr
                     | inst_j
                     | inst_jr
                   ) & ds_valid & ~ERET;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bltzal || inst_bgezal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr  || inst_jalr)             ? rs_value :
                  /*inst_jal*/                           {fs_pc[31:28], jidx[25:0], 2'b0};

// EX
assign ex_code = (ES_EX | MS_EX | WS_EX         ) ? `NO_EX   :
                 (fs_to_ds_bus_r[68:64] == `ADEL) ? `ADEL    :
                 inst_syscall                     ? `SYSCALL :
                 inst_break                       ? `BREAK   :
                 inst_no                          ? `RI      :
                 ds_valid && tlb_inv              ? `TLB_INV :
                                                    fs_to_ds_bus_r[68:64];
assign eret  = inst_eret   ;
/* tlbwi 和tlbr 指令之后的第一条指令标记异常（不是真的异常） */
reg tlb_inv;
always @ (posedge clk) begin
    if (reset) begin
        tlb_inv <= 1'b0;
    end else if ((inst_tlbwi || inst_tlbr) && ds_to_es_valid && es_allowin) begin
        tlb_inv <= 1'b1;
    end else if (ds_to_es_valid && es_allowin) begin
        tlb_inv <= 1'b0;
    end
end

endmodule
