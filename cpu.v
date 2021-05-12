/*
 * Date: 5-09-2021
 * Name: CPU
 */


`include "adder.v"
`include "programCounter.v"
`include "instructionMemory.v"
`include "stage_buffer.v"
`include "register.v"
`include "comparator.v"
`include "mux4to1.v"
`include "mux2to1.v"
`include "sign_extend.v"
`include "shiftLeft.v"
`include "control.v"
`include "alu.v"
`include "alu_control.v"
`include "dataMemory.v"
`include "zero_extend.v"

module cpu(
    input clk, reset_n, 
    output PCSrc, aluBType, aluSrc, zeroExtendFlag, memRead, memWrite, memToReg, 
    output [1:0] aluControlOp, regWrite, 
    output [2:0] jumpBranch,
    output [15:0] PCOutput, IFAdderOutput, Instruction, rd1Read, rd2Read, reg0Read, signExtendedImmediate, ShiftResult, IDAdderOutput,
    output [31:0] IFID_Output /*[31:16] IFAdderOutput, [15:0] Instruction Output*/
    output [65:0] IDEX_Output, /*[3:0] Function Code, [19:4] signExtendedImmediate, [35:20] rd2SrcMuxOutput, [51:36]rd1SrcMuxOutput, [52] ALUBType, [53] ALUSrc, [55:54] ALUControlOp}
                                [56] MemRead, [57] MemWrite, [58] zeroExtendFlag, [59] memToReg, [60:61] RegWrite, [65:62] EXRegDst*/
    output [57:0] EXM_Output, /*[3:0] MRegDest, [19:4] DataToWrite, [35:20] ALUOverflowOutput, [51:36] ALUOutput, [52] MemRead, [53] MemWrite, [54] zeroExtendFlag, [55] memToReg, [57:56] RegWrite*/
    output [55:0] MWB_Output /* [3:0] WBRegDest, [19:4] ALUOverflowOutput, [35:20] DataMemoryOutputMuxResult, [51:36] ALUOutput, [52] memToReg, [54:53]RegWrite*/
);

.in({ EXM[57:56], EXM[55], EXM[51:36], DataMemoryOutputMuxResult, EXM[35:20], EXM[3:0]}),


wire [15:0] PCSourceMuxOutput, ALUSource1MuxOutput, ALUSource2MuxOutput, exReg0, ALUOverflowOutput, ALUOutput, DataMemoryOutput, zeroExtendedResult, MemToRegMuxOutput;
wire [9:0] SignalFlushMuxOutput;

//Instantiation of IF Stage
adder IFAdder(
    .A(PCOutput),
    .B(16'h0002),
    .sum(IFAdderOutput)
);

mux2to1 PCSourceMux (
        .switch(PCSrc),                      
        .input1(IFAdderOutput),
        .input2(IDAdderOutput),
        .out(PCSourceMuxOutput)
);

programCounter PC(
    .reset_n(reset_n),
    .clock(clk),
    .pcWrite(1'b1),                          //Actual value added later
    .inputAddress(PCSourceMuxOutput),
    .outputAddress(PCOutput)
);

instructionMemory IM(
    .clk(clk),
    .reset_n(reset_n),
    .address(PCOutput),
    .data(Instruction)
);

stage_buffer #(.SIZE(32)) IFID (
        .in({IFAdderOutput, Instruction}),
        .writeEnable(1'b1),             
        .clk(clk),
        .flush(reset_n),
        .out(IFID_Output)       
        );

//Instantiation of ID Stage
register RegisterFile(
        .clk(clk), 
        .reset_n(reset_n), 
        .registerRead1(IFID_Output[11:8]),
        .registerRead2(IFID_Output[7:4]),
        .regWriteLocal(4'hE),                   //Actual value added later
        .registerWrite(2'b11),               //Actual value added later
        .dataWrite(16'h0000),               //Actual value added later 
        .r0Write(16'h0000),                 //Actual value added later
        .dataRead1(rd1Read),
        .dataRead2(rd2Read), 
        .r0Read(reg0Read)
        );

mux4to1 Register0SourceMux(
        .switch(2'b00),                      //Add later, output of OFrwarding UNnit (R0Fwd)
        .input1(reg0Read),
        .input2(ALUOverflowOutput),  
        .input3(16'h0000),                  //Add later. m Stage R OUTPUT
        .input4(16'h0000),                   //Add later, WB STAGE R OUTPUT
        .out(reg0Read)
);

mux4to1 rd1SourceMux(
        .switch(2'b00),                      //Add later, output of OFrwarding UNnit (Op1Fwd)
        .input1(reg0Read),
        .input2(ALUOutput), 
        .input3(16'h0000),                  //Add later. m Stage ALU OUTPUT
        .input4(16'h0000)                   //Add later, WB STAGE ALU OUTPUT
);

mux4to1 rd2SourceMux(
        .switch(2'b00),                      //Add later, output of OFrwarding UNnit (Op2Fwd)
        .input1(reg0Read),
        .input2(16'h0000),                  //Add later. EX STAGE ALU OUTPUT
        .input3(16'h0000),                  //Add later. m Stage ALU OUTPUT
        .input4(16'h0000)                   //Add later, WB STAGE ALU OUTPUT
);

comparator Comparator(
    .r0(reg0Read),
    .op1(rd1Read),
    .CTRL(jumpBranch),
    .PCSrc(PCSrc)
);

sign_extend SignExtend(
    .instruction(Instruction),
    .signExtendedImmediate(signExtendedImmediate)
);

shiftLeft ShiftLeft(
    .beforeShift(signExtendedImmediate),
    .afterShift(ShiftResult)
);

adder IDAdder (
    .A(IFID_Output[31:16]),
    .B(ShiftResult),
    .sum(IDAdderOutput)
);

control ControlUnit(
    .multiDiv(IFID_Output[3:2]),
    .opcode(IFID_Output[15:12]),
    .aluBType(aluBType),
    .aluSrc(aluSrc),
    .zeroExtendFlag(zeroExtendFlag),
    .memRead(memRead),
    .memToReg(memToReg),
    .memWrite(memWrite),
    .aluControlOp(aluControlOp),
    .regWrite(regWrite),
    .jumpBranch(jumpBranch)
);

mux2to1 #(.SIZE(10)) SignalFlushMux (
        .switch(1'b0),                      
        .input1({regWrite, memToReg, zeroExtendFlag, memWrite, memRead, aluControlOp, aluSrc, aluBType}),
        .input2(10'b0),
        .out(SignalFlushMuxOutput)
);

/*[3:0] Function Code, [19:4] signExtendedImmediate, [35:20] rd2SrcMuxOutput, [51:36]rd1SrcMuxOutput, [52] ALUBType, [53] ALUSrc, [55:54] ALUControlOp}
                                [56] MemRead, [57] MemWrite, [58] zeroExtendFlag, [59] memToReg, [61:60] RegWrite, [65:62]EXRegDest*/
stage_buffer #(.SIZE(66)) IDEX (
        .in({IFID_Output[11:8], SignalFlushMuxOutput, rd1SrcMuxOutput, rd2SrcMuxOutput, signExtendedImmediate, IFID_Output[3:0]}),
        .writeEnable(1'b1),             
        .clk(clk),
        .flush(reset_n),
        .out(IDEX_Output)       
        );

//Instantiation of EX Stage
mux2to1 ALUSource1Mux (
        .switch(IDEX_Output[52]),                      
        .input1(IDEX_Output[51:36]),
        .input2(IDEX_Output[19:4]),
        .out(ALUSource1MuxOutput)
);

mux2to1 ALUSource2Mux (
        .switch(IDEX_Output[53]),                      
        .input1(IDEX_Output[35:20]),
        .input2(IDEX_Output[19:4]),
        .out(ALUSource2MuxOutput)
);

alu_control ALUControlUnit(
        .aluControlOp(IDEX_Output[55:54]),
        .functionCode(IDEX_Output[3:0]),
        .ALUOp(aluOp)
);

alu ALU(
    .A(ALUSource1MuxOutput),
    .B(ALUSource2MuxOutput),
    .CTRL(aluOp),
    .result(ALUOutput),
    .overflow(ALUOverflowOutput)
);

stage_buffer #(.SIZE(58)) EXM (
        .in({IDEX_Output[61:60], IDEX_Output[59], IDEX_Output[58], IDEX_Output[57], IDEX_Output[56], ALUOutput, ALUOverflowOutput, IDEX_Output[51:36], IDEX_Output[65:62]}),
        .writeEnable(1'b1),             
        .clk(clk),
        .flush(reset_n),
        .out(IDEX_Output)       
        );

//Instantiation of M Stage
dataMemory DataMemory(
        .clk(clk),
        .reset_n(reset_n),
        .memoryWrite(EXM[53]),
        .memoryRead(EXM[52]),
        .address(EXM[51:36]),
        .dataWrite(EXM[19:4]),
        .dataRead(DataMemoryOutput)
);

zero_extend ZeroExtend(
        .lowerByteDataMemoryOutput(DataMemoryOutput[7:0]),
        .zeroExtendedResult(zeroExtendedResult)
);

mux2to1 DataMemoryOutputMux(
        .switch(EXM[54]),                      
        .input1(DataMemoryOutput),
        .input2(zeroExtendedResult),
        .out(DataMemoryOutputMuxResult)
);

stage_buffer #(.SIZE()) MWB (
        .in({ EXM[57:56], EXM[55], EXM[51:36], DataMemoryOutputMuxResult, EXM[35:20], EXM[3:0]}),
        .writeEnable(1'b1),             
        .clk(clk),
        .flush(reset_n),
        .out(MWB_Output)       
        );

//Instantiation of WB Stage
mux2to1 MemToRegMux(
        .switch(MWB[52]),                      
        .input1(MWB[35:20]),
        .input2(MWB[51:36]),
        .out(MemToRegMuxOutput)
);


endmodule