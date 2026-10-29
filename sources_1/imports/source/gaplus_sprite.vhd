--------------------------------------------------------------------------------
-- Sprite Engine for "FPGA Gaplus"
-- VHDL translation of gaplus_sprite.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--  Scanline Renderer
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_SPRITE_REND is
  port (
    VCLK : in std_logic;
    HB : in std_logic;
    vpr : in std_logic;
    spra0 : in std_logic_vector(28 downto 0);
    spra1 : in std_logic_vector(23 downto 0);
    wrclk : out std_logic;
    wrrad : out std_logic_vector(5 downto 0);
    SPCH_A : out std_logic_vector(14 downto 0);
    SPCH_D : in std_logic_vector(15 downto 0);

    vpw : out std_logic;
    wp : out std_logic_vector(8 downto 0);
    wd : out std_logic_vector(8 downto 0);
    we : out std_logic
  );
end GAPLUS_SPRITE_REND;

architecture rtl of GAPLUS_SPRITE_REND is

  signal phase : unsigned(7 downto 0) := (others => '0');
  signal hc : unsigned(5 downto 0) := (others => '0');

  signal xf, yf, xs, ys, dp : std_logic;

  signal coffs : std_logic_vector(1 downto 0);
  signal chipno : std_logic_vector(8 downto 0);
  signal paltno : std_logic_vector(5 downto 0);
  signal va : std_logic_vector(3 downto 0);
  signal pdp : std_logic_vector(1 downto 0);
  signal pixd : std_logic_vector(2 downto 0);
  signal hbit : std_logic_vector(3 downto 0);
  signal we_i : std_logic;

  signal hbedge2 : std_logic := '0';

begin

  xf <= spra0(16);
  yf <= spra0(17);

  xs <= spra0(19);
  ys <= spra0(21);

  dp <= spra0(23);

  coffs <= "00" when dp = '1' else
           ((not spra0(28)) xor ((not yf) and ys)) & (std_logic(hc(4)) xor (xf and xs));

  chipno <= std_logic_vector(unsigned(spra0(22) & spra0(7 downto 0)) + unsigned("0000000" & coffs));
  paltno <= spra1(5 downto 0);

  va <= spra0(27 downto 24) xor (yf & yf & yf & yf);
  pdp <= std_logic_vector(hc(1 downto 0)) xor (xf & xf);

  hbit(3) <= SPCH_D(11) when chipno(7) = '1' else
             SPCH_D(15);
  hbit(2) <= SPCH_D(10) when chipno(7) = '1' else
             SPCH_D(14);
  hbit(1) <= SPCH_D(9) when chipno(7) = '1' else
             SPCH_D(13);
  hbit(0) <= SPCH_D(8) when chipno(7) = '1' else
             SPCH_D(12);

  pixd <= (hbit(3) & SPCH_D(7) & SPCH_D(3)) when pdp = "00" else
          (hbit(2) & SPCH_D(6) & SPCH_D(2)) when pdp = "01" else
          (hbit(1) & SPCH_D(5) & SPCH_D(1)) when pdp = "10" else
          (hbit(0) & SPCH_D(4) & SPCH_D(0));

  we_i <= '1' when (xs = '1' and hc < 32) or (xs = '0' and hc < 16) else
          '0';
  we <= we_i;
  wd <= paltno & pixd;

  process (VCLK)
  begin
    if rising_edge(VCLK) then
      if HB = '1' and hbedge2 = '0' then
        phase <= (others => '0');
        hbedge2 <= '1';
      else
        if HB = '0' then
          hbedge2 <= '0';
        end if;
        if phase(7) = '0' then
          case phase(1 downto 0) is
            when "00" =>
              hc <= (others => '0');
              phase <= phase + 1;
            when "01" =>
              phase <= phase + 1;
            when "10" =>
              if we_i = '0' then
                phase <= phase + 2;
              else
                hc <= hc + 1;
              end if;
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  wrclk <= VCLK;
  wrrad <= vpr & std_logic_vector(phase(6 downto 2));
  SPCH_A <= chipno & va(3) & (std_logic_vector(hc(3 downto 2)) xor (xf & xf)) & va(2 downto 0);

  vpw <= not vpr;
  wp <= std_logic_vector((unsigned(spra1(16 downto 8)) - 88) + resize(hc, 9));

