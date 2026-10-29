--------------------------------------------------------------------------------
-- Biquad-Filter, einfach, ohne Multiplizierer
-- Frequenzeinstellung durch Anzahl der Oversampling-Ticks
-- Idee und Implementierung (c) C. Meyer 3/2014
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;

entity biquad_mult_kq is
  port (
    SYSCLK : in std_logic;
    SYNC : in std_logic; -- Sampling-Tick 48 kHz
    INP : in std_logic_vector (11 downto 0); -- Audiodaten
    KF : in std_logic_vector (7 downto 0); -- Frequenzeinstellung
    -- KQ bestimmt Peaking jedes einzelnen Filters, 
    -- 0 = kein Peak, 1 = leicht bis 4 = sehr stark (Vorsicht, �bersteuerung!)
    KQ : in std_logic_vector (1 downto 0); -- Peak 0..3
    HP : out std_logic_vector (11 downto 0); -- Hochpass Ausgang
    LP : out std_logic_vector (11 downto 0); -- Tiefpass Ausgang
    BP : out std_logic_vector (11 downto 0) -- Bandpass Ausgang
  );
end entity biquad_mult_kq;

architecture behave of biquad_mult_kq is

  signal inp_arr, lp_input_arr, lp_added_arr, bp_input_arr, pb_kq_arr,
  lp_arr, bp_arr, hp_arr : std_logic_vector (23 downto 0) := (others => '0');

  signal kf_signed : std_logic_vector (8 downto 0) := (others => '0');
begin

  out_regs : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      kf_signed <= '0' & KF; -- immer positiv
      if SYNC = '1' then
        inp_arr <= INP(11) & INP & "00000000000"; -- Eingangswerte skaliert mit 1 Bit Headroom
        LP <= lp_added_arr(23 downto 12);
        HP <= hp_arr(23 downto 12);
        BP <= bp_arr(23 downto 12);
      end if;
    end if;
  end process;

  -- KQ-Faktor:
  -- Q = 2     mit KQ = 0 (shift left 1), neutrales Filter ohne Peak
  -- Q = 1     mit KQ = 1 (kein Shift), Filter mit leichtem Peak
  -- Q = 0.5   mit KQ = 2
  -- Q = 0.25  mit KQ = 3 ausgepraegter Peak (Vorsicht vor Uebersteuerung!)
  -- Q = 0.125 mit KQ = 4 sehr starker Peak (Vorsicht vor Uebersteuerung!)
  pb_kq_arr <= to_stdlogicvector((to_bitvector(bp_arr) sla 1) sra conv_integer(unsigned(KQ)));

  hp_arr <= inp_arr - lp_added_arr - pb_kq_arr;
  -- Multiplikations-Ergebnis 28 Bits
  bp_input_arr <= hp_arr(23 downto 9) * kf_signed; -- kf-Multiplier 1, 1/256 = 32 Hz
  lp_input_arr <= bp_arr(23 downto 9) * kf_signed; -- kf-Multiplier 2, 1/256 = 32 Hz
  lp_added_arr <= lp_arr + lp_input_arr;

  delay_register : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      -- zwei 24-Bit-Integratoren updaten
      if SYNC = '1' then
        bp_arr <= bp_arr + bp_input_arr;
        lp_arr <= lp_added_arr;
      end if;
    end if;
  end process;

end behave;