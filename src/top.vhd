library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  port ( 
    ----- Audio -----
    AUD_ADCDAT : in std_logic; 
    AUD_ADCLRCK : inout std_logic;
    AUD_BCLK : inout std_logic;
    AUD_DACDAT : out std_logic;
    AUD_DACLRCK : inout std_logic;
    AUD_XCK : out std_logic;

    ----- CLOCK -----
    CLOCK_50 : in std_logic;
    CLOCK2_50 : in std_logic;
    CLOCK3_50 : in std_logic;
    CLOCK4_50 : in std_logic;

    ----- SDRAM -----
    DRAM_ADDR : out std_logic_vector(12 downto 0);
    DRAM_BA : out std_logic_vector(1 downto 0);
    DRAM_CAS_N : out std_logic;
    DRAM_CKE : out std_logic;
    DRAM_CLK : out std_logic;
    DRAM_CS_N : out std_logic;
    DRAM_DQ : inout std_logic_vector(15 downto 0);
    DRAM_LDQM : out std_logic;
    DRAM_RAS_N : out std_logic;
    DRAM_UDQM : out std_logic;
    DRAM_WE_N : out std_logic;

    ----- I2C for Audio and Video-In -----
    FPGA_I2C_SCLK : out std_logic;
    FPGA_I2C_SDAT : inout std_logic;

    ----- SEG7 -----
    HEX0 : out std_logic_vector(6 downto 0);
    HEX1 : out std_logic_vector(6 downto 0);
    HEX2 : out std_logic_vector(6 downto 0);
    HEX3 : out std_logic_vector(6 downto 0);
    HEX4 : out std_logic_vector(6 downto 0);
    HEX5 : out std_logic_vector(6 downto 0);

    ----- KEY -----
    KEY : in std_logic_vector(3 downto 0);

    ----- LED -----
    LEDR : out  std_logic_vector(9 downto 0);

    ----- SW -----
    SW : in  std_logic_vector(9 downto 0);

    ----- GPIO_0, GPIO_0 connect to GPIO Default -----
    GPIO_0 : inout  std_logic_vector(35 downto 0);

    ----- GPIO_1, GPIO_1 connect to GPIO Default -----
    GPIO_1 : inout  std_logic_vector(35 downto 0)
  );
end top;

architecture beh of top is
	component DE1_SoC_QSYS is
		port (
			clk_clk                        : in    std_logic                     := 'X';             -- clk
			reset_reset_n                  : in    std_logic                     := 'X';             -- reset_n
			data_in_export                 : in    std_logic_vector(15 downto 0) := (others => 'X'); -- export
			data_out_export                : out   std_logic_vector(15 downto 0);                    -- export
			key_external_connection_export : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- export
			clk_sdram_clk                  : out   std_logic;                                        -- clk
		   --pll_locked_export              : out   std_logic;                                        -- export
			sdram_wire_addr                : out   std_logic_vector(12 downto 0);                    -- addr
			sdram_wire_ba                  : out   std_logic_vector(1 downto 0);                     -- ba
			sdram_wire_cas_n               : out   std_logic;                                        -- cas_n
			sdram_wire_cke                 : out   std_logic;                                        -- cke
			sdram_wire_cs_n                : out   std_logic;                                        -- cs_n
			sdram_wire_dq                  : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
			sdram_wire_dqm                 : out   std_logic_vector(1 downto 0);                     -- dqm
			sdram_wire_ras_n               : out   std_logic;                                        -- ras_n
			sdram_wire_we_n                : out   std_logic;
			sync_in_export                 : in    std_logic                     := 'X';              -- export			-- we_n
			play_btn_in_export             : in    std_logic                     := 'X';             -- export
			record_btn_in_export           : in    std_logic                     := 'X'              -- export
		);
	end component DE1_SoC_QSYS;

  component clock_generator
    port( 
      CLOCK_27 : in std_logic;
      reset    : in std_logic;
      AUD_XCK  : out std_logic
    );
  end component;
  
  component audio_and_video_config
    port( 
      CLOCK_50 : in std_logic;
      reset    : in std_logic;
      I2C_SDAT : INOUT std_logic;
      I2C_SCLK : out std_logic
    );
  end component;   
  
  component audio_codec
    port(
      CLOCK_50        : in std_logic;
      reset           : in std_logic;
      read_s          : in std_logic;
      write_s         : in std_logic;
      writedata_left  : in std_logic_vector(23 DOWNTO 0); 
      writedata_right : in std_logic_vector(23 DOWNTO 0);                 
      AUD_ADCDAT      : in std_logic;
      AUD_BCLK        : in std_logic;
      AUD_ADCLRCK     : in std_logic;
      AUD_DACLRCK     : in std_logic;
      read_ready      : out std_logic; 
      write_ready     : out std_logic;
      readdata_left   : out std_logic_vector(23 DOWNTO 0);
      readdata_right  : out std_logic_vector(23 DOWNTO 0);                
      AUD_DACDAT      : out std_logic
    );
  end component;
  
  signal read_ready       : std_logic;
  signal write_ready      : std_logic;
  signal read_s           : std_logic;
  signal write_s          : std_logic;
  signal readdata_left    : std_logic_vector(23 DOWNTO 0);
  signal readdata_right   : std_logic_vector(23 DOWNTO 0);            
  signal writedata_left   : std_logic_vector(23 DOWNTO 0);
  signal writedata_right  : std_logic_vector(23 DOWNTO 0);             
  signal write_data       : std_logic_vector(15 DOWNTO 0);                        
  signal write_data_24    : std_logic_vector(23 DOWNTO 0);        
  signal reset            : std_logic;
  signal SDRAM_DQM : std_logic_vector(1 downto 0);
  signal SDRAM_ADDR : std_logic_vector(11 downto 0);
  
  signal reset_n : std_logic;
  
