unit Main.ViewModel.Convert.Tests;

{
  Unit tests for TMainViewModel.ConvertFile with the real Model (its
  companies data set gives the fixed-width layout) and a real test file.

  Tests\Data\cordata0.txt was made from rows of
  handson1-master\XData-LLC\sql\companies.sql, padded to the Model's field
  widths (1436 characters a record). Its 8 lines:
    1  293499        FLINN FARMS, INC.                    A  real row
    2  100906        FLINT REALTY CORP                    I  real row
    3  537890        AIR-FLITE CONTAINERS, INCORPORATED   A  real row
    4  T00000000001  STATUS X IS DROPPED INC              X  dropped: status not A/E/I
    5  T00000000002  'SMITH\JONES'#9'  AND  SONS'         A  tab, backslash, double spaces
    6  593675        FLIGHT DECK, INC.                    A  real row
    7  103469        FLINN W M INC                        I  real row
    8  'TRAILER 00000008'                                    skipped: 50 characters or less
  The expected values below come from a separate PowerShell version of the
  rules, not from this code.

  Each test copies the file to Tests\Build\TestData and converts it there,
  so the .csv lands next to the copy and Tests\Data stays unchanged.
}

interface

uses
  DUnitX.TestFramework,
  Main.Int;

type
  [TestFixture]
  TMainViewModelConvertTests = class
  private
    FModelObject: TObject;
    FViewModel: IMainViewModel;
    FSourceFile: string;
    FProgress: TArray<TArray<Integer>>;
    procedure RecordProgress(const aPosition, aMax: Integer);
    function ConvertedLines: TArray<string>;
    function Fields(const aLine: string): TArray<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ConvertFile_WritesTheCsvNextToTheFile;
    [Test]
    procedure ConvertFile_KeepsStatusAEIAndDropsOthers;
    [Test]
    procedure ConvertFile_SkipsShortLines;
    [Test]
    procedure ConvertFile_WritesEveryFieldTabSeparated;
    [Test]
    procedure ConvertFile_TrimsTheFields;
    [Test]
    procedure ConvertFile_CleansTabsBackslashesAndDoubleSpaces;
    [Test]
    procedure ConvertFile_ReportsProgress;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Main.Model, Main.ViewModel;

{ TMainViewModelConvertTests }

procedure TMainViewModelConvertTests.Setup;
var
  Model: TMainModel;
  TestDir: string;
begin
  TestDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'TestData');
  ForceDirectories(TestDir);
  FSourceFile := TPath.Combine(TestDir, 'cordata0.txt');
  TFile.Copy(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\Data\cordata0.txt')), FSourceFile, True);
  if TFile.Exists(FSourceFile + '.csv') then
    TFile.Delete(FSourceFile + '.csv');

  Model := TMainModel.Create(nil);
  FModelObject := Model;
  FViewModel := TMainViewModel.Create(Model);
  FViewModel.Init;
  FProgress := nil;
end;

procedure TMainViewModelConvertTests.TearDown;
begin
  if Assigned(FViewModel) then
    FViewModel.Close;
  FViewModel := nil;   // before the data module is freed
  FreeAndNil(FModelObject);
end;

procedure TMainViewModelConvertTests.RecordProgress(const aPosition, aMax: Integer);
begin
  FProgress := FProgress + [[aPosition, aMax]];
end;

function TMainViewModelConvertTests.ConvertedLines: TArray<string>;
begin
  FViewModel.ConvertFile(FSourceFile);
  Result := TFile.ReadAllLines(FSourceFile + '.csv');
end;

function TMainViewModelConvertTests.Fields(const aLine: string): TArray<string>;
begin
  Result := aLine.Split([#9]);
end;

procedure TMainViewModelConvertTests.ConvertFile_WritesTheCsvNextToTheFile;
begin
  FViewModel.ConvertFile(FSourceFile);
  Assert.IsTrue(TFile.Exists(FSourceFile + '.csv'), 'No cordata0.txt.csv was written');
end;

procedure TMainViewModelConvertTests.ConvertFile_KeepsStatusAEIAndDropsOthers;
var
  Lines: TArray<string>;
  Ids: string;
  Line: string;
begin
  Lines := ConvertedLines;
  Ids := '';
  for Line in Lines do
    Ids := Ids + Fields(Line)[0] + ' ';
  Assert.AreEqual('293499 100906 537890 T00000000002 593675 103469 ', Ids,
    'Ids of the converted lines, in order (T00000000001 has status X)');
end;

procedure TMainViewModelConvertTests.ConvertFile_SkipsShortLines;
var
  Line: string;
begin
  for Line in ConvertedLines do
    Assert.IsFalse(Line.StartsWith('TRAILER'), 'The short trailer line was converted');
end;

procedure TMainViewModelConvertTests.ConvertFile_WritesEveryFieldTabSeparated;
var
  Line: string;
begin
  for Line in ConvertedLines do
    Assert.AreEqual(85, Length(Fields(Line)), 'Fields in line ' + Fields(Line)[0]);
end;

procedure TMainViewModelConvertTests.ConvertFile_TrimsTheFields;
var
  First: TArray<string>;
begin
  First := Fields(ConvertedLines[0]);
  Assert.AreEqual('293499', First[0], 'id');
  Assert.AreEqual('FLINN FARMS, INC.', First[1], 'name');
  Assert.AreEqual('A', First[2], 'status');
  Assert.AreEqual('DOMP', First[3], 'filing_type');
end;

procedure TMainViewModelConvertTests.ConvertFile_CleansTabsBackslashesAndDoubleSpaces;
var
  Cleaned: TArray<string>;
begin
  Cleaned := Fields(ConvertedLines[3]);
  Assert.AreEqual('T00000000002', Cleaned[0], 'id');
  Assert.AreEqual('SMITH/JONES AND SONS', Cleaned[1],
    'Tab removed, backslash made a slash, double spaces made single');
end;

procedure TMainViewModelConvertTests.ConvertFile_ReportsProgress;
begin
  FViewModel.OnConvertProgress.Add(RecordProgress);
  FViewModel.ConvertFile(FSourceFile);
  Assert.IsTrue(Length(FProgress) >= 2, 'Progress was reported less than twice');
  Assert.AreEqual(0, FProgress[0][0], 'First position');
  Assert.AreEqual(8, FProgress[0][1], 'First max: the file has 8 lines');
  Assert.AreEqual(0, FProgress[High(FProgress)][0], 'Last position: the bar is reset');
end;

initialization
  TDUnitX.RegisterTestFixture(TMainViewModelConvertTests);

end.
