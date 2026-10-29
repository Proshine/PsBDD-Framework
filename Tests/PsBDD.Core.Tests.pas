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

unit PsBDD.Core.Tests;

{
  DUnitX tests for the core of the BDD framework:
    - TPsBDDScenario              : steps, status, failures and teardown
    - TPsBDDFeatureDocumentWriter : which documents each write goes to

  No files are written. Fake documents and a fake scenario writer record
  every call in a log, and the tests compare the log with what they expect.

  A scenario writes its status when it is released. The chained calls of a
  fluent scenario keep hidden references that are only released when the
  method that made them ends, so every scenario is built in its own private
  Run... method and has ended, status written, when that method returns. The
  steps are private procedures too, as in any fixture that uses the
  framework.
}

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  PsBDD.Framework, PsBDD.FeatureWriter;

type
  [TestFixture]
  TPsBDDScenarioTests = class
  private
    FLog: TStringList;
    FWriter: IPsBDDScenarioDocumentWriter;
    FStepRan: Boolean;
    FThenRan: Boolean;
    procedure ExpectLog(const AExpected: array of string);

    // Scenarios. Each one has ended when its method returns.
    procedure RunFiveDocumentedSteps;
    procedure RunScenarioWithOneStep;
    procedure RunScenarioFailingAtGiven;
    procedure RunScenarioFailingAtWhen;
    procedure RunScenarioWithTeardown;
    procedure RunScenarioWithTeardownFailingAtGiven;
    procedure RunScenarioWithFailingTeardown;
    procedure RunScenarioWithFailingTeardownFailingAtGiven;
    procedure RunScenarioWithTwoTeardowns;
    procedure RunScenarioWithoutSteps;

    // Steps
    procedure StepRuns;
    procedure StepFails;
    procedure ThenStepRuns;
    procedure TeardownIsLogged;
    procedure SecondTeardownIsLogged;
    procedure TeardownFails;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Steps_AreDocumentedInOrder;
    [Test]
    procedure PassingScenario_WritesPassedWhenReleased;
    [Test]
    procedure FailingStep_IsRaisedAgain;
    [Test]
    procedure FailingStep_StopsTheChainAndWritesFailed;
    [Test]
    procedure Teardown_RunsBeforeTheStatusIsWritten;
    [Test]
    procedure Teardown_RunsWhenAStepFails;
    [Test]
    procedure FailingTeardown_FailsTheScenario;
    [Test]
    procedure FailingStepAndTeardown_ReportBothMessages;
    [Test]
    procedure SecondTeardown_RaisesInvalidOp;
    [Test]
    procedure NoSteps_WritesNoStatus;
    [Test]
    procedure NilWriter_StillRunsTheSteps;
  end;

  [TestFixture]
  TPsBDDFeatureDocumentWriterTests = class
  private
    FLog: TStringList;
    procedure ExpectLog(const AExpected: array of string);
    function CreateWriter: IPsBDDFeatureDocumentWriter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Open_OpensEveryDocument;
    [Test]
    procedure AddDocumentAfterOpen_OpensTheDocument;
    [Test]
    procedure WriteFeature_GoesOnlyToTheFeatureAudiences;
    [Test]
    procedure WriteRequirement_GoesOnlyToTheFeatureAudiences;
    [Test]
    procedure BeginScenario_WithoutAudiences_UsesTheFeatureAudiences;
    [Test]
    procedure BeginScenario_WithAudiences_OverridesTheFeatureAudiences;
    [Test]
    procedure ScenarioSteps_GoOnlyToTheDocumentsOfTheScenario;
    [Test]
    procedure DocumentsWithTheSameAudience_BothReceiveTheWrites;
    [Test]
    procedure Close_ClosesEveryDocumentAndRaisesTheErrorsTogether;
  end;

implementation

const
  STEP_FAILURE = 'step failed';
  TEARDOWN_FAILURE = 'cleanup failed';

