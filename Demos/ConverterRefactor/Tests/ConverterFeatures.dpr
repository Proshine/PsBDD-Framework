program ConverterFeatures;

{
  Console runner for the ConverterRefactor BDD feature scenarios. They drive
  real windows and are slower than the unit tests, so they run on their own,
  not in TestInsight (the unit tests are in ConverterTests).

  Exe in Tests\Build, dcus in Tests\Build\dcu\Features, BDD documents in
  Tests\BDDOutput: one per feature, and AllFeatures.md / .html with every
  feature of the run below the preamble (Tests\Preamble.md / .html).
  Close any running CSVConvert.exe first.
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  PsBDD.Framework in '..\..\..\Source\PsBDD.Framework.pas',
  PsBDD.FeatureWriter in '..\..\..\Source\PsBDD.FeatureWriter.pas',
  PsBDD.MarkdownDocument in '..\..\..\Source\PsBDD.MarkdownDocument.pas',
  PsBDD.HTMLDocument in '..\..\..\Source\PsBDD.HTMLDocument.pas',
  Feature.Documents in 'Feature.Documents.pas',
  AppController in '..\AppController.pas',
  ConverterConst in '..\ConverterConst.pas',
  Dialogs.Int in '..\Dialogs.Int.pas',
  Main.Int in '..\Main.Int.pas',
  Main.View in '..\Main.View.pas' {FrmMain},
  Main.ViewModel in '..\Main.ViewModel.pas',
  Main.Model in '..\Main.Model.pas' {MainModel: TDataModule},
  Main.Registration in '..\Main.Registration.pas',
  Converter.Feature.Tests in 'Converter.Feature.Tests.pas',
  SingleInstance.Feature.Tests in 'SingleInstance.Feature.Tests.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  try
    // Reads the DUnitX options, e.g. --exit:Pause from the IDE's run params
    TDUnitX.CheckCommandLine;
    // Every run starts new combined documents, with the preamble; the
    // previous ones are kept, named with their time
    TPsBDDRun.RunStart := rsArchive;
    RegisterPreambles;
    Runner := TDUnitX.CreateRunner;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Runner.FailsOnNoAsserts := False;
    Results := Runner.Execute;
    if not Results.AllPassed then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
  if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
  begin
    Write('Done. Press <Enter> to quit.');
    Readln;
  end;
end.
