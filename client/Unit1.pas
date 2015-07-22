unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,  JvComponentBase, JvTrayIcon, ExtCtrls,jpeg,
  Menus,inifiles, Sockets, SimpleTCP, ScktComp, ComCtrls,
  JvSimLogic;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Image1: TImage;
    Panel1: TPanel;
    Label1: TLabel;
    Button1: TButton;
    Edit1: TEdit;
    ScrollBar1: TScrollBar;
    CheckBox1: TCheckBox;
    Button2: TButton;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    tray: TJvTrayIcon;
    PopupMenu1: TPopupMenu;
    Show1: TMenuItem;
    client: TClientSocket;
    ProgressBar1: TProgressBar;
    Button5: TButton;
    procedure Button1Click(Sender: TObject);
    procedure clientConnected(Sender: TObject);

    procedure ScrollBar1Scroll(Sender: TObject; ScrollCode: TScrollCode;
      var ScrollPos: Integer);
    procedure FormCreate(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
     procedure Show1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure clientError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure clientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure clientLookup(Sender: TObject; Socket: TCustomWinSocket);
    procedure clientConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure clientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure clientWrite(Sender: TObject; Socket: TCustomWinSocket);
    procedure clientConnecting(Sender: TObject; Socket: TCustomWinSocket);
    procedure Button5Click(Sender: TObject);
  private
    { Private declarations }
  public
   procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
    { Public declarations }
  end;

  type
  TMyByteArray = array of Byte;


var
  Form1: TForm1;

  numCaptures:Integer=0;

 MTYPE:Integer=100;

 MTYPEPING:integer=101;
 MTYPEPONG:integer=102;

 MTYPEDELAY:integer=103;
 MTYPEIMAGE:integer=500;
 MTYPESTART:integer=200;
 MTYPECLOSE:integer=300;
  MTYPELOG:integer=400;


 conected:Boolean=False;

 fullread:Boolean=true;

implementation

{$R *.dfm}


function BytesPerPixel(APixelFormat: TPixelFormat): Integer;
begin
  Result := -1;
  case APixelFormat of
    pf8bit: Result := 1;
    pf16bit: Result := 2;
    pf24bit: Result := 3;
    pf32bit: Result := 4;
  end;
end;

procedure BitmapToBytes(Bitmap: TBitmap; out Bytes: TMyByteArray);
var
  BytesPerLine: Integer;
  Row, Col, BPP: Integer;
  PPixels, PBytes: Pointer;
begin
  BPP := BytesPerPixel(Bitmap.PixelFormat);
  if BPP < 1 then
    raise Exception.Create('Unknown pixel format');
  SetLength(Bytes, Bitmap.Width * Bitmap.Height * BPP);
  BytesPerLine := Bitmap.Width * BPP;
  for Row := 0 to Bitmap.Height-1 do
  begin
    PBytes := @Bytes[Row * BytesPerLine];
    PPixels := Bitmap.ScanLine[Row];
    CopyMemory(PBytes, PPixels, BytesPerLine);
  end;
end;

procedure BytesToBitmap(const Bytes: TMyByteArray; Bitmap: TBitmap;
  APixelFormat: TPixelFormat; AWidth, AHeight: Integer);
var
  BytesPerLine: Integer;
  Row, Col, BPP: Integer;
  PPixels, PBytes: Pointer;
begin
  BPP := BytesPerPixel(APixelFormat);
  if BPP < 1 then
    raise Exception.Create('Unknown pixel format');
  if (AWidth * AHeight * BPP) <> Length(Bytes) then
    raise Exception.Create('Bytes do not match image properties');
  Bitmap.Width := AWidth;
  Bitmap.Height := AHeight;
  Bitmap.PixelFormat := APixelFormat;
  BytesPerLine := Bitmap.Width * BPP;
  for Row := 0 to Bitmap.Height-1 do
  begin
    PBytes := @Bytes[Row * BytesPerLine];
    PPixels := Bitmap.ScanLine[Row];
    CopyMemory(PPixels, PBytes, BytesPerLine);
  end;
end;


        procedure msg(m:string);
begin
  Form1.memo1.Lines.Add(m);
  end;

function  SendStreamTo( Stream: TMemoryStream): Integer; // returns N of bytes sent
var
  Buffer: Pointer;
  SavePosition: LongInt;
begin
     Result := 0;
    SavePosition := Stream.Position;
    Stream.Seek(0, soFromBeginning);
    try
      GetMem(Buffer, Stream.Size);
      try
        Stream.Read(Buffer^, Stream.Size);

      Result:=  form1.client.Socket.SendBuf(buffer^,Stream.Size);

     //  Result:=Form1.client.SendBuf(buffer^,Stream.Size,0);

      finally
        { release memory taken for buffer }
        FreeMem(Buffer);
      end;
    finally
      { restore position in stream }
      Stream.Seek(SavePosition, soFromBeginning);
    end;

end;

procedure sendPack(stm:TMemoryStream);

begin
// msg('send :'+inttostr(SendStreamTo(stm)));
SendStreamTo(stm);
 // if  not conected then Exit;
  //
//  Form1.client.SendStream(stm);
//form1.client.s
//  form1.client.SendBuf(

end;



function WriteBuffer(m_file:TStream; const buffer; bufferSize: LongWord) : integer;
begin
   try
     Result:=m_file.Write(buffer, bufferSize);
   except
     result := 0;
   end;
end;
function WriteByte(m_file:TStream; value: integer) : integer;
begin
   WriteBuffer(m_file,value, 1);
   Result:=1;
end;

function writeShort(m_file:TStream; v: byte) : integer;
begin
  WriteByte(m_file, (v shr 8) and $ff);
  WriteByte(m_file, (v shr 0) and $ff);
  Result:=2;
end;

function writeChar(m_file:TStream; v: integer) : integer;
begin
  WriteByte(m_file, (v shr 8) and $ff);
  WriteByte(m_file, (v shr 0) and $ff);
  Result:=4;
end;
function writeInt(m_file:TStream; v: integer) : boolean;
begin

  WriteByte(m_file, (v shr 24) and $ff);
  WriteByte(m_file, (v shr 16) and $ff);
  WriteByte(m_file, (v shr 8) and $ff);
  WriteByte(m_file, (v shr 0) and $ff);
  Result:=True;
end;


//*******************************
function ReadBuffer(m_file:TStream;var buffer; bufferSize: LongWord) : integer;
begin
   try
   Result:=     m_file.Read(buffer, bufferSize);
    except
     result := 0;
   end;
end;







function WriteString(m_file:TStream;data:String):integer;
var
  i:Integer;
   len: cardinal;
   oString: UTF8String;
begin
  // oString := UTF8String(data);
   //len := length(oString);
    data:=Trim(data);
    len:=Length(data);
    writeInt(m_file,len);
    for i:=1 to  len do
    WriteBuffer(m_file,data[i], 1);
  //  writeChar(m_file,Ord(data[i]));
   //if len > 0 then
   //WriteBuffer(m_file,oString[1], len);
end;




function readByte(m_file:TStream):byte;
var
  ch:integer;
begin
   ReadBuffer(m_file,ch, 1);
   Result:=Byte(ch);
end;



function readInt(m_file:TStream):integer;
var
  ch1,ch2,ch3,ch4:Integer;
begin



  ch1:=ReadByte(m_file);
  ch2:=ReadByte(m_file);
  ch3:=ReadByte(m_file);
  ch4:=ReadByte(m_file);
  Result:=((ch1 shl 24) + (ch2 shl 16) + (ch3 shl 8) + (ch4 shl 0));

end;
function readChar(m_file:TStream):char;
var
  ch1,ch2:Integer;
begin
  ch1:=ReadByte(m_file);
  ch2:=ReadByte(m_file);
  Result:=char( (ch1 shl 8) + (ch2 shl 0));
end;
function readShort(m_file:TStream):Smallint;
var
  ch1,ch2:Integer;
begin
  ch1:=ReadByte(m_file);
  ch2:=ReadByte(m_file);
  Result:=Smallint( (ch1 shl 8) + (ch2 shl 0));
end;

function ReadString(m_file:TStream):string;
var
   len: cardinal;
   iString: UTF8String;
begin
   len:=readInt(m_file);
   if len > 0 then
   begin
      setLength(iString, len);
      ReadBuffer(m_file,iString[1], len);
      result := string(iString);
   end;
end;
procedure getLog;
var
  str:TMemoryStream;
  b:Byte;
begin
  //  if  not conected then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPELOG);  //ping
    sendPack(str);
    str.Destroy;
end;
procedure Ping;
var
  str:TMemoryStream;
  b:Byte;
begin
  //  if  not conected then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPEPING);  //ping
    sendPack(str);
    str.Destroy;
end;

procedure Pong;
var
  str:TMemoryStream;
  b:Byte;
begin
    if  not conected then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPEPONG);  //ping
    sendPack(str);
    str.Destroy;