type
  EStepFailed = class(Exception);

  /// <summary>Records every call of a scenario in a log.</summary>
  TFakeScenarioWriter = class(TInterfacedObject, IPsBDDScenarioDocumentWriter)
  private
    FLog: TStrings;
  public
    constructor Create(ALog: TStrings);
    procedure WriteGiven(const ADescription: string);
    procedure WriteWhen(const ADescription: string);
    procedure WriteThen(const ADescription: string);
    procedure WriteAnd(const ADescription: string);
    procedure WriteBut(const ADescription: string);
    procedure WriteStatus(AStatus: TPsBDDScenarioStatus; const AMessage: string);
  end;

  /// <summary>
  ///   Records every call in a log, each entry starting with the name of the
  ///   document. Close raises CloseError when it is set.
  /// </summary>
  TFakeDocument = class(TInterfacedObject, IPsBDDDocument)
  private
    FName: string;
    FTarget: TPsBDDDocumentTarget;
    FLog: TStrings;
    FCloseError: string;
    procedure Add(const AText: string);
  public
    constructor Create(const AName: string; AAudience: TPsBDDAudience;
      ALog: TStrings; const ACloseError: string = '');
    function GetTarget: TPsBDDDocumentTarget;
    procedure Open;
    procedure Close;
    procedure WriteFeature(const ATitle, ADescription: string;
      AStatus: TPsBDDFeatureStatus);
    procedure WriteRequirement(const AReference, AText: string);
    procedure WriteScenario(const ATitle: string);
    procedure WriteStep(AKind: TPsBDDStepKind; const ADescription: string);
    procedure WriteScenarioStatus(AStatus: TPsBDDScenarioStatus;
      const AMessage: string);
  end;

function StatusEntry(AStatus: TPsBDDScenarioStatus; const AMessage: string): string;
begin
  if AStatus = ssPassed then
    Result := 'Status: Passed'
  else
    Result := 'Status: Failed: ' + AMessage;
end;

{ TFakeScenarioWriter }

constructor TFakeScenarioWriter.Create(ALog: TStrings);
begin
  inherited Create;
  FLog := ALog;
end;

procedure TFakeScenarioWriter.WriteGiven(const ADescription: string);
begin
  FLog.Add('Given ' + ADescription);
end;

procedure TFakeScenarioWriter.WriteWhen(const ADescription: string);
begin
  FLog.Add('When ' + ADescription);
end;

procedure TFakeScenarioWriter.WriteThen(const ADescription: string);
begin
  FLog.Add('Then ' + ADescription);
end;

procedure TFakeScenarioWriter.WriteAnd(const ADescription: string);
begin
  FLog.Add('And ' + ADescription);
end;

procedure TFakeScenarioWriter.WriteBut(const ADescription: string);
begin
  FLog.Add('But ' + ADescription);
end;

procedure TFakeScenarioWriter.WriteStatus(AStatus: TPsBDDScenarioStatus;
  const AMessage: string);
begin
  FLog.Add(StatusEntry(AStatus, AMessage));
end;

{ TFakeDocument }

constructor TFakeDocument.Create(const AName: string; AAudience: TPsBDDAudience;
  ALog: TStrings; const ACloseError: string);
begin
  inherited Create;
  FName := AName;
  FTarget.Audience := AAudience;
  FTarget.Path := AName + '.md';
  FLog := ALog;
  FCloseError := ACloseError;
end;

procedure TFakeDocument.Add(const AText: string);
begin
  FLog.Add(FName + ' ' + AText);
end;

function TFakeDocument.GetTarget: TPsBDDDocumentTarget;
begin
  Result := FTarget;
end;

procedure TFakeDocument.Open;
begin
  Add('Open');
end;

procedure TFakeDocument.Close;
begin
  Add('Close');
  if FCloseError <> '' then
    raise Exception.Create(FCloseError);
end;

procedure TFakeDocument.WriteFeature(const ATitle, ADescription: string;
  AStatus: TPsBDDFeatureStatus);
begin
  Add('Feature ' + ATitle);
end;

procedure TFakeDocument.WriteRequirement(const AReference, AText: string);
begin
  Add('Requirement ' + AReference);
end;

procedure TFakeDocument.WriteScenario(const ATitle: string);
begin
  Add('Scenario ' + ATitle);
end;

procedure TFakeDocument.WriteStep(AKind: TPsBDDStepKind;
  const ADescription: string);
begin
  Add('Step ' + ADescription);
end;

procedure TFakeDocument.WriteScenarioStatus(AStatus: TPsBDDScenarioStatus;
  const AMessage: string);
