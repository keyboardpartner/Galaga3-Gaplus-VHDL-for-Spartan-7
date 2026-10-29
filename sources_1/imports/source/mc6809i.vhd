--------------------------------------------------------------------------------
-- Cycle-Accurate 6809 Core
--
-- VHDL translation of mc6809i.v
-- Original Verilog: Copyright (c) 2016, Greg Miller
--
-- The structure of the Verilog source is kept 1:1:
--   * one big combinational process computing the "_nxt" values (the Verilog
--     "always @(*)" block), written with variables because the Verilog uses
--     blocking assignments and re-reads values it has just written,
--   * the sampling/latching processes triggered by the falling edges of Q and E.
--
-- Generic ILLEGAL_INSTRUCTIONS: "GHOST" (default), "STOP" or "IGNORE"
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mc6809i is
  generic (
    ILLEGAL_INSTRUCTIONS : string := "GHOST"
  );
  port (
    D        : in  std_logic_vector(7 downto 0);
    DOut     : out std_logic_vector(7 downto 0);
    ADDR     : out std_logic_vector(15 downto 0);
    RnW      : out std_logic;
    E        : in  std_logic;
    Q        : in  std_logic;
    BS       : out std_logic;
    BA       : out std_logic;
    nIRQ     : in  std_logic;
    nFIRQ    : in  std_logic;
    nNMI     : in  std_logic;
    AVMA     : out std_logic;
    BUSY     : out std_logic;
    LIC      : out std_logic;
    nHALT    : in  std_logic;
    nRESET   : in  std_logic;
    nDMABREQ : in  std_logic;
    RegData  : out std_logic_vector(111 downto 0)
  );
end mc6809i;

