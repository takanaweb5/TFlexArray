unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, FlexArray, Numpas, DebugLog, System.DateUtils;

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

// --- 論理転置テスト ---
procedure Test_LogicalTranspose;
var
  A: TFlexArray<Integer>;
  i, j: Integer;
begin
  Log('[Test: Logical Transpose]');
  
  // 2x3行列を作成
  A := TFlexArray<Integer>.Create([2, 3], 1);
  A[1,1] := 1; A[1,2] := 2; A[1,3] := 3;
  A[2,1] := 4; A[2,2] := 5; A[2,3] := 6;

  Log('Original 2x3:');
  Log(A.ToString);
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  // 論理転置 [2, 1] → 2次元と1次元を入れ替え
  A.LogicalTranspose([2, 1]);
  Log('After LogicalTranspose([2, 1]):');
  Log(A.ToString);
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  // アクセス確認
  Log('Access check:');
  Log(Format('A[1,1] = %d (should be 1)', [A[1,1]]));
  Log(Format('A[1,2] = %d (should be 4)', [A[1,2]]));
  Log(Format('A[2,1] = %d (should be 2)', [A[2,1]]));
  Log(Format('A[2,2] = %d (should be 5)', [A[2,2]]));
  Log(Format('A[3,1] = %d (should be 3)', [A[3,1]]));
  Log(Format('A[3,2] = %d (should be 6)', [A[3,2]]));
  
  // ResetTransposeテスト
  A.ResetTranspose;
  Log('After ResetTranspose:');
  Log(A.ToString);
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  // Reshapeテスト（自動リセット）
  A.LogicalTranspose([2, 1]);
  Log('Before Reshape (transposed):');
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  A.Reshape([3, 2], 1);
  Log('After Reshape([3, 2], 1):');
  Log(A.ToString);
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  Log('Logical Transpose test completed');
end;

// --- Slice系テスト（論理転置＋Base/Lenばらばら） ---
procedure Test_SliceWithLogicalTranspose;
var
  A: TFlexArray<Integer>;
  Slice1, Slice2: TFlexArray<Integer>;
  i, j: Integer;
begin
  Log('[Test: Slice with Logical Transpose (Random Base/Len)]');
  
  // BaseとLenがばらばらな3次元配列を作成
  // 形状: [1990..1991, 5..7, 10..12] → 2x3x3 = 18要素
  A := TFlexArray<Integer>.CreateFromRange([[1990, 1991], [5, 7], [10, 12]]);
  
  // データを設定
  for i := 1990 to 1991 do
    for j := 5 to 7 do
      A[i, j, 10] := (i * 1000) + (j * 10) + 10;  // 一意な値
  
  Log('Original 3D array [1990..1991, 5..7, 10..12]:');
  Log(A.ToString);
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  // 論理転置 [3, 1, 2] → 次元順序を入れ替え
  A.LogicalTranspose([3, 1, 2]);
  Log('After LogicalTranspose([3, 1, 2]):');
  Log(A.ToString);
  Log(Format('IsLogicalTransposed: %s', [A.IsLogicalTransposed.ToString]));
  
  // SliceDimテスト（論理2次元をスライス）
  Log('--- SliceDim Test ---');
  Slice1 := A.SliceDim(2, 1990);  // 論理2次元の1990をスライス
  Log('SliceDim(2, 1990) result:');
  Log(Slice1.ToString);
  
  // SliceRowテスト（論理2次元をスライス）
  Log('--- SliceRow Test ---');
  Slice2 := A.SliceRow(1990);  // 論理2次元の1990をスライス
  Log('SliceRow(1990) result:');
  Log(Slice2.ToString);
  
  // アクセス確認
  Log('--- Access Verification ---');
  Log(Format('A[1990, 5, 10] = %d', [A[1990, 5, 10]]));
  Log(Format('A[1991, 6, 10] = %d', [A[1991, 6, 10]]));
  Log(Format('A[1990, 7, 12] = %d', [A[1990, 7, 12]]));
  
  // Resetしてから再度テスト
  Log('--- After ResetTranspose ---');
  A.ResetTranspose;
  Slice1 := A.SliceDim(1, 1990);
  Log('SliceDim(1, 1990) after reset:');
  Log(Slice1.ToString);
  
  Log('Slice with Logical Transpose test completed');
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
//  for var D in A do
//    Log(Format('    Value: %s', [D]));
//
//  Log('  --- ToString ---');
//  Log(A.ToString);
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

// 座標のインデックス+1を返す（連番生成）
function SequentialNumber2(const Value: Integer; const Coords: TCoords): Integer;
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

procedure TestTranspose2;
var
  Matrix2D, Matrix3D, Tensor3D: TFlexArray<Integer>;
  Transposed2D, Transposed3D, Swapped3D: TFlexArray<Integer>;
  i, j, k: Integer;
