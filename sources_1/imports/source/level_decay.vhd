--------------------------------------------------------------------------------
-- FILTER 1. Ordnung als Hochpass
-- by Carsten Meyer, cm@ct.de, 10/2011
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity level_decay is
  generic (
    FREQU : integer range 0 to 7 := 6 -- max. 7 Shifts - more shifts = slower
  );
  port (
    SYSCLK : in std_logic;
    INTEGR_TICK : in std_logic; -- Integrate tick
    TRIGGER : in std_logic; -- input level data
    START_VAL : in std_logic_vector(7 downto 0); -- initial value for the decay
    DIFF_OUT : out std_logic_vector(7 downto 0)
  );
end entity level_decay;

architecture behave of level_decay is
  -- 16 Bit, max. 7 Shifts
  signal level_16 : std_logic_vector (15 downto 0);
  signal out_temp_6, adder_6, diff_6 : std_logic_vector (15 downto 0) := (others => '0');
  signal trigger_d1 : std_logic := '0';

begin

  level_16 <= '0' & START_VAL & "0000000";
  adder_6 <= to_stdlogicvector(to_bitvector(diff_6) sra FREQU);
  diff_6 <= level_16 - out_temp_6; -- highpass
  DIFF_OUT <= diff_6(14 downto 7); -- Hochpass 6 dB/Okt., nicht ganz pegelfest bei abrupten starken Spr�ngen

  delay_register : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      if INTEGR_TICK = '1' then
        out_temp_6 <= out_temp_6 + adder_6;
      end if;
      if (trigger_d1 = '0') and (TRIGGER = '1') then
        out_temp_6 <= (others => '0');
      end if;
      trigger_d1 <= TRIGGER;
    end if;
  end process;

end behave;