architecture rtl of mc6809i is

  subtype byte_t is std_logic_vector(7 downto 0);
  subtype word_t is std_logic_vector(15 downto 0);

  ------------------------------------------------------------------------------
  -- Vectors
  ------------------------------------------------------------------------------
  constant RESET_VECTOR : word_t := x"FFFE";
  constant NMI_VECTOR   : word_t := x"FFFC";
  constant SWI_VECTOR   : word_t := x"FFFA";
  constant IRQ_VECTOR   : word_t := x"FFF8";
  constant FIRQ_VECTOR  : word_t := x"FFF6";
  constant SWI2_VECTOR  : word_t := x"FFF4";
  constant SWI3_VECTOR  : word_t := x"FFF2";

  ------------------------------------------------------------------------------
  -- Condition code bits
  ------------------------------------------------------------------------------
  constant CC_E : byte_t := x"80";
  constant CC_F : byte_t := x"40";
  constant CC_H : byte_t := x"20";
  constant CC_I : byte_t := x"10";
  constant CC_N : byte_t := x"08";
  constant CC_Z : byte_t := x"04";
  constant CC_V : byte_t := x"02";
  constant CC_C : byte_t := x"01";

  constant CC_E_BIT : integer := 7;
  constant CC_F_BIT : integer := 6;
  constant CC_H_BIT : integer := 5;
  constant CC_I_BIT : integer := 4;
  constant CC_N_BIT : integer := 3;
  constant CC_Z_BIT : integer := 2;
  constant CC_V_BIT : integer := 1;
  constant CC_C_BIT : integer := 0;

  ------------------------------------------------------------------------------
  -- Interrupt types
  ------------------------------------------------------------------------------
  constant INTTYPE_NMI  : integer := 0;
  constant INTTYPE_IRQ  : integer := 1;
  constant INTTYPE_FIRQ : integer := 2;
  constant INTTYPE_SWI  : integer := 3;
  constant INTTYPE_SWI2 : integer := 4;
  constant INTTYPE_SWI3 : integer := 5;

  ------------------------------------------------------------------------------
  -- CPU states
  ------------------------------------------------------------------------------
  constant CPUSTATE_RESET               : integer := 0;
  constant CPUSTATE_RESET0              : integer := 1;
  constant CPUSTATE_RESET2              : integer := 3;
  constant CPUSTATE_FETCH_I1            : integer := 4;
  constant CPUSTATE_FETCH_I1V2          : integer := 5;
  constant CPUSTATE_FETCH_I2            : integer := 8;

  constant CPUSTATE_LBRA_OFFSETLOW      : integer := 17;
  constant CPUSTATE_LBRA_DONTCARE       : integer := 18;
  constant CPUSTATE_LBRA_DONTCARE2      : integer := 19;

  constant CPUSTATE_BRA_DONTCARE        : integer := 20;

  constant CPUSTATE_BSR_DONTCARE1       : integer := 21;
  constant CPUSTATE_BSR_DONTCARE2       : integer := 22;
  constant CPUSTATE_BSR_RETURNLOW       : integer := 23;
  constant CPUSTATE_BSR_RETURNHIGH      : integer := 24;

  constant CPUSTATE_TFR_DONTCARE1       : integer := 26;
  constant CPUSTATE_TFR_DONTCARE2       : integer := 27;
  constant CPUSTATE_TFR_DONTCARE3       : integer := 28;
  constant CPUSTATE_TFR_DONTCARE4       : integer := 29;

  constant CPUSTATE_EXG_DONTCARE1       : integer := 30;
  constant CPUSTATE_EXG_DONTCARE2       : integer := 31;
  constant CPUSTATE_EXG_DONTCARE3       : integer := 32;
  constant CPUSTATE_EXG_DONTCARE4       : integer := 33;
  constant CPUSTATE_EXG_DONTCARE5       : integer := 34;
  constant CPUSTATE_EXG_DONTCARE6       : integer := 35;

  constant CPUSTATE_ABX_DONTCARE        : integer := 36;

  constant CPUSTATE_RTS_HI              : integer := 38;
  constant CPUSTATE_RTS_LO              : integer := 39;
  constant CPUSTATE_RTS_DONTCARE2       : integer := 40;

  constant CPUSTATE_16IMM_LO            : integer := 41;
  constant CPUSTATE_ALU16_DONTCARE      : integer := 42;
  constant CPUSTATE_DIRECT_DONTCARE     : integer := 43;

  constant CPUSTATE_ALU_EA              : integer := 44;

  constant CPUSTATE_ALU_DONTCARE        : integer := 46;
  constant CPUSTATE_ALU_WRITEBACK       : integer := 47;

  constant CPUSTATE_LD16_LO             : integer := 48;

  constant CPUSTATE_ST16_LO             : integer := 49;
  constant CPUSTATE_ALU16_LO            : integer := 50;

  constant CPUSTATE_JSR_DONTCARE        : integer := 53;
  constant CPUSTATE_JSR_RETLO           : integer := 54;
  constant CPUSTATE_JSR_RETHI           : integer := 55;
  constant CPUSTATE_EXTENDED_ADDRLO     : integer := 56;
  constant CPUSTATE_EXTENDED_DONTCARE   : integer := 57;
  constant CPUSTATE_INDEXED_BASE        : integer := 58;

  constant CPUSTATE_IDX_DONTCARE3       : integer := 60;

  constant CPUSTATE_IDX_OFFSET_LO       : integer := 61;
  constant CPUSTATE_IDX_16OFFSET_LO     : integer := 62;

  constant CPUSTATE_IDX_16OFF_DONTCARE0 : integer := 63;
  constant CPUSTATE_IDX_16OFF_DONTCARE1 : integer := 64;
  constant CPUSTATE_IDX_16OFF_DONTCARE2 : integer := 65;
  constant CPUSTATE_IDX_16OFF_DONTCARE3 : integer := 66;

  constant CPUSTATE_IDX_DOFF_DONTCARE1  : integer := 68;
  constant CPUSTATE_IDX_DOFF_DONTCARE2  : integer := 69;
  constant CPUSTATE_IDX_DOFF_DONTCARE3  : integer := 70;
  constant CPUSTATE_IDX_PC16OFF_DONTCARE : integer := 71;

  constant CPUSTATE_IDX_EXTIND_LO       : integer := 72;
  constant CPUSTATE_IDX_EXTIND_DONTCARE : integer := 73;

  constant CPUSTATE_INDIRECT_HI         : integer := 74;
  constant CPUSTATE_INDIRECT_LO         : integer := 75;
  constant CPUSTATE_INDIRECT_DONTCARE   : integer := 76;
  constant CPUSTATE_MUL_ACTION          : integer := 77;

  constant CPUSTATE_PSH_DONTCARE1       : integer := 80;
  constant CPUSTATE_PSH_DONTCARE2       : integer := 81;
  constant CPUSTATE_PSH_DONTCARE3       : integer := 82;
  constant CPUSTATE_PSH_ACTION          : integer := 83;

  constant CPUSTATE_PUL_DONTCARE1       : integer := 84;
  constant CPUSTATE_PUL_DONTCARE2       : integer := 85;
  constant CPUSTATE_PUL_ACTION          : integer := 86;

  constant CPUSTATE_NMI_START           : integer := 87;
  constant CPUSTATE_IRQ_DONTCARE        : integer := 88;
  constant CPUSTATE_IRQ_START           : integer := 89;
  constant CPUSTATE_IRQ_DONTCARE2       : integer := 90;
  constant CPUSTATE_IRQ_VECTOR_HI       : integer := 91;
  constant CPUSTATE_IRQ_VECTOR_LO       : integer := 92;
  constant CPUSTATE_FIRQ_START          : integer := 93;
  constant CPUSTATE_CC_DONTCARE         : integer := 94;
  constant CPUSTATE_SWI_START           : integer := 95;

  constant CPUSTATE_TST_DONTCARE1       : integer := 96;
  constant CPUSTATE_TST_DONTCARE2       : integer := 97;

  constant CPUSTATE_DEBUG               : integer := 98;

  constant CPUSTATE_16IMM_DONTCARE      : integer := 99;

  constant CPUSTATE_HALTED              : integer := 100;

  constant CPUSTATE_HALT_EXIT2          : integer := 102;
  constant CPUSTATE_STOP                : integer := 105;
  constant CPUSTATE_STOP2               : integer := 106;
  constant CPUSTATE_STOP3               : integer := 107;

  constant CPUSTATE_CWAI                : integer := 108;
  constant CPUSTATE_CWAI_DONTCARE1      : integer := 109;
  constant CPUSTATE_CWAI_POST           : integer := 110;

  constant CPUSTATE_DMABREQ             : integer := 111;
  constant CPUSTATE_DMABREQ_EXIT        : integer := 112;
  constant CPUSTATE_SYNC                : integer := 113;
  constant CPUSTATE_SYNC_EXIT           : integer := 114;

  constant CPUSTATE_INT_DONTCARE        : integer := 115;

  ------------------------------------------------------------------------------
  -- Illegal instruction handling selected by the generic
  ------------------------------------------------------------------------------
  function sel_post_illegal(g : string) return integer is
  begin
    if g = "STOP" then
      return CPUSTATE_STOP;
    else
      return CPUSTATE_FETCH_I1;
    end if;
  end function;

  function sel_illegal_state(g : string) return integer is
  begin
    if g = "IGNORE" then
      return CPUSTATE_FETCH_I1;
    elsif g = "STOP" then
      return CPUSTATE_STOP;
    else
      return 0;
    end if;
  end function;

  constant PostIllegalState        : integer := sel_post_illegal(ILLEGAL_INSTRUCTIONS);
  constant IllegalInstructionState : integer := sel_illegal_state(ILLEGAL_INSTRUCTIONS);
  constant GHOST_MODE              : boolean := (ILLEGAL_INSTRUCTIONS = "GHOST");

  ------------------------------------------------------------------------------
  -- Index postbyte decode constants
  ------------------------------------------------------------------------------
  constant IDX_REG_X  : integer := 0;
  constant IDX_REG_Y  : integer := 1;
  constant IDX_REG_U  : integer := 2;
  constant IDX_REG_S  : integer := 3;
  constant IDX_REG_PC : integer := 4;

  constant IDX_MODE_POSTINC1        : integer := 0;
  constant IDX_MODE_POSTINC2        : integer := 1;
  constant IDX_MODE_PREDEC1         : integer := 2;
  constant IDX_MODE_PREDEC2         : integer := 3;
  constant IDX_MODE_NOOFFSET        : integer := 4;
  constant IDX_MODE_B_OFFSET        : integer := 5;
  constant IDX_MODE_A_OFFSET        : integer := 6;
  constant IDX_MODE_5BIT_OFFSET     : integer := 7;
  constant IDX_MODE_8BIT_OFFSET     : integer := 8;
  constant IDX_MODE_16BIT_OFFSET    : integer := 9;
  constant IDX_MODE_D_OFFSET        : integer := 11;
  constant IDX_MODE_8BIT_OFFSET_PC  : integer := 12;
  constant IDX_MODE_16BIT_OFFSET_PC : integer := 13;
  constant IDX_MODE_EXTENDED_INDIRECT : integer := 15;

  ------------------------------------------------------------------------------
  -- Store / ALU constants
  ------------------------------------------------------------------------------
  constant ST8_REG_A : std_logic := '0';
  constant ST8_REG_B : std_logic := '1';

  constant ST16_REG_X : integer := 0;
  constant ST16_REG_Y : integer := 1;
  constant ST16_REG_U : integer := 2;
  constant ST16_REG_S : integer := 3;
  constant ST16_REG_D : integer := 4;

  constant ALU16_REG_X : integer := 0;
  constant ALU16_REG_Y : integer := 1;
  constant ALU16_REG_U : integer := 2;
  constant ALU16_REG_S : integer := 3;
  constant ALU16_REG_D : integer := 4;

  constant ALUOP16_SUB     : integer := 0;
  constant ALUOP16_ADD     : integer := 1;
  constant ALUOP16_LD      : integer := 2;
  constant ALUOP16_CMP     : integer := 3;
  constant ALUOP16_LEA     : integer := 4;
  constant ALUOP16_INVALID : integer := 7;

  constant ALUOP_NEG : integer := 0;
  constant ALUOP_COM : integer := 3;
  constant ALUOP_LSR : integer := 4;
  constant ALUOP_ROR : integer := 6;
  constant ALUOP_ASR : integer := 7;
  constant ALUOP_ASL : integer := 8;
  constant ALUOP_LSL : integer := 8;
  constant ALUOP_ROL : integer := 9;
  constant ALUOP_DEC : integer := 10;
  constant ALUOP_INC : integer := 12;
  constant ALUOP_TST : integer := 13;
  constant ALUOP_CLR : integer := 15;

  constant ALUOP_SUB : integer := 16;
  constant ALUOP_CMP : integer := 17;
  constant ALUOP_SBC : integer := 18;
  constant ALUOP_AND : integer := 20;
  constant ALUOP_BIT : integer := 21;
  constant ALUOP_LD  : integer := 22;
  constant ALUOP_EOR : integer := 24;
  constant ALUOP_ADC : integer := 25;
  constant ALUOP_OR  : integer := 26;
  constant ALUOP_ADD : integer := 27;

  constant TYPE_INHERENT  : integer := 0;
  constant TYPE_IMMEDIATE : integer := 1;
  constant TYPE_DIRECT    : integer := 2;
  constant TYPE_RELATIVE  : integer := 3;
  constant TYPE_INDEXED   : integer := 4;
  constant TYPE_EXTENDED  : integer := 5;
  constant TYPE_INVALID   : integer := 7;

  constant OPCODE_INH_ABX  : byte_t := x"3A";
  constant OPCODE_INH_RTS  : byte_t := x"39";
  constant OPCODE_INH_RTI  : byte_t := x"3B";
  constant OPCODE_INH_CWAI : byte_t := x"3C";
  constant OPCODE_INH_MUL  : byte_t := x"3D";
  constant OPCODE_INH_SWI  : byte_t := x"3F";
  constant OPCODE_INH_SEX  : byte_t := x"1D";
  constant OPCODE_INH_NOP  : byte_t := x"12";
  constant OPCODE_INH_SYNC : byte_t := x"13";
  constant OPCODE_INH_DAA  : byte_t := x"19";

  constant OPCODE_IMM_ORCC  : byte_t := x"1A";
  constant OPCODE_IMM_ANDCC : byte_t := x"1C";
  constant OPCODE_IMM_EXG   : byte_t := x"1E";
  constant OPCODE_IMM_TFR   : byte_t := x"1F";
  constant OPCODE_IMM_PSHS  : byte_t := x"34";
  constant OPCODE_IMM_PULS  : byte_t := x"35";
  constant OPCODE_IMM_PSHU  : byte_t := x"36";
  constant OPCODE_IMM_PULU  : byte_t := x"37";

  constant EXGTFR_REG_D  : integer := 0;
  constant EXGTFR_REG_X  : integer := 1;
  constant EXGTFR_REG_Y  : integer := 2;
  constant EXGTFR_REG_U  : integer := 3;
  constant EXGTFR_REG_S  : integer := 4;
  constant EXGTFR_REG_PC : integer := 5;
  constant EXGTFR_REG_A  : integer := 8;
  constant EXGTFR_REG_B  : integer := 9;
  constant EXGTFR_REG_CC : integer := 10;
  constant EXGTFR_REG_DP : integer := 11;

  constant INST_LBRA : byte_t := x"16";
  constant INST_LBSR : byte_t := x"17";
  constant INST_BSR  : byte_t := x"8D";

  ------------------------------------------------------------------------------
  -- Helper functions
  ------------------------------------------------------------------------------
  function sext8(v : byte_t) return word_t is
  begin
    return (15 downto 8 => v(7)) & v;
  end function;

  function sext5(v : std_logic_vector(4 downto 0)) return word_t is
  begin
    return (15 downto 5 => v(4)) & v;
  end function;

  function add16(v : word_t; n : integer) return word_t is
  begin
    return std_logic_vector(unsigned(v) + n);
  end function;

  function sub16(v : word_t; n : integer) return word_t is
  begin
    return std_logic_vector(unsigned(v) - n);
  end function;

  function to_sl(bv : boolean) return std_logic is
  begin
    if bv then
      return '1';
    else
      return '0';
    end if;
  end function;

  function nib(v : byte_t; hi : boolean) return integer is
  begin
    if hi then
      return to_integer(unsigned(v(7 downto 4)));
    else
      return to_integer(unsigned(v(3 downto 0)));
    end if;
  end function;

  -- Maps instructions the real 6809 would ghost onto a neighbour
  function MapInstruction(i : byte_t) return byte_t is
    variable topnyb : std_logic_vector(3 downto 0);
    variable btmnyb : std_logic_vector(3 downto 0);
    variable newinst : byte_t;
  begin
    newinst := i;
    topnyb  := i(7 downto 4);
    btmnyb  := i(3 downto 0);
    if topnyb = x"0" or topnyb = x"4" or topnyb = x"5" or topnyb = x"6" or topnyb = x"7" then
      if btmnyb = x"1" then
        newinst := topnyb & x"0";
      end if;
      if btmnyb = x"2" then
        newinst := topnyb & x"3";
      end if;
      if btmnyb = x"5" then
        newinst := topnyb & x"4";
      end if;
      if btmnyb = x"B" then
        newinst := topnyb & x"A";
      end if;
    end if;
    return newinst;
  end function;

  function IllegalInstruction(i : byte_t) return boolean is
    variable hi      : integer;
    variable lo      : integer;
    variable illegal : boolean;
  begin
    illegal := false;
    hi := nib(i, true);
    lo := nib(i, false);
    if hi = 0 or hi = 4 or hi = 5 or hi = 6 or hi = 7 then
      if lo = 1 or lo = 2 or lo = 5 or lo = 11 then
        illegal := true;
      end if;
      if lo = 14 then
        if hi = 4 or hi = 5 then
          illegal := true;
        end if;
      end if;
    end if;
    if hi = 3 then
      if lo = 8 or lo = 14 then
        illegal := true;
      end if;
    end if;
    if hi = 1 then
      if lo = 4 or lo = 5 or lo = 8 or lo = 11 then
        illegal := true;
      end if;
    end if;
    if hi = 8 or hi = 12 then
      if lo = 7 or lo = 15 then
        illegal := true;
      end if;
      if lo = 13 then
        if hi = 12 then
          illegal := true;
        end if;
      end if;
    end if;
    return illegal;
  end function;

  -- Index postbyte decode: indirect flag, mode[3:0], register number
  procedure IndexDecode(postbyte : in byte_t;
                        indirect : out boolean;
                        mode     : out integer;
                        regnum   : out integer) is
    variable m : integer;
  begin
    indirect := false;
    if postbyte(7) = '0' then
      m := IDX_MODE_5BIT_OFFSET;
    else
      m := to_integer(unsigned(postbyte(3 downto 0)));
      indirect := (postbyte(4) = '1');
    end if;
    if m /= IDX_MODE_8BIT_OFFSET_PC and m /= IDX_MODE_16BIT_OFFSET_PC then
      regnum := to_integer(unsigned(postbyte(6 downto 5)));
    else
      regnum := IDX_REG_PC;
    end if;
    mode := m;
  end procedure;

  function IsJMP(inst : byte_t) return boolean is
    variable hi : integer;
    variable lo : integer;
  begin
    hi := nib(inst, true);
    lo := nib(inst, false);
    if hi = 0 or hi = 6 or hi = 7 then
      if lo = 14 then
        return true;
      end if;
    end if;
    return false;
  end function;

  function IsSpecialImm(inst : byte_t) return boolean is
    variable hi : integer;
    variable lo : integer;
    variable is_v : boolean;
  begin
    hi := nib(inst, true);
    lo := nib(inst, false);
    is_v := false;
    if hi = 1 then
      if lo = 10 or lo = 12 or lo = 14 or lo = 15 then
        is_v := true;
      end if;
    elsif hi = 3 then
      if lo >= 3 and lo <= 7 then
        is_v := true;
      end if;
    else
      is_v := false;
    end if;
    return is_v;
  end function;

  function IsOneByteInstruction(inst : byte_t) return boolean is
    variable hi : integer;
    variable lo : integer;
    variable is_v : boolean;
  begin
    hi := nib(inst, true);
    lo := nib(inst, false);
    is_v := false;
    if hi = 4 or hi = 5 then
      is_v := true;
    elsif hi = 1 then
      if lo = 2 or lo = 3 or lo = 9 or lo = 13 then
        is_v := true;
      end if;
    elsif hi = 3 then
      if lo >= 9 and lo /= 12 then
        is_v := true;
      end if;
    else
      is_v := false;
    end if;
    return is_v;
  end function;

  function IsALU8Set0(instr : byte_t) return boolean is
    variable hi : integer;
    variable lo : integer;
  begin
    hi := nib(instr, true);
    lo := nib(instr, false);
    if hi = 0 or hi = 4 or hi = 5 or hi = 6 or hi = 7 then
      if lo /= 1 and lo /= 2 and lo /= 5 and lo /= 11 and lo /= 14 then
        return true;
      end if;
    end if;
    return false;
  end function;

  function IsALU8Set1(instr : byte_t) return boolean is
    variable hi : integer;
    variable lo : integer;
  begin
    hi := nib(instr, true);
    lo := nib(instr, false);
    if hi >= 8 then
      if lo <= 11 and lo /= 3 and lo /= 7 then
        return true;
      end if;
    end if;
    return false;
  end function;

  function ALU8BitOp(instr : byte_t) return boolean is
  begin
    return IsALU8Set0(instr) or IsALU8Set1(instr);
  end function;

  function IsRegA(instr : byte_t) return boolean is
    variable hi : integer;
  begin
    hi := nib(instr, true);
    return (hi = 4 or hi = 8 or hi = 9 or hi = 10 or hi = 11);
  end function;

  -- 8 bit ALU operation of an instruction: op = {inst[7], inst[3:0]}
  function ALU8OpOf(inst : byte_t) return integer is
  begin
    return to_integer(unsigned(inst(7 downto 7) & inst(3 downto 0)));
  end function;

  function ALU8WritebackOf(inst : byte_t) return boolean is
    variable op : integer;
  begin
    op := ALU8OpOf(inst);
    if op = ALUOP_CMP or op = ALUOP_TST or op = ALUOP_BIT then
      return false;
    end if;
    return true;
  end function;

  -- Store decode (8 bit): returns IsStore and the register
  procedure IsST8(inst : in byte_t; is_store : out boolean; regnum : out std_logic) is
  begin
    is_store := false;
    regnum   := '1';
    if inst = x"97" or inst = x"A7" or inst = x"B7" then
      is_store := true;
      regnum   := '0';
    elsif inst = x"D7" or inst = x"E7" or inst = x"F7" then
      is_store := true;
      regnum   := '1';
    end if;
  end procedure;

  procedure IsST16(inst : in byte_t; page2 : in std_logic;
                   is_store : out boolean; regnum : out integer) is
  begin
    is_store := false;
    regnum   := 7;
    if inst = x"9F" or inst = x"AF" or inst = x"BF" then
      is_store := true;
      if page2 = '0' then
        regnum := ST16_REG_X;
      else
        regnum := ST16_REG_Y;
      end if;
    elsif inst = x"DF" or inst = x"EF" or inst = x"FF" then
      is_store := true;
      if page2 = '0' then
        regnum := ST16_REG_U;
      else
        regnum := ST16_REG_S;
      end if;
    elsif inst = x"DD" or inst = x"ED" or inst = x"FD" then
      is_store := true;
      regnum := ST16_REG_D;
    end if;
  end procedure;

  function pmatch(key : std_logic_vector(9 downto 0); pat : unsigned(9 downto 0)) return boolean is
  begin
    return std_match(unsigned(key), pat);
  end function;

  function ALU16RegFromInst(page2 : std_logic; page3 : std_logic; inst : byte_t) return integer is
    variable key : std_logic_vector(9 downto 0);
  begin
    key := page2 & page3 & inst;
    if    pmatch(key, "1010--0011") then return ALU16_REG_D;  -- CMPD
    elsif pmatch(key, "1010--1100") then return ALU16_REG_Y;  -- CMPY
    elsif pmatch(key, "0110--0011") then return ALU16_REG_U;  -- CMPU
    elsif pmatch(key, "0110--1100") then return ALU16_REG_S;  -- CMPS
    elsif pmatch(key, "0010--1100") then return ALU16_REG_X;  -- CMPX
    elsif pmatch(key, "0011--0011") then return ALU16_REG_D;  -- ADDD
    elsif pmatch(key, "0011--1100") then return ALU16_REG_D;  -- LDD
    elsif pmatch(key, "0010--1110") then return ALU16_REG_X;  -- LDX
    elsif pmatch(key, "0011--1110") then return ALU16_REG_U;  -- LDU
    elsif pmatch(key, "1010--1110") then return ALU16_REG_Y;  -- LDY
    elsif pmatch(key, "1011--1110") then return ALU16_REG_S;  -- LDS
    elsif pmatch(key, "0010--0011") then return ALU16_REG_D;  -- SUBD
    elsif pmatch(key, "0000111010") then return ALU16_REG_X;  -- ABX
    elsif pmatch(key, "0000110000") then return ALU16_REG_X;  -- LEAX
    elsif pmatch(key, "0000110001") then return ALU16_REG_Y;  -- LEAY
    elsif pmatch(key, "0000110010") then return ALU16_REG_S;  -- LEAS
    elsif pmatch(key, "0000110011") then return ALU16_REG_U;  -- LEAU
    else return 7;
    end if;
  end function;

  -- 16 bit ALU operation of an instruction and whether it writes back
  procedure ALU16OpFromInst(page2 : in std_logic; page3 : in std_logic; inst : in byte_t;
                            writeback : out boolean; aluop : out integer) is
    variable key : std_logic_vector(9 downto 0);
  begin
    key := page2 & page3 & inst;
    aluop     := 7;
    writeback := true;
    if    pmatch(key, "1010--0011") then aluop := ALUOP16_CMP; writeback := false;
    elsif pmatch(key, "1010--1100") then aluop := ALUOP16_CMP; writeback := false;
    elsif pmatch(key, "0110--0011") then aluop := ALUOP16_CMP; writeback := false;
    elsif pmatch(key, "0110--1100") then aluop := ALUOP16_CMP; writeback := false;
    elsif pmatch(key, "0010--1100") then aluop := ALUOP16_CMP; writeback := false;
    elsif pmatch(key, "0011--0011") then aluop := ALUOP16_ADD;
    elsif pmatch(key, "0011--1100") then aluop := ALUOP16_LD;
    elsif pmatch(key, "001---1110") then aluop := ALUOP16_LD;
    elsif pmatch(key, "101---1110") then aluop := ALUOP16_LD;
    elsif pmatch(key, "0010--0011") then aluop := ALUOP16_SUB;
    elsif pmatch(key, "0000111010") then aluop := ALUOP16_ADD;
    elsif pmatch(key, "00001100--") then aluop := ALUOP16_LEA;
    else aluop := ALUOP16_INVALID;
    end if;
  end procedure;

  -- 16 bit ALU, returns {cc[7:0], result[15:0]}
  function ALU16Inst(operation16 : integer; a_arg : word_t; b_arg : word_t; cc_arg : byte_t)
    return std_logic_vector is
    variable cc_out : byte_t;
    variable ALUFn  : word_t;
    variable sum    : unsigned(16 downto 0);
  begin
    cc_out := cc_arg;
    ALUFn  := (others => '0');
    case operation16 is
      when ALUOP16_ADD =>
        sum := ('0' & unsigned(a_arg)) + ('0' & unsigned(b_arg));
        cc_out(CC_C_BIT) := sum(16);
        ALUFn := std_logic_vector(sum(15 downto 0));
        cc_out(CC_V_BIT) := (a_arg(15) and b_arg(15) and not ALUFn(15)) or
                            (not a_arg(15) and not b_arg(15) and ALUFn(15));
      when ALUOP16_SUB | ALUOP16_CMP =>
        sum := ('0' & unsigned(a_arg)) - ('0' & unsigned(b_arg));
        cc_out(CC_C_BIT) := sum(16);
        ALUFn := std_logic_vector(sum(15 downto 0));
        cc_out(CC_V_BIT) := (a_arg(15) and not b_arg(15) and not ALUFn(15)) or
                            (not a_arg(15) and b_arg(15) and ALUFn(15));
      when ALUOP16_LD =>
        ALUFn := b_arg;
        cc_out(CC_V_BIT) := '0';
      when ALUOP16_LEA =>
        ALUFn := a_arg;
      when others =>
        ALUFn := (others => '0');
    end case;
    cc_out(CC_Z_BIT) := to_sl(ALUFn = x"0000");
    if operation16 /= ALUOP16_LEA then
      cc_out(CC_N_BIT) := ALUFn(15);
    end if;
    return cc_out & ALUFn;
  end function;

  -- 8 bit ALU, returns {cc[7:0], result[7:0]}
  function ALUInst(operation : integer; a_arg : byte_t; b_arg : byte_t; cc_arg : byte_t)
    return std_logic_vector is
    variable cc_out : byte_t;
    variable ALUFn  : byte_t;
    variable sum    : unsigned(8 downto 0);
  begin
    cc_out := cc_arg;
    ALUFn  := (others => '0');
    case operation is
      when ALUOP_NEG =>
        ALUFn := std_logic_vector(unsigned(not a_arg) + 1);
        cc_out(CC_C_BIT) := to_sl(ALUFn /= x"00");
        cc_out(CC_V_BIT) := to_sl(a_arg = x"80");

      when ALUOP_LSL =>
        cc_out(CC_C_BIT) := a_arg(7);
        ALUFn := a_arg(6 downto 0) & '0';
        cc_out(CC_V_BIT) := a_arg(7) xor a_arg(6);

      when ALUOP_LSR =>
        cc_out(CC_C_BIT) := a_arg(0);
        ALUFn := '0' & a_arg(7 downto 1);

      when ALUOP_ASR =>
        cc_out(CC_C_BIT) := a_arg(0);
        ALUFn := a_arg(7) & a_arg(7 downto 1);

      when ALUOP_ROL =>
        cc_out(CC_C_BIT) := a_arg(7);
        ALUFn := a_arg(6 downto 0) & cc_arg(CC_C_BIT);
        cc_out(CC_V_BIT) := a_arg(7) xor a_arg(6);

      when ALUOP_ROR =>
        cc_out(CC_C_BIT) := a_arg(0);
        ALUFn := cc_arg(CC_C_BIT) & a_arg(7 downto 1);

      when ALUOP_OR =>
        ALUFn := a_arg or b_arg;
        cc_out(CC_V_BIT) := '0';

      when ALUOP_ADD =>
        sum := ('0' & unsigned(a_arg)) + ('0' & unsigned(b_arg));
        cc_out(CC_C_BIT) := sum(8);
        ALUFn := std_logic_vector(sum(7 downto 0));
        cc_out(CC_V_BIT) := (a_arg(7) and b_arg(7) and not ALUFn(7)) or
                            (not a_arg(7) and not b_arg(7) and ALUFn(7));
        cc_out(CC_H_BIT) := a_arg(4) xor b_arg(4) xor ALUFn(4);

      when ALUOP_SUB | ALUOP_CMP =>
        sum := ('0' & unsigned(a_arg)) - ('0' & unsigned(b_arg));
        cc_out(CC_C_BIT) := sum(8);
        ALUFn := std_logic_vector(sum(7 downto 0));
        cc_out(CC_V_BIT) := (a_arg(7) and not b_arg(7) and not ALUFn(7)) or
                            (not a_arg(7) and b_arg(7) and ALUFn(7));

      when ALUOP_AND | ALUOP_BIT =>
        ALUFn := a_arg and b_arg;
        cc_out(CC_V_BIT) := '0';

      when ALUOP_EOR =>
        ALUFn := a_arg xor b_arg;
        cc_out(CC_V_BIT) := '0';

      when ALUOP_COM =>
        ALUFn := not a_arg;
        cc_out(CC_V_BIT) := '0';
        cc_out(CC_C_BIT) := '1';

      when ALUOP_ADC =>
        sum := ('0' & unsigned(a_arg)) + ('0' & unsigned(b_arg));
        if cc_arg(CC_C_BIT) = '1' then
          sum := sum + 1;
        end if;
        cc_out(CC_C_BIT) := sum(8);
        ALUFn := std_logic_vector(sum(7 downto 0));
        cc_out(CC_V_BIT) := (a_arg(7) and b_arg(7) and not ALUFn(7)) or
                            (not a_arg(7) and not b_arg(7) and ALUFn(7));
        cc_out(CC_H_BIT) := a_arg(4) xor b_arg(4) xor ALUFn(4);

      when ALUOP_LD =>
        ALUFn := b_arg;
        cc_out(CC_V_BIT) := '0';

      when ALUOP_INC =>
        sum := ('0' & unsigned(a_arg)) + 1;
        ALUFn := std_logic_vector(sum(7 downto 0));
        cc_out(CC_V_BIT) := (not a_arg(7)) and ALUFn(7);

      when ALUOP_DEC =>
        sum := ('0' & unsigned(a_arg)) - 1;
        ALUFn := std_logic_vector(sum(7 downto 0));
        cc_out(CC_V_BIT) := a_arg(7) and (not ALUFn(7));

      when ALUOP_CLR =>
        ALUFn := x"00";
        cc_out(CC_V_BIT) := '0';
        cc_out(CC_C_BIT) := '0';

      when ALUOP_TST =>
        ALUFn := a_arg;
        cc_out(CC_V_BIT) := '0';

      when ALUOP_SBC =>
        sum := ('0' & unsigned(a_arg)) - ('0' & unsigned(b_arg));
        if cc_arg(CC_C_BIT) = '1' then
          sum := sum - 1;
        end if;
        cc_out(CC_C_BIT) := sum(8);
        ALUFn := std_logic_vector(sum(7 downto 0));
        cc_out(CC_V_BIT) := (a_arg(7) and not b_arg(7) and not ALUFn(7)) or
                            (not a_arg(7) and b_arg(7) and ALUFn(7));

      when others =>
        ALUFn := x"00";
    end case;

    cc_out(CC_N_BIT) := ALUFn(7);
    cc_out(CC_Z_BIT) := to_sl(ALUFn = x"00");
    return cc_out & ALUFn;
  end function;

  -- Addressing mode of an instruction
  function addressing_mode_type(inst : byte_t) return integer is
    variable hi : integer;
    variable lo : integer;
  begin
    hi := nib(inst, true);
    lo := nib(inst, false);
    case hi is
      when 0 => return TYPE_DIRECT;
      when 1 =>
        case lo is
          when 2 | 3 | 9 | 13    => return TYPE_INHERENT;
          when 6 | 7             => return TYPE_RELATIVE;
          when 10 | 12 | 14 | 15 => return TYPE_IMMEDIATE;
          when others            => return TYPE_INVALID;
        end case;
      when 2 => return TYPE_RELATIVE;
      when 3 =>
        case lo is
          when 0 to 3            => return TYPE_INDEXED;
          when 4 to 7            => return TYPE_IMMEDIATE;
          when 9 | 10 | 11 | 12 | 13 | 15 => return TYPE_INHERENT;
          when others            => return TYPE_INVALID;
        end case;
      when 4 | 5 => return TYPE_INHERENT;
      when 6 => return TYPE_INDEXED;
      when 7 => return TYPE_EXTENDED;
      when 8 =>
        case lo is
          when 7 | 15 => return TYPE_INVALID;
          when 13     => return TYPE_RELATIVE;
          when others => return TYPE_IMMEDIATE;
        end case;
      when 9  => return TYPE_DIRECT;
      when 10 => return TYPE_INDEXED;
      when 11 => return TYPE_EXTENDED;
      when 12 => return TYPE_IMMEDIATE;
      when 13 => return TYPE_DIRECT;
      when 14 => return TYPE_INDEXED;
      when others => return TYPE_EXTENDED;
    end case;
  end function;

  function take_branch(inst : byte_t; ccr : byte_t) return boolean is
    variable nv : std_logic;
  begin
    nv := ccr(CC_N_BIT) xor ccr(CC_V_BIT);
    if inst = INST_BSR or inst = INST_LBSR or inst = INST_LBRA then
      return true;
    end if;
    case nib(inst, false) is
      when 0  => return true;
      when 1  => return false;
      when 2  => return (ccr(CC_Z_BIT) or ccr(CC_C_BIT)) = '0';
      when 3  => return (ccr(CC_Z_BIT) or ccr(CC_C_BIT)) = '1';
      when 4  => return ccr(CC_C_BIT) = '0';
      when 5  => return ccr(CC_C_BIT) = '1';
      when 6  => return ccr(CC_Z_BIT) = '0';
      when 7  => return ccr(CC_Z_BIT) = '1';
      when 8  => return ccr(CC_V_BIT) = '0';
      when 9  => return ccr(CC_V_BIT) = '1';
      when 10 => return ccr(CC_N_BIT) = '0';
      when 11 => return ccr(CC_N_BIT) = '1';
      when 12 => return nv = '0';
      when 13 => return nv = '1';
      when 14 => return nv = '0' and ccr(CC_Z_BIT) = '0';
      when others => return nv = '1' or ccr(CC_Z_BIT) = '1';
    end case;
  end function;

  function EXGTFRRegister(regid : integer;
                          a_v : byte_t; b_v : byte_t;
                          x_v : word_t; y_v : word_t; u_v : word_t; s_v : word_t;
                          pc_p1_v : word_t; dp_v : byte_t; ccr : byte_t) return word_t is
  begin
    case regid is
      when EXGTFR_REG_D  => return a_v & b_v;
      when EXGTFR_REG_X  => return x_v;
      when EXGTFR_REG_Y  => return y_v;
      when EXGTFR_REG_U  => return u_v;
      when EXGTFR_REG_S  => return s_v;
      when EXGTFR_REG_PC => return pc_p1_v;
      when EXGTFR_REG_DP => return x"FF" & dp_v;
      when EXGTFR_REG_A  => return x"FF" & a_v;
      when EXGTFR_REG_B  => return x"FF" & b_v;
      when EXGTFR_REG_CC => return x"FF" & ccr;
      when others        => return x"0000";
    end case;
  end function;

  ------------------------------------------------------------------------------
  -- Registers
  ------------------------------------------------------------------------------
  signal a, b, dp, cc                     : byte_t := (others => '0');
  signal x, y, u, s, pc, tmp, addr_q, ea  : word_t := (others => '0');

  signal a_nxt_s, b_nxt_s, dp_nxt_s, cc_nxt_s : byte_t := (others => '0');
  signal x_nxt_s, y_nxt_s, u_nxt_s, s_nxt_s, pc_nxt_s, addr_nxt_s, ea_nxt_s, tmp_nxt_s
                                          : word_t := (others => '0');

  signal CpuState        : integer range 0 to 127 := CPUSTATE_RESET;
  signal CpuState_nxt_s  : integer range 0 to 127 := CPUSTATE_RESET;
  signal NextState       : integer range 0 to 127 := CPUSTATE_RESET;
  signal NextState_nxt_s : integer range 0 to 127 := CPUSTATE_RESET;

  signal IntType         : integer range 0 to 7 := 0;
  signal IntType_nxt_s   : integer range 0 to 7 := 0;

  signal InstPage2, InstPage3             : std_logic := '0';
  signal InstPage2_nxt_s, InstPage3_nxt_s : std_logic := '0';
  signal Inst1, Inst2, Inst3              : byte_t := (others => '0');
  signal Inst1_nxt_s, Inst2_nxt_s, Inst3_nxt_s : byte_t := (others => '0');

  -- Interrupt / control synchronisation
  signal NMIMask        : std_logic := '1';
  signal NMILatched     : std_logic := '1';
  signal NMISample      : std_logic := '1';
  signal NMISample2     : std_logic := '1';
  signal NMIClear       : std_logic := '0';
  signal NMIClear_nxt_s : std_logic := '0';

  signal IRQSample, IRQSample2, IRQLatched             : std_logic := '1';
  signal FIRQSample, FIRQSample2, FIRQLatched          : std_logic := '1';
  signal HALTSample, HALTSample2, HALTLatched          : std_logic := '1';
  signal DMABREQSample, DMABREQSample2, DMABREQLatched : std_logic := '1';

  signal rnRESET : std_logic := '0';

