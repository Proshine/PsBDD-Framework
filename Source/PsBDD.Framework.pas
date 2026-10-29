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

unit PsBDD.Framework;

{
  BDD (Given / When / Then / And / But) framework for DUnitX tests.

  The core of the framework. Every other BDD unit and every test unit uses
  it. It contains:
    - TPsBDDAudience / TPsBDDAudiences : who a feature or scenario is for
    - TPsBDDFeatureStatus               : proposed ... deprecated
    - TPsBDDScenarioStatus              : passed or failed
    - TPsBDDDocumentTarget           : audience, path and mode of one document
    - IPsBDDConversion             : a conversion to perform when the run is
                                     finished, for example Markdown to PDF
    - TPsBDDRunStart / TPsBDDRun       : what a test run does with an existing
                                     document that is added to
    - IPsBDDDocument                 : one output document (Markdown, HTML, ...)
    - IPsBDDScenarioDocumentWriter   : writes the steps of one scenario
    - IPsBDDFeatureDocumentWriter    : owns the documents, opens and closes them
    - IPsBDDScenario                 : fluent Given / When / Then / And / But / Teardown
    - TPsBDDScenario                 : the implementation of IPsBDDScenario

  The implementations live in their own units:
    - PsBDD.FeatureWriter : TPsBDDFeatureDocumentWriter
    - PsBDD.MarkdownDocument      : TPsBDDMarkdownDocument

  Typical use inside a DUnitX test fixture:

    uses
      DUnitX.TestFramework,
      PsBDD.Framework, PsBDD.FeatureWriter, PsBDD.MarkdownDocument;

    procedure TMyFixture.SetupFixture;
    begin
      FFeatureWriter := TPsBDDFeatureDocumentWriter.Create;
      FFeatureWriter.Title := 'Customer maintenance';
      FFeatureWriter.Description := 'Customers can be created and saved.';
      FFeatureWriter.RequirementReference := 'REQ#001';
      FFeatureWriter.RequirementText := 'The system shall save a new customer.';
      FFeatureWriter.Audiences := [auBusiness, auTester];
      FFeatureWriter.Status := fsInDevelopment;
      FFeatureWriter.AddDocument(
        TPsBDDMarkdownDocument.Create('C:\Docs\Business.md', auBusiness, False));
      FFeatureWriter.AddDocument(
        TPsBDDMarkdownDocument.Create('C:\Docs\Tests.md', auTester, True));
      FFeatureWriter.Open;
      FFeatureWriter.WriteFeature;
      FFeatureWriter.WriteRequirement;
    end;

    procedure TMyFixture.TearDownFixture;
    begin
      FFeatureWriter.Close;
    end;

    procedure TMyFixture.CustomerCanBeSaved;
    var
      Scenario: IPsBDDScenario;
    begin
      Scenario := TPsBDDScenario.Create(
        FFeatureWriter.BeginScenario('Customer can be saved'));
      Scenario
        .Teardown(DeleteCustomer)
        .Given(SetupCustomer, 'a new customer')
        .When(SaveCustomer, 'the customer is saved')
        .&Then(CheckCustomerExists, 'the customer can be found')
        .&And(CheckAuditEntry, 'an audit entry is written')
        .But(CheckNoDuplicate, 'no duplicate customer is created');
    end;

  Call Teardown first, before the first Given. A failing step stops the
  chain, so a Teardown placed after it would never be registered and the
  cleanup would never run. Registered first, it always runs when the
  scenario ends, like a finally block.

  Note: Then and And are reserved words in Delphi, so they are declared and
  called with the & prefix (.&Then and .&And). But is not reserved and needs
  no prefix.

  Run start

    TPsBDDRun.RunStart decides what happens to an existing document that is
    added to (StandAlone = False) the first time it is opened in a test run:

      rsAppend    (default) the run is added to the existing document
      rsOverwrite the existing document is deleted and a new one is started
      rsArchive   the existing document is renamed with its last write time,
                  for example Features_2026-10-27_143012.md, and a new one
                  is started

    Every later open of the same document in the run adds to what the first
    one started, so all the features of a run end up in one document. Set it
    once in the DUnitX project file, before the runner executes:

      begin
        TPsBDDRun.RunStart := rsArchive;
        Runner := TDUnitX.CreateRunner;
        ...
        Results := Runner.Execute;

    A run is the test process: documents are recognised by their full path,
    ignoring case, for as long as the test executable runs. Stand alone
    documents replace their file on every open and are not affected.

  Preamble

    A document that is added to can start with a preamble that introduces
    it, for example the application the features are for. Write it in the
    same format as the document and register it in the project file:

      TPsBDDRun.AddPreamble('C:\Docs\AllFeatures.md', 'C:\Docs\Preamble.md');
      TPsBDDRun.AddPreamble('C:\Docs\AllFeatures.html', 'C:\Docs\Preamble.html');

    It is copied to the top of the document, above the table of contents,
    when the document is created: on the first run, and on every run that
    RunStart starts afresh. It is optional: until the preamble file exists
    the document is written without one. Stand alone documents have none.

  Conversions

    Some outputs can only be made once every fixture has written its
    documents, for example a PDF made from the combined Markdown document.
    Register them as IPsBDDConversion in the project file and perform them
    after the runner, in a finally block so they also run when the runner
    raises:

      begin
        TPsBDDRun.AddConversion(
          TPsBDDTMSPDFConversion.Create('Features.md', 'Features.pdf'));
        Runner := TDUnitX.CreateRunner;
        ...
        try
          Results := Runner.Execute;
        finally
          TPsBDDRun.PerformConversions;
        end;

    Every conversion runs even when another one fails. The errors are then
    raised together.
}

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  /// <summary>
  ///   The audience a document, feature or scenario is written for.
  ///   auAcceptance is for a requirement acceptance document.
  /// </summary>
  TPsBDDAudience = (auDeveloper, auTester, auBusiness, auAcceptance);

  /// <summary>
  ///   A set of audiences. A feature or scenario can apply to several.
  /// </summary>
  TPsBDDAudiences = set of TPsBDDAudience;

  /// <summary>
  ///   Where a feature is in its life cycle.
  /// </summary>
  TPsBDDFeatureStatus = (
    fsProposed,
    fsInDevelopment,
    fsImplemented,
    fsAccepted,
    fsDeprecated
  );

  /// <summary>
  ///   The outcome of a scenario.
  /// </summary>
  TPsBDDScenarioStatus = (ssPassed, ssFailed);

  /// <summary>
  ///   The kind of a scenario step.
  /// </summary>
  TPsBDDStepKind = (skGiven, skWhen, skThen, skAnd, skBut);

  /// <summary>
  ///   Describes one output document.
  /// </summary>
  TPsBDDDocumentTarget = record
    /// <summary>
    ///   The audience of the document. A step is written to the document
    ///   when this audience is in the audiences of its scenario.
    /// </summary>
    Audience: TPsBDDAudience;
    /// <summary>The path of the document file.</summary>
    Path: string;
    /// <summary>
    ///   True writes a new stand alone document at Path, replacing any
    ///   existing file. False adds to the existing document at Path. When
    ///   the format supports it, features and scenarios added to an
    ///   existing document are also listed in its table of contents.
    /// </summary>
    StandAlone: Boolean;
  end;

  /// <summary>
  ///   What happens to an existing document that is added to, the first
  ///   time it is opened in a test run.
  /// </summary>
  TPsBDDRunStart = (
    /// <summary>The run is added to the existing document.</summary>
    rsAppend,
    /// <summary>
    ///   The existing document is deleted and a new one is started.
    /// </summary>
    rsOverwrite,
    /// <summary>
    ///   The existing document is renamed with its last write time and a new
    ///   one is started.
    /// </summary>
    rsArchive
  );

  /// <summary>
  ///   One conversion to perform when the test run is finished, for example
  ///   a Markdown document to PDF. Register it with TPsBDDRun.AddConversion.
  /// </summary>
  IPsBDDConversion = interface
    ['{5E2B8C47-1F93-4A6D-B0C5-8D74E19A3F62}']
    function GetDescription: string;

    /// <summary>Performs the conversion. Raises an exception when it fails.</summary>
    procedure Convert;

    /// <summary>
    ///   Says what the conversion does, for example
    ///   'Features.md to Features.pdf'. Starts its error message.
    /// </summary>
    property Description: string read GetDescription;
  end;

  /// <summary>
  ///   The test run, which is the test process. Remembers which documents
  ///   were opened in the run and applies RunStart the first time each one
  ///   is opened. Holds the conversions to perform when the run is finished.
  /// </summary>
  /// <remarks>
  ///   Set RunStart and add the conversions once in the DUnitX project file,
  ///   before the runner executes. Call PerformConversions after it.
  /// </remarks>
  TPsBDDRun = class
  strict private
    class var FRunStart: TPsBDDRunStart;
    class var FStarted: TDictionary<string, Boolean>;
    class var FConversions: TList<IPsBDDConversion>;
    class var FPreambles: TDictionary<string, string>;
    class var FLock: TObject;
    class constructor Create;
    class destructor Destroy;
    class function ArchiveFile(const APath: string): string; static;
    class function PathKey(const APath: string): string; static;
  public
    /// <summary>
    ///   Registers the preamble of a document that is added to: a file in
    ///   the same format as the document (Markdown for a .md document, the
    ///   body content of a page for an .html document) that introduces it,
    ///   for example the application the features are for. It is written at
    ///   the top of the document, above the table of contents, when the
    ///   document is created. It is optional: when the preamble file does
    ///   not exist the document is written without it.
    /// </summary>
    class procedure AddPreamble(const ADocumentPath, APreamblePath: string); static;

    /// <summary>
    ///   The lines of the preamble registered for ADocumentPath, trailing
    ///   blank lines removed. Empty when none is registered or its file does
    ///   not exist. Called by a document when it creates a new file.
    /// </summary>
    class function PreambleFor(const ADocumentPath: string): TArray<string>; static;

    /// <summary>
    ///   Registers a conversion to perform when the run is finished.
    ///   Conversions are performed in the order they were added.
    /// </summary>
    class procedure AddConversion(const AConversion: IPsBDDConversion); static;

    /// <summary>
    ///   Performs every registered conversion and forgets them, so a second
    ///   call does nothing. Every conversion runs even when another one
    ///   fails. The errors are then raised together, each starting with the
    ///   description of its conversion.
    /// </summary>
    /// <remarks>
    ///   Call it once in the project file after Runner.Execute, in a finally
    ///   block. It can't run by itself when the program ends: by then the
    ///   units a conversion uses may already be finalized.
    /// </remarks>
    class procedure PerformConversions; static;

    /// <summary>
    ///   Called by a document that is added to when it opens, before it
    ///   loads the existing file. The first time APath is opened in the run
    ///   the existing file is kept, deleted or archived, as RunStart says.
    ///   Does nothing on later opens.
    /// </summary>
    class procedure BeginDocument(const APath: string); static;

    /// <summary>
    ///   Forgets the documents opened so far, so the next open of each one
    ///   acts like the first of a new run, and the registered conversions
    ///   and preambles. For tests.
    /// </summary>
    class procedure Reset; static;

    /// <summary>
    ///   What happens to an existing document that is added to, the first
    ///   time it is opened in the run. rsAppend by default.
    /// </summary>
    class property RunStart: TPsBDDRunStart read FRunStart write FRunStart;
  end;

  /// <summary>
  ///   One output document in a specific format, for example Markdown or
  ///   HTML. The feature document writer owns the documents, opens and
  ///   closes them and decides which documents each write goes to.
  /// </summary>
  IPsBDDDocument = interface
    ['{4A7F2C91-8D35-4E60-B1A8-3C5E9F70D246}']
    function GetTarget: TPsBDDDocumentTarget;

    /// <summary>
    ///   Prepares the document for writing: starts an empty document when
    ///   stand alone, otherwise loads the existing document. Does nothing
    ///   when already open.
    /// </summary>
    procedure Open;

    /// <summary>
    ///   Saves the document to its path when anything was written to it,
    ///   then closes it. Does nothing when not open.
    /// </summary>
    procedure Close;

    procedure WriteFeature(const ATitle, ADescription: string;
      AStatus: TPsBDDFeatureStatus);
    procedure WriteRequirement(const AReference, AText: string);
    procedure WriteScenario(const ATitle: string);
    procedure WriteStep(AKind: TPsBDDStepKind; const ADescription: string);
    procedure WriteScenarioStatus(AStatus: TPsBDDScenarioStatus;
      const AMessage: string);

    property Target: TPsBDDDocumentTarget read GetTarget;
  end;

  /// <summary>
  ///   Writes the steps of a single BDD scenario to the documents whose
  ///   audience applies to the scenario. Returned by
  ///   IPsBDDFeatureDocumentWriter.BeginScenario.
  /// </summary>
  IPsBDDScenarioDocumentWriter = interface
    ['{7C1E5B3A-4D92-4F68-9A0B-2E8F6D31C5A7}']
    procedure WriteGiven(const ADescription: string);
    procedure WriteWhen(const ADescription: string);
    procedure WriteThen(const ADescription: string);
    procedure WriteAnd(const ADescription: string);
    procedure WriteBut(const ADescription: string);

    /// <summary>
    ///   Called when the scenario ends: writes whether it passed or failed.
    ///   AMessage is the failure message, empty when the scenario passed.
    /// </summary>
    procedure WriteStatus(AStatus: TPsBDDScenarioStatus; const AMessage: string);
  end;

  /// <summary>
  ///   Owns the output documents of a feature, opens and closes them and
  ///   writes the feature header, the requirement and the scenarios to the
  ///   documents whose audience applies.
  /// </summary>
  /// <remarks>
  ///   Create the writer in the DUnitX SetupFixture method, assign the
  ///   properties, add the documents, call Open and the write methods that
  ///   are needed. Call Close in TearDownFixture.
  /// </remarks>
  IPsBDDFeatureDocumentWriter = interface
    ['{B3A94E12-6F07-4C5D-8E21-90D7A4C6F3B8}']
    function GetTitle: string;
    procedure SetTitle(const AValue: string);
    function GetDescription: string;
    procedure SetDescription(const AValue: string);
    function GetRequirementReference: string;
    procedure SetRequirementReference(const AValue: string);
    function GetRequirementText: string;
    procedure SetRequirementText(const AValue: string);
    function GetAudiences: TPsBDDAudiences;
    procedure SetAudiences(const AValue: TPsBDDAudiences);
    function GetStatus: TPsBDDFeatureStatus;
    procedure SetStatus(AValue: TPsBDDFeatureStatus);

    /// <summary>Adds an output document, for example a Markdown file.</summary>
    procedure AddDocument(const ADocument: IPsBDDDocument);

    /// <summary>Opens every added document.</summary>
    procedure Open;

    /// <summary>
    ///   Saves and closes every added document. Safe to call more than once.
    /// </summary>
    procedure Close;

    /// <summary>
    ///   Writes the Title, Description and Status to the documents whose
    ///   audience is in Audiences.
    /// </summary>
    procedure WriteFeature;

    /// <summary>
    ///   Writes the RequirementReference and RequirementText to the
    ///   documents whose audience is in Audiences.
    /// </summary>
    procedure WriteRequirement;

    /// <summary>
    ///   Writes the scenario heading and returns the writer for its steps.
    /// </summary>
    /// <param name="ATitle">The scenario title.</param>
    /// <param name="AAudiences">
    ///   The audiences the scenario applies to. An empty set uses the
    ///   Audiences of the feature.
    /// </param>
    function BeginScenario(const ATitle: string;
      AAudiences: TPsBDDAudiences = []): IPsBDDScenarioDocumentWriter;

    /// <summary>The feature title.</summary>
    property Title: string read GetTitle write SetTitle;

    /// <summary>The feature description.</summary>
    property Description: string read GetDescription write SetDescription;

    /// <summary>
    ///   The requirement number or reference, for example REQ#001.
    /// </summary>
    property RequirementReference: string
      read GetRequirementReference write SetRequirementReference;

    /// <summary>The text of the requirement the feature satisfies.</summary>
    property RequirementText: string
      read GetRequirementText write SetRequirementText;

    /// <summary>
    ///   The audiences the feature applies to. A document receives the
    ///   feature only when its audience is in this set.
    /// </summary>
    property Audiences: TPsBDDAudiences read GetAudiences write SetAudiences;

    /// <summary>Where the feature is in its life cycle.</summary>
    property Status: TPsBDDFeatureStatus read GetStatus write SetStatus;
  end;

  /// <summary>
  ///   Fluent Given / When / Then / And / But interface for a BDD scenario.
  ///   Every method runs AAction, documents ADescription and returns the
  ///   scenario so calls can be chained.
  /// </summary>
  IPsBDDScenario = interface
    ['{E52D80F9-1A36-47B4-B6C3-5F09D8A2713E}']
    function Given(AAction: TProc; const ADescription: string): IPsBDDScenario;
    function When(AAction: TProc; const ADescription: string): IPsBDDScenario;
    function &Then(AAction: TProc; const ADescription: string): IPsBDDScenario;
    function &And(AAction: TProc; const ADescription: string): IPsBDDScenario;
    function But(AAction: TProc; const ADescription: string): IPsBDDScenario;
    function Teardown(AAction: TProc): IPsBDDScenario;
  end;

  /// <summary>
  ///   Implements IPsBDDScenario. Intended to be created inside a DUnitX test
  ///   case and called with the setup, action and check procedures declared
  ///   in the private section of the test fixture.
  /// </summary>
  /// <remarks>
  ///   Hold the scenario in a local IPsBDDScenario variable of the test
  ///   method. When the scenario is released at the end of the method, its
  ///   status is written to the document: passed, or failed with the
  ///   message of the first step that raised an exception. An exception
  ///   from a step is raised again, so DUnitX still reports the failure.
  ///   The procedure registered with Teardown runs at the same moment,
  ///   before the status is written, like a finally block. Call Teardown
  ///   first, before the first Given, so the cleanup is registered even
  ///   when a step fails.
  /// </remarks>
  TPsBDDScenario = class(TInterfacedObject, IPsBDDScenario)
  private
    FWriter: IPsBDDScenarioDocumentWriter;
    FStepCount: Integer;
    FFailed: Boolean;
    FFailureMessage: string;
    FTeardown: TProc;
    FTeardownError: string;
    procedure RunStep(AAction: TProc);
    procedure RunTeardown;
    procedure WriteOutcome;
  public
    /// <summary>
    ///   Creates a scenario that documents its steps through AWriter.
    ///   AWriter may be nil, in which case the steps are only executed.
    /// </summary>
    constructor Create(const AWriter: IPsBDDScenarioDocumentWriter);

    /// <summary>
    ///   Ends the scenario: runs the procedure registered with Teardown,
    ///   then writes the status of the scenario to the document when at
    ///   least one step ran.
    /// </summary>
    destructor Destroy; override;

    /// <summary>Precondition: sets up the initial state for the scenario.</summary>
    /// <param name="AAction">The setup procedure to run.</param>
    /// <param name="ADescription">Text written to the document for this step.</param>
    /// <returns>The scenario, for chaining.</returns>
    function Given(AAction: TProc; const ADescription: string): IPsBDDScenario;

    /// <summary>Trigger: the behaviour of the system under test is invoked.</summary>
    /// <param name="AAction">The procedure that performs the action.</param>
    /// <param name="ADescription">Text written to the document for this step.</param>
    /// <returns>The scenario, for chaining.</returns>
    function When(AAction: TProc; const ADescription: string): IPsBDDScenario;

    /// <summary>Outcome: assertions about the result of the When step.</summary>
    /// <param name="AAction">The procedure that performs the checks.</param>
    /// <param name="ADescription">Text written to the document for this step.</param>
    /// <returns>The scenario, for chaining.</returns>
    function &Then(AAction: TProc; const ADescription: string): IPsBDDScenario;

    /// <summary>Continues the previous Given, When or Then step.</summary>
    /// <param name="AAction">The procedure to run for this step.</param>
    /// <param name="ADescription">Text written to the document for this step.</param>
    /// <returns>The scenario, for chaining.</returns>
    function &And(AAction: TProc; const ADescription: string): IPsBDDScenario;

    /// <summary>
    ///   Continues the previous step with a contrasting or negative
    ///   condition.
    /// </summary>
    /// <param name="AAction">The procedure to run for this step.</param>
    /// <param name="ADescription">Text written to the document for this step.</param>
    /// <returns>The scenario, for chaining.</returns>
    function But(AAction: TProc; const ADescription: string): IPsBDDScenario;

    /// <summary>
    ///   Registers the cleanup procedure for the environment the steps
    ///   created. It does not run now. Like a finally block, it runs when
    ///   the scenario ends, even when a step failed. A scenario has one
    ///   teardown: calling Teardown again raises EInvalidOpException. It is
    ///   not written to the document.
    /// </summary>
    /// <remarks>
    ///   Call Teardown first in the chain, before the first Given. A step
    ///   that raises an exception ends the chain, so a Teardown called after
    ///   that step is never registered and its cleanup never runs.
    /// </remarks>
    /// <param name="AAction">The cleanup procedure.</param>
    /// <returns>The scenario, for chaining.</returns>
    function Teardown(AAction: TProc): IPsBDDScenario;
  end;

