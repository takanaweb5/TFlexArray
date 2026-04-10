unit FlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math,
  System.Rtti,    // TValue のため
  System.TypInfo, // tkString などの型判定（TValue.Kind）のため
  System.Generics.Defaults; // IEqualityComparerのため

type

  TFlexRange = TArray<Integer>;  // [Low, High] のペア
  TFlexRangeHelper = record helper for TFlexRange
    function Low:  Integer; inline;
    function High: Integer; inline;
    function Len:  Integer; inline;
  end;
  TFlexRanges = TArray<TFlexRange>;  // [[Low1, High1], [Low2, High2], ...]

  TCoords = array of Integer;  // 座標配列 [x, y, z, ...]
  TCoordsHelper = record helper for TCoords
  public
    class function FromArray(const Coords: array of Integer): TCoords; static;
  end;

  TFlexDimension = record
    Low, High, Stride: Integer;
    RealIndex: Integer;
    function Len: Integer; inline;
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
    FTotalSize: Integer;
    FIndex: Integer;
    function GetCurrent: T;
  public
    constructor Create(const AData: TArray<T>; Size: Integer);
    property Current: T read GetCurrent;
    function MoveNext: Boolean;
  end;


  // Map用コールバック関数サンプル(連番作成)
  function SequentialNumber(const Value: Integer; const Coords: TCoords): Integer;

