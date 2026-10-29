--------------------------------------------------------------------------------
-- Video Module for "FPGA Gaplus"
-- VHDL translation of gaplus_video.v   (Copyright (c) 2007,2019 MiSTer-X)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GAPLUS_VIDEO is
  port (
    CLK50M  : in  std_logic;     -- 50.0MHz
    VCLKx4  : in  std_logic;     -- 25.0MHz
    VCLKx2  : in  std_logic;     -- 12.5MHz
    VCLK    : in  std_logic;     -- 6.25MHz

    RESET   : in  std_logic;

    PH      : in  std_logic_vector(8 downto 0);
    PV      : in  std_logic_vector(8 downto 0);
    POUT    : out std_logic_vector(11 downto 0);
    VB      : out std_logic;

    VRAM_A  : out std_logic_vector(10 downto 0);
    VRAM_D  : in  std_logic_vector(15 downto 0);

    SPRA_A  : out std_logic_vector(6 downto 0);
    SPRA_D  : in  std_logic_vector(23 downto 0);

    STAR_AD : in  std_logic_vector(1 downto 0);
    STAR_DT : in  std_logic_vector(7 downto 0);
    STAR_WE : in  std_logic
  );
end GAPLUS_VIDEO; 

architecture rtl of GAPLUS_VIDEO is

  signal HPOS : std_logic_vector(8 downto 0);
  signal VPOS : std_logic_vector(8 downto 0);

  signal VB_i : std_logic;
  signal oHB  : std_logic;

  ----------------------------------------
  --  ROMs
  ----------------------------------------
  signal PALT_A : std_logic_vector(7 downto 0);
  signal PALT_D : std_logic_vector(11 downto 0);

  signal CLT0_A : std_logic_vector(7 downto 0);
  signal CLT0_D : std_logic_vector(3 downto 0);
  signal clt0_data : std_logic_vector(7 downto 0);

  signal CLT1_A : std_logic_vector(8 downto 0);
  signal CLT1_D : std_logic_vector(7 downto 0);

  signal BGCH_A : std_logic_vector(13 downto 0);
  signal BGCH_D : std_logic_vector(7 downto 0);

  signal SPCH_A : std_logic_vector(14 downto 0);
  signal SPCH_D : std_logic_vector(15 downto 0);

  ----------------------------------------
  --  BG Scanline Generator
  ----------------------------------------
  signal BGPN : std_logic_vector(7 downto 0) := (others => '0');
  signal BGHI : std_logic := '0';

  signal COL  : std_logic_vector(5 downto 0);
  signal ROW  : std_logic_vector(5 downto 0);

  signal CHRC : std_logic_vector(8 downto 0);
  signal BGPL : std_logic_vector(5 downto 0);
  signal PRIO : std_logic;

  signal HP   : std_logic_vector(8 downto 0);
  signal VP   : std_logic_vector(8 downto 0);

  signal CHRO : std_logic_vector(7 downto 0);

  signal p0   : std_logic_vector(1 downto 0);
  signal p1   : std_logic_vector(1 downto 0);

  signal vbus0, vbus1, vbusout : std_logic_vector(31 downto 0);

  signal BGCOL : std_logic_vector(7 downto 0);
  signal BGOPQ : std_logic;

  ----------------------------------------
  --  Sprite Engine
  ----------------------------------------
  signal SPCOL : std_logic_vector(7 downto 0);
  signal SPOPQ : std_logic;

  ----------------------------------------
  --  StarField Generator
  ----------------------------------------
  signal starreg0 : std_logic_vector(7 downto 0) := (others => '0');
  signal starreg1 : std_logic_vector(4 downto 0) := (others => '0');
  signal starreg2 : std_logic_vector(4 downto 0) := (others => '0');
  signal starreg3 : std_logic_vector(4 downto 0) := (others => '0');

  signal oSTAR_g : std_logic_vector(7 downto 0);
  signal oSTAR   : std_logic_vector(7 downto 0);

  function stargen_com(com : std_logic_vector(7 downto 0)) return std_logic_vector is
  begin
    case com is
      when x"86" => return "00" & "001";
      when x"85" => return "00" & "010";
      when x"06" => return "00" & "011";

      when x"80" => return "01" & "001";
      when x"82" => return "01" & "010";
      when x"81" => return "01" & "011";

      when x"9F" => return "10" & "011";
      when x"AF" => return "10" & "010";

      when others => return "00000";
    end case;
  end function;

  ----------------------------------------
  --  Color mixer & Pixel output
  ----------------------------------------
  signal BGHIOPQ  : std_logic;
  signal SPTRNSP  : std_logic;
  signal mix_sel0 : std_logic;