implementation

uses
  System.IOUtils;

const
  // The time added to the name of an archived document
  ARCHIVE_TIMESTAMP_FORMAT = 'yyyy-mm-dd_hhnnss';

{ TPsBDDRun }

class constructor TPsBDDRun.Create;
begin
  FStarted := TDictionary<string, Boolean>.Create;
  FConversions := TList<IPsBDDConversion>.Create;
  FPreambles := TDictionary<string, string>.Create;
  FLock := TObject.Create;
end;

class destructor TPsBDDRun.Destroy;
begin
  // Only frees memory. Conversions that were never performed are dropped,
  // not performed: their units may already be finalized.
  FLock.Free;
  FPreambles.Free;
  FConversions.Free;
  FStarted.Free;
end;

// The same document can be named in different ways, for example with a
// relative path or in other case
class function TPsBDDRun.PathKey(const APath: string): string;
begin
  Result := TPath.GetFullPath(APath).ToUpperInvariant;
end;

class procedure TPsBDDRun.AddPreamble(const ADocumentPath, APreamblePath: string);
begin
  TMonitor.Enter(FLock);
  try
    FPreambles.AddOrSetValue(PathKey(ADocumentPath), APreamblePath);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TPsBDDRun.PreambleFor(const ADocumentPath: string): TArray<string>;