end;

procedure sendDelay;
var
  str:TMemoryStream;
  b:Byte;
begin
    if  not conected then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPEDELAY);
    WriteInt(str,form1.ScrollBar1.Position);
    sendPack(str);
   str.Destroy;
end;

procedure sendStart;
var
  str:TMemoryStream;
  b:Byte;
begin
    if  not conected then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPESTART);
    sendPack(str);
   str.Destroy;
end;
procedure sendClose;
var
  str:TMemoryStream;
  b:Byte;
begin
    if  not conected then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPECLOSE);  //ping
    sendPack(str);
    str.Destroy;

end;

procedure TForm1.Button1Click(Sender: TObject);
begin

if (   client.Active) then
begin
  sendClose();
  client.Close;


end else
begin


client.Host:=Edit1.Text;
client.Port:=8741;
client.Open;
end;





end;

procedure TForm1.clientConnected(Sender: TObject);
begin
Memo1.Lines.Add('conected');
conected:=True;
end;

procedure TForm1.ScrollBar1Scroll(Sender: TObject; ScrollCode: TScrollCode;
  var ScrollPos: Integer);
begin
Label1.Caption:='Delay:'+inttostr(ScrollBar1.position);
sendDelay();
end;

procedure TForm1.FormCreate(Sender: TObject);
var
   appINI : TIniFile;
 begin
   appINI := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
 try
    Edit1.Text:=appINI.ReadString('Conection','Ip','192.168.1.2') ;
   form1.ScrollBar1.Position:=     appINI.ReadInteger('Setup','delay',5000) ;
   finally
     appIni.Free;
   end;

