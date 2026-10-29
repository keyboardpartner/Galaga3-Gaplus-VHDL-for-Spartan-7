----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.10.2026 09:40:51
-- Design Name: 
-- Module Name: invert - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity invert is
  port (
    INP : in std_logic;
    OUT_INV : out std_logic
  );
end invert;

architecture Behavioral of invert is

begin

  OUT_INV <= not INP;

end Behavioral;