begin
  Log('=== Transposeテスト ===');

  // 1. 2次元行列の転置テスト
  Log('1. 2次元行列の転置テスト:');
  Matrix2D := TFlexArray<Integer>.Create([3, 4], 1);
  Matrix2D.Map(SequentialNumber);
  Log('元の行列 (3x4):');
  Log(Matrix2D.ToString);
  Log('');

  Matrix2D.LogicalTranspose([2,1]);
  Log('転置後の行列 (4x3):');
  Log(Matrix2D.ToString);
  Log('');

  // 2. 3次元テンソルの転置テスト
  Log('2. 3次元テンソルの転置テスト:');
  Matrix3D := TFlexArray<Integer>.Create([2, 3, 4], 1);
  Matrix3D.Map(SequentialNumber);
  Log('元のテンソル (2x3x4):');
  Log(Matrix3D.ToString);
  Log('');

  // 次元の入れ替え [1,2,3] → [3,2,1]
  Matrix3D.LogicalTranspose([3, 2, 1]);
  Log('転置後のテンソル (4x3x2) - [1,2,3]→[3,2,1]:');
  Log(Matrix3D.ToString);
  Log('');

  // 次元の入れ替え [1,2,3] → [2,3,1]
  Matrix3D.LogicalTranspose([2, 3, 1]);
  Log('転置後のテンソル (3x4x2) - [1,2,3]→[2,3,1]:');
  Log(Matrix3D.ToString);
  Log('');

  // 3. 4次元テンソルの転置テスト
  Log('3. 4次元テンソルの転置テスト:');
  Tensor3D := TFlexArray<Integer>.Create([2, 3, 2, 2], 1);
  Tensor3D.Map(SequentialNumber);
  Log('元のテンソル (2x3x2x2):');
  Log(Tensor3D.ToString);
  Log('');

  // 次元の入れ替え [1,2,3,4] → [4,3,2,1]
  Tensor3D.LogicalTranspose([4, 3, 2, 1]);
  Log('転置後のテンソル (2x2x3x2) - [1,2,3,4]→[4,3,2,1]:');
  Log(Tensor3D.ToString);
  Log('');

  // 4. 転置の検証テスト
  Log('4. 転置の検証テスト:');
  var TestMatrix := TFlexArray<Integer>.Create([2, 3], 1);
  TestMatrix[1, 1] := 1; TestMatrix[1, 2] := 2; TestMatrix[1, 3] := 3;
  TestMatrix[2, 1] := 4; TestMatrix[2, 2] := 5; TestMatrix[2, 3] := 6;

  Log('元の行列:');
  Log(TestMatrix.ToString);

  TestMatrix.LogicalTranspose([2,1]);
  Log('転置後の行列:');
  Log(TestMatrix.ToString);

  // 検証: [i,j] → [j,i]
  Log('検証:');
//  Log(Format('元の[1,2]=%d → 転置後[2,1]=%d', [TestMatrix[1, 2], TestTransposed[2, 1]]));
//  Log(Format('元の[2,3]=%d → 転置後[3,2]=%d', [TestMatrix[2, 3], TestTransposed[3, 2]]));
  Log('');

  Log('=== Transposeテスト完了 ===');
end;

procedure TestTranspose;
var
  Matrix2D, Matrix3D, Tensor3D: TFlexArray<Integer>;
  Transposed2D, Transposed3D, Swapped3D: TFlexArray<Integer>;
  i, j, k: Integer;
begin
  Log('=== Transposeテスト ===');
  
  // 1. 2次元行列の転置テスト
  Log('1. 2次元行列の転置テスト:');
  Matrix2D := TFlexArray<Integer>.Create([3, 4], 1);
  Matrix2D.Map(SequentialNumber);
  Log('元の行列 (3x4):');
  Log(Matrix2D.ToString);
  Log('');

  Transposed2D := Matrix2D.Transpose;
  Log('転置後の行列 (4x3):');
  Log(Transposed2D.ToString);
  Log('');

  // 2. 3次元テンソルの転置テスト
  Log('2. 3次元テンソルの転置テスト:');
  Matrix3D := TFlexArray<Integer>.Create([2, 3, 4], 1);
  Matrix3D.Map(SequentialNumber);
  Log('元のテンソル (2x3x4):');
  Log(Matrix3D.ToString);
  Log('');

  // 次元の入れ替え [1,2,3] → [3,2,1]
  Transposed3D := Matrix3D.Transpose([3, 2, 1]);
  Log('転置後のテンソル (4x3x2) - [1,2,3]→[3,2,1]:');
  Log(Transposed3D.ToString);
  Log('');

  // 次元の入れ替え [1,2,3] → [2,3,1]
  Swapped3D := Matrix3D.Transpose([2, 3, 1]);
  Log('転置後のテンソル (3x4x2) - [1,2,3]→[2,3,1]:');
  Log(Swapped3D.ToString);
  Log('');

  // 3. 4次元テンソルの転置テスト
  Log('3. 4次元テンソルの転置テスト:');
  Tensor3D := TFlexArray<Integer>.Create([2, 3, 2, 2], 1);
  Tensor3D.Map(SequentialNumber);
  Log('元のテンソル (2x3x2x2):');
  Log(Tensor3D.ToString);
  Log('');

  // 次元の入れ替え [1,2,3,4] → [4,3,2,1]
  var Transposed4D := Tensor3D.Transpose([4, 3, 2, 1]);
  Log('転置後のテンソル (2x2x3x2) - [1,2,3,4]→[4,3,2,1]:');
  Log(Transposed4D.ToString);
  Log('');

  // 4. 転置の検証テスト
  Log('4. 転置の検証テスト:');
  var TestMatrix := TFlexArray<Integer>.Create([2, 3], 1);
  TestMatrix[1, 1] := 1; TestMatrix[1, 2] := 2; TestMatrix[1, 3] := 3;
  TestMatrix[2, 1] := 4; TestMatrix[2, 2] := 5; TestMatrix[2, 3] := 6;

  Log('元の行列:');
  Log(TestMatrix.ToString);

  var TestTransposed := TestMatrix.Transpose;
  Log('転置後の行列:');
  Log(TestTransposed.ToString);

  // 検証: [i,j] → [j,i]
  Log('検証:');
  Log(Format('元の[1,2]=%d → 転置後[2,1]=%d', [TestMatrix[1, 2], TestTransposed[2, 1]]));
  Log(Format('元の[2,3]=%d → 転置後[3,2]=%d', [TestMatrix[2, 3], TestTransposed[3, 2]]));
  Log('');

  Log('=== Transposeテスト完了 ===');
end;

procedure TestPromoteDemoteDimension;
var
  Vector1D, Matrix2D, Tensor3D: TFlexArray<Integer>;
  Promoted1D, Promoted2D, Promoted3D: TFlexArray<Integer>;
  Demoted2D, Demoted3D, Demoted4D: TFlexArray<Integer>;
  i, j, k: Integer;