Label1.Caption:='Delay:'+inttostr(ScrollBar1.position);


end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
if (CheckBox1.Checked) then
begin
  sendstart();
end else
begin
  sendClose();
end;

end;

procedure TForm1.Button2Click(Sender: TObject);
begin
Ping();
end;


  Function ByteSwap32(Const A:Cardinal):Cardinal;
Var
  B1,B2,B3,B4:Byte;
Begin
  B1:=A And 255;
  B2:=(A Shr 8) And 255;
  B3:=(A Shr 16)And 255;
  B4:=(A Shr 24)And 255;

  Result:=(Cardinal(B1)Shl 24) + (Cardinal(B2) Shl 16) + (Cardinal(B3) Shl 8) + B4;
End;

Function ByteSwap16(A:Word):Word;
Var
  B1,B2:Byte;
Begin
  B1:=A And 255;
  B2:=(A Shr 8) And 255;

  Result:=(B1 Shl 8)+B2;
End;

{
procedure TForm1.clientRead(Sender: TObject; Stream: TStream);
var

  len, msgType:Integer;
 w,h, current,i, imagesize:Integer;
  data:integer;
        MyJPEG : TJPEGImage;
   readstr:TMemoryStream;
   imgstr:TMemoryStream;
    FilePath:string;
    Buffer: integer;
    b:Integer;
//buffer:byte;

begin
//msg('Size of pack:'+inttostr(stream.Size));
//msg('MSG TYPE:'+inttostr(  msgType));
//if not fullread then Exit;
//Stream.Position:=0;



msgType:= readInt(stream);  //id
if (msgType=MTYPEIMAGE) then
begin
fullread:=False;

   w:=readInt(stream);  //size
   h:=readInt(stream);  //size
   imagesize:=readInt(stream) ;  //size

   msg(IntToStr(w)+','+inttostr(h)+','+inttostr(imagesize)+','+inttostr(Stream.Size));


     imgstr:=TMemoryStream.Create();

    current:=0;


    repeat
         stream.Read(buffer,1);
         imgstr.Write(buffer,1);

    Inc(current);
    until (current >= imagesize);



     while   (current<Stream.Size) do
     begin
       stream.Read(buffer,1);
       imgstr.Write(buffer,1);
       Inc(current);
     end;
     msg(IntToStr(current-1));



     GetMem(Buffer, imagesize);
     try
     Stream.Read(Buffer^, imagesize);
     imgstr.Write(Buffer^, imagesize);
     finally
     FreeMem(Buffer);
     end;


            if(CheckBox2.Checked) then
            begin
             MyJPEG := TJPEGImage.Create;
             imgstr.Position:=0;
             MyJPEG.LoadFromStream(imgstr);
             Image1.Picture.Assign(MyJPEG);
             MyJPEG.Destroy;
             end;


             
     if(CheckBox3.Checked) then
     begin

        FilePath := ExtractFilePath(ParamStr(0))+'images\s_('+inttostr(numCaptures)+')'+floattostr(Time())+'_.jpeg';
        inc(numCaptures);
        imgstr.SaveToFile(FilePath);
     end;


   imgstr.Destroy;

fullread:=True;


end else
if (msgType=MTYPEPING) then
begin
    msg('Client PING you... send PONG.');
    Pong();
end else

if (msgType=MTYPEPONG) then
begin
msg('PONG ');


end else
if (msgType= MTYPECLOSE) then
begin

end else
begin
  //que tipo de msg???
end;


end;

    }

