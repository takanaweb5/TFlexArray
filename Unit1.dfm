object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 534
  ClientWidth = 758
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  DesignSize = (
    758
    534)
  TextHeight = 15
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 758
    Height = 495
    Align = alTop
    Anchors = [akLeft, akTop, akRight, akBottom]
    ScrollBars = ssVertical
    TabOrder = 0
    ExplicitWidth = 756
    ExplicitHeight = 487
  end
  object Button1: TButton
    Left = 24
    Top = 504
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Button1'
    TabOrder = 1
    OnClick = Button1Click
    ExplicitTop = 496
  end
end
