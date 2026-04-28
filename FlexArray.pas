unit FlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math,
  System.Rtti,    // TValue のため
  System.TypInfo, // tkString などの型判定（TValue.Kind）のため
  System.Generics.Defaults; // IEqualityComparerのため

type

  TFlexDimension = record
    Low, High, Stride: Integer;
//    RealIndex: Integer; 論理転置用（対応しないことにする）
    function Len: Integer; inline;
  end;
  TFlexDimensions = TArray<TFlexDimension>;
  TFlexDimensionsHelper = record helper for TFlexDimensions
  private
    function GetDimension(Index: Integer): TFlexDimension; inline;
  public
    property Items[Index: Integer]: TFlexDimension read GetDimension;
  end;

  TFlexRange = array of Integer;  // [Low, High] のペア
  TFlexRangeHelper = record helper for TFlexRange
    function Low:  Integer; inline;
    function High: Integer; inline;
    function Len:  Integer; inline;
    procedure Check(AllowAny: Boolean = False);
  end;
  TFlexRanges = TArray<TFlexRange>;  // [[Low1, High1], [Low2, High2], ...]
  TFlexRangesHelper = record helper for TFlexRanges
    procedure Check(const Dims: TFlexDimensions); overload;
  end;

  TSliceIndexes = array of Integer;  // スライス用インデックス配列
  TSliceIndexesHelper = record helper for TSliceIndexes
    procedure Check(const Dim: TFlexDimension);
  end;

  TCoords = array of Integer;  // 座標配列 [x, y, z, ...]
  TCoordsHelper = record helper for TCoords
  public
    class function FromArray(const Coords: array of Integer): TCoords; static;
  end;

  type
  TFlexArray<T> = record
  type

    // for in 用列挙子
    TFlexArrayEnumerator<T> = class
    private
      FArray: TArray<T>;
      FIndex: Integer;
      function GetCurrent: T;
    public
      constructor Create(const AData: TArray<T>);
      property Current: T read GetCurrent;
      function MoveNext: Boolean;
    end;

    // 座標イテレータ
    TCoordsIterator = class
    private
      FRanges: TFlexRanges;
      FCoords: TCoords;
      function GetCurrent: TCoords;
      function IncCoords(var Coords: TCoords): Boolean;
    public
      constructor Create(const Dims: TFlexDimensions; Ranges: TFlexRanges);
      function MoveNext: Boolean;
      property Current: TCoords read GetCurrent;
      function GetEnumerator: TCoordsIterator;
    end;

    // Filter用コールバック
    TFilterFunc<T> = reference to function(Value: T; Coords: TCoords): Boolean;
  
    // Binary操作用コールバック
    TOperationFunc<T> = reference to function(L, R: T): T;

    // スマートポインタを実現するためにすべての内部データを管理
    TData = class(TInterfacedObject)
      FArray: TArray<T>;
      FDims: TFlexDimensions;  // 次元情報
      FIsView: Boolean;
    end;

  private
    FData: TData;     // データ本体
    FRef: IInterface; // 寿命管理（スマートポインタ代わり）
    function Data: TData; // 内部データへのアクセサ

    function GetValue(const Coords: array of Integer): T; overload;
    procedure SetValue(const Coords: array of Integer; Value: T); overload;
    function GetValue(const Coords: TCoords): T;  overload;
    procedure SetValue(const Coords: TCoords; const Value: T);  overload;
    function GetElement(Index: Integer): T; inline;
    procedure SetElement(Index: Integer; Value: T); inline;
    function GetDimensionCount: Integer; inline;
    function GetTotalSize: Integer; inline;
    procedure ValidateTransposeDimensions(const NewDims: array of Integer);
    function GetRanges: TFlexRanges;
    function ValueToStr(V: T): string;
    function InitializeDimensions(const Ranges: TFlexRanges): Integer;
    procedure CheckDimension(ExpectedDim: Integer);
