unit Numpas;

interface

uses
  System.SysUtils, FlexArray;

type
//  // 数値配列のエイリアス（TFlexプレフィックスで競合を回避）
//  TFlexIntArray = TFlexArray<Integer>;
//  TFlexDblArray = TFlexArray<Double>;

    TReduceFunc<T> = reference to function(const Acc, Element: T): T;

  // TNumpas インターフェース
  INumpas<T> = interface

    function Reduce(const Func: TReduceFunc<T>; Init: T): T;
    function GetValue(const Coords: array of Integer): T; overload;
    procedure SetValue(const Coords: array of Integer; const Value: T); overload;
    function GetValue(const Coords: TCoords): T; overload;
    procedure SetValue(const Coords: TCoords; const Value: T); overload;
    function GetElement(Index: Integer): T;
    procedure SetElement(Index: Integer; const Value: T);
    function GetDimensionCount: Integer;
    function GetTotalSize: Integer;
    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function Len(Dim: Integer): Integer;
    function BaseIndex: Integer;

    property ItemAt[const Coords: TCoords]: T read GetValue write SetValue;
    property Items[const Coords: array of Integer]: T read GetValue write SetValue; default;
    property Elements[Index: Integer]: T read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;
    property TotalSize: Integer read GetTotalSize;
  end;

  TNumpas<T> = class(TInterfacedObject, INumpas<T>)
  private
    FData: TFlexArray<T>;

    // GetValue/SetValue メソッド - TFlexArrayと完全統一
    function GetValue(const Coords: array of Integer): T; overload;
    procedure SetValue(const Coords: array of Integer; const Value: T); overload;
    function GetValue(const Coords: TCoords): T; overload;
    procedure SetValue(const Coords: TCoords; const Value: T); overload;

    // Elements プロパティ用のアクセサメソッド
    function GetElement(Index: Integer): T;
    procedure SetElement(Index: Integer; const Value: T);
    function GetDimensionCount: Integer;
    function GetTotalSize: Integer;

    // Low/High/Len メソッド - TFlexArrayと完全統一
    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function Len(Dim: Integer): Integer;

    function BaseIndex: Integer;
    procedure ValidateBaseIndexConsistency;

  public
    // コンストラクタ
    constructor Create(const AData: TFlexArray<T>); overload;
    constructor Create(const Shapes: array of Integer; BaseIndex: Integer); overload;
    destructor Destroy; override;

    // // 演算子オーバーロードによる型変換
    // class operator Implicit(const AData: TFlexDblArray): TNumpas;

    function Reduce(const Func: TReduceFunc<T>; Init: T): T; overload;
//    function Reduce(const Dims: array of Integer; Func: TReduceFunc; Init: T): TNumpas<T>; overload;

    property ItemAt[const Coords: TCoords]: T read GetValue write SetValue;
    property Items[const Coords: array of Integer]: T read GetValue write SetValue; default;
    property Elements[Index: Integer]: T read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;
    property TotalSize: Integer read GetTotalSize;

    // TFlexArrayへの直接アクセス
    property Data: TFlexArray<T> read FData;
  end;

  // 数値演算特化クラス（Double）
  INumpasDbl = interface(INumpas<Double>)
  end;
  TNumpasDbl = class(TNumpas<Double>, INumpasDbl)
  end;



implementation

{ TNumpas }

////////////////////////////////////////////////////////////////////////////////////////
//// [概要] array of Integer を TCoords に変換するヘルパー関数
//// [引数] Coords: Integer配列
//// [戻値] TCoords型の座標配列
//// [使用例] Coords := ArrayToCoords([1, 2, 3]);
////////////////////////////////////////////////////////////////////////////////////////
//function TNumpas<T>.ArrayToCoords(const Coords: array of Integer): TCoords;
//var
//  i: Integer;
//begin
//  SetLength(Result, Length(Coords));
//  for i := 0 to System.High(Coords) do
//    Result[i] := Coords[i];
//end;


//////////////////////////////////////////////////////////////////////////////////////
// [概要] GetValueメソッド（array of Integer版）- TFlexArrayと完全統一
// [引数] Coords: 座標配列
// [戻値] 指定座標の値
// [使用例] Value := Numpas.GetValue([1, 2]);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.GetValue(const Coords: array of Integer): T;
begin
  Result := FData.ItemAt[TCoords.FromArray(Coords)];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] SetValueメソッド（array of Integer版）- TFlexArrayと完全統一
// [引数] Coords: 座標配列, Value: 設定する値
// [使用例] Numpas.SetValue([1, 2], 3.14);
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas<T>.SetValue(const Coords: array of Integer; const Value: T);
begin
  FData.ItemAt[TCoords.FromArray(Coords)] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] GetValueメソッド（TCoords版）- TFlexArrayと完全統一
// [引数] Coords: TCoords型座標配列
// [戻値] 指定座標の値
// [使用例] Value := Numpas.GetValue([1, 2]);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.GetValue(const Coords: TCoords): T;
begin
  Result := FData.ItemAt[Coords];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] SetValueメソッド（TCoords版）- TFlexArrayと完全統一
