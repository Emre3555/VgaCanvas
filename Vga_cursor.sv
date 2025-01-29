`timescale 1ns / 1ps
module canvas(input logic clk,
              input logic reset,
              input logic[2:0]sw,
              input logic BTNU,
              input logic BTND,
              input logic BTNR,
              input logic BTNL,
              input logic BTNC,
              input logic Brush,
              output logic hsync,
              output logic vsync,
              output logic[11:0] rgb);

logic video_on;
logic Pclk;
logic[9:0] x,y;
logic[9:0] cursor_x;
logic[9:0] cursor_y;
localparam SCREEN_WIDTH  = 640;
localparam SCREEN_HEIGHT = 480;
localparam CURSOR_SIZE = 3;
logic [9:0] next_cursor_x, next_cursor_y;
logic[2:0] array[40][30];
logic[2:0] inpcolor;
logic[11:0] rgb_reg;
logic write_en = 0;
initial begin
        for (int i = 0; i < 40; i++) begin
            for (int j = 0; j < 30; j++) begin
                array[i][j] = 3'b111; // Assign 3'b111 to each element
            end
        end
    end
always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cursor_x <= SCREEN_WIDTH / 2;  // Center X position
            cursor_y <= SCREEN_HEIGHT / 2; // Center Y position
        end else begin
            cursor_x <= next_cursor_x;
            cursor_y <= next_cursor_y;
        end
    end
 logic [19:0] move_count;  // Adjust the width based on desired delay
logic move_tick;
// Rate-limiting logic
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        move_count <= 0;
    end else if (move_count == 20'd999_999) begin
        move_count <= 0;
    end else if (BTNU || BTND || BTNL || BTNR) begin
        move_count <= move_count + 1;
    end
end
always_comb begin
inpcolor <= sw;
end
assign move_tick = (move_count == 20'd999_999);
    always_comb begin
    next_cursor_x = cursor_x;
    next_cursor_y = cursor_y;

    if (move_tick) begin
        if (BTNU && cursor_y > 0)
            next_cursor_y = cursor_y - 1;
        if (BTND && cursor_y < SCREEN_HEIGHT - 1)
            next_cursor_y = cursor_y + 1;
        if (BTNL && cursor_x > 0)
            next_cursor_x = cursor_x - 1;
        if (BTNR && cursor_x < SCREEN_WIDTH - 1)
            next_cursor_x = cursor_x + 1;
    end
end
always_ff @(posedge clk)begin
if(BTNC)begin
write_en = 1;
if(Brush)begin
for(int i = 1;i>=-1;i--)begin
    for(int c = 1;c>=-1;c--)begin
    array[cursor_x/16 + i][cursor_y/16 + c] <= inpcolor;
   end
 end
 end else begin
 array[cursor_x/16][cursor_y/16] <= inpcolor;
 end
write_en = 0;
end
end
vga_sync sync_unit(
    .clk (clk),
    .reset(reset),
    .hsync (hsync),
    .vsync(vsync),
    .video_en(video_on),
    .Pclk(Pclk),
    .x (x),
    .y(y)
  );
  always_ff @(posedge Pclk or posedge reset) begin
    if (reset) begin
      rgb_reg <= 12'b0;
    end else if (video_on) begin
      // Draw cursor as a + shape
      if (((x == cursor_x) && ((y >= cursor_y - 5) && (y <= cursor_y + 5))) || // vertical line of the cursor
          ((y == cursor_y) && ((x >= cursor_x - 5) && (x <= cursor_x + 5)))) // horizontal line of the cursor
        rgb_reg <= 12'b0000_0000_0000; // Black for cursor
      else begin
        if(~write_en)begin
        rgb_reg[11:9] <= array[x/16][y/16]; 
        rgb_reg[8:6] <= array[x/16][y/16];
        rgb_reg[5:3] <= array[x/16][y/16];
        rgb_reg[2:0] <= array[x/16][y/16];
        end
     end
     end else
      rgb_reg <= 12'b0; // Blank during sync
    end

  assign rgb = rgb_reg;


endmodule



  


 

 


module vga_sync(input logic clk,
                    input logic reset,
                    output logic hsync,
                    output logic vsync,
                    output logic video_en,
                    output logic Pclk,
                    output logic[9:0] x,
                    output logic[9:0] y
                    );
parameter HD = 640; // Horizontal display area
parameter HF = 16;  // Front porch
parameter HB = 48;  // Back porch
parameter HR = 96;  // Sync pulse
parameter HMax = HD + HF + HB + HR - 1;
parameter VD = 480; // Vertical display area
parameter VF = 10;  // Front porch
parameter VB = 33;  // Back porch
parameter VR = 2;   // Sync pulse
parameter VMax = VD + VF + VB + VR - 1;
parameter SQUARE_SIZE = 80;
logic[1:0] pixel_next;
logic[1:0] pixel_reg;
logic pixel_tick;
    always_ff @ (posedge clk or posedge reset)begin
    if(reset)
        pixel_reg <= 0;
        else
        pixel_reg <= pixel_next;
    end
  assign pixel_next = pixel_reg + 1;
  assign pixel_tick = (pixel_reg == 0);
  
  
  logic[9:0]h_count,h_count_next;
  logic[9:0]v_count,v_count_next;
  
  logic vsync_register,hsync_register;
  logic vsync_next,hsync_next; 
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        h_count <= 0;
        v_count <= 0;
        vsync_register <= 0;
        hsync_register <= 0;
        end else begin 
        v_count <= v_count_next;
        h_count <= h_count_next;
        vsync_register <= vsync_next;
        hsync_register <= hsync_next;
       end
     end
    

always_comb begin
    if(pixel_tick) begin
        if(h_count == HMax)
        h_count_next = 0;
    else 
       h_count_next = h_count + 1;
     end else begin
     h_count_next = h_count; 
     end
   if(pixel_tick && h_count == HMax)begin 
        if(v_count == VMax)
            v_count_next = 0;
         else
            v_count_next = v_count + 1;
     end else begin 
            v_count_next = v_count;
         end
      end     
      assign hsync_next = (h_count >= HD + HF) && (h_count <= HD + HF + HR);
      assign vsync_next = (v_count >= VD + VF) && (v_count <= VD + VF + VR);
      assign video_en = (h_count < HD) && (v_count < VD);
      
      assign hsync = hsync_register;
      assign vsync = vsync_register;
      assign x = h_count;
      assign y = v_count;
      assign Pclk = pixel_tick;


endmodule

