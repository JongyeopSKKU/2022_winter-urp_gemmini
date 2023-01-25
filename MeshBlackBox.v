module MeshBlackBox
    #(parameter MESHROWS, MESHCOLUMNS, INPUT_BITWIDTH, OUTPUT_BITWIDTH, TILEROWS=1, TILECOLUMNS=1)
    (
        input                               clock,
        input                               reset,
        input signed [INPUT_BITWIDTH-1:0]   in_a[MESHROWS-1:0][TILEROWS-1:0],
        input signed [INPUT_BITWIDTH-1:0]   in_d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        input signed [INPUT_BITWIDTH-1:0]   in_b[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        input                               in_control_dataflow[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        input                               in_control_propagate[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        input                               in_valid[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        output signed [OUTPUT_BITWIDTH-1:0] out_c[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        output signed [OUTPUT_BITWIDTH-1:0] out_b[MESHCOLUMNS-1:0][TILECOLUMNS-1:0],
        output                              out_valid[MESHCOLUMNS-1:0][TILECOLUMNS-1:0]
    );

    // ---------------------------------------------------------
    // ---------------------------------------------------------
    //           DO NOT MODIFY ANYTHING ABOVE THIS
    // ---------------------------------------------------------
    // ---------------------------------------------------------


    //******************** FILL THIS ***************************

    // TILEROWS=1, TILECOLUMNS=1�� �����Ѵ�.
    // PE_Col�� �Է¿� ���� wire�� �����Ѵ�,
    wire signed [INPUT_BITWIDTH-1:0] new_in_a [MESHROWS-1:0];
    wire signed [INPUT_BITWIDTH-1:0] new_in_b [MESHCOLUMNS-1:0];
    wire new_in_control_propagate [MESHCOLUMNS-1:0];
    wire new_in_valid [MESHCOLUMNS-1:0];
    // input activations�� internal signal�� 2dim���� �����Ѵ�
    wire signed [INPUT_BITWIDTH-1:0] inter_a [MESHCOLUMNS-1:0][MESHROWS-1:0];

    genvar i, j, k;
    // PE_Col�� input activation�� ���� input�� ���Ӱ� ������ wire�� �����Ѵ�
    generate
        for (i = 0; i < MESHROWS; i += 1) begin
            assign new_in_a[i] = in_a[i][0];
        end
    endgenerate

    // PE_Col�� weight, control propagate, valid�� ���� input�� ���Ӱ� ������ wire�� �����Ѵ�
    generate
        for (j = 0; j < MESHCOLUMNS; j += 1) begin
            assign new_in_b[j] = in_b[j][0];
            assign new_in_control_propagate[j] = in_control_propagate[j][0];
            assign new_in_valid[j] = in_valid[j][0];
        end
    endgenerate
    
    // PE_Col ����� �ռ� ������ internal signal�� �̿��Ͽ� ��������� �����Ѵ�
    generate
        for (k = 0; k < MESHCOLUMNS; k += 1) begin
            //���� ù���� ���� PE_Col�� �ܺ� input�� in_a, in_b, in_control_propagate, in_valid�� �����ϰ�
            //out_a�� internal signal�� �����ϰ�
            //out_c, out_valid�� �ܺ� output�� �����Ѵ�
            if (k == 0) begin
                PE_Col # (.MESHROWS(MESHROWS), .INPUT_BITWIDTH(INPUT_BITWIDTH), .OUTPUT_BITWIDTH(OUTPUT_BITWIDTH)) pe_col (
                    .clock(clock),
                    .reset(reset),
                    .col_in_a(new_in_a),
                    .col_in_b(new_in_b[k]),
                    .col_in_control_propagate(new_in_control_propagate[k]),
                    .col_in_valid(new_in_valid[k]),
                    .col_out_a(inter_a[k]),
                    .col_out_c(out_c[k][0]),
                    .col_out_valid(out_valid[k][0])
                );
            //������ ���� PE_Col�� �ܺ� input�� in_b, in_control_propagate, in_valid�� �����ϰ�
            //in_a, out_a�� internal signal�� �����ϰ�
            //out_c, out_valid�� �ܺ� output�� �����Ѵ�
            end else begin
                PE_Col # (.MESHROWS(MESHROWS), .INPUT_BITWIDTH(INPUT_BITWIDTH), .OUTPUT_BITWIDTH(OUTPUT_BITWIDTH)) pe_col (
                    .clock(clock),
                    .reset(reset),
                    .col_in_a(inter_a[k-1]),
                    .col_in_b(new_in_b[k]),
                    .col_in_control_propagate(new_in_control_propagate[k]),
                    .col_in_valid(new_in_valid[k]),
                    .col_out_a(inter_a[k]),
                    .col_out_c(out_c[k][0]),
                    .col_out_valid(out_valid[k][0])
                );
            end
        end
    endgenerate
endmodule // MeshBlackBox

//********** FEEL FREE TO ADD MODULES HERE *****************
module PE_Col // PE����� ���� ������ ������ ����̴�
    #(parameter MESHROWS, INPUT_BITWIDTH, OUTPUT_BITWIDTH)
    (
        input clock,
        input reset,
        input signed [INPUT_BITWIDTH-1:0] col_in_a [MESHROWS-1:0],  // input activations of all rows
        input signed [INPUT_BITWIDTH-1:0] col_in_b,  // weight
        input col_in_control_propagate,
        input col_in_valid,

        output signed [INPUT_BITWIDTH-1:0] col_out_a [MESHROWS-1:0],  // forward the input activations of all rows
        output signed [OUTPUT_BITWIDTH-1:0] col_out_c, // the actual output
        output col_out_valid
    );
       
    // weight�� �κ����� internal signal�� �����Ѵ�
    wire signed [INPUT_BITWIDTH-1:0] inter_b [MESHROWS-1:0];
    wire signed [OUTPUT_BITWIDTH-1:0] inter_c [MESHROWS-1:0];
    // control propagate�� valid�� internal signal�� �����Ѵ�
    wire inter_propagate [MESHROWS-1:0];
    wire inter_valid [MESHROWS-1:0];
    // ù��° ���� PE�� �ԷµǴ� �κ����� ���� 0���� �̸� �����Ѵ�.
    wire signed [OUTPUT_BITWIDTH-1:0] init_c;
    assign init_c = 0;

    // PE����� ���������� �����Ѵ�
    genvar i;
    generate
        for (i = 0; i < MESHROWS; i += 1) begin
            //���� ù���� ���� PE�� �ܺ� input�� �κ��� ���� 0�� �Է��ϰ�
            //������ b, out_c, propagate control, valid�� internal signal�� �����Ѵ�.
            //input activation�� �ܺ� input, output�� �����Ѵ�(�ٸ���鵵 ����).
            if (i == 0) begin
                PE #(.INPUT_BITWIDTH(INPUT_BITWIDTH), .OUTPUT_BITWIDTH(OUTPUT_BITWIDTH)) pe (
                    .clock(clock),
                    .reset(reset),
                    .pe_in_a(col_in_a[i]),
                    .pe_in_b(col_in_b),
                    .in_c(init_c),
                    .pe_in_control_propagate(col_in_control_propagate),
                    .pe_in_valid(col_in_valid),
                    .pe_out_a(col_out_a[i]),
                    .pe_out_b(inter_b[i]),
                    .pe_out_c(inter_c[i]),
                    .pe_out_control_propagate(inter_propagate[i]),
                    .pe_out_valid(inter_valid[i]));
            //���� ������ ���� PE�� �ܺ� output�� out_c�� out_valid�� �����ϸ�
            //������ b, in_c, propagate control, in_valid�� internal signal�� �����Ѵ�.
            end else if (i == MESHROWS - 1) begin
                // The last/bottom PE of the column
                PE #(.INPUT_BITWIDTH(INPUT_BITWIDTH), .OUTPUT_BITWIDTH(OUTPUT_BITWIDTH)) pe (
                    .clock(clock),
                    .reset(reset),
                    .pe_in_a(col_in_a[i]),
                    .pe_in_b(inter_b[i-1]),
                    .in_c(inter_c[i-1]),
                    .pe_in_control_propagate(inter_propagate[i-1]),
                    .pe_in_valid(inter_valid[i-1]),
                    .pe_out_a(col_out_a[i]),
                    .pe_out_b(inter_b[i]),
                    .pe_out_c(col_out_c),
                    .pe_out_control_propagate(inter_propagate[i]),
                    .pe_out_valid(col_out_valid));
            //�߰� ����� PE�� �ܺ� output�� out_c�� out_valid�� �����ϸ�
            //b, c, propagate control, valid�� internal signal�� �����Ѵ�.
            end else begin
                PE #(.INPUT_BITWIDTH(INPUT_BITWIDTH), .OUTPUT_BITWIDTH(OUTPUT_BITWIDTH)) pe (
                    .clock(clock),
                    .reset(reset),
                    .pe_in_a(col_in_a[i]),
                    .pe_in_b(inter_b[i-1]),
                    .in_c(inter_c[i-1]),
                    .pe_in_control_propagate(inter_propagate[i-1]),
                    .pe_in_valid(inter_valid[i-1]),
                    .pe_out_a(col_out_a[i]),
                    .pe_out_b(inter_b[i]),
                    .pe_out_c(inter_c[i]),
                    .pe_out_control_propagate(inter_propagate[i]),
                    .pe_out_valid(inter_valid[i]));
            end
        end
    endgenerate

