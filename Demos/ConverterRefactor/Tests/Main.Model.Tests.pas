unit Main.Model.Tests;

{
  Unit tests for the Model (TMainModel) on its own: it holds the companies
  query and exposes it as a plain TDataSet.

  The fields are persistent (made with AllFields from MariaDB), so their
  names and widths are there without opening the query; no database is
  needed. The converter reads a fixed-width line by walking these fields and
  their DisplayWidth, so the layout is pinned here: 85 string fields,
  1436 characters, 'id' (12) first and 'princ6_zip4' (4) last.
}

interface

uses
  DUnitX.TestFramework,
  Main.Int;

type
  [TestFixture]
  TMainModelTests = class
  private
    FModelObject: TObject;
    FModel: IMainModel;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure GetCompaniesDataSet_IsTheCompaniesDataSet;
    [Test]
    procedure GetCompaniesDataSet_IsOwnedByTheModel;
    [Test]
    procedure GetCompaniesDataSet_IsNotOpened;
    [Test]
    procedure GetCompaniesDataSet_HasTheFixedWidthLayout;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  Main.Model;

{ TMainModelTests }

procedure TMainModelTests.Setup;
var
  Model: TMainModel;
begin
  Model := TMainModel.Create(nil);
  FModelObject := Model;
  FModel := Model;
end;

procedure TMainModelTests.TearDown;
begin
  FModel := nil;   // before the data module is freed
  FreeAndNil(FModelObject);
end;

procedure TMainModelTests.GetCompaniesDataSet_IsTheCompaniesDataSet;
begin
  Assert.IsNotNull(FModel.GetCompaniesDataSet, 'GetCompaniesDataSet returned nil');
  Assert.AreEqual('quCompanies', FModel.GetCompaniesDataSet.Name);
end;

procedure TMainModelTests.GetCompaniesDataSet_IsOwnedByTheModel;
begin
  Assert.IsTrue(FModel.GetCompaniesDataSet.Owner = FModelObject,
    'The companies data set is not owned by the Model, so it is not freed with it');
end;

procedure TMainModelTests.GetCompaniesDataSet_IsNotOpened;
begin
  Assert.IsFalse(FModel.GetCompaniesDataSet.Active, 'The companies data set is open; it needs no database');
end;

procedure TMainModelTests.GetCompaniesDataSet_HasTheFixedWidthLayout;
var
  DataSet: TDataSet;
  i, TotalWidth: Integer;
begin
  DataSet := FModel.GetCompaniesDataSet;
  Assert.AreEqual(85, DataSet.FieldCount, 'Field count');
  TotalWidth := 0;
  for i := 0 to DataSet.FieldCount - 1 do
  begin
    Assert.IsTrue(DataSet.Fields[i] is TStringField,
      DataSet.Fields[i].FieldName + ' is not a string field');
    Inc(TotalWidth, DataSet.Fields[i].DisplayWidth);
  end;
  Assert.AreEqual(1436, TotalWidth, 'Total DisplayWidth of a record');
  Assert.AreEqual('id', DataSet.Fields[0].FieldName);
  Assert.AreEqual(12, DataSet.Fields[0].DisplayWidth, 'id width');
  Assert.AreEqual('status', DataSet.Fields[2].FieldName, 'The converter filters on status');
  Assert.AreEqual(1, DataSet.Fields[2].DisplayWidth, 'status width');
  Assert.AreEqual('princ6_zip4', DataSet.Fields[DataSet.FieldCount - 1].FieldName);
  Assert.AreEqual(4, DataSet.Fields[DataSet.FieldCount - 1].DisplayWidth, 'princ6_zip4 width');
end;

initialization
  TDUnitX.RegisterTestFixture(TMainModelTests);

end.
