unit Feature.Documents;

{
  The combined BDD documents of the feature scenarios: every feature of a
  run in one Markdown and one HTML document, Tests\BDDOutput\AllFeatures.md
  and .html, next to each feature's own stand-alone document.

  Each new combined document starts with the preamble, Tests\Preamble.md or
  Tests\Preamble.html. The project file calls RegisterPreambles and sets
  TPsBDDRun.RunStart before the runner; each fixture calls
  AddCombinedDocuments in SetupFixture.
}

interface

uses
  PsBDD.Framework;

/// <summary>The path of a file in Tests\BDDOutput.</summary>
function OutputPath(const aFileName: string): string;

/// <summary>Adds the combined Markdown and HTML documents to a feature.</summary>
procedure AddCombinedDocuments(const aFeatureWriter: IPsBDDFeatureDocumentWriter);

/// <summary>Registers the preambles of the combined documents.</summary>
procedure RegisterPreambles;

implementation

uses
  System.SysUtils, System.IOUtils,
  PsBDD.MarkdownDocument, PsBDD.HTMLDocument;

const
  ALL_FEATURES_MD = 'AllFeatures.md';
  ALL_FEATURES_HTML = 'AllFeatures.html';
  PREAMBLE_MD = 'Preamble.md';
  PREAMBLE_HTML = 'Preamble.html';

// The runner is built into Tests\Build, so Tests is one folder up
function TestsPath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    TPath.Combine('..', aFileName)));
end;

function OutputPath(const aFileName: string): string;
begin
  Result := TestsPath(TPath.Combine('BDDOutput', aFileName));
end;

procedure AddCombinedDocuments(const aFeatureWriter: IPsBDDFeatureDocumentWriter);
begin
  ForceDirectories(ExtractFilePath(OutputPath(ALL_FEATURES_MD)));
  aFeatureWriter.AddDocument(
    TPsBDDMarkdownDocument.Create(OutputPath(ALL_FEATURES_MD), auDeveloper, False));
  aFeatureWriter.AddDocument(
    TPsBDDHTMLDocument.Create(OutputPath(ALL_FEATURES_HTML), auDeveloper, False));
end;

procedure RegisterPreambles;
begin
  TPsBDDRun.AddPreamble(OutputPath(ALL_FEATURES_MD), TestsPath(PREAMBLE_MD));
  TPsBDDRun.AddPreamble(OutputPath(ALL_FEATURES_HTML), TestsPath(PREAMBLE_HTML));
end;

end.