//    procedure CheckViewMode;
    function GetCompatibleBaseIndex(const Another: TFlexArray<T>): Integer;
    function RangesStringToRanges(RangeStr: string): TFlexRanges;
    function ShapesToRanges(const Shapes: array of Integer; BaseIndex: Integer): TFlexRanges;
    procedure LogicalTranspose(const NewDims: array of Integer);
    function TransposeCore(const NewDims: array of Integer): TFlexArray<T>;
    function InsertDimCore(Dim: Integer; Index: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
    function DeleteDimCore(Dim: Integer; const Range: TFlexRange): TFlexArray<T>;
    function SliceCore(const Ranges: TFlexRanges): TFlexArray<T>;
    function SliceIndexedCore(const Indexes: TArray<TSliceIndexes>; BaseIndex: Integer = 0): TFlexArray<T>;
    class function BroadcastCore(Source: TFlexArray<T>; Target: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>; static;

  public
    constructor Create(const Shapes: array of Integer; BaseIndex: Integer = 0); overload; // nD
    constructor CreateFromRange(const Range: TFlexRange); overload; // 1D
    constructor CreateFromRange(const Ranges: TFlexRanges); overload; // nD
    constructor CreateFromRange(RangeStr: string); overload;
    constructor CreateFromFlexArray(const Src: TFlexArray<T>); overload;
    constructor CreateFromArray(const Src: TArray<T>; BaseIndex: Integer = 0); overload;
    constructor CreateFromValues(const Values: array of T; BaseIndex: Integer = 0); overload;
    constructor ViewFromArray(const Src: TArray<T>; BaseIndex: Integer = 0); overload;

    function Low: Integer; overload;  // 1D
    function High: Integer; overload; // 1D
    function Low(Dim: Integer): Integer; overload; // nD
    function High(Dim: Integer): Integer; overload; // nD
    function Len(Dim: Integer): Integer;
    function IsView: Boolean;

    function GetCoords(LinearIndex: Integer): TCoords;
    function GetOffset(const Coords: array of Integer): Integer;

    procedure InitializeCoords(out Coords: TCoords);
    function IncCoords(var Coords: TCoords): Boolean;

    property ItemAt[const Coords: TCoords]: T read GetValue write SetValue;
    property Items[const Coords: array of Integer]: T read GetValue write SetValue; default;
    property Elements[Index: Integer]: T read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;
    property TotalSize: Integer read GetTotalSize;

    function Reshape(const Shapes: array of Integer; BaseIndex: Integer = 0): TFlexArray<T>;
    function ReshapeRange(const Range: TFlexRange): TFlexArray<T>; overload; // 1D
    function ReshapeRange(const Ranges: TFlexRanges): TFlexArray<T>; overload; // nD
    function ReshapeRange(RangeStr: string): TFlexArray<T>; overload;
    function Rebase(BaseIndex: Integer): TFlexArray<T>; overload;
    function Rebase(const BaseIndexes: array of Integer): TFlexArray<T>; overload;

    function ToVector(): TArray<T>;
    function ToString(): string;
    function ToRangesString(): string;

    function PromoteDimension(TargetDim: Integer): TFlexArray<T>;
    function DemoteDimension(TargetDim: Integer): TFlexArray<T>;

    function SliceDim(Dim: Integer; Index: Integer): TFlexArray<T>; overload;  // nD
    function SliceRow(RowIndex: Integer): TFlexArray<T>;  // 2D
    function SliceCol(ColIndex: Integer): TFlexArray<T>;  // 2D
    function Slice(const Ranges: TFlexRanges): TFlexArray<T>; overload;
    function SliceIndexed(const Indexes: TArray<TSliceIndexes>; BaseIndex: Integer = 0): TFlexArray<T>;

    // 2D配列の行・列挿入
    function InsertRow(RowIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>; overload; // 2D
    function InsertCol(ColIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>; overload; // 2D
    function InsertRow(RowIndex: Integer; const Items: TArray<T>): TFlexArray<T>; overload; // 2D
    function InsertCol(ColIndex: Integer; const Items: TArray<T>): TFlexArray<T>; overload; // 2D
    function InsertRows(RowIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>; // 2D
    function InsertCols(ColIndex: Integer; const Another: TFlexArray<T>): TFlexArray<T>; // 2D
    function InsertDim(Dim: Integer; Index: Integer; const Items: TFlexArray<T>): TFlexArray<T>; // nD

    // 2D配列の行・列削除
    function DeleteRow(RowIndex: Integer): TFlexArray<T>; // 2D
    function DeleteCol(ColIndex: Integer): TFlexArray<T>; // 2D
    function DeleteRowRange(const Range: TFlexRange): TFlexArray<T>; // 2D
    function DeleteColRange(const Range: TFlexRange): TFlexArray<T>;  // 2D
    function DeleteDim(Dim: Integer; const Range: TFlexRange): TFlexArray<T>; // 2D

    function Transpose(Dim1, Dim2: Integer): TFlexArray<T>; overload; // nD
    function Transpose(const NewDims: array of Integer): TFlexArray<T>; overload; // nD
    function Transpose(): TFlexArray<T>; overload; // 2D

    function ArgSort(Ascending: Boolean = True): TArray<Integer>;
    function Concat(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;  // nD
    function HStack(const Another: TFlexArray<T>): TFlexArray<T>;  // 2D
    function VStack(const Another: TFlexArray<T>): TFlexArray<T>;  // 2D
    function AppendArray(const Another: TFlexArray<T>): TFlexArray<T>; overload;  // 1D
    function AppendArray(const Another: TArray<T>): TFlexArray<T>; overload;  // 1D
    function AppendArray(Value: T): TFlexArray<T>; overload;  // 1D

    // 1D配列操作メソッド
//    function InsertArray(const StartIndex: Integer; const Items: TArray<T>): TFlexArray<T>; overload;
//    function InsertArray(const StartIndex: Integer; const Items: TFlexArray<T>): TFlexArray<T>; overload;
//    function InsertArray(const StartIndex: Integer; const Item: T): TFlexArray<T>; overload;
//
//    function DeleteArray(const Range: TFlexRange): TFlexArray<T>;
//    function SliceArray(const Range: TFlexRange): TFlexArray<T>;

    // Swiftスタイル: 非破壊的(-ed) / 破壊的(原形)
    function Fill(Value: T): TFlexArray<T>;

    function Filter(AFunc: TFilterFunc<T>): TArray<T>;

    // in 演算子のオーバーロード
    class operator In(const Value: T; const FlexArray: TFlexArray<T>): Boolean;

    // Contains メソッド - 指定値が含まれるかチェック（関数版）
    function Contains(const Value: T): Boolean;
    function IndexOfElements(const Value: T): Integer;
    function IndexOfCoords(const Value: T): TCoords;

    // 座標イテレータ - for Coords in FlexArray.CoordsIterator do
    function CoordsIterator(Ranges: TFlexRanges = nil): TCoordsIterator;
    
    // for-in ループ用列挙子
    function GetEnumerator: TFlexArrayEnumerator<T>;
    
    // ブロードキャスト関数
    function Broadcast(Value: T; AFunc: TOperationFunc<T>): TFlexArray<T>; overload;
    function Broadcast(const Source: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>; overload;
    class function Broadcast(Value: T; const Target: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>; overload; static;
    class function Broadcast(const Source: TFlexArray<T>; Value: T; AFunc: TOperationFunc<T>): TFlexArray<T>; overload; static;
    class function Broadcast(const Source: TFlexArray<T>; const Target: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>; overload; static;
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
  if Length(Self) = 1 then
    Result := Self[0]
  else
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

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangeの妥当性チェック
// [引数] AllowAny: True=[], [L], [L,H]を許可, False=[L,H]のみ許可(デフォルト)
// [戻値] なし
// [備考] 不正な場合は例外を発生
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexRangeHelper.Check(AllowAny: Boolean = False);
begin
  if AllowAny then
  begin
    if System.Length(Self) > 2 then
      raise Exception.CreateFmt('TFlexRange: 要素数が不正です。%d要素あります。', [System.Length(Self)]);
  end
  else
  begin
    if System.Length(Self) <> 2 then
      raise Exception.CreateFmt('TFlexRange: 要素数が不正です。%d要素あります。', [System.Length(Self)]);
  end;

  if System.Length(Self) = 2 then
    if Self.Low > Self.High then
      raise Exception.CreateFmt('TFlexRange: Low(%d) > High(%d) は不正です。', [Low, High]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangesの妥当性チェック（次元範囲も検証）
// [引数] Dims: 各次元のLow/High情報
// [戻値] なし
// [備考] 不正な場合は例外を発生
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexRangesHelper.Check(const Dims: TFlexDimensions);
var
  i: Integer;
  Range: TFlexRange;
  TargetDim: TFlexDimension;
begin
  if System.Length(Self) <> System.Length(Dims) then
    raise Exception.CreateFmt('TFlexRanges: 次元数が一致しません。Ranges=%d, Dims=%d', [System.Length(Self), System.Length(Dims)]);

  for i := 0 to System.Length(Self) - 1 do
  begin
    TargetDim := Dims[i];
    Range := Self[i];
    Range.Check(True);

    case System.Length(Range) of
      0: ;  // [] 全範囲指定
      1, 2:  // [L] or [L, H]
        if (Range.Low < TargetDim.Low) or (Range.High > TargetDim.High) then
          raise Exception.CreateFmt('TFlexRanges: 第%d次元の範囲[%d..%d]が配列範囲外です。範囲=%d..%d',
            [i + 1, Range.Low, Range.High, TargetDim.Low, TargetDim.High]);
    end;
  end;
end;

{ TSliceIndexesHelper }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] TSliceIndexesの妥当性チェック
// [引数] Dim: 対象次元のLow/High情報
// [戻値] なし
// [備考] 不正な場合は例外を発生
//////////////////////////////////////////////////////////////////////////////////////
procedure TSliceIndexesHelper.Check(const Dim: TFlexDimension);
var
  Index: Integer;
begin
  for Index in Self do
    if (Index < Dim.Low) or (Index > Dim.High) then
      raise Exception.CreateFmt('TSliceIndexes: インデックス%dが範囲外です。範囲=%d..%d',
        [Index, Dim.Low, Dim.High]);
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
  Result := Self[Index - 1];  // 1base → 0base
//  Result := Self[Self[Index - 1].RealIndex];  // 1base → 0base & 論理転置
end;

{ TFlexArrayEnumerator<T> }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を初期化
// [引数] データの先頭ポインタ, 全要素数
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.TFlexArrayEnumerator<T>.Create(const AData: TArray<T>);
begin
  FArray := AData;
  FIndex := -1;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 現在の要素を取得
// [引数] なし
// [戻値] 現在の要素
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TFlexArrayEnumerator<T>.GetCurrent: T;
begin
  Result := FArray[FIndex];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次の要素に移動
// [引数] なし
// [戻値] 次の要素が存在するかどうか
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TFlexArrayEnumerator<T>.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < System.Length(FArray);
end;

{ TCoordsIterator }
//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標列挙子を初期化
// [引数] 親の次元情報, 座標範囲
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.TCoordsIterator.Create(const Dims: TFlexDimensions; Ranges: TFlexRanges);
var
  i: Integer;
  DimCount: Integer;
begin
  inherited Create;

  if Ranges <> nil then
  begin
    Ranges.Check(Dims);
  end;

  DimCount := System.Length(Dims);
  SetLength(FRanges, DimCount);
  for i := 0 to DimCount - 1 do
  begin
    if Ranges <> nil then
    begin
      case System.Length(Ranges[i]) of
        0: FRanges[i] := [Dims[i].Low, Dims[i].High]; // []
        1: FRanges[i] := [Ranges[i].Low, Ranges[i].Low];  // [L]
        2: FRanges[i] := [Ranges[i].Low, Ranges[i].High]; // [L, H]
      end;
    end
    else
    begin
      FRanges[i] := [Dims[i].Low, Dims[i].High];
    end;
  end;

  SetLength(FCoords, DimCount);
  for i := 0 to DimCount - 1 do
    FCoords[i] := FRanges[i].Low;

  // MoveNextが最初に呼ばれる前に1つ戻す（for..in の仕様に合わせる）
  FCoords[DimCount - 1] := FRanges[DimCount - 1].Low - 1;
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
// [概要] FRangesの範囲内で座標をインクリメントする
// [引数] Coords: 現在の座標配列
// [戻値] 1周した（終了）場合はTrue、まだ続く場合はFalse
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TCoordsIterator.IncCoords(var Coords: TCoords): Boolean;
var
  d: Integer;
begin
  // 一番右側の次元（最小単位）から順にチェック
  for d := System.High(Coords) downto 0 do
  begin
    Inc(Coords[d]);
    if Coords[d] <= FRanges[d].High then Exit(False);
    Coords[d] := FRanges[d].Low;
  end;

  // すべての次元がリセットされた＝1周した
  Result := True;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次の座標に移動
// [戻値] 次の座標が存在する場合はTrue、終了時はFalse
//////////////////////////////////////////////////////////////////////////////////////
function  TFlexArray<T>.TCoordsIterator.MoveNext: Boolean;
begin
  Result := not IncCoords(FCoords);
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
// [概要] データオブジェクトを取得（遅延初期化）
// [戻値] TDataオブジェクト
// [備考] 参照がなくなるとDataオブジェクトが開放される（メソッドチェーンを実現するため）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Data: TData;
begin
  if FRef = nil then
  begin
    FData := TData.Create(); // データ本体
    FRef  := FData;          // 寿命管理（スマートポインタ代わり）
  end;
  Result := FData;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] ビューモードかどうかを取得
// [戻値] ビューモードの場合はtrue
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.IsView: Boolean;
begin
  Result := Data.FIsView;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 範囲配列から配列構造を初期化
// [引数] 各次元の範囲配列
// [戻値] 総要素数
// [使用例] TotalSize := InitializeFromRanges([[1, 10], [1, 10]])
// [備考] 各次元の範囲配列は [Low, High] のペアになっていること
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InitializeDimensions(const Ranges: TFlexRanges): Integer;
var
  i: Integer;
  CurrentStride: Integer;
begin
  SetLength(Data.FDims, System.Length(Ranges));  // 完全0ベース化
  CurrentStride := 1;

  // 後ろの次元から歩幅を計算することで多次元に対応
  for i := System.High(Ranges) downto 0 do
  begin
    Ranges[i].Check;

    Data.FDims[i].Low    := Ranges[i].Low;    // 0base
    Data.FDims[i].High   := Ranges[i].High;
    Data.FDims[i].Stride := CurrentStride;
//    Data.FDims[i].RealIndex := i;  // RealIndexを自然順序で初期化

    // 全要素数を累積計算
    CurrentStride := CurrentStride * Ranges[i].Len;
  end;

  Result := CurrentStride;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 汎用・多次元コンストラクタ
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.Create([3, 4], 1)  // 1始まりの3x4行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.Create(const Shapes: array of Integer; BaseIndex: Integer = 0);
begin
  SetLength(Data.FArray, InitializeDimensions(ShapesToRanges(Shapes, BaseIndex)));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元用範囲指定コンストラクタ
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([-5, 5])  // -5から5までの11要素
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const Range: TFlexRange);
begin
  SetLength(Data.FArray, InitializeDimensions([Range]));
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
  SetLength(Data.FArray, InitializeDimensions(Ranges));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 文字列から範囲指定コンストラクタ
// [引数] 範囲文字列 "1..3,1..2" または "[1..3,1..2]"
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange("1..3,1..2")  // 3x2行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(RangeStr: string);
begin
  SetLength(Data.FArray, InitializeDimensions(RangesStringToRanges(RangeStr)));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] FlexArrayからFlexArrayを生成する
// [引数] 元のFlexArray
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromFlexArray(arr, 1)
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromFlexArray(const Src: TFlexArray<T>);
begin
  Data.FDims := Copy(Src.Data.FDims);
  Data.FArray := Copy(Src.Data.FArray);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 一次元配列簡易生成コンストラクタ
// [引数] Values: 配列の要素値, BaseIndex: ベースインデックス(省略時:0)
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromValues([1,2,3,4], 0)
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromValues(const Values: array of T; BaseIndex: Integer = 0);
var
  i: Integer;
begin
  InitializeDimensions([[BaseIndex, BaseIndex + System.Length(Values) - 1]]);
  SetLength(Data.FArray, System.Length(Values));
  for i := 0 to System.High(Values) do
    Data.FArray[i] := Values[i];
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
  Data.FArray := Copy(Src);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 参照生成コンストラクタ
// [引数] 元の動的配列, 開始インデックス(省略時:0)
// [戻値] なし
// [備考] CreateFromArrayと異なり、変更は元の配列に反映される
// [使用例] TFlexArray<Integer>.ViewFromArray(arr, 1)
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.ViewFromArray(const Src: TArray<T>; BaseIndex: Integer = 0);
begin
  InitializeDimensions([[BaseIndex, BaseIndex + System.Length(Src) - 1]]);
  Data.FArray := Src; // データを参照して同一化
  Data.FIsView := True;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の形状を変更し、データを保持したまま次元構造を再定義
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] self(メソッドチェーン用)
// [使用例] Matrix.Reshape([3, 2], 1)  // 1始まりの3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Reshape(const Shapes: array of Integer; BaseIndex: Integer = 0): TFlexArray<T>;
begin
  Result := ReshapeRange(ShapesToRanges(Shapes, BaseIndex));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元範囲指定による再定義
// [引数] 範囲配列 [Low, High]
// [戻値] Self（メソッドチェーン専用）
// [使用例] Vector.ReshapeRange([-5, 5])  // -5から5までの範囲に再定義
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ReshapeRange(const Range: TFlexRange): TFlexArray<T>;
begin
  Result := ReshapeRange([Range]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元範囲指定による再定義
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] Self（メソッドチェーン専用）
// [使用例] Tensor.ReshapeRange([[1, 3], [1, 2]])  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ReshapeRange(const Ranges: TFlexRanges): TFlexArray<T>;
var
  oldTotalSize: Integer;
  newTotalSize: Integer;
begin
  oldTotalSize := Self.TotalSize;
  newTotalSize := InitializeDimensions(Ranges);

  // サイズのチェック
  if oldTotalSize <> newTotalSize then
    raise Exception.Create(Format(
      'Reshape: 要素数が一致しません。現在=%d, 新規=%d', [oldTotalSize, newTotalSize]));

  Result := Self;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 文字列から範囲指定による再定義
// [引数] 範囲文字列 "1..3,1..2" または "[1..3,1..2]"
// [戻値] Self（メソッドチェーン専用）
// [使用例] Matrix.ReshapeRange("1..3,1..2")  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ReshapeRange(RangeStr: string): TFlexArray<T>;
begin
  Result := ReshapeRange(RangesStringToRanges(RangeStr));
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] ベースインデックスを再設定
// [引数] BaseIndex - 新しいベースインデックス
// [戻値] Self（メソッドチェーン専用）
// [使用例] Matrix.Rebase(1)
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Rebase(BaseIndex: Integer): TFlexArray<T>;
var
  i: Integer;
  Shapes: TArray<Integer>;
begin
  // 現在の形状を取得
  SetLength(Shapes, Self.DimensionCount);
  for i := 0 to system.High(Shapes) do
    Shapes[i] := Self.Data.FDims[i].Len;

  Result := Reshape(Shapes, BaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 各次元のベースインデックスを個別に指定して再設定
// [引数] BaseIndexes - 各次元のベースインデックス配列
// [戻値] Self（メソッドチェーン専用）
// [使用例] Tensor.Rebase([1, 0, 1])
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Rebase(const BaseIndexes: array of Integer): TFlexArray<T>;
var
  i: Integer;
  NewRanges: TFlexRanges;
begin
  if System.Length(BaseIndexes) <> Self.DimensionCount then
    raise Exception.CreateFmt('Rebase: 指定された次元数(%d)が配列の次元数(%d)と一致しません',
      [System.Length(BaseIndexes), Self.DimensionCount]);

  SetLength(NewRanges, Self.DimensionCount);
  for i := 0 to System.High(BaseIndexes) do
  begin
    NewRanges[i] := [BaseIndexes[i], BaseIndexes[i] + Self.Data.FDims[i].Len - 1];
  end;

  Result := ReshapeRange(NewRanges);
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
//procedure TFlexArray<T>.CheckViewMode;
//var
//  Val: TValue;
//begin
//  if FIsView then
//  begin
//    // 数値型のみ許可
//    Val := TValue.From<T>(default(T));
//    if Val.Kind in [tkInteger, tkFloat] then Exit;
//
//    raise Exception.Create('Viewモードの配列は変更できません。CreateFromFlexArrayでコピーしてから使用してください。');
//  end;
//end;

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
  Result := Self.Data.FDims.Items[1].Low;  // 論理1次元のLow値

  for i := 1 to Self.DimensionCount do
  begin
    if Self.Data.FDims.Items[i].Low <> Result then
      raise Exception.Create('GetCompatibleBaseIndex: 各配列のすべての次元で同じベースインデックスを使用する必要があります。混合ベースは未対応です。');
  end;

  for i := 1 to Another.DimensionCount do
  begin
    if Another.Data.FDims.Items[i].Low <> Result then
      raise Exception.CreateFmt('GetCompatibleBaseIndex: 異なるベースインデックスの配列は結合できません。Self=%d, Another=%d', [Result, Another.Data.FDims.Items[i].Low]);
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
begin
  SetLength(Result, Self.DimensionCount);
  TempIndex := LinearIndex;

  // 末尾の次元から順に割っていく（GetOffsetの逆工程）
  for i := system.Length(Result) - 1 downto 0 do
  begin
    Result[i] := (TempIndex mod Data.FDims[i].Len) + Data.FDims[i].Low; // 論理次元アクセス
    TempIndex := TempIndex div Data.FDims[i].Len;
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
  TargetDim: TFlexDimension;
begin
  if System.Length(Coords) <> Self.DimensionCount then
    raise Exception.CreateFmt('GetOffset: 座標数が次元数と一致しません。Coords=%d, Dims=%d', [System.Length(Coords), Self.DimensionCount]);

  Result := 0;
  for i := 0 to Self.DimensionCount - 1 do
  begin
    TargetDim := Data.FDims[i];
    if (TargetDim.Low <= Coords[i]) and (Coords[i] <= TargetDim.High) then
      Result := Result + (Integer(Coords[i]) - TargetDim.Low) * TargetDim.Stride
    else
      raise Exception.CreateFmt('GetOffset: 範囲外です。Dim=%d, Value=%d, Range=%d..%d',
                 [i + 1, Coords[i], TargetDim.Low, TargetDim.High]);
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
  Result := Data.FArray[GetOffset(Coords)];
end;
function TFlexArray<T>.GetValue(const Coords: TCoords): T;
begin
  Result := Data.FArray[GetOffset(Coords)];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標に値を設定（オーバーロード）
// [引数] Coords: 各次元の座標配列（array of Integer または TCoords）, Value: 設定する値
// [戻値] なし
// [備考] TCoordsは動的配列変数用
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetValue(const Coords: array of Integer; Value: T);
begin
  Data.FArray[GetOffset(Coords)] := Value;
end;
procedure TFlexArray<T>.SetValue(const Coords: TCoords; const Value: T);
begin
  Data.FArray[GetOffset(Coords)] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスで要素を取得
// [引数] 0-based線形インデックス
// [戻値] 指定位置の要素（範囲外の場合は例外）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetElement(Index: Integer): T;
begin
  Result := Data.FArray[Index];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素を設定（1次元インデックス）
// [引数] インデックス, 値
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetElement(Index: Integer; Value: T);
begin
  Data.FArray[Index] := Value;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 値を文字列に変換
// [引数] 変換対象の値
// [戻値] 文字列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ValueToStr(V: T): string;
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

  // 4次元以上は値を出力しない
  if Self.DimensionCount = 0 then
    Exit('[]');

  // 1〜3次元の共通処理
  SetLength(Rows, Data.FDims.Items[1].Len);  // 1base
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
  Result := Copy(Data.FArray);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 範囲文字列を解析して範囲配列に変換
// [引数] 範囲文字列 "1..3,1..2" または "[1..3,1..2]"
// [戻値] 範囲配列 [[1,3],[1,2]]
// [使用例] ParseRangesString("1..3,1..2") → [[1,3],[1,2]]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.RangesStringToRanges(RangeStr: string): TFlexRanges;
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
// [引数] 対象次元 1base
// [戻値] 配列サイズ
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Len(Dim: Integer): Integer;
begin
  Result := Data.FDims.Items[Dim].Len;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の最小インデックスを取得
// [引数] なし
// [戻値] 最小インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Low: Integer;
begin
  if System.Length(Data.FDims) <> 1 then
    raise Exception.Create('多次元配列です。次元を明示してください（例: Low(1)）。');
  Result := Data.FDims.Items[1].Low;  // 1base
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の最大インデックスを取得
// [引数] なし
// [戻値] 最大インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.High: Integer;
begin
  if System.Length(Data.FDims) <> 1 then
    raise Exception.Create('多次元配列です。次元を明示してください（例: High(1)）。');
  Result := Data.FDims.Items[1].High;  // 1base
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最小インデックスを取得
// [引数] 対象次元 1base
// [戻値] 最小インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Low(Dim: Integer): Integer;
begin
  Result := Data.FDims.Items[Dim].Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最大インデックスを取得
// [引数] 対象次元 1base
// [戻値] 最大インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.High(Dim: Integer): Integer;
begin
  Result := Data.FDims.Items[Dim].High;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元数を取得
// [引数] なし
// [戻値] 次元数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetDimensionCount: Integer;
begin
  Result := System.Length(Data.FDims);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の総要素数を取得
// [引数] なし
// [戻値] 要素数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetTotalSize: Integer;
begin
  Result := System.Length(Data.FArray);
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
    Result[i] := [Data.FDims[i].Low, Data.FDims[i].High];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を取得
// [引数] なし
// [戻値] 列挙子オブジェクト
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetEnumerator: TFlexArrayEnumerator<T>;
begin
  Result := TFlexArrayEnumerator<T>.Create(Self.Data.FArray);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標列挙子を取得
// [引数] Ranges: 走査する範囲（Slice関数と同じ指定方法。省略時は配列全体）
//        各次元ごとに必ず全次元を指定する
//        []      → 全範囲（その次元をそのまま走査）
//        [L]     → Lのみ
//        [L, H]  → L..H（両端含む）
// [戻値] TCoordsIterator オブジェクト
// [使用例] for Coords in N.CoordsIterator do
//            N.ItemAt[Coords] := Coords[0] * 10 + Coords[1];
//          for Coords in N.CoordsIterator([[2], [1, 3], []]) do  // 部分範囲
//            N.ItemAt[Coords] := Coords[0] * 100 + Coords[1] * 10 + Coords[2];
// [備考] イテレータで戻されるCoordsは0ベース（0-base）です
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.CoordsIterator(Ranges: TFlexRanges = nil): TCoordsIterator;
begin
  Result := TCoordsIterator.Create(Data.FDims, Ranges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標を初期化
// [引数] 初期化する座標配列
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.InitializeCoords(out Coords: TCoords);
var
  i: Integer;
begin
  SetLength(Coords, Self.DimensionCount);
  for i := 0 to system.Length(Coords) - 1 do
    Coords[i] := Self.Data.FDims[i].Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標をインクリメント
// [引数] Coords: 現在の座標配列 0base
// [戻値] 1周した場合にtrue、それ以外はfalse
// [備考] 2次元配列 [1..3, 1..2] の場合:
//        [1,1] → [1,2] → [2,1] → [2,2] → [3,1] → [3,2] → [1,1](true)
// [使用例] repeat-untilループでの全要素走査に最適
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.IncCoords(var Coords: TCoords): Boolean;
var
  d: Integer;
begin
  // 一番右側の次元（最小単位）から順にチェック
  for d := system.High(Coords) downto 0 do
  begin
    Inc(Coords[d]);

    // 上限を超えていないなら終了
    if Coords[d] <= Self.Data.FDims[d].High then Exit(False);

    // 繰り上がり
    Coords[d] := Self.Data.FDims[d].Low;
  end;

  // すべての次元がリセットされた＝1周した
  Result := True;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元にサイズ1の次元を挿入して次元数を増やす
// [引数] TargetDim: 挿入する次元番号(1-based)
// [戻値] Self（メソッドチェーン専用）
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
function TFlexArray<T>.PromoteDimension(TargetDim: Integer): TFlexArray<T>;
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
  Result := ReshapeRange(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元を削除して次元数を減らす（PromoteDimensionの逆変換）
// [引数] 削除する次元番号(1-based)
// [戻値] Self（メソッドチェーン専用）
// [使用例]
//   元: [1..2, 1..2, 1..1] (2×2×1) → DemoteDimension(3) → [1..2, 1..2] (2×2)
//   元: [1..1, 1..2, 1..3] (1×2×3) → DemoteDimension(1) → [1..2, 1..3] (2×3)
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DemoteDimension(TargetDim: Integer): TFlexArray<T>;
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
  for d := TargetDim-1 to system.High(NewRanges) - 1 do
    NewRanges[d] := NewRanges[d + 1];  // 前に詰める
  SetLength(NewRanges, Length(NewRanges) - 1);

  // 他の次元のLow/Highは維持したままreshape
  Result := ReshapeRange(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 自由自在に配列をスライス
// [引数] 切り抜く座標（すべての次元の設定要）
// [戻値] 切取り後の配列
// [使用例] NewArr := arr.Slice([[1, 5], [2, 8], [], [3]]);
//         NumPyの arr[1:5, 2:8, :, 3] に相当
//         Juliaの arr[1:5, 2:8, :, 3] に相当
// [備考] 実行後の各次元の[Low,High]は引数の[[L,H], [L,H]]]がそのまま適用される
//        []の次元は元の次元の[Low,High]がそのまま適用される
//        [4]のように要素数が1の次元は潰される
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Slice(const Ranges: TFlexRanges): TFlexArray<T>;
var
  i: Integer;
  SingleDimCount: Integer;
begin
  SingleDimCount := 0;
  for i := 0 to System.High(Ranges) do
    if System.Length(Ranges[i]) = 1 then
      Inc(SingleDimCount);

  if Self.DimensionCount = SingleDimCount then
    raise Exception.Create('Slice: 全ての次元が単一指定されています。スカラー値を取得してください。');

  Result := SliceCore(Ranges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] すべての次元でインデックス配列を指定して要素を抽出
// [引数] Indexes - 各次元のインデックス配列（空配列は全範囲指定）
//       BaseIndex - ベースインデックス（実行後すべての次元に適用される）
// [戻値] 抽出された配列
// [使用例] result := arr.SliceIndexed([[1,2,3], [], [4]])
//         NumPyの arr[[1,2,3], :, 4] に相当
//         Juliaの arr[[1,2,3], :, 4] に相当
// [備考] [4]のように要素数が1の次元は潰される
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceIndexed(const Indexes: TArray<TSliceIndexes>; BaseIndex: Integer = 0): TFlexArray<T>;
begin
  if System.Length(Indexes) <> Self.DimensionCount then
    raise Exception.CreateFmt('SliceIndexed: 指定された次元数(%d)が配列の次元数(%d)と一致しません',
      [System.Length(Indexes), Self.DimensionCount]);

  Result := SliceIndexedCore(Indexes, BaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TSliceIndexesからスライス範囲を構築してResult配列を作成し、Selfから要素をコピーするコア関数
// [引数] Indexes - 各次元のインデックス配列
//       BaseIndex - ベースインデックス
// [戻値] スライスされた配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceIndexedCore(const Indexes: TArray<TSliceIndexes>; BaseIndex: Integer = 0): TFlexArray<T>;
var
  i, d: Integer;
  ResultCoords, SelfCoords: TCoords;
  NewRanges: TFlexRanges;
  TargetDim: TFlexDimension;
  MappedIndexes: TArray<TSliceIndexes>;
begin
  for i := 0 to System.High(Indexes) do
    Indexes[i].Check(Data.FDims[i]);

  SetLength(NewRanges, Self.DimensionCount);

  // IndexesからNewRangesを構築
  for i := 0 to System.High(Indexes) do
  begin
    TargetDim := Self.Data.FDims[i];
    if System.Length(Indexes[i]) = 0 then
      NewRanges[i] := [0, TargetDim.Len - 1]  // [] は全範囲、Low=0で統一
    else
      NewRanges[i] := [0, System.Length(Indexes[i]) - 1];
  end;

  // []をLow..Highに展開
  MappedIndexes := Copy(Indexes);
  for i := 0 to System.High(Indexes) do
  begin
    TargetDim := Self.Data.FDims[i];
    if System.Length(Indexes[i]) = 0 then
    begin
      // []の場合はLow..Highに展開
      SetLength(MappedIndexes[i], TargetDim.Len);
      for d := 0 to TargetDim.Len - 1 do
        MappedIndexes[i][d] := TargetDim.Low + d;
    end;
  end;

  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  Result.InitializeCoords(ResultCoords);
  SetLength(SelfCoords, Self.DimensionCount);

  // Resultの座標イテレーションで、Selfから対応する要素を取得
  for i := 0 to Result.TotalSize - 1 do
  begin
    // 引数のIndexesをSelfの座標に変換
    for d := 0 to System.High(ResultCoords) do
      SelfCoords[d] := MappedIndexes[d][ResultCoords[d]];

    Result.Data.FArray[i] := Self.ItemAt[SelfCoords];
    Result.IncCoords(ResultCoords);
  end;

  // 要素数1の次元を後方からDemoteDimensionで処理
  for i := System.High(Indexes) downto 0 do
  begin
    if System.Length(Indexes[i]) = 1 then
      Result.DemoteDimension(i + 1);  // 1次元ずつつぶす
  end;

  Result.Rebase(BaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] スライス範囲からResult配列を作成し、Selfから要素をコピーするコア関数
// [引数] Ranges - スライス範囲を表現する次元情報
// [戻値] スライスされた配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceCore(const Ranges: TFlexRanges): TFlexArray<T>;
var
  i: Integer;
  ResultCoords: TCoords;
  NewRanges: TFlexRanges;
  TargetDim: TFlexDimension;
begin
  Ranges.Check(Data.FDims);

  SetLength(NewRanges, Self.DimensionCount);
  for i := 0 to System.High(Ranges) do
  begin
    TargetDim := Self.Data.FDims[i];
    case System.Length(Ranges[i]) of
      0: NewRanges[i] := [TargetDim.Low, TargetDim.High];
      1: NewRanges[i] := [Ranges[i].Low, Ranges[i].Low];
      2: NewRanges[i] := [Ranges[i].Low, Ranges[i].High];
    end;
  end;

  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  Result.InitializeCoords(ResultCoords);

  // Resultの座標イテレーションで、Selfからスライス範囲の要素を取得
  for i := 0 to Result.TotalSize - 1 do
  begin
    Result.Data.FArray[i] := Self.ItemAt[ResultCoords];
    Result.IncCoords(ResultCoords);
  end;

  // つぶす次元を後方からDemoteDimensionで処理
  for i := System.High(Ranges) downto 0 do
  begin
    if System.Length(Ranges[i]) = 1 then
      Result.DemoteDimension(i + 1);  // 1次元ずつつぶす
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元にAnother配列を挿入するコア関数
// [引数] Dim: 対象次元(1-based), Index: 挿入開始位置, Another: 挿入する配列
// [戻値] 挿入後の新しい配列
// [使用例]
//   Result := Matrix.InsertDimCore(1, 2, Another); // 2行目からAnotherを挿入
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertDimCore(Dim: Integer; Index: Integer; const Another: TFlexArray<T>): TFlexArray<T>;
var
  DimIdx: Integer;
  NewRanges: TFlexRanges;
  ResultCoords: TCoords;
  MappedIndexes: TFlexArray<Integer>;
  IsAnotherArea: TFlexArray<Boolean>;
  i, d, bak: Integer;
  SelfDim, AnotherDim: TFlexDimension;
begin
  // 1-based to 0-based
  DimIdx := Dim - 1;

  // パラメータ検証
  if (Dim < 1) or (Dim > Self.DimensionCount) then
    raise Exception.CreateFmt('InsertDimCore: 次元番号が範囲外です。Dim=%d, 次元数=%d', [Dim, Self.DimensionCount]);

  if (Index < Self.Low(Dim)) or (Index > Self.High(Dim) + 1) then
    raise Exception.CreateFmt('InsertDimCore: 挿入位置が範囲外です。Index=%d, 範囲=%d..%d',
      [Index, Self.Low(Dim), Self.High(Dim) + 1]);

  // Anotherの次元数チェック（Selfと同じ次元数が必要）
  if Another.DimensionCount <> Self.DimensionCount then
    raise Exception.CreateFmt('InsertDimCore: 挿入配列の次元数が不正です。期待=%d, 実際=%d',
      [Self.DimensionCount, Another.DimensionCount]);

  // 挿入次元以外の次元でLow/Highが一致することをチェック
  for i := 0 to Self.DimensionCount - 1 do
  begin
    if i <> DimIdx then
    begin
      SelfDim := Self.Data.FDims[i];
      AnotherDim := Another.Data.FDims[i];
      if (SelfDim.Low <> AnotherDim.Low) or (SelfDim.High <> AnotherDim.High) then
        raise Exception.CreateFmt('InsertDimCore: 挿入配列の次元%dの境界が一致しません。Self[%d..%d], Another[%d..%d]',
          [i + 1, SelfDim.Low, SelfDim.High, AnotherDim.Low, AnotherDim.High]);
    end;
  end;

  // 結果配列の形状を計算
  NewRanges := Self.GetRanges;
  // 対象次元のサイズを拡張（Selfのサイズ + Anotherのサイズ）
  NewRanges[DimIdx] := [Self.Low(Dim), Self.High(Dim) + Another.Len(Dim)];

  // MappedIndexesを作成 - Resultの次元インデックスをソースインデックスにマッピング
  MappedIndexes := TFlexArray<Integer>.CreateFromRange(NewRanges[DimIdx]);
  IsAnotherArea := TFlexArray<Boolean>.CreateFromRange(NewRanges[DimIdx]); // デフォルトはFalse

  // 前半部：Selfのインデックスをマッピング
  d := Self.Low(Dim);
  for i := Self.Low(Dim) to Index - 1 do
  begin
    MappedIndexes[d] := i;
    Inc(d);
  end;

  // 中間部：Anotherのインデックスをマッピングし、IsAnotherAreaをTrueに設定
  for i := Another.Low(Dim) to Another.High(Dim) do
  begin
    MappedIndexes[d] := i;
    IsAnotherArea[d] := True;
    Inc(d);
  end;

  // 後半部：Selfの残りのインデックスをマッピング
  for i := Index to Self.High(Dim) do
  begin
    MappedIndexes[d] := i;
    Inc(d);
  end;

  // 結果配列を作成
  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  Result.InitializeCoords(ResultCoords);

  // 線形反復でデータをコピー
  for i := 0 to Result.TotalSize - 1 do
  begin
    bak := ResultCoords[DimIdx];
    ResultCoords[DimIdx] := MappedIndexes[bak];

    if IsAnotherArea[bak] then
      Result.Data.FArray[i] := Another.ItemAt[ResultCoords]
    else
      Result.Data.FArray[i] := Self.ItemAt[ResultCoords];

    ResultCoords[DimIdx] := bak;
    Result.IncCoords(ResultCoords);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元をスライスして取得
// [引数] 対象次元, 取得インデックス
// [戻値] スライス配列（元の次元数より1次元少ない配列を生成）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceDim(Dim: Integer; Index: Integer): TFlexArray<T>;
var
  Ranges: TFlexRanges;
begin
  if Self.DimensionCount = 1 then
    raise Exception.Create('1次元配列にはSliceDim(Dim, Index)は使用できません。');

  if (Dim < 1) or (Dim > Self.DimensionCount) then
    raise Exception.CreateFmt('Dimは1から%dの範囲で指定してください', [Self.DimensionCount]);

  SetLength(Ranges, Self.DimensionCount);
  // 対象次元のみ単一インデックス
  Ranges[Dim - 1] := [Index];

  Result := Slice(Ranges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定行1次元を取得
// [引数] 行インデックス
// [戻値] 行の1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceRow(RowIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := Slice([[RowIndex], []]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定列を1次元で取得
// [引数] 列インデックス
// [戻値] 列の1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.SliceCol(ColIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := Slice([[], [ColIndex]]);
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
  if Another.Data.FDims.Items[1].Len <> Self.Data.FDims.Items[2].Len then
    raise Exception.Create('InsertRow: 列数が一致しません');

  // constパラメータをローカル変数にコピー
  AnotherReady := Another;

  // 1Dを2Dに昇格（次元1にサイズ1の次元を挿入）
  AnotherReady.PromoteDimension(1);

  // BaseIndexを合わせる
  AnotherReady.Rebase(Self.Low(1));

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
  if Another.Data.FDims.Items[1].Len <> Self.Data.FDims.Items[1].Len then
    raise Exception.Create('InsertCol: 行数が一致しません');

  // constパラメータをローカル変数にコピー
  AnotherReady := Another;

  // 1Dを2Dに昇格（次元2にサイズ1の次元を挿入）
  AnotherReady.PromoteDimension(2);

  // BaseIndexを合わせる
  AnotherReady.ReBase(Self.Low(1));

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
// [概要] 指定次元の指定位置に配列を挿入
// [引数] Dim: 対象次元(1-based), Index: 挿入位置, Items: 挿入する配列
// [戻値] 挿入後の新しい配列
// [使用例]
//   3D配列[2,3,4]に次元1の位置2で[1,4]配列を挿入 → [3,3,4]配列
//   2D配列[3,4]に行2で[1,4]配列を挿入 → [4,4]配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InsertDim(Dim: Integer; Index: Integer; const Items: TFlexArray<T>): TFlexArray<T>;
begin
  Result := InsertDimCore(Dim, Index, Items);
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
  Result := DeleteDim(1, [RowIndex]);
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
  Result := DeleteDim(2, [ColIndex]);
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
// [概要] 指定次元の範囲を削除
// [引数] Dim: 対象次元(1-based), Range: 削除範囲[Low, High]
// [戻値] 削除後の新しい配列
// [使用例] Result := Matrix.DeleteDim(2, [3, 5]); // 3〜5列目を削除
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteDim(Dim: Integer; const Range: TFlexRange): TFlexArray<T>;
begin
  Result := DeleteDimCore(Dim, Range);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の範囲を削除するコア関数
// [引数] Dim: 対象次元(1-based), Range: 削除範囲[Low, High]
// [戻値] 削除後の新しい配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.DeleteDimCore(Dim: Integer; const Range: TFlexRange): TFlexArray<T>;
var
  DimIdx: Integer;
  NewRanges: TFlexRanges;
  ResultCoords: TCoords;
  MappedIndexes: TFlexArray<Integer>;
  i, d, bak: Integer;
begin
  // 1-based to 0-based
  DimIdx := Dim - 1;

  // パラメータ検証
  Range.Check(True);

  if (Dim < 1) or (Dim > Self.DimensionCount) then
    raise Exception.CreateFmt('DeleteDimCore: 次元番号が範囲外です。Dim=%d, 次元数=%d', [Dim, Self.DimensionCount]);

  if (Range.Low < Self.Low(Dim)) or (Range.High > Self.High(Dim)) then
    raise Exception.CreateFmt('DeleteDimCore: 削除範囲が不正です。Range=[%d,%d], 範囲=%d..%d',
      [Range.Low, Range.High, Self.Low(Dim), Self.High(Dim)]);

  // 全範囲の削除チェック
  if (Range.Low = Self.Low(Dim)) and (Range.High = Self.High(Dim)) then
    raise Exception.Create('DeleteDimCore: 全範囲を削除することはできません');

  // 結果配列の形状を計算
  NewRanges := Self.GetRanges;
  NewRanges[DimIdx] := [Self.Low(Dim), Self.High(Dim) - Range.Len];

  // MappedIndexesを作成 - Resultの次元インデックスをソースインデックスにマッピング
  MappedIndexes := TFlexArray<Integer>.CreateFromRange(NewRanges[DimIdx]);

  // 前半部：Selfのインデックスをマッピング（削除範囲の前）
  d := Self.Low(Dim);
  for i := Self.Low(Dim) to Range.Low - 1 do
  begin
    MappedIndexes[d] := i;
    Inc(d);
  end;

  // 後半部：Selfの残りのインデックスをマッピング（削除範囲の後）
  for i := Range.High + 1 to Self.High(Dim) do
  begin
    MappedIndexes[d] := i;
    Inc(d);
  end;

  // 結果配列を作成
  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  Result.InitializeCoords(ResultCoords);

  for i := 0 to Result.TotalSize - 1 do
  begin
    bak := ResultCoords[DimIdx];
    ResultCoords[DimIdx] := MappedIndexes[bak];
    Result.Data.FArray[i] := Self.ItemAt[ResultCoords];
    ResultCoords[DimIdx] := bak;
    Result.IncCoords(ResultCoords);
  end;
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
// [概要] FDims配列の次元順序を物理的に入れ替える
// [引数] NewDims: 新しい次元の順序（1-based）、指定例：[3, 1, 2]
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.LogicalTranspose(const NewDims: array of Integer);
var
  i: Integer;
  NewFDims: TFlexDimensions;
begin
  SetLength(NewFDims, DimensionCount);
  for i := 0 to DimensionCount - 1 do
    NewFDims[i] := Data.FDims[NewDims[i] - 1];  // 1-based -> 0-based
  Data.FDims := NewFDims;
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
  Coords: TCoords;
  bak: TFlexDimensions;
begin
  bak := Copy(Data.FDims);
  try
    // FDimsの順番を入れ替え
    LogicalTranspose(NewDims);
    // 入替え後のFDimsを利用し、結果を作成
    Result := TFlexArray<T>.CreateFromRange(GetRanges);

    // FDims入替え後のselfを利用して値を結果に設定
    Self.InitializeCoords(Coords);
    for i := 0 to Result.TotalSize - 1 do
    begin
      Result.Data.FArray[i] := Self.ItemAt[Coords];
      Self.IncCoords(Coords);
    end;
  finally
    Data.FDims := bak;
  end;
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
// [概要] 指定次元で配列を結合
// [引数] 結合対象の配列, 結合する次元(1-based)
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
//  BaseIndex := Self.GetCompatibleBaseIndex(Another);

  SelfReady := Self;
  AnotherReady := Another;

  // 1ベース以外は1ベースに正規化
//  if BaseIndex <> 1 then
//  begin
//    SelfReady.ReBase(1);
//    AnotherReady.ReBase(1);
//  end;

  // AnotherReadyの次元をSelfReadyにあわせて拡張
//  if DimDiff > 0 then
//    AnotherReady.PromoteDimension(TargetDim);

  // 同一次元結合を実行
  Result := SelfReady.InsertDim(TargetDim, SelfReady.High(TargetDim) + 1, AnotherReady);

  // 元のベースインデックスに戻す
//  if BaseIndex <> 1 then
//    Result.ReBase(BaseIndex);
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
  Result := Self.AppendArray(Another.Data.FArray);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列専用の配列結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(const Another: TArray<T>): TFlexArray<T>;
begin
  CheckDimension(1);
  Result := Default(TFlexArray<T>);
  Result.Data.FArray := Self.Data.FArray +  Another;
  Result.Data.FDims := Copy(Self.Data.FDims);
  Result.Data.FDims[0].High := Self.Low + Result.TotalSize - 1;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 単一値を配列に追加
// [引数] 追加する値
// [戻値] 追加後の新しい配列
// [使用例] Vector1 := Vector1.AppendArray(42)
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(Value: T): TFlexArray<T>;
begin
  CheckDimension(1);
  Result := Self.AppendArray([Value]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列のすべての要素を指定した値で埋める
// [引数] Value: 埋める値
// [戻値] Self（メソッドチェーン専用）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Fill(Value: T): TFlexArray<T>;
var
  i: Integer;
begin
  for i := 0 to Self.TotalSize - 1 do
    Data.FArray[i] := Value;

  Result := Self;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列をソートした場合のインデックス配列を返す
// [引数] Ascending: True=昇順, False=降順 (デフォルト=True)
// [戻値] ソート後のインデックス配列
// [使用例]
// matrix (Before) : [[3,2,1], [6,5,4]]
// Vector := matrix.Slice([2, []]); // 2行目の要素を抽出 結果: [6,5,4]
// SortIndices := Vector.ArgSort;   // 結果: [2,1,0]
// matrix := matrix.SliceDimIndexes(2, SortIndices); // 列をソート 結果: [[1,2,3], [4,5,6]]
// NumPyの np.argsort(matrix[1, :]) に相当
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ArgSort(Ascending: Boolean = True): TArray<Integer>;
var
  i: Integer;
  Indices: TArray<Integer>;
  Comparer: IComparer<Integer>;
  LSelf: TFlexArray<T>; // FDataを直接参照するためのローカル変数
begin
  // 1次元配列専用チェック
  CheckDimension(1);
  LSelf := Self; // 内部配列をキャプチャ

  // インデックス配列を初期化
  SetLength(Indices, TotalSize);
  for i := Self.Low to Self.High do
    Indices[i - Self.Low] := i;

  // カスタム比較子を作成してインデックスをソート
  Comparer := TComparer<Integer>.Construct(
    function(const L, R: Integer): Integer
    begin
      if Ascending then
        Result := TComparer<T>.Default.Compare(LSelf[L], LSelf[R])
      else
        Result := TComparer<T>.Default.Compare(LSelf[R], LSelf[L]);
    end
  );

  TArray.Sort<Integer>(Indices, Comparer);
  Result := Indices;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素をフィルタリングして条件に合う要素のみを返す（非破壊的）
// [引数] フィルタ関数（値と座標を引数に取り、条件を返す）
// [戻値] 条件に合う要素の配列
// [使用例] B := A.Filter(function(Value: Integer; Coords: TCoords): Boolean
//                 begin
//                   Result := (Coords[0] >= Coords[1]);
//                 end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Filter(AFunc: TFilterFunc<T>): TArray<T>;
var
  i, Count: Integer;
  CurrentCoords: TCoords;
begin
  // まず結果をカウント
  Count := 0;
  Self.InitializeCoords(CurrentCoords);
  for i := 0 to Self.TotalSize - 1 do
  begin
    if AFunc(Self.Elements[i], CurrentCoords) then
      Inc(Count);
    Self.IncCoords(CurrentCoords);
  end;

  // 結果を設定
  SetLength(Result, Count);
  Count := 0;
  Self.InitializeCoords(CurrentCoords);
  for i := 0 to Self.TotalSize - 1 do
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
  Result := TArray.Contains<T>(Self.Data.FArray, Value);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定値のインデックスを返す
// [引数] Value: 検索する値
// [戻値] 見つかった場合は0-basedインデックス、見つからない場合は-1
// [使用例] idx := arr.IndexOf(20);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.IndexOfElements(const Value: T): Integer;
begin
  Result := TArray.IndexOf<T>(Self.Data.FArray, Value);
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
  Result := [];
  Index := TArray.IndexOf<T>(Self.Data.FArray, Value);
  if Index >= 0 then
    Result := Self.GetCoords(Index);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2つの配列を次元をあわせて演算する
// [引数] Source:演算対象の配列, Target:演算対象の配列, AFunc:要素ごとの演算を行うコールバック
// [戻値] 演算適用後の新しい配列
//////////////////////////////////////////////////////////////////////////////////////
class function TFlexArray<T>.BroadcastCore(Source: TFlexArray<T>; Target: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>;
var
  i, d, MaxDims: Integer;
  Coords: TCoords;
  NewRanges: TFlexRanges;
  SrcIdx, TgtIdx: Integer;
  bak1, bak2: TFlexDimensions;
  SrcDims, TgtDims: TFlexDimensions;
  SrcStride, TgtStride: array of Integer;
begin
  SrcDims := Source.Data.FDims;
  TgtDims := Target.Data.FDims;

  MaxDims := Max(Length(SrcDims), Length(TgtDims));
  SetLength(NewRanges, MaxDims);
  SetLength(SrcStride, MaxDims);
  SetLength(TgtStride, MaxDims);

  SrcIdx := Length(SrcDims) - 1;
  TgtIdx := Length(TgtDims) - 1;

  for d := MaxDims - 1 downto 0 do
  begin
    if (SrcIdx < 0) or (TgtIdx < 0) then Break;

    if SrcDims[SrcIdx].Len = 1 then
    begin
      NewRanges[d] := [TgtDims[TgtIdx].Low, TgtDims[TgtIdx].High];
    end
    else if TgtDims[TgtIdx].Len = 1 then
    begin
      NewRanges[d] := [SrcDims[SrcIdx].Low, SrcDims[SrcIdx].High];
    end
    else
    begin
      // 両方の次元がサイズ複数の場合のみ形状をチェック
      if (SrcDims[SrcIdx].Low <> TgtDims[TgtIdx].Low) or
         (SrcDims[SrcIdx].High <> TgtDims[TgtIdx].High) then
        raise Exception.CreateFmt('ブロードキャストできません：次元 %d で形状が一致しません', [d]);

      NewRanges[d] := [SrcDims[SrcIdx].Low, SrcDims[SrcIdx].High];
    end;

    if SrcDims[SrcIdx].Len > 1 then
      SrcStride[d] := SrcDims[SrcIdx].Stride;

    if TgtDims[TgtIdx].Len > 1 then
      TgtStride[d] := TgtDims[TgtIdx].Stride;

    Dec(SrcIdx);
    Dec(TgtIdx);
  end;

  if SrcIdx >= 0 then
  begin
    // Sourceの残り次元をコピー
    for d := SrcIdx downto 0 do
    begin
      NewRanges[d] := [SrcDims[d].Low, SrcDims[d].High];
      SrcStride[d] := SrcDims[d].Stride;
    end;
  end
  else if TgtIdx >= 0 then
  begin
    // Targetの残り次元をコピー
    for d := TgtIdx downto 0 do
    begin
      NewRanges[d] := [TgtDims[d].Low, TgtDims[d].High];
      TgtStride[d] := TgtDims[d].Stride;
    end;
  end;

  // 結果配列を作成（共通形状を使用）
  Result := TFlexArray<T>.CreateFromRange(NewRanges);

  // 元のFDimsを保存
  bak1 := Copy(Source.Data.FDims);
  bak2 := Copy(Target.Data.FDims);

  try
    // 共通座標系で処理するため、両配列のFDimsをResultの形状に統一
    Source.Data.FDims := Copy(Result.Data.FDims);
    Target.Data.FDims := Copy(Result.Data.FDims);

    // 元の次元のStrideを設定するが、要素数1の次元は0なので空回りする
    for d := 0 to MaxDims - 1 do
    begin
      Source.Data.FDims[d].Stride := SrcStride[d];
      Target.Data.FDims[d].Stride := TgtStride[d];
    end;

    Result.InitializeCoords(Coords);
    for i := 0 to Result.TotalSize - 1 do
    begin
      Result.Data.FArray[i] := AFunc(Source.ItemAt[Coords], Target.ItemAt[Coords]);
      Result.IncCoords(Coords);
    end;

  finally
    Source.Data.FDims := bak1;
    Target.Data.FDims := bak2;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 自身の配列とスカラー値をブロードキャストして演算する
// [引数] Value: 演算対象の値, AFunc: 要素ごとの演算関数
// [戻値] 演算適用後の新しい配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Broadcast(Value: T; AFunc: TOperationFunc<T>): TFlexArray<T>;
begin
  Result := TFlexArray<T>.Broadcast(Self, Value, AFunc);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 自身の配列と引数の配列をブロードキャストして演算する
// [引数] Source: 演算対象配列, AFunc: 要素ごとの演算関数
// [戻値] 演算適用後の新しい配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Broadcast(const Source: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>;
begin
  Result := TFlexArray<T>.Broadcast(Self, Source, AFunc);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列をスカラー値でブロードキャスト
// [引数] Source:演算対象配列, Value:演算対象の値, AFunc:要素ごとの演算関数
// [戻値] 演算適用後の新しい配列
// [使用例]
//   A: [[1, 2], [3, 4]]
//   C := TFlexArray<Integer>.Broadcast(A, 10,
//     function(X, Y: Integer): Integer
//     begin
//       Result := X + Y;
//     end);
//   結果: [[11, 12], [13, 14]]
//////////////////////////////////////////////////////////////////////////////////////
class function TFlexArray<T>.Broadcast(const Source: TFlexArray<T>; Value: T; AFunc: TOperationFunc<T>): TFlexArray<T>;
var
  i: Integer;
begin
  Result := TFlexArray<T>.CreateFromRange(Source.GetRanges);
  for i := 0 to Result.TotalSize - 1 do
    Result.Data.FArray[i] := AFunc(Source.Data.FArray[i], Value);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] スカラー値をターゲット形状でブロードキャスト
// [引数] Value: 演算対象の値, Target: 演算対象配列, AFunc: 要素ごとの演算関数
// [戻値] 演算適用後の新しい配列
// [使用例]
//   Target: [[1, 2], [3, 4]] の場合
//   C := TFlexArray<Integer>.Broadcast(5, Target,
//     function(X, Y: Integer): Integer
//     begin
//       Result := X * Y;
//     end);
//   結果: [[5, 10], [15, 20]]
//////////////////////////////////////////////////////////////////////////////////////
class function TFlexArray<T>.Broadcast(Value: T; const Target: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>;
var
  i: Integer;
begin
  Result := TFlexArray<T>.CreateFromRange(Target.GetRanges);
  for i := 0 to Result.TotalSize - 1 do
    Result.Data.FArray[i] := AFunc(Value, Target.Data.FArray[i]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2つの配列を次元をあわせて演算する
// [引数] Source: 演算対象配列, Target: 演算対象配列, AFunc: 要素ごとの演算関数
// [戻値] 演算適用後の新しい配列
// [使用例]
//   A: [1, 2, 3]
//   B: [[1, 2, 3], [4, 5, 6]] の場合
//   C := TFlexArray<Integer>.Broadcast(A, B,
//     function(X, Y: Integer): Integer
//     begin
//       Result := X * Y;
//     end);
//   結果: [[1, 4, 9], [4, 10, 18]]
// NumPy相当:
//   A = np.array([1, 2, 3])
//   B = np.array([[1, 2, 3], [4, 5, 6]])
//   C = A * B  # ブロードキャストによる要素ごとの積
//////////////////////////////////////////////////////////////////////////////////////
class function TFlexArray<T>.Broadcast(const Source: TFlexArray<T>; const Target: TFlexArray<T>; AFunc: TOperationFunc<T>): TFlexArray<T>;
begin
  Result := BroadcastCore(Source, Target, AFunc);
end;

end.
