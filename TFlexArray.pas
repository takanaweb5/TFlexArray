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
//    function Len(Dim: Integer): Integer;
  public

////////////////////////////////////////////////////////////////
    { --- 1. 新規生成 (Create: メモリ確保あり) --- }
    
    // 汎用・多次元
    constructor Create(const AShapes: array of Integer; ABaseIndex: Integer); overload;
    // 1次元（ショートカット）
    constructor Create(ASize: Integer; ABaseIndex: Integer); overload;
    // 行列特化（明示的 Rows, Cols）
    constructor CreateMatrix(ARows, ACols: Integer; ABaseIndex: Integer); overload;

    { --- 2. 範囲指定生成 (CreateFromRange: メモリ確保あり) --- }
    
    // 1次元：CreateFromRange([-5, 5])
    constructor CreateFromRange(const ARange: TArray<Integer>); overload;
    // 多次元：CreateFromRange([[1, 10], [1, 10]])
    constructor CreateFromRange(const ARanges: array of TArray<Integer>); overload;

    { --- 3. 既存データからの生成 (Copy / View) --- }

    // 既存の動的配列を「コピー」して実体を作成
    constructor CreateFromArray(const ASrc: TArray<T>; ABaseIndex: Integer); overload;
    // 既存の FlexArray を「コピー」して実体を作成
    constructor CreateFromFlexArray(const ASrc: TFlexArray<T>); overload;
    // 既存の動的配列を「参照」する (Julia-style View)
    constructor ViewFromArray(var ASrc: TArray<T>; ABaseIndex: Integer); overload;

    { --- 4. 構造の再定義 (Reshape) --- }

    // 汎用・多次元変形
    procedure Reshape(const AShapes: array of Integer; ABaseIndex: Integer);
    // 行列特化変形（明示的 Rows, Cols）
    procedure ReshapeMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
    // 範囲指定による再定義
    procedure ReshapeRange(const ARange: array of Integer); overload; // 1D
    procedure ReshapeRange(const ARanges: array of TArray<Integer>); overload; // nD
////////////////////////////////////////////////////////////////




    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function Dimensions: Integer;
    property Items[const Indices: array of Integer]: T read GetValue write SetValue; default;
    property Length: NativeInt read FTotalSize;

    function ToString(): string;
    function ToVector(): TArray<T>;
    function Transpose(): TFlexArray<T>; overload;
    function Transpose(const NewDimensions: array of Integer): TFlexArray<T>; overload;

    function ChooseSlice(FixedIndex: Integer): T; overload;
    function ChooseSlice(Dimension: Integer; FixedIndex: Integer): TFlexArray<T>; overload;
    function ChooseRow(RowIndex: Integer): TFlexArray<T>;
    function ChooseCol(ColIndex: Integer): TFlexArray<T>;

    function GetEnumerator: TFlexEnumerator<T>;
    // function Each(): TFlexEnumerator<T>; overload;
    // function Each(Dimension: Integer): TDimensionEnumerator<T>; overload;
  end;

implementation

{ TFlexArray<T> }

{ TFlexArray<T>.TDimension }

function TFlexArray<T>.TDimension.Len: NativeInt;
begin
  Result := High - Low + 1;
end;

{ --- 共通ロジック：次元情報の構築 --- }
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

{ --- 公開コンストラクタ --- }

// 汎用・多次元コンストラクタ
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

// 1次元ショートカットコンストラクタ
constructor TFlexArray<T>.Create(ASize: Integer; ABaseIndex: Integer);
begin
  Create([ASize], ABaseIndex);
end;

// CreateFromRange 1次元
constructor TFlexArray<T>.CreateFromRange(const ARange: TArray<Integer>);
begin
  CreateFromRange([ARange]);
end;

// CreateFromRange 多次元
{
  CreateFromRange (多次元版)
  記述例: TFlexArray<Double>.CreateFromRange([[1, 10], [-5, 5]]);
}
constructor TFlexArray<T>.CreateFromRange(const ARanges: array of TArray<Integer>);
begin
  FTotalSize := InternalSetup(ARanges);

  SetLength(FData, FTotalSize);
  FHead := @FData[0];
end;

// 既存データから生成
{ --- CreateFromArray: 動的配列からのコピー生成 --- }
constructor TFlexArray<T>.CreateFromArray(const ASrc: TArray<T>; ABaseIndex: Integer);
var
  Ranges: array of TArray<Integer>;
begin
  // ViewFromArrayと同じロジックを実装
  SetLength(Ranges, 1);
  Ranges[0] := [ABaseIndex, ABaseIndex + System.Length(ASrc) - 1];
  FTotalSize := InternalSetup(Ranges);
  
  // データをコピーして実体化
  SetLength(FData, FTotalSize);
  FHead := @FData[0];
  TArray.Copy<T>(ASrc, FData, FTotalSize); // 管理型も安全にコピー
end;

