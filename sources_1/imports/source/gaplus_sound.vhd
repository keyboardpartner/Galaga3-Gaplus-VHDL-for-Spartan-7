--------------------------------------------------------------------------------
-- Sound Module for "FPGA Gaplus"
-- VHDL translation of gaplus_sound.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  Sound module
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_SOUND is
  port (
    RESET : in std_logic;

    CPUCLK : in std_logic;
    CLK24M : in std_logic;
    PCM_CLK : out std_logic;
    VB : in std_logic;

    com_clk : in std_logic;
    com_adrs : in std_logic_vector(10 downto 0);
    com_wd : in std_logic_vector(7 downto 0);
    com_rd : out std_logic_vector(7 downto 0);
    com_we : in std_logic;

    SND : out std_logic_vector(7 downto 0);
    SND_ENABLE : in std_logic
  );
end GAPLUS_SOUND;

architecture rtl of GAPLUS_SOUND is

  signal wave_c : std_logic;
  signal wave_a : std_logic_vector(7 downto 0);
  signal wave_d : std_logic_vector(3 downto 0);
  signal wave_data : std_logic_vector(7 downto 0);

  signal sndrom_a : std_logic_vector(12 downto 0);
  signal sndrom_d : std_logic_vector(7 downto 0);

  signal SNDCPU_ADRS : std_logic_vector(15 downto 0);
  signal SNDCPU_VMA : std_logic;
  signal SNDCPU_RW : std_logic;

  signal SNDCPU_WE : std_logic;

  signal sndram_d : std_logic_vector(7 downto 0);

  signal sndreg_cs : std_logic;
  signal sndram_cs : std_logic;
  signal sndrom_cs : std_logic;
  signal sndirq_cs : std_logic;

  signal SNDCPU_RESET : std_logic;

  signal SNDCPU_IRQEN : std_logic := '1';
  signal SNDCPU_IRQ : std_logic;

  signal SNDCPU_IRQWE : std_logic;

  signal SNDCPU_DO : std_logic_vector(7 downto 0);
  signal SNDCPU_DI : std_logic_vector(7 downto 0);

  signal sndram_we : std_logic;
  signal sndreg_we : std_logic;

begin

  wave : entity work.galaga_4_3f
    port map(clk => wave_c, addr => wave_a, data => wave_data);
  wave_d <= wave_data(3 downto 0);

  isn : entity work.galaga_1_4b
    port map(clk => CPUCLK, addr => sndrom_a, data => sndrom_d);

  SNDCPU_WE <= not SNDCPU_RW;

  sndrom_a <= SNDCPU_ADRS(12 downto 0);

  sndreg_cs <= '1' when SNDCPU_ADRS(15 downto 6) = "0000000000" and SNDCPU_VMA = '1' else
               '0'; -- $0000-$003F
  sndram_cs <= '1' when SNDCPU_ADRS(15 downto 13) = "000" and sndreg_cs = '0' and SNDCPU_VMA = '1' else
               '0'; -- $0000-$1FFF ($400 image)
  sndrom_cs <= '1' when SNDCPU_ADRS(15 downto 14) = "11" and SNDCPU_VMA = '1' else
               '0'; -- $C000-$FFFF
  sndirq_cs <= '1' when SNDCPU_ADRS(15 downto 14) = "01" and SNDCPU_VMA = '1' else
               '0'; -- $4000

  SNDCPU_RESET <= RESET;

  SNDCPU_IRQ <= VB and (not SNDCPU_IRQEN);

  SNDCPU_IRQWE <= sndirq_cs and SNDCPU_WE;

  process (CPUCLK, RESET)
  begin
    if RESET = '1' then
      SNDCPU_IRQEN <= '1';
    elsif falling_edge(CPUCLK) then
      if SNDCPU_IRQWE = '1' then
        SNDCPU_IRQEN <= SNDCPU_ADRS(13);
      end if;
    end if;
  end process;

  sndcpu_disel : entity work.dataselector2
    port map(
      oDATA => SNDCPU_DI,
      iSEL0 => sndram_cs, iDATA0 => sndram_d,
      iSEL1 => sndrom_cs, iDATA1 => sndrom_d,
      dData => x"FF");

  sndcpu : entity work.cpu6809
    port map(
      clkx2 => CPUCLK, rst => SNDCPU_RESET, rw => SNDCPU_RW, vma => SNDCPU_VMA,
      address => SNDCPU_ADRS, data_in => SNDCPU_DI, data_out => SNDCPU_DO,
      halt => '0', hold => '0', irq => SNDCPU_IRQ, firq => '0', nmi => '0');

  sndram_we <= sndram_cs and SNDCPU_WE;
  sndreg_we <= sndreg_cs and SNDCPU_WE;

  sndram : entity work.DPRAM_2048
    port map(
      CL0 => com_clk, ADRS0 => com_adrs, IN0 => com_wd, OUT0 => com_rd, WR0 => com_we,
      CL1 => CPUCLK, ADRS1 => SNDCPU_ADRS(10 downto 0), IN1 => SNDCPU_DO, OUT1 => sndram_d,
      WR1 => sndram_we);

  wsg : entity work.WSG_8CH_AUX
    port map(
      CLK24M => CLK24M, RST => RESET,
      ADDR => SNDCPU_ADRS(5 downto 0), DATA => SNDCPU_DO, WE => sndreg_we,
      WAVE_CL => wave_c, WAVE_AD => wave_a, WAVE_DT => wave_d,
      AUX_CL => PCM_CLK, -- 24 kHz
      AUX_DT => x"00",
      WSG_ENABLE => SND_ENABLE,
      SND => SND);

end rtl;