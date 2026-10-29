-- #############################################################################
--
--      __ ________  _____  ____  ___   ___  ___
--     / //_/ __/\ \/ / _ )/ __ \/ _ | / _ \/ _ \
--    / ,< / _/   \  / _  / /_/ / __ |/ , _/ -- /
--   /_/|_/___/_  /_/____/\____/_/_|_/_/|_/____/
--     / _ \/ _ | / _ \/_  __/ |/ / __/ _ \
--    / ___/ __ |/ , _/ / / /    / _-- , _/
--   /_/  /_/ |_/_/|_| /_/ /_/|_/___/_/|_|
--
-- #############################################################################
--
-- Company:
-- Engineer: Carsten Meyer
--
-- Create Date:  17:17:17 09/27/2026
-- Module Name:  rom_loader_55ns - Behavioral
-- Project Name: Breakout Sprite Engine

-- TV Video Resynchronizer andf Border Generator
-- TV Input pixel Clock in 5..6 MHz range
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
--use ieee.numeric_std.all;

library UNISIM;
use UNISIM.Vcomponents.all;

entity border_gen is
  port (
    RED_IN : in std_logic_vector(3 downto 0);
    GREEN_IN : in std_logic_vector(3 downto 0);
    BLUE_IN : in std_logic_vector(3 downto 0);
    HSYNC : in std_logic;
    VSYNC : in std_logic;
    BORDER : in std_logic;
    TESTGRID : in std_logic;
    --
    RED_OUT : out std_logic_vector(3 downto 0);
    GREEN_OUT : out std_logic_vector(3 downto 0);
    BLUE_OUT : out std_logic_vector(3 downto 0);
    --
    HSYNC_OUT : out std_logic;
    VSYNC_OUT : out std_logic;
    --
    PIXEL_CLK : in std_logic
  );
end border_gen;

architecture behave of border_gen is

  constant hsync_pulsewidth : integer := 28; -- 28 * 0.1666µs (6 MHz) = 4.6µs
  constant vsync_pulsewidth : integer := 2; -- 2 Lines

   -- Galaga 3 values, 384 Pixel H, 256 Pixel V total, 256 x 240 visible
  constant hsync_start_new : integer := 4; -- higher values shift picture to the left
  constant hsync_end_new : integer := (hsync_start_new + hsync_pulsewidth) mod 384;

  constant vsync_start_new : integer := 6; -- higher values shift picture up
  constant vsync_end_new : integer := (vsync_start_new + vsync_pulsewidth) mod 256;

  -- border values for the visible area; optional displayed as rectangle for VGA auto adjustment
  -- actual visible area is 4px smaller on Galaga game
  constant border_left : integer := 70; -- example value, adjust as needed
  constant border_right : integer := 361; -- example value, adjust as needed
  constant border_top : integer := 26; -- example value, adjust as needed
  constant border_bottom : integer := 251; -- example value, adjust as needed
  constant border_width : integer := 2; -- example value, adjust as needed
  -- outer border values based on the inner border and border width
  constant border_outer_left : integer := border_left - border_width; -- example value, adjust as needed
  constant border_outer_right : integer := border_right + border_width; -- example value, adjust as needed
  constant border_outer_top : integer := border_top - border_width; -- example value, adjust as needed
  constant border_outer_bottom : integer := border_bottom + border_width; -- example value, adjust as needed
  
  -- a border is displayed for a certain amount of time to help with VGA auto adjustment
  constant border_timeout : integer range 0 to 255 := 12; -- border timeout in seconds (min. 18 for Pollin LS-7 display)
  constant border_color : std_logic_vector(11 downto 0) := x"666"; -- rectangle color 12 Bit BLUE, GREEN, RED

  constant invert_sync : std_logic := '0'; -- set to true to invert sync signals (must be positive)

  ----------------------------------------------------------- 
  --      #####  ###  #####  #     #    #    #        #####  
  --     #     #  #  #     # ##    #   # #   #       #     # 
  --     #        #  #       # #   #  #   #  #       #       
  --      #####   #  #  #### #  #  # #     # #        #####  
  --           #  #  #     # #   # # ####### #             # 
  --     #     #  #  #     # #    ## #     # #       #     # 
  --      #####  ###  #####  #     # #     # #######  #####                                                          
  ----------------------------------------------------------- 

  --
  --  
  signal hsync_in_d1, vsync_in_d1 : std_logic;
  signal hsync_in, vsync_in : std_logic;
  signal hpos_o : std_logic_vector(8 downto 0) := (others => '0');
  signal vpos_o : std_logic_vector(8 downto 0) := (others => '0');

  signal frame_count : integer range 0 to 255 := 0;
  signal border_timeout_count : integer range 0 to 255 := 0;
  signal border_elapsed : std_logic := '0';

  signal hor_outer_valid, vert_outer_valid : std_logic := '0';
  signal hor_inner_valid, vert_inner_valid : std_logic := '0';

