unit Dialogs.Registration;

{
  Registers the dialog services (Dialogs.Int) with a Spring4D container, as
  singletons. Like the feature registration units, the app's registration
  runs in initialization (the .dpr lists this unit). Tests don't use it: they
  register a fake or a mock instead.
}

interface

uses
  Spring.Container;

procedure RegisterDialogs(const aContainer: TContainer);

implementation

uses
  Dialogs.Int,
  Dialogs.FolderDialog;

procedure RegisterDialogs(const aContainer: TContainer);
begin
  aContainer.RegisterType<IFolderDialogService, TFolderDialogService>.AsSingleton;
end;

initialization
  RegisterDialogs(GlobalContainer);

end.