begin
  Add(StatusEntry(AStatus, AMessage));
end;

{ TPsBDDScenarioTests }

procedure TPsBDDScenarioTests.Setup;
begin
  FLog := TStringList.Create;
  FWriter := TFakeScenarioWriter.Create(FLog);
  FStepRan := False;
  FThenRan := False;
end;

procedure TPsBDDScenarioTests.TearDown;
begin
  FWriter := nil;
  FreeAndNil(FLog);
end;

procedure TPsBDDScenarioTests.ExpectLog(const AExpected: array of string);
begin
  Assert.AreEqual(string.Join(sLineBreak, AExpected),
    string.Join(sLineBreak, FLog.ToStringArray));
end;

{ Scenarios }

procedure TPsBDDScenarioTests.RunFiveDocumentedSteps;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Given(nil, 'a customer')
    .When(nil, 'it is saved')
    .&Then(nil, 'it is found')
    .&And(nil, 'it is audited')
    .But(nil, 'it is not duplicated');
end;

procedure TPsBDDScenarioTests.RunScenarioWithOneStep;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario.Given(StepRuns, 'a step');
  // Not ended yet: the status is written only when it is released
  Assert.AreEqual(-1, FLog.IndexOf(StatusEntry(ssPassed, '')),
    'The status was written before the scenario ended');
end;

procedure TPsBDDScenarioTests.RunScenarioFailingAtGiven;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario.Given(StepFails, 'a failing step');
end;

procedure TPsBDDScenarioTests.RunScenarioFailingAtWhen;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Given(nil, 'a customer')
    .When(StepFails, 'it is saved')
    .&Then(ThenStepRuns, 'it is found');
end;

procedure TPsBDDScenarioTests.RunScenarioWithTeardown;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Teardown(TeardownIsLogged)
    .Given(nil, 'a customer');
  Assert.AreEqual(-1, FLog.IndexOf('Teardown'),
    'Teardown ran before the scenario ended');
end;

procedure TPsBDDScenarioTests.RunScenarioWithTeardownFailingAtGiven;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Teardown(TeardownIsLogged)
    .Given(StepFails, 'a failing step');
end;

procedure TPsBDDScenarioTests.RunScenarioWithFailingTeardown;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Teardown(TeardownFails)
    .Given(nil, 'a customer');
end;

procedure TPsBDDScenarioTests.RunScenarioWithFailingTeardownFailingAtGiven;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Teardown(TeardownFails)
    .Given(StepFails, 'a failing step');
end;

procedure TPsBDDScenarioTests.RunScenarioWithTwoTeardowns;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
  Scenario
    .Teardown(TeardownIsLogged)
    .Teardown(SecondTeardownIsLogged);
end;

procedure TPsBDDScenarioTests.RunScenarioWithoutSteps;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(FWriter);
end;

{ Steps }

procedure TPsBDDScenarioTests.StepRuns;
begin
  FStepRan := True;
end;

procedure TPsBDDScenarioTests.StepFails;
begin
  raise EStepFailed.Create(STEP_FAILURE);
end;

procedure TPsBDDScenarioTests.ThenStepRuns;
begin
  FThenRan := True;
end;

procedure TPsBDDScenarioTests.TeardownIsLogged;
begin
  FLog.Add('Teardown');
end;

procedure TPsBDDScenarioTests.SecondTeardownIsLogged;
begin
  FLog.Add('Second teardown');
end;

procedure TPsBDDScenarioTests.TeardownFails;
begin
  raise Exception.Create(TEARDOWN_FAILURE);
end;

{ Tests }

procedure TPsBDDScenarioTests.Steps_AreDocumentedInOrder;
begin
  RunFiveDocumentedSteps;

  ExpectLog([
    'Given a customer',
    'When it is saved',
    'Then it is found',
    'And it is audited',
    'But it is not duplicated',
    'Status: Passed']);
end;

procedure TPsBDDScenarioTests.PassingScenario_WritesPassedWhenReleased;
begin
  RunScenarioWithOneStep;

  Assert.IsTrue(FStepRan, 'The step action did not run');
  ExpectLog(['Given a step', 'Status: Passed']);
end;

procedure TPsBDDScenarioTests.FailingStep_IsRaisedAgain;
begin
  Assert.WillRaise(RunScenarioFailingAtGiven, EStepFailed);
