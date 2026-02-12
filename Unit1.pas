unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, TFlexArray;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private 宣言 }
  public
    { Public 宣言 }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

type
  TLogProc = procedure(const S: string) of object;

// --- テスト用サブ関数群 ---
procedure Log(const S: string);
begin
  OutputDebugString(PChar(S));
  Form1.Memo1.Lines.Add(S);
end;


// ① 新規生成のテスト
procedure Test_New();
var
  A: TFlexArray<Double>;
begin
  Log('[Test: New]');
  A := TFlexArray<Double>.Create([[1990, 1991], [1, 2]]);
  A[1990, 1] := 10.5;
  A[1991, 2] := 99.9;
  Log(Format('  A[1990, 1] = %.1f', [A[1990, 1]]));
  Log(Format('  A[1991, 2] = %.1f', [A[1991, 2]]));
  Log('  --- for-in enumeration ---');
  for var D in A do
    Log(Format('    Value: %.1f', [D]));
end;

procedure Test_3D_New();
var
  A: TFlexArray<Double>;
  V: Double;
begin
  Log('[Test: 3D New (1990-1991, 1-2, 10-11)]');

  // 3次元配列の生成： [年, 月, 項目ID]
  // 形状: [[1990, 1991], [1, 2], [10, 11]]
  A := TFlexArray<Double>.Create([[1990, 1991], [1, 3], [10, 11]]);

  // データの代入（離れた場所を突く）
  A[1990, 1, 10] := 10.5;
  A[1990, 3, 11] := 20.0;
  A[1991, 2, 11] := 99.9;

  Log(Format('  A[1990, 1, 10] = %.1f', [A[1990, 1, 10]]));
  Log(Format('  A[1990, 3, 11] = %.1f', [A[1990, 3, 11]]));
  Log(Format('  A[1991, 2, 11] = %.1f', [A[1991, 2, 11]]));

  // 未代入箇所（Delphiの動的配列なので初期値は0）
  Log(Format('  A[1991, 1, 10] = %.1f (Empty)', [A[1991, 1, 10]]));

  Log('  --- for-in enumeration (All 8 elements) ---');
  // 3次元でも内部は一本のポインタなので、列挙子は全要素を高速に走破します
  for V in A do
//    if V <> 0 then
      Log(Format('    Found Value: %.1f', [V]));
end;

// ② 1次元参照のテスト
procedure Test_1D_Ref();
var
  Src: TArray<string>;
  A: TFlexArray<string>;
begin
  Src := 'a,b,c,d,e'.Split([',']);

  Log('[Test: 1D Reference]');
//  SetLength(Src, 5);
  A := TFlexArray<string>.Create([1, length(Src)], Src);
  Src[0] := '100';
  Log(Format('  Src[0] changed to 100 -> A[1] = %s', [A[1]]));
  A[5] := '500';
  Log(Format('  A[5] changed to 500   -> Src[4] = %s', [Src[4]]));

  Log('  --- for-in enumeration ---');
  for var D in A do
    Log(Format('    Value: %s', [D]));
end;

// --- Form のイベントハンドラ ---

procedure TForm1.Button1Click(Sender: TObject);
begin
  Memo1.Clear;
  Memo1.Lines.Add('--- TFlexArray 最終試運転 ---');

  Test_New;        // 新規作成
  Test_1D_Ref;    // 1次元参照
  Test_3D_New;
  Memo1.Lines.Add('--- テスト完了 ---');
end;

end.
