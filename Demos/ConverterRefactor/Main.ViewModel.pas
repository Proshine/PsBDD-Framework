unit Main.ViewModel;

{
  ViewModel for the converter window. See Main.Int.
}

interface

uses
  Data.DB,
  Spring,
  Main.Int;

type
  TMainViewModel = class(TInterfacedObject, IMainViewModel)
  private
    FModel: IMainModel;
    FCompaniesDataSet: TDataSet;
    FOnConvertProgress: Event<TConvertProgressEvent>;
    function GetOnConvertProgress: IEvent<TConvertProgressEvent>;
  public
    constructor Create(const aModel: IMainModel);
    procedure Init;
    procedure Close;
    procedure ConvertFile(const aFileName: string);
  end;

implementation

uses
  System.SysUtils, System.Classes;

{ TMainViewModel }

constructor TMainViewModel.Create(const aModel: IMainModel);
begin
  inherited Create;
  FModel := aModel;
end;

procedure TMainViewModel.Init;
begin
  if Assigned(FModel) then
    FCompaniesDataSet := FModel.GetCompaniesDataSet;
end;

procedure TMainViewModel.Close;
begin
  // The Model's data module owns the data sets: close and let go of them
  // first, then of the Model. Safe to call twice (OnClose, then OnDestroy).
  if Assigned(FCompaniesDataSet) then
  begin
    FCompaniesDataSet.Close;
    FCompaniesDataSet := nil;
  end;
  FModel := nil;
end;

function TMainViewModel.GetOnConvertProgress: IEvent<TConvertProgressEvent>;
begin
  Result := FOnConvertProgress;
end;

procedure TMainViewModel.ConvertFile(const aFileName: string);
var
  LInputFile: TFileStream;
  LOutputFile: TFileStream;

  LReader: TStreamReader;
  LWriter: TStreamWriter;

  LLine: String;
  LField: TField;
  LBuffer: String;
  LNewLine: String;
  LPos : Integer;

  i : Integer;

  LCount: Integer;
  LMax : Integer;

  LDontAdd: Boolean;

begin
  if not Assigned(FCompaniesDataSet) then
    raise EInvalidOpException.Create('ConvertFile needs Init first');

  // streams for files
  LInputFile := TFileStream.Create(aFileName, fmOpenRead );
  LOutputFile := TFileStream.Create(aFileName + '.csv', fmCreate );

  // writer and reader
  LWriter := TStreamWriter.Create(LOutputFile);
  LReader := TStreamReader.Create(LInputFile, TEncoding.ANSI);

  // init count vars
  LCount := 0;
  LMax := 0;

  try
    //
    // count lines
    while not LReader.EndOfStream do
    begin
      Inc( LMax );
      LReader.ReadLine;
      if LMax MOD 500 = 0 then
      begin
        // still counting: lets the View keep the window responsive
        FOnConvertProgress.Invoke(0, 0);
      end;
    end;

    // set up progress
    FOnConvertProgress.Invoke(0, LMax);


    // restart reader
    LReader.Rewind;

    // iterate all records
    while not LReader.EndOfStream do
    begin
      // get line
      LLine := LReader.ReadLine;
      Inc( LCount );

      // one lines with complete data
      if Length( LLine ) > 50 then
      begin
        LPos := 1;
        LNewLine := '';
        LDontAdd := False;

        // iterate all fields and assign values
        for i := 0 to FCompaniesDataSet.FieldCount -1 do
        begin
          LField := FCompaniesDataSet.Fields[i];

          LBuffer := TRIM( COPY( LLine, LPos, LField.DisplayWidth ) );
          LBuffer := LBuffer.Replace(#9, '', [] );

          while LBuffer.Contains('\') do
          begin
            LBuffer := LBuffer.Replace('\', '/', [ rfReplaceAll ] );
          end;

          while LBuffer.Contains('  ') do
          begin
            LBuffer := LBuffer.Replace('  ', ' ', [ ] );
          end;


          if i > 0 then
          begin
            LNewLine := LNewLine + #9;
          end;

          LNewLine := LNewLine + TRIM( LBuffer );

          Inc(LPos, LField.DisplayWidth );

          if ( LField.DisplayLabel = 'status' )  then
          begin
            if LBuffer.Length > 0 then
            begin
              if not CharInSet( LBuffer[1], ['A', 'E', 'I'] ) then
              begin
                LDontAdd := True;
              end;
            end
            else
            begin
              LDontAdd := True;
            end;
          end;

          if LDontAdd then
          begin
            LNewLine := '';
            break;
          end;

        end; // iterating fields

        if LNewLine <> '' then
        begin
          // write line
          LWriter.WriteLine(LNewLine);
        end;
      end;  // processing line

      // update progress
      if LCount MOD 500 = 0 then
      begin
        FOnConvertProgress.Invoke(LCount, LMax);
      end;
    end; // end while

  finally
    LReader.Free;
    LWriter.Free;
    LOutputFile.Free;
    LInputFile.Free;

    FOnConvertProgress.Invoke(0, LMax);
  end;
end;

end.
