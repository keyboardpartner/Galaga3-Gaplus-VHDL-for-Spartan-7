-- #############################################################################
--
--       __ ________  _____  ____  ___   ___  ___
--      / --_/ __/\ \/ / _ )/ __ \/ _ | / _ \/ _ \
--     / ,< / _/   \  / _  / /_/ / __ |/ , _/ -- /
--    /_/|_/___/_  /_/____/\____/_/_|_/_/|_/____/
--      / _ \/ _ | / _ \/_  __/ |/ / __/ _ \
--     / ___/ __ |/ , _/ / / /    / _-- , _/
--    /_/  /_/ |_/_/|_| /_/ /_/|_/___/_/|_|
--
-- #############################################################################
--
-- Company:  KeyboardPartner UG
-- Engineer: Carsten Meyer, cm@keyboardpartner.de
-- 
-- Create Date: 15.09.2026
-- Design Name: Slow LEDs with PWM and fade effect
-- Module Name: lamp_driver
-- Project Name: Nexys4 Gaplus
-- Target Devices: all
-- Tool Versions: Vivado 2025.2
-- Description: Slow LEDs with PWM and fade effect.
--
-- LED PWM with slow rise/fall times to simulate incandescent bulbs
-- 64 levels of PWM resolution
-- Even small indicator lamps have a noticeable slow fade effect,
-- taking around 40 to 50 ms to be fully lit up or fully off.
-- Set the update_rate to control the speed of the LED fade effect.
-- smaller = faster rise/fall times, 125 gives a 40 ms transition @ 50 MHz clock

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity lamp_driver is
  generic (
    data_width : integer := 3;
    update_rate : integer := 80 -- smaller = faster rise/fall times, 80 gives a 50 ms transition @ 50 MHz clock
  );
  port (
    SYSCLK : in std_logic; -- nom. 50 MHz
    LED_1_IN : in std_logic;
    LED_2_IN : in std_logic;
    LED_COIN_IN : in std_logic;
    LED_BLINK_OUT : out std_logic;
    LED_1_OUT : out std_logic;
    LED_2_OUT : out std_logic;
    LED_COIN_OUT : out std_logic
  );
end entity lamp_driver;

architecture rtl of lamp_driver is
  signal prescaler : std_logic_vector(8 downto 0) := (others => '0'); -- 97.8 kHz
  signal prescale_tick : std_logic;
  signal blink_count : std_logic_vector(14 downto 0) := (others => '0'); -- 97.8 kHz / 32767
  signal blink_toggle : std_logic;
  signal update_counter : integer range 0 to update_rate; -- inc/dec LED intensity
  signal pwm_counter : std_logic_vector(5 downto 0); -- PWM counter

  type t_pwm_val is array (data_width - 1 downto 0) of std_logic_vector(5 downto 0);
  signal pwm_vals : t_pwm_val := (others => (others => '0')); -- array of PWM values
  signal led_in_i : std_logic_vector(data_width - 1 downto 0);
  signal led_out_i : std_logic_vector(data_width - 1 downto 0);

begin
  led_in_i <= LED_1_IN & LED_2_IN & (LED_COIN_IN and blink_toggle); 

  -- for efficiency, the prescaler is implemented as an LFSR
  -- mod-511-counter by LFSR
  -- taps for the LFSR from Xilinx application note https://docs.amd.com/v/u/en-US/xapp052
  prescale : process (SYSCLK)
    variable prescaler_fb : std_logic;
  begin
    if rising_edge(SYSCLK) then
      prescaler_fb := prescaler(8) xnor prescaler(4);
      prescaler <= prescaler(7 downto 0) & prescaler_fb;
      prescale_tick <= '0';
      if prescaler = 0 then
        prescale_tick <= '1'; -- SYSCLK div 511
      end if;
    end if;
  end process;

  -- mod-32767-counter by LFSR
  blink : process (SYSCLK, prescale_tick)
    variable blink_count_fb : std_logic;
  begin
    if rising_edge(SYSCLK) and (prescale_tick = '1') then
      blink_count_fb := blink_count(14) xnor blink_count(13);
      blink_count <= blink_count(13 downto 0) & blink_count_fb;
      if blink_count = 0 then
        blink_toggle <= not blink_toggle; -- prescale_tick div 32767
      end if;
    end if;
  end process;
  
  LED_BLINK_OUT <= blink_toggle;

  process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      if (prescale_tick = '1') then
        pwm_counter <= pwm_counter + 1;
        update_counter <= update_counter + 1;
        -- update LEDs according to current PWM value
        -- loop through all LEDs (for multiple LEDs)
        for i in 0 to data_width - 1 loop
          -- update each LED according to its PWM value
          if pwm_vals(i) = 63 then
            led_out_i(i) <= '1';
          elsif pwm_vals(i) = 0 then
            led_out_i(i) <= '0';
          elsif pwm_counter < pwm_vals(i) then
            led_out_i(i) <= '1';
          else
            led_out_i(i) <= '0';
          end if;
        end loop;

        -- update PWM values
        if update_counter = update_rate then
          update_counter <= 0;
          -- loop through all PWM values (for multiple LEDs)
          for i in 0 to data_width - 1 loop
            if led_in_i(i) = '1' then
              if pwm_vals(i) /= 63 then
                pwm_vals(i) <= pwm_vals(i) + 1;
              end if;
            else
              if pwm_vals(i) /= 0 then
                pwm_vals(i) <= pwm_vals(i) - 1;
              end if;
            end if;
          end loop;
        end if;

      end if;
    end if;
  end process;

  LED_1_OUT <= led_out_i(2);
  LED_2_OUT <= led_out_i(1);
  LED_COIN_OUT <= led_out_i(0);

end architecture rtl;