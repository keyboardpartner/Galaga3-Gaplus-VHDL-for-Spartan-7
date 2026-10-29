--------------------------------------------------------------------------------
-- CPU Modules for "FPGA Gaplus"
-- VHDL translation of gaplus_cpus.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  CPU core wrapper
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity cpu6809 is
  port (
    clkx2    : in  std_logic;
    rst      : in  std_logic;
    rw       : out std_logic;
    vma      : out std_logic;
    address  : out std_logic_vector(15 downto 0);
    data_in  : in  std_logic_vector(7 downto 0);
    data_out : out std_logic_vector(7 downto 0);
    halt     : in  std_logic;
    hold     : in  std_logic;
    irq      : in  std_logic;
    firq     : in  std_logic;
    nmi      : in  std_logic
  );
end cpu6809;

architecture rtl of cpu6809 is

  -- Phase Generator
  signal rE : std_logic := '0';
  signal rQ : std_logic := '0';

  signal nIRQ_s, nFIRQ_s, nNMI_s, nHALT_s, nRESET_s : std_logic;

begin

  process (clkx2)
  begin
    if rising_edge(clkx2) then
      rQ <= not rQ;
    end if;
  end process;

  process (clkx2)
  begin
    if falling_edge(clkx2) then
      rE <= not rE;
    end if;
  end process;

  nIRQ_s   <= not irq;
  nFIRQ_s  <= not firq;
  nNMI_s   <= not nmi;
  nHALT_s  <= not halt;
  nRESET_s <= not rst;

  -- CPU core
  core : entity work.mc6809i
    port map (
      D        => data_in,
      DOut     => data_out,
      ADDR     => address,
      RnW      => rw,
      E        => rE,
      Q        => rQ,
      BS       => open,
      BA       => open,
      nIRQ     => nIRQ_s,
      nFIRQ    => nFIRQ_s,
      nNMI     => nNMI_s,
      AVMA     => open,
      BUSY     => open,
      LIC      => open,
      nHALT    => nHALT_s,
      nRESET   => nRESET_s,
      nDMABREQ => '1',
      RegData  => open
    );

  vma <= rE;

end rtl;


--------------------------------------------------------------------------------
--  Main CPU
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_MAIN is
  port (
    MCPU_CLK     : in  std_logic;
    RESET        : in  std_logic;
    VBLK         : in  std_logic;

    INP0         : in  std_logic_vector(31 downto 0);
    INP1         : in  std_logic_vector(31 downto 0);
    INP2         : in  std_logic_vector(3 downto 0);

    mcpu_ma      : out std_logic_vector(15 downto 0);
    mcpu_we      : out std_logic;
    mcpu_do      : out std_logic_vector(7 downto 0);
    mcpu_mr      : in  std_logic_vector(7 downto 0);

    snd_we       : out std_logic;
    snd_rd       : in  std_logic_vector(7 downto 0);

    mcpu_star_cs : out std_logic;

    SUB_RESET    : out std_logic;
    coin_lamp    : out std_logic;
    start_1_lamp : out std_logic;
    start_2_lamp : out std_logic;
    kick_explode : out std_logic
  );
end GAPLUS_MAIN;

architecture rtl of GAPLUS_MAIN is

  signal mcpu_di   : std_logic_vector(7 downto 0);
  signal mcpu_do_i : std_logic_vector(7 downto 0);
  signal mcpu_ma_i : std_logic_vector(15 downto 0);
  signal mcpu_rw   : std_logic;
  signal mcpu_vma  : std_logic;
  signal mcpu_wr   : std_logic;

  signal mcpu_irom_cs : std_logic;
  signal mcpu_mram_cs : std_logic;
  signal mcpu_srst_cs : std_logic;
  signal mcpu_irqe_cs : std_logic;
  signal mcpu_sndw_cs : std_logic;
  signal mcpu_iocr_cs : std_logic;

  signal mrom_d : std_logic_vector(7 downto 0);

  signal mirq_en   : std_logic := '1';
  signal mcpu_irq  : std_logic;

  signal SUBRESET_r : std_logic := '1';

  signal io_rd : std_logic_vector(7 downto 0);

