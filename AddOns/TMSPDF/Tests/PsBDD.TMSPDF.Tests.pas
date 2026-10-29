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

unit PsBDD.TMSPDF.Tests;

{
  DUnitX tests for TPsBDDTMSPDFConversion.

  Each test writes a Markdown document with TPsBDDMarkdownDocument, converts
  it and reads the PDF back with TMS FNC Core: page count, document
  information and the text of each page. The layout itself (fonts, colours,
  positions) is not checked here; look at a converted PDF for that.

  The files are written to a BDDTMSPDFTestOutput folder next to the test
  executable. The folder is emptied before each test and removed after it.
}

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  PsBDD.Framework, PsBDD.MarkdownDocument, PsBDD.TMSPDF;

type
  TPdfContent = record
    PageCount: Integer;
    Title: string;
    Author: string;
    Creator: string;
    /// <summary>The text of each page, white space collapsed to one space.</summary>
    Pages: TArray<string>;
    function AllText: string;
  end;

  [TestFixture]
  TPsBDDTMSPDFConversionTests = class
  private
    FDirectory: string;
    FMissingConversion: IPsBDDConversion;
    function PathOf(const AName: string): string;
    function NewMarkdown(AStandAlone: Boolean): IPsBDDDocument;
    procedure WriteCustomerListFeature(const ADocument: IPsBDDDocument);
    procedure WriteMarkdown(AStandAlone: Boolean);
    procedure Convert(const ATitle: string = ''; const AAuthor: string = '');
    function ReadPdf(const AName: string = ''): TPdfContent;
    procedure ConvertMissingMarkdown;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Description_NamesBothFiles;
    [Test]
    procedure MissingMarkdown_RaisesFileNotFound;
    [Test]
    procedure Convert_WritesTitleAuthorAndCreator;
    [Test]
    procedure Convert_TitleDefaultsToTheMarkdownFileName;
    [Test]
    procedure Convert_CreatesTheMissingFolder;
    [Test]
    procedure StandAlone_DrawsFeatureScenariosStepsAndStatus;
    [Test]
    procedure Combined_StartsWithATableOfContentsPage;
    [Test]
    procedure FailedScenario_ShowsItsMessage;
    [Test]
    procedure MarkdownEscapes_AreRemoved;
    [Test]
    procedure HandWrittenText_IsKept;
    [Test]
    procedure LongDocument_FlowsOntoMorePages;
    [Test]
    procedure PerformConversions_WritesThePdf;
    [Test]
    procedure Preamble_IsOnACoverPageBeforeTheContents;
    [Test]
    procedure Preamble_KeepsItsFormattingAndListItems;
  end;

implementation

uses
  System.IOUtils, System.RegularExpressions,
  VCL.TMSFNCPDFLib;

const
  OUTPUT_FOLDER = 'BDDTMSPDFTestOutput';
  MARKDOWN_NAME = 'Features.md';
  PDF_NAME = 'Features.pdf';
  DESCRIPTION = '''
    As a clerk
    I want to check whether a customer is in the customer list
    So that I do not create the same customer twice
    ''';

{ TPdfContent }

function TPdfContent.AllText: string;
begin
  Result := string.Join(' ', Pages);
end;

{ TPsBDDTMSPDFConversionTests }

procedure TPsBDDTMSPDFConversionTests.Setup;
begin
  FDirectory := TPath.Combine(ExtractFilePath(ParamStr(0)), OUTPUT_FOLDER);
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
  TDirectory.CreateDirectory(FDirectory);
  TPsBDDRun.Reset;
  TPsBDDRun.RunStart := rsAppend;
end;

procedure TPsBDDTMSPDFConversionTests.TearDown;
begin
  FMissingConversion := nil;
  TPsBDDRun.Reset;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

function TPsBDDTMSPDFConversionTests.PathOf(const AName: string): string;
begin
  Result := TPath.Combine(FDirectory, AName);
end;

function TPsBDDTMSPDFConversionTests.NewMarkdown(
  AStandAlone: Boolean): IPsBDDDocument;
begin
  Result := TPsBDDMarkdownDocument.Create(PathOf(MARKDOWN_NAME), auTester,
    AStandAlone);
