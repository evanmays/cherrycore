// Handles sending packets. State Machine
// Must arbitrate among packet types
// Each packet type has a priority so we pull from queue with highest priority
// Packet format in PacketReceiver.sv
module PacketSender(
    input clk,
    input reset,

    // UART connection (no real reason this couldn't be replaced with a high bandwidth link layer like ethernet or pcie. Just feed this module 1 byte at a time)
    input              tx_busyn,
    output logic       tx_en,
    output logic [7:0] tx_data,

    // Start read requests
    input [15:0]    dma_send_read_queue_data,
    input           dma_send_read_queue_available,
    output          dma_send_read_queue_re,
    // Start write request
    input [15:0]    dma_send_write_queue_data,
    input [18*16-1:0] dma_send_write_queue_data2,
    input           dma_send_write_queue_available,
    output          dma_send_write_queue_re,
    // Send end program command
    input [7:0]     dma_send_end_program_data,
    input           dma_send_end_program_queue_available,
    output          dma_send_end_program_queue_re
);
enum {IDLE, SENDING_READ_REQUEST, SENDING_WRITE, SENDING_END_PROG_NOTIF} S;

reg [15:0] counter;
reg [18*16-1:0] matrix_send_tile;
always @(posedge clk) begin
    tx_en <= 0;
    dma_send_read_queue_re <= 0;
    dma_send_write_queue_re <= 0;
    dma_send_end_program_queue_re <= 0;
    case (S)
        IDLE: if (tx_busyn) begin
            if (dma_send_end_program_queue_available) begin
                dma_send_end_program_queue_re <= 1;
                counter <= 0;
                S <= SENDING_END_PROG_NOTIF;
            end else if (dma_send_read_queue_available) begin
                dma_send_read_queue_re <= 1;
                counter <= 0;
                S <= SENDING_READ_REQUEST;
            end else if (dma_send_write_queue_available) begin
                dma_send_write_queue_re <= 1;
                counter <= 0;
                S <= SENDING_WRITE;
            end
        end

        // MAKE&SEND PROG END NOTIFICATION PACKET
        SENDING_READ_REQUEST: if (tx_busyn) begin
            counter <= counter + 1;
            if (counter == 1) // Read request packet is 1 header byte, 2 payload bytes. 3 bytes total.
                S <= IDLE;
            case (counter)
                0: begin
                    tx_data <= {2'd2, 6'd0}; // packet type bits kinds are different depeending on direction of packet
                    tx_en <= 1;
                end
                1: begin
                    tx_data <= dma_send_end_program_data;
                    tx_en <= 1;
                end
            endcase
        end
    
        // MAKE&SEND READ REQUEST PACKET
        SENDING_READ_REQUEST: if (tx_busyn) begin
            counter <= counter + 1;
            if (counter == 2) // Read request packet is 1 header byte, 2 payload bytes. 3 bytes total.
                S <= IDLE;
            case (counter)
                0: begin
                    tx_data <= {2'd0, 6'd0}; // packet type bits kinds are different depeending on direction of packet
                    tx_en <= 1;
                end
                1: begin
                    tx_data <= dma_send_read_queue_data[15:8];
                    tx_en <= 1;
                end
                2: begin
                    tx_data <= dma_send_read_queue_data[7:0];
                    tx_en <= 1;
                end
            endcase
        end

        // MAKE&SEND SEND WRITE COMMAND PACKET
        SENDING_WRITE: if (tx_busyn) begin
            counter <= counter + 1;
            if (counter == 38) // 1 byte for header, Then payload has two parts. 2 bytes for host address and 36 bytes for data
                S <= IDLE;
            case (counter)
                0: begin
                    // eventually send packet length when we support burst write and dma write reordering
                    tx_data <= {2'd1, 6'd0}; // packet type bits kinds are different depeending on direction of packet
                    tx_en <= 1;
                end
                1: begin
                    tx_data <= dma_send_read_queue_data[15:8];
                    tx_en <= 1;
                end
                2: begin
                    tx_data <= dma_send_read_queue_data[7:0];
                    tx_en <= 1;
                    matrix_send_tile <= dma_send_write_queue_data2;
                end
                default: begin
                    tx_data <= matrix_send_tile[18*16-1 -: 8];
                    tx_en <= 1;
                    matrix_send_tile <= matrix_send_tile << 8;
                end
            endcase
        end
    endcase
end



endmodule