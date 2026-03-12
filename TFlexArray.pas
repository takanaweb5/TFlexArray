unit TFlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math,
  System.Rtti,    // TValue のため
  System.TypInfo, // tkString などの型判定（TValue.Kind）のため
  System.Generics.Defaults; // IComparer のため

type
  TFlexRange = TArray<Integer>;  // [Low, High] のペア
  TFlexRangeHelper = record helper for TFlexRange
    function Low:  Integer; inline;
    function High: Integer; inline;
    function Len:  Integer; inline;
  end;
  TFlexRanges = TArray<TFlexRange>;  // [[Low1, High1], [Low2, High2], ...]

  TCoords = array of Integer;  // 座標配列 [x, y, z, ...]

  TFlexDimension = record
    Low, High, Stride: NativeInt;
    function Len: NativeInt; inline;
  end;
  TFlexDimensions = TArray<TFlexDimension>;
  TFlexDimensionsHelper = record helper for TFlexDimensions
  private
    function GetDimension(Index: Integer): TFlexDimension; inline;
    procedure SetDimension(Index: Integer; const Value: TFlexDimension); inline;
  public
    property Items[Index: Integer]: TFlexDimension read GetDimension write SetDimension;
  end;

  // for in 用列挙子
  TFlexArrayEnumerator<T> = class
  private
    FData: TArray<T>;
    FTotalSize: NativeInt;
    FIndex: NativeInt;
    function GetCurrent: T;
  public
    constructor Create(const AData: TArray<T>; Size: NativeInt);
    property Current: T read GetCurrent;
    function MoveNext: Boolean;
  end;

  // 非破壊的Map用コールバック
  TMappedFunc<T, TResult> = reference to function(const Value: T; const Coords: TCoords): TResult;
  TMappedFuncValue<T, TResult> = reference to function(const Value: T): TResult;
  // 破壊的Map用コールバック
  TMapFunc<T> = reference to function(const Value: T; const Coords: TCoords): T;
  TMapFuncValue<T> = reference to function(const Value: T): T;
  // Filter用コールバック
  TFilterFunc<T> = reference to function(const Value: T; const Coords: TCoords): Boolean;
  TFilterFuncValue<T> = reference to function(const Value: T): Boolean;
  // Reduce用コールバック（InitialValueあり）
  TReduceFunc<T, TResult> = reference to function(const Current: TResult; const Value: T; const Coords: TCoords): TResult;
  TReduceFuncValue<T, TResult> = reference to function(const Current: TResult; const Value: T): TResult;
  // Reduce用コールバック（InitialValueなし、TResult=Tに固定）
  TReduceFuncSimple<T> = reference to function(const Current: T; const Value: T): T;

  // Map用コールバック関数サンプル(連番作成)
  function SequentialNumber(const Value: Integer; const Coords: TCoords): Integer;

