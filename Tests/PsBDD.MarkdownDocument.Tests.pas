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

unit PsBDD.MarkdownDocument.Tests;

{
  DUnitX tests for TPsBDDMarkdownDocument:
    - stand alone documents: plain headings, the file is replaced
    - documents that are added to: numbered headings, table of contents,
      numbers that continue across runs
    - escaping, multiline text, step indentation and the scenario status
    - when the file is saved, and how

  The documents are written to a BDDMarkdownTestOutput folder next to the
  test executable. The folder is emptied before each test and removed after
  it.

  The run time below a feature heading changes on every run, so the tests
  check its format and then compare it as '**Run:** <time>'.
}

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  PsBDD.Framework, PsBDD.MarkdownDocument;

type
  [TestFixture]
  TPsBDDMarkdownDocumentTests = class
  private
    FDirectory: string;
    function PathOf(const AName: string): string;
    function NewDocument(const AName: string; AStandAlone: Boolean): IPsBDDDocument;
    function ReadLines(const AName: string): TArray<string>;
    procedure ExpectFile(const AName: string; const AExpected: array of string);
    procedure WriteCustomerListFeature(const ADocument: IPsBDDDocument);
    procedure WritePreamble;
    procedure WriteScenarioRun(const ATitle: string; AStandAlone: Boolean);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Opening and saving
    [Test]
    procedure WriteBeforeOpen_RaisesInvalidOperation;
    [Test]
    procedure OpenWithoutPath_RaisesInvalidOperation;
    [Test]
    procedure NothingWritten_CreatesNoFile;
    [Test]
    procedure NothingWritten_LeavesTheExistingFileUnchanged;
    [Test]
    procedure Close_IsSafeToCallTwice;
    [Test]
    procedure Save_CreatesTheMissingFolder;
    [Test]
    procedure Save_WritesUtf8WithoutByteOrderMark;

    // Stand alone documents
    [Test]
    procedure StandAlone_WritesFeatureWithRunTimeAndStatus;
    [Test]
    procedure StandAlone_ReplacesTheExistingFile;
    [Test]
    procedure StandAlone_WritesScenarioStepsAndStatus;
    [Test]
    procedure FailedStatus_IncludesTheEscapedMessage;
    [Test]
    procedure Requirement_WithAndWithoutReference;

    // Text
    [Test]
    procedure Text_EscapesMarkdownCharacters;
    [Test]
    procedure Text_EscapesALeadingHash;
    [Test]
    procedure MultilineStep_KeepsItsLineBreaksAndIndent;
    [Test]
    procedure MultilineRequirement_StaysInTheQuote;

    // Documents that are added to
    [Test]
    procedure NewDocument_MatchesTheCustomerListExample;
    [Test]
    procedure SecondRun_ContinuesTheNumbersAndTheTableOfContents;
    [Test]
    procedure ExistingDocumentWithoutToc_GetsTocAtTheTop;
    [Test]
    procedure MovedToc_IsFoundByItsMarkers;
    [Test]
    procedure EndMarkerWithoutBlankLine_KeepsEntriesApart;
    [Test]
    procedure TocLink_UsesTheHeadingIdOfTheUnescapedTitle;

    // Preamble
    [Test]
    procedure Preamble_StartsANewDocumentAboveTheTableOfContents;
    [Test]
    procedure Preamble_IsNotRepeatedWhenTheDocumentIsAddedTo;
    [Test]
    procedure Preamble_IsWrittenAgainWhenARunStartsAfresh;
    [Test]
    procedure Preamble_NotWrittenYet_DocumentHasNone;
    [Test]
    procedure Preamble_StandAloneDocumentHasNone;
  end;

implementation

uses
  System.IOUtils, System.RegularExpressions;

const
  OUTPUT_FOLDER = 'BDDMarkdownTestOutput';
  DOCUMENT_NAME = 'Features.md';
  PREAMBLE_NAME = 'Preamble.md';
  RUN_PREFIX = '**Run:** ';
  RUN_PLACEHOLDER = '**Run:** <time>';
  RUN_PATTERN = '^\*\*Run:\*\* \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$';
  // 'Café', written with a character code so the source encoding cannot
  // change it
  CAFE = 'Caf'#$00E9;

