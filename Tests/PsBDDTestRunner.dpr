(*****************************************************************************
MIT License

Copyright (c) 2026 Proshine Window Cleaning (proshinewindowcleaning@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
******************************************************************************)

program PsBDDTestRunner;

{
  Console runner for the BDD framework tests. Build from this folder:

    dcc32 -B -Q -NSSystem;Winapi -U"<Studio>\lib\win32\release" -NUdcu -E. PsBDDTestRunner.dpr
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  PsBDD.Framework in '..\Source\PsBDD.Framework.pas',
  PsBDD.FeatureWriter in '..\Source\PsBDD.FeatureWriter.pas',
  PsBDD.MarkdownDocument in '..\Source\PsBDD.MarkdownDocument.pas',
  PsBDD.HTMLDocument in '..\Source\PsBDD.HTMLDocument.pas',
  PsBDD.Core.Tests in 'PsBDD.Core.Tests.pas',
  PsBDD.MarkdownDocument.Tests in 'PsBDD.MarkdownDocument.Tests.pas',
  PsBDD.Run.Tests in 'PsBDD.Run.Tests.pas',
  PsBDD.HTMLDocument.Tests in 'PsBDD.HTMLDocument.Tests.pas',
  PsBDD.Conversion.Tests in 'PsBDD.Conversion.Tests.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  try
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
  // Run with --exitbehavior:Pause to keep the window open
  if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
  begin
    Write('Done.. press <Enter> key to quit.');
    Readln;
  end;
end.
