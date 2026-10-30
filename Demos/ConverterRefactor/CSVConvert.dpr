program CSVConvert;

uses
  {$IFDEF DEBUG}
  FastMM4,   // must be the first unit
  {$ENDIF}
  AppController in 'AppController.pas',
  ConverterConst in 'ConverterConst.pas',
  Dialogs.Int in 'Dialogs.Int.pas',
  Dialogs.FolderDialog in 'Dialogs.FolderDialog.pas',
  Dialogs.Registration in 'Dialogs.Registration.pas',
  Main.Int in 'Main.Int.pas',
  Main.View in 'Main.View.pas' {FrmMain},
  Main.ViewModel in 'Main.ViewModel.pas',
  Main.Model in 'Main.Model.pas' {MainModel: TDataModule},
  Main.Registration in 'Main.Registration.pas';

{$R *.res}

begin
  TAppController.Run;
end.
