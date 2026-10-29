--------------------------------------------------------------------------------
-- FPGA Gaplus port to MiSTer
--
-- VHDL translation of fpga_gaplus.v
-- Copyright (c) 2007,2019 MiSTer-X
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FPGA_GAPLUS is
  port (
    SYSCLK50 : in std_logic; -- MasterClock: 49.125MHz
    RESET : in std_logic; -- RESET

    PCLK : out std_logic; -- Pixel Clock
    RED : out std_logic_vector(3 downto 0); -- Pixel Color
    GREEN : out std_logic_vector(3 downto 0); -- Pixel Color
    BLUE : out std_logic_vector(3 downto 0); -- Pixel Color
    HSYNC : out std_logic; -- Horizontal Sync
    VSYNC : out std_logic; -- Vertical Sync
    SOUND : out std_logic_vector(7 downto 0); -- Sound Out
    PCM_CLK : out std_logic; -- PCM Clock for sound module
    PCM_KICK : out std_logic; -- External explosion sound trigger
    COIN_LAMP : out std_logic;
    START_1_LAMP : out std_logic;
    START_2_LAMP : out std_logic;

    -- Joysticks and Buttons (Active Logic)
    UP_1 : in std_logic;
    DOWN_1 : in std_logic;
    LEFT_1 : in std_logic;
    RIGHT_1 : in std_logic;
    FIRE_1 : in std_logic;

    UP_2 : in std_logic;
    DOWN_2 : in std_logic;
    LEFT_2 : in std_logic;
    RIGHT_2 : in std_logic;
    FIRE_2 : in std_logic;

    COIN : in std_logic;
    START_1 : in std_logic;
    START_2 : in std_logic;
    SERVICE_SW : in std_logic;

    -- DIP switch settings
    DSW0 : in std_logic_vector(7 downto 0); -- DIPSWs (Active High Logic)
    DSW1 : in std_logic_vector(7 downto 0)
  );
end FPGA_GAPLUS;

architecture rtl of FPGA_GAPLUS is

  ----------------------------------------
  --  Input port connection
  ----------------------------------------
  signal joystick_1 : std_logic_vector(3 downto 0); -- {L,D,R,U}
  signal joystick_2 : std_logic_vector(3 downto 0);
  signal buttons : std_logic_vector(3 downto 0);
  signal serv_coins : std_logic_vector(3 downto 0); -- {Service, none, Coin2, Coin1}

  signal intf_word_0 : std_logic_vector(31 downto 0);
  signal intf_word_1 : std_logic_vector(31 downto 0);
  signal intf_nibble_2 : std_logic_vector(3 downto 0);

  ----------------------------------------
  --  Clock Generator
  ----------------------------------------
  signal CLKS : unsigned(4 downto 0) := (others => '0');

  signal CLK25M : std_logic;
  signal CLK12M5 : std_logic;
  signal CLK6M25 : std_logic;
  signal CLK3M125 : std_logic;

  signal SCPU_CLK : std_logic;
  signal pclk_i : std_logic;

  ----------------------------------------
  --  Share Memory Module
  ----------------------------------------
  signal mcpu_ma : std_logic_vector(15 downto 0);
  signal mcpu_mr : std_logic_vector(7 downto 0);
  signal mcpu_do : std_logic_vector(7 downto 0);
  signal mcpu_we : std_logic;

  signal scpu_ma : std_logic_vector(15 downto 0);
  signal scpu_mr : std_logic_vector(7 downto 0);
  signal scpu_do : std_logic_vector(7 downto 0);
  signal scpu_we : std_logic;

  signal vram_a : std_logic_vector(10 downto 0);
  signal vram_d : std_logic_vector(15 downto 0);

  signal spra_a : std_logic_vector(6 downto 0);
  signal spra_d : std_logic_vector(23 downto 0);

  ----------------------------------------
  --  Video Module
  ----------------------------------------
  signal mcpu_star_cs : std_logic;
  signal oVB : std_logic;
  signal PH : std_logic_vector(8 downto 0);
  signal PV : std_logic_vector(8 downto 0);
  signal pout_i : std_logic_vector(11 downto 0);
  signal pout_o : std_logic_vector(11 downto 0);

  ----------------------------------------
  --  MAIN CPUserv_coins
  ----------------------------------------
  signal SUB_RESET : std_logic;
  signal snd_rd : std_logic_vector(7 downto 0);
  signal snd_we : std_logic;

  ----------------------------------------
  --  Sound Module
  ----------------------------------------
  signal snd_enable : std_logic;
  signal snd_adrs : std_logic_vector(10 downto 0);