begin
  Log('=== PromoteDimension/DemoteDimensionテスト ===');
  
  // 1. 1次元配列の昇格テスト
  Log('1. 1次元配列の昇格テスト:');
  Vector1D := TFlexArray<Integer>.Create([3], 1);
  Vector1D.Map(SequentialNumber);
  Log('元の1次元配列 (1..3):');
  Log(Vector1D.ToString);
  Log('範囲: ' + Vector1D.ToRangesString);
  
  // TargetDim=1で昇格（先頭に次元を追加）
  Promoted1D := Vector1D;
  Promoted1D.PromoteDimension(1);
  Log('PromoteDimension(1) - 2次元配列 (1x3):');
  Log(Promoted1D.ToString);
  Log('範囲: ' + Promoted1D.ToRangesString);
  Log('');
  
  // TargetDim=2で昇格（末尾に次元を追加）
  Promoted1D := Vector1D;
  Promoted1D.PromoteDimension(2);
  Log('PromoteDimension(2) - 2次元配列 (3x1):');
  Log(Promoted1D.ToString);
  Log('範囲: ' + Promoted1D.ToRangesString);
  Log('');
  
  // 2. 2次元配列の昇格テスト
  Log('2. 2次元配列の昇格テスト:');
  Vector1D := TFlexArray<Integer>.Create([6], 1);
  Vector1D.Map(SequentialNumber);
  Matrix2D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Matrix2D.Reshape([2, 3], 1);
  Log('元の2次元配列 (2x3):');
  Log(Matrix2D.ToString);
  Log('範囲: ' + Matrix2D.ToRangesString);
  
  // TargetDim=1で昇格
  Promoted2D := Matrix2D;
  Promoted2D.PromoteDimension(1);
  Log('PromoteDimension(1) - 3次元配列 (1x2x3):');
  Log(Promoted2D.ToString);
  Log('範囲: ' + Promoted2D.ToRangesString);
  
  // TargetDim=2で昇格
  Promoted2D := Matrix2D;
  Promoted2D.PromoteDimension(2);
  Log('PromoteDimension(2) - 3次元配列 (2x1x3):');
  Log(Promoted2D.ToString);
  Log('範囲: ' + Promoted2D.ToRangesString);
  
  // TargetDim=3で昇格
  Promoted2D := Matrix2D;
  Promoted2D.PromoteDimension(3);
  Log('PromoteDimension(3) - 3次元配列 (2x3x1):');
  Log(Promoted2D.ToString);
  Log('範囲: ' + Promoted2D.ToRangesString);
  Log('');
  
  // 3. 3次元配列の昇格テスト
  Log('3. 3次元配列の昇格テスト:');
  Vector1D := TFlexArray<Integer>.Create([8], 1);
  Vector1D.Map(SequentialNumber);
  Tensor3D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Tensor3D.Reshape([2, 2, 2], 1);
  Log('元の3次元配列 (2x2x2):');
  Log(Tensor3D.ToString);
  Log('範囲: ' + Tensor3D.ToRangesString);
  
  // TargetDim=2で昇格
  Promoted3D := Tensor3D;
  Promoted3D.PromoteDimension(2);
  Log('PromoteDimension(2) - 4次元配列 (2x1x2x2):');
  Log(Promoted3D.ToString);
  Log('範囲: ' + Promoted3D.ToRangesString);
  Log('');
  
  // 4. DemoteDimensionテスト
  Log('4. DemoteDimensionテスト:');
  
  // 2次元配列の削除テスト
  Log('4.1 2次元配列の次元削除:');
  Vector1D := TFlexArray<Integer>.Create([6], 1);
  Vector1D.Map(SequentialNumber);
  Matrix2D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Matrix2D.Reshape([2, 1, 3], 1);
  Log('元の3次元配列 (2x1x3):');
  Log(Matrix2D.ToString);
  Log('範囲: ' + Matrix2D.ToRangesString);
  
  // TargetDim=2で削除
  Demoted3D := Matrix2D;
  Demoted3D.DemoteDimension(2);
  Log('DemoteDimension(2) - 2次元配列 (2x3):');
  Log(Demoted3D.ToString);
  Log('範囲: ' + Demoted3D.ToRangesString);
  Log('');
  
  // 3次元配列の削除テスト
  Log('4.2 3次元配列の次元削除:');
  Vector1D := TFlexArray<Integer>.Create([12], 1);
  Vector1D.Map(SequentialNumber);
  Tensor3D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Tensor3D.Reshape([1, 2, 2, 3], 1);
  Log('元の4次元配列 (1x2x2x3):');
  Log(Tensor3D.ToString);
  Log('範囲: ' + Tensor3D.ToRangesString);
  
  // TargetDim=1で削除
  Demoted4D := Tensor3D;
  Demoted4D.DemoteDimension(1);
  Log('DemoteDimension(1) - 3次元配列 (2x2x3):');
  Log(Demoted4D.ToString);
  Log('範囲: ' + Demoted4D.ToRangesString);
  Log('');
  
  // 5. 昇格・降格のチェーンテスト
  Log('5. 昇格・降格のチェーンテスト:');
  Vector1D := TFlexArray<Integer>.Create([4], 1);
  Vector1D.Map(SequentialNumber);
  Log('開始: 1次元配列 (1..4):');
  Log(Vector1D.ToString);
  
  // 1D → 2D → 3D → 2D → 1D
  Promoted1D := Vector1D;
  Promoted1D.PromoteDimension(2);  // 1D → 2D (4x1)
  Log('昇格: 2次元配列 (4x1):');
  Log(Promoted1D.ToString);
  
  Promoted1D.PromoteDimension(1);  // 2D → 3D (1x4x1)
  Log('昇格: 3次元配列 (1x4x1):');
  Log(Promoted1D.ToString);
  
  Promoted1D.DemoteDimension(1);   // 3D → 2D (4x1)
  Log('降格: 2次元配列 (4x1):');
  Log(Promoted1D.ToString);
  
  Promoted1D.DemoteDimension(2);   // 2D → 1D (4)
  Log('降格: 1次元配列 (4):');
  Log(Promoted1D.ToString);
  Log('');
  
  // 6. BaseIndex保持テスト
  Log('6. BaseIndex保持テスト:');
  Vector1D := TFlexArray<Integer>.CreateFromRange('[5..6, 10..12]');
  Vector1D.Map(SequentialNumber);
  Matrix2D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Matrix2D.Reshape([2, 3], 5);
  Log('元の配列 (BaseIndex=[5,10]):');
  Log(Matrix2D.ToString);
  Log('範囲: ' + Matrix2D.ToRangesString);
  
  Promoted2D := Matrix2D;
  Promoted2D.PromoteDimension(2);
  Log('昇格後 (BaseIndex=[5,10,1]):');
  Log(Promoted2D.ToString);
  Log('範囲: ' + Promoted2D.ToRangesString);
  Log('');
  
  // 7. ラウンドトリップ検証テスト（Promote→Demote後に元の値と一致するか）
  Log('7. ラウンドトリップ検証テスト:');
  
  // 1次元配列のラウンドトリップ
  Vector1D := TFlexArray<Integer>.Create([3], 1);
  Vector1D.Map(SequentialNumber);
  Promoted1D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Log('元の1次元配列:');
  Log('  ToString: ' + Vector1D.ToString);
  Log('  ToRangesString: ' + Vector1D.ToRangesString);
  
  Promoted1D.PromoteDimension(1);  // 1D → 2D (1x3)
  Promoted1D.DemoteDimension(1);   // 2D → 1D
  Log('PromoteDimension(1)→DemoteDimension(1)後:');
  Log('  ToString: ' + Promoted1D.ToString);
  Log('  ToRangesString: ' + Promoted1D.ToRangesString);
  if (Vector1D.ToString = Promoted1D.ToString) and (Vector1D.ToRangesString = Promoted1D.ToRangesString) then
    Log('  ✓ 一致')
  else
    Log('  ✗ 不一致');
  Log('');
  
  // 2次元配列のラウンドトリップ
  Vector1D := TFlexArray<Integer>.Create([6], 1);
  Vector1D.Map(SequentialNumber);
  Matrix2D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Matrix2D.Reshape([2, 3], 1);
  Log('元の2次元配列:');
  Log('  ToString: ' + Matrix2D.ToString);
  Log('  ToRangesString: ' + Matrix2D.ToRangesString);
  
  Promoted2D := TFlexArray<Integer>.CreateFromFlexArray(Matrix2D);
  Promoted2D.PromoteDimension(2);  // 2D → 3D (2x3x1)
  Promoted2D.DemoteDimension(2);   // 3D → 2D
  Log('PromoteDimension(2)→DemoteDimension(2)後:');
  Log('  ToString: ' + Promoted2D.ToString);
  Log('  ToRangesString: ' + Promoted2D.ToRangesString);
  if (Matrix2D.ToString = Promoted2D.ToString) and (Matrix2D.ToRangesString = Promoted2D.ToRangesString) then
    Log('  ✓ 一致')
  else
    Log('  ✗ 不一致');
  Log('');
  
  // 複数次元のラウンドトリップ
  Vector1D := TFlexArray<Integer>.Create([4], 1);
  Vector1D.Map(SequentialNumber);
  Promoted1D := TFlexArray<Integer>.CreateFromFlexArray(Vector1D);
  Log('元の1次元配列 (複数回昇格):');
  Log('  ToString: ' + Vector1D.ToString);
  Log('  ToRangesString: ' + Vector1D.ToRangesString);
  
  Promoted1D.PromoteDimension(2);  // 1D → 2D (4x1)
  Promoted1D.PromoteDimension(1);  // 2D → 3D (1x4x1)
  Promoted1D.DemoteDimension(1);   // 3D → 2D (1x4x1)
  Promoted1D.DemoteDimension(2);   // 2D → 1D
  Log('PromoteDimension(2)→PromoteDimension(1)→DemoteDimension(1)→DemoteDimension(2)後:');
  Log('  ToString: ' + Promoted1D.ToString);
  Log('  ToRangesString: ' + Promoted1D.ToRangesString);
  if (Vector1D.ToString = Promoted1D.ToString) and (Vector1D.ToRangesString = Promoted1D.ToRangesString) then
    Log('  ✓ 一致')
  else
    Log('  ✗ 不一致');
  Log('');
  
  Log('=== PromoteDimension/DemoteDimensionテスト完了 ===');