function HasLine(const ALines: TArray<string>; const ALine: string): Boolean;
var
  LLine: string;
begin
  for LLine in ALines do
    if LLine = ALine then
      Exit(True);
  Result := False;
end;

{ TPsBDDMarkdownDocumentTests }

procedure TPsBDDMarkdownDocumentTests.Setup;
begin
  FDirectory := TPath.Combine(ExtractFilePath(ParamStr(0)), OUTPUT_FOLDER);
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
  TDirectory.CreateDirectory(FDirectory);
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
end;

procedure TPsBDDMarkdownDocumentTests.TearDown;
begin
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

function TPsBDDMarkdownDocumentTests.PathOf(const AName: string): string;
begin
  Result := TPath.Combine(FDirectory, AName);
end;

function TPsBDDMarkdownDocumentTests.NewDocument(const AName: string;
  AStandAlone: Boolean): IPsBDDDocument;
begin
  Result := TPsBDDMarkdownDocument.Create(PathOf(AName), auTester, AStandAlone);
end;

function TPsBDDMarkdownDocumentTests.ReadLines(const AName: string): TArray<string>;
begin
  Result := TFile.ReadAllLines(PathOf(AName), TEncoding.UTF8);
end;

// Compares the file line by line. Run lines must hold a valid time and are
// compared as RUN_PLACEHOLDER.
procedure TPsBDDMarkdownDocumentTests.ExpectFile(const AName: string;
  const AExpected: array of string);
var
  LLines: TArray<string>;
  I: Integer;
begin
  Assert.IsTrue(TFile.Exists(PathOf(AName)), 'The document was not saved');
  LLines := ReadLines(AName);
  for I := 0 to High(LLines) do
    if LLines[I].StartsWith(RUN_PREFIX) then
    begin
      Assert.IsTrue(TRegEx.IsMatch(LLines[I], RUN_PATTERN),
        'Unexpected run time: ' + LLines[I]);
      LLines[I] := RUN_PLACEHOLDER;
    end;
  Assert.AreEqual(string.Join(sLineBreak, AExpected),
    string.Join(sLineBreak, LLines));
end;

// The feature of CustomerListExample.md
procedure TPsBDDMarkdownDocumentTests.WriteCustomerListFeature(
  const ADocument: IPsBDDDocument);
const
  DESCRIPTION = '''
    As a clerk
    I want to check whether a customer is in the customer list
    So that I do not create the same customer twice
    ''';
begin
  ADocument.WriteFeature('Customer list', DESCRIPTION, fsInDevelopment);
  ADocument.WriteRequirement('REQ#014',
    'The system shall report whether a customer is in the customer list.');

  ADocument.WriteScenario('Customer is found in the list');
  ADocument.WriteStep(skGiven, 'a customer list with "Smith" and "Jones"');
  ADocument.WriteStep(skWhen, 'the clerk searches for "Smith"');
  ADocument.WriteStep(skThen, 'the customer is found');
  ADocument.WriteStep(skAnd, 'exactly one match is returned');
  ADocument.WriteScenarioStatus(ssPassed, '');

  ADocument.WriteScenario('Unknown customer is not found');
  ADocument.WriteStep(skGiven, 'a customer list with "Smith" and "Jones"');
  ADocument.WriteStep(skWhen, 'the clerk searches for "Brown"');
  ADocument.WriteStep(skThen, 'no customer is found');
  ADocument.WriteStep(skBut, 'the customer list still holds 2 customers');
  ADocument.WriteScenarioStatus(ssPassed, '');
end;

{ Opening and saving }

procedure TPsBDDMarkdownDocumentTests.WriteBeforeOpen_RaisesInvalidOperation;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Assert.WillRaise(
    procedure
    begin
      Document.WriteScenario('Not opened');
    end,
    EInvalidOperation);
end;

