--------------------------------------------------------------------------------
-- SPI Interface for c't-Lab FPGA und c't-Lab UNIC
-- AVR SPI-Mode CPOL/CPHA 1.1 (SCK normally high)
-- by C. Meyer cm@ctmagazin.de
-- Creative Commons by-nc-sa, use by your own risk
-- Letzte �nderungen:
-- 02.07.2011 rs_tick und ds_tick besser mit SYSCLK synchronisiert
-- 11.01.2012 DNA_PORT auslesen auf SPI 240 und 241 ($F0, $F1)
-- 27.11.2021 Spartan S7
-- 14.02.2023 einfachere Seriennummer-Extraktion je 24 Bit aus DNA_PORT
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SPI_inout_small is
  port (
    SYSCLK : in std_logic;
    SCK : in std_logic;
    MOSI : in std_logic;
    DS_N : in std_logic;
    RS_N : in std_logic;

    MISO : inout std_logic;

    RSEL : out std_logic_vector(7 downto 0); -- an weitere Ausgangsregister, Adresse
    STROBE : out std_logic; -- Schreibimpuls für Ausgangsregister

    -- Game Buttons
    COIN : out std_logic;
    START_1 : out std_logic;
    START_2 : out std_logic;
    FIRE : out std_logic;
    BOMB : out std_logic; -- for Xevious and Defender
    SHIELD : out std_logic; -- e.g. Hyperspace for Defender
    UP : out std_logic;
    DOWN : out std_logic;
    LEFT : out std_logic;
    RIGHT : out std_logic;

    LAMP_C : in std_logic;
    LAMP_1 : in std_logic;
    LAMP_2 : in std_logic;

    VERSION : in std_logic_vector(31 downto 0);
    DATA_18 : out std_logic_vector(17 downto 0);

    PORT_1 : out std_logic_vector(15 downto 0);

    DISABLE_FLASH : out std_logic; -- Disable connection to SPI Flash

    RST_LC0 : out std_logic; -- RESET für 16 Cores, Core 0 = Bit (0) etc.
    INC_LC0 : out std_logic; -- INCR für 16 Cores
    RST_LC1 : out std_logic; -- RESET für 16 Cores, Core 1 = Bit (1) etc.
    INC_LC1 : out std_logic -- INCR für 16 Cores
  );

end SPI_inout_small;

architecture behave of SPI_inout_small is
  signal q_int, q_sro, q_sro_tmp, q_sri : std_logic_vector(31 downto 0);
  signal r_int, r_sri : std_logic_vector(15 downto 0);
  signal rs_tick, rs_tmp, ds_tick, ds_tmp, ds_del, rs_del : std_logic;
  signal lc_sel_int : std_logic_vector(3 downto 0) := (others => '0');

  signal rs_n_d1, ds_n_d1, miso_ena : std_logic;
  signal disable_flash_int : std_logic := '0';

  signal port_0_i : std_logic_vector(15 downto 0);