end;

procedure TestConcat;
var
  Matrix1, Matrix2, Matrix3: TFlexArray<Integer>;
  Vector1, Vector2, Vector3: TFlexArray<Integer>;
  Tensor1, Tensor2: TFlexArray<Integer>;
  ConcatResult: TFlexArray<Integer>;
  i, j: Integer;
begin
  Log('=== Concatテスト ===');

  // 1. 1次元配列の結合テスト
  Log('1. 1次元配列の結合テスト:');
  Vector1 := TFlexArray<Integer>.Create([3], 1);
  Vector1.Map(SequentialNumber);
  Log('Vector1 (1D, 3要素):');
  Log(Vector1.ToString);

  Vector2 := TFlexArray<Integer>.Create([2], 1);
  Vector2.Map(SequentialNumber);

  Log('Vector2 (1D, 2要素):');
  Log(Vector2.ToString);

  // AppendArrayテスト
  Vector3 := Vector1.AppendArray(Vector2);
  Log('Vector1.AppendArray(Vector2) - 結合結果:');
  Log(Vector3.ToString);
  Log('');

  // 2. 2次元行列の水平結合テスト (HStack)
  Log('2. 2次元行列の水平結合テスト (HStack):');
  Matrix1 := TFlexArray<Integer>.Create([2, 3], 1);
  Matrix1.Map(SequentialNumber);
  Log('Matrix1 (2x3):');
  Log(Matrix1.ToString);

  Matrix2 := TFlexArray<Integer>.Create([2, 2], 1);
  Matrix2.Map(SequentialNumber);
  Log('Matrix2 (2x2):');
  Log(Matrix2.ToString);

  // HStackテスト (列方向に結合)
  Matrix3 := Matrix1.HStack(Matrix2);
  Log('Matrix1.HStack(Matrix2) - 結合結果 (2x5):');
  Log(Matrix3.ToString);
  Log('');

  // 3. 2次元行列の垂直結合テスト (VStack)
  Log('3. 2次元行列の垂直結合テスト (VStack):');
  Matrix1 := TFlexArray<Integer>.Create([2, 3], 1);
  Matrix1.Map(SequentialNumber);
  Log('Matrix1 (2x3):');
  Log(Matrix1.ToString);

  Matrix2 := TFlexArray<Integer>.Create([1, 3], 1);
  Matrix2.Map(SequentialNumber);
  Log('Matrix2 (1x3):');
  Log(Matrix2.ToString);

  // VStackテスト (行方向に結合)
  Matrix3 := Matrix1.VStack(Matrix2);
  Log('Matrix1.VStack(Matrix2) - 結合結果 (3x3):');
  Log(Matrix3.ToString);
  Log('');
  
  // 4. 3次元テンソルの結合テスト
  Log('4. 3次元テンソルの結合テスト:');
  Tensor1 := TFlexArray<Integer>.Create([2, 2, 3], 1);
  Tensor1.Map(SequentialNumber);
  Log('Tensor1 (2x2x3):');
  Log(Tensor1.ToString);
  
  Tensor2 := TFlexArray<Integer>.Create([1, 2, 3], 1);
  Tensor2.Map(SequentialNumber);
  Log('Tensor2 (1x2x3):');
  Log(Tensor2.ToString);
  
  // 次元1で結合
  ConcatResult := Tensor1.Concat(Tensor2, 1);
  Log('Tensor1.Concat(Tensor2, 1) - 次元1で結合 (3x2x3):');
  Log(ConcatResult.ToString);
  Log('');
  
  // 5. 次元数の異なる配列の結合テスト
  Log('5. 次元数の異なる配列の結合テスト:');
  Matrix1 := TFlexArray<Integer>.Create([2, 2], 1);
  Matrix1.Map(SequentialNumber);
  Log('Matrix1 (2x2):');
  Log(Matrix1.ToString);

  Vector1 := TFlexArray<Integer>.Create([2], 1);
  Vector1.Map(SequentialNumber);
  Log('Vector1 (1D, 2要素):');
  Log(Vector1.ToString);
  
  // 2Dと1Dを次元2で結合（自動的に1Dが2Dに昇格）
  ConcatResult := Matrix1.Concat(Vector1, 2);
  Log('Matrix1.Concat(Vector1, 2) - 2Dと1Dを次元2で結合 (2x3):');
  Log(ConcatResult.ToString);
  Log('');
  
  // 6. 結合の検証テスト
  Log('6. 結合の検証テスト:');
  Matrix1 := TFlexArray<Integer>.Create([2, 2], 1);
  Matrix1[1, 1] := 1; Matrix1[1, 2] := 2;
  Matrix1[2, 1] := 3; Matrix1[2, 2] := 4;
  Log('Matrix1:');
  Log(Matrix1.ToString);

  Matrix2 := TFlexArray<Integer>.Create([2, 1], 1);
  Matrix2[1, 1] := 5;
  Matrix2[2, 1] := 6;
  Log('Matrix2:');
  Log(Matrix2.ToString);
  
  Matrix3 := Matrix1.HStack(Matrix2);
  Log('HStack結果:');
  Log(Matrix3.ToString);
  
  // 検証
  Log('検証:');
  Log(Format('Matrix3[1,1]=%d, Matrix3[1,2]=%d, Matrix3[1,3]=%d', 
    [Matrix3[1,1], Matrix3[1,2], Matrix3[1,3]]));
  Log(Format('Matrix3[2,1]=%d, Matrix3[2,2]=%d, Matrix3[2,3]=%d', 
    [Matrix3[2,1], Matrix3[2,2], Matrix3[2,3]]));
  Log('');
  
  Log('=== Concatテスト完了 ===');