begin

  -- Debug ability to export register contents
  RegData(7 downto 0)     <= a;
  RegData(15 downto 8)    <= b;
  RegData(31 downto 16)   <= x;
  RegData(47 downto 32)   <= y;
  RegData(63 downto 48)   <= s;
  RegData(79 downto 64)   <= u;
  RegData(87 downto 80)   <= cc;
  RegData(95 downto 88)   <= dp;
  RegData(111 downto 96)  <= pc;

  ------------------------------------------------------------------------------
  -- NMI latch: set asynchronously by NMIClear, cleared by the falling edge of
  -- NMISample2 unless NMI is still masked
  ------------------------------------------------------------------------------
  nmi_latch : process(NMISample2, NMIClear)
  begin
    if NMIClear = '1' then
      NMILatched <= '1';
    elsif falling_edge(NMISample2) then
      if NMIMask = '0' then
        NMILatched <= '0';
      else
        NMILatched <= '1';
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- The control signals are sampled on the falling edge of Q
  ------------------------------------------------------------------------------
  q_sample : process(Q)
  begin
    if falling_edge(Q) then
      NMISample     <= nNMI;
      IRQSample     <= nIRQ;
      FIRQSample    <= nFIRQ;
      HALTSample    <= nHALT;
      DMABREQSample <= nDMABREQ;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- State and register latching on the falling edge of E
  ------------------------------------------------------------------------------
  e_latch : process(E)
  begin
    if falling_edge(E) then
      rnRESET <= nRESET;

      NMISample2 <= NMISample;

      IRQSample2  <= IRQSample;
      IRQLatched  <= IRQSample2;

      FIRQSample2 <= FIRQSample;
      FIRQLatched <= FIRQSample2;

      HALTSample2 <= HALTSample;
      HALTLatched <= HALTSample2;

      DMABREQSample2 <= DMABREQSample;
      DMABREQLatched <= DMABREQSample2;

      if rnRESET = '1' then
        CpuState  <= CpuState_nxt_s;
        NextState <= NextState_nxt_s;

        a  <= a_nxt_s;
        b  <= b_nxt_s;
        x  <= x_nxt_s;
        y  <= y_nxt_s;
        s  <= s_nxt_s;
        u  <= u_nxt_s;
        cc <= cc_nxt_s;
        dp <= dp_nxt_s;
        pc <= pc_nxt_s;
        tmp    <= tmp_nxt_s;
        addr_q <= addr_nxt_s;
        ea     <= ea_nxt_s;

        InstPage2 <= InstPage2_nxt_s;
        InstPage3 <= InstPage3_nxt_s;
        Inst1 <= Inst1_nxt_s;
        Inst2 <= Inst2_nxt_s;
        Inst3 <= Inst3_nxt_s;
        NMIClear <= NMIClear_nxt_s;

        IntType <= IntType_nxt_s;

        -- Once S changes at all, release the NMI mask
        if s /= s_nxt_s then
          NMIMask <= '0';
        end if;
      else
        CpuState <= CPUSTATE_RESET;
        NMIMask  <= '1';
        NMIClear <= '0';
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- CPU state machine (combinational)
  ------------------------------------------------------------------------------
  state_machine : process(CpuState, NextState, IntType, NMIClear,
                          a, b, x, y, u, s, pc, dp, cc, tmp, addr_q, ea,
                          Inst1, Inst2, Inst3, InstPage2, InstPage3, D,
                          DMABREQLatched, HALTLatched, FIRQLatched, IRQLatched, NMILatched,
                          DMABREQSample2, HALTSample2)
    variable a_nxt, b_nxt, dp_nxt, cc_nxt : byte_t;
    variable x_nxt, y_nxt, u_nxt, s_nxt, pc_nxt, addr_nxt, ea_nxt, tmp_nxt : word_t;
    variable BS_nxt, BA_nxt, NMIClear_nxt : std_logic;
    variable InstPage2_nxt, InstPage3_nxt : std_logic;
    variable IntType_nxt : integer range 0 to 7;
    variable NextState_nxt, CpuState_nxt : integer range 0 to 127;
    variable Inst1_nxt, Inst2_nxt, Inst3_nxt : byte_t;
    variable rLIC, rAVMA, rBUSY, RnWOut : std_logic;
    variable DOutput : byte_t;

    variable ALU_A, ALU_B, ALU_CC : byte_t;
    variable ALU_OP               : integer range 0 to 31;
    variable ALU16_OP             : integer range 0 to 7;
    variable ALU16_A, ALU16_B     : word_t;
    variable ALU16_CC             : byte_t;
    variable ALU_R                : std_logic_vector(15 downto 0);
    variable ALU16_R              : std_logic_vector(23 downto 0);

    -- Convenience calculations
    variable pc_p1, pc_p2, pc_p3, s_p1, s_m1, u_p1, u_m1, addr_p1, ea_p1 : word_t;

    -- Decoded properties of the current instruction (functions of the registers)
    variable MappedInstruction  : byte_t;
    variable IsIllegalInstruction : boolean;
    variable IndexedIndirect    : boolean;
    variable IndexedMode        : integer;
    variable IndexedRegister    : integer;
    variable IsStore8           : boolean;
    variable Store8RegisterNum  : std_logic;
    variable IsStore16          : boolean;
    variable StoreRegisterNum   : integer;
    variable IsSpecialImmediate : boolean;
    variable ALU16Reg           : integer;
    variable ALU16OpWriteback   : boolean;
    variable ALU16Opcode        : integer;
    variable IsALU16Opcode      : boolean;
    variable ALU8Op             : integer;
    variable ALU8Writeback      : boolean;
    variable Is8BitInst         : boolean;
    variable IsTargetRegA       : boolean;
    variable AddrModeType       : integer;
    variable TakeBranch         : boolean;
    variable EXGTFRRegA         : word_t;
    variable EXGTFRRegB         : word_t;

    variable matched            : boolean;
    variable daa_sum            : unsigned(8 downto 0);
  begin
    -- Decode
    if GHOST_MODE then
      MappedInstruction := MapInstruction(D);
    else
      MappedInstruction := D;
    end if;
    IsIllegalInstruction := (not GHOST_MODE) and IllegalInstruction(Inst1);
    IndexDecode(Inst2, IndexedIndirect, IndexedMode, IndexedRegister);
    IsST8(Inst1, IsStore8, Store8RegisterNum);
    IsST16(Inst1, InstPage2, IsStore16, StoreRegisterNum);
    IsSpecialImmediate := IsSpecialImm(Inst1);
    ALU16Reg := ALU16RegFromInst(InstPage2, InstPage3, Inst1);
    ALU16OpFromInst(InstPage2, InstPage3, Inst1, ALU16OpWriteback, ALU16Opcode);
    IsALU16Opcode := (ALU16Opcode /= 7);
    ALU8Op := ALU8OpOf(Inst1);
    ALU8Writeback := ALU8WritebackOf(Inst1);
    Is8BitInst := ALU8BitOp(Inst1);
    IsTargetRegA := IsRegA(Inst1);
    AddrModeType := addressing_mode_type(Inst1);
    TakeBranch := take_branch(Inst1, cc);

    rLIC  := '0';
    rAVMA := '1';
    rBUSY := '0';

    addr_nxt := x"FFFF";
    pc_p1   := add16(pc, 1);
    pc_p2   := add16(pc, 2);
    pc_p3   := add16(pc, 3);
    s_p1    := add16(s, 1);
    s_m1    := sub16(s, 1);
    u_p1    := add16(u, 1);
    u_m1    := sub16(u, 1);
    addr_p1 := add16(addr_q, 1);
    ea_p1   := add16(ea, 1);
    BS_nxt  := '0';
    BA_nxt  := '0';

    EXGTFRRegA := EXGTFRRegister(to_integer(unsigned(D(7 downto 4))), a, b, x, y, u, s, pc_p1, dp, cc);
    EXGTFRRegB := EXGTFRRegister(to_integer(unsigned(D(3 downto 0))), a, b, x, y, u, s, pc_p1, dp, cc);

    -- By default the "next" version is the last latched version.
    IntType_nxt   := IntType;
    NMIClear_nxt  := NMIClear;
    NextState_nxt := NextState;
    a_nxt  := a;
    b_nxt  := b;
    x_nxt  := x;
    y_nxt  := y;
    s_nxt  := s;
    u_nxt  := u;
    cc_nxt := cc;
    dp_nxt := dp;
    pc_nxt := pc;
    tmp_nxt := tmp;
    ea_nxt  := ea;

    ALU_A  := x"00";
    ALU_B  := x"00";
    ALU_CC := x"00";
    ALU_OP := 0;

    ALU16_OP := 0;
    ALU16_A  := x"0000";
    ALU16_B  := x"0000";
    ALU16_CC := x"00";

    DOutput := x"00";
    RnWOut  := '1';     -- read

    Inst1_nxt := Inst1;
    Inst2_nxt := Inst2;
    Inst3_nxt := Inst3;
    InstPage2_nxt := InstPage2;
    InstPage3_nxt := InstPage3;

    CpuState_nxt := CpuState;

    case CpuState is

      when CPUSTATE_RESET =>
        addr_nxt := x"FFFF";
        a_nxt  := x"00";
        b_nxt  := x"00";
        x_nxt  := x"0000";
        y_nxt  := x"0000";
        s_nxt  := x"FFFD";      -- logic depends on the delta between s and s_nxt to clear NMIMask
        u_nxt  := x"0000";
        cc_nxt := CC_F or CC_I; -- reset disables interrupts
        dp_nxt := x"00";
        ea_nxt := x"FFFF";

        RnWOut := '1';
        rLIC   := '0';
        NMIClear_nxt := '0';
        IntType_nxt  := 7;
        rAVMA  := '1';
        CpuState_nxt := CPUSTATE_RESET0;

      when CPUSTATE_RESET0 =>
        addr_nxt := RESET_VECTOR;
        rBUSY := '1';
        pc_nxt(15 downto 8) := D;
        BS_nxt := '1';          -- ACK RESET
        rAVMA := '1';
        rLIC  := '1';
        CpuState_nxt := CPUSTATE_RESET2;

      when CPUSTATE_RESET2 =>
        addr_nxt := addr_p1;
        BS_nxt := '1';          -- ACK RESET
        pc_nxt(7 downto 0) := D;
        rAVMA := '1';
        rLIC  := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_FETCH_I1 =>
        if DMABREQLatched = '0' then
          addr_nxt := pc;
          RnWOut := '1';
          rAVMA  := '0';
          tmp_nxt := tmp(15 downto 4) & "1111";
          BS_nxt := '1';
          BA_nxt := '1';
          rLIC   := '1';
          CpuState_nxt := CPUSTATE_DMABREQ;
        elsif HALTLatched = '0' then
          addr_nxt := pc;
          RnWOut := '1';
          rAVMA  := '0';
          BS_nxt := '1';
          BA_nxt := '1';
          rLIC   := '1';
          CpuState_nxt := CPUSTATE_HALTED;
        else  -- not halting, run the inst byte fetch
          addr_nxt := pc;
          pc_nxt := pc_p1;
          RnWOut := '1';
          Inst1_nxt := MappedInstruction;
          InstPage2_nxt := '0';
          InstPage3_nxt := '0';

          -- New instruction fetch; service interrupts pending
          if NMILatched = '0' then
            pc_nxt := pc;
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_NMI_START;
          elsif FIRQLatched = '0' and cc(CC_F_BIT) = '0' then
            pc_nxt := pc;
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FIRQ_START;
          elsif IRQLatched = '0' and cc(CC_I_BIT) = '0' then
            pc_nxt := pc;
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_IRQ_START;

          -- The actual 1st byte checks
          elsif Inst1_nxt = x"10" then    -- Page 2
            InstPage2_nxt := '1';
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I1V2;
          elsif Inst1_nxt = x"11" then    -- Page 3
            InstPage3_nxt := '1';
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I1V2;
          else
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I2;
          end if;
        end if;

      when CPUSTATE_FETCH_I1V2 =>
        addr_nxt := pc;
        pc_nxt := pc_p1;
        RnWOut := '1';
        Inst1_nxt := MappedInstruction;

        if Inst1_nxt = x"10" then         -- Page 2
          if InstPage3 = '0' then
            InstPage2_nxt := '1';
          end if;
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1V2;
        elsif Inst1_nxt = x"11" then      -- Page 3
          if InstPage2 = '0' then
            InstPage3_nxt := '1';
          end if;
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1V2;
        else
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I2;
        end if;

      when CPUSTATE_FETCH_I2 =>
        addr_nxt := addr_p1;
        pc_nxt := pc_p1;
        Inst2_nxt := D;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

        if IsIllegalInstruction then      -- Skip illegal instructions
          rAVMA := '1';
          CpuState_nxt := IllegalInstructionState;
          rLIC := '1';
        else
          -- First byte decode for this stage
          case AddrModeType is

            when TYPE_INDEXED =>
              rAVMA := '1';
              CpuState_nxt := CPUSTATE_INDEXED_BASE;

            when TYPE_EXTENDED =>
              ea_nxt(15 downto 8) := Inst2_nxt;
              rAVMA := '1';
              CpuState_nxt := CPUSTATE_EXTENDED_ADDRLO;

            when TYPE_DIRECT =>
              ea_nxt := dp & Inst2_nxt;
              rAVMA := '0';
              CpuState_nxt := CPUSTATE_DIRECT_DONTCARE;

            when TYPE_INHERENT =>
              if Inst1 = OPCODE_INH_NOP then
                rLIC := '1';
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_FETCH_I1;
              elsif Inst1 = OPCODE_INH_DAA then       -- BCD lunacy
                if cc(CC_C_BIT) = '1' or unsigned(a(7 downto 4)) > 9 or
                   (unsigned(a(7 downto 4)) > 8 and unsigned(a(3 downto 0)) > 9) then
                  tmp_nxt(7 downto 4) := x"6";
                else
                  tmp_nxt(7 downto 4) := x"0";
                end if;

                if cc(CC_H_BIT) = '1' or unsigned(a(3 downto 0)) > 9 then
                  tmp_nxt(3 downto 0) := x"6";
                else
                  tmp_nxt(3 downto 0) := x"0";
                end if;

                -- DAA handles carry in the weirdest way: once set, it stays set
                daa_sum := ('0' & unsigned(a)) + unsigned(tmp_nxt(7 downto 0));
                tmp_nxt(8) := daa_sum(8);
                a_nxt := std_logic_vector(daa_sum(7 downto 0));

                cc_nxt(CC_C_BIT) := cc_nxt(CC_C_BIT) or tmp_nxt(8);

                cc_nxt(CC_N_BIT) := a_nxt(7);
                cc_nxt(CC_Z_BIT) := to_sl(a_nxt = x"00");
                rLIC := '1';
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_FETCH_I1;
              elsif Inst1 = OPCODE_INH_SYNC then
                CpuState_nxt := CPUSTATE_SYNC;
                rLIC := '1';
                rAVMA := '0';
              elsif Inst1 = OPCODE_INH_MUL then
                tmp_nxt := x"0000";
                ea_nxt(15 downto 8) := x"00";
                ea_nxt(7 downto 0) := a;
                a_nxt := x"08";
                rAVMA := '0';
                CpuState_nxt := CPUSTATE_MUL_ACTION;
              elsif Inst1 = OPCODE_INH_RTS then
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_RTS_HI;
              elsif Inst1 = OPCODE_INH_RTI then
                rAVMA := '1';
                tmp_nxt := x"1001";   -- tmp[12] marks an RTI, and at least pull CC
                CpuState_nxt := CPUSTATE_PUL_ACTION;
                NextState_nxt := CPUSTATE_FETCH_I1;
              elsif Inst1 = OPCODE_INH_SWI then
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_SWI_START;
              elsif Inst1 = OPCODE_INH_CWAI then
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_CWAI;
              elsif Inst1 = OPCODE_INH_SEX then
                a_nxt := (7 downto 0 => b(7));
                rLIC := '1';
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_FETCH_I1;
              elsif Inst1 = OPCODE_INH_ABX then
                x_nxt := std_logic_vector(unsigned(x) + unsigned(b));
                rAVMA := '0';
                CpuState_nxt := CPUSTATE_ABX_DONTCARE;
              else
                ALU_OP := ALU8Op;
                if IsTargetRegA then
                  ALU_A := a;
                else
                  ALU_A := b;
                end if;

                ALU_B  := x"00";
                ALU_CC := cc;
                ALU_R  := ALUInst(ALU_OP, ALU_A, ALU_B, ALU_CC);
                cc_nxt := ALU_R(15 downto 8);

                if ALU8Writeback then
                  if IsTargetRegA then
                    a_nxt := ALU_R(7 downto 0);
                  else
                    b_nxt := ALU_R(7 downto 0);
                  end if;
                end if;
                rLIC := '1';
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_FETCH_I1;
              end if;
              if IsOneByteInstruction(Inst1) then   -- the 6809 auto-reads 2 bytes per instruction
                pc_nxt := pc;
              end if;

            when TYPE_IMMEDIATE =>
              if IsSpecialImmediate then
                if Inst1 = OPCODE_IMM_ANDCC then
                  pc_nxt := pc_p1;
                  cc_nxt := cc and D;
                  rAVMA := '1';
                  CpuState_nxt := CPUSTATE_CC_DONTCARE;
                elsif Inst1 = OPCODE_IMM_ORCC then
                  pc_nxt := pc_p1;
                  cc_nxt := cc or D;
                  rAVMA := '1';
                  CpuState_nxt := CPUSTATE_CC_DONTCARE;
                elsif Inst1 = OPCODE_IMM_PSHS or Inst1 = OPCODE_IMM_PSHU then
                  pc_nxt := pc_p1;
                  tmp_nxt(15) := '0';
                  tmp_nxt(14) := Inst1(1);    -- save to U or S
                  tmp_nxt(13) := '0';         -- not pushing due to an interrupt
                  tmp_nxt(13 downto 8) := "000000";
                  tmp_nxt(7 downto 0) := Inst2_nxt;
                  rAVMA := '0';
                  CpuState_nxt := CPUSTATE_PSH_DONTCARE1;
                  NextState_nxt := CPUSTATE_FETCH_I1;
                elsif Inst1 = OPCODE_IMM_PULS or Inst1 = OPCODE_IMM_PULU then
                  pc_nxt := pc_p1;
                  tmp_nxt(15) := '0';
                  tmp_nxt(14) := Inst1(1);    -- S (0) or U (1) stack in use
                  tmp_nxt(13 downto 8) := "000000";
                  tmp_nxt(7 downto 0) := Inst2_nxt;
                  rAVMA := '0';
                  CpuState_nxt := CPUSTATE_PUL_DONTCARE1;
                  NextState_nxt := CPUSTATE_FETCH_I1;
                elsif Inst1 = OPCODE_IMM_TFR then
                  -- top nybble is reg #1, bottom is reg #2
                  case to_integer(unsigned(Inst2_nxt(3 downto 0))) is
                    when EXGTFR_REG_D  => a_nxt := EXGTFRRegA(15 downto 8); b_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_X  => x_nxt := EXGTFRRegA;
                    when EXGTFR_REG_Y  => y_nxt := EXGTFRRegA;
                    when EXGTFR_REG_U  => u_nxt := EXGTFRRegA;
                    when EXGTFR_REG_S  => s_nxt := EXGTFRRegA;
                    when EXGTFR_REG_PC => pc_nxt := EXGTFRRegA;
                    when EXGTFR_REG_DP => dp_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_A  => a_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_B  => b_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_CC => cc_nxt := EXGTFRRegA(7 downto 0);
                    when others => null;
                  end case;
                  rAVMA := '0';
                  CpuState_nxt := CPUSTATE_TFR_DONTCARE1;
                elsif Inst1 = OPCODE_IMM_EXG then
                  case to_integer(unsigned(Inst2_nxt(7 downto 4))) is
                    when EXGTFR_REG_D  => a_nxt := EXGTFRRegB(15 downto 8); b_nxt := EXGTFRRegB(7 downto 0);
                    when EXGTFR_REG_X  => x_nxt := EXGTFRRegB;
                    when EXGTFR_REG_Y  => y_nxt := EXGTFRRegB;
                    when EXGTFR_REG_U  => u_nxt := EXGTFRRegB;
                    when EXGTFR_REG_S  => s_nxt := EXGTFRRegB;
                    when EXGTFR_REG_PC => pc_nxt := EXGTFRRegB;
                    when EXGTFR_REG_DP => dp_nxt := EXGTFRRegB(7 downto 0);
                    when EXGTFR_REG_A  => a_nxt := EXGTFRRegB(7 downto 0);
                    when EXGTFR_REG_B  => b_nxt := EXGTFRRegB(7 downto 0);
                    when EXGTFR_REG_CC => cc_nxt := EXGTFRRegB(7 downto 0);
                    when others => null;
                  end case;
                  case to_integer(unsigned(Inst2_nxt(3 downto 0))) is
                    when EXGTFR_REG_D  => a_nxt := EXGTFRRegA(15 downto 8); b_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_X  => x_nxt := EXGTFRRegA;
                    when EXGTFR_REG_Y  => y_nxt := EXGTFRRegA;
                    when EXGTFR_REG_U  => u_nxt := EXGTFRRegA;
                    when EXGTFR_REG_S  => s_nxt := EXGTFRRegA;
                    when EXGTFR_REG_PC => pc_nxt := EXGTFRRegA;
                    when EXGTFR_REG_DP => dp_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_A  => a_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_B  => b_nxt := EXGTFRRegA(7 downto 0);
                    when EXGTFR_REG_CC => cc_nxt := EXGTFRRegA(7 downto 0);
                    when others => null;
                  end case;
                  rAVMA := '0';
                  CpuState_nxt := CPUSTATE_EXG_DONTCARE1;
                end if;

              -- Determine if this is an 8-bit ALU operation.
              elsif Is8BitInst then
                ALU_OP := ALU8Op;
                if IsTargetRegA then
                  ALU_A := a;
                else
                  ALU_A := b;
                end if;

                ALU_B  := Inst2_nxt;
                ALU_CC := cc;
                ALU_R  := ALUInst(ALU_OP, ALU_A, ALU_B, ALU_CC);
                cc_nxt := ALU_R(15 downto 8);

                if ALU8Writeback then
                  if IsTargetRegA then
                    a_nxt := ALU_R(7 downto 0);
                  else
                    b_nxt := ALU_R(7 downto 0);
                  end if;
                end if;
                rLIC := '1';
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_FETCH_I1;
              else            -- Then it must be a 16 bit instruction
                if IsALU16Opcode then
                  rAVMA := '1';
                  CpuState_nxt := CPUSTATE_16IMM_LO;
                end if;
              end if;

            when TYPE_RELATIVE =>
              -- If InstPage2 is set, it's a long branch; if clear, a normal branch.
              if InstPage2 = '1' or Inst1 = INST_LBRA or Inst1 = INST_LBSR then
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_LBRA_OFFSETLOW;
              else
                rAVMA := '0';
                CpuState_nxt := CPUSTATE_BRA_DONTCARE;
              end if;

            when others =>
              CpuState_nxt := CPUSTATE_FETCH_I1;
          end case;
        end if;

      when CPUSTATE_LBRA_OFFSETLOW =>
        addr_nxt := pc;
        pc_nxt := pc_p1;
        Inst3_nxt := D;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_LBRA_DONTCARE;

      when CPUSTATE_LBRA_DONTCARE =>
        addr_nxt := x"FFFF";
        if TakeBranch then
          rAVMA := '0';
          CpuState_nxt := CPUSTATE_LBRA_DONTCARE2;
        else
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        end if;

      when CPUSTATE_BRA_DONTCARE =>
        addr_nxt := x"FFFF";
        tmp_nxt := pc;
        if TakeBranch then
          pc_nxt := std_logic_vector(unsigned(pc) + unsigned(sext8(Inst2)));
          if Inst1 = INST_BSR then
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_BSR_DONTCARE1;
          else
            rLIC := '1';
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I1;
          end if;
        else
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        end if;

      when CPUSTATE_LBRA_DONTCARE2 =>
        tmp_nxt := pc;
        addr_nxt := x"FFFF";
        pc_nxt := std_logic_vector(unsigned(pc) + unsigned(Inst2 & Inst3));
        if Inst1 = INST_LBSR then
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_BSR_DONTCARE1;
        else
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        end if;

      when CPUSTATE_BSR_DONTCARE1 =>
        addr_nxt := pc;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_BSR_DONTCARE2;

      when CPUSTATE_BSR_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_BSR_RETURNLOW;

      when CPUSTATE_BSR_RETURNLOW =>
        addr_nxt := s_m1;
        s_nxt := s_m1;
        DOutput := tmp(7 downto 0);
        RnWOut := '0';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_BSR_RETURNHIGH;

      when CPUSTATE_BSR_RETURNHIGH =>
        addr_nxt := s_m1;
        s_nxt := s_m1;
        DOutput := tmp(15 downto 8);
        RnWOut := '0';
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_TFR_DONTCARE1 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_TFR_DONTCARE2;

      when CPUSTATE_TFR_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_TFR_DONTCARE3;

      when CPUSTATE_TFR_DONTCARE3 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_TFR_DONTCARE4;

      when CPUSTATE_TFR_DONTCARE4 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        rLIC := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_EXG_DONTCARE1 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_EXG_DONTCARE2;

      when CPUSTATE_EXG_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_EXG_DONTCARE3;

      when CPUSTATE_EXG_DONTCARE3 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_EXG_DONTCARE4;

      when CPUSTATE_EXG_DONTCARE4 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_EXG_DONTCARE5;

      when CPUSTATE_EXG_DONTCARE5 =>
        rAVMA := '0';
        addr_nxt := x"FFFF";
        CpuState_nxt := CPUSTATE_EXG_DONTCARE6;

      when CPUSTATE_EXG_DONTCARE6 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        rLIC := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_ABX_DONTCARE =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        rLIC := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_RTS_HI =>
        addr_nxt := s;
        s_nxt := s_p1;
        pc_nxt(15 downto 8) := D;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_RTS_LO;

      when CPUSTATE_RTS_LO =>
        addr_nxt := s;
        s_nxt := s_p1;
        pc_nxt(7 downto 0) := D;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_RTS_DONTCARE2;

      when CPUSTATE_RTS_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_16IMM_LO =>
        addr_nxt := pc;
        pc_nxt := pc_p1;

        ALU16_OP := ALU16Opcode;
        ALU16_CC := cc;
        ALU16_B  := Inst2 & D;

        case ALU16Reg is
          when ALU16_REG_X => ALU16_A := x;
          when ALU16_REG_D => ALU16_A := a & b;
          when ALU16_REG_Y => ALU16_A := y;
          when ALU16_REG_U => ALU16_A := u;
          when ALU16_REG_S => ALU16_A := s;
          when others      => ALU16_A := x"0000";
        end case;
        ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);

        if ALU16OpWriteback then
          case ALU16Reg is
            when ALU16_REG_X => cc_nxt := ALU16_R(23 downto 16); x_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_D => cc_nxt := ALU16_R(23 downto 16); a_nxt := ALU16_R(15 downto 8); b_nxt := ALU16_R(7 downto 0);
            when ALU16_REG_Y => cc_nxt := ALU16_R(23 downto 16); y_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_U => cc_nxt := ALU16_R(23 downto 16); u_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_S => cc_nxt := ALU16_R(23 downto 16); s_nxt := ALU16_R(15 downto 0);
            when others => null;
          end case;
        else
          cc_nxt := ALU16_R(23 downto 16);
        end if;

        if ALU16_OP = ALUOP16_LD then
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        else
          rAVMA := '0';
          CpuState_nxt := CPUSTATE_16IMM_DONTCARE;
        end if;

      when CPUSTATE_DIRECT_DONTCARE =>
        addr_nxt := x"FFFF";
        if IsJMP(Inst1) then
          pc_nxt := ea;
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        else
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_ALU_EA;
        end if;

      when CPUSTATE_ALU_EA =>
        -- Is Figure 18/5 Column 3?
        if IsALU8Set1(Inst1) then
          addr_nxt := ea;

          ALU_OP := ALU8Op;
          ALU_B  := D;
          ALU_CC := cc;

          if IsTargetRegA then
            ALU_A := a;
          else
            ALU_A := b;
          end if;

          ALU_R  := ALUInst(ALU_OP, ALU_A, ALU_B, ALU_CC);
          cc_nxt := ALU_R(15 downto 8);

          if ALU8Writeback then
            if IsTargetRegA then
              a_nxt := ALU_R(7 downto 0);
            else
              b_nxt := ALU_R(7 downto 0);
            end if;
          end if;

          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;

        -- Is Figure 18/5 Column 4? (Store, 8 bits)
        elsif IsStore8 then
          addr_nxt := ea;
          RnWOut := '0';    -- write

          ALU_OP := ALUOP_LD;   -- load has the same CC characteristics as store
          ALU_A  := x"00";
          ALU_CC := cc;

          if Store8RegisterNum = ST8_REG_A then
            DOutput := a;
            ALU_B := a;
          else
            DOutput := b;
            ALU_B := b;
          end if;

          ALU_R  := ALUInst(ALU_OP, ALU_A, ALU_B, ALU_CC);
          cc_nxt := ALU_R(15 downto 8);

          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;

        -- Is Figure 18/5 Column 5?  (Load, 16 bits)
        elsif IsALU16Opcode and ALU16Opcode = ALUOP16_LD then
          addr_nxt := ea;
          ea_nxt := ea_p1;

          case ALU16Reg is
            when ALU16_REG_X => x_nxt(15 downto 8) := D;
            when ALU16_REG_D => a_nxt := D;
            when ALU16_REG_Y => y_nxt(15 downto 8) := D;
            when ALU16_REG_S => s_nxt(15 downto 8) := D;
            when ALU16_REG_U => u_nxt(15 downto 8) := D;
            when others => null;
          end case;
          rAVMA := '1';
          rBUSY := '1';
          CpuState_nxt := CPUSTATE_LD16_LO;

        -- Is Figure 18/5 Column 6?  (Store, 16 bits)
        elsif IsStore16 then
          addr_nxt := ea;
          ea_nxt := ea_p1;

          ALU16_OP := ALUOP16_LD;   -- LD and ST have the same CC characteristics
          ALU16_CC := cc;
          ALU16_A  := x"0000";

          case StoreRegisterNum is
            when ST16_REG_X =>
              DOutput := x(15 downto 8);
              ALU16_B := x;
            when ST16_REG_Y =>
              DOutput := y(15 downto 8);
              ALU16_B := y;
            when ST16_REG_U =>
              DOutput := u(15 downto 8);
              ALU16_B := u;
            when ST16_REG_S =>
              DOutput := s(15 downto 8);
              ALU16_B := s;
            when ST16_REG_D =>
              DOutput := a;
              ALU16_B := a & b;
            when others => null;
          end case;

          ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
          cc_nxt := ALU16_R(23 downto 16);

          RnWOut := '0';        -- write
          rAVMA := '1';
          rBUSY := '1';
          CpuState_nxt := CPUSTATE_ST16_LO;

        -- Is Figure 18/5 Column 7?
        elsif IsALU8Set0(Inst1) then
          -- ASL, ASR, CLR, COM, DEC, INC, (LSL), LSR, NEG, ROL, ROR and TST (special!)
          -- Read, modify, write; there is a /VMA cycle between read and write.
          addr_nxt := ea;

          ALU_OP := ALU8Op;
          ALU_A  := D;
          ALU_CC := cc;
          ALU_R  := ALUInst(ALU_OP, ALU_A, ALU_B, ALU_CC);
          tmp_nxt(15 downto 8) := cc;  -- for debug only
          tmp_nxt(7 downto 0)  := ALU_R(7 downto 0);
          cc_nxt := ALU_R(15 downto 8);
          if ALU8Op = ALUOP_TST then
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_TST_DONTCARE1;
          else
            rAVMA := '0';
            rBUSY := '1';
            CpuState_nxt := CPUSTATE_ALU_DONTCARE;
          end if;

        -- Is Figure 18/5 Column 9?  (16-bit ALU ops, non-load)
        elsif IsALU16Opcode and ALU16Opcode /= ALUOP16_LD and
              (unsigned(Inst1) < 16#30# or unsigned(Inst1) > 16#33#) then   -- 30-33 = LEAX..LEAU
          addr_nxt := ea;
          ea_nxt := ea_p1;

          tmp_nxt(15 downto 8) := D;
          rAVMA := '1';
          rBUSY := '1';
          CpuState_nxt := CPUSTATE_ALU16_LO;

        -- Is Figure 18/5 Column 10?  JSR (not Immediate Mode)
        elsif Inst1 = x"9D" or Inst1 = x"AD" or Inst1 = x"BD" then
          pc_nxt := ea;
          addr_nxt := ea;
          tmp_nxt := pc;
          rAVMA := '0';
          CpuState_nxt := CPUSTATE_JSR_DONTCARE;

        -- Is Figure 18/5 Column 11?  LEA(X,Y,S,U)
        elsif unsigned(Inst1) >= 16#30# and unsigned(Inst1) <= 16#33# then
          addr_nxt := x"FFFF";

          ALU16_OP := ALU16Opcode;
          ALU16_CC := cc;
          ALU16_A  := ea;
          ALU16_R  := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);

          case ALU16Reg is
            when ALU16_REG_X => cc_nxt := ALU16_R(23 downto 16); x_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_Y => cc_nxt := ALU16_R(23 downto 16); y_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_U => u_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_S => s_nxt := ALU16_R(15 downto 0);
            when others => null;
          end case;

          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        end if;

      when CPUSTATE_ALU_DONTCARE =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        rBUSY := '1';
        CpuState_nxt := CPUSTATE_ALU_WRITEBACK;

      when CPUSTATE_ALU_WRITEBACK =>
        addr_nxt := ea;
        RnWOut := '0';    -- write
        DOutput := tmp(7 downto 0);
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_LD16_LO =>
        addr_nxt := ea;

        case ALU16Reg is
          when ALU16_REG_X =>
            x_nxt(7 downto 0) := D;
            ALU16_B(15 downto 8) := x(15 downto 8);
          when ALU16_REG_D =>
            b_nxt := D;
            ALU16_B(15 downto 8) := a;
          when ALU16_REG_Y =>
            y_nxt(7 downto 0) := D;
            ALU16_B(15 downto 8) := y(15 downto 8);
          when ALU16_REG_S =>
            s_nxt(7 downto 0) := D;
            ALU16_B(15 downto 8) := s(15 downto 8);
          when ALU16_REG_U =>
            u_nxt(7 downto 0) := D;
            ALU16_B(15 downto 8) := u(15 downto 8);
          when others => null;
        end case;

        ALU16_OP := ALU16Opcode;
        ALU16_CC := cc;
        ALU16_A  := x"0000";
        ALU16_B(7 downto 0) := D;
        ALU16_R  := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
        cc_nxt   := ALU16_R(23 downto 16);

        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_ST16_LO =>
        addr_nxt := ea;
        ea_nxt := ea_p1;
        case StoreRegisterNum is
          when ST16_REG_X => DOutput := x(7 downto 0);
          when ST16_REG_Y => DOutput := y(7 downto 0);
          when ST16_REG_U => DOutput := u(7 downto 0);
          when ST16_REG_S => DOutput := s(7 downto 0);
          when ST16_REG_D => DOutput := b;
          when others => null;
        end case;
        RnWOut := '0';        -- write

        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_ALU16_LO =>
        addr_nxt := ea;

        ALU16_OP := ALU16Opcode;
        ALU16_CC := cc;

        ALU16_B := tmp(15 downto 8) & D;

        case ALU16Reg is
          when ALU16_REG_X => ALU16_A := x;
          when ALU16_REG_D => ALU16_A := a & b;
          when ALU16_REG_Y => ALU16_A := y;
          when ALU16_REG_S => ALU16_A := s;
          when ALU16_REG_U => ALU16_A := u;
          when others      => ALU16_A := x"0000";
        end case;
        ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);

        if ALU16OpWriteback then
          case ALU16Reg is
            when ALU16_REG_X => cc_nxt := ALU16_R(23 downto 16); x_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_D => cc_nxt := ALU16_R(23 downto 16); a_nxt := ALU16_R(15 downto 8); b_nxt := ALU16_R(7 downto 0);
            when ALU16_REG_Y => cc_nxt := ALU16_R(23 downto 16); y_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_U => cc_nxt := ALU16_R(23 downto 16); u_nxt := ALU16_R(15 downto 0);
            when ALU16_REG_S => cc_nxt := ALU16_R(23 downto 16); s_nxt := ALU16_R(15 downto 0);
            when others => null;
          end case;
        else
          cc_nxt := ALU16_R(23 downto 16);
        end if;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_ALU16_DONTCARE;

      when CPUSTATE_ALU16_DONTCARE =>
        addr_nxt := x"FFFF";
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_JSR_DONTCARE =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_JSR_RETLO;

      when CPUSTATE_JSR_RETLO =>
        addr_nxt := s_m1;
        s_nxt := s_m1;
        RnWOut := '0';
        DOutput := tmp(7 downto 0);
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_JSR_RETHI;

      when CPUSTATE_JSR_RETHI =>
        addr_nxt := s_m1;
        s_nxt := s_m1;
        RnWOut := '0';
        DOutput := tmp(15 downto 8);
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_EXTENDED_ADDRLO =>
        addr_nxt := pc;
        pc_nxt := pc_p1;
        ea_nxt(7 downto 0) := D;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_EXTENDED_DONTCARE;

      when CPUSTATE_EXTENDED_DONTCARE =>
        addr_nxt := x"FFFF";
        if IsJMP(Inst1) then
          pc_nxt := ea;
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        else
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_ALU_EA;
        end if;

      when CPUSTATE_INDEXED_BASE =>
        addr_nxt := pc;

        Inst3_nxt := D;

        case IndexedRegister is
          when IDX_REG_X  => ALU16_A := x;
          when IDX_REG_Y  => ALU16_A := y;
          when IDX_REG_U  => ALU16_A := u;
          when IDX_REG_S  => ALU16_A := s;
          when IDX_REG_PC => ALU16_A := pc_p1;
          when others     => ALU16_A := x"0000";
        end case;
        ALU16_OP := ALUOP16_ADD;

        case IndexedMode is

          when IDX_MODE_NOOFFSET =>
            case IndexedRegister is
              when IDX_REG_X => ea_nxt := x;
              when IDX_REG_Y => ea_nxt := y;
              when IDX_REG_U => ea_nxt := u;
              when IDX_REG_S => ea_nxt := s;
              when others    => ea_nxt := x"0000";
            end case;

            if IndexedIndirect then
              rAVMA := '1';
              CpuState_nxt := CPUSTATE_INDIRECT_HI;
            else
              if IsJMP(Inst1) then
                pc_nxt := ea_nxt;
                rLIC := '1';
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_FETCH_I1;
              else
                rAVMA := '1';
                CpuState_nxt := CPUSTATE_ALU_EA;
              end if;
            end if;

          when IDX_MODE_5BIT_OFFSET =>
            -- The offset is the bottom 5 bits of the index postbyte, sign-extended
            ALU16_B := sext5(Inst2(4 downto 0));
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_R(15 downto 0);
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_DONTCARE3;

          when IDX_MODE_8BIT_OFFSET_PC | IDX_MODE_8BIT_OFFSET =>
            ALU16_B := sext8(D);
            pc_nxt := pc_p1;
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_R(15 downto 0);
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_DONTCARE3;

          when IDX_MODE_A_OFFSET =>
            ALU16_B := sext8(a);
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_DONTCARE3;
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_R(15 downto 0);

          when IDX_MODE_B_OFFSET =>
            ALU16_B := sext8(b);
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_DONTCARE3;
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_R(15 downto 0);

          when IDX_MODE_D_OFFSET =>
            ALU16_B := a & b;
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_R(15 downto 0);
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_IDX_DOFF_DONTCARE1;

          when IDX_MODE_POSTINC1 =>
            ALU16_B := x"0001";
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_A;
            case IndexedRegister is
              when IDX_REG_X => x_nxt := ALU16_R(15 downto 0);
              when IDX_REG_Y => y_nxt := ALU16_R(15 downto 0);
              when IDX_REG_U => u_nxt := ALU16_R(15 downto 0);
              when IDX_REG_S => s_nxt := ALU16_R(15 downto 0);
              when others => null;
            end case;
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE2;

          when IDX_MODE_POSTINC2 =>
            ALU16_B := x"0002";
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            ea_nxt := ALU16_A;
            case IndexedRegister is
              when IDX_REG_X => x_nxt := ALU16_R(15 downto 0);
              when IDX_REG_Y => y_nxt := ALU16_R(15 downto 0);
              when IDX_REG_U => u_nxt := ALU16_R(15 downto 0);
              when IDX_REG_S => s_nxt := ALU16_R(15 downto 0);
              when others => null;
            end case;
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE0;

          when IDX_MODE_PREDEC1 =>
            ALU16_B := x"FFFF";     -- -1
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            case IndexedRegister is
              when IDX_REG_X => x_nxt := ALU16_R(15 downto 0);
              when IDX_REG_Y => y_nxt := ALU16_R(15 downto 0);
              when IDX_REG_U => u_nxt := ALU16_R(15 downto 0);
              when IDX_REG_S => s_nxt := ALU16_R(15 downto 0);
              when others => null;
            end case;
            ea_nxt := ALU16_R(15 downto 0);
            rAVMA := '0';
            CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE2;

          when IDX_MODE_PREDEC2 =>
            ALU16_B := x"FFFE";     -- -2
            ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
            case IndexedRegister is
              when IDX_REG_X => x_nxt := ALU16_R(15 downto 0);
              when IDX_REG_Y => y_nxt := ALU16_R(15 downto 0);
              when IDX_REG_U => u_nxt := ALU16_R(15 downto 0);
              when IDX_REG_S => s_nxt := ALU16_R(15 downto 0);
              when others => null;
            end case;
            ea_nxt := ALU16_R(15 downto 0);
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE0;

          when IDX_MODE_16BIT_OFFSET_PC | IDX_MODE_16BIT_OFFSET =>
            tmp_nxt(15 downto 8) := D;
            pc_nxt := pc_p1;
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_IDX_16OFFSET_LO;

          when IDX_MODE_EXTENDED_INDIRECT =>
            ea_nxt(15 downto 8) := D;
            pc_nxt := pc_p1;
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_IDX_EXTIND_LO;

          when others =>
            rLIC := '1';
            CpuState_nxt := PostIllegalState;

        end case;

      when CPUSTATE_IDX_OFFSET_LO =>
        tmp_nxt(7 downto 0) := D;
        addr_nxt := pc;
        pc_nxt := pc_p1;
        ALU16_B := tmp_nxt;

        case IndexedRegister is
          when IDX_REG_X  => ALU16_A := x;
          when IDX_REG_Y  => ALU16_A := y;
          when IDX_REG_U  => ALU16_A := u;
          when IDX_REG_S  => ALU16_A := s;
          when IDX_REG_PC => ALU16_A := pc;
          when others     => ALU16_A := x"0000";
        end case;
        ALU16_OP := ALUOP16_ADD;

        ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
        ea_nxt := ALU16_R(15 downto 0);
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE1;

      when CPUSTATE_IDX_DONTCARE3 =>
        addr_nxt := x"FFFF";
        if IndexedIndirect then
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_INDIRECT_HI;
        else
          if IsJMP(Inst1) then
            pc_nxt := ea;
            rLIC := '1';
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I1;
          else
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_ALU_EA;
          end if;
        end if;

      when CPUSTATE_IDX_16OFFSET_LO =>
        addr_nxt := pc;
        pc_nxt := pc_p1;

        case IndexedRegister is
          when IDX_REG_X  => ALU16_A := x;
          when IDX_REG_Y  => ALU16_A := y;
          when IDX_REG_U  => ALU16_A := u;
          when IDX_REG_S  => ALU16_A := s;
          when IDX_REG_PC => ALU16_A := pc_nxt;   -- tricky; not part of the actual pattern
          when others     => ALU16_A := x;        -- default to something
        end case;

        ALU16_OP := ALUOP16_ADD;

        ALU16_B := tmp(15 downto 8) & D;

        ALU16_R := ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);
        ea_nxt := ALU16_R(15 downto 0);
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE1;

      when CPUSTATE_IDX_16OFF_DONTCARE1 =>
        addr_nxt := pc;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE2;

      when CPUSTATE_IDX_16OFF_DONTCARE0 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE2;

      when CPUSTATE_IDX_16OFF_DONTCARE2 =>
        addr_nxt := x"FFFF";
        if IndexedRegister = IDX_REG_PC then
          rAVMA := '0';
          CpuState_nxt := CPUSTATE_IDX_PC16OFF_DONTCARE;
        else
          rAVMA := '0';
          CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE3;
        end if;

      when CPUSTATE_IDX_PC16OFF_DONTCARE =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE3;

      when CPUSTATE_IDX_16OFF_DONTCARE3 =>
        addr_nxt := x"FFFF";
        if IndexedIndirect then
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_INDIRECT_HI;
        else
          if IsJMP(Inst1) then
            pc_nxt := ea;
            rLIC := '1';
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I1;
          else
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_ALU_EA;
          end if;
        end if;

      when CPUSTATE_IDX_DOFF_DONTCARE1 =>
        addr_nxt := pc_p1;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IDX_DOFF_DONTCARE2;

      when CPUSTATE_IDX_DOFF_DONTCARE2 =>
        addr_nxt := pc_p2;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_IDX_16OFF_DONTCARE2;

      when CPUSTATE_IDX_DOFF_DONTCARE3 =>
        addr_nxt := pc_p3;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IDX_DOFF_DONTCARE2;

      when CPUSTATE_IDX_EXTIND_LO =>
        ea_nxt(7 downto 0) := D;
        addr_nxt := pc;
        pc_nxt := pc_p1;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IDX_EXTIND_DONTCARE;

      when CPUSTATE_IDX_EXTIND_DONTCARE =>
        addr_nxt := pc;
        if IndexedIndirect then
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_INDIRECT_HI;
        else
          if IsJMP(Inst1) then
            pc_nxt := ea;
            rLIC := '1';
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_FETCH_I1;
          else
            rAVMA := '1';
            CpuState_nxt := CPUSTATE_ALU_EA;
          end if;
        end if;

      when CPUSTATE_INDIRECT_HI =>
        addr_nxt := ea;
        tmp_nxt(15 downto 8) := D;
        rAVMA := '1';
        rBUSY := '1';
        CpuState_nxt := CPUSTATE_INDIRECT_LO;

      when CPUSTATE_INDIRECT_LO =>
        addr_nxt := ea_p1;
        ea_nxt(15 downto 8) := tmp_nxt(15 downto 8);
        ea_nxt(7 downto 0) := D;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_INDIRECT_DONTCARE;

      when CPUSTATE_INDIRECT_DONTCARE =>
        addr_nxt := x"FFFF";
        if IsJMP(Inst1) then
          pc_nxt := ea;
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        else
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_ALU_EA;
        end if;

      when CPUSTATE_MUL_ACTION =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        -- tmp = result, ea = additor (the shifted multiplicand),
        -- a = counter, b is the multiplier (which gets shifted right)
        if a /= x"00" then
          if b(0) = '1' then
            tmp_nxt := std_logic_vector(unsigned(tmp) + unsigned(ea));
          end if;
          ea_nxt := ea(14 downto 0) & '0';
          b_nxt  := '0' & b(7 downto 1);
          a_nxt  := std_logic_vector(unsigned(a) - 1);
        else
          a_nxt := tmp(15 downto 8);
          b_nxt := tmp(7 downto 0);

          cc_nxt(CC_Z_BIT) := to_sl(tmp = x"0000");
          cc_nxt(CC_C_BIT) := tmp(7);
          rLIC := '1';
          rAVMA := '1';
          CpuState_nxt := CPUSTATE_FETCH_I1;
        end if;

      when CPUSTATE_PSH_DONTCARE1 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_PSH_DONTCARE2;

      when CPUSTATE_PSH_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_PSH_DONTCARE3;

      when CPUSTATE_PSH_DONTCARE3 =>
        if Inst1(1) = '1' then
          addr_nxt := u;
        else
          addr_nxt := s;
        end if;
        CpuState_nxt := CPUSTATE_PSH_ACTION;

      when CPUSTATE_PSH_ACTION =>
        rAVMA := '1';
        matched := true;
        if tmp(7) = '1' and tmp(15) = '0' then                  -- PC_LO
          DOutput := pc(7 downto 0);
          tmp_nxt(15) := '1';
        elsif tmp(7) = '1' and tmp(15) = '1' then               -- PC_HI
          DOutput := pc(15 downto 8);
          tmp_nxt(7) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(6) = '1' and tmp(15) = '0' then               -- U/S_LO
          if tmp(14) = '1' then
            DOutput := s(7 downto 0);
          else
            DOutput := u(7 downto 0);
          end if;
          tmp_nxt(15) := '1';
        elsif tmp(6) = '1' and tmp(15) = '1' then               -- U/S_HI
          if tmp(14) = '1' then
            DOutput := s(15 downto 8);
          else
            DOutput := u(15 downto 8);
          end if;
          tmp_nxt(6) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(5) = '1' and tmp(15) = '0' then               -- Y_LO
          DOutput := y(7 downto 0);
          tmp_nxt(15) := '1';
        elsif tmp(5) = '1' and tmp(15) = '1' then               -- Y_HI
          DOutput := y(15 downto 8);
          tmp_nxt(5) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(4) = '1' and tmp(15) = '0' then               -- X_LO
          DOutput := x(7 downto 0);
          tmp_nxt(15) := '1';
        elsif tmp(4) = '1' and tmp(15) = '1' then               -- X_HI
          DOutput := x(15 downto 8);
          tmp_nxt(4) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(3) = '1' then                                 -- DP
          DOutput := dp;
          tmp_nxt(3) := '0';
        elsif tmp(2) = '1' then                                 -- B
          DOutput := b;
          tmp_nxt(2) := '0';
        elsif tmp(1) = '1' then                                 -- A
          DOutput := a;
          tmp_nxt(1) := '0';
        elsif tmp(0) = '1' then                                 -- CC
          DOutput := cc;
          tmp_nxt(0) := '0';
        else
          matched := false;
        end if;

        if matched then
          if tmp(14) = '1' then
            addr_nxt := u_m1;
            u_nxt := u_m1;
          else
            addr_nxt := s_m1;
            s_nxt := s_m1;
          end if;
          RnWOut := '0';  -- write
        end if;

        if tmp(13) = '1' then   -- pushing for an IRQ, LIC is supposed to be set
          rLIC := '1';
        end if;
        if tmp_nxt(7 downto 0) = x"00" then
          if NextState = CPUSTATE_FETCH_I1 then
            rAVMA := '1';
            rLIC := '1';
          else
            rAVMA := '0';
          end if;
          CpuState_nxt := NextState;
        end if;

      when CPUSTATE_PUL_DONTCARE1 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_PUL_DONTCARE2;

      when CPUSTATE_PUL_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_PUL_ACTION;

      when CPUSTATE_PUL_ACTION =>
        rAVMA := '1';
        matched := true;
        if tmp(0) = '1' then                                    -- CC
          cc_nxt := D;
          if tmp(12) = '1' then
            -- Pull from an RTI: the E flag of the retrieved CC says what else to pull
            if D(CC_E_BIT) = '1' then
              tmp_nxt(7 downto 0) := x"FE";   -- retrieve all registers (CC already retrieved)
            else
              tmp_nxt(7 downto 0) := x"80";   -- retrieve PC and CC (CC already retrieved)
            end if;
          else
            tmp_nxt(0) := '0';
          end if;
        elsif tmp(1) = '1' then                                 -- A
          a_nxt := D;
          tmp_nxt(1) := '0';
        elsif tmp(2) = '1' then                                 -- B
          b_nxt := D;
          tmp_nxt(2) := '0';
        elsif tmp(3) = '1' then                                 -- DP
          dp_nxt := D;
          tmp_nxt(3) := '0';
        elsif tmp(4) = '1' and tmp(15) = '0' then               -- X_HI
          x_nxt(15 downto 8) := D;
          tmp_nxt(15) := '1';
        elsif tmp(4) = '1' and tmp(15) = '1' then               -- X_LO
          x_nxt(7 downto 0) := D;
          tmp_nxt(4) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(5) = '1' and tmp(15) = '0' then               -- Y_HI
          y_nxt(15 downto 8) := D;
          tmp_nxt(15) := '1';
        elsif tmp(5) = '1' and tmp(15) = '1' then               -- Y_LO
          y_nxt(7 downto 0) := D;
          tmp_nxt(5) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(6) = '1' and tmp(15) = '0' then               -- U/S_HI
          if tmp(14) = '1' then
            s_nxt(15 downto 8) := D;
          else
            u_nxt(15 downto 8) := D;
          end if;
          tmp_nxt(15) := '1';
        elsif tmp(6) = '1' and tmp(15) = '1' then               -- U/S_LO
          if tmp(14) = '1' then
            s_nxt(7 downto 0) := D;
          else
            u_nxt(7 downto 0) := D;
          end if;
          tmp_nxt(6) := '0';
          tmp_nxt(15) := '0';
        elsif tmp(7) = '1' and tmp(15) = '0' then               -- PC_HI
          pc_nxt(15 downto 8) := D;
          tmp_nxt(15) := '1';
        elsif tmp(7) = '1' and tmp(15) = '1' then               -- PC_LO
          pc_nxt(7 downto 0) := D;
          tmp_nxt(7) := '0';
          tmp_nxt(15) := '0';
        else
          matched := false;
        end if;

        if matched then
          if tmp(14) = '1' then
            addr_nxt := u;
            u_nxt := u_p1;
          else
            addr_nxt := s;
            s_nxt := s_p1;
          end if;
        else
          if tmp(14) = '1' then
            addr_nxt := u;
          else
            addr_nxt := s;
          end if;
          if NextState = CPUSTATE_FETCH_I1 then
            rAVMA := '1';
            rLIC := '1';
          else
            rAVMA := '0';
          end if;
          CpuState_nxt := NextState;
        end if;

      when CPUSTATE_NMI_START =>
        NMIClear_nxt := '1';
        addr_nxt := pc;
        -- tmp stands as the bits to push to the stack
        tmp_nxt := x"20FF";   -- save to the S stack: PC, U, Y, X, DP, B, A, CC; set LIC on every push
        NextState_nxt := CPUSTATE_IRQ_DONTCARE2;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_IRQ_DONTCARE;
        IntType_nxt := INTTYPE_NMI;
        cc_nxt(CC_E_BIT) := '1';

      when CPUSTATE_IRQ_START =>
        addr_nxt := pc;
        tmp_nxt := x"20FF";
        NextState_nxt := CPUSTATE_IRQ_DONTCARE2;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IRQ_DONTCARE;
        IntType_nxt := INTTYPE_IRQ;
        cc_nxt(CC_E_BIT) := '1';

      when CPUSTATE_FIRQ_START =>
        addr_nxt := pc;
        tmp_nxt := x"2081";   -- save to the S stack: PC, CC; set LIC on every push
        NextState_nxt := CPUSTATE_IRQ_DONTCARE2;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IRQ_DONTCARE;
        IntType_nxt := INTTYPE_FIRQ;
        cc_nxt(CC_E_BIT) := '0';

      when CPUSTATE_SWI_START =>
        addr_nxt := pc;
        tmp_nxt := x"00FF";   -- save to the S stack: PC, U, Y, X, DP, B, A, CC

        NextState_nxt := CPUSTATE_IRQ_DONTCARE2;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IRQ_DONTCARE;
        if InstPage3 = '1' then
          IntType_nxt := INTTYPE_SWI3;
        end if;
        if InstPage2 = '1' then
          IntType_nxt := INTTYPE_SWI2;
        else
          IntType_nxt := INTTYPE_SWI;
        end if;

        cc_nxt(CC_E_BIT) := '1';

      when CPUSTATE_IRQ_DONTCARE =>
        NMIClear_nxt := '0';
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_PSH_ACTION;

      when CPUSTATE_IRQ_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_IRQ_VECTOR_HI;
        rLIC := '1';

      when CPUSTATE_IRQ_VECTOR_HI =>
        case IntType is
          when INTTYPE_NMI =>
            addr_nxt := NMI_VECTOR;
            BS_nxt := '1';    -- ACK interrupt
          when INTTYPE_SWI =>
            addr_nxt := SWI_VECTOR;
          when INTTYPE_FIRQ =>
            addr_nxt := FIRQ_VECTOR;
            BS_nxt := '1';
          when INTTYPE_SWI2 =>
            addr_nxt := SWI2_VECTOR;
          when INTTYPE_SWI3 =>
            addr_nxt := SWI3_VECTOR;
          when others =>      -- INTTYPE_IRQ and the default, which should never happen
            addr_nxt := IRQ_VECTOR;
            BS_nxt := '1';
        end case;

        pc_nxt(15 downto 8) := D;
        rAVMA := '1';
        rBUSY := '1';
        rLIC := '1';
        CpuState_nxt := CPUSTATE_IRQ_VECTOR_LO;

      when CPUSTATE_IRQ_VECTOR_LO =>
        case IntType is
          when INTTYPE_NMI =>
            addr_nxt := add16(NMI_VECTOR, 1);
            cc_nxt(CC_I_BIT) := '1';
            cc_nxt(CC_F_BIT) := '1';
            BS_nxt := '1';
          when INTTYPE_IRQ =>
            addr_nxt := add16(IRQ_VECTOR, 1);
            cc_nxt(CC_I_BIT) := '1';
            BS_nxt := '1';
          when INTTYPE_SWI =>
            addr_nxt := add16(SWI_VECTOR, 1);
            cc_nxt(CC_F_BIT) := '1';
            cc_nxt(CC_I_BIT) := '1';
            rLIC := '1';
          when INTTYPE_FIRQ =>
            addr_nxt := add16(FIRQ_VECTOR, 1);
            cc_nxt(CC_F_BIT) := '1';
            cc_nxt(CC_I_BIT) := '1';
            BS_nxt := '1';
          when INTTYPE_SWI2 =>
            addr_nxt := add16(SWI2_VECTOR, 1);
            rLIC := '1';
          when INTTYPE_SWI3 =>
            addr_nxt := add16(SWI3_VECTOR, 1);
            rLIC := '1';
          when others => null;
        end case;

        pc_nxt(7 downto 0) := D;
        rAVMA := '1';
        rLIC := '1';
        CpuState_nxt := CPUSTATE_INT_DONTCARE;

      when CPUSTATE_INT_DONTCARE =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        rLIC := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_CC_DONTCARE =>
        addr_nxt := pc;
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_TST_DONTCARE1 =>
        addr_nxt := x"FFFF";
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_TST_DONTCARE2;

      when CPUSTATE_TST_DONTCARE2 =>
        addr_nxt := x"FFFF";
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_DEBUG =>
        addr_nxt := tmp;
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_16IMM_DONTCARE =>
        addr_nxt := x"FFFF";
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_SYNC =>
        addr_nxt := x"FFFF";
        BA_nxt := '1';
        rLIC := '1';
        rAVMA := '0';

        if (NMILatched and FIRQLatched and IRQLatched) = '0' then
          CpuState_nxt := CPUSTATE_SYNC_EXIT;
        end if;

      when CPUSTATE_SYNC_EXIT =>
        addr_nxt := x"FFFF";
        BA_nxt := '1';
        rLIC := '1';
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_DMABREQ =>
        rAVMA := '0';
        addr_nxt := x"FFFF";
        BS_nxt := '1';
        BA_nxt := '1';
        rLIC := '1';
        tmp_nxt(3 downto 0) := std_logic_vector(unsigned(tmp(3 downto 0)) - 1);
        if tmp(3 downto 0) = x"0" or DMABREQSample2 = '1' then
          CpuState_nxt := CPUSTATE_DMABREQ_EXIT;
        end if;

      when CPUSTATE_DMABREQ_EXIT =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_HALTED =>
        rAVMA := '0';
        addr_nxt := x"FFFF";
        BS_nxt := '1';
        BA_nxt := '1';
        rLIC := '1';
        if HALTSample2 = '1' then
          CpuState_nxt := CPUSTATE_HALT_EXIT2;
        end if;

      when CPUSTATE_HALT_EXIT2 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_FETCH_I1;

      when CPUSTATE_STOP =>
        addr_nxt := x"DEAD";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_STOP2;

      when CPUSTATE_STOP2 =>
        addr_nxt := pc;
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_STOP3;

      when CPUSTATE_STOP3 =>
        addr_nxt := x"0000";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_STOP;

      -- CWAI waits with /VMA cycles on the bus until an interrupt occurs
      when CPUSTATE_CWAI =>
        addr_nxt := pc;
        cc_nxt := '1' & (cc(6 downto 0) and Inst2(6 downto 0));  -- set E flag, AND CC with CWAI argument
        tmp_nxt := x"00FF";   -- save to the S stack: PC, U, Y, X, DP, B, A, CC

        NextState_nxt := CPUSTATE_CWAI_POST;
        rAVMA := '0';
        CpuState_nxt := CPUSTATE_CWAI_DONTCARE1;

      when CPUSTATE_CWAI_DONTCARE1 =>
        addr_nxt := x"FFFF";
        rAVMA := '1';
        CpuState_nxt := CPUSTATE_PSH_ACTION;

      when CPUSTATE_CWAI_POST =>
        addr_nxt := x"FFFF";
        rAVMA := '0';

        CpuState_nxt := CPUSTATE_CWAI_POST;

        -- Wait for an interrupt
        if NMILatched = '0' then
          rAVMA := '1';
          IntType_nxt := INTTYPE_NMI;
          cc_nxt(CC_F_BIT) := '1';
          cc_nxt(CC_I_BIT) := '1';
          CpuState_nxt := CPUSTATE_IRQ_VECTOR_HI;
        elsif FIRQLatched = '0' and cc(CC_F_BIT) = '0' then
          rAVMA := '1';
          cc_nxt(CC_F_BIT) := '1';
          cc_nxt(CC_I_BIT) := '1';
          IntType_nxt := INTTYPE_FIRQ;
          CpuState_nxt := CPUSTATE_IRQ_VECTOR_HI;
        elsif IRQLatched = '0' and cc(CC_I_BIT) = '0' then
          rAVMA := '1';
          cc_nxt(CC_I_BIT) := '1';
          IntType_nxt := INTTYPE_IRQ;
          CpuState_nxt := CPUSTATE_IRQ_VECTOR_HI;
        end if;

      when others =>
        CpuState_nxt := PostIllegalState;

    end case;

    -- Hand the results to the latching process and the output ports
    a_nxt_s  <= a_nxt;
    b_nxt_s  <= b_nxt;
    x_nxt_s  <= x_nxt;
    y_nxt_s  <= y_nxt;
    u_nxt_s  <= u_nxt;
    s_nxt_s  <= s_nxt;
    cc_nxt_s <= cc_nxt;
    dp_nxt_s <= dp_nxt;
    pc_nxt_s <= pc_nxt;
    tmp_nxt_s <= tmp_nxt;
    ea_nxt_s  <= ea_nxt;
    addr_nxt_s <= addr_nxt;
    InstPage2_nxt_s <= InstPage2_nxt;
    InstPage3_nxt_s <= InstPage3_nxt;
    Inst1_nxt_s <= Inst1_nxt;
    Inst2_nxt_s <= Inst2_nxt;
    Inst3_nxt_s <= Inst3_nxt;
    NMIClear_nxt_s <= NMIClear_nxt;
    IntType_nxt_s  <= IntType_nxt;
    NextState_nxt_s <= NextState_nxt;
    CpuState_nxt_s  <= CpuState_nxt;

    ADDR <= addr_nxt;
    DOut <= DOutput;
    RnW  <= RnWOut;
    BS   <= BS_nxt;
    BA   <= BA_nxt;
    LIC  <= rLIC;
    AVMA <= rAVMA;
    BUSY <= rBUSY;
  end process;

end rtl;