end;

procedure TPsBDDScenarioTests.FailingStep_StopsTheChainAndWritesFailed;
begin
  Assert.WillRaise(RunScenarioFailingAtWhen, EStepFailed);

  Assert.IsFalse(FThenRan, 'A step after the failing step ran');
  // The failing step is documented before it runs, so it is the last step
  ExpectLog([
    'Given a customer',
    'When it is saved',
    StatusEntry(ssFailed, STEP_FAILURE)]);
end;

procedure TPsBDDScenarioTests.Teardown_RunsBeforeTheStatusIsWritten;
begin
  RunScenarioWithTeardown;

  ExpectLog(['Given a customer', 'Teardown', 'Status: Passed']);
end;

procedure TPsBDDScenarioTests.Teardown_RunsWhenAStepFails;
begin
  Assert.WillRaise(RunScenarioWithTeardownFailingAtGiven, EStepFailed);

  ExpectLog([
    'Given a failing step',
    'Teardown',
    StatusEntry(ssFailed, STEP_FAILURE)]);
end;

procedure TPsBDDScenarioTests.FailingTeardown_FailsTheScenario;
begin
  // The teardown error is reported in the status, never raised
  Assert.WillNotRaiseAny(RunScenarioWithFailingTeardown);

  ExpectLog([
    'Given a customer',
    StatusEntry(ssFailed, 'Teardown failed: ' + TEARDOWN_FAILURE)]);
end;

procedure TPsBDDScenarioTests.FailingStepAndTeardown_ReportBothMessages;
begin
  Assert.WillRaise(RunScenarioWithFailingTeardownFailingAtGiven, EStepFailed);

  ExpectLog([
    'Given a failing step',
    StatusEntry(ssFailed,
      STEP_FAILURE + sLineBreak + 'Teardown failed: ' + TEARDOWN_FAILURE)]);
end;

procedure TPsBDDScenarioTests.SecondTeardown_RaisesInvalidOp;
begin
  Assert.WillRaise(RunScenarioWithTwoTeardowns, EInvalidOpException);

  // The first teardown is kept and still runs. No step ran, so no status.
  ExpectLog(['Teardown']);
end;

procedure TPsBDDScenarioTests.NoSteps_WritesNoStatus;
begin
  RunScenarioWithoutSteps;

  ExpectLog([]);
end;

procedure TPsBDDScenarioTests.NilWriter_StillRunsTheSteps;
begin
  FWriter := nil;

  RunScenarioWithOneStep;

  Assert.IsTrue(FStepRan, 'The step action did not run');
end;

{ TPsBDDFeatureDocumentWriterTests }

procedure TPsBDDFeatureDocumentWriterTests.Setup;
begin
  FLog := TStringList.Create;
end;

procedure TPsBDDFeatureDocumentWriterTests.TearDown;
begin
  FreeAndNil(FLog);
end;

procedure TPsBDDFeatureDocumentWriterTests.ExpectLog(
  const AExpected: array of string);
begin
  Assert.AreEqual(string.Join(sLineBreak, AExpected),
    string.Join(sLineBreak, FLog.ToStringArray));
end;

// A writer with one document per audience, opened, with an empty log
function TPsBDDFeatureDocumentWriterTests.CreateWriter: IPsBDDFeatureDocumentWriter;
begin
  Result := TPsBDDFeatureDocumentWriter.Create;
  Result.Title := 'Customer list';
  Result.RequirementReference := 'REQ#014';
  Result.AddDocument(TFakeDocument.Create('Developer', auDeveloper, FLog));
  Result.AddDocument(TFakeDocument.Create('Tester', auTester, FLog));
  Result.AddDocument(TFakeDocument.Create('Business', auBusiness, FLog));
  Result.Open;
  FLog.Clear;
end;

procedure TPsBDDFeatureDocumentWriterTests.Open_OpensEveryDocument;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := TPsBDDFeatureDocumentWriter.Create;
  Writer.AddDocument(TFakeDocument.Create('Developer', auDeveloper, FLog));
  Writer.AddDocument(TFakeDocument.Create('Business', auBusiness, FLog));
  Assert.AreEqual(0, FLog.Count, 'A document was opened before Open');

  Writer.Open;

  ExpectLog(['Developer Open', 'Business Open']);
