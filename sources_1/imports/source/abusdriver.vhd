--------------------------------------------------------------------------------
-- Bus driver and data selector helpers
-- VHDL translation of abusdriver.v
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity busdriver is
  port (
    iENABLE : in  std_logic;
    iSELECT : in  std_logic;
    iBUS0   : in  std_logic_vector(31 downto 0);
    iBUS1   : in  std_logic_vector(31 downto 0);
    oBUS    : out std_logic_vector(31 downto 0)
  );
end busdriver;

architecture rtl of busdriver is
begin
  oBUS <= (others => '0') when iENABLE = '0' else
          iBUS0           when iSELECT = '1' else
          iBUS1;
end rtl;


library ieee;
use ieee.std_logic_1164.all;

entity dataselector2 is
  port (
    oDATA  : out std_logic_vector(7 downto 0);
    iSEL0  : in  std_logic;
    iDATA0 : in  std_logic_vector(7 downto 0);
    iSEL1  : in  std_logic;
    iDATA1 : in  std_logic_vector(7 downto 0);
    dData  : in  std_logic_vector(7 downto 0)
  );
end dataselector2;

architecture rtl of dataselector2 is
begin
  oDATA <= iDATA0 when iSEL0 = '1' else
           iDATA1 when iSEL1 = '1' else
           dData;
end rtl;


library ieee;
use ieee.std_logic_1164.all;

entity dataselector4 is
  port (
    oDATA  : out std_logic_vector(7 downto 0);
    iSEL0  : in  std_logic;
    iDATA0 : in  std_logic_vector(7 downto 0);
    iSEL1  : in  std_logic;
    iDATA1 : in  std_logic_vector(7 downto 0);
    iSEL2  : in  std_logic;
    iDATA2 : in  std_logic_vector(7 downto 0);
    iSEL3  : in  std_logic;
    iDATA3 : in  std_logic_vector(7 downto 0);
    dData  : in  std_logic_vector(7 downto 0)
  );
end dataselector4;

architecture rtl of dataselector4 is
begin
  oDATA <= iDATA0 when iSEL0 = '1' else
           iDATA1 when iSEL1 = '1' else
           iDATA2 when iSEL2 = '1' else
           iDATA3 when iSEL3 = '1' else
           dData;
end rtl;
