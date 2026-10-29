--------------------------------------------------------------------------------
-- Wave-base Sound Generator (8CH) with AUX-in
-- VHDL translation of wsg_aux.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity WSG_8CH_AUX is
  port (
    CLK24M : in std_logic;
    RST : in std_logic;

    ADDR : in std_logic_vector(5 downto 0);
    DATA : in std_logic_vector(7 downto 0);
    WE : in std_logic;

    WAVE_CL : out std_logic;
    WAVE_AD : out std_logic_vector(7 downto 0);
    WAVE_DT : in std_logic_vector(3 downto 0);

    AUX_CL : out std_logic;
    AUX_DT : in std_logic_vector(7 downto 0);

    WSG_ENABLE : in std_logic;

    SND : out std_logic_vector(7 downto 0)
  );
end WSG_8CH_AUX;

architecture rtl of WSG_8CH_AUX is

  type slv8_arr is array (0 to 7) of std_logic_vector(7 downto 0);
  type slv4_arr is array (0 to 7) of std_logic_vector(3 downto 0);
  type slv3_arr is array (0 to 7) of std_logic_vector(2 downto 0);
  type slv20_arr is array (0 to 7) of std_logic_vector(19 downto 0);

  -------------------------------------------
  --  Clock Generator & Ctrl Registers
  -------------------------------------------
  signal clk24k_cnt : unsigned(9 downto 0) := (others => '0');

  alias CLK_WSGx8 : std_logic is clk24k_cnt(6); -- 24KHz*8
  alias CLK_WSG : std_logic is clk24k_cnt(9); -- 24KHz

  signal fl : slv8_arr := (others => (others => '0'));
  signal fm : slv8_arr := (others => (others => '0'));
  signal fh : slv4_arr := (others => (others => '0'));
  signal fv : slv3_arr := (others => (others => '0'));
  signal v : slv4_arr := (others => (others => '0'));

  signal ra : integer range 0 to 7;
  signal rc : integer range 0 to 7;

  -------------------------------------------
  --  WSG core (8ch)
  -------------------------------------------
  signal phase : unsigned(2 downto 0) := (others => '0');

  signal o, ot : std_logic_vector(7 downto 0) := (others => '0');
  signal c : slv20_arr := (others => (others => '0'));
  signal wa : std_logic_vector(7 downto 0) := (others => '0');
  signal wm : std_logic_vector(3 downto 0) := (others => '0');
  signal en : std_logic := '0';

  signal mix_o : std_logic_vector(7 downto 0);

begin

  ra <= to_integer(unsigned(ADDR(5 downto 3)));
  rc <= to_integer(clk24k_cnt(2 downto 0));

  process (CLK24M)
  begin
    if rising_edge(CLK24M) then
      if RST = '1' then
        v(rc) <= (others => '0');
      elsif WE = '1' then
        case ADDR(2 downto 0) is
          when "011" => v(ra) <= DATA(3 downto 0);
          when "100" => fl(ra) <= DATA;
          when "101" => fm(ra) <= DATA;
          when "110" =>
            fh(ra) <= DATA(3 downto 0);
            fv(ra) <= DATA(6 downto 4);
          when others => null;
        end case;
      end if;
      clk24k_cnt <= clk24k_cnt + 1;
    end if;
  end process;

  WAVE_CL <= clk24k_cnt(6);
  WAVE_AD <= wa;

  process (CLK_WSGx8)
    variable p : integer range 0 to 7;
    variable fq : std_logic_vector(19 downto 0);
    variable va : unsigned(7 downto 0);
    variable cx : unsigned(19 downto 0);
    variable add : unsigned(7 downto 0);
  begin
    if falling_edge(CLK_WSGx8) then
      p := to_integer(phase);
      fq := fh(p) & fm(p) & fl(p);
      va := unsigned(WAVE_DT) * unsigned(wm);
      cx := unsigned(c(p));

      if en = '1' then
        add := x"0" & va(7 downto 4);
      else
        add := x"00";
      end if;

      if phase /= 0 then
        ot <= std_logic_vector(unsigned(ot) + add);
      else
        o <= ot;
        ot <= std_logic_vector(add);
      end if;
      c(p) <= std_logic_vector(cx + unsigned(fq));
      if unsigned(fq) /= 0 then
        en <= '1';
      else
        en <= '0';
      end if;
      wm <= v(p);
      wa <= fv(p) & std_logic_vector(cx(19 downto 15));
      phase <= phase + 1;
    end if;
  end process;

  mix_o <= std_logic_vector(resize(unsigned(o(6 downto 0)), 8) + unsigned(AUX_DT));

  AUX_CL <= clk24k_cnt(9);
  SND <= '0' & (mix_o(6 downto 0) or (6 downto 0 => mix_o(7)));

end rtl;