--------------------------------------------------------------------------------
-- ROM Modules for "FPGA Gaplus"
-- Sprite Characters ROMs
-- VHDL translation of roms.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MAIN_ROM is
  port (
    clk   : in  std_logic;
    ad    : in  std_logic_vector(15 downto 0);
    dt    : out std_logic_vector(7 downto 0)
  );
end MAIN_ROM;

architecture rtl of MAIN_ROM is
  signal dt0, dt1, dt2 : std_logic_vector(7 downto 0);
begin
  mrom0 : entity work.galaga_4_8d
    port map (clk => clk, addr => ad(12 downto 0), data => dt0);
  mrom1 : entity work.galaga_3_8c
    port map (clk => clk, addr => ad(12 downto 0), data => dt1);
  mrom2 : entity work.galaga_2_8b
    port map (clk => clk, addr => ad(12 downto 0), data => dt2);

  dt <= dt0 when ad(15 downto 13) = "101" else
        dt1 when ad(15 downto 13) = "110" else
        dt2 when ad(15 downto 13) = "111" else
        x"00";
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SUB_ROM is
  port (
    clk   : in  std_logic;
    ad    : in  std_logic_vector(15 downto 0);
    dt    : out std_logic_vector(7 downto 0)
  );
end SUB_ROM;

architecture rtl of SUB_ROM is
  signal dt0, dt1, dt2 : std_logic_vector(7 downto 0);
begin
  srom0 : entity work.galaga_8_11d
    port map (clk => clk, addr => ad(12 downto 0), data => dt0);
  srom1 : entity work.galaga_7_11c
    port map (clk => clk, addr => ad(12 downto 0), data => dt1);
  srom2 : entity work.galaga_6_11b
    port map (clk => clk, addr => ad(12 downto 0), data => dt2);

  dt <= dt0 when ad(15 downto 13) = "101" else
        dt1 when ad(15 downto 13) = "110" else
        dt2 when ad(15 downto 13) = "111" else
        x"00";
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BGCH_ROM is
  port (
    clk   : in  std_logic;
    ad    : in  std_logic_vector(13 downto 0);
    dt    : out std_logic_vector(7 downto 0)
  );
end BGCH_ROM;

architecture rtl of BGCH_ROM is
  signal dt0  : std_logic_vector(7 downto 0);
  signal ad13 : std_logic := '0';
begin
  rom : entity work.galaga_5_8s
    port map (clk => clk, addr => ad(12 downto 0), data => dt0);

  process (clk)
  begin
    if rising_edge(clk) then
      ad13 <= ad(13);
    end if;
  end process;

  dt <= x"0" & dt0(7 downto 4) when ad13 = '1' else dt0;
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SPCH_ROM is
  port (
    clk   : in  std_logic;
    ad    : in  std_logic_vector(14 downto 0);
    dt    : out std_logic_vector(15 downto 0)
  );
end SPCH_ROM;

architecture rtl of SPCH_ROM is
  signal dt0, dt1, dt2, dt3 : std_logic_vector(7 downto 0);
  signal ad_r : std_logic_vector(1 downto 0) := "00";
begin
  rom0 : entity work.galaga_11_11p
    port map (clk => clk, addr => ad(12 downto 0), data => dt0);
  rom1 : entity work.galaga_10_11n
    port map (clk => clk, addr => ad(12 downto 0), data => dt1);
  rom2 : entity work.galaga_12_11r
    port map (clk => clk, addr => ad(12 downto 0), data => dt2);
  rom3 : entity work.galaga_9_11m
    port map (clk => clk, addr => ad(12 downto 0), data => dt3);

  process (clk)
  begin
    if rising_edge(clk) then
      ad_r <= ad(14 downto 13);
    end if;
  end process;

  dt <= x"00" & dt3 when ad_r = "11" else
        x"00" & dt2 when ad_r = "10" else
        dt3 & dt1   when ad_r = "01" else
        dt3 & dt0;
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CLUT1_ROM is
  port (
    clk   : in  std_logic;
    adr   : in  std_logic_vector(8 downto 0);
    data  : out std_logic_vector(7 downto 0)
  );
end CLUT1_ROM;

architecture rtl of CLUT1_ROM is
  signal clut1l_data : std_logic_vector(7 downto 0);
  signal clut1h_data : std_logic_vector(7 downto 0);
begin
  clut1l : entity work.galaga_6_6p
    port map (clk => clk, addr => adr, data => clut1l_data);
  data(3 downto 0) <= clut1l_data(3 downto 0);

  clut1h : entity work.galaga_5_6n
    port map (clk => clk, addr => adr, data => clut1h_data);
  data(7 downto 4) <= clut1h_data(3 downto 0);
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PALET_ROM is
  port (
    clk   : in  std_logic;
    ad    : in  std_logic_vector(7 downto 0);
    dt    : out std_logic_vector(11 downto 0)
  );
end PALET_ROM;

architecture rtl of PALET_ROM is
  signal pr_data, pg_data, pb_data : std_logic_vector(7 downto 0);
begin
  pr : entity work.galaga_3_1p
    port map (clk => clk, addr => ad, data => pr_data);
  dt(3 downto 0) <= pr_data(3 downto 0);
  pg : entity work.galaga_1_1n
    port map (clk => clk, addr => ad, data => pg_data);
  dt(7 downto 4) <= pg_data(3 downto 0);
  pb : entity work.galaga_2_2n
    port map (clk => clk, addr => ad, data => pb_data);
  dt(11 downto 8) <= pb_data(3 downto 0);
end rtl;