type
  TFlexArray<T> = record
  type
    TCoordsIterator = class
    private
      FData: Pointer;
      FCoords: TCoords;
      function GetCurrent: TCoords;
    public
      constructor Create(const Parent: Pointer);
      function MoveNext: Boolean;
      property Current: TCoords read GetCurrent;
      function GetEnumerator: TCoordsIterator;
    end;

    // 非破壊的Map用コールバック
    TMappedFunc<T, TResult> = reference to function(const Value: T; const Coords: TCoords): TResult;
    // 破壊的Map用コールバック
    TMapFunc<T> = reference to function(const Value: T; const Coords: TCoords): T;
    // Filter用コールバック
    TFilterFunc<T> = reference to function(const Value: T; const Coords: TCoords): Boolean;
  private
    FData: TArray<T>;
    FDims: TFlexDimensions;  // 次元情報
    FTotalSize: Integer;
    FIsView: Boolean;
    FIsLogicalTransposed: Boolean;

    function GetValue(const Coords: array of Integer): T; overload;
    procedure SetValue(const Coords: array of Integer; const Value: T); overload;
    function GetValue(const Coords: TCoords): T;  overload;
    procedure SetValue(const Coords: TCoords; const Value: T);  overload;
    function GetElement(Index: Integer): T; inline;
    procedure SetElement(Index: Integer; const Value: T); inline;
    function GetDimensionCount: Integer; inline;
    procedure ValidateTransposeDimensions(const NewDims: array of Integer);
    function GetRanges: TFlexRanges;
    function LogicalIndexToRealIndex(Index: Integer): Integer;
    function RealIndexToLogicalIndex(Index: Integer): Integer;
    function ValueToStr(const V: T): string;
    procedure InitializeDimensions(const Ranges: TFlexRanges);
    procedure CheckDimension(ExpectedDim: Integer);
    procedure CheckViewMode;
    function GetCompatibleBaseIndex(const Another: TFlexArray<T>): Integer;
    function RangesStringToRanges(const RangeStr: string): TFlexRanges;
    function ShapesToRanges(const Shapes: array of Integer; BaseIndex: Integer): TFlexRanges;
    function TransposeCore(const NewDims: array of Integer): TFlexArray<T>;
    function SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>; overload;
    function SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>; const Another: TFlexArray<T>; Index: Integer): TFlexArray<T>; overload;
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
    function Len(Dim: Integer): Integer;

    function GetCoords(LinearIndex: Integer): TCoords;
    function GetOffset(const Coords: array of Integer): Integer;

    property ItemAt[const Coords: TCoords]: T read GetValue write SetValue;
    property Items[const Coords: array of Integer]: T read GetValue write SetValue; default;
    property Elements[Index: Integer]: T read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;
    property TotalSize: Integer read FTotalSize;

    procedure InitializeCoords(var Coords: TCoords);
    function IncCoords(var Coords: TCoords): Boolean;

    procedure Reshape(const Shapes: array of Integer; BaseIndex: Integer);
    procedure ReshapeVector(BaseIndex: Integer); // 1D
    procedure ReshapeRange(const Range: TFlexRange); overload; // 1D
    procedure ReshapeRange(const Ranges: TFlexRanges); overload; // nD
    procedure ReshapeRange(const RangeStr: string); overload;
    procedure NormalizeToBaseIndex(BaseIndex: Integer);

    function ToVector(): TArray<T>;
    function ToString(): string;
    function ToRangesString(): string;

    procedure PromoteDimension(TargetDim: Integer);
    procedure DemoteDimension(TargetDim: Integer);

    function SliceDim(Dim: Integer; Index: Integer): TFlexArray<T>; overload;  // nD
    function SliceDimRange(Dim: Integer; const Range: TFlexRange): TFlexArray<T>; overload;  // nD
    function SliceRow(RowIndex: Integer): TFlexArray<T>;  // 2D
    function SliceCol(ColIndex: Integer): TFlexArray<T>;  // 2D
    function SliceRows(const RowIndexes: TArray<Integer>): TFlexArray<T>;  // 2D
    function SliceCols(const ColIndexes: TArray<Integer>): TFlexArray<T>;  // 2D
    function SliceRowRange(const Range: TFlexRange): TFlexArray<T>;  // 2D
    function SliceColRange(const Range: TFlexRange): TFlexArray<T>;  // 2D
    function SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>; overload;
    function SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>; BaseIndex: Integer): TFlexArray<T>; overload;

    // 2D配列の行・列挿入
    function InsertRow(RowIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>; overload;
    function InsertCol(ColIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>; overload;
    function InsertRow(RowIndex: Integer; const Items: TArray<T>): TFlexArray<T>; overload;
    function InsertCol(ColIndex: Integer; const Items: TArray<T>): TFlexArray<T>; overload;
    function InsertRows(RowIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
    function InsertCols(ColIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>;

    // 2D配列の行・列削除
    function DeleteRow(RowIndex: Integer): TFlexArray<T>;
    function DeleteCol(ColIndex: Integer): TFlexArray<T>;
    function DeleteRowRange(const Range: TFlexRange): TFlexArray<T>;
    function DeleteColRange(const Range: TFlexRange): TFlexArray<T>;

    function Transpose(Dim1, Dim2: Integer): TFlexArray<T>; overload; // nD
    function Transpose(const NewDims: array of Integer): TFlexArray<T>; overload; // nD
    function Transpose(): TFlexArray<T>; overload; // 2D
    procedure LogicalTranspose(const NewDims: array of Integer);
    procedure ResetTranspose;
    property IsLogicalTransposed: Boolean read FIsLogicalTransposed;

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
    function Mapped<TResult>(const AFunc: TMappedFunc<T, TResult>): TFlexArray<TResult>; overload;

    function Filter(const AFunc: TFilterFunc<T>): TArray<T>; overload;

    // in 演算子のオーバーロード
    class operator In(const Value: T; const FlexArray: TFlexArray<T>): Boolean;

    // Contains メソッド - 指定値が含まれるかチェック（関数版）
    function Contains(const Value: T): Boolean;
    function IndexOfElements(const Value: T): Integer;
    function IndexOfCoords(const Value: T): TCoords;

    // 座標イテレータ - for Coords in FlexArray.CoordsIterator do
    function CoordsIterator: TCoordsIterator;
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

{ TCoordsHelper }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] array of Integer から TCoords への変換
// [引数] Coords: Integer配列
// [戻値] TCoords型の座標配列
// [使用例] Coords := TCoords.FromArray([1, 2, 3]);
//////////////////////////////////////////////////////////////////////////////////////
class function TCoordsHelper.FromArray(const Coords: array of Integer): TCoords;
var
  i: Integer;
begin
  SetLength(Result, Length(Coords));
  for i := 0 to System.High(Coords) do
    Result[i] := Coords[i];
end;

{ TFlexDimension }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 対象次元の配列サイズを返す
// [引数] なし
// [戻値] 配列サイズ
//////////////////////////////////////////////////////////////////////////////////////
function TFlexDimension.Len: Integer;
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
  Result := Self[Self[Index - 1].RealIndex];  // 1ベース→0ベース変換 & 論理転置
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の情報を設定（1-based）
// [引数] 次元番号（1-based）, 次元情報
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexDimensionsHelper.SetDimension(Index: Integer; const Value: TFlexDimension);
begin
  Self[Self[Index - 1].RealIndex] := Value;  // 1ベース→0ベース変換 & 論理転置
end;

{ TFlexArrayEnumerator<T> }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を初期化
// [引数] データの先頭ポインタ, 全要素数
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArrayEnumerator<T>.Create(const AData: TArray<T>; Size: Integer);
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


{ TCoordsIterator }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標列挙子を初期化
// [引数] 親配列のポインタ
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.TCoordsIterator.Create(const Parent: Pointer);
begin
  inherited Create;
  FData := Parent;
  TFlexArray<T>(FData^).InitializeCoords(FCoords);
end;

/////////////////////////////////////////////////////////////////////////////////////
// [概要] 現在の座標を取得
// [戻値] 現在の座標（TCoordsのコピー）
//////////////////////////////////////////////////////////////////////////////////////
function  TFlexArray<T>.TCoordsIterator.GetCurrent: TCoords;
begin
  Result := Copy(FCoords);  // コピーを返す
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次の座標に移動
// [戻値] 次の座標が存在する場合はTrue、終了時はFalse
//////////////////////////////////////////////////////////////////////////////////////
function  TFlexArray<T>.TCoordsIterator.MoveNext: Boolean;
begin
  Result := not TFlexArray<T>(FData^).IncCoords(FCoords);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 自身を列挙子として返す（for..in ループ用）
// [戻値] 自身のインスタンス
// [使用例] for Coords in FlexArray.CoordsIterator do ...
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TCoordsIterator.GetEnumerator: TFlexArray<T>.TCoordsIterator;
begin
  Result := Self;
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
  CurrentStride: Integer;
begin
  SetLength(FDims, System.Length(Ranges));  // 完全0ベース化
  CurrentStride := 1;

  // 後ろの次元から歩幅を計算することで多次元に対応
  for i := System.High(Ranges) downto 0 do
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
    FDims[i].RealIndex := i;  // RealIndexを自然順序で初期化

    // 全要素数を累積計算
    CurrentStride := CurrentStride * Ranges[i].Len;
  end;

  FTotalSize := CurrentStride;
  FIsLogicalTransposed := False;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 汎用・多次元コンストラクタ
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.Create([3, 4], 1)  // 1始まりの3x4行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.Create(const Shapes: array of Integer; BaseIndex: Integer);
begin
  InitializeDimensions(ShapesToRanges(Shapes, BaseIndex));
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
  FDims := Copy(Src.FDims);
  FTotalSize := Src.FTotalSize;
  FData := Copy(Src.FData);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 動的一次元配列からFlexArrayを生成する
// [引数] 元の動的配列, 開始インデックス(省略時:0)
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromArray(arr, 1)
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromArray(const Src: TArray<T>; BaseIndex: Integer = 0);
begin
  InitializeDimensions([[BaseIndex, BaseIndex + System.Length(Src) - 1]]);
  FData := Copy(Src);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 参照生成コンストラクタ
// [引数] 元の動的配列, 開始インデックス(省略時:0)
// [戻値] なし
// [備考] CreateFromArrayと異なり、変更は元の配列に反映される
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.ViewFromArray(const Src: TArray<T>; BaseIndex: Integer = 0);
begin
  InitializeDimensions([[BaseIndex, BaseIndex + System.Length(Src) - 1]]);
  FData := Src; // データを参照して同一化
  FIsView := True;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の形状を変更し、データを保持したまま次元構造を再定義
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] Matrix.Reshape([3, 2], 1)  // 1始まりの3x2行列に再定義
// [備考] 変更前後の全要素数が一致する必要あり
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Reshape(const Shapes: array of Integer; BaseIndex: Integer);
begin
  ReshapeRange(ShapesToRanges(Shapes, BaseIndex));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] ベクトル形状に再定義（1次元専用）
// [引数] 開始インデックス
// [戻値] なし
// [使用例] Vector.ReshapeVector(1)  // 1始まりのベクトルに再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeVector(BaseIndex: Integer);
begin
  ReshapeRange([[BaseIndex, BaseIndex + FTotalSize - 1]]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元範囲指定による再定義
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] Vector.ReshapeRange([-5, 5])  // -5から5までの範囲に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const Range: TFlexRange);
begin
  ReshapeRange([Range]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元範囲指定による再定義
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] Tensor.ReshapeRange([[1, 3], [1, 2]])  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const Ranges: TFlexRanges);
var
  oldTotalSize: Integer;
