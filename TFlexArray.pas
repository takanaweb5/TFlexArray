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
  private
    FData: TArray<T>;      // 実データ保持用
    FHead: Pointer;        // 物理先頭ポインタ
    FDims: TArray<TDimension>;
    FTotalSize: NativeInt;

    function GetOffset(const Indices: array of Integer): NativeInt;
    function GetValue(const Indices: array of Integer): T;
    procedure SetValue(const Indices: array of Integer; const Value: T);
    function InternalSetup(const Ranges: array of TArray<Integer>): NativeInt;
    function ValueToStr(const V: T): string;
    procedure CheckDimension(ExpectedDim: Integer);
    function Len(Dim: Integer): Integer;
  public
    constructor Create(const Range: TArray<Integer>); overload;
    constructor Create(const Ranges: array of TArray<Integer>); overload;
    constructor Create(const Range: TArray<Integer>;
                           const Src: TArray<T>; ACopy: Boolean = False); overload;
    constructor Create(const Ranges: array of TArray<Integer>;
                           const Src: TArray<T>; ACopy: Boolean = False); overload;
    function Low: Integer; overload;
    function High: Integer; overload;
    function Low(Dim: Integer): Integer; overload;
    function High(Dim: Integer): Integer; overload;
    function Dimensions: Integer;
    property Items[const Indices: array of Integer]: T read GetValue write SetValue; default;

    function ToString(): string;
    function ToVector(): TArray<T>;
    function Transpose: TFlexArray<T>;

    function ChooseRow(RowIndex: Integer): TFlexArray<T>;
    function ChooseRows(const RowIndices: TArray<Integer>; ALow: Integer = 1): TFlexArray<T>;
    function ChooseCol(ColIndex: Integer): TFlexArray<T>;
    function ChooseCols(const ColIndices: TArray<Integer>; ALow: Integer = 1): TFlexArray<T>;

    function GetEnumerator: TFlexEnumerator<T>;
  end;

implementation

{ TFlexArray<T> }

{ --- 共通ロジック：次元情報の構築 --- }
function TFlexArray<T>.InternalSetup(const Ranges: array of TArray<Integer>): NativeInt;
var
  i: Integer;
  CurrentStride: NativeInt;
  L, H: Integer;
begin
  SetLength(FDims, Length(Ranges));
  CurrentStride := 1;

  // 後ろの次元から歩幅を計算することで多次元に対応
  for i := system.High(Ranges) downto 0 do
  begin
    // 引数の配列が [Low, High] のペアになっているか念のためチェック
    Assert(Length(Ranges[i]) = 2,
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

// ① 新規生成（１次元限定）  例：TFlexArray<Double>.Create([1, 10]);
constructor TFlexArray<T>.Create(const Range: TArray<Integer>);
begin
  Create([Range]);
end;

// ① 新規生成（多次元）  例：TFlexArray<Double>.Create([[1, 10], [1, 12]]);
constructor TFlexArray<T>.Create(const Ranges: array of TArray<Integer>);
begin
  FTotalSize := InternalSetup(Ranges);

  SetLength(FData, FTotalSize);
  FHead := @FData[0];
end;

// ② 配列の偽装/コピ（1次元限定）　例：TFlexArray<Double>.Create([1, 10], src, True);
constructor TFlexArray<T>.Create(const Range: TArray<Integer>;
                         const Src: TArray<T>; ACopy: Boolean = False);
begin
  Create([Range], Src, Acopy);
end;

// ② 既存1次元配列の偽装/コピ（多次元へ）  例：TFlexArray<Double>.Create([[1, 10], [1, 12]], src, True);
constructor TFlexArray<T>.Create(const Ranges: array of TArray<Integer>;
                         const Src: TArray<T>; ACopy: Boolean = False);
begin
  FTotalSize := InternalSetup(Ranges);
  Assert(FTotalSize <= Length(Src), '指定サイズが元の配列を超えています');

  if ACopy then
  begin
    SetLength(FData, FTotalSize);
    FHead := @FData[0];
    if (FTotalSize > 0) and (Pointer(Src) <> nil) then
      TArray.Copy<T>(Src, FData, FTotalSize); // 管理型も安全にコピー
  end
  else
  begin
    // 参照（偽装）モード
    FHead := Pointer(Src);
  end;
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
var
  c: Integer;
begin
  CheckDimension(2);
  Result := TFlexArray<T>.Create([[Low(2), High(2)]]);
  for c := Low(2) to High(2) do Result[c] := Self[RowIndex, c];
end;

function TFlexArray<T>.ChooseRows(const RowIndices: TArray<Integer>; ALow: Integer): TFlexArray<T>;
var
  r, c, NewR: Integer;
begin
  CheckDimension(2);
  Result := TFlexArray<T>.Create([[ALow, ALow + System.High(RowIndices)], [Low(2), High(2)]]);
  NewR := ALow;
  for r in RowIndices do begin
    for c := Low(2) to High(2) do Result[NewR, c] := Self[r, c];
    Inc(NewR);
  end;
end;

function TFlexArray<T>.ChooseCol(ColIndex: Integer): TFlexArray<T>;
var
  r: Integer;
begin
  CheckDimension(2);
  Result := TFlexArray<T>.Create([[Low(1), High(1)]]);
  for r := Low(1) to High(1) do Result[r] := Self[r, ColIndex];
end;

function TFlexArray<T>.ChooseCols(const ColIndices: TArray<Integer>; ALow: Integer): TFlexArray<T>;
var
  r, c, NewC: Integer;
begin
  CheckDimension(2);
  Result := TFlexArray<T>.Create([[Low(1), High(1)], [ALow, ALow + System.High(ColIndices)]]);
  NewC := ALow;
  for c in ColIndices do begin
    for r := Low(1) to High(1) do Result[r, NewC] := Self[r, c];
    Inc(NewC);
  end;
end;

function TFlexArray<T>.GetOffset(const Indices: array of Integer): NativeInt;
var
  i: Integer;
begin
  // 次元数が合わない場合は「範囲外」
  if Length(Indices) <> Length(FDims) then Exit(-1);

  Result := 0;
  for i := 0 to system.High(FDims) do
  begin
    if (FDims[i].Low <= Indices[i] ) and (Indices[i] <= FDims[i].High) then
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
      Result := Val.ToString;
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
    raise Exception.Create('ToString は3次元以上の配列には対応していません。');
  end;
end;

function TFlexArray<T>.ToVector(): TArray<T>;
begin
  SetLength(Result, FTotalSize);
  TArray.Copy<T>(TArray<T>(FHead), Result, FTotalSize);
end;

function TFlexArray<T>.Transpose: TFlexArray<T>;
var r, c: Integer;
begin
  CheckDimension(2);
  Result := TFlexArray<T>.Create([[Low(2), High(2)], [Low(1), High(1)]]);
  for r := Low(1) to High(1) do
    for c := Low(2) to High(2) do
      Result[c, r] := Self[r, c];
end;

function TFlexArray<T>.Len(Dim: Integer): Integer;
begin
  Result := FDims[Dim - 1].High - FDims[Dim - 1].Low + 1;
end;

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
function TFlexArray<T>.Dimensions: Integer; begin Result := Length(FDims); end;

function TFlexArray<T>.GetEnumerator: TFlexEnumerator<T>;
begin
  Result := TFlexEnumerator<T>.Create(FHead, FTotalSize);
end;

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

end.
