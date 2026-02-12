object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 537
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  DesignSize = (
    760
    537)
  TextHeight = 15
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 760
    Height = 498
    Align = alTop
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object Button1: TButton
    Left = 8
    Top = 504
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Button1'
    TabOrder = 1
    OnClick = Button1Click
    ExplicitTop = 400
  end
end