// [引数] Coords: TCoords型座標配列, Value: 設定する値
// [使用例] Numpas.SetValue([1, 2], 3.14);
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas<T>.SetValue(const Coords: TCoords; const Value: T);
begin
  FData.ItemAt[Coords] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Elementsプロパティのゲッター（ラッパー）
// [引数] Index: 線形インデックス
// [戻値] 指定インデックスの値
// [使用例] Value := Numpas.Elements[0];
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.GetElement(Index: Integer): T;
begin
  Result := FData.Elements[Index];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Elementsプロパティのセッター（ラッパー）
// [引数] Index: 線形インデックス, Value: 設定する値
// [使用例] Numpas.Elements[0] := 1.0;
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas<T>.SetElement(Index: Integer; const Value: T);
begin
  FData.Elements[Index] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] DimensionCountプロパティのゲッター（ラッパー）
// [戻値] 次元数
// [使用例] DimCount := Numpas.DimensionCount;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.GetDimensionCount: Integer;
begin
  Result := Self.FData.DimensionCount;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TotalSizeプロパティのゲッター（ラッパー）
// [戻値] 全要素数
// [使用例] Size := Numpas.TotalSize;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.GetTotalSize: Integer;
begin
  Result := Self.FData.TotalSize;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Lowメソッド（1D版）- TFlexArrayと完全統一
// [戻値] 1次元目のLow値
// [使用例] LowVal := Numpas.Low;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.Low: Integer;
begin
  Result := FData.Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Highメソッド（1D版）- TFlexArrayと完全統一
// [戻値] 1次元目のHigh値
// [使用例] HighVal := Numpas.High;
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.High: Integer;
begin
  Result := FData.High;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Lowメソッド（nD版）- TFlexArrayと完全統一