begin

  mcpu_ma <= mcpu_ma_i;
  mcpu_do <= mcpu_do_i;

  mcpu_wr <= not mcpu_rw;

  mcpu_irom_cs <= mcpu_ma_i(15) and mcpu_vma;
  mcpu_mram_cs <= '1' when mcpu_ma_i(15 downto 13) = "000"   and mcpu_vma = '1' else '0';
  mcpu_srst_cs <= '1' when mcpu_ma_i(15 downto 12) = "1000"  and mcpu_vma = '1' and mcpu_wr = '1' else '0';
  mcpu_irqe_cs <= '1' when mcpu_ma_i(15 downto 12) = "0111"  and mcpu_vma = '1' and mcpu_wr = '1' else '0';
  mcpu_sndw_cs <= '1' when mcpu_ma_i(15 downto 11) = "01100" and mcpu_vma = '1' else '0';

  imn : entity work.MAIN_ROM
    port map (clk => MCPU_CLK, ad => mcpu_ma_i, dt => mrom_d);

  mcpu_we <= mcpu_mram_cs and mcpu_wr;
  snd_we  <= mcpu_sndw_cs and mcpu_wr;

  mcpu_irq <= (not mirq_en) and VBLK;

  SUB_RESET <= SUBRESET_r;

  process (MCPU_CLK, RESET)
  begin
    if RESET = '1' then
      SUBRESET_r <= '1';
      mirq_en    <= '1';
    elsif falling_edge(MCPU_CLK) then
      if mcpu_srst_cs = '1' then
        SUBRESET_r <= mcpu_ma_i(11);
      end if;
      if mcpu_irqe_cs = '1' then
        mirq_en <= mcpu_ma_i(11);
      end if;
    end if;
  end process;

  mcpudsel : entity work.dataselector4
    port map (oDATA => mcpu_di,
              iSEL0 => mcpu_irom_cs, iDATA0 => mrom_d,
              iSEL1 => mcpu_mram_cs, iDATA1 => mcpu_mr,
              iSEL2 => mcpu_sndw_cs, iDATA2 => snd_rd,
              iSEL3 => mcpu_iocr_cs, iDATA3 => io_rd,
              dData => x"FF");

  maincpu : entity work.cpu6809
    port map (clkx2 => MCPU_CLK, rst => RESET, rw => mcpu_rw, vma => mcpu_vma,
              address => mcpu_ma_i, data_in => mcpu_di, data_out => mcpu_do_i,
              halt => '0', hold => '0', irq => mcpu_irq, firq => '0', nmi => '0');

  io : entity work.GAPLUS_IO
    port map (reset => RESET, clk => MCPU_CLK, VBLK => VBLK,
              cpu_ad => mcpu_ma_i, cpu_vma => mcpu_vma, cpu_wr => mcpu_wr, cpu_wd => mcpu_do_i,
              cpu_rd => io_rd, cpu_cs => mcpu_iocr_cs,
              INP0 => INP0, INP1 => INP1, INP2 => INP2,
              coin_lamp => coin_lamp, start_1_lamp => start_1_lamp, start_2_lamp => start_2_lamp,
              pcm_kick => kick_explode);

  mcpu_star_cs <= '1' when mcpu_ma_i(15 downto 11) = "10100" and mcpu_vma = '1' and mcpu_wr = '1' else '0';

end rtl;


--------------------------------------------------------------------------------
--  Sub CPU
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_SUB is
  port (
    SCPU_CLK : in  std_logic;
    RESET    : in  std_logic;
    VBLK     : in  std_logic;

    scpu_mr  : in  std_logic_vector(7 downto 0);
    scpu_ma  : out std_logic_vector(15 downto 0);
    scpu_we  : out std_logic;
    scpu_do  : out std_logic_vector(7 downto 0)
  );
end GAPLUS_SUB;

architecture rtl of GAPLUS_SUB is

  signal scpu_di   : std_logic_vector(7 downto 0);
  signal scpu_do_i : std_logic_vector(7 downto 0);
  signal scpu_ma_i : std_logic_vector(15 downto 0);
  signal scpu_rw   : std_logic;
  signal scpu_vma  : std_logic;
  signal scpu_wr   : std_logic;

  signal scpu_irom_cs : std_logic;
  signal scpu_mram_cs : std_logic;
  signal scpu_irqe_cs : std_logic;

  signal srom_d : std_logic_vector(7 downto 0);

  signal sirq_en  : std_logic := '1';
  signal scpu_irq : std_logic;

begin

  scpu_ma <= scpu_ma_i;
  scpu_do <= scpu_do_i;

  scpu_wr <= not scpu_rw;

  scpu_irom_cs <= scpu_ma_i(15) and scpu_vma;
  scpu_mram_cs <= '1' when scpu_ma_i(15 downto 13) = "000"  and scpu_vma = '1' else '0';
  scpu_irqe_cs <= '1' when scpu_ma_i(15 downto 12) = "0110" and scpu_vma = '1' else '0';

  isb : entity work.SUB_ROM
    port map (clk => SCPU_CLK, ad => scpu_ma_i, dt => srom_d);

  scpu_disel : entity work.dataselector2
    port map (oDATA => scpu_di,
              iSEL0 => scpu_irom_cs, iDATA0 => srom_d,
              iSEL1 => scpu_mram_cs, iDATA1 => scpu_mr,
              dData => x"FF");

  scpu_we <= scpu_mram_cs and scpu_wr;

  scpu_irq <= (not sirq_en) and VBLK;

  process (SCPU_CLK, RESET)
  begin
    if RESET = '1' then
      sirq_en <= '1';
    elsif falling_edge(SCPU_CLK) then
      if scpu_irqe_cs = '1' then
        sirq_en <= not scpu_ma_i(0);
      end if;
    end if;
  end process;

  subcpu : entity work.cpu6809
    port map (clkx2 => SCPU_CLK, rst => RESET, rw => scpu_rw, vma => scpu_vma,
              address => scpu_ma_i, data_in => scpu_di, data_out => scpu_do_i,
              halt => '0', hold => '0', irq => scpu_irq, firq => '0', nmi => '0');

end rtl;
