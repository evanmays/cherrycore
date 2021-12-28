// Handles receipt of packets... one byte at a time. State Machine
// Packet format
// 1 Byte header. First 2 bits are packet type. Next 6 bits are packet length. length is is ignored for some packet types
// Payload. With max packet length of 6 bits, payload may be at most 2^6==64 bytes.
module PacketReceiver(
    input clk,
    input reset,

    // UART connection (no real reason this couldn't be replaced with a high bandwidth link layer like ethernet or pcie. Just feed this module 1 byte at a time)
    input       rx_interrupt,
    input [7:0] rx_data,

    // Receives
    // get a byte from UART
    // if its the completion of read request, forward payload to execution section queue
    output logic             mem_read_result_stb,
    output logic [18*16-1:0] mem_read_result_matrix_tile,
    // if upload program request forward payload to pcache
    output logic             upload_program_stb,
    output logic [15:0]      upload_program_instr_addr,
    output logic [15:0]      upload_program_instr_dat,
    // if start program request forward payload to execution queue.
    output logic       enqueue_program_stb,
    output logic [7:0] enqueue_program_addr
);
enum {IDLE, UPLOAD_PROG_PACKET, ENQUEUE_PROG_PACKET, DATA_READ_RESULT_PACKET} S;
reg instr_MSB;
reg [15:0] counter;
reg [5:0]  packet_length; // measured in bytes
always @(posedge clk) begin
    enqueue_program_stb <= 0;
    upload_program_stb <= 0;
    mem_read_result_stb <= 0;
    case (S)
        IDLE: if (rx_interrupt) begin
            counter <= 0;
            packet_length <= rx_data[7:2]; // only used for upload program packets. In future can use for received data to support burst packets
            case (rx_data[1:0])
                2'd1: S <= UPLOAD_PROG_PACKET;
                2'd2: S <= ENQUEUE_PROG_PACKET;
                2'd3: S <= DATA_READ_RESULT_PACKET;
                2'd0: begin end
            endcase
        end

        // UPLOAD PROGRAM PACKET HANDLE
        // UPLOAD_PROG_PACKET: if (rx_interrupt) begin
        //     counter <= counter + 1;
        //     if (counter + 1 == packet_length)
        //         S <= IDLE;
        //     case (counter)
        //         0: begin
        //             upload_program_instr_addr[15:8] <= rx_data;
        //         end
        //         1: begin
        //             upload_program_instr_addr[7:0] <= rx_data;
        //             upload_program_instr_next_addr <= {upload_program_instr_addr[15:8], rx_data};
        //             instr_MSB <= 1;
        //         end
        //         default: begin
        //             // instructions
        //             if (instr_MSB)
        //                 upload_program_instr_dat[15:8] <= rx_data;
        //             else begin
        //                 upload_program_instr_dat[7:0] <= rx_data;
        //                 upload_program_stb <= 1;
        //             end
        //         end
        //     endcase
        // end

        // // ENQUEUE PROGRAM PACKET HANDLE
        // ENQUEUE_PROG_PACKET: if (rx_interrupt) begin
        //     S <= IDLE;
        //     enqueue_program_stb <= 1;
        //     enqueue_program_addr <= rx_data;
        // end

        // MEM READ COMPLETION PACKET HANDLE
        DATA_READ_RESULT_PACKET: if (rx_interrupt) begin
            counter <= counter + 1;
            if (counter == 35) begin// receive 36 bytes = 4x4x18/8
                S <= IDLE;
                mem_read_result_stb <= 1;
            end
            mem_read_result_matrix_tile <= {mem_read_result_matrix_tile[288-8-1:0], rx_data};
        end
    endcase
end



endmodule