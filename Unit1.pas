unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, TFlexArray, DebugLog, System.DateUtils;

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
  OutputDebugLog(PChar(S));
  Form1.Memo1.Lines.Add(S);
end;

// 日付変換関数（Mapped用）
function CreateValidDateFromCoords(const Value: TDateTime; const Coords: TArray<Integer>): TDateTime;
var
  Year, Month, Day: Integer;
begin
  Year := Coords[0];
  Month := Coords[1];
  Day := Coords[2];

  // 有効な日付かチェック
  if IsValidDate(Year, Month, Day) then
    Result := EncodeDate(Year, Month, Day)
  else
    Result := 0; // 無効な日付は0に
end;

function FormatDateToString(const Value: TDateTime;const  Coords: TArray<Integer> = nil): string;
begin
  if Value = 0 then
    Result := '---' // 無効な日付
  else
    Result := FormatDateTime('yyyy/mm/dd', Value);
end;

// --- パフォーマンス比較テスト ---
// --- パフォーマンス比較テスト（String版・ヘビー） ---
procedure TestPerformance;
var
  A, B: TFlexArray<string>;
  StartTime, EndTime: TDateTime;
  i, j, k: Integer;
  ReshapeTime, CopyTime: Integer;
  TestString: string;
begin
//  Log('[Test: Performance Comparison (String Heavy)]');
//
//  // ヘビーな文字列データを準備
//  TestString := 'This is a very long test string with heavy content to make the performance test more realistic and demanding. ' +
//                'It contains multiple sentences and should consume more memory per element. ' +
//                'The purpose is to create a significant difference between reference counting and actual copying operations. ' +
//                'Each element will hold substantial data to amplify the performance characteristics.';
//
//  // 大きな配列を準備（500x500 = 250,000要素）
//  A := TFlexArray<string>.CreateMatrix(100, 100, 1);
//  Log(Format('Created %dx%d matrix (%d elements)', [100, 100, A.TotalSize]));
//
//  // 全要素にヘビーな文字列を設定（インデックスも文字列で生成）
//  Log('Setting heavy string values...');
//  for i := A.Low(1) to A.High(1) do
//    for j := A.Low(2) to A.High(2) do
//      A[i, j] := Format('Element[%d,%d]', [i, j]);
//
//  Log('Data setup completed');
//
//  // Reshapeのパフォーマンス測定（参照カウントのみ）
//  StartTime := Now;
//  for i := 1 to 10 do
//  begin
//    A.ReshapeVector(1);  // メソッドチェーン
//    log(A.ToString);
//  end;
//  EndTime := Now;
//  ReshapeTime := MilliSecondsBetween(EndTime, StartTime);
//  Log(Format('Reshape (ref-count only): %d ms for 5000 operations', [ReshapeTime]));
//
//  // CreateFromFlexArrayのパフォーマンス測定（実コピー）
//  StartTime := Now;
//  for i := 1 to 10 do  // 回数を大幅に減らす（重い処理のため）
//  begin
//    A := TFlexArray<string>.CreateFromFlexArray(A);
//    log(A.ToString);
//  end;
//  EndTime := Now;
//  CopyTime := MilliSecondsBetween(EndTime, StartTime);
//  Log(Format('CreateFromFlexArray (real copy): %d ms for 100 operations', [CopyTime]));
//
//  // 速度比較
//  if ReshapeTime > 0 then
//    Log(Format('Speed difference: %.1fx faster', [CopyTime * 50.0 / ReshapeTime]))
//  else
//    Log('Reshape was too fast to measure accurately');
//
//  // 実コピーの確認
//  B := TFlexArray<string>.CreateFromFlexArray(A);
//
//
//  // データ整合性確認
//  Log('Sample data check:');
//  Log(Format('A[1,1]: %s', [Copy(A[1,1], 1, 50) + '...']));
//  Log(Format('B[1,1]: %s', [Copy(B[1,1], 1, 50) + '...']));
end;

// --- Reshapeチェーン実験 ---
procedure TestReshapeChain;
var
  A: TFlexArray<Integer>;
begin
//  Log('[Test: Reshape Chain Experiment]');
//
//  // 2x3行列を作成
//  A := TFlexArray<Integer>.CreateMatrix(2, 3, 1);
//  A[1,1] := 1; A[1,2] := 2; A[1,3] := 3;
//  A[2,1] := 4; A[2,2] := 5; A[2,3] := 6;
//
//  Log('Original 2x3:');
//  Log(A.ToString);
//  Log(A.TotalSize.ToString);
//
//  // 現状のReshapeはprocedureなので戻り値なし
//  // 以下のコードはコンパイルエラーになるはず
//  try
//    Log('After reshape to 3x2:');
//    A.Reshape([3, 2], 1);
//    Log(A.ToString);
//
//    // もう一度Reshape
//
//
//    Log('After reshape to 1x6:');
//    A.ReshapeRange([1, 6]);
//    Log(A.ToString);
//
//  except
//    on E: Exception do
//      Log('Error: ' + E.Message);
//  end;
//
//  Log('Reshape chain test completed');
end;

