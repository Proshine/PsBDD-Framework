unit Main.Int;

{
  Interfaces for the converter window: View (TFrmMain), ViewModel and Model.

  The form owns the Model's TDataModule, so the data module is freed with the
  form. The ViewModel holds the Model by interface, so the form's OnClose
  must call IMainViewModel.Close, which lets go of the Model (and of any
  TDataSet or other data module member it holds) before the form is freed.
}

interface

uses
  Data.DB,
  Spring;

type
  /// <summary>
  /// Progress of ConvertFile. aMax is the file's line count; aMax = 0 while
  /// the lines are still being counted. The last call has aPosition = 0, so
  /// a progress bar is reset.
  /// </summary>
  TConvertProgressEvent = procedure(const aPosition, aMax: Integer) of object;

  IMainModel = interface
    ['{6ADC65D3-3BB3-4900-A553-AAD0E23A2B8B}']
    /// <summary>
    /// The companies record layout: persistent fields whose names and
    /// DisplayWidths describe one fixed-width line of a cordata file. A plain
    /// TDataSet, so callers don't depend on FireDAC. Owned by the Model.
    /// </summary>
    function GetCompaniesDataSet: TDataSet;
  end;

  IMainViewModel = interface
    ['{C0235E52-A609-43EA-9034-3C920FE02324}']
    /// <summary>
    /// Called once after the ViewModel is created with its Model: takes the
    /// Model's data sets into the ViewModel's own fields. Kept apart from the
    /// constructor so each can be tested on its own.
    /// </summary>
    procedure Init;
    /// <summary>
    /// Called from the form's OnClose. Closes and nils any TDataSet references
    /// to the Model, then nils the Model.
    /// </summary>
    procedure Close;
    /// <summary>
    /// Converts one fixed-width cordata file to aFileName + '.csv': one
    /// tab-separated line per record, fields cut and named by the companies
    /// data set, records with a status other than A, E or I dropped, lines of
    /// 50 characters or less skipped. Needs Init first.
    /// </summary>
    procedure ConvertFile(const aFileName: string);
    function GetOnConvertProgress: IEvent<TConvertProgressEvent>;
    /// <summary>
    /// The View subscribes to it (Spring Event: it holds its ViewModel) to
    /// move its progress bar.
    /// </summary>
    property OnConvertProgress: IEvent<TConvertProgressEvent> read GetOnConvertProgress;
  end;

implementation

end.
