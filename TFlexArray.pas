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
    type
      // 内部専用の列挙子。これなら制約エラーも出ず、ポインタを直接スキャンできる。
      TFlexEnumerator<V> = class
      private
        FHead: Pointer;
        FTotalSize: NativeInt;
        FIndex: NativeInt;
        function GetCurrent: V;
      public
        constructor Create(AHead: Pointer; ASize: NativeInt);
        property Current: V read GetCurrent;
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
  public
    constructor Create(const Ranges: array of TArray<Integer>); overload;
    constructor Create(var Src: TArray<T>; ALow: Integer; ACopy: Boolean = False); overload;
    function LBound(Dim: Integer = 1): Integer;
    function UBound(Dim: Integer = 1): Integer;
    function Dimensions: Integer;
    function GetEnumerator: TFlexEnumerator<T>;
    property Items[const Indices: array of Integer]: T read GetValue write SetValue; default;
  end;

implementation

{ TFlexAny<T> }

// ① 新規生成（多次元）： A := TFlexAny<Double>.Create([[1, 10], [1, 12]]);
constructor TFlexAny<T>.Create(const Ranges: array of TArray<Integer>);
var
  i, DimCount: Integer;
  CurrentStride: NativeInt;
begin
  DimCount := Length(Ranges);
  SetLength(FDims, DimCount);

  // 多次元の設計図を後ろから組み立てる
  CurrentStride := 1;
  for i := DimCount - 1 downto 0 do
  begin
    FDims[i].Low := Ranges[i][0];
    FDims[i].High := Ranges[i][1];
    FDims[i].Stride := CurrentStride;
    CurrentStride := CurrentStride * (FDims[i].High - FDims[i].Low + 1);
  end;
  FTotalSize := CurrentStride;

  // メモリ確保
  SetLength(FData, FTotalSize);
  FHead := @FData[0];
end;

// ② 1次元既存偽装/コピー： A := TFlexAny<Double>.Create(Src, 1);
constructor TFlexAny<T>.Create(var Src: TArray<T>; ALow: Integer; ACopy: Boolean = False);
begin
  // 1次元に特化し、ループも計算関数も通らず一撃でセット
  FTotalSize := Length(Src);
  SetLength(FDims, 1);
  FDims[0].Low := ALow;
  FDims[0].High := ALow + FTotalSize - 1;
  FDims[0].Stride := 1;

  if ACopy then
  begin
    SetLength(FData, FTotalSize);
    FHead := @FData[0];
    if FTotalSize > 0 then
      Move(Src[0], FHead^, FTotalSize * SizeOf(T));
  end
  else
    FHead := Pointer(Src);
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

{ TFlexAny<T>.TFlexEnumerator }

constructor TFlexAny<T>.TFlexEnumerator<V>.Create(AHead: Pointer; ASize: NativeInt);
begin
  FHead := AHead;
  FTotalSize := ASize;
  FIndex := -1;
end;

function TFlexAny<T>.TFlexEnumerator<V>.GetCurrent: V;
begin
  // ポインタから直接アクセス（TArray偽装）
  Result := TArray<V>(FHead)[FIndex];
end;

function TFlexAny<T>.TFlexEnumerator<V>.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FTotalSize;
end;

{ TFlexAny<T> 本体 }

function TFlexAny<T>.GetEnumerator: TFlexEnumerator<T>;
begin
  // 参照でもコピーでも、FHead さえあればこの Enumerator は動く
  Result := TFlexEnumerator<T>.Create(FHead, FTotalSize);
end;

end.
