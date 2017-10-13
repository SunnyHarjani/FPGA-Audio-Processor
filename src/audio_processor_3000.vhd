library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_processor_3000 is 
  port(
    clk                 : in std_logic;
    reset               : in std_logic;
    execute_btn         : in std_logic;
    sync                : in std_logic;
    audio_in            : in std_logic_vector(15 downto 0);
    led                 : out std_logic_vector(9 downto 0);
    audio_out           : out std_logic_vector(15 downto 0)
  );
end audio_processor_3000;



architecture beh of audio_processor_3000 is
  TYPE state_type is (idle, recording, playing);
  signal current_state, next_state : state_type := idle;
  
  
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
		clk_clk                    : in    std_logic                     := 'X';             -- clk
		reset_reset_n              : in    std_logic                     := 'X';             -- reset_n
		sdram_addr                 : out   std_logic_vector(11 downto 0);                    -- addr
		sdram_ba                   : out   std_logic_vector(1 downto 0);                     -- ba
		sdram_cas_n                : out   std_logic;                                        -- cas_n
		sdram_cke                  : out   std_logic;                                        -- cke
		sdram_cs_n                 : out   std_logic;                                        -- cs_n
		sdram_dq                   : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
		sdram_dqm                  : out   std_logic_vector(3 downto 0);                     -- dqm
		sdram_ras_n                : out   std_logic;                                        -- ras_n
		sdram_we_n                 : out   std_logic;                                        -- we_n
	);
end component nios_system;
  
  signal synced_execute   : std_logic;
  signal DRAM_DQM : std_logic_vector(3 downto 0);
  signal DRAM_BA : std_logic_vector(1 downto 0);
  signal led_state        : std_logic_vector(9 downto 0);
  signal reset_n : std_logic;
  
begin
DRAM_BA_1 <= DRAM_BA(1);
DRAM_BA_0 <= DRAM_BA(0);
DRAM_UDQM <= DRAM_DQM(3 downto 2);
DRAM_LDQM <= DRAM_DQM(1 downto 0);
reset_n <= NOT reset;			

sync_inst : rising_edge_synchronizer
  port map (
    clk     => clk,
    reset   => reset,
    input   => execute_btn,
    edge    => synced_execute
  );
  
  DRAM_data <= audio_in when (we = '1') else (others=>'Z');
  
	process(clk, reset, current_state, next_state) is
	begin
		if reset = '1' then
			current_state <= idle;
		elsif rising_edge(clk) then
			current_state <= next_state;
		else
			current_state <= current_state;
		end if;
	end process;

  process(clk, reset, synced_execute, current_state) is
  begin
    if reset = '1' then
      next_state <= passthrough;
    elsif rising_edge(clk) then
      if synced_execute = '1' then
        case(current_state) is
          when idle => next_state <= recording;
          when recording => next_state <= playing;
          when others => next_state <= idle;
        end case;
      end if;
    end if;
	end process;
  
  	u0 : component nios_system
		port map (
			clk_clk                    => clk,                    --               clk.clk
			reset_reset_n              => reset_n,              --             reset.reset_n
			sdram_addr                 => DRAM_ADDR,                 --             sdram.addr
			sdram_ba                   => DRAM_BA,                   --                  .ba
			sdram_cas_n                => DRAM_CAS_N,                --                  .cas_n
			sdram_cke                  => DRAM_CKE,                  --                  .cke
			sdram_cs_n                 => DRAM_cs_n,                 --                  .cs_n
			sdram_dq                   => DRAM_DQ,                   --                  .dq
			sdram_dqm                  => DRAM_DQM,                  --                  .dqm
			sdram_ras_n                => DRAM_RAS_N,                --                  .ras_n
			sdram_we_n                 => DRAM_WE_N,                 --                  .we_n
		);

  
  -- feedthrough
  process(clk,reset)
  begin 
    if (reset = '1') then 
      audio_out <= (others => '0');
    elsif rising_edge(clk) then
      if (sync = '1') then
        case(current_state) is
          when playing => audio_out <= std_logic_vector(signed(recorded_audio));
          when recording => audio_out <= (others => '0');
          when others => audio_out <= audio_in;
        end case;
      end if;
    end if;
  end process;

  process(clk)
  begin 
    if rising_edge(clk) then
      case(current_state) is
        when recording => led <= "1000000000";
        when playing => led <= "0100000000";
        when others => led <= "1111111111";
      end case;
    end if;
  end process;
end beh;