endmodule // PE_Col

module PE  // PE ���� ��⿡ �ش��Ѵ�
    #(parameter INPUT_BITWIDTH, OUTPUT_BITWIDTH)
    (
        input wire clock,
        input wire reset,
        input wire signed [INPUT_BITWIDTH-1:0] pe_in_a,  // input activation
        input wire signed [INPUT_BITWIDTH-1:0] pe_in_b,  // weight
        input wire signed [OUTPUT_BITWIDTH-1:0] in_c,  // partial sum
        input wire pe_in_control_propagate,
        input wire pe_in_valid,

        output reg signed [INPUT_BITWIDTH-1:0] pe_out_a,  // forward input activation
        output reg signed [INPUT_BITWIDTH-1:0] pe_out_b,  // forward the weight
        output reg signed [OUTPUT_BITWIDTH-1:0] pe_out_c,  // forward the partial sum
        output reg pe_out_control_propagate,  // forward propogration control
        output reg pe_out_valid  // forward input valid bit
    );
    
    // weight�� Double buffer register�� �����Ѵ�
    reg signed [INPUT_BITWIDTH-1:0] buf_b[1:0];
    // ���ǿ����ڸ� �̿��Ͽ� in_control_propagate�� ���� ���� �ΰ��� buf_b �� �ϳ��� ���� 
    //internal signal�� ��������(MUX���)
    wire signed [INPUT_BITWIDTH-1:0] mac_b = pe_in_control_propagate ? buf_b[0] : buf_b[1];

    always @(posedge clock or posedge reset) begin
        // active high reset�� Ȱ��ȭ �Ǿ��� �� ��� reg���� �ʱ�ȭ �ǵ��� �Ѵ�.
        if (reset) begin
            pe_out_a <= 0;
            pe_out_b <= 0;
            pe_out_c <= 0;
            pe_out_control_propagate <= 0;
            pe_out_valid <= 0;
            buf_b[0] <= 0;
            buf_b[1] <= 0;
        end
        else begin
            // in_valid�� Ȱ��ȭ �� ��� weight�� ���Ӱ� ����ǰ� ��µǵ��� �Ѵ�.
            if (pe_in_valid) begin
                // Propagate�� ���� ���� ������ weight reg�� �����Ѵ�
                //(�ռ� MUX�� ��¿� �ش��ϴ� buffer�� �ٸ� buffer�� ���õǵ����Ѵ�.) 
                if (pe_in_control_propagate) begin
                    buf_b[1] <= pe_in_b;
                    pe_out_b <= buf_b[1];
                end else begin
                    buf_b[0] <= pe_in_b;
                    pe_out_b <= buf_b[0];
                end
            end
            // MAC ����� ��µǵ��� �Ѵ�. (c = a * b + psum) ??????????
            pe_out_c <= pe_in_a *  mac_b +  in_c;
            // input activation, control_propagate_valid��ȣ�� ���޵ǵ��� �Ѵ�.
            pe_out_a <= pe_in_a;
            pe_out_control_propagate <= pe_in_control_propagate;
            pe_out_valid <= pe_in_valid;
        end
    end