end rtl;

--------------------------------------------------------------------------------
--  Attribute Register Scanner
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_SPRITE_REGSCAN is
  port (
    VCLKx4 : in std_logic;
    HB : in std_logic;
    VPOS : in std_logic_vector(7 downto 0);
    SPRA_A : out std_logic_vector(6 downto 0);
    SPRA_D : in std_logic_vector(23 downto 0);
    wwclk : out std_logic;
    wrwad : out std_logic_vector(5 downto 0);
    wrwd0 : out std_logic_vector(28 downto 0);
    wrwd1 : out std_logic_vector(23 downto 0);
    wrwe : out std_logic;
    vpr : out std_logic
  );
end GAPLUS_SPRITE_REGSCAN;

architecture rtl of GAPLUS_SPRITE_REGSCAN is

  signal hcntx4 : unsigned(11 downto 0) := (others => '0');
  signal hbedge : std_logic := '0';
  signal vpf : std_logic := '0';
  signal vpw : std_logic;

  signal nspra0 : std_logic_vector(23 downto 0) := (others => '0');
  signal nspra1 : std_logic_vector(23 downto 0) := (others => '0');

  signal nvpos : std_logic_vector(7 downto 0) := (others => '0');
  signal hramad : unsigned(5 downto 0) := (others => '0');

  signal wrwe0 : std_logic := '0';

  signal nyt : unsigned(7 downto 0);
  signal nys : std_logic;
  signal nvt : std_logic_vector(7 downto 0);
  signal nvh : std_logic;
  signal son : std_logic;

  signal hcnt_m32 : unsigned(11 downto 0);
  signal wrclr : std_logic;

begin

  process (VCLKx4)
  begin
    if rising_edge(VCLKx4) then
      if HB = '1' and hbedge = '0' then
        hcntx4 <= (others => '0');
        vpf <= not vpf;
        hbedge <= '1';
      else
        if HB = '0' then
          hbedge <= '0';
        end if;
        hcntx4 <= hcntx4 + 1;
      end if;
    end if;
  end process;

  vpr <= vpf;
  vpw <= not vpf;

  nyt <= unsigned(nspra0(15 downto 8)) + 27;
  nys <= nspra0(21);
  nvt <= std_logic_vector(unsigned(nvpos) + nyt);
  nvh <= '1' when (nys = '1' and nvt(7 downto 5) = "111") or
         (nys = '0' and nvt(7 downto 4) = "1111") else
         '0';

  son <= '1' when nspra1(17) = '0' and nspra0(15 downto 8) /= x"F0" and
         nspra1(16 downto 8) /= "000000000" else
         '0';

  hcnt_m32 <= hcntx4 - 32;

  wrclr <= '1' when hcntx4 < 32 else
           '0';
  wwclk <= VCLKx4;
  wrwd0 <= (others => '0') when wrclr = '1' else
           nvt(4 downto 0) & nspra0;
  wrwd1 <= (others => '0') when wrclr = '1' else
           nspra1;
  wrwad <= (vpw & std_logic_vector(hcntx4(4 downto 0))) when wrclr = '1' else
           (vpw & std_logic_vector(hramad(4 downto 0)));
  wrwe <= '1' when wrclr = '1' else
          wrwe0;

  process (VCLKx4)
  begin
    if rising_edge(VCLKx4) then
      if hcntx4 = 0 then
        hramad <= (others => '0');
        nvpos <= VPOS;
        wrwe0 <= '0';
      else
        if hcntx4 < 544 and hramad < 32 then
          case hcntx4(2 downto 0) is
            when "000" => nspra0 <= SPRA_D;
            when "001" => nspra1 <= SPRA_D;
            when "100" => wrwe0 <= nvh and son;
            when "101" =>
              if wrwe0 = '1' then
                hramad <= hramad + 1;
              end if;
              wrwe0 <= '0';
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  SPRA_A <= std_logic_vector(hcnt_m32(8 downto 3)) & hcnt_m32(0);

