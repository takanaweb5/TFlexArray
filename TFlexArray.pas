unit TFlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math,
  System.Rtti,    // TValue のため
  System.TypInfo; // tkString などの型判定（TValue.Kind）のため

// Range types
type
  TFlexRange = TArray<Integer>;  // [Low, High] のペア
  TFlexRanges = TArray<TFlexRange>;  // [[Low1, High1], [Low2, High2], ...]
  TCoords = array of Integer;  // 座標配列 [x, y, z, ...]
  
  // TFlexArray用の次元情報（グローバル化）
  TFlexDimension = record
    Low, High, Stride: NativeInt;
    function Len: NativeInt; inline;
  end;
  
  TFlexDimensions = TArray<TFlexDimension>;
  
  // TFlexArray用の列挙子（グローバル化）
  TFlexArrayEnumerator<T> = class
  private
    FData: TArray<T>;
    FTotalSize: NativeInt;
    FIndex: NativeInt;
    function GetCurrent: T;
  public
    constructor Create(const AData: TArray<T>; ASize: NativeInt);
    property Current: T read GetCurrent;
    function MoveNext: Boolean;
  end;
  TFlexRangeHelper = record helper for TFlexRange
  public
    function Low:  Integer; inline;
    function High:  Integer; inline;
    function Length: Integer; inline;
  end;

  TFlexDimensionsHelper = record helper for TFlexDimensions
  private
    function GetDimension(Index: Integer): TFlexDimension; inline;
    procedure SetDimension(Index: Integer; const Value: TFlexDimension); inline;
  public
    class function Create(Count: Integer): TFlexDimensions; static;
    function Count: Integer; inline;
    function TotalSize: NativeInt;
    function ToString: string;
    property Items[Index: Integer]: TFlexDimension read GetDimension write SetDimension;
  end;
  
  TFlexRangesHelper = record helper for TFlexRanges
    class function Create(const ARanges: array of TFlexRange): TFlexRanges; static;
    function Count: Integer; inline;
    function TotalSize: NativeInt; inline;
  public
  end;

  // 非破壊的Map用コールバック
  TMappedFunc<T, TResult> = reference to function(const Value: T; const Coords: TCoords): TResult;
  TMappedFuncValue<T, TResult> = reference to function(const Value: T): TResult;
  // 破壊的Map用コールバック
  TMapFunc<T> = reference to function(const Value: T; const Coords: TCoords): T;
  TMapFuncValue<T> = reference to function(const Value: T): T;
  TFilterFunc<T> = reference to function(const Value: T; const Coords: TCoords): Boolean;
  TFilterFuncValue<T> = reference to function(const Value: T): Boolean;

