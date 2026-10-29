--------------------------------------------------------------------------------
-- StarField Generator for "FPGA Gaplus"
-- VHDL translation of gaplus_stargen.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_STARGEN is
  port (
    VCLK  : in  std_logic;
    RESET : in  std_logic;

    VB    : in  std_logic;

    C1    : in  std_logic_vector(4 downto 0);
    C2    : in  std_logic_vector(4 downto 0);
    C3    : in  std_logic_vector(4 downto 0);

    OUTP  : out std_logic_vector(7 downto 0)
  );
end GAPLUS_STARGEN;

architecture rtl of GAPLUS_STARGEN is

  subtype lfsr_t is std_logic_vector(15 downto 0);
  subtype sp_t   is unsigned(11 downto 0);

  signal vbtrig : std_logic := '0';

  signal sp1, sp2, sp3     : sp_t := (others => '0');
  signal sp1d, sp2d, sp3d  : std_logic := '0';

  signal sLFSR1 : lfsr_t := x"ACE1";
  signal sLFSR2 : lfsr_t := x"ACE1";
  signal sLFSR3 : lfsr_t := x"ACE1";
  signal LFSR1, LFSR2, LFSR3 : lfsr_t := x"ACE1";

  signal oSTAR1, oSTAR2, oSTAR3 : std_logic_vector(7 downto 0);

  -- dir = '1': backward, dir = '0': forward
  function LFSR(i : lfsr_t; dir : std_logic) return lfsr_t is
  begin
    if dir = '1' then
      return i(14 downto 0) & (((i(15) xor i(4)) xor i(2)) xor i(1));
    else
      return (((i(0) xor i(2)) xor i(3)) xor i(5)) & i(15 downto 1);
    end if;
  end function;

  -- 384 * n for n = 0..7
  function mul384(n : std_logic_vector(2 downto 0)) return sp_t is
  begin
    return resize(unsigned(n) * to_unsigned(384, 9), 12);
  end function;

begin

  oSTAR1 <= LFSR1(7 downto 0) when LFSR1(15 downto 8) = x"80" else x"00";
  oSTAR2 <= LFSR2(7 downto 0) when LFSR2(15 downto 8) = x"90" else x"00";
  oSTAR3 <= LFSR3(7 downto 0) when LFSR3(15 downto 8) = x"A0" else x"00";

  process (VCLK, RESET)
  begin
    if RESET = '1' then

      sLFSR1 <= x"ACE1";
      sLFSR2 <= x"ACE1";
      sLFSR3 <= x"ACE1";

      OUTP   <= (others => '0');

      vbtrig <= '0';

    elsif rising_edge(VCLK) then

      if VB = '1' and vbtrig = '0' then

        if C1(4) = '1' then sp1 <= mul384(C1(2 downto 0)); else sp1 <= resize(unsigned(C1(2 downto 0)), 12); end if;
        sp1d <= C1(3);
        if C2(4) = '1' then sp2 <= mul384(C2(2 downto 0)); else sp2 <= resize(unsigned(C2(2 downto 0)), 12); end if;
        sp2d <= C2(3);
        if C3(4) = '1' then sp3 <= mul384(C3(2 downto 0)); else sp3 <= resize(unsigned(C3(2 downto 0)), 12); end if;
        sp3d <= C3(3);

        LFSR1 <= sLFSR1;
        LFSR2 <= sLFSR2;
        LFSR3 <= sLFSR3;

        vbtrig <= '1';

      else

        if VB = '0' then
          if oSTAR1 /= x"00" then
            OUTP <= oSTAR1;
          elsif oSTAR2 /= x"00" then
            OUTP <= oSTAR2;
          else
            OUTP <= oSTAR3;
          end if;

          LFSR1 <= LFSR(LFSR1, '0');
          LFSR2 <= LFSR(LFSR2, '0');
          LFSR3 <= LFSR(LFSR3, '0');

          vbtrig <= '0';
        end if;

        if sp1 /= 0 then sLFSR1 <= LFSR(sLFSR1, not sp1d); sp1 <= sp1 - 1; end if;
        if sp2 /= 0 then sLFSR2 <= LFSR(sLFSR2, not sp2d); sp2 <= sp2 - 1; end if;
        if sp3 /= 0 then sLFSR3 <= LFSR(sLFSR3, not sp3d); sp3 <= sp3 - 1; end if;

      end if;

    end if;
  end process;

end rtl;
