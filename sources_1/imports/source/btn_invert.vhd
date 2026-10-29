----------------------------------------------------------------------------------
-- Company: KeyboardPartner UG
-- Engineer: Carsten Meyer
-- 
-- Create Date: 01.10.2026 09:40:51
-- Design Name: 
-- Module Name: btn_invert - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Inverts game button inputs when the INVERT signal is high
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Added INVERT functionality to all button inputs
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity btn_invert is
    Port ( COIN : in STD_LOGIC;
           COIN_INV : out STD_LOGIC;
           START_1 : in STD_LOGIC;
           START_1_INV : out STD_LOGIC;
           START_2 : in STD_LOGIC;
           START_2_INV : out STD_LOGIC;
           FIRE : in STD_LOGIC;
           FIRE_INV : out STD_LOGIC;
           UP : in STD_LOGIC;
           UP_INV : out STD_LOGIC;
           DOWN : in STD_LOGIC;
           DOWN_INV : out STD_LOGIC;
           LEFT : in STD_LOGIC;
           LEFT_INV : out STD_LOGIC;
           RIGHT : in STD_LOGIC;
           RIGHT_INV : out STD_LOGIC;
           INVERT: in STD_LOGIC
           );
end btn_invert;

architecture Behavioral of btn_invert is

begin

  COIN_INV <= COIN xor INVERT;
  START_1_INV <= START_1 xor INVERT;
  START_2_INV <= START_2 xor INVERT;
  FIRE_INV <= FIRE xor INVERT;
  UP_INV <= UP xor INVERT;
  DOWN_INV <= DOWN xor INVERT;
  LEFT_INV <= LEFT xor INVERT;
  RIGHT_INV <= RIGHT xor INVERT;

end Behavioral;
