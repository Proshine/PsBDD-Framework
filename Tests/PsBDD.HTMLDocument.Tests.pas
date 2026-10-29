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

unit PsBDD.HTMLDocument.Tests;

{
  DUnitX tests for TPsBDDHTMLDocument:
    - the page: a complete HTML5 document, UTF-8 without a byte order mark
    - stand alone documents: plain headings, the file is replaced
    - documents that are added to: numbered headings with ids, table of
      contents, numbers that continue across runs, pages without markers
    - escaping, multiline text, step classes and the scenario status
    - TPsBDDRun.RunStart

  The documents are written to a BDDHTMLTestOutput folder next to the test
  executable. The folder is emptied before each test and removed after it.

  Most tests compare only the body of the page. The run time below a feature
  heading changes on every run, so it is checked and then compared as
  RUN_PLACEHOLDER.
}

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  PsBDD.Framework, PsBDD.HTMLDocument;

type
  [TestFixture]
  TPsBDDHTMLDocumentTests = class
  private
    FDirectory: string;
    function PathOf(const AName: string): string;
    function NewDocument(const AName: string; AStandAlone: Boolean): IPsBDDDocument;
    function ReadLines(const AName: string): TArray<string>;
    function BodyLines(const AName: string): TArray<string>;
    procedure ExpectBody(const AName: string; const AExpected: array of string);
    procedure WriteCustomerListFeature(const ADocument: IPsBDDDocument);
    procedure WriteBeforeOpen;
    procedure OpenWithoutPath;
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
    procedure Save_WritesACompletePageTitledWithTheFileName;
    [Test]
    procedure Save_WritesUtf8WithoutByteOrderMark;

    // Stand alone documents
    [Test]
    procedure StandAlone_WritesFeatureWithRunTimeStatusAndDescription;
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
    procedure Text_EscapesHtmlCharacters;
    [Test]
    procedure MultilineText_KeepsItsLineBreaks;

    // Documents that are added to
    [Test]
    procedure NewDocument_HasNumberedHeadingsAndTableOfContents;
    [Test]
    procedure SecondRun_ContinuesTheNumbersAndTheTableOfContents;
    [Test]
    procedure PageWithoutMarkers_GetsThemInItsBody;
    [Test]
    procedure RunStartArchive_StartsANewPage;

    // Preamble
    [Test]
    procedure Preamble_StartsANewPageAboveTheTableOfContents;
    [Test]
    procedure Preamble_IsNotRepeatedWhenThePageIsAddedTo;
    [Test]
    procedure Preamble_StandAlonePageHasNone;
  end;

implementation

uses
  System.IOUtils, System.RegularExpressions;

const
  OUTPUT_FOLDER = 'BDDHTMLTestOutput';
  DOCUMENT_NAME = 'Features.html';
  PREAMBLE_NAME = 'Preamble.html';
  RUN_PATTERN =
    '^<p class="run"><strong>Run:</strong> \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}</p>$';
  RUN_PLACEHOLDER = '<p class="run"><strong>Run:</strong> <time></p>';
  CONTENT_END = '<!-- BDD-CONTENT-END -->';
  // 'Café', written with a character code so the source encoding cannot
  // change it
  CAFE = 'Caf'#$00E9;

{ TPsBDDHTMLDocumentTests }

procedure TPsBDDHTMLDocumentTests.Setup;
begin
  FDirectory := TPath.Combine(ExtractFilePath(ParamStr(0)), OUTPUT_FOLDER);
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
  TDirectory.CreateDirectory(FDirectory);
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
end;

procedure TPsBDDHTMLDocumentTests.TearDown;
begin
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

function TPsBDDHTMLDocumentTests.PathOf(const AName: string): string;
begin
  Result := TPath.Combine(FDirectory, AName);
end;

function TPsBDDHTMLDocumentTests.NewDocument(const AName: string;
  AStandAlone: Boolean): IPsBDDDocument;
begin
  Result := TPsBDDHTMLDocument.Create(PathOf(AName), auTester, AStandAlone);
end;

