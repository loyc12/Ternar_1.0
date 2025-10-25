const std = @import( "std" );
const def = @import( "defs" );

// =========================== PROCESS FLAGS ===========================

// F_SN => what the last ALU/CMP opp returned            ( -/0/+ ) sign flag
// F_CR => if the last ALU opp had a carry               (  -/+  ) carry flag
// F_BR => if the last ALU opp had a borrow              (  -/+  ) borrow flag
// F_FL => if the last ALU opp under- or over-flowed     (  -/+  ) over/under flow flag

// F_ST => if the process is quiting, running or pausing ( -/0/+ ) process state flag
// F_ER => wether the last op failed or succeeded        (  -/+  ) oper. error flag

// F_IS => when to auto-inter. ( always, never, on jmp ) ( -/0/+ ) inter. step step flag
// F_IP => when to allow non-auto interrupts ( idem )    ( -/0/+ ) inter. perm. flag
// F_?? => ? ( maybe interupt stuff )


// =========================== MEMORY LAYOUT ===========================

// ========= PUM =========
// processing units memory : 19_683 Trytes

// 0   POUT => process reg.    : 1  Tryte | default process work & output register
// 1   PADR => process adr.    : 1  Tryte | where the process pointer is currently at
// 2   PFLG => process flags   : 1  Tryte | ( see above for list )
// 3   PSTK => process stack   : 1  Tryte | adr. to top of currently used call stack ( delimited by null )
// 4   PSTP => step counter    : 1  Tryte | how many steps since process launche
// 5   ???? => ? ( maybe interupt stuff )
// 6   ???? => ? ( maybe interupt stuff )
// 7   RSEC => RAM sector reg. : 1  Tryte | upper half of any RAM adressing
// 8.1 OLEN => cur. op. lenght : 3  Trits | number of args the current ops has
// 8.2 ???? => TBA             : 3  Trits | ?
// 8.3 ???? => TBA             : 3  Trits | ?

// 9-26     => CPU fast  regs. : 18 Trytes
// 27-?     => CPU cache regs. : ?  Trytes

// ?-?      => I/O mapping reg.
// ?-?      => video memory    : 2x max resolution            move to RAM ?
// ?-?      => audio memory    : 1 sec of soundwaves          move to RAM ?
// ?-?      => boot protocol   : what to do on cold start     move to RAM ?
// ?-end    => adr. stack(s)   : size = max recursivity       move to RAM ?

// ========= RAM =========
// random access memory

// 0-end => general memory : 387_420_489 ( 19_683^2 ) Trytes
// NOTE : when addressing, uses the RSEC as the address' uper half ( lower half is arg )


// =========================== OPCODES ===========================
// NOTE : *arg means optional address/arg

