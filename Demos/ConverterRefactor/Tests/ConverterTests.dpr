program ConverterTests;

{
  Unit tests for ConverterRefactor (View, ViewModel, Model, factories).
  Fast, so they run in TestInsight: the .dproj defines TESTINSIGHT for the
  IDE. Without it (command-line builds) this is a console runner.

  The BDD feature scenarios are in ConverterFeatures, which runs on its own.
  Exe in Tests\Build, dcus in Tests\Build\dcu\Unit.
}

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  {$ENDIF}
  DUnitX.TestFramework,
  ConverterConst in '..\ConverterConst.pas',
  Dialogs.Int in '..\Dialogs.Int.pas',
  Main.Int in '..\Main.Int.pas',
  Main.View in '..\Main.View.pas' {FrmMain},
  Main.ViewModel in '..\Main.ViewModel.pas',
  Main.Model in '..\Main.Model.pas' {MainModel: TDataModule},
  Main.Registration in '..\Main.Registration.pas',
  Main.Fakes in 'Main.Fakes.pas',
  Main.Factory.Tests in 'Main.Factory.Tests.pas',
  Main.View.Tests in 'Main.View.Tests.pas',
  Main.Model.Tests in 'Main.Model.Tests.pas',
  Main.ViewModel.Tests in 'Main.ViewModel.Tests.pas',
  Main.ViewModel.Convert.Tests in 'Main.ViewModel.Convert.Tests.pas';

{$IFNDEF TESTINSIGHT}
var
  Runner: ITestRunner;
  Results: IRunResults;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    // Reads the DUnitX options, e.g. --exit:Pause from the IDE's run params
    TDUnitX.CheckCommandLine;
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
{$ENDIF}
end.
