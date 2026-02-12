unit TFlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math;

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
  public
    constructor Create(const Range: TArray<Integer>); overload;
    constructor Create(const Ranges: array of TArray<Integer>); overload;
    constructor Create(const Range: TArray<Integer>;
                           const Src: TArray<T>; ACopy: Boolean = False); overload;
    constructor Create(const Ranges: array of TArray<Integer>;
                           const Src: TArray<T>; ACopy: Boolean = False); overload;
    function LBound(Dim: Integer = 1): Integer;
    function UBound(Dim: Integer = 1): Integer;
    function Dimensions: Integer;
    function GetEnumerator: TFlexEnumerator<T>;
    property Items[const Indices: array of Integer]: T read GetValue write SetValue; default;
  end;

implementation

{ TFlexAny<T> }

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
  for i := High(Ranges) downto 0 do
  begin
    // 引数の配列が [Low, High] のペアになっているか念のためチェック
    Assert(Length(Ranges[i]) = 2,
      Format('TFlexAny: 第 %d 次元の指定が [Low, High] のペアではありません。', [i + 1]));

    L := Ranges[i][0];
    H := Ranges[i][1];

    // ★ ここで開始 > 終了をチェック
    Assert(L <= H,
      Format('TFlexAny: 第 %d 次元の範囲が不正です (Low:%d > High:%d)', [i + 1, L, H]));

    FDims[i].Low    := L;
    FDims[i].High   := H;
    FDims[i].Stride := CurrentStride;

    // 全要素数を累積計算
    CurrentStride := CurrentStride * (H - L + 1);
  end;

  Result := CurrentStride;
end;
{ --- 公開コンストラクタ --- }

// ① 新規生成（１次元限定）  例：TFlexAny<Double>.Create([1, 10]);
constructor TFlexArray<T>.Create(const Range: TArray<Integer>);
begin
  Create([Range]);
end;

// ① 新規生成（多次元）  例：TFlexAny<Double>.Create([[1, 10], [1, 12]]);
constructor TFlexArray<T>.Create(const Ranges: array of TArray<Integer>);
begin
  FTotalSize := InternalSetup(Ranges);

  SetLength(FData, FTotalSize);
  FHead := @FData[0];
end;

// ② 配列の偽装/コピ（1次元限定）　例：TFlexAny<Double>.Create([1, 10], src, True);
constructor TFlexArray<T>.Create(const Range: TArray<Integer>;
                         const Src: TArray<T>; ACopy: Boolean = False);
begin
  Create([Range], Src, Acopy);
end;

// ② 既存1次元配列の偽装/コピ（多次元へ）  例：TFlexAny<Double>.Create([[1, 10], [1, 12]], src, True);
constructor TFlexArray<T>.Create(const Ranges: array of TArray<Integer>;
                         const Src: TArray<T>; ACopy: Boolean = False);
begin
  FTotalSize := InternalSetup(Ranges);
  Assert(FTotalSize <= Length(Src), 'TFlexAny: 指定サイズが元の配列を超えています');

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

function TFlexArray<T>.GetOffset(const Indices: array of Integer): NativeInt;
var
  i: Integer;
begin
  // 次元数が合わない場合は「範囲外」
  if Length(Indices) <> Length(FDims) then Exit(-1);

  Result := 0;
  for i := 0 to High(FDims) do
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

function TFlexArray<T>.LBound(Dim: Integer): Integer; begin Result := FDims[Dim - 1].Low; end;
function TFlexArray<T>.UBound(Dim: Integer): Integer; begin Result := FDims[Dim - 1].High; end;
function TFlexArray<T>.Dimensions: Integer; begin Result := Length(FDims); end;

function TFlexArray<T>.GetEnumerator: TFlexEnumerator<T>;
begin
  Result := TFlexEnumerator<T>.Create(FHead, FTotalSize);
end;

{ TFlexAny<T>.TFlexEnumerator }

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