var
  LPreamblePath: string;
  LCount: Integer;
begin
  Result := nil;
  TMonitor.Enter(FLock);
  try
    if not FPreambles.TryGetValue(PathKey(ADocumentPath), LPreamblePath) then
      Exit;
  finally
    TMonitor.Exit(FLock);
  end;

  // Optional: a preamble that isn't written yet is left out
  if not TFile.Exists(LPreamblePath) then
    Exit;
  Result := TFile.ReadAllLines(LPreamblePath, TEncoding.UTF8);
  LCount := Length(Result);
  while (LCount > 0) and (Trim(Result[LCount - 1]) = '') do
    Dec(LCount);
  SetLength(Result, LCount);
end;

class procedure TPsBDDRun.AddConversion(const AConversion: IPsBDDConversion);
begin
  if AConversion = nil then
    Exit;
  TMonitor.Enter(FLock);
  try
    FConversions.Add(AConversion);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TPsBDDRun.PerformConversions;
var
  LConversions: TArray<IPsBDDConversion>;
  LConversion: IPsBDDConversion;
  LErrors: string;
begin
  // Taken out of the list first, so a conversion that fails is not tried
  // again and the lock is not held while converting
  TMonitor.Enter(FLock);
  try
    LConversions := FConversions.ToArray;
    FConversions.Clear;
  finally
    TMonitor.Exit(FLock);
  end;

  LErrors := '';
  for LConversion in LConversions do
  begin
    try
      LConversion.Convert;
    except
      on E: Exception do
      begin
        if LErrors <> '' then
          LErrors := LErrors + sLineBreak;
        LErrors := LErrors + LConversion.Description + ': ' + E.Message;
      end;
    end;
  end;
  if LErrors <> '' then
    raise Exception.Create(LErrors);
