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

unit PsBDD.HTMLDocument;

{
  HTML implementation of IPsBDDDocument.

  The document is one HTML5 page with its own style sheet, so it opens in
  any browser and can be mailed or published as it is. The style follows the
  reader's light or dark setting. Like the Markdown document it is built in
  memory and written to disk by Close, and only when something was written
  to it.

  Feature
    The time the document was opened and the status of the feature follow
    the heading, then the description:

      <h1>Feature: Customer maintenance</h1>
      <p class="run"><strong>Run:</strong> 2026-10-25 14:03:12</p>
      <p class="feature-status"><strong>Status:</strong> In Development</p>
      <p class="description">As a clerk<br>
      I want to save a new customer</p>

  Scenario
    Each step is a paragraph. And and But are indented below the step they
    continue. The status follows the steps, green when passed and red when
    failed:

      <h2>Scenario: Customer can be saved</h2>
      <p class="step"><strong>Given</strong> a new customer</p>
      <p class="step nested"><strong>And</strong> an audit entry is written</p>
      <p class="status passed"><strong>Status:</strong> Passed</p>

  Stand alone document (StandAlone = True)
    The file is replaced. Features and scenarios are written as plain
    headings.

  Part of a larger document (StandAlone = False)
    The existing page is loaded by Open and the new content is added at the
    end of its body, in front of the marker

      <!-- BDD-CONTENT-END -->

    Features and scenarios are numbered, continuing from the numbers already
    in the page, and get the ids feature-<n> and scenario-<n>:

      <h1 id="feature-1">Feature 1: Customer maintenance</h1>
      <h2 id="scenario-1">Scenario 1: Customer can be saved</h2>

    A table of contents linking to them is kept between two markers, by
    default at the top of the body:

      <!-- BDD-TOC-START -->
      <nav class="toc">
      <h2>Table of Contents</h2>
      <ul>
      <li class="feature"><a href="#feature-1">Feature 1: ...</a></li>
      <li class="scenario"><a href="#scenario-1">Scenario 1: ...</a></li>
      </ul>
      </nav>
      <!-- BDD-TOC-END -->

    The markers are HTML comments, which browsers do not show. The block
    can be moved, it is found again by its markers. When the page is
    printed, or saved as PDF from the browser, the table of contents is on
    a page of its own.

    A new page starts with the preamble registered for it with
    TPsBDDRun.AddPreamble, when its file exists: the user's own HTML for
    the body, copied as it is into <div class="preamble">, above the table
    of contents. Printed, it is a cover page of its own. A page without the
    markers, for example one written by hand, gets them added in its body.

    TPsBDDRun.RunStart decides whether the first open of a test run adds to
    the existing page, or starts a new one.

  Every element is written on lines of its own, so the markers and the
  numbered headings are found again line by line.

  Text
    Titles, descriptions, requirements, steps and messages are escaped, so
    characters such as < and & are shown as typed. Multiline text keeps its
    line breaks.
}

interface

uses
  System.SysUtils, System.Classes,
  PsBDD.Framework;

type
  /// <summary>
  ///   Writes a BDD document as an HTML page. Create it with the path,
  ///   audience and mode of the document and add it to a feature document
  ///   writer, which opens and closes it.
  /// </summary>
  TPsBDDHTMLDocument = class(TInterfacedObject, IPsBDDDocument)
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
    procedure EnsureContentEnd;
    procedure EnsureToc;
    function BodyStart: Integer;
    function FindLine(const AText: string): Integer;
    function GetTarget: TPsBDDDocumentTarget;
    function HasToc: Boolean;
    function HeadingText(const ATag, AKind, ATitle: string;
      var ACounter: Integer; const ATocClass: string): string;
    function LastHeadingNumber(const ATag, AKind: string): Integer;
    procedure Save;
  public
    /// <summary>Creates an HTML document for the given target.</summary>
    /// <param name="APath">The path of the .html file.</param>
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
  System.IOUtils;

