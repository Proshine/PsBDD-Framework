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

unit PsBDD.TMSPDF;

{
  Optional add-on: converts a Markdown document written by
  TPsBDDMarkdownDocument to PDF, using the PDF library of TMS FNC Core
  (VCL.TMSFNCPDFLib). Only projects that use this unit need TMS FNC Core.

  The conversion runs when the test run is finished, so a combined Markdown
  document holds every feature of the run. Register it in the project file
  and perform it after the runner:

    uses
      PsBDD.Framework, PsBDD.TMSPDF;

    begin
      TPsBDDRun.AddConversion(TPsBDDTMSPDFConversion.Create(
        'C:\Docs\AllFeatures.md', 'C:\Docs\AllFeatures.pdf'));
      Runner := TDUnitX.CreateRunner;
      ...
      try
        Results := Runner.Execute;
      finally
        TPsBDDRun.PerformConversions;
      end;

  The PDF
    - A header with the title on every page, and the page number in the
      footer. The title is also in the document information, with the
      author.
    - Features and scenarios as headings, the run time and feature status
      in grey, requirements in a shaded box, steps indented (And and But
      further), the scenario status green when passed and red when failed.
    - A combined Markdown document (one with a table of contents) starts
      with a table of contents page. Each entry is a link to the page of
      its heading.
    - Anything above the table of contents, the preamble, is drawn first
      on a cover page of its own, and is not in the contents.
    - Text the Markdown reader doesn't recognise, for example added by
      hand, is drawn as a plain paragraph. Simple hand-written Markdown, as
      in a preamble, keeps its **bold**, *italic*, `code` and list items.

  The pages are laid out twice: first in memory to find the page of every
  heading, then to the file with the table of contents pointing at those
  pages. Both passes lay out the same content, so the pages match.
}

interface

uses
  System.SysUtils,
  PsBDD.Framework;

type
  /// <summary>
  ///   Converts a Markdown document written by TPsBDDMarkdownDocument to
  ///   PDF with TMS FNC Core. Register it with TPsBDDRun.AddConversion.
  /// </summary>
  TPsBDDTMSPDFConversion = class(TInterfacedObject, IPsBDDConversion)
  private
    FMarkdownPath: string;
    FPdfPath: string;
    FTitle: string;
    FAuthor: string;
    function GetDescription: string;
  public
    /// <summary>Creates the conversion of one Markdown document.</summary>
    /// <param name="AMarkdownPath">The Markdown document to convert.</param>
    /// <param name="APdfPath">
    ///   The PDF to write. It is replaced. Missing folders are created.
    /// </param>
    /// <param name="ATitle">
    ///   The title in the page header and the document information. Empty
    ///   uses the name of the Markdown file.
    /// </param>
    /// <param name="AAuthor">The author in the document information.</param>
    constructor Create(const AMarkdownPath, APdfPath: string;
      const ATitle: string = ''; const AAuthor: string = '');

    /// <summary>
    ///   Writes the PDF. Raises EFileNotFoundException when the Markdown
    ///   document does not exist.
    /// </summary>
    procedure Convert;

    property Description: string read GetDescription;
  end;

implementation

uses
  System.Types, System.IOUtils, System.Generics.Collections,
  VCL.TMSFNCPDFLib, VCL.TMSFNCPDFGraphicsLib, VCL.TMSFNCGraphicsTypes;