type
  TFlexArray<T> = record
  private
    FData: TArray<T>;
    FDims: TFlexDimensions;  // 次元情報
    FTotalSize: NativeInt;
    FIsView: Boolean;

    function GetCoords(LinearIndex: NativeInt): TCoords;
    function GetOffset(const Coords: array of Integer): NativeInt;
    function GetValue(const Coords: array of Integer): T;
    procedure SetValue(const Coords: array of Integer; const Value: T);
    function GetElement(Index: NativeInt): T; inline;
    procedure SetElement(Index: NativeInt; const Value: T); inline;
    function GetDimensionCount: Integer; inline;
    function GetRanges: TFlexRanges;
    function ValueToStr(const V: T): string;
    procedure InitializeDimensions(const Ranges: TFlexRanges);
    procedure CheckDimension(ExpectedDim: Integer);
    procedure CheckViewMode;
    procedure InitializeCoords(var Coords: TCoords);
    procedure IncCoords(var Coords: TCoords);
    function ConcatEqualDim(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
    function GetCompatibleBaseIndex(const Another: TFlexArray<T>): Integer;
    procedure PromoteDimension(TargetDim: Integer);
    procedure DemoteDimension(TargetDim: Integer);
    function RangesStringToRanges(const RangeStr: string): TFlexRanges;
    function SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>; overload;
    function SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>; const Another: TFlexArray<T>; Index: Integer): TFlexArray<T>; overload;
    function SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>; overload;
    function SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>; BaseIndex: Integer): TFlexArray<T>; overload;
    function GetEnumerator: TFlexArrayEnumerator<T>;

  public
    constructor Create(const Shapes: array of Integer; BaseIndex: Integer); overload; // nD
    constructor CreateFromRange(const Range: TFlexRange); overload; // 1D
    constructor CreateFromRange(const Ranges: TFlexRanges); overload; // nD
    constructor CreateFromRange(const RangeStr: string); overload;
    constructor CreateFromFlexArray(const Src: TFlexArray<T>); overload;
    constructor CreateFromArray(const Src: TArray<T>; BaseIndex: Integer = 0); overload;
    constructor ViewFromArray(const Src: TArray<T>; BaseIndex: Integer = 0); overload;

    function Low: Integer; overload;  // 1D
    function High: Integer; overload; // 1D
    function Low(Dim: Integer): Integer; overload; // nD
    function High(Dim: Integer): Integer; overload; // nD
    function Len(Dim: Integer): NativeInt;

    property Items[const Coords: array of Integer]: T read GetValue write SetValue; default;
    property Elements[Index: NativeInt]: T read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;
    property TotalSize: NativeInt read FTotalSize;

    procedure NormalizeToBaseIndex(BaseIndex: Integer);
    procedure Reshape(const Shapes: array of Integer; BaseIndex: Integer);
    procedure ReshapeVector(BaseIndex: Integer); // 1D
    procedure ReshapeRange(const Range: TFlexRange); overload; // 1D
    procedure ReshapeRange(const Ranges: TFlexRanges); overload; // nD
    procedure ReshapeRange(const RangeStr: string); overload;

    function ToVector(): TArray<T>;
    function ToString(): string;
    function ToRangesString(): string;

    function SliceDim(Dim: Integer; Index: Integer): TFlexArray<T>; overload;  // nD
    function SliceDimRange(Dim: Integer; const Range: TFlexRange): TFlexArray<T>; overload;  // nD
    function SliceRow(RowIndex: Integer): TFlexArray<T>;  // 2D
    function SliceCol(ColIndex: Integer): TFlexArray<T>;  // 2D

    function Transpose(const NewDims: array of Integer): TFlexArray<T>; overload; // nD
    function Transpose(): TFlexArray<T>; overload; // 2D

    function Concat(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;  // nD
    function HStack(const Another: TFlexArray<T>): TFlexArray<T>;  // 2D
    function VStack(const Another: TFlexArray<T>): TFlexArray<T>;  // 2D
    function AppendArray(const Another: TFlexArray<T>): TFlexArray<T>; overload;  // 1D
    function AppendArray(const Another: TArray<T>): TFlexArray<T>; overload;  // 1D
    function AppendArray(const Value: T): TFlexArray<T>; overload;  // 1D

    // 1D配列操作メソッド
//    function InsertArray(const StartIndex: Integer; const Items: TArray<T>): TFlexArray<T>; overload;
//    function InsertArray(const StartIndex: Integer; const Items: TFlexArray<T>): TFlexArray<T>; overload;
//    function InsertArray(const StartIndex: Integer; const Item: T): TFlexArray<T>; overload;
//
//    function DeleteArray(const Range: TFlexRange): TFlexArray<T>;
//    function SliceArray(const Range: TFlexRange): TFlexArray<T>;

    // 多次元配列操作メソッド
    function InsertDim(Dim: Integer; Index: Integer; const Items: TFlexArray<T>): TFlexArray<T>;
    function DeleteDim(Dim: Integer; const Range: TFlexRange): TFlexArray<T>;

    // Swiftスタイル: 非破壊的(-ed) / 破壊的(原形)
    procedure Map(const AFunc: TMapFunc<T>); overload;
    procedure Map(const AFunc: TMapFuncValue<T>); overload;
    function Mapped<TResult>(const AFunc: TMappedFunc<T, TResult>): TFlexArray<TResult>; overload;
    function Mapped<TResult>(const AFunc: TMappedFuncValue<T, TResult>): TFlexArray<TResult>; overload;

    function Filter(const AFunc: TFilterFunc<T>): TArray<T>; overload;
    function Filter(const AFunc: TFilterFuncValue<T>): TArray<T>; overload;

    function Reduce<TResult>(const InitialValue: TResult; const AFunc: TReduceFunc<T, TResult>): TResult; overload;
    function Reduce<TResult>(const InitialValue: TResult; const AFunc: TReduceFuncValue<T, TResult>): TResult; overload;
    function Reduce(const AFunc: TReduceFuncSimple<T>): T; overload;

    // 集約関数
    function Sum: T;
    function Max: T;
    function Min: T;
  end;

implementation

{ TFlexRangeHelper }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangeの下限値を取得
// [引数] なし
// [戻値] 下限値
//////////////////////////////////////////////////////////////////////////////////////
function TFlexRangeHelper.Low: Integer;
begin
  Result := Self[0];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangeの上限値を取得
// [引数] なし
// [戻値] 上限値
//////////////////////////////////////////////////////////////////////////////////////
function TFlexRangeHelper.High: Integer;
begin
  Result := Self[1];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangeの長さを取得
// [引数] なし
// [戻値] 長さ
//////////////////////////////////////////////////////////////////////////////////////
function TFlexRangeHelper.Len: Integer;
begin
  Result := High - Low + 1;
end;

{ TFlexDimension }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 対象次元の配列サイズを返す
// [引数] なし
// [戻値] 配列サイズ
//////////////////////////////////////////////////////////////////////////////////////
function TFlexDimension.Len: NativeInt;
begin
  Result := High - Low + 1;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の情報を取得（1-based）
// [引数] 次元番号（1-based）
// [戻値] 次元情報
//////////////////////////////////////////////////////////////////////////////////////
function TFlexDimensionsHelper.GetDimension(Index: Integer): TFlexDimension;
begin
  Result := Self[Index - 1];  // 1ベース→0ベース変換
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の情報を設定（1-based）
// [引数] 次元番号（1-based）, 次元情報
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexDimensionsHelper.SetDimension(Index: Integer; const Value: TFlexDimension);
begin
  Self[Index - 1] := Value;  // 1ベース→0ベース変換
end;

{ TFlexArrayEnumerator<T> }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を初期化
// [引数] データの先頭ポインタ, 全要素数
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArrayEnumerator<T>.Create(const AData: TArray<T>; Size: NativeInt);
begin
  FData := AData;
  FTotalSize := Size;
  FIndex := -1;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 現在の要素を取得
// [引数] なし
// [戻値] 現在の要素
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArrayEnumerator<T>.GetCurrent: T;
begin
  Result := FData[FIndex];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次の要素に移動
// [引数] なし
// [戻値] 次の要素が存在するかどうか
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArrayEnumerator<T>.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FTotalSize;
end;


{ TFlexArray<T> }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 範囲配列から配列構造を初期化
// [引数] 各次元の範囲配列
// [戻値] なし
// [使用例] InitializeFromRanges([[1, 10], [1, 10]])
// [備考] 各次元の範囲配列は [Low, High] のペアになっていること
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.InitializeDimensions(const Ranges: TFlexRanges);
var
  i: Integer;
  CurrentStride: NativeInt;
begin
  SetLength(FDims, System.Length(Ranges));  // 完全0ベース化
  CurrentStride := 1;

  // 後ろの次元から歩幅を計算することで多次元に対応
  for i := System.Length(Ranges) - 1 downto 0 do
  begin
    // 引数の配列が [Low, High] のペアになっているか念のためチェック
    if System.Length(Ranges[i]) <> 2 then
      raise Exception.CreateFmt(
        'TFlexArray: 第 %d 次元の指定が [Low, High] のペアではありません。', [i + 1]);

    if Ranges[i].Low > Ranges[i].High then
      raise Exception.CreateFmt(
        'TFlexArray: 第 %d 次元の範囲が不正です (Low:%d > High:%d)', [i + 1, Ranges[i].Low, Ranges[i].High]);

    FDims[i].Low    := Ranges[i].Low;    // 0ベースで格納
    FDims[i].High   := Ranges[i].High;
    FDims[i].Stride := CurrentStride;

    // 全要素数を累積計算
    CurrentStride := CurrentStride * Ranges[i].Len;
  end;

  FTotalSize := CurrentStride;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 汎用・多次元コンストラクタ
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.Create([3, 4], 1)  // 1始まりの3x4行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.Create(const Shapes: array of Integer; BaseIndex: Integer);
var
  i: Integer;
  Ranges: TFlexRanges;
  L, H: Integer;
begin
  SetLength(Ranges, System.Length(Shapes));
  for i := 0 to System.High(Shapes) do
  begin
    L := BaseIndex;
    H := BaseIndex + Shapes[i] - 1;
    Ranges[i] := [L, H];
  end;
  InitializeDimensions(Ranges);
  SetLength(FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元用範囲指定コンストラクタ
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([-5, 5])  // -5から5までの11要素
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const Range: TFlexRange);
begin
  InitializeDimensions([Range]);
  SetLength(FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元用範囲指定コンストラクタ
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([[1, 3], [1, 2]])  // 3x2行列
//          静的配列の宣言例に相当 array[1..3, 1..2] of Integer;
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const Ranges: TFlexRanges);
begin
  InitializeDimensions(Ranges);
  SetLength(FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 文字列から範囲指定コンストラクタ
// [引数] 範囲文字列 "1..3,1..2" または "[1..3,1..2]"
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange("1..3,1..2")  // 3x2行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const RangeStr: string);
begin
  InitializeDimensions(RangesStringToRanges(RangeStr));
  SetLength(FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] FlexArrayからFlexArrayを生成する
// [引数] 元のFlexArray
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromFlexArray(const Src: TFlexArray<T>);
begin
  // 構造情報をコピー
  SetLength(FDims, System.Length(Src.FDims));
  TArray.Copy<TFlexDimension>(Src.FDims, FDims, System.Length(Src.FDims));

  FTotalSize := Src.FTotalSize;
  SetLength(FData, FTotalSize);
  TArray.Copy<T>(Src.FData, FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 動的一次元配列からFlexArrayを生成する
// [引数] 元の動的配列, 開始インデックス(省略時:0)
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromArray(arr, 1)
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromArray(const Src: TArray<T>; BaseIndex: Integer = 0);
var
  L, H: Integer;
begin
  L := BaseIndex;
  H := BaseIndex + System.Length(Src) - 1;
  InitializeDimensions([[L, H]]);

  // データをコピーして実体化
  SetLength(FData, FTotalSize);
  TArray.Copy<T>(Src, FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 参照生成コンストラクタ
// [引数] 元の動的配列, 開始インデックス(省略時:0)
// [戻値] なし
// [備考] CreateFromArrayと異なり、変更は元の配列に反映される
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.ViewFromArray(const Src: TArray<T>; BaseIndex: Integer = 0);
var
  L, H: Integer;
begin
  FIsView := True;
  L := BaseIndex;
  H := BaseIndex + System.Length(Src) - 1;
  InitializeDimensions([[L, H]]);

  // データを参照して同一化
  FData := Src;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の形状を変更し、データを保持したまま次元構造を再定義
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] Matrix.Reshape([3, 2], 1)  // 1始まりの3x2行列に再定義
// [備考] 変更前後の全要素数が一致する必要あり
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Reshape(const Shapes: array of Integer; BaseIndex: Integer);
var
  i: Integer;
  NewTotalSize: NativeInt;
  NewRanges: TFlexRanges;
  L, H: Integer;
begin
  // 新しい形状の全要素数を計算
  NewTotalSize := 1;
  for i := 0 to System.High(Shapes) do
    NewTotalSize := NewTotalSize * Shapes[i];

  // 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'Reshape: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));

  // 新しい範囲配列を生成
  SetLength(NewRanges, System.Length(Shapes));
  for i := 0 to System.High(Shapes) do
  begin
    L := BaseIndex;
    H := BaseIndex + Shapes[i] - 1;
    NewRanges[i] := [L, H];
  end;

  // 次元情報のみ更新（データは保持）
  InitializeDimensions(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] ベクトル形状に再定義（1次元専用）
// [引数] 開始インデックス
// [戻値] なし
// [使用例] Vector.ReshapeVector(1)  // 1始まりのベクトルに再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeVector(BaseIndex: Integer);
begin
  Reshape([FTotalSize], BaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元範囲指定による再定義
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] Vector.ReshapeRange([-5, 5])  // -5から5までの範囲に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const Range: TFlexRange);
var
  NewTotalSize: NativeInt;
begin
  // 新しい範囲の全要素数を計算
  NewTotalSize := Range.Len;

  // 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'ReshapeRange: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));

  // 次元情報のみ更新（データは保持）
  InitializeDimensions([Range]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元範囲指定による再定義
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] Tensor.ReshapeRange([[1, 3], [1, 2]])  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const Ranges: TFlexRanges);
var
  i: Integer;
  NewTotalSize: NativeInt;
begin
  // 新しい範囲の全要素数を計算
  NewTotalSize := 1;
  for i := 0 to System.High(Ranges) do
    NewTotalSize := NewTotalSize * Ranges[i].Len;

  // 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'ReshapeRange: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));

  // 次元情報のみ更新（データは保持）
  InitializeDimensions(Ranges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 文字列から範囲指定による再定義
// [引数] 範囲文字列 "1..3,1..2" または "[1..3,1..2]"
// [戻値] なし
// [使用例] Matrix.ReshapeRange("1..3,1..2")  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const RangeStr: string);
begin
  ReshapeRange(RangesStringToRanges(RangeStr));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次元数のチェック
// [引数] 期待される次元数
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.CheckDimension(ExpectedDim: Integer);
var
  ActualDim: Integer;
begin
  ActualDim := Self.DimensionCount;
  if ActualDim <> ExpectedDim then
    raise Exception.CreateFmt(
      '次元エラー: %d次元配列専用の操作ですが、現在は %d次元です。', [ExpectedDim, ActualDim]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Viewモードかチェックし、例外を発生させる
// [引数] なし
// [戻値] なし
// [備考] Viewモードの場合は例外を発生（ただし、数値型のみ許可）
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.CheckViewMode;
var
  Val: TValue;
begin
  if FIsView then
  begin
    // 数値型のみ許可
    Val := TValue.From<T>(default(T));
    if Val.Kind in [tkInteger, tkFloat] then Exit;

    raise Exception.Create('Viewモードの配列は変更できません。CreateFromFlexArrayでコピーしてから使用してください。');
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] すべての次元のベースインデックスを指定された値に統一
// [引数] BaseIndex - 目標のベースインデックス
// [戻値] なし
// [備考] データは保持したまま次元情報のみ変更
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.NormalizeToBaseIndex(BaseIndex: Integer);
var
  i: Integer;
  Shapes: TArray<Integer>;
begin
  // 現在の形状を取得
  SetLength(Shapes, Self.DimensionCount);
  for i := 0 to Self.DimensionCount - 1do
    Shapes[i] := Self.FDims[i].Len; // FDimsは0ベース

  Reshape(Shapes, BaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] SelfとAnotherのベースインデックスをチェックし、統一されたベースインデックスを返す
// [引数] Another - 比較対象の配列
// [戻値] Integer - 統一されたベースインデックス
// [備考] すべてが一致の場合：ベースインデックスを返す。不一致の場合：内部で例外
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetCompatibleBaseIndex(const Another: TFlexArray<T>): Integer;
var
  i: Integer;
begin
  Result := Self.FDims[0].Low;

  for i := 0 to Self.DimensionCount - 1 do
  begin
    if Self.FDims[i].Low <> Result then
      raise Exception.Create('GetCompatibleBaseIndex: 各配列のすべての次元で同じベースインデックスを使用する必要があります。混合ベースは未対応です。');
  end;

  for i := 0 to Another.DimensionCount - 1 do
  begin
    if Another.FDims[i].Low <> Result then
      raise Exception.CreateFmt('GetCompatibleBaseIndex: 異なるベースインデックスの配列は結合できません。Self=%d, Another=%d', [Result, Another.FDims[i].Low]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスから多次元座標への変換
// [引数] 線形インデックス
// [戻値] 各次元の座標配列（GetOffsetの逆の変換を行う）
// [例] [[1, 3], [1, 2]] のとき GetCoords(0)=[1,1], GetCoords(1)=[1,2], GetCoords(2)=[2,1]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetCoords(LinearIndex: NativeInt): TCoords;
var
  i: Integer;
  TempIndex: NativeInt;
begin
  SetLength(Result, Self.DimensionCount);
  TempIndex := LinearIndex;

  // 末尾の次元から順に割っていく（GetOffsetの逆工程）
  for i := Self.DimensionCount - 1 downto 0 do
  begin
    Result[i] := (TempIndex mod FDims[i].Len) + FDims[i].Low; // FDimsは0ベース
    TempIndex := TempIndex div FDims[i].Len;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元座標から線形インデックスへの変換
// [引数] 各次元の座標配列
// [戻値] 線形インデックス（範囲外の場合は例外）
// [例] [[1, 3], [1, 2]] のとき GetOffset([1,1])=0, GetOffset([1,2])=1, GetOffset([2,1])=2
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetOffset(const Coords: array of Integer): NativeInt;
var
  i: Integer;
begin
  if System.Length(Coords) <> Self.DimensionCount then
    raise Exception.CreateFmt('GetOffset: 座標数が次元数と一致しません。Coords=%d, Dims=%d', [System.Length(Coords), Self.DimensionCount]);

  Result := 0;
  for i := 0 to Self.DimensionCount - 1 do
  begin
    if (FDims[i].Low <= Coords[i]) and (Coords[i] <= FDims[i].High) then
      Result := Result + (NativeInt(Coords[i]) - FDims[i].Low) * FDims[i].Stride
    else
      raise Exception.CreateFmt('GetOffset: 範囲外です。Dim=%d, Value=%d, Range=%d..%d', [i + 1, Coords[i], FDims[i].Low, FDims[i].High]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標の値を取得
// [引数] 各次元の座標配列
// [戻値] 座標に対応する値（範囲外の場合は例外）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetValue(const Coords: array of Integer): T;
begin
  Result := Self.Elements[GetOffset(Coords)];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標に値を設定
// [引数] 各次元の座標配列, 設定する値
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetValue(const Coords: array of Integer; const Value: T);
begin
  Self.Elements[GetOffset(Coords)] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスで要素を取得
// [引数] 0-based線形インデックス
// [戻値] 指定位置の要素（範囲外の場合は例外）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetElement(Index: NativeInt): T;
begin
  Result := FData[Index];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスに要素を設定
// [引数] 0-based線形インデックス, 設定する要素
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetElement(Index: NativeInt; const Value: T);
begin
  FData[Index] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 値を文字列に変換
// [引数] 変換対象の値
// [戻値] 文字列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ValueToStr(const V: T): string;
var
  Val: TValue;
begin
  Val := TValue.From<T>(V);
  case Val.Kind of
    // 文字列型の場合は、Delphi定数として成立するように単一引用符で囲む
    tkString, tkLString, tkWString, tkUString, tkChar, tkWChar:
      Result := QuotedStr(Val.ToString);

    else
    begin
      try
        Result := Val.ToString;  // とりあえず実行
      except
        Result := 'この型は表示できません';  // 例外時
      end;
    end;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列を文字列に変換
// [引数] なし
// [戻値] 文字列表現
// [使用例] 1次元の場合: [2, 2, 3]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ToString: string;
var
  Rows: TArray<string>;
  r, i: Integer;
begin
  // 4次元以上は値を出力しない
  if Self.DimensionCount > 3 then
    Exit(Format('%d次元配列です', [Self.DimensionCount]));

  // 1〜3次元の共通処理
  SetLength(Rows, FDims[0].Len);
  i := 0;
  for r := Low(1) to High(1) do
  begin
    case Self.DimensionCount of
      1: Rows[i] := ValueToStr(Self[[r]]);
      2: Rows[i] := SliceRow(r).ToString;
      3: Rows[i] := Format('{Page %d}' + ' %s', [r, SliceDim(1, r).ToString]);
    end;
    Inc(i);
  end;

  case Self.DimensionCount of
    1: Result := '[' + String.Join(', ', Rows) + ']';
    2: Result := '[' + sLineBreak + '  ' + String.Join(',' + sLineBreak + '  ', Rows) + sLineBreak + ']';
    3: Result := '[' + sLineBreak + '  ' + String.Join(',' + sLineBreak + '  ', Rows) + ']';
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列を1次元配列に変換
// [引数] なし
// [戻値] 1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ToVector(): TArray<T>;
begin
  SetLength(Result, FTotalSize);
  TArray.Copy<T>(FData, Result, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 範囲文字列を解析して範囲配列に変換
// [引数] 範囲文字列 "1..3,1..2" または "[1..3,1..2]"
// [戻値] 範囲配列 [[1,3],[1,2]]
// [使用例] ParseRangesString("1..3,1..2") → [[1,3],[1,2]]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.RangesStringToRanges(const RangeStr: string): TFlexRanges;
var
  CleanStr: string;
  Parts: TArray<string>;
  RangeParts: TArray<string>;
  i: Integer;
  L, H: Integer;
begin
  CleanStr := RangeStr.Replace(' ', '');

  if (CleanStr.StartsWith('[')) and (CleanStr.EndsWith(']')) then
    CleanStr := CleanStr.Substring(1, CleanStr.Length - 2);

  if CleanStr = '' then
    raise Exception.CreateFmt('ParseRangesString: 不正な形式 "%s"', [RangeStr]);

  Parts := CleanStr.Split([',']);

  // 次元の数だけLOOP
  SetLength(Result, System.Length(Parts));
  for i := 0 to System.High(Parts) do
  begin
    RangeParts := Parts[i].Split(['..']);

    if System.Length(RangeParts) <> 2 then
      raise Exception.CreateFmt('ParseRangesString: 不正な形式 "%s"', [RangeStr]);

    if not (TryStrToInt(RangeParts[0], L) and TryStrToInt(RangeParts[1], H)) then
      raise Exception.CreateFmt('ParseRangesString: 不正な形式 "%s"', [RangeStr]);

    if L > H then
      raise Exception.CreateFmt('ParseRangesString: 不正な形式 "%s"', [RangeStr]);

    Result[i] := [L, H];
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 範囲情報を文字列に変換
// [引数] なし
// [戻値] 範囲情報の文字列表現 例：[1990..1991, 1..12, 1..31]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ToRangesString(): string;
var
  i: Integer;
  Ranges: TFlexRanges;
  Parts: TArray<string>;
begin
  Ranges := GetRanges;
  SetLength(Parts, System.Length(Ranges));
  for i := 0 to System.Length(Ranges) - 1 do
    Parts[i] := Format('%d..%d', [Ranges[i].Low, Ranges[i].High]);
  Result := '[' + String.Join(', ', Parts) + ']';
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の配列サイズを返す
// [引数] 次元番号
// [戻値] 配列サイズ
// [備考] 利用者向けAPI（封印中）です。内部実装では FDims.Items[Dim].Len を使用してください。
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Len(Dim: Integer): NativeInt;
begin
  Result := FDims.Items[Dim].Len;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の最小インデックスを取得
// [引数] なし
// [戻値] 最小インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Low: Integer;
begin
  if System.Length(FDims) <> 1 then
    raise Exception.Create('多次元配列です。次元を明示してください（例: Low(1)）。');
  Result := FDims[0].Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の最大インデックスを取得
// [引数] なし
// [戻値] 最大インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.High: Integer;
begin
  if System.Length(FDims) <> 1 then
    raise Exception.Create('多次元配列です。次元を明示してください（例: High(1)）。');
  Result := FDims[0].High;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最小インデックスを取得
// [引数] 次元番号
// [戻値] 最小インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Low(Dim: Integer): Integer;
begin
  Result := FDims.Items[Dim].Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最大インデックスを取得
// [引数] 次元番号
// [戻値] 最大インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.High(Dim: Integer): Integer;
begin
  Result := FDims.Items[Dim].High;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元数を取得
// [引数] なし
// [戻値] 次元数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetDimensionCount: Integer;
begin
  Result := System.Length(FDims); // 完全0ベース化
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 現在の範囲情報を取得する
// [引数] なし
// [戻値] 各次元の範囲配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetRanges: TFlexRanges;
var
  i: Integer;
begin
  SetLength(Result, Self.DimensionCount);
  for i := 0 to Self.DimensionCount - 1 do
    Result[i] := [FDims[i].Low, FDims[i].High]; // FDimsは0ベース
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を取得
// [引数] なし
// [戻値] 列挙子オブジェクト
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetEnumerator: TFlexArrayEnumerator<T>;
begin
  Result := TFlexArrayEnumerator<T>.Create(FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標を初期化
// [引数] 初期化する座標配列
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.InitializeCoords(var Coords: TCoords);
var
  i: Integer;
begin
  SetLength(Coords, Self.DimensionCount);
  for i := 0 to Self.DimensionCount - 1 do
    Coords[i] := Self.FDims[i].Low;  // FDimsは0ベース
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標をインクリメント
// [引数] 現在の座標配列
// [戻値] なし
// [備考] 2次元配列 [1..3, 1..2] の場合:
//        [1,1] → [1,2] → [2,1] → [2,2] → [3,1] → [3,2]
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.IncCoords(var Coords: TCoords);
var
  d: Integer;
begin
  // 一番右側の次元（最小単位）から順にチェック
  for d := system.High(Coords) downto 0 do
  begin
    Inc(Coords[d]);

    // 上限を超えていないなら終了
    if Coords[d] <= Self.FDims[d].High then Exit;

    // 上限を超えたので、現在の次元を最小値(Low)にリセットし、
    // ループを継続して一つ左の次元（上位桁）を Inc する
    Coords[d] := Self.FDims[d].Low;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元をスライスして取得
// [引数] 次元番号, 取得インデックス
// [戻値] スライス配列（元の次元数より1次元少ない配列が生成されます）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDim(Dim: Integer; Index: Integer): TFlexArray<T>;
begin
  if Self.DimensionCount = 1 then
    raise Exception.Create('1次元配列にはChooseSlice(Dim, Index)は使用できません。ChooseSlice(Index)を使用してください。');

  Result := SliceDimIndexes(Dim, [Index, Index]);

  // 2. DemoteDimensionで次元を削除
  Result.DemoteDimension(Dim);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定行1次元を取得
// [引数] 行インデックス
// [戻値] 行の1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceRow(RowIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := SliceDim(1, RowIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定列を1次元で取得
// [引数] 列インデックス
// [戻値] 列の1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceCol(ColIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := SliceDim(2, ColIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元を入れ替え
// [引数] 新しい次元の順序 指定例：[1, 2, 3] -> [3, 1, 2]
// [戻値] 転置後の配列
// [備考] NewDims は「1..次元数」の並べ替え（重複なし）を、次元数分指定します。
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Transpose(const NewDims: array of Integer): TFlexArray<T>;
var
  i, d: Integer;
  NewRanges: TFlexRanges;
  ResultCoords, SelfCoords: TCoords;
  DimUsed: array of Boolean;
begin
  // 整合性チェック
  if System.Length(NewDims) <> Self.DimensionCount then
    raise Exception.Create('Transpose: 指定された軸の数が配列の次元数と一致しません。');

  // すべての次元が使用されているかチェック
  SetLength(DimUsed, DimensionCount);
  for i := 0 to DimensionCount - 1 do
  begin
    if (NewDims[i] < 1) or (NewDims[i] > DimensionCount) then
      raise Exception.CreateFmt('Transpose: 次元指定 %d が範囲外です。', [NewDims[i]]);
    DimUsed[NewDims[i] - 1] := True;
  end;
  for i := 0 to DimensionCount - 1 do
    if not DimUsed[i] then
      raise Exception.CreateFmt('Transpose: 次元 %d が指定されていません。', [i + 1]);

  // NewRanges の計算
  SetLength(NewRanges, DimensionCount);
  for i := 0 to DimensionCount - 1 do
    NewRanges[i] := [Self.Low(NewDims[i]), Self.High(NewDims[i])];
  Result := TFlexArray<T>.CreateFromRange(NewRanges);

  SetLength(SelfCoords, DimensionCount);
  Result.InitializeCoords(ResultCoords);
  for i := 0 to Result.FTotalSize - 1 do
  begin
    for d := 0 to DimensionCount - 1 do
    begin
      // 次元を入れ替え（注意：1-basedインデックスを0-basedインデックスに変換）
      SelfCoords[NewDims[d] - 1] := ResultCoords[d];
    end;
    Result.Elements[i] := Self.Elements[GetOffset(SelfCoords)];
    Result.IncCoords(ResultCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用の転置
// [引数] なし
// [戻値] 行列を入れ替えた配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Transpose: TFlexArray<T>;
begin
  CheckDimension(2);
  Result := Transpose([2, 1]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 同一次元配列の結合
// [引数] 結合対象の配列, 結合する次元
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ConcatEqualDim(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
var
  AllIndexes: TArray<Integer>;
  i: Integer;
  DimIdx: Integer;
  d: Integer;
begin
  // 1-based to 0-based
  DimIdx := TargetDim - 1;

  // 次元のサイズチェック
  for d := 0 to Self.DimensionCount - 1 do
  begin
    if d <> DimIdx then
    begin
      if Self.FDims[d].Len <> Another.FDims[d].Len then
        raise Exception.CreateFmt('ConcatEqualDim: 次元%dのサイズが一致しません。Self=%d, Another=%d',
          [d+1, Self.FDims[d].Len, Another.FDims[d].Len]);
    end;
  end;

  // Selfの全インデックスを生成
  SetLength(AllIndexes, Self.Len(TargetDim));
  for i := 0 to System.High(AllIndexes) do
    AllIndexes[i] := Self.Low(TargetDim) + i;

end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元にサイズ1の次元を挿入して次元数を増やす（破壊系ヘルパー）
// [引数] TargetDim: 挿入する次元番号(1-based)
// [戻値] なし
// [使用例]
// PromoteDimension([1,2,3], 1) → [[1,2,3]] (1D→2D)
//    [1..3] (サイズ3) →  [1..1, 1..3] (1×3)
// PromoteDimension([1,2,3], 2) → [[1],[2],[3]] (1D→2D)
//    [1..3] (サイズ3) →  [1..3, 1..1] (3×1)
// PromoteDimension([[1,2],[3,4]], 1) → [[[1,2],[3,4]]] (2D→3D)
//    [1..2, 1..2] (2×2) →  [1..1, 1..2, 1..2] (1×2×2)
// PromoteDimension([[1,2],[3,4]], 2) → [[[1,2]], [[3,4]]]
//    [1..2, 1..2] (2×2) →  [1..2, 1..1, 1..2] (2×1×2)
// PromoteDimension([[1,2],[3,4]], 3) → [[[1],[2]], [[3],[4]]]
//    [1..2, 1..2] (2×2) →  [1..2, 1..2, 1..1] (2×2×1)
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.PromoteDimension(TargetDim: Integer);
var
  NewRanges: TFlexRanges;
  d: Integer;
begin
  // TargetDimのチェック
  if (TargetDim < 1) or (TargetDim > DimensionCount + 1) then
    raise Exception.CreateFmt(
      'PromoteDimension: TargetDimは1から%dの範囲である必要があります', [DimensionCount + 1]);

  // 現在の範囲を取得
  NewRanges := GetRanges;

  // TargetDimにサイズ1の次元を挿入
  SetLength(NewRanges, Length(NewRanges) + 1);
  for d := system.High(NewRanges) downto TargetDim do
    NewRanges[d] := NewRanges[d-1];  // 後ろにシフト
  NewRanges[TargetDim-1] := [1, 1];  // サイズ1の次元を挿入

  // 他の次元のLow/Highは維持したままreshape
  ReshapeRange(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元を削除して次元数を減らす（PromoteDimensionの逆変換）
// [引数] 削除する次元番号(1-based)
// [戻値] なし
// [使用例]
//   元: [1..2, 1..2, 1..1] (2×2×1) → DemoteDimension(3) → [1..2, 1..2] (2×2)
//   元: [1..1, 1..2, 1..3] (1×2×3) → DemoteDimension(1) → [1..2, 1..3] (2×3)
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.DemoteDimension(TargetDim: Integer);
var
  NewRanges: TFlexRanges;
  d: Integer;
begin
  // TargetDimのチェック
  if (TargetDim < 1) or (TargetDim > DimensionCount) then
    raise Exception.CreateFmt(
      'DemoteDimension: TargetDimは1から%dの範囲である必要があります', [DimensionCount]);

  // 削除する次元のサイズが1でなければならない
  if FDims[TargetDim - 1].Len <> 1 then
    raise Exception.CreateFmt(
      'DemoteDimension: 削除する次元のサイズは1である必要があります。Dim=%d, Size=%d', 
      [TargetDim, FDims[TargetDim - 1].Len]);

  // 現在の範囲を取得
  NewRanges := GetRanges;
  
  // TargetDimの次元を削除
  for d := TargetDim-1 to system.High(NewRanges)-1 do
    NewRanges[d] := NewRanges[d+1];  // 前に詰める
  SetLength(NewRanges, Length(NewRanges) - 1);
  
  // 他の次元のLow/Highは維持したままreshape
  ReshapeRange(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元で配列を結合
// [引数] 結合対象の配列, 結合する次元
// [戻値] 結合結果の配列
// [備考] 次元数の差が1以内の場合は自動的に次元を昇格させて結合
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Concat(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
var
  SelfReady, AnotherReady: TFlexArray<T>;
  DimDiff: Integer;
  BaseIndex: Integer;
begin
  // TargetDimの制約チェック
  if (TargetDim < 1) or (TargetDim > Self.DimensionCount) then
    raise Exception.CreateFmt(
      'Concat: TargetDimは1から%dの範囲である必要があります', [Self.DimensionCount]);

  // 次元数のチェック（Another - Self = [0, 1] のみ許可）
  DimDiff := Self.DimensionCount - Another.DimensionCount;
  if not (Self.DimensionCount - Another.DimensionCount in [0, 1]) then
    raise Exception.CreateFmt(
      'Concat: %d次元配列と%d次元配列は結合できません。AnotherはSelfと同次元か1次元少ない必要があります', 
      [Self.DimensionCount, Another.DimensionCount]);

  // ベースインデックスのチェックと取得（すべて一致しないと例外）
  BaseIndex := Self.GetCompatibleBaseIndex(Another);

  SelfReady := Self;
  AnotherReady := Another;

  // 1ベース以外は1ベースに正規化
  if BaseIndex <> 1 then
  begin
    SelfReady.NormalizeToBaseIndex(1);
    AnotherReady.NormalizeToBaseIndex(1);
  end;

  // AnotherReadyの次元をSelfReadyにあわせて拡張
  if DimDiff > 0 then
    AnotherReady.PromoteDimension(TargetDim);

  // 同一次元結合を実行
  Result := SelfReady.ConcatEqualDim(AnotherReady, TargetDim);

  // 元のベースインデックスに戻す
  if BaseIndex <> 1 then
    Result.NormalizeToBaseIndex(BaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用の縦方向結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.VStack(const Another: TFlexArray<T>): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := Self.Concat(Another, 1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用の水平方向結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.HStack(const Another: TFlexArray<T>): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := Self.Concat(Another, 2);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列専用の配列結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(const Another: TFlexArray<T>): TFlexArray<T>;
begin
  CheckDimension(1);
  Another.CheckDimension(1);
  Result := Self.Concat(Another, 1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列専用の配列結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(const Another: TArray<T>): TFlexArray<T>;
var
  NewRange: TFlexRange;
  AnotherLen: Integer;
begin
  CheckDimension(1);
  AnotherLen := System.Length(Another);
  NewRange := [Self.Low, Self.High + AnotherLen];
  Result := TFlexArray<T>.CreateFromRange(NewRange);

  // 高速なデータコピー
  TArray.Copy<T>(Self.FData, Result.FData, 0, 0, Self.FTotalSize);
  TArray.Copy<T>(Another, Result.FData, 0, Self.FTotalSize, AnotherLen);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 単一値を配列に追加
// [引数] 追加する値
// [戻値] 追加後の新しい配列
// [使用例] Vector1 := Vector1.AppendArray(42)
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(const Value: T): TFlexArray<T>;
begin
  CheckDimension(1);
  Result := Self.AppendArray([Value]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を直接変更する（破壊的）
// [引数] 変換関数（値と座標を引数に取り、新しい値を返す）
// [戻値] なし
// [使用例]   A.Map(function(const Value: Integer; const Coords: TCoords): Integer
//               begin
//                 Result := Coords[0] * 1000 + Coords[1];
//               end);
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Map(const AFunc: TMapFunc<T>);
var
  i: Integer;
  CurrentCoords: TCoords;
begin
  CheckViewMode;
  Self.InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    Self.Elements[i] := AFunc(Self.Elements[i], CurrentCoords);
    Self.IncCoords(CurrentCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を直接変更する（破壊的）
// [引数] 変換関数（値のみを引数に取り、新しい値を返す）
// [戻値] なし
// [使用例]  A.Map(function(const Value: Integer): Integer
//             begin
//               Result := Value * 2;
//             end);
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Map(const AFunc: TMapFuncValue<T>);
var
  i: Integer;
begin
  CheckViewMode;
  for i := 0 to FTotalSize - 1 do
  begin
    Self.Elements[i] := AFunc(Self.Elements[i]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を変換して新しい配列を返す（非破壊的）
// [引数] 変換関数（値と座標を引数に取り、新しい値を返す）
// [戻値] 変換後の新しい配列
// [使用例] B := A.Mapped<string>(function(const Value: Integer; const Coords: TCoords): string
//                 begin
//                   Result := Coords[0].ToString + '.' + Coords[1].ToString;
//                 end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Mapped<TResult>(const AFunc: TMappedFunc<T, TResult>): TFlexArray<TResult>;
var
  i: Integer;
  CurrentCoords: TCoords;
begin
  Result := TFlexArray<TResult>.CreateFromRange(GetRanges);
  Result.InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    Result.Elements[i] := AFunc(Self.Elements[i], CurrentCoords);
    Result.IncCoords(CurrentCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を変換して新しい配列を返す（非破壊的）
// [引数] 変換関数（値のみを引数に取り、新しい値を返す）
// [戻値] 変換後の新しい配列
// [使用例] B := A.Mapped<string>(function(const Value: Integer): string
//                 begin
//                   Result := Value.ToString;
//                 end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Mapped<TResult>(const AFunc: TMappedFuncValue<T, TResult>): TFlexArray<TResult>;
var
  i: Integer;
begin
  Result := TFlexArray<TResult>.CreateFromRange(GetRanges);
  for i := 0 to FTotalSize - 1 do
  begin
    Result.Elements[i] := AFunc(Self.Elements[i]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素をフィルタリングして条件に合う要素のみを返す（非破壊的）
// [引数] フィルタ関数（値と座標を引数に取り、条件を返す）
// [戻値] 条件に合う要素の配列
// [使用例] B := A.Filter(function(const Value: Integer; const Coords: TCoords): Boolean
//                 begin
//                   Result := (Coords[0] >= Coords[1]);
//                 end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Filter(const AFunc: TFilterFunc<T>): TArray<T>;
var
  i, Count: Integer;
  CurrentCoords: TCoords;
begin
  // まず結果をカウント
  Count := 0;
  Self.InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    if AFunc(Self.Elements[i], CurrentCoords) then
      Inc(Count);
    Self.IncCoords(CurrentCoords);
  end;

  // 結果を設定
  SetLength(Result, Count);
  Count := 0;
  Self.InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    if AFunc(Self.Elements[i], CurrentCoords) then
    begin
      Result[Count] := Self.Elements[i];
      Inc(Count);
    end;
    Self.IncCoords(CurrentCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素をフィルタリングして条件に合う要素のみを返す（非破壊的）
// [引数] フィルタ関数（値のみを引数に取り、条件を返す）
// [戻値] 条件に合う要素の配列
// [使用例] B := A.Filter(function(const Value: Integer): Boolean
//                 begin
//                   Result := Value > 0;
//                 end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Filter(const AFunc: TFilterFuncValue<T>): TArray<T>;
var
  i, Count: Integer;
begin
  // まず結果をカウント
  Count := 0;
  for i := 0 to FTotalSize - 1 do
    if AFunc(Self.Elements[i]) then
      Inc(Count);

  // 結果を設定
  SetLength(Result, Count);
  Count := 0;
  for i := 0 to FTotalSize - 1 do
  begin
    if AFunc(Self.Elements[i]) then
    begin
      Result[Count] := Self.Elements[i];
      Inc(Count);
    end;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素を集約して単一の値に変換（非破壊的）
// [引数] 初期値, 集約関数（値と座標を引数に取る）
// [戻値] 集約結果
// [使用例] Sum := A.Reduce<Integer>(0,
//            function(const Current: Integer; const Value: Integer; const Coords: TCoords): Integer
//            begin
//              Result := Current + Coords[0];
//            end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Reduce<TResult>(const InitialValue: TResult; const AFunc: TReduceFunc<T, TResult>): TResult;
var
  i: Integer;
  CurrentCoords: TCoords;
begin
  Result := InitialValue;
  Self.InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    Result := AFunc(Result, Self.Elements[i], CurrentCoords);
    Self.IncCoords(CurrentCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素を集約して単一の値に変換（非破壊的）
// [引数] 初期値, 集約関数（値のみを引数に取る）
// [戻値] 集約結果
// [使用例] Sum := A.Reduce<Integer>(0,
//            function(const Current: Integer; const Value: Integer): Integer
//            begin
//              Result := Current + Value;
//            end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Reduce<TResult>(const InitialValue: TResult; const AFunc: TReduceFuncValue<T, TResult>): TResult;
var
  i: Integer;
begin
  Result := InitialValue;
  for i := 0 to FTotalSize - 1 do
    Result := AFunc(Result, Self.Elements[i]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素を集約して単一の値に変換（非破壊的、初期値なし）
// [引数] 集約関数（値のみを引数に取る、TResult=Tに固定）
// [戻値] 集約結果
// [備考] 空配列の場合は例外を発生させる
// [使用例] Sum := A.Reduce(
//            function(const Current: Integer; const Value: Integer): Integer
//            begin
//              Result := Current + Value;
//            end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Reduce(const AFunc: TReduceFuncSimple<T>): T;
var
  i: Integer;
begin
  Result := Self.Elements[0];
  for i := 1 to FTotalSize - 1 do
    Result := AFunc(Result, Self.Elements[i]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素の合計値を計算
// [引数] なし
// [戻値] 合計値
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Sum: T;
var
  i: Integer;
  Value: Variant;
begin
  try
    Value := 0;
    for i := 0 to FTotalSize - 1 do
      Value := Value + TValue.From<T>(Self.Elements[i]).AsVariant;

    Result := TValue.FromVariant(Value).AsType<T>;
  except
    raise Exception.Create('Sum: この型は加算ができません');
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素の最大値を取得
// [引数] なし
// [戻値] 最大値
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Max: T;
var
  i: Integer;
  Comparer: IComparer<T>;
begin
  // 型 T に最適な比較器を取得（一度だけ実行）
  Comparer := TComparer<T>.Default;

  // 最初の要素を暫定の最大値とする
  Result := Self.Elements[0];

  try
    for i := 1 to FTotalSize - 1 do
    begin
      // Comparer.Compare(A, B) は A < B なら 負の値、A = B なら 0、A > B なら 正の値を返す
      if Comparer.Compare(Self.Elements[i], Result) > 0 then
        Result := Self.Elements[i];
    end;
  except
    raise Exception.Create('Max: この型は比較ができません');
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素の最小値を取得
// [引数] なし
// [戻値] 最小値
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Min: T;
var
  i: Integer;
  Comparer: IComparer<T>;
begin
  // 型 T に最適な比較器を取得（一度だけ実行）
  Comparer := TComparer<T>.Default;

  // 最初の要素を暫定の最小値とする
  Result := Self.Elements[0];

  try
    for i := 1 to FTotalSize - 1 do
    begin
      // Comparer.Compare(A, B) は A < B なら 負の値、A = B なら 0、A > B なら 正の値を返す
      if Comparer.Compare(Self.Elements[i], Result) < 0 then
        Result := Self.Elements[i];
    end;
  except
    raise Exception.Create('Min: この型は比較ができません');
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の指定位置に配列を挿入
// [引数] Dim: 次元番号(1-based), Index: 挿入位置, Items: 挿入する配列
// [戻値] 挿入後の新しい配列
// [使用例]
//   3D配列[2,3,4]に次元1の位置2で[1,4]配列を挿入 → [3,3,4]配列
//   2D配列[3,4]に行2で[1,4]配列を挿入 → [4,4]配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertDim(Dim: Integer; Index: Integer; const Items: TFlexArray<T>): TFlexArray<T>;
var
  Indexes: TArray<Integer>;
  i: Integer;
begin
  // パラメータ検証
  if (Dim < 1) or (Dim > DimensionCount) then
    raise Exception.CreateFmt('InsertDim: 次元番号が範囲外です。Dim=%d, 次元数=%d', [Dim, DimensionCount]);

  if (Index < Low(Dim)) or (Index > High(Dim) + 1) then
    raise Exception.CreateFmt('InsertDim: 挿入位置が範囲外です。Index=%d, 範囲=%d..%d', [Index, Low(Dim), High(Dim) + 1]);

  // Itemsの次元数チェック（同じ次元数が必要）
  if Items.DimensionCount <> DimensionCount then
    raise Exception.CreateFmt('InsertDim: 挿入配列の次元数が不正です。期待=%d, 実際=%d', [DimensionCount, Items.DimensionCount]);

  SetLength(Indexes, Self.Len(Dim));
  for i := 0 to System.High(Indexes) do
    Indexes[i] := Self.Low(Dim) + i;

  Result := SliceDimIndexesCore(Dim, Indexes, Items, Index);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の範囲を削除
// [引数] Dim: 次元番号(1-based), Range: 削除範囲[Low, High]
// [戻値] 削除後の新しい配列
// [使用例]
//   Result := Matrix.DeleteDim(2, [2, 5]); // 2〜5列目を削除
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteDim(Dim: Integer; const Range: TFlexRange): TFlexArray<T>;
var
  Indexes: TArray<Integer>;
  i, d: Integer;
begin
  // パラメータ検証
  if (Dim < 1) or (Dim > DimensionCount) then
    raise Exception.CreateFmt('DeleteDim: 次元番号が範囲外です。Dim=%d, 次元数=%d', [Dim, DimensionCount]);

  if (Range.Low < Low(Dim)) or (Range.High > High(Dim)) or (Range.Low > Range.High) then
    raise Exception.CreateFmt('DeleteDim: 削除範囲が不正です。Range=[%d,%d], 範囲=%d..%d', [Range.Low, Range.High, Low(Dim), High(Dim)]);

  SetLength(Indexes, Self.Len(Dim) - Range.Len);
  d := 0;

  // 前半部のインデックスを収集
  for i := Self.Low(Dim) to Range.Low - 1 do
  begin
    Indexes[d] := i;
    Inc(d);
  end;

  // 後半部のインデックスを収集
  for i := Range.High + 1 to Self.High(Dim) do
  begin
    Indexes[d] := i;
    Inc(d);
  end;

  Result := SliceDimIndexes(Dim, Indexes);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の範囲を抽出
// [引数] Dim: 次元番号(1-based), Range: 抽出範囲[Low, High]
// [戻値] 抽出後の新しい配列
// [使用例]
//   Result := Matrix.SliceDimRange(2, [2, 5]); // 2〜5列目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDimRange(Dim: Integer; const Range: TFlexRange): TFlexArray<T>;
var
  Indexes: TArray<Integer>;
  i: Integer;
begin
  // パラメータ検証
  if (Dim < 1) or (Dim > DimensionCount) then
    raise Exception.CreateFmt('SliceDimRange: 次元番号が範囲外です。Dim=%d, 次元数=%d', [Dim, DimensionCount]);

  if (Range.Low < Low(Dim)) or (Range.High > High(Dim)) or (Range.Low > Range.High) then
    raise Exception.CreateFmt('SliceDimRange: 抽出範囲が不正です。Range=[%d,%d], 範囲=%d..%d', [Range.Low, Range.High, Low(Dim), High(Dim)]);

  SetLength(Indexes, Range.Len);
  for i := 0 to system.High(Indexes) do
    Indexes[i] := Range.Low + i;

  Result := SliceDimIndexes(Dim, Indexes);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元のIndexの配列で指定した範囲を抽出
// [引数] Dim: 次元番号(1-based), Indexes: 抽出するIndexの配列, BaseIndex: 基準インデックス
// [戻値] 抽出後の新しい配列
// [備考] BaseIndexの省略時はselfの該当次元のbaseを使用
// [使用例]
//   Result := Matrix.SliceDimIndexes(2, [1, 3, 5]);    // 1,3,5列目を抽出
//   Result := Matrix.SliceDimIndexes(2, [1, 3, 5], 1); // 1,3,5列目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>;
begin
  Result := SliceDimIndexes(Dim, Indexes, Self.FDims[Dim - 1].Low);
end;
function TFlexArray<T>.SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>; BaseIndex: Integer): TFlexArray<T>;
var
  NewRanges: TFlexRanges;
  d: Integer;
begin
  Result := SliceDimIndexesCore(Dim, Indexes);

  // 指定次元をBaseIndexに合わせてreshape
  SetLength(NewRanges, Result.DimensionCount);
  for d := 0 to Result.DimensionCount - 1 do
  begin
    if d = Dim - 1 then
      // 指定次元のみBaseIndexを基準に
      NewRanges[d] := [BaseIndex, BaseIndex + Length(Indexes) - 1]
    else
      // 他の次元は元のまま
      NewRanges[d] := [Result.FDims[d].Low, Result.FDims[d].High];
  end;

  Result.ReshapeRange(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元のIndexの配列で指定した範囲を抽出または挿入
// [引数] Dim: 次元番号(1-based), Indexes: 抽出するIndexの配列,
//        Another: 挿入する配列(省略時は抽出のみ), Index: 挿入開始位置
// [戻値] 抽出後の新しい配列
// [使用例]
//   Result := Matrix.SliceDimIndexesCore(2, [1, 3, 5]);           // 1,3,5列目を抽出
//   Result := Matrix.SliceDimIndexesCore(2, [1, 2, 3], Insert, 2); // 2列目からInsertを挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>;
var
  dmy: TFlexArray<T>;
begin
  dmy.FTotalSize := -1;  // マーカー値（抽出専用モード）
  SliceDimIndexesCore(Dim, Indexes, dmy, 0);
end;
function TFlexArray<T>.SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>;
  const Another: TFlexArray<T>; Index: Integer): TFlexArray<T>;
var
  i, d, d1, d2: Integer;
  NewRanges: TFlexRanges;
  ResultCoords: TCoords;
  DimIdx: Integer;
  bak: Integer;
  AnotherLow, AnotherHigh: Integer;
  SelfIndexes, AnotherIndexes: TArray<Integer>;
begin
  // 1-based to 0-based
  DimIdx := Dim - 1;

  // Self用インデックス配列（既存のIndexes）
  SelfIndexes := Copy(Indexes);

  // Another用インデックス配列を生成
  if (Another.FTotalSize > 0) then
  begin
    SetLength(AnotherIndexes, Another.Len(Dim));
    for i := 0 to system.High(AnotherIndexes) do
      AnotherIndexes[i] := Index + i;
  end;
  
  // NewRangesの計算
  SetLength(NewRanges, DimensionCount);
  for d := 0 to DimensionCount - 1 do
  begin
    if d = DimIdx then
    begin
      if (Another.FTotalSize > 0) then
        // 結果の次元サイズ = Indexesの数 + Anotherのサイズ
        NewRanges[d] := [Self.FDims[d].Low, Self.FDims[d].Low + Length(Indexes) + Another.Len(Dim) - 1]
      else
        // 抽出する次元はIndexesの範囲に合わせる
        NewRanges[d] := [Self.FDims[d].Low, Self.FDims[d].Low + Length(Indexes) - 1];
    end
    else
      // 他の次元は元の配列の範囲を維持
      NewRanges[d] := [FDims[d].Low, FDims[d].High];
  end;

  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  Result.InitializeCoords(ResultCoords);

  d1 := -1;
  d2 := -1;
  
  // Anotherの範囲を計算
  if (Another.FTotalSize > 0) then
  begin
    AnotherLow := Index;
    AnotherHigh := Index + Another.Len(Dim) - 1;
  end;

  for i := 0 to Result.FTotalSize - 1 do
  begin
    bak := ResultCoords[DimIdx];
    
    // Anotherの範囲内か判定
    if (Another.FTotalSize > 0) and (ResultCoords[DimIdx] >= AnotherLow) and (ResultCoords[DimIdx] <= AnotherHigh) then
    begin
      // Anotherの範囲内
      Inc(d2);
      ResultCoords[DimIdx] := AnotherIndexes[d2];
      Result.Elements[i] := Another.Elements[Another.GetOffset(ResultCoords)];
    end
    else
    begin
      // Selfの範囲内
      Inc(d1);
      ResultCoords[DimIdx] := SelfIndexes[d1];
      Result.Elements[i] := Self.Elements[Self.GetOffset(ResultCoords)];
    end;
    
    ResultCoords[DimIdx] := bak;
    Result.IncCoords(ResultCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] Map用コールバック関数
//        連番を生成する
// [引数] Value: 現在値（無視）, Coords: 座標配列
// [戻値] 座標ベースの連番
// [使用例] FlexArray.Map(SequentialNumber) → [1, 2, 3, ...]
//////////////////////////////////////////////////////////////////////////////////////
function SequentialNumber(const Value: Integer; const Coords: TCoords): Integer;
begin
  Result := Coords[0];
end;

end.
