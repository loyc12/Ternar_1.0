const std = @import( "std" );
const def = @import( "defs" );

// =========================== PROCESS FLAGS ===========================

// SIGN  | what the last ALU/CMP opp returned              ( -/0/+ )
// CARRY | wether the last ALU opp had a carry             (  -/+  )
// BORROW| wether the last ALU opp had a borrow            (  -/+  )
// FLOW  | wether the last ALU opp under- or over-flowed   (  -/+  )

// STATE | if the process is stopping, running or resuming ( -/0/+ )
// STEP  | when to auto-inter. ( always, never, on jmp )   ( -/0/+ ) always, never, on jmp
// PERM  | where to delay gen. interrupts to               ( -/0/+ ) always, never, on jmp

// LEN   | lenght of the current operation                 ( -/0/+ ) 1, 2 or 3 args passed
// ERR   | execution status of the last operation          ( -/0/+ ) failed, unknown, succeeded


// =========================== MEMORY LAYOUT ===========================

// ========= PUM =========
// processing units memory

// 0      => process reg.   : 1 Tryte |
// 1      => process adr.   : 1 Tryte | where the process pointer is currently at
// 2      => process flags  : 1 Tryte |
// 3      => process stack  : 1 Tryte |

// 4-8    => fast registers : 5 Trytes
// 9-80   => slow registers : 72 Trytes
// 81-240 => CPU cache reg. : 169 Trytes

// 241-?  => I/O mapping reg.
// ?-?    => video memory  : 2x max resolution
// ?-?    => audio memory  : 1 sec of soundwaves
// ?-?    => adr. stack(s) : size = max recursivity
// ?-end  => boot protocol : what to do on cold start

// ========= RAM =========
// random access memory

// 0-end  => general memory


// =========================== OPCODES ===========================