begin

  hsync_in <= HSYNC xor invert_sync; -- hsync_in, vsync_in must be negative pulses
  vsync_in <= VSYNC xor invert_sync;

  --------------------------------------------------------------------------
  --     ### #     # ######  #     # ####### 
  --      #  ##    # #     # #     #    #    
  --      #  # #   # #     # #     #    #    
  --      #  #  #  # ######  #     #    #    
  --      #  #   # # #       #     #    #    
  --      #  #    ## #       #     #    #    
  --     ### #     # #        #####     #    
  --------------------------------------------------------------------------

  p_timing : process
  begin
    wait until rising_edge (PIXEL_CLK);
    hsync_in_d1 <= hsync_in;
    vsync_in_d1 <= vsync_in;

    if (hsync_in = '0') and (hsync_in_d1 = '1') then
      hpos_o <= (others => '0');
      vpos_o <= vpos_o + 1;
    else
      hpos_o <= hpos_o + 1;
    end if;

    if (vsync_in = '0') and (vsync_in_d1 = '1') then
      vpos_o <= (others => '0');
      if frame_count >= 60 then -- 60 Hz vertical
        frame_count <= 0;
        if border_timeout_count >= border_timeout then
          border_elapsed <= '1';
        else
          border_timeout_count <= border_timeout_count + 1;
        end if;
      else
        frame_count <= frame_count + 1;
      end if;
    end if;

    -- re-synchronize HSYNC and VSYNC outputs
    -- based on the new timing constants to center frame
    if (hpos_o = hsync_start_new) then
      HSYNC_OUT <= '0'; -- negative polarity
    elsif (hpos_o = hsync_end_new) then
      HSYNC_OUT <= '1';
    end if;

    if (vpos_o = vsync_start_new) then
      VSYNC_OUT <= '0'; -- negative polarity
    elsif (vpos_o = vsync_end_new) then
      VSYNC_OUT <= '1';
    end if;
    --  VSYNC_OUT <= vsync_in;
  end process;


  -- border process for TV signals
  p_border : process
    variable border_valid, outer_rect_valid, inner_rect_valid : std_logic;
  begin
    wait until rising_edge (PIXEL_CLK);
    
    if (hpos_o = border_outer_left) then    
      hor_outer_valid <= '1';
    end if;  
    if (hpos_o = border_outer_right) then    
      hor_outer_valid <= '0';
    end if;  
    if (vpos_o = border_outer_top) then    
      vert_outer_valid <= '1';
    end if;  
    if (vpos_o = border_outer_bottom) then    
      vert_outer_valid <= '0';
    end if;  
    
    
    if (hpos_o = border_left) then    
      hor_inner_valid <= '1';
    end if;  
    if (hpos_o = border_right) then    
      hor_inner_valid <= '0';
    end if;  
    if (vpos_o = border_top) then    
      vert_inner_valid <= '1';
    end if;  
    if (vpos_o = border_bottom) then    
      vert_inner_valid <= '0';
    end if;  
    
    outer_rect_valid := vert_outer_valid and hor_outer_valid;
    inner_rect_valid := vert_inner_valid and hor_inner_valid;
    border_valid := outer_rect_valid and (not inner_rect_valid);

    if (border_valid = '1') and ((BORDER = '1') or (border_elapsed = '0')) then
      -- video is valid, proceed with normal processing
      BLUE_OUT <= border_color(11 downto 8);
      GREEN_OUT <= border_color(7 downto 4);
      RED_OUT <= border_color(3 downto 0);
    else
      -- normal video output
      BLUE_OUT <= BLUE_IN;
      GREEN_OUT <= GREEN_IN;
      RED_OUT <= RED_IN;
    end if;

    if (TESTGRID = '1') and (border_inner_rect = '1') then
      if (vpos_o(3 downto 0) = "0000") or (hpos_o(3 downto 0) = "0000") then
        BLUE_OUT <= "1100"; -- light grey
        GREEN_OUT <= "1100";
        RED_OUT <= "1100";
      end if;
    end if;

  end process;

end architecture behave;