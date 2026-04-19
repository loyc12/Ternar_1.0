const std = @import( "std" );
const def = @import( "defs" );

// =========================== PROCESS FLAGS ( PFLG ) ===========================

pub const PFlagTrit = enum( u4 )
{
  F_SN = 0, // what the last ALU/CMPR op returned                      ( -/0/+ ) sign flag
  F_CR = 1, // if the last ALU op had a carry                         (  -/+  ) carry flag           ( add )
  F_BR = 2, // if the last ALU op had a borrow                        (  -/+  ) borrow flag          ( sub )
  F_FL = 3, // if the last ALU op under- or over-flowed               (  -/+  ) over/under flow flag ( add, sub. mul )
  F_OR = 4, // wether the last opcond was false, skipped or true      ( -/0/+ ) opcond result flag
  F_OM = 5, // how to modify the next opcond ( inv, skip )            (  -/+  ) opcond modifier flag
  F_IS = 6, // when to auto-inter. ( on step, never, on jmp )         ( -/0/+ ) interupt-on-step flag
  F_ST = 7, // if the process is quiting, running or pausing          ( -/0/+ ) process state flag   TODO : check if useless ?
  F_IP = 8, // if the process can inter. itself( via SYST, no, yes )   ( -/0/+ ) interupt permissions
};

// =========================== PUM MEMORY LAYOUT ===========================
// processing unit memory ( page 0 ) : 19_683 Trytes

// NOTE : CONTEXT = PRG + PCR

// ========= PRG : process registers =========

pub const PRegTryte = enum( u4 ) // TODO : add more work regs ?
{
  PREG = 0, // process reg.    : process output register
  PADR = 1, // process adr.    : where the process pointer is currently at
  PFLG = 2, // process flags   : ( see above for list )
  PSTK = 3, // process stack   : adr. to top of currently used call stack ( delimited by nulls )
  MSEG = 4, // RAM segment     : upper half of any RAM adressing ( page / sector HADR )
//???? = 5, // ?               :
//???? = 6, // ?               :
//???? = 7, // ?               :
  STEP = 8, // step counter    : how many steps since process launched
};

// ========= PCR : cache registers =========

// 9-81 => cache registers.  : 72 Trytes

// ========= TEQL : auxiliary registers =========

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

