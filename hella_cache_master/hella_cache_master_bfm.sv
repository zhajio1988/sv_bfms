/****************************************************************************
 * hella_cache_master_bfm.sv
 ****************************************************************************/

/**
 * Module: hella_cache_master_bfm
 * 
 * TODO: Add interface documentation
 */
module hella_cache_master_bfm #(
		parameter int		NUM_ADDR_BITS=32,
		parameter int		NUM_DATA_BITS=32,
		parameter int		NUM_TAG_BITS=7
		)(
		input							clock,
		input							reset,
		output [NUM_ADDR_BITS-1:0]		req_addr,
		input							req_ready,
		output							req_valid,
		output [NUM_TAG_BITS-1:0]		req_tag,
		output [4:0]					req_cmd,
		output [2:0]					req_typ,
		output [NUM_DATA_BITS-1:0]		req_data,
		output [(NUM_DATA_BITS/8)-1:0]	req_data_mask,
		output							req_kill,
		input							rsp_valid,
		input							rsp_nack,
		input  [NUM_TAG_BITS-1:0]		rsp_tag,
		input  [2:0]					rsp_typ,
		input  [NUM_DATA_BITS-1:0]		rsp_data
		);

	hella_cache_master_bfm_core #(
		.NUM_ADDR_BITS  (NUM_ADDR_BITS ), 
		.NUM_DATA_BITS  (NUM_DATA_BITS ), 
		.NUM_TAG_BITS   (NUM_TAG_BITS  )
		) u_core (
		.clock          (clock         ), 
		.reset          (reset         )
		);

	assign req_addr = u_core.req.addr;
	assign u_core.req_ready = req_ready;
	assign req_valid = u_core.req_valid;
	assign req_tag = u_core.req.tag;
	assign req_cmd = u_core.req.cmd;
	assign req_typ = u_core.req.typ;
	assign req_data = u_core.req.data;
	assign req_data_mask = u_core.req.mask;
	assign req_kill = (rsp_nack | u_core.req_kill);
	assign u_core.rsp_valid = rsp_valid;
	assign u_core.rsp_nack = rsp_nack;
	assign u_core.rsp_tag = rsp_tag;
	assign u_core.rsp_typ = rsp_typ;
	assign u_core.rsp_data = rsp_data;

endmodule

interface hella_cache_master_bfm_core #(
		parameter int		NUM_ADDR_BITS=32,
		parameter int		NUM_DATA_BITS=32,
		parameter int		NUM_TAG_BITS=7
		)(
		input			clock,
		input			reset
		);
//pragma attribute hella_cache_master_bfm_core partition_interface_xif
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
	import hella_cache_master_api_pkg::*;
`endif /* HAVE_HDL_VIRTUAL_INTERFACE */
	
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
	hella_cache_master_api			api;
`else
		int unsigned				m_id;
		
		import "DPI-C" context function int unsigned hella_cache_master_bfm_register(string path);
		
		initial begin
			m_id = hella_cache_master_bfm_register($sformatf("%m"));
		end