end;

// The feature of CustomerListExample.md
procedure TPsBDDTMSPDFConversionTests.WriteCustomerListFeature(
  const ADocument: IPsBDDDocument);
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

procedure TPsBDDTMSPDFConversionTests.WriteMarkdown(AStandAlone: Boolean);
var
  Document: IPsBDDDocument;
begin
  Document := NewMarkdown(AStandAlone);
  Document.Open;
  WriteCustomerListFeature(Document);
  Document.Close;
end;

procedure TPsBDDTMSPDFConversionTests.Convert(const ATitle, AAuthor: string);
var
  Conversion: IPsBDDConversion;
begin
  Conversion := TPsBDDTMSPDFConversion.Create(PathOf(MARKDOWN_NAME),
    PathOf(PDF_NAME), ATitle, AAuthor);
  Conversion.Convert;
end;

function TPsBDDTMSPDFConversionTests.ReadPdf(const AName: string): TPdfContent;
var
  LPdf: TTMSFNCPDFLib;
  LPath: string;
  I: Integer;
begin
  LPath := PathOf(PDF_NAME);
  if AName <> '' then
    LPath := PathOf(AName);
  Assert.IsTrue(TFile.Exists(LPath), 'The PDF was not written');

  LPdf := TTMSFNCPDFLib.Create;
  try
    LPdf.OpenDocument(LPath);
    Result.PageCount := LPdf.GetPageCount;
    Result.Title := LPdf.Title;
    Result.Author := LPdf.Author;
    Result.Creator := LPdf.Creator;
    SetLength(Result.Pages, Result.PageCount);
    for I := 0 to Result.PageCount - 1 do
      Result.Pages[I] := Trim(TRegEx.Replace(LPdf.GetDocumentPageText(I),
        '\s+', ' '));
  finally
    LPdf.Free;
  end;
end;

procedure TPsBDDTMSPDFConversionTests.ConvertMissingMarkdown;
begin
  FMissingConversion.Convert;
end;

procedure TPsBDDTMSPDFConversionTests.Description_NamesBothFiles;
var
  Conversion: IPsBDDConversion;
begin
  Conversion := TPsBDDTMSPDFConversion.Create('C:\Docs\AllFeatures.md',
    'D:\Reports\AllFeatures.pdf');

  Assert.AreEqual('AllFeatures.md to AllFeatures.pdf', Conversion.Description);
end;

procedure TPsBDDTMSPDFConversionTests.MissingMarkdown_RaisesFileNotFound;
begin
  FMissingConversion := TPsBDDTMSPDFConversion.Create(PathOf('Missing.md'),
    PathOf(PDF_NAME));

  Assert.WillRaise(ConvertMissingMarkdown, EFileNotFoundException);
  Assert.IsFalse(TFile.Exists(PathOf(PDF_NAME)), 'A PDF was written');
end;

procedure TPsBDDTMSPDFConversionTests.Convert_WritesTitleAuthorAndCreator;
var
  LPdf: TPdfContent;
begin
  WriteMarkdown(True);

  Convert('Customer features', 'Proshine Window Cleaning');

  LPdf := ReadPdf;
  Assert.AreEqual('Customer features', LPdf.Title);
  Assert.AreEqual('Proshine Window Cleaning', LPdf.Author);
  Assert.AreEqual('PsBDD', LPdf.Creator);
  // The title is in the page header too
  Assert.Contains(LPdf.Pages[0], 'Customer features');
end;

procedure TPsBDDTMSPDFConversionTests.Convert_TitleDefaultsToTheMarkdownFileName;
begin
  WriteMarkdown(True);

  Convert;

  Assert.AreEqual('Features', ReadPdf.Title);
end;

procedure TPsBDDTMSPDFConversionTests.Convert_CreatesTheMissingFolder;
var
  Conversion: IPsBDDConversion;
begin
  WriteMarkdown(True);

  Conversion := TPsBDDTMSPDFConversion.Create(PathOf(MARKDOWN_NAME),
    PathOf(TPath.Combine('Sub', PDF_NAME)));
  Conversion.Convert;

  Assert.IsTrue(TFile.Exists(PathOf(TPath.Combine('Sub', PDF_NAME))));
