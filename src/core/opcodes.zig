const std = @import( "std" );
const def = @import( "defs" );

const Tryte = def.Tryte;



// ========= OP FUNCTIONS =========

/// Only accepts OpCode's SUBMASKS
pub inline fn getOpComp( op : Tryte, mask : OpCodeMask ) u18
{
  return ( op & @intFromEnum( mask ));
}

/// Only accepts OpCode's SUBMASKS
pub inline fn getOpCompShifted( op : Tryte, mask : OpCodeMask ) u18
{
  const maskOffset = mask.getRightBitOffset();
  const opComp     = getOpComp( op, mask );

  return opComp >> maskOffset;
}

pub inline fn getOpLen( op : Tryte ) ?u18
{
  const opType = getOpCompShifted( op, ._OPT_ ); // Always valid

  switch( opType )
  {
    0b00_00 => return( 1 + 1 ), // SYSTEM
    0b00_01 => return( 1 + 1 ), // PROCESS
    0b00_10 => return( 1 + 2 ), // MOVE
    0b01_00 => return( 1 + 1 ), // TRIT 1
    0b01_01 => return( 1 + 2 ), // TRIT 2
    0b01_10 => return( 1 + 3 ), // TRIT 3
    0b10_00 => return( 1 + 3 ), // ALU  1
    0b10_01 => return( 1 + 4 ), // ALU  2
    0b10_10 => return( 1 + 3 ), // VECTOR
    else    =>
    {
      def.qlog( .ERROR, 0, @src(), "unrecognized opType" );
      return null;
    }
  }
}


// =========================== PUM MEMORY LAYOUT ===========================
// processing unit memory ( page 0 ) : 19_683 Trytes

// NOTE : CONTEXT = PRG + PCR

// ========= PRG : process registers =========

