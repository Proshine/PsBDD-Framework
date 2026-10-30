unit SingleInstance.Feature.Tests;

{
  BDD scenarios for starting the converter only once.

  The main form registers its window class as WINDOW_CLASS_NAME. A second
  start finds that window, brings it back and stops, instead of opening a
  second converter.

  "Started again" runs what TAppController.Run does before it creates the
  form: CheckSingleton, and SetFocusRunningInstance when another converter
  is running. Run itself isn't called, because when it finds no running
  converter it goes on to Application.Run and would never return.

  These scenarios use real windows, so close any running CSVConvert.exe first.
}

interface

uses
  Vcl.Forms,
  Spring.Container,
  Spring.Mocking,
  DUnitX.TestFramework,
  PsBDD.Framework,
  Dialogs.Int;

type
  [TestFixture]
  TSingleInstanceFeature = class
  private
    FFeatureWriter: IPsBDDFeatureDocumentWriter;
    FContainer: TContainer;
    FMainView: TForm;
    FFolderDialog: Mock<IFolderDialogService>;   // the window needs one; never asked here
    FIsOnlyConverter: Boolean;

    procedure TeardownStartingTheConverterASecondTime;
    procedure TheConverterIsRunningAndMinimized;
    procedure TheConverterIsStartedAgain;
    procedure TheRunningConverterIsFound;
    procedure TheRunningConverterWindowIsRestored;
    procedure TheRunningConverterWindowIsInFront;

    procedure TeardownStartingTheConverterTheFirstTime;
    procedure NoConverterIsRunning;
    procedure TheConverterIsStarted;
    procedure ItIsTheOnlyConverter;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test]
    procedure StartingTheConverterASecondTime;
    [Test]
    procedure StartingTheConverterTheFirstTime;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.IOUtils,
  PsBDD.FeatureWriter, PsBDD.MarkdownDocument,
  AppController, ConverterConst, Main.Registration, Feature.Documents;

const
  FEATURE_DESCRIPTION = '''
    As a user
    I want the converter to open only once
    So that starting it again brings back the converter I already have open
    ''';

function DocumentPath: string;
begin
  // The runner is built into Tests\Build; the document goes to Tests\BDDOutput.
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\BDDOutput\SingleInstance.md'));
end;

{ TSingleInstanceFeature }

procedure TSingleInstanceFeature.SetupFixture;
begin
  ForceDirectories(ExtractFilePath(DocumentPath));
  FFeatureWriter := TPsBDDFeatureDocumentWriter.Create;
  FFeatureWriter.Title := 'Single instance';
  FFeatureWriter.Description := FEATURE_DESCRIPTION;
  FFeatureWriter.Audiences := [auDeveloper, auTester];
  FFeatureWriter.Status := fsInDevelopment;
  FFeatureWriter.AddDocument(
    TPsBDDMarkdownDocument.Create(DocumentPath, auDeveloper, True));
  AddCombinedDocuments(FFeatureWriter);
  FFeatureWriter.Open;
  FFeatureWriter.WriteFeature;
end;

procedure TSingleInstanceFeature.TearDownFixture;
begin
  FFeatureWriter.Close;
  FFeatureWriter := nil;
end;

procedure TSingleInstanceFeature.StartingTheConverterASecondTime;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(
    FFeatureWriter.BeginScenario('Starting the converter a second time'));
  Scenario
    .Teardown(TeardownStartingTheConverterASecondTime)
    .Given(TheConverterIsRunningAndMinimized, 'the converter is running and minimized')
    .When(TheConverterIsStartedAgain, 'the converter is started again')
    .&Then(TheRunningConverterIsFound, 'the running converter is found, so no second one opens')
    .&And(TheRunningConverterWindowIsRestored, 'the running converter window is restored')
    .&And(TheRunningConverterWindowIsInFront, 'the running converter window is in front');
end;

procedure TSingleInstanceFeature.StartingTheConverterTheFirstTime;
var
  Scenario: IPsBDDScenario;
begin
  Scenario := TPsBDDScenario.Create(
    FFeatureWriter.BeginScenario('Starting the converter the first time'));
  Scenario
    .Teardown(TeardownStartingTheConverterTheFirstTime)
    .Given(NoConverterIsRunning, 'no converter is running')
    .When(TheConverterIsStarted, 'the converter is started')
    .&Then(ItIsTheOnlyConverter, 'it is the only converter, so it opens');
end;

{ Steps: Starting the converter a second time }

procedure TSingleInstanceFeature.TeardownStartingTheConverterASecondTime;
begin
  // Runs even when a step fails, so it must not fail itself. Application owns
  // the form; freeing it removes it and clears Application.MainForm.
  FreeAndNil(FMainView);
  FreeAndNil(FContainer);
end;

procedure TSingleInstanceFeature.TheConverterIsRunningAndMinimized;
begin
  // As TAppController.Run sets it, before the form is created. Without it a
  // minimized main form is hidden instead of iconic.
  Application.MainFormOnTaskbar := True;
  FContainer := TContainer.Create;
  FContainer.RegisterInstance<IFolderDialogService>(FFolderDialog);
  RegisterMain(FContainer);
  FContainer.Build;
  FMainView := FContainer.Resolve<TForm>('MainView');
  FMainView.WindowState := wsMinimized;
  FMainView.Show;
  Assert.IsTrue(IsIconic(FMainView.Handle), 'The converter window is not minimized');
end;

procedure TSingleInstanceFeature.TheConverterIsStartedAgain;
begin
  FIsOnlyConverter := TAppController.CheckSingleton;
  if not FIsOnlyConverter then
    TAppController.SetFocusRunningInstance;
end;

procedure TSingleInstanceFeature.TheRunningConverterIsFound;
begin
  Assert.IsFalse(FIsOnlyConverter, 'The running converter was not found');
  Assert.IsTrue(FindWindow(WINDOW_CLASS_NAME, nil) = FMainView.Handle,
    'The window found is not the running converter');
end;

procedure TSingleInstanceFeature.TheRunningConverterWindowIsRestored;
begin
  Assert.IsFalse(IsIconic(FMainView.Handle), 'The converter window is still minimized');
end;

procedure TSingleInstanceFeature.TheRunningConverterWindowIsInFront;
begin
  Assert.IsTrue(GetForegroundWindow = FMainView.Handle,
    'The converter window is not the foreground window');
end;

{ Steps: Starting the converter the first time }

procedure TSingleInstanceFeature.TeardownStartingTheConverterTheFirstTime;
begin
  // Nothing to clean up: no window is opened. It runs even when a step
  // fails, so it must not fail itself.
end;

procedure TSingleInstanceFeature.NoConverterIsRunning;
begin
  Assert.IsTrue(FindWindow(WINDOW_CLASS_NAME, nil) = 0,
    'A converter window is already open. Close CSVConvert.exe and run again');
end;

procedure TSingleInstanceFeature.TheConverterIsStarted;
begin
  FIsOnlyConverter := TAppController.CheckSingleton;
end;

procedure TSingleInstanceFeature.ItIsTheOnlyConverter;
begin
  Assert.IsTrue(FIsOnlyConverter, 'Another converter was reported as running');
end;

initialization
  TDUnitX.RegisterTestFixture(TSingleInstanceFeature);

end.
