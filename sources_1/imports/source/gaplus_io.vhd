--------------------------------------------------------------------------------
-- I/O Module for "FPGA Gaplus"
-- VHDL translation of gaplus_io.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  Binary to BCD converter (0..99) using a 100 byte table
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BCDCONV is
  port (
    A    : in  std_logic_vector(7 downto 0);
    ONES : out std_logic_vector(3 downto 0);
    TENS : out std_logic_vector(3 downto 0)
  );
end BCDCONV;

architecture rtl of BCDCONV is
  type bcd_lut_t is array (0 to 99) of std_logic_vector(7 downto 0);
  constant bcd_lut : bcd_lut_t := (
    x"00", x"01", x"02", x"03", x"04", x"05", x"06", x"07",
    x"08", x"09", x"10", x"11", x"12", x"13", x"14", x"15",
    x"16", x"17", x"18", x"19", x"20", x"21", x"22", x"23",
    x"24", x"25", x"26", x"27", x"28", x"29", x"30", x"31",
    x"32", x"33", x"34", x"35", x"36", x"37", x"38", x"39",
    x"40", x"41", x"42", x"43", x"44", x"45", x"46", x"47",
    x"48", x"49", x"50", x"51", x"52", x"53", x"54", x"55",
    x"56", x"57", x"58", x"59", x"60", x"61", x"62", x"63",
    x"64", x"65", x"66", x"67", x"68", x"69", x"70", x"71",
    x"72", x"73", x"74", x"75", x"76", x"77", x"78", x"79",
    x"80", x"81", x"82", x"83", x"84", x"85", x"86", x"87",
    x"88", x"89", x"90", x"91", x"92", x"93", x"94", x"95",
    x"96", x"97", x"98", x"99"
  );
begin
  ONES <= bcd_lut(to_integer(unsigned(A)))(3 downto 0);
  TENS <= bcd_lut(to_integer(unsigned(A)))(7 downto 4);
end rtl;


--------------------------------------------------------------------------------
--  I/O chips #0/#1 (credits, switches)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_IO_CUS0 is
  generic (
    CUS_ID : natural range 0 to 1 := 0
  );
  port (
    reset   : in  std_logic;
    clk     : in  std_logic;
    VB      : in  std_logic;
    cs      : in  std_logic;
    adrs    : in  std_logic_vector(3 downto 0);
    rd      : out std_logic_vector(3 downto 0);
    wd      : in  std_logic_vector(3 downto 0);
    we      : in  std_logic;
    coin_lamp : out  std_logic;
    start_1_lamp : out  std_logic;
    start_2_lamp : out  std_logic;

    INPORT  : in  std_logic_vector(31 downto 0)
  );
end GAPLUS_IO_CUS0;

architecture rtl of GAPLUS_IO_CUS0 is

  type regs_t is array (0 to 15) of std_logic_vector(3 downto 0);
  signal regs : regs_t := (others => (others => '0'));

  signal out_r : std_logic_vector(3 downto 0) := (others => '0');

  signal credits : std_logic_vector(7 downto 0) := (others => '0');

  signal pINPORT, fINPORT : std_logic_vector(31 downto 0) := (others => '0');
  signal iINPORT          : std_logic_vector(31 downto 0);

  signal CREDIT_ONES, CREDIT_TENS : std_logic_vector(3 downto 0);

  signal pVB : std_logic := '0';

