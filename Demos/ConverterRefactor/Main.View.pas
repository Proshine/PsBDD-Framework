unit Main.View;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, AdvProgr, AdvEdit, AdvEdBtn,
  System.Actions, Vcl.ActnList,
  Dialogs.Int,
  Main.Int;

const
  SELECT_FOLDER_TITLE = 'Please select the folder with the source files.';

type
  TFrmMain = class(TForm)
    btnConvert: TButton;
    Progress: TAdvProgress;
    lblFilename: TLabel;
    txtFolder: TAdvEditBtn;
    alMain: TActionList;
    actConvert: TAction;
    actSelectFolder: TAction;
    procedure actConvertExecute(Sender: TObject);
    procedure actConvertUpdate(Sender: TObject);
    procedure actSelectFolderExecute(Sender: TObject);
    procedure txtFolderClickBtn(Sender: TObject);
    procedure txtFolderChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    FViewModel: IMainViewModel;
    FFolderDialog: IFolderDialogService;
    procedure ConvertProgress(const aPosition, aMax: Integer);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { Public declarations }
    procedure SetViewModel(const aViewModel: IMainViewModel);
    /// <summary>
    /// The folder button asks this service for the folder (UI work, so the
    /// View calls it, not the ViewModel).
    /// </summary>
    procedure SetFolderDialog(const aFolderDialog: IFolderDialogService);
    /// <summary>
    /// Read only, so tests can check the View is wired. Set it with
    /// SetViewModel.
    /// </summary>
    property ViewModel: IMainViewModel read FViewModel;
  end;

implementation

{$R *.dfm}

{ TFrmMain }

uses System.IOUtils, ConverterConst;

procedure TFrmMain.actConvertExecute(Sender: TObject);
var
  LDir : String;
  LFile: String;
  i: Integer;

begin
  LDir := txtFolder.Text;

  // files are named cordata[0-9].txt
  for i := 0 to 9 do begin
    LFile := TPath.Combine(LDir, 'cordata' + i.ToString + '.txt');

    // if file exists, process it
    if TFile.Exists(LFile) then
    begin
      lblFilename.Caption := LFile;
      FViewModel.ConvertFile( LFile );
    end;
  end;

  ShowMessage('Done.');
end;

procedure TFrmMain.actConvertUpdate(Sender: TObject);
begin
  // Nothing to convert until a folder is chosen
  actConvert.Enabled := Trim(txtFolder.Text) <> '';
end;

procedure TFrmMain.ConvertProgress(const aPosition, aMax: Integer);
begin
  // aMax = 0 while the ViewModel is still counting lines: keep the bar
  if aMax > 0 then
  begin
    Progress.Max := aMax;
    Progress.Min := 0;
  end;
  Progress.Position := aPosition;
  Application.ProcessMessages;
end;

procedure TFrmMain.CreateParams(var Params: TCreateParams);
begin
  inherited;
  StrCopy(Params.WinClassName, WINDOW_CLASS_NAME);
end;

procedure TFrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // The ViewModel lets go of the Model (owned by this form) before the form
  // and its data module are freed. See Main.Int.
  if Assigned(FViewModel) then
    FViewModel.Close;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
  // Also when the form is freed without being closed (tests). Runs before
  // the owned data module is freed. Close must allow being called twice.
  if Assigned(FViewModel) then
  begin
    FViewModel.OnConvertProgress.Remove(ConvertProgress);
    FViewModel.Close;
    FViewModel := nil;
  end;
end;

procedure TFrmMain.SetViewModel(const aViewModel: IMainViewModel);
begin
  if Assigned(FViewModel) then
    FViewModel.OnConvertProgress.Remove(ConvertProgress);
  FViewModel := aViewModel;
  if Assigned(FViewModel) then
    FViewModel.OnConvertProgress.Add(ConvertProgress);
end;

procedure TFrmMain.SetFolderDialog(const aFolderDialog: IFolderDialogService);
begin
  FFolderDialog := aFolderDialog;
end;

procedure TFrmMain.actSelectFolderExecute(Sender: TObject);
var
  Folder: string;
begin
  if not Assigned(FFolderDialog) then
    raise EInvalidOpException.Create('The View has no folder dialog service');
  // Opens at the folder already in the box; '' means the user cancelled
  Folder := FFolderDialog.SelectFolder(SELECT_FOLDER_TITLE, txtFolder.Text);
  if Folder <> '' then
    txtFolder.Text := Folder;
end;

procedure TFrmMain.txtFolderChange(Sender: TObject);
begin
  // Convert follows the folder as it is typed, cleared or chosen, without
  // waiting for the idle loop's Update
  actConvert.Update;
end;

procedure TFrmMain.txtFolderClickBtn(Sender: TObject);
begin
  // TAdvEditBtn's button has no Action property, so it runs the action here
  actSelectFolder.Execute;
end;

end.
