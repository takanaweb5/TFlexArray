unit Numpas;

interface

uses
  System.SysUtils, FlexArray;

type
  // 数値配列のエイリアス（TFlexプレフィックスで競合を回避）
  TFlexIntArray = TFlexArray<Integer>;
  TFlexDblArray = TFlexArray<Double>;

  // 数値演算用コールバック関数
  TReduceFunc = function(
    const Acc: Double;
    const Value: Double;
    const Coords: TCoords
  ): Double;

  TMapFunc = function(const Value: Double; const Coords: TCoords): Double;

  // 数値演算特化レコード（Integer版）
  TNumpasInt = record
  private
    FData: TFlexArray<Integer>;
  end;

  // 数値演算特化レコード（Double版）
  TNumpas = record
  private
    FData: TFlexDblArray;

    // GetValue/SetValue メソッド - TFlexArrayと完全統一
    function GetValue(const Coords: array of Integer): Double; overload;
    procedure SetValue(const Coords: array of Integer; const Value: Double); overload;
    function GetValue(const Coords: TCoords): Double; overload;
    procedure SetValue(const Coords: TCoords; const Value: Double); overload;

    // Elements プロパティ用のアクセサメソッド
    function GetElement(Index: Integer): Double;
    procedure SetElement(Index: Integer; const Value: Double);
    function GetDimensionCount: Integer;

    // Low/High/Len メソッド - TFlexArrayと完全統一
    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function Len(Dim: Integer): Integer;

    function BaseIndex: Integer;
    procedure ValidateBaseIndexConsistency;

    // 座標初期化用のヘルパー関数
    procedure InitializeCoords(var Coords: TCoords);

    // 論理転置用のカスタムIncCoords
    procedure LogicalIncCoords(var Coords: TCoords; const Order: TArray<Integer>);

  public
    // コンストラクタ
    constructor Create(const AData: TFlexDblArray); overload;
    constructor Create(const Shapes: array of Integer; BaseIndex: Integer); overload;

    // 演算子オーバーロードによる型変換
    class operator Implicit(const AData: TFlexDblArray): TNumpas;

    function Reduce(const Dims: array of Integer; Func: TReduceFunc; Init: Double): TNumpas; overload;

    function Reduce(const Func: TReduceFunc; Init: Double): Double; overload;

    property ItemAt[const Coords: TCoords]: Double read GetValue write SetValue;
    property Items[const Coords: array of Integer]: Double read GetValue write SetValue; default;
    property Elements[Index: Integer]: Double read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;
    
    // TFlexArrayへの直接アクセス
    property Data: TFlexDblArray read FData;
  end;

implementation

{ TNumpas }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] GetValueメソッド（array of Integer版）- TFlexArrayと完全統一
// [引数] Coords: 座標配列
// [戻値] 指定座標の値
// [使用例] Value := Numpas.GetValue([1, 2]);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.GetValue(const Coords: array of Integer): Double;
var
  CoordsArray: TCoords;
  i: Integer;
begin
  SetLength(CoordsArray, Length(Coords));
  for i := 0 to System.High(Coords) do
    CoordsArray[i] := Coords[i];
  Result := FData.ItemAt[CoordsArray];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] SetValueメソッド（array of Integer版）- TFlexArrayと完全統一
// [引数] Coords: 座標配列, Value: 設定する値
// [使用例] Numpas.SetValue([1, 2], 3.14);
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas.SetValue(const Coords: array of Integer; const Value: Double);
var
  CoordsArray: TCoords;
  i: Integer;
begin
  SetLength(CoordsArray, Length(Coords));
  for i := 0 to System.High(Coords) do
    CoordsArray[i] := Coords[i];

  FData.ItemAt[CoordsArray] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] GetValueメソッド（TCoords版）- TFlexArrayと完全統一
// [引数] Coords: TCoords型座標配列
// [戻値] 指定座標の値
// [使用例] Value := Numpas.GetValue([1, 2]);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.GetValue(const Coords: TCoords): Double;
begin
  Result := FData.ItemAt[Coords];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] SetValueメソッド（TCoords版）- TFlexArrayと完全統一
