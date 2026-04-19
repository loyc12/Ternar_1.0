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

const T1     = def.T1;
const T0     = def.T0;
const T2     = def.T2;

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


pub fn NOPE( ternar : *Ternar, A : Tryte ) void
{
  _ = ternar;
  _ = A;      // TODO : handle A as a multiplier
}
