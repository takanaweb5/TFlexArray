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
  Form1.Memo1.Lines.Add(S);
end;


// ① 新規生成のテスト（[]なし）
procedure Test_New();
var
  A: TFlexAny<Double>;
begin
  Log('[Test: New]');
  A := TFlexAny<Double>.Create([1990, 1991, 1, 2]);
  A[1990, 1] := 10.5;
  A[1991, 2] := 99.9;
  Log(Format('  A[1990, 1] = %.1f', [A[1990, 1]]));
  Log(Format('  A[1991, 2] = %.1f', [A[1991, 2]]));
end;

// ② 1次元参照のテスト
procedure Test_1D_Ref();
var
  Src: TArray<Integer>;
  A: TFlexAny<Integer>;
begin
  Log('[Test: 1D Reference]');
  SetLength(Src, 5);
  A := TFlexAny<Integer>.Create(Src, 1);
  Src[0] := 100;
  Log(Format('  Src[0] changed to 100 -> A[1] = %d', [A[1]]));
  A[5] := 500;
  Log(Format('  A[5] changed to 500   -> Src[4] = %d', [Src[4]]));
end;

// ③ 2次元参照のテスト
procedure Test_2D_Ref();
var
  Src: TArray<TArray<Double>>;
  A: TFlexAny<Double>;
begin
  Log('[Test: 2D Reference]');
  SetLength(Src, 2, 2);
  A := TFlexAny<Double>.Create(Src, 100, 200);
  Src[1, 1] := 123.45;
  Log(Format('  Src[1,1] = 123.45 -> A[101, 201] = %.2f', [A[101, 201]]));
end;

// ④ 3次元参照のテスト（for-in）
procedure Test_3D_Ref();
var
  Src: TArray<TArray<TArray<Integer>>>;
  A: TFlexAny<Integer>;
  V, Total: Integer;
begin
  Log('[Test: 3D Reference & Enumerator]');
  SetLength(Src, 2, 2, 2);
  A := TFlexAny<Integer>.Create(Src, 0, 0, 0);
  // 全要素に 1 を代入
  A[0,0,0] := 1; A[0,0,1] := 1; A[0,1,0] := 1; A[0,1,1] := 1;
  A[1,0,0] := 1; A[1,0,1] := 1; A[1,1,0] := 1; A[1,1,1] := 1;

  Total := 0;
  for V in A do Inc(Total, V);
  Log(Format('  3D Total Sum (for-in): %d (Expected: 8)', [Total]));
end;

// --- Form のイベントハンドラ ---

procedure TForm1.Button1Click(Sender: TObject);
begin
  Memo1.Clear;
  Memo1.Lines.Add('--- TFlexAny 最終試運転 ---');

  Test_New;        // 新規作成
  Test_1D_Ref;    // 1次元参照
  Test_2D_Ref;    // 2次元参照
  Test_3D_Ref;    // 3次元参照

  Memo1.Lines.Add('--- テスト完了 ---');
end;

end.
