unit Main.ViewModel.Tests;

{
  Unit tests for the ViewModel (TMainViewModel) on its own.

  Init takes the companies data set from the Model into a private field;
  Close closes it and lets go of it, then lets go of the Model. The field is
  not exposed, so the tests watch what Close does to the data set.

  A fake Model returns an open in-memory table (or nil), so no database or
  data module is needed.
}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMainViewModelTests = class
  public
    [Test]
    procedure Close_ClosesTheCompaniesDataSet;
    [Test]
    procedure Close_WithoutInit_LeavesTheDataSetAlone;
    [Test]
    procedure Close_LetsGoOfTheModel;
    [Test]
    procedure Close_CanBeCalledTwice;
    [Test]
    procedure Init_WithAModelWithoutADataSet;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Main.Int, Main.ViewModel;

type
  TFakeCompaniesModel = class(TInterfacedObject, IMainModel)
  private
    FTable: TFDMemTable;
    FFreed: PBoolean;
  public
    /// <summary>
    /// With aWithDataSet, GetCompaniesDataSet returns an open in-memory table;
    /// otherwise nil.
    /// </summary>
    constructor Create(const aWithDataSet: Boolean; const aFreed: PBoolean = nil);
    destructor Destroy; override;
    function GetCompaniesDataSet: TDataSet;
    property Table: TFDMemTable read FTable;
  end;

{ TFakeCompaniesModel }

constructor TFakeCompaniesModel.Create(const aWithDataSet: Boolean;
  const aFreed: PBoolean);
begin
  inherited Create;
  FFreed := aFreed;
  if Assigned(FFreed) then
    FFreed^ := False;
  if aWithDataSet then
  begin
    FTable := TFDMemTable.Create(nil);
    FTable.FieldDefs.Add('id', ftString, 12);
    FTable.CreateDataSet;
  end;
end;

destructor TFakeCompaniesModel.Destroy;
begin
  FTable.Free;
  if Assigned(FFreed) then
    FFreed^ := True;
  inherited;
end;

function TFakeCompaniesModel.GetCompaniesDataSet: TDataSet;
begin
  Result := FTable;
end;

{ TMainViewModelTests }

procedure TMainViewModelTests.Close_ClosesTheCompaniesDataSet;
var
  Fake: TFakeCompaniesModel;
  Model: IMainModel;
  ViewModel: IMainViewModel;
begin
  Fake := TFakeCompaniesModel.Create(True);
  Model := Fake;   // keeps the fake, and its table, alive after Close
  ViewModel := TMainViewModel.Create(Model);
  ViewModel.Init;
  Assert.IsTrue(Fake.Table.Active, 'The table should start open');
  ViewModel.Close;
  Assert.IsFalse(Fake.Table.Active, 'Close did not close the companies data set');
end;

procedure TMainViewModelTests.Close_WithoutInit_LeavesTheDataSetAlone;
var
  Fake: TFakeCompaniesModel;
  Model: IMainModel;
  ViewModel: IMainViewModel;
begin
  Fake := TFakeCompaniesModel.Create(True);
  Model := Fake;
  ViewModel := TMainViewModel.Create(Model);
  ViewModel.Close;
  Assert.IsTrue(Fake.Table.Active,
    'Close closed a data set that Init never took; Init should take it, not Close');
end;

procedure TMainViewModelTests.Close_LetsGoOfTheModel;
var
  ModelFreed: Boolean;
  ViewModel: IMainViewModel;
begin
  ViewModel := TMainViewModel.Create(TFakeCompaniesModel.Create(True, @ModelFreed));
  ViewModel.Init;
  Assert.IsFalse(ModelFreed, 'The ViewModel does not hold the Model');
  ViewModel.Close;
  Assert.IsTrue(ModelFreed, 'Close did not let go of the Model');
end;

procedure TMainViewModelTests.Close_CanBeCalledTwice;
var
  Fake: TFakeCompaniesModel;
  Model: IMainModel;
  ViewModel: IMainViewModel;
begin
  // OnClose and then OnDestroy both call Close
  Fake := TFakeCompaniesModel.Create(True);
  Model := Fake;
  ViewModel := TMainViewModel.Create(Model);
  ViewModel.Init;
  ViewModel.Close;
  ViewModel.Close;
  Assert.IsFalse(Fake.Table.Active, 'The companies data set is open after two Closes');
end;

procedure TMainViewModelTests.Init_WithAModelWithoutADataSet;
var
  ViewModel: IMainViewModel;
begin
  ViewModel := TMainViewModel.Create(TFakeCompaniesModel.Create(False));
  Assert.WillNotRaise(
    procedure
    begin
      ViewModel.Init;
      ViewModel.Close;
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TMainViewModelTests);

end.