pub const e_oper = enum( u18 ) // represents t9 Tryte
{
  // OPERATION SUBMASKS
  _IAS_ = 0b11_00_00_00_00_00_00_00_00, // input  adr. space
  _OAS_ = 0b00_11_00_00_00_00_00_00_00, // output adr. space
  _OTC_ = 0b00_00_11_11_11_11_00_00_00, // oper. type + code
  _OPT_ = 0b00_00_11_11_00_00_00_00_00, // oper. type
  _OPC_ = 0b00_00_00_00_11_11_00_00_00, // oper. code
  _SPC_ = 0b00_00_00_00_00_00_11_00_00, // proc. flow ops
  _EXC_ = 0b00_00_00_00_00_00_00_11_11, // exec. condition


  // INPUT SPACE |
  IPM   = 0b00_XX_XX_XX_XX_XX_XX_XX_XX, // PUM adresses
  IRM   = 0b01_XX_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( upper half in RAM sector reg. )
  IRL   = 0b10_XX_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( relative to proc. adr, signed )

  // OUTPUT SPACE | always outputs to process reg. as well
  OPM   = 0bXX_00_XX_XX_XX_XX_XX_XX_XX, // PUM adresses
  ORM   = 0bXX_01_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( upper half in RAM sector reg. )
  ORL   = 0bXX_10_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( relative to proc. adr, signed )

  // NOTE : RES being the default state ops also means any jump/call needs to set adr. to the Tryte BEFORE the intended target, although cassembler could remove that quirk automatically for non-min adr.
  // PROCESS STATE OPS | ?T ( ? arg ) | take effect after op is run, only if cond. fulfilled
  RES   = 0bXX_XX_XX_XX_XX_XX_00_XX_XX, // resume process   ( skip ) => sets STATE flag to 0 and increments process adr. by OLEN + 1
  SUS   = 0bXX_XX_XX_XX_XX_XX_01_XX_XX, // suspend process  ( exit ) => sets STATE flag to +
  INT   = 0bXX_XX_XX_XX_XX_XX_10_XX_XX, // interupt process ( wait ) => sets STATE flag to -

  // EXECUTION CONDITION | only execute opcode if ...
  ALW   = 0bXX_XX_XX_XX_XX_XX_XX_00_00, // ...always, unconditionally
  IFC   = 0bXX_XX_XX_XX_XX_XX_XX_00_01, // ...if CARRY or BORROW flag != 0
  IFF   = 0bXX_XX_XX_XX_XX_XX_XX_00_10, // ...if FLOW flag != 0

  IFZ   = 0bXX_XX_XX_XX_XX_XX_XX_01_00, // ...if SIGN flag == 0
  IFP   = 0bXX_XX_XX_XX_XX_XX_XX_01_01, // ...if SIGN flag == +
  IFN   = 0bXX_XX_XX_XX_XX_XX_XX_01_10, // ...if SIGN flag == -

  INZ   = 0bXX_XX_XX_XX_XX_XX_XX_10_00, // ...if SIGN flag != 0 // change for better flags ?
  INP   = 0bXX_XX_XX_XX_XX_XX_XX_10_01, // ...if SIGN flag != + // change for better flags ?
  INN   = 0bXX_XX_XX_XX_XX_XX_XX_10_10, // ...if SIGN flag != - // change for better flags ?

  // ========= OPERATION TYPE & CODE =========

  // PROCESS OPS | 2T ( 1 arg )
  JMP   = 0bXX_XX_00_00_01_00_XX_XX_XX, // set the process address to adr1.val
  CAL   = 0bXX_XX_00_00_01_01_XX_XX_XX, // PSH( proc. adr. ) + JMP( a1 )
  RET   = 0bXX_XX_00_00_01_10_XX_XX_XX, // JMP( POP() )                            NOTE : adr1 ignored

  PSH   = 0bXX_XX_00_00_10_00_XX_XX_XX, // pushes adr1.val into the process stack
  POP   = 0bXX_XX_00_00_10_01_XX_XX_XX, // pops from the process stack into adr1
  CLR   = 0bXX_XX_00_00_10_10_XX_XX_XX, // empties the process stack               NOTE : adr1 ignored

  SPA   = 0bXX_XX_00_01_00_00_XX_XX_XX, // sets the process stack adr. to adr1.val
  SRA   = 0bXX_XX_00_01_00_01_XX_XX_XX, // sets the process stack adr. to adr1.val
//XXX   = 0bXX_XX_00_01_00_10_XX_XX_XX, // sets the RAM sector address to adr1.val ( upper half of RAM I/O address space )

//XXX   = 0bXX_XX_00_01_01_00_XX_XX_XX,
//XXX   = 0bXX_XX_00_01_01_01_XX_XX_XX,
//XXX   = 0bXX_XX_00_01_01_10_XX_XX_XX,

  // MOVE OPS | 3T ( 2 args )
  MOV   = 0bXX_XX_00_01_10_00_XX_XX_XX, // copies adr1.val to adr2
  SWP   = 0bXX_XX_00_01_10_01_XX_XX_XX, // swaps vals betwix adr1 and adr2
  INF   = 0bXX_XX_00_01_10_10_XX_XX_XX, // writes device info to adr1, *adr2

  STR   = 0bXX_XX_00_10_00_00_XX_XX_XX, // writes process reg. val to adr1, *adr2
  LOD   = 0bXX_XX_00_10_00_01_XX_XX_XX, // reads adr1.val into process reg, *adr2
  STL   = 0bXX_XX_00_10_00_10_XX_XX_XX, // writes process reg. val to adr1 THEN eads adr1.val into process reg. ( STR + LOD )

//XXX   = 0bXX_XX_00_10_01_01_XX_XX_XX,
//XXX   = 0bXX_XX_00_10_01_00_XX_XX_XX,
//XXX   = 0bXX_XX_00_10_01_10_XX_XX_XX,

//XXX   = 0bXX_XX_00_10_10_00_XX_XX_XX,
//XXX   = 0bXX_XX_00_10_10_01_XX_XX_XX,
//XXX   = 0bXX_XX_00_10_10_10_XX_XX_XX,


  // TRIT1 OPS | 4T ( 3 args )        | in place ops. ( unless specified otherwise )
  INC   = 0bXX_XX_01_00_00_00_XX_XX_XX, // increment adr1.val, *adr2.val, *adr3.val
  DEC   = 0bXX_XX_01_00_00_01_XX_XX_XX, // decrement adr1.val, *adr2.val, *adr3.val
  INV   = 0bXX_XX_01_00_00_10_XX_XX_XX, // invert    adr1.val, *adr2.val, *adr3.val

  SHU   = 0bXX_XX_01_00_01_00_XX_XX_XX, // shift all trits up   by one in adr1.val, *adr2.val, *adr3.val
  SHD   = 0bXX_XX_01_00_01_01_XX_XX_XX, // shift all trits down by one in adr1.val, *adr2.val, *adr3.val
  SHV   = 0bXX_XX_01_00_01_10_XX_XX_XX, // shift all trits by adr1.val in adr2.val, *adr3.val

  RTU   = 0bXX_XX_01_00_10_00_XX_XX_XX, // rotate all trits up   by one in adr1.val, *adr2.val, *adr3.val
  RTD   = 0bXX_XX_01_00_10_01_XX_XX_XX, // rotate all trits down by one in adr1.val, *adr2.val, *adr3.val
  RTV   = 0bXX_XX_01_00_10_10_XX_XX_XX, // rotate all trits by adr1.val in adr2.val, *adr3.val

  FLP   = 0bXX_XX_01_01_00_00_XX_XX_XX, // flip the trits back-to-front for adr1.val, *adr2.val, *adr3.val
  PAB   = 0bXX_XX_01_01_00_01_XX_XX_XX, // finds the positive absolutes for adr1.val, *adr2.val, *adr3.val ( via INV call )
  NAB   = 0bXX_XX_01_01_00_10_XX_XX_XX, // finds the negative absolutes for adr1.val, *adr2.val, *adr3.val ( via INV call )

  // TRIT2 OPS | 4T ( 3 args )        | outputs to adr3.val ( unless specified otherwise )
  AND   = 0bXX_XX_01_01_01_00_XX_XX_XX,
  ORR   = 0bXX_XX_01_01_01_01_XX_XX_XX,
  XOR   = 0bXX_XX_01_01_01_10_XX_XX_XX,

  NAN   = 0bXX_XX_01_01_10_00_XX_XX_XX,
  NOR   = 0bXX_XX_01_01_10_01_XX_XX_XX,
  XNR   = 0bXX_XX_01_01_10_10_XX_XX_XX,

  CON   = 0bXX_XX_01_10_00_00_XX_XX_XX, // 1/2 => 1, else 2                   | determinacy     TODO : move to unary trit ops
  DET   = 0bXX_XX_01_10_00_01_XX_XX_XX, // 1 +   1 => 1, 2 +   2 => 2, else 0 | consensus
  MAJ   = 0bXX_XX_01_10_00_10_XX_XX_XX, // 1 + 0/1 => 1, 2 + 0/2 => 2, else 0 | majority

  NDT   = 0bXX_XX_01_10_01_00_XX_XX_XX, // 1/2 => 2, else 1                   | inv determinacy TODO : move to unary trit ops
  NCN   = 0bXX_XX_01_10_01_01_XX_XX_XX, // 1 + 1 =>   2, 2 +   2 => 1, else 0 | inv consensus
  NMJ   = 0bXX_XX_01_10_01_10_XX_XX_XX, // 1 + 0/1 => 2, 2 + 0/2 => 1, else 0 | inv majority

  MSK   = 0bXX_XX_01_10_10_00_XX_XX_XX, // 1 + 1/2 => 1/2, 2 + 1/2 => 2/1, else 0 ( mask & invmask ) NOTE : adr1 is masker, adr2 is maskee
//XXX   = 0bXX_XX_01_10_10_01_XX_XX_XX,
//XXX   = 0bXX_XX_01_10_10_10_XX_XX_XX,

  // ALU OPS | 4T ( 3 args )          | outputs to adr3.val ( unless specified otherwise )
  ADD   = 0bXX_XX_10_00_00_00_XX_XX_XX, // addition  adr2.val to   adr1.val
  SUB   = 0bXX_XX_10_00_00_01_XX_XX_XX, // substract adr2.val from adr1.val
  MUL   = 0bXX_XX_10_00_00_10_XX_XX_XX, // multiply  adr2.val with adr1.val

  MOD   = 0bXX_XX_10_00_01_00_XX_XX_XX, // modulo adr1.val by adr2.val
  DIV   = 0bXX_XX_10_00_01_01_XX_XX_XX, // divide adr1.val by adr2.val                           NOTE : rounded towards 0
  RND   = 0bXX_XX_10_00_01_10_XX_XX_XX, // round  adr1.val by adr2.val                           NOTE : rounded towards 0

  EXP   = 0bXX_XX_10_00_10_00_XX_XX_XX, // finds the adr1.val exponent or adr2.val
  ROT   = 0bXX_XX_10_00_10_01_XX_XX_XX, // finds the adr1.val root or adr2.val                   NOTE : rounded towards 0
  CMP   = 0bXX_XX_10_00_10_10_XX_XX_XX, // compares  adr1.val to adr2.val, setting the relevant process flag // TODO : move to binary trit ops ?

  MAX   = 0bXX_XX_10_01_00_00_XX_XX_XX, // finds the maximum betwix adr1.val, adr2.val
  MIN   = 0bXX_XX_10_01_00_01_XX_XX_XX, // finds the minimum betwix adr1.val, adr2.val
  MED   = 0bXX_XX_10_01_00_10_XX_XX_XX, // finds the median  betwix adr1.val, adr2.val, adr3.val NOTE : only outputs to proc. reg.

  ADC   = 0bXX_XX_10_01_01_00_XX_XX_XX, // ADD( a1 + a2, + CARRY trit )
  SBB   = 0bXX_XX_10_01_01_01_XX_XX_XX, // SUB( a1 - a2, - FLP( BORROW trit )
  MAD   = 0bXX_XX_10_01_01_10_XX_XX_XX, // ADD( MUL( a1, a2 ), a3 )                              NOTE : only outputs to proc. reg.

//XXX   = 0bXX_XX_10_01_10_00_XX_XX_XX,
//XXX   = 0bXX_XX_10_01_10_01_XX_XX_XX,
//XXX   = 0bXX_XX_10_01_10_10_XX_XX_XX,

//XXX   = 0bXX_XX_10_10_00_00_XX_XX_XX,
//XXX   = 0bXX_XX_10_10_00_01_XX_XX_XX,
//XXX   = 0bXX_XX_10_10_00_10_XX_XX_XX,

//XXX   = 0bXX_XX_10_10_01_00_XX_XX_XX,
//XXX   = 0bXX_XX_10_10_01_01_XX_XX_XX,
//XXX   = 0bXX_XX_10_10_01_10_XX_XX_XX,

//XXX   = 0bXX_XX_10_10_10_00_XX_XX_XX,
//XXX   = 0bXX_XX_10_10_10_01_XX_XX_XX,
//XXX   = 0bXX_XX_10_10_10_10_XX_XX_XX,
};