end rtl;

--------------------------------------------------------------------------------
--  Work RAM
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_SPRITE_WRAM is
  port (
    CLKw : in std_logic;
    ADRSw : in std_logic_vector(5 downto 0);
    Dw0 : in std_logic_vector(28 downto 0);
    Dw1 : in std_logic_vector(23 downto 0);
    we : in std_logic;

    CLKr : in std_logic;
    ADRSr : in std_logic_vector(5 downto 0);
    Dr0 : out std_logic_vector(28 downto 0);
    Dr1 : out std_logic_vector(23 downto 0)
  );
end GAPLUS_SPRITE_WRAM;

architecture rtl of GAPLUS_SPRITE_WRAM is
  signal data_i : std_logic_vector(63 downto 0);
  signal q_i : std_logic_vector(63 downto 0);
begin
  data_i <= "00000000000" & Dw1 & Dw0;

  mem : entity work.BUF64_53
    port map(
      data => data_i, rdaddress => ADRSr, rdclock => CLKr,
      wraddress => ADRSw, wrclock => CLKw, wren => we, q => q_i);

  Dr0 <= q_i(28 downto 0);
  Dr1 <= q_i(52 downto 29);
end rtl;

--------------------------------------------------------------------------------
--  Line Buffer
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity LINEBUF is
  port (
    CLKW : in std_logic;
    WEN : in std_logic;
    ADRSW : in std_logic_vector(8 downto 0);
    DIN : in std_logic_vector(8 downto 0);
    CLKR : in std_logic;
    REN : in std_logic;
    ADRSR : in std_logic_vector(8 downto 0);
    DOUT : out std_logic_vector(8 downto 0)
  );
end LINEBUF;

architecture rtl of LINEBUF is
begin
  mem : entity work.LBUF512_9
    port map(
      clock_a => CLKR,
      address_a => ADRSR,
      rden_a => REN,
      q_a => DOUT,
      address_b => ADRSW,
      clock_b => CLKW,
      data_b => DIN,
      wren_b => WEN
    );
end rtl;

--------------------------------------------------------------------------------
--  Line Double Buffer
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_SPRITE_LBUF is
  port (
    CLK : in std_logic;
    SIDE1 : in std_logic;
    WEN : in std_logic;
    ADRSW : in std_logic_vector(8 downto 0);
    DIN : in std_logic_vector(8 downto 0);
    ADRSR : in std_logic_vector(8 downto 0);
    DOUT : out std_logic_vector(8 downto 0)
  );
end GAPLUS_SPRITE_LBUF;

architecture rtl of GAPLUS_SPRITE_LBUF is
  signal OUT0, OUT1 : std_logic_vector(8 downto 0);
  signal SIDE0 : std_logic;
  signal OPAQUE : std_logic;

  signal wen0, wen1 : std_logic;
  signal adw0, adw1 : std_logic_vector(8 downto 0);
  signal din0, din1 : std_logic_vector(8 downto 0);
  signal adrsr_m1 : std_logic_vector(8 downto 0);
