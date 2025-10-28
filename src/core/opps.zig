const std = @import( "std" );
const def = @import( "defs" );

// =========================== PROCESS FLAGS ( PFLG ) ===========================

// F_SN => what the last ALU/CMP opp returned        ( -/0/+ ) sign flag
// F_CR => if the last ALU opp had a carry           (  -/+  ) carry flag           ( add )
// F_BR => if the last ALU opp had a borrow          (  -/+  ) borrow flag          ( sub )
// F_FL => if the last ALU opp under- or over-flowed (  -/+  ) over/under flow flag ( add, sub. mul )

// F_ER => wether the last op failed, skipped or succeeded        ( -/0/+ ) operation error flag
// F_CN => wether to modify the next opcond ( inv, skip )         (  -/+  ) operation condition flag

// F_IS => when to auto-inter. ( on step, never, on jmp )         ( -/0/+ ) interupt-on-step flag
// F_ST => if the process is quiting, running or pausing          ( -/0/+ ) process state flag   TODO : check if useless ?
// F_IP => if the process can inter. itself( via SYS, no, yes )   ( -/0/+ ) interupt permissions


// =========================== PUM MEMORY LAYOUT ===========================
// processing units memory : 19_683 Trytes

// NOTE : CONTEXT = PPR + PCR

// ========= PPR : process registers =========

//     Tryte #
//        |
// PREG | 0 => process reg.    :  default process work register NOTE : add more work regs ?
// PADR | 1 => process adr.    :  where the process pointer is currently at
// PFLG | 2 => process flags   :  ( see above for list )
// PSTK | 3 => process stack   :  adr. to top of currently used call stack ( delimited by nulls )
// RSEG | 4 => RAM segment     :  upper half of any RAM adressing ( page / sector HADR )
// ???? | 5 => ?               :
// ???? | 6 => ?               :
// PSTP | 7 => step counter    :  how many steps since process launched
// OLEN | 8 => cur. op. lenght :  number of args the current ops has

// ========= PCR : cache registers =========

// 9-81 => CPU work regs.  : 72 Trytes

// ========= PAR : auxiliary registers =========

// 81-?  => CPU cache regs.

// ?-?   => boot   protocol : what to do on computer open
// ?-?   => close  protocol : what to do on computer close

// ?-?   => launch protocol : what to do on program start
// ?-?   => pause  protocol : what to do on program pause    ( interupt context switching )
// ?-?   => resume protocol : what to do on program resumes  ( interupt context switching )
// ?-?   => exit   protocol : what to do on program stop

// ?-?   => I/O mapping reg.

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

// NOTE : when addressing, uses the RSEG as the address' uper half ( lower half is arg )

// 0-? => general memory
// ?-? => audio   memory   : 1 sec of soundwaves
// ?-? => video   memory   : 2x max resolution


// =========================== OPCODES ===========================

// ========= NOMENCLATURE =========
// A, B, C : arg1/2/3
// *arg    : optional arg ( can be zero and wont do anything  )
// .adr    : arg as an adfress
// .var    : value at arg's address
// .VAL    : arg as a value
// .stk    : entire stack at adfress
//
//     B-
//     | B0
//     | | B+
//  A- t t t   // NOTE : truth table layout
//  A0 t t t
//  A+ t t t

