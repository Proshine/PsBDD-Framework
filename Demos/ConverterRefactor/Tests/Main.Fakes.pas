unit Main.Fakes;

{
  Fakes shared by the unit tests.

  TFakeMainViewModel stands in for the ViewModel when a test drives the View
  or the factory: it counts Close calls, records the files it is asked to
  convert, and lets the test raise its progress event.
}

interface

uses
  Spring,
  Main.Int;

type
  TFakeMainViewModel = class(TInterfacedObject, IMainViewModel)
  private
    FCloseCount: Integer;
    FConvertedFiles: TArray<string>;
    FOnConvertProgress: Event<TConvertProgressEvent>;
    function GetOnConvertProgress: IEvent<TConvertProgressEvent>;
  public
    procedure Init;
    procedure Close;
    procedure ConvertFile(const aFileName: string);
    /// <summary>
    /// Raises OnConvertProgress, as ConvertFile would.
    /// </summary>
    procedure RaiseConvertProgress(const aPosition, aMax: Integer);
    property CloseCount: Integer read FCloseCount;
    property ConvertedFiles: TArray<string> read FConvertedFiles;
  end;

implementation

{ TFakeMainViewModel }

procedure TFakeMainViewModel.Init;
begin
end;

procedure TFakeMainViewModel.Close;
begin
  Inc(FCloseCount);
end;

procedure TFakeMainViewModel.ConvertFile(const aFileName: string);
begin
  FConvertedFiles := FConvertedFiles + [aFileName];
end;

function TFakeMainViewModel.GetOnConvertProgress: IEvent<TConvertProgressEvent>;
begin
  Result := FOnConvertProgress;
end;

procedure TFakeMainViewModel.RaiseConvertProgress(const aPosition, aMax: Integer);
begin
  FOnConvertProgress.Invoke(aPosition, aMax);
end;

end.
