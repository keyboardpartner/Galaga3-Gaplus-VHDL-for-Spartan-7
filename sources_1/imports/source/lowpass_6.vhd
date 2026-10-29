--------------------------------------------------------------------------------
-- FILTER 1. Ordnung als Hoch- oder Tiefpass
-- by Carsten Meyer, cm@ct.de, 10/2011
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;
--use IEEE.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity lowpass_6 is
  generic (
    FREQU : integer range 0 to 7 := 5 -- 1=5500, 2=2250, 3=1050, 4=510, 5=255, 6=125, 7=62 Hz @ 48KHz sampling clk
  );
  port (
    SYSCLK : in std_logic;
    SYNC : in std_logic;
    INP : in std_logic_vector (11 downto 0); -- input wave data
    FILTER_OUT : out std_logic_vector(11 downto 0)
  );
end entity lowpass_6;

architecture behave of lowpass_6 is
  -- 20 Bit plus 1 Bit headroom
  signal in_temp_6, out_temp_6, adder_6, diff_6 : std_logic_vector (20 downto 0) := (others => '0');

begin

  in_temp_6(19 downto 8) <= INP;
  in_temp_6(20) <= INP(11);

  --FILTER_OUT <= diff_6(19 downto 8);	-- Hochpass 6 dB/Okt., nicht ganz pegelfest bei abrupten starken Spr�ngen
  FILTER_OUT <= out_temp_6(19 downto 8); -- Tiefpass 6 dB/Okt.
  diff_6 <= in_temp_6 - out_temp_6; -- hier bei Tiefpass

  adder_6 <= to_stdlogicvector(to_bitvector(diff_6) sra FREQU);

  delay_register : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then

      -- diff_6 <= in_temp_6 - out_temp_6; -- hier bei Hochpass
      if SYNC = '1' then
        out_temp_6 <= out_temp_6 + adder_6;
      end if;
    end if;
  end process;

end behave;