unit Main.Registration;

{
  Registers the Main feature (View, ViewModel, Model) with a Spring4D
  container. This is the only unit that knows both the container and the
  concrete MVVM classes; Main.View, Main.ViewModel and Main.Model know
  neither.

  The app's registration runs in initialization, so the .dpr hooks it in and
  AppController doesn't know this unit. Tests call RegisterMain with their
  own TContainer.

  The main form is registered as TForm 'MainView'. Resolving it runs
  TMainFactory.Build: the form is created with Application.CreateForm (the
  only way to set Application.MainForm) and wired, but not shown.
  Application owns the form and frees it at shutdown, so never Free it or
  Release it through the container.

  TMainFactory makes one thing per step. Each step takes what it needs and
  returns what it made, so each can be unit tested on its own.
}

interface

uses
  System.Classes,
  Vcl.Forms,
  Spring.Container,
  Dialogs.Int,
  Main.Int,
  Main.View;

type
  TMainFactory = class
  public
    class function CreateView: TFrmMain;
    /// <summary>
    /// The owner frees the Model. In Build the owner is the View.
    /// </summary>
    class function CreateModel(const aOwner: TComponent): IMainModel;
    class function CreateViewModel(const aModel: IMainModel): IMainViewModel;
    /// <summary>
    /// Gives the View its ViewModel and the services it calls itself.
    /// </summary>
    class procedure WireUp(const aView: TFrmMain; const aViewModel: IMainViewModel;
      const aFolderDialog: IFolderDialogService);
    /// <summary>
    /// Runs the steps in order: a created, wired, not shown main form. The
    /// ViewModel's Init runs after it gets its Model, before WireUp. The
    /// services come in as parameters, so the factory needs no container.
    /// </summary>
    class function Build(const aFolderDialog: IFolderDialogService): TForm;
  end;

procedure RegisterMain(const aContainer: TContainer);

implementation

uses
  Main.ViewModel,
  Main.Model;

{ TMainFactory }

class function TMainFactory.CreateView: TFrmMain;
begin
  Application.CreateForm(TFrmMain, Result);
end;

class function TMainFactory.CreateModel(const aOwner: TComponent): IMainModel;
begin
  Result := TMainModel.Create(aOwner);
end;

class function TMainFactory.CreateViewModel(const aModel: IMainModel): IMainViewModel;
begin
  Result := TMainViewModel.Create(aModel);
end;

class procedure TMainFactory.WireUp(const aView: TFrmMain;
  const aViewModel: IMainViewModel; const aFolderDialog: IFolderDialogService);
begin
  aView.SetViewModel(aViewModel);
  aView.SetFolderDialog(aFolderDialog);
end;

class function TMainFactory.Build(const aFolderDialog: IFolderDialogService): TForm;
var
  View: TFrmMain;
  ViewModel: IMainViewModel;
begin
  View := CreateView;
  ViewModel := CreateViewModel(CreateModel(View));   // the form owns the Model
  ViewModel.Init;
  WireUp(View, ViewModel, aFolderDialog);
  Result := View;
end;

procedure RegisterMain(const aContainer: TContainer);
begin
  aContainer.RegisterType<TForm>(
    function: TForm
    begin
      // The services are whatever the container has: the real ones in the
      // app (Dialogs.Registration), fakes or mocks in tests
      Result := TMainFactory.Build(aContainer.Resolve<IFolderDialogService>);
    end,
    'MainView');
end;

initialization
  RegisterMain(GlobalContainer);

end.