pub const e_oper = enum( u18 )
{
  //       in. adr. space
  //        |  oper. type
  //        |  |     oper. code
  //        |  |     |     exec. condition
  //        |  |     |     |     spec. code
  //        |  |     |     |     |  out. adr. space
  //        |  |     |     |     |  |
  //      0bFF_XX-XX_XX-XX_FF-FF_FF_FF,

  // SPECIAL OPERATIONS | // TODO : expand these for interupts
  NOP   = 0bXX_00_00_00_00_XX_XX_XX_XX, // do nothing                ( skip )
  SUS   = 0bXX_XX_XX_XX_XX_XX_XX_01_XX, // close process after op.   ( exit )
//WAI   = 0bXX_XX_XX_XX_XX_XX_XX_10_XX, // suspend process after op. ( wait )

  // INPUT SPACE |
  IPM   = 0b00_XX_XX_XX_XX_XX_XX_XX_XX, // PUM adresses
  IRM   = 0b01_XX_XX_XX_XX_XX_XX_XX_XX, // RAM adresses
  IRL   = 0b10_XX_XX_XX_XX_XX_XX_XX_XX, // RAM adresses ( process adr. relative )

  // OUTPUT SPACE | always outputs to process reg. as well
  OPM   = 0bXX_XX_XX_XX_XX_XX_XX_XX_00, // PUM adresses
  ORM   = 0bXX_XX_XX_XX_XX_XX_XX_XX_01, // RAM adresses
  ORL   = 0bXX_XX_XX_XX_XX_XX_XX_XX_10, // RAM adresses ( process adr. relative )

  // EXECUTION CONDITION | only execute opcode if ...
  ALW   = 0bXX_XX_XX_XX_XX_00_00_XX_XX, // ...always, unconditionally
  IFC   = 0bXX_XX_XX_XX_XX_00_01_XX_XX, // ...if carry flag != 0
  IFF   = 0bXX_XX_XX_XX_XX_00_10_XX_XX, // ...if flow flag != 0

  IFZ   = 0bXX_XX_XX_XX_XX_01_00_XX_XX, // ...if sign flag == 0
  IFP   = 0bXX_XX_XX_XX_XX_01_01_XX_XX, // ...if sign flag == +
  IFN   = 0bXX_XX_XX_XX_XX_01_10_XX_XX, // ...if sign flag == -

  INZ   = 0bXX_XX_XX_XX_XX_10_00_XX_XX, // ...if sign flag != 0
  INP   = 0bXX_XX_XX_XX_XX_10_01_XX_XX, // ...if sign flag != +
  INN   = 0bXX_XX_XX_XX_XX_10_10_XX_XX, // ...if sign flag != -

  // ========= OPERATION TYPE & CODE =========

  // PROCESS ADR. OPS | 2T ( 1 arg )
  JMP   = 0bXX_00_00_01_00_XX_XX_XX_XX, // > set the process address to adr1.val
  CAL   = 0bXX_00_00_01_01_XX_XX_XX_XX, // > PSH( proc. adr. ) + JMP( a1 )
  RET   = 0bXX_00_00_01_10_XX_XX_XX_XX, // > JMP( POP() )                              NOTE : adr1 ignored

//XXX   = 0bXX_00_00_10_00_XX_XX_XX_XX,
//XXX   = 0bXX_00_00_10_01_XX_XX_XX_XX, // ICAL
//XXX   = 0bXX_00_00_10_10_XX_XX_XX_XX, // IRET

  // PROCESS STACK OPS | 2T ( 1 arg )
  PSH   = 0bXX_00_01_00_00_XX_XX_XX_XX, // pushes adr1.val into the process stack
  POP   = 0bXX_00_01_00_01_XX_XX_XX_XX, // pops from the process stack into adr1
  CLR   = 0bXX_00_01_00_10_XX_XX_XX_XX, // empties the process stack                  NOTE : adr1 ignored

  SPA   = 0bXX_00_01_01_00_XX_XX_XX_XX, // sets the process stack's adr. to adr1.val
//XXX   = 0bXX_00_01_01_01_XX_XX_XX_XX,
//XXX   = 0bXX_00_01_01_10_XX_XX_XX_XX,

//XXX   = 0bXX_00_01_10_00_XX_XX_XX_XX,
//XXX   = 0bXX_00_01_10_01_XX_XX_XX_XX,
//XXX   = 0bXX_00_01_10_10_XX_XX_XX_XX,

  // MOVE OPS | 3T ( 2 args )
  MOV   = 0bXX_00_10_00_00_XX_XX_XX_XX, // copies adr1.val to adr2
  SWP   = 0bXX_00_10_00_01_XX_XX_XX_XX, // swaps vals betwix adr1 and adr2
//INF   = 0bXX_00_10_00_10_XX_XX_XX_XX, // writes device info to adr1, *adr2

  STR   = 0bXX_00_10_01_01_XX_XX_XX_XX, // writes process reg. val to adr1, *adr2
  LOD   = 0bXX_00_10_01_00_XX_XX_XX_XX, // reads adr1.val into process reg, *adr2
  STL   = 0bXX_00_10_01_10_XX_XX_XX_XX, // writes process reg. val to adr1 THEN eads adr1.val into process reg. ( STR + LOD )

//XXX   = 0bXX_00_10_10_00_XX_XX_XX_XX,
//XXX   = 0bXX_00_10_10_01_XX_XX_XX_XX,
//XXX   = 0bXX_00_10_10_10_XX_XX_XX_XX,


  // TRIT OPS | 3T ( 2 args ) | in place operations
  INC   = 0bXX_01_00_00_00_XX_XX_XX_XX, // increment adr1.val, *adr2.val
  DEC   = 0bXX_01_00_00_01_XX_XX_XX_XX, // decrement adr1.val, *adr2.val
  INV   = 0bXX_01_00_00_10_XX_XX_XX_XX, // invert    adr1.val, *adr2.val

  SHU   = 0bXX_01_00_01_00_XX_XX_XX_XX, // shift all trits up by one in adr1,   *adr2.val
  SHD   = 0bXX_01_00_01_01_XX_XX_XX_XX, // shift all trits down by one in adr1, *adr2.val
  SHV   = 0bXX_01_00_01_10_XX_XX_XX_XX, // shift all trits by adr1.val in adr2

  RTU   = 0bXX_01_00_10_00_XX_XX_XX_XX, // rotate all trits up by one in adr1,   *adr2.val
  RTD   = 0bXX_01_00_10_01_XX_XX_XX_XX, // rotate all trits down by one in adr1, *adr2.val
  RTV   = 0bXX_01_00_10_10_XX_XX_XX_XX, // rotate all trits by adr1.val in adr2

  FLP   = 0bXX_01_01_00_00_XX_XX_XX_XX, // flip the trits around inside the trite ( 100 -> 001 )
  PAB   = 0bXX_01_01_00_01_XX_XX_XX_XX, // positive absolute of adr1.val, *adr2.val ( calls INV if need be )
  NAB   = 0bXX_01_01_00_10_XX_XX_XX_XX, // negative absolute of adr1.val, *adr2.val ( calls INV if need be )

  // the following ops override adr1 and not // TODO : revise organisation ( 4T for output arg ? )
  AND   = 0bXX_01_01_01_00_XX_XX_XX_XX,
  ORR   = 0bXX_01_01_01_01_XX_XX_XX_XX,
  XOR   = 0bXX_01_01_01_10_XX_XX_XX_XX,

  NAN   = 0bXX_01_01_10_00_XX_XX_XX_XX,
  NOR   = 0bXX_01_01_10_01_XX_XX_XX_XX,
  XNR   = 0bXX_01_01_10_10_XX_XX_XX_XX,

  CON   = 0bXX_01_10_00_00_XX_XX_XX_XX, // 1/2 => 1, else 2                   ( determinacy ) ( unary )
  DET   = 0bXX_01_10_00_01_XX_XX_XX_XX, // 1 +   1 => 1, 2 +   2 => 2, else 0 ( consensus )
  MAJ   = 0bXX_01_10_00_10_XX_XX_XX_XX, // 1 + 0/1 => 1, 2 + 0/2 => 2, else 0 ( majority )

  NDT   = 0bXX_01_10_01_00_XX_XX_XX_XX, // 1/2 => 2, else 1                   ( determinacy ) ( unary )
  NCN   = 0bXX_01_10_01_01_XX_XX_XX_XX, // 1 + 1 =>   2, 2 +   2 => 1, else 0 ( consensus )
  NMJ   = 0bXX_01_10_01_10_XX_XX_XX_XX, // 1 + 0/1 => 2, 2 + 0/2 => 1, else 0 ( majority )

//XXX   = 0bXX_01_10_10_00_XX_XX_XX_XX,
//XXX   = 0bXX_01_10_10_01_XX_XX_XX_XX,
//XXX   = 0bXX_01_10_10_10_XX_XX_XX_XX,

  // ALU OPS | 4T ( 3 args )
  ADD   = 0bXX_10_00_00_00_XX_XX_XX_XX, // addition  adr2.val to   adr1.val, then outputs to adr3
  SUB   = 0bXX_10_00_00_01_XX_XX_XX_XX, // substract adr2.val from adr1.val, then outputs to adr3
  MUL   = 0bXX_10_00_00_10_XX_XX_XX_XX, // multiply  adr2.val with adr1.val, then outputs to adr3

  MOD   = 0bXX_10_00_01_00_XX_XX_XX_XX, // modulo adr1.val by adr2.val, then outputs to adr3
  DIV   = 0bXX_10_00_01_01_XX_XX_XX_XX, // divide adr1.val by adr2.val, then outputs to adr3 ( rounded towards 0 )
  RND   = 0bXX_10_00_01_10_XX_XX_XX_XX, // round  adr1.val by adr2.val, then outputs to adr3 ( rounded towards 0 )

  EXP   = 0bXX_10_00_10_00_XX_XX_XX_XX, // finds the adr1.val exponent or adr2.val
  ROT   = 0bXX_10_00_10_01_XX_XX_XX_XX, // finds the adr1.val root or adr2.val     ( rounded towards 0 )
  CMP   = 0bXX_10_00_10_10_XX_XX_XX_XX, // compares  adr1.val to adr2.val, setting the relevant process flag

  MAX   = 0bXX_10_01_00_00_XX_XX_XX_XX, // finds the maximum betwix adr1.val, adr2.val, then outputs to adr3
  MIN   = 0bXX_10_01_00_01_XX_XX_XX_XX, // finds the minimum betwix adr1.val, adr2.val, then outputs to adr3
  MED   = 0bXX_10_01_00_10_XX_XX_XX_XX, // finds the median  betwix adr1.val, adr2.val, adr3.val ( only outputs to proc. reg. )

  ADC   = 0bXX_10_01_01_00_XX_XX_XX_XX, // ADD( a1 + a2, + carry trit )
  SBB   = 0bXX_10_01_01_01_XX_XX_XX_XX, // SUB( a1 - a2, - FLP( borrow trit )
  MAD   = 0bXX_10_01_01_10_XX_XX_XX_XX, // ADD( MUL( a1, a2 ), a3 )

//XXX   = 0bXX_10_01_10_00_XX_XX_XX_XX,
//XXX   = 0bXX_10_01_10_01_XX_XX_XX_XX,
//XXX   = 0bXX_10_01_10_10_XX_XX_XX_XX,

//XXX   = 0bXX_10_10_00_00_XX_XX_XX_XX,
//XXX   = 0bXX_10_10_00_01_XX_XX_XX_XX,
//XXX   = 0bXX_10_10_00_10_XX_XX_XX_XX,

//XXX   = 0bXX_10_10_01_00_XX_XX_XX_XX,
//XXX   = 0bXX_10_10_01_01_XX_XX_XX_XX,
//XXX   = 0bXX_10_10_01_10_XX_XX_XX_XX,

//XXX   = 0bXX_10_10_10_00_XX_XX_XX_XX,
//XXX   = 0bXX_10_10_10_01_XX_XX_XX_XX,
//XXX   = 0bXX_10_10_10_10_XX_XX_XX_XX,
};
