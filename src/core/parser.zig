const std = @import( "std" );
const def = @import( "defs" );

var isFileInit : bool = false;
var isReadInit : bool = false;
var lineBuffer : [ 1024 ]u8 = undefined;
var lineReader : std.fs.File.Reader = undefined;

var file : std.fs.File = undefined;
var row  : u32 = 0;

pub fn openFile( comptime filePath : [:0] const u8 ) void
{
  if( isFileInit )
  {
    def.qlog( .WARN, 0, @src(), "Closing previous file beforehand" );
    file.close();
  }

  file = if( std.fs.cwd().openFile( filePath, .{} )) | f | f else | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to open file : {s} : {}", .{ filePath, err });
    return;
  };

  lineReader = file.reader( &lineBuffer );
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

pub fn logNextLine() void
{
  if( !isFileInit )
  {
    def.qlog( .WARN, 0, @src(), "Cannot read line : none opened yet");
    return;
  }

  const line = if ( lineReader.interface.takeDelimiter('\n')) | l | l else | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to read file line : {}", .{ err });
    return;
  };

  if( line != null )
  {
    row += 1;
    def.log( .INFO, row, @src(), "{s}\n", .{ line.? });
  }
  else
  {
    def.qlog( .INFO, row, @src(), "EOF reached\n" );
  }
}



pub fn testParser() void
{
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
  openFile( "exampleAssemblies/debug.trn" );
  logNextLine();
  closeFile();

  logNextLine();

  openFile( "exampleAssemblies/debug.trn" );

  logNextLine();
  logNextLine();
  logNextLine();
  logNextLine();
  logNextLine();

  closeFile();
}