// [引数] Coords: TCoords型座標配列, Value: 設定する値
// [使用例] Numpas.SetValue([1, 2], 3.14);
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas.SetValue(const Coords: TCoords; const Value: Double);
begin
  FData.ItemAt[Coords] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Elementsプロパティのゲッター（ラッパー）
// [引数] Index: 線形インデックス
// [戻値] 指定インデックスの値
// [使用例] Value := Numpas.Elements[0];
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.GetElement(Index: Integer): Double;
begin
  Result := FData.Elements[Index];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Elementsプロパティのセッター（ラッパー）
// [引数] Index: 線形インデックス, Value: 設定する値
// [使用例] Numpas.Elements[0] := 1.0;
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas.SetElement(Index: Integer; const Value: Double);
begin
  FData.Elements[Index] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] DimensionCountプロパティのゲッター（ラッパー）
// [戻値] 次元数
// [使用例] DimCount := Numpas.DimensionCount;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.GetDimensionCount: Integer;
begin
  Result := FData.DimensionCount;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Lowメソッド（1D版）- TFlexArrayと完全統一
// [戻値] 1次元目のLow値
// [使用例] LowVal := Numpas.Low;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.Low: Integer;
begin
  Result := FData.Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Highメソッド（1D版）- TFlexArrayと完全統一
// [戻値] 1次元目のHigh値
// [使用例] HighVal := Numpas.High;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.High: Integer;
begin
  Result := FData.High;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Lowメソッド（nD版）- TFlexArrayと完全統一