endmodule // PE_unit


// ---------------------------------------------------------
// ---------------------------------------------------------
//           DO NOT MODIFY ANYTHING BELOW THIS
// ---------------------------------------------------------
// ---------------------------------------------------------

// We are providing this adapter, due to the format of Chisel-generated Verilog
// and it's compatibility with a blackbox interface.
//
// This adapter converts the Gemmini multiplication function into something
// more amenable to teaching:
//
// Assumed that bias matrix is 0.
//
// Originally Gemmini does:
//   A*D + B => B
// more amenable to teaching:
//
// Assumed that bias matrix is 0.
//
// Originally Gemmini does:
//   A*D + B => B
//   0 => C
//
// This adapter converts it to the following:
//   A*B + D => C
//   0 => B
module MeshBlackBoxAdapter
  #(parameter MESHROWS, MESHCOLUMNS, INPUT_BITWIDTH, OUTPUT_BITWIDTH, TILEROWS=1, TILECOLUMNS=1)
    (
    input                                                clock,
    input                                                reset,
    input [MESHROWS*TILEROWS*INPUT_BITWIDTH-1:0]         in_a,
    input [MESHCOLUMNS*TILECOLUMNS*INPUT_BITWIDTH-1:0]   in_d,
    input [MESHCOLUMNS*TILECOLUMNS*INPUT_BITWIDTH-1:0]   in_b,
    input [MESHCOLUMNS*TILECOLUMNS-1:0]                  in_control_dataflow,
    input [MESHCOLUMNS*TILECOLUMNS-1:0]                  in_control_propagate,
    input [MESHCOLUMNS*TILECOLUMNS-1:0]                  in_valid,
    output [MESHCOLUMNS*TILECOLUMNS*OUTPUT_BITWIDTH-1:0] out_c,
    output [MESHCOLUMNS*TILECOLUMNS*OUTPUT_BITWIDTH-1:0] out_b,
    output [MESHCOLUMNS*TILECOLUMNS-1:0]                 out_valid
    );

  wire signed [INPUT_BITWIDTH-1:0]  in_a_2d[MESHROWS-1:0][TILEROWS-1:0];
  wire signed [INPUT_BITWIDTH-1:0]  in_d_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire signed [INPUT_BITWIDTH-1:0]  in_b_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire                              in_control_dataflow_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire                              in_control_propagate_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire                              in_valid_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire signed [OUTPUT_BITWIDTH-1:0] out_c_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire signed [OUTPUT_BITWIDTH-1:0] out_b_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  wire                              out_valid_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  reg signed [OUTPUT_BITWIDTH-1:0] reg_out_c_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  reg signed [OUTPUT_BITWIDTH-1:0] reg_out_b_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];
  reg                              reg_out_valid_2d[MESHCOLUMNS-1:0][TILECOLUMNS-1:0];

  // Convert wide signals into "cleaner" 2D Verilog arrays
  genvar i;
  genvar j;
  generate
  for (i = 0; i < MESHROWS ; i++) begin
    for (j = 0; j < TILEROWS ; j++) begin
      assign in_a_2d[i][j] = in_a[i*(TILEROWS*INPUT_BITWIDTH)+(j+1)*(INPUT_BITWIDTH)-1:i*(TILEROWS*INPUT_BITWIDTH)+j*(INPUT_BITWIDTH)];
    end
  end
  endgenerate

  generate
  for (i = 0; i < MESHCOLUMNS ; i++) begin
    for (j = 0; j < TILECOLUMNS ; j++) begin
       assign in_d_2d[i][j] = in_d[i*(TILECOLUMNS*INPUT_BITWIDTH)+(j+1)*(INPUT_BITWIDTH)-1:i*(TILECOLUMNS*INPUT_BITWIDTH)+j*(INPUT_BITWIDTH)];
       assign in_b_2d[i][j] = in_b[i*(TILECOLUMNS*INPUT_BITWIDTH)+(j+1)*(INPUT_BITWIDTH)-1:i*(TILECOLUMNS*INPUT_BITWIDTH)+j*(INPUT_BITWIDTH)];
       assign in_control_dataflow_2d[i][j] = in_control_dataflow[i*(TILECOLUMNS)+(j+1)-1:i*(TILECOLUMNS)+j];
       assign in_control_propagate_2d[i][j] = in_control_propagate[i*(TILECOLUMNS)+(j+1)-1:i*(TILECOLUMNS)+j];
       assign in_valid_2d[i][j] = in_valid[i*(TILECOLUMNS)+(j+1)-1:i*(TILECOLUMNS)+j];

       assign out_c[i*(TILECOLUMNS*OUTPUT_BITWIDTH)+(j+1)*(OUTPUT_BITWIDTH)-1:i*(TILECOLUMNS*OUTPUT_BITWIDTH)+j*(OUTPUT_BITWIDTH)] = reg_out_c_2d[i][j];
       assign out_b[i*(TILECOLUMNS*OUTPUT_BITWIDTH)+(j+1)*(OUTPUT_BITWIDTH)-1:i*(TILECOLUMNS*OUTPUT_BITWIDTH)+j*(OUTPUT_BITWIDTH)] = reg_out_b_2d[i][j];
       assign out_valid[i*(TILECOLUMNS)+(j+1)-1:i*(TILECOLUMNS)+j] = reg_out_valid_2d[i][j];

       always @(posedge clock) begin
           if (reset) begin
               // reset all values to 0
               reg_out_c_2d[i][j] <= '0;
               reg_out_b_2d[i][j] <= '0;
               reg_out_valid_2d[i][j] <= '0;
           end
           else begin
               // regnext the values
               reg_out_c_2d[i][j] <= out_c_2d[i][j];
               reg_out_b_2d[i][j] <= out_b_2d[i][j];
           end
       end
    end
  end
  endgenerate

  // Instantiate the Mesh BlackBox implementation (the one you are writing in
  // this assignment)
  // Note: This swaps signals around a bit:
  //   in_b <-> in_d
  //   out_c <-> out_b
  MeshBlackBox #(.MESHROWS(MESHROWS),.TILEROWS(TILEROWS),.MESHCOLUMNS(MESHCOLUMNS),.TILECOLUMNS(TILECOLUMNS),.INPUT_BITWIDTH(INPUT_BITWIDTH),.OUTPUT_BITWIDTH(OUTPUT_BITWIDTH))
   mesh_blackbox_inst (
       .clock                (clock),
       .reset                (reset),
       .in_a                 (in_a_2d),
       .in_d                 (in_b_2d),
       .in_b                 (in_d_2d),
       .in_control_dataflow  (in_control_dataflow_2d),
       .in_control_propagate (in_control_propagate_2d),
       .in_valid             (in_valid_2d),
       .out_c                (out_b_2d),
       .out_b                (out_c_2d),
       .out_valid            (out_valid_2d)
  );

endmodule  //MeshBlackBoxAdapter