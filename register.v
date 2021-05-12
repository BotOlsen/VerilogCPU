/*
 * Date : 05-03-2021
 * Author: Ramsey Alahmad
 * Name: register
 *
 */


module register
(
    input clk, reset_n, 
    input [1:0] registerWrite,
    input [3:0] registerRead1, registerRead2, regWriteLocal,
    input [15:0] dataWrite, r0Write,
    output reg [15:0] dataRead1, dataRead2, r0Read
);



reg [15:0] registerFile [15:0];

always@(posedge clk, negedge reset_n)
begin
    if(!reset_n) // initializes R0-R15
    begin
        registerFile[0] <= 16'h0000;
        registerFile[1] <= 16'h7B18;
        registerFile[2] <= 16'h245B;
        registerFile[3] <= 16'hFF0F;
        registerFile[4] <= 16'hF0FF;
        registerFile[5] <= 16'h0051;
        registerFile[6] <= 16'h6666;
        registerFile[7] <= 16'h00FF;
        registerFile[8] <= 16'hFF88;
        registerFile[9] <= 16'h0000;
        registerFile[10] <= 16'h0000;
        registerFile[11] <= 16'h3099;
        registerFile[12] <= 16'hCCCC;
        registerFile[13] <= 16'h0002;
        registerFile[14] <= 16'h0011;
        registerFile[15] <= 16'h0000;
    end
    else
    begin
        if(registerWrite == 2'b1x)
        begin
            registerFile[0] <= r0Write;
        end
        if(registerWrite == 2'bx1)
        begin
            registerFile[regWriteLocal] <= dataWrite;
        end
    end
end

always@(*)
begin 
    dataRead1 = registerFile[registerRead1];
    dataRead2 = registerFile[registerRead2];
    r0Read = registerFile[0];
end

endmodule