begin

  ----------------------------------------
  --  Input port connection
  ----------------------------------------
  joystick_1 <= LEFT_1 & DOWN_1 & RIGHT_1 & UP_1;
  joystick_2 <= LEFT_2 & DOWN_2 & RIGHT_2 & UP_2;
  buttons <= START_2 & START_1 & FIRE_2 & FIRE_1;
  serv_coins <= SERVICE_SW & '0' & '0' & COIN; -- {Service, none, Coin2, Coin1}

  intf_word_0 <= x"0000" & buttons & joystick_2 & joystick_1 & serv_coins;
  intf_word_1 <= (DSW0(3 downto 0) & DSW1(7 downto 4) & DSW1(3 downto 0) & DSW0(7 downto 4)) &
           (DSW0(3 downto 0) & DSW1(7 downto 4) & DSW1(3 downto 0) & DSW0(7 downto 4));
  intf_nibble_2 <= SERVICE_SW & "111"; -- {Serv.Mode(Gal3), Cabinet, 2'b11}

  ----------------------------------------
  --  Clock Generator
  ----------------------------------------
  process (SYSCLK50)
  begin
    if rising_edge(SYSCLK50) then
      CLKS <= CLKS + 1;
    end if;
  end process;

  CLK25M <= CLKS(0);
  CLK12M5 <= CLKS(1);
  CLK6M25 <= CLKS(2);
  CLK3M125 <= CLKS(3);

  SCPU_CLK <= (not CLKS(3));

  pclk_i <= CLK6M25;
  PCLK <= pclk_i;

  hvgen : entity work.HVGEN
    port map(
      HPOS => PH,
      VPOS => PV,
      PCLK => pclk_i,
      iRGB => pout_i,
      oRGB => pout_o,
      HBLK => open,
      VBLK => open,
      HSYN => HSYNC,
      VSYN => VSYNC
    );

  BLUE <= pout_o(11 downto 8);
  GREEN <= pout_o(7 downto 4);
  RED <= pout_o(3 downto 0);

  ----------------------------------------
  --  Share Memory Module
  ----------------------------------------
  smem : entity work.GAPLUS_SHAREMEM
    port map(
      clk => CLK6M25, -- CPUCLKx4
      vclk => SYSCLK50,
      sel => CLK3M125, -- MCPU_CLK
      ad0 => mcpu_ma, rd0 => mcpu_mr, wd0 => mcpu_do, we0 => mcpu_we,
      ad1 => scpu_ma, rd1 => scpu_mr, wd1 => scpu_do, we1 => scpu_we,
      vram_a => vram_a(9 downto 0), vram_d => vram_d,
      spra_a => spra_a, spra_d => spra_d
    );

  ----------------------------------------
  --  Video Module
  ----------------------------------------
  video : entity work.GAPLUS_VIDEO
    port map(
      CLK50M => SYSCLK50,
      VCLKx4 => CLK25M,
      VCLKx2 => CLK12M5,
      VCLK => CLK6M25,
      RESET => RESET,

      PH => PH, PV => PV,
      POUT => pout_i, VB => oVB,

      VRAM_A => vram_a, VRAM_D => vram_d,
      SPRA_A => spra_a, SPRA_D => spra_d,

      STAR_AD => mcpu_ma(1 downto 0),
      STAR_DT => mcpu_do,
      STAR_WE => mcpu_star_cs
    );

  ----------------------------------------
  --  MAIN CPU
  ----------------------------------------
  main : entity work.GAPLUS_MAIN
    port map(
      MCPU_CLK => CLK3M125,
      RESET => RESET,
      VBLK => oVB,
      INP0 => intf_word_0,
      INP1 => intf_word_1,
      INP2 => intf_nibble_2,
      mcpu_ma => mcpu_ma, mcpu_we => mcpu_we, mcpu_do => mcpu_do, mcpu_mr => mcpu_mr,
      snd_we => snd_we, snd_rd => snd_rd,
      mcpu_star_cs => mcpu_star_cs,
      SUB_RESET => SUB_RESET,
      coin_lamp => COIN_LAMP, start_1_lamp => START_1_LAMP, start_2_lamp => START_2_LAMP,
      kick_explode => PCM_KICK
    );

  ----------------------------------------
  --  Sub CPU
  ----------------------------------------
  sub : entity work.GAPLUS_SUB
    port map(
      SCPU_CLK => SCPU_CLK,
      RESET => SUB_RESET,
      VBLK => oVB,
      scpu_mr => scpu_mr,
      scpu_ma => scpu_ma, scpu_we => scpu_we, scpu_do => scpu_do
    );

  ----------------------------------------
  --  Sound Module
  ----------------------------------------
  snd_enable <= not SUB_RESET;
  snd_adrs <= '0' & mcpu_ma(9 downto 0);

  sound_engine : entity work.GAPLUS_SOUND
    port map(
      RESET => SUB_RESET,
      CPUCLK => CLK3M125,
      CLK24M => CLK25M,
      PCM_CLK => PCM_CLK,
      VB => oVB,
      com_clk => SYSCLK50,
      com_adrs => snd_adrs, com_wd => mcpu_do, com_rd => snd_rd, com_we => snd_we,
      SND => SOUND,
      SND_ENABLE => snd_enable
    );

end rtl;