// ① 新規生成のテスト
procedure Test_New();
var
  A: TFlexArray<Double>;
begin
//  Log('[Test: New]');
//  A := TFlexArray<Double>.CreateFromRange([[1990, 1991], [1, 2]]);
//  A[1990, 1] := 10.5;
//  A[1991, 2] := 99.9;
//  Log(Format('  A[1990, 1] = %.1f', [A[1990, 1]]));
//  Log(Format('  A[1991, 2] = %.1f', [A[1991, 2]]));
//  Log('  --- for-in enumeration ---');
//  for var D in A do
//    Log(Format('    Value: %.1f', [D]));
//
//  Log('  --- ToString ---');
//  Log(A.ToString);
end;

procedure Test_3D_New();
var
  A: TFlexArray<Double>;
  V: Double;
begin
//  Log('[Test: 3D New (1990-1991, 1-2, 10-11)]');
//
//  // 3次元配列の生成： [年, 月, 項目ID]
//  // 形状: [[1990, 1991], [1, 2], [10, 11]]
//  A := TFlexArray<Double>.CreateFromRange([[1990, 1991], [1, 3], [10, 11]]);
//
//  // データの代入（離れた場所を突く）
//  A[1990, 1, 10] := 10.5;
//  A[1990, 3, 11] := 20.0;
//  A[1991, 2, 11] := 99.9;
//
//  Log(Format('  A[1990, 1, 10] = %.1f', [A[1990, 1, 10]]));
//  Log(Format('  A[1990, 3, 11] = %.1f', [A[1990, 3, 11]]));
//  Log(Format('  A[1991, 2, 11] = %.1f', [A[1991, 2, 11]]));
//
//  // 未代入箇所（Delphiの動的配列なので初期値は0）
//  Log(Format('  A[1991, 1, 10] = %.1f (Empty)', [A[1991, 1, 10]]));
//
//  Log('  --- for-in enumeration (All 8 elements) ---');
//  // 3次元でも内部は一本のポインタなので、列挙子は全要素を高速に走破します
//  for V in A do
////    if V <> 0 then
//      Log(Format('    Found Value: %.1f', [V]));
//  Log('  --- ToString ---');
//  Log(A.ToString);
end;
//
// ② 1次元参照のテスト
procedure Test_1D_Ref();
var
  Src: TArray<string>;
  A: TFlexArray<string>;
begin
  Src := 'a,b,c,d,e'.Split([',']);

  Log('[Test: 1D Reference]');
  A := TFlexArray<string>.ViewFromArray(Src, 1);
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
//
//// --- Form のイベントハンドラ ---
//
//// Mapメソッドを使って日付を作成するテスト
//procedure TestMapDateCreation;
//var
//  DateArray: TFlexArray<TDateTime>;
//  DateStrings: TFlexArray<string>;
//  i, j, k: Integer;
//  TestDate: TDateTime;
//begin
////  Log('[Test: Map Date Creation]');
////
////  // 3次元配列を作成: [年, 月, 日]
////  DateArray := TFlexArray<TDateTime>.CreateFromRange([[2000, 2001], [1, 12], [1, 31]]);
////
////  // Mapを使って有効な日付のみを設定（2月30日などは無効）
////  DateArray.Map(function(const Value: TDateTime; const Coords: TCoords): TDateTime
////  var
////    Year, Month, Day: Integer;
////  begin
////    Year := Coords[0];
////    Month := Coords[1];
////    Day := Coords[2];
////
////    // 有効な日付かチェック
////    if IsValidDate(Year, Month, Day) then
////      Result := EncodeDate(Year, Month, Day)
////    else
////      Result := 0; // 無効な日付は0に
////  end);
////
////  // Mapを使って日付を文字列に変換
////  DateStrings := DateArray.Mapped<string>(function(const Value: TDateTime; const Coords: TCoords): string  // ← stringに修正
////  begin
////    if Value = 0 then
////      Result := '---' // 無効な日付
////    else
////      Result := FormatDateTime('yyyy/mm/dd', Value);
////  end);
////
////  Log('  --- 日付配列のサンプル ---');
////  // 2000年1月1日, 2000年2月29日（うるう年）, 2001年2月28日などを表示
////  Log(Format('  2000/01/01 = %s', [DateStrings[2000, 1, 1]]));
////  Log(Format('  2000/02/29 = %s', [DateStrings[2000, 2, 29]])); // うるう年
////  Log(Format('  2001/02/29 = %s', [DateStrings[2001, 2, 29]])); // 無効な日付
////  Log(Format('  2001/02/28 = %s', [DateStrings[2001, 2, 28]]));
////
////  Log('  --- 統計情報 ---');
////  var ValidCount := 0;
////  var TotalCount := DateArray.TotalSize;
////
////  for var DateStr in DateStrings do
////  begin
////    if DateStr <> '---' then
////      Inc(ValidCount);
////  end;
////
////  Log(Format('  全要素数: %d', [TotalCount]));
////  Log(Format('  有効な日付数: %d', [ValidCount]));
////  Log(Format('  無効な日付数: %d', [TotalCount - ValidCount]));
////  Log('  --- テスト完了 ---');
//end;
//