pub const OpCode = enum( u18 ) // represents t9 Tryte
{

  // OPCODE SUBMASKS ( always in _SCREAMING_SNAKECASE_ )
  // NOTE : Masks are the only ones allowed to use 0b11, as it is an invalid trit otherwise

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

  NOPE  = 0b00_00_00_00_00_00_00_00_00, // do nothing ( TODO : nothing * A.var )
//XXXX  = 0b00_00_00_00_00_00_01_00_00
//XXXX  = 0b00_00_00_00_00_00_10_00_00,

  INFO  = 0b00_00_00_00_00_01_00_00_00, // writes device info to A.adr
//SFLG  = 0b00_00_00_00_00_01_01_00_00, // sets PFLG.var to
//GFLG  = 0b00_00_00_00_00_01_10_00_00, // sets A.var to PFLG.var

  PRNT  = 0b00_00_00_00_00_10_00_00_00, // writes A.var to terminal
//XXXX  = 0b00_00_00_00_00_10_01_00_00
//XXXX  = 0b00_00_00_00_00_10_10_00_00,

  // sys calls          2T ( 1 arg ) |
  SYST  = 0b00_00_00_00_01_00_00_00_00, // sets F_ST to - and calls protocol # A.var if it exists, and F_IP allows
//XXXX  = 0b00_00_00_00_00_00_01_00_00,
//XXXX  = 0b00_00_00_00_00_00_10_00_00,

//XXXX  = 0b00_00_00_00_01_01_00_00_00,
//XXXX  = 0b00_00_00_00_01_01_01_00_00,
//XXXX  = 0b00_00_00_00_01_01_10_00_00,

//XXXX  = 0b00_00_00_00_01_10_00_00_00,
//XXXX  = 0b00_00_00_00_01_10_01_00_00,
//XXXX  = 0b00_00_00_00_01_10_10_00_00,

  // sys macros          1T ( 0 arg ) | NOTE : ignores A ( for now ? )
  CONT  = 0b00_00_00_00_10_01_00_00_00, // resume process   ( continue  ) => sets F_ST to 0 and increments PREG.var to the begining of the next op
  TERM  = 0b00_00_00_00_10_01_01_00_00, // suspend process  ( terminate ) => sets F_ST to + and calls exit protocol  if F_IP allows
  YILD  = 0b00_00_00_00_10_01_10_00_00, // interupt process ( yield     ) => sets F_ST to - and calls pause protocol if F_IP allows

//XXXX  = 0b00_00_00_00_10_01_00_00_00,
//XXXX  = 0b00_00_00_00_10_01_01_00_00,
//XXXX  = 0b00_00_00_00_10_01_10_00_00,

//XXXX  = 0b00_00_00_00_10_10_00_00_00,
//XXXX  = 0b00_00_00_00_10_10_01_00_00,
//XXXX  = 0b00_00_00_00_10_10_10_00_00,

// PROCESS OPS           2T ( 1 arg ) |

  SPTR  = 0b00_00_00_01_00_00_00_00_00, // sets PSTK.var to A.var
  SSEG  = 0b00_00_00_01_00_00_01_00_00, // sets MSEG.var to A.var ( upper half of RAM I/O address space )
//XXXX  = 0b00_00_00_01_00_00_10_00_00,

  SAVE  = 0b00_00_00_01_00_01_00_00_00, // save    CONTEXT to   A.adr ( first 81 Trytes of PUM )
  RSTR  = 0b00_00_00_01_00_01_01_00_00, // restore CONTEXT from A.adr ( first 81 Trytes of PUM )
//XXXX  = 0b00_00_00_01_00_01_10_00_00,

//XXXX  = 0b00_00_00_01_00_10_00_00_00,
//XXXX  = 0b00_00_00_01_00_10_01_00_00,
//XXXX  = 0b00_00_00_01_00_10_10_00_00,

  JUMP  = 0b00_00_00_01_01_00_00_00_00, // set PADR to A.var
  CALL  = 0b00_00_00_01_01_00_01_00_00, // PSH( PADR.var ) + JUMP( A.var )
  RTRN  = 0b00_00_00_01_01_00_10_00_00, // JUMP( POP().var )               ( + SPTR( A )? )

//XXXX  = 0b00_00_00_01_01_01_00_00_00,
//XXXX  = 0b00_00_00_01_01_01_01_00_00,
//XXXX  = 0b00_00_00_01_01_01_10_00_00,

//XXXX  = 0b00_00_00_01_01_10_00_00_00,
//XXXX  = 0b00_00_00_01_01_10_01_00_00,
//XXXX  = 0b00_00_00_01_01_10_10_00_00,

  PSHS  = 0b00_00_00_01_10_00_00_00_00, // pushes A.var into PSTK.stk
  POPS  = 0b00_00_00_01_10_00_01_00_00, // pops from PSTK.stk into A.adr
  CLRS  = 0b00_00_00_01_10_00_10_00_00, // empties the PSTK.stk           ( + SPTR( A )? )

//XXXX  = 0b00_00_00_01_10_01_00_00_00,
//XXXX  = 0b00_00_00_01_10_01_01_00_00,
//XXXX  = 0b00_00_00_01_10_01_10_00_00,

//XXXX  = 0b00_00_00_01_10_10_00_00_00,
//XXXX  = 0b00_00_00_01_10_10_01_00_00,
//XXXX  = 0b00_00_00_01_10_10_10_00_00,

  // MOVE OPS           3T ( 2 args ) | in place ops

  SETV  = 0b00_00_00_10_00_00_00_00_00, // sets a.var to value B
  COPY  = 0b00_00_00_10_00_00_01_00_00, // copies A.var to B.adr
  SWAP  = 0b00_00_00_10_00_00_10_00_00, // swaps A.var and B.var

//XXXX  = 0b00_00_00_10_00_01_01_00_00,
//XXXX  = 0b00_00_00_10_00_01_00_00_00,
//XXXX  = 0b00_00_00_10_00_01_10_00_00,

//XXXX  = 0b00_00_00_10_00_10_00_00_00,
//XXXX  = 0b00_00_00_10_00_10_01_00_00,
//XXXX  = 0b00_00_00_10_00_10_10_00_00,

  STOR  = 0b00_00_00_10_01_00_00_00_00, // copies PREG.var to A.adr, *B.adr
  LOAD  = 0b00_00_00_10_01_00_01_00_00, // copies A.var to PREG.adr, *B.adr
  STLD  = 0b00_00_00_10_01_00_10_00_00, // STOR( A ) + LOAD( B )

//XXXX  = 0b00_00_00_10_01_01_00_00_00,
//XXXX  = 0b00_00_00_10_01_01_01_00_00,
//XXXX  = 0b00_00_00_10_01_01_10_00_00,

//XXXX  = 0b00_00_00_10_01_10_00_00_00,
//XXXX  = 0b00_00_00_10_01_10_01_00_00,
//XXXX  = 0b00_00_00_10_01_10_10_00_00,

//XXXX  = 0b00_00_00_10_10_00_00_00_00,
//XXXX  = 0b00_00_00_10_10_00_01_00_00,
//XXXX  = 0b00_00_00_10_10_00_10_00_00,

//XXXX  = 0b00_00_00_10_10_01_00_00_00,
//XXXX  = 0b00_00_00_10_10_01_01_00_00,
//XXXX  = 0b00_00_00_10_10_01_10_00_00,

//XXXX  = 0b00_00_00_10_10_10_00_00_00,
//XXXX  = 0b00_00_00_10_10_10_01_00_00,
//XXXX  = 0b00_00_00_10_10_10_10_00_00,

  // VECTOR OPS         4T ( 3 args ) |

  VSET  = 0b00_00_01_00_00_00_00_00_00, // SET(  A,   B++ ) C.var times
  VCPY  = 0b00_00_01_00_00_00_01_00_00, // COPY( A++, B++ ) C.var times
  VSWP  = 0b00_00_01_00_00_00_10_00_00, // SWAP( A++, B++ ) C.var times

//XXXX  = 0b00_00_01_00_00_01_00_00_00,
//XXXX  = 0b00_00_01_00_00_01_01_00_00,
//XXXX  = 0b00_00_01_00_00_01_10_00_00,

//XXXX  = 0b00_00_01_00_00_10_00_00_00,
//XXXX  = 0b00_00_01_00_00_10_01_00_00,
//XXXX  = 0b00_00_01_00_00_10_10_00_00,

//XXXX  = 0b00_00_01_00_01_00_00_00_00,
//XXXX  = 0b00_00_01_00_01_00_01_00_00,
//XXXX  = 0b00_00_01_00_01_00_10_00_00,

//XXXX  = 0b00_00_01_00_01_01_00_00_00,
//XXXX  = 0b00_00_01_00_01_01_01_00_00,
//XXXX  = 0b00_00_01_00_01_01_10_00_00,

//XXXX  = 0b00_00_01_00_01_10_00_00_00,
//XXXX  = 0b00_00_01_00_01_10_01_00_00,
//XXXX  = 0b00_00_01_00_01_10_10_00_00,

//XXXX  = 0b00_00_01_00_10_00_00_00_00,
//XXXX  = 0b00_00_01_00_10_00_01_00_00,
//XXXX  = 0b00_00_01_00_10_00_10_00_00,

//XXXX  = 0b00_00_01_00_10_01_00_00_00,
//XXXX  = 0b00_00_01_00_10_01_01_00_00,
//XXXX  = 0b00_00_01_00_10_01_10_00_00,

//XXXX  = 0b00_00_01_00_10_10_00_00_00,
//XXXX  = 0b00_00_01_00_10_10_01_00_00,
//XXXX  = 0b00_00_01_00_10_10_10_00_00,

  // TRIT 1 OPS          2T ( 1 arg ) | in place ops.

  INC   = 0b00_00_01_01_00_00_00_00_00, // increment     A.var
  DEC   = 0b00_00_01_01_00_00_01_00_00, // decrement     A.var
  INV   = 0b00_00_01_01_00_00_10_00_00, // negate/invert A.var

  SHU   = 0b00_00_01_01_00_01_00_00_00, // shift all trits in tryte up   by one in A.var
  SHD   = 0b00_00_01_01_00_01_01_00_00, // shift all trits in tryte down by one in A.var
  SHV   = 0b00_00_01_01_00_01_10_00_00, // shift all trits in tryte by A.var

  RTU   = 0b00_00_01_01_00_10_00_00_00, // rotate all trits in tryte up   by one in A.var
  RTD   = 0b00_00_01_01_00_10_01_00_00, // rotate all trits in tryte down by one in A.var
  RTV   = 0b00_00_01_01_00_10_10_00_00, // rotate all trits in tryte by A.var

  FLP   = 0b00_00_01_01_01_00_00_00_00, // flip all trits back-to-front for A.var
  PTZ   = 0b00_00_01_01_01_00_01_00_00, // converts all 1 trits to 0
  NTZ   = 0b00_00_01_01_01_00_10_00_00, // converts all 2 trits to 0

  MAG   = 0b00_00_01_01_01_01_00_00_00, // set A.var to the sum of individual trits
  PTN   = 0b00_00_01_01_01_01_01_00_00, // clamp all 1 trits to 2
  NTP   = 0b00_00_01_01_01_01_10_00_00, // clamp all 2 trits to 1

  EQZ   = 0b00_00_01_01_01_10_00_00_00, // 0 => 1, 1/2 => - | is null
  ZTP   = 0b00_00_01_01_01_10_01_00_00, // converts all 0 trits to 1
  ZTN   = 0b00_00_01_01_01_10_10_00_00, // converts all 0 trits to 2

//XXXX  = 0b00_00_01_01_10_00_00_00_00, // TODO : add a shift A by B, trit-per-trip op
  TUP   = 0b00_00_01_01_10_00_01_00_00, // convert all individual trits up   by 1 ( 2 > 0 > 1 > 2 )
  TDW   = 0b00_00_01_01_10_00_10_00_00, // convert all individual trits down by 1 ( 1 > 0 > 2 > 1 )

//XXXX  = 0b00_00_01_01_10_01_00_00_00,
  DET   = 0b00_00_01_01_10_01_01_00_00, // 1/2 => 1, 0 => 2 | determinacy
  IDT   = 0b00_00_01_01_10_01_10_00_00, // 1/2 => 2, 0 => 1 | inv determinacy

  CMPZ  = 0b00_00_01_01_10_10_00_00_00, // A.var >/=/< 0, updating PFLGs
//XXXX  = 0b00_00_01_01_10_10_01_00_00,
//XXXX  = 0b00_00_01_01_10_10_10_00_00,

  // TRIT 2 OPS         3T ( 2 args ) | outputs to PREG only   // NOTE : SHOULD THIS OUTPUT TO C.adr instead ?

//XXXX  = 0b00_00_01_10_00_00_00_00_00, // - - -   + + +
  TMIN  = 0b00_00_01_10_00_00_01_00_00, // - 0 0   + 0 0  // (NOT) MINIMUM
  TNMN  = 0b00_00_01_10_00_00_10_00_00, // - 0 +   + 0 -

//XXXX  = 0b00_00_01_10_00_01_00_00_00, // - 0 +   + 0 -
  TMAX  = 0b00_00_01_10_00_01_01_00_00, // 0 0 +   0 0 -  // (NOT) MAXIMUM
  TNMX  = 0b00_00_01_10_00_01_10_00_00, // + + +   - - -

//XXXX  = 0b00_00_01_10_00_10_00_00_00, // + 0 -   - 0 +
  TAGR  = 0b00_00_01_10_00_10_01_00_00, // 0 0 0   0 0 0  // (DIS) AGREEMENT
  TDIS  = 0b00_00_01_10_00_10_10_00_00, // - 0 +   + 0 -

//XXXX  = 0b00_00_01_10_01_00_00_00_00, // - - 0   + + 0
  TMAJ  = 0b00_00_01_10_01_00_01_00_00, // - 0 +   + 0 -  // (NOT) MAJORITY
  TNMJ  = 0b00_00_01_10_01_00_10_00_00, // 0 + +   0 - -

//XXXX  = 0b00_00_01_10_01_01_00_00_00, // - 0 0   + 0 0
  TCON  = 0b00_00_01_10_01_01_01_00_00, // 0 0 0   0 0 0  // (INV) CONSENSUS ( TCON => CARRY TRIT )
  TNCN  = 0b00_00_01_10_01_01_10_00_00, // 0 0 +   0 0 -

//XXXX  = 0b00_00_01_10_01_10_00_00_00, // + - -   - + +
  TEQL  = 0b00_00_01_10_01_10_01_00_00, // - + -   + - +  // (NON) PARITY
  TNEQ  = 0b00_00_01_10_01_10_10_00_00, // - - +   + + -

//XXXX  = 0b00_00_01_10_10_00_00_00_00, // - 0 +   + + +
  TBPS  = 0b00_00_01_10_10_00_01_00_00, // 0 + +   + + 0  // BIASED POS/NEG ( ??? )
  TBNG  = 0b00_00_01_10_10_00_10_00_00, // + + +   + 0 -

//XXXX  = 0b00_00_01_10_10_01_00_00_00, // - 0 -   + 0 +
  TJZR  = 0b00_00_01_10_10_01_01_00_00, // 0 + 0   0 - 0  // (NON) JOINTLY ZERO
  TNJZ  = 0b00_00_01_10_10_01_10_00_00, // - 0 -   + 0 +

//XXXX  = 0b00_00_01_10_10_10_00_00_00, //
//XXXX  = 0b00_00_01_10_10_10_01_00_00, //
//XXXX  = 0b00_00_01_10_10_10_10_00_00, //

  // TRIT 3 OPS         4T ( 3 args ) | outputs to C.adr

  CMPR  = 0b00_00_10_00_00_00_00_00_00, // A.var >/=/< B.var,        updating PFLGs
  CMPN  = 0b00_00_10_00_00_00_01_00_00, // A.var >/=/< NEG( B.var ), updating PFLGs
  CMPF  = 0b00_00_10_00_00_00_10_00_00, // A.var >/=/< FLP( B.var ), updating PFLGs

//XXXX  = 0b00_00_10_00_00_01_00_00_00,
//XXXX  = 0b00_00_10_00_00_01_01_00_00,
//XXXX  = 0b00_00_10_00_00_01_10_00_00,

//XXXX  = 0b00_00_10_00_00_10_00_00_00,
//XXXX  = 0b00_00_10_00_00_10_01_00_00,
//XXXX  = 0b00_00_10_00_00_10_10_00_00,

  MSKZ  = 0b00_00_10_00_01_00_00_00_00, // 0 0 0   0 0 0   - 0 +
  MSKP  = 0b00_00_10_00_01_00_01_00_00, // - 0 +   0 0 0   0 0 0  // TRIWISE MASKING (?)
  MSKN  = 0b00_00_10_00_01_00_10_00_00, // 0 0 0   - 0 +   0 0 0

//XXXX  = 0b00_00_10_00_01_01_00_00_00,
//XXXX  = 0b00_00_10_00_01_01_01_00_00,
//XXXX  = 0b00_00_10_00_01_01_10_00_00,

//XXXX  = 0b00_00_10_00_01_10_00_00_00,
//XXXX  = 0b00_00_10_00_01_10_01_00_00,
//XXXX  = 0b00_00_10_00_01_10_10_00_00,

//XXXX  = 0b00_00_10_00_10_00_00_00_00,
//XXXX  = 0b00_00_10_00_10_00_01_00_00,
//XXXX  = 0b00_00_10_00_10_00_10_00_00,

//XXXX  = 0b00_00_10_00_10_01_00_00_00,
//XXXX  = 0b00_00_10_00_10_01_01_00_00,
//XXXX  = 0b00_00_10_00_10_01_10_00_00,

//XXXX  = 0b00_00_10_00_10_10_00_00_00,
//XXXX  = 0b00_00_10_00_10_10_01_00_00,
//XXXX  = 0b00_00_10_00_10_10_10_00_00,

  // ALU 1 OPS          4T ( 3 args ) | outputs to C.adr

  ADD   = 0b00_00_10_01_00_00_00_00_00, // addition  B.var to   A.var
  SUB   = 0b00_00_10_01_00_00_01_00_00, // substract B.var from A.var
  MOD   = 0b00_00_10_01_00_00_10_00_00, // modulo A.var by B.var

  ADDC  = 0b00_00_10_01_00_01_00_00_00, // ( A.var + B.var ) + CARRY trit
  SUBB  = 0b00_00_10_01_00_01_01_00_00, // ( A.var - B.var ) - ( BORROW trit << ( TRYTE_SIZE - 1 ))
  MODC  = 0b00_00_10_01_00_01_10_00_00, // ( A.var + B.var   + CARRY trit ) % 2

  MUL   = 0b00_00_10_01_00_10_00_00_00, // multiply  B.var with A.var
  DIV   = 0b00_00_10_01_00_10_01_00_00, // divide A.var by B.var     NOTE : rounds towards 0
  EXP   = 0b00_00_10_01_00_10_10_00_00, // A.var ^ B.var

  LOG   = 0b00_00_10_01_01_00_00_00_00, // LOG( A.var ) / LOG ( B.var ), aka logB( A )   // NOTE : overspecialized ?
  ROND  = 0b00_00_10_01_01_00_01_00_00, // round  A.var to B.var     NOTE : rounds towards 0
  ROOT  = 0b00_00_10_01_01_00_10_00_00, // A.var ^ ( 1 / B.var )     NOTE : rounds towards 0   // NOTE : overspecialized ?

  AVG2  = 0b00_00_10_01_01_01_00_00_00, // AVERAGE( A.var | B.var )  NOTE : rounds towards 0
  MIN2  = 0b00_00_10_01_01_01_01_00_00, // MINIMUM( A.var | B.var )
  MAX2  = 0b00_00_10_01_01_01_10_00_00, // MAXIMUM( A.var | B.var )

  EXP2  = 0b00_00_10_01_01_10_00_00_00, // ( A.var + *B.var ) ^ 2
  RUT2  = 0b00_00_10_01_01_10_01_00_00, // ( A.var + *B.var ) ^ 1/2
  MOD2  = 0b00_00_10_01_01_10_10_00_00, // ( A.var + *B.var ) % 2

  EXP3  = 0b00_00_10_01_10_00_00_00_00, // ( A.var + *B.var ) ^ 3
  RUT3  = 0b00_00_10_01_10_00_01_00_00, // ( A.var + *B.var ) ^ 1/3
  MOD3  = 0b00_00_10_01_10_00_10_00_00, // ( A.var + *B.var ) % 3

//MOD   = 0b00_00_10_01_10_01_00_00_00,
//EXP   = 0b00_00_10_01_10_01_01_00_00,
//LOG   = 0b00_00_10_01_10_01_10_00_00,

//XXXX  = 0b00_00_10_01_10_10_00_00_00,
//XXXX  = 0b00_00_10_01_10_10_01_00_00,
//XXXX  = 0b00_00_10_01_10_10_10_00_00,

// ALU 2 OPS            5T ( 4 args ) | outputs to D.adr

  MEDI  = 0b00_00_10_10_00_00_00_00_00, // MED( A.var, B.var, C.var )
  MADD  = 0b00_00_10_10_00_00_01_00_00, // ( A.var * B.var ) + C.var
  AMUL  = 0b00_00_10_10_00_00_10_00_00, // ( A.var + B.var ) * C.var

  AVG3  = 0b00_00_10_10_00_01_00_00_00, // AVERAGE( A.var | B.var | c.var )  NOTE : rounds towards 0
  MIN3  = 0b00_00_10_10_00_01_01_00_00, // MINIMUM( A.var | B.var | c.var )
  MAX3  = 0b00_00_10_10_00_01_10_00_00, // MAXIMUM( A.var | B.var | c.var )

//XXXX  = 0b00_00_10_10_00_10_00_00_00,
//XXXX  = 0b00_00_10_10_00_10_01_00_00,
//XXXX  = 0b00_00_10_10_00_10_10_00_00,

//XXXX  = 0b00_00_10_10_01_00_00_00_00,
//XXXX  = 0b00_00_10_10_01_00_01_00_00,
//XXXX  = 0b00_00_10_10_01_00_10_00_00,

//XXXX  = 0b00_00_10_10_01_01_00_00_00,
//XXXX  = 0b00_00_10_10_01_01_01_00_00,
//XXXX  = 0b00_00_10_10_01_01_10_00_00,

//XXXX  = 0b00_00_10_10_01_10_00_00_00,
//XXXX  = 0b00_00_10_10_01_10_01_00_00,
//XXXX  = 0b00_00_10_10_01_10_10_00_00,

//XXXX  = 0b00_00_10_10_10_00_00_00_00,
//XXXX  = 0b00_00_10_10_10_00_01_00_00,
//XXXX  = 0b00_00_10_10_10_00_10_00_00,

//XXXX  = 0b00_00_10_10_10_01_00_00_00,
//XXXX  = 0b00_00_10_10_10_01_01_00_00,
//XXXX  = 0b00_00_10_10_10_01_10_00_00,

//XXXX  = 0b00_00_10_10_10_10_00_00_00,
//XXXX  = 0b00_00_10_10_10_10_01_00_00,
//XXXX  = 0b00_00_10_10_10_10_10_00_00,

  pub inline fn getOpLen( opName : OpCode ) u18
  {
    _ = opName;

    return 4; // TODO : replace with real calc
  }

};


