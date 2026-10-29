--------------------------------------------------------------------------------
-- RAM Modules for "FPGA Gaplus"
-- VHDL translation of rams.v   (Copyright (c) 2007,2019 MiSTer-X)
--
-- Dual clock block RAMs. The array is a shared variable written/read from two
-- clock processes, which is the standard way to infer a true dual clock RAM.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DPRAM_1024V is
  port (
    CL0   : in  std_logic;
    ADRS0 : in  std_logic_vector(9 downto 0);
    IN0   : in  std_logic_vector(7 downto 0);
    OUT0  : out std_logic_vector(7 downto 0);
    WR0   : in  std_logic;
    CL1   : in  std_logic;
    ADRS1 : in  std_logic_vector(9 downto 0);
    OUT1  : out std_logic_vector(7 downto 0)
  );
end DPRAM_1024V;

architecture rtl of DPRAM_1024V is
  type ram_t is array (0 to 1023) of std_logic_vector(7 downto 0);
  shared variable ramcore : ram_t := (others => (others => '0'));
begin
  process (CL0)
  begin
    if rising_edge(CL0) then
      if WR0 = '1' then
        ramcore(to_integer(unsigned(ADRS0))) := IN0;
      else
        OUT0 <= ramcore(to_integer(unsigned(ADRS0)));
      end if;
    end if;
  end process;

  process (CL1)
  begin
    if rising_edge(CL1) then
      OUT1 <= ramcore(to_integer(unsigned(ADRS1)));
    end if;
  end process;
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DPRAM_2048 is
  port (
    CL0   : in  std_logic;
    ADRS0 : in  std_logic_vector(10 downto 0);
    IN0   : in  std_logic_vector(7 downto 0);
    OUT0  : out std_logic_vector(7 downto 0);
    WR0   : in  std_logic;
    CL1   : in  std_logic;
    ADRS1 : in  std_logic_vector(10 downto 0);
    IN1   : in  std_logic_vector(7 downto 0);
    OUT1  : out std_logic_vector(7 downto 0);
    WR1   : in  std_logic
  );
end DPRAM_2048;

architecture rtl of DPRAM_2048 is
  type ram_t is array (0 to 2047) of std_logic_vector(7 downto 0);
  shared variable ramcore : ram_t := (others => (others => '0'));
begin
  process (CL0)
  begin
    if rising_edge(CL0) then
      if WR0 = '1' then
        ramcore(to_integer(unsigned(ADRS0))) := IN0;
      else
        OUT0 <= ramcore(to_integer(unsigned(ADRS0)));
      end if;
    end if;
  end process;

  process (CL1)
  begin
    if rising_edge(CL1) then
      if WR1 = '1' then
        ramcore(to_integer(unsigned(ADRS1))) := IN1;
      else
        OUT1 <= ramcore(to_integer(unsigned(ADRS1)));
      end if;
    end if;
  end process;
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DPRAM_2048V is
  port (
    CL0   : in  std_logic;
    ADRS0 : in  std_logic_vector(10 downto 0);
    IN0   : in  std_logic_vector(7 downto 0);
    OUT0  : out std_logic_vector(7 downto 0);
    WR0   : in  std_logic;
    CL1   : in  std_logic;
    ADRS1 : in  std_logic_vector(10 downto 0);
    OUT1  : out std_logic_vector(7 downto 0)
  );
end DPRAM_2048V;

architecture rtl of DPRAM_2048V is
  type ram_t is array (0 to 2047) of std_logic_vector(7 downto 0);
  shared variable ramcore : ram_t := (others => (others => '0'));
begin
  process (CL0)
  begin
    if rising_edge(CL0) then
      if WR0 = '1' then
        ramcore(to_integer(unsigned(ADRS0))) := IN0;
      else
        OUT0 <= ramcore(to_integer(unsigned(ADRS0)));
      end if;
    end if;
  end process;

  process (CL1)
  begin
    if rising_edge(CL1) then
      OUT1 <= ramcore(to_integer(unsigned(ADRS1)));
    end if;
  end process;
end rtl;