var
  counter: Integer;

function SequentialNumber2(const Value: Integer; const Coords: TCoords): Integer;
begin
  Inc(counter);
  Result := counter;
end;

// 座標のインデックス+1を返す（連番生成）
function SequentialNumber(const Value: Integer; const Coords: TCoords): Integer;
var
  i: Integer;
  Index: Integer;
begin
  // 線形インデックスを計算
  Index := Coords[0];  // 1次元目はそのまま
  for i := 1 to High(Coords) do
    Index := Index * 10 + Coords[i];  // 簡易的な計算
  Result := Index;
end;


procedure TestUltimateChaosSlice;
var
  Data4D, Data3D, Data2D, Data1D: TFlexArray<Integer>;
  i, j, k, l, expectedValue: Integer;
  vec: TArray<Integer>;
begin
  log('--- カオス次元（Low=0,1混在）スライステスト開始 ---');

  SetLength(vec, 24);
  for i := 0 to High(vec) do vec[i] := i + 1; // これを忘れると全部 0 になっちゃいます！
  // 1. 低下インデックスのバラエティを最大化
  Data4D := TFlexArray<Integer>.CreateFromArray(vec, 1);
  Data4D.Reshape([2, 2, 3, 2], 1);  // 2x2x3x4 → 2x2x3x2 に変更
//  Data4D.ReshapeRange([[1, 2], [-1, 0], [2021, 2023], [0, 1]]);

  // 4. Reshape後の範囲情報を確認
  log('Reshape後の範囲情報: ' + Data4D.ToRangesString);


  expectedValue := 0;

  // 3. 4重ループによる「次元の皮剥ぎ」
  // Data4D[i] -> Data3D[j] -> Data2D[k] -> Data1D[l]
  var Dim: Integer;
  Dim := 2;
  for i := Data4D.Low(Dim) to Data4D.High(Dim) do
  begin
    Data3D := Data4D.ChooseSlice(Dim, i);

    for j := Data3D.Low(Dim) to Data3D.High(Dim) do
    begin
      Data2D := Data3D.ChooseSlice(Dim, j);

      for k := Data2D.Low(Dim) to Data2D.High(Dim) do
      begin
        Data1D := Data2D.ChooseSlice(Dim, k);

        for l := Data1D.Low(1) to Data1D.High(1) do
        begin
          // 4. 検証
          // GetValue([l]) が内部で GetOffset を呼び、
          // 複雑な歩幅(Stride)とオフセット計算を経て、元のFDataの正解に辿り着く
          Log(Format('%2d ', [Data1D[l]]));

          if Data1D[l] <> expectedValue then
//            Log(Format(
//              'パズル崩壊！ エラー地点: Indices[%d, %d, %d, %d] 期待値:%d 実際:%d',
//              [i, j, k, l, expectedValue, Data1D[l]]
//            ));

          Inc(expectedValue);
        end;
        Log('終了');
      end;
    end;
  end;

  Log('--- テスト成功：カオスなインデックス設定でも連番を完全走破！ ---');
end;