pub const opCodeMap = std.StaticStringMap( OpCode ).initComptime(
.{
  // SYSTEM OPS
  .{ "NOPE", .NOPE },
  .{ "INFO", .INFO },
  .{ "PRNT", .PRNT },
  .{ "SYST", .SYST },
  .{ "CONT", .CONT },
  .{ "TERM", .TERM },
  .{ "YILD", .YILD },

  // PROCESS OPS
  .{ "SPTR", .SPTR },
  .{ "SSEG", .SSEG },
  .{ "SAVE", .SAVE },
  .{ "RSTR", .RSTR },
  .{ "JUMP", .JUMP },
  .{ "CALL", .CALL },
  .{ "RTRN", .RTRN },
  .{ "PSHS", .PSHS },
  .{ "POPS", .POPS },
  .{ "CLRS", .CLRS },

  // MOVE OPS
  .{ "SETV", .SETV },
  .{ "COPY", .COPY },
  .{ "SWAP", .SWAP },
  .{ "STOR", .STOR },
  .{ "LOAD", .LOAD },
  .{ "STLD", .STLD },

  // VECTORISED OPS
  .{ "VSET", .VSET },
  .{ "VCPY", .VCPY },
  .{ "VSWP", .VSWP },

  // TRITWISE OPS (1)
  .{ "INC", .INC },
  .{ "DEC", .DEC },
  .{ "INV", .INV },
  .{ "SHU", .SHU },
  .{ "SHD", .SHD },
  .{ "SHV", .SHV },
  .{ "RTU", .RTU },
  .{ "RTD", .RTD },
  .{ "RTV", .RTV },
  .{ "FLP", .FLP },
  .{ "PTZ", .PTZ },
  .{ "NTZ", .NTZ },
  .{ "MAG", .MAG },
  .{ "PTN", .PTN },
  .{ "NTP", .NTP },
  .{ "EQZ", .EQZ },
  .{ "ZTP", .ZTP },
  .{ "ZTN", .ZTN },
  .{ "TUP", .TUP },
  .{ "TDW", .TDW },
  .{ "DET", .DET },
  .{ "IDT", .IDT },
  .{ "CMPZ", .CMPZ },

  // TRITWISE OPS (2)
  .{ "TMIN", .TMIN },
  .{ "TNMN", .TNMN },
  .{ "TMAX", .TMAX },
  .{ "TNMX", .TNMX },
  .{ "TAGR", .TAGR },
  .{ "TDIS", .TDIS },
  .{ "TMAJ", .TMAJ },
  .{ "TNMJ", .TNMJ },
  .{ "TCON", .TCON },
  .{ "TNCN", .TNCN },
  .{ "TEQL", .TEQL },
  .{ "TNEQ", .TNEQ },
  .{ "TBPS", .TBPS },
  .{ "TBNG", .TBNG },
  .{ "TJZR", .TJZR },
  .{ "TNJZ", .TNJZ },

  // TRITWISE OPS (3)
  .{ "CMPR", .CMPR },
  .{ "CMPN", .CMPN },
  .{ "CMPF", .CMPF },
  .{ "MSKZ", .MSKZ },
  .{ "MSKP", .MSKP },
  .{ "MSKN", .MSKN },

  // ARITHMETIC OPS (1)
  .{ "ADD", .ADD },
  .{ "SUB", .SUB },
  .{ "MOD", .MOD },
  .{ "ADDC", .ADDC },
  .{ "SUBB", .SUBB },
  .{ "MODC", .MODC },
  .{ "MUL", .MUL },
  .{ "DIV", .DIV },
  .{ "EXP", .EXP },
  .{ "LOG", .LOG },
  .{ "ROND", .ROND },
  .{ "ROOT", .ROOT },
  .{ "AVG2", .AVG2 },
  .{ "MIN2", .MIN2 },
  .{ "MAX2", .MAX2 },
  .{ "EXP2", .EXP2 },
  .{ "RUT2", .RUT2 },
  .{ "MOD2", .MOD2 },
  .{ "EXP3", .EXP3 },
  .{ "RUT3", .RUT3 },
  .{ "MOD3", .MOD3 },

  // ARITHMETIC OPS (2)
  .{ "MEDI", .MEDI },
  .{ "MADD", .MADD },
  .{ "AMUL", .AMUL },
  .{ "AVG3", .AVG3 },
  .{ "MIN3", .MIN3 },
  .{ "MAX3", .MAX3 },
});
