--------------------------------------------------------------------------------
-- Video Timing Generator
-- VHDL translation of hvgen.v
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity HVGEN is
  port (
    HPOS : out std_logic_vector(8 downto 0);
    VPOS : out std_logic_vector(8 downto 0);
    PCLK : in  std_logic;
    iRGB : in  std_logic_vector(11 downto 0);

    oRGB : out std_logic_vector(11 downto 0);
    HBLK : out std_logic;
    VBLK : out std_logic;
    HSYN : out std_logic;
    VSYN : out std_logic
  );
end HVGEN;

architecture rtl of HVGEN is
  signal hcnt : unsigned(8 downto 0) := (others => '0');
  signal vcnt : unsigned(8 downto 0) := (others => '0');

  signal hblk_i : std_logic := '1';
  signal vblk_i : std_logic := '1';
  signal hsyn_i : std_logic := '1';
  signal vsyn_i : std_logic := '1';
begin
  HPOS <= std_logic_vector(hcnt);
  VPOS <= std_logic_vector(vcnt);

  HBLK <= hblk_i;
  VBLK <= vblk_i;
  HSYN <= hsyn_i;
  VSYN <= vsyn_i;

  process (PCLK)
  begin
    if rising_edge(PCLK) then
      case to_integer(hcnt) is
        when 0 =>
          hblk_i <= '0';
          hcnt   <= hcnt + 1;

        when 289 =>
          hblk_i <= '1';
          hcnt   <= hcnt + 1;

        when 311 =>
          hsyn_i <= '0';
          hcnt   <= hcnt + 1;

        when 342 =>
          hsyn_i <= '1';
          hcnt   <= to_unsigned(471, hcnt'length);

        when 511 =>
          hcnt <= (others => '0');

          case to_integer(vcnt) is
            when 223 =>
              vblk_i <= '1';
              vcnt   <= vcnt + 1;

            when 234 =>
              vsyn_i <= '0';
              vcnt   <= vcnt + 1;

            when 241 =>
              vsyn_i <= '1';
              vcnt   <= to_unsigned(492, vcnt'length);

            when 511 =>
              vblk_i <= '0';
              vcnt   <= (others => '0');

            when others =>
              vcnt <= vcnt + 1;
          end case;

        when others =>
          hcnt <= hcnt + 1;
      end case;

    end if;
  end process;

  oRGB <= iRGB when hblk_i = '0' and vblk_i = '0' else (others => '0');

end rtl;