procedure TForm1.WMSysCommand(var Message: TWMSysCommand);
begin
case Message.cmdType of
SC_MINIMIZE:
tray.HideApplication();
SC_MAXIMIZE:
tray.ShowApplication();
//ShowMessage('Maximizing');
SC_RESTORE:
//ShowMessage('Restoring');
end;
inherited;
end; 



procedure TForm1.Show1Click(Sender: TObject);
begin
tray.ShowApplication();
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var
   appINI : TIniFile;
 begin
   appINI := TIniFile.Create(ChangeFileExt(Application.ExeName,'.ini')) ;
 try
      appINI.WriteString('Conection','Ip',Edit1.Text) ;
      appINI.WriteInteger('Setup','delay',form1.ScrollBar1.Position) ;
   finally
     appIni.Free;
   end;

   client.Active:=False;

end;

procedure TForm1.Button3Click(Sender: TObject);

   var
    MyJPEG : TJPEGImage;
   str:TMemoryStream;
   imgstr:TMemoryStream;

begin
    imgstr:=TMemoryStream.Create();


    MyJPEG:=TJPEGImage.Create;
    MyJPEG.LoadFromFile('capture.jpg');
    MyJPEG.SaveToStream(imgstr);



    str:=TMemoryStream.Create();
    WriteInt(str,MTYPEIMAGE);
    WriteInt(str,MyJPEG.Width);
    WriteInt(str,MyJPEG.Height);
    WriteInt(str,imgstr.Size);
    imgstr.SaveToStream(str);
    imgstr.Destroy;
    MyJPEG.Destroy;
    str.SaveToFile('savepack.txt');
    str.Destroy;




end;

procedure TForm1.Button4Click(Sender: TObject);
var
  buffer:byte;
  mtype,h,imagesize,current,w:Integer;
  imgstr,stream:TMemoryStream;
   MyJPEG : TJPEGImage;
begin

  stream:=TMemoryStream.Create();
  stream.LoadFromFile('savepack.txt');

   mtype:=readInt(stream);  //size
   w:=readInt(stream);  //size
   h:=readInt(stream);  //size
   imagesize:=readInt(stream) ;  //size

   msg(IntToStr(w)+','+inttostr(h)+','+inttostr(imagesize)+','+inttostr(Stream.Size));


     imgstr:=TMemoryStream.Create();

     current:=0;
     while   (current<=imagesize) do
     begin
   
     Inc(current);
     end;
     msg(IntToStr(current-1));

      {
     GetMem(Buffer, imagesize);
     try
     Stream.ReadBuffer(Buffer^, imagesize);
     imgstr.WriteBuffer(Buffer^, imagesize);
     finally
     FreeMem(Buffer);
     end;
      }


       MyJPEG := TJPEGImage.Create;
       imgstr.Position:=0;
       MyJPEG.LoadFromStream(imgstr);
       MyJPEG.SaveToFile('capture.jpeg');
       MyJPEG.Destroy;

         //   imgstr.SaveToFile('capture.jpeg');


    {
     GetMem(Buffer, imagesize);
     try
     Stream.ReadBuffer(Buffer^, imagesize);
     imgstr.WriteBuffer(Buffer^, imagesize);
     finally
     FreeMem(Buffer);
     end;
   }

   imgstr.Destroy;
   stream.Destroy;

end;






