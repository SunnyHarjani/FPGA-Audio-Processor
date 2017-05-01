
module nios_system (
	clk_clk,
	data_in_export,
	data_out_export,
	led_out_export,
	play_btn_in_export,
	record_btn_in_export,
	reset_reset_n,
	sdram_addr,
	sdram_ba,
	sdram_cas_n,
	sdram_cke,
	sdram_cs_n,
	sdram_dq,
	sdram_dqm,
	sdram_ras_n,
	sdram_we_n,
	sync_in_export);	

	input		clk_clk;
	input	[15:0]	data_in_export;
	output	[15:0]	data_out_export;
	output	[9:0]	led_out_export;
	input		play_btn_in_export;
	input		record_btn_in_export;
	input		reset_reset_n;
	output	[11:0]	sdram_addr;
	output	[1:0]	sdram_ba;
	output		sdram_cas_n;
	output		sdram_cke;
	output		sdram_cs_n;
	inout	[15:0]	sdram_dq;
	output	[1:0]	sdram_dqm;
	output		sdram_ras_n;
	output		sdram_we_n;
	input		sync_in_export;
endmodule
