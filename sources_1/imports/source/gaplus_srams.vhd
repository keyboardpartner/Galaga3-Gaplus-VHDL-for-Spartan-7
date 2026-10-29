--------------------------------------------------------------------------------
-- Share memory module for "FPGA Gaplus"
-- VHDL translation of gaplus_srams.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_SHAREMEM is
  port (
    clk    : in  std_logic;
    vclk   : in  std_logic;

    sel    : in  std_logic;

    ad0    : in  std_logic_vector(15 downto 0);
    rd0    : out std_logic_vector(7 downto 0);
    wd0    : in  std_logic_vector(7 downto 0);
    we0    : in  std_logic;

    ad1    : in  std_logic_vector(15 downto 0);
    rd1    : out std_logic_vector(7 downto 0);
    wd1    : in  std_logic_vector(7 downto 0);
    we1    : in  std_logic;

    vram_a : in  std_logic_vector(9 downto 0);
    vram_d : out std_logic_vector(15 downto 0);

    spra_a : in  std_logic_vector(6 downto 0);
    spra_d : out std_logic_vector(23 downto 0)
  );
end GAPLUS_SHAREMEM;

architecture rtl of GAPLUS_SHAREMEM is

  signal bus0, bus1, busout : std_logic_vector(31 downto 0);

  signal ad  : std_logic_vector(15 downto 0);
  signal wd  : std_logic_vector(7 downto 0);
  signal we  : std_logic;

  signal o3I, o3J, o3M, o3K, o3L : std_logic_vector(7 downto 0);
  signal e3I, e3J, e3M, e3K, e3L : std_logic;
  signal we3I, we3J, we3M, we3K, we3L : std_logic;

  signal rd : std_logic_vector(7 downto 0);

  signal spra_ax : std_logic_vector(10 downto 0);

begin

  bus0 <= "0000000" & ad0 & wd0 & we0;
  bus1 <= "0000000" & ad1 & wd1 & we1;

  arb : entity work.busdriver
    port map (iENABLE => '1', iSELECT => sel, iBUS0 => bus0, iBUS1 => bus1, oBUS => busout);

  ad <= busout(24 downto 9);
  wd <= busout(8 downto 1);
  we <= busout(0);

  e3I <= '1' when ad(15 downto 10) = "000000" else '0';
  e3J <= '1' when ad(15 downto 10) = "000001" else '0';
  e3M <= '1' when ad(15 downto 11) = "00001"  else '0';
  e3K <= '1' when ad(15 downto 11) = "00010"  else '0';
  e3L <= '1' when ad(15 downto 11) = "00011"  else '0';

  rd <= o3I when e3I = '1' else
        o3J when e3J = '1' else
        o3M when e3M = '1' else
        o3K when e3K = '1' else
        o3L when e3L = '1' else
        x"FF";

  we3I <= we and e3I;
  we3J <= we and e3J;
  we3M <= we and e3M;
  we3K <= we and e3K;
  we3L <= we and e3L;

  spra_ax <= "1111" & spra_a;

  sram3I : entity work.DPRAM_1024V
    port map (CL0 => clk, ADRS0 => ad(9 downto 0), IN0 => wd, OUT0 => o3I, WR0 => we3I,
              CL1 => vclk, ADRS1 => vram_a, OUT1 => vram_d(7 downto 0));
  sram3J : entity work.DPRAM_1024V
    port map (CL0 => clk, ADRS0 => ad(9 downto 0), IN0 => wd, OUT0 => o3J, WR0 => we3J,
              CL1 => vclk, ADRS1 => vram_a, OUT1 => vram_d(15 downto 8));

  sram3M : entity work.DPRAM_2048V
    port map (CL0 => clk, ADRS0 => ad(10 downto 0), IN0 => wd, OUT0 => o3M, WR0 => we3M,
              CL1 => vclk, ADRS1 => spra_ax, OUT1 => spra_d(7 downto 0));
  sram3K : entity work.DPRAM_2048V
    port map (CL0 => clk, ADRS0 => ad(10 downto 0), IN0 => wd, OUT0 => o3K, WR0 => we3K,
              CL1 => vclk, ADRS1 => spra_ax, OUT1 => spra_d(15 downto 8));
  sram3L : entity work.DPRAM_2048V
    port map (CL0 => clk, ADRS0 => ad(10 downto 0), IN0 => wd, OUT0 => o3L, WR0 => we3L,
              CL1 => vclk, ADRS1 => spra_ax, OUT1 => spra_d(23 downto 16));

  rd0 <= rd;
  rd1 <= rd;

end rtl;
