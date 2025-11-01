const std = @import( "std" );
const def = @import( "defs" );

// =========================== PROCESS FLAGS ( PFLG ) ===========================

pub const e_PFlagTrit = enum( u4 )
{
  F_SN = 0, // what the last ALU/CMP op returned                      ( -/0/+ ) sign flag
  F_CR = 1, // if the last ALU op had a carry                         (  -/+  ) carry flag           ( add )
  F_BR = 2, // if the last ALU op had a borrow                        (  -/+  ) borrow flag          ( sub )
  F_FL = 3, // if the last ALU op under- or over-flowed               (  -/+  ) over/under flow flag ( add, sub. mul )
  F_OR = 4, // wether the last opcond was false, skipped or true      ( -/0/+ ) opcond result flag
  F_OM = 5, // how to modify the next opcond ( inv, skip )            (  -/+  ) opcond modifier flag
  F_IS = 6, // when to auto-inter. ( on step, never, on jmp )         ( -/0/+ ) interupt-on-step flag
  F_ST = 7, // if the process is quiting, running or pausing          ( -/0/+ ) process state flag   TODO : check if useless ?
  F_IP = 8, // if the process can inter. itself( via SYS, no, yes )   ( -/0/+ ) interupt permissions
};

// =========================== PUM MEMORY LAYOUT ===========================
// processing unit memory ( page 0 ) : 19_683 Trytes

// NOTE : CONTEXT = PRG + PCR

// ========= PRG : process registers =========

pub const e_PRegTryte = enum( u4 ) // TODO : add more work regs ?
{
  PREG = 0, // process reg.    : process output register
  PADR = 1, // process adr.    : where the process pointer is currently at
  PFLG = 2, // process flags   : ( see above for list )
  PSTK = 3, // process stack   : adr. to top of currently used call stack ( delimited by nulls )
  MSEG = 4, // RAM segment     : upper half of any RAM adressing ( page / sector HADR )
//???? = 5, // ?               :
//???? = 6, // ?               :
  STEP = 7, // step counter    : how many steps since process launched
  OLEN = 8, // cur. op. lenght : number of args the current ops has
};

// ========= PCR : cache registers =========

// 9-81 => cache registers.  : 72 Trytes

// ========= PAR : auxiliary registers =========

// ?-?   => I/O mapping reg.

// ?-?   => boot   protocol : what to do on computer open
// ?-?   => close  protocol : what to do on computer close

// ?-?   => launch protocol : what to do on program start
// ?-?   => exit   protocol : what to do on program stop

// ?-?   => resume protocol : what to do on program resumes  ( interupt context switching )
// ?-?   => pause  protocol : what to do on program pause    ( interupt context switching )

// NOTE : potential protocols
// SYS_RSTRT ( restart computer )
// SYS_SLEEP ( yield for X cycles )
// SYS_IO    ( perform I/O on device )
// SYS_LOAD  ( load another process into RAM )
// SYS_FORK  ( duplicate current context )
// SYS_ALLOC ( memory allocation )
// SYS_GET   ( ead system flag )

// ========= PSR : stack registers =========

// ?-end => process stack(s) : size = 9 * MAX_RECURSIVITY ( stores full PPR context )

// =========================== RAM MEMORY LAYOUT ===========================
// random access memory : 387_420_489 ( 19_683^2 ) Trytes

// NOTE : when addressing, uses the MSEG as the address' uper half ( lower half is arg )

// 0-? => general memory
// ?-? => audio   memory   : 1 sec of soundwaves
// ?-? => video   memory   : 2x max resolution


// =========================== OPCODES ===========================

// ========= NOMENCLATURE =========
// A, B, C : arg1/2/3
//  arg    : mandatory arg
// *arg    : optional arg ( can be zero and wont do anything  )
// .adr    : arg as an address
// .var    : value at arg's address
// .stk    : entire stack at address
//
//     B-
//     | B0
//     | | B+
//  A- t t t   // NOTE : truth table layout
//  A0 t t t
//  A+ t t t