{ --- CreateFromFlexArray: FlexArray 同士の完全コピー --- }
constructor TFlexArray<T>.CreateFromFlexArray(const ASrc: TFlexArray<T>);
begin
  // 構造情報をコピー
  FTotalSize := ASrc.FTotalSize;
  SetLength(FDims, System.Length(ASrc.FDims));
  TArray.Copy<TDimension>(ASrc.FDims, FDims, System.Length(ASrc.FDims));
  
  // データをコピー
  SetLength(FData, FTotalSize);
  TArray.Copy<T>(TArray<T>(ASrc.FHead), FData, FTotalSize);
  FHead := @FData[0];
end;

{ --- ViewFromArray: 参照生成 (Julia-style) --- }
constructor TFlexArray<T>.ViewFromArray(var ASrc: TArray<T>; ABaseIndex: Integer);
var
  Ranges: array of TArray<Integer>;
begin
  SetLength(Ranges, 1);
  Ranges[0] := [ABaseIndex, ABaseIndex + System.Length(ASrc) - 1];
  FTotalSize := InternalSetup(Ranges);
  FHead := Pointer(ASrc);
end;
// --- 静的関数の実装 ---

// 行列特化コンストラクタ
constructor TFlexArray<T>.CreateMatrix(ARows, ACols: Integer; ABaseIndex: Integer);
begin
  TFlexArray<T>.Create([ARows, ACols], ABaseIndex);
end;

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

function TFlexArray<T>.ChooseRow(RowIndex: Integer): TFlexArray<T>;
begin
  Result := ChooseSlice(1, RowIndex);
end;

function TFlexArray<T>.ChooseCol(ColIndex: Integer): TFlexArray<T>;
begin
  Result := ChooseSlice(2, ColIndex);
end;

function TFlexArray<T>.ChooseSlice(FixedIndex: Integer): T;
begin
  if Dimensions = 1 then
    Result := Self[FixedIndex]
  else
    raise Exception.Create('1次元配列専用です。多次元配列ではDimensionを指定してください');
end;

function TFlexArray<T>.ChooseSlice(Dimension: Integer; FixedIndex: Integer): TFlexArray<T>;
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
  Result := TFlexArray<T>.Create(NewRanges);
  
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
        SrcCoords[i] := FixedIndex // 指定された次元は固定値
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

function TFlexArray<T>.GetOffset(const Indices: array of Integer): NativeInt;
var
  i: Integer;
begin
  if System.Length(Indices) <> System.Length(FDims) then Exit(-1);

  // Result := FBaseOffset; // 0 ではなく FBaseOffset から開始
  for i := 0 to system.High(FDims) do
  begin
    if (FDims[i].Low <= Indices[i]) and (Indices[i] <= FDims[i].High) then
      Result := Result + (NativeInt(Indices[i]) - FDims[i].Low) * FDims[i].Stride
    else
      Exit(-1);
  end;
end;
function TFlexArray<T>.GetValue(const Indices: array of Integer): T;
var
  Offset: NativeInt;
begin
  Offset := GetOffset(Indices);
  // 境界外なら初期値を返す
  if Offset = -1 then Exit(Default(T));
  Result := TArray<T>(FHead)[Offset];
end;

procedure TFlexArray<T>.SetValue(const Indices: array of Integer; const Value: T);
var
  Offset: NativeInt;
begin
  Offset := GetOffset(Indices);
  // 境界外なら何もしない
  if Offset = -1 then Exit;
  TArray<T>(FHead)[Offset] := Value;
end;

// 【内部関数1】型 T を Delphi の定数形式に合わせた文字列に変換する
// ここを調整するだけで、数値のフォーマットや文字列の扱いを一括管理できる
function TFlexArray<T>.ValueToStr(const V: T): string;
var
  Val: TValue;
begin
  Val := TValue.From<T>(V);
  case Val.Kind of
    // 文字列型の場合は、Delphi定数として成立するように単一引用符で囲む
    tkString, tkLString, tkWString, tkUString:
      Result := QuotedStr(Val.ToString);

    // Boolean型は True/False のまま出力（Delphi定数で利用可能）
    tkEnumeration:
      Result := Val.ToString;

    // 数値型などはそのままの文字列表現
    else
      Result := 'この型は表示できません';
  end;
end;

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
        Result := '(' + sLineBreak + '  ' + String.Join(sLineBreak + ', ', Rows) + sLineBreak + ')';
      end;
    else
      // --- 3次元以上の場合 ---
      Result := Format('%d次元配列です', [System.Length(FDims)]);
  end;
end;

function TFlexArray<T>.ToVector(): TArray<T>;
begin
  SetLength(Result, FTotalSize);
  TArray.Copy<T>(TArray<T>(FHead), Result, FTotalSize);
end;

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
  Result := TFlexArray<T>.Create(NewRanges);

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