procedure TForm1.clientError(Sender: TObject; Socket: TCustomWinSocket;
  ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
Memo1.Lines.Add('error');
end;

procedure TForm1.clientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
Memo1.Lines.Add('disconnected');
conected:=False;
Button1.Caption:='Connect';
end;

procedure TForm1.clientLookup(Sender: TObject; Socket: TCustomWinSocket);
begin
msg('look up');
end;

procedure TForm1.clientConnect(Sender: TObject; Socket: TCustomWinSocket);
begin
conected:=true;
Button1.Caption:='Disconect';
end;

procedure TForm1.clientRead(Sender: TObject; Socket: TCustomWinSocket);








var

//Buffer: array [0..9999] of Char;

 //  buffer : Array [0..1023] of byte;



  IncommingLen, RecievedLen: integer;


  len, msgType:Integer;
 w,h, current,i, imagesize:Integer;
  data:integer;
    MyJPEG : TJPEGImage;
   readstr:TMemoryStream;
   imgstr:TMemoryStream;
    FilePath:string;
   // Buffer: integer;
      b:byte;

   total,  count: Integer;

      BytesPerLine: Integer;



      stream:TMemoryStream;
      // stream:LMemoryStream;

//       b,buffer :byte;
working:boolean;


begin




 stream:=TMemoryStream.Create;



  //  JvSimLight1.Lit:=True;
  stream:=TMemoryStream.Create;
  total:=0;
  working:=true;
  while  (working) do
  begin
  RecievedLen:=socket.ReceiveBuf(b, 1);
  stream.Write(b,1);
  inc(total);
  if (RecievedLen<=0) then working:=false;
  //  Application.ProcessMessages;
  end;
 // JvSimLight1.Lit:=false;

   stream.Position:=0;

//  msg(inttostr(total));











 stream.Position:=0;




msgType:= readInt(stream);  //id
if (msgType=MTYPEIMAGE) then
begin
fullread:=False;

   w:=readInt(stream);  //size
   h:=readInt(stream);  //size
   imagesize:=readInt(stream) ;  //size

  // msg(IntToStr(w)+','+inttostr(h)+','+inttostr(imagesize)+','+inttostr(IncommingLen));
 //  msg(inttostr(imagesize)+','+inttostr(total)+','+inttostr(stream.size));

     imgstr:=TMemoryStream.Create();
     current:=0;
     while   (current<=imagesize) do
     begin
        Application.ProcessMessages;
        stream.Read(b,1);
        imgstr.write(b,1);
        Inc(current);
     end;
     imgstr.Position:=0;







            if(CheckBox2.Checked) then
            begin
             MyJPEG := TJPEGImage.Create;
             MyJPEG.LoadFromStream(imgstr);
             Image1.Picture.Assign(MyJPEG);
             MyJPEG.Destroy;
             end;


             
     if(CheckBox3.Checked) then
     begin

        FilePath := ExtractFilePath(ParamStr(0))+'images\s_('+inttostr(numCaptures)+')'+floattostr(Time())+'_.jpeg';
        inc(numCaptures);
        imgstr.SaveToFile(FilePath);

     end;



   imgstr.Destroy;

fullread:=True;


end else
if (msgType=MTYPEPING) then
begin
    msg('Client PING you... send PONG.');
    Pong();
end else

if (msgType=MTYPEPONG) then
begin
msg('PONG ');


end else
if (msgType= MTYPECLOSE) then
begin

end else
if (msgType= MTYPELOG) then
begin

    imagesize:=readInt(stream) ;  //size
    msg(inttostr(total)+','+inttostr(stream.size));

     imgstr:=TMemoryStream.Create();
     current:=0;
     while   (current<=imagesize) do
     begin
        Application.ProcessMessages;
        stream.Read(b,1);
        imgstr.write(b,1);
        Inc(current);
     end;
     imgstr.Position:=0;
     Form1.Memo1.Lines.LoadFromStream(imgstr);
     imgstr.Destroy;

end else
begin
  //que tipo de msg???
end;






 // stream.Write(          Socket.Data^,Socket.ReceiveLength);


 //  msg('size:'+inttostr(stream.size));



  stream.Destroy;


end;

procedure TForm1.clientWrite(Sender: TObject; Socket: TCustomWinSocket);
begin
 msg('send data');
end;

procedure TForm1.clientConnecting(Sender: TObject;
  Socket: TCustomWinSocket);
begin
msg('Connect');
conected:=true;
Button1.Caption:='Disconect';
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
getLog();
end;

end.procedure TForm1.SimpleTCPServer1Accept(Sender: TObject;
  Client: TSimpleTCPClient; var Accept: Boolean);
begin

end;


