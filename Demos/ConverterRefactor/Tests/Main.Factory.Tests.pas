unit Main.Factory.Tests;

{
  Unit tests for TMainFactory (Main.Registration): one test per step, then
  Build, which runs them in order.

  Fakes stand in for the Model and ViewModel, so each step is tested alone.
  Forms are freed at the end of each test; Application owns them, and freeing
  one removes it and clears Application.MainForm.
}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMainFactoryTests = class
  public
    [Test]
    procedure CreateView_MakesTheMainForm;
    [Test]
    procedure CreateModel_IsOwnedByTheOwner;
    [Test]
    procedure CreateViewModel_HoldsTheModelUntilClose;
    [Test]
    procedure WireUp_GivesTheViewItsViewModel;
    [Test]
    procedure WireUp_ClosingTheViewClosesTheViewModel;
    [Test]
    procedure WireUp_FreeingTheViewClosesTheViewModel;
    [Test]
    procedure WireUp_GivesTheViewItsFolderDialog;
    [Test]
    procedure Build_MakesAWiredMainFormThatOwnsTheModel;
  end;

implementation

uses
  System.SysUtils, System.Classes,
  Data.DB,
  Vcl.Forms,
  Spring.Mocking,
  Dialogs.Int,
  Main.Int, Main.View, Main.Model, Main.Registration, Main.Fakes;

type
  TFakeMainModel = class(TInterfacedObject, IMainModel)
  private
    FFreed: PBoolean;
  public
    constructor Create(const aFreed: PBoolean);
    destructor Destroy; override;
    function GetCompaniesDataSet: TDataSet;
  end;

{ TFakeMainModel }

constructor TFakeMainModel.Create(const aFreed: PBoolean);
begin
  inherited Create;
  FFreed := aFreed;
  FFreed^ := False;
end;

destructor TFakeMainModel.Destroy;
begin
  FFreed^ := True;
  inherited;
end;

function TFakeMainModel.GetCompaniesDataSet: TDataSet;
begin
  Result := nil;
end;

{ TMainFactoryTests }

procedure TMainFactoryTests.CreateView_MakesTheMainForm;
var
  View: TFrmMain;
begin
  View := TMainFactory.CreateView;
  try
    Assert.IsNotNull(View, 'No View was made');
    Assert.IsTrue(Application.MainForm = View, 'The View is not the main form');
    Assert.IsFalse(View.Visible, 'The View is shown');
  finally
    View.Free;
  end;
end;

procedure TMainFactoryTests.CreateModel_IsOwnedByTheOwner;
var
  Owner: TComponent;
  Model: IMainModel;
begin
  Owner := TComponent.Create(nil);
  try
    Model := TMainFactory.CreateModel(Owner);
    Assert.IsNotNull(Model, 'No Model was made');
    Assert.IsTrue((Model as TComponent).Owner = Owner, 'The Model has another owner');
    Assert.AreEqual(1, Owner.ComponentCount, 'The owner does not hold the Model');
    Model := nil;   // before the owner frees the data module
  finally
    Owner.Free;
  end;
end;

procedure TMainFactoryTests.CreateViewModel_HoldsTheModelUntilClose;
var
  ModelFreed: Boolean;
  Model: IMainModel;
  ViewModel: IMainViewModel;
begin
  Model := TFakeMainModel.Create(@ModelFreed);
  ViewModel := TMainFactory.CreateViewModel(Model);
  Assert.IsNotNull(ViewModel, 'No ViewModel was made');
  Model := nil;
  Assert.IsFalse(ModelFreed, 'The ViewModel does not hold the Model');
  ViewModel.Close;
  Assert.IsTrue(ModelFreed, 'Close did not let go of the Model');
end;

procedure TMainFactoryTests.WireUp_GivesTheViewItsViewModel;
var
  View: TFrmMain;
  ViewModel: IMainViewModel;
begin
  ViewModel := TFakeMainViewModel.Create;
  View := TMainFactory.CreateView;
  try
    TMainFactory.WireUp(View, ViewModel, nil);
    Assert.IsTrue(View.ViewModel = ViewModel, 'The View has another ViewModel');
  finally
    View.Free;
  end;
end;

procedure TMainFactoryTests.WireUp_ClosingTheViewClosesTheViewModel;
var
  View: TFrmMain;
  Fake: TFakeMainViewModel;
  ViewModel: IMainViewModel;
  Action: TCloseAction;
begin
  Fake := TFakeMainViewModel.Create;
  ViewModel := Fake;
  View := TMainFactory.CreateView;
  try
    TMainFactory.WireUp(View, ViewModel, nil);
    // The OnClose handler itself: View.Close on the main form would call
    // Application.Terminate.
    Assert.IsTrue(Assigned(View.OnClose), 'The View has no OnClose handler');
    Action := caHide;
    View.OnClose(View, Action);
    Assert.AreEqual(1, Fake.CloseCount, 'Closing the View did not close the ViewModel');
  finally
    View.Free;
  end;
end;

procedure TMainFactoryTests.WireUp_FreeingTheViewClosesTheViewModel;
var
  View: TFrmMain;
  Fake: TFakeMainViewModel;
  ViewModel: IMainViewModel;
begin
  Fake := TFakeMainViewModel.Create;
  ViewModel := Fake;
  View := TMainFactory.CreateView;
  TMainFactory.WireUp(View, ViewModel, nil);
  View.Free;
  Assert.AreEqual(1, Fake.CloseCount, 'Freeing the View did not close the ViewModel');
end;

procedure TMainFactoryTests.WireUp_GivesTheViewItsFolderDialog;
var
  View: TFrmMain;
  ViewModel: IMainViewModel;
  FolderDialog: Mock<IFolderDialogService>;
begin
  FolderDialog.Setup.Returns<string>('C:\Data').When.SelectFolder(
    Arg.IsAny<string>, Arg.IsAny<string>);
  ViewModel := TFakeMainViewModel.Create;
  View := TMainFactory.CreateView;
  try
    TMainFactory.WireUp(View, ViewModel, FolderDialog);
    View.actSelectFolder.Execute;
    Assert.AreEqual('C:\Data', View.txtFolder.Text,
      'The View did not use the folder dialog it was given');
  finally
    View.Free;
  end;
end;

procedure TMainFactoryTests.Build_MakesAWiredMainFormThatOwnsTheModel;
var
  View: TForm;
  FolderDialog: Mock<IFolderDialogService>;
  i: Integer;
  OwnsModel: Boolean;
begin
  FolderDialog.Setup.Returns<string>('C:\Data').When.SelectFolder(
    Arg.IsAny<string>, Arg.IsAny<string>);
  View := TMainFactory.Build(FolderDialog);
  try
    Assert.IsTrue(View is TFrmMain, 'Build did not make a TFrmMain');
    Assert.IsTrue(Application.MainForm = View, 'The View is not the main form');
    Assert.IsFalse(View.Visible, 'The View is shown');
    Assert.IsNotNull(TFrmMain(View).ViewModel, 'The View has no ViewModel');
    OwnsModel := False;
    for i := 0 to View.ComponentCount - 1 do
      if View.Components[i] is TMainModel then
        OwnsModel := True;
    Assert.IsTrue(OwnsModel, 'The View does not own the Model');
    TFrmMain(View).actSelectFolder.Execute;
    Assert.AreEqual('C:\Data', TFrmMain(View).txtFolder.Text,
      'The View does not use the folder dialog Build was given');
  finally
    View.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMainFactoryTests);

end.
