object FrmMain: TFrmMain
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = 'Convert txt to csv'
  ClientHeight = 90
  ClientWidth = 533
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Droid Sans'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnDestroy = FormDestroy
  DesignSize = (
    533
    90)
  TextHeight = 17
  object lblFilename: TLabel
    Left = 8
    Top = 41
    Width = 4
    Height = 17
    Anchors = [akLeft, akRight, akBottom]
  end
  object btnConvert: TButton
    Left = 394
    Top = 17
    Width = 131
    Height = 25
    Action = actConvert
    Anchors = [akTop, akRight]
    TabOrder = 0
  end
  object Progress: TAdvProgress
    Left = 8
    Top = 65
    Width = 517
    Height = 17
    Anchors = [akLeft, akRight, akBottom]
    BarColor = clHighlight
    TabOrder = 1
    BkColor = clWindow
    Version = '1.2.0.0'
  end
  object txtFolder: TAdvEditBtn
    Left = 8
    Top = 16
    Width = 380
    Height = 25
    EmptyTextStyle = []
    FlatLineColor = 11250603
    FocusColor = clWhite
    FocusFontColor = 3881787
    LabelFont.Charset = DEFAULT_CHARSET
    LabelFont.Color = 4474440
    LabelFont.Height = -11
    LabelFont.Name = 'Tahoma'
    LabelFont.Style = []
    Lookup.Font.Charset = DEFAULT_CHARSET
    Lookup.Font.Color = clWindowText
    Lookup.Font.Height = -11
    Lookup.Font.Name = 'Arial'
    Lookup.Font.Style = []
    Lookup.Separator = ';'
    Color = clWhite
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 4474440
    Font.Height = -15
    Font.Name = 'Droid Sans'
    Font.Style = []
    ParentFont = False
    ShortCut = 0
    TabOrder = 2
    Text = ''
    Visible = True
    OnChange = txtFolderChange
    Version = '1.7.2.3'
    ButtonStyle = bsButton
    ButtonWidth = 16
    Flat = False
    Etched = False
    ButtonCaption = '...'
    ReadOnly = False
    OnClickBtn = txtFolderClickBtn
  end
  object alMain: TActionList
    Left = 352
    Top = 48
    object actConvert: TAction
      Caption = 'Convert'
      Enabled = False
      Hint = 'Convert the cordata files in the folder to CSV'
      OnExecute = actConvertExecute
      OnUpdate = actConvertUpdate
    end
    object actSelectFolder: TAction
      Caption = 'Select folder'
      Hint = 'Select the folder with the source files'
      OnExecute = actSelectFolderExecute
    end
  end
end
