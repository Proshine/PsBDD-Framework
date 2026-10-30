unit Converter.Feature.Tests;

{
  End-to-end BDD scenarios for the converter window.

  The window is driven the way a user drives it, by pressing its buttons.
  Everything the user is asked or told goes through interfaced services,
  which the tests replace with fakes.

  Every step starts as a failing 'Not implemented yet' assert and is
  implemented one at a time. A failing step stops the scenario, so only the
  first unfinished step runs.
}

interface

uses
  Vcl.Forms,
  Spring.Container,
  DUnitX.TestFramework,
  PsBDD.Framework,
  Dialogs.Int;

type
  /// <summary>
  /// Stands in for the folder dialog: "chooses" ChosenFolder and records how
  /// it was asked.
  /// </summary>
  TFakeFolderDialogService = class(TInterfacedObject, IFolderDialogService)
  private
    FAskedCount: Integer;
    FTitle: string;
    FChosenFolder: string;
  public
    constructor Create(const aChosenFolder: string);
    function SelectFolder(const aTitle, aInitialFolder: string): string;
    property AskedCount: Integer read FAskedCount;
    property Title: string read FTitle;
    property ChosenFolder: string read FChosenFolder;
  end;

  [TestFixture]
  TConverterFeature = class
  private
    FFeatureWriter: IPsBDDFeatureDocumentWriter;
    FContainer: TContainer;
    FMainView: TForm;
    FFolderDialog: TFakeFolderDialogService;
    FFolderDialogService: IFolderDialogService;   // keeps the fake alive

    procedure TeardownSelectingTheSourceFolder;
    procedure TheConverterWindowIsOpen;
    procedure TheSelectFolderButtonIsPressed;
    procedure TheFolderDialogAsksForAFolder;
    procedure TheChosenFolderIsShown;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure SelectingTheSourceFolder;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  PsBDD.FeatureWriter, PsBDD.MarkdownDocument,
  Main.View, Main.Registration, Feature.Documents;

const
  FEATURE_DESCRIPTION = '''
    As a user
    I want to choose the folder with the Florida corporate data files
    So that I can convert them to CSV files for MariaDB
    ''';

  CHOSEN_FOLDER = 'C:\FloridaData';

{ TFakeFolderDialogService }

constructor TFakeFolderDialogService.Create(const aChosenFolder: string);
begin
  inherited Create;
  FChosenFolder := aChosenFolder;
end;

function TFakeFolderDialogService.SelectFolder(const aTitle,
  aInitialFolder: string): string;
begin
  Inc(FAskedCount);
  FTitle := aTitle;
  Result := FChosenFolder;
end;

function DocumentPath: string;
begin
  // The runner is built into Tests\Build; the document goes to Tests\BDDOutput.
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\BDDOutput\ConverterWindow.md'));
end;

{ TConverterFeature }

procedure TConverterFeature.SetupFixture;
begin
  ForceDirectories(ExtractFilePath(DocumentPath));
  FFeatureWriter := TPsBDDFeatureDocumentWriter.Create;
  FFeatureWriter.Title := 'Converter window';
  FFeatureWriter.Description := FEATURE_DESCRIPTION;
  FFeatureWriter.Audiences := [auDeveloper, auTester];
  FFeatureWriter.Status := fsInDevelopment;
  FFeatureWriter.AddDocument(
    TPsBDDMarkdownDocument.Create(DocumentPath, auDeveloper, True));
  AddCombinedDocuments(FFeatureWriter);
  FFeatureWriter.Open;
  FFeatureWriter.WriteFeature;
end;

procedure TConverterFeature.TearDownFixture;
begin
  FFeatureWriter.Close;
  FFeatureWriter := nil;
end;

procedure TConverterFeature.SelectingTheSourceFolder;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(
    FFeatureWriter.BeginScenario('Selecting the source folder'));
  Scenario
    .Teardown(TeardownSelectingTheSourceFolder)
    .Given(TheConverterWindowIsOpen, 'the converter window is open')
    .When(TheSelectFolderButtonIsPressed, 'the Select folder button is pressed')
    .&Then(TheFolderDialogAsksForAFolder, 'the folder dialog asks for a folder')
    .&And(TheChosenFolderIsShown, 'the chosen folder is shown in the folder box');
end;

{ Steps }

procedure TConverterFeature.TeardownSelectingTheSourceFolder;
begin
  // Runs even when a step fails, so it must not fail itself. Application owns
  // the form; freeing it removes it and clears Application.MainForm.
  FreeAndNil(FMainView);
  FreeAndNil(FContainer);
  FFolderDialog := nil;
  FFolderDialogService := nil;
end;

procedure TConverterFeature.TheConverterWindowIsOpen;
begin
  // Resolved the way TAppController.Run does it: created and wired, not shown.
  // The folder dialog is a fake, so no one has to choose a folder.
  FFolderDialog := TFakeFolderDialogService.Create(CHOSEN_FOLDER);
  FFolderDialogService := FFolderDialog;
  FContainer := TContainer.Create;
  FContainer.RegisterInstance<IFolderDialogService>(FFolderDialogService);
  RegisterMain(FContainer);
  FContainer.Build;
  FMainView := FContainer.Resolve<TForm>('MainView');
  Assert.IsTrue(Application.MainForm = FMainView,
    'The converter window is not the main form');
  Assert.IsNotNull((FMainView as TFrmMain).ViewModel,
    'The converter window has no ViewModel');
end;

procedure TConverterFeature.TheSelectFolderButtonIsPressed;
var
  View: TFrmMain;
begin
  // The "..." button of the folder box
  View := FMainView as TFrmMain;
  View.txtFolder.OnClickBtn(View.txtFolder);
end;

procedure TConverterFeature.TheFolderDialogAsksForAFolder;
begin
  Assert.AreEqual(1, FFolderDialog.AskedCount, 'The folder dialog was not asked once');
  Assert.AreEqual(SELECT_FOLDER_TITLE, FFolderDialog.Title, 'The folder dialog''s title');
end;

procedure TConverterFeature.TheChosenFolderIsShown;
var
  View: TFrmMain;
begin
  View := FMainView as TFrmMain;
  Assert.AreEqual(CHOSEN_FOLDER, View.txtFolder.Text, 'The folder box');
  Assert.IsTrue(View.actConvert.Enabled, 'Convert is not enabled with a folder');
end;

initialization
  TDUnitX.RegisterTestFixture(TConverterFeature);

end.
