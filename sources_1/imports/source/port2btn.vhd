----------------------------------------------------------------------------------
-- Company: KeyboardPartner UG
-- Engineer: Carsten Meyer
-- 
-- Create Date: 01.10.2026 09:40:51
-- Design Name: 
-- Module Name: port2btn - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: converts HX3 SPI port to game button inputs
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Removed INVERT functionality from all button inputs
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity port2btn is
  port (
    PORT_0 : in std_logic_vector(15 downto 0);
    COIN : out std_logic;
    START_1 : out std_logic;
    START_2 : out std_logic;
    FIRE : out std_logic;
    UP : out std_logic;
    DOWN : out std_logic;
    LEFT : out std_logic;
    RIGHT : out std_logic
  );
end port2btn;

architecture Behavioral of port2btn is

begin
  COIN <= PORT_0(0);
  START_1 <= PORT_0(1);
  START_2 <= PORT_0(2);
  FIRE <= PORT_0(3);
  UP <= PORT_0(4);
  DOWN <= PORT_0(5);
  LEFT <= PORT_0(6);
  RIGHT <= PORT_0(7);

end Behavioral;