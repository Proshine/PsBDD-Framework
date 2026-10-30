unit Main.View.Tests;

{
  Unit tests for the main View (TFrmMain) on its own: its controls run its
  actions.

  The form is created with Create(nil) and freed, never shown. Each test
  replaces an action's OnExecute with RecordExecute, so pressing a control
  only records which action ran (the real handlers would open dialogs or
  convert files).
}

interface

uses
  DUnitX.TestFramework,
  Main.View;

type
  [TestFixture]
  TMainViewTests = class
  private
    FView: TFrmMain;
    FExecuteCount: Integer;
    FExecutedSender: TObject;
    procedure RecordExecute(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Actions_HaveTheirHandlers;
    [Test]
    procedure ConvertButton_UsesTheConvertAction;
    [Test]
    procedure ConvertButton_RunsTheConvertAction;
    [Test]
    procedure ConvertButton_DoesNothingWithoutAFolder;
    [Test]
    procedure FolderButton_RunsTheSelectFolderAction;
    [Test]
    procedure ConvertAction_StartsDisabled;
    [Test]
    procedure ConvertAction_IsDisabledAgainWhenTheFolderIsCleared;
    [Test]
    procedure ConvertAction_IsDisabledWhenTheFolderIsOnlySpaces;
    [Test]
    procedure ConvertAction_IsEnabledWithAFolder;
    [Test]
    procedure FolderButton_ShowsTheChosenFolder;
    [Test]
    procedure FolderButton_AsksWithTheTitleAndTheCurrentFolder;
    [Test]
    procedure FolderButton_Cancelled_KeepsTheFolder;
    [Test]
    procedure ConvertProgress_MovesTheProgressBar;
    [Test]
    procedure ConvertProgress_WhileCounting_KeepsTheBarsMax;
    [Test]
    procedure ConvertProgress_AfterTheViewIsFreed_IsNotHeard;
  end;

implementation

uses
  System.SysUtils,
  Spring.Mocking,
  Dialogs.Int,
  Main.Int, Main.Fakes;

{ TMainViewTests }

procedure TMainViewTests.Setup;
begin
  FView := TFrmMain.Create(nil);
  FExecuteCount := 0;
  FExecutedSender := nil;
end;

procedure TMainViewTests.TearDown;
begin
  FreeAndNil(FView);
end;

procedure TMainViewTests.RecordExecute(Sender: TObject);
begin
  Inc(FExecuteCount);
  FExecutedSender := Sender;
end;

procedure TMainViewTests.Actions_HaveTheirHandlers;
begin
  Assert.IsTrue(Assigned(FView.actConvert.OnExecute), 'actConvert has no OnExecute');
  Assert.IsTrue(Assigned(FView.actSelectFolder.OnExecute), 'actSelectFolder has no OnExecute');
end;

procedure TMainViewTests.ConvertButton_UsesTheConvertAction;
begin
  Assert.IsTrue(FView.btnConvert.Action = FView.actConvert,
    'btnConvert does not use actConvert');
  Assert.AreEqual('Convert', FView.btnConvert.Caption);
end;

procedure TMainViewTests.ConvertButton_RunsTheConvertAction;
begin
  FView.actConvert.OnExecute := RecordExecute;
  FView.txtFolder.Text := 'C:\Data';   // Convert is disabled without a folder
  FView.btnConvert.Click;
  Assert.AreEqual(1, FExecuteCount, 'Pressing Convert did not run an action once');
  Assert.IsTrue(FExecutedSender = FView.actConvert, 'Pressing Convert ran another action');
end;

procedure TMainViewTests.ConvertButton_DoesNothingWithoutAFolder;
begin
  // TCustomAction.Execute runs Update first and skips a disabled action
  FView.actConvert.OnExecute := RecordExecute;
  FView.txtFolder.Text := '';
  FView.btnConvert.Click;
  Assert.AreEqual(0, FExecuteCount, 'Pressing Convert without a folder ran the action');
end;

procedure TMainViewTests.FolderButton_RunsTheSelectFolderAction;
begin
  FView.actSelectFolder.OnExecute := RecordExecute;
  FView.txtFolder.OnClickBtn(FView.txtFolder);
  Assert.AreEqual(1, FExecuteCount, 'Pressing the folder button did not run an action once');
  Assert.IsTrue(FExecutedSender = FView.actSelectFolder,
    'Pressing the folder button ran another action');
end;

procedure TMainViewTests.ConvertAction_StartsDisabled;
begin
  // Set in the form designer, so the window opens with Convert disabled
  // before the first idle Update
  Assert.IsFalse(FView.actConvert.Enabled, 'actConvert starts enabled');
  Assert.IsFalse(FView.btnConvert.Enabled, 'btnConvert starts enabled');
end;

{ Convert's enabled state follows the folder box's text as it changes. These
  tests only change the text, as typing or the folder dialog does; none calls
  actConvert.Update. }

procedure TMainViewTests.ConvertAction_IsDisabledAgainWhenTheFolderIsCleared;
begin
  FView.txtFolder.Text := 'C:\Data';
  FView.txtFolder.Text := '';
  Assert.IsFalse(FView.actConvert.Enabled, 'actConvert stays enabled after the folder is cleared');
  Assert.IsFalse(FView.btnConvert.Enabled, 'btnConvert stays enabled after the folder is cleared');
end;

procedure TMainViewTests.ConvertAction_IsDisabledWhenTheFolderIsOnlySpaces;
begin
  FView.txtFolder.Text := 'C:\Data';
  FView.txtFolder.Text := '   ';
  Assert.IsFalse(FView.actConvert.Enabled, 'actConvert is enabled with a blank folder');
end;

procedure TMainViewTests.ConvertAction_IsEnabledWithAFolder;
begin
  FView.txtFolder.Text := 'C:\Data';
  Assert.IsTrue(FView.actConvert.Enabled, 'actConvert is disabled with a folder');
  Assert.IsTrue(FView.btnConvert.Enabled, 'btnConvert is disabled with a folder');
end;

{ The folder button asks the View's IFolderDialogService, here a Spring mock,
  so no dialog opens and no one has to choose a folder. }

procedure TMainViewTests.FolderButton_ShowsTheChosenFolder;
var
  FolderDialog: Mock<IFolderDialogService>;
begin
  FolderDialog.Setup.Returns<string>('C:\Data').When.SelectFolder(
    Arg.IsAny<string>, Arg.IsAny<string>);
  FView.SetFolderDialog(FolderDialog);
  FView.txtFolder.OnClickBtn(FView.txtFolder);
  Assert.AreEqual('C:\Data', FView.txtFolder.Text, 'The folder box');
  Assert.IsTrue(FView.actConvert.Enabled, 'Convert is not enabled with the chosen folder');
end;

procedure TMainViewTests.FolderButton_AsksWithTheTitleAndTheCurrentFolder;
var
  FolderDialog: Mock<IFolderDialogService>;
begin
  FView.SetFolderDialog(FolderDialog);
  FView.txtFolder.Text := 'C:\Old';
  FView.txtFolder.OnClickBtn(FView.txtFolder);
  // The dialog opens at the folder already in the box
  FolderDialog.Received(Times.Once).SelectFolder(SELECT_FOLDER_TITLE, 'C:\Old');
  Assert.Pass;
end;

procedure TMainViewTests.FolderButton_Cancelled_KeepsTheFolder;
var
  FolderDialog: Mock<IFolderDialogService>;
begin
  // Not set up: the mock returns '', which is what the service returns on Cancel
  FView.SetFolderDialog(FolderDialog);
  FView.txtFolder.Text := 'C:\Old';
  FView.txtFolder.OnClickBtn(FView.txtFolder);
  Assert.AreEqual('C:\Old', FView.txtFolder.Text, 'Cancel changed the folder box');
end;

{ The View subscribes to its ViewModel's OnConvertProgress in SetViewModel.
  A fake ViewModel raises the event, as ConvertFile would. }

procedure TMainViewTests.ConvertProgress_MovesTheProgressBar;
var
  Fake: TFakeMainViewModel;
  ViewModel: IMainViewModel;
begin
  Fake := TFakeMainViewModel.Create;
  ViewModel := Fake;
  FView.SetViewModel(ViewModel);
  Fake.RaiseConvertProgress(0, 8);
  Assert.AreEqual(8, FView.Progress.Max, 'Max after the lines are counted');
  Assert.AreEqual(0, FView.Progress.Position, 'Position at the start');
  Fake.RaiseConvertProgress(5, 8);
  Assert.AreEqual(5, FView.Progress.Position, 'Position while converting');
end;

procedure TMainViewTests.ConvertProgress_WhileCounting_KeepsTheBarsMax;
var
  Fake: TFakeMainViewModel;
  ViewModel: IMainViewModel;
begin
  Fake := TFakeMainViewModel.Create;
  ViewModel := Fake;
  FView.SetViewModel(ViewModel);
  Fake.RaiseConvertProgress(0, 8);
  Fake.RaiseConvertProgress(0, 0);   // aMax = 0: still counting the next file
  Assert.AreEqual(8, FView.Progress.Max, 'Counting changed the bar''s Max');
end;

procedure TMainViewTests.ConvertProgress_AfterTheViewIsFreed_IsNotHeard;
var
  Fake: TFakeMainViewModel;
  ViewModel: IMainViewModel;
begin
  Fake := TFakeMainViewModel.Create;
  ViewModel := Fake;
  FView.SetViewModel(ViewModel);
  FreeAndNil(FView);
  Assert.WillNotRaise(
    procedure
    begin
      Fake.RaiseConvertProgress(1, 8);
    end, nil, 'The freed View still handled the progress event');
end;

initialization
  TDUnitX.RegisterTestFixture(TMainViewTests);

end.