function TPsBDDHTMLDocumentTests.ReadLines(const AName: string): TArray<string>;
begin
  Assert.IsTrue(TFile.Exists(PathOf(AName)), 'The document was not saved');
  Result := TFile.ReadAllLines(PathOf(AName), TEncoding.UTF8);
end;

// The lines between <body> and </body>, run lines replaced by
// RUN_PLACEHOLDER after their time was checked
function TPsBDDHTMLDocumentTests.BodyLines(const AName: string): TArray<string>;
var
  LLine: string;
  LInBody: Boolean;
begin
  Result := nil;
  LInBody := False;
  for LLine in ReadLines(AName) do
  begin
    if LLine = '</body>' then
      Break;
    if LInBody then
    begin
      if LLine.StartsWith('<p class="run">') then
      begin
        Assert.IsTrue(TRegEx.IsMatch(LLine, RUN_PATTERN),
          'Unexpected run time: ' + LLine);
        Result := Result + [RUN_PLACEHOLDER];
      end
      else
        Result := Result + [LLine];
    end;
    if LLine = '<body>' then
      LInBody := True;
  end;
end;

procedure TPsBDDHTMLDocumentTests.ExpectBody(const AName: string;
  const AExpected: array of string);
begin
  Assert.AreEqual(string.Join(sLineBreak, AExpected),
    string.Join(sLineBreak, BodyLines(AName)));
end;

