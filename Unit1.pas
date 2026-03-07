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

procedure TestSumAllTypes;
var
  IntArray: TFlexArray<Integer>;
  DblArray: TFlexArray<Double>;
  StrArray: TFlexArray<string>;
  SumResult: Integer;
  DblSum: Double;
  StrSum: string;
begin
  Log('=== Sumメソッドテスト ===');
  Log('');
  
  // Integer型テスト
  Log('--- Integer型テスト ---');
  Log('テスト1: 基本的な整数配列');
  IntArray := TFlexArray<Integer>.CreateFromArray([1, 2, 3, 4, 5]);
  SumResult := IntArray.Sum;
  Log('  配列: [1, 2, 3, 4, 5]');
  Log('  期待値: 15, 実際値: ' + IntToStr(SumResult));
  Log('');

  Log('テスト2: 負数を含む配列');
  IntArray := TFlexArray<Integer>.CreateFromArray([-1, 5, -3, 2], 1);
  SumResult := IntArray.Sum;
  Log('  配列: [-1, 5, -3, 2]');
  Log('  期待値: 3, 実際値: ' + IntToStr(SumResult));
  Log('');
  
  Log('テスト3: ゼロを含む配列');
  IntArray := TFlexArray<Integer>.CreateFromArray([0, 10, 0, 5], 0);
  SumResult := IntArray.Sum;
  Log('  配列: [0, 10, 0, 5]');
  Log('  期待値: 15, 実際値: ' + IntToStr(SumResult));
  Log('');
  
  // Double型テスト
  Log('--- Double型テスト ---');
  Log('テスト1: 基本的な小数配列');
  DblArray := TFlexArray<Double>.CreateFromArray([1.5, 2.3, 3.7, 4.1], 0);
  DblSum := DblArray.Sum;
  Log('  配列: [1.5, 2.3, 3.7, 4.1]');
  Log('  期待値: 11.60, 実際値: ' + FormatFloat('0.00', DblSum));
  Log('');

  Log('テスト2: 負の小数を含む配列');
  DblArray := TFlexArray<Double>.CreateFromArray([-1.2, 3.5, -2.8, 1.0]);
  DblSum := DblArray.Sum;
  Log('  配列: [-1.2, 3.5, -2.8, 1.0]');
  Log('  期待値: 0.50, 実際値: ' + FormatFloat('0.00', DblSum));
  Log('');

  Log('テスト3: 非常に小さい値');
  DblArray := TFlexArray<Double>.CreateFromArray([0.001, 0.002, 0.003]);
  DblSum := DblArray.Sum;
  Log('  配列: [0.001, 0.002, 0.003]');
  Log('  期待値: 0.006000, 実際値: ' + FormatFloat('0.000000', DblSum));
  Log('');
  
//  // String型テスト
//  Log('--- String型テスト ---');
//  Log('テスト1: 基本的な文字列配列');
//  StrArray := TFlexArray<string>.CreateFromArray(['Hello', ' ', 'World', '!']);
//  StrSum := StrArray.Sum;
//  Log('  配列: ["Hello", " ", "World", "!"]');
//  Log('  期待値: "Hello World!", 実際値: "' + StrSum + '"');
//  Log('');

//  Log('テスト2: 数字の文字列');
//  StrArray := TFlexArray<string>.CreateFromArray(['1', '2', '3']);
//  StrSum := StrArray.Sum;
//  Log('  配列: ["1", "2", "3"]');
//  Log('  期待値: "123", 実際値: "' + StrSum + '"');
//  Log('');
//
//  Log('テスト3: 空文字列を含む配列');
//  StrArray := TFlexArray<string>.CreateFromArray(['A', '', 'B', '', 'C']);
//  StrSum := StrArray.Sum;
//  Log('  配列: ["A", "", "B", "", "C"]');
//  Log('  期待値: "ABC", 実際値: "' + StrSum + '"');
//  Log('');

  // 多次元配列テスト
  Log('--- 多次元配列テスト ---');
  Log('テスト1: 2次元Integer配列');
  IntArray := TFlexArray<Integer>.CreateFromRange([[-1, 3], [1, 2]]);
  IntArray.Map(SequentialNumber);
  SumResult := IntArray.max;
  Log(IntArray.ToString);
  Log('  期待値: 10, 実際値: ' + IntToStr(SumResult));
  Log('');
  
  Log('=== Sumメソッドテスト完了 ===');
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
  Matrix2D := TFlexArray<Integer>.Create([3, 4], 1);
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
  var Vec1D := TFlexArray<Integer>.Create([5], 1);
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
//   TestUltimateChaosSlice;
//  TestTranspose;
//  TestChooseSlice;  // ChooseSlice/ChooseRow/ChooseCol テスト
//  TestConcat;
//  TestAppendArrayStrings;  // AppendArray文字列テスト
//  TestRangeStringOperations;  // RangeStr文字列テスト
  TestSumAllTypes;  // Sumメソッドテスト
end;

end.