begin
  reset_n <= KEY(0);
  reset <= NOT reset_n;

  writedata_left <= readdata_left;
  writedata_right <= readdata_right;
  read_s <= read_ready;
  write_s <= write_ready AND read_ready;
  
  DRAM_UDQM <= SDRAM_DQM(1);
  DRAM_LDQM <= SDRAM_DQM(0);

	u0 : component DE1_SoC_QSYS
		port map (
			clk_clk                        => CLOCK_50,                        --                     clk.clk
			reset_reset_n                  => reset_n,                  --                   reset.reset_n
			data_in_export                 => readdata_left(23 downto 8),
			data_out_export                => write_data,
			key_external_connection_export => KEY, -- key_external_connection.export
			clk_sdram_clk                  => DRAM_CLK,                  --               clk_sdram.clk
			--pll_locked_export              => CONNECTED_TO_pll_locked_export,              --              pll_locked.export
			sdram_wire_addr                => DRAM_ADDR,                --              sdram_wire.addr
			sdram_wire_ba                  => DRAM_BA,                  --                        .ba
			sdram_wire_cas_n               => DRAM_CAS_N,               --                        .cas_n
			sdram_wire_cke                 => DRAM_CKE,                 --                        .cke
			sdram_wire_cs_n                => DRAM_cs_n,                --                        .cs_n
			sdram_wire_dq                  => DRAM_DQ,                  --                        .dq
			sdram_wire_dqm                 => SDRAM_DQM,                 --                        .dqm
			sdram_wire_ras_n               => DRAM_RAS_N,               --                        .ras_n
			sdram_wire_we_n                => DRAM_WE_N,  
			sync_in_export						 => write_s,												--                        .we_n
			play_btn_in_export             => KEY(1),             --             play_btn_in.export
			record_btn_in_export           => KEY(2)            --           record_btn_in.export
		);
  
  my_clock_gen: clock_generator 
    port map (
      CLOCK_27  => CLOCK2_50, 
      reset     => reset, 
      AUD_XCK   => AUD_XCK
    );
      
  cfg: audio_and_video_config 
    port map (
      CLOCK_50  => CLOCK_50,
      reset     => reset,
      I2C_SDAT  => FPGA_I2C_SDAT,
      I2C_SCLK  => FPGA_I2C_SCLK
    );
    
  codec: audio_codec 
    port map (
      CLOCK_50          => CLOCK_50,
      reset             => reset,
      read_s            => read_s,
      write_s           => write_s,
      writedata_left    => write_data_24,
      writedata_right   => write_data_24,
      AUD_ADCDAT        => AUD_ADCDAT,
      AUD_BCLK          => AUD_BCLK,
      AUD_ADCLRCK       => AUD_ADCLRCK,
      AUD_DACLRCK       => AUD_DACLRCK,
      read_ready        => read_ready,
      write_ready       => write_ready,
      readdata_left     => readdata_left,
      readdata_right    => readdata_right,
      AUD_DACDAT        => AUD_DACDAT
    );
    
    write_data_24 <= write_data & "00000000";
    LEDR <= "1010101010";
end beh;