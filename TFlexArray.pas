unit TFlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math,
  System.Rtti,    // TValue のため
  System.TypInfo; // tkString などの型判定（TValue.Kind）のため
type
  TFlexArray<T> = record
  private
    type
      TDimension = record
        Low, High, Stride: NativeInt;
        function Len: NativeInt; inline;
      end;
    type
      // 内部専用の列挙子。これなら制約エラーも出ず、ポインタを直接スキャンできる。
      TFlexEnumerator<T> = class
      private
        FHead: Pointer;
        FTotalSize: NativeInt;
        FIndex: NativeInt;
        function GetCurrent: T;
      public
        constructor Create(AHead: Pointer; ASize: NativeInt);
        property Current: T read GetCurrent;
        function MoveNext: Boolean;
      end;
      
      // // 次元指定列挙子。指定された次元に沿って部分配列を列挙する
      // TDimensionEnumerator<T> = class
      // private
      //   FSource: TFlexArray<T>;
      //   FDimension: Integer;
      //   FIndex: Integer;
      //   function GetCurrent: TFlexArray<T>;
      //   function CreateSlice(FixedIndex: Integer): TFlexArray<T>;
      // public
      //   constructor Create(Source: TFlexArray<T>; Dimension: Integer);
      //   property Current: TFlexArray<T> read GetCurrent;
      //   function MoveNext: Boolean;
      // end;
  private
    FData: TArray<T>;       // 実データ保持用
    // FBaseOffset: NativeInt; // Viewとしての論理的な開始位置
    FHead: Pointer;         // 物理先頭ポインタ
    FDims: TArray<TDimension>;
    FTotalSize: NativeInt;

    function GetCoords(LinearIndex: NativeInt): TArray<Integer>;
    function GetOffset(const Indices: array of Integer): NativeInt;
    function GetValue(const Indices: array of Integer): T;
    procedure SetValue(const Indices: array of Integer; const Value: T);
    function InternalSetup(const Ranges: array of TArray<Integer>): NativeInt;
    function ValueToStr(const V: T): string;
    procedure CheckDimension(ExpectedDim: Integer);
    procedure IncCoords(var CurrentCoords: TArray<Integer>;
      const Ranges: array of TArray<Integer>);
    function GetMinCoords: TArray<Integer>;
    procedure AddValue(const Value: T);
{$IFDEF FLEXARRAY_ENABLE_LEN}
    function Len(Dim: Integer): NativeInt;
{$ENDIF}
  public

    constructor Create(const AShapes: array of Integer; ABaseIndex: Integer); overload;
    constructor Create(ASize: Integer; ABaseIndex: Integer); overload;
    constructor CreateMatrix(ARows, ACols: Integer; ABaseIndex: Integer); overload;
    constructor CreateFromRange(const ARange: TArray<Integer>); overload;
    constructor CreateFromRange(const ARanges: array of TArray<Integer>); overload;
    constructor CreateFromArray(const ASrc: TArray<T>; ABaseIndex: Integer); overload;
    constructor CreateFromFlexArray(const ASrc: TFlexArray<T>); overload;
    constructor ViewFromArray(const ASrc: TArray<T>; ABaseIndex: Integer); overload;

    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function Dimensions: Integer;
    property Items[const Indices: array of Integer]: T read GetValue write SetValue; default;
    property TotalSize: NativeInt read FTotalSize;

    procedure Reshape(const AShapes: array of Integer; ABaseIndex: Integer);
    procedure ReshapeMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
    procedure ReshapeRange(const ARange: TArray<Integer>); overload; // 1D
    procedure ReshapeRange(const ARanges: array of TArray<Integer>); overload; // nD

    function ToVector(): TArray<T>;
    function ToString(): string;
    function ToRangesString(): string;
    function Transpose(): TFlexArray<T>; overload;
    function Transpose(const NewDimensions: array of Integer): TFlexArray<T>; overload;

    function ChooseSlice(Index: Integer): T; overload;
    function ChooseSlice(Dimension: Integer; Index: Integer): TFlexArray<T>; overload;
    function ChooseRow(RowIndex: Integer): TFlexArray<T>;
    function ChooseCol(ColIndex: Integer): TFlexArray<T>;

    function Concat(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
    function HStack(const Another: TFlexArray<T>): TFlexArray<T>;
    function VStack(const Another: TFlexArray<T>): TFlexArray<T>;

    function AppendArray(const Another: TFlexArray<T>): TFlexArray<T>; overload;
    function AppendArray(const Another: TArray<T>): TFlexArray<T>; overload;

    function GetEnumerator: TFlexEnumerator<T>;
    // function Each(): TFlexEnumerator<T>; overload;
    // function Each(Dimension: Integer): TDimensionEnumerator<T>; overload;
  end;

implementation

{ TFlexArray<T> }

{ TFlexArray<T>.TDimension }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 対象次元の配列サイズを返す
// [引数] なし
// [戻値] 配列サイズ
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TDimension.Len: NativeInt;
begin
  Result := High - Low + 1;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次元情報の構築
// [引数] 各次元の範囲配列
// [戻値] 全要素数
// [使用例] InternalSetup([[1, 10], [1, 10]])  
// [備考] 各次元の範囲配列は [Low, High] のペアになっていること
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.InternalSetup(const Ranges: array of TArray<Integer>): NativeInt;
var
  i: Integer;
  CurrentStride: NativeInt;
  L, H: Integer;
begin
  SetLength(FDims, System.Length(Ranges));
  CurrentStride := 1;

  // 後ろの次元から歩幅を計算することで多次元に対応
  for i := system.High(Ranges) downto 0 do
  begin
    // 引数の配列が [Low, High] のペアになっているか念のためチェック
    Assert(System.Length(Ranges[i]) = 2,
      Format('TFlexArray: 第 %d 次元の指定が [Low, High] のペアではありません。', [i + 1]));

    L := Ranges[i][0];
    H := Ranges[i][1];

    // ★ ここで開始 > 終了をチェック
    Assert(L <= H,
      Format('TFlexArray: 第 %d 次元の範囲が不正です (Low:%d > High:%d)', [i + 1, L, H]));

    FDims[i].Low    := L;
    FDims[i].High   := H;
    FDims[i].Stride := CurrentStride;

    // 全要素数を累積計算
    CurrentStride := CurrentStride * (H - L + 1);
  end;

  Result := CurrentStride;
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
  Ranges: array of TArray<Integer>;
begin
  SetLength(Ranges, System.Length(AShapes));
  for i := 0 to System.High(AShapes) do
    Ranges[i] := [ABaseIndex, ABaseIndex + AShapes[i] - 1];
  
  FTotalSize := InternalSetup(Ranges);
  SetLength(FData, FTotalSize);
  FHead := @FData[0];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元用コンストラクタ
// [引数] 配列サイズ, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.Create(10, 1)  // 1-10の10要素配列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.Create(ASize: Integer; ABaseIndex: Integer);
begin
  Create([ASize], ABaseIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元用範囲指定コンストラクタ
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([-5, 5])  // -5から5までの11要素
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const ARange: TArray<Integer>);
begin
  CreateFromRange([ARange]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元用範囲指定コンストラクタ
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromRange([[1, 3], [1, 2]])  // 3x2行列
//          静的配列の宣言例に相当 array[1..3, 1..2] of Integer;
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromRange(const ARanges: array of TArray<Integer>);
begin
  FTotalSize := InternalSetup(ARanges);

  SetLength(FData, FTotalSize);
  FHead := @FData[0];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] FlexArrayからFlexArrayを生成する
// [引数] 元のFlexArray
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromFlexArray(const ASrc: TFlexArray<T>);
begin
  // 構造情報をコピー
  FTotalSize := ASrc.FTotalSize;
  SetLength(FDims, System.Length(ASrc.FDims));
  TArray.Copy<TDimension>(ASrc.FDims, FDims, System.Length(ASrc.FDims));
  
  // ToVectorを呼び出してデータをコピー
  FData := ASrc.ToVector;
  FHead := @FData[0];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 動的一次元配列からFlexArrayを生成する
// [引数] 元の動的配列, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateFromArray([2,2,3], 1)  // 1始まりの2x2x3要素配列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateFromArray(const ASrc: TArray<T>; ABaseIndex: Integer);
var
  Ranges: array of TArray<Integer>;
begin
  SetLength(Ranges, 1);
  Ranges[0] := [ABaseIndex, ABaseIndex + System.Length(ASrc) - 1];
  FTotalSize := InternalSetup(Ranges);

  // データをコピーして実体化
  SetLength(FData, FTotalSize);
  FHead := @FData[0];
  TArray.Copy<T>(ASrc, FData, FTotalSize); // 管理型も安全にコピー
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 参照生成コンストラクタ
// [引数] 元の動的配列, 開始インデックス
// [戻値] なし
// [備考] CreateFromArrayと異なり、変更は元の配列に反映される
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.ViewFromArray(const ASrc: TArray<T>; ABaseIndex: Integer);
var
  Ranges: array of TArray<Integer>;
begin
  SetLength(Ranges, 1);
  Ranges[0] := [ABaseIndex, ABaseIndex + System.Length(ASrc) - 1];
  FTotalSize := InternalSetup(Ranges);
  FHead := Pointer(ASrc);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用コンストラクタ
// [引数] 行数, 列数, 開始インデックス
// [戻値] なし
// [使用例] TFlexArray<Integer>.CreateMatrix(3, 4, 1)  // 1始まりの3x4行列
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.CreateMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
begin
  TFlexArray<T>.Create([ARows, ACols], ABaseIndex);
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
  ActualDim := System.Length(FDims);
  if ActualDim <> ExpectedDim then
    raise Exception.CreateFmt(
      '次元エラー: %d次元配列専用の操作ですが、現在は %d次元です。',
      [ExpectedDim, ActualDim]
    );
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定行をスライスして取得
// [引数] 行インデックス
// [戻値] 行のスライス配列（1次元配列）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseRow(RowIndex: Integer): TFlexArray<T>;
begin
  Result := ChooseSlice(1, RowIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定列をスライスして取得
// [引数] 列インデックス
// [戻値] 列のスライス配列（1次元配列）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseCol(ColIndex: Integer): TFlexArray<T>;
begin
  Result := ChooseSlice(2, ColIndex);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の要素を取得
// [引数] インデックス
// [戻値] 指定位置の要素<T>
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseSlice(Index: Integer): T;
begin
  if Dimensions = 1 then
    Result := Self[Index]
  else
    raise Exception.Create('1次元配列専用です。多次元配列ではDimensionを指定してください');
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元をスライスして取得
// [引数] 次元番号, 取得インデックス
// [戻値] スライス配列（元の次元数より1次元少ない配列が生成されます）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ChooseSlice(Dimension: Integer; Index: Integer): TFlexArray<T>;
var
  i, j: Integer;
  NewRanges: array of TArray<Integer>;
  
  // 座標変換の無名関数
  CalcSrcCoords: TFunc<NativeInt, TFlexArray<T>, TFlexArray<T>, TArray<Integer>>;
  
begin
  // NewRangesの例:
  // 3次元配列 [1..3, 1..4, 1..5] から Dimension=2 のスライスを取る場合
  // → NewRanges = [[1,3], [1,5]] となり、2次元配列が生成される
  SetLength(NewRanges, Self.Dimensions - 1);
  j := 0;

  // 元の次元数分ループ
  for i := 1 to Self.Dimensions do
  begin
    if i <> Dimension then
    begin
      NewRanges[j] := [Low(i), High(i)];
      Inc(j);
    end;
  end;
  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  
  // 無名関数の定義（ジェネリックスがあるとプライベート関数では宣言出来ない）
  CalcSrcCoords := function(DestIndex: NativeInt; DestArray, SrcArray: TFlexArray<T>): TArray<Integer>
  var
    // 具体例: 3次元配列[1..3,1..4,1..5]からDimension=2, FixedIndex=2のスライスを取る場合
    // DestIndex=0 → DestCoords=[1,1] → SrcCoords=[1,2,1]
    // DestIndex=1 → DestCoords=[2,1] → SrcCoords=[2,2,1]
    SrcCoords: TArray<Integer>;
    DestCoords: TArray<Integer>;
    i, k: Integer;
  begin
    DestCoords := DestArray.GetCoords(DestIndex);
    SetLength(SrcCoords, SrcArray.Dimensions);
    
    k := 0; // DestCoords用のインデックス(元の次元数より１つ少ない)
    
    // 元の次元数分ループ
    for i := 0 to System.High(SrcArray.FDims) do
    begin
      if (i + 1) = Dimension then
        SrcCoords[i] := Index // 指定された次元は固定値
      else
      begin
        SrcCoords[i] := DestCoords[k];
        Inc(k);
      end;
    end;
    Result := SrcCoords;
  end;

  for i := 0 to Result.FTotalSize - 1 do
    if (Self.FHead <> nil) then
      Result.FData[i] := TArray<T>(Self.FHead)[GetOffset(CalcSrcCoords(i, Result, Self))];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 線形インデックスから多次元座標への変換
// [引数] 線形インデックス
// [戻値] 各次元の座標配列（GetOffsetの逆の変換を行う）
// [例] [[1, 3], [1, 2]] のとき GetCoords(0)=[1,1], GetCoords(1)=[1,2], GetCoords(2)=[2,1]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetCoords(LinearIndex: NativeInt): TArray<Integer>;
var
  i: Integer;
  TempIndex: NativeInt;
begin
  SetLength(Result, System.Length(FDims));
  TempIndex := LinearIndex;

  // 末尾の次元から順に割っていく（GetOffsetの逆工程）
  for i := System.High(FDims) downto System.Low(FDims) do
  begin
    Result[i] := (TempIndex mod FDims[i].Len) + FDims[i].Low;
    TempIndex := TempIndex div FDims[i].Len;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元座標から線形インデックスへの変換
// [引数] 各次元の座標配列
// [戻値] 線形インデックス（範囲外の場合は-1）
// [例] [[1, 3], [1, 2]] のとき GetOffset([1,1])=0, GetOffset([1,2])=1, GetOffset([2,1])=2
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetOffset(const Indices: array of Integer): NativeInt;
var
  i: Integer;
begin
  if System.Length(Indices) <> System.Length(FDims) then Exit(-1);

  // Result := FBaseOffset; // 0 ではなく FBaseOffset から開始
  Result := 0;
  for i := 0 to system.High(FDims) do
  begin
    if (FDims[i].Low <= Indices[i]) and (Indices[i] <= FDims[i].High) then
      Result := Result + (NativeInt(Indices[i]) - FDims[i].Low) * FDims[i].Stride
    else
      Exit(-1);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標の値を取得
// [引数] 各次元の座標配列
// [戻値] 座標に対応する値（範囲外の場合は既定値）
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetValue(const Indices: array of Integer): T;
var
  Offset: NativeInt;
begin
  Offset := GetOffset(Indices);
  // 境界外なら初期値を返す
  if Offset = -1 then Exit(Default(T));
  Result := TArray<T>(FHead)[Offset];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定座標に値を設定
// [引数] 各次元の座標配列, 設定する値
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.SetValue(const Indices: array of Integer; const Value: T);
var
  Offset: NativeInt;
begin
  Offset := GetOffset(Indices);
  // 境界外なら何もしない
  if Offset = -1 then Exit;
  TArray<T>(FHead)[Offset] := Value;
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
    tkString, tkLString, tkWString, tkUString:
      Result := QuotedStr(Val.ToString);

    // その他の型の場合
    else
    begin
      try
        Result := Val.ToString;  // とりあえず実行
      except
        Result := 'この型は表示できません';  // 例外ならデフォルト
      end;
    end;
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列を文字列に変換
// [引数] なし
// [戻値] 文字列表現
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ToString: string;
var
  Rows: TArray<string>;
  r, i: Integer;
begin
  case System.Length(FDims) of
    1: // --- 1次元（Vector）の場合 ---
      begin
        SetLength(Rows, High - Low + 1);
        i := 0;
        for r := Low to High do
        begin
          Rows[i] := ValueToStr(Self[r]);
          Inc(i);
        end;
        Exit('(' + String.Join(', ', Rows) + ')');
      end;
    2: // --- 2次元（Matrix）の場合 ---
      begin
        SetLength(Rows, High(1) - Low(1) + 1);
        i := 0;
        for r := Low(1) to High(1) do
        begin
          Rows[i] := ChooseRow(r).ToString;
          Inc(i);
        end;
        Result := '(' + sLineBreak + '  ' + String.Join(',' + sLineBreak + '  ', Rows) + sLineBreak + ')';
      end;
    3: // --- 3次元（Tensor）の場合 ---
      begin
        SetLength(Rows, High(1) - Low(1) + 1);
        i := 0;
        for r := Low(1) to High(1) do
        begin
          Rows[i] := Format('[Page %d]' + sLineBreak + '  %s', [r, ChooseSlice(1, r).ToString]);
          Inc(i);
        end;
        Result := '(' + sLineBreak + '  ' + String.Join(',' + sLineBreak + '  ', Rows) + sLineBreak + ')';
      end;
    else
      // --- 4次元以上の場合 ---
      Result := Format('%d次元配列です', [System.Length(FDims)]);
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
  TArray.Copy<T>(TArray<T>(FHead), Result, FTotalSize);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 範囲情報を文字列に変換
// [引数] なし
// [戻値] 範囲情報の文字列表現 例：[1990..1991, 1..12, 1..31]
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.ToRangesString(): string;
var
  i: Integer;
  Parts: TArray<string>;
begin
  SetLength(Parts, Length(FDims));
  for i := 0 to system.High(FDims) do
    Parts[i] := Format('%d..%d', [FDims[i].Low, FDims[i].High]);
  
  Result := '[' + String.Join(', ', Parts) + ']';
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元を入れ替え
// [引数] 新しい次元の順序 指定例：[1, 2, 3] -> [3, 1, 2]
// [戻値] 転置後の配列
// [備考] NewDimensions は「1..次元数」の並べ替え（重複なし）を、次元数分指定します。
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Transpose(const NewDimensions: array of Integer): TFlexArray<T>;
var
  i: Integer;
  NewRanges: array of TArray<Integer>;
  InternalAxes: TArray<Integer>;
  CalcSrcCoords: TFunc<NativeInt, TFlexArray<T>, TFlexArray<T>, TArray<Integer>>;
  // 最適化用：ループ外で座標バッファを確保
  DestCoords: TArray<Integer>;
  SrcCoords: TArray<Integer>;
begin
  // --- A. バリデーション ---
  if System.Length(NewDimensions) <> Self.Dimensions then
    raise Exception.Create('Transpose: 指定された軸の数が配列の次元数と一致しません。');

  // --- B. 1-based -> 0-based 変換と NewRanges の構築 ---
  SetLength(InternalAxes, Dimensions);
  SetLength(NewRanges, Dimensions);
  
  for i := 0 to Dimensions - 1 do
  begin
    if (NewDimensions[i] < 1) or (NewDimensions[i] > Dimensions) then
      raise Exception.CreateFmt('Transpose: 次元指定 %d が範囲外です。', [NewDimensions[i]]);
      
    InternalAxes[i] := NewDimensions[i] - 1;
    // 新しい第(i+1)次元には、元の第(Axes[i])次元の範囲を設定
    NewRanges[i] := [Self.Low(NewDimensions[i]), Self.High(NewDimensions[i])];
  end;

  // 新しい実体配列を生成
  Result := TFlexArray<T>.CreateFromRange(NewRanges);

  // --- C. 座標変換ロジックの定義 ---
  // 最適化：クロージャ内で使い回すためのバッファを事前に確保
  SetLength(DestCoords, Dimensions);
  SetLength(SrcCoords, Dimensions);

  CalcSrcCoords := function(DestIndex: NativeInt; DestArray, SrcArray: TFlexArray<T>): TArray<Integer>
  var
    k: Integer;
  begin
    // 転置後配列における現在の線形位置から論理座標(x,y,z...)を出す
    DestCoords := DestArray.GetCoords(DestIndex);

    // 元の配列の座標を再構築
    for k := 0 to System.High(InternalAxes) do
    begin
      // 「転置後の第k次元」のインデックスを「元の第InternalAxes[k]次元」へ配置
      SrcCoords[InternalAxes[k]] := DestCoords[k];
    end;
    Result := SrcCoords;
  end;

  // --- D. 物理コピー実行 ---
  for i := 0 to Result.FTotalSize - 1 do
  begin
    if (Self.FHead <> nil) then
    begin
      // GetOffsetを通じて正しい物理位置を特定し、コピー
      Result.FData[i] := TArray<T>(Self.FHead)[Self.GetOffset(CalcSrcCoords(i, Result, Self))];
    end;
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
// [備考] 利用者向けAPI（封印中）です。内部実装では FDims[i].Len を使用してください。
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Len(Dim: Integer): NativeInt;
begin
  Result := FDims[Dim - 1].Len;
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
  Result := FDims[Dim - 1].Low; 
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 指定次元の最大インデックスを取得
// [引数] 次元番号
// [戻値] 最大インデックス
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.High(Dim: Integer): Integer; 
begin 
  Result := FDims[Dim - 1].High; 
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 配列の次元数を取得
// [引数] なし
// [戻値] 次元数
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Dimensions: Integer; 
begin 
  Result := System.Length(FDims); 
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を取得
// [引数] なし
// [戻値] 列挙子オブジェクト
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetEnumerator: TFlexEnumerator<T>;
begin
  Result := TFlexEnumerator<T>.Create(FHead, FTotalSize);
end;

// function TFlexArray<T>.Each(): TFlexEnumerator<T>;
// begin
//   // 1次元用：要素を列挙
//   if (Dimensions = 1) or (Dimensions = 0) then
//     Result := TFlexEnumerator<T>.Create(FHead, FTotalSize)
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

{ TFlexArray<T>.TFlexEnumerator }

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 列挙子を初期化
// [引数] データの先頭ポインタ, 全要素数
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
constructor TFlexArray<T>.TFlexEnumerator<T>.Create(AHead: Pointer; ASize: NativeInt);
begin
  FHead := AHead;
  FTotalSize := ASize;
  FIndex := -1;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 現在の要素を取得
// [引数] なし
// [戻値] 現在の要素
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TFlexEnumerator<T>.GetCurrent: T;
begin
  // ポインタから直接アクセス（TArray偽装）
  Result := TArray<T>(FHead)[FIndex];
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 次の要素に移動
// [引数] なし
// [戻値] 次の要素が存在するかどうか
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.TFlexEnumerator<T>.MoveNext: Boolean;
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
// [概要] 各次元の最小座標を取得
// [引数] なし
// [戻値] 各次元の最小値配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.GetMinCoords: TArray<Integer>;
var
  i: Integer;
begin
  SetLength(Result, System.Length(FDims));
  for i := 0 to System.High(FDims) do
    Result[i] := FDims[i].Low;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 座標をインクリメント
// [引数] 現在の座標配列, 各次元の範囲配列
// [戻値] なし
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.IncCoords(var CurrentCoords: TArray<Integer>; const Ranges: array of TArray<Integer>);
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
// [概要] 指定次元で配列を結合
// [引数] 結合対象の配列, 結合する次元
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.Concat(const Another: TFlexArray<T>; TargetDim: Integer): TFlexArray<T>;
var
  DimIdx: Integer;
  NewRanges: array of TArray<Integer>;
  DestCoords: TArray<Integer>;
  SelfSizeAlongDim: Integer;
  i, d: Integer;
begin
  // 1. 次元の正規化 (1-based to 0-based)
  DimIdx := TargetDim - 1;

  // 2. 新しい形状（Ranges）の計算
  SetLength(NewRanges, Self.Dimensions);
  for d := 0 to Self.Dimensions - 1 do
  begin
    SetLength(NewRanges[d], 2); // [Low, High] の 2要素配列
    NewRanges[d][0] := Self.FDims[d].Low; // LowBoundはSelfに合わせる
    if d = DimIdx then
      // 結合する次元だけ、自分と相手のサイズを足し合わせる
      NewRanges[d][1] := Self.FDims[d].High + Another.FDims[d].Len
    else
      NewRanges[d][1] := Self.FDims[d].High;
  end;

  // 3. 結果用配列の生成
  Result := TFlexArray<T>.CreateFromRange(NewRanges);
  SelfSizeAlongDim := Self.FDims[DimIdx].Len;
  
  // 4. Result 用の座標を初期化
  DestCoords := Result.GetMinCoords;

  // 5. Self のデータを埋める
  for i := 0 to Self.FTotalSize - 1 do
  begin
    // ストライドにより、変更前後で同じ座標でも Self の正しいメモリ位置が引ける
    Result.FData[i] := Self.FData[Self.GetOffset(DestCoords)];

    // 座標を1つ進めるイテレーターの一種
    Result.IncCoords(DestCoords, NewRanges);
  end;

  // 6. Another のデータを埋める
  for i := Self.FTotalSize to Result.FTotalSize - 1 do
  begin
    // Another のローカル座標に合わせる（※ 抽出後に必ず戻すこと）
    DestCoords[DimIdx] := DestCoords[DimIdx] - SelfSizeAlongDim;
  
    Result.FData[i] := Another.FData[Another.GetOffset(DestCoords)];

    // 約束の通り、座標を元に戻す
    DestCoords[DimIdx] := DestCoords[DimIdx] + SelfSizeAlongDim;
  
    // 座標を1つ進めるイテレーターの一種
    // [1,1,1] → [1,1,2]  繰上がり時 [1,1,3] → [1,2,1]
    Result.IncCoords(DestCoords, NewRanges);
  end;
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用の縦方向結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.VStack(const Another: TFlexArray<T>): TFlexArray<T>;
var
  SelfExpanded, AnotherExpanded: TFlexArray<T>;
begin
  // 例: [1,2,3] + [4,5,6] → [[1,2,3],[4,5,6]] (2x3)
  // 注意: [1,2,3]は[[1,2,3]]に、[4,5,6]は[[4,5,6]]に変換してから2次元同士で結合
  if (Self.Dimensions = 1) and (Another.Dimensions = 1) then
  begin
    // [1,2,3] → [[1,2,3]] (行ベクトル)
    SelfExpanded := TFlexArray<T>.ViewFromArray(TArray<T>(Self.FHead), 1);
    SelfExpanded.Reshape([1, Self.FDims[0].Len], 1);
    // [4,5,6] → [[4,5,6]] (行ベクトル)
    AnotherExpanded := TFlexArray<T>.ViewFromArray(TArray<T>(Another.FHead), 1);
    AnotherExpanded.Reshape([1, Another.FDims[0].Len], 1);
    Result := SelfExpanded.Concat(AnotherExpanded, 1);
    Exit;
  end;

  // 例: [1,2] + [[3,4],[5,6]] → [[1,2],[3,4],[5,6]] (3x2)
  // 注意: [1,2]は[[1,2]]に変換され、[[3,4],[5,6]]の上に結合
  if (Self.Dimensions = 1) and (Another.Dimensions = 2) then
  begin
    // [1,2] → [[1,2]] (行ベクトル)
    SelfExpanded := TFlexArray<T>.ViewFromArray(TArray<T>(Self.FHead), 1);
    SelfExpanded.Reshape([1, Self.FDims[0].Len], 1);
    // 結合可能性チェック
    if SelfExpanded.FDims[1].Len <> Another.FDims[1].Len then
      raise Exception.CreateFmt('VStack: 列数が一致しません。Self=%d, Another=%d', 
        [SelfExpanded.FDims[1].Len, Another.FDims[1].Len]);
    Result := SelfExpanded.Concat(Another, 1);
    Exit;
  end;

  // 例: [[1,2],[3,4]] + [5,6] → [[1,2],[3,4],[5,6]] (3x2)
  // 注意: [5,6]は[[5,6]]に変換され、[[1,2],[3,4]]の下に結合
  if (Self.Dimensions = 2) and (Another.Dimensions = 1) then
  begin
    // [5,6] → [[5,6]] (行ベクトル)
    AnotherExpanded := TFlexArray<T>.ViewFromArray(TArray<T>(Another.FHead), 1);
    AnotherExpanded.Reshape([1, Another.FDims[0].Len], 1);
    // 結合可能性チェック
    if Self.FDims[1].Len <> AnotherExpanded.FDims[1].Len then
      raise Exception.CreateFmt('VStack: 列数が一致しません。Self=%d, Another=%d', 
        [Self.FDims[1].Len, AnotherExpanded.FDims[1].Len]);
    Result := Self.Concat(AnotherExpanded, 1);
    Exit;
  end;
end;


//////////////////////////////////////////////////////////////////////////////////////
// [概要] 2次元配列専用の水平方向結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.HStack(const Another: TFlexArray<T>): TFlexArray<T>;
var
  SelfExpanded, AnotherExpanded: TFlexArray<T>;
begin
  // 例: [1,2,3] + [4,5,6] → [1,2,3,4,5,6] (1次元)
  if (Self.Dimensions = 1) and (Another.Dimensions = 1) then
  begin
    Result := Self.AppendArray(Another);
    Exit;
  end;

  // 例: [1,2] + [[3,4],[5,6]] → [[1,3,4],[2,5,6]] (2x3)
  // 注意: [1,2]は[[1],[2]]（列ベクトル）に変換され、左側に結合される
  if (Self.Dimensions = 1) and (Another.Dimensions = 2) then
  begin
    // Selfを列ベクトルに変換: [1,2] → [[1],[2]]
    SelfExpanded := TFlexArray<T>.ViewFromArray(TArray<T>(Self.FHead), 1);
    SelfExpanded.Reshape([Self.FDims[0].Len, 1], 1);
    // 結合可能性チェック: Selfの行数とAnotherの行数が一致するか
    if SelfExpanded.FDims[0].Len <> Another.FDims[0].Len then
      raise Exception.CreateFmt('HStack: 行数が一致しません。Self=%d, Another=%d', 
        [SelfExpanded.FDims[0].Len, Another.FDims[0].Len]);
    Result := SelfExpanded.Concat(Another, 2);
    Exit;
  end;

  // 例: [[1,2],[3,4]] + [5,6] → [[1,2,5],[3,4,6]] (2x3)
  // 注意: [5,6]は[[5],[6]]に変換され、[[1,2],[3,4]]の右側に結合
  if (Self.Dimensions = 2) and (Another.Dimensions = 1) then
  begin
    // Anotherを列ベクトルに変換: [5,6] → [[5],[6]]
    AnotherExpanded := TFlexArray<T>.ViewFromArray(TArray<T>(Another.FHead), 1);
    AnotherExpanded.Reshape([Another.FDims[0].Len, 1], 1);
    // 結合可能性チェック: Selfの行数とAnotherの行数が一致するか
    if Self.FDims[0].Len <> AnotherExpanded.FDims[0].Len then
      raise Exception.CreateFmt('HStack: 行数が一致しません。Self=%d, Another=%d', 
        [Self.FDims[0].Len, AnotherExpanded.FDims[0].Len]);
    // 2:1 2次元 + 1次元 → 次元統一して結合
    Result := Self.Concat(AnotherExpanded, 2);
    Exit;
  end;

  // 例: [[1,2],[3,4]] + [[5,6],[7,8]] → [[1,2,5,6],[3,4,7,8]] (2x4)
  if (Self.Dimensions = 2) and (Another.Dimensions = 2) then
  begin
    // 結合可能性チェック: 行数が一致するか
    if Self.FDims[0].Len <> Another.FDims[0].Len then
      raise Exception.CreateFmt('HStack: 行数が一致しません。Self=%d, Another=%d', 
        [Self.FDims[0].Len, Another.FDims[0].Len]);
    Result := Self.Concat(Another, 2);
    Exit;
  end;

  // その他の組み合わせは未サポート
  raise Exception.CreateFmt('HStack: 未対応の次元の組み合わせです。Self=%d次元, Another=%d次元', 
    [Self.Dimensions, Another.Dimensions]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列専用の配列結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(const Another: TFlexArray<T>): TFlexArray<T>;
begin
  CheckDimension(1);
  Result := Self.Concat(Another, 1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列専用の配列結合
// [引数] 結合対象の配列
// [戻値] 結合結果の配列
//////////////////////////////////////////////////////////////////////////////////////
function TFlexArray<T>.AppendArray(const Another: TArray<T>): TFlexArray<T>;
begin
  Result := Self.Concat(TFlexArray<T>.ViewFromArray(Another, 1), 1);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 1次元配列の末尾に要素を追加
// [引数] 追加する要素
// [戻値] なし
// [備考] 1次元配列専用です。多次元配列では例外を発生させます。
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.AddValue(const Value: T);
begin
  CheckDimension(1);
  
  // 新しい配列サイズを計算
  var NewSize := FTotalSize + 1;
  var NewLow := FDims[0].Low;
  var NewHigh := NewLow + NewSize - 1;
  
  // 新しい配列を確保してデータをコピー
  var NewData: TArray<T>;
  SetLength(NewData, NewSize);
  TArray.Copy<T>(TArray<T>(FHead), NewData, FTotalSize);
  NewData[FTotalSize] := Value; // 末尾に追加
  
  // 内部情報を更新
  FTotalSize := NewSize;
  FData := NewData;
  FHead := @FData[0];
  FDims[0].High := NewHigh;
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
  NewRanges: array of TArray<Integer>;
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
  InternalSetup(NewRanges);
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
// [概要] 1次元範囲指定による再定義
// [引数] 範囲配列 [Low, High]
// [戻値] なし
// [使用例] Vector.ReshapeRange([-5, 5])  // -5から5までの範囲に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const ARange: TArray<Integer>);
var
  NewTotalSize: NativeInt;
begin
  // 1. 新しい範囲の全要素数を計算
  NewTotalSize := ARange[1] - ARange[0] + 1;
  
  // 2. 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'ReshapeRange: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));
  
  // 3. 次元情報のみ更新（データは保持）
  InternalSetup([ARange]);
end;

//////////////////////////////////////////////////////////////////////////////////////
// [概要] 多次元範囲指定による再定義
// [引数] 各次元の範囲配列 [[Low, High], ...]
// [戻値] なし
// [使用例] Tensor.ReshapeRange([[1, 3], [1, 2]])  // 3x2行列に再定義
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.ReshapeRange(const ARanges: array of TArray<Integer>);
var
  i: Integer;
  NewTotalSize: NativeInt;
begin
  // 1. 新しい範囲の全要素数を計算
  NewTotalSize := 1;
  for i := 0 to System.High(ARanges) do
    NewTotalSize := NewTotalSize * (ARanges[i][1] - ARanges[i][0] + 1);
  
  // 2. 要素数チェック
  if NewTotalSize <> FTotalSize then
    raise Exception.Create(Format(
      'ReshapeRange: 要素数が一致しません。現在=%d, 新規=%d', [FTotalSize, NewTotalSize]));
  
  // 3. 次元情報のみ更新（データは保持）
  InternalSetup(ARanges);
end;

end.