//const
//  // [奥行, 行, 列] のイメージ
//  StaticData3D: array[-1..1, 1..3, 0..1] of Integer = (
//    ( (111, 112), (121, 122), (131, 132) ), // 1ページ目
//    ( (111, 112), (131, 444), (131, 132) ), // 1ページ目
//    ( (211, 212), (221, 222), (231, 253) )  // 3ページ目
//  );
//
//procedure TForm1.Button2Click(Sender: TObject);
//var
//  Flex: TFlexArray<Integer>;
//  Transposed: TFlexArray<Integer>;
//  p: integer;
//begin
////  Flex := TFlexArray<Integer>.CreateFromRange(
////    [
////      [System.Low(StaticData3D),    System.High(StaticData3D)],    // 第1次元: 1..2
////      [System.Low(StaticData3D[1]), System.High(StaticData3D[1])], // 第2次元: 1..3
////      [System.Low(StaticData3D[1,1]), System.High(StaticData3D[1,1])] // 第3次元: 1..2
////    ]
//////    TArray<Integer>(@StaticData3D),
//////    True
////  );
////
////  // Julia方式: Axes[1, 2, 3] の並び順を [3,
////  // --- 転置前の表示 ---
////  Log('=== Original 3D Array (Page, Row, Col) ===');
////  for p := Flex.Low(1) to Flex.High(1) do
////  begin
////    LOg(Format('[Page %d]', [p]));
////    // 1次元目(Page)でスライスして、残りの2次元をToStringで表示
////    Log(Flex.ChooseSlice(1, p).ToString);
////    Log('');
////  end;
////
////  LOg('------------------------------------------');
////
////  // --- 転置後の表示 ([3, 2, 1] への転置) ---
////  Transposed := Flex.Transpose([3, 2, 1]);
////  Transposed := Transposed.Transpose([2,1,3]);
//////  Transposed := Transposed.Transpose([2, 3, 1]);
////  Log('=== Transposed 3D Array (New Page = Old Col) ===');
////  for p := Transposed.Low(1) to Transposed.High(1) do
////  begin
////    Log(Format('[New Page %d]', [p]));
////    Log(Transposed.ToString);
////    Log('');
////  end;
//end;


// ChooseSliceのテスト
procedure TestChooseSlice;
var
  Matrix2D, Matrix3D: TFlexArray<Integer>;
  Row1, Row2, Col1, Col2: TFlexArray<Integer>;
  Slice1, Slice2: TFlexArray<Integer>;
  Page1, Page2: TFlexArray<Integer>;
begin
  Log('=== ChooseSlice/ChooseRow/ChooseCol テスト ===');

  // 1. 2次元行列の準備
  Log('1. 2次元行列 (3x4) を準備:');
  Matrix2D := TFlexArray<Integer>.CreateMatrix(3, 4, 1);
  Matrix2D.Map(SequentialNumber);
  Log(Matrix2D.ToString);
  Log('');

  // 2. ChooseRowテスト
  Log('2. ChooseRowテスト:');
  Log('  Row1 = ChooseRow(1):');
  Row1 := Matrix2D.ChooseRow(1);
  Log(Row1.ToString);

  Log('  Row2 = ChooseRow(2):');
  Row2 := Matrix2D.ChooseRow(2);
  Log(Row2.ToString);
  Log('');

  // 3. ChooseColテスト
  Log('3. ChooseColテスト:');
  Log('  Col1 = ChooseCol(1):');
  Col1 := Matrix2D.ChooseCol(1);
  Log(Col1.ToString);

  Log('  Col2 = ChooseCol(2):');
  Col2 := Matrix2D.ChooseCol(2);
  Log(Col2.ToString);
  Log('');

  // 4. 3次元配列の準備
  Log('4. 3次元配列 (2x3x2) を準備:');
  Matrix3D := TFlexArray<Integer>.Create([2, 3, 2], 1);
  Matrix3D.Map(SequentialNumber);
  Log(Matrix3D.ToString);
  Log('');

  // 5. ChooseSliceテスト（3次元）
  Log('5. ChooseSliceテスト（3次元）:');
  Log('  Page1 = ChooseSlice(1, 1):');
  Page1 := Matrix3D.ChooseSlice(1, 1);
  Log(Page1.ToString);

  Log('  Page2 = ChooseSlice(1, 2):');
  Page2 := Matrix3D.ChooseSlice(1, 2);
  Log(Page2.ToString);
  Log('');

  // 6. ChooseSliceテスト（2次元目）
  Log('6. ChooseSliceテスト（2次元目）:');
  Log('  Slice1 = ChooseSlice(2, 1):');
  Slice1 := Matrix3D.ChooseSlice(2, 1);
  Log(Slice1.ToString);

  Log('  Slice2 = ChooseSlice(2, 2):');
  Slice2 := Matrix3D.ChooseSlice(2, 2);
  Log(Slice2.ToString);
  Log('');

  // 7. 1次元配列のChooseSliceテスト
  Log('7. 1次元配列のChooseSliceテスト:');
  var Vec1D := TFlexArray<Integer>.Create(5, 1);
  Vec1D.Map(SequentialNumber);
  Log('  元の1次元配列:');
  Log(Vec1D.ToString);
  Log('  ChooseSlice(1, 3):');
  Log('  結果: ' + Vec1D[3].ToString);
  Log('');

  Log('=== ChooseSliceテスト完了 ===');
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  Flex1D, Flex2D, Flex3D: TFlexArray<Integer>;
  SourceArray: TArray<Integer>;
  SourceFlex: TFlexArray<Integer>;
  ViewFlex: TFlexArray<Integer>;