// The feature of CustomerListExample.md
procedure TPsBDDHTMLDocumentTests.WriteCustomerListFeature(
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

procedure TPsBDDHTMLDocumentTests.WriteBeforeOpen;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.WriteScenario('Not opened');
end;

procedure TPsBDDHTMLDocumentTests.OpenWithoutPath;
var
  Document: IPsBDDDocument;
begin
  Document := TPsBDDHTMLDocument.Create('', auTester, True);
  Document.Open;
end;

{ Opening and saving }

procedure TPsBDDHTMLDocumentTests.WriteBeforeOpen_RaisesInvalidOperation;
begin
  Assert.WillRaise(WriteBeforeOpen, EInvalidOperation);
end;

procedure TPsBDDHTMLDocumentTests.OpenWithoutPath_RaisesInvalidOperation;
begin
  Assert.WillRaise(OpenWithoutPath, EInvalidOperation);
end;

procedure TPsBDDHTMLDocumentTests.NothingWritten_CreatesNoFile;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.Close;

  Assert.IsFalse(TFile.Exists(PathOf(DOCUMENT_NAME)));
end;

procedure TPsBDDHTMLDocumentTests.NothingWritten_LeavesTheExistingFileUnchanged;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllText(PathOf(DOCUMENT_NAME), '<p>Hand written</p>', TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.Close;

  // No markers were added, because nothing was written
  Assert.AreEqual('<p>Hand written</p>',
    TFile.ReadAllText(PathOf(DOCUMENT_NAME), TEncoding.UTF8));
end;

procedure TPsBDDHTMLDocumentTests.Save_WritesACompletePageTitledWithTheFileName;
var
  Document: IPsBDDDocument;
  LLines: TArray<string>;
  LText: string;
begin
  Document := NewDocument('Customer list.html', True);
  Document.Open;
  Document.WriteScenario('Once');
  Document.Close;

  LLines := ReadLines('Customer list.html');
  LText := string.Join(sLineBreak, LLines);
  Assert.AreEqual('<!DOCTYPE html>', LLines[0]);
  Assert.AreEqual('</html>', LLines[High(LLines)]);
  Assert.Contains(LText, '<meta charset="utf-8">');
  Assert.Contains(LText, '<title>Customer list</title>');
  Assert.Contains(LText, '<style>');
  // Printed, the table of contents is on a page of its own
  Assert.Contains(LText, '.toc { break-after: page; }');
end;

procedure TPsBDDHTMLDocumentTests.Save_WritesUtf8WithoutByteOrderMark;
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
  ExpectBody(DOCUMENT_NAME, ['<h2>Scenario: ' + CAFE + '</h2>', CONTENT_END]);
end;

{ Stand alone documents }

procedure TPsBDDHTMLDocumentTests.StandAlone_WritesFeatureWithRunTimeStatusAndDescription;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteFeature('Customer list', 'Customers can be found.', fsAccepted);
  Document.Close;

  ExpectBody(DOCUMENT_NAME, [
    '<h1>Feature: Customer list</h1>',
    RUN_PLACEHOLDER,
    '<p class="feature-status"><strong>Status:</strong> Accepted</p>',
    '<p class="description">Customers can be found.</p>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.StandAlone_ReplacesTheExistingFile;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllText(PathOf(DOCUMENT_NAME), 'Old content', TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('New content');
  Document.Close;

  ExpectBody(DOCUMENT_NAME, ['<h2>Scenario: New content</h2>', CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.StandAlone_WritesScenarioStepsAndStatus;
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

  // And and But are indented below the step they continue
  ExpectBody(DOCUMENT_NAME, [
    '<h2>Scenario: Customer can be saved</h2>',
    '<p class="step"><strong>Given</strong> a new customer</p>',
    '<p class="step"><strong>When</strong> the customer is saved</p>',
    '<p class="step"><strong>Then</strong> the customer can be found</p>',
    '<p class="step nested"><strong>And</strong> an audit entry is written</p>',
    '<p class="step nested"><strong>But</strong> no duplicate is created</p>',
    '<p class="status passed"><strong>Status:</strong> Passed</p>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.FailedStatus_IncludesTheEscapedMessage;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('Customer can be saved');
  Document.WriteStep(skGiven, 'a new customer');
  Document.WriteScenarioStatus(ssFailed, 'Expected <1> but got 2' + sLineBreak +
    'Teardown failed: disk full');
  Document.Close;

  ExpectBody(DOCUMENT_NAME, [
    '<h2>Scenario: Customer can be saved</h2>',
    '<p class="step"><strong>Given</strong> a new customer</p>',
    '<p class="status failed"><strong>Status:</strong> Failed - Expected &lt;1&gt; but got 2<br>',
    'Teardown failed: disk full</p>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.Requirement_WithAndWithoutReference;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteRequirement('REQ#001', 'The system shall save a customer.');
  Document.WriteRequirement('', 'The system shall not lose a customer.');
  Document.Close;

  ExpectBody(DOCUMENT_NAME, [
    '<blockquote class="requirement"><p><strong>REQ#001:</strong> The system shall save a customer.</p></blockquote>',
    '<blockquote class="requirement"><p>The system shall not lose a customer.</p></blockquote>',
    CONTENT_END]);
end;

{ Text }

procedure TPsBDDHTMLDocumentTests.Text_EscapesHtmlCharacters;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteScenario('Tom & Jerry''s <list>');
  Document.WriteStep(skGiven, 'the name "<b>Smith</b>" & *stars*');
  Document.Close;

  // Markdown characters such as * mean nothing in HTML and are kept
  ExpectBody(DOCUMENT_NAME, [
    '<h2>Scenario: Tom &amp; Jerry&#39;s &lt;list&gt;</h2>',
    '<p class="step"><strong>Given</strong> the name &quot;&lt;b&gt;Smith&lt;/b&gt;&quot; &amp; *stars*</p>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.MultilineText_KeepsItsLineBreaks;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, True);
  Document.Open;
  Document.WriteFeature('Multiline', 'As a clerk' + sLineBreak +
    'I want a list', fsProposed);
  Document.WriteStep(skGiven, 'a customer' + sLineBreak + 'with two lines');
  Document.Close;

  ExpectBody(DOCUMENT_NAME, [
    '<h1>Feature: Multiline</h1>',
    RUN_PLACEHOLDER,
    '<p class="feature-status"><strong>Status:</strong> Proposed</p>',
    '<p class="description">As a clerk<br>',
    'I want a list</p>',
    '<p class="step"><strong>Given</strong> a customer<br>',
    'with two lines</p>',
    CONTENT_END]);
end;

{ Documents that are added to }

procedure TPsBDDHTMLDocumentTests.NewDocument_HasNumberedHeadingsAndTableOfContents;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  WriteCustomerListFeature(Document);
  Document.Close;

  ExpectBody(DOCUMENT_NAME, [
    '<!-- BDD-TOC-START -->',
    '<nav class="toc">',
    '<h2>Table of Contents</h2>',
    '<ul>',
    '<li class="feature"><a href="#feature-1">Feature 1: Customer list</a></li>',
    '<li class="scenario"><a href="#scenario-1">Scenario 1: Customer is found in the list</a></li>',
    '<li class="scenario"><a href="#scenario-2">Scenario 2: Unknown customer is not found</a></li>',
    '</ul>',
    '</nav>',
    '<!-- BDD-TOC-END -->',
    '<h1 id="feature-1">Feature 1: Customer list</h1>',
    RUN_PLACEHOLDER,
    '<p class="feature-status"><strong>Status:</strong> In Development</p>',
    '<p class="description">As a clerk<br>',
    'I want to check whether a customer is in the customer list<br>',
    'So that I do not create the same customer twice</p>',
    '<blockquote class="requirement"><p><strong>REQ#014:</strong> The system shall report whether a customer is in the customer list.</p></blockquote>',
    '<h2 id="scenario-1">Scenario 1: Customer is found in the list</h2>',
    '<p class="step"><strong>Given</strong> a customer list with &quot;Smith&quot; and &quot;Jones&quot;</p>',
    '<p class="step"><strong>When</strong> the clerk searches for &quot;Smith&quot;</p>',
    '<p class="step"><strong>Then</strong> the customer is found</p>',
    '<p class="step nested"><strong>And</strong> exactly one match is returned</p>',
    '<p class="status passed"><strong>Status:</strong> Passed</p>',
    '<h2 id="scenario-2">Scenario 2: Unknown customer is not found</h2>',
    '<p class="step"><strong>Given</strong> a customer list with &quot;Smith&quot; and &quot;Jones&quot;</p>',
    '<p class="step"><strong>When</strong> the clerk searches for &quot;Brown&quot;</p>',
    '<p class="step"><strong>Then</strong> no customer is found</p>',
    '<p class="step nested"><strong>But</strong> the customer list still holds 2 customers</p>',
    '<p class="status passed"><strong>Status:</strong> Passed</p>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.SecondRun_ContinuesTheNumbersAndTheTableOfContents;
var
  Document: IPsBDDDocument;
  LBody: TArray<string>;
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

  LBody := BodyLines(DOCUMENT_NAME);
  Assert.AreEqual(string.Join(sLineBreak, [
    '<!-- BDD-TOC-START -->',
    '<nav class="toc">',
    '<h2>Table of Contents</h2>',
    '<ul>',
    '<li class="feature"><a href="#feature-1">Feature 1: Customer list</a></li>',
    '<li class="scenario"><a href="#scenario-1">Scenario 1: Customer is found in the list</a></li>',
    '<li class="scenario"><a href="#scenario-2">Scenario 2: Unknown customer is not found</a></li>',
    '<li class="feature"><a href="#feature-2">Feature 2: Customer list</a></li>',
    '<li class="scenario"><a href="#scenario-3">Scenario 3: Customer is found in the list</a></li>',
    '</ul>',
    '</nav>',
    '<!-- BDD-TOC-END -->']),
    string.Join(sLineBreak, Copy(LBody, 0, 12)));

  // The first run is kept and the second run is added after it. An empty
  // description writes no paragraph.
  Assert.AreEqual(string.Join(sLineBreak, [
    '<p class="status passed"><strong>Status:</strong> Passed</p>',
    '<h1 id="feature-2">Feature 2: Customer list</h1>',
    RUN_PLACEHOLDER,
    '<p class="feature-status"><strong>Status:</strong> Implemented</p>',
    '<h2 id="scenario-3">Scenario 3: Customer is found in the list</h2>',
    CONTENT_END]),
    string.Join(sLineBreak, Copy(LBody, Length(LBody) - 6, 6)));
end;

procedure TPsBDDHTMLDocumentTests.PageWithoutMarkers_GetsThemInItsBody;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllLines(PathOf(DOCUMENT_NAME), [
    '<!DOCTYPE html>',
    '<html>',
    '<body>',
    '<p>Hand written intro</p>',
    '</body>',
    '</html>'], TEncoding.UTF8);

  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteScenario('Added');
  Document.Close;

  // The table of contents at the top of the body, the content at its end.
  // No feature was written, so the scenario is not indented in the contents.
  ExpectBody(DOCUMENT_NAME, [
    '<!-- BDD-TOC-START -->',
    '<nav class="toc">',
    '<h2>Table of Contents</h2>',
    '<ul>',
    '<li><a href="#scenario-1">Scenario 1: Added</a></li>',
    '</ul>',
    '</nav>',
    '<!-- BDD-TOC-END -->',
    '<p>Hand written intro</p>',
    '<h2 id="scenario-1">Scenario 1: Added</h2>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.RunStartArchive_StartsANewPage;
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteFeature('Old run', '', fsImplemented);
  Document.Close;

  // A new test run
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsArchive;
  Document := NewDocument(DOCUMENT_NAME, False);
  Document.Open;
  Document.WriteFeature('New run', '', fsImplemented);
  Document.Close;

  Assert.AreEqual(1, Length(TDirectory.GetFiles(FDirectory, 'Features_*.html')),
    'The old page was not archived');
  Assert.IsTrue(string.Join(sLineBreak, BodyLines(DOCUMENT_NAME))
    .Contains('<h1 id="feature-1">Feature 1: New run</h1>'));
  Assert.IsFalse(string.Join(sLineBreak, BodyLines(DOCUMENT_NAME))
    .Contains('Old run'));
end;

{ Preamble }

procedure TPsBDDHTMLDocumentTests.WritePreamble;
begin
  TFile.WriteAllLines(PathOf(PREAMBLE_NAME), [
    '<h1>Converter</h1>',
    '<p>Converts the Florida corporate data files to <b>CSV</b>.</p>',
    ''], TEncoding.UTF8);
  TPsBDDRun.AddPreamble(PathOf(DOCUMENT_NAME), PathOf(PREAMBLE_NAME));
end;

procedure TPsBDDHTMLDocumentTests.WriteScenarioRun(const ATitle: string;
  AStandAlone: Boolean);
var
  Document: IPsBDDDocument;
begin
  Document := NewDocument(DOCUMENT_NAME, AStandAlone);
  Document.Open;
  Document.WriteScenario(ATitle);
  Document.Close;
end;

procedure TPsBDDHTMLDocumentTests.Preamble_StartsANewPageAboveTheTableOfContents;
begin
  WritePreamble;

  WriteScenarioRun('First', False);

  // The preamble is the user's HTML, copied as it is
  ExpectBody(DOCUMENT_NAME, [
    '<div class="preamble">',
    '<h1>Converter</h1>',
    '<p>Converts the Florida corporate data files to <b>CSV</b>.</p>',
    '</div>',
    '<!-- BDD-TOC-START -->',
    '<nav class="toc">',
    '<h2>Table of Contents</h2>',
    '<ul>',
    '<li><a href="#scenario-1">Scenario 1: First</a></li>',
    '</ul>',
    '</nav>',
    '<!-- BDD-TOC-END -->',
    '<h2 id="scenario-1">Scenario 1: First</h2>',
    CONTENT_END]);
end;

procedure TPsBDDHTMLDocumentTests.Preamble_IsNotRepeatedWhenThePageIsAddedTo;
var
  LBody: string;
begin
  WritePreamble;
  WriteScenarioRun('First', False);

  // A later run that adds to the page
  TPsBDDRun.Reset;
  WritePreamble;
  WriteScenarioRun('Second', False);

  LBody := string.Join(sLineBreak, BodyLines(DOCUMENT_NAME));
  Assert.AreEqual(1, TRegEx.Matches(LBody, '<div class="preamble">').Count);
  Assert.Contains(LBody, '<h2 id="scenario-2">Scenario 2: Second</h2>');
end;

procedure TPsBDDHTMLDocumentTests.Preamble_StandAlonePageHasNone;
begin
  WritePreamble;

  WriteScenarioRun('Alone', True);

  ExpectBody(DOCUMENT_NAME, ['<h2>Scenario: Alone</h2>', CONTENT_END]);
end;

initialization
  TDUnitX.RegisterTestFixture(TPsBDDHTMLDocumentTests);

end.
