`default_nettype none
//-------------------------------------------------------------------------------------------------
module clp
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock12,

	output wire[ 7:0] led,

	output wire       dramCk,
	output wire       dramCe,
	output wire       dramCs,
	output wire       dramWe,
	output wire       dramRas,
	output wire       dramCas,
	output wire[ 1:0] dramDQM,
	inout  wire[15:0] dramDQ,
	output wire[ 1:0] dramBA,
	output wire[11:0] dramA,

	output wire[ 1:0] sync,
	output wire[11:0] rgb,

	input  wire       tape,

	output wire       i2sCk,
	output wire       i2sWs,
	output wire       i2sD,

	// output wire       midi,  // cyc_aux4
	// input  wire       midiCk, // cyc_aux7
	// input  wire       midiWs, // cyc_aux6
	// input  wire       midiD,  // cyc_aux5

	input  wire       spiCk,
	input  wire       spiSs2,
	input  wire       spiSs3,
	input  wire       spiSsIo,
	input  wire       spiMosi,
	output wire       spiMiso
);
//--- clock ---------------------------------------------------------------------------------------

	wire clock0;
	wire power0;

	pll0 pll0(clock12, clock0, power0);

	wire clock1;
	wire power1;

	pll1 pll1(clock12, clock1, power1);

	wire clock = model ? clock1 : clock0;
	wire power = power1 && power0;

	reg[3:0] ce;
	always @(negedge clock, negedge power) if(!power) ce <= 1'd0; else ce <= ce+1'd1;

	wire ne14M = ce[1:0] == 3;
	wire ne7M0 = ce[2:0] == 7;
	wire pe7M0 = ce[2:0] == 3;

	wire ne3M5 = ce[3:0] == 15;
	wire pe3M5 = ce[3:0] == 7;
	
//--- mist ----------------------------------------------------------------------------------------

	wire hsync;
	wire vsync;
	wire r;
	wire g;
	wire b;
	wire i;

	wire ps2kCk;
	wire ps2kD;

	wire[7:0] joy1;
	wire[7:0] joy2;

	wire[2:0] mbtns;
	wire[7:0] xaxis;
	wire[7:0] yaxis;

	wire[63:0] status;

	wire[31:0] dioSz;
	wire       dioEn;
	wire[ 7:0] dioIx;
	wire[26:0] dioA;
	wire[ 7:0] dioD;
	wire       dioW;

	wire sdcCs;
	wire sdcCk;
	wire sdcMosi;
	wire sdcMiso;

	mist mist
	(
		.clock  (clock  ),
		.ne14M  (ne14M  ),
		.ne7M0  (ne7M0  ),
		.spiCk  (spiCk  ),
		.spiSs2 (spiSs2 ),
		.spiSs3 (spiSs3 ),
		.spiSsIo(spiSsIo),
		.spiMosi(spiMosi),
		.spiMiso(spiMiso),
		.status (status ),
		.hsync  (hsync  ),
		.vsync  (vsync  ),
		.r      (r      ),
		.g      (g      ),
		.b      (b      ),
		.i      (i      ),
		.sync   (sync   ),
		.rgb    (rgb    ),
		.ps2kCk (ps2kCk ),
		.ps2kD  (ps2kD  ),
		.joy1   (joy1   ),
		.joy2   (joy2   ),
		.mbtns  (mbtns  ),
		.xaxis  (xaxis  ),
		.yaxis  (yaxis  ),
		.dioSz  (dioSz  ),   
		.dioEn  (dioEn  ),   
		.dioIx  (dioIx  ),   
		.dioA   (dioA   ),  
		.dioD   (dioD   ),  
		.dioW   (dioW   ),  
		.sdcCs  (sdcCs  ),
		.sdcCk  (sdcCk  ),
		.sdcMosi(sdcMosi),
		.sdcMiso(sdcMiso)
	);

//--- audio ---------------------------------------------------------------------------------------

	wire[14:0] left;
	wire[14:0] right;

	// wire[15:0] lmidi, rmidi;
	// i2s_decoder i2s_decoder(clock, lmidi, rmidi, midiCk, midiWs, midiD);

	// wire[15:0] lmix = { 1'b0, lmidi[15:1] }^16'h4000+{ 1'd0,  left }+{ 4'd0, {12{ !status[5] && ear}} };
	// wire[15:0] rmix = { 1'b0, rmidi[15:1] }^16'h4000+{ 1'd0, right }+{ 4'd0, {12{ !status[5] && ear}} };

	wire[15:0] lmix = { 1'd0,  left }+{ 4'd0, {12{ !status[5] && ear}} };
	wire[15:0] rmix = { 1'd0, right }+{ 4'd0, {12{ !status[5] && ear}} };

	i2s i2s(clock, lmix, rmix, i2sCk, i2sWs, i2sD);
	
//--- keyboard ------------------------------------------------------------------------------------

	wire      strb;
	wire[7:0] code;

	ps2k ps2k(clock, ps2kCk, ps2kD, strb, code);

	wire[7:0] row;
	wire[4:0] col;
	wire F5;
	wire F9;
	wire play;
	wire stop;

	matrix matrix(clock, strb, code, 6'h3F, 6'h3F, row, col, ,,,, F5, F9, play, stop);

//--- memory --------------------------------------------------------------------------------------

	wire ready;
	wire mreq;
	wire rfsh;

	wire[13:0] a1;
	wire[ 7:0] q1;
	wire w1 = !mreq && !w2 && a2[18:17] == 2 && (a2[16:14] == 5 || a2[16:14] == 7) && !a2[13];

	wire[18:0] a2;
	wire[ 7:0] d2;
	wire[ 7:0] q2 = sdrQ[7:0];
	wire w2;
	wire r2;

	wire romIo = dioEn && dioIx[5:0] == 0;

	reg r2p = 1'b1;
	always @(posedge clock) if(pe3M5) r2p <= r2;

	dprs #(16) drp(clock, a1, q1, clock, { a2[15], a2[12:0] }, d2, w1);

	wire[21:0] sdrA = romIo ? dioA[21:0] : { 3'd0, a2 };
	wire[15:0] sdrD = { 8'hFF, romIo ? dioD : d2 };
	wire[15:0] sdrQ;
	wire       sdrR = !mreq && !r2p;
	wire       sdrW = romIo ? dioW : !mreq && !w2 && a2[18:17];

	sdram sdram
	(
		.clock  (clock  ),
		.reset  (power  ),
		.ready  (ready  ),
		.rfsh   (rfsh   ),
		.a      (sdrA   ),
		.d      (sdrD   ),
		.q      (sdrQ   ),
		.rd     (sdrR   ),
		.wr     (sdrW   ),
		.dramCs (dramCs ),
		.dramRas(dramRas),
		.dramCas(dramCas),
		.dramWe (dramWe ),
		.dramDQM(dramDQM),
		.dramDQ (dramDQ ),
		.dramBA (dramBA ),
		.dramA  (dramA  )
	);

	assign dramCk = clock;
	assign dramCe = 1'b1;

//--- tzx -----------------------------------------------------------------------------------------

	localparam TK = 44;
	localparam TW = $clog2(TK*1024);

	wire         tzxIo = dioEn && dioIx[5:0] == 1;
	wire[TW-1:0] tzxA;

	reg[TW-1:0] tzxSize;
	always @(posedge clock) if(tzxIo) tzxSize <= dioSz[TW-1:0];

	wire[7:0] tzxQ;
	ram #(TK) ram(clock, tzxIo ? dioA[TW-1:0] : tzxA, dioD, tzxQ, tzxIo && dioW);

	wire tzxBusy;
	wire tzxTape;

	tzx #(56000, TW) tzx
	(
		.clock  (clock  ),
		.ce     (1'b1   ),
		.a      (tzxA   ),
		.d      (tzxQ   ),
		.play   (!play  ),
		.stop   (!stop  ),
		.busy   (tzxBusy),
		.size   (tzxSize),
		.tape   (tzxTape)
	);

//--- zx ------------------------------------------------------------------------------------------

	reg rsp = 1'b0;
	reg rse = 1'b1;
	always @(posedge clock) begin rsp <= model; rse <= rsp == model; end

	wire model = status[3];
	wire divmmc = !status[4];

	wire reset = power && F9 && ready && !romIo && !status[1] && rse;
	wire nmi = F5 && !status[2];

	wire ear = tzxBusy ? tzxTape : ~tape;

	zx zx
	(
		.model  (model  ),
		.divmmc (divmmc ),
		.clock  (clock  ),
		.ne7M0  (ne7M0  ),
		.pe7M0  (pe7M0  ),
		.ne3M5  (ne3M5  ),
		.pe3M5  (pe3M5  ),
		.reset  (reset  ),
		.mreq   (mreq   ),
		.rfsh   (rfsh   ),
		.nmi    (nmi    ),
		.a1     (a1     ),
		.q1     (q1     ),
		.a2     (a2     ),
		.d2     (d2     ),
		.q2     (q2     ),
		.r2     (r2     ),
		.w2     (w2     ),
		.hsync  (hsync  ),
		.vsync  (vsync  ),
		.r      (r      ),
		.g      (g      ),
		.b      (b      ),
		.i      (i      ),
		.ear    (ear    ),
		.midi   (       ),
		.left   (left   ),
		.right  (right  ),
		.col    (col    ),
		.row    (row    ),
		.joy1   (joy1   ),
		.joy2   (joy2   ),
		.mbtns  (mbtns  ),
		.xaxis  (xaxis  ),
		.yaxis  (yaxis  ),
		.sdcCs  (sdcCs  ),
		.sdcCk  (sdcCk  ),
		.sdcMosi(sdcMosi),
		.sdcMiso(sdcMiso)
	);

//-------------------------------------------------------------------------------------------------

	assign led = { tape, 6'd0, ~sdcCs };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
