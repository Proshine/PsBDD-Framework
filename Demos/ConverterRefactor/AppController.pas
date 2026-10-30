unit AppController;

interface

type
  TAppController = class
  public
    /// <summary>
    /// True when no other converter is running (no window of class
    /// WINDOW_CLASS_NAME). Call it before the main form is created, or it
    /// finds this one.
    /// </summary>
    class function CheckSingleton: Boolean;
    /// <summary>
    /// Restores the running converter's window if it is minimized and brings
    /// it to the front.
    /// </summary>
    class procedure SetFocusRunningInstance;
    class procedure Run; static;
  end;

implementation

uses
  Vcl.Forms
  , Winapi.Windows
  , Spring.Container
  , ConverterConst
  ;

class function TAppController.CheckSingleton: Boolean;
begin
  Result := FindWindow(WINDOW_CLASS_NAME, nil) = 0;
end;

class procedure TAppController.SetFocusRunningInstance;
var
  Wnd: HWND;
begin
  Wnd := FindWindow(WINDOW_CLASS_NAME, nil);
  if Wnd = 0 then
    Exit;
  if IsIconic(Wnd) then
    ShowWindow(Wnd, SW_RESTORE);
  SetForegroundWindow(Wnd);
end;

class procedure TAppController.Run;
var
  MainView: TForm;
begin
{$IFDEF DEBUG}
  // FastMM4 (first unit in the .dpr) honours this because the Debug config
  // defines ManualLeakReportingControl. By default it only reports when a
  // debugger is attached.
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if not TAppController.CheckSingleton then
  begin
    TAppController.SetFocusRunningInstance;
    Exit;
  end;
  // Every feature's .Registration unit has registered itself in initialization
  GlobalContainer.Build;
  // Created but not shown. Application owns it and frees it at shutdown
  MainView := GlobalContainer.Resolve<TForm>('MainView');
  //This is the seam we will use for the tests
  MainView.Show;
  Application.Run;
end;

end.