pub const PRegTryte = enum( u4 ) // TODO : add more work regs ?
{
  R_PREG = 0, // process reg.    : process output register
  R_PADR = 1, // process adr.    : where the process pointer is currently at
  R_PFLG = 2, // process flags   : ( see above for list )
  R_PSTK = 3, // process stack   : adr. to top of currently used call stack ( delimited by nulls )
  R_MSEG = 4, // RAM segment     : upper half of any RAM adressing ( page / sector HADR )
//R_XXXX = 5, // TBA             :
//R_XXXX = 6, // TBA             :
//R_XXXX = 7, // TBA             :
  R_STEP = 8, // step counter    : how many steps since process launched
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

// NOTE : when addressing, uses the R_MSEG as the address' uper half ( lower half is arg )

// 0-? => general memory
// ?-? => audio   memory   : 1 sec of soundwaves
// ?-? => video   memory   : 3x max resolution


// =========================== OPCODES SUBMASKS ===========================
// NOTE : masks are always in _SCREAMING_SNAKECASE_

pub const OpCodeMask = enum( u18 )
{
  _IAS_ = 0b11_00_00_00_00_00_00_00_00, // input  adress space
  _OAS_ = 0b00_11_00_00_00_00_00_00_00, // output adress space
  _EXC_ = 0b00_00_00_00_00_00_00_11_11, // execution conditions
  _OPN_ = 0b00_00_11_11_11_11_11_00_00, // operation names ( types & codes )
  _OPT_ = 0b00_00_11_11_00_00_00_00_00, // operation types
  _OPC_ = 0b00_00_00_00_11_11_11_00_00, // operation codes

  pub fn getRightBitOffset( self : OpCodeMask ) u5
  {
    return def.BITS_PER_TRIT * self.getRightTritOffset();
  }
  pub fn getRightTritOffset( self : OpCodeMask ) u5
  {
    return switch( self )
    {
      ._IAS_ => 8,
      ._OAS_ => 7,
      ._EXC_ => 0,
      ._OPN_ => 2,
      ._OPT_ => 5,
      ._OPC_ => 2,
    };
  }

  pub fn getLeftBitOffset( self : OpCodeMask ) u5
  {
    return def.BITS_PER_TRIT * self.getLeftTritOffset();
  }
  pub fn getLeftTritOffset( self : OpCodeMask ) u5
  {
    return switch( self )
    {
      ._IAS_ => 0,
      ._OAS_ => 1,
      ._EXC_ => 7,
      ._OPN_ => 2,
      ._OPT_ => 2,
      ._OPC_ => 4,
    };
  }
};


// =========================== PROCESS FLAGS ( TRITS OF R_PFLG ) ===========================

pub const PFlagTrit = enum( u4 )
{
  F_SN = 0, // what the last ALU/CMPR op returned                     ( -/0/+ ) sign flag
  F_OV = 1, // if the last add/sub op overflowed                      ( -/0/+ ) add overflow flag ( add / sub )
  F_XC = 2, // if the last mul/div op overflowed                      ( -/0/+ ) mul overflow flag ( mul / div )
//F_XX = 3, // TBA
  F_OR = 4, // whether the last opcond was false, skipped or true     ( -/0/+ ) opcond result flag
  F_OM = 5, // how to modify the next opcond ( inv, skip )            ( -/0/+ ) opcond modifier flag
  F_IS = 6, // when to auto-inter. ( on step, never, on jmp )         ( -/0/+ ) interupt-on-step flag
  F_ST = 7, // if the process is quiting, running or pausing          ( -/0/+ ) process state flag   TODO : check if useless ?
  F_IP = 8, // if the process can inter. itself( via SYSC, no, yes )  ( -/0/+ ) interupt permissions
};


// =========================== OPCODES ===========================

// ========= NOMENCLATURE =========
// A, B, C : arg1 / 2 / 3 / etc
//  arg    : mandatory arg
// *arg    : optional arg ( can be zero - simply won't do anything  )
// .adr    : arg as an address
// .var    : value at arg's address
// .stk    : entire stack at address
//
//      B-
//      | B0
//      | | B+
//
//  A-  t t t   // NOTE : truth table layout
//  A0  t t t
//  A+  t t t

pub const OpCode = enum( u18 ) // represents 9 Trits ( 1 Tryte )
{
  // ========= OPERATION MODIFIERS =========

  // INPUT SPACE  |
  pub const I_VAL : u18 = 0b00_00_00_00_00_00_00_00_00; // raw values   ( in-place ops stored in prog. as static val. )
  pub const I_ADR : u18 = 0b01_00_00_00_00_00_00_00_00; // RAM adresses ( upper half of the address in R_MSEG )
  pub const I_RAM : u18 = 0b10_00_00_00_00_00_00_00_00; // RAM adresses ( relative to current R_PADR.var, signed )

  // OUTPUT SPACE | always outputs to R_PREG as well
  pub const O_VAL : u18 = 0b00_00_00_00_00_00_00_00_00; // raw values   ( in-place ops stored in prog. as static val. )
  pub const O_ADR : u18 = 0b00_01_00_00_00_00_00_00_00; // RAM adresses ( upper half of the address in R_MSEG )
  pub const O_RAM : u18 = 0b00_10_00_00_00_00_00_00_00; // RAM adresses ( relative to current R_PADR.var, signed )

  // OP CONDITION | only execute opcode if :
  pub const C_ALW : u18 = 0b00_00_00_00_00_00_00_00_00; // always, unconditionally
  pub const C_IFC : u18 = 0b00_00_00_00_00_00_00_00_01; // if F_OV != 0
  pub const C_IFF : u18 = 0b00_00_00_00_00_00_00_00_10; // if F_XC != 0

  pub const C_IFZ : u18 = 0b00_00_00_00_00_00_00_01_00; // if F_SN != 0
  pub const C_IFP : u18 = 0b00_00_00_00_00_00_00_01_01; // if F_SN != +
  pub const C_IFN : u18 = 0b00_00_00_00_00_00_00_01_10; // if F_SN != -

  pub const C_INV : u18 = 0b00_00_00_00_00_00_00_10_00; // set F_SK to - to invert the next condition check's result
  pub const C_SKP : u18 = 0b00_00_00_00_00_00_00_10_01; // set F_SK to + to avoid the next condition check ( acts like C_ALW  )
//pub const C_XXX : u18 = 0b00_00_00_00_00_00_00_10_10;


  // ========= OPERATION NAMES ( TYPE & CODE ) =========

  // NOTE : encoding layout per opcode ( 9 trits, each trit = 2 bits )
  // format : 0b IAS OAS OPT1 OPT0 OPC2 OPC1 OPC0 EXC1 EXC0
  // all base encodings have IAS/OAS/EXC == 00 ( modifiers applied at runtime )

  // SYSTEM OPS         2T ( *1 arg ) | NOTE : CONT/TERM/YILD treat A as optional

  NOPE  = 0b00_00_00_00_00_00_00_00_00, // do nothing                                    ( *A = reserved )
  WAIT  = 0b00_00_00_00_00_00_01_00_00, // stall A.var cycles before advancing
  HALT  = 0b00_00_00_00_00_00_10_00_00, // hard halt with code A.var                     ( bypasses F_IP )

  INFO  = 0b00_00_00_00_00_01_00_00_00, // write device info block to A.adr
  SFLG  = 0b00_00_00_00_00_01_01_00_00, // set R_PFLG to A.var
  GFLG  = 0b00_00_00_00_00_01_10_00_00, // read R_PFLG.var => R_PREG, write to *A.adr

  PRNT  = 0b00_00_00_00_00_10_00_00_00, // write A.var to terminal output
  DBUG  = 0b00_00_00_00_00_10_01_00_00, // debug-dump tryte block starting at A.adr
//XXXX  = 0b00_00_00_00_00_10_10_00_00,

  SYSC  = 0b00_00_00_00_01_00_00_00_00, // syscall #A.var                                ( requires F_IP permission )
//XXXX  = 0b00_00_00_00_01_00_01_00_00,
//XXXX  = 0b00_00_00_00_01_00_10_00_00,

//XXXX  = 0b00_00_00_00_01_01_00_00_00,
//XXXX  = 0b00_00_00_00_01_01_01_00_00,
//XXXX  = 0b00_00_00_00_01_01_10_00_00,

//XXXX  = 0b00_00_00_00_01_10_00_00_00,
//XXXX  = 0b00_00_00_00_01_10_01_00_00,
//XXXX  = 0b00_00_00_00_01_10_10_00_00,

//XXXX  = 0b00_00_00_00_10_00_00_00_00,
//XXXX  = 0b00_00_00_00_10_00_01_00_00,
//XXXX  = 0b00_00_00_00_10_00_10_00_00,

  // sys macros                       | NOTE : *A treated as optional hint ( exit code, yield reason, etc. )
  CONT  = 0b00_00_00_00_10_01_00_00_00, // resume process     => F_ST = 0
  TERM  = 0b00_00_00_00_10_01_01_00_00, // terminate process  => F_ST = +,  calls exit  protocol if F_IP allows
  YILD  = 0b00_00_00_00_10_01_10_00_00, // yield process      => F_ST = -,  calls pause protocol if F_IP allows

//XXXX  = 0b00_00_00_00_10_10_00_00_00,
//XXXX  = 0b00_00_00_00_10_10_01_00_00,
//XXXX  = 0b00_00_00_00_10_10_10_00_00,

  // PROCESS OPS         2T ( 1 arg ) |

  SPTR  = 0b00_00_00_01_00_00_00_00_00, // set R_PSTK to A.var                      ( stack base pointer )
  SSEG  = 0b00_00_00_01_00_00_01_00_00, // set R_MSEG to A.var                      ( RAM segment upper half )
//XXXX  = 0b00_00_00_01_00_00_10_00_00,

  SAVE  = 0b00_00_00_01_00_01_00_00_00, // save    full PRG context to   A.adr
  RSTR  = 0b00_00_00_01_00_01_01_00_00, // restore full PRG context from A.adr
//XXXX  = 0b00_00_00_01_00_01_10_00_00,

//XXXX  = 0b00_00_00_01_00_10_00_00_00,
//XXXX  = 0b00_00_00_01_00_10_01_00_00,
//XXXX  = 0b00_00_00_01_00_10_10_00_00,

  JUMP  = 0b00_00_00_01_01_00_00_00_00, // set R_PADR to A.var
  CALL  = 0b00_00_00_01_01_00_01_00_00, // push R_PADR onto stack, then JUMP A.var
  RTRN  = 0b00_00_00_01_01_00_10_00_00, // pop R_PADR from stack                    ( *A = reserved )

//XXXX  = 0b00_00_00_01_01_01_00_00_00,
//XXXX  = 0b00_00_00_01_01_01_01_00_00,
//XXXX  = 0b00_00_00_01_01_01_10_00_00,

//XXXX  = 0b00_00_00_01_01_10_00_00_00,
//XXXX  = 0b00_00_00_01_01_10_01_00_00,
//XXXX  = 0b00_00_00_01_01_10_10_00_00,

  PSHS  = 0b00_00_00_01_10_00_00_00_00, // push A.var onto R_PSTK
  POPS  = 0b00_00_00_01_10_00_01_00_00, // pop  R_PSTK => A.adr
  CLRS  = 0b00_00_00_01_10_00_10_00_00, // clear R_PSTK          ( *A = new base address, 0 = keep current )

//XXXX  = 0b00_00_00_01_10_01_00_00_00,
//XXXX  = 0b00_00_00_01_10_01_01_00_00,
//XXXX  = 0b00_00_00_01_10_01_10_00_00,

//XXXX  = 0b00_00_00_01_10_10_00_00_00,
//XXXX  = 0b00_00_00_01_10_10_01_00_00,
//XXXX  = 0b00_00_00_01_10_10_10_00_00,

  // MOVE OPS           3T ( 2 args ) |

  SETV  = 0b00_00_00_10_00_00_00_00_00, // set A.adr to literal value B
  COPY  = 0b00_00_00_10_00_00_01_00_00, // copy A.var to B.adr
  SWAP  = 0b00_00_00_10_00_00_10_00_00, // swap A.var and B.var                   ( bidirectional )

//XXXX  = 0b00_00_00_10_00_01_00_00_00,
//XXXX  = 0b00_00_00_10_00_01_01_00_00,
//XXXX  = 0b00_00_00_10_00_01_10_00_00,

//XXXX  = 0b00_00_00_10_00_10_00_00_00,
//XXXX  = 0b00_00_00_10_00_10_01_00_00,
//XXXX  = 0b00_00_00_10_00_10_10_00_00,

  STOR  = 0b00_00_00_10_01_00_00_00_00, // store R_PREG.var to A.adr                ( *B = optional secondary dest )
  LOAD  = 0b00_00_00_10_01_00_01_00_00, // load  A.var => R_PREG                    ( *B = optional write-back dest )
  STLD  = 0b00_00_00_10_01_00_10_00_00, // STOR A + LOAD B in one step

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

  // TRIT 1 OPS          2T ( 1 arg ) | in-place : A.var modified, result also => R_PREG
  // NOTE : TXXX indicates a tritwise op

  SUMT  = 0b00_00_01_00_00_00_00_00_00, // sum all trits as ±1/0 integers => scalar tryte  ( trit reduce )
  INC1  = 0b00_00_01_00_00_00_01_00_00, // A.var + 1
  DEC1  = 0b00_00_01_00_00_00_10_00_00, // A.var - 1

  SHF3  = 0b00_00_01_00_00_01_00_00_00, // shift all trits toward MST by 3     ( one digit group, equiv. x27 )
  SHFU  = 0b00_00_01_00_00_01_01_00_00, // shift all trits toward MST by 1     ( equiv. x3 )
  SHFD  = 0b00_00_01_00_00_01_10_00_00, // shift all trits toward LST by 1     ( equiv. /3, round toward 0 )

  ROT3  = 0b00_00_01_00_00_10_00_00_00, // rotate all trits toward MST by 3    ( one digit group, wraps )
  ROTU  = 0b00_00_01_00_00_10_01_00_00, // rotate all trits toward MST by 1    ( wraps )
  ROTD  = 0b00_00_01_00_00_10_10_00_00, // rotate all trits toward LST by 1    ( wraps )

  FLIP  = 0b00_00_01_00_01_00_00_00_00, // mirror tryte : trit[0]<=>trit[8], trit[1]<=>trit[7], ...
  TPTZ  = 0b00_00_01_00_01_00_01_00_00, // set all + trits to 0                ( positive => zero )
  TNTZ  = 0b00_00_01_00_01_00_10_00_00, // set all - trits to 0                ( negative => zero )

  TABS  = 0b00_00_01_00_01_01_00_00_00, // invert sign of every trit           ( -A.var )
  TABP  = 0b00_00_01_00_01_01_01_00_00, // convert all + trits to -            ( positive => negative )
  TABN  = 0b00_00_01_00_01_01_10_00_00, // convert all - trits to +            ( negative => positive )

  TEQZ  = 0b00_00_01_00_01_10_00_00_00, // per-trit: 0 => +, +/- => -          ( is-zero mask )
  TZTP  = 0b00_00_01_00_01_10_01_00_00, // set all 0 trits to +                ( zero => positive )
  TZTN  = 0b00_00_01_00_01_10_10_00_00, // set all 0 trits to -                ( zero => negative )

//XXXX  = 0b00_00_01_00_10_00_00_00_00,
  TCYU  = 0b00_00_01_00_10_00_01_00_00, // cycle each trit upward              ( ) - => 0 => + => - )
  TCYD  = 0b00_00_01_00_10_00_10_00_00, // cycle each trit downward            ( ) + => 0 => - => + )

//XXXX  = 0b00_00_01_00_10_01_00_00_00,
  TDET  = 0b00_00_01_00_10_01_01_00_00, // determinacy :      +/- => +, 0 => - ( is-nonzero mask )
  TNDT  = 0b00_00_01_00_10_01_10_00_00, // inv. determinacy : +/- => -, 0 => +

  CMPZ  = 0b00_00_01_00_10_10_00_00_00, // compare A.var to 0 => flags + R_PREG  ( A.var unchanged )
  ABSV  = 0b00_00_01_00_10_10_01_00_00, // | A.var | as whole integer
  SGNV  = 0b00_00_01_00_10_10_10_00_00, // SIGN( A.var ) => -/0/+ as tryte


  // TRIT 2 OPS         3T ( 2 args ) | read-only : A / B => R_PREG only
  // truth table layout : left table = this op,  right table = its NOT complement

//XXXX  = 0b00_00_01_01_00_00_00_00_00, //   - - -   + + +
  TMIN  = 0b00_00_01_01_00_00_01_00_00, //   - 0 0   + 0 0  // ( NOT ) MINIMUM   ( AND = MIN )
  TNMN  = 0b00_00_01_01_00_00_10_00_00, //   - 0 +   + 0 -

//XXXX  = 0b00_00_01_01_00_01_00_00_00, //   - 0 +   + 0 -
  TMAX  = 0b00_00_01_01_00_01_01_00_00, //   0 0 +   0 0 -  // ( NOT ) MAXIMUM   ( OR = MAX )
  TNMX  = 0b00_00_01_01_00_01_10_00_00, //   + + +   - - -

//XXXX  = 0b00_00_01_01_00_10_00_00_00, //   + 0 -   - 0 +
  TAGR  = 0b00_00_01_01_00_10_01_00_00, //   0 0 0   0 0 0  // ( DIS ) AGREEMENT  ( AGR = SIGN( A x B ) )
  TDIS  = 0b00_00_01_01_00_10_10_00_00, //   - 0 +   + 0 -

//XXXX  = 0b00_00_01_01_01_00_00_00_00, //   - - 0   + + 0
  TMAJ  = 0b00_00_01_01_01_00_01_00_00, //   - 0 +   + 0 -  // ( NOT ) MAJORITY
  TNMJ  = 0b00_00_01_01_01_00_10_00_00, //   0 + +   0 - -

//XXXX  = 0b00_00_01_01_01_01_00_00_00, //   - 0 0   + 0 0
  TCON  = 0b00_00_01_01_01_01_01_00_00, //   0 0 0   0 0 0  // ( INV ) CONSENSUS  ( TCON => CARRY TRIT )
  TNCN  = 0b00_00_01_01_01_01_10_00_00, //   0 0 +   0 0 -

//XXXX  = 0b00_00_01_01_01_10_00_00_00, //   + - -   - + +
  TEQL  = 0b00_00_01_01_01_10_01_00_00, //   - + -   + - +  // ( NEQ ) EQUALITY
  TNEQ  = 0b00_00_01_01_01_10_10_00_00, //   - - +   + + -

//XXXX  = 0b00_00_01_01_10_00_00_00_00, //   - 0 +   + + +
  TBPS  = 0b00_00_01_01_10_00_01_00_00, //   0 + +   + + 0  // ( BNG ) BIASED POSITIVE  ( SIGN( A + B + 1 ) )
  TBNG  = 0b00_00_01_01_10_00_10_00_00, //   + + +   + 0 -

//XXXX  = 0b00_00_01_01_10_01_00_00_00, //   - 0 -   + 0 +
  TJZR  = 0b00_00_01_01_10_01_01_00_00, //   0 + 0   0 - 0  // ( NJZ ) JOINTLY ZERO  ( SIGN( 1 - |A| - |B| ) )
  TNJZ  = 0b00_00_01_01_10_01_10_00_00, //   - 0 -   + 0 +

//XXXX  = 0b00_00_01_01_10_10_00_00_00,
//XXXX  = 0b00_00_01_01_10_10_01_00_00,
//XXXX  = 0b00_00_01_01_10_10_10_00_00,

  // TRIT 3 OPS         4T ( 3 args ) | A / B => flags + R_PREG,  *C = extra dest
  // MSK* : trytewise masking, A masked by B  => C.adr + R_PREG

  CMPR  = 0b00_00_01_10_00_00_00_00_00, // compare A.var to         B.var  => flags, SIGN => R_PREG, *C.adr
  CMPN  = 0b00_00_01_10_00_00_01_00_00, // compare A.var to  INVR ( B.var) => flags, SIGN => R_PREG, *C.adr
  CMPF  = 0b00_00_01_10_00_00_10_00_00, // compare A.var to  FLIP ( B.var) => flags, SIGN => R_PREG, *C.adr

//XXXX  = 0b00_00_01_10_00_01_00_00_00,
//XXXX  = 0b00_00_01_10_00_01_01_00_00,
//XXXX  = 0b00_00_01_10_00_01_10_00_00,

//XXXX  = 0b00_00_01_10_00_10_00_00_00,
//XXXX  = 0b00_00_01_10_00_10_01_00_00,
//XXXX  = 0b00_00_01_10_00_10_10_00_00,

  MSKZ  = 0b00_00_01_10_01_00_00_00_00, // copy A.var, zero-out trits where B != 0  => C.adr, R_PREG
  MSKP  = 0b00_00_01_10_01_00_01_00_00, // copy A.var, zero-out trits where B != +  => C.adr, R_PREG
  MSKN  = 0b00_00_01_10_01_00_10_00_00, // copy A.var, zero-out trits where B != -  => C.adr, R_PREG

//XXXX  = 0b00_00_01_10_01_01_00_00_00,
//XXXX  = 0b00_00_01_10_01_01_01_00_00,
//XXXX  = 0b00_00_01_10_01_01_10_00_00,

//XXXX  = 0b00_00_01_10_01_10_00_00_00,
//XXXX  = 0b00_00_01_10_01_10_01_00_00,
//XXXX  = 0b00_00_01_10_01_10_10_00_00,

  SHFV  = 0b00_00_01_10_10_00_00_00_00, // shift  A.var by B.var positions ( signed: + = toward MST ) => C.adr, R_PREG
  ROTV  = 0b00_00_01_10_10_00_01_00_00, // rotate A.var by B.var positions ( signed: + = toward MST ) => C.adr, R_PREG
//XXXX  = 0b00_00_01_10_10_00_10_00_00,

//XXXX  = 0b00_00_01_10_10_01_00_00_00,
//XXXX  = 0b00_00_01_10_10_01_01_00_00,
//XXXX  = 0b00_00_01_10_10_01_10_00_00,

//XXXX  = 0b00_00_01_10_10_10_00_00_00,
//XXXX  = 0b00_00_01_10_10_10_01_00_00,
//XXXX  = 0b00_00_01_10_10_10_10_00_00,

  // ALU 1 OPS          4T ( 3 args ) | A / B => C.adr + R_PREG

  ADDV  = 0b00_00_10_00_00_00_00_00_00, // A.var + B.var
  SUBV  = 0b00_00_10_00_00_00_01_00_00, // A.var - B.var
  MODV  = 0b00_00_10_00_00_00_10_00_00, // A.var mod B.var

  ADDO  = 0b00_00_10_00_00_01_00_00_00, // ( A.var + B.var ) + F_OV
  SUBO  = 0b00_00_10_00_00_01_01_00_00, // ( A.var - B.var ) + F_OV
  MODO  = 0b00_00_10_00_00_01_10_00_00, // ( A.var + F_OV  ) % B.var    // NOTE : useless ?

  MULV  = 0b00_00_10_00_00_10_00_00_00, // A.var x B.var
  DIVV  = 0b00_00_10_00_00_10_01_00_00, // A.var / B.var                               ( round toward 0 )
  EXPV  = 0b00_00_10_00_00_10_10_00_00, // A.var ^ B.var                               ( general power, round toward 0 )

  AVGV  = 0b00_00_10_00_01_00_00_00_00, // AVERAGE( A.var, B.var )                     ( round toward 0 )                // NOTE : add an overflow version ?
  MINV  = 0b00_00_10_00_01_00_01_00_00, // MIN( A.var, B.var )
  MAXV  = 0b00_00_10_00_01_00_10_00_00, // MAX( A.var, B.var )

  EXP2  = 0b00_00_10_00_01_01_00_00_00, // ( A.var + *B.var ) ^ 2                      ( square )
  SRT2  = 0b00_00_10_00_01_01_01_00_00, // ( A.var + *B.var ) ^ 1/2                    ( square root, round toward 0 )
  MOD2  = 0b00_00_10_00_01_01_10_00_00, // ( A.var + *B.var ) mod 2                                                      // NOTE : overkill ?

  EXP3  = 0b00_00_10_00_01_10_00_00_00, // ( A.var + *B.var ) ^ 3                      ( cube )
  CRT3  = 0b00_00_10_00_01_10_01_00_00, // ( A.var + *B.var ) ^ 1/3                    ( cube root, round toward 0 )
  MOD3  = 0b00_00_10_00_01_10_10_00_00, // ( A.var + *B.var ) mod 3

  LOGV  = 0b00_00_10_00_10_00_00_00_00, // log_B( A.var )                              ( general log, round toward 0 )   // NOTE : overkill ?
  RNDV  = 0b00_00_10_00_10_00_01_00_00, // round A.var to nearest multiple of B.var    ( round toward 0 )
  ROOT  = 0b00_00_10_00_10_00_10_00_00, // A.var ^ ( 1 / B.var )                       ( Nth root, round toward 0 )      // NOTE : overkill ?

  DIFF  = 0b00_00_10_00_10_01_00_00_00, // | A.var - B.var |                           ( absolute difference )
//XXXX  = 0b00_00_10_00_10_01_01_00_00,
//XXXX  = 0b00_00_10_00_10_01_10_00_00,

//XXXX  = 0b00_00_10_00_10_10_00_00_00,
//XXXX  = 0b00_00_10_00_10_10_01_00_00,
//XXXX  = 0b00_00_10_00_10_10_10_00_00,

  // ALU 2 OPS          5T ( 4 args ) | A / B / C => D.adr + R_PREG

  MEDI  = 0b00_00_10_01_00_00_00_00_00, // MEDIAN( A.var, B.var, C.var )
  MADD  = 0b00_00_10_01_00_00_01_00_00, // ( A.var x B.var ) + C.var
  AMUL  = 0b00_00_10_01_00_00_10_00_00, // ( A.var + B.var ) x C.var

  AVG3  = 0b00_00_10_01_00_01_00_00_00, // AVERAGE( A.var, B.var, C.var )               ( round toward 0 )
  MIN3  = 0b00_00_10_01_00_01_01_00_00, // MIN( A.var, B.var, C.var )
  MAX3  = 0b00_00_10_01_00_01_10_00_00, // MAX( A.var, B.var, C.var )

  CLMP  = 0b00_00_10_01_00_10_00_00_00, // clamp A.var to [ B.var, C.var ] range
//XXXX  = 0b00_00_10_01_00_10_01_00_00,
//XXXX  = 0b00_00_10_01_00_10_10_00_00,

//XXXX  = 0b00_00_10_01_01_00_00_00_00,
//XXXX  = 0b00_00_10_01_01_00_01_00_00,
//XXXX  = 0b00_00_10_01_01_00_10_00_00,

//XXXX  = 0b00_00_10_01_01_01_00_00_00,
//XXXX  = 0b00_00_10_01_01_01_01_00_00,
//XXXX  = 0b00_00_10_01_01_01_10_00_00,

//XXXX  = 0b00_00_10_01_01_10_00_00_00,
//XXXX  = 0b00_00_10_01_01_10_01_00_00,
//XXXX  = 0b00_00_10_01_01_10_10_00_00,

//XXXX  = 0b00_00_10_01_10_00_00_00_00,
//XXXX  = 0b00_00_10_01_10_00_01_00_00,
//XXXX  = 0b00_00_10_01_10_00_10_00_00,

//XXXX  = 0b00_00_10_01_10_01_00_00_00,
//XXXX  = 0b00_00_10_01_10_01_01_00_00,
//XXXX  = 0b00_00_10_01_10_01_10_00_00,

//XXXX  = 0b00_00_10_01_10_10_00_00_00,
//XXXX  = 0b00_00_10_01_10_10_01_00_00,
//XXXX  = 0b00_00_10_01_10_10_10_00_00,

  // VECTOR OPS         4T ( 3 args ) |
  // NOTE : VXXX indicates a vectorized op

  VSET  = 0b00_00_10_10_00_00_00_00_00, // SETV( A,   B++ ) C.var times
  VCPY  = 0b00_00_10_10_00_00_01_00_00, // COPY( A++, B++ ) C.var times
  VSWP  = 0b00_00_10_10_00_00_10_00_00, // SWAP( A++, B++ ) C.var times

  VPSH  = 0b00_00_10_10_00_01_00_00_00, // push C.var trytes from A.adr onto stack at B.stk
  VPOP  = 0b00_00_10_10_00_01_01_00_00, // pop  C.var trytes from B.stk => starting at A.adr
  VCLR  = 0b00_00_10_10_00_01_10_00_00, // zero C.var trytes in stack B.stk from A.adr

//XXXX  = 0b00_00_10_10_00_10_00_00_00, // TODO : add more vectorised ops
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
};


pub const opCodeMap = std.StaticStringMap( OpCode ).initComptime(
.{
// SYSTEM OPERATIONS
  .{ "NOPE", .NOPE },
  .{ "WAIT", .WAIT },
  .{ "HALT", .HALT },
  .{ "INFO", .INFO },
  .{ "SFLG", .SFLG },
  .{ "GFLG", .GFLG },
  .{ "PRNT", .PRNT },
  .{ "DBUG", .DBUG },
  .{ "SYSC", .SYSC },
  .{ "CONT", .CONT },
  .{ "TERM", .TERM },
  .{ "YILD", .YILD },

// PROCESS OPERATIONS
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

// MOVE OPERATIONS
  .{ "SETV", .SETV },
  .{ "COPY", .COPY },
  .{ "SWAP", .SWAP },
  .{ "STOR", .STOR },
  .{ "LOAD", .LOAD },
  .{ "STLD", .STLD },

// TRITWISE OPERATIONS
  .{ "SUMT", .SUMT },
  .{ "INC1", .INC1 },
  .{ "DEC1", .DEC1 },
  .{ "SHF3", .SHF3 },
  .{ "SHFU", .SHFU },
  .{ "SHFD", .SHFD },
  .{ "ROT3", .ROT3 },
  .{ "ROTU", .ROTU },
  .{ "ROTD", .ROTD },
  .{ "FLIP", .FLIP },
  .{ "TPTZ", .TPTZ },
  .{ "TNTZ", .TNTZ },
  .{ "TABS", .TABS },
  .{ "TABP", .TABP },
  .{ "TABN", .TABN },
  .{ "TEQZ", .TEQZ },
  .{ "TZTP", .TZTP },
  .{ "TZTN", .TZTN },
  .{ "TCYU", .TCYU },
  .{ "TCYD", .TCYD },
  .{ "TDET", .TDET },
  .{ "TNDT", .TNDT },
  .{ "CMPZ", .CMPZ },
  .{ "ABSV", .ABSV },
  .{ "SGNV", .SGNV },

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

  .{ "CMPR", .CMPR },
  .{ "CMPN", .CMPN },
  .{ "CMPF", .CMPF },
  .{ "MSKZ", .MSKZ },
  .{ "MSKP", .MSKP },
  .{ "MSKN", .MSKN },
  .{ "SHFV", .SHFV },
  .{ "ROTV", .ROTV },

// ARITHMETIC OPERATIONS
  .{ "ADDV", .ADDV },
  .{ "SUBV", .SUBV },
  .{ "MODV", .MODV },
  .{ "ADDO", .ADDO },
  .{ "SUBO", .SUBO },
  .{ "MODO", .MODO },
  .{ "MULV", .MULV },
  .{ "DIVV", .DIVV },
  .{ "EXPV", .EXPV },
  .{ "AVGV", .AVGV },
  .{ "MINV", .MINV },
  .{ "MAXV", .MAXV },
  .{ "EXP2", .EXP2 },
  .{ "SRT2", .SRT2 },
  .{ "MOD2", .MOD2 },
  .{ "EXP3", .EXP3 },
  .{ "CRT3", .CRT3 },
  .{ "MOD3", .MOD3 },
  .{ "LOGV", .LOGV },
  .{ "RNDV", .RNDV },
  .{ "ROOT", .ROOT },
  .{ "DIFF", .DIFF },

  .{ "MEDI", .MEDI },
  .{ "MADD", .MADD },
  .{ "AMUL", .AMUL },
  .{ "AVG3", .AVG3 },
  .{ "MIN3", .MIN3 },
  .{ "MAX3", .MAX3 },
  .{ "CLMP", .CLMP },

// VECTOR OPERATIONS
  .{ "VSET", .VSET },
  .{ "VCPY", .VCPY },
  .{ "VSWP", .VSWP },
  .{ "VPSH", .VPSH },
  .{ "VPOP", .VPOP },
  .{ "VCLR", .VCLR },
});