--------------------------------------------------------------------------------
-- Replacement for the Quartus "RAM: 2-PORT" megafunction (altsyncram) BUF64_53.v
--
-- 64 words x 64 bit simple dual port RAM (write port on wrclock, read port on
-- rdclock). As configured in the original megafunction (address register and
-- output register both on rdclock, power-up content = 0) the read data is
-- available two rdclock cycles after the address.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BUF64_53 is
  port (
    data      : in  std_logic_vector(63 downto 0);
    rdaddress : in  std_logic_vector(5 downto 0);
    rdclock   : in  std_logic;
    wraddress : in  std_logic_vector(5 downto 0);
    wrclock   : in  std_logic;
    wren      : in  std_logic;
    q         : out std_logic_vector(63 downto 0)
  );
end BUF64_53;

architecture rtl of BUF64_53 is
  type ram_t is array (0 to 63) of std_logic_vector(63 downto 0);
  shared variable mem : ram_t := (others => (others => '0'));
  signal q_mem : std_logic_vector(63 downto 0) := (others => '0');
begin
  process (wrclock)
  begin
    if rising_edge(wrclock) then
      if wren = '1' then
        mem(to_integer(unsigned(wraddress))) := data;
      end if;
    end if;
  end process;

  process (rdclock)
  begin
    if rising_edge(rdclock) then
      q_mem <= mem(to_integer(unsigned(rdaddress)));
      q     <= q_mem;
    end if;
  end process;
end rtl;