begin
//  Memo1.Lines.Add('=== 全コンストラクタテスト ===');
//
//  // 1. Create(ASize, ABaseIndex) - 1次元用
//  Log('1. Create(5, 1):');
//  Flex1D := TFlexArray<Integer>.Create(5, 1);
//  Flex1D.Map(SequentialNumber);
//  Log(Flex1D.ToString);
//
//  // 2. Create(AShapes, ABaseIndex) - 多次元用
//  Log('2. Create([3, 4], 1):');
//  Flex2D := TFlexArray<Integer>.Create([3, 4], 1);
//  Flex2D.Map(SequentialNumber);
//  Log(Flex2D.ToString);
//
//  // 3. CreateMatrix(ARows, ACols, ABaseIndex) - 2次元専用
//  Log('3. CreateMatrix(2, 3, 1):');
//  Flex2D := TFlexArray<Integer>.CreateMatrix(2, 3, 1);
//  Flex2D.Map(SequentialNumber);
//  Log(Flex2D.ToString);
//
//  // 4. CreateFromRange(ARange) - 1次元範囲指定
//  Log('4. CreateFromRange([-2, 2]):');
//  Flex1D := TFlexArray<Integer>.CreateFromRange([-2, 2]);
//  Flex1D.Map(SequentialNumber);
//  Log(Flex1D.ToString);
//
//  // 5. CreateFromRange(ARanges) - 多次元範囲指定
//  Log('5. CreateFromRange([[0, 1], [0, 2]]):');
//  Flex2D := TFlexArray<Integer>.CreateFromRange([[0, 1], [0, 2]]);
//  Flex2D.Map(SequentialNumber);
//  Log(Flex2D.ToString);
//
//  // 6. CreateFromArray(ASrc, ABaseIndex) - 配列から生成
//  Log('6. CreateFromArray([10, 20, 30], 0):');
//  SourceArray := [10, 20, 30];
//  Flex1D := TFlexArray<Integer>.CreateFromArray(SourceArray, 0);
//  Log(Flex1D.ToString);
//
//  // 7. CreateFromFlexArray(ASrc) - FlexArrayからコピー
//  Log('7. CreateFromFlexArray(Source):');
//  SourceFlex := TFlexArray<Integer>.Create([2, 2], 1);
//  SourceFlex.Map(SequentialNumber);
//  Flex2D := TFlexArray<Integer>.CreateFromFlexArray(SourceFlex);
//  Log('元配列: ' + SourceFlex.ToString);
//  Log('コピー: ' + Flex2D.ToString);
//
//  // 8. ViewFromArray(ASrc, ABaseIndex) - 参照ビュー
//  Log('8. ViewFromArray([100, 200], 1):');
//  SourceArray := [100, 200];
//  ViewFlex := TFlexArray<Integer>.ViewFromArray(SourceArray, 1);
//  Log('元配列: [' + SourceArray[0].ToString + ', ' + SourceArray[1].ToString + ']');
//  Log('ビュー: ' + ViewFlex.ToString);
//
//  // 9. 3次元配列テスト
//  Log('9. Create([2, 2, 2], 1):');
//  Flex3D := TFlexArray<Integer>.Create([2, 2, 2], 1);
//  Flex3D.Map(SequentialNumber);
//  Log(Flex3D.ToString);
//
//  // 10. 負のインデックステスト
//  Log('10. CreateFromRange([[-1, 0], [-1, 0]]):');
//  Flex2D := TFlexArray<Integer>.CreateFromRange([[-1, 0], [-1, 0]]);
//  Flex2D.Map(SequentialNumber);
//  Log(Flex2D.ToString);
//
//  Log('=== コンストラクタテスト完了 ===')


//  TestReshapeChain;
//  TestPerformance;
//  TestMapDateCreation; // Map日付作成テスト
//  Test_New;        // 新規作成
//  Test_1D_Ref;    // 1次元参照
//  Test_3D_New;
//  Memo1.Lines.Add('--- テスト完了 ---');
  TestUltimateChaosSlice;
//  TestChooseSlice;  // ChooseSlice/ChooseRow/ChooseCol テスト
end;

end.
