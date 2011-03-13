unit Settings;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Menus, ExtCtrls, ComCtrls, pngimage;

type
  TSettingsForm = class(TForm)
    Save: TButton;
    Button1: TButton;
    Button2: TButton;
    S1: TShape;
    S2: TShape;
    S3: TShape;
    Label1: TLabel;
    UBar: TTrackBar;
    UnitN: TLabel;
    MapT: TComboBox;
    Label3: TLabel;
    Detail: TLabel;
    Image1: TImage;
    Image2: TImage;
    StaticText1: TStaticText;
    Blood: TCheckBox;
    Button3: TButton;
    procedure SaveClick(Sender: TObject);
    //function EnumDM(w, h, bpp, rr: Cardinal): Boolean;
    //procedure ResolutionChange(Sender: TObject);
    //function EnumRR(w, h, bpp, rr: Cardinal): Boolean;
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure UBarChange(Sender: TObject);
    procedure BloodClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SettingsForm: TSettingsForm;

implementation

uses Menu;

{$R *.dfm}

//type
//  DisplayModeEnum = function(w, h, bpp, refresh: Cardinal): Boolean of object;

var
  F: TextFile;
  //devMode: TDeviceMode;
  eStr: String;
  SrRC: TSearchRec;
  ResX, ResY: Integer;

procedure TSettingsForm.SaveClick(Sender: TObject);
begin
  AssignFile(F, 'Config.cfg');
  Rewrite(F);

    //Writeln(F, Resolution.Text);
    //Writeln(F, Copy(RefreshRate.Text, 0, Length(RefreshRate.Text)-2));

    if S3.Brush.Color = clGreen then
    Writeln(F, 'High') else
    if S2.Brush.Color = clGreen then
    Writeln(F, 'Medium') else
    if S1.Brush.Color = clGreen then
    Writeln(F, 'Low') else
    Writeln(F, 'Very Low');

    Writeln(F, UBar.Position);

    if MapT.Text <> '' then
    Writeln(F, MapT.Text) else
    Writeln(F, 'Default');

    if Blood.Checked then
      Writeln(F, 1)
    else
      Writeln(F, 0);

  CloseFile(F);

  MenuForm.Show;
  SettingsForm.Destroy;
end;
procedure TSettingsForm.Button3Click(Sender: TObject);
begin
  MenuForm.Show;
  SettingsForm.Destroy;
end;

(*
function TSettingsForm.EnumRR(w, h, bpp, rr: Cardinal): Boolean;
var
  str: String;
begin
  Result := True;

  if (w <> ResX) or (h <> ResY) or (rr < 60) then Exit;

  str := Format('%dHz', [rr]);
  if RefreshRate.Items.IndexOf(str) = -1 then
  RefreshRate.Items.Add(str);
end;

function TSettingsForm.EnumDM(w, h, bpp, rr: Cardinal): Boolean;
var
  str: String;
begin
  Result := True;

  if  (( w <>  800 ) or ( h <> 600 ))
  and (( w <> 1024 ) or ( h <> 768 ))
  and (( w <> 1152 ) or ( h <> 864 ))
  and (( w <> 1280 ) or ( h <> 960 )) then
    Exit;

  str := Format('%dx%d', [w, h]);
  if Resolution.Items.IndexOf(str) = -1 then
  Resolution.Items.Add(str);
end;

procedure EnumerateDisplays(cb: DisplayModeEnum);
var
  I: Integer;
  modeExists: LongBool;
begin

  I := 0;
  modeExists := EnumDisplaySettings(nil, I, devMode);
  while modeExists do
  begin
    with devMode do
    begin
      if not cb(dmPelsWidth, dmPelsHeight, dmBitsPerPel, dmDisplayFrequency) then
      Exit;
    end;
    Inc(I);
    modeExists := EnumDisplaySettings(nil, I, devMode);
  end;

end;

procedure TSettingsForm.ResolutionChange(Sender: TObject);
var
  I: Integer;
begin
  I := 1;
  while Resolution.Text[I] <> 'x' do Inc(I);

  ResX := StrToInt(Copy(Resolution.Text, 0, I-1));
  ResY := StrToInt(Copy(Resolution.Text, I+1, Length(Resolution.Text)));

  RefreshRate.Clear;
  EnumerateDisplays(EnumRR);
  RefreshRate.ItemIndex := RefreshRate.Items.Count-1;
end;
*)
procedure TSettingsForm.FormCreate(Sender: TObject);
var
  TStr: String;
  I: Integer;
