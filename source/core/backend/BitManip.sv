// bit ops in ALU
import bitutils::*;

module BitManip (
    input word_t value,
    output word_t clz_result,
    output word_t ctz_result,
    output word_t cntone_result
);

logic[3:0] clz_count3, clz_count2, clz_count1, clz_count0;
CountLeadingZero clz_byte3(.val(value[31:24]), .count(clz_count3));
CountLeadingZero clz_byte2(.val(value[23:16]), .count(clz_count2));
CountLeadingZero clz_byte1(.val(value[15:8]),  .count(clz_count1));
CountLeadingZero clz_byte0(.val(value[7:0]),   .count(clz_count0));
always_comb begin
    if (clz_count3 != 4'd8) begin
        clz_result = { 29'b0, clz_count3[2:0] };
    end else if(clz_count2 != 4'd8) begin
        clz_result = { 27'b0, 2'b01, clz_count2[2:0] };
    end else if(clz_count1 != 4'd8) begin
        clz_result = { 27'b0, 2'b10, clz_count1[2:0] };
    end else begin
        clz_result = { 27'b0, 2'b11, 3'b0 } + { 28'b0, clz_count0 };
    end
end

logic[3:0] ctz_count3, ctz_count2, ctz_count1, ctz_count0;
CountTrailingZero ctz_byte3(.val(value[31:24]), .count(ctz_count3));
CountTrailingZero ctz_byte2(.val(value[23:16]), .count(ctz_count2));
CountTrailingZero ctz_byte1(.val(value[15:8]),  .count(ctz_count1));
CountTrailingZero ctz_byte0(.val(value[7:0]),   .count(ctz_count0));
always_comb begin
    if (ctz_count0 != 4'd8) begin
        ctz_result = { 29'b0, ctz_count0[2:0] };
    end else if(clz_count1 != 4'd8) begin
        ctz_result = { 27'b0, 2'b01, clz_count1[2:0] };
    end else if(clz_count2 != 4'd8) begin
        ctz_result = { 27'b0, 2'b10, clz_count2[2:0] };
    end else begin
        ctz_result = { 27'b0, 2'b11, 3'b0 } + { 28'b0, clz_count3 };
    end
end

always_comb begin
    cntone_result = '0;  
    foreach (value[idx]) begin
        cntone_result += value[idx];
    end
end

endmodule