pub const e_OpCode = enum( u18 ) // represents t9 Tryte
{

  // OP SUBMASKS
  pub const _IAS_ : u18 = 0b11_00_00_00_00_00_00_00_00; // input  adress space
  pub const _OAS_ : u18 = 0b00_11_00_00_00_00_00_00_00; // output adress space
  pub const _EXC_ : u18 = 0b00_00_00_00_00_00_00_11_11; // execution conditions

  pub const _OPN_ : u18 = 0b00_00_11_11_11_11_11_00_00; // operation names ( types & codes )
  pub const _OPT_ : u18 = 0b00_00_11_11_00_00_00_00_00; // operation types
  pub const _OPC_ : u18 = 0b00_00_00_00_11_11_11_00_00; // operation codes

  // ========= OPERATION MODIFIERS =========

  // INPUT SPACE  |
  pub const I_VL  : u18 = 0b00_00_00_00_00_00_00_00_00; // raw values   ( in-place ops stored in prog. as static val. )
  pub const I_AD  : u18 = 0b01_00_00_00_00_00_00_00_00; // RAM adresses ( upper half of the address in MSEG )
  pub const I_RA  : u18 = 0b10_00_00_00_00_00_00_00_00; // RAM adresses ( relative to current PADR.var, signed )

  // OUTPUT SPACE | always outputs to PREG as well
  pub const O_VL  : u18 = 0b00_00_00_00_00_00_00_00_00; // raw values   ( in-place ops stored in prog. as static val. )
  pub const O_AD  : u18 = 0b00_01_00_00_00_00_00_00_00; // RAM adresses ( upper half of the address in MSEG )
  pub const O_RA  : u18 = 0b00_10_00_00_00_00_00_00_00; // RAM adresses ( relative to current PADR.var, signed )

  // OP CONDITION | only execute opcode if :
  pub const C_ALW : u18 = 0b00_00_00_00_00_00_00_00_00; // always, unconditionally
  pub const C_IFC : u18 = 0b00_00_00_00_00_00_00_00_01; // if F_CR or F_BR != 0
  pub const C_IFF : u18 = 0b00_00_00_00_00_00_00_00_10; // if F_FL != 0

  pub const C_IFZ : u18 = 0b00_00_00_00_00_00_00_01_00; // if F_SN != 0
  pub const C_IFP : u18 = 0b00_00_00_00_00_00_00_01_01; // if F_SN != +
  pub const C_IFN : u18 = 0b00_00_00_00_00_00_00_01_10; // if F_SN != -

  pub const C_INV : u18 = 0b00_00_00_00_00_00_00_10_00; // set F_SK to - to invert the next condition check's result
  pub const C_SKP : u18 = 0b00_00_00_00_00_00_00_10_01; // set F_SK to + to avoid the next condition check ( acts like C_ALW  )
//C_XXX = 0b00_00_00_00_00_00_00_10_10,


  // ========= OPERATION NAMES ( TYPE & CODE ) =========

  // SYSTEM OPS          2T ( 1 arg ) |

  NOP   = 0b00_00_00_00_00_00_00_00_00, // do nothing ( TODO : nothing * A.var )
//XXX   = 0b00_00_00_00_00_00_01_00_00
//XXX   = 0b00_00_00_00_00_00_10_00_00,

  INF   = 0b00_00_00_00_00_01_00_00_00, // writes device info to A.adr
//SFL   = 0b00_00_00_00_00_01_01_00_00, // sets PFLG.var to
//GFL   = 0b00_00_00_00_00_01_10_00_00, // sets A.var to PFLG.var

  PRT   = 0b00_00_00_00_00_10_00_00_00, // writes A.var to terminal
//XXX   = 0b00_00_00_00_00_10_01_00_00
//XXX   = 0b00_00_00_00_00_10_10_00_00,

  // sys calls          2T ( 1 arg ) |
  SYS   = 0b00_00_00_00_01_00_00_00_00, // sets F_ST to - and calls protocol # A.var if it exists, and F_IP allows
  SAV   = 0b00_00_00_00_00_00_01_00_00, // save    CONTEXT to   A.adr ( first 81 Trytes of PUM )
  RST   = 0b00_00_00_00_00_00_10_00_00, // restore CONTEXT from A.adr ( first 81 Trytes of PUM )

//XXX   = 0b00_00_00_00_01_01_00_00_00,
//XXX   = 0b00_00_00_00_01_01_01_00_00,
//XXX   = 0b00_00_00_00_01_01_10_00_00,

//XXX   = 0b00_00_00_00_01_10_00_00_00,
//XXX   = 0b00_00_00_00_01_10_01_00_00,
//XXX   = 0b00_00_00_00_01_10_10_00_00,

  // sys macros          1T ( 0 arg ) | NOTE : ignores A ( for now ? )
  CNT   = 0b00_00_00_00_10_01_00_00_00, // resume process   ( continue  ) => sets F_ST to 0 and increments PREG.var by OLEN.var
  TRM   = 0b00_00_00_00_10_01_01_00_00, // suspend process  ( terminate ) => sets F_ST to + and calls exit protocol  if F_IP allows
  YLD   = 0b00_00_00_00_10_01_10_00_00, // interupt process ( yield     ) => sets F_ST to - and calls pause protocol if F_IP allows

//XXX   = 0b00_00_00_00_10_01_00_00_00,
//XXX   = 0b00_00_00_00_10_01_01_00_00,
//XXX   = 0b00_00_00_00_10_01_10_00_00,

//XXX   = 0b00_00_00_00_10_10_00_00_00,
//XXX   = 0b00_00_00_00_10_10_01_00_00,
//XXX   = 0b00_00_00_00_10_10_10_00_00,

// PROCESS OPS           2T ( 1 arg ) |

  SSA   = 0b00_00_00_01_00_00_00_00_00, // sets PSTK.var to A.var
  SRA   = 0b00_00_00_01_00_00_01_00_00, // sets MSEG.var to A.var ( upper half of RAM I/O address space )
//XXX   = 0b00_00_00_01_00_00_10_00_00,

//XXX   = 0b00_00_00_01_00_01_00_00_00,
//XXX   = 0b00_00_00_01_00_01_01_00_00,
//XXX   = 0b00_00_00_01_00_01_10_00_00,

//XXX   = 0b00_00_00_01_00_10_00_00_00,
//XXX   = 0b00_00_00_01_00_10_01_00_00,
//XXX   = 0b00_00_00_01_00_10_10_00_00,

  JMP   = 0b00_00_00_01_01_00_00_00_00, // set PADR to A.var
  CAL   = 0b00_00_00_01_01_00_01_00_00, // PSH( PADR.var ) + JMP( A.var )
  RET   = 0b00_00_00_01_01_00_10_00_00, // JMP( POP().var )               ( + SSA( A )? )

//XXX   = 0b00_00_00_01_01_01_00_00_00,
//XXX   = 0b00_00_00_01_01_01_01_00_00,
//XXX   = 0b00_00_00_01_01_01_10_00_00,

//XXX   = 0b00_00_00_01_01_10_00_00_00,
//XXX   = 0b00_00_00_01_01_10_01_00_00,
//XXX   = 0b00_00_00_01_01_10_10_00_00,

  PSS   = 0b00_00_00_01_10_00_00_00_00, // pushes A.var into PSTK.stk
  PPS   = 0b00_00_00_01_10_00_01_00_00, // pops from PSTK.stk into A.adr
  CLS   = 0b00_00_00_01_10_00_10_00_00, // empties the PSTK.stk           ( + SSA( A )? )

//XXX   = 0b00_00_00_01_10_01_00_00_00,
//XXX   = 0b00_00_00_01_10_01_01_00_00,
//XXX   = 0b00_00_00_01_10_01_10_00_00,

//XXX   = 0b00_00_00_01_10_10_00_00_00,
//XXX   = 0b00_00_00_01_10_10_01_00_00,
//XXX   = 0b00_00_00_01_10_10_10_00_00,

  // MOVE OPS           3T ( 2 args ) | in place ops

//XXX   = 0b00_00_00_10_00_00_00_00_00,
  CPY   = 0b00_00_00_10_00_00_01_00_00, // copies A.var to B.adr
  SWP   = 0b00_00_00_10_00_00_10_00_00, // swaps A.var and B.var

  STR   = 0b00_00_00_10_00_01_01_00_00, // copies PREG.var to A.adr, *B.adr
  LOD   = 0b00_00_00_10_00_01_00_00_00, // copies A.var to PREG.adr, *B.adr
  STL   = 0b00_00_00_10_00_01_10_00_00, // STR( A ) + LOD( B )

//XXX   = 0b00_00_00_10_00_10_00_00_00,
//XXX   = 0b00_00_00_10_00_10_01_00_00,
//XXX   = 0b00_00_00_10_00_10_10_00_00,

//XXX   = 0b00_00_00_10_01_00_00_00_00,
//XXX   = 0b00_00_00_10_01_00_01_00_00,
//XXX   = 0b00_00_00_10_01_00_10_00_00,

//XXX   = 0b00_00_00_10_01_01_00_00_00,
//XXX   = 0b00_00_00_10_01_01_01_00_00,
//XXX   = 0b00_00_00_10_01_01_10_00_00,

//XXX   = 0b00_00_00_10_01_10_00_00_00,
//XXX   = 0b00_00_00_10_01_10_01_00_00,
//XXX   = 0b00_00_00_10_01_10_10_00_00,

//XXX   = 0b00_00_00_10_10_00_00_00_00,
//XXX   = 0b00_00_00_10_10_00_01_00_00,
//XXX   = 0b00_00_00_10_10_00_10_00_00,

//XXX   = 0b00_00_00_10_10_01_00_00_00,
//XXX   = 0b00_00_00_10_10_01_01_00_00,
//XXX   = 0b00_00_00_10_10_01_10_00_00,

//XXX   = 0b00_00_00_10_10_10_00_00_00,
//XXX   = 0b00_00_00_10_10_10_01_00_00,
//XXX   = 0b00_00_00_10_10_10_10_00_00,

  // MULTI OPS          4T ( 3 args ) |

  STM   = 0b00_00_01_00_00_00_00_00_00, // SET( A,   B++ ) C.var times
  CPM   = 0b00_00_01_00_00_00_01_00_00, // CPY( A++, B++ ) C.var times
  SWM   = 0b00_00_01_00_00_00_10_00_00, // SWP( A++, B++ ) C.var times

  PSH   = 0b00_00_01_00_00_01_00_00_00, // ...
  POP   = 0b00_00_01_00_00_01_01_00_00, // ...
  CLR   = 0b00_00_01_00_00_01_10_00_00, // ...

//XXX   = 0b00_00_01_00_00_10_00_00_00,
//XXX   = 0b00_00_01_00_00_10_01_00_00,
//XXX   = 0b00_00_01_00_00_10_10_00_00,

//XXX   = 0b00_00_01_00_01_00_00_00_00,
//XXX   = 0b00_00_01_00_01_00_01_00_00,
//XXX   = 0b00_00_01_00_01_00_10_00_00,

//XXX   = 0b00_00_01_00_01_01_00_00_00,
//XXX   = 0b00_00_01_00_01_01_01_00_00,
//XXX   = 0b00_00_01_00_01_01_10_00_00,

//XXX   = 0b00_00_01_00_01_10_00_00_00,
//XXX   = 0b00_00_01_00_01_10_01_00_00,
//XXX   = 0b00_00_01_00_01_10_10_00_00,

//XXX   = 0b00_00_01_00_10_00_00_00_00,
//XXX   = 0b00_00_01_00_10_00_01_00_00,
//XXX   = 0b00_00_01_00_10_00_10_00_00,

//XXX   = 0b00_00_01_00_10_01_00_00_00,
//XXX   = 0b00_00_01_00_10_01_01_00_00,
//XXX   = 0b00_00_01_00_10_01_10_00_00,

//XXX   = 0b00_00_01_00_10_10_00_00_00,
//XXX   = 0b00_00_01_00_10_10_01_00_00,
//XXX   = 0b00_00_01_00_10_10_10_00_00,

  // GATE OPS          3T ( 2 args ) | outputs to PREG only

//XXX   = 0b00_00_01_01_00_00_00_00_00, // - - -   + + +
  AND   = 0b00_00_01_01_00_00_01_00_00, // - 0 0   + 0 0  // MINIMUM
  NAN   = 0b00_00_01_01_00_00_10_00_00, // - 0 +   + 0 -

//XXX   = 0b00_00_01_01_00_01_00_00_00, // - 0 +   + 0 -
  ORR   = 0b00_00_01_01_00_01_01_00_00, // 0 0 +   0 0 -  // MAXIMUM
  NOR   = 0b00_00_01_01_00_01_10_00_00, // + + +   - - -

//XXX   = 0b00_00_01_01_00_10_00_00_00, // - 0 +   + 0 -
  XOR   = 0b00_00_01_01_00_10_01_00_00, // 0 0 0   0 0 0  // ???
  XNR   = 0b00_00_01_01_00_10_10_00_00, // + 0 -   - 0 +

//XXX   = 0b00_00_01_01_01_00_00_00_00, // - - 0   + + 0
  MAJ   = 0b00_00_01_01_01_00_01_00_00, // - 0 +   + 0 -  // (INV) MAJORITY
  IMJ   = 0b00_00_01_01_01_00_10_00_00, // 0 + +   0 - -

//XXX   = 0b00_00_01_01_01_01_00_00_00, // - 0 0   + 0 0
  CON   = 0b00_00_01_01_01_01_01_00_00, // 0 0 0   0 0 0  // (INV) CONSENSUS
  ICN   = 0b00_00_01_01_01_01_10_00_00, // 0 0 +   0 0 -

//XXX   = 0b00_00_01_01_01_10_00_00_00, // + - -   - + +
  PAR   = 0b00_00_01_01_01_10_01_00_00, // - + -   + - +  // (NON) PARITY
  NPR   = 0b00_00_01_01_01_10_10_00_00, // - - +   + + -

//XXX   = 0b00_00_01_01_10_00_01_00_00, // - 0 +   + 0 -
//XXX   = 0b00_00_01_01_10_00_10_00_00, // 0 + +   0 - -  // ???
//XXX   = 0b00_00_01_01_10_00_10_00_00, // + + +   - - -

//XXX   = 0b00_00_01_01_10_01_00_00_00, // - 0 -   + 0 +
//XXX   = 0b00_00_01_01_10_01_01_00_00, // 0 + 0   0 - 0  // ???
//XXX   = 0b00_00_01_01_10_01_10_00_00, // - 0 -   + 0 +

//XXX   = 0b00_00_01_01_10_10_00_00_00, //
//XXX   = 0b00_00_01_01_10_10_01_00_00, //
//XXX   = 0b00_00_01_01_10_10_10_00_00, //

  // TRIT1 OPS           2T ( 1 arg ) | in place ops.

  INC   = 0b00_00_01_10_00_00_00_00_00, // increment     A.var
  DEC   = 0b00_00_01_10_00_00_01_00_00, // decrement     A.var
  INV   = 0b00_00_01_10_00_00_10_00_00, // negate/invert A.var

  SHU   = 0b00_00_01_10_00_01_00_00_00, // shift all trits in tryte up   by one in A.var
  SHD   = 0b00_00_01_10_00_01_01_00_00, // shift all trits in tryte down by one in A.var
  SHV   = 0b00_00_01_10_00_01_10_00_00, // shift all trits in tryte by A.var

  RTU   = 0b00_00_01_10_00_10_00_00_00, // rotate all trits in tryte up   by one in A.var
  RTD   = 0b00_00_01_10_00_10_01_00_00, // rotate all trits in tryte down by one in A.var
  RTV   = 0b00_00_01_10_00_10_10_00_00, // rotate all trits in tryte by A.var

  FLP   = 0b00_00_01_10_01_00_00_00_00, // flip all trits back-to-front for A.var
  PTZ   = 0b00_00_01_10_01_00_01_00_00, // converts all 1 trits to 0
  NTZ   = 0b00_00_01_10_01_00_10_00_00, // converts all 2 trits to 0

  MAG   = 0b00_00_01_10_01_01_00_00_00, // set A.var to the sum of individual trits
  PTN   = 0b00_00_01_10_01_01_01_00_00, // clamp all 1 trits to 2
  NTP   = 0b00_00_01_10_01_01_10_00_00, // clamp all 2 trits to 1

  EQZ   = 0b00_00_01_10_01_10_00_00_00, // 0 => 1, 1/2 => - | is null
  ZTP   = 0b00_00_01_10_01_10_01_00_00, // converts all 0 trits to 1
  ZTN   = 0b00_00_01_10_01_10_10_00_00, // converts all 0 trits to 2

//XXX   = 0b00_00_01_10_10_00_00_00_00,
  TUP   = 0b00_00_01_10_10_00_01_00_00, // convert all individual trits up   by 1 ( 2 > 0 > 1 > 2 )
  TDW   = 0b00_00_01_10_10_00_10_00_00, // convert all individual trits down by 1 ( 1 > 0 > 2 > 1 )

//XXX   = 0b00_00_01_10_10_01_00_00_00,
  DET   = 0b00_00_01_10_10_01_01_00_00, // 1/2 => 1, 0 => 2 | determinacy
  IDT   = 0b00_00_01_10_10_01_10_00_00, // 1/2 => 2, 0 => 1 | inv determinacy

  CMZ   = 0b00_00_01_10_10_10_00_00_00, // A.var >/=/< 0, updating PFLGs
//XXX   = 0b00_00_01_10_10_10_01_00_00,
//XXX   = 0b00_00_01_10_10_10_10_00_00,

  // TRIT2 OPS          4T ( 3 args ) | outputs to C.adr

  CMF   = 0b00_00_10_00_00_00_00_00_00, // A.var >/=/< FLP( B.var ), updating PFLGs
  CMP   = 0b00_00_10_00_00_00_01_00_00, // A.var >/=/< PTZ( B.var ), updating PFLGs
  CMN   = 0b00_00_10_00_00_00_10_00_00, // A.var >/=/< NTZ( B.var ), updating PFLGs

  MSZ   = 0b00_00_10_00_00_01_00_00_00, // 0 0 0   0 0 0   - 0 +
  MSP   = 0b00_00_10_00_00_01_01_00_00, // - 0 +   0 0 0   0 0 0  // MASKING
  MSN   = 0b00_00_10_00_00_01_10_00_00, // 0 0 0   - 0 +   0 0 0

//XXX   = 0b00_00_10_00_00_10_00_00_00,
//XXX   = 0b00_00_10_00_00_10_01_00_00,
//XXX   = 0b00_00_10_00_00_10_10_00_00,

//XXX   = 0b00_00_10_00_01_00_00_00_00,
//XXX   = 0b00_00_10_00_01_00_01_00_00,
//XXX   = 0b00_00_10_00_01_00_10_00_00,

//XXX   = 0b00_00_10_00_01_01_00_00_00,
//XXX   = 0b00_00_10_00_01_01_01_00_00,
//XXX   = 0b00_00_10_00_01_01_10_00_00,

//XXX   = 0b00_00_10_00_01_10_00_00_00,
//XXX   = 0b00_00_10_00_01_10_01_00_00,
//XXX   = 0b00_00_10_00_01_10_10_00_00,

//XXX   = 0b00_00_10_00_10_00_00_00_00,
//XXX   = 0b00_00_10_00_10_00_01_00_00,
//XXX   = 0b00_00_10_00_10_00_10_00_00,

//XXX   = 0b00_00_10_00_10_01_00_00_00,
//XXX   = 0b00_00_10_00_10_01_01_00_00,
//XXX   = 0b00_00_10_00_10_01_10_00_00,

//XXX   = 0b00_00_10_00_10_10_00_00_00,
//XXX   = 0b00_00_10_00_10_10_01_00_00,
//XXX   = 0b00_00_10_00_10_10_10_00_00,

  // ALU1 OPS           4T ( 3 args ) | outputs to C.adr

  ADD   = 0b00_00_10_01_00_00_00_00_00, // addition  B.var to   A.var
  SUB   = 0b00_00_10_01_00_00_01_00_00, // substract B.var from A.var
  MUL   = 0b00_00_10_01_00_00_10_00_00, // multiply  B.var with A.var

  MOD   = 0b00_00_10_01_00_01_00_00_00, // modulo A.var by B.var
  EXP   = 0b00_00_10_01_00_01_01_00_00, // A.var ^ B.var
  LOG   = 0b00_00_10_01_00_01_10_00_00, // LOG( A.var ) / LOG ( B.var )  NOTE : logB( A )

  DIV   = 0b00_00_10_01_00_10_00_00_00, // divide A.var by B.var         NOTE : rounds towards 0
  RND   = 0b00_00_10_01_00_10_01_00_00, // round  A.var by B.var         NOTE : rounds towards 0
  RUT   = 0b00_00_10_01_00_10_10_00_00, // A.var ^ ( 1 / B.var )         NOTE : rounds towards 0

  AVG   = 0b00_00_10_01_01_00_00_00_00, //    ( A.var + B.var ) / 2      NOTE : rounds towards 0
  MAX   = 0b00_00_10_01_01_00_01_00_00, // MAX( A.var | B.var )
  MIN   = 0b00_00_10_01_01_00_10_00_00, // MIN( A.var | B.var )

//XXX   = 0b00_00_10_01_01_01_00_00_00,
  ADC   = 0b00_00_10_01_01_01_01_00_00, // ( A.var + B.var ) + CARRY trit
  SBB   = 0b00_00_10_01_01_01_10_00_00, // ( A.var - B.var ) - BORROW trit << TRYTE_SIZE - 1

  SQR   = 0b00_00_10_01_01_10_00_00_00, // ( A.var + *B.var ) ^ 2        NOTE : is this useful ?
  CUB   = 0b00_00_10_01_01_10_01_00_00, // ( A.var + *B.var ) ^ 3        NOTE : is this useful ?
  MDT   = 0b00_00_10_01_01_10_10_00_00, // ( A.var + *B.var ) % 3        NOTE : is this useful ?

//XXX   = 0b00_00_10_01_10_00_00_00_00,
//XXX   = 0b00_00_10_01_10_00_01_00_00,
//XXX   = 0b00_00_10_01_10_00_10_00_00,

//XXX   = 0b00_00_10_01_10_01_00_00_00,
//XXX   = 0b00_00_10_01_10_01_01_00_00,
//XXX   = 0b00_00_10_01_10_01_10_00_00,

//XXX   = 0b00_00_10_01_10_10_00_00_00,
//XXX   = 0b00_00_10_01_10_10_01_00_00,
//XXX   = 0b00_00_10_01_10_10_10_00_00,

// ALU2 OPS             5T ( 4 args ) | outputs to D.adr

  MED   = 0b00_00_10_10_00_00_00_00_00, // MED( A.var, B.var, C.var )
  MAD   = 0b00_00_10_10_00_00_01_00_00, // ( A.var * B.var ) + C.var
  AMU   = 0b00_00_10_10_00_00_10_00_00, // ( A.var + B.var ) * C.var

//XXX   = 0b00_00_10_10_00_01_00_00_00,
//XXX   = 0b00_00_10_10_00_01_01_00_00,
//XXX   = 0b00_00_10_10_00_01_10_00_00,

//XXX   = 0b00_00_10_10_00_10_00_00_00,
//XXX   = 0b00_00_10_10_00_10_01_00_00,
//XXX   = 0b00_00_10_10_00_10_10_00_00,

//XXX   = 0b00_00_10_10_01_00_00_00_00,
//XXX   = 0b00_00_10_10_01_00_01_00_00,
//XXX   = 0b00_00_10_10_01_00_10_00_00,

//XXX   = 0b00_00_10_10_01_01_00_00_00,
//XXX   = 0b00_00_10_10_01_01_01_00_00,
//XXX   = 0b00_00_10_10_01_01_10_00_00,

//XXX   = 0b00_00_10_10_01_10_00_00_00,
//XXX   = 0b00_00_10_10_01_10_01_00_00,
//XXX   = 0b00_00_10_10_01_10_10_00_00,

//XXX   = 0b00_00_10_10_10_00_00_00_00,
//XXX   = 0b00_00_10_10_10_00_01_00_00,
//XXX   = 0b00_00_10_10_10_00_10_00_00,

//XXX   = 0b00_00_10_10_10_01_00_00_00,
//XXX   = 0b00_00_10_10_10_01_01_00_00,
//XXX   = 0b00_00_10_10_10_01_10_00_00,

//XXX   = 0b00_00_10_10_10_10_00_00_00,
//XXX   = 0b00_00_10_10_10_10_01_00_00,
//XXX   = 0b00_00_10_10_10_10_10_00_00,
};
