unit ConverterConst;

{
  Constants shared across the converter app.
}

interface

const
  /// <summary>
  /// Window class name of the main form, set in TFrmMain.CreateParams.
  /// TAppController finds a running converter by it, so it must be unique.
  /// </summary>
  WINDOW_CLASS_NAME = 'ConverterMainView';

implementation

end.
