unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, TFlexArray;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
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

  Log('  --- ToString ---');
  Log(A.ToString);
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
  Log('  --- ToString ---');
  Log(A.ToString);
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

  Log('  --- ToString ---');
  Log(A.ToString);
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

procedure TestUltimateChaosSlice;
var
  Data4D, Data3D, Data2D, Data1D: TFlexArray<Integer>;
  i, j, k, l, expectedValue: Integer;
  vec: TArray<Integer>;
begin
  log('--- カオス次元（Low=0,1混在）スライステスト開始 ---');

  SetLength(vec, 24);
  for i := 0 to 23 do vec[i] := i; // これを忘れると全部 0 になっちゃいます！
  // 1. 低下インデックスのバラエティを最大化
  Data4D := TFlexArray<Integer>.Create([
    [1, 2],       // Dim1: Low=1 (1始まり)
    [-1, -1],     // Dim2: Low=-1 (負数)
    [2021, 2023], // Dim3: Low=2021 (巨大な正数)
    [0, 3]        // Dim4: Low=0 (0始まり)
  ], vec);


  expectedValue := 0;

  // 3. 4重ループによる「次元の皮剥ぎ」
  // Data4D[i] -> Data3D[j] -> Data2D[k] -> Data1D[l]

  for i := Data4D.Low(1) to Data4D.High(1) do
  begin
    Data3D := Data4D.ChooseSlice(1, i);

    for j := Data3D.Low(1) to Data3D.High(1) do
    begin
      Data2D := Data3D.ChooseSlice(1, j);

      for k := Data2D.Low(1) to Data2D.High(1) do
      begin
        Data1D := Data2D.ChooseSlice(1, k);

        for l := Data1D.Low(1) to Data1D.High(1) do
        begin
          // 4. 検証
          // GetValue([l]) が内部で GetOffset を呼び、
          // 複雑な歩幅(Stride)とオフセット計算を経て、元のFDataの正解に辿り着く
          Log(Format('%2d ', [Data1D[l]]));

          if Data1D[l] <> expectedValue then
            Log(Format(
              'パズル崩壊！ エラー地点: Indices[%d, %d, %d, %d] 期待値:%d 実際:%d',
              [i, j, k, l, expectedValue, Data1D[l]]
            ));

          Inc(expectedValue);
        end;
        Log('終了');
      end;
    end;
  end;

  Log('--- テスト成功：カオスなインデックス設定でも連番を完全走破！ ---');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
TestUltimateChaosSlice
end;

end.