begin

  HPOS <= std_logic_vector(unsigned(PH) - 16);
  VPOS <= PV;

  VB_i <= '1' when unsigned(PV) = 224 and unsigned(PH) < 32 else '0';
  VB   <= VB_i;
  oHB  <= '1' when unsigned(PH) >= 290 else '0';

  ----------------------------------------
  --  ROMs
  ----------------------------------------
  palet : entity work.PALET_ROM
    port map (clk => CLK50M, ad => PALT_A, dt => PALT_D);

  clut0 : entity work.galaga_7_6s
    port map (clk => CLK50M, addr => CLT0_A, data => clt0_data);
  CLT0_D <= clt0_data(3 downto 0);

  clut1 : entity work.CLUT1_ROM
    port map (clk => CLK50M, adr => CLT1_A, data => CLT1_D);

  bgch : entity work.BGCH_ROM
    port map (clk => CLK50M, ad => BGCH_A, dt => BGCH_D);

  spch : entity work.SPCH_ROM
    port map (clk => CLK50M, ad => SPCH_A, dt => SPCH_D);

  ----------------------------------------
  --  BG Scanline Generator
  ----------------------------------------
  COL  <= HPOS(8 downto 3);
  ROW  <= std_logic_vector(unsigned(VPOS(8 downto 3)) + 2);

  CHRC <= VRAM_D(15) & VRAM_D(7 downto 0);
  BGPL <= VRAM_D(13 downto 8);
  PRIO <= VRAM_D(14);

  HP   <= HPOS;
  VP   <= VPOS;

  CHRO <= BGCH_D;

  p0 <= '1' & (not HP(0));
  p1 <= '0' & (not HP(0));

  process (VCLK)
  begin
    if rising_edge(VCLK) then
      BGPN <= BGPL & CHRO(to_integer(unsigned(p0))) & CHRO(to_integer(unsigned(p1)));
      BGHI <= PRIO;
    end if;
  end process;

  vbus0 <= "0000000000000000000000" & COL(4 downto 0) & ROW(4 downto 0);
  vbus1 <= "0000000000000000000000" & ROW(4 downto 0) & COL(4 downto 0);

  vramadrs : entity work.busdriver
    port map (iENABLE => '1', iSELECT => COL(5), iBUS0 => vbus0, iBUS1 => vbus1, oBUS => vbusout);

  VRAM_A <= vbusout(10 downto 0);

  BGCH_A <= CHRC & (not HP(2)) & HP(1) & VP(2 downto 0);
  CLT0_A <= BGPN;

  BGCOL <= x"F" & CLT0_D;
  BGOPQ <= '1' when CLT0_D /= x"F" else '0';

  ----------------------------------------
  --  Sprite Engine
  ----------------------------------------
  SPCOL <= CLT1_D;
  SPOPQ <= '1' when CLT1_D /= x"FF" else '0';

  sprite : entity work.GAPLUS_SPRITE
    port map (VCLKx4 => VCLKx4, VCLK => VCLK,
              HPOS => HPOS, VPOS => VPOS,
              HB => oHB, VB => '0',
              SPCH_A => SPCH_A, SPCH_D => SPCH_D,
              SPRA_A => SPRA_A, SPRA_D => SPRA_D,
              CLUT_A => CLT1_A);

  ----------------------------------------
  --  StarField Generator
  ----------------------------------------
  process (VCLKx4, RESET)
  begin
    if RESET = '1' then
      starreg0 <= (others => '0');
      starreg1 <= (others => '0');
      starreg2 <= (others => '0');
      starreg3 <= (others => '0');
    elsif rising_edge(VCLKx4) then
      if STAR_WE = '1' then
        case STAR_AD is
          when "00" => starreg0 <= STAR_DT;
          when "01" => starreg1 <= stargen_com(STAR_DT);
          when "10" => starreg2 <= stargen_com(STAR_DT);
          when others => starreg3 <= stargen_com(STAR_DT);
        end case;
      end if;
    end if;
  end process;

  oSTAR <= oSTAR_g and (7 downto 0 => starreg0(0));

  stargen : entity work.GAPLUS_STARGEN
    port map (VCLK => VCLK, RESET => RESET, VB => VB_i,
              C1 => starreg1, C2 => starreg2, C3 => starreg3, OUTP => oSTAR_g);

  ----------------------------------------
  --  Color mixer & Pixel output
  ----------------------------------------
  BGHIOPQ  <= BGHI and BGOPQ;
  SPTRNSP  <= not SPOPQ;
  mix_sel0 <= BGHIOPQ or (SPTRNSP and BGOPQ);

  colormixer : entity work.dataselector2
    port map (oDATA => PALT_A,
              iSEL0 => mix_sel0, iDATA0 => BGCOL,
              iSEL1 => SPOPQ,    iDATA1 => SPCOL,
              dData => oSTAR);

  POUT <= PALT_D(11 downto 8) & PALT_D(7 downto 4) & PALT_D(3 downto 0);

end rtl;
