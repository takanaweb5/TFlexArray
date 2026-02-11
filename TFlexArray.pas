unit TFlexArray;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math;

type
  TFlexAny<T> = record
  private
    type
      TDimension = record
        Low, High, Stride: NativeInt;
      end;
  private
    FData: TArray<T>;      // 実データ保持用
    FHead: Pointer;        // 物理先頭ポインタ
    FDims: TArray<TDimension>;
    FTotalSize: NativeInt;

    procedure SetupReference(APtr: Pointer; const ASizes, ALows: array of Integer; ACopy: Boolean);
    function GetOffset(const Indices: array of Integer): NativeInt;
    function GetValue(const Indices: array of Integer): T;
    procedure SetValue(const Indices: array of Integer; const Value: T);
  public
    // ① 新規生成： A := TFlexAny<Double>.Create(1, 10, 1, 12);
    constructor Create(const Ranges: array of const); overload;

    // ②〜④ 既存配列の偽装/コピー： A := TFlexAny<Double>.Create(Src, 1, 1);
    constructor Create(var Src: TArray<T>; L1: Integer; ACopy: Boolean = False); overload;
    constructor Create(var Src: TArray<TArray<T>>; L1, L2: Integer; ACopy: Boolean = False); overload;
    constructor Create(var Src: TArray<TArray<TArray<T>>>; L1, L2, L3: Integer; ACopy: Boolean = False); overload;

    function LBound(Dim: Integer = 1): Integer;
    function UBound(Dim: Integer = 1): Integer;
    function Dimensions: Integer;
    function GetEnumerator: TEnumerator<T>;

    property Items[const Indices: array of Integer]: T read GetValue write SetValue; default;
  end;

implementation

{ TFlexAny<T> }

procedure TFlexAny<T>.SetupReference(APtr: Pointer; const ASizes, ALows: array of Integer; ACopy: Boolean);
var
  i: Integer;
  CurrentStride: NativeInt;
begin
  SetLength(FDims, Length(ASizes));
  CurrentStride := 1;
  // Stride（歩幅）を後ろから順に確定
  for i := High(ASizes) downto 0 do
  begin
    FDims[i].Low := ALows[i];
    FDims[i].High := ALows[i] + ASizes[i] - 1;
    FDims[i].Stride := CurrentStride;
    CurrentStride := CurrentStride * ASizes[i];
  end;
  FTotalSize := CurrentStride;

  if ACopy then
  begin
    SetLength(FData, FTotalSize);
    FHead := @FData[0];
    if (FTotalSize > 0) and (APtr <> nil) then
      Move(APtr^, FHead^, FTotalSize * SizeOf(T));
  end
  else
    FHead := APtr;
end;

constructor TFlexAny<T>.Create(const Ranges: array of const);
var
  i, DimCount: Integer;
  Lows, Sizes: TArray<Integer>;
begin
  DimCount := Length(Ranges) div 2;
  SetLength(Lows, DimCount);
  SetLength(Sizes, DimCount);
  for i := 0 to DimCount - 1 do
  begin
    Lows[i] := Ranges[i * 2].VInteger;
    Sizes[i] := Ranges[i * 2 + 1].VInteger - Lows[i] + 1;
  end;
  SetupReference(nil, Sizes, Lows, True);
end;

constructor TFlexAny<T>.Create(var Src: TArray<T>; L1: Integer; ACopy: Boolean);
begin
  SetupReference(@Src[0], [Length(Src)], [L1], ACopy);
end;

constructor TFlexAny<T>.Create(var Src: TArray<TArray<T>>; L1, L2: Integer; ACopy: Boolean);
begin
  SetupReference(@Src[0, 0], [Length(Src), Length(Src[0])], [L1, L2], ACopy);
end;

constructor TFlexAny<T>.Create(var Src: TArray<TArray<TArray<T>>>; L1, L2, L3: Integer; ACopy: Boolean);
begin
  SetupReference(@Src[0, 0, 0], [Length(Src), Length(Src[0]), Length(Src[0, 0])], [L1, L2, L3], ACopy);
end;

function TFlexAny<T>.GetOffset(const Indices: array of Integer): NativeInt;
var i: Integer;
begin
  Result := 0;
  for i := 0 to High(Indices) do
    Result := Result + (NativeInt(Indices[i]) - FDims[i].Low) * FDims[i].Stride;
end;

function TFlexAny<T>.GetValue(const Indices: array of Integer): T;
begin
  // TArray<T>キャストにより、サイズTを考慮したポインタ演算が行われる
  Result := TArray<T>(FHead)[GetOffset(Indices)];
end;

procedure TFlexAny<T>.SetValue(const Indices: array of Integer; const Value: T);
begin
  TArray<T>(FHead)[GetOffset(Indices)] := Value;
end;

function TFlexAny<T>.LBound(Dim: Integer): Integer; begin Result := FDims[Dim - 1].Low; end;
function TFlexAny<T>.UBound(Dim: Integer): Integer; begin Result := FDims[Dim - 1].High; end;
function TFlexAny<T>.Dimensions: Integer; begin Result := Length(FDims); end;

function TFlexAny<T>.GetEnumerator: TEnumerator<T>;
begin
  // 連続したメモリブロック全体をイテレート可能
  Result := TEnumerable<T>.ToArrayEnumerator(TArray<T>(FHead));
end;

end.