begin
  oldTotalSize := Self.FTotalSize;
  InitializeDimensions(Ranges);

  // サイズのチェック
  if oldTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'Reshape: 要素数が一致しません。現在=%d, 新規=%d', [oldTotalSize, FTotalSize]));
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
  for i := 0 to system.High(Shapes) do
    Shapes[i] := Self.FDims.Items[i + 1].Len; // 論理次元アクセス（1-base）

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
  Result := Self.FDims.Items[1].Low;  // 論理1次元のLow値

  for i := 1 to Self.DimensionCount do
  begin
    if Self.FDims.Items[i].Low <> Result then
      raise Exception.Create('GetCompatibleBaseIndex: 各配列のすべての次元で同じベースインデックスを使用する必要があります。混合ベースは未対応です。');
  end;

  for i := 1 to Another.DimensionCount do
  begin
    if Another.FDims.Items[i].Low <> Result then
      raise Exception.CreateFmt('GetCompatibleBaseIndex: 異なるベースインデックスの配列は結合できません。Self=%d, Another=%d', [Result, Another.FDims.Items[i].Low]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスから多次元座標への変換
// [引数] 線形インデックス
// [戻値] 各次元の座標配列（GetOffsetの逆の変換を行う）
// [例] [[1, 3], [1, 2]] のとき GetCoords(0)=[1,1], GetCoords(1)=[1,2], GetCoords(2)=[2,1]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetCoords(LinearIndex: Integer): TCoords;
var
  i: Integer;
  TempIndex: Integer;
  DimIdx: Integer;
begin
  SetLength(Result, Self.DimensionCount);
  TempIndex := LinearIndex;

  // 末尾の次元から順に割っていく（GetOffsetの逆工程）
  for i := system.Length(Result) - 1 downto 0 do
  begin
    DimIdx := i + 1;  // 論理次元インデックス
    Result[i] := (TempIndex mod FDims.Items[DimIdx].Len) + FDims.Items[DimIdx].Low; // 論理次元アクセス
    TempIndex := TempIndex div FDims.Items[DimIdx].Len;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元座標から線形インデックスへの変換
// [引数] 各次元の座標配列
// [戻値] 線形インデックス（範囲外の場合は例外）
// [例] [[1, 3], [1, 2]] のとき GetOffset([1,1])=0, GetOffset([1,2])=1, GetOffset([2,1])=2
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetOffset(const Coords: array of Integer): Integer;
var
  i: Integer;
  DimIdx: Integer;
begin
  if System.Length(Coords) <> Self.DimensionCount then
    raise Exception.CreateFmt('GetOffset: 座標数が次元数と一致しません。Coords=%d, Dims=%d', [System.Length(Coords), Self.DimensionCount]);

  Result := 0;
  for i := 0 to Self.DimensionCount - 1 do
  begin
    DimIdx := i + 1;  // 論理次元インデックス
    if (FDims.Items[DimIdx].Low <= Coords[i]) and (Coords[i] <= FDims.Items[DimIdx].High) then
      Result := Result + (Integer(Coords[i]) - FDims.Items[DimIdx].Low) * FDims.Items[DimIdx].Stride
    else
      raise Exception.CreateFmt('GetOffset: 範囲外です。Dim=%d, Value=%d, Range=%d..%d', [DimIdx, Coords[i], FDims.Items[DimIdx].Low, FDims.Items[DimIdx].High]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標の値を取得（オーバーロード）
// [引数] Coords: 各次元の座標配列（array of Integer または TCoords）
// [戻値] 座標に対応する値（範囲外の場合は例外）
// [備考] TCoordsは動的配列変数用
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetValue(const Coords: array of Integer): T;
begin
  Result := FData[GetOffset(Coords)];
end;
function TFlexArray<T>.GetValue(const Coords: TCoords): T;
begin
  Result := FData[GetOffset(Coords)];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標に値を設定（オーバーロード）
// [引数] Coords: 各次元の座標配列（array of Integer または TCoords）, Value: 設定する値
// [戻値] なし
// [備考] TCoordsは動的配列変数用
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetValue(const Coords: array of Integer; const Value: T);
begin
  FData[GetOffset(Coords)] := Value;
end;
procedure TFlexArray<T>.SetValue(const Coords: TCoords; const Value: T);
begin
  FData[GetOffset(Coords)] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスで要素を取得
// [引数] 0-based線形インデックス
// [戻値] 指定位置の要素（範囲外の場合は例外）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetElement(Index: Integer): T;
begin
  if IsLogicalTransposed then
    Result := FData[LogicalIndexToRealIndex(Index)]
  else
    Result := FData[Index];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素を設定（1次元インデックス）
// [引数] インデックス, 値
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetElement(Index: Integer; const Value: T);
begin
  if IsLogicalTransposed then
    FData[LogicalIndexToRealIndex(Index)] := Value
  else
    FData[Index] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 論理インデックスを物理インデックスに変換
// [引数] 論理インデックス
// [戻値] 物理インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.LogicalIndexToRealIndex(Index: Integer): Integer;
var
  Coords: TCoords;
  bak: TFlexDimensions;
begin
  // 論理的な座標を取得
  Coords := GetCoords(Index);

  // 論理座標を、転置なしの状態（物理メモリ配置）のインデックスに変換
  bak := Copy(FDims);
  try
    ResetTranspose;
    Result := GetOffset(Coords);
  finally
    FDims := bak;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 物理インデックスを論理インデックスに変換
// [引数] 物理インデックス
// [戻値] 論理インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.RealIndexToLogicalIndex(Index: Integer): Integer;
var
  Coords: TCoords;
  bak: TFlexDimensions;
begin
  // 物理的な座標を取得（転置なしの状態）
  bak := Copy(FDims);
  try
    ResetTranspose;
    Coords := GetCoords(Index);
  finally
    FDims := bak;
  end;
  
  // 物理座標を、論理転置状態のインデックスに変換
  Result := GetOffset(Coords);
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
  SetLength(Rows, FDims.Items[1].Len);  // 論理1次元のサイズ
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
var
  i: Integer;
  Coords: TCoords;
begin
  if IsLogicalTransposed then
  begin
    // 論理転置されている場合は正しい順序で抽出
    SetLength(Result, FTotalSize);
    SetLength(Coords, DimensionCount);
    InitializeCoords(Coords);

    for i := 0 to FTotalSize - 1 do
    begin
      Result[i] := Self.ItemAt[Coords];
      IncCoords(Coords);
    end;
  end
  else
  begin
    Result := Copy(FData);
  end;
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
// [概要] 形状配列を範囲配列に変換
// [引数] 形状配列, 開始インデックス
// [戻値] 範囲配列
// [使用例] ShapesToRanges([3, 4], 1) → [[1, 3], [1, 4]]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ShapesToRanges(const Shapes: array of Integer; BaseIndex: Integer): TFlexRanges;
var
  i: Integer;
  L, H: Integer;
begin
  SetLength(Result, System.Length(Shapes));
  for i := 0 to System.High(Shapes) do
  begin
    L := BaseIndex;
    H := BaseIndex + Shapes[i] - 1;
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
  Ranges := Self.GetRanges;
  SetLength(Parts, System.Length(Ranges));
  for i := 0 to System.High(Ranges) do
    Parts[i] := Format('%d..%d', [Ranges[i].Low, Ranges[i].High]);
  Result := '[' + String.Join(', ', Parts) + ']';
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の配列サイズを返す
// [引数] 対象次元
// [戻値] 配列サイズ
// [備考] 利用者向けAPI（封印中）です。内部実装では FDims.Items[Dim].Len を使用してください。
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Len(Dim: Integer): Integer;
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
  Result := FDims.Items[1].Low;  // 論理1次元アクセスに統一
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
  Result := FDims.Items[1].High;  // 論理1次元アクセスに統一
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最小インデックスを取得
// [引数] 対象次元
// [戻値] 最小インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Low(Dim: Integer): Integer;
begin
  Result := FDims.Items[Dim].Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最大インデックスを取得
// [引数] 対象次元
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
  for i := 0 to system.Length(Result) - 1 do
    Result[i] := [FDims.Items[i + 1].Low, FDims.Items[i + 1].High]; // 論理次元アクセス
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を取得
// [引数] なし
// [戻値] 列挙子オブジェクト
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetEnumerator: TFlexArrayEnumerator<T>;
begin
  Result := TFlexArrayEnumerator<T>.Create(Self.ToVector, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標列挙子を取得
// [引数] なし
// [戻値] TCoordsIterator オブジェクト
// [使用例] for Coords in FlexArray.CoordsIterator do ...
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.CoordsIterator: TFlexArray<T>.TCoordsIterator;
begin
  Result := TCoordsIterator.Create(@Self);
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
  for i := 0 to system.Length(Coords) - 1 do
    Coords[i] := Self.FDims.Items[i + 1].Low;  // 論理次元アクセス
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標をインクリメント
// [引数] Coords: 現在の座標配列
// [戻値] 1周した場合にtrue、それ以外はfalse
// [備考] 2次元配列 [1..3, 1..2] の場合:
//        [1,1] → [1,2] → [2,1] → [2,2] → [3,1] → [3,2] → [1,1](true)
// [使用例] repeat-untilループでの全要素走査に最適
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.IncCoords(var Coords: TCoords): Boolean;
var
  d: Integer;
  DimIdx: Integer;
begin
  // 一番右側の次元（最小単位）から順にチェック
  for d := system.High(Coords) downto 0 do
  begin
    Inc(Coords[d]);
    DimIdx := d + 1;  // 論理次元インデックス

    // 上限を超えていないなら終了
    if Coords[d] <= Self.FDims.Items[DimIdx].High then
    begin
      Result := False;  // 1周していない
      Exit;
    end;

    // 上限を超えたので、現在の次元を最小値(Low)にリセットし、
    // ループを継続して一つ左の次元（上位桁）を Inc する
    Coords[d] := Self.FDims.Items[DimIdx].Low;
  end;
  
  // すべての次元がリセットされた＝1周した
  Result := True;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元をスライスして取得
// [引数] 対象次元, 取得インデックス
// [戻値] スライス配列（元の次元数より1次元少ない配列を生成）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDim(Dim: Integer; Index: Integer): TFlexArray<T>;
begin
  if Self.DimensionCount = 1 then
    raise Exception.Create('1次元配列にはSliceDim(Dim, Index)は使用できません。');

  Result := SliceDimIndexes(Dim, [Index]);

  // 次元を削除
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
// [概要] 指定された複数行を抽出
// [引数] RowIndexes: 抽出する行インデックスの配列
// [戻値] 抽出後の新しい配列
// [使用例] Matrix.SliceRows([1, 3, 5])  // 1,3,5行目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceRows(const RowIndexes: TArray<Integer>): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := SliceDimIndexes(1, RowIndexes);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定された複数列を抽出
// [引数] ColIndexes: 抽出する列インデックスの配列
// [戻値] 抽出後の新しい配列
// [使用例] Matrix.SliceCols([2, 4, 6])  // 2,4,6列目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceCols(const ColIndexes: TArray<Integer>): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := SliceDimIndexes(2, ColIndexes);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定範囲の複数行を抽出
// [引数] Range: 抽出範囲 [Low, High]
// [戻値] 抽出後の新しい配列
// [使用例] Matrix.SliceRowRange([2, 5])  // 2〜5行目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceRowRange(const Range: TFlexRange): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := SliceDimRange(1, Range);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定範囲の複数列を抽出
// [引数] Range: 抽出範囲 [Low, High]
// [戻値] 抽出後の新しい配列
// [使用例] Matrix.SliceColRange([1, 3])  // 1〜3列目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceColRange(const Range: TFlexRange): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := SliceDimRange(2, Range);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定位置に行を挿入
// [引数] RowIndex: 挿入位置, Another: 挿入する行配列
// [戻値] 挿入後の新しい配列
// [使用例] Matrix.InsertRow(2, NewRow)  // 2行目に挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertRow(RowIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
var
  AnotherReady: TFlexArray<T>;
begin
  CheckDimension(2);
  Another.CheckDimension(1);
  if Another.FDims.Items[1].Len <> Self.FDims.Items[2].Len then
    raise Exception.Create('InsertRow: 列数が一致しません');

  // constパラメータをローカル変数にコピー
  AnotherReady := Another;

  // 1Dを2Dに昇格（次元1にサイズ1の次元を挿入）
  AnotherReady.PromoteDimension(1);

  // BaseIndexを合わせる
  AnotherReady.NormalizeToBaseIndex(Self.Low(1));

  Result := InsertDim(1, RowIndex, AnotherReady);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定位置に列を挿入
// [引数] ColIndex: 挿入位置, Another: 挿入する列配列
// [戻値] 挿入後の新しい配列
// [使用例] Matrix.InsertCol(3, NewCol)  // 3列目に挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertCol(ColIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
var
  AnotherReady: TFlexArray<T>;
begin
  CheckDimension(2);
  Another.CheckDimension(1);
  if Another.FDims.Items[1].Len <> Self.FDims.Items[1].Len then
    raise Exception.Create('InsertCol: 行数が一致しません');

  // constパラメータをローカル変数にコピー
  AnotherReady := Another;

  // 1Dを2Dに昇格（次元2にサイズ1の次元を挿入）
  AnotherReady.PromoteDimension(2);

  // BaseIndexを合わせる
  AnotherReady.NormalizeToBaseIndex(Self.Low(1));

  Result := InsertDim(2, ColIndex, AnotherReady);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定位置に1D配列を行として挿入
// [引数] RowIndex: 挿入位置, Items: 挿入する1D配列
// [戻値] 挿入後の新しい配列
// [使用例] Matrix.InsertRow(2, [1,2,3,4])  // 2行目に1D配列を挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertRow(RowIndex: Integer; const Items: TArray<T>): TFlexArray<T>;
var
  Row2D: TFlexArray<T>;
begin
  CheckDimension(2);
  // 1D配列を2D配列に昇格
  Row2D := TFlexArray<T>.CreateFromArray(Items);
  Row2D.Reshape([1, Length(Items)], 1);
  Result := InsertDim(1, RowIndex, Row2D);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定位置に1D配列を列として挿入
// [引数] ColIndex: 挿入位置, Items: 挿入する1D配列
// [戻値] 挿入後の新しい配列
// [使用例] Matrix.InsertCol(3, [1,2,3])  // 3列目に1D配列を挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertCol(ColIndex: Integer; const Items: TArray<T>): TFlexArray<T>;
var
  Col2D: TFlexArray<T>;
begin
  CheckDimension(2);
  // 1D配列を2D配列に昇格
  Col2D := TFlexArray<T>.CreateFromArray(Items);
  Col2D.Reshape([Length(Items), 1], 1);
  Result := InsertDim(2, ColIndex, Col2D);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定位置に複数行を挿入
// [引数] RowIndex: 挿入位置, Another: 挿入する行配列
// [戻値] 挿入後の新しい配列
// [使用例] Matrix.InsertRows(2, NewRows)  // 2行目から複数行を挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertRows(RowIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := InsertDim(1, RowIndex, Another);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定位置に複数列を挿入
// [引数] ColIndex: 挿入位置, Another: 挿入する列配列
// [戻値] 挿入後の新しい配列
// [使用例] Matrix.InsertCols(3, NewCols)  // 3列目から複数列を挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertCols(ColIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := InsertDim(2, ColIndex, Another);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定行を削除
// [引数] RowIndex: 削除する行インデックス
// [戻値] 削除後の新しい配列
// [使用例] Matrix.DeleteRow(2)  // 2行目を削除
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteRow(RowIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := DeleteDim(1, [RowIndex, RowIndex]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定列を削除
// [引数] ColIndex: 削除する列インデックス
// [戻値] 削除後の新しい配列
// [使用例] Matrix.DeleteCol(3)  // 3列目を削除
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteCol(ColIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := DeleteDim(2, [ColIndex, ColIndex]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定範囲の複数行を削除
// [引数] Range: 削除範囲 [Low, High]
// [戻値] 削除後の新しい配列
// [使用例] Matrix.DeleteRowRange([2, 5])  // 2〜5行目を削除
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteRowRange(const Range: TFlexRange): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := DeleteDim(1, Range);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定範囲の複数列を削除
// [引数] Range: 削除範囲 [Low, High]
// [戻値] 削除後の新しい配列
// [使用例] Matrix.DeleteColRange([1, 3])  // 1〜3列目を削除
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteColRange(const Range: TFlexRange): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := DeleteDim(2, Range);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2つの指定次元を入れ替える
// [引数] Dim1: , Dim2: 入れ替える次元番号(1-based)
// [戻値] 次元を入れ替えた配列
// [使用例] Array3D.Transpose(1, 3)  // 次元1と3を入れ替える
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Transpose(Dim1, Dim2: Integer): TFlexArray<T>;
var
  NewDims: array of Integer;
  i: Integer;
begin
  // パラメータ検証
  if (Dim1 < 1) or (Dim1 > DimensionCount) then
    raise Exception.CreateFmt('Transpose: 次元指定 %d が範囲外です。', [Dim1]);
  if (Dim2 < 1) or (Dim2 > DimensionCount) then
    raise Exception.CreateFmt('Transpose: 次元指定 %d が範囲外です。', [Dim2]);
  if Dim1 = Dim2 then
    raise Exception.Create('Transpose: 同じ次元は入れ替えできません。');

  SetLength(NewDims, DimensionCount);
  for i := 0 to System.Length(NewDims) - 1 do
    NewDims[i] := i + 1; // デフォルトは [1, 2, 3, ...]

  // 指定された2つの次元を入れ替え
  NewDims[Dim1 - 1] := Dim2;
  NewDims[Dim2 - 1] := Dim1;

  Result := TransposeCore(NewDims); // 次元1と3を入れ替える時、[3,2,1]
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元を入れ替え
// [引数] 新しい次元の順序 指定例：[1, 2, 3] -> [3, 1, 2]
// [戻値] 転置後の配列
// [備考] NewDims は「1..次元数」の並べ替え（重複なし）を、次元数分指定します。
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Transpose(const NewDims: array of Integer): TFlexArray<T>;
begin
  ValidateTransposeDimensions(NewDims);
  Result := TransposeCore(NewDims);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用の転置
// [引数] なし
// [戻値] 行列を入れ替えた配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Transpose: TFlexArray<T>;
begin
  CheckDimension(2);
  Result := TransposeCore([2, 1]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元を入れ替え
// [引数] 新しい次元の順序 指定例：[1, 2, 3] -> [3, 1, 2]
// [戻値] 転置後の配列
// [備考] パラメータ検証は呼び出し元で実行済みであること
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TransposeCore(const NewDims: array of Integer): TFlexArray<T>;
var
  i: Integer;
  SelfCoords: TCoords;
  bak: TFlexDimensions;
begin
  bak := Copy(FDims);
  try
    if IsLogicalTransposed then ResetTranspose;

    // 論理転置を適用
    LogicalTranspose(NewDims);
    // 論理転置状態を利用し、新しい配列を作成
    Result := TFlexArray<T>.CreateFromRange(GetRanges);

    // 論理転置状態を利用し、1対1でコピー
    Result.InitializeCoords(SelfCoords);
    for i := 0 to Result.FTotalSize - 1 do
    begin
      Result.FData[i] := Self.ItemAt[SelfCoords];
      Self.IncCoords(SelfCoords);
    end;
  finally
    FDims := bak;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 論理転置を実行する（データ移動なし）
// [引数] NewDims: 新しい次元順序 [論理1次元→物理X次元, 論理2次元→物理Y次元, ...]
// [戻値] なし
// [使用例] LogicalTranspose([3, 1, 2])  // 論理1→物理3, 論理2→物理1, 論理3→物理2
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.LogicalTranspose(const NewDims: array of Integer);
var
  i: Integer;
begin
  ValidateTransposeDimensions(NewDims);

  if IsLogicalTransposed then ResetTranspose;

  FIsLogicalTransposed := False;

  // RealIndexを再設定（論理次元i → 物理次元NewDims[i]）
  for i := 0 to DimensionCount - 1 do
  begin
    FDims[i].RealIndex := NewDims[i] - 1;  // 1-based→0-based

    if NewDims[i] - 1 <> i then
      FIsLogicalTransposed := True;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 論理転置をリセットして自然順序に戻す
// [引数] なし
// [戻値] なし
// [備考] 論理転置されていない場合は例外
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ResetTranspose;
var
  i: Integer;
begin
  // RealIndexを自然順序に直接設定
  for i := 0 to DimensionCount - 1 do
    FDims[i].RealIndex := i;

  FIsLogicalTransposed := False;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 転置用の次元指定を検証する
// [引数] NewDims: 検証する次元配列
// [戻値] なし
// [備考] TransposeとLogicalTransposeで共通使用
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ValidateTransposeDimensions(const NewDims: array of Integer);
var
  i: Integer;
  DimUsed: array of Boolean;
begin
  // 整合性チェック
  if System.Length(NewDims) <> Self.DimensionCount then
    raise Exception.Create('指定された軸の数が配列の次元数と一致しません。');

  // すべての次元が使用されているかチェック
  SetLength(DimUsed, DimensionCount);
  for i := 0 to system.High(DimUsed) do
    DimUsed[i] := False;

  for i := 0 to system.High(NewDims) do
  begin
    if (NewDims[i] < 1) or (NewDims[i] > DimensionCount) then
      raise Exception.CreateFmt('次元指定 %d が範囲外です。', [NewDims[i]]);
    DimUsed[NewDims[i] - 1] := True;
  end;

  for i := 0 to system.High(DimUsed) do
    if not DimUsed[i] then
      raise Exception.CreateFmt('次元 %d が指定されていません。', [i + 1]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元にサイズ1の次元を挿入して次元数を増やす
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
  NewRanges := Self.GetRanges;

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
  if Self.Len(TargetDim) <> 1 then
    raise Exception.CreateFmt(
      'DemoteDimension: 削除する次元のサイズは1である必要があります。Dim=%d, Size=%d', 
      [TargetDim, Self.Len(TargetDim)]);

  // 現在の範囲を取得
  NewRanges := Self.GetRanges;
  
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
  Result := SelfReady.InsertDim(TargetDim, SelfReady.High(TargetDim) + 1, AnotherReady);

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
// [概要] 指定次元の指定位置に配列を挿入
// [引数] Dim: 対象次元(1-based), Index: 挿入位置, Items: 挿入する配列
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
  for i := 0 to System.Length(Indexes) - 1 do
    Indexes[i] := Self.Low(Dim) + i; // 元の配列[1..5]の全インデックスを収集[1,2,3,4,5]

  Result := SliceDimIndexesCore(Dim, Indexes, Items, Index);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の範囲を削除
// [引数] Dim: 対象次元(1-based), Range: 削除範囲[Low, High]
// [戻値] 削除後の新しい配列
// [使用例]
//   Result := Matrix.DeleteDim(2, [3, 5]); // 3〜5列目を削除
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
    Indexes[d] := i; // [1..9]のうち[3..5]を削除 → [1,2]
    Inc(d);
  end;

  // 後半部のインデックスを収集
  for i := Range.High + 1 to Self.High(Dim) do
  begin
    Indexes[d] := i; // [1..9]のうち[3..5]を削除 → [6,7,8,9]
    Inc(d);
  end;

  Result := SliceDimIndexes(Dim, Indexes);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の範囲を抽出
// [引数] Dim: 対象次元(1-based), Range: 抽出範囲[Low, High]
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
  for i := 0 to system.Length(Indexes) - 1 do
    Indexes[i] := Range.Low + i; // [2..5] → [2,3,4,5]

  Result := SliceDimIndexes(Dim, Indexes);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元のIndexの配列で指定した範囲を抽出
// [引数] Dim: 対象次元(1-based), Indexes: 抽出するIndexの配列, BaseIndex: 基準インデックス
// [戻値] 抽出後の新しい配列
// [備考] BaseIndexの省略時はselfの該当次元のbaseを使用
// [使用例]
//   Result := Matrix.SliceDimIndexes(2, [1, 3, 5]);    // 1,3,5列目を抽出
//   Result := Matrix.SliceDimIndexes(2, [1, 3, 5], 1); // 1,3,5列目を抽出
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>;
begin
  Result := SliceDimIndexes(Dim, Indexes, Self.Low(Dim));
end;
function TFlexArray<T>.SliceDimIndexes(Dim: Integer; const Indexes: TArray<Integer>; BaseIndex: Integer): TFlexArray<T>;
var
  NewRanges: TFlexRanges;
begin
  Result := SliceDimIndexesCore(Dim, Indexes);

  // BaseIndexが対象次元のBaseIndexと等しい場合、Reshapeは不要
  if BaseIndex = Result.Low(Dim) then Exit;

  // 指定次元をBaseIndexに合わせてReshape
  NewRanges := Result.GetRanges;
  NewRanges[Dim - 1] := [BaseIndex, BaseIndex + Result.Len(Dim) - 1];

  Result.ReshapeRange(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元のIndexの配列で指定した範囲を抽出または挿入
// [引数] Dim: 対象次元(1-based), Indexes: 抽出するIndexの配列,
//        Another: 挿入する配列(省略時は抽出のみ), Index: 挿入開始位置
// [戻値] 抽出後の新しい配列
// [使用例]
//   Result := Matrix.SliceDimIndexesCore(2, [1, 3, 5]);           // 1,3,5列目を抽出
//   Result := Matrix.SliceDimIndexesCore(1, [1, 2, 3], Another, 2); // 2行目からAnotherを挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>): TFlexArray<T>;
var
  dmy: TFlexArray<T>;
begin
  dmy.FTotalSize := -1;  // マーカー値（抽出専用モード）
  Result := SliceDimIndexesCore(Dim, Indexes, dmy, 0);
end;
function TFlexArray<T>.SliceDimIndexesCore(Dim: Integer; const Indexes: TArray<Integer>;
  const Another: TFlexArray<T>; Index: Integer): TFlexArray<T>;
var
  i, d: Integer;
  NewRanges: TFlexRanges;
  ResultCoords: TCoords;
  DimIdx, TargetDimBaseIdx: Integer;
  bak: Integer;
  FlexIndexes, MappedIndexes: TFlexArray<Integer>;
  IsAnotherArea: TFlexArray<Boolean>;
begin
  // 論理次元のBaseIndexを取得
  TargetDimBaseIdx := Self.FDims.Items[Dim].Low;
  // 1-based to 0-based
  DimIdx := Dim - 1;

  // NewRangesの設定
  NewRanges := Self.GetRanges;
  if Another.FTotalSize > 0 then
    // 対象の次元サイズ = Indexesのサイズ + Anotherのサイズ
    NewRanges[DimIdx] := [TargetDimBaseIdx, TargetDimBaseIdx + Length(Indexes) + Another.Len(Dim) - 1]
  else
    // 対象の次元はIndexesの範囲に合わせる
    NewRanges[DimIdx] := [TargetDimBaseIdx, TargetDimBaseIdx + Length(Indexes) - 1];

  // BaseIndexを対象次元のBaseIndexで統一する
  FlexIndexes := TFlexArray<Integer>.CreateFromArray(Indexes, TargetDimBaseIdx);
  IsAnotherArea := TFlexArray<Boolean>.CreateFromRange(NewRanges[DimIdx]); // デフォルトはFalse
  if Another.FTotalSize > 0 then
  begin
    // BaseIndexを対象次元のBaseIndexで統一する
    MappedIndexes := TFlexArray<Integer>.CreateFromRange(NewRanges[DimIdx]);
    d := TargetDimBaseIdx;

    for i := FlexIndexes.Low to Index - 1 do begin
      MappedIndexes[d] := FlexIndexes[i];
      Inc(d);
    end;

    for i := Another.Low(Dim) to Another.High(Dim) do begin
      MappedIndexes[d] := i;
      IsAnotherArea[d] := True;
      Inc(d);
    end;

    for i := Index to FlexIndexes.High do begin
      MappedIndexes[d] := FlexIndexes[i];
      Inc(d);
    end;
  end
  else
  begin
    MappedIndexes := FlexIndexes;
  end;

  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  Result.InitializeCoords(ResultCoords);

  for i := 0 to Result.FTotalSize - 1 do
  begin
    bak := ResultCoords[DimIdx];
    ResultCoords[DimIdx] := MappedIndexes[bak];

    if IsAnotherArea[bak] then
      Result.FData[i] := Another.ItemAt[ResultCoords]
    else
      Result.FData[i] := Self.ItemAt[ResultCoords];

    ResultCoords[DimIdx] := bak;
    Result.IncCoords(ResultCoords);
  end;
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
  Result := TFlexArray<TResult>.CreateFromRange(Self.GetRanges);
  Result.InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    Result.Elements[i] := AFunc(Self.Elements[i], CurrentCoords);
    Result.IncCoords(CurrentCoords);
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

{ TFlexArray<T> }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] in 演算子のオーバーロード - 指定値が配列に含まれるかチェック
// [引数] Value: 検索する値, FlexArray: 検索対象の配列
// [戻値] 値が含まれる場合は True、含まれない場合は False
// [使用例] if 20 in arr then ShowMessage('含まれています');
//////////////////////////////////////////////////////////////////////////////////////
class operator TFlexArray<T>.In(const Value: T; const FlexArray: TFlexArray<T>): Boolean;
begin
  Result := FlexArray.Contains(Value);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定値が含まれるかチェック
// [引数] Value: 検索する値
// [戻値] 値が含まれる場合は True、含まれない場合は False
// [使用例] if arr.Contains(20) then ShowMessage('含まれています');
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Contains(const Value: T): Boolean;
begin
  Result := TArray.Contains<T>(Self.FData, Value);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定値のインデックスを返す
// [引数] Value: 検索する値
// [戻値] 見つかった場合は0-basedインデックス、見つからない場合は-1
// [使用例] idx := arr.IndexOf(20);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.IndexOfElements(const Value: T): Integer;
var
  Index: Integer;
begin
  Index := TArray.IndexOf<T>(Self.FData, Value);

  if Index = -1 then Exit(-1);

  if IsLogicalTransposed then
    Result := RealIndexToLogicalIndex(Index)
  else
    Result := Index;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定値の座標を返す
// [引数] Value: 検索する値
// [戻値] 見つかった場合は座標配列、見つからない場合は空の配列
// [使用例] coords := arr.IndexOfCoords(20);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.IndexOfCoords(const Value: T): TCoords;
var
  Index: Integer;
begin
  Index := TArray.IndexOf<T>(Self.FData, Value);
  // Index := Self.IndexOfElements(Value);

  if Index >= 0 then
    Result := Self.GetCoords(Index);
end;

end.