procedure TPsBDDMarkdownDocumentTests.OpenWithoutPath_RaisesInvalidOperation;
var
  Document: IPsBDDDocument;
begin
  Document := TPsBDDMarkdownDocument.Create('', auTester, True);
  Assert.WillRaise(
    procedure
    begin
      Document.Open;
    end,
    EInvalidOperation);
end;

procedure TPsBDDMarkdownDocumentTests.NothingWritten_CreatesNoFile;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.Close;

  Assert.IsFalse(TFile.Exists(PathOf(DOCUMENT_NAME)));
end;

procedure TPsBDDMarkdownDocumentTests.NothingWritten_LeavesTheExistingFileUnchanged;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllText(PathOf(DOCUMENT_NAME), 'Hand written', TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.Close;

  // No table of contents was added, because nothing was written
  Assert.AreEqual('Hand written',
    TFile.ReadAllText(PathOf(DOCUMENT_NAME), TEncoding.UTF8));
end;

procedure TPsBDDMarkdownDocumentTests.Close_IsSafeToCallTwice;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Assert.WillNotRaiseAny(
    procedure
    begin
      Document.Close;
      Document.Open;
      Document.WriteScenario('Once');
      Document.Close;
      Document.Close;
    end);

  ExpectFile(DOCUMENT_NAME, ['## Scenario: Once', '']);
end;

procedure TPsBDDMarkdownDocumentTests.Save_CreatesTheMissingFolder;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(TPath.Combine('Sub', DOCUMENT_NAME), True);
  Document.Open;
  Document.WriteScenario('In a new folder');
  Document.Close;

  Assert.IsTrue(TFile.Exists(PathOf(TPath.Combine('Sub', DOCUMENT_NAME))));
end;

procedure TPsBDDMarkdownDocumentTests.Save_WritesUtf8WithoutByteOrderMark;
var
  Document: IPsBDDDocument;
  LBytes: TBytes;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario(CAFE);
  Document.Close;

  LBytes := TFile.ReadAllBytes(PathOf(DOCUMENT_NAME));
  Assert.IsFalse((Length(LBytes) >= 3) and (LBytes[0] = $EF)
    and (LBytes[1] = $BB) and (LBytes[2] = $BF), 'The file has a BOM');
  ExpectFile(DOCUMENT_NAME, ['## Scenario: ' + CAFE, '']);
end;

{ Stand alone documents }

procedure TPsBDDMarkdownDocumentTests.StandAlone_WritesFeatureWithRunTimeAndStatus;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteFeature('Customer list', 'Customers can be found.', fsAccepted);
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '# Feature: Customer list',
    '',
    RUN_PLACEHOLDER,
    '',
    '**Status:** Accepted',
    '',
    'Customers can be found.']);
end;

procedure TPsBDDMarkdownDocumentTests.StandAlone_ReplacesTheExistingFile;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllText(PathOf(DOCUMENT_NAME), 'Old content', TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('New content');
  Document.Close;

  ExpectFile(DOCUMENT_NAME, ['## Scenario: New content', '']);
end;

procedure TPsBDDMarkdownDocumentTests.StandAlone_WritesScenarioStepsAndStatus;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('Customer can be saved');
  Document.WriteStep(skGiven, 'a new customer');
  Document.WriteStep(skWhen, 'the customer is saved');
  Document.WriteStep(skThen, 'the customer can be found');
  Document.WriteStep(skAnd, 'an audit entry is written');
  Document.WriteStep(skBut, 'no duplicate is created');
  Document.WriteScenarioStatus(ssPassed, '');
  Document.Close;

  // And and But are nested under the step they continue
  ExpectFile(DOCUMENT_NAME, [
    '## Scenario: Customer can be saved',
    '',
    '* **Given** a new customer',
    '* **When** the customer is saved',
    '* **Then** the customer can be found',
    '  * **And** an audit entry is written',
    '  * **But** no duplicate is created',
    '',
    '**Status:** Passed']);
end;

procedure TPsBDDMarkdownDocumentTests.FailedStatus_IncludesTheEscapedMessage;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('Customer can be saved');
  Document.WriteStep(skGiven, 'a new customer');
  Document.WriteScenarioStatus(ssFailed, 'Expected <1> but got *2*');
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '## Scenario: Customer can be saved',
    '',
    '* **Given** a new customer',
    '',
    '**Status:** Failed - Expected \<1\> but got \*2\*']);