// [引数] Dim: 次元番号
// [戻値] 指定次元のLow値
// [使用例] LowVal := Numpas.Low(2);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.Low(Dim: Integer): Integer;
begin
  Result := FData.Low(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Highメソッド（nD版）- TFlexArrayと完全統一
// [引数] Dim: 次元番号
// [戻値] 指定次元のHigh値
// [使用例] HighVal := Numpas.High(2);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.High(Dim: Integer): Integer;
begin
  Result := FData.High(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Lenメソッド - TFlexArrayと完全統一
// [引数] Dim: 次元番号
// [戻値] 指定次元の要素数
// [使用例] Length := Numpas.Len(2);
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.Len(Dim: Integer): Integer;
begin
  Result := FData.Len(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] BaseIndex（1次元目のLow値）を取得する
// [戻値] BaseIndex値
// [使用例] Index := Numpas.BaseIndex
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.BaseIndex: Integer;
begin
  Result := FData.Low(1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 全次元のBaseIndexが統一されているか検証する
// [詳細] すべての次元のLow値が1次元目と一致するかチェック
// [例外] BaseIndexが不統一の場合に例外を発生
// [使用例] ValidateBaseIndexConsistency;  // コンストラクタ内で自動呼び出し
//////////////////////////////////////////////////////////////////////////////////////
procedure TNumpas<T>.ValidateBaseIndexConsistency;
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
// [引数] AData: 元となるT配列
// [戻値] TNumpasインスタンス
// [使用例] Numpas := TNumpas<T>.Create(FlexArray)
// [備考] BaseIndexの整合性を自動検証
//////////////////////////////////////////////////////////////////////////////////////
constructor TNumpas<T>.Create(const AData: TFlexArray<T>);
begin
  FData := AData;
  ValidateBaseIndexConsistency;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 形状とBaseIndexから新しいTNumpasを作成する
// [引数] Shapes: 各次元のサイズ配列, BaseIndex: 基準インデックス
// [戻値] TNumpasインスタンス
// [使用例] Numpas := TNumpas<T>.Create([3, 4], 1)  // 3x4配列、1ベース
// [備考] BaseIndexの整合性を自動検証
//////////////////////////////////////////////////////////////////////////////////////
constructor TNumpas<T>.Create(const Shapes: array of Integer; BaseIndex: Integer);
begin
  FData := TFlexArray<T>.Create(Shapes, BaseIndex);
  ValidateBaseIndexConsistency;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] デストラクタ
// [使用例] N.Free; またはインターフェース参照カウントで自動解放
//////////////////////////////////////////////////////////////////////////////////////
destructor TNumpas<T>.Destroy;
begin
  inherited;
end;

{ TNumpas privateメソッド }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 全要素を畳み込んでスカラー値を返す
// [引数] Func: 畳み込み関数, Init: 初期値
// [戻値] 全要素を畳み込んだ結果のDouble値
// [使用例] Total := Array.Reduce(SumFunc, 0.0)  // 全要素の合計
// [アルゴリズム] Map+SequentialNumberによる自然順序生成
//////////////////////////////////////////////////////////////////////////////////////
function TNumpas<T>.Reduce(const Func: TReduceFunc<T>; Init: T): T;
var
  Coords: TCoords;
  Acc: T;
  i: Integer;
begin
  Self.FData.InitializeCoords(Coords);
  Acc := Init;

  for i := 0 to Self.TotalSize - 1 do
  begin
    Acc := Func(Acc, Self.Elements[i]);
    Self.FData.IncCoords(Coords);
  end;

  Result := Acc;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元を削減して配列を返す
// [引数] Dims: 削減する次元配列, Func: 畳み込み関数, Init: 初期値
// [戻値] 次元削減後のTNumpas配列
// [使用例] Result := Array.Reduce([2], SumFunc, 0.0)  // 次元2を削減
// [備考] 全次元削減にはReduce(Func, Init)を使用してください
// [アルゴリズム] 論理転置によるカウンターベース1重ループ
//////////////////////////////////////////////////////////////////////////////////////
//function TNumpas<T>.Reduce(const Dims: array of Integer; Func: TReduceFunc;
//  Init: T): TNumpas<T>;
//var
//  ReduceDims, KeepDims, LogicalOrder: TArray<Integer>;
//  NewRanges: TFlexRanges;
//  ResultArray: TFlexArray<T>;
//  Coords, OldCoords, ResultCoords: TCoords;
//  Acc: T;
//  i, d, DimIdx: Integer;
//  InnerStepCount, InnerCounter: Integer;
//  DimUsed: array of Integer;
//  KeepCount, ReduceCount: Integer;
//begin
//  // 0. 削減次元のチェック
//  if Length(Dims) = 0 then
//    raise Exception.Create('Reduce: 削減次元が空です');
//
//  if Length(Dims) = Self.DimensionCount then
//    raise Exception.Create('Reduce: 全次元の削減にはReduce(Func, Init)を使用してください');
//
//  SetLength(DimUsed, Self.DimensionCount);
//
//  // 境界チェックとカウント
//  for i := 0 to System.High(Dims) do
//  begin
//    if (Dims[i] < 1) or (Dims[i] > Self.DimensionCount) then
//      raise Exception.CreateFmt('Reduce: 次元%dは範囲外です', [Dims[i]]);
//
//    DimUsed[Dims[i] - 1] := DimUsed[Dims[i] - 1] + 1;
//  end;
//
//  // 2. 保持次元と削減次元の作成（カウントベース）
//  SetLength(KeepDims, Self.DimensionCount - Length(Dims));
//  SetLength(ReduceDims, Length(Dims));
//
//  KeepCount := 0;
//  ReduceCount := 0;
//
//  for d := 1 to Self.DimensionCount do
//  begin
//    case DimUsed[d - 1] of
//      0: begin
//         KeepDims[KeepCount] := d;
//         Inc(KeepCount);
//       end;
//      1: begin
//         ReduceDims[ReduceCount] := d;
//         Inc(ReduceCount);
//       end;
//      else
//        raise Exception.Create('Reduce: 削減次元に重複があります');
//    end;
//  end;
//
//  // 3. 論理転置配列の作成 [保持次元] + [削減次元]
//  LogicalOrder := KeepDims + ReduceDims;
//
//  // 4. インナー歩数の計算（削減次元の全要素数）
//  InnerStepCount := 1;
//  for i := 0 to System.High(ReduceDims) do
//  begin
//    DimIdx := ReduceDims[i] - 1;
//    InnerStepCount := InnerStepCount * Self.Len(DimIdx);
//  end;
//
//  // 5. 結果配列の準備
//  SetLength(NewRanges, Length(KeepDims));
//  for i := 0 to System.High(KeepDims) do
//  begin
//    DimIdx := KeepDims[i] - 1;
//    NewRanges[i] := [Self.Low(DimIdx), Self.High(DimIdx)];
//  end;
//
//  ResultArray := TFlexArray<T>.CreateFromRange(NewRanges);
//
//  // 6. カウンターベース1重ループ処理
//  InitializeCoords(Coords);
//  Acc := Init;
//  InnerCounter := 0;
//
//  for i := 0 to Self.TotalSize - 1 do
//  begin
//    // 積み上げ処理
//    Acc := Func(Acc, Self.Elements[i], Coords);
//
//    // インナーカウンタをインクリメント
//    Inc(InnerCounter);
//
//    // インナー歩数に達したら結果を書き込み
//    if InnerCounter >= InnerStepCount then
//    begin
//      // 配列結果（座標から線形インデックスを計算）
//      SetLength(ResultCoords, Length(KeepDims));
//      for d := 0 to System.High(KeepDims) do
//        ResultCoords[d] := Coords[KeepDims[d] - 1];
//
//      ResultArray.ItemAt[ResultCoords] := Acc;
//
//      Acc := Init;        // 積み上げ値をクリア
//      InnerCounter := 0;  // インナーカウンタもクリア
//    end;
//
//    // 次の座標へ
//    LogicalIncCoords(Coords, LogicalOrder);
//  end;
//
//  // 7. TNumpasでラップして返す
//  Result := TNumpas<T>.Create(ResultArray);
//end;


end.


{ TNumpasDbl }
end;