const
  // Lines of the Markdown that PsBDD writes
  TOC_START_MARKER = '[BDD-TOC-START]: #';
  TOC_END_MARKER = '[BDD-TOC-END]: #';
  TOC_HEADING = 'Table of Contents';
  HEADING1_START = '# ';
  HEADING2_START = '## ';
  RUN_START = '**Run:** ';
  STATUS_START = '**Status:** ';
  PASSED = 'Passed';
  FAILED = 'Failed';
  QUOTE_START = '>';
  MARKDOWN_LINE_BREAK = '  ';
  // * **Given** text, indented for And and But
  STEP_PATTERN_START = '* **';
  STEP_KEYWORD_END = '** ';
  REFERENCE_END = ':** ';
  STEP_KEYWORDS: array[0..4] of string = ('Given', 'When', 'Then', 'And', 'But');
  // List items of a hand-written preamble: '* item', '- item' or '+ item'
  BULLET_STARTS: array[0..2] of string = ('* ', '- ', '+ ');
  BULLET = #$2022' ';
  CODE_FONT_HTML = '<font face="Courier New">';
  ESCAPED_CHARS = ['\', '`', '*', '_', '[', ']', '<', '>', '|', '#'];

  // Page layout, in points
  MARGIN_TOP = 72;
  MARGIN_BOTTOM = 72;
  MARGIN_SIDE = 54;
  STEP_INDENT = 14;
  NESTED_STEP_INDENT = 34;
  REQUIREMENT_PADDING = 8;
  REQUIREMENT_BAR = 3;
  TOC_SCENARIO_INDENT = 18;
  TOC_LINE_HEIGHT = 18;
  // Space in front of each kind of block
  SPACE_HEADING1 = 22;
  SPACE_HEADING2 = 14;
  SPACE_PARAGRAPH = 6;
  SPACE_STEP = 2;
  SPACE_STATUS = 6;
  // Room needed below a heading, so it is never alone at the bottom of a page
  KEEP_WITH_HEADING = 40;

  FONT_NAME = 'Arial';
  FONT_SIZE = 11;
  HEADER_FONT_SIZE = 9;
  PAGE_NUMBER_FORMAT = 'Page %d';
  CREATOR = 'PsBDD';

  // Colours for the HTML of the text, as in PsBDD.HTMLDocument
  HTML_MUTED = '#59636e';
  HTML_PASSED = '#1a7f37';
  HTML_FAILED = '#cf222e';
  // The same colours as TColor values ($00BBGGRR) for drawing
  COLOR_TEXT = $0028231F;
  COLOR_MUTED = $006E6359;
  COLOR_LINE = $00E0D9D1;
  COLOR_QUOTE = $00FAF8F6;
  COLOR_LINK = $00DA6909;

  HEADING1_HTML = '<font size="18"><b>%s</b></font>';
  HEADING2_HTML = '<font size="14"><b>%s</b></font>';
  MUTED_HTML = '<font color="' + HTML_MUTED + '">%s</font>';
  LABEL_HTML = '<b>%s</b> %s';
  STEP_HTML = '<b>%s</b> %s';
  STATUS_HTML = '<font color="%s"><b>Status: %s</b></font>';
  LINE_BREAK_HTML = '<br>';

type
  TBlockKind = (bkHeading1, bkHeading2, bkRun, bkFeatureStatus, bkParagraph,
    bkRequirement, bkStep, bkNestedStep, bkScenarioStatus, bkBullet,
    bkNestedBullet);

  /// <summary>One block of the Markdown document.</summary>
  TBlock = record
    Kind: TBlockKind;
    /// <summary>The text, as TMS HTML: escaped, lines joined with &lt;br&gt;.</summary>
    Html: string;
    /// <summary>The text of a heading without markup, for the table of contents.</summary>
    Plain: string;
    /// <summary>The step keyword or the requirement reference.</summary>
    Prefix: string;
    /// <summary>For a scenario status: True when passed.</summary>
    Passed: Boolean;
  end;

  /// <summary>The blocks of a Markdown document written by PsBDD.</summary>
  TMarkdownContent = record
    Blocks: TArray<TBlock>;
    /// <summary>True when the document has a table of contents.</summary>
    HasToc: Boolean;
    /// <summary>
    ///   The number of blocks above the table of contents, the preamble.
    ///   They are drawn on a cover page and are not in the contents.
    /// </summary>
    CoverCount: Integer;
  end;

  /// <summary>
  ///   Reads the Markdown that TPsBDDMarkdownDocument writes into blocks.
  /// </summary>
  TMarkdownReader = class
  private
    FBlocks: TList<TBlock>;
    FHasToc: Boolean;
    FCoverCount: Integer;
    FOpen: Integer;           // the block that following lines continue, or -1
    FBreakBefore: Boolean;    // the previous line ended with a line break
    procedure Add(AKind: TBlockKind; const AText: string;
      const APrefix: string = ''; ACanContinue: Boolean = True;
      APassed: Boolean = False);
    procedure AppendLine(const AText: string);
    procedure ReadLine(const ALine: string);
    function ReadStep(const ALine: string): Boolean;
    function ReadBullet(const ALine: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Read(const ALines: TArray<string>): TMarkdownContent;
  end;

  /// <summary>
  ///   Draws the blocks on the pages of one PDF and records the page of
  ///   every heading.
  /// </summary>
  TPdfRenderer = class
  private
    FPdf: TTMSFNCPDFLib;
    FContent: TMarkdownContent;
    FTitle: string;
    FAuthor: string;
    FTargets: TArray<Integer>;
    FHeadingPages: TList<Integer>;
    FTop: Single;
    FBottom: Single;
    FLeft: Single;
    FRight: Single;
    FY: Single;
    FDrawingCover: Boolean;
    function Graphics: ITMSFNCCustomPDFGraphicsLib;
    procedure NewPage;
    function Place(const AHtml: string; AIndent, ASpaceBefore,
      AKeepAfter: Single): TRectF;
    procedure DrawHtml(const AHtml: string; AIndent, ASpaceBefore: Single;
      AKeepAfter: Single = 0);
    procedure DrawBlock(const ABlock: TBlock);
    procedure DrawHeading(const ABlock: TBlock);
    procedure DrawRequirement(const ABlock: TBlock);
    procedure DrawToc;
    procedure SetUpPage;
  public
    constructor Create(const AContent: TMarkdownContent;
      const ATitle, AAuthor: string; const ATargets: TArray<Integer>);
    destructor Destroy; override;
    /// <summary>
    ///   Draws the document to AFileName, or in memory when it is empty, and
    ///   returns the page index of every heading in order.
    /// </summary>
    function Render(const AFileName: string): TArray<Integer>;
  end;

{ Text helpers }

// Escapes the characters that TMS HTML gives a meaning
function EscapeHtml(const AText: string): string;
begin
  Result := AText
    .Replace('&', '&amp;')
    .Replace('<', '&lt;')
    .Replace('>', '&gt;')
    .Replace('"', '&quot;');
end;

// A line of Markdown text as TMS HTML. PsBDD escapes every character that
// would be formatting, so what is left unescaped is formatting written by
// hand, for example in a preamble: **bold**, *italic* and `code`. Tags still
// open at the end of the line are closed.
function LineHtml(const ALine: string): string;
var
  LText: string;
  LBold, LItalic, LCode: Boolean;
  I: Integer;
begin
  LText := Trim(ALine);
  Result := '';
  LBold := False;
  LItalic := False;
  LCode := False;
  I := 1;
  while I <= Length(LText) do
  begin
    if (LText[I] = '\') and (I < Length(LText))
      and CharInSet(LText[I + 1], ESCAPED_CHARS) then
    begin
      Result := Result + EscapeHtml(LText[I + 1]);
      Inc(I, 2);
      Continue;
    end;
    if LCode and (LText[I] <> '`') then
      Result := Result + EscapeHtml(LText[I])
    else if LText[I] = '`' then
    begin
      if LCode then
        Result := Result + '</font>'
      else
        Result := Result + CODE_FONT_HTML;
      LCode := not LCode;
    end
    else if (LText[I] = '*') and (I < Length(LText)) and (LText[I + 1] = '*') then
    begin
      if LBold then
        Result := Result + '</b>'
      else
        Result := Result + '<b>';
      LBold := not LBold;
      Inc(I);
    end
    else if LText[I] = '*' then
    begin
      if LItalic then
        Result := Result + '</i>'
      else
        Result := Result + '<i>';
      LItalic := not LItalic;
    end
    else
      Result := Result + EscapeHtml(LText[I]);
    Inc(I);
  end;
  if LCode then
    Result := Result + '</font>';
  if LItalic then
    Result := Result + '</i>';
  if LBold then
    Result := Result + '</b>';
end;

// A line of Markdown text without its formatting, for the table of contents
function PlainText(const ALine: string): string;
var
  LText: string;
  I: Integer;
begin
  LText := Trim(ALine);
  Result := '';
  I := 1;
  while I <= Length(LText) do
  begin
    if (LText[I] = '\') and (I < Length(LText))
      and CharInSet(LText[I + 1], ESCAPED_CHARS) then
    begin
      Result := Result + LText[I + 1];
      Inc(I, 2);
      Continue;
    end;
    if not CharInSet(LText[I], ['*', '`']) then
      Result := Result + LText[I];
    Inc(I);
  end;
end;

function IsStepKeyword(const AText: string): Boolean;
var
  LKeyword: string;
begin
  for LKeyword in STEP_KEYWORDS do
    if AText = LKeyword then
      Exit(True);
  Result := False;
end;

{ TMarkdownReader }

constructor TMarkdownReader.Create;
begin
  inherited Create;
  FBlocks := TList<TBlock>.Create;
end;

destructor TMarkdownReader.Destroy;
begin
  FBlocks.Free;
  inherited;
end;

procedure TMarkdownReader.Add(AKind: TBlockKind; const AText: string;
  const APrefix: string; ACanContinue: Boolean; APassed: Boolean);
var
  LBlock: TBlock;
begin
  LBlock := Default(TBlock);
  LBlock.Kind := AKind;
  LBlock.Html := LineHtml(AText);
  LBlock.Plain := PlainText(AText);
  LBlock.Prefix := APrefix;
  LBlock.Passed := APassed;
  FBlocks.Add(LBlock);
  if ACanContinue then
    FOpen := FBlocks.Count - 1
  else
    FOpen := -1;
end;

// Adds a line to the open block: on a new line after a Markdown line break,
// otherwise as the same paragraph
procedure TMarkdownReader.AppendLine(const AText: string);
var
  LBlock: TBlock;
begin
  LBlock := FBlocks[FOpen];
  if FBreakBefore then
    LBlock.Html := LBlock.Html + LINE_BREAK_HTML + LineHtml(AText)
  else
    LBlock.Html := LBlock.Html + ' ' + LineHtml(AText);
  FBlocks[FOpen] := LBlock;
end;

// Reads '* **Given** text', or indented '  * **And** text'
function TMarkdownReader.ReadStep(const ALine: string): Boolean;
var
  LTrimmed, LKeyword: string;
  LEnd: Integer;
begin
  LTrimmed := TrimLeft(ALine);
  Result := LTrimmed.StartsWith(STEP_PATTERN_START);
  if not Result then
    Exit;
  LEnd := Pos(STEP_KEYWORD_END, LTrimmed, Length(STEP_PATTERN_START) + 1);
  if LEnd = 0 then
    Exit(False);
  LKeyword := Copy(LTrimmed, Length(STEP_PATTERN_START) + 1,
    LEnd - Length(STEP_PATTERN_START) - 1);
  // A list item that starts with bold text, in a preamble, is not a step
  if not IsStepKeyword(LKeyword) then
    Exit(False);
  if Length(LTrimmed) < Length(ALine) then
    Add(bkNestedStep, Copy(LTrimmed, LEnd + Length(STEP_KEYWORD_END)), LKeyword)
  else
    Add(bkStep, Copy(LTrimmed, LEnd + Length(STEP_KEYWORD_END)), LKeyword);
end;

// Reads a list item written by hand, for example in a preamble. Indented
// items are nested.
function TMarkdownReader.ReadBullet(const ALine: string): Boolean;
var
  LTrimmed, LStart: string;
begin
  LTrimmed := TrimLeft(ALine);
  for LStart in BULLET_STARTS do
    if LTrimmed.StartsWith(LStart) then
    begin
      if Length(LTrimmed) < Length(ALine) then
        Add(bkNestedBullet, Copy(LTrimmed, Length(LStart) + 1))
      else
        Add(bkBullet, Copy(LTrimmed, Length(LStart) + 1));
      Exit(True);
    end;
  Result := False;
end;

procedure TMarkdownReader.ReadLine(const ALine: string);
var
  LTrimmed, LText, LReference: string;
  LEnd: Integer;
begin
  LTrimmed := Trim(ALine);

  if LTrimmed = '' then
  begin
    FOpen := -1;
    Exit;
  end;

  if ALine.StartsWith(HEADING2_START) then
    Add(bkHeading2, Copy(ALine, Length(HEADING2_START) + 1), '', False)
  else if ALine.StartsWith(HEADING1_START) then
    Add(bkHeading1, Copy(ALine, Length(HEADING1_START) + 1), '', False)
  else if ALine.StartsWith(RUN_START) then
    Add(bkRun, Copy(ALine, Length(RUN_START) + 1), '', False)
  else if ALine.StartsWith(STATUS_START) then
  begin
    LText := Copy(ALine, Length(STATUS_START) + 1);
    // A scenario is passed or failed, a feature has a life cycle status
    if LText.StartsWith(PASSED) or LText.StartsWith(FAILED) then
      Add(bkScenarioStatus, LText, '', True, LText.StartsWith(PASSED))
    else
      Add(bkFeatureStatus, LText, '', False);
  end
  else if LTrimmed.StartsWith(QUOTE_START) then
  begin
    LText := TrimLeft(Copy(LTrimmed, Length(QUOTE_START) + 1));
    if (FOpen >= 0) and (FBlocks[FOpen].Kind = bkRequirement) then
      AppendLine(LText)
    else
    begin
      // > **REQ#014:** text, or > text without a reference
      LReference := '';
      LEnd := Pos(REFERENCE_END, LText);
      if LText.StartsWith('**') and (LEnd > 0) then
      begin
        LReference := LineHtml(Copy(LText, 3, LEnd - 3));
        LText := Copy(LText, LEnd + Length(REFERENCE_END));
      end;
      Add(bkRequirement, LText, LReference);
    end;
  end
  else if not ReadStep(ALine) and not ReadBullet(ALine) then
  begin
    if FOpen >= 0 then
      AppendLine(LTrimmed)
    else
      Add(bkParagraph, LTrimmed);
  end;

  FBreakBefore := ALine.EndsWith(MARKDOWN_LINE_BREAK);
end;

function TMarkdownReader.Read(const ALines: TArray<string>): TMarkdownContent;
var
  LLine: string;
  LInToc: Boolean;
begin
  FBlocks.Clear;
  FHasToc := False;
  FCoverCount := 0;
  FOpen := -1;
  FBreakBefore := False;
  LInToc := False;

  for LLine in ALines do
  begin
    // The table of contents is drawn again from the headings, with links
    if Trim(LLine) = TOC_START_MARKER then
    begin
      LInToc := True;
      FHasToc := True;
      if (FBlocks.Count > 0) and (FBlocks.Last.Kind = bkHeading1)
        and (FBlocks.Last.Plain = TOC_HEADING) then
        FBlocks.Delete(FBlocks.Count - 1);
      // What comes before the table of contents is the preamble
      FCoverCount := FBlocks.Count;
      Continue;
    end;
    if LInToc then
    begin
      if Trim(LLine) = TOC_END_MARKER then
      begin
        LInToc := False;
        FOpen := -1;
      end;
      Continue;
    end;
    ReadLine(LLine);
  end;

  Result.Blocks := FBlocks.ToArray;
  Result.HasToc := FHasToc;
  Result.CoverCount := FCoverCount;
end;

{ TPdfRenderer }

constructor TPdfRenderer.Create(const AContent: TMarkdownContent;
  const ATitle, AAuthor: string; const ATargets: TArray<Integer>);
begin
  inherited Create;
  FContent := AContent;
  FTitle := ATitle;
  FAuthor := AAuthor;
  FTargets := ATargets;
  FHeadingPages := TList<Integer>.Create;
end;

destructor TPdfRenderer.Destroy;
begin
  FHeadingPages.Free;
  inherited;
end;

function TPdfRenderer.Graphics: ITMSFNCCustomPDFGraphicsLib;
begin
  Result := FPdf.Graphics;
end;

procedure TPdfRenderer.SetUpPage;
begin
  Graphics.Font.Name := FONT_NAME;
  Graphics.Font.SizeNoScale := FONT_SIZE;
  Graphics.Font.Color := COLOR_TEXT;
  Graphics.URLFont.Name := FONT_NAME;
  Graphics.URLFont.SizeNoScale := FONT_SIZE;
  Graphics.URLFont.Color := COLOR_LINK;
end;

procedure TPdfRenderer.NewPage;
begin
  FPdf.NewPage;
  SetUpPage;
  FY := FTop;
end;

// Reserves room for AHtml below the previous block, on a new page when it
// doesn't fit, and returns its rectangle. AKeepAfter is room needed below
// it, so a heading moves to the next page with its first lines.
function TPdfRenderer.Place(const AHtml: string; AIndent, ASpaceBefore,
  AKeepAfter: Single): TRectF;
var
  LHeight: Single;
begin
  if FY > FTop then
    FY := FY + ASpaceBefore;
  LHeight := Graphics.CalculateHTMLText(AHtml,
    RectF(FLeft + AIndent, FY, FRight, FY + 10000)).Height;
  if (FY > FTop) and (FY + LHeight + AKeepAfter > FBottom) then
    NewPage;
  Result := RectF(FLeft + AIndent, FY, FRight, FY + LHeight);
  FY := FY + LHeight;
end;

procedure TPdfRenderer.DrawHtml(const AHtml: string; AIndent,
  ASpaceBefore: Single; AKeepAfter: Single);
begin
  Graphics.DrawHTMLText(AHtml, Place(AHtml, AIndent, ASpaceBefore, AKeepAfter));
end;

procedure TPdfRenderer.DrawHeading(const ABlock: TBlock);
var
  LRect: TRectF;
begin
  if ABlock.Kind = bkHeading1 then
  begin
    LRect := Place(Format(HEADING1_HTML, [ABlock.Html]), 0, SPACE_HEADING1,
      KEEP_WITH_HEADING);
    Graphics.DrawHTMLText(Format(HEADING1_HTML, [ABlock.Html]), LRect);
    // A rule below the feature heading
    Graphics.Stroke.Kind := gskSolid;
    Graphics.Stroke.Color := COLOR_LINE;
    Graphics.Stroke.Width := 1;
    Graphics.DrawLine(PointF(FLeft, FY + 3), PointF(FRight, FY + 3));
    FY := FY + 6;
  end
  else
  begin
    LRect := Place(Format(HEADING2_HTML, [ABlock.Html]), 0, SPACE_HEADING2,
      KEEP_WITH_HEADING);
    Graphics.DrawHTMLText(Format(HEADING2_HTML, [ABlock.Html]), LRect);
  end;
  // The headings of the preamble are not in the table of contents
  if not FDrawingCover then
    FHeadingPages.Add(FPdf.GetPageIndex);
end;

procedure TPdfRenderer.DrawRequirement(const ABlock: TBlock);
var
  LHtml: string;
  LRect: TRectF;
begin
  if ABlock.Prefix = '' then
    LHtml := ABlock.Html
  else
    LHtml := Format(LABEL_HTML, [ABlock.Prefix + ':', ABlock.Html]);

  // The text is placed inside the padding, then the box is drawn behind it
  LRect := Place(LHtml, REQUIREMENT_PADDING + REQUIREMENT_BAR,
    SPACE_PARAGRAPH + REQUIREMENT_PADDING, REQUIREMENT_PADDING);
  Graphics.Stroke.Kind := gskNone;
  Graphics.Fill.Kind := gfkSolid;
  Graphics.Fill.Color := COLOR_QUOTE;
  Graphics.DrawRectangle(RectF(FLeft, LRect.Top - REQUIREMENT_PADDING / 2,
    FRight, LRect.Bottom + REQUIREMENT_PADDING / 2));
  Graphics.Fill.Color := COLOR_LINE;
  Graphics.DrawRectangle(RectF(FLeft, LRect.Top - REQUIREMENT_PADDING / 2,
    FLeft + REQUIREMENT_BAR, LRect.Bottom + REQUIREMENT_PADDING / 2));
  Graphics.Fill.Kind := gfkNone;
  LRect.Right := LRect.Right - REQUIREMENT_PADDING;
  Graphics.DrawHTMLText(LHtml, LRect);
  FY := FY + REQUIREMENT_PADDING / 2;
end;

procedure TPdfRenderer.DrawBlock(const ABlock: TBlock);
const
  STATUS_COLORS: array[Boolean] of string = (HTML_FAILED, HTML_PASSED);
begin
  case ABlock.Kind of
    bkHeading1, bkHeading2:
      DrawHeading(ABlock);
    bkRun:
      DrawHtml(Format(MUTED_HTML, [Format(LABEL_HTML, ['Run:', ABlock.Html])]),
        0, SPACE_STEP);
    bkFeatureStatus:
      DrawHtml(Format(MUTED_HTML, [Format(LABEL_HTML, ['Status:', ABlock.Html])]),
        0, SPACE_STEP);
    bkParagraph:
      DrawHtml(ABlock.Html, 0, SPACE_PARAGRAPH);
    bkRequirement:
      DrawRequirement(ABlock);
    bkStep:
      DrawHtml(Format(STEP_HTML, [ABlock.Prefix, ABlock.Html]), STEP_INDENT,
        SPACE_STEP);
    bkNestedStep:
      DrawHtml(Format(STEP_HTML, [ABlock.Prefix, ABlock.Html]),
        NESTED_STEP_INDENT, SPACE_STEP);
    bkScenarioStatus:
      DrawHtml(Format(STATUS_HTML, [STATUS_COLORS[ABlock.Passed], ABlock.Html]),
        0, SPACE_STATUS);
    bkBullet:
      DrawHtml(BULLET + ABlock.Html, STEP_INDENT, SPACE_STEP);
    bkNestedBullet:
      DrawHtml(BULLET + ABlock.Html, NESTED_STEP_INDENT, SPACE_STEP);
  end;
end;

// A page of links to the headings, scenarios indented below their feature.
// The links point at FTargets, the pages found by the first pass.
procedure TPdfRenderer.DrawToc;
var
  LBlock: TBlock;
  LIndex, LTarget, I: Integer;
  LIndent: Single;
  LInFeature: Boolean;
begin
  DrawHtml(Format(HEADING1_HTML, [TOC_HEADING]), 0, 0);
  FY := FY + SPACE_PARAGRAPH;
  LIndex := 0;
  LInFeature := False;
  for I := FContent.CoverCount to High(FContent.Blocks) do
  begin
    LBlock := FContent.Blocks[I];
    if not (LBlock.Kind in [bkHeading1, bkHeading2]) then
      Continue;
    if LBlock.Kind = bkHeading1 then
      LInFeature := True;
    if (LBlock.Kind = bkHeading2) and LInFeature then
      LIndent := TOC_SCENARIO_INDENT
    else
      LIndent := 0;
    if LIndex < Length(FTargets) then
      LTarget := FTargets[LIndex]
    else
      LTarget := 0;
    if FY + TOC_LINE_HEIGHT > FBottom then
      NewPage;
    Graphics.AddGoTo(LBlock.Plain, LTarget, '/Fit',
      RectF(FLeft + LIndent, FY, FRight, FY + TOC_LINE_HEIGHT));
    FY := FY + TOC_LINE_HEIGHT;
    Inc(LIndex);
  end;
end;

function TPdfRenderer.Render(const AFileName: string): TArray<Integer>;
var
  I: Integer;
begin
  FHeadingPages.Clear;
  FPdf := TTMSFNCPDFLib.Create;
  try
    // The document information is written by BeginDocument, so it is set
    // first
    FPdf.Title := FTitle;
    FPdf.Author := FAuthor;
    FPdf.Creator := CREATOR;
    FPdf.BeginDocument(AFileName);
    FPdf.Header := FTitle;
    FPdf.HeaderFont.Name := FONT_NAME;
    FPdf.HeaderFont.SizeNoScale := HEADER_FONT_SIZE;
    FPdf.HeaderFont.Color := COLOR_MUTED;
    FPdf.Footer := '';
    FPdf.PageNumber := pnFooter;
    FPdf.PageNumberFormat := PAGE_NUMBER_FORMAT;
    FPdf.PageNumberFont.Name := FONT_NAME;
    FPdf.PageNumberFont.SizeNoScale := HEADER_FONT_SIZE;
    FPdf.PageNumberFont.Color := COLOR_MUTED;

    NewPage;
    FTop := MARGIN_TOP;
    FBottom := FPdf.PageHeight - MARGIN_BOTTOM;
    FLeft := MARGIN_SIDE;
    FRight := FPdf.PageWidth - MARGIN_SIDE;
    FY := FTop;

    // The preamble on a cover page, then the table of contents on a page of
    // its own, then the features
    if FContent.CoverCount > 0 then
    begin
      FDrawingCover := True;
      for I := 0 to FContent.CoverCount - 1 do
        DrawBlock(FContent.Blocks[I]);
      FDrawingCover := False;
      NewPage;
    end;
    if FContent.HasToc then
    begin
      DrawToc;
      NewPage;
    end;
    for I := FContent.CoverCount to High(FContent.Blocks) do
      DrawBlock(FContent.Blocks[I]);

    // In memory the PDF comes back as a stream, which is not needed
    FPdf.EndDocument.Free;
  finally
    FreeAndNil(FPdf);
  end;
  Result := FHeadingPages.ToArray;
end;

{ TPsBDDTMSPDFConversion }

constructor TPsBDDTMSPDFConversion.Create(const AMarkdownPath, APdfPath: string;
  const ATitle: string; const AAuthor: string);
begin
  inherited Create;
  FMarkdownPath := AMarkdownPath;
  FPdfPath := APdfPath;
  FTitle := ATitle;
  if FTitle = '' then
    FTitle := TPath.GetFileNameWithoutExtension(AMarkdownPath);
  FAuthor := AAuthor;
end;

function TPsBDDTMSPDFConversion.GetDescription: string;
begin
  Result := Format('%s to %s', [TPath.GetFileName(FMarkdownPath),
    TPath.GetFileName(FPdfPath)]);
end;

procedure TPsBDDTMSPDFConversion.Convert;
var
  LReader: TMarkdownReader;
  LContent: TMarkdownContent;
  LRenderer: TPdfRenderer;
  LPages: TArray<Integer>;
  LDirectory: string;
begin
  if not TFile.Exists(FMarkdownPath) then
    raise EFileNotFoundException.CreateFmt(
      'The Markdown document "%s" does not exist.', [FMarkdownPath]);

  LReader := TMarkdownReader.Create;
  try
    LContent := LReader.Read(TFile.ReadAllLines(FMarkdownPath, TEncoding.UTF8));
  finally
    LReader.Free;
  end;

  LDirectory := TPath.GetDirectoryName(FPdfPath);
  if LDirectory <> '' then
    TDirectory.CreateDirectory(LDirectory);

  // First pass in memory finds the page of every heading, the second writes
  // the file with the table of contents linking to them
  LRenderer := TPdfRenderer.Create(LContent, FTitle, FAuthor, nil);
  try
    LPages := LRenderer.Render('');
  finally
    LRenderer.Free;
  end;
  LRenderer := TPdfRenderer.Create(LContent, FTitle, FAuthor, LPages);
  try
    LRenderer.Render(FPdfPath);
  finally
    LRenderer.Free;
  end;
end;

end.