// [引数] Dim: 次元番号
// [戻値] 指定次元のLow値
// [使用例] LowVal := Numpas.Low(2);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.Low(Dim: Integer): Integer;
begin
  Result := FData.Low(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Highメソッド（nD版）- TFlexArrayと完全統一
// [引数] Dim: 次元番号
// [戻値] 指定次元のHigh値
// [使用例] HighVal := Numpas.High(2);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.High(Dim: Integer): Integer;
begin
  Result := FData.High(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Lenメソッド - TFlexArrayと完全統一
// [引数] Dim: 次元番号
// [戻値] 指定次元の要素数
// [使用例] Length := Numpas.Len(2);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.Len(Dim: Integer): Integer;
begin
  Result := FData.Len(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] BaseIndex（1次元目のLow値）を取得する
// [戻値] BaseIndex値
// [使用例] Index := Numpas.BaseIndex
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.BaseIndex: Integer;
begin
  Result := FData.Low(1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 全次元のBaseIndexが統一されているか検証する
// [詳細] すべての次元のLow値が1次元目と一致するかチェック
// [例外] BaseIndexが不統一の場合に例外を発生
// [使用例] ValidateBaseIndexConsistency;  // コンストラクタ内で自動呼び出し
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas.ValidateBaseIndexConsistency;
var
  i: Integer;
begin
  // BaseIndex統一チェック
  for i := 2 to FData.DimensionCount do
  begin
    if FData.Low(i) <> FData.Low(1) then
      raise Exception.CreateFmt(
        'TNumpas: BaseIndexが不統一です。次元1=%d, 次元%d=%d',
        [FData.Low(1), i, FData.Low(i)]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 既存のTFlexDblArrayからTNumpasを作成する
// [引数] AData: 元となるDouble配列
// [戻値] TNumpasインスタンス
// [使用例] Numpas := TNumpas.Create(FlexArray)
// [備考] BaseIndexの整合性を自動検証
//////////////////////////////////////////////////////////////////////////////////////
constructor TNumpas.Create(const AData: TFlexDblArray);
begin
  FData := AData;
  ValidateBaseIndexConsistency;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 形状とBaseIndexから新しいTNumpasを作成する
// [引数] Shapes: 各次元のサイズ配列, BaseIndex: 基準インデックス
// [戻値] TNumpasインスタンス
// [使用例] Numpas := TNumpas.Create([3, 4], 1)  // 3x4配列、1ベース
// [備考] BaseIndexの整合性を自動検証
//////////////////////////////////////////////////////////////////////////////////////
constructor TNumpas.Create(const Shapes: array of Integer; BaseIndex: Integer);
begin
  FData := TFlexArray<Double>.Create(Shapes, BaseIndex);
  ValidateBaseIndexConsistency;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexDblArrayからTNumpasへの暗黙的型変換
// [引数] AData: 変換元のDouble配列
// [戻値] TNumpasインスタンス
// [使用例] Numpas := FlexArray;  // 暗黙的に変換
// [備考] 代入文などで自動的に呼び出される
//////////////////////////////////////////////////////////////////////////////////////
class operator TNumpas.Implicit(const AData: TFlexDblArray): TNumpas;
begin
  Result := TNumpas.Create(AData);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元を削減して配列を返す
// [引数] Dims: 削減する次元配列, Func: 畳み込み関数, Init: 初期値
// [戻値] 次元削減後のTNumpas配列
// [使用例] Result := Array.Reduce([2], SumFunc, 0.0)  // 次元2を削減
// [備考] 全次元削減にはReduce(Func, Init)を使用してください
// [アルゴリズム] 論理転置によるカウンターベース1重ループ
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.Reduce(const Dims: array of Integer; Func: TReduceFunc; Init: Double): TNumpas;
var
  ReduceDims, KeepDims, LogicalOrder: TArray<Integer>;
  NewRanges: TFlexRanges;
  ResultArray: TFlexDblArray;
  Coords, OldCoords, ResultCoords: TCoords;
  TempCoords: array of Integer;
  Acc: Double;
  i, d, DimIdx: Integer;
  InnerStepCount, InnerCounter: Integer;
  DimUsed: array of Integer;
  KeepCount, ReduceCount: Integer;
begin
  // 0. 削減次元のチェック
  if Length(Dims) = 0 then
    raise Exception.Create('Reduce: 削減次元が空です');
  
  if Length(Dims) = FData.DimensionCount then
    raise Exception.Create('Reduce: 全次元の削減にはReduce(Func, Init)を使用してください');
  
  SetLength(DimUsed, FData.DimensionCount);
  
  // 境界チェックとカウント
  for i := 0 to System.High(Dims) do
  begin
    if (Dims[i] < 1) or (Dims[i] > FData.DimensionCount) then
      raise Exception.CreateFmt('Reduce: 次元%dは範囲外です', [Dims[i]]);
    
    DimUsed[Dims[i] - 1] := DimUsed[Dims[i] - 1] + 1;
  end;
  
  // 2. 保持次元と削減次元の作成（カウントベース）
  // 事前に正確なサイズを確保
  SetLength(KeepDims, FData.DimensionCount - Length(Dims));
  SetLength(ReduceDims, Length(Dims));
  
  KeepCount := 0;
  ReduceCount := 0;
  
  for d := 1 to FData.DimensionCount do
  begin
    case DimUsed[d - 1] of
      0: begin
         // 0の次元 → 残す（KeepDims）
         KeepDims[KeepCount] := d;
         Inc(KeepCount);
       end;
      1: begin
         // 1の次元 → つぶす（ReduceDims）
         ReduceDims[ReduceCount] := d;
         Inc(ReduceCount);
       end;
      else
        // 2以上はエラー（重複）
        raise Exception.Create('Reduce: 削減次元に重複があります');
    end;
  end;
  
  // 3. 論理転置配列の作成 [保持次元] + [削減次元]
  LogicalOrder := KeepDims + ReduceDims;
  
  // 4. インナー歩数の計算（削減次元の全要素数）
  InnerStepCount := 1;
  for i := 0 to System.High(ReduceDims) do
  begin
    DimIdx := ReduceDims[i] - 1;
    InnerStepCount := InnerStepCount * FData.Len(DimIdx);
  end;
  
  // 4. 結果配列の準備
  SetLength(NewRanges, Length(KeepDims));
  for i := 0 to System.High(KeepDims) do
  begin
    DimIdx := KeepDims[i] - 1;
    NewRanges[i] := [FData.Low(DimIdx), FData.High(DimIdx)];
  end;
  
  ResultArray := TFlexDblArray.CreateFromRange(NewRanges);
  
  // 5. 革新的カウンターベース1重ループ処理
  InitializeCoords(Coords);
  Acc := Init;
  InnerCounter := 0;
  
  for i := 0 to FData.TotalSize - 1 do
  begin
    // 積み上げ処理
    Acc := Func(Acc, FData.Elements[i], Coords);
    
    // インナーカウンタをインクリメント
    Inc(InnerCounter);
    
    // インナー歩数に達したら結果を書き込み
    if InnerCounter >= InnerStepCount then
    begin
      // 配列結果（座標から線形インデックスを計算）
      SetLength(ResultCoords, Length(KeepDims));
      for d := 0 to System.High(KeepDims) do
        ResultCoords[d] := Coords[KeepDims[d] - 1];

      ResultArray.ItemAt[ResultCoords] := Acc;

      Acc := Init;        // 積み上げ値をクリア
      InnerCounter := 0;  // インナーカウンタもクリア
    end;
    
    // 次の座標へ
    LogicalIncCoords(Coords, LogicalOrder);
  end;
  
  // 6. TNumpasでラップして返す
  Result := TNumpas.Create(ResultArray);
end;

{ TNumpas privateメソッド }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標配列を初期化する（各次元のLow値で）
// [引数] Coords: 初期化する座標配列（参照渡し）
// [使用例] InitializeCoords(Coords);  // ループ開始前に呼び出し
// [備考] Reduce関数内で使用されるヘルパー関数
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas.InitializeCoords(var Coords: TCoords);
var
  d: Integer;
begin
  SetLength(Coords, FData.DimensionCount);
  for d := 0 to FData.DimensionCount - 1 do
    Coords[d] := FData.Low(d + 1);  // 1-based次元
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 論理転置順序で座標をインクリメントする
// [引数] Coords: インクリメントする座標配列（参照渡し）, Order: 次元の順序配列
// [使用例] LogicalIncCoords(Coords, [1, 3, 2])  // 次元1→3→2の順で繰り上げ
// [アルゴリズム] 指定された次元順序で繰り上げ処理を実行
// [備考] Reduce関数の革命的アルゴリズムの核心部分
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas.LogicalIncCoords(var Coords: TCoords; const Order: TArray<Integer>);
var
  i, DimIdx: Integer;
begin
  // 論理転置順序で繰り上げ処理
  for i := System.High(Order) downto 0 do
  begin
    DimIdx := Order[i] - 1;  // 1-based→0-based
    Inc(Coords[DimIdx]);
    
    // 上限を超えていないなら終了
    if Coords[DimIdx] <= FData.High(DimIdx) then Exit;

    // 上限を超えたのでリセット
    Coords[DimIdx] := FData.Low(DimIdx);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 全要素を畳み込んでスカラー値を返す
// [引数] Func: 畳み込み関数, Init: 初期値
// [戻値] 全要素を畳み込んだ結果のDouble値
// [使用例] Total := Array.Reduce(SumFunc, 0.0)  // 全要素の合計
// [アルゴリズム] Map+SequentialNumberによる自然順序生成
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas.Reduce(const Func: TReduceFunc; Init: Double): Double;
var
  Coords: TCoords;
  Acc: Double;
  i: Integer;
  NaturalOrder: TFlexArray<Integer>;
begin
  InitializeCoords(Coords);
  Acc := Init;

  // 自然な順序 [1, 2, 3, ...] をMapで生成
  NaturalOrder := TFlexArray<Integer>.Create([FData.DimensionCount], 1);
  NaturalOrder.Map(SequentialNumber);
  for i := 0 to FData.TotalSize - 1 do
  begin
    Acc := Func(Acc, FData.Elements[i], Coords);
    LogicalIncCoords(Coords, NaturalOrder.ToVector);
  end;

  Result := Acc;
end;

end.
