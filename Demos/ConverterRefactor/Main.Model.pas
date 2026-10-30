unit Main.Model;

{
  Model for the converter window. The form owns this data module, so it is
  freed with the form. See Main.Int.

  quCompanies holds the companies record layout as persistent fields (made
  with AllFields from MariaDB). It has no connection and is never opened:
  the converter only reads its fields' names and DisplayWidths. Callers get
  it as a plain TDataSet through IMainModel.GetCompaniesDataSet.
}

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async,
  FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  Main.Int;

type
  TMainModel = class(TDataModule, IMainModel)
    quCompanies: TFDQuery;
    quCompaniesid: TStringField;
    quCompaniesname: TStringField;
    quCompaniesstatus: TStringField;
    quCompaniesfiling_type: TStringField;
    quCompaniesprinc_add_1: TStringField;
    quCompaniesprinc_add_2: TStringField;
    quCompaniesprinc_city: TStringField;
    quCompaniesprinc_state: TStringField;
    quCompaniesprinc_zip: TStringField;
    quCompaniesprinc_country: TStringField;
    quCompaniesmail_add_1: TStringField;
    quCompaniesmail_add_2: TStringField;
    quCompaniesmail_city: TStringField;
    quCompaniesmail_state: TStringField;
    quCompaniesmail_zip: TStringField;
    quCompaniesmail_country: TStringField;
    quCompaniesfile_date: TStringField;
    quCompaniesfei_number: TStringField;
    quCompaniesmore_than_six_off_flag: TStringField;
    quCompanieslast_trx_date: TStringField;
    quCompaniesstate_country: TStringField;
    quCompaniesreport_year_1: TStringField;
    quCompanieshouse_flag_1: TStringField;
    quCompaniesreport_date_1: TStringField;
    quCompaniesreport_year_2: TStringField;
    quCompanieshouse_flag_2: TStringField;
    quCompaniesreport_date_2: TStringField;
    quCompaniesreport_year_3: TStringField;
    quCompanieshouse_flag_3: TStringField;
    quCompaniesreport_date_3: TStringField;
    quCompaniesra_name: TStringField;
    quCompaniesra_name_type: TStringField;
    quCompaniesra_add_1: TStringField;
    quCompaniesra_city: TStringField;
    quCompaniesra_state: TStringField;
    quCompaniesra_zip5: TStringField;
    quCompaniesra_zip4: TStringField;
    quCompaniesprinc1_title: TStringField;
    quCompaniesprinc1_name_type: TStringField;
    quCompaniesprinc1_name: TStringField;
    quCompaniesprinc1_add_1: TStringField;
    quCompaniesprinc1_city: TStringField;
    quCompaniesprinc1_state: TStringField;
    quCompaniesprinc1_zip5: TStringField;
    quCompaniesprinc1_zip4: TStringField;
    quCompaniesprinc2_title: TStringField;
    quCompaniesprinc2_name_type: TStringField;
    quCompaniesprinc2_name: TStringField;
    quCompaniesprinc2_add_1: TStringField;
    quCompaniesprinc2_city: TStringField;
    quCompaniesprinc2_state: TStringField;
    quCompaniesprinc2_zip5: TStringField;
    quCompaniesprinc2_zip4: TStringField;
    quCompaniesprinc3_title: TStringField;
    quCompaniesprinc3_name_type: TStringField;
    quCompaniesprinc3_name: TStringField;
    quCompaniesprinc3_add_1: TStringField;
    quCompaniesprinc3_city: TStringField;
    quCompaniesprinc3_state: TStringField;
    quCompaniesprinc3_zip5: TStringField;
    quCompaniesprinc3_zip4: TStringField;
    quCompaniesprinc4_title: TStringField;
    quCompaniesprinc4_name_type: TStringField;
    quCompaniesprinc4_name: TStringField;
    quCompaniesprinc4_add_1: TStringField;
    quCompaniesprinc4_city: TStringField;
    quCompaniesprinc4_state: TStringField;
    quCompaniesprinc4_zip5: TStringField;
    quCompaniesprinc4_zip4: TStringField;
    quCompaniesprinc5_title: TStringField;
    quCompaniesprinc5_name_type: TStringField;
    quCompaniesprinc5_name: TStringField;
    quCompaniesprinc5_add_1: TStringField;
    quCompaniesprinc5_city: TStringField;
    quCompaniesprinc5_state: TStringField;
    quCompaniesprinc5_zip5: TStringField;
    quCompaniesprinc5_zip4: TStringField;
    quCompaniesprinc6_title: TStringField;
    quCompaniesprinc6_name_type: TStringField;
    quCompaniesprinc6_name: TStringField;
    quCompaniesprinc6_add_1: TStringField;
    quCompaniesprinc6_city: TStringField;
    quCompaniesprinc6_state: TStringField;
    quCompaniesprinc6_zip5: TStringField;
    quCompaniesprinc6_zip4: TStringField;
  private
    { Private declarations }
  public
    { Public declarations }
    function GetCompaniesDataSet: TDataSet;
  end;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

{ TMainModel }

function TMainModel.GetCompaniesDataSet: TDataSet;
begin
  Result := quCompanies;
end;

end.