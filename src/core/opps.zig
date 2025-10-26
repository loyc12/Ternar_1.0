const std = @import( "std" );
const def = @import( "defs" );

// =========================== PROCESS FLAGS ( PFLG ) ===========================

// F_SN => what the last ALU/CMP opp returned          ( -/0/+ ) sign flag
// F_CR => if the last ALU opp had a carry             (  -/+  ) carry flag           ( add )
// F_BR => if the last ALU opp had a borrow            (  -/+  ) borrow flag          ( sub )
// F_FL => if the last ALU opp under- or over-flowed   (  -/+  ) over/under flow flag ( add, sub. mul )

// F_ER => wether the last op failed or succeeded      (  -/+  ) operation error flag

// F_IS => when to auto-inter. ( on step, never, on jmp )       ( -/0/+ ) interupt-on-step flag
// F_ST => if the process is quiting, running or pausing        ( -/0/+ ) process state flag   TODO : check if useless ?
// F_IP => if the process can inter. itself( via SYS, no, yes ) ( -/0/+ ) interupt permissions
// F_?? => ?                                              NOTE : maybe interupt stuff


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

// NOTE : potential prots
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
// .val    : value at arg address
// .adr    : arg as an adfress
// .stk    : entire stack at adfress

pub const e_oper = enum( u18 ) // represents t9 Tryte
{
  // OPERATION SUBMASKS
  _IAS_ = 0b11_00_00_00_00_00_00_00_00, // input  adress space
  _OAS_ = 0b00_11_00_00_00_00_00_00_00, // output adress space
  _PFT_ = 0b00_00_11_00_00_00_00_00_00, // flow tags ( interupts and such )
  _OPN_ = 0b00_00_00_11_11_11_11_00_00, // operation names ( types & codes )
  _OPT_ = 0b00_00_00_11_11_00_00_00_00, // operation types
  _OPC_ = 0b00_00_00_00_00_11_11_00_00, // operation codes
  _EXC_ = 0b00_00_00_00_00_00_00_11_11, // execution conditions


  // INPUT SPACE                      | // adr. 0 is null
  I_PM  = 0b00_XX_XX_XX_XX_XX_XX_XX_XX, // PUM adresses
  I_RM  = 0b01_XX_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( upper half in RSEG )
  I_RL  = 0b10_XX_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( relative to PADR, signed )

  // OUTPUT SPACE                     | always outputs to PREG. as well
  O_PM  = 0bXX_00_XX_XX_XX_XX_XX_XX_XX, // PUM adresses
  O_RM  = 0bXX_01_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( upper half in RSEG )
  O_RL  = 0bXX_10_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( relative to PADR, signed )

  // NOTE : RES being the default state ops also means any jump/call needs to set adr. to the Tryte BEFORE
  //  V     the intended target, although assembly could remove that quirk automatically for non-min adr.

  // PROCESS FLOW TAGS                | take effect after op is run, only if cond. was fulfilled
  CNT   = 0bXX_XX_00_XX_XX_XX_XX_XX_XX, // step / resume process  ( continue  ) => sets F_ST to 0 and increments PREG.val by OLEN + 1
  TRM   = 0bXX_XX_01_XX_XX_XX_XX_XX_XX, // suspend / quit process ( terminate ) => sets F_ST to + and calls exit protocol  if F_IP allows
  YLD   = 0bXX_XX_10_XX_XX_XX_XX_XX_XX, // interupt process       ( yield     ) => sets F_ST to - and calls pause protocol if F_IP allows

  // OPERATION CONDITIONS             | only execute opcode if :
  ALW   = 0bXX_XX_XX_XX_XX_XX_XX_00_00, // always, unconditionally
  IFC   = 0bXX_XX_XX_XX_XX_XX_XX_00_01, // if F_CR or F_BR != 0
  IFF   = 0bXX_XX_XX_XX_XX_XX_XX_00_10, // if F_FL != 0

  IFZ   = 0bXX_XX_XX_XX_XX_XX_XX_01_00, // if F_SN == 0
  IFP   = 0bXX_XX_XX_XX_XX_XX_XX_01_01, // if F_SN == +
  IFN   = 0bXX_XX_XX_XX_XX_XX_XX_01_10, // if F_SN == -

  IAZ   = 0bXX_XX_XX_XX_XX_XX_XX_10_00, // if A.val == 0     TODO change for better conditions ?
  IAP   = 0bXX_XX_XX_XX_XX_XX_XX_10_01, // if A.val >  0     TODO change for better conditions ?
  IAN   = 0bXX_XX_XX_XX_XX_XX_XX_10_10, // if A.val <  0     TODO change for better conditions ?


  // ========= OPERATION TYPE & CODE =========

  // PROCESS OPS         2T ( 1 arg ) |
  NOP   = 0bXX_XX_XX_00_00_00_00_XX_XX, // do nothing, A.val times ( NOOP * A )
  SAV   = 0bXX_XX_XX_00_00_00_01_XX_XX, // save    CONTEXT to   A.adr ( first 81 Trytes of PUM )
  RST   = 0bXX_XX_XX_00_00_00_10_XX_XX, // restore CONTEXT from A.adr ( first 81 Trytes of PUM )

  SFL   = 0bXX_XX_XX_00_00_01_00_XX_XX, // sets PFLG.val to A.val
  GFL   = 0bXX_XX_XX_00_00_01_01_XX_XX, // sets A.val to PFLG.val
//XXX   = 0bXX_XX_XX_00_00_01_10_XX_XX, // NOTE : needs arbitrary stack manips

  INF   = 0bXX_XX_XX_00_00_10_00_XX_XX, // writes device info to A.adr
  SYS   = 0bXX_XX_XX_00_00_10_01_XX_XX, // sets F_ST to - and calls protocol # A.val if it exists, and F_IP allows
//XXX   = 0bXX_XX_XX_00_00_10_10_XX_XX, // NOTE : needs arbitrary stack manips

// FLOW OPS              2T ( 1 arg ) |
  PSH   = 0bXX_XX_XX_00_01_00_00_XX_XX, // pushes A.val into PSTK.stk
  POP   = 0bXX_XX_XX_00_01_00_01_XX_XX, // pops from PSTK.stk into A.adr
  CLR   = 0bXX_XX_XX_00_01_00_10_XX_XX, // empties the PSTK.stk          ( + SSA( A )? )

  JMP   = 0bXX_XX_XX_00_01_01_00_XX_XX, // set PADR to A.val
  CAL   = 0bXX_XX_XX_00_01_01_01_XX_XX, // PSH( PADR.val ) + JMP( A.val )
  RET   = 0bXX_XX_XX_00_01_01_10_XX_XX, // JMP( POP().val )              ( + SSA( A )? )

  SSA   = 0bXX_XX_XX_00_01_10_00_XX_XX, // sets PSTK.val to A.val
  SRA   = 0bXX_XX_XX_00_01_10_01_XX_XX, // sets RSEG.val to A.val ( upper half of RAM I/O address space )
//XXX   = 0bXX_XX_XX_00_01_10_10_XX_XX,

  // MOVE OPS           3T ( 2 args ) | in place ops
  SET   = 0bXX_XX_XX_00_10_00_00_XX_XX, // copies VAL into B.adr
  CPY   = 0bXX_XX_XX_00_10_00_01_XX_XX, // copies A.val to B.adr
  SWP   = 0bXX_XX_XX_00_10_00_10_XX_XX, // swaps A.val and B.val

  STR   = 0bXX_XX_XX_00_10_01_01_XX_XX, // writes PREG.val to  A.adr, *B.adr
  LOD   = 0bXX_XX_XX_00_10_01_00_XX_XX, // reads A.val into PREG.adr, *B.adr
  STL   = 0bXX_XX_XX_00_10_01_10_XX_XX, // STR( A ) + LOD( B )

  //                    4T ( 3 args ) |
  STM   = 0bXX_XX_XX_00_10_10_00_XX_XX, // SET( VAL, B++ ) C.val times
  CPM   = 0bXX_XX_XX_00_10_10_01_XX_XX, // CPY( A++, B++ ) C.val times
  SWM   = 0bXX_XX_XX_00_10_10_10_XX_XX, // SWP( A++, B++ ) C.val times

  // TRIT1 OPS          4T ( 3 args ) | in place ops.
  INC   = 0bXX_XX_XX_01_00_00_00_XX_XX, // increment     A.val, *B.val, *C.val
  DEC   = 0bXX_XX_XX_01_00_00_01_XX_XX, // decrement     A.val, *B.val, *C.val
  NEG   = 0bXX_XX_XX_01_00_00_10_XX_XX, // negate/invert A.val, *B.val, *C.val

  SHU   = 0bXX_XX_XX_01_00_01_00_XX_XX, // shift all trits up   by one in A.val, *B.val, *C.val
  SHD   = 0bXX_XX_XX_01_00_01_01_XX_XX, // shift all trits down by one in A.val, *B.val, *C.val
  SHV   = 0bXX_XX_XX_01_00_01_10_XX_XX, // shift all trits by A.val    in B.val, *C.val

  RTU   = 0bXX_XX_XX_01_00_10_00_XX_XX, // rotate all trits up   by one in A.val, *B.val, *C.val
  RTD   = 0bXX_XX_XX_01_00_10_01_XX_XX, // rotate all trits down by one in A.val, *B.val, *C.val
  RTV   = 0bXX_XX_XX_01_00_10_10_XX_XX, // rotate all trits by A.val    in B.val, *C.val

  FLP   = 0bXX_XX_XX_01_01_00_00_XX_XX, // flip all trits back-to-front for A.val, *B.val, *C.val
  PAB   = 0bXX_XX_XX_01_01_00_01_XX_XX, // finds the positive absolutes for A.val, *B.val, *C.val ( via NEG call ) NOTE could be done with opconds ?
  NAB   = 0bXX_XX_XX_01_01_00_10_XX_XX, // finds the negative absolutes for A.val, *B.val, *C.val ( via NEG call ) NOTE could be done with opconds ?

  MAG   = 0bXX_XX_XX_01_01_01_00_XX_XX, // finds the lenght of A.val, *B.val, *c.val in trits ( negative if MST is negative )
  DET   = 0bXX_XX_XX_01_01_01_01_XX_XX, // 1/2 => 1, else 2 | determinacy
  NDT   = 0bXX_XX_XX_01_01_01_10_XX_XX, // 1/2 => 2, else 1 | inv determinacy

//XXX   = 0bXX_XX_XX_01_01_10_00_XX_XX,
//XXX   = 0bXX_XX_XX_01_01_10_01_XX_XX,
//XXX   = 0bXX_XX_XX_01_01_10_10_XX_XX,

  // TRIT2 OPS          4T ( 3 args ) | outputs to C.adr
  AND   = 0bXX_XX_XX_01_10_00_00_XX_XX,
  ORR   = 0bXX_XX_XX_01_10_00_01_XX_XX,
  XOR   = 0bXX_XX_XX_01_10_00_10_XX_XX,

  NAN   = 0bXX_XX_XX_01_10_01_00_XX_XX,
  NOR   = 0bXX_XX_XX_01_10_01_01_XX_XX,
  XNR   = 0bXX_XX_XX_01_10_01_10_XX_XX,

  MSK   = 0bXX_XX_XX_01_10_10_00_XX_XX, // 1 + 1/2 => 1/2, 2 + 1/2 => 2/1, else 0 | masking    NOTE : A is masker, B is maskee
  CON   = 0bXX_XX_XX_01_10_10_01_XX_XX, // 1 +   1 => 1,   2 +   2 => 2,   else 0 | consensus
  MAJ   = 0bXX_XX_XX_01_10_10_10_XX_XX, // 1 + 0/1 => 1,   2 + 0/2 => 2,   else 0 | majority

  CMP   = 0bXX_XX_XX_10_00_00_00_XX_XX, // A.val >/=/< B.val, updating PFLGs
//CMV   = 0bXX_XX_XX_10_00_00_01_XX_XX, // A.val >/=/< VAL, updating PFLGs
//XXX   = 0bXX_XX_XX_10_00_00_10_XX_XX,

//XXX   = 0bXX_XX_XX_10_00_01_00_XX_XX,
  NCN   = 0bXX_XX_XX_10_00_01_01_XX_XX, // 1 + 1 =>   2, 2 +   2 => 1, else 0     | inv consensus
  NMJ   = 0bXX_XX_XX_10_00_01_10_XX_XX, // 1 + 0/1 => 2, 2 + 0/2 => 1, else 0     | inv majority

//XXX   = 0bXX_XX_XX_10_00_10_00_XX_XX,
//XXX   = 0bXX_XX_XX_10_00_10_01_XX_XX,
//XXX   = 0bXX_XX_XX_10_00_10_10_XX_XX,

  // ALU OPS            4T ( 3 args ) | outputs to C.adr ( except for MED and MAD )
  ADD   = 0bXX_XX_XX_10_01_00_00_XX_XX, // addition  B.val to   A.val
  SUB   = 0bXX_XX_XX_10_01_00_01_XX_XX, // substract B.val from A.val
  MUL   = 0bXX_XX_XX_10_01_00_10_XX_XX, // multiply  B.val with A.val

  MOD   = 0bXX_XX_XX_10_01_01_00_XX_XX, // modulo A.val by B.val
  EXP   = 0bXX_XX_XX_10_01_01_00_XX_XX, // A.val ^ B.val
  LOG   = 0bXX_XX_XX_10_01_01_10_XX_XX, // LOG( A.val ) / LOG ( B.val )  NOTE : logB( A )

  DIV   = 0bXX_XX_XX_10_01_10_01_XX_XX, // divide A.val by B.val         NOTE : rounds towards 0
  RND   = 0bXX_XX_XX_10_01_10_10_XX_XX, // round  A.val by B.val         NOTE : rounds towards 0
  RUT   = 0bXX_XX_XX_10_01_10_01_XX_XX, // A.val ^ ( 1 / B.val )         NOTE : rounds towards 0

  MAX   = 0bXX_XX_XX_10_10_00_00_XX_XX, // MAX( A.val, B.val )
  MIN   = 0bXX_XX_XX_10_10_00_01_XX_XX, // MIN( A.val, B.val )
  MED   = 0bXX_XX_XX_10_10_00_10_XX_XX, // MED( A.val, B.val, C.val )    NOTE : only outputs to PREG

  ADC   = 0bXX_XX_XX_10_10_01_00_XX_XX, // ( A.val + B.val ) + CARRY trit
  SBB   = 0bXX_XX_XX_10_10_01_01_XX_XX, // ( A.val - B.val ) - FLP( BORROW trit
  MAD   = 0bXX_XX_XX_10_10_01_10_XX_XX, // ( A.val * B.val ) + C.val )   NOTE : only outputs to PREG

  SQR   = 0bXX_XX_XX_10_10_10_00_XX_XX, // ( A.val + *B.val ) ^ 2        NOTE : is this useful ?
  CUB   = 0bXX_XX_XX_10_10_10_01_XX_XX, // ( A.val + *B.val ) ^ 3        NOTE : is this useful ?
  MDT   = 0bXX_XX_XX_10_10_10_10_XX_XX, // ( A.val + *B.val ) % 3        NOTE : is this useful ?
};
