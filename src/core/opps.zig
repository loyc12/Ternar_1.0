const std = @import( "std" );
const def = @import( "defs" );

// OPS FLAGS

// SIGN  | what the last ALU/CMP opp returned              ( -/0/+ )
// CARRY | wether the last ALU opp had a carry             (  -/+  )
// FLOW  | wether the last ALU opp under- or over-flowed   (  -/+  )

// STATE | if the process is stopping, running or resuming ( -/0/+ )
// STEP  | when to auto-inter. ( always, never, on jmp )   ( -/0/+ ) always, never, on jmp
// PERM  | where to delay gen. interrupts to               ( -/0/+ ) always, never, on jmp

// DIR   | which direction the CPU increments              ( -/0/+ ) 0 == halted
// SPEC  | 2 trits long
//       |  -- :
//       |  -0 :
//       |  -+ :
//       |  0- :
//       |  00 :
//       |  0+ :
//       |  +- :
//       |  +0 :
//       |  ++ :



// MEMORY LAYOUT

// 0      => working reg.   : 1 Tryte
// 1      => process addr.  : 1 Tryte
// 2      => flags.         : 1 Tryte
// 3-8    => fast registers : 6*1 Tryte
// 9-80   => small cache    : 72*1 Tryte
// 81-240 => large cache    : 72*9 Trytes
// 241 +  => gen. memory



pub const e_args = enum( u18 )
{
  //        ops type
  //        |  ops code
  //        |  |     ops subcode
  //        |  |     |     1st arg
  //        |  |     |     |     2nd arg
  //        |  |     |     |     |
  //        |  |     |     |     |
  //      . XX XX-XX XX-XX XX-XX XX-XX
  NOP   = 0b00_00_00_00_00_00_00_00_00, //                           ( skip )
  SUS   = 0b00_00_00_00_01_00_00_00_00, // suspends process          ( exit )
  WAI   = 0b00_00_00_00_10_00_00_00_00, // pauses process until flag ( wait )


  REG   = 0b00_XX_XX_XX_XX_XX_XX_XX_XX, // register operations    | 00_00 == working register
  CCH   = 0b01_XX_XX_XX_XX_XX_XX_XX_XX, // cache operations       | 00_00 == working register
  MEM   = 0b10_XX_XX_XX_XX_XX_XX_XX_XX, // gen. memory operations | 00_00 == working register

  //                                                              | ARG1     ARG2
  MOV   = 0bXX_00_01_XX_XX_XX_XX_XX_XX, // move from              | src  to  dst
  SWP   = 0bXX_00_10_XX_XX_XX_XX_XX_XX, // swap betwix            | src1 and src2
  CMP   = 0bXX_01_00_XX_XX_XX_XX_XX_XX, // comparisons betwix     | val1 and val2 ( only outputs to FLAGS )

  TRT   = 0bXX_01_01_XX_XX_XX_XX_XX_XX, // tritwise operations b. | val1 and *val2

    SHU = 0bXX_01_01_00_01_XX_XX_XX_XX, // shift up ( increments  )
    SHD = 0bXX_01_01_00_10_XX_XX_XX_XX, // shift up ( idecrements )

    RTU = 0bXX_01_01_01_01_XX_XX_XX_XX, // rotate up ( increments  )
    RTD = 0bXX_01_01_01_10_XX_XX_XX_XX, // rotate up ( idecrements )

    FLP = 0bXX_01_01_10_00_XX_XX_XX_XX, // flips trits around 0 ( - <=> + )
    FLU = 0bXX_01_01_10_01_XX_XX_XX_XX, // flips trits up       ( - => 0 => + => - )
    FLD = 0bXX_01_01_10_10_XX_XX_XX_XX, // flips trits down     ( - => + => 0 => - )

  MTH   = 0bXX_01_10_XX_XX_XX_XX_XX_XX, // math operations betwix | arg1 and arg2 ( also outputs to FLAGS )

    INC = 0bXX_01_00_00_01_XX_XX_XX_XX, // arg1++, *arg2++
    DEC = 0bXX_01_00_00_10_XX_XX_XX_XX, // arg1++, *arg2++

    ADD = 0bXX_01_00_01_01_XX_XX_XX_XX, // arg1 = add( arg1, arg2 )
    SUB = 0bXX_01_00_01_10_XX_XX_XX_XX, // arg1 = sub( arg1, arg2 )

    MUL = 0bXX_01_00_10_01_XX_XX_XX_XX, // arg1 = mul( arg1, arg2 )
    EXP = 0bXX_01_00_10_10_XX_XX_XX_XX, // arg1 = exp( arg1, arg2 )

    MOD = 0bXX_01_00_00_00_XX_XX_XX_XX, // arg1 = mod( arg1, arg2 )
    DIV = 0bXX_01_00_01_00_XX_XX_XX_XX, // arg1 = div( arg1, arg2 )
    MRT = 0bXX_01_00_10_00_XX_XX_XX_XX, // arg1 = root( arg2 of arg1 )

  XXX = 0bXX_10_00_XX_XX_XX_XX_XX_XX,

  //               -CONDITION- -ADR- ?
  JMP = 0bXX_10_01_XX_XX_XX_XX_XX_XX, // set the proc. addr. to | adr

  //                           -DST-
  SPE = 0bXX_10_10_XX_XX_XX_XX_XX_XX, // special opperations


  XXX = 0bXX_XX_XX_XX_XX_XX_XX_XX_XX,
  XXX = 0bXX_XX_XX_XX_XX_XX_XX_XX_XX,

};