end;

procedure TPsBDDFeatureDocumentWriterTests.AddDocumentAfterOpen_OpensTheDocument;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := CreateWriter;

  Writer.AddDocument(TFakeDocument.Create('Acceptance', auAcceptance, FLog));

  ExpectLog(['Acceptance Open']);
end;

procedure TPsBDDFeatureDocumentWriterTests.WriteFeature_GoesOnlyToTheFeatureAudiences;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := CreateWriter;
  Writer.Audiences := [auBusiness, auTester];

  Writer.WriteFeature;

  // In the order the documents were added, not the order of the set
  ExpectLog(['Tester Feature Customer list', 'Business Feature Customer list']);
end;

procedure TPsBDDFeatureDocumentWriterTests.WriteRequirement_GoesOnlyToTheFeatureAudiences;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := CreateWriter;
  Writer.Audiences := [auDeveloper];

  Writer.WriteRequirement;

  ExpectLog(['Developer Requirement REQ#014']);
end;

procedure TPsBDDFeatureDocumentWriterTests.BeginScenario_WithoutAudiences_UsesTheFeatureAudiences;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := CreateWriter;
  Writer.Audiences := [auTester];

  Writer.BeginScenario('Customer is found');

  ExpectLog(['Tester Scenario Customer is found']);
end;

procedure TPsBDDFeatureDocumentWriterTests.BeginScenario_WithAudiences_OverridesTheFeatureAudiences;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := CreateWriter;
  Writer.Audiences := [auBusiness];

  Writer.BeginScenario('Customer is found', [auDeveloper, auTester]);

  ExpectLog([
    'Developer Scenario Customer is found',
    'Tester Scenario Customer is found']);
end;

procedure TPsBDDFeatureDocumentWriterTests.ScenarioSteps_GoOnlyToTheDocumentsOfTheScenario;
var
  Writer: IPsBDDFeatureDocumentWriter;
  ScenarioWriter: IPsBDDScenarioDocumentWriter;
begin
  Writer := CreateWriter;
  ScenarioWriter := Writer.BeginScenario('Customer is found', [auBusiness]);
  FLog.Clear;

  ScenarioWriter.WriteGiven('a customer list');
  ScenarioWriter.WriteStatus(ssFailed, STEP_FAILURE);

  ExpectLog([
    'Business Step a customer list',
    'Business ' + StatusEntry(ssFailed, STEP_FAILURE)]);
end;

procedure TPsBDDFeatureDocumentWriterTests.DocumentsWithTheSameAudience_BothReceiveTheWrites;
var
  Writer: IPsBDDFeatureDocumentWriter;
begin
  Writer := TPsBDDFeatureDocumentWriter.Create;
  Writer.Title := 'Customer list';
  Writer.AddDocument(TFakeDocument.Create('Markdown', auBusiness, FLog));
  Writer.AddDocument(TFakeDocument.Create('Html', auBusiness, FLog));
  Writer.Open;
  FLog.Clear;

  Writer.WriteFeature;

  ExpectLog(['Markdown Feature Customer list', 'Html Feature Customer list']);
end;

procedure TPsBDDFeatureDocumentWriterTests.Close_ClosesEveryDocumentAndRaisesTheErrorsTogether;
var
  Writer: IPsBDDFeatureDocumentWriter;
  LMessage: string;
begin
  Writer := TPsBDDFeatureDocumentWriter.Create;
  Writer.AddDocument(TFakeDocument.Create('A', auDeveloper, FLog, 'A failed'));
  Writer.AddDocument(TFakeDocument.Create('B', auTester, FLog));
  Writer.AddDocument(TFakeDocument.Create('C', auBusiness, FLog, 'C failed'));
  Writer.Open;
  FLog.Clear;

  LMessage := '';
  try
    Writer.Close;
  except
    on E: Exception do
      LMessage := E.Message;
  end;

  ExpectLog(['A Close', 'B Close', 'C Close']);
  Assert.AreEqual('A failed' + sLineBreak + 'C failed', LMessage);
end;

initialization
  TDUnitX.RegisterTestFixture(TPsBDDScenarioTests);
  TDUnitX.RegisterTestFixture(TPsBDDFeatureDocumentWriterTests);

end.
