`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD            35
    `define FS_TO_DS_BUS_WD     104
    `define DS_TO_ES_BUS_WD     190
    `define ES_TO_MS_BUS_WD     122
    `define MS_TO_WS_BUS_WD     120
    `define WS_TO_RF_BUS_WD      38

    `define ST_WORD_LEN           4
    `define LD_WORD_LEN           6
    `define MV_WORD_LEN           4

    `define CP0_EPC         5'b1110
    `define CP0_CAUSE       5'b1101
    `define CP0_STATUS      5'b1100
    `define CP0_BadVAddr    5'b1000
    `define CP0_COUNT       5'b1001
    `define CP0_COMPARE     5'b1011
    `define CP0_INDEX       5'b0000
    `define CP0_EnrtyLo0    5'b0010
    `define CP0_EnrtyLo1    5'b0011
    `define CP0_EnrtyHi     5'b1010

    `define SYSCALL         5'b01000
    `define BREAK           5'b01001
    `define OVERFLOW        5'b01100
    `define RI              5'b01010
    `define INT             5'b00000
    `define Mod             5'b00001
    `define TLBL            5'b00010
    `define TLBS            5'b00011
    `define ADEL            5'b00100
    `define ADES            5'b00101
    `define TLB_INV         5'b00110
    `define NO_EX           5'b11111
`endif
