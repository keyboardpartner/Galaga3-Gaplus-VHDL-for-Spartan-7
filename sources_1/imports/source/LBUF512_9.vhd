--------------------------------------------------------------------------------
-- Replacement for the Quartus "RAM: 2-PORT" megafunction (altsyncram) LBUF512_9.v
--
-- 512 words x 9 bit simple dual port RAM (BIDIR_DUAL_PORT). As configured in the
-- original megafunction each port has its own clock, a read enable, an address
-- register and an output register (read data two clocks after the address),
-- reading the new data when writing on the same port, power-up content = 0.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LBUF512_9 is
  port (
    address_a : in  std_logic_vector(8 downto 0);
    clock_a   : in  std_logic;
    rden_a    : in  std_logic;
    q_a       : out std_logic_vector(8 downto 0);
    
    address_b : in  std_logic_vector(8 downto 0);
    clock_b   : in  std_logic;
    data_b    : in  std_logic_vector(8 downto 0);
    wren_b    : in  std_logic
  );
end LBUF512_9;

architecture rtl of LBUF512_9 is
  type ram_t is array (0 to 511) of std_logic_vector(8 downto 0);
  shared variable mem : ram_t := (others => (others => '0'));
  signal qa_mem : std_logic_vector(8 downto 0) := (others => '0');
begin
  port_a : process (clock_a)
  begin
    if rising_edge(clock_a) then
      if rden_a = '1' then
        qa_mem <= mem(to_integer(unsigned(address_a)));
      end if;
      q_a <= qa_mem;
    end if;
  end process;

  port_b : process (clock_b)
  begin
    if rising_edge(clock_b) then
      if wren_b = '1' then
        mem(to_integer(unsigned(address_b))) := data_b;
      end if;
    end if;
  end process;
end rtl;
