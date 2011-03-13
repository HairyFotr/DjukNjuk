program DjukNjuk;

uses
  Forms,
  Menu in 'Menu.pas' {MenuForm},
  Settings in 'Settings.pas' {SettingsForm},
  Game in 'Game.pas' {DjukNjuk};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Djuk Njuk';
  Application.CreateForm(TMenuForm, MenuForm);
  Application.Run;
end.
