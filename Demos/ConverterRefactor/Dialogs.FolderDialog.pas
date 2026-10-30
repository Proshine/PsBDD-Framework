unit Dialogs.FolderDialog;

{
  IFolderDialogService on the TMS TFolderDialog. The dialog is created and
  set up in the constructor (as the form's FormCreate used to do) and freed
  in the destructor. Registered as a singleton by Dialogs.Registration.

  It shows a real modal dialog, so it has no unit test; tests use a fake or a
  mock of IFolderDialogService.
}

interface

uses
  FolderDialog,
  Dialogs.Int;

type
  TFolderDialogService = class(TInterfacedObject, IFolderDialogService)
  private
    FDialog: TFolderDialog;
  public
    constructor Create;
    destructor Destroy; override;
    function SelectFolder(const aTitle, aInitialFolder: string): string;
  end;

implementation

{ TFolderDialogService }

constructor TFolderDialogService.Create;
begin
  inherited Create;
  FDialog := TFolderDialog.Create(nil);
  FDialog.Caption := 'Select folder';
  FDialog.Options := FDialog.Options +
    [ fdoNewDialogStyle,
      fdoEditBox,              // show edit box
      fdoNoNewFolderButton     // no button to add folders
    ];
end;

destructor TFolderDialogService.Destroy;
begin
  FDialog.Free;
  inherited;
end;

function TFolderDialogService.SelectFolder(const aTitle,
  aInitialFolder: string): string;
begin
  FDialog.Title := aTitle;
  FDialog.Directory := aInitialFolder;
  if FDialog.Execute then
    Result := FDialog.Directory
  else
    Result := '';
end;

end.
