

module CountTrailingZero (
    input  logic[7:0] val,
    output logic[3:0] count
);
always_comb begin
    unique casez(val)
        8'b???????1: count = 4'd0;
        8'b??????10: count = 4'd1;
        8'b?????100: count = 4'd2;
        8'b????1000: count = 4'd3;
        8'b???10000: count = 4'd4;
        8'b??100000: count = 4'd5;
        8'b?1000000: count = 4'd6;
        8'b10000000: count = 4'd7;
        8'b00000000: count = 4'd8;
    endcase
end
endmodule