end;

// Renames APath to <name>_<last write time><ext> next to it, adding _2, _3,
// ... when that name is taken, and returns the new path.
class function TPsBDDRun.ArchiveFile(const APath: string): string;
var
  LBase: string;
  LExtension: string;
  LNumber: Integer;
begin
  LExtension := TPath.GetExtension(APath);
  LBase := TPath.Combine(TPath.GetDirectoryName(APath),
    TPath.GetFileNameWithoutExtension(APath) + '_' +
    FormatDateTime(ARCHIVE_TIMESTAMP_FORMAT, TFile.GetLastWriteTime(APath)));

  Result := LBase + LExtension;
  LNumber := 1;
  while TFile.Exists(Result) do
  begin
    Inc(LNumber);
    Result := Format('%s_%d%s', [LBase, LNumber, LExtension]);
  end;
  TFile.Move(APath, Result);
end;

class procedure TPsBDDRun.BeginDocument(const APath: string);
var
  LKey: string;
begin
  LKey := PathKey(APath);

  TMonitor.Enter(FLock);
  try
    if FStarted.ContainsKey(LKey) then
      Exit;
    FStarted.Add(LKey, True);

    // The file is cleared away now, not when the document is saved, so a
    // later open in the run never loads the content of an earlier run, even
    // when the first open wrote nothing
    if TFile.Exists(APath) then
      case FRunStart of
        rsAppend:
          ;
        rsOverwrite:
          TFile.Delete(APath);
        rsArchive:
          ArchiveFile(APath);
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TPsBDDRun.Reset;
begin
  TMonitor.Enter(FLock);
  try
    FStarted.Clear;
    FConversions.Clear;
    FPreambles.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TPsBDDScenario }

