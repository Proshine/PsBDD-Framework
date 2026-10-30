unit Dialogs.Int;

{
  Interfaces of the dialog services: everything the user is asked goes
  through one, so tests replace it with a fake or a Spring Mock<T> instead of
  waiting for user input.

  The implementations are View-side (VCL) code in their own units and are
  registered by Dialogs.Registration. Views get them injected.

  The interfaces descend from IInvokable so they have RTTI, which Spring's
  Mock<T> needs.
}

interface

type
  IFolderDialogService = interface(IInvokable)
    ['{79013173-1CCE-4CEA-852A-4FCD3133C4CF}']
    /// <summary>
    /// Asks the user for a folder, starting at aInitialFolder. Returns the
    /// chosen folder, or '' when the user cancels.
    /// </summary>
    function SelectFolder(const aTitle, aInitialFolder: string): string;
  end;

implementation

end.