end;

procedure TPsBDDTMSPDFConversionTests.StandAlone_DrawsFeatureScenariosStepsAndStatus;
var
  LText: string;
begin
  WriteMarkdown(True);

  Convert;

  LText := ReadPdf.AllText;
  Assert.IsFalse(LText.Contains('Table of Contents'),
    'A stand alone document has no table of contents');
  Assert.Contains(LText, 'Feature: Customer list');
  Assert.Contains(LText, 'Run:');
  Assert.Contains(LText, 'In Development');
  Assert.Contains(LText, 'I want to check whether a customer is in the customer list');
  Assert.Contains(LText, 'REQ#014:');
  Assert.Contains(LText, 'Scenario: Customer is found in the list');
  Assert.Contains(LText, 'Given a customer list with "Smith" and "Jones"');
  Assert.Contains(LText, 'And exactly one match is returned');
  Assert.Contains(LText, 'But the customer list still holds 2 customers');
  Assert.Contains(LText, 'Status: Passed');
end;

procedure TPsBDDTMSPDFConversionTests.Combined_StartsWithATableOfContentsPage;
var
  LPdf: TPdfContent;
begin
  WriteMarkdown(False);

  Convert;

  LPdf := ReadPdf;
  Assert.IsTrue(LPdf.PageCount >= 2, 'The table of contents has no page of its own');
  Assert.Contains(LPdf.Pages[0], 'Table of Contents');
  Assert.Contains(LPdf.Pages[0], 'Feature 1: Customer list');
  Assert.Contains(LPdf.Pages[0], 'Scenario 2: Unknown customer is not found');
  Assert.IsFalse(LPdf.Pages[0].Contains('Run:'), 'Content is on the contents page');
  Assert.Contains(LPdf.Pages[1], 'Feature 1: Customer list');
  Assert.Contains(LPdf.Pages[1], 'Run:');
end;

procedure TPsBDDTMSPDFConversionTests.FailedScenario_ShowsItsMessage;
var
  Document: IPsBDDDocument;
  LText: string;
begin
  Document := NewMarkdown(True);
  Document.Open;
  Document.WriteScenario('Customer can be deleted');
  Document.WriteStep(skGiven, 'a customer list with "Smith"');
  Document.WriteScenarioStatus(ssFailed,
    'Condition is False when True expected. The list still holds 1 customer');
  Document.Close;

  Convert;

  LText := ReadPdf.AllText;
  Assert.Contains(LText,
    'Status: Failed - Condition is False when True expected. The list still holds 1 customer');
end;

procedure TPsBDDTMSPDFConversionTests.MarkdownEscapes_AreRemoved;
var
  Document: IPsBDDDocument;
  LText: string;
begin
  Document := NewMarkdown(True);
  Document.Open;
  Document.WriteScenario('Total *must* be [1|2]');
  Document.WriteStep(skGiven, 'file C:\temp\a_b.txt & <tag>');
  Document.Close;

  Convert;

  LText := ReadPdf.AllText;
  Assert.Contains(LText, 'Total *must* be [1|2]');
  Assert.Contains(LText, 'file C:\temp\a_b.txt & <tag>');
end;

procedure TPsBDDTMSPDFConversionTests.HandWrittenText_IsKept;
var
  Document: IPsBDDDocument;
begin
  TFile.WriteAllText(PathOf(MARKDOWN_NAME),
    'Written by hand before the first run.' + sLineBreak, TEncoding.UTF8);
  Document := NewMarkdown(False);
  Document.Open;
  Document.WriteScenario('Added');
  Document.Close;

  Convert;

  Assert.Contains(ReadPdf.AllText, 'Written by hand before the first run.');
end;

procedure TPsBDDTMSPDFConversionTests.LongDocument_FlowsOntoMorePages;
var
  Document: IPsBDDDocument;
  LPdf: TPdfContent;
  I: Integer;
