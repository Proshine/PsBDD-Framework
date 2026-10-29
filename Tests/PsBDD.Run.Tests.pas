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

unit PsBDD.Run.Tests;

{
  DUnitX tests for TPsBDDRun.RunStart, through TPsBDDMarkdownDocument documents
  that are added to:
    - rsAppend keeps the existing document and continues its numbers
    - rsOverwrite deletes it at the first open of the run
    - rsArchive renames it with its last write time at the first open
    - later opens in the same run add to what the first one started
    - Reset starts a new run
    - stand alone documents are not affected

  Every test starts a new run with rsAppend and restores it afterwards. The
  documents are written to a BDDRunTestOutput folder next to the test
  executable, which is removed after each test.
}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  PsBDD.Framework, PsBDD.MarkdownDocument;

type
  [TestFixture]
  TPsBDDRunTests = class
  private
    FDirectory: string;
    function PathOf(const AName: string): string;
    procedure WriteOldRun;
    procedure WriteFeature(const AName, ATitle: string);
    function ReadText(const AName: string): string;
    function FeatureHeadings(const AName: string): TArray<string>;
    procedure ExpectFiles(const ANames: array of string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure RunStart_IsAppendByDefault;
    [Test]
    procedure Append_ContinuesTheExistingDocument;

    [Test]
    procedure Overwrite_StartsANewDocument;
    [Test]
    procedure Overwrite_LaterOpensInTheRunAppend;
    [Test]
    procedure Overwrite_RemovesTheOldDocumentEvenWhenNothingIsWritten;

    [Test]
    procedure Archive_RenamesTheOldDocumentWithItsLastWriteTime;
    [Test]
    procedure Archive_AddsANumberWhenTheNameIsTaken;
    [Test]
    procedure Archive_LaterOpensInTheRunAppend;
    [Test]
    procedure Archive_WithoutAnExistingDocument_CreatesNoArchive;

    [Test]
    procedure Reset_StartsANewRun;
    [Test]
    procedure SameDocumentNamedDifferently_IsStartedOnce;
    [Test]
    procedure StandAlone_IsNotArchived;

    [Test]
    procedure Preamble_NotRegistered_IsEmpty;
    [Test]
    procedure Preamble_NotWrittenYet_IsEmpty;
    [Test]
    procedure Preamble_IsFoundByAnyPathSpellingWithoutTrailingBlankLines;
    [Test]
    procedure Reset_ForgetsThePreambles;
  end;

implementation

uses
  System.IOUtils, System.DateUtils;

const
  OUTPUT_FOLDER = 'BDDRunTestOutput';
  DOCUMENT_NAME = 'Features.md';
  PREAMBLE_NAME = 'Preamble.md';
  // The archive name made from the last write time WriteOldRun gives the old
  // document, 2026-01-02 03:04:05
  ARCHIVE_NAME = 'Features_2026-01-02_030405.md';

{ TPsBDDRunTests }

procedure TPsBDDRunTests.Setup;
begin
  FDirectory := TPath.Combine(ExtractFilePath(ParamStr(0)), OUTPUT_FOLDER);
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
  TDirectory.CreateDirectory(FDirectory);
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
end;

procedure TPsBDDRunTests.TearDown;
begin
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

function TPsBDDRunTests.PathOf(const AName: string): string;
begin
  Result := TPath.Combine(FDirectory, AName);
end;

// Writes the document of an earlier run, with one feature, and dates it
// 2026-01-02 03:04:05. The run is then forgotten, so the next open is the first of a
// new run.
procedure TPsBDDRunTests.WriteOldRun;
begin
  WriteFeature(DOCUMENT_NAME, 'Old run');
  TFile.SetLastWriteTime(PathOf(DOCUMENT_NAME),
    EncodeDateTime(2026, 1, 2, 3, 4, 5, 0));
  TPsBDDRun.Reset;
end;

// One fixture of a run: opens the document that is added to, writes a
// feature and closes it
procedure TPsBDDRunTests.WriteFeature(const AName, ATitle: string);
var
  Document: IPsBDDDocument;
begin
  Document := TPsBDDMarkdownDocument.Create(PathOf(AName), auTester, False);
  Document.Open;
  Document.WriteFeature(ATitle, '', fsImplemented);
  Document.Close;
end;

function TPsBDDRunTests.ReadText(const AName: string): string;
begin
  Result := TFile.ReadAllText(PathOf(AName), TEncoding.UTF8);
end;

function TPsBDDRunTests.FeatureHeadings(const AName: string): TArray<string>;
var
  LLine: string;
begin
  Result := nil;
  for LLine in TFile.ReadAllLines(PathOf(AName), TEncoding.UTF8) do
    if LLine.StartsWith('# Feature ') then
      Result := Result + [LLine];
end;

// Checks the output folder holds exactly the files ANames
procedure TPsBDDRunTests.ExpectFiles(const ANames: array of string);
var
  LName: string;
begin
  Assert.AreEqual(Length(ANames), Length(TDirectory.GetFiles(FDirectory)),
    'Files: ' + string.Join(', ', TDirectory.GetFiles(FDirectory)));
  for LName in ANames do
    Assert.IsTrue(TFile.Exists(PathOf(LName)), LName + ' is missing');
end;

procedure TPsBDDRunTests.RunStart_IsAppendByDefault;
begin
  // A class var starts as zero, the first value of the enumeration
  Assert.AreEqual(Ord(rsAppend), Ord(Default(TPsBDDRunStart)));
end;

procedure TPsBDDRunTests.Append_ContinuesTheExistingDocument;
begin
  WriteOldRun;

  WriteFeature(DOCUMENT_NAME, 'New run');

  Assert.AreEqual(string.Join('|', [
    '# Feature 1: Old run',
    '# Feature 2: New run']),
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
  ExpectFiles([DOCUMENT_NAME]);
end;

procedure TPsBDDRunTests.Overwrite_StartsANewDocument;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsOverwrite;

  WriteFeature(DOCUMENT_NAME, 'New run');

  Assert.AreEqual('# Feature 1: New run',
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
  Assert.IsFalse(ReadText(DOCUMENT_NAME).Contains('Old run'));
  ExpectFiles([DOCUMENT_NAME]);
end;

procedure TPsBDDRunTests.Overwrite_LaterOpensInTheRunAppend;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsOverwrite;

  // Two fixtures of one run writing the same document
  WriteFeature(DOCUMENT_NAME, 'Customers');
  WriteFeature(DOCUMENT_NAME, 'Invoices');

  Assert.AreEqual(string.Join('|', [
    '# Feature 1: Customers',
    '# Feature 2: Invoices']),
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
end;

procedure TPsBDDRunTests.Overwrite_RemovesTheOldDocumentEvenWhenNothingIsWritten;
var
  Document: IPsBDDDocument;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsOverwrite;

  // The first fixture of the run writes nothing to the document
  Document := TPsBDDMarkdownDocument.Create(PathOf(DOCUMENT_NAME), auTester, False);
  Document.Open;
  Document.Close;
  Assert.IsFalse(TFile.Exists(PathOf(DOCUMENT_NAME)));

  // So the next one does not add to the old run
  WriteFeature(DOCUMENT_NAME, 'New run');
  Assert.AreEqual('# Feature 1: New run',
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
end;

procedure TPsBDDRunTests.Archive_RenamesTheOldDocumentWithItsLastWriteTime;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsArchive;

  WriteFeature(DOCUMENT_NAME, 'New run');

  ExpectFiles([ARCHIVE_NAME, DOCUMENT_NAME]);
  Assert.AreEqual('# Feature 1: Old run',
    string.Join('|', FeatureHeadings(ARCHIVE_NAME)));
  Assert.AreEqual('# Feature 1: New run',
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
end;

procedure TPsBDDRunTests.Archive_AddsANumberWhenTheNameIsTaken;
const
  SECOND_ARCHIVE_NAME = 'Features_2026-01-02_030405_2.md';
begin
  TFile.WriteAllText(PathOf(ARCHIVE_NAME), 'Archived before', TEncoding.UTF8);
  WriteOldRun;
  TPsBDDRun.RunStart := rsArchive;

  WriteFeature(DOCUMENT_NAME, 'New run');

  ExpectFiles([ARCHIVE_NAME, SECOND_ARCHIVE_NAME, DOCUMENT_NAME]);
  Assert.AreEqual('Archived before', ReadText(ARCHIVE_NAME));
  Assert.AreEqual('# Feature 1: Old run',
    string.Join('|', FeatureHeadings(SECOND_ARCHIVE_NAME)));
end;

procedure TPsBDDRunTests.Archive_LaterOpensInTheRunAppend;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsArchive;

  WriteFeature(DOCUMENT_NAME, 'Customers');
  WriteFeature(DOCUMENT_NAME, 'Invoices');

  // One archive, and both features of the run in the new document
  ExpectFiles([ARCHIVE_NAME, DOCUMENT_NAME]);
  Assert.AreEqual(string.Join('|', [
    '# Feature 1: Customers',
    '# Feature 2: Invoices']),
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
end;

procedure TPsBDDRunTests.Archive_WithoutAnExistingDocument_CreatesNoArchive;
begin
  TPsBDDRun.RunStart := rsArchive;

  WriteFeature(DOCUMENT_NAME, 'First run');

  ExpectFiles([DOCUMENT_NAME]);
end;

procedure TPsBDDRunTests.Reset_StartsANewRun;
begin
  TPsBDDRun.RunStart := rsOverwrite;
  WriteFeature(DOCUMENT_NAME, 'First run');

  TPsBDDRun.Reset;
  WriteFeature(DOCUMENT_NAME, 'Second run');

  Assert.AreEqual('# Feature 1: Second run',
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
end;

procedure TPsBDDRunTests.SameDocumentNamedDifferently_IsStartedOnce;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsArchive;

  WriteFeature(DOCUMENT_NAME, 'Customers');
  // The same file in other case and through a relative part
  WriteFeature(TPath.Combine('..', TPath.Combine(OUTPUT_FOLDER,
    UpperCase(DOCUMENT_NAME))), 'Invoices');

  ExpectFiles([ARCHIVE_NAME, DOCUMENT_NAME]);
  Assert.AreEqual(string.Join('|', [
    '# Feature 1: Customers',
    '# Feature 2: Invoices']),
    string.Join('|', FeatureHeadings(DOCUMENT_NAME)));
end;

procedure TPsBDDRunTests.StandAlone_IsNotArchived;
var
  Document: IPsBDDDocument;
begin
  WriteOldRun;
  TPsBDDRun.RunStart := rsArchive;

  // A stand alone document replaces its file, as before
  Document := TPsBDDMarkdownDocument.Create(PathOf(DOCUMENT_NAME), auTester, True);
  Document.Open;
  Document.WriteScenario('Stand alone');
  Document.Close;

  ExpectFiles([DOCUMENT_NAME]);
  Assert.IsFalse(ReadText(DOCUMENT_NAME).Contains('Old run'));
end;

{ Preambles }

procedure TPsBDDRunTests.Preamble_NotRegistered_IsEmpty;
begin
  Assert.AreEqual(0, Length(TPsBDDRun.PreambleFor(PathOf(DOCUMENT_NAME))));
end;

procedure TPsBDDRunTests.Preamble_NotWrittenYet_IsEmpty;
begin
  TPsBDDRun.AddPreamble(PathOf(DOCUMENT_NAME), PathOf(PREAMBLE_NAME));

  Assert.AreEqual(0, Length(TPsBDDRun.PreambleFor(PathOf(DOCUMENT_NAME))));
end;

procedure TPsBDDRunTests.Preamble_IsFoundByAnyPathSpellingWithoutTrailingBlankLines;
begin
  TFile.WriteAllLines(PathOf(PREAMBLE_NAME),
    ['# Converter', '', 'Converts the data files.', '', ''], TEncoding.UTF8);
  TPsBDDRun.AddPreamble(PathOf(DOCUMENT_NAME), PathOf(PREAMBLE_NAME));

  Assert.AreEqual(string.Join('|', ['# Converter', '', 'Converts the data files.']),
    string.Join('|', TPsBDDRun.PreambleFor(PathOf(TPath.Combine('..',
      TPath.Combine(OUTPUT_FOLDER, UpperCase(DOCUMENT_NAME)))))));
end;

procedure TPsBDDRunTests.Reset_ForgetsThePreambles;
begin
  TFile.WriteAllText(PathOf(PREAMBLE_NAME), '# Converter', TEncoding.UTF8);
  TPsBDDRun.AddPreamble(PathOf(DOCUMENT_NAME), PathOf(PREAMBLE_NAME));

  TPsBDDRun.Reset;

  Assert.AreEqual(0, Length(TPsBDDRun.PreambleFor(PathOf(DOCUMENT_NAME))));
end;

initialization
  TDUnitX.RegisterTestFixture(TPsBDDRunTests);

end.