begin
  SIDE0 <= not SIDE1;
  OPAQUE <= '1' when DIN(2 downto 0) /= "000" else
            '0';

  DOUT <= OUT1 when SIDE1 = '1' else
          OUT0;

  adrsr_m1 <= std_logic_vector(unsigned(ADRSR) - 1);

  wen0 <= '1' when SIDE0 = '1' else
          (WEN and SIDE1 and OPAQUE);
  adw0 <= adrsr_m1 when SIDE0 = '1' else
          ADRSW;
  din0 <= "000000000" when SIDE0 = '1' else
          DIN;

  wen1 <= '1' when SIDE1 = '1' else
          (WEN and SIDE0 and OPAQUE);
  adw1 <= adrsr_m1 when SIDE1 = '1' else
          ADRSW;
  din1 <= "000000000" when SIDE1 = '1' else
          DIN;

  buf0 : entity work.LINEBUF
    port map(
      CLKW => CLK, WEN => wen0, ADRSW => adw0, DIN => din0,
      CLKR => CLK, REN => SIDE0, ADRSR => ADRSR, DOUT => OUT0);
  buf1 : entity work.LINEBUF
    port map(
      CLKW => CLK, WEN => wen1, ADRSW => adw1, DIN => din1,
      CLKR => CLK, REN => SIDE1, ADRSR => ADRSR, DOUT => OUT1);
end rtl;

--------------------------------------------------------------------------------
--  Sprite Engine
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity GAPLUS_SPRITE is
  port (
    VCLKx4 : in std_logic;
    VCLK : in std_logic;

    HPOS : in std_logic_vector(8 downto 0);
    VPOS : in std_logic_vector(8 downto 0);

    HB : in std_logic;
    VB : in std_logic;

    SPCH_A : out std_logic_vector(14 downto 0);
    SPCH_D : in std_logic_vector(15 downto 0);

    SPRA_A : out std_logic_vector(6 downto 0);
    SPRA_D : in std_logic_vector(23 downto 0);

    CLUT_A : out std_logic_vector(8 downto 0)
  );
end GAPLUS_SPRITE;

architecture rtl of GAPLUS_SPRITE is

  signal wwclk, wrwe, vpr : std_logic;
  signal wrwad : std_logic_vector(5 downto 0);
  signal wrwd0 : std_logic_vector(28 downto 0);
  signal wrwd1 : std_logic_vector(23 downto 0);

  signal wrclk, lwe, vpw : std_logic;
  signal wrrad : std_logic_vector(5 downto 0);
  signal spra0 : std_logic_vector(28 downto 0);
  signal spra1 : std_logic_vector(23 downto 0);
  signal lwp : std_logic_vector(8 downto 0);
  signal lwd : std_logic_vector(8 downto 0);

  signal dout : std_logic_vector(8 downto 0);

begin

  scan : entity work.GAPLUS_SPRITE_REGSCAN
    port map(
      VCLKx4 => VCLKx4, HB => HB, VPOS => VPOS(7 downto 0),
      SPRA_A => SPRA_A, SPRA_D => SPRA_D,
      wwclk => wwclk, wrwad => wrwad, wrwd0 => wrwd0, wrwd1 => wrwd1,
      wrwe => wrwe, vpr => vpr);

  wram : entity work.GAPLUS_SPRITE_WRAM
    port map(
      CLKw => wwclk, ADRSw => wrwad, Dw0 => wrwd0, Dw1 => wrwd1, we => wrwe,
      CLKr => wrclk, ADRSr => wrrad, Dr0 => spra0, Dr1 => spra1);

  rend : entity work.GAPLUS_SPRITE_REND
    port map(
      VCLK => VCLK, HB => HB, vpr => vpr, spra0 => spra0, spra1 => spra1,
      wrclk => wrclk, wrrad => wrrad, SPCH_A => SPCH_A, SPCH_D => SPCH_D,
      vpw => vpw, wp => lwp, wd => lwd, we => lwe);

  lbuf : entity work.GAPLUS_SPRITE_LBUF
    port map(
      CLK => VCLK, SIDE1 => vpw, WEN => lwe, ADRSW => lwp, DIN => lwd,
      ADRSR => HPOS, DOUT => dout);

  CLUT_A <= dout;

end rtl;