function TFlexArray<T>.Transpose: TFlexArray<T>;
begin
  CheckDimension(2);
  // Julia方式 [2, 1] で行と列を入れ替え
  Result := Transpose([2, 1]);
end;

//function TFlexArray<T>.Len(Dim: Integer): Integer;
//begin
//  Result := FDims[Dim - 1].High - FDims[Dim - 1].Low + 1;
//end;

function TFlexArray<T>.Low: Integer;
begin
  if System.Length(FDims) <> 1 then
    raise Exception.Create('多次元配列です。次元を明示してください（例: Low(1)）。');
  Result := FDims[0].Low;
end;
function TFlexArray<T>.High: Integer;
begin
  if System.Length(FDims) <> 1 then
    raise Exception.Create('多次元配列です。次元を明示してください（例: High(1)）。');
  Result := FDims[0].High;
end;

function TFlexArray<T>.Low(Dim: Integer): Integer; begin Result := FDims[Dim - 1].Low; end;
function TFlexArray<T>.High(Dim: Integer): Integer; begin Result := FDims[Dim - 1].High; end;
function TFlexArray<T>.Dimensions: Integer; begin Result := System.Length(FDims); end;

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

constructor TFlexArray<T>.TFlexEnumerator<T>.Create(AHead: Pointer; ASize: NativeInt);
begin
  FHead := AHead;
  FTotalSize := ASize;
  FIndex := -1;
end;

function TFlexArray<T>.TFlexEnumerator<T>.GetCurrent: T;
begin
  // ポインタから直接アクセス（TArray偽装）
  Result := TArray<T>(FHead)[FIndex];
end;

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
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
procedure TFlexArray<T>.IncCoords(var CurrentCoords: TArray<Integer>; const Ranges: array of TArray<Integer>);
var
  d: Integer;
begin
  // 一番右側の次元（最小単位）から順にチェック
  for d := High(CurrentCoords) downto 0 do
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

function TFlexArray<T>.Concat(const Another: TFlexArray<T>; Dim: Integer): TFlexArray<T>;
var
  TargetDimIdx: Integer;
  NewRanges: TArray<TArray<Integer>>;
  DestCoords: TArray<Integer>;
  SelfSizeAlongDim: Integer;
  i, d: Integer;
begin
  // 1. 次元の正規化 (1-based to 0-based)
  TargetDimIdx := Dim - 1;

  // 2. 新しい形状（Ranges）の計算
  SetLength(NewRanges, Self.FDimensions);
  for d := 0 to Self.FDimensions - 1 do
  begin
    SetLength(NewRanges[d], 2);
    NewRanges[d][0] := Self.FRanges[d][0]; // LowBoundはSelfに合わせる
    if d = TargetDimIdx then
      // 結合する次元だけ、自分と相手のサイズを足し合わせる
      NewRanges[d][1] := Self.FRanges[d][1] + (Another.FRanges[d][1] - Another.FRanges[d][0] + 1)
    else
      NewRanges[d][1] := Self.FRanges[d][1];
  end;

  // 3. 結果用配列の生成
  Result := TFlexArray<T>.Create(NewRanges);
  SelfSizeAlongDim := Self.FRanges[TargetDimIdx][1] - Self.FRanges[TargetDimIdx][0] + 1;
  
  // 4. Result 用の時計（座標）を初期化
  DestCoords := Result.GetMinCoords;

  // 5. Self のデータを埋める
  for i := 0 to Self.FTotalSize - 1 do
  begin
    // ストライドにより、変更前後で同じ座標でも Self の正しいメモリ位置が引ける
    Result.FData[i] := Self.FData[Self.GetOffset(DestCoords)];

    // 座標を1つ進めるイテレーターの一種
    Result.IncCoords(DestCoords, Result.FRanges);
  end;

  // 6. Another のデータを埋める
  for i := Self.FTotalSize to Result.FTotalSize - 1 do
  begin
    // Another のローカル座標に合わせる（※ 抽出後に必ず戻すこと）
    DestCoords[TargetDimIdx] := DestCoords[TargetDimIdx] - SelfSizeAlongDim;
  
    Result.FData[i] := Another.FData[Another.GetOffset(DestCoords)];

    // 約束の通り、座標を元に戻す
    DestCoords[TargetDimIdx] := DestCoords[TargetDimIdx] + SelfSizeAlongDim;
  
    // 座標を1つ進めるイテレーターの一種
    // [1,1,1] → [1,1,2]  繰上がり時 [1,1,3] → [1,2,1]
    Result.IncCoords(DestCoords, Result.FRanges);
  end;
end;

function TFlexArray<T>.VStack(const Another: TFlexArray<T>): TFlexArray<T>;
begin
  Result := Self.Concat(Another, 1);
end;

function TFlexArray<T>.HStack(const Another: TFlexArray<T>): TFlexArray<T>;
begin
  Result := Self.Concat(Another, 2);
end;

end.