end;

procedure TPsBDDMarkdownDocumentTests.Requirement_WithAndWithoutReference;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteRequirement('REQ#001', 'The system shall save a customer.');
  Document.WriteRequirement('', 'The system shall not lose a customer.');
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '> **REQ#001:** The system shall save a customer.',
    '',
    '> The system shall not lose a customer.',
    '']);
end;

{ Text }

procedure TPsBDDMarkdownDocumentTests.Text_EscapesMarkdownCharacters;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('Total *must* be [1|2]');
  Document.WriteStep(skGiven, 'file C:\temp\a_b.txt and `code` <tag>');
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '## Scenario: Total \*must\* be \[1\|2\]',
    '',
    '* **Given** file C:\\temp\\a\_b.txt and \`code\` \<tag\>']);
end;

procedure TPsBDDMarkdownDocumentTests.Text_EscapesALeadingHash;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteFeature('Feature', '#1 is not a heading', fsProposed);
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '# Feature: Feature',
    '',
    RUN_PLACEHOLDER,
    '',
    '**Status:** Proposed',
    '',
    '\#1 is not a heading']);
end;

procedure TPsBDDMarkdownDocumentTests.MultilineStep_KeepsItsLineBreaksAndIndent;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('Multiline');
  Document.WriteStep(skGiven, 'a customer' + sLineBreak + 'with two lines');
  Document.WriteStep(skAnd, 'an order' + sLineBreak + sLineBreak + 'after a gap');
  Document.Close;

  // Two trailing spaces make a Markdown line break. Continuation lines are
  // indented to stay inside their list item.
  ExpectFile(DOCUMENT_NAME, [
    '## Scenario: Multiline',
    '',
    '* **Given** a customer  ',
    '  with two lines',
    '  * **And** an order',
    '',
    '    after a gap']);
end;

procedure TPsBDDMarkdownDocumentTests.MultilineRequirement_StaysInTheQuote;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteRequirement('REQ#002',
    'The system shall' + sLineBreak + 'keep every line');
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '> **REQ#002:** The system shall  ',
    '> keep every line',
    '']);
end;

{ Documents that are added to }

procedure TPsBDDMarkdownDocumentTests.NewDocument_MatchesTheCustomerListExample;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  WriteCustomerListFeature(Document);
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '# Table of Contents',
    '',
    '[BDD-TOC-START]: #',
    '',
    '- [Feature 1: Customer list](#feature-1-customer-list)',
    '  - [Scenario 1: Customer is found in the list](#scenario-1-customer-is-found-in-the-list)',
    '  - [Scenario 2: Unknown customer is not found](#scenario-2-unknown-customer-is-not-found)',
    '',
    '[BDD-TOC-END]: #',
    '',
    '# Feature 1: Customer list',
    '',
    RUN_PLACEHOLDER,
    '',
    '**Status:** In Development',
    '',
    'As a clerk  ',
    'I want to check whether a customer is in the customer list  ',
    'So that I do not create the same customer twice',
    '',
    '> **REQ#014:** The system shall report whether a customer is in the customer list.',
    '',
    '## Scenario 1: Customer is found in the list',
    '',
    '* **Given** a customer list with "Smith" and "Jones"',
    '* **When** the clerk searches for "Smith"',
    '* **Then** the customer is found',
    '  * **And** exactly one match is returned',
    '',
    '**Status:** Passed',
    '',
    '## Scenario 2: Unknown customer is not found',
    '',
    '* **Given** a customer list with "Smith" and "Jones"',
    '* **When** the clerk searches for "Brown"',
    '* **Then** no customer is found',
    '  * **But** the customer list still holds 2 customers',
    '',
    '**Status:** Passed']);
end;

