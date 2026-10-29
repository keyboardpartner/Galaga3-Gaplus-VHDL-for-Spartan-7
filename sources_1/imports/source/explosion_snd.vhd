library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity explosion_snd is
  port (
    SYSCLK : in std_logic; -- nom. 50 MHz
    SAMPLE_CLK : in std_logic; -- can be a tick or a continuous clock
    TRIGGER : in std_logic;
    AUDIO : out std_logic_vector(11 downto 0) -- unsigned audio 12 Bit, mid = x"800"
  );
end entity explosion_snd;

architecture rtl of explosion_snd is
  component biquad_mult_kq
    port (
      SYSCLK : in std_logic;
      SYNC : in std_logic;
      INP : in std_logic_vector(11 downto 0);
      KF : in std_logic_vector(7 downto 0);
      KQ : in std_logic_vector(1 downto 0);
      HP : out std_logic_vector(11 downto 0);
      LP : out std_logic_vector(11 downto 0);
      BP : out std_logic_vector(11 downto 0)
    );
  end component;

  component level_decay
    port (
      SYSCLK : in std_logic;
      INTEGR_TICK : in std_logic;
      START_VAL : in std_logic_vector(7 downto 0); -- initial value for the decay
      TRIGGER : in std_logic;
      DIFF_OUT : out std_logic_vector(7 downto 0)
    );
  end component;

	COMPONENT lowpass_6
  GENERIC (
    FREQU : integer range 0 to 7 -- 1=5500, 2=2250, 3=1050, 4=510, 5=255, 6=125, 7=62 Hz @ 48KHz sampling clk
  );
	PORT(
		SYSCLK : IN std_logic;
		SYNC : IN std_logic;
		INP : IN std_logic_vector(11 downto 0);          
		FILTER_OUT : OUT std_logic_vector(11 downto 0)
		);
	END COMPONENT;

  signal prescaler_fast : std_logic_vector(6 downto 0) := (others => '0'); -- div 127
  signal sample_clk_d1, sample_tick : std_logic;
  signal noise_tick : std_logic;

  signal noise_lfsr : std_logic_vector(16 downto 0) := (others => '0'); -- 24425 Hz
  signal noise_raw, noise_filt, noise_lp : std_logic_vector(11 downto 0);

  signal decay_prescaler : std_logic_vector(9 downto 0); -- must fit decay_prescaler_max
  constant decay_prescaler_max : integer := 400; -- max value for the decay prescaler, smaller = faster decay
  constant decay_startval : std_logic_vector(7 downto 0) := x"B0"; -- max value for the decay prescaler, higher = higher cutoff
  signal decay : std_logic_vector(7 downto 0); -- Filter frequency setting
  signal decay_tick : std_logic;
  signal audio_mult_signed : std_logic_vector(20 downto 0); -- leveled Audio Output

begin
  sample_clk_sync : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      sample_tick <= '0';
      if SAMPLE_CLK = '1' and sample_clk_d1 = '0' then
        sample_tick <= '1'; -- rising edge of SAMPLE_CLK
      end if;
      sample_clk_d1 <= SAMPLE_CLK;
    end if;
  end process;

  -- mod-127-counter by LFSR
  prescale_noise : process (SYSCLK)
    variable lfsr_fb : std_logic;
  begin
    if rising_edge(SYSCLK) then
      lfsr_fb := prescaler_fast(6) xnor prescaler_fast(5);
      prescaler_fast <= prescaler_fast(5 downto 0) & lfsr_fb;
      noise_tick <= '0';
      if prescaler_fast = 0 then
        noise_tick <= '1'; -- SYSCLK div 127
      end if;
    end if;
  end process;

  noise_gen : process (SYSCLK)
    variable lfsr_fb : std_logic;
  begin
    if rising_edge(SYSCLK) then
      decay_tick <= '0';
      if (noise_tick = '1') then
        lfsr_fb := noise_lfsr(16) xnor noise_lfsr(11);
        noise_lfsr <= noise_lfsr(15 downto 0) & lfsr_fb;
      end if;
      if (sample_tick = '1') then
        noise_raw <= noise_lfsr(11) & noise_lfsr(11 downto 1); -- half-signed
        decay_prescaler <= decay_prescaler + 1;
        if decay_prescaler = decay_prescaler_max then
          decay_tick <= '1';
          decay_prescaler <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  Inst_lowpass_6 : lowpass_6
  generic map(
    FREQU => 5
  )
  port map(
    SYSCLK => SYSCLK,
    SYNC => sample_tick,
    INP => noise_raw,
    FILTER_OUT => noise_lp
  );

  Inst_level_decay : level_decay port map(
    SYSCLK => SYSCLK,
    INTEGR_TICK => decay_tick,
    TRIGGER => TRIGGER,
    START_VAL => decay_startval, -- initial value for the frequency decay
    DIFF_OUT => decay
  );

  Inst_biquad_mult_kq : biquad_mult_kq
  port map(
    SYSCLK => SYSCLK,
    SYNC => sample_tick,
    INP => noise_raw,
    KF => decay,
    KQ => "01",
    HP => open,
    LP => noise_filt, 
    BP => open
  );

  audio_mult_signed <= (noise_lp + noise_filt) * ('0' & decay);

  audio_proc : process (SYSCLK)
  begin
    if rising_edge(SYSCLK) then
      AUDIO <= audio_mult_signed(18 downto 7);
    end if;
  end process;

end rtl;