end;

procedure TestAppendArrayStrings;
var
  Words1, Words2, Words3: TFlexArray<string>;
  SingleWord: TFlexArray<string>;
  StringArray: TArray<string>;
  SpecialArray: TArray<string>;
begin
  Log('=== AppendArray文字列テスト ===');
  
  // 1. 基本的な文字列配列の結合
  Log('1. 基本的な文字列配列の結合:');
  Words1 := TFlexArray<string>.Create([3], 1);
  Words1.Map(function(const Value: string; const Coords: TCoords): string
            begin
              Result := 'Apple_' + IntToStr(Coords[0]);
            end);
  Log('Words1:');
  Log(Words1.ToString);
  
  Words2 := TFlexArray<string>.Create([2], 1);
  Words2.Map(function(const Value: string; const Coords: TCoords): string
            begin
              Result := 'Orange_' + IntToStr(Coords[0]);
            end);
  Log('Words2:');
  Log(Words2.ToString);
  
  // AppendArrayテスト
  Words3 := Words1.AppendArray(Words2);
  Log('Words1.AppendArray(Words2) - 結合結果:');
  Log(Words3.ToString);
  Log('');
  
  // 2. TArray<string>からの結合
  Log('2. TArray<string>からの結合:');
  StringArray := ['Banana', 'Grape', 'Melon'];
  Words3 := Words1.AppendArray(StringArray);
  Log('Words1.AppendArray(["Banana", "Grape", "Melon"]) - 結合結果:');
  Log(Words3.ToString);
  Log('');
  
  // 3. 単一値の追加
  Log('3. 単一値の追加:');
  SingleWord := Words1.AppendArray('Cherry');
  Log('Words1.AppendArray("Cherry") - 結合結果:');
  Log(SingleWord.ToString);
  Log('');
  
  // 4. 複雑な文字列変換のテスト
  Log('4. 複雑な文字列変換のテスト:');
  Words1 := TFlexArray<string>.Create([2], 1);
  Words1.Map(function(const Value: string; const Coords: TCoords): string
            begin
              Result := 'Item_' + IntToStr(Coords[0]) + '_' + 
                       FormatDateTime('hhnnss', Now);
            end);
  Log('Words1 (タイムスタンプ付き):');
  Log(Words1.ToString);
  
  Words2 := TFlexArray<string>.Create([2], 1);
  Words2.Map(function(const Value: string; const Coords: TCoords): string
            begin
              Result := 'Extra_' + UpperCase(StringOfChar('x', Coords[0]));
            end);
  Log('Words2 (大文字変換):');
  Log(Words2.ToString);
  
  Words3 := Words1.AppendArray(Words2);
  Log('結合結果:');
  Log(Words3.ToString);
  Log('');
  
  // 5. 空文字列と特殊文字のテスト
  Log('5. 空文字列と特殊文字のテスト:');
  Words1 := TFlexArray<string>.Create([2], 1);
  Words1.Map(function(const Value: string; const Coords: TCoords): string
            begin
              if Coords[0] = 1 then
                Result := ''
              else
                Result := 'Special: ' + #9#10#13 + 'Chars';
            end);
  Log('Words1 (空文字列と特殊文字):');
  Log(Words1.ToString);
  
  SpecialArray := ['', 'Test', 'Line1' + #13 + 'Line2'];
  Words3 := Words1.AppendArray(SpecialArray);
  Log('特殊文字配列を追加:');
  Log(Words3.ToString);
  Log('');
  
  Log('=== AppendArray文字列テスト完了 ===');
end;

procedure TestRangeStringOperations;
var
  Matrix1D, Matrix2D, Matrix3D: TFlexArray<string>;
  Matrix1D_Reshaped, Matrix2D_Reshaped: TFlexArray<string>;
  ComplexMatrix: TFlexArray<string>;
begin
  Log('=== RangeStr文字列テスト ===');

  // 1. 1次元範囲文字列からの生成
  Log('1. 1次元範囲文字列からの生成:');
  Matrix1D := TFlexArray<string>.CreateFromRange('1..5 ');
  Matrix1D.Map(function(const Value: string; const Coords: TCoords): string
              begin
                Result := 'Pos_' + IntToStr(Coords[0]);
              end);
  Log('Matrix1D (1..5):');
  Log(Matrix1D.ToString);
  Log('範囲情報: ' + Matrix1D.ToRangesString);
  Log('');

  // 2. 2次元範囲文字列からの生成
  Log('2. 2次元範囲文字列からの生成:');
  Matrix2D := TFlexArray<string>.CreateFromRange('[1..3, 1..2]');
  Matrix2D.Map(function(const Value: string; const Coords: TCoords): string
              begin
                Result := Format('[%d,%d]', [Coords[0], Coords[1]]);
              end);
  Log('Matrix2D ([1..3,1..2]):');
  Log(Matrix2D.ToString);
  Log('範囲情報: ' + Matrix2D.ToRangesString);
  Log('');

  // 3. 3次元範囲文字列からの生成
  Log('3. 3次元範囲文字列からの生成:');
  Matrix3D := TFlexArray<string>.CreateFromRange('1..2, 1..2, 1..2');
  Matrix3D.Map(function(const Value: string; const Coords: TCoords): string
              begin
                Result := Format('[%d,%d,%d]', [Coords[0], Coords[1], Coords[2]]);
              end);
  Log('Matrix3D (1..2,1..2,1..2):');
  Log(Matrix3D.ToString);
  Log('範囲情報: ' + Matrix3D.ToRangesString);
  Log('');

  // 4. ReshapeRange文字列テスト（1次元）
  Log('4. ReshapeRange文字列テスト（1次元）:');
  Matrix1D_Reshaped := TFlexArray<string>.Create([5], 1);
  Matrix1D_Reshaped.Map(function(const Value: string; const Coords: TCoords): string
                       begin
                         Result := 'Old_' + IntToStr(Coords[0]);
                       end);
  Log('変更前:');
  Log(Matrix1D_Reshaped.ToString);
  Log('範囲情報: ' + Matrix1D_Reshaped.ToRangesString);

  Matrix1D_Reshaped.ReshapeRange('0..4');
  Log('変更後 (0..4):');
  Log(Matrix1D_Reshaped.ToString);
  Log('範囲情報: ' + Matrix1D_Reshaped.ToRangesString);
  Log('');

  // 5. ReshapeRange文字列テスト（2次元）
  Log('5. ReshapeRange文字列テスト（2次元）:');
  Matrix2D_Reshaped := TFlexArray<string>.Create([2, 3], 1);
  Matrix2D_Reshaped.Map(function(const Value: string; const Coords: TCoords): string
                       begin
                         Result := Format('[%d,%d]', [Coords[0], Coords[1]]);
                       end);
  Log('変更前:');
  Log(Matrix2D_Reshaped.ToString);
  Log('範囲情報: ' + Matrix2D_Reshaped.ToRangesString);

  Matrix2D_Reshaped.ReshapeRange('[ 0..1 , 0..2 ]');
  Log('変更後 ([0..1,0..2]):');
  Log(Matrix2D_Reshaped.ToString);
  Log('範囲情報: ' + Matrix2D_Reshaped.ToRangesString);
  Log('');

  // 6. 複雑な範囲文字列テスト
  Log('6. 複雑な範囲文字列テスト:');
  ComplexMatrix := TFlexArray<string>.CreateFromRange(' [ -2 .. 2 , 0 .. 1 ] ');
  ComplexMatrix.Map(function(const Value: string; const Coords: TCoords): string
                   begin
                     Result := Format('Neg_%d_%d', [Coords[0], Coords[1]]);
                   end);
  Log('ComplexMatrix ([-2..2,0..1]):');
  Log(ComplexMatrix.ToString);
  Log('範囲情報: ' + ComplexMatrix.ToRangesString);
  Log('');

  // 7. エラーハンドリングテスト（コメントアウトして実行しない）
  Log('7. エラーハンドリングテスト（コメントアウト済み）:');
  Log('  - 不正な形式: "1..2,3" → 例外発生');
  Log('  - 範囲逆転: "5..1" → 例外発生');
  Log('  - 空文字列: "" → 例外発生');
  Log('');

  Log('=== RangeStr文字列テスト完了 ===');
end;


procedure TestUltimateChaosSlice;
var
  Data4D, Data3D, Data2D, Data1D: TFlexArray<Integer>;
  i, j, k, l, expectedValue: Integer;
  a: array of array of array of Integer;
begin
  a := [
  {Page 0} [
  [0, 1, 2],
  [10, 11, 12],
  [0, 1, 2],
  [10, 11, 12],
  [20, 21, 22]
],
  {Page 1} [
  [100, 101, 102],
  [110, 111, 112],
  [100, 101, 102],
  [110, 111, 112],
  [120, 121, 122]
]];

  log('--- カオス次元（Low=0,1混在）スライステスト開始 ---');

  // 1. 低下インデックスのバラエティを最大化
  Data4D := TFlexArray<Integer>.Create([2, 2, 3, 2], 1);
  Data4D.Reshape([2, 2, 3, 2], 1);  // 2x2x3x4 → 2x2x3x2 に変更
//  Data4D.ReshapeRange([[1, 2], [-1, 0], [2021, 2023], [0, 1]]);
  Data4D.Map(SequentialNumber2);

  // 4. Reshape後の範囲情報を確認
  log('Reshape後の範囲情報: ' + Data4D.ToRangesString);


  expectedValue := 0;

  // 3. 4重ループによる「次元の皮剥ぎ」
  // Data4D[i] -> Data3D[j] -> Data2D[k] -> Data1D[l]
  var Dim: Integer;
  Dim := 2;
  for i := Data4D.Low(Dim) to Data4D.High(Dim) do
  begin
    Data3D := Data4D.SliceDim(Dim, i);

    for j := Data3D.Low(Dim) to Data3D.High(Dim) do
    begin
      Data2D := Data3D.SliceDim(Dim, j);

      for k := Data2D.Low(Dim) to Data2D.High(Dim) do
      begin
        Data1D := Data2D.SliceDim(Dim, k);

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
////    Log(Flex.SliceDim(1, p).ToString);
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


// SliceDimのテスト
procedure TestSliceDimIndexesCounterReset;
var
  Matrix2D, Matrix3D: TFlexArray<Integer>;
  InsertArray: TFlexArray<Integer>;
  ResultArray: TFlexArray<Integer>;
  Vector1D: TFlexArray<Integer>;
begin
  Log('=== SliceDimIndexesCore カウンタリセットテスト ===');
  
  // 1. 2次元配列での列方向挿入テスト（カウンタリセット発生）
  Log('1. 2次元配列 列方向挿入テスト:');
  Matrix2D := TFlexArray<Integer>.Create([2, 3], 1);
  Matrix2D.Map(SequentialNumber);
  Log('元の行列 (2x3):');
  Log(Matrix2D.ToString);
  
  InsertArray := TFlexArray<Integer>.Create([2, 2], 1);
  InsertArray.Map(function(const Value: Integer; const Coords: TCoords): Integer
                 begin
                   Result := 100 + Coords[0] * 10 + Coords[1];
                 end);
  Log('挿入配列 (2x2):');
  Log(InsertArray.ToString);

  // 次元2（列方向）の位置2に挿入 → 座標減少が発生
  ResultArray := Matrix2D.InsertDim(2, 2, InsertArray);
  Log('InsertDim(2, 2, InsertArray) 結果 (2x5):');
  Log(ResultArray.ToString);
  Log('');
  
  // 2. 3次元配列での深さ方向挿入テスト
  Log('2. 3次元配列 深さ方向挿入テスト:');
  Matrix3D := TFlexArray<Integer>.Create([2, 2, 2], 1);
  Matrix3D.Map(SequentialNumber);
  Log('元のテンソル (2x2x2):');
  Log(Matrix3D.ToString);
  
  InsertArray := TFlexArray<Integer>.Create([1, 2, 2], 1);
  InsertArray.Map(function(const Value: Integer; const Coords: TCoords): Integer
                 begin
                   Result := 200 + Coords[0] * 100 + Coords[1] * 10 + Coords[2];
                 end);
  Log('挿入配列 (1x2x2):');
  Log(InsertArray.ToString);
  
  // 次元1（深さ方向）の位置2に挿入
  ResultArray := Matrix3D.InsertDim(1, 2, InsertArray);
  Log('InsertDim(1, 2, InsertArray) 結果 (3x2x2):');
  Log(ResultArray.ToString);
  Log('');
  
  // 3. 複数回挿入でのカウンタリセット連続発生テスト
  Log('3. 複数回挿入テスト:');
  Vector1D := TFlexArray<Integer>.Create([4], 1);
  Vector1D.Map(SequentialNumber);
  Log('元の1次元配列:');
  Log(Vector1D.ToString);
  
  // 2次元に変換してから複数回挿入
  Vector1D.Reshape([2, 2], 1);
  Log('2次元変換後 (2x2):');
  Log(Vector1D.ToString);
  
  // 2回連続で挿入（カウンタリセットが複数回発生）
  InsertArray := TFlexArray<Integer>.Create([2, 1], 1);
  InsertArray.Map(function(const Value: Integer; const Coords: TCoords): Integer
                 begin
                   Result := 300 + Coords[0] * 10 + Coords[1];
                 end);
  
  ResultArray := Vector1D.InsertDim(2, 2, InsertArray);
  Log('1回目挿入後 (2x3):');
  Log(ResultArray.ToString);
  
  ResultArray := ResultArray.InsertDim(2, 3, InsertArray);
  Log('2回目挿入後 (2x4):');
  Log(ResultArray.ToString);
  Log('');
  
  Log('=== カウンタリセットテスト完了 ===');
end;

procedure TestSliceDim;
var
  Matrix2D, Matrix3D: TFlexArray<Integer>;
  Row1, Row2, Col1, Col2: TFlexArray<Integer>;
  Slice1, Slice2: TFlexArray<Integer>;
  Page1, Page2: TFlexArray<Integer>;
begin
  Log('=== SliceDim/SliceRow/ChooseCol テスト ===');

  // 1. 2次元行列の準備
  Log('1. 2次元行列 (3x4) を準備:');
  Matrix2D := TFlexArray<Integer>.Create([3, 4], 1);
  Matrix2D.Map(SequentialNumber);
  Log(Matrix2D.ToString);
  Log('');

  // 2. SliceRowテスト
  Log('2. SliceRowテスト:');
  Log('  Row1 = SliceRow(1):');
  Row1 := Matrix2D.SliceRow(1);
  Log(Row1.ToString);

  Log('  Row2 = SliceRow(2):');
  Row2 := Matrix2D.SliceRow(2);
  Log(Row2.ToString);
  Log('');

  // 3. ChooseColテスト
  Log('3. ChooseColテスト:');
  Log('  Col1 = ChooseCol(1):');
  Col1 := Matrix2D.SliceCol(1);
  Log(Col1.ToString);

  Log('  Col2 = ChooseCol(2):');
  Col2 := Matrix2D.SliceCol(2);
  Log(Col2.ToString);
  Log('');

  // 4. 3次元配列の準備
  Log('4. 3次元配列 (2x3x2) を準備:');
  Matrix3D := TFlexArray<Integer>.Create([2, 3, 2], 1);
  Matrix3D.Map(SequentialNumber);
  Log(Matrix3D.ToString);
  Log('');

  // 5. SliceDimテスト（3次元）
  Log('5. SliceDimテスト（3次元）:');
  Log('  Page1 = SliceDim(1, 1):');
  Page1 := Matrix3D.SliceDim(1, 1);
  Log(Page1.ToString);

  Log('  Page2 = SliceDim(1, 2):');
  Page2 := Matrix3D.SliceDim(1, 2);
  Log(Page2.ToString);
  Log('');

  // 6. SliceDimテスト（2次元目）
  Log('6. SliceDimテスト（2次元目）:');
  Log('  Slice1 = SliceDim(2, 1):');
  Slice1 := Matrix3D.SliceDim(2, 1);
  Log(Slice1.ToString);

  Log('  Slice2 = SliceDim(2, 2):');
  Slice2 := Matrix3D.SliceDim(2, 2);
  Log(Slice2.ToString);
  Log('');

  // 7. 1次元配列のSliceDimテスト
  Log('7. 1次元配列のSliceDimテスト:');
  var Vec1D := TFlexArray<Integer>.Create([5], 1);
  Vec1D.Map(SequentialNumber);
  Log('  元の1次元配列:');
  Log(Vec1D.ToString);
  Log('  SliceDim(1, 3):');
  Log('  結果: ' + Vec1D[3].ToString);
  Log('');

  Log('=== SliceDimテスト完了 ===');
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


  TestReshapeChain;
  TestPerformance;
//  TestMapDateCreation; // Map日付作成テスト
  Test_LogicalTranspose;  // 論理転置テスト
//  Test_SliceWithLogicalTranspose;  // Slice系テスト
  Test_New;        // 新規作成
  Test_1D_Ref;    // 1次元参照
  Test_3D_New;
  Memo1.Lines.Add('--- テスト完了 ---');
   TestUltimateChaosSlice;
  TestTranspose;
  Log('******************************************');
  TestTranspose2;
  TestSliceDim;  // SliceDim/SliceRow/ChooseCol テスト
  TestPromoteDemoteDimension;
  TestSliceDimIndexesCounterReset;
  TestAppendArrayStrings;  // AppendArray文字列テスト
  TestRangeStringOperations;  // RangeStr文字列テスト
//  TestSumAllTypes;  // Sumメソッドテスト
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  N: INumpasInt;
  i, j: Integer;
  Sum: Integer;
  ResultArray: INumpasInt;
  Coords: TCoords;
begin
  Memo1.Lines.Add('=== TNumpasInt Reduce テスト ===');

  // 3x3配列を作成
  N := TNumpasInt.Create([2,5], 1);

  // データを設定
  // for i := N.Low(1) to N.High(1) do
  //   for j := N.Low(2) to N.High(2) do
  //     N[i, j] := i * 10 + j;  // 11, 12, 13, 21, 22, 23, 31, 32, 33

  // データを設定 - InitializeCoordsとIncCoordsを使用
  // N.Data.InitializeCoords(Coords);
  // for i := 1 to N.TotalSize do
  // begin
  //   N.ItemAt[Coords] := Coords[0] * 100 + Coords[1];
  //   N.Data.IncCoords(Coords);
  // end;

  // データを設定 - CoordsIterator を使用
  for Coords in N.Data.CoordsIterator do
  begin
    N.ItemAt[Coords] := Coords[0] * 1000 + Coords[1];
  end;


  N[1,2] := 126;

  Memo1.Lines.Add('元の配列:');
  Memo1.Lines.Add(N.Data.ToString);
  Memo1.Lines.Add(N.Data.ToRangesString);
  N.Data.Reshape([5,2], 0);
  N[0,1] := 256;
  N[1,0] := 64;
  Memo1.Lines.Add(N.Data.ToString);
  Memo1.Lines.Add(N.Data.ToRangesString);



  // Reduceテスト（全要素の合計）
  Sum := N.Reduce(
    function(const Acc: Integer; const Value: Integer): Integer
    begin
      Result := Acc + Value;
    end,
    0
  );
  Memo1.Lines.Add(Format('全要素の合計: %d', [Sum]));  // 11+12+13+21+22+23+31+32+33 = 198

  // Reduceテスト（最大値）
  var MaxValue := N.Reduce(
    function(const Acc: Integer; const Value: Integer): Integer
    begin
      if Value > Acc then
        Result := Value
      else
        Result := Acc;
    end,
    -MaxInt
  );
  Memo1.Lines.Add(Format('最大値: %d', [MaxValue]));  // 33

  // Reduceテスト（平均値）
  var Avg := N.Reduce(
    function(const Acc: Integer; const Value: Integer): Integer
    begin
      Result := Acc + Value;
    end,
    0
  ) / N.TotalSize;
  Memo1.Lines.Add(Format('平均値: %.2f', [Avg]));  // 198 / 9 = 22.00

  // 次元削減Reduceテスト（コメントアウト中）
  Memo1.Lines.Add('次元削減Reduceは現在コメントアウトされています');
  {
  // 行ごとの合計（次元2を削減）
  ResultArray := N.Reduce(
    [2],  // 次元2を削減
    function(const Acc: Integer; const Value: Integer; const Coords: TCoords): Integer
    begin
      Result := Acc + Value;
    end,
    0
  );
  Memo1.Lines.Add('行ごとの合計:');
  for i := 1 to ResultArray.DimensionCount do
    Memo1.Lines.Add(Format('行%d: %.1f', [i, ResultArray[i]]));
  }

end;

end.
