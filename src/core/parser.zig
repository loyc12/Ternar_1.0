const std = @import( "std" );
const def = @import( "defs" );

var isFileInit : bool = false;
var readBuffer : [ 1024 ]u8 = undefined;
var fileReader : std.fs.File.Reader = undefined;

var file : std.fs.File = undefined;
var line : ?[]u8 = null;
var eof  : bool = false;
var row  : u32 = 0;

const OpCode = def.OpCode;
const Tryte  = def.Tryte;

pub const ArgLine = struct
{
  op : ?OpCode = null,
  A  : ?Tryte  = null,
  B  : ?Tryte  = null,
  C  : ?Tryte  = null,
  D  : ?Tryte  = null,
};

const LINE_DELIMITER = ';';
const ARG_DELIMITERS = "\t\r\n ,;.:(){}[]#/|\\";
const COMMENT_DELIMITER = '#';

// ================================ FILE PARSER FUNCTIONS ================================

pub fn openFile( comptime filePath : [:0] const u8 ) void
{
  if( isFileInit )
  {
    def.qlog( .WARN, 0, @src(), "Closing previous file beforehand" );
    file.close();
  }

  if( std.fs.cwd().openFile( filePath, .{} ))| f |{ file = f; }
  else | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to open file '{s}' : {}", .{ filePath, err });
    isFileInit = false;
    return;
  }

  fileReader = file.reader( &readBuffer );
  row = 0;

  isFileInit = true;
}

pub fn closeFile() void
{
  if( !isFileInit )
  {
    def.qlog( .WARN, 0, @src(), "Cannot close file : none opened yet");
    return;
  }

  file.close();
  isFileInit = false;
}

pub fn loadNextLine() bool
{
  if( !isFileInit )
  {
    def.qlog( .WARN, 0, @src(), "Cannot read line : none opened yet");
    return false;
  }

  if( fileReader.interface.takeDelimiter( LINE_DELIMITER ))| l |{ line = l; }
  else | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to read file line : {}", .{ err });
    return false;
  }

  eof = ( line == null );
  if( !eof ){ row += 1; }

  return true;
}


pub fn parseNextLine() ArgLine
{
  if( !loadNextLine() )
  {
    def.qlog( .ERROR, 0, @src(), "Failed to obtain parsable line : load error");
    return .{};
  }

  if( eof )
  {
    def.qlog( .ERROR, 0, @src(), "Failed to obtain parsable line : end of file");
    return .{};
  }

  const codeLine = std.mem.sliceTo( line.?, COMMENT_DELIMITER );
  var it = std.mem.tokenizeAny( u8, codeLine, ARG_DELIMITERS );
  var tokenIndex : u32 = 0;

  while( it.next() )| token |
  {
    if( tokenIndex == 0 )
    {
      const opCode = def.opCodeMap.get( token );
      if( opCode != null )
      {
        std.debug.print("{s}\n", .{ @tagName( opCode.? )});
      }
    }
    else
    {
      const arg : ?u18 = std.fmt.parseInt( u18, token, 2 ) catch null;

      if( arg != null )
      {
        std.debug.print("{}\n", .{ arg.? });
      }

    }
    tokenIndex += 1;
  }

  return .{};
}



// ================================ DEBUG FUNCTIONS ================================

fn logNextLine() void
{
  if( !loadNextLine() ){ return; }

  if( !eof ){ def.log(  .INFO, row, @src(), "{s}", .{ line.? }); }
  else      { def.qlog( .WARN, row, @src(), "EOF reached"     ); }
}

pub fn testParser() void
{
  def.qlog( .DEBUG, 0, @src(), "TESTING PARSER\n");

  closeFile();

  logNextLine();

  openFile( "BAD_PATH" );
  logNextLine();
  closeFile();

  openFile( "BAD_PATH" );
  openFile( "exampleAssemblies/debug.trn" );
  logNextLine();
  closeFile();
  closeFile();

  openFile( "exampleAssemblies/debug.trn" );
  openFile( "BAD_PATH" );
  logNextLine();
  closeFile();

  logNextLine();

  openFile( "exampleAssemblies/debug.trn" );

  logNextLine();
  logNextLine();
  logNextLine();
  logNextLine();
  logNextLine();

  openFile( "exampleAssemblies/debug.trn" );

  _ = parseNextLine();
  _ = parseNextLine();
  _ = parseNextLine();
  _ = parseNextLine();
  _ = parseNextLine();

  closeFile();

  def.qlog( .DEBUG, 0, @src(), "PARSER TESTED\n");
}

