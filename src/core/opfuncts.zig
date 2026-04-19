const std = @import( "std" );
const def = @import( "defs" );


// =========================== DEFS IMPORTS ===========================

// Typedefs

const Bit             = def.Bit;
const Byte            = def.Byte;
const BITS_PER_BYTE   = def.BITS_PER_BYTE;
const Trit            = def.Trit;
const BITS_PER_TRIT   = def.BITS_PER_TRIT;
const Tryte           = def.Tryte;
const TRITS_PER_TRYTE = def.TRITS_PER_TRYTE;
const BITS_PER_TRYTE  = def.BITS_PER_TRYTE;
const TRITS_PER_BYTE  = def.TRITS_PER_BYTE;
const TritChar        = def.TritChar;
const TryteStr        = def.TryteStr;


// Constants

const T2     = def.T2;
const T0     = def.T0;
const T1     = def.T1;
const tPos   = def.tPos;
const tZero  = def.tZero;
const tNeg   = def.tNeg;
const tFalse = def.tFalse;
const tMaybe = def.tMaybe;
const tTrue  = def.tTrue;


// Functions

const tritToTryte = def.tritToTryte;
const tryteToTrit = def.tryteToTrit;
const tritToChar  = def.tritToChar;
const tryteToStr  = def.tryteToStr;
const charToTrit  = def.charToTrit;
const strToTryte  = def.strToTryte;


// structs

const MemBank   = def.MemBank;
const OpCode    = def.OpCode;
const PRegTryte = def.PRegTryte;
const PFlagTrit = def.PFlagTrit;
const Ternar    = def.Ternar;




// =========================== OPFUNCTIONS ===========================

// SYSTEM OPS          2T ( 1 arg ) |

  pub fn NOPE( ternar : *Ternar, A : Tryte ) void
  {
    _ = ternar;
    _ = A;      // TODO : handle A as a multiplier
  }

//  pub fn INFO( ternar : Ternar, A : Tryte ) void {}
//  pub fn PRNT( ternar : Ternar, A : Tryte ) void {}

//  pub fn SYSC( ternar : Ternar, A : Tryte ) void {}
//  pub fn SAVE( ternar : Ternar, A : Tryte ) void {}
//  pub fn RSTR( ternar : Ternar, A : Tryte ) void {}

//  pub fn CONT( ternar : Ternar ) void {}
//  pub fn TERM( ternar : Ternar ) void {}
//  pub fn YILD( ternar : Ternar ) void {}

// PROCESS OPS           2T ( 1 arg ) |

//  pub fn SPTR( ternar : Ternar, A : Tryte ) void {}
//  pub fn SSEG( ternar : Ternar, A : Tryte ) void {}

//  pub fn JUMP( ternar : Ternar, A : Tryte ) void {}
//  pub fn CALL( ternar : Ternar, A : Tryte ) void {}
//  pub fn RTRN( ternar : Ternar, A : Tryte ) void {}

//  pub fn PSHS( ternar : Ternar, A : Tryte ) void {}
//  pub fn POPS( ternar : Ternar, A : Tryte ) void {}
//  pub fn CLRS( ternar : Ternar, A : Tryte ) void {}

// MOVE OPS           3T ( 2 args ) | in place ops

//  pub fn COPY( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn SWAP( ternar : Ternar, A : Tryte, B : Tryte ) void {}

//  pub fn STOR( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn LOAD( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn STLD( ternar : Ternar, A : Tryte, B : Tryte ) void
//  {
//    STOR( ternar, A, null );
//    LOAD( ternar, B, null );
//  }

// MULTI OPS          4T ( 3 args ) |

//  pub fn VSET( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn VCPY( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn VSWP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn PSH( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn POP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn CLR( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

// GATE OPS          3T ( 2 args ) | outputs to PREG only

//  pub fn AND( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn TNMN( ternar : Ternar, A : Tryte, B : Tryte ) void {}

//  pub fn TMAX( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn TNMX( ternar : Ternar, A : Tryte, B : Tryte ) void {}

//  pub fn TDIS( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn TAGR( ternar : Ternar, A : Tryte, B : Tryte ) void {}

//  pub fn TMAJ( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn TNMJ( ternar : Ternar, A : Tryte, B : Tryte ) void {}

//  pub fn TCON( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn TNCN( ternar : Ternar, A : Tryte, B : Tryte ) void {}

//  pub fn TEQL( ternar : Ternar, A : Tryte, B : Tryte ) void {}
//  pub fn TNEQ( ternar : Ternar, A : Tryte, B : Tryte ) void {}

// TRIT1 OPS           2T ( 1 arg ) | in place ops.

//  pub fn INC( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn DEC( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn INV( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn SHU( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn SHD( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn SHV( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn RTU( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn RTD( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn RTV( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn FLP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn PTZ( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn NTZ( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn MAG( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn PTN( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn NTP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn EQZ( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn ZTP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn ZTN( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn TUP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn TDW( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn DET( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn IDT( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn CMPZ( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

// TRIT2 OPS          4T ( 3 args ) | outputs to C.adr

//  pub fn CMPF( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn CMPR( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn CMN( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn MSKZ( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn MSKP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn MSKN( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

// ALU1 OPS           4T ( 3 args ) | outputs to C.adr

//  pub fn ADD( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn SUB( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn MUL( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn MOD( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn EXP( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn LOG( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn DIV( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn ROND( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn ROOT( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn AVG( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn MAX( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn TMIN( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn ADC( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn SBB( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

//  pub fn SQR( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn CUB( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}
//  pub fn MDT( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte ) void {}

// ALU2 OPS             5T ( 4 args ) | outputs to D.adr

//  pub fn MED( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte, D : Tryte ) void {}
//  pub fn MAD( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte, D : Tryte ) void {}
//  pub fn AMU( ternar : Ternar, A : Tryte, B : Tryte, C : Tryte, D : Tryte ) void {}