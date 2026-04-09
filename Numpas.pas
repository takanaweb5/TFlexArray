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

    // TFlexArrayへの直接アクセス
    property Data: TFlexDblArray read FData;
  end;

implementation

{ TNumpas }

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
  for i := 0 to High(Dims) do
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
  for i := 0 to High(ReduceDims) do
  begin
    DimIdx := ReduceDims[i] - 1;
    InnerStepCount := InnerStepCount * FData.Len(DimIdx);
  end;
  
  // 4. 結果配列の準備
  SetLength(NewRanges, Length(KeepDims));
  for i := 0 to High(KeepDims) do
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
      for d := 0 to High(KeepDims) do
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
  for i := High(Order) downto 0 do
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