begin

  DISABLE_FLASH <= disable_flash_int or (not (DS_N and RS_N)); -- connect internal signal to output port

  sel_sync : process (SYSCLK)
    -- Schieberegister für Eingangsdaten
  begin
    if rising_edge(SYSCLK) then
      rs_n_d1 <= RS_N;
      ds_n_d1 <= DS_N;
    end if;
  end process;

  spi_dshiftin : process (SCK)
    -- Schieberegister für Eingangsdaten
  begin
    if rising_edge(SCK) then
      if (ds_n_d1 = '0') then
        q_sri <= (q_sri(30 downto 0) & MOSI);
      end if;
    end if;
  end process;

  spi_rshift : process (SCK)
    -- Schieberegister für Select-Adresse
  begin
    if rising_edge(SCK) then
      if (rs_n_d1 = '0') then
        r_sri <= (r_sri(14 downto 0) & MOSI);
      end if;
    end if;
  end process;

  spi_rs : process (rs_n_d1)
    -- Eingangsregister Adresse buffered
  begin
    if rising_edge(rs_n_d1) then
      r_int <= r_sri;
    end if;
  end process;

  spi_ds : process (ds_n_d1)
    -- Eingangsregister Daten buffered
  begin
    if rising_edge(ds_n_d1) then
      q_int <= q_sri;
    end if;
  end process;

  spi_dshiftout : process (SCK, ds_n_d1, q_sro)
    -- Schieberegister für Ausgangsdaten
  begin
    if ds_n_d1 = '1' then -- Latch für Ausgangsdaten an MISO
      q_sro_tmp <= q_sro;
    elsif rising_edge(SCK) then
      q_sro_tmp <= (q_sro_tmp(30 downto 0) & '0'); -- MSB first
    end if;
  end process;

  OBUFT_inst : OBUFT
  generic map(
    DRIVE => 8,
    IOSTANDARD => "DEFAULT",
    SLEW => "SLOW")
  port map(
    O => MISO, -- Buffer output (connect directly to top-level port)
    I => q_sro_tmp(31), -- Buffer input
    T => DS_N -- 3-state enable input, Z when '1'
  );

  STROBE <= ds_tick;
  --DATA <= q_int(7 downto 0);
  DATA_18 <= q_int(17 downto 0);
  RSEL <= r_int(7 downto 0);

  spi_regs : process (SYSCLK)
    -- SPI-Registerwerte zwischenspeichern
  begin
    if rising_edge(SYSCLK) then
      INC_LC0 <= '0';
      RST_LC0 <= '0';
      INC_LC1 <= '0';
      RST_LC1 <= '0';
      if (ds_tick = '1') and (r_int(15) = '1') then -- Schreibfreigabe, neue Version
        case r_int(7 downto 0) is
          when x"00" =>
            port_0_i <= q_sri(15 downto 0);
          when x"01" =>
            PORT_1 <= q_sri(15 downto 0);

          when x"80" =>
            if lc_sel_int = "0000" then
              INC_LC0 <= '1'; -- bis zu 16 Cores
            end if;
            if lc_sel_int = "0001" then
              INC_LC1 <= '1'; -- bis zu 16 Cores
            end if;

          when x"81" =>
            lc_sel_int <= q_int(3 downto 0);
            if q_int(3 downto 0) = "0000" then
              RST_LC0 <= '1'; -- bis zu 16 Cores
            end if;
            if q_int(3 downto 0) = "0001" then
              RST_LC1 <= '1'; -- bis zu 16 Cores
            end if;
          when x"82" =>
            disable_flash_int <= '1'; -- disable SPI flash when resetting LC0
          when x"83" =>
            disable_flash_int <= '0'; -- re-enable SPI flash
          when others =>
        end case;
      end if;
    end if;
  end process;

  COIN <= port_0_i(0);
  START_1 <= port_0_i(1);
  START_2 <= port_0_i(2);
  UP <= port_0_i(3);
  DOWN <= port_0_i(4);
  LEFT <= port_0_i(5);
  RIGHT <= port_0_i(6);
  FIRE <= port_0_i(7);
  BOMB <= port_0_i(8);
  SHIELD <= port_0_i(9);

  spi_sync : process (SYSCLK)
    -- Synchrone Ticks erzeugen bei SlaveSelect-Ende (steigende Flanke)
  begin
    if rising_edge(SYSCLK) then
      ds_del <= ds_tmp;
      ds_tmp <= DS_N;
      ds_tick <= (not ds_del) and ds_tmp;
      rs_del <= rs_tmp;
      rs_tmp <= RS_N;
      rs_tick <= (not rs_del) and rs_tmp;

      if rs_tick = '1' then -- Register-Select geschrieben?
        -- Eingangsmultiplexer, aktualisiert mit Schreiben von RS_N
        if (r_int(15) = '0') then -- Schreib-Bit nicht gesetzt, Register 0 bis 255
          case r_int(7 downto 0) is -- aktuelle Registeradresse
            when x"00" =>
              q_sro <= x"000000" & "00000" & LAMP_1 & LAMP_2 & LAMP_C; -- Lamp info in LSB, must be 32-bit-read
            when x"03" => -- FPGA-Version
              q_sro <= VERSION;
            when others =>
          end case;
        end if;
      end if;
    end if;
  end process;

end behave;