type
  TFlexArray<T> = record
  private
  private
    FData: TArray<T>;       // 実データ保持用
    // FBaseOffset: NativeInt; // Viewとしての論理的な開始位置
    FDims: TFlexDimensions;  // 次元情報（1ベース、0番目は未使用）
    FTotalSize: NativeInt; // 全要素数
    FIsView: Boolean;

    function GetCoords(LinearIndex: NativeInt): TCoords;
    function GetOffset(const Coords: array of Integer): NativeInt;
    function GetValue(const Coords: array of Integer): T;
    procedure SetValue(const Coords: array of Integer; const Value: T);
    procedure InitializeFromRanges(const Ranges: TFlexRanges);
    function ValueToStr(const V: T): string;
    procedure CheckDimension(ExpectedDim: Integer);
    procedure CheckViewMode;
    procedure NormalizeToBaseIndex(TargetBase: Integer);
    function GetCompatibleBaseIndex(const Another: TFlexArray<T>): Integer;
    procedure IncCoords(var CurrentCoords: TCoords;
      const Ranges: TFlexRanges);
    procedure InitializeCoords(var Coords: TCoords);
    function GetElement(Index: NativeInt): T; inline;
    procedure SetElement(Index: NativeInt; const Value: T); inline;
    function ConcatEqualDim(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
    function PromoteDimension(const Source: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
    function GetRanges: TFlexRanges;
{$IFDEF FLEXARRAY_ENABLE_LEN}
    function Len(Dim: Integer): NativeInt;
{$ENDIF}
  public

    constructor Create(const AShapes: array of Integer; ABaseIndex: Integer); overload;
    constructor Create(ASize: Integer; ABaseIndex: Integer); overload;
    constructor CreateMatrix(ARows, ACols: Integer; ABaseIndex: Integer); overload;
    constructor CreateFromRange(const ARange: TFlexRange); overload;
    constructor CreateFromRange(const ARanges: TFlexRanges); overload;
    constructor CreateFromArray(const ASrc: TArray<T>; ABaseIndex: Integer); overload;
    constructor CreateFromFlexArray(const ASrc: TFlexArray<T>); overload;
    constructor ViewFromArray(const ASrc: TArray<T>; ABaseIndex: Integer); overload;

    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function GetDimensionCount: Integer; inline;
    property Items[const Coords: array of Integer]: T read GetValue write SetValue; default;
    property Elements[Index: NativeInt]: T read GetElement write SetElement;
    property DimensionCount: Integer read GetDimensionCount;

    property TotalSize: NativeInt read FTotalSize;
    procedure Reshape(const AShapes: array of Integer; ABaseIndex: Integer);
    procedure ReshapeMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
    procedure ReshapeVector(ABaseIndex: Integer = 1);
    procedure ReshapeRange(const ARange: TFlexRange); overload; // 1D
    procedure ReshapeRange(const ARanges: TFlexRanges); overload; // nD

    function ToVector(): TArray<T>;
    function ToString(): string;
    function ToRangesString(): string;
    function Transpose(): TFlexArray<T>; overload;
    function Transpose(const NewDims: array of Integer): TFlexArray<T>; overload;

    function ChooseSlice(Index: Integer): T; overload;
    function ChooseSlice(Dim: Integer; Index: Integer): TFlexArray<T>; overload;
    function ChooseRow(RowIndex: Integer): TFlexArray<T>;
    function ChooseCol(ColIndex: Integer): TFlexArray<T>;

    function Concat(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
    function HStack(const Another: TFlexArray<T>): TFlexArray<T>;
    function VStack(const Another: TFlexArray<T>): TFlexArray<T>;

    function AppendArray(const Another: TFlexArray<T>): TFlexArray<T>; overload;
    function AppendArray(const Another: TArray<T>): TFlexArray<T>; overload;

    function GetEnumerator: TFlexArrayEnumerator<T>;

    // Swiftスタイル: 非破壊的(-ed) / 破壊的(原形)
    procedure Map(const AFunc: TMapFunc<T>); overload;
    procedure Map(const AFunc: TMapFuncValue<T>); overload;
    function Mapped<TResult>(const AFunc: TMappedFunc<T, TResult>): TFlexArray<TResult>; overload;
    function Mapped<TResult>(const AFunc: TMappedFuncValue<T, TResult>): TFlexArray<TResult>; overload;
    function Filter(const AFunc: TFilterFunc<T>): TArray<T>; overload;
    function Filter(const AFunc: TFilterFuncValue<T>): TArray<T>; overload;
  end;

implementation

{ TFlexArray<T> }

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
// [概要] 範囲配列から配列構造を初期化
// [引数] 各次元の範囲配列
// [戻値] なし
// [使用例] InitializeFromRanges([[1, 10], [1, 10]])
// [備考] 各次元の範囲配列は [Low, High] のペアになっていること
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.InitializeFromRanges(const Ranges: TFlexRanges);
var
  i: Integer;
  CurrentStride: NativeInt;
begin
  SetLength(FDims, Ranges.Count);  // 完全0ベース化
  CurrentStride := 1;

  // 後ろの次元から歩幅を計算することで多次元に対応
  for i := Ranges.Count - 1 downto 0 do
  begin
    // 引数の配列が [Low, High] のペアになっているか念のためチェック
    if System.Length(Ranges[i]) <> 2 then
      raise Exception.CreateFmt('TFlexArray: 第 %d 次元の指定が [Low, High] のペアではありません。', [i + 1]);

    // ★ ここで開始 > 終了をチェック
    if Ranges[i].Low > Ranges[i].High then
      raise Exception.CreateFmt('TFlexArray: 第 %d 次元の範囲が不正です (Low:%d > High:%d)', [i + 1, Ranges[i].Low, Ranges[i].High]);

    FDims[i].Low    := Ranges[i].Low;    // 0ベースで格納
    FDims[i].High   := Ranges[i].High;
    FDims[i].Stride := CurrentStride;

    // 全要素数を累積計算
    CurrentStride := CurrentStride * Ranges[i].Length;
  end;

  FTotalSize := CurrentStride;
  if not FIsView then
    SetLength(FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 汎用・多次元コンストラクタ
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.Create([3, 4], 1)  // 1始まりの3x4行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.Create(const AShapes: array of Integer; ABaseIndex: Integer);
var
  i: Integer;
  Ranges: TFlexRanges;
  L, H: Integer;
begin
  SetLength(Ranges, System.Length(AShapes));
  for i := 0 to System.High(AShapes) do
  begin
    L := ABaseIndex;
    H := ABaseIndex + AShapes[i] - 1;
    Ranges[i] := [L, H];
  end;
  InitializeFromRanges(Ranges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元用コンストラクタ
// [引数] 配列サイズ, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.Create(10, 1)  // 1-10の10要素配列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.Create(ASize: Integer; ABaseIndex: Integer);
var
  L, H: Integer;
begin
  L := ABaseIndex;
  H := ABaseIndex + ASize - 1;
  InitializeFromRanges([[L, H]]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元用範囲指定コンストラクタ
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([-5, 5])  // -5から5までの11要素
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const ARange: TFlexRange);
begin
  InitializeFromRanges([ARange]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元用範囲指定コンストラクタ
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([[1, 3], [1, 2]])  // 3x2行列
//          静的配列の宣言例に相当 array[1..3, 1..2] of Integer;
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const ARanges: TFlexRanges);
begin
  InitializeFromRanges(ARanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] FlexArrayからFlexArrayを生成する
// [引数] 元のFlexArray
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromFlexArray(const ASrc: TFlexArray<T>);
begin
  // 構造情報をコピー
  SetLength(FDims, ASrc.FDims.Count);
  TArray.Copy<TFlexDimension>(ASrc.FDims, FDims, ASrc.FDims.Count);

  FTotalSize := ASrc.FTotalSize;
  SetLength(FData, FTotalSize);
  TArray.Copy<T>(ASrc.FData, FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 動的一次元配列からFlexArrayを生成する
// [引数] 元の動的配列, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromArray(arr, 1)
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromArray(const ASrc: TArray<T>; ABaseIndex: Integer);
var
  L, H: Integer;
begin
  L := ABaseIndex;
  H := ABaseIndex + System.Length(ASrc) - 1;
  InitializeFromRanges([[L, H]]);

  // データをコピーして実体化
  SetLength(FData, FTotalSize);
  TArray.Copy<T>(ASrc, FData, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 参照生成コンストラクタ
// [引数] 元の動的配列, 開始インデックス
// [戻値] なし
// [備考] CreateFromArrayと異なり、変更は元の配列に反映される
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.ViewFromArray(const ASrc: TArray<T>; ABaseIndex: Integer);
var
  L, H: Integer;
begin
  FIsView := True;
  L := ABaseIndex;
  H := ABaseIndex + System.Length(ASrc) - 1;
  InitializeFromRanges([[L, H]]);

  // データを参照して同一化
  FData := ASrc;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用コンストラクタ
// [引数] 行数, 列数, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateMatrix(3, 4, 1)  // 1始まりの3x4行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
var
  L, H1, H2: Integer;
begin
  L := ABaseIndex;
  H1 := ABaseIndex + ARows - 1;
  H2 := ABaseIndex + ACols - 1;
  InitializeFromRanges([[L, H1], [L, H2]]);
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
      '次元エラー: %d次元配列専用の操作ですが、現在は %d次元です。',
      [ExpectedDim, ActualDim]
    );
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
  if FData = nil then
  begin
    // 数値型のみ許可
    Val := TValue.From<T>(default(T));
    if Val.Kind in [tkInteger, tkFloat] then
      Exit; // 数値型はOK

    // それ以外はNG
    raise Exception.Create('Viewモードの配列は変更できません。CreateFromFlexArrayでコピーしてから使用してください。');
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定されたベースインデックスに正規化
// [引数] TargetBase - 目標のベースインデックス（0または1）
// [戻値] なし
// [備考] データは保持したまま次元情報のみ変更
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.NormalizeToBaseIndex(TargetBase: Integer);
var
  i: Integer;
  Shapes: TArray<Integer>;
begin
  // 現在の形状を取得
  SetLength(Shapes, Self.DimensionCount);
  for i := 1 to Self.DimensionCount do
    Shapes[i - 1] := Self.FDims[i - 1].Len; // FDimsは0ベース

  // Reshapeを呼び出し（要素数チェックは不要）
  Reshape(Shapes, TargetBase);
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
// [概要] 指定行1次元を取得
// [引数] 行インデックス
// [戻値] 行の1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseRow(RowIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := ChooseSlice(1, RowIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定列を1次元で取得
// [引数] 列インデックス
// [戻値] 列の1次元配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseCol(ColIndex: Integer): TFlexArray<T>;
begin
  CheckDimension(2);
  Result := ChooseSlice(2, ColIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の要素を取得
// [引数] インデックス
// [戻値] 指定位置の要素<T>
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseSlice(Index: Integer): T;
begin
  CheckDimension(1);
  Result := Self[[Index]]
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元をスライスして取得
// [引数] 次元番号, 取得インデックス
// [戻値] スライス配列（元の次元数より1次元少ない配列が生成されます）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseSlice(Dim: Integer; Index: Integer): TFlexArray<T>;
var
  i, j, d: Integer;
  NewRanges: TFlexRanges;
  DestCoords, SrcCoords: TCoords;
begin
  // NewRangesの計算（指定次元を除外）
  // 3次元配列 [1..3, 1..4, 1..5] から Dim=2 のスライスを取る場合
  // → NewRanges = [[1,3], [1,5]] となり、2次元配列が生成される
  SetLength(NewRanges, Self.DimensionCount - 1);
  d := 0;
  for i := 1 to Self.DimensionCount do
  begin
    if i <> Dim then
    begin
      NewRanges[d] := [Low(i), High(i)];
      Inc(d);
    end;
  end;
  Result := TFlexArray<T>.CreateFromRange(NewRanges);

  // Resultの各要素に対応するSelfの該当Index要素をコピー
  SetLength(SrcCoords, DimensionCount);
  Result.InitializeCoords(DestCoords);
  for i := 0 to Result.FTotalSize - 1 do
  begin
    d := 0; // DestCoords用のインデックス(元の次元数より１つ少ない)

    // 元の次元数分ループ
    for j := 0 to System.High(SrcCoords) do
    begin
      if (j + 1) = Dim then
        SrcCoords[j] := Index // 指定された次元は固定値
      else
      begin
        SrcCoords[j] := DestCoords[d];
        Inc(d);
      end;
    end;

    Result.Elements[i] := Self.Elements[GetOffset(SrcCoords)];
    Result.IncCoords(DestCoords, NewRanges);
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

  // Result := FBaseOffset; // 0 ではなく FBaseOffset から開始
  Result := 0;
  for i := 0 to Self.DimensionCount - 1 do
  begin
    // FDimsは0ベース、Coordsは0ベース
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
// [使用例] 1次元の場合: (2, 2, 3)
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
      2: Rows[i] := ChooseRow(r).ToString;
      3: Rows[i] := Format('[Page %d]' + sLineBreak + '  %s', [r, ChooseSlice(1, r).ToString]);
    end;
    Inc(i);
  end;

  // フォーマット処理
  case Self.DimensionCount of
    1: Result := '(' + String.Join(', ', Rows) + ')';
    2: Result := '(' + sLineBreak + '  ' + String.Join(',' + sLineBreak + '  ', Rows) + sLineBreak + ')';
    3: Result := '(' + sLineBreak + '  ' + String.Join(',' + sLineBreak + '  ', Rows) + sLineBreak + ')';
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
// [概要] 範囲情報を文字列に変換
// [引数] なし
// [戻値] 範囲情報の文字列表現 例：[1990..1991, 1..12, 1..31]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ToRangesString(): string;
begin
  Result := FDims.ToString;
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
  DestCoords, SrcCoords: TCoords;
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

  // Resultの各要素に対応するSelfの転置後要素をコピー
  Result.InitializeCoords(DestCoords);
  SetLength(SrcCoords, DimensionCount);
  for i := 0 to Result.FTotalSize - 1 do
  begin
    for d := 0 to DimensionCount - 1 do
    begin
      // 次元を入れ替え（注意：1-basedインデックスを0-basedインデックスに変換）
      SrcCoords[NewDims[d] - 1] := DestCoords[d];
    end;

    Result.Elements[i] := Self.Elements[GetOffset(SrcCoords)];
    Result.IncCoords(DestCoords, NewRanges);
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

{$IFDEF FLEXARRAY_ENABLE_LEN}
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
{$ENDIF}

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
// [概要] 列挙子を取得
// [引数] なし
// [戻値] 列挙子オブジェクト
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetEnumerator: TFlexArrayEnumerator<T>;
begin
  Result := TFlexArrayEnumerator<T>.Create(FData, FTotalSize);
end;

// function TFlexArray<T>.Each(): TFlexEnumerator<T>;
// begin
//   // 1次元用：要素を列挙
//   if (Dimensions = 1) or (Dimensions = 0) then
//     Result := TFlexEnumerator<T>.Create(@FData[0], FTotalSize)
//   else
//     raise Exception.Create('多次元配列です。Each(次元) を使用してください。');
// end;

// function TFlexArray<T>.Each(Dimension: Integer): TDimensionEnumerator<T>;
// begin
//   // 多次元用：部分配列を列挙
//   if (Dimension < 1) or (Dimension > Dimensions) then
//     raise Exception.CreateFmt('次元 %d は範囲外です（1～%d）', [Dimension, Dimensions]);
  
//   // 1次元配列でEach(1)の場合は要素を列挙
//   if (Dimensions = 1) and (Dimension = 1) then
//     raise Exception.Create('1次元配列では Each() を使用してください。');
    
//   Result := TDimensionEnumerator<T>.Create(Self, Dimension);
// end;

{ TFlexArrayEnumerator<T> }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を初期化
// [引数] データの先頭ポインタ, 全要素数
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArrayEnumerator<T>.Create(const AData: TArray<T>; ASize: NativeInt);
begin
  FData := AData;
  FTotalSize := ASize;
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

{ TFlexArray<T>.TDimensionEnumerator }

// constructor TFlexArray<T>.TDimensionEnumerator<T>.Create(Source: TFlexArray<T>; Dimension: Integer);
// begin
//   FSource := Source;
//   FDimension := Dimension;
//   FIndex := Source.Low(Dimension) - 1; // 開始位置の前から
// end;

// function TFlexArray<T>.TDimensionEnumerator<T>.MoveNext: Boolean;
// begin
//   Inc(FIndex);
//   Result := FIndex <= FSource.High(FDimension);
// end;

// function TFlexArray<T>.TDimensionEnumerator<T>.GetCurrent: TFlexArray<T>;
// begin
//   Result := CreateSlice(FIndex);
// end;

// function TFlexArray<T>.TDimensionEnumerator<T>.CreateSlice(FixedIndex: Integer): TFlexArray<T>;
// begin
//   Result := FSource.ChooseSlice(FDimension, FixedIndex);
// end;


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
// [引数] 現在の座標配列, 各次元の範囲配列
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.IncCoords(var CurrentCoords: TCoords; const Ranges: TFlexRanges);
var
  d: Integer;
begin
  // 一番右側の次元（最小単位）から順にチェック
  for d := system.High(CurrentCoords) downto 0 do
  begin
    Inc(CurrentCoords[d]); // 1つ進める

    // 上限(High)を超えていないかチェック
    // Ranges[d] は [Low, High] の 2要素配列を想定
    if CurrentCoords[d] <= Ranges[d][1] then
    begin
      // 繰り上がりが発生しなかったので、ここで終了
      Exit;
    end
    else
    begin
      // 上限を超えたので、現在の次元を最小値(Low)にリセットし、
      // ループを継続して一つ左の次元（上位桁）を Inc する
      CurrentCoords[d] := Ranges[d][0];
    end;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 同一次元配列の結合
// [引数] 結合対象の配列, 結合する次元
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ConcatEqualDim(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
var
  DimIdx: Integer;
  NewRanges: TFlexRanges;
  DestCoords: TCoords;
  SelfSizeAlongDim: Integer;
  i, d: Integer;
  L, H: Integer;
begin

  // 1-based to 0-based
  DimIdx := TargetDim - 1;

  // 次元のサイズチェック
  for d := 0 to Self.DimensionCount - 1 do
  begin
    if d <> DimIdx then
    begin
      // 結合しない次元はサイズが一致している必要がある
      if Self.FDims[d].Len <> Another.FDims[d].Len then
        raise Exception.CreateFmt('ConcatEqualDim: 次元%dのサイズが一致しません。Self=%d, Another=%d', 
          [d+1, Self.FDims[d].Len, Another.FDims[d].Len]);
    end;
  end;

  // NewRangesの計算
  SetLength(NewRanges, Self.DimensionCount);
  for d := 0 to Self.DimensionCount - 1 do
  begin
    L := Self.FDims[d].Low;
    if d = DimIdx then
      // 結合する次元だけ、自分と相手のサイズを足し合わせる
      H := Self.FDims[d].High + Another.FDims[d].Len
    else
      H := Self.FDims[d].High;
    NewRanges[d] := [L, H];
  end;
  Result := TFlexArray<T>.CreateFromRange(NewRanges);

  // Self のデータを埋める
  Result.InitializeCoords(DestCoords);
  for i := 0 to Self.FTotalSize - 1 do
  begin
    Result.Elements[i] := Self.Elements[GetOffset(DestCoords)];
    Result.IncCoords(DestCoords, NewRanges);
  end;

  // Another のデータを埋める
  SelfSizeAlongDim := Self.FDims.Items[DimIdx].Len;
  for i := Self.FTotalSize to Result.FTotalSize - 1 do
  begin
    DestCoords[DimIdx] := DestCoords[DimIdx] - SelfSizeAlongDim;
    Result.Elements[i] := Another.Elements[GetOffset(DestCoords)];
    DestCoords[DimIdx] := DestCoords[DimIdx] + SelfSizeAlongDim;
    Result.IncCoords(DestCoords, NewRanges);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列を1次元だけ昇格させる
// [引数] 元の配列, 次元を追加する位置
// [戻値] 1次元増えた配列
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
function TFlexArray<T>.PromoteDimension(const Source: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
var
  NewShapes: TArray<Integer>;
  i, j: Integer;
begin
  // TargetDimのチェック
  if (TargetDim < 1) or (TargetDim > Source.DimensionCount + 1) then
    raise Exception.CreateFmt('PromoteDimension: TargetDimは1から%dの範囲である必要があります', [Source.DimensionCount + 1]);

  // 新しい形状を準備（1次元だけ増やす）
  SetLength(NewShapes, Source.DimensionCount + 1);
  j := 0;
  for i := 0 to System.High(NewShapes) do  // 新しい次元数分ループ
  begin
    if i = TargetDim - 1 then
      NewShapes[i] := 1  // 挿入位置はサイズ1
    else
    begin
      NewShapes[i] := Source.FDims.Items[j].Len;
      Inc(j);
    end;
  end;

  // データはコピーせず、ビューとして再解釈
  Result := TFlexArray<T>.ViewFromArray(Source.FData, 1);
  Result.Reshape(NewShapes, 1);
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
    raise Exception.CreateFmt('Concat: TargetDimは1から%dの範囲である必要があります', [Self.DimensionCount]);


  // 次元数のチェック（Another - Self = [0, 1] のみ許可）
  DimDiff := Self.DimensionCount - Another.DimensionCount;
  if not (Self.DimensionCount - Another.DimensionCount in [0, 1]) then
    raise Exception.CreateFmt('Concat: %d次元配列と%d次元配列は結合できません。AnotherはSelfと同次元か1次元少ない必要があります', 
      [Self.DimensionCount, Another.DimensionCount]);

  // ベースインデックスのチェック（すべて一致しないと例外）と取得
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
    AnotherReady := PromoteDimension(AnotherReady, TargetDim);

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
begin
  CheckDimension(1);
  Result := Self.Concat(TFlexArray<T>.ViewFromArray(Another, 1), 1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の形状を変更し、データを保持したまま次元構造を再定義
// [引数] 各次元の形状配列, 開始インデックス
// [戻値] なし
// [使用例] Matrix.Reshape([3, 2], 1)  // 1始まりの3x2行列に再定義
// [備考] 変更前後の全要素数が一致する必要あり
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Reshape(const AShapes: array of Integer; ABaseIndex: Integer);
var
  i: Integer;
  NewTotalSize: NativeInt;
  NewRanges: TFlexRanges;
begin
  // 1. 新しい形状の全要素数を計算
  NewTotalSize := 1;
  for i := 0 to System.High(AShapes) do
    NewTotalSize := NewTotalSize * AShapes[i];
  
  // 2. 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'Reshape: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));
  
  // 3. 新しい範囲配列を生成
  SetLength(NewRanges, System.Length(AShapes));
  for i := 0 to System.High(AShapes) do
    NewRanges[i] := [ABaseIndex, ABaseIndex + AShapes[i] - 1];
  
  // 4. 次元情報のみ更新（データは保持）
  InitializeFromRanges(NewRanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 行列形状に再定義（2次元専用）
// [引数] 行数, 列数, 開始インデックス
// [戻値] なし
// [使用例] Matrix.ReshapeMatrix(3, 4, 1)  // 1始まりの3x4行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
begin
  Reshape([ARows, ACols], ABaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] ベクトル形状に再定義（1次元専用）
// [引数] 開始インデックス
// [戻値] なし
// [使用例] Vector.ReshapeVector(1)  // 1始まりのベクトルに再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeVector(ABaseIndex: Integer);
begin
  Reshape([FTotalSize], ABaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元範囲指定による再定義
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] Vector.ReshapeRange([-5, 5])  // -5から5までの範囲に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const ARange: TFlexRange);
var
  NewTotalSize: NativeInt;
begin
  // 1. 新しい範囲の全要素数を計算
  NewTotalSize := ARange.Length;
  
  // 2. 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'ReshapeRange: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));
  
  // 3. 次元情報のみ更新（データは保持）
  InitializeFromRanges([ARange]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元範囲指定による再定義
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] Tensor.ReshapeRange([[1, 3], [1, 2]])  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const ARanges: TFlexRanges);
var
  i: Integer;
  NewTotalSize: NativeInt;
begin
  // 1. 新しい範囲の全要素数を計算
  NewTotalSize := 1;
  for i := 0 to System.High(ARanges) do
    NewTotalSize := NewTotalSize * ARanges[i].Length;
  
  // 2. 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'ReshapeRange: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));
  
  // 3. 次元情報のみ更新（データは保持）
  InitializeFromRanges(ARanges);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を変換して新しい配列を返す（非破壊的）
// [引数] 変換関数（値と座標を引数に取り、新しい値を返す）
// [戻値] 変換後の新しい配列
// [使用例] B := A.Mapped<Integer>(function(Value: string; Coords): Integer
//           begin
//             Result := Length(Value) + Coords[0] + Coords[1];
//           end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Mapped<TResult>(const AFunc: TMappedFunc<T, TResult>): TFlexArray<TResult>;
var
  i: Integer;
  CurrentCoords: TCoords;
  SelfRanges: TFlexRanges;
begin
  // 同じ形状で新しい配列を作成
  SelfRanges := GetRanges;
  Result := TFlexArray<TResult>.CreateFromRange(SelfRanges);

  InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    Result.Elements[i] := AFunc(Self.Elements[i], CurrentCoords);
    IncCoords(CurrentCoords, SelfRanges);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を変換して新しい配列を返す（非破壊的、Simple版）
// [引数] 変換関数（値のみを引数に取り、新しい値を返す）
// [戻値] 変換後の新しい配列
// [使用例] B := A.Mapped<Integer>(function(Value: string): Integer
//           begin
//             Result := Length(Value);
//           end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Mapped<TResult>(const AFunc: TMappedFuncValue<T, TResult>): TFlexArray<TResult>;
var
  i: Integer;
begin
  // 同じ形状で新しい配列を作成
  Result := TFlexArray<TResult>.CreateFromRange(GetRanges);

  for i := 0 to FTotalSize - 1 do
  begin
    Result.Elements[i] := AFunc(Self.Elements[i]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を直接変更する（破壊的）
// [引数] 変換関数（値と座標を引数に取り、新しい値を返す）
// [戻値] なし
// [使用例] A.Map(function(Value: string; Coords): string
//           begin
//             Result := UpperCase(Value) + '_' + IntToStr(Coords[0]);
//           end);
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Map(const AFunc: TMapFunc<T>);
var
  i: Integer;
  CurrentCoords: TCoords;
  SelfRanges: TFlexRanges;
begin
  CheckViewMode; // 数値型チェック

  SelfRanges := GetRanges;
  InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    Self.Elements[i] := AFunc(Self.Elements[i], CurrentCoords);
    IncCoords(CurrentCoords, SelfRanges);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の各要素を直接変更する（破壊的、Simple版）
// [引数] 変換関数（値のみを引数に取り、新しい値を返す）
// [戻値] なし
// [使用例] A.Map(function(Value: string): string
//           begin
//             Result := UpperCase(Value);
//           end);
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.Map(const AFunc: TMapFuncValue<T>);
var
  i: Integer;
begin
  CheckViewMode; // 数値型チェック

  for i := 0 to FTotalSize - 1 do
  begin
    Self.Elements[i] := AFunc(Self.Elements[i]);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素をフィルタリングして条件に合う要素のみを返す（非破壊的、座標付き）
// [引数] フィルタ関数（値と座標を引数に取り、条件を返す）
// [戻値] 条件に合う要素の配列
// [使用例] Result := A.Filter(function(Value: Integer; Coords): Boolean
//           begin
//             Result := (Value > 0) and (Coords[0] mod 2 = 0);
//           end);
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Filter(const AFunc: TFilterFunc<T>): TArray<T>;
var
  i, Count: Integer;
  CurrentCoords: TCoords;
  SelfRanges: TFlexRanges;
begin
  SelfRanges := GetRanges;
  // まず結果をカウント
  Count := 0;
  InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    if AFunc(Self.Elements[i], CurrentCoords) then
      Inc(Count);
    IncCoords(CurrentCoords, SelfRanges);
  end;

  // 配列を確保して格納
  SetLength(Result, Count);
  Count := 0;
  InitializeCoords(CurrentCoords);
  for i := 0 to FTotalSize - 1 do
  begin
    if AFunc(Self.Elements[i], CurrentCoords) then
    begin
      Result[Count] := Self.Elements[i];
      Inc(Count);
    end;
    IncCoords(CurrentCoords, SelfRanges);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の要素をフィルタリングして条件に合う要素のみを返す（非破壊的、Simple版）
// [引数] フィルタ関数（値のみを引数に取り、条件を返す）
// [戻値] 条件に合う要素の配列
// [使用例] Result := A.Filter(function(Value: Integer): Boolean
//           begin
//             Result := Value > 0;
//           end);
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

  // 配列を確保して格納
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
function TFlexRangeHelper.Length: Integer;
begin
  Result := High - Low + 1;
end;

{ TFlexRangesHelper }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangesの静的コンストラクタ
// [引数] 範囲配列 [[Low1, High1], [Low2, High2], ...]
// [戻値] TFlexRanges
// [使用例] Ranges := TFlexRanges.Create([[1, 3], [1, 2]])
//////////////////////////////////////////////////////////////////////////////////////
class function TFlexRangesHelper.Create(const ARanges: array of TFlexRange): TFlexRanges;
var
  i: Integer;
begin
  // 入力チェック
  for i := 0 to High(ARanges) do
  begin
    if ARanges[i].Length <> 2 then
      raise Exception.CreateFmt('TFlexRanges.Create: %d番目の範囲が[Low, High]の形式ではありません', [i]);
    if ARanges[i].Low > ARanges[i].High then
      raise Exception.CreateFmt('TFlexRanges.Create: %d番目の範囲が無効です。Low(%d) > High(%d)', 
        [i, ARanges[i].Low, ARanges[i].High]);
  end;
  
  SetLength(Result, Length(ARanges));
  for i := 0 to High(ARanges) do
    Result[i] := ARanges[i];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangesの次元数を取得
// [引数] なし
// [戻値] 次元数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexRangesHelper.Count: Integer;
begin
  Result := Length(Self);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexRangesの全要素数を取得
// [引数] なし
// [戻値] 全要素数 (各次元のサイズの積)
// [使用例] [[1, 3], [1, 2]] → 3 * 2 = 6
//////////////////////////////////////////////////////////////////////////////////////
function TFlexRangesHelper.TotalSize: NativeInt;
var
  i: Integer;
begin
  Result := 1;
  for i := 0 to High(Self) do
    Result := Result * Self[i].Length;
end;

{ TFlexDimensionsHelper }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexDimensionsの次元数を取得
// [引数] なし
// [戻値] 次元数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexDimensionsHelper.Count: Integer;
begin
  Result := Length(Self);
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

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexDimensionsの全要素数を取得
// [引数] なし
// [戻値] 全要素数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexDimensionsHelper.TotalSize: NativeInt;
var
  i: Integer;
begin
  Result := 1;
  for i := 0 to Count - 1 do
    Result := Result * Self[i].Len;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] TFlexDimensionsを文字列化
// [引数] なし
// [戻値] 次元情報の文字列表現  例：[1990..1991, 1..12, 1..31]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexDimensionsHelper.ToString: string;
var
  i: Integer;
  Parts: TArray<string>;
begin
  SetLength(Parts, Count);
  for i := 0 to Count - 1 do
    Parts[i] := Format('%d..%d', [Self[i].Low, Self[i].High]);
  Result := '[' + String.Join(', ', Parts) + ']';
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定された次元数でTFlexDimensionsを作成
// [引数] 次元数
// [戻値] 新しいTFlexDimensions
//////////////////////////////////////////////////////////////////////////////////////
class function TFlexDimensionsHelper.Create(Count: Integer): TFlexDimensions;
begin
  SetLength(Result, Count);
end;

end.