pub const e_oper = enum( u18 ) // represents t9 Tryte
{
  // OPERATION SUBMASKS
  _IAS_ = 0b11_00_00_00_00_00_00_00_00, // input  adress space
  _OAS_ = 0b00_11_00_00_00_00_00_00_00, // output adress space
  _OPN_ = 0b00_00_11_11_11_11_11_00_00, // operation names ( types & codes )
  _OPT_ = 0b00_00_11_11_00_00_00_00_00, // operation types
  _OPC_ = 0b00_00_00_00_11_11_11_00_00, // operation codes
  _EXC_ = 0b00_00_00_00_00_00_00_11_11, // execution conditions

  // INPUT SPACE                      | // adr. 0 is null
  I_PM  = 0b00_00_00_00_00_00_00_00_00, // PUM adresses                  // TODO : replace with "use static values instead of pointers to variables" ?
  I_RM  = 0b01_00_00_00_00_00_00_00_00, // RAM adresses ( upper half in RSEG )
  I_RL  = 0b10_00_00_00_00_00_00_00_00, // RAM adresses ( relative to PADR, signed )

  // OUTPUT SPACE                     | always outputs to PREG. as well
  O_PM  = 0b00_00_00_00_00_00_00_00_00, // PUM adresses
  O_RM  = 0b00_01_00_00_00_00_00_00_00, // RAM adresses ( upper half in RSEG )
  O_RL  = 0b00_10_00_00_00_00_00_00_00, // RAM adresses ( relative to PADR, signed )

  // OPERATION CONDITIONS             | only execute opcode if :
  C_ALW = 0b00_00_00_00_00_00_00_00_00, // always, unconditionally
  C_IFC = 0b00_00_00_00_00_00_00_00_01, // if F_CR or F_BR != 0
  C_IFF = 0b00_00_00_00_00_00_00_00_10, // if F_FL != 0

  C_IFZ = 0b00_00_00_00_00_00_00_01_00, // if F_SN != 0
  C_IFP = 0b00_00_00_00_00_00_00_01_01, // if F_SN != +
  C_IFN = 0b00_00_00_00_00_00_00_01_10, // if F_SN != -

//C_INV = 0b00_00_00_00_00_00_00_10_00, // set F_SK to - to invert the next condition check's result
//C_SKP = 0b00_00_00_00_00_00_00_10_01, // set F_SK to + to avoid the next condition check ( acts like C_ALW  )
//C_XXX = 0b00_00_00_00_00_00_00_10_10,


  // ========= OPERATION TYPE & CODE =========

  // SYSTEM OPS          2T ( 1 arg ) |

  NOP   = 0b00_00_00_00_00_00_00_00_00, // do nothing * A.val
//XXX   = 0b00_00_00_00_00_00_01_00_00
//XXX   = 0b00_00_00_00_00_00_10_00_00,

  SFL   = 0b00_00_00_00_00_01_00_00_00, // sets PFLG.var to A.var
  GFL   = 0b00_00_00_00_00_01_01_00_00, // sets A.var to PFLG.var
//XXX   = 0b00_00_00_00_00_01_10_00_00,

  INF   = 0b00_00_00_00_00_10_00_00_00, // writes device info to A.adr
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

  // sys macros          1T ( 0 arg ) |
  CNT   = 0b00_00_00_00_10_01_00_00_00, // step / resume process  ( continue  ) => sets F_ST to 0 and increments PREG.var by OLEN + 1
  TRM   = 0b00_00_00_00_10_01_01_00_00, // suspend / quit process ( terminate ) => sets F_ST to + and calls exit protocol  if F_IP allows
  YLD   = 0b00_00_00_00_10_01_10_00_00, // interupt process       ( yield     ) => sets F_ST to - and calls pause protocol if F_IP allows

//XXX   = 0b00_00_00_00_10_01_00_00_00,
//XXX   = 0b00_00_00_00_10_01_01_00_00,
//XXX   = 0b00_00_00_00_10_01_10_00_00,

//XXX   = 0b00_00_00_00_10_10_00_00_00,
//XXX   = 0b00_00_00_00_10_10_01_00_00,
//XXX   = 0b00_00_00_00_10_10_10_00_00,


// PROCESS OPS           2T ( 1 arg ) |

  SSA   = 0b00_00_00_01_00_00_00_00_00, // sets PSTK.var to A.var
  SRA   = 0b00_00_00_01_00_00_01_00_00, // sets RSEG.var to A.var ( upper half of RAM I/O address space )
//XXX   = 0b00_00_00_01_00_00_10_00_00,

//XXX   = 0b00_00_00_01_00_01_00_00_00,
//XXX   = 0b00_00_00_01_00_01_01_00_00,
//XXX   = 0b00_00_00_01_00_01_10_00_00,

//XXX   = 0b00_00_00_01_00_10_00_00_00,
//XXX   = 0b00_00_00_01_00_10_01_00_00,
//XXX   = 0b00_00_00_01_00_10_10_00_00,

  // jump ops
  JMP   = 0b00_00_00_01_01_00_00_00_00, // set PADR to A.var
  CAL   = 0b00_00_00_01_01_00_01_00_00, // PSH( PADR.var ) + JMP( A.var )
  RET   = 0b00_00_00_01_01_00_10_00_00, // JMP( POP().var )              ( + SSA( A )? )

//XXX   = 0b00_00_00_01_01_01_00_00_00,
//XXX   = 0b00_00_00_01_01_01_01_00_00,
//XXX   = 0b00_00_00_01_01_01_10_00_00,

//XXX   = 0b00_00_00_01_01_10_00_00_00,
//XXX   = 0b00_00_00_01_01_10_01_00_00,
//XXX   = 0b00_00_00_01_01_10_10_00_00,

  // stack ops           2T ( 1 arg ) |
  PSH   = 0b00_00_00_01_10_00_00_00_00, // ...
  POP   = 0b00_00_00_01_10_00_01_00_00, // ...
  CLR   = 0b00_00_00_01_10_00_10_00_00, // ...

  PSS   = 0b00_00_00_01_10_01_00_00_00, // pushes A.var into PSTK.stk
  PPS   = 0b00_00_00_01_10_01_01_00_00, // pops from PSTK.stk into A.adr
  CLS   = 0b00_00_00_01_10_01_10_00_00, // empties the PSTK.stk          ( + SSA( A )? )

//XXX   = 0b00_00_00_01_10_10_00_00_00,
//XXX   = 0b00_00_00_01_10_10_01_00_00,
//XXX   = 0b00_00_00_01_10_10_10_00_00,

  // MOVE OPS           3T ( 2 args ) | in place ops

  SET   = 0b00_00_00_10_00_00_00_00_00, // copies A.VAL into B.adr
  CPY   = 0b00_00_00_10_00_00_01_00_00, // copies A.var to B.adr
  SWP   = 0b00_00_00_10_00_00_10_00_00, // swaps A.var and B.var

  STR   = 0b00_00_00_10_00_01_01_00_00, // writes PREG.var to  A.adr, *B.adr
  LOD   = 0b00_00_00_10_00_01_00_00_00, // reads A.var into PREG.adr, *B.adr
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

  // array ops          4T ( 3 args ) |
  STM   = 0b00_00_00_10_10_00_00_00_00, // SET( A,   B++ ) C.var times
  CPM   = 0b00_00_00_10_10_00_01_00_00, // CPY( A++, B++ ) C.var times
  SWM   = 0b00_00_00_10_10_00_10_00_00, // SWP( A++, B++ ) C.var times

//XXX   = 0b00_00_00_10_10_01_00_00_00,
//XXX   = 0b00_00_00_10_10_01_01_00_00,
//XXX   = 0b00_00_00_10_10_01_10_00_00,

//XXX   = 0b00_00_00_10_10_10_00_00_00,
//XXX   = 0b00_00_00_10_10_10_01_00_00,
//XXX   = 0b00_00_00_10_10_10_10_00_00,

  // TRIT1 OPS          4T ( 3 args ) | in place ops.

  INC   = 0b00_00_01_00_00_00_00_00_00, // increment     A.var, *B.var, *C.var
  DEC   = 0b00_00_01_00_00_00_01_00_00, // decrement     A.var, *B.var, *C.var
  INV   = 0b00_00_01_00_00_00_10_00_00, // negate/invert A.var, *B.var, *C.var

  SHU   = 0b00_00_01_00_00_01_00_00_00, // shift all trits in tryte up   by one in A.var, *B.var, *C.var
  SHD   = 0b00_00_01_00_00_01_01_00_00, // shift all trits in tryte down by one in A.var, *B.var, *C.var
  SHV   = 0b00_00_01_00_00_01_10_00_00, // shift all trits in tryte by A.var    in B.var, *C.var

  RTU   = 0b00_00_01_00_00_10_00_00_00, // rotate all trits in tryte up   by one in A.var, *B.var, *C.var
  RTD   = 0b00_00_01_00_00_10_01_00_00, // rotate all trits in tryte down by one in A.var, *B.var, *C.var
  RTV   = 0b00_00_01_00_00_10_10_00_00, // rotate all trits in tryte by A.var    in B.var, *C.var


  FLP   = 0b00_00_01_00_01_00_00_00_00, // flip all trits back-to-front for A.var, *B.var, *C.var
  POS   = 0b00_00_01_00_01_00_01_00_00, // converts all 2 trits to 0
  NEG   = 0b00_00_01_00_01_00_10_00_00, // converts all 1 trits to 0

  MAG   = 0b00_00_01_00_01_01_00_00_00, // set A.var, *B.var, *C.var to the sum of their individual trits
  CLP   = 0b00_00_01_00_01_01_01_00_00, // clamp all 2 trits to 1
  CLN   = 0b00_00_01_00_01_01_10_00_00, // clamp all 1 trits to 2

//XXX   = 0b00_00_01_00_01_10_00_00_00,
  TRU   = 0b00_00_01_00_01_10_01_00_00, // convert all individual trip up   ( 2 > 0 > 1 > 2)
  TRD   = 0b00_00_01_00_01_10_10_00_00, // convert all individual trip down ( 1 > 0 > 2 > 1)


  EQZ   = 0b00_00_01_00_10_00_00_00_00, // 0 => 1, 1/2 => - | is null
  DET   = 0b00_00_01_00_10_00_01_00_00, // 1/2 => 1, 0 => 2 | determinacy
  IDT   = 0b00_00_01_00_10_00_10_00_00, // 1/2 => 2, 0 => 1 | inv determinacy

//XXX   = 0b00_00_01_00_10_01_00_00_00,
//XXX   = 0b00_00_01_00_10_01_01_00_00,
//XXX   = 0b00_00_01_00_10_01_10_00_00,

  CMZ   = 0b00_00_01_00_10_10_00_00_00, // A.var >/=/< 0, updating PFLGs
//XXX   = 0b00_00_01_00_10_10_01_00_00,
//XXX   = 0b00_00_01_00_10_10_10_00_00,

  // TRIT2 OPS          4T ( 3 args ) | outputs to C.adr

  CMV   = 0b00_00_01_01_00_00_00_00_00, // A.var >/=/<  B.VAL, updating PFLGs
  CMP   = 0b00_00_01_01_00_00_01_00_00, // A.var >/=/<  B.var, updating PFLGs
  CMN   = 0b00_00_01_01_00_00_10_00_00, // A.var >/=/< -B.var, updating PFLGs

  MSZ   = 0b00_00_01_01_00_01_00_00_00, // 0 0 0   0 0 0   - 0 +
  MSP   = 0b00_00_01_01_00_01_01_00_00, // - 0 +   0 0 0   0 0 0  // MASKING
  MSN   = 0b00_00_01_01_00_01_10_00_00, // 0 0 0   - 0 +   0 0 0

//XXX   = 0b00_00_01_01_00_10_00_00_00,
//XXX   = 0b00_00_01_01_00_10_01_00_00,
//XXX   = 0b00_00_01_01_00_10_10_00_00,


//XXX   = 0b00_00_01_01_01_00_00_00_00,
//XXX   = 0b00_00_01_01_01_00_01_00_00,
//XXX   = 0b00_00_01_01_01_00_10_00_00,

//XXX   = 0b00_00_01_01_01_01_00_00_00,
//XXX   = 0b00_00_01_01_01_01_01_00_00,
//XXX   = 0b00_00_01_01_01_01_10_00_00,

//XXX   = 0b00_00_01_01_01_10_00_00_00,
//XXX   = 0b00_00_01_01_01_10_01_00_00,
//XXX   = 0b00_00_01_01_01_10_10_00_00,


//XXX   = 0b00_00_01_01_10_00_00_00_00,
//XXX   = 0b00_00_01_01_10_00_01_00_00,
//XXX   = 0b00_00_01_01_10_00_10_00_00,

//XXX   = 0b00_00_01_01_10_01_00_00_00,
//XXX   = 0b00_00_01_01_10_01_01_00_00,
//XXX   = 0b00_00_01_01_10_01_10_00_00,

//XXX   = 0b00_00_01_01_10_10_00_00_00,
//XXX   = 0b00_00_01_01_10_10_01_00_00,
//XXX   = 0b00_00_01_01_10_10_10_00_00,

  // GATE OPS          3T ( 2 args ) | outputs to PREG only

//XXX   = 0b00_00_01_10_00_00_00_00_00, // - - -   + + +
  AND   = 0b00_00_01_10_00_00_01_00_00, // - 0 0   + 0 0  // MINIMUM
  NAN   = 0b00_00_01_10_00_00_10_00_00, // - 0 +   + 0 -

//XXX   = 0b00_00_01_10_00_01_00_00_00, // - 0 +   + 0 -
  ORR   = 0b00_00_01_10_00_01_01_00_00, // 0 0 +   0 0 -  // MAXIMUM
  NOR   = 0b00_00_01_10_00_01_10_00_00, // + + +   - - -

//XXX   = 0b00_00_01_10_00_10_00_00_00, // - 0 +   + 0 -
  XOR   = 0b00_00_01_10_00_10_01_00_00, // 0 0 0   0 0 0  // ???
  XNR   = 0b00_00_01_10_00_10_10_00_00, // + 0 -   - 0 +


//XXX   = 0b00_00_01_10_01_00_00_00_00, // - - 0   + + 0
  MAJ   = 0b00_00_01_10_01_00_01_00_00, // - 0 +   + 0 -  // (INV) MAJORITY
  IMJ   = 0b00_00_01_10_01_00_10_00_00, // 0 + +   0 - -

//XXX   = 0b00_00_01_10_01_01_00_00_00, // - 0 0   + 0 0
  CON   = 0b00_00_01_10_01_01_01_00_00, // 0 0 0   0 0 0  // (INV) CONSENSUS
  ICN   = 0b00_00_01_10_01_01_10_00_00, // 0 0 +   0 0 -

//XXX   = 0b00_00_01_10_01_10_01_00_00, // - 0 +   + 0 -
//XXX   = 0b00_00_01_10_01_10_10_00_00, // 0 + +   0 - -  // ???
//XXX   = 0b00_00_01_10_01_10_10_00_00, // + + +   - - -


//XXX   = 0b00_00_01_10_10_00_00_00_00, // + - -   - + +
  EQL   = 0b00_00_01_10_10_00_01_00_00, // - + -   + - +  // (IN)EQUALITY
  INE   = 0b00_00_01_10_10_00_10_00_00, // - - +   + + -

//XXX   = 0b00_00_01_10_10_01_00_00_00, // + 0 +   - 0 -
//XXX   = 0b00_00_01_10_10_01_01_00_00, // 0 - 0   0 + 0
//XXX   = 0b00_00_01_10_10_01_10_00_00, // + 0 +   - 0 -

//XXX   = 0b00_00_01_10_10_10_00_00_00, // + 0 +   - 0 -
//XXX   = 0b00_00_01_10_10_10_01_00_00, // 0 - 0   0 + 0
//XXX   = 0b00_00_01_10_10_10_10_00_00, // + 0 +   - 0 -

  // ???

//XXX   = 0b00_00_10_00_00_00_00_00_00,
//XXX   = 0b00_00_10_00_00_00_01_00_00,
//XXX   = 0b00_00_10_00_00_00_10_00_00,

//XXX   = 0b00_00_10_00_00_01_00_00_00,
//XXX   = 0b00_00_10_00_00_01_01_00_00,
//XXX   = 0b00_00_10_00_00_01_10_00_00,

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
  EXP   = 0b00_00_10_01_00_01_00_00_00, // A.var ^ B.var
  LOG   = 0b00_00_10_01_00_01_10_00_00, // LOG( A.var ) / LOG ( B.var )  NOTE : logB( A )

  DIV   = 0b00_00_10_01_00_10_01_00_00, // divide A.var by B.var         NOTE : rounds towards 0
  RND   = 0b00_00_10_01_00_10_10_00_00, // round  A.var by B.var         NOTE : rounds towards 0
  RUT   = 0b00_00_10_01_00_10_01_00_00, // A.var ^ ( 1 / B.var )         NOTE : rounds towards 0


  MAX   = 0b00_00_10_01_01_00_00_00_00, // MAX( A.var, B.var )
  MIN   = 0b00_00_10_01_01_00_01_00_00, // MIN( A.var, B.var )
//XXX   = 0b00_00_10_01_01_00_10_00_00,

  ADC   = 0b00_00_10_01_01_01_00_00_00, // ( A.var + B.var ) + CARRY trit
  SBB   = 0b00_00_10_01_01_01_01_00_00, // ( A.var - B.var ) - BORROW trit << TRYTE_SIZE - 1
//XXX   = 0b00_00_10_01_01_01_10_00_00, // ( A.var * B.var ) + C.var )   NOTE : only outputs to PREG

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

// ALU2 OPS            5T ( 4 args ) | outputs to D.adr

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