procedure TPsBDDMarkdownDocumentTests.SecondRun_ContinuesTheNumbersAndTheTableOfContents;
var
  Document: IPsBDDDocument;
  LLines: TArray<string>;
begin
  // First run
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  WriteCustomerListFeature(Document);
  Document.Close;

  // Second run, a new document object on the same file
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteFeature('Customer list', '', fsImplemented);
  Document.WriteScenario('Customer is found in the list');
  Document.Close;

  LLines := ReadLines(DOCUMENT_NAME);
  Assert.AreEqual(string.Join(sLineBreak, [
    '# Table of Contents',
    '',
    '[BDD-TOC-START]: #',
    '',
    '- [Feature 1: Customer list](#feature-1-customer-list)',
    '  - [Scenario 1: Customer is found in the list](#scenario-1-customer-is-found-in-the-list)',
    '  - [Scenario 2: Unknown customer is not found](#scenario-2-unknown-customer-is-not-found)',
    '- [Feature 2: Customer list](#feature-2-customer-list)',
    '  - [Scenario 3: Customer is found in the list](#scenario-3-customer-is-found-in-the-list)',
    '',
    '[BDD-TOC-END]: #']),
    string.Join(sLineBreak, Copy(LLines, 0, 11)));

  // The first run is kept and the second run is added after it
  Assert.IsTrue(HasLine(LLines, '# Feature 1: Customer list'));
  Assert.IsTrue(HasLine(LLines, '## Scenario 2: Unknown customer is not found'));
  Assert.IsTrue(HasLine(LLines, '# Feature 2: Customer list'));
  Assert.AreEqual('## Scenario 3: Customer is found in the list',
    LLines[High(LLines) - 1]);
end;

