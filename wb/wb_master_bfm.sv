/****************************************************************************
 * wb_master_bfm.sv
 ****************************************************************************/
 

/**
 * Module: wb_master_bfm
 * 
 * TODO: Add module documentation
 */
module wb_master_bfm #(
		parameter int			WB_ADDR_WIDTH = 32,
		parameter int			WB_DATA_WIDTH = 32
		) (
		input					clk,
		input					rstn,
		wb_if.master			master
		);

	wb_master_bfm_core u_core (
			.clk(clk),
			.rstn(rstn));
	assign u_core.WB_ADDR_WIDTH = WB_ADDR_WIDTH;
	assign u_core.WB_DATA_WIDTH = WB_DATA_WIDTH;
	

	assign u_core.ACK = master.ACK;
	assign u_core.ERR = master.ERR;
	assign master.ADR = u_core.ADR_rs;
	assign master.CTI = u_core.CTI_rs;
	assign master.BTE = u_core.BTE_rs;
	assign master.DAT_W = u_core.DAT_W_rs;
	assign u_core.DAT_R = master.DAT_R;
	assign master.CYC = u_core.CYC_rs;
	assign master.SEL = u_core.SEL_rs;
	assign master.STB = u_core.STB_rs;
	assign master.WE  = u_core.WE_rs;	

endmodule

interface wb_master_bfm_core(
		input						clk,
		input						rstn
		);
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
		import wb_master_api_pkg::*;
`endif

	parameter WB_DATA_WIDTH_P = 64;
	parameter WB_ADDR_WIDTH_P = 64;
	reg							reset = 0;
	reg							reset_done = 0;
	wire[31:0]					WB_ADDR_WIDTH;
	wire[31:0]					WB_DATA_WIDTH;
	
	longint unsigned				write_data_buf;
	longint unsigned				read_data_buf;
	reg								req = 0;
	
	reg[WB_ADDR_WIDTH_P-1:0]		ADR_r;
	reg[WB_ADDR_WIDTH_P-1:0]		ADR_rs;
	reg[2:0]						CTI_r;
	reg[2:0]						CTI_rs;
	reg[1:0]						BTE_r;
	reg[1:0]						BTE_rs;
	reg[WB_DATA_WIDTH_P-1:0]		DAT_W_rs;
	reg								CYC_rs;
	reg[(WB_DATA_WIDTH_P/8)-1:0]	SEL_r;
	reg[(WB_DATA_WIDTH_P/8)-1:0]	SEL_rs;
	reg								STB_rs;
	reg								WE_r;
	reg								WE_rs;
	wire[WB_DATA_WIDTH_P-1:0]		DAT_R;
	wire							ACK;
	wire							ERR;


	
	reg[1:0] state;

`ifdef HAVE_HDL_VIRTUAL_INTERFACE
	wb_master_api				m_api;
`else
	int unsigned				m_id;
	
	initial begin
		m_id = wb_master_bfm_register_hdl($sformatf("%m"));
	end
`endif	

	// BFM State machine
	always @(posedge clk) begin
		if (rstn == 0) begin
			state <= 0;
			req = 0;
			reset <= 1;
			ADR_rs <= 0;
			CTI_rs <= 0;
			BTE_rs <= 0;
			DAT_W_rs <= 0;
			CYC_rs <= 0;
			SEL_rs <= 0;
			STB_rs <= 0;
			WE_rs  <= 0;
		end else begin
			if (reset == 1) begin
				send_reset_done();
				reset_done <= 1;
				reset <= 0;
			end
			case (state)
				0: begin
					if (req) begin
						STB_rs <= 1;
						CYC_rs <= 1;
						ADR_rs <= ADR_r;
						CTI_rs <= CTI_r;
						BTE_rs <= BTE_r;
						WE_rs <= WE_r;
						if (WE_r) begin
							DAT_W_rs <= write_data_buf;
						end else begin
							DAT_W_rs <= 0;
						end
						SEL_rs <= SEL_r;
						state <= 1;
						req = 0;
					end
				end
				
				1: begin
					if (ACK) begin
						response();
						if (!WE_r) begin
							read_data_buf = DAT_R;
						end
						
						STB_rs <= 0;
						CYC_rs <= 0;
						ADR_rs <= 0;
						CTI_rs <= 0;
						BTE_rs <= 0;
						SEL_rs <= 0;

						state <= 0;
					end
				end
			endcase
		end
	end
		
	task wb_master_bfm_get_parameters_hdl(
		input int unsigned			id,
		output int unsigned			addr_width,
		output int unsigned			data_width);
		addr_width = WB_ADDR_WIDTH;
		data_width = WB_DATA_WIDTH;
	endtask
`ifndef HAVE_HDL_VIRTUAL_INTERFACE
		export "DPI-C" task wb_master_bfm_get_parameters_hdl;
`endif /* HAVE_HDL_VIRTUAL_INTERFACE */
	
	task wb_master_bfm_set_data_hdl(
		int unsigned				id,
		int unsigned				idx,
		longint unsigned			data);
		write_data_buf = data;
	endtask
`ifndef HAVE_HDL_VIRTUAL_INTERFACE
	export "DPI-C" task wb_master_bfm_set_data_hdl;
`endif /* HAVE_HDL_VIRTUAL_INTERFACE */
	
	task wb_master_bfm_get_data_hdl(
		input int unsigned				id,
		input int unsigned				idx,
		output longint unsigned			data);
		data = read_data_buf;
	endtask
`ifndef HAVE_HDL_VIRTUAL_INTERFACE
	export "DPI-C" task wb_master_bfm_get_data_hdl;
`endif /* HAVE_HDL_VIRTUAL_INTERFACE */


	/****************************************************************
	 ****************************************************************/
	task wb_master_bfm_request_hdl(
		int unsigned				id,
		longint unsigned 			ADR,
		byte unsigned				CTI,
		byte unsigned				BTE,
		int unsigned				SEL,
		byte unsigned				WE);
//`ifndef BFM_NONBLOCK
//			// Wait for reset
//			while (reset_done == 0) begin
//				@(posedge clk);
//			end
//`endif
		ADR_r = ADR;
		CTI_r = CTI;
		BTE_r = BTE;
		SEL_r = SEL;
		WE_r = WE;
		req = 1;

//		// non-SC BFM version blocks waiting for completion
//`ifndef BFM_NONBLOCK
//			ack = 0; // TODO: should check?
//			do begin
//				@(posedge clk);
//			end while (ack == 0);
//			ack = 0;
//`endif
	endtask
`ifndef HAVE_HDL_VIRTUAL_INTERFACE
	export "DPI-C" task wb_master_bfm_request_hdl;
`endif /* HAVE_HDL_VIRTUAL_INTERFACE */

`ifndef HAVE_HDL_VIRTUAL_INTERFACE
	import "DPI-C" context task wb_master_bfm_response_hdl(
			int unsigned			id,
			byte unsigned			ERR);
	
	import "DPI-C" context task wb_master_bfm_reset_hdl(int unsigned id);
	

	import "DPI-C" context function int unsigned wb_master_bfm_register_hdl(string path);
`endif
	
	task send_reset_done();
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
		m_api.reset();
`else
		wb_master_bfm_reset_hdl(m_id);
`endif
	endtask
		
	task response();
`ifdef HAVE_HDL_VIRTUAL_INTERFACE
		m_api.response(ERR);
`else
		wb_master_bfm_response_hdl(m_id, ERR);
`endif
	endtask
	
endinterface