begin

  iINPORT <= (fINPORT xor pINPORT) and fINPORT;

  creditsBCD : entity work.BCDCONV
    port map (A => credits, ONES => CREDIT_ONES, TENS => CREDIT_TENS);

  coin_lamp <= '1' when credits = x"00" else '0';
  start_1_lamp <= '1' when credits > x"00" else '0';
  start_2_lamp <= '1' when credits > x"02" else '0';

  process (clk, reset)
    -- credit_add / credit_sub keep their value between clocks (registers in the Verilog)
    variable credit_add : std_logic_vector(7 downto 0) := (others => '0');
    variable credit_sub : std_logic_vector(7 downto 0) := (others => '0');
    variable cr         : unsigned(7 downto 0);
  begin
    if reset = '1' then
      out_r   <= x"F";
      credits <= (others => '0');

      pVB <= '0';
    elsif rising_edge(clk) then

      cr := unsigned(credits);

      if VB = '0' then
        pVB <= '0';
      elsif pVB = '0' then

        if (CUS_ID = 0 and regs(8) = x"4") or
           (CUS_ID = 1 and regs(8) = x"3") then

          credit_add := x"00";
          credit_sub := x"00";

          if iINPORT(0) = '1' and cr < 99 then
            credit_add := x"01";
            cr := cr + 1;
          end if;

          if regs(9) = x"0" then
            if cr >= 2 and iINPORT(15) = '1' then
              credit_sub := x"02";
              cr := cr - 2;
            elsif cr >= 1 and iINPORT(14) = '1' then
              credit_sub := x"01";
              cr := cr - 1;
            end if;
          end if;
        end if;

        pINPORT <= fINPORT;
        fINPORT <= INPORT;
        pVB <= '1';
      end if;

      if cs = '1' then
        if we = '1' then
          regs(to_integer(unsigned(adrs))) <= wd;
        else
          out_r <= regs(to_integer(unsigned(adrs)));
        end if;
      end if;

      if regs(8) = x"1" then      -- Switches Input
        if CUS_ID = 0 then
          regs(0) <= fINPORT(3 downto 0);
          regs(1) <= fINPORT(7 downto 4);
          regs(2) <= fINPORT(11 downto 8);
          regs(3) <= fINPORT(15 downto 12);
        else
          regs(4) <= fINPORT(3 downto 0);
          regs(5) <= fINPORT(7 downto 4);
          regs(6) <= fINPORT(11 downto 8);
          regs(7) <= fINPORT(15 downto 12);
        end if;
      end if;

      if (CUS_ID = 0 and regs(8) = x"4") or
         (CUS_ID = 1 and regs(8) = x"3") then -- Handle Coin & Switches Input
        if CUS_ID = 0 then
          regs(0) <= CREDIT_TENS;
          regs(1) <= CREDIT_ONES;
          regs(2) <= credit_add(3 downto 0);
          regs(3) <= credit_sub(3 downto 0);
        else
          regs(0) <= credit_add(3 downto 0);
          regs(1) <= credit_sub(3 downto 0);
          regs(2) <= CREDIT_TENS;
          regs(3) <= CREDIT_ONES;
        end if;

        regs(4) <= fINPORT(7 downto 4);
        regs(5) <= fINPORT(14) & iINPORT(14) & fINPORT(12) & iINPORT(12);
        regs(6) <= INPORT(11 downto 8);
        regs(7) <= fINPORT(15) & iINPORT(15) & fINPORT(13) & iINPORT(13);
      end if;

      if (CUS_ID = 0 and regs(8) = x"8") or
         (CUS_ID = 1 and regs(8) = x"5") then -- Bootup check
        if CUS_ID = 0 then
          regs(0) <= x"6";
          regs(1) <= x"9";
        else
          regs(0) <= x"F";
          regs(1) <= x"F";
        end if;
      end if;

      if (CUS_ID = 0 and regs(8) = x"9") or
         (CUS_ID = 1 and regs(8) = x"4") then -- DIP Switches Input
        regs(0) <= fINPORT(3 downto 0);
        regs(2) <= fINPORT(7 downto 4);
        regs(4) <= fINPORT(11 downto 8);
        regs(6) <= fINPORT(15 downto 12);

        regs(1) <= fINPORT(19 downto 16);
        regs(3) <= fINPORT(23 downto 20);
        regs(5) <= fINPORT(27 downto 24);
        regs(7) <= fINPORT(31 downto 28);
      end if;

      credits <= std_logic_vector(cr);

    end if;
  end process;

  rd <= out_r;

end rtl;


--------------------------------------------------------------------------------
--  Custom I/O chip #2 (service/cabinet switches, PCM kick)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_IO_CUS2 is
  port (
    reset   : in  std_logic;
    clk     : in  std_logic;
    cs      : in  std_logic;
    adrs    : in  std_logic_vector(3 downto 0);
    rd      : out std_logic_vector(7 downto 0);
    wd      : in  std_logic_vector(7 downto 0);
    we      : in  std_logic;
    kickpcm : out std_logic;

    INP     : in  std_logic_vector(3 downto 0)
  );
end GAPLUS_IO_CUS2;

architecture rtl of GAPLUS_IO_CUS2 is

  type regs_t is array (0 to 15) of std_logic_vector(7 downto 0);
  signal regs  : regs_t := (others => (others => '0'));
  signal mode  : std_logic_vector(7 downto 0) := (others => '0');
  signal out_r : std_logic_vector(7 downto 0) := (others => '0');
  signal nkick : unsigned(8 downto 0) := (others => '0');

