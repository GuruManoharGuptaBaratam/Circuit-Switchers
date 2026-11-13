`timescale 1ns/1ps

// ============================================================================
// Module: cache_controller
// Owner:  Member 04 - Cache Controller FSM and Main-Memory Model
//
// Function:
//   Sequences one read request at a time through lookup, optional main-memory
//   refill, and response. Ports follow docs/interface_contract.md exactly.
//
// States (see docs/fsm_design.md for the diagram and transition table):
//   IDLE     : req_ready = 1. On req_valid, capture tag/index/offset.
//   LOOKUP   : active_* drive the storage read; lookup_hit is combinational.
//              Hit  -> latch cache_byte_data, go to RESPOND (resp_hit = 1).
//              Miss -> go to MEM_WAIT.
//   MEM_WAIT : mem_req = 1 with a stable aligned address (built in cache_top
//              from active_tag/active_index). Wait for mem_ready.
//              On the mem_ready cycle: refill_write_en = 1 (block, tag and
//              valid bit are installed on that rising edge), latch
//              refill_byte_data, go to RESPOND (resp_hit = 0).
//   RESPOND  : resp_valid = 1 for exactly one cycle, then back to IDLE.
//
// Timing (edge E0 = request-acceptance rising edge; resp_valid is high in the
// cycle after edge Ek, reported as "k+1 cycles"):
//   Hit : 2 cycles            (E0 IDLE->LOOKUP, E1 LOOKUP->RESPOND)
//   Miss: LATENCY + 4 cycles  (E1 LOOKUP->MEM_WAIT, E2 memory accepts,
//                              E2+LATENCY mem_ready, next edge ->RESPOND)
//   Miss penalty over a hit = LATENCY + 2 cycles.
//
// Reset is active-high and synchronous. It returns the FSM to IDLE from any
// state and clears all registered outputs.
// ============================================================================

module cache_controller (
    input  wire        clk,
    input  wire        reset,

    // Processor request side (decoded fields from address_decoder).
    input  wire        req_valid,
    input  wire [21:0] req_tag,
    input  wire [5:0]  req_index,
    input  wire [3:0]  req_offset,
    output wire        req_ready,

    // Captured request fields, stable for the whole transaction.
    output reg  [21:0] active_tag,
    output reg  [5:0]  active_index,
    output reg  [3:0]  active_offset,

    // Lookup / data-path results for the active request.
    input  wire        lookup_hit,
    input  wire [7:0]  cache_byte_data,
    input  wire [7:0]  refill_byte_data,

    // Main-memory handshake and refill control.
    input  wire        mem_ready,
    output wire        mem_req,
    output wire        refill_write_en,

    // Processor response side.
    output wire        resp_valid,
    output reg  [7:0]  resp_data,
    output reg         resp_hit
);

    // ------------------------------------------------------------------------
    // State encoding
    // ------------------------------------------------------------------------
    localparam [1:0] S_IDLE     = 2'd0;
    localparam [1:0] S_LOOKUP   = 2'd1;
    localparam [1:0] S_MEM_WAIT = 2'd2;
    localparam [1:0] S_RESPOND  = 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;

    // ------------------------------------------------------------------------
    // Output decode
    // ------------------------------------------------------------------------
    assign req_ready       = (state == S_IDLE);
    assign mem_req         = (state == S_MEM_WAIT);
    // Refill only in the single cycle where memory reports the block valid.
    assign refill_write_en = (state == S_MEM_WAIT) && mem_ready;
    assign resp_valid      = (state == S_RESPOND);

    // ------------------------------------------------------------------------
    // Next-state logic
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:     if (req_valid)  next_state = S_LOOKUP;
            S_LOOKUP:   next_state = lookup_hit ? S_RESPOND : S_MEM_WAIT;
            S_MEM_WAIT: if (mem_ready)  next_state = S_RESPOND;
            S_RESPOND:  next_state = S_IDLE;
            default:    next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // State register and datapath registers
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state         <= S_IDLE;
            active_tag    <= 22'b0;
            active_index  <= 6'b0;
            active_offset <= 4'b0;
            resp_data     <= 8'b0;
            resp_hit      <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    // Capture the request on the acceptance edge.
                    if (req_valid) begin
                        active_tag    <= req_tag;
                        active_index  <= req_index;
                        active_offset <= req_offset;
                    end
                end

                S_LOOKUP: begin
                    if (lookup_hit) begin
                        resp_data <= cache_byte_data;
                        resp_hit  <= 1'b1;
                    end
                end

                S_MEM_WAIT: begin
                    if (mem_ready) begin
                        // Bypass the requested byte straight from the
                        // returned block (contract section 4, rule 6).
                        resp_data <= refill_byte_data;
                        resp_hit  <= 1'b0;
                    end
                end

                default: ;
            endcase
        end
    end

endmodule
