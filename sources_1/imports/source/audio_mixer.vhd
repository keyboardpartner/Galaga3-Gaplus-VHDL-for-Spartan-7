-- Audio Mixer

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity audio_mixer is
  port (
    SYSCLK : in std_logic; -- nom. 50 MHz
    IN_SIGNED_1 : in std_logic_vector(11 downto 0);
    -- IN_SIGNED_2 : in std_logic_vector(11 downto 0);
    -- IN_SIGNED_3 : in std_logic_vector(11 downto 0);
    IN_UNSIGNED : in std_logic_vector(7 downto 0);
    AUDIO_UNSIGNED : out std_logic_vector(11 downto 0) -- unsigned audio 12 Bit, mid = x"800"
  );
end entity audio_mixer;

architecture rtl of audio_mixer is

  signal mix_in_signed : std_logic_vector(11 downto 0); -- signed version of the sum of IN_SIGNED_1, IN_SIGNED_2, and IN_SIGNED_3

begin

  mix_in_signed <= (IN_UNSIGNED - x"80") & "0000";

  audio_proc : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      -- AUDIO_UNSIGNED <= x"800" + (IN_SIGNED_1 + IN_SIGNED_2 + IN_SIGNED_3) + mix_in_signed(11 downto 1);
      AUDIO_UNSIGNED <= x"800" + IN_SIGNED_1 + mix_in_signed(11 downto 1);
    end if;
  end process;

end rtl;