constructor TPsBDDScenario.Create(const AWriter: IPsBDDScenarioDocumentWriter);
begin
  inherited Create;
  FWriter := AWriter;
end;

destructor TPsBDDScenario.Destroy;
begin
  // The scenario ends here. Errors are not raised from a destructor, which
  // also runs while an exception is unwinding the test method.
  RunTeardown;
  WriteOutcome;
  inherited;
end;

procedure TPsBDDScenario.RunTeardown;
var
  LTeardown: TProc;
begin
  // Cleared before it runs so it can never run twice. An error is kept for
  // the status.
  LTeardown := FTeardown;
  FTeardown := nil;
  if not Assigned(LTeardown) then
    Exit;
  try
    LTeardown();
  except
    on E: Exception do
      FTeardownError := E.Message;
  end;
end;

procedure TPsBDDScenario.WriteOutcome;
var
  LMessage: string;
begin
  if (FWriter = nil) or (FStepCount = 0) then
    Exit;

  LMessage := FFailureMessage;
  if FTeardownError <> '' then
  begin
    if LMessage <> '' then
      LMessage := LMessage + sLineBreak;
    LMessage := LMessage + 'Teardown failed: ' + FTeardownError;
  end;

  try
    if FFailed or (FTeardownError <> '') then
      FWriter.WriteStatus(ssFailed, LMessage)
    else
      FWriter.WriteStatus(ssPassed, '');
  except
  end;