begin
  Width := 800;
  Height := 600;
  Left := GetSystemMetrics(SM_CXSCREEN) div 2 - Width div 2;
  Top := GetSystemMetrics(SM_CYSCREEN) div 2 - Height div 2;

  //Image1.Picture.Bitmap.LoadFromFile('Pic2.dat');
  //Image2.Picture.Bitmap.LoadFromFile('Pic.dat');

  DoubleBuffered := True;

  //EnumerateDisplayS(EnumDM);
  //Resolution.ItemIndex := 0;

  ResX := 800;
  ResY := 600;

  //RefreshRate.Clear;
  //EnumerateDisplayS(EnumRR);
  //RefreshRate.ItemIndex := RefreshRate.Items.Count-1;

  UnitN.Caption := UnitN.Caption+' 15';
  eStr := '15';
  UBar.Position := 15;

  if FindFirst('Data\Terrain\Themes\inf.pci', faAnyFile, SrRc) = 0 then
  begin
    AssignFile(F, 'Data\Terrain\Themes\inf.pci');
    Reset(F);
    repeat
      Readln(F, TStr);
      MapT.Items.Add(TStr);
    until eof(F);
    CloseFile(F);

    MapT.ItemIndex := 0;
  end;

  if FindFirst('config.cfg', faAnyFile, SrRc) = 0 then
  begin
    AssignFile(F, 'config.cfg');
    Reset(F);
      (*Readln(F, TStr);
      Resolution.ItemIndex := Resolution.Items.IndexOf(TStr);

      I := 1;
      while Resolution.Text[I] <> 'x' do Inc(I);

      ResX := StrToInt(Copy(Resolution.Text, 0, I-1));
      ResY := StrToInt(Copy(Resolution.Text, I+1, Length(Resolution.Text)));

      Readln(F, TStr);
      RefreshRate.Clear;
      EnumerateDisplayS(EnumRR);
      Refreshrate.ItemIndex := Refreshrate.Items.IndexOf(TStr+'Hz');
      *)
      Readln(F, TStr);
      if TStr = 'High' then
      begin
        S1.Brush.Color := clGreen;
        S2.Brush.Color := clGreen;
        S3.Brush.Color := clGreen;
      end else
      if TStr = 'Medium' then
      begin
        S1.Brush.Color := clGreen;
        S2.Brush.Color := clGreen;
        S3.Brush.Color := clMaroon;
      end else
      if TStr = 'Low' then
      begin
        S1.Brush.Color := clGreen;
        S2.Brush.Color := clMaroon;
        S3.Brush.Color := clMaroon;
      end else
      if TStr = 'Very Low' then
      begin
        S1.Brush.Color := clMaroon;
        S2.Brush.Color := clMaroon;
        S3.Brush.Color := clMaroon;
      end;
    Detail.Caption := TStr;

    Readln(F, I);
    UBar.Position := I;

    Readln(F, TStr);
    MapT.ItemIndex := MapT.Items.IndexOf(TStr);

    Readln(F, I);
    if I = 0 then
      Blood.Checked := False
    else
      Blood.Checked := True;

    CloseFile(F);
  end;

  //I := 1;
  //while Resolution.Text[I] <> 'x' do Inc(I);

//  UnitN.Width := 20;
//  UnitN.Height := 20;
end;

procedure TSettingsForm.Button2Click(Sender: TObject);
begin
  if S1.Brush.Color = clMaroon then S1.Brush.Color := clGreen else
  if S2.Brush.Color = clMaroon then S2.Brush.Color := clGreen else
  if S3.Brush.Color = clMaroon then S3.Brush.Color := clGreen;

  Blood.Enabled := True;

  if S3.Brush.Color = clGreen then Detail.Caption := 'High' else
  if S2.Brush.Color = clGreen then Detail.Caption := 'Medium' else
  if S1.Brush.Color = clGreen then Detail.Caption := 'Low' else
  begin
    Blood.Checked := False;
    Blood.Enabled := False;
    Detail.Caption := 'Very Low';
  end;
end;

procedure TSettingsForm.Button1Click(Sender: TObject);
begin
  if S3.Brush.Color = clGreen then S3.Brush.Color := clMaroon else
  if S2.Brush.Color = clGreen then S2.Brush.Color := clMaroon else
  if S1.Brush.Color = clGreen then S1.Brush.Color := clMaroon;

  Blood.Enabled := True;

  if S3.Brush.Color = clGreen then Detail.Caption := 'High' else
  if S2.Brush.Color = clGreen then Detail.Caption := 'Medium' else
  if S1.Brush.Color = clGreen then Detail.Caption := 'Low' else
  begin
    Detail.Caption := 'Very Low';
    Blood.Checked := False;
    Blood.Enabled := False;
  end;
end;

procedure TSettingsForm.UBarChange(Sender: TObject);
begin
  UnitN.Caption := Copy(UnitN.Caption, 0, Length(UnitN.Caption)-3)+' '+IntToStr(UBar.Position);
  UnitN.Caption := Copy(UnitN.Caption, 0, Length(UnitN.Caption)-3)+' '+IntToStr(UBar.Position);
end;

procedure TSettingsForm.BloodClick(Sender: TObject);
begin
  if Detail.Caption = 'Very Low' then
  Blood.Checked := False;
end;

end.
