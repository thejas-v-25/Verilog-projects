module uart_simple #(
    parameter CLK_FREQ = 50000000,    // 50 MHz clock
    parameter BAUD_RATE = 9600        // UART baud rate
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,                   // UART RX pin
    output reg  tx,                   // UART TX pin
    input  wire [7:0] tx_data,        // Data to transmit
    input  wire tx_start,             // Start transmission
    output reg  tx_busy,              // Transmitter busy flag
    output reg  [7:0] rx_data,        // Received data
    output reg  rx_done               // Reception done flag
);

    // --------------------------
    // Clock Divider for Baud
    // --------------------------
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // --------------------------
    // Transmitter
    // --------------------------
    reg [15:0] tx_count = 0;
    reg [3:0]  tx_bit_index = 0;
    reg [9:0]  tx_shift = 10'b1111111111; // idle = high

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            tx_busy <= 0;
            tx_count <= 0;
            tx_bit_index <= 0;
            tx_shift <= 10'b1111111111;
        end else begin
            if (tx_start && !tx_busy) begin
                // Load start(0), data, stop(1)
                tx_shift <= {1'b1, tx_data, 1'b0};
                tx_busy <= 1;
                tx_count <= 0;
                tx_bit_index <= 0;
            end else if (tx_busy) begin
                if (tx_count == CLKS_PER_BIT-1) begin
                    tx <= tx_shift[0];                  // send LSB first
                    tx_shift <= tx_shift >> 1;          // shift right
                    tx_bit_index <= tx_bit_index + 1;
                    tx_count <= 0;

                    if (tx_bit_index == 9) begin
                        tx_busy <= 0; // done
                    end
                end else begin
                    tx_count <= tx_count + 1;
                end
            end
        end
    end

    // --------------------------
    // Receiver
    // --------------------------
    reg [15:0] rx_count = 0;
    reg [3:0]  rx_bit_index = 0;
    reg [7:0]  rx_shift = 0;
    reg rx_busy = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_done <= 0;
            rx_busy <= 0;
            rx_count <= 0;
            rx_bit_index <= 0;
        end else begin
            rx_done <= 0;

            if (!rx_busy && !rx) begin
                // start bit detected
                rx_busy <= 1;
                rx_count <= CLKS_PER_BIT/2; // sample mid bit
                rx_bit_index <= 0;
            end else if (rx_busy) begin
                if (rx_count == CLKS_PER_BIT-1) begin
                    rx_count <= 0;
                    if (rx_bit_index < 8) begin
                        rx_shift <= {rx, rx_shift[7:1]}; // shift in data
                        rx_bit_index <= rx_bit_index + 1;
                    end else begin
                        rx_data <= rx_shift; // save data
                        rx_done <= 1;
                        rx_busy <= 0;
                    end
                end else begin
                    rx_count <= rx_count + 1;
                end
            end
        end
    end
endmodule
