unit Menu;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, dglOpenGL, pngimage;


type
  TMenuForm = class(TForm)
    Image1: TImage;
    StaticText1: TStaticText;
    MenuPanel: TPanel;
    S1: TImage;
    N1: TImage;
    N0: TImage;
    S0: TImage;
    Q1: TImage;
    Q0: TImage;
    procedure FormCreate(Sender: TObject);
    procedure N0MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure S0MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure Q0MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure N1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Q1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure S1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MenuForm: TMenuForm;

implementation

uses Settings, Game;

var
  DjukNjuk: TGame;


{$R *.dfm}

(*function ChangeDisplaySettingsA(lpDevMode: PDevMode; dwflags: DWORD): Integer;
  stdcall; external 'user32.dll';

function glSetRes(w, h, bpp, refresh: Cardinal): Boolean;
var
  devMode: TDeviceMode;
  modeExists: LongBool;
  modeSwitch, closeMode, i: Integer;
begin
  Result := FALSE;

  // Change the display resolution to w x h x bpp @ refresh
  // Use (0, 0, 0, 0) to restore the normal resolution.
  closeMode := 0;
  i := 0;
  repeat
    modeExists := EnumDisplaySettings(nil, i, devMode);
    // if not modeExists then: This mode may not be supported. We'll try anyway, though.
    with devMode do
    begin
      if (dmPelsWidth = w) and (dmPelsHeight = h) and
         (dmBitsPerPel = bpp) and (dmDisplayFrequency = refresh) then
      begin
        modeSwitch := ChangeDisplaySettingsA(@devMode, CDS_FULLSCREEN);
        if modeSwitch = DISP_CHANGE_SUCCESSFUL then
        begin
          Result := TRUE;
          Exit;
        end;
      end;
    end;
    if closeMode <> 0 then closeMode := i;
    INC(i);
  until not modeExists;

  EnumDisplaySettings(nil, closeMode, devMode);
  with devMode do
  begin
    dmBitsPerPel := bpp;
    dmPelsWidth := w;
    dmPelsHeight := h;
    dmDisplayFrequency := refresh;
    dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT or DM_DISPLAYFREQUENCY;
  end;
  modeSwitch := ChangeDisplaySettingsA(@devMode, CDS_FULLSCREEN);
  if modeSwitch = DISP_CHANGE_SUCCESSFUL then
  begin
    Result := TRUE;
    Exit;
  end;

  devMode.dmFields := DM_BITSPERPEL;
  modeSwitch := ChangeDisplaySettingsA(@devMode, CDS_FULLSCREEN);
  if modeSwitch = DISP_CHANGE_SUCCESSFUL then
  begin
    devMode.dmFields := DM_PELSWIDTH or DM_PELSHEIGHT;
    modeSwitch := ChangeDisplaySettingsA(@devMode, CDS_FULLSCREEN);
    if modeSwitch = DISP_CHANGE_SUCCESSFUL then
    begin
      ChangeDisplaySettingsA(nil, 0);
      Result := TRUE;
      Exit;
    end;
  end;
end;
*)
procedure TMenuForm.FormCreate(Sender: TObject);
begin
  Width := 800;
  Height := 600;
  Left := GetSystemMetrics(SM_CXSCREEN) div 2 - Width div 2;
  Top := GetSystemMetrics(SM_CYSCREEN) div 2 - Height div 2;

(*  if  ((FileExists('Djuk.exe') = False)
  and (FileExists('Djuk.dat') = False))
  or (FileExists('Settings.dat') = False)
  then
  begin
    ShowMessage('Some of the main game files are missing. Please reinstall.');
    Application.Terminate;
  end;*)

  DoubleBuffered := True;

  (*if (GetSystemMetrics(SM_CXSCREEN) <> 800)
  or (GetSystemMetrics(SM_CYSCREEN) <> 600) then
  glSetRes(800, 600, 16, 60);*)
end;

procedure TMenuForm.FormShow(Sender: TObject);
begin
  if DjukNjuk <> nil then
  begin
    //DjukNjuk.Close;
  end;
end;

procedure TMenuForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  N0.Visible := True;
  S0.Visible := True;
  Q0.Visible := True;
  N1.Visible := False;
  S1.Visible := False;
  Q1.Visible := False;
end;

procedure TMenuForm.N0MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  N0.Visible := False;
  N1.Visible := True;

  S0.Visible := True;
  Q0.Visible := True;
  S1.Visible := False;
  Q1.Visible := False;
end;

procedure TMenuForm.S0MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  S0.Visible := False;
  S1.Visible := True;

  N0.Visible := True;
  Q0.Visible := True;
  N1.Visible := False;
  Q1.Visible := False;
end;

procedure TMenuForm.Q0MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  Q0.Visible := False;
  Q1.Visible := True;

  N0.Visible := True;
  S0.Visible := True;
  N1.Visible := False;
  S1.Visible := False;
end;

procedure TMenuForm.N1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  (*glSetRes(0,0,0,0);

  if FileExists('Djuk.exe') then
    WinExec('Djuk.exe', SW_SHOWNORMAL)
  else if FileExists('Djuk.dat') then
    WinExec('Djuk.dat', SW_SHOWNORMAL);

  Application.Terminate;*)
  //if DjukNjuk <> nil then DjukNjuk.Destroy;
  (*DjukNjuk := TDjukNjuk(FindComponent('DjukNjuk'));
  if DjukNjuk <> nil then
    DjukNjuk.Release
  else
    ShowMessage('Failed to find it') ;
    *)
  //if DjukNjuk <> nil then DjukNjuk.Release;
  //if DjukNjuk <> nil then DjukNjuk:=nil;

  if DjukNjuk <> nil then
    DjukNjuk.Close;

  DjukNjuk := TGame.Create(nil);
  //DjukNjuk.Show;
//  Application.CreateForm(TDjukNjuk, DjukNjuk);
  MenuForm.Hide;
end;

procedure TMenuForm.Q1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  //glSetRes(0,0,0,0);
  Application.Terminate;
end;

procedure TMenuForm.S1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
//  glSetRes(0,0,0,0);
//  WinExec('Settings.dat', SW_SHOWNORMAL);
//  Application.Terminate;
  Application.CreateForm(TSettingsForm, SettingsForm);
  SettingsForm.Show;
  MenuForm.Hide;
end;

end.
