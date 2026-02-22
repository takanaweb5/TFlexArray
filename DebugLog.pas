unit DebugLog;

interface

procedure OutputDebugLog(str: string);
procedure OutputDebugFmt(const FormatStr: string; const Args: array of const);
procedure OutputDebugSet(strFileName: string);

implementation

uses
  Windows, SysUtils;

function OpenFile(strFileName: string): THandle; forward;
procedure WriteLine(str: string); forward;
function GetTimeStr(): string; forward;

const
  FileName = 'Z:\Debug.log';  //任意のログファイル名を指定

var
  hFile: THandle;

//*****************************************************************************
//[ 概  要 ]　ログファイル名を設定
//[ 引  数 ]　ファイル名
//*****************************************************************************
procedure OutputDebugSet(strFileName: string);
begin
  if hFile <> 0 then CloseHandle(hFile);

  hFile := OpenFile(strFileName);
  if hFile = 0 then Exit;

  //例：--- 23:59:01.001 Project1.exe ---
  WriteLine(Format('--- %s %s ---', [GetTimeStr, ExtractFileName(ParamStr(0))]));
end;

//*****************************************************************************
//[ 概  要 ]　ログファイルにログを書込む
//[ 引  数 ]　Format()関数と同じ
//*****************************************************************************
procedure OutputDebugFmt(const FormatStr: string; const Args: array of const);
begin
  OutputDebugLog(Format(FormatStr, Args));
end;

//*****************************************************************************
//[ 概  要 ]　ログファイルにログを書込む
//[ 引  数 ]　書込む文字列
//*****************************************************************************
procedure OutputDebugLog(str: string);
begin
  WriteLine(GetTimeStr + ' '+ str);
end;

//*****************************************************************************
//[ 概  要 ]　ログファイルをオープンする
//[ 引  数 ]　ログファイル名
//[ 戻り値 ]　ファイルハンドル
//*****************************************************************************
function OpenFile(strFileName: string): THandle;
begin
  Result := CreateFile(PChar(strFileName), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if Result = 0 then Exit;

  //ファイルポインターをファイルの末尾に設定
  if Integer(SetFilePointer(Result, 0, nil, FILE_END)) = -1 then
    Result := 0;
end;

//*****************************************************************************
//[ 概  要 ]　ログファイルに1行書込む
//[ 引  数 ]　書込む文字列
//*****************************************************************************
procedure WriteLine(str: string);
var
  WriteCnt: LongWord;
  WriteStr: AnsiString;
begin
  str := str + #13#10;
  WriteStr := AnsiString(str);
  Writefile(hFile, WriteStr[1],  Length(WriteStr), WriteCnt, nil);
end;

//*****************************************************************************
//[ 概  要 ]　現在時刻を文字列で取得
//[ 戻り値 ]　例：「23:59:01.001」
//*****************************************************************************
function GetTimeStr(): string;
var
  ST: SYSTEMTIME;
begin
  GetLocalTime(ST);
  Result := Format('%.2d:%.2d:%.2d.%.3d',
                   [ST.wHour, ST.wMinute, ST.wSecond, ST.wMilliseconds]);
end;

//*****************************************************************************
//[ 概  要 ]　ログファイルを開き、開始時刻とEXE名を書き込む
//*****************************************************************************
initialization
  hFile := OpenFile(FileName);
  if hFile = 0 then Exit;

  //例：--- 23:59:01.001 Project1.exe ---
  WriteLine(Format('--- %s %s ---', [GetTimeStr, ExtractFileName(ParamStr(0))]));

//*****************************************************************************
//[ 概  要 ]　ログファイルを閉じる
//*****************************************************************************
finalization
  if hFile <> 0 then CloseHandle(hFile);
end.