procedure TPsBDDMarkdownDocumentTests.ExistingDocumentWithoutToc_GetsTocAtTheTop;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllText(PathOf(DOCUMENT_NAME), 'Hand written intro' + sLineBreak,
    TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteScenario('Added');
  Document.Close;

  // No feature was written, so the scenario is not nested in the contents
  ExpectFile(DOCUMENT_NAME, [
    '# Table of Contents',
    '',
    '[BDD-TOC-START]: #',
    '',
    '- [Scenario 1: Added](#scenario-1-added)',
    '',
    '[BDD-TOC-END]: #',
    '',
    'Hand written intro',
    '',
    '## Scenario 1: Added',
    '']);
end;

procedure TPsBDDMarkdownDocumentTests.MovedToc_IsFoundByItsMarkers;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllLines(PathOf(DOCUMENT_NAME), [
    'Hand written intro',
    '',
    '[BDD-TOC-START]: #',
    '',
    '',
    '[BDD-TOC-END]: #'], TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteScenario('Added');
  Document.Close;

  // No second table of contents is added at the top
  ExpectFile(DOCUMENT_NAME, [
    'Hand written intro',
    '',
    '[BDD-TOC-START]: #',
    '',
    '- [Scenario 1: Added](#scenario-1-added)',
    '',
    '[BDD-TOC-END]: #',
    '',
    '## Scenario 1: Added',
    '']);
end;

procedure TPsBDDMarkdownDocumentTests.EndMarkerWithoutBlankLine_KeepsEntriesApart;
var
  Document: IPsBDDDocument;
begin
  // The blank line in front of the end marker was removed by hand
  TFile.WriteAllLines(PathOf(DOCUMENT_NAME), [
    '[BDD-TOC-START]: #',
    '- [Scenario 1: First](#scenario-1-first)',
    '[BDD-TOC-END]: #',
    '',
    '## Scenario 1: First'], TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteScenario('Second');
  Document.Close;

  ExpectFile(DOCUMENT_NAME, [
    '[BDD-TOC-START]: #',
    '- [Scenario 1: First](#scenario-1-first)',
    '- [Scenario 2: Second](#scenario-2-second)',
    '',
    '[BDD-TOC-END]: #',
    '',
    '## Scenario 1: First',
    '',
    '## Scenario 2: Second',
    '']);
end;

procedure TPsBDDMarkdownDocumentTests.TocLink_UsesTheHeadingIdOfTheUnescapedTitle;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteScenario('Customer''s list_v2 (draft)!');
  Document.Close;

  // The text is escaped like the heading. The id is made from the title as a
  // reader shows it: punctuation removed, underscore kept.
  ExpectFile(DOCUMENT_NAME, [
    '# Table of Contents',
    '',
    '[BDD-TOC-START]: #',
    '',
    '- [Scenario 1: Customer''s list\_v2 (draft)!](#scenario-1-customers-list_v2-draft)',
    '',
    '[BDD-TOC-END]: #',
    '',
    '## Scenario 1: Customer''s list\_v2 (draft)!',
    '']);
end;

{ Preamble }

procedure TPsBDDMarkdownDocumentTests.WritePreamble;
begin
  TFile.WriteAllLines(PathOf(PREAMBLE_NAME), [
    '# Converter',
    '',
    'Converts the Florida corporate data files to CSV.',
    ''], TEncoding.UTF8);
  TPsBDDRun.AddPreamble(PathOf(DOCUMENT_NAME), PathOf(PREAMBLE_NAME));
end;

procedure TPsBDDMarkdownDocumentTests.WriteScenarioRun(const ATitle: string;
  AStandAlone: Boolean);
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, AStandAlone);
  Document.Open;
  Document.WriteScenario(ATitle);
  Document.Close;
end;

procedure TPsBDDMarkdownDocumentTests.Preamble_StartsANewDocumentAboveTheTableOfContents;
begin
  WritePreamble;

  WriteScenarioRun('First', False);

  ExpectFile(DOCUMENT_NAME, [
    '# Converter',
    '',
    'Converts the Florida corporate data files to CSV.',
    '',
    '# Table of Contents',
    '',
    '[BDD-TOC-START]: #',
    '',
    '- [Scenario 1: First](#scenario-1-first)',
    '',
    '[BDD-TOC-END]: #',
    '',
    '## Scenario 1: First',
    '']);
end;

procedure TPsBDDMarkdownDocumentTests.Preamble_IsNotRepeatedWhenTheDocumentIsAddedTo;
var
  LText: string;
begin
  WritePreamble;
  WriteScenarioRun('First', False);

  // A later run that adds to the document
  TPsBDDRun.Reset;
  WritePreamble;
  WriteScenarioRun('Second', False);

  LText := TFile.ReadAllText(PathOf(DOCUMENT_NAME), TEncoding.UTF8);
  Assert.AreEqual(1, TRegEx.Matches(LText, '^# Converter', [roMultiLine]).Count);
  Assert.Contains(LText, '## Scenario 2: Second');
end;

procedure TPsBDDMarkdownDocumentTests.Preamble_IsWrittenAgainWhenARunStartsAfresh;
var
  LLines: TArray<string>;
begin
  WritePreamble;
  WriteScenarioRun('First', False);

  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsOverwrite;
  WritePreamble;
  WriteScenarioRun('Second', False);

  LLines := ReadLines(DOCUMENT_NAME);
  Assert.AreEqual('# Converter', LLines[0]);
  Assert.IsFalse(HasLine(LLines, '## Scenario 1: First'));
  Assert.IsTrue(HasLine(LLines, '## Scenario 1: Second'));
end;

procedure TPsBDDMarkdownDocumentTests.Preamble_NotWrittenYet_DocumentHasNone;
begin
  TPsBDDRun.AddPreamble(PathOf(DOCUMENT_NAME), PathOf(PREAMBLE_NAME));

  WriteScenarioRun('First', False);

  Assert.AreEqual('# Table of Contents', ReadLines(DOCUMENT_NAME)[0]);
end;

procedure TPsBDDMarkdownDocumentTests.Preamble_StandAloneDocumentHasNone;
begin
  WritePreamble;

  WriteScenarioRun('Alone', True);

  ExpectFile(DOCUMENT_NAME, ['## Scenario: Alone', '']);
end;

initialization
  TDUnitX.RegisterTestFixture(TPsBDDMarkdownDocumentTests);

end.
