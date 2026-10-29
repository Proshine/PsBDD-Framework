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

unit PsBDD.MarkdownDocument;

{
  Markdown implementation of IPsBDDDocument.

  The document is built in memory and written to disk by Close, and only when
  something was written to it. Only plain Markdown is written, no HTML, so the
  document can be read by any Markdown reader and processed by conversion
  software that expects Markdown.

  Feature
    The time the document was opened and the status of the feature follow
    the heading, so every run is dated:

      # Feature: Customer maintenance

      **Run:** 2026-10-25 14:03:12

      **Status:** In Development

  Scenario
    When a scenario ends its status is written after its steps:

      **Status:** Passed

    or, when a step raised an exception:

      **Status:** Failed - the message of the exception

  Stand alone document (StandAlone = True)
    The file is replaced. Features and scenarios are written as plain
    headings.

  Part of a larger document (StandAlone = False)
    The existing file is loaded by Open and the new content is added to the
    end of it, so each run adds a dated feature and the document keeps a
    running audit. Set TPsBDDRun.RunStart to start a new document, or archive
    the old one, at the first open of each test run instead.

    Features and scenarios are numbered, so every heading in the document is
    unique, also across runs. The numbers continue from the headings already
    in the document:

      # Feature 1: Customer maintenance
      ## Scenario 1: Customer can be saved

    A table of contents is kept between two markers, by default at the top
    of the document:

      # Table of Contents

      [BDD-TOC-START]: #

      - [Feature 1: Customer maintenance](#feature-1-customer-maintenance)
        - [Scenario 1: Customer can be saved](#scenario-1-customer-can-be-saved)

      [BDD-TOC-END]: #

    The markers are link reference definitions that nothing links to, the
    usual way to write a comment in Markdown. Readers do not show them, and
    each has its own label so converters do not report a duplicate. The
    marker block can be moved anywhere in the document, it is found again
    by its markers.

    A new document starts with the preamble registered for it with
    TPsBDDRun.AddPreamble, when its file exists, and the table of contents
    below it.

    The links are plain Markdown links to the headings, using the heading id
    most Markdown tools generate (GitHub, GitLab, VS Code, Pandoc, ...):
    lower case, letters, digits, hyphens and underscores kept, each space
    becomes a hyphen and all other characters are removed.

  Text
    Titles, descriptions, requirements and steps are escaped so characters
    such as * and _ do not change the formatting. Multiline text keeps its
    line breaks. Pass it as a const multiline string:

      const
        CUSTOMER_DESCRIPTION = '''
          As a clerk
          I want to save a new customer
          So that I can find the customer later
          ''';
}

interface

uses
  System.SysUtils, System.Classes,
  PsBDD.Framework;

type
  /// <summary>
  ///   Writes a BDD document as Markdown. Create it with the path, audience
  ///   and mode of the document and add it to a feature document writer,
  ///   which opens and closes it.
  /// </summary>
  TPsBDDMarkdownDocument = class(TInterfacedObject, IPsBDDDocument)
  private
    FTarget: TPsBDDDocumentTarget;
    FLines: TStringList;
    FIsOpen: Boolean;
    FModified: Boolean;
    FFeatureWritten: Boolean;
    FFeatureCount: Integer;
    FScenarioCount: Integer;
    FOpenedAt: TDateTime;
    procedure AddPreamble;
    procedure AddText(const AText: string);
    procedure AddTocEntry(const AEntry: string);
    procedure BeginWrite;
    procedure CheckOpen;
    procedure EnsureBlankLine;
    procedure EnsureToc;
    function FindLine(const AText: string): Integer;
    function GetTarget: TPsBDDDocumentTarget;
    function HasToc: Boolean;
    function HeadingText(const AKind, ATitle: string;
      var ACounter: Integer; const ATocIndent: string): string;
    function LastHeadingNumber(const AHeadingStart: string): Integer;
    procedure Save;
  public
    /// <summary>Creates a Markdown document for the given target.</summary>
    /// <param name="APath">The path of the .md file.</param>
    /// <param name="AAudience">The audience of the document.</param>
    /// <param name="AStandAlone">
    ///   True writes a new document, replacing any existing file. False adds
    ///   to the existing document, which is created when it does not exist,
    ///   and maintains its table of contents.
    /// </param>
    constructor Create(const APath: string; AAudience: TPsBDDAudience;
      AStandAlone: Boolean);
    destructor Destroy; override;

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

implementation

uses
  System.IOUtils, System.Character;

const
  STEP_KEYWORDS: array[TPsBDDStepKind] of string =
    ('Given', 'When', 'Then', 'And', 'But');

  FEATURE_STATUS_NAMES: array[TPsBDDFeatureStatus] of string =
    ('Proposed', 'In Development', 'Implemented', 'Accepted', 'Deprecated');

  SCENARIO_STATUS_NAMES: array[TPsBDDScenarioStatus] of string =
    ('Passed', 'Failed');

  // The time shown below the feature heading
  TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss';

  // Markdown comments: link reference definitions that readers do not show
  TOC_START_MARKER = '[BDD-TOC-START]: #';
  TOC_END_MARKER = '[BDD-TOC-END]: #';
  TOC_NEST_INDENT = '  ';
  TOC_ENTRY_TEMPLATE = '%s- [%s](#%s)';

  FEATURE_KIND = 'Feature';
  SCENARIO_KIND = 'Scenario';
  FEATURE_LEVEL = '# ';
  SCENARIO_LEVEL = '## ';

  // %s = kind, title
  HEADING_TEMPLATE = '%s: %s';
  // %s = kind, %d = number, %s = title
  NUMBERED_HEADING_TEMPLATE = '%s %d: %s';

  SCENARIO_STATUS_TEMPLATE = '**Status:** %s';
  STEP_TEMPLATE = '%s* **%s** %s';
  REQUIREMENT_TEMPLATE = '> **%s:** %s';
  QUOTE_PREFIX = '> ';

  // %s = start marker, end marker. The two blank lines between the markers
  // keep the entries apart from the end marker, so the end marker is never
  // read as part of the last entry.
  TOC_BLOCK_TEMPLATE = '''
    # Table of Contents

    %s


    %s
    ''';

  // %s = heading text, run time, status, description
  FEATURE_TEMPLATE = '''
    # %s

    **Run:** %s

    **Status:** %s

    %s
    ''';

{ Text helpers }

// Escapes the characters that change Markdown formatting.
function EscapeMarkdown(const AText: string): string;
var
  LChar: Char;
begin
  Result := '';
  for LChar in AText do
  begin
    if CharInSet(LChar, ['\', '`', '*', '_', '[', ']', '<', '>', '|']) then
      Result := Result + '\';
    Result := Result + LChar;
  end;
  // a leading # would become a heading
  if (Result <> '') and (Result[1] = '#') then
    Result := '\' + Result;
end;

// Escapes AText and keeps its line breaks: a line that is followed by
// another line of text ends with two spaces (a Markdown line break) and every
// line after the first starts with AContinuation.
function MarkdownText(const AText: string;
  const AContinuation: string = ''): string;
var
  LLines: TStringList;
  LText, LLine: string;
  I: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    for I := 0 to LLines.Count - 1 do
    begin
      LText := Trim(LLines[I]);
      LLine := EscapeMarkdown(LText);
      if I > 0 then
      begin
        Result := Result + sLineBreak;
        if LText = '' then
          LLine := TrimRight(AContinuation)
        else
          LLine := AContinuation + LLine;
      end;
      if (LText <> '') and (I < LLines.Count - 1)
        and (Trim(LLines[I + 1]) <> '') then
        LLine := LLine + '  ';
      Result := Result + LLine;
    end;
  finally
    LLines.Free;
  end;
end;

// The heading id most Markdown tools generate: lower case, letters, digits,
// hyphens and underscores kept, each space becomes a hyphen, everything else
// removed.
function HeadingId(const AHeading: string): string;
var
  LChar: Char;
begin
  Result := '';
  for LChar in AHeading.ToLower do
  begin
    if LChar.IsLetterOrDigit or (LChar = '-') or (LChar = '_') then
      Result := Result + LChar
    else if LChar = ' ' then
      Result := Result + '-';
  end;
end;

{ TPsBDDMarkdownDocument }

constructor TPsBDDMarkdownDocument.Create(const APath: string;
  AAudience: TPsBDDAudience; AStandAlone: Boolean);
begin
  inherited Create;
  FTarget.Path := APath;
  FTarget.Audience := AAudience;
  FTarget.StandAlone := AStandAlone;
  FLines := TStringList.Create;
end;

destructor TPsBDDMarkdownDocument.Destroy;
begin
  // Safety net when Close was not called. Errors are not raised from a
  // destructor. Call Close explicitly to see them.
  try
    Close;
  except
  end;
  FLines.Free;
  inherited;
end;

function TPsBDDMarkdownDocument.GetTarget: TPsBDDDocumentTarget;
begin
  Result := FTarget;
end;

function TPsBDDMarkdownDocument.HasToc: Boolean;
begin
  Result := not FTarget.StandAlone;
end;

procedure TPsBDDMarkdownDocument.CheckOpen;
begin
  if not FIsOpen then
    raise EInvalidOperation.CreateFmt(
      'The BDD document "%s" must be opened before it is written to.',
      [FTarget.Path]);
end;

procedure TPsBDDMarkdownDocument.BeginWrite;
begin
  CheckOpen;
  if HasToc then
    EnsureToc;
  FModified := True;
end;

procedure TPsBDDMarkdownDocument.AddText(const AText: string);
var
  LLines: TStringList;
begin
  // Splits on CRLF, LF and CR so the line breaks are always consistent
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    FLines.AddStrings(LLines);
  finally
    LLines.Free;
  end;
end;

procedure TPsBDDMarkdownDocument.EnsureBlankLine;
begin
  if (FLines.Count > 0) and (FLines[FLines.Count - 1] <> '') then
    FLines.Add('');
end;

function TPsBDDMarkdownDocument.FindLine(const AText: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FLines.Count - 1 do
    if Trim(FLines[I]) = AText then
      Exit(I);
  Result := -1;
end;

// Returns the highest number of the headings that start with AHeadingStart,
// for example '## Scenario ', or 0 when there are none.
function TPsBDDMarkdownDocument.LastHeadingNumber(
  const AHeadingStart: string): Integer;
var
  LLine: string;
  LStart, LEnd, LNumber: Integer;
begin
  Result := 0;
  for LLine in FLines do
  begin
    if not LLine.StartsWith(AHeadingStart) then
      Continue;
    LStart := Length(AHeadingStart) + 1;
    LEnd := LStart;
    while (LEnd <= Length(LLine)) and CharInSet(LLine[LEnd], ['0'..'9']) do
      Inc(LEnd);
    if TryStrToInt(Copy(LLine, LStart, LEnd - LStart), LNumber)
      and (LNumber > Result) then
      Result := LNumber;
  end;
end;

procedure TPsBDDMarkdownDocument.EnsureToc;
var
  LTop: TStringList;
begin
  if FindLine(TOC_END_MARKER) >= 0 then
    Exit;

  // No table of contents yet: put one at the top of the document
  LTop := TStringList.Create;
  try
    LTop.Text := Format(TOC_BLOCK_TEMPLATE, [TOC_START_MARKER, TOC_END_MARKER]);
    LTop.Add('');
    LTop.AddStrings(FLines);
    FLines.Assign(LTop);
  finally
    LTop.Free;
  end;
end;

procedure TPsBDDMarkdownDocument.AddTocEntry(const AEntry: string);
var
  LEnd: Integer;
begin
  // The end marker must follow a blank line, otherwise a reader takes it as
  // part of the last entry and shows it
  LEnd := FindLine(TOC_END_MARKER);
  if (LEnd = 0) or (Trim(FLines[LEnd - 1]) <> '') then
  begin
    FLines.Insert(LEnd, '');
    Inc(LEnd);
  end;
  // Entries go in front of that blank line, so they stay in the order written
  FLines.Insert(LEnd - 1, AEntry);
end;

// Returns the heading text, without the heading level. When the document has
// a table of contents it also numbers the heading and adds its table of
// contents entry.
function TPsBDDMarkdownDocument.HeadingText(const AKind, ATitle: string;
  var ACounter: Integer; const ATocIndent: string): string;
begin
  if not HasToc then
    Exit(Format(HEADING_TEMPLATE, [AKind, EscapeMarkdown(ATitle)]));

  Inc(ACounter);
  Result := Format(NUMBERED_HEADING_TEMPLATE,
    [AKind, ACounter, EscapeMarkdown(ATitle)]);
  // The link is made from the heading as a reader shows it, not escaped
  AddTocEntry(Format(TOC_ENTRY_TEMPLATE, [ATocIndent, Result,
    HeadingId(Format(NUMBERED_HEADING_TEMPLATE, [AKind, ACounter, ATitle]))]));
end;

// A new document that is added to starts with its preamble, when one is
// registered and written, and the table of contents below it
procedure TPsBDDMarkdownDocument.AddPreamble;
var
  LPreamble: TArray<string>;
  LToc: TStringList;
begin
  LPreamble := TPsBDDRun.PreambleFor(FTarget.Path);
  if Length(LPreamble) = 0 then
    Exit;
  FLines.AddStrings(LPreamble);
  FLines.Add('');
  LToc := TStringList.Create;
  try
    LToc.Text := Format(TOC_BLOCK_TEMPLATE, [TOC_START_MARKER, TOC_END_MARKER]);
    FLines.AddStrings(LToc);
  finally
    LToc.Free;
  end;
end;

procedure TPsBDDMarkdownDocument.Open;
begin
  if FIsOpen then
    Exit;
  if FTarget.Path = '' then
    raise EInvalidOperation.Create('The BDD document path has not been set.');

  FLines.Clear;
  if not FTarget.StandAlone then
  begin
    // The first open in the test run keeps, deletes or archives the existing
    // file, as TPsBDDRun.RunStart says
    TPsBDDRun.BeginDocument(FTarget.Path);
    if TFile.Exists(FTarget.Path) then
      FLines.LoadFromFile(FTarget.Path, TEncoding.UTF8)
    else
      AddPreamble;
  end;

  // Continue the numbers of the features and scenarios already in the
  // document
  FFeatureCount := LastHeadingNumber(FEATURE_LEVEL + FEATURE_KIND + ' ');
  FScenarioCount := LastHeadingNumber(SCENARIO_LEVEL + SCENARIO_KIND + ' ');
  FFeatureWritten := False;
  FModified := False;
  FOpenedAt := Now;
  FIsOpen := True;
end;

procedure TPsBDDMarkdownDocument.Save;
var
  LDirectory: string;
  LEncoding: TUTF8Encoding;
begin
  LDirectory := TPath.GetDirectoryName(FTarget.Path);
  if LDirectory <> '' then
    TDirectory.CreateDirectory(LDirectory);

  // UTF-8 without a byte order mark
  LEncoding := TUTF8Encoding.Create(False);
  try
    FLines.SaveToFile(FTarget.Path, LEncoding);
  finally
    LEncoding.Free;
  end;
end;

procedure TPsBDDMarkdownDocument.Close;
begin
  if not FIsOpen then
    Exit;
  if FModified then
    Save;
  FModified := False;
  FIsOpen := False;
end;

procedure TPsBDDMarkdownDocument.WriteFeature(const ATitle, ADescription: string;
  AStatus: TPsBDDFeatureStatus);
var
  LHeading: string;
begin
  BeginWrite;
  LHeading := HeadingText(FEATURE_KIND, ATitle, FFeatureCount, '');
  FFeatureWritten := True;
  EnsureBlankLine;
  // The run time makes each run of the feature a dated entry in the document
  AddText(Format(FEATURE_TEMPLATE, [LHeading,
    FormatDateTime(TIMESTAMP_FORMAT, FOpenedAt, TFormatSettings.Invariant),
    FEATURE_STATUS_NAMES[AStatus], MarkdownText(ADescription)]));
end;

procedure TPsBDDMarkdownDocument.WriteRequirement(const AReference, AText: string);
var
  LText: string;
begin
  BeginWrite;
  LText := MarkdownText(AText, QUOTE_PREFIX);
  EnsureBlankLine;
  if AReference = '' then
    AddText(QUOTE_PREFIX + LText)
  else
    AddText(TrimRight(Format(REQUIREMENT_TEMPLATE,
      [EscapeMarkdown(AReference), LText])));
  FLines.Add('');
end;

procedure TPsBDDMarkdownDocument.WriteScenario(const ATitle: string);
var
  LIndent, LHeading: string;
begin
  BeginWrite;
  // Scenarios are indented below their feature in the table of contents
  if FFeatureWritten then
    LIndent := TOC_NEST_INDENT
  else
    LIndent := '';
  LHeading := HeadingText(SCENARIO_KIND, ATitle, FScenarioCount, LIndent);
  EnsureBlankLine;
  AddText(SCENARIO_LEVEL + LHeading);
  FLines.Add('');
end;

procedure TPsBDDMarkdownDocument.WriteStep(AKind: TPsBDDStepKind;
  const ADescription: string);
var
  LIndent: string;
begin
  BeginWrite;
  // And and But continue the previous step, so they are nested under it
  if AKind in [skAnd, skBut] then
    LIndent := '  '
  else
    LIndent := '';
  AddText(Format(STEP_TEMPLATE, [LIndent, STEP_KEYWORDS[AKind],
    MarkdownText(ADescription, LIndent + '  ')]));
end;

procedure TPsBDDMarkdownDocument.WriteScenarioStatus(AStatus: TPsBDDScenarioStatus;
  const AMessage: string);
var
  LText: string;
begin
  BeginWrite;
  LText := Format(SCENARIO_STATUS_TEMPLATE, [SCENARIO_STATUS_NAMES[AStatus]]);
  if AMessage <> '' then
    LText := LText + ' - ' + MarkdownText(AMessage);
  EnsureBlankLine;
  AddText(LText);
end;

end.