begin

  process (clk, reset)
    variable a : integer range 0 to 15;
  begin
    if reset = '1' then
      nkick <= (others => '0');
      out_r <= x"FF";
    elsif rising_edge(clk) then
      a := to_integer(unsigned(adrs));
      if cs = '1' then
        if we = '1' then
          regs(a) <= wd;
          if a = 8 then
            mode <= wd;
          elsif a = 9 then
            nkick <= "111111111";
          end if;
        else
          case a is
            when 0 =>
              out_r <= x"0" & INP;     -- {SRVSW,Cabinet,2'b11}
            when 1 =>
              if mode = x"02" then
                out_r <= regs(a);
              else
                out_r <= x"0F";
              end if;
            when 2 =>
              if mode = x"02" then
                out_r <= x"0F";
              else
                out_r <= x"0E";
              end if;
            when 3 =>
              if mode = x"02" then
                out_r <= regs(a);
              else
                out_r <= x"01";
              end if;
            when others =>
              out_r <= regs(a);
          end case;
        end if;
      end if;
      if nkick /= 0 then
        nkick <= nkick - 1;
      end if;
    end if;
  end process;

  rd      <= out_r;
  kickpcm <= '1' when nkick /= 0 else '0';

end rtl;


--------------------------------------------------------------------------------
--  I/O module
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_IO is
  port (
    reset    : in  std_logic;
    clk      : in  std_logic;
    VBLK     : in  std_logic;

    cpu_ad   : in  std_logic_vector(15 downto 0);
    cpu_vma  : in  std_logic;
    cpu_wr   : in  std_logic;
    cpu_wd   : in  std_logic_vector(7 downto 0);
    cpu_rd   : out std_logic_vector(7 downto 0);
    cpu_cs   : out std_logic;

    INP0     : in  std_logic_vector(31 downto 0);
    INP1     : in  std_logic_vector(31 downto 0);
    INP2     : in  std_logic_vector(3 downto 0);

    coin_lamp    : out std_logic;
    start_1_lamp : out std_logic;
    start_2_lamp : out std_logic;
    pcm_kick : out std_logic
  );
end GAPLUS_IO;

architecture rtl of GAPLUS_IO is

  signal io_cs     : std_logic;
  signal iochp0_cs : std_logic;
  signal iochp1_cs : std_logic;
  signal iocust_cs : std_logic;

  signal iochp0_rd : std_logic_vector(3 downto 0);
  signal iochp1_rd : std_logic_vector(3 downto 0);
  signal iocust_rd : std_logic_vector(7 downto 0);

  signal io_rd     : std_logic_vector(3 downto 0);

begin

  io_cs <= '1' when cpu_ad(15 downto 8) = x"68" and cpu_vma = '1' else '0';

  iochp0_cs <= io_cs when cpu_ad(7 downto 4) = x"0" else '0';
  iochp1_cs <= io_cs when cpu_ad(7 downto 4) = x"1" else '0';
  iocust_cs <= io_cs when cpu_ad(7 downto 4) = x"2" else '0';

  io_rd <= iochp0_rd          when iochp0_cs = '1' else
           iochp1_rd          when iochp1_cs = '1' else
           iocust_rd(3 downto 0) when iocust_cs = '1' else
           x"F";

  cpu_cs <= io_cs;
  cpu_rd <= x"F" & io_rd;

  iochp0 : entity work.GAPLUS_IO_CUS0
    generic map (CUS_ID => 0)
    port map (reset => reset, clk => clk, VB => VBLK, cs => iochp0_cs, adrs => cpu_ad(3 downto 0),
              rd => iochp0_rd, wd => cpu_wd(3 downto 0), we => cpu_wr,
              coin_lamp => coin_lamp, start_1_lamp => start_1_lamp, start_2_lamp => start_2_lamp,
              INPORT => INP0);

  iochp1 : entity work.GAPLUS_IO_CUS0
    generic map (CUS_ID => 1)
    port map (reset => reset, clk => clk, VB => VBLK, cs => iochp1_cs, adrs => cpu_ad(3 downto 0),
              rd => iochp1_rd, wd => cpu_wd(3 downto 0), we => cpu_wr,
              coin_lamp => open, start_1_lamp => open, start_2_lamp => open,
              INPORT => INP1);

  iocust : entity work.GAPLUS_IO_CUS2
    port map (reset => reset, clk => clk, cs => iocust_cs, adrs => cpu_ad(3 downto 0),
              rd => iocust_rd, wd => cpu_wd, we => cpu_wr, kickpcm => pcm_kick, INP => INP2);

end rtl;