`endif
	//disabled-pragma tbx one_way_caller_opt api.bfm_rsp on
	typedef struct packed {
		bit[NUM_ADDR_BITS-1:0]		addr;
		bit[NUM_TAG_BITS-1:0]		tag;
		bit[4:0]					cmd;
		bit[2:0]					typ;
		bit[NUM_DATA_BITS-1:0]		data;
		bit[(NUM_DATA_BITS/8)-1:0]	mask;
	} req_data_s;

	req_data_s					req;
	bit							next_req_valid = 0;
	bit							next_req_taken = 0;
	req_data_s					next_req;
	
	wire						req_ready;
	reg							req_valid = 0;
	reg							req_kill = 0;
	wire						rsp_valid;
	wire						rsp_nack;
	wire  [NUM_TAG_BITS-1:0]	rsp_tag;
	wire  [2:0]					rsp_typ;
	wire  [NUM_DATA_BITS-1:0]	rsp_data;
	
	task hella_cache_master_bfm_clear_kill();
		req_kill = 0;
	endtask

	typedef enum {
		REQ_STATE_IDLE,
		REQ_STATE_WAIT_ACCEPT,
		REQ_STATE_DATA,
		REQ_STATE_NACK,
		REQ_STATE_NACK1,
		REQ_STATE_NACK2
	} req_state_e;
	
	req_state_e					req_state;
	bit							in_reset = 0;
	
	always @(posedge clock) begin
		if (reset == 1) begin
			req_state <= REQ_STATE_IDLE;
			next_req_taken <= 0;
			in_reset <= 1;
		end else begin
			if (in_reset) begin
				rst();
				in_reset <= 0;
			end else begin
			if (rsp_valid == 1) begin
				rsp(rsp_tag, rsp_typ, rsp_data);
			end
			case (req_state)
				REQ_STATE_IDLE: begin
					if (next_req_valid == 1) begin
						req <= next_req;
						next_req_taken <= 1;
						req_valid <= 1;
//						$display("%0t - IDLE: receive new request 'h%08h", $time, next_req.addr);
						req_state <= REQ_STATE_WAIT_ACCEPT;
					end
				end
				
				REQ_STATE_WAIT_ACCEPT: begin
					if (req_ready == 1) begin
//						$display("%0t - WAIT_ACCEPT: accepted 'h%08h", $time, req.addr);
						req_valid <= 0;
						req_state <= REQ_STATE_DATA;
						req_kill <= 0;
					end
				end
				
				REQ_STATE_DATA: begin
//					$display("%0t - STATE_DATA: data phase 'h%08h", $time, req.addr);
					req_state <= REQ_STATE_NACK;
				end
				
				REQ_STATE_NACK: begin
					if (rsp_nack == 1) begin
						// Re-issue the request
//						$display("%0t - STATE_NACK: delaying 'h%08h", $time, req.addr);
						req_state <= REQ_STATE_NACK1;
					end else begin
//TODO:						rsp();
						if (next_req_valid == 1) begin
//						$display("%0t - STATE_NACK: next request waiting 'h%08h", $time, next_req.addr);
						req_valid <= 1;
						req <= next_req;
						next_req_taken <= 1;
						req_state <= REQ_STATE_WAIT_ACCEPT;
						end else begin 
//							$display("%0t - STATE_NACK: back to idle", $time);
							req_state <= REQ_STATE_IDLE;
						end
					end
				end
				
				REQ_STATE_NACK1: begin
					req_state <= REQ_STATE_NACK2;
				end
				
				REQ_STATE_NACK2: begin
//					$display("%0t - STATE_NACK: reissue 'h%08h", $time, req.addr);
					req_valid <= 1;
					req_state <= REQ_STATE_WAIT_ACCEPT;
				end
			endcase
			end
		end
	end
	
	task hella_cache_master_bfm_send_req(
		longint unsigned	addr,
		longint unsigned	tag,
		int unsigned		cmd,
		int unsigned		typ,
		longint	unsigned	data,
		int unsigned		data_mask);
		
//		$display("--> %0t - %m send_req 'h%08h", $time, addr);
		
		// Wait for reset
//		while (reset == 1) begin
//			@(posedge clock);
//		end

//		$display("Assign req_cmd=%0d req_typ=%0d", req_cmd, req_typ);
		next_req.addr = addr;
		next_req.tag = tag;
		next_req.cmd = cmd;
		next_req.typ = typ;
		next_req.mask = data_mask;
		next_req.data = data;
	
		// Wait for ready
		next_req_valid = 1;
//		do begin
//			@(posedge clock);
//		end while (next_req_taken == 0);
		next_req_taken = 0;
		next_req_valid = 0;
		
//		@(posedge clock);
//		$display("<-- %0t - %m send_req 'h%08h", $time, addr);
	endtask

`ifdef UNDEFINED	
`endif

`ifndef HAVE_HDL_VIRTUAL_INTERFACE
	import "DPI-C" context task hella_cache_master_bfm_rsp(
			int unsigned		id,
			int unsigned		tag,
			int unsigned		typ,
			longint unsigned	data);
`endif
	
	task rsp(int unsigned tag, int unsigned typ, longint unsigned data);
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
		m_api.rsp(tag, typ, data);
`else
		hella_cache_master_bfm_rsp(m_id, tag, typ, data);
`endif
	endtask
		
`ifndef HAVE_HDL_VIRTUAL_INTERFACE
	import "DPI-C" context task hella_cache_master_bfm_rst(int unsigned id);
`endif
		
	task rst();
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
		m_api.rst();
`else
		hella_cache_master_bfm_rst(m_id);
`endif
	endtask
		
//	task hella_cache_master_bfm_rsp(
//		input int unsigned		tag,
//		input int unsigned		typ,
//		input longint unsigned	data);
//		if (api != null) begin
//			api.bfm_rsp(tag, typ, data);
//		end else begin
//			$display("Error: %m no API handle");
//		end
//	endtask

endinterface