const
  STEP_KEYWORDS: array[TPsBDDStepKind] of string =
    ('Given', 'When', 'Then', 'And', 'But');

  FEATURE_STATUS_NAMES: array[TPsBDDFeatureStatus] of string =
    ('Proposed', 'In Development', 'Implemented', 'Accepted', 'Deprecated');

  SCENARIO_STATUS_NAMES: array[TPsBDDScenarioStatus] of string =
    ('Passed', 'Failed');

  // The class of the status paragraph, which colours it
  SCENARIO_STATUS_CLASSES: array[TPsBDDScenarioStatus] of string =
    ('passed', 'failed');

  // The time shown below the feature heading
  TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss';

  // HTML comments, which browsers do not show
  TOC_START_MARKER = '<!-- BDD-TOC-START -->';
  TOC_END_MARKER = '<!-- BDD-TOC-END -->';
  CONTENT_END_MARKER = '<!-- BDD-CONTENT-END -->';
  TOC_LIST_END = '</ul>';
  PREAMBLE_START = '<div class="preamble">';
  PREAMBLE_END = '</div>';

  FEATURE_KIND = 'Feature';
  SCENARIO_KIND = 'Scenario';
  FEATURE_TAG = 'h1';
  SCENARIO_TAG = 'h2';
  TOC_FEATURE_CLASS = ' class="feature"';
  TOC_SCENARIO_CLASS = ' class="scenario"';

  // %0 = tag, %1 = kind, %2 = title
  HEADING_TEMPLATE = '<%0:s>%1:s: %2:s</%0:s>';
  // %0 = tag, %1 = id prefix, %2 = number, %3 = kind, %4 = title
  NUMBERED_HEADING_TEMPLATE = '<%0:s id="%1:s%2:d">%3:s %2:d: %4:s</%0:s>';
  // %0 = class, %1 = id prefix, %2 = number, %3 = kind, %4 = title
  TOC_ENTRY_TEMPLATE = '<li%0:s><a href="#%1:s%2:d">%3:s %2:d: %4:s</a></li>';

  // %s = run time, status
  FEATURE_TEMPLATE = '''
    <p class="run"><strong>Run:</strong> %s</p>
    <p class="feature-status"><strong>Status:</strong> %s</p>
    ''';
  DESCRIPTION_TEMPLATE = '<p class="description">%s</p>';
  REQUIREMENT_TEMPLATE =
    '<blockquote class="requirement"><p><strong>%s:</strong> %s</p></blockquote>';
  REQUIREMENT_TEXT_TEMPLATE =
    '<blockquote class="requirement"><p>%s</p></blockquote>';
  // %s = class, keyword, text
  STEP_TEMPLATE = '<p class="%s"><strong>%s</strong> %s</p>';
  STEP_CLASS = 'step';
  NESTED_STEP_CLASS = 'step nested';
  // %s = class, status name
  SCENARIO_STATUS_TEMPLATE = '<p class="status %s"><strong>Status:</strong> %s';
  SCENARIO_STATUS_END = '</p>';
  LINE_BREAK = '<br>';

  // %s = start marker, end marker
  TOC_BLOCK_TEMPLATE = '''
    %s
    <nav class="toc">
    <h2>Table of Contents</h2>
    <ul>
    </ul>
    </nav>
    %s
    ''';

  // %s = title, style sheet, content end marker
  PAGE_TEMPLATE = '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>%s</title>
    <style>
    %s
    </style>
    </head>
    <body>
    %s
    </body>
    </html>
    ''';

  STYLE_SHEET = '''
    :root {
      color-scheme: light dark;
      --text: #1f2328; --muted: #59636e; --line: #d1d9e0; --quote: #f6f8fa;
      --passed: #1a7f37; --failed: #cf222e; --link: #0969da;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --text: #e6edf3; --muted: #9198a1; --line: #3d444d; --quote: #151b23;
        --passed: #3fb950; --failed: #f85149; --link: #4493f8;
      }
    }
    body {
      font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.5; color: var(--text); background: Canvas;
      max-width: 60rem; margin: 0 auto; padding: 1rem 1rem 3rem;
    }
    h1 {
      font-size: 1.6rem; margin: 2.5rem 0 .5rem;
      padding-bottom: .3rem; border-bottom: 1px solid var(--line);
    }
    h2 { font-size: 1.25rem; margin: 1.75rem 0 .5rem; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    .run, .feature-status { margin: .2rem 0; color: var(--muted); }
    .description { margin: 1rem 0; }
    .requirement {
      margin: 1rem 0; padding: .5rem 1rem;
      border-left: 4px solid var(--line); background: var(--quote);
    }
    .requirement p { margin: 0; }
    .step { margin: .2rem 0 .2rem 1rem; }
    .step.nested { margin-left: 2.5rem; }
    .status { margin: .75rem 0 0; font-weight: 600; }
    .status.passed { color: var(--passed); }
    .status.failed { color: var(--failed); }
    .toc ul { list-style: none; padding-left: 0; }
    .toc li { margin: .15rem 0; }
    .toc li.scenario { padding-left: 1.5rem; }
    .preamble { margin-bottom: 2rem; }
    @media print {
      body { max-width: none; padding: 0; }
      .preamble, .toc { break-after: page; }
      h1, h2 { break-after: avoid; }
    }
    ''';

{ Text helpers }

// Escapes the characters that have a meaning in HTML.
function EscapeHtml(const AText: string): string;
begin
  Result := AText
    .Replace('&', '&amp;')
    .Replace('<', '&lt;')
    .Replace('>', '&gt;')
    .Replace('"', '&quot;')
    .Replace('''', '&#39;');
end;

// Escapes AText and keeps its line breaks: every line but the last ends with
// <br> and stays on a line of its own.
function HtmlText(const AText: string): string;
var
  LLines: TStringList;
  I: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    for I := 0 to LLines.Count - 1 do
    begin
      if I > 0 then
        Result := Result + LINE_BREAK + sLineBreak;
      Result := Result + EscapeHtml(Trim(LLines[I]));
    end;
  finally
    LLines.Free;
  end;
end;

{ TPsBDDHTMLDocument }

constructor TPsBDDHTMLDocument.Create(const APath: string;
  AAudience: TPsBDDAudience; AStandAlone: Boolean);
begin
  inherited Create;
  FTarget.Path := APath;
  FTarget.Audience := AAudience;
  FTarget.StandAlone := AStandAlone;
  FLines := TStringList.Create;
end;

destructor TPsBDDHTMLDocument.Destroy;
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

function TPsBDDHTMLDocument.GetTarget: TPsBDDDocumentTarget;
begin
  Result := FTarget;
end;

function TPsBDDHTMLDocument.HasToc: Boolean;
begin
  Result := not FTarget.StandAlone;
end;

procedure TPsBDDHTMLDocument.CheckOpen;
begin
  if not FIsOpen then
    raise EInvalidOperation.CreateFmt(
      'The BDD document "%s" must be opened before it is written to.',
      [FTarget.Path]);
end;

procedure TPsBDDHTMLDocument.BeginWrite;
begin
  CheckOpen;
  if HasToc then
    EnsureToc;
  FModified := True;
end;

function TPsBDDHTMLDocument.FindLine(const AText: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FLines.Count - 1 do
    if SameText(Trim(FLines[I]), AText) then
      Exit(I);
  Result := -1;
end;

// The index of the first line inside the body, 0 when there is no body tag
function TPsBDDHTMLDocument.BodyStart: Integer;
var
  I: Integer;
begin
  for I := 0 to FLines.Count - 1 do
    if Trim(FLines[I]).StartsWith('<body', True) then
      Exit(I + 1);
  Result := 0;
end;

// Adds the lines of AText in front of the content end marker
procedure TPsBDDHTMLDocument.AddText(const AText: string);
var
  LLines: TStringList;
  LEnd: Integer;
  LLine: string;
begin
  LLines := TStringList.Create;
  try
    // Splits on CRLF, LF and CR so the line breaks are always consistent
    LLines.Text := AText;
    LEnd := FindLine(CONTENT_END_MARKER);
    for LLine in LLines do
    begin
      FLines.Insert(LEnd, LLine);
      Inc(LEnd);
    end;
  finally
    LLines.Free;
  end;
end;

// A page that has no content end marker, for example one written by hand,
// gets it at the end of its body
procedure TPsBDDHTMLDocument.EnsureContentEnd;
var
  LBodyEnd: Integer;
begin
  if FindLine(CONTENT_END_MARKER) >= 0 then
    Exit;
  LBodyEnd := FindLine('</body>');
  if LBodyEnd < 0 then
    LBodyEnd := FLines.Count;
  FLines.Insert(LBodyEnd, CONTENT_END_MARKER);
end;

procedure TPsBDDHTMLDocument.EnsureToc;
var
  LBlock: TStringList;
  I: Integer;
begin
  if FindLine(TOC_END_MARKER) >= 0 then
    Exit;

  // No table of contents yet: put one at the top of the body
  LBlock := TStringList.Create;
  try
    LBlock.Text := Format(TOC_BLOCK_TEMPLATE, [TOC_START_MARKER, TOC_END_MARKER]);
    for I := LBlock.Count - 1 downto 0 do
      FLines.Insert(BodyStart, LBlock[I]);
  finally
    LBlock.Free;
  end;
end;

procedure TPsBDDHTMLDocument.AddTocEntry(const AEntry: string);
var
  LEnd: Integer;
begin
  // Entries go in front of the end of the list, so they stay in the order
  // written. Without the list, in front of the end marker.
  LEnd := FindLine(TOC_END_MARKER);
  while (LEnd > 0) and not SameText(Trim(FLines[LEnd - 1]), TOC_LIST_END)
    and not SameText(Trim(FLines[LEnd - 1]), TOC_START_MARKER) do
    Dec(LEnd);
  if (LEnd > 0) and SameText(Trim(FLines[LEnd - 1]), TOC_LIST_END) then
    Dec(LEnd)
  else
    LEnd := FindLine(TOC_END_MARKER);
  FLines.Insert(LEnd, AEntry);
end;

// Returns the highest number of the headings <ATag id="<kind>-<n>">, or 0
// when there are none.
function TPsBDDHTMLDocument.LastHeadingNumber(const ATag, AKind: string): Integer;
var
  LStartText, LLine: string;
  LStart, LEnd, LNumber: Integer;
begin
  Result := 0;
  LStartText := Format('<%s id="%s-', [ATag, AKind.ToLower]);
  for LLine in FLines do
  begin
    if not LLine.StartsWith(LStartText, True) then
      Continue;
    LStart := Length(LStartText) + 1;
    LEnd := LStart;
    while (LEnd <= Length(LLine)) and CharInSet(LLine[LEnd], ['0'..'9']) do
      Inc(LEnd);
    if TryStrToInt(Copy(LLine, LStart, LEnd - LStart), LNumber)
      and (LNumber > Result) then
      Result := LNumber;
  end;
end;

// Returns the heading. When the document has a table of contents it also
// numbers the heading, gives it an id and adds its table of contents entry.
function TPsBDDHTMLDocument.HeadingText(const ATag, AKind, ATitle: string;
  var ACounter: Integer; const ATocClass: string): string;
var
  LIdPrefix: string;
begin
  if not HasToc then
    Exit(Format(HEADING_TEMPLATE, [ATag, AKind, EscapeHtml(ATitle)]));

  Inc(ACounter);
  LIdPrefix := AKind.ToLower + '-';
  Result := Format(NUMBERED_HEADING_TEMPLATE,
    [ATag, LIdPrefix, ACounter, AKind, EscapeHtml(ATitle)]);
  AddTocEntry(Format(TOC_ENTRY_TEMPLATE,
    [ATocClass, LIdPrefix, ACounter, AKind, EscapeHtml(ATitle)]));
end;

// A new page that is added to starts with its preamble, when one is
// registered and written, and the table of contents below it. The preamble
// is the user's own HTML, copied as it is.
procedure TPsBDDHTMLDocument.AddPreamble;
var
  LPreamble: TArray<string>;
  LToc: TStringList;
  LIndex: Integer;
  LLine: string;

  procedure Insert(const ALine: string);
  begin
    FLines.Insert(LIndex, ALine);
    Inc(LIndex);
  end;

begin
  LPreamble := TPsBDDRun.PreambleFor(FTarget.Path);
  if Length(LPreamble) = 0 then
    Exit;
  LIndex := BodyStart;
  Insert(PREAMBLE_START);
  for LLine in LPreamble do
    Insert(LLine);
  Insert(PREAMBLE_END);
  LToc := TStringList.Create;
  try
    LToc.Text := Format(TOC_BLOCK_TEMPLATE, [TOC_START_MARKER, TOC_END_MARKER]);
    for LLine in LToc do
      Insert(LLine);
  finally
    LToc.Free;
  end;
end;

procedure TPsBDDHTMLDocument.Open;
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
      FLines.LoadFromFile(FTarget.Path, TEncoding.UTF8);
  end;

  // A new page. Its title is the file name.
  if FLines.Count = 0 then
  begin
    FLines.Text := Format(PAGE_TEMPLATE, [
      EscapeHtml(TPath.GetFileNameWithoutExtension(FTarget.Path)),
      STYLE_SHEET.TrimRight, CONTENT_END_MARKER]);
    if not FTarget.StandAlone then
      AddPreamble;
  end;
  EnsureContentEnd;

  // Continue the numbers of the features and scenarios already in the
  // document
  FFeatureCount := LastHeadingNumber(FEATURE_TAG, FEATURE_KIND);
  FScenarioCount := LastHeadingNumber(SCENARIO_TAG, SCENARIO_KIND);
  FFeatureWritten := False;
  FModified := False;
  FOpenedAt := Now;
  FIsOpen := True;
end;

procedure TPsBDDHTMLDocument.Save;
var
  LDirectory: string;
  LEncoding: TUTF8Encoding;
begin
  LDirectory := TPath.GetDirectoryName(FTarget.Path);
  if LDirectory <> '' then
    TDirectory.CreateDirectory(LDirectory);

  // UTF-8 without a byte order mark, as the page's charset says
  LEncoding := TUTF8Encoding.Create(False);
  try
    FLines.SaveToFile(FTarget.Path, LEncoding);
  finally
    LEncoding.Free;
  end;
end;

procedure TPsBDDHTMLDocument.Close;
begin
  if not FIsOpen then
    Exit;
  if FModified then
    Save;
  FModified := False;
  FIsOpen := False;
end;

procedure TPsBDDHTMLDocument.WriteFeature(const ATitle, ADescription: string;
  AStatus: TPsBDDFeatureStatus);
begin
  BeginWrite;
  AddText(HeadingText(FEATURE_TAG, FEATURE_KIND, ATitle, FFeatureCount,
    TOC_FEATURE_CLASS));
  FFeatureWritten := True;
  // The run time makes each run of the feature a dated entry in the document
  AddText(Format(FEATURE_TEMPLATE, [
    FormatDateTime(TIMESTAMP_FORMAT, FOpenedAt, TFormatSettings.Invariant),
    FEATURE_STATUS_NAMES[AStatus]]));
  if Trim(ADescription) <> '' then
    AddText(Format(DESCRIPTION_TEMPLATE, [HtmlText(ADescription)]));
end;

procedure TPsBDDHTMLDocument.WriteRequirement(const AReference, AText: string);
begin
  BeginWrite;
  if AReference = '' then
    AddText(Format(REQUIREMENT_TEXT_TEMPLATE, [HtmlText(AText)]))
  else
    AddText(Format(REQUIREMENT_TEMPLATE,
      [EscapeHtml(AReference), HtmlText(AText)]));
end;

procedure TPsBDDHTMLDocument.WriteScenario(const ATitle: string);
var
  LTocClass: string;
begin
  BeginWrite;
  // Scenarios are indented below their feature in the table of contents
  if FFeatureWritten then
    LTocClass := TOC_SCENARIO_CLASS
  else
    LTocClass := '';
  AddText(HeadingText(SCENARIO_TAG, SCENARIO_KIND, ATitle, FScenarioCount,
    LTocClass));
end;

procedure TPsBDDHTMLDocument.WriteStep(AKind: TPsBDDStepKind;
  const ADescription: string);
var
  LClass: string;
begin
  BeginWrite;
  // And and But continue the previous step, so they are indented below it
  if AKind in [skAnd, skBut] then
    LClass := NESTED_STEP_CLASS
  else
    LClass := STEP_CLASS;
  AddText(Format(STEP_TEMPLATE,
    [LClass, STEP_KEYWORDS[AKind], HtmlText(ADescription)]));
end;

procedure TPsBDDHTMLDocument.WriteScenarioStatus(AStatus: TPsBDDScenarioStatus;
  const AMessage: string);
var
  LText: string;
begin
  BeginWrite;
  LText := Format(SCENARIO_STATUS_TEMPLATE,
    [SCENARIO_STATUS_CLASSES[AStatus], SCENARIO_STATUS_NAMES[AStatus]]);
  if AMessage <> '' then
    LText := LText + ' - ' + HtmlText(AMessage);
  AddText(LText + SCENARIO_STATUS_END);
end;

end.