begin
  Document := NewMarkdown(False);
  Document.Open;
  Document.WriteFeature('Many scenarios', '', fsImplemented);
  for I := 1 to 60 do
  begin
    Document.WriteScenario(Format('Scenario number %d', [I]));
    Document.WriteStep(skGiven, 'a step');
    Document.WriteStep(skThen, 'another step');
    Document.WriteScenarioStatus(ssPassed, '');
  end;
  Document.Close;

  Convert;

  LPdf := ReadPdf;
  Assert.IsTrue(LPdf.PageCount > 3, Format('Only %d pages', [LPdf.PageCount]));
  // Every scenario is drawn: each title once in the contents, once as heading
  for I := 1 to 60 do
    Assert.AreEqual(2, TRegEx.Matches(LPdf.AllText,
      Format('Scenario %0:d: Scenario number %0:d\b', [I])).Count,
      Format('Scenario %d', [I]));
  Assert.Contains(LPdf.Pages[LPdf.PageCount - 1], 'Scenario number 60');
end;

procedure TPsBDDTMSPDFConversionTests.PerformConversions_WritesThePdf;
begin
  WriteMarkdown(False);

  TPsBDDRun.AddConversion(TPsBDDTMSPDFConversion.Create(PathOf(MARKDOWN_NAME),
    PathOf(PDF_NAME)));
  TPsBDDRun.PerformConversions;

  Assert.Contains(ReadPdf.AllText, 'Scenario 1: Customer is found in the list');
end;

procedure TPsBDDTMSPDFConversionTests.Preamble_IsOnACoverPageBeforeTheContents;
var
  LPdf: TPdfContent;
begin
  TFile.WriteAllLines(PathOf('Preamble.md'), [
    '# Converter',
    '',
    'Converts the Florida corporate data files to CSV.'], TEncoding.UTF8);
  TPsBDDRun.AddPreamble(PathOf(MARKDOWN_NAME), PathOf('Preamble.md'));
  WriteMarkdown(False);

  Convert;

  LPdf := ReadPdf;
  Assert.IsTrue(LPdf.PageCount >= 3, Format('Only %d pages', [LPdf.PageCount]));
  // Cover, then contents, then the features
  Assert.Contains(LPdf.Pages[0], 'Converts the Florida corporate data files to CSV.');
  Assert.IsFalse(LPdf.Pages[0].Contains('Table of Contents'), 'Contents on the cover');
  Assert.Contains(LPdf.Pages[1], 'Table of Contents');
  Assert.Contains(LPdf.Pages[1], 'Feature 1: Customer list');
  // The preamble's heading is not in the contents
  Assert.IsFalse(LPdf.Pages[1].Contains('Converter'), 'Preamble heading in the contents');
  Assert.Contains(LPdf.Pages[2], 'Run:');
end;

procedure TPsBDDTMSPDFConversionTests.Preamble_KeepsItsFormattingAndListItems;
var
  LCover: string;
begin
  // Hand-written Markdown, not escaped as PsBDD escapes its own text
  TFile.WriteAllLines(PathOf('Preamble.md'), [
    '# Customer Lookup',
    '',
    '**Written by its tests.** Searching *never* changes `customers.db`.',
    '',
    '* **Clerks** search the list',
    '  while taking a call.',
    '* **Managers** read this document.'], TEncoding.UTF8);
  TPsBDDRun.AddPreamble(PathOf(MARKDOWN_NAME), PathOf('Preamble.md'));
  WriteMarkdown(False);

  Convert;

  LCover := ReadPdf.Pages[0];
  // Reading the text back adds a space where the code font ends
  Assert.Contains(LCover, 'Written by its tests. Searching never changes customers.db');
  // List items, not Given / When / Then steps, with their continuation line
  Assert.Contains(LCover, 'Clerks search the list while taking a call.');
  Assert.Contains(LCover, 'Managers read this document.');
  Assert.Contains(LCover, #$2022);
  Assert.IsFalse(LCover.Contains('*'), 'Markdown markup is shown: ' + LCover);
  Assert.IsFalse(LCover.Contains('`'), 'Markdown markup is shown: ' + LCover);
end;

initialization
  TDUnitX.RegisterTestFixture(TPsBDDTMSPDFConversionTests);

end.
