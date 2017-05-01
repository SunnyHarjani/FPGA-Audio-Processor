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
  component rising_edge_synchronizer
    port(
      clk               : in std_logic;
      reset             : in std_logic;
      input             : in std_logic;
      edge              : out std_logic
    );          
  end component;
  
	component nios_system is
		port (
			clk_clk              : in    std_logic                     := 'X';             -- clk
			data_in_export       : in    std_logic_vector(15 downto 0) := (others => 'X'); -- export
			data_out_export      : out   std_logic_vector(15 downto 0);                    -- export
			led_out_export       : out   std_logic_vector(9 downto 0);                     -- export
			play_btn_in_export   : in    std_logic                     := 'X';             -- export
			record_btn_in_export : in    std_logic                     := 'X';             -- export
			reset_reset_n        : in    std_logic                     := 'X';             -- reset_n
			sdram_addr           : out   std_logic_vector(11 downto 0);                    -- addr
			sdram_ba             : out   std_logic_vector(1 downto 0);                     -- ba
			sdram_cas_n          : out   std_logic;                                        -- cas_n
			sdram_cke            : out   std_logic;                                        -- cke
			sdram_cs_n           : out   std_logic;                                        -- cs_n
			sdram_dq             : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
			sdram_dqm            : out   std_logic_vector(1 downto 0);                     -- dqm
			sdram_ras_n          : out   std_logic;                                        -- ras_n
			sdram_we_n           : out   std_logic;                                        -- we_n
			sync_in_export       : in    std_logic                     := 'X'              -- export
		);
	end component nios_system;

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
  
  signal read_ready        : std_logic;
  signal write_ready       : std_logic;
  signal read_s            : std_logic;
  signal write_s           : std_logic;
  signal readdata_left     : std_logic_vector(23 DOWNTO 0);
  signal readdata_right    : std_logic_vector(23 DOWNTO 0);                      
  signal write_data        : std_logic_vector(15 DOWNTO 0);
  signal write_data_24     : std_logic_vector(23 DOWNTO 0);
  signal reset_n           : std_logic;  
  signal reset             : std_logic;
  signal sync              : std_logic;
  signal synced_record_btn : std_logic;
  signal synced_play_btn   : std_logic;
  signal SDRAM_DQM         : std_logic_vector(1 downto 0);
  signal SDRAM_ADDR        : std_logic_vector(11 downto 0);
  
begin
  reset_n <= KEY(0);
  reset <= NOT reset_n;
  sync <= write_ready AND read_ready;
  read_s <= read_ready;
  write_s <= write_ready AND read_ready;
  write_data_24 <= write_data & "00000000";
  DRAM_UDQM <= SDRAM_DQM(1);
  DRAM_LDQM <= SDRAM_DQM(0);
  DRAM_ADDR <= '0' & SDRAM_ADDR;
			

  record_sync : rising_edge_synchronizer
    port map (
      clk     => CLOCK_50,
      reset   => reset,
      input   => KEY(1),
      edge    => synced_record_btn
    );
  play_sync : rising_edge_synchronizer
    port map (
      clk     => CLOCK_50,
      reset   => reset,
      input   => KEY(2),
      edge    => synced_play_btn
    );
  
  	u0 : component nios_system
		port map (
			clk_clk              => CLOCK_50,                   --           clk.clk
			reset_reset_n        => reset_n,                    --         reset.reset_n
			sdram_addr           => SDRAM_ADDR,                 --         sdram.addr
			sdram_ba             => DRAM_BA,                    --              .ba
			sdram_cas_n          => DRAM_CAS_N,                 --              .cas_n
			sdram_cke            => DRAM_CKE,                   --              .cke
			sdram_cs_n           => DRAM_cs_n,                  --              .cs_n
			sdram_dq             => DRAM_DQ,                    --              .dq
			sdram_dqm            => SDRAM_DQM,                  --              .dqm
			sdram_ras_n          => DRAM_RAS_N,                 --              .ras_n
			sdram_we_n           => DRAM_WE_N,                  --              .we_n
			sync_in_export       => sync,                       --       sync_in.export
			record_btn_in_export => synced_record_btn,          -- record_btn_in.export
			play_btn_in_export   => synced_play_btn,            --   play_btn_in.export
			data_out_export      => write_data,                 --      data_out.export
			data_in_export       => readdata_left(23 downto 8), --       data_in.export
			led_out_export       => LEDR                        --       led_out.export
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
end beh;