end;

procedure TPsBDDScenario.RunStep(AAction: TProc);
begin
  Inc(FStepCount);
  if not Assigned(AAction) then
    Exit;
  try
    AAction();
  except
    on E: Exception do
    begin
      // keep the first failure, then let DUnitX see the exception
      if not FFailed then
      begin
        FFailed := True;
        FFailureMessage := E.Message;
      end;
      raise;
    end;
  end;
end;

function TPsBDDScenario.Given(AAction: TProc; const ADescription: string): IPsBDDScenario;
begin
  // The step is documented before it runs so that, if it fails, the failing
  // step is the last one in the document.
  if Assigned(FWriter) then
    FWriter.WriteGiven(ADescription);
  RunStep(AAction);
  Result := Self;
end;

function TPsBDDScenario.When(AAction: TProc; const ADescription: string): IPsBDDScenario;
begin
  if Assigned(FWriter) then
    FWriter.WriteWhen(ADescription);
  RunStep(AAction);
  Result := Self;
end;

function TPsBDDScenario.&Then(AAction: TProc; const ADescription: string): IPsBDDScenario;
begin
  if Assigned(FWriter) then
    FWriter.WriteThen(ADescription);
  RunStep(AAction);
  Result := Self;
end;

function TPsBDDScenario.&And(AAction: TProc; const ADescription: string): IPsBDDScenario;
begin
  if Assigned(FWriter) then
    FWriter.WriteAnd(ADescription);
  RunStep(AAction);
  Result := Self;
end;

function TPsBDDScenario.But(AAction: TProc; const ADescription: string): IPsBDDScenario;
begin
  if Assigned(FWriter) then
    FWriter.WriteBut(ADescription);
  RunStep(AAction);
  Result := Self;
end;

function TPsBDDScenario.Teardown(AAction: TProc): IPsBDDScenario;
begin
  if Assigned(FTeardown) then
    raise EInvalidOpException.Create(
      'A BDD scenario has one teardown and it has already been registered.');
  FTeardown := AAction;
  Result := Self;
end;

end.
