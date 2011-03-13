unit Game;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ImgList, ExtCtrls, StdCtrls, dglOpenGL, ShellAPI;

type
  RGun = record
    ClipTime, ClipSize,
    sX, sY,
    pX, pY, Dmg, Interval: Integer;
    Tip: String[16];
    TT, ET: String[8];
  end;
  RmyGun = record
    Clip, Index: Integer;
  end;
  RCreature = record
    eX, eY, X, Y: Real;
    sX, sY, g,
    PicN, Pic, Pic2, PicInt, PicIndex,
    Index, TgIndex,
    OrgSpd, Spd,
    OrgPwr, Pwr, GunY,
    HitBy, AiL, Kills, Deaths: Integer;
    Dir: -1..1;
    AITip, Name,
    Act, ActM, exAct: String[16];
    myGun: RmyGun;
    myGunsI: Array of RmyGun;
    ClipTimer,
    PicT, ShootI: Int64;
    PicShowStyle: 0..1; //animate when walking (0), or repetitive animation (1)
    MainPic: 0..20; //pic shown, when standing still
    JumpPic:Boolean; //does creature have pics to jump
    Dead, Air: Boolean; //is it dead, is it in the air
  end;
  RBullet = record
    X, Y, Dmg: Integer;
    Dir: -1..1;
    DirY: -3..3;
    Owner: record
      Name:String[16];
      Index: Integer;
      HisGun: RMyGun;
    end;
    Typ, TT, ET: String[8];
  end;

  TGame = class(TForm)
    procedure DrawTex(X, Y: Real; sX, sY: Integer; Rotate: Real; Flip: Boolean; Index: Integer);
    procedure DrawCRTex(X, Y: Real; sX, sY: Integer; Rotate: Real; Flip: Boolean; Index1, Index2: Integer);
    //TODO: bitmap font.. its just letter by letter right now (see data/font folder)
    procedure Text(X, Y: Integer; S: String; Size: Real);

    //Particle effects... some effects are used only once and dont have their own functions
    procedure P_Blood(X, Y: Real; Int, Size, Dir: Integer);
    procedure P_Dissolve(L: Integer);
    procedure P_Explode(X, Y: Real; Tip: ShortString);

    procedure Draw;
    procedure CreatureAI(var C: RCreature; Tg: RCreature);
    function OwnedAlready(I, L: Integer): Boolean;
    procedure Calculate;

    procedure LoadMap;

    procedure Loop(Sender: Tobject; var Done: Boolean);
    procedure EndItAll;

    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure FormDestroy(Sender: TObject);
  end;

var
  DjukNjuk: TGame;

implementation

uses Menu;

{$R *.dfm}

const
  StuffCount = 300;//Number of trees, bushes and the stuff, that hangs form the ceiling
  FontSize = 64;
  RespawnPointCount = 150;
  TransColor = $10000000;
  FPSLimit = 29; //didn't figure out the fps independancy
  //Particles
  Blood = 0;
  Bullet = 1;
  Explosion = 2;
  Dissolve = 3;//when creature dies
  //Quality setting
  Lowest = 0;
  Low = 1;
  Medium = 2;
  High = 3;//when creature dies
  //Terrain
  Dirt = False;
  Sky = True;

var
  //Poly1 is for the light polygons, poly2 for the dark
  //TODO: concave polygon support(then there will be no need for poly2..]
  Poly1, Poly2: Array of TPoint;
  PolyList: Integer=-1; //The display list for polygons
  //A temporary array, used to readback the polygons to array T, screen by screen
  TmB: array of Cardinal;

  //The array, that stores the terrain (dirt:=false, sky:=true)
  T: Array of Array of Boolean;

  //Creatures
  Cre: Array[ 0..20, 0..20 ] of record//Pics
    Pic: array[0..64*64] of Integer;
    Index: Cardinal;
  end;

  CR: Array of RCreature;
  //some variables only to enable Djuk to run
  //TODO: make all creatures able to run
  OrgSpd, OrgPicInt: Integer;
  Running: Boolean = False;

  //Stuff that lies around on the terrain
  ST: Array [0..StuffCount] of record
    sX, sY, X, Y,
    pIndex: Integer;
    Tip: Char;
  end;
  Stv: Array of record
    Pic: array[0..256*256] of Integer;
    sX, sY: Integer;
    Index: GluInt;
  end;

  //Bullets
  BL: Array of RBullet;
  //Particles
  PT: Array of record
        X: Integer;
        Y, g: Single;
        Dir: SmallInt;
        Tip: 0..3;
        Clr: Integer;
      end;

  //Weather particles
  Weather: Array of record
        X, Y: Word;
        Dir: 0..5;
      end;
  WeatherInTheSky: Integer = 400;
  MaxWeather: Integer = 30000;
  WeatherType: Integer;
  Wind: 0..2;
  //Guns
  GN: Array of RGun;
  LGN: array of record //guns that lie on the ground
    X, Y, g: Integer;
    Dir: 0..1;
    Air: Boolean;
    Index: Integer;
  end;
  GB: Array of record
    Pic: Array [0..64*16] of Integer;
    Index: Cardinal;
  end;

  //Stores letters for the Text function
  TextFont: Array of record
         Pic: Array[ 0..FontSize, 0..FontSize ] of Cardinal;
         Chr: Char;
         Index: Cardinal;
       end;

  //Respawn points
  RP: Array [0..RespawnPointCount-1] of TPoint;

  Keys: Array of Word;

  LoopT: Real;

  FPS, RunT: Int64;
  Theme: String;
  MapCnt: Integer = 0;

  //Needed?
  //RR: Integer;
  XdZ: Integer;
  YdZ: Integer;

  Pause: Boolean = False;
  KP: Boolean = False;
  MP: Boolean = False;
  Gameover: Boolean = True;
  Excape: Boolean = False;
  Loading: Boolean = True;
  //Quality settings
  Part, Back, Smooth, BloodEnabled: Boolean;

  stOrgStvari,

  tpX, tpY,
  tX, tY: Integer;

  Rs, Gs, Bs,
  Rt, Gt, Bt: Real; //terrain color

//  FPSCnt,
  FpsTim: Integer;

  DeadT: Int64;

  Maps: Array of String;

//Loading
  Lindex: Cardinal;
  Lpic: Array[0..512*128] of Cardinal;
  CFl: File of Cardinal;

//  QStr: String;
  Quality: 0..5;
//  bol: boolean=True;
  SRec: TSearchRec; //just a search record for finding some files :)

var //GDI/OpenGL stuff
  RC: HGLRC;
  PF: Integer;
  PFD: TPixelFormatDescriptor;
  DC: HDC;
var//Timer
  StartTime: Int64;
  freq: Int64;

function dotTime: Int64;
begin

  // Return the current performance counter value.
  QueryPerformanceCounter(Result);

end;

function dotTimeSince(start: Int64): Single;
var
  x: Int64;
begin

  // Return the time elapsed since start (get start with dotTime()).
  QueryPerformanceCounter(x);
  Result := (x - start) * 1000 / freq;

end;

procedure dotStartTiming;
begin

  // Call this to start measuring elapsed time.
  StartTime := dotTime;

end;

function dotTimeElapsed: Single;
begin

  // Call this to measure the time elapsed since the last StartTiming call.
  Result := dotTimeSince(StartTime);

end;

procedure TGame.DrawTex(X, Y: Real; sX, sY: Integer; Rotate: Real; Flip: Boolean; Index: Integer);
var
  FlipI: Integer;
begin
  glBindTexture(GL_TEXTURE_2D,Index);

  if (rotate <> 0) then
  begin
    glTranslatef(X+sx/2, Y+sy/2, 0);
    glRotatef(Rotate, 0, 0, 1);
    glTranslatef(-(X+sx/2), -(Y+sy/2), 0);
  end;

  if Flip then
    FlipI := 1
  else
    FlipI := 0;

  glBegin(GL_QUADS);
  glColor3f(1, 1, 1);
    glTexCoord2f(Abs(1-FlipI), 0);
    glVertex2f  (X, Y);

    glTexCoord2f(Abs(1-FlipI), 1);
    glVertex2f  (X, Y+Sy);

    glTexCoord2f(FlipI, 1);
    glVertex2f  (X+Sx, Y+Sy);

    glTexCoord2f(FlipI, 0);
    glVertex2f  (X+Sx, Y);
  glend;
  glLoadIdentity;
end;

procedure TGame.DrawCRTex(X, Y: Real; sX, sY: Integer; Rotate: Real; Flip: Boolean; Index1, Index2: Integer);
var
  FlipI, K: Integer;
begin
  if (rotate <> 0) then
  begin
    glTranslatef(X+sx/2, Y+sy/2, 0);
    glRotatef(Rotate, 0, 0, 1);
    glTranslatef(-(X+sx/2), -(Y+sy/2), 0);
  end;

  if Flip then
    FlipI := 1
  else
    FlipI := 0;

  K := 44;

  glBindTexture(GL_TEXTURE_2D,Index1);
  glBegin(GL_QUADS);
  glColor3f(1, 1, 1);
    glTexCoord2f(Abs(1-FlipI), 0);
    glVertex2f  (X, Y);

    glTexCoord2f(Abs(1-FlipI), K/sy);
    glVertex2f  (X, Y+(Sy*K)/sy);

    glTexCoord2f(FlipI, K/sy);
    glVertex2f  (X+Sx, Y+(Sy*K)/sy);

    glTexCoord2f(FlipI, 0);
    glVertex2f  (X+Sx, Y);
  glend;
  glBindTexture(GL_TEXTURE_2D,Index2);
  glBegin(GL_QUADS);
  glColor3f(1, 1, 1);
    glTexCoord2f(Abs(1-FlipI), K/sy);
    glVertex2f  (X, Y+(Sy*K)/sy);

    glTexCoord2f(Abs(1-FlipI), 1);
    glVertex2f  (X, Y+Sy);

    glTexCoord2f(FlipI, 1);
    glVertex2f  (X+Sx, Y+Sy);

    glTexCoord2f(FlipI, K/sy);
    glVertex2f  (X+Sx, Y+(Sy*K)/sy);
  glend;
  glLoadIdentity;
end;

procedure TGame.Text(X, Y: Integer; S: String; Size: Real);
var
  I, J: Integer;
begin
  S := UpperCase(S);
  for I := 1 to Length(S) do
  begin
    for J := 0 to Length(TextFont)-1 do
    if TextFont[J].Chr = S[I] then
    begin
      glBindTexture(GL_TEXTURE_2D,TextFont[J].Index);
      glLoadIdentity;
      glTranslatef(X+(I-1)*Size, Y, 0);
      glBegin(GL_QUADS);
      glColor3f(0, 0, 0);
        glTexCoord2f(0, 0);
        glVertex2f  (0, 0);

        glTexCoord2f(1, 0);
        glVertex2f  (0, Size);

        glTexCoord2f(1, 1);
        glVertex2f  (Size, Size);

        glTexCoord2f(0, 1);
        glVertex2f  (Size, 0);
      glend;
    end;
  end;
end;

procedure TGame.P_Blood(X, Y: Real; Int, Size, Dir: Integer);
var
  I: Integer;
begin
  if ((X < tpx-100)
  or  (X > tpx+(XdZ*2)+100))
  and((Y < tpy-100)
  or  (Y > tpy+(YdZ*2)+100))
  or (Part = False)
  or (BloodEnabled = False)
  then
    Exit;

  Setlength(PT, Length(PT)+Int);
  for I := 1 to Int-1 do
  begin
    PT[Length(PT)-I].X := Round(X)+Random(Size+2)-Random(Size+2);
    PT[Length(PT)-I].Y := Y+Random(Size+2)-Random(Size+2);
    PT[Length(PT)-I].g := (Random(Size*7)*0.1)-(Random(Size*7)*0.1);
    PT[Length(PT)-I].Tip := Blood;

    if Dir = 0 then
    begin
      if Random(2) = 0 then
      PT[Length(PT)-I].Dir := +1+Random(Size) else
      PT[Length(PT)-I].Dir := -1-Random(Size);
    end else
    begin
      if Random(3) = 0 then
      begin
        if Random(2) = 0 then
        PT[Length(PT)-I].Dir := +1+Random(Size) else
        PT[Length(PT)-I].Dir := -1-Random(Size);
      end else
      PT[Length(PT)-I].Dir := Dir*(4+Random(3))+Random(3)-Random(3);
    end;
  end;
end;

procedure TGame.P_Dissolve(L: Integer);
var
  I, J, C: Integer;
begin
  if  (CR[L].X > tpx-CR[L].sX-3)
  and (CR[L].X < tpx+(XdZ*2)+3)
  and (CR[L].Y > tpy-CR[L].sY-3)
  and (CR[L].Y < tpy+(YdZ*2)+3)
  and (Part) and (Quality > 1)
  then
  for C := 1 to Quality-1 do
    with CR[L] do
    for I := 1+((64-sX) div 2) + ((64-sX) mod 2)
          to 64-((64-sX) div 2) do
    for J := 1+((64-sY) div 2) + ((64-sY) mod 2)
          to 64-((64-sY) div 2) do
    try
      if (Cre[ Pic, PicIndex ].Pic[I+(J*64)] <> TransColor) then
      begin
        Setlength(PT, Length(PT)+1);
        if Dir = 1 then
          PT[Length(PT)-1].X := Round(X)+I-((64-sX) div 2)
        else
          PT[Length(PT)-1].X := Round(X)+((64-((64-sX) div 2)) div 2)-I+((64-sX) div 2);
        PT[Length(PT)-1].Y := Y+J-((64-sY) div 2);
        PT[Length(PT)-1].g := 1.5+Random(200)*0.01;
        PT[Length(PT)-1].Tip := Dissolve;
        PT[Length(PT)-1].Clr := Cre[ Pic, PicIndex ].Pic[I+(J*64)]
      end;
    except
      Continue;
    end;
end;

procedure TGame.P_Explode(X, Y: Real; Tip: ShortString);
var
  I, Int, Size: Integer;
label
  ven;
begin
  if(((X < tpx-200)
  or  (X > tpx+(XdZ*2)+200))
  and((Y < tpy-200)
  or  (Y > tpy+(YdZ*2)+200)))
  or (Part = False) then
    Exit;

  if Tip = 'Tiny' then
  begin
    Int := 25;
    Size := 6+Random(3)-Random(3);
  end else
  if Tip = 'Small' then
  begin
    Int := 75;
    Size := 7+Random(5)-Random(5);
  end else
  if Tip = 'Medium' then
  begin
    Int := 300;
    Size := 10+Random(5)-Random(5);
  end else
  if Tip = 'Large' then
  begin
    Int := 800;
    Size := 15+Random(10)-Random(10);
  end else
  if Tip = 'Huge' then
  begin
    Int := 1300;
    Size := 25+Random(15)-Random(15);
  end else
  goto Ven;

  Setlength(PT, Length(PT)+Int);
  for I := 1 to Int-1 do
  begin
    PT[Length(PT)-I].X := Round(X)+Random(Size div 2)-Random(Size div 2);
    PT[Length(PT)-I].Y := Y+Random(Size div 2)-Random(Size div 2);
    PT[Length(PT)-I].g := (Random(Size*5)*0.1)-(Random(Size*5)*0.1);
    PT[Length(PT)-I].Tip := Explosion;

    if Random(2) = 0 then
    PT[Length(PT)-I].Dir := 1+Random(Size) else
    PT[Length(PT)-I].Dir := -1-Random(Size);
  end;
  ven:
end;

//A function that tells, if a creature already ownes a weapon
function TGame.OwnedAlready(I, L: Integer): Boolean;
var
  J: Integer;
begin
  Result := False;

  if (Length(CR[L].myGunsI) > 0) then
  for J := 0 to Length(CR[L].myGunsI)-1 do
  if (CR[L].myGunsI[J].Index = I) then
  Result := True;
end;

var
  ptdelete: Integer;

procedure DeleteParticle(P: Integer);
begin
  Inc(PtDelete);
  PT[P] := PT[Length(PT)-PtDelete];
end;

//  DDDDDD
//  DD   DD            aaaaa   w           w
//  DD    DD  rr rrr  a    aa  ww         ww
//  DD    DD  rrr  r       aa  ww    w    ww
//  DD    DD  rrr      aaaaaa  ww   www   ww
//  DD   DD   rr      aa   aa   ww ww ww ww
//  DDDDDD    rr       aaaaa     www   www
procedure TGame.Draw;
var
  I, J, I2, J2, L, Lg: Integer;
  Bool: Boolean;
  R, G, B: Real;
begin
  glClear(GL_COLOR_BUFFER_BIT);
  glLoadIdentity;
//Terrain
  //Draw Polygons
    glTranslatef(-tpx, -tpy, 0);
    glCallList(PolyList);

  glEnable(GL_TEXTURE_2D);

  //Stuff on Terrain
  if Back then
    for I := 0 to StuffCount do
    with ST[I] do
    if  ((X > tpX-sX)
    and  (X < tpX+(XdZ*2)))
    and ((Y > tpY-sY)
    and  (Y < tpY+(YdZ*2))) then
    DrawTex(X-tpX, Y-tpy, Stv[pIndex].sX, Stv[pIndex].sY, 0, True, Stv[pIndex].Index);
  //end Stuff on Terrain
//end Terrain

//Creatures&Weapons
  for I2 := 0 to Length(CR)-1 do
  with CR[I2] do
  if (Dead = False) or (I2 = 0) then
  if  ((X > tpx-sX)
  and  (X < tpx+(XdZ*2)))
  and ((Y > tpy-sY)
  and  (Y < tpy+(YdZ*2))) then
  begin
  //Creatures
    if (JumpPic) and (Air)
    and (T[Round(X)+Sx div 2, Round(Y)+Sy+26]=Sky) then
    begin
      Pic := PicN+1;
      if G < -27 then Pic := PicN+2;
      if G < -34 then Pic := PicN+3;
      if G < -40 then Pic := PicN+4;

      if G > 7 then Pic := PicN+1;

      if T[Round(X)+Sx div 2, Round(Y)+350]=Dirt then Pic := PicN+3;
      if T[Round(X)+Sx div 2, Round(Y)+150]=Dirt then Pic := PicN+2;
      if T[Round(X)+Sx div 2, Round(Y)+50]=Dirt then  Pic := PicN+1;
    end;

    if myGun.Index = -1 then
    Pic2 := Pic else
    Pic2 := 1;

    //@HACK: user upper body hack
    if I2 = 0 then
    begin
      if Dir = 1 then
        DrawCRTex(X-tpX-((64-sX) / 2),
                  Y-tpy-((64-sY) / 2),
                  64, 64, 0, True,
                  Cre[ Pic2, PicIndex ].Index,
                  Cre[ Pic, PicIndex ].Index)
      else
        DrawCRTex(X-tpX-((64-sX) / 2),
                  Y-tpy-((64-sY) / 2),
                  64, 64, 0, False,
                  Cre[ Pic2, PicIndex ].Index,
                  Cre[ Pic, PicIndex ].Index);
    end else
    begin
      if Dir = 1 then
        DrawTex(X-tpX-((64-sX) / 2),
                Y-tpy-((64-sY) / 2),
                64, 64, 0, True,
                Cre[ Pic, PicIndex ].Index)
      else
        DrawTex(X-tpX-((64-sX) / 2),
                Y-tpy-((64-sY) / 2),
                64, 64, 0, False,
                Cre[ Pic, PicIndex ].Index);
    end;
  //end Creatures

    if (myGun.Index > -1) and (Length(myGunsI) > 0) then
    begin
    //Tilts the gun while reloading
      if (dotTimeSince(ClipTimer)) < (GN[myGun.Index].ClipTime) then
      R := 15 else
      R := 0;
    //Weapons
  //    if CR[I2].myGun.Index <> -1 then
      For J2 := 0 to Length(GN)-1 do
      if J2 = myGun.Index then
      if Dir = 1 then
        DrawTex(X+((sX-((sX+GN[J2].sX) div 2)))-tpx-((64-GN[J2].sX) / 2)+GN[J2].pX,
                Y+GN[J2].pY-tpy-((16-GN[J2].sY) / 2)+GunY,
                64, 16, -R, True,
                GB[J2].Index)
      else
        DrawTex(X+((sX-((sX+GN[J2].sX) div 2)))-tpx-((64-GN[J2].sX) / 2)-GN[J2].pX,
                Y+GN[J2].pY-tpy-((16-GN[J2].sY) / 2)+GunY,
                64, 16, R, False,
                GB[J2].Index);
    //end Weapons
    end;
  end;

//The weapons on the ground
  if Length(LGN) > 0 then
  For I := 0 to Length(LGN)-1 do
  if  ((LGN[I].X > tpx-GN[LGN[I].Index].sX)
  and  (LGN[I].X < tpx+(XdZ*2)))
  and ((LGN[I].Y > tpy-GN[LGN[I].Index].sY)
  and  (LGN[I].Y < tpy+(YdZ*2))) then
  if LGN[I].Dir = 1 then
    DrawTex(LGN[I].X-tpx-((64-GN[LGN[I].Index].sX) / 2),
            LGN[I].Y-tpy-((16-GN[LGN[I].Index].sY) / 2),
            64, 16, 1, True,
            GB[LGN[I].Index].Index)
  else
    DrawTex(LGN[I].X-tpx-((64-GN[LGN[I].Index].sX) / 2),
            LGN[I].Y-tpy-((16-GN[LGN[I].Index].sY) / 2),
            64, 16, 1, False,
            GB[LGN[I].Index].Index);

//end Creatures&Weapons
  glFinish;
  glDisable(GL_TEXTURE_2D);

//*  _____     __  *   _____ * ________* __   *____ *__   * _____ *______ *    *
//  *][I][_ * _[]_     ][I][_  ]IIIIII[  ][ * _]II[  ][     ]III[  ]IIII[
//*  ][__][  _][][_  * ][__][     ][     ][  _][     ][ *   ][__*  ][___  *  *
//   ][II[  _][__][_   ][I][   *  ][   * ][  ][_ *   ][ *   ]II[    ]II[_
// * ][  *  ]IIIIII[   ][ ][_     ][ *   ][   ][___* ][__ * ][___ * ___I[  *    *
//  *][ *   ][ *  ][ * ][  ][ *   ][    *][  * ]II[ *]III[  ]III[  ]IIII[ *
  if (Part) then
  begin
    if (Length(PT) > 0) then
    begin
      PtDelete := 0;
      for I := 0 to Length(PT)-1 do
      With PT[I] do
      begin
      //Calculate
        Case Tip of
        Blood:
          begin
            X := X+Dir;
            Y := Y+g;
            g := g+(Random(15)*0.1);
          end;
        Bullet:
          if Random(15) = 0 then
            X := 0//Deletes the particle
          else
          begin
            if Random(10) = 0 then
              g := -g;

            if Random(2) = 0 then
            begin
              if g < 0 then
                g := g-0.01-0.001*Random(150)
              else
                g := g+0.01+0.001*Random(150);

              Y := Y+g+(Random(2)-Random(4))*0.2;
            end;
            X := X+Dir*Random(5)-1;
            Clr := Clr+Random(50);
          end;
        Explosion:
          if (Random(6) = 0) then
            X := 0//Deletes the particle
          else
          begin
            X := X+Dir;
            Y := Y+g;
            g := g+(Random(15)*0.1)-(Random(15)*0.1);
            if Random(25) = 0 then
            g := -g*5;
          end;
        Dissolve:
          begin
            g := g + 1 + Random(2);

            Y := Y + g;
            if (Random(10) = 0) then
            X := Random(2)-Random(2);
          end;
        end;
        //end Calculate

        if I > Length(PT)-PtDelete then
        Break;

        if (X <= 2)
        or (Y <= 2)
        or (X >= tx)
        or (Y >= ty)
        or (X < tpx-20)
        or (X > tpx+(XdZ*2)+20)
        or (((Y < tpy-20)
        or   (Y > tpy+(YdZ*2)+20))
        and (Random(7) = 0)
        and (Length(PT) > 1500))
        or (T[Round(X), Round(Y)]=Dirt) then
        begin
          DeleteParticle(I);
          Continue;
        end;

      //Draw
        glBegin(GL_POINTS);
        if ((X > tpx)
        and (X < tpx+(XdZ*2)))
        and((Y > tpy)
        and (Y < tpy+(YdZ*2)))
        then
        begin
          J := Random(150)+50;

          Case Tip of
            Blood: glColor4f( 1-Random(J)*0.002, Random(J)*0.002, Random(J)*0.002, 0);
            Bullet: if Random(2)=0 then
                 glColor4f((Rs*Clr+(0.1+0.1*Random(5))*J) / (Clr+J),
                           (Gs*Clr+(0.1+0.1*Random(5))*J) / (Clr+J),
                           (Bs*Clr+(0.1+0.1*Random(5))*J) / (Clr+J), 0)
                 else
                 glColor4f((Rs*Clr+0.4*J) / (Clr+J),
                           (Gs*Clr+0.4*J) / (Clr+J),
                           (Bs*Clr+0.4*J) / (Clr+J), 0);
            Explosion:
              begin
                if Random(2) = 1 then
                  glColor4f(1-Random(5)*0.1,
                              Random(5)*0.1,
                              Random(5)*0.1, 0) else
                if Random(2) = 1 then
                  glColor4f(J*0.01+Random(5)*0.1-Random(5)*0.1,
                            J*0.01+Random(5)*0.1-Random(5)*0.1,
                            Random(4)*0.1, 0)
                else
                  if Random(2) = 1 then
                  glColor4f(J*0.001, J*0.001, J*0.001, 0);
              end;
            Dissolve:
              begin
                R := (Clr mod $100)           / $FF;
                G := ((Clr div $100) mod $100) / $FF;
                B := (Clr div $10000)         / $FF;
                I2 := Random(10);
                J := Random(5);
                glColor4f( (R*I2+Rs*J)/(I2+J),
                           (G*I2+Gs*J)/(I2+J),
                           (B*I2+Bs*J)/(I2+J), 0);
              end;
          end;
          glVertex2f( X-tpx, Y-tpy );
        end;
        glEnd();
      //end Draw
      end;
      if PtDelete > 0 then
      try
        Setlength(PT, Length(PT)-PtDelete);
      except
        Setlength(PT, 0);
      end;
    end;
  //Snow
    if WeatherType = 1 then
    begin
      glBegin(GL_POINTS);
      glColor4f(1,1,1,0);
      J := 0;
      for I := 0 to Length(Weather)-1 do
      with Weather[I] do
      begin
      //Calculates&Draws the snow
        //Draws the "trail"
        if Dir > 0 then
        begin
          if (Quality >= Medium)
          and (X > tpx)
          and (X < tpx+(XdZ*2))
          and (Y > tpy)
          and (Y < tpy+(YdZ*2))
          then
          begin
            glColor4f((1+Rs)/2,(1+Gs)/2,(1+Bs)/2, 0);
            glVertex2f(X-tpx, Y-tpy);
            glColor4f(1,1,1,0);
          end;

          //Drops snow
          if (T[X,Y+Dir]=Sky) or (T[X,Y+Random(Dir)]=Sky) then
          begin
            if (Random(2) = 0) then
            X := X+Random(Wind+1)-1 else
            if (Random(2) = 0) then
            X := X+Random(2)-Random(2);

            Y := Y+Dir+Random(2);
          end;

          //Draws snow and tells how much is there in the sky
          if (T[X,Y]=Sky) then
            Inc(J)
          else
          begin
            Dir := 0;
            if random(5)=0 then
            Y := Y+Random(4)-1;
          end;
        end;

        if  (X > tpx)
        and (X < tpx+(XdZ*2))
        and (Y > tpy)
        and (Y < tpy+(YdZ*2))
        then
          glVertex2f(X-tpx, Y-tpy);
      end;

      //Deletes the duplicated snowflakes - and a lot of them...
//      if (Length(Weather) >= MaxWeather-(MaxWeather div 10)-Random(MaxWeather div 5)) then
      for L := 0 to 75 do
      begin
        I2 := 0;
        repeat
          J2 := Random(Length(Weather));
        until Weather[J2].Dir = 0;

        for I := 0 to Length(Weather)-1 do
        with Weather[I] do
        if Dir = 0 then
          if  (X = Weather[J2].X)
          and (Y = Weather[J2].Y)
          and (I <> J2) then
          begin
            Weather[I] := Weather[Length(Weather)-1];
            repeat
              J2 := Random(Length(Weather));
            until Weather[J2].Dir = 0;
            Inc(I2);
          end;
        SetLength(Weather, Length(Weather)-I2);
      end;

      //Makes sure there is enough snow in the sky
      if (J < WeatherInTheSky) then
      begin
        if (Length(Weather)+(WeatherInTheSky-J) < MaxWeather) then
          L := WeatherInTheSky-J
        else
          L := MaxWeather-Length(Weather);

        SetLength(Weather, Length(Weather)+L);
        for I := Length(Weather)-L-1 to Length(Weather)-1 do
        with Weather[I] do
        begin
          repeat
            X := Random(tX);
            Y := Random(tY);
          until (T[X,Y]=Sky);
          Dir := Random(5)+1;
        end;
      end;
      glEnd();
    end;
  end;
//end Particles

//PowerMeter
  glBegin(GL_QUADS);
    if CR[0].Pwr <> CR[0].OrgPwr then
    begin
      glColor4f(0, 0.5, 0, 0);
      glVertex2f(10+(CR[0].Pwr / 4),    10);
      glVertex2f(10+(CR[0].Pwr / 4),    20);
      glVertex2f(10+(CR[0].OrgPwr / 4), 20);
      glVertex2f(10+(CR[0].OrgPwr / 4), 10);
    end;
    glColor4f(1, 0, 0, 0);
    glVertex2f(10, 10);
    glVertex2f(10, 20);
    glColor4f(0, 1, 0, 0);
    glVertex2f(10+(CR[0].Pwr / 4), 20);
    glVertex2f(10+(CR[0].Pwr / 4), 10);
  glEnd();
//end PowerMeter

  glEnable(GL_TEXTURE_2D);
  Text(Round(CR[0].OrgPwr / 4)+30, 5, 'Kills:'+IntToStr(CR[0].Kills)+'   Deaths:'+IntToStr(CR[0].Deaths), 20);

  if (CR[0].myGun.Index > -1) and (Length(CR[0].myGunsI) > 0) then
  begin
    Text(10, 30, GN[CR[0].myGun.Index].Tip, 20);

    if (dotTimeSince(CR[0].ClipTimer) < GN[CR[0].myGun.Index].ClipTime) then
      Text(10, 55, 'Reloading', 16);
  end;

  if Pause then
    Text(XdZ-(64 div 2)*Length('PAUSED'), YdZ-(64 div 2), 'PAUSED', 64);

  if CR[0].Dead then
    Text(XdZ-(100 div 2)*Length('DEAD'), YdZ-(100 div 2), 'DEAD', 100);

//  Text(0, 350, IntToStr(Length(LGN)), 32);
//  J := 0;
//  if (CR[0].myGun <> -1) and (Length(CR[0].myGunsI) > 0) then
//  for I := 0 to Length(CR)-1 do
//  J := J + Length(CR[I].myGunsI);
//  Text(0, 400, IntToStr(J), 32);
//  Text(0, 450, IntToStr(J+Length(LGN)), 32);

  if GameOver then
  begin
    if MapCnt >= Length(Maps) then
      Text(XdZ-(85 div 2)*Length('GAME OVER'), YdZ-(85 div 2), 'GAME OVER', 85)
    else
      Text(XdZ-(60 div 2)*Length('STAGE CLEARED'), YdZ-(60 div 2), 'STAGE CLEARED', 60);
  end;

//  Text(0, 300, IntToStr(Round(FPSDisp)), 64);
//  Text(0, 370, IntToStr(FPSundercount), 64);
//  Text(0, 450, IntToStr(Length(PT)), 64);
  glDisable(GL_TEXTURE_2D);

  SwapBuffers(DC);
  //Context.PageFlip;
  if GameOver then
  Sleep(1500);
end;


//Read this function at your own risk... its UGLY, non-commented, and tottaly random
procedure TGame.CreatureAI(var C: RCreature; Tg: RCreature);
var               //Creature, its target
  I, J: Integer;
label
  Up;
begin
  With C do
  try

  //The cheapest AI - not used
(*  if AITip = 'Dumberer' then
  if Random(AiL*3) = 0 then
    if (X = eX)
    and (Random(3) = 0) then
    begin
      if Random(2) = 0 then
      Act := 'Right' else
      Act := 'Left';
    end else
    if Random(AiL*4) = 0 then
    begin
      if Random(2) = 0 then
      Act := 'Right' else
      Act := 'Left';
    end else
    if (Tg.X > X) then
    Act := 'Right' else
    Act := 'Left';*)

  try
  //the new ai
  if AITip = 'Dumberer' then
  if Random(5)=0 then
  begin
    if Act <> 'Walk' then Act := '';

    if  (abs(Y-tg.Y) < 30+Random(18))
    and (abs(X-tg.X) < XdZ+Random(20))
    and (myGun.Index <> -1)
    and (Random(5)=0) then
    begin
      Act := 'Shoot';
      if tg.X > X then Dir := 1 else Dir := -1;
    end else
    if  (X>30)
    and (T[Trunc(X-Random(15)), Trunc(Y+(sY/1.5))]=Dirt) and (T[Trunc(X-Random(30)), Trunc(Y)]=Sky)
    and (Air = False)
    and (Random(8)=0) then
    begin
      Act := 'Jump';
      Dir := -1;
    end else
    if  (X>30)
    and  (T[Trunc(X+Random(15)), Trunc(Y+(sY/1.5))]=Dirt) and (T[Trunc(X+Random(30)), Trunc(Y)]=Sky)
    and (Air = False)
    and (Random(8)=0) then
    begin
      Act := 'Jump';
      Dir := +1;
    end else
    if ((X > (Spd*2) div 4) and (Y > 15) and (X > 50))
    and ((T[Trunc(X-Random((Spd*2) div 4)), Trunc(Y-Random(15))]=Dirt)
    or  (T[Trunc(X-Random((Spd*2) div 4)), Trunc(Y+(sY/2))]=Dirt)
    or  (T[Trunc(X-Random((Spd*2) div 4)), Trunc(Y+sY)]=Dirt))
    and (T[Trunc(X-Random(40)), Trunc(Y+sY)]=Sky)
    and (T[Trunc(X-Random(50)), Trunc(Y+(sY/2))]=Sky)
    and (Air = False)
    and (Random(4)=0) then
    begin
      Act := 'Jump';
      Dir := -1;
    end else
    if ((X > (Spd*2) div 4) and (Y > 15) and (X > 50))
    and ((T[Trunc(X+sX+Random((Spd*2) div 4)), Trunc(Y-Random(15))]=Dirt)
    or  (T[Trunc(X+sX+Random((Spd*2) div 4)), Trunc(Y+(sY/2))]=Dirt)
    or  (T[Trunc(X+sX+Random((Spd*2) div 4)), Trunc(Y+sY)]=Dirt))
    and (T[Trunc(X+sX+Random(40)), Trunc(Y+sY)]=Sky)
    and (T[Trunc(X+sX+Random(50)), Trunc(Y+(sY/2))]=Sky)
    and (Air = False)
    and (Random(4)=0) then
    begin
      Act := 'Jump';
      Dir := 1;
    end else
    if  (abs(Y-tg.Y) > 150)
    and (((Random(5)=0)
    and  (X > tX/15)
    and  (X < (14*tX)/15))
    or  ((Random(7)=0)
    and  (X > tX/10)
    and  (X < (9*tX)/10))
    or  ((Random(15)=0)
    and  (X > tX/7)
    and  (X < (6*tX)/7)))
    then
    begin
      if X < tX/3 then
        Dir := -1
      else if X > (2*tX)/3 then
        Dir := 1;

      if Random(30) = 0 then
        Act := 'Jump'
      else
        Act := 'Walk';
    end else
    if (abs(X-eX) = 0)
    and (Air = False)
    and (Random(3)=0) then
    begin
      if Random(3)=0 then
        Act := 'Jump';
      if Random(4)=0 then
        Dir := -Dir;
    end else
    if (abs(X-eX) < 3)
    and (Air = False)
    and (Random(5)=0) then
    begin
      if Random(4)=0 then
        Act := 'Jump';
      if Random(2)=0 then
        Dir := -Dir;
    end else
    if (X > tg.X)
    and (Random(2)=0) then
      Dir := -1
    else
    if (X < tg.X)
    and (Random(2)=0) then
      Dir := 1;

    if (Act = '')
    or (Random(70)=0) then
    begin
      Act := 'Walk';

(*      if (X > tg.X) then
        Dir := -1
      else
      if (X < tg.X) then
        Dir := 1;*)
    end;
  end;
  except
  end;


  //The cheaper AI
  if AITip = 'Dumber' then
  if Random(AiL*3) = 0 then
    if (Random(AiL) = 0)
    and (X < Random(250)) then
    begin
      Act := 'Walk';
      Dir := 1;
    end else
    if (Random(AiL) = 0)
    and (X > tx-Random(250)) then
    begin
      Act := 'Walk';
      Dir := -1;
    end else
    if (X>25) and (Y > 100)
    and(((T[Round(X+25), Round(Y-99)]=Sky) and (T[Round(X+25), Round(Y-90)]=Dirt))
    or  ((T[Round(X+25), Round(Y-90)]=Sky) and (T[Round(X+25), Round(Y-80)]=Dirt))
    or  ((T[Round(X+20), Round(Y-80)]=Sky) and (T[Round(X+20), Round(Y-70)]=Dirt))
    or  ((T[Round(X+20), Round(Y-70)]=Sky) and (T[Round(X+20), Round(Y-60)]=Dirt))
    or  ((T[Round(X+20), Round(Y-60)]=Sky) and (T[Round(X+20), Round(Y-50)]=Dirt))
    or  ((T[Round(X+20), Round(Y-50)]=Sky) and (T[Round(X+20), Round(Y-40)]=Dirt))
    or  ((T[Round(X+20), Round(Y-40)]=Sky) and (T[Round(X+20), Round(Y-30)]=Dirt)))
    and (Tg.Y+50 < Y)
    and (Act = 'Walk')
    and (Air = False) then
    begin
      Act := 'Jump';
      if Random(2) = 0 then
        Dir := 1
      else
        Dir := -1;
    end else
    if (X > 26) and (Y > 100) then
    if (((T[Round(X-25), Round(Y-99)]=Sky) and (T[Round(X-25), Round(Y-90)]=Dirt))
    or  ((T[Round(X-25), Round(Y-90)]=Sky) and (T[Round(X-25), Round(Y-80)]=Dirt))
    or  ((T[Round(X-20), Round(Y-80)]=Sky) and (T[Round(X-20), Round(Y-70)]=Dirt))
    or  ((T[Round(X-20), Round(Y-70)]=Sky) and (T[Round(X-20), Round(Y-60)]=Dirt))
    or  ((T[Round(X-20), Round(Y-60)]=Sky) and (T[Round(X-20), Round(Y-50)]=Dirt))
    or  ((T[Round(X-20), Round(Y-50)]=Sky) and (T[Round(X-20), Round(Y-40)]=Dirt))
    or  ((T[Round(X-20), Round(Y-40)]=Sky) and (T[Round(X-20), Round(Y-30)]=Dirt)))
    and (Act = 'Walk')
    and (Tg.Y+50 < Y)
    and (Air = False) then
    begin
      Act := 'Jump';
      if Random(2) = 0 then
        Dir := 1
      else
        Dir := -1;
    end else
    if (Random(AiL*7) = 0)
    and (myGun.Index <> -1) then
    Act := 'Shoot' else
    if (X = eX)
    and (Random(3) = 0) then
    begin
      if (Tg.X > X) then
      begin
        if (Air = False) then
        Act := 'Jump';

        if Random(2) = 0 then
          Dir := 1
        else
          Dir := -1;
      end else
      begin
        if (Air = False) then
        Act := 'Jump';

        if Random(2) = 0 then
          Dir := 1
        else
          Dir := -1;
      end;
    end else
    if (X > 40) then
    if  ((T[Round(X-15), Round(Y+20)]=Sky) and (T[Round(X-40), Round(Y+20)]=Dirt))
    and (Act = 'Walk')
    and (Tg.Y+50 < Y)
    and (Air = False) then
    begin
      Act := 'Jump';
      Dir := -1;
    end else
    if  ((T[Round(X+15), Round(Y+20)]=Sky) and (T[Round(X+40), Round(Y+20)]=Dirt))
    and (Act = 'Walk')
    and (Tg.Y+50 < Y)
    and (Air = False) then
    begin
      Act := 'Jump';
      Dir := 1;
    end else
    if (Random(AiL*2) = 0)
    and (myGun.Index <> -1) then
    begin
      Repeat
        TgIndex := Random(Length(CR));
      Until (CR[TgIndex].Name <> Name);

        if X < CR[TgIndex].X then Dir := +1 else
        if X > CR[TgIndex].X then Dir := -1;
    end else
    if Random(AiL*4) = 0 then
    begin
        Act := 'Walk';
      if Random(2) = 0 then
        Dir := 1
      else
        Dir := -1;
    end else
    if (Tg.X > X) then
    begin
        Act := 'Walk';
      if Random(2) = 0 then
        Dir := 1
      else
        Dir := -1;
    end;

  //The little better AI
  if  (AITip = 'Dumb')
  and (Random(AiL*2) = 0) then
    if (Random(AiL*4) = 0)
    and (X < Random(150)) then
    begin
      Act := 'Walk';
      Dir := 1;
    end else
    if (Random(AiL*4) = 0)
    and (X > tx-Random(150)) then
    begin
      Act := 'Walk';
      Dir := -1;
    end else
    if (Random(AiL*10) = 0)
    and (myGun.Index <> -1) then
    Act := 'Shoot' else
    if (Random(AiL*7) = 0) then
    Act := 'Jump' else
    if (Tg.Y+sY < Y)
    and (Air = False)
    and (Random(AiL) = 0) then
    begin
      For I := Round(X-50) to Round(X+sX+50) do
      For J := Round(Y-150) to Round(Y) do
      if (X > 52) and (Y > 152)
      and (X < tx-sx-52) and (Y < ty) then
      if  (T[I, J]=Sky)
      and (T[I-1, J+1]=Dirt)
      and (T[I-1, J+2]=Dirt)
      and (T[I-5, J+1]=Dirt)
      and (T[I-5, J+2]=Dirt)
      and (T[I, J+1]=Dirt)
      and (T[I, J+2]=Dirt)
      and (T[I+1, J+1]=Sky)
      and (T[I+1, J+2]=Sky)
      and (T[I+5, J+1]=Sky)
      and (T[I+5, J+2]=Sky)
      then
      begin
        Act := 'Jump';

        if I > X+sX then
        begin
          Act := 'Walk';
          Dir := 1;
        end else
        if I < X then
        begin
          Act := 'Walk';
          Dir := -1;
        end else
        if Random(2) = 0 then
        begin
            Act := 'Walk';
          if Random(2) = 0 then
            Dir := 1
          else
            Dir := -1;
        end;
      end;
    end else
    if (Random(AiL*2) = 0)
    and (myGun.Index <> -1) then
    begin
      if X < CR[TgIndex].X then Dir := +1 else
      if X > CR[TgIndex].X then Dir := -1;
      if  (X < CR[TgIndex].X+1000)
      and (X > CR[TgIndex].X-1000)
      and (Y < CR[TgIndex].Y+300)
      and (Y > CR[TgIndex].Y-300)
      then
      Act := 'Shoot';
    end else
    if ((X = eX) and (Act <> 'Shoot') and (Random(AiL) = 0))
    or ((X = eX) and (Act = 'Shoot') and (Random(AiL*6) = 0)) then
    begin
      if (Tg.X > X) then
      begin
        if (Air = False) then
        Act := 'Jump';

        if Random(2) = 0 then
          Dir := -1
        else
          Dir := +1;
      end else
      begin
        if (Air = False) then
        Act := 'Jump';

        if Random(2) = 0 then
          Dir := -1
        else
          Dir := +1;
      end;
    end else
    if  ((T[Round(X+15), Round(Y+20)]=Sky) and (T[Round(X+40), Round(Y+20)]=Dirt))
    and (Act = 'Walk')
    and (Tg.Y+50 < Y)
    and (Air = False) then
    begin
      Act := 'Jump';
      Dir := +1;
    end else
    if  (X > 50) and (Y > 75) then
    if  ((T[Round(X-15), Round(Y+20)]=Sky) and (T[Round(X-40), Round(Y+20)]=Dirt))
    and (Act = 'Walk')
    and (Tg.Y+50 < Y)
    and (Air = False) then
    begin
      Act := 'Jump';
      Dir := -1;
    end else
    if Random(AiL*3) = 0 then
    begin
      if Random(2) = 0 then
      begin
          Act := 'Walk';
        if Random(2) = 0 then
          Dir := 1
        else
          Dir := -1;
      end;
    end else
    if (Tg.X > X) then
    begin
        Act := 'Walk';
      if Random(2) = 0 then
        Dir := 1
      else
        Dir := -1;
    end;

  if (Random(AiL*5) = 0)
  and (HitBy <> 0) then
  begin
    TgIndex := HitBy;
    HitBy := 0;
    if X < CR[TgIndex].X then Dir := +1 else
    if X > CR[TgIndex].X then Dir := -1;
    Act := 'Shoot';
  end;

  if (Act = 'Shoot') and (Random(AiL*3) = 0) then
  begin
    if X < CR[TgIndex].X then Dir := +1 else
    if X > CR[TgIndex].X then Dir := -1;
  end else

  if Act = 'Jump' then
  begin
    g := 15;
    Y := Y - Round(g);
    Air := True;
    Act := 'Walk';
  end;
  eX := X;

  if (dotTimeSince(DeadT) < 7000)
  and (Act = 'Shoot') then
    Act := 'Walk';

  except

  end;//With C

  //Result := C;
end;

//One of the main procedures in this game... calculates movement, collision detection, gravity
procedure TGame.Calculate;
var
  I, I2, J, J2, LGCnt, Counter, LG, X, Y, L: Integer;
  bool: Boolean;
label
  GoOut;
begin//Calculate
//Gun Calculate
  if Length(LGN) > 0 then
  For L := 0 to Length(LGN)-1 do
  With GN[LGN[L].Index] do
  if (LGN[L].Air) then
  begin
    X := LGN[L].X;
    Y := LGN[L].Y;

    if (T[ X, Y] = False)
    or (T[ X, Y+(sY div 4)] = False)
    or (T[ X, Y+(sY div 2)] = False)
    or (T[ X, Y+(sY div 2)+(sY div 4)] = False)
    then
    repeat
      X := X + 1;
    until (T[ X, Y])
      and (T[ X, Y+(sY div 4)])
      and (T[ X, Y+(sY div 2)])
      and (T[ X, Y+(sY div 2)+(sY div 4)]);

    if (T[ X+sX, Y] = False)
    or (T[ X+sX, Y+(sY div 4)] = False)
    or (T[ X+sX, Y+(sY div 2)] = False)
    or (T[ X+sX, Y+(sY div 2)+(sY div 4)] = False)
    then
    repeat
      X := X - 1;
    until (T[ X+sX, Y])
      and (T[ X+sX, Y+(sY div 4)])
      and (T[ X+sX, Y+(sY div 2)])
      and (T[ X+sX, Y+(sY div 2)+(sY div 4)]);

    if (T[ X,                                         Y+sY] = False)
    or (T[ X+(sX div 4),                     Y+sY] = False)
    or (T[ X+(sX div 2),                     Y+sY] = False)
    or (T[ X+(sX div 2)+(sX div 4), Y+sY] = False)
    or (T[ X+sX,                             Y+sY] = False)
    then
    repeat
      Y := Y - 1;
      LGN[L].Air := False;

      if  (T[ X,                       Y+sY])
      and (T[ X+(sX div 4),            Y+sY])
      and (T[ X+(sX div 2),            Y+sY])
      and (T[ X+(sX div 2)+(sX div 4), Y+sY])
      and (T[ X+(sX),                  Y+sY])
      then LGN[L].Air := True;
    until (T[ X,                       Y+sY])
      and (T[ X+(sX div 4),            Y+sY])
      and (T[ X+(sX div 2),            Y+sY])
      and (T[ X+(sX div 2)+(sX div 4), Y+sY])
      and (T[ X+sX,                    Y+sY]);

    if ((T[ X,                       Y+sY])
    or  (T[ X+(sX div 4),            Y+sY])
    or  (T[ X+(sX div 2),            Y+sY])
    or  (T[ X+(sX div 2)+(sX div 4), Y+sY])
    or  (T[ X+(sX),                  Y+sY]))
    then
    begin
      LGN[L].g := LGN[L].g - 2;
      Y := Y - LGN[L].g;
    end;

    if (T[ X,                       Y+sY] = False)
    or (T[ X+(sX div 4),            Y+sY] = False)
    or (T[ X+(sX div 2),            Y+sY] = False)
    or (T[ X+(sX div 2)+(sX div 4), Y+sY] = False)
    or (T[ X+sX,                    Y+sY] = False)
    then
    repeat
      Y := Y - 1;
      LGN[L].Air := False;
    until (T[ X,                       Y+sY])
      and (T[ X+(sX div 4),            Y+sY])
      and (T[ X+(sX div 2),            Y+sY])
      and (T[ X+(sX div 2)+(sX div 4), Y+sY])
      and (T[ X+sX,                    Y+sY]);

    For I := X to X+sX do
    if (T[ I, Y+sY] = False) then
    begin
      LGN[L].g := 0;
      LGN[L].Air := False;
    end;

    LGN[L].X := X;
    LGN[L].Y := Y;
  end;
//end Gun Calculate

//Kreature Calculate
  For L := 0 to Length(CR)-1 do
  if CR[L].Dead = False then
  begin
    try
      if (CR[CR[L].TgIndex].Dead)
      or ((CR[L].TgIndex <> 0)
      and (Random(75) = 0)) then
      Repeat
        CR[L].TgIndex := Random(Length(CR));
      Until (CR[CR[L].TgIndex].Name <> CR[L].Name)
        and (CR[CR[L].TgIndex].Dead = False);

      if (CR[L].Pwr > 0) and (CR[L].Dead = False) then
      begin

        if (Loading = False) then
        begin
          //Weapon pick up routine
          if  (Length(LGN) > 0)
          and (Length(CR[L].myGunsI) < Length(GN)) then
          repeat
            bool := False;

            Lg := 0;
            for I := 0 to Length(LGN)-1 do
            if  (abs(CR[L].X-LGN[I].X) < CR[L].sX+GN[LGN[I].Index].sX)
            and (abs(CR[L].Y-LGN[I].Y) < CR[L].sY+GN[LGN[I].Index].sY) then //fast check if the gun is even close to the creature
            if (OwnedAlready(LGN[I].Index, L) = False) then //and if its already owned by the creature
            if ((CR[L].X          < LGN[I].X) //then the slow check
            and (CR[L].X+CR[L].sX > LGN[I].X)
            and (CR[L].Y          < LGN[I].Y)
            and (CR[L].Y+CR[L].sY > LGN[I].Y))
            or ((CR[L].X          > LGN[I].X)
            and (CR[L].X+CR[L].sX < LGN[I].X)
            and (CR[L].Y          > LGN[I].Y)
            and (CR[L].Y+CR[L].sY < LGN[I].Y))
            or ((CR[L].X          < LGN[I].X+GN[LGN[I].Index].sX)
            and (CR[L].X+CR[L].sX > LGN[I].X+GN[LGN[I].Index].sX)
            and (CR[L].Y          < LGN[I].Y+GN[LGN[I].Index].sY)
            and (CR[L].Y+CR[L].sY > LGN[I].Y+GN[LGN[I].Index].sY))
            or ((CR[L].X          > LGN[I].X+GN[LGN[I].Index].sX)
            and (CR[L].X+CR[L].sX < LGN[I].X+GN[LGN[I].Index].sX)
            and (CR[L].Y          > LGN[I].Y+GN[LGN[I].Index].sY)
            and (CR[L].Y+CR[L].sY < LGN[I].Y+GN[LGN[I].Index].sY))
            or ((CR[L].X          < LGN[I].X+(GN[LGN[I].Index].sX div 2))
            and (CR[L].X+CR[L].sX > LGN[I].X+(GN[LGN[I].Index].sX div 2))
            and (CR[L].Y          < LGN[I].Y+(GN[LGN[I].Index].sY div 2))
            and (CR[L].Y+CR[L].sY > LGN[I].Y+(GN[LGN[I].Index].sY div 2)))
            or ((CR[L].X          > LGN[I].X+(GN[LGN[I].Index].sX div 2))
            and (CR[L].X+CR[L].sX < LGN[I].X+(GN[LGN[I].Index].sX div 2))
            and (CR[L].Y          > LGN[I].Y+(GN[LGN[I].Index].sY div 2))
            and (CR[L].Y+CR[L].sY < LGN[I].Y+(GN[LGN[I].Index].sY div 2)))
            then
            with CR[L] do
            begin
              SetLength(myGunsI, Length(myGunsI)+1);
              myGunsI[Length(myGunsI)-1].Index := LGN[I].Index;
              myGunsI[Length(myGunsI)-1].Clip := GN[LGN[I].Index].ClipSize;

              ShootI := dotTime;
              //@TODO move this bit to AI probably
              if  ((Name <> 'User')
              and (Random(15) = 0))
              or (myGun.Index = -1) then
                myGun := myGunsI[Length(myGunsI)-1];

              if Length(myGunsI) > 1 then
              for J2 := 0 to Length(myGunsI)*2 do
              for J := 0 to Length(myGunsI)-2 do
              if MyGunsI[J].Index > MyGunsI[J+1].Index then
              begin
                I2 := MyGunsI[J].Index;
                MyGunsI[J].Index := MyGunsI[J+1].Index;
                MyGunsI[J+1].Index := I2;
              end;

              LGN[I] := LGN[Length(LGN)-1-Lg];
              Inc(Lg);
              bool := True;
            end;

           if bool then
           SetLength(LGN, Length(LGN)-Lg);
         until bool = False;

        //Weapon Shooting
          if (Length(CR[L].myGunsI) > 0) and (CR[L].myGun.Index > -1) then
          if (((KP and (CR[L].Act = 'Shoot')) or (MP and (CR[L].ActM = 'Shoot'))) and (CR[L].Name = 'User'))
          or (((CR[L].Act = 'Shoot') and (CR[L].Name <> 'User'))) then
          if (dotTimeSince(CR[L].ClipTimer)) > (GN[CR[L].myGun.Index].ClipTime) then
          if (dotTimeSince(CR[L].ShootI)) > ((GN[CR[L].myGun.Index].Interval)+Random(GN[CR[L].myGun.Index].Interval div 4)-Random(GN[CR[L].myGun.Index].Interval div 4)) then
          begin
            if GN[CR[L].myGun.Index].TT = 'ShotGun' then
            begin
              for I := 0 to 5+Random(5) do
              begin
                SetLength(BL, Length(BL)+1);
                With BL[Length(BL)-1] do
                begin
                  Typ := GN[CR[L].myGun.Index].Tip;
                  Dir := CR[L].Dir;
                  Case CR[L].Dir of
                   +1: X := Round(CR[L].X)+GN[CR[L].myGun.Index].sX;
                   -1: X := Round(CR[L].X)+CR[L].sX-GN[CR[L].myGun.Index].sX;
                  end;
                  Y := Round(CR[L].Y)+GN[CR[L].myGun.Index].pY+(GN[CR[L].myGun.Index].sY div 2)+Random(3)-Random(3);
                  Owner.Name := CR[L].Name;
                  Owner.Index := CR[L].Index;
                  Owner.HisGun := CR[L].myGun;
                  Dmg := GN[CR[L].myGun.Index].Dmg div 5;
                  TT := GN[CR[L].myGun.Index].TT;
                  ET := GN[CR[L].myGun.Index].ET;
                  DirY := I-Random(8);
                  CR[L].ShootI := dotTime;
                end;
              end;
              Dec(CR[L].myGun.Clip);
              if (CR[L].myGun.Clip <= 0) then
              begin
                CR[L].ClipTimer := dotTime;
                CR[L].myGun.Clip := GN[CR[L].myGun.Index].ClipSize;
              end;
            end else
            begin
              SetLength(BL, Length(BL)+1);
              With BL[Length(BL)-1] do
              begin
                Typ := GN[CR[L].myGun.Index].Tip;
                Dir := CR[L].Dir;
                Case CR[L].Dir of
                 +1: X := Round(CR[L].X)+GN[CR[L].myGun.Index].sX;
                 -1: X := Round(CR[L].X)+CR[L].sX-GN[CR[L].myGun.Index].sX;
                end;
                Y := Round(CR[L].Y)+GN[CR[L].myGun.Index].pY+(GN[CR[L].myGun.Index].sY div 2)+Random(3)-Random(3);
                Owner.Name := CR[L].Name;
                Owner.Index:= CR[L].Index;
                Owner.HisGun := CR[L].myGun;
                Dmg := GN[CR[L].myGun.Index].Dmg;
                TT := GN[CR[L].myGun.Index].TT;
                ET := GN[CR[L].myGun.Index].ET;
                CR[L].ShootI := dotTime;

                Dec(CR[L].myGun.Clip);
                if (CR[L].myGun.Clip <= 0) then
                begin
                  CR[L].ClipTimer := dotTime;
                  CR[L].myGun.Clip := GN[CR[L].myGun.Index].ClipSize;
                end;
              end;
            end;
          end;
        //end Weapon Shooting

        //Moving
          if (dotTimeSince(CR[L].PicT) > CR[L].PicInt)
          and (CR[L].PicShowStyle = 1) then
          begin
            CR[L].PicT := dotTime;

            if CR[L].Pic >= CR[L].PicN then
            CR[L].Pic := 0;

            Inc(CR[L].Pic);
          end else
          if (dotTimeSince(CR[L].PicT) > CR[L].PicInt)
          and (CR[L].Spd > 5)
          then
          begin
            CR[L].PicT := dotTime;

            Inc(CR[L].Pic);
            if CR[L].Pic >= CR[L].PicN then
            CR[L].Pic := 1;

            if (CR[L].Spd < 5)
            and (CR[L].PicShowStyle = 0) then
            CR[L].Pic := 1;
          end else
          if (CR[L].Spd < 5)
          and (CR[L].Pic <> CR[L].MainPic) then
          begin
            CR[L].Pic := CR[L].MainPic;
          end;

          if (CR[L].Act = 'Walk') then
          with CR[L] do
          begin
            X := X + (Spd*0.04)*Dir;
          end else if (CR[L].Name = 'User') then
            CR[L].Spd := 0;
        //end Moving
      end;//not Loading

      //Terrain collision-detection
        X := Round(CR[L].X);
        Y := Round(CR[L].Y);

        for I := 1 to 25 do
        begin
          if (T[ X+(CR[L].sX)+1, Y] = False)
          or (T[ X+(CR[L].sX)+1, Y+(CR[L].sY div 4)] = False)
          or (T[ X+(CR[L].sX)+1, Y+(CR[L].sY div 2)] = False)
          then
          X := X-1;

          if (T[ X-1, Y] = False)
          or (T[ X-1, Y+(CR[L].sY div 4)] = False)
          or (T[ X-1, Y+(CR[L].sY div 2)] = False)
          then
          X := X+1;

          if (T[ X+((CR[L].sX) div 2), Y] = False) then
          Y := Y+1;
        end;

        Counter := 0;
        if (T[ X,                                       Y+CR[L].sY] = False)
        or (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY] = False)
        or (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY] = False)
        or (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY] = False)
        or (T[ X+CR[L].sX,                            Y+CR[L].sY] = False)
        then
        repeat
          Y := Y - 1;
          CR[L].Air := False;
          if CR[L].Air = False then CR[L].g := -5;
          Inc(Counter);
        until ((T[ X,                                       Y+CR[L].sY])
           and (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY])
           and (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY])
           and (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY])
           and (T[ X+CR[L].sX,                            Y+CR[L].sY]))
            or (Counter > 100000);

        if (T[ X,                                       Y+CR[L].sY])
        or (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY])
        or (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY])
        or (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY])
        or (T[ X+CR[L].sX,                            Y+CR[L].sY])
        then
        begin
          CR[L].g := CR[L].g - 2;

          LG := Y;
          if CR[L].g < 0 then
          LGcnt := 1 else
          LGcnt := -1;

          repeat
            Y := Y + LGcnt;

            if (T[ X,                                       Y+CR[L].sY ] = False)
            or (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY ] = False)
            or (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY ] = False)
            or (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY ] = False)
            or (T[ X+CR[L].sX,                            Y+CR[L].sY ] = False)
            then
            begin
              CR[L].Air := False;
              LGcnt := 2;
            end;
          until (Y = LG - CR[L].g)
             or (LGcnt = 2);

          if (T[ X+(CR[L].sX div 4),                    Y+1] = False)
          or (T[ X+(CR[L].sX div 2),                    Y  ] = False)
          or (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+1] = False)
          then
          begin
            if (CR[L].g > 0) then
            CR[L].g := -CR[L].g+(CR[L].g div 3);

            for I := 1 to 50 do
            if  (T[ X+(CR[L].sX div 4),                    Y+1] = False)
            or  (T[ X+(CR[L].sX div 2),                    Y  ] = False)
            or  (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+1] = False)
            then
            Y := Y+1;
          end;

          if  (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY])
          and (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY])
          and (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY])
          then CR[L].Air := True;
          if CR[L].Air = False then CR[L].g := -5;
        end;

        Counter := 0;
        if (T[ X,                                       Y+CR[L].sY] = False)
        or (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY] = False)
        or (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY] = False)
        or (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY] = False)
        or (T[ X+CR[L].sX,                            Y+CR[L].sY] = False)
        then
        repeat
          Y := Y - 1;
          CR[L].Air := False;
          if CR[L].Air = False then CR[L].g := -5;
          Inc(Counter)
        until ((T[ X,                                       Y+CR[L].sY])
           and (T[ X+(CR[L].sX div 4),                    Y+CR[L].sY])
           and (T[ X+(CR[L].sX div 2),                    Y+CR[L].sY])
           and (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+CR[L].sY])
           and (T[ X+CR[L].sX,                            Y+CR[L].sY]))
            or (Counter > 100000);

        if (T[ X+(CR[L].sX div 4),                    Y+1] = False)
        or (T[ X+(CR[L].sX div 2),                    Y  ] = False)
        or (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+1] = False)
        then
        begin
          if (CR[L].g > 0) then
          CR[L].g := -CR[L].g+(CR[L].g div 3);

          for I := 1 to 50 do
          if  (T[ X+(CR[L].sX div 4),                    Y+1] = False)
          or  (T[ X+(CR[L].sX div 2),                    Y  ] = False)
          or  (T[ X+(CR[L].sX div 2)+(CR[L].sX div 4), Y+1] = False)
          then
          Y := Y+1;

          if CR[L].Air = False then CR[L].g := -5;
        end;

        CR[L].X := X;
        CR[L].Y := Y;

        if (Loading = False) then
        begin
        //Creatures Bleed
          if (CR[L].Pwr < CR[L].OrgPwr/6) then
          begin
            P_Blood( CR[L].X+(CR[L].sX div 2), CR[L].Y+(CR[L].sY div 2), ((200 div CR[L].Pwr)+25) div 2, Random(3)+2, 0);
            if Random(2) = 0 then
            CR[L].Pwr := CR[L].Pwr - 1;
            CR[L].Spd := CR[L].Pwr;
          end;
        //end Creatures Bleed

        //AI
          if (CR[L].Name <> 'User') then CreatureAI(CR[L], CR[CR[L].TgIndex]);
        //end AI
        end;
      end else
      if (CR[L].Dead = False) and (Loading = False) then
      begin
      //Respawn
        //Makes particle effects when someone gets killed
        if Part then
        begin
          //Some blood
          if CR[L].X > CR[CR[L].HitBy].X then
            J2 := 1
          else
            J2 := -1;

          P_Blood(Random(CR[L].sX)+CR[L].X, Random(CR[L].sY)+CR[L].Y, 300, 25, J2);
          P_Blood(CR[L].X+(CR[L].sX div 2), CR[L].Y+(CR[L].sY div 2), 100, 10, 0);
          P_Blood(CR[L].X+(CR[L].sX div 2), CR[L].Y+(CR[L].sY div 2), 65, 20, J2);

          //A small explosion
          P_Explode(CR[L].X+(CR[L].sX div 2), CR[L].Y+(CR[L].sY div 2), 'Tiny');

          //And a effect, to dissolve a killed creature
//          if Quality <> 'Low' then
          P_Dissolve(L);
        end;
        //end particle effects

        //Drops weapons
        if Length(CR[L].myGunsI) > 0 then
        for J2 := 0 to Length(CR[L].myGunsI)-1 do
        begin
          J := Length(LGN);
          SetLength(LGN, Length(LGN)+1);
          LGN[J].Index := CR[L].myGunsI[J2].Index;
          LGN[J].X := -Random(5)+Round(CR[L].X+((CR[L].sX-((CR[L].sX+GN[LGN[J].Index].sX) div 2))));
          LGN[J].Y := -Random(5)+Round(CR[L].Y+GN[LGN[J].Index].pY);
          LGN[J].Air := True;
          LGN[J].g := 5;
          LGN[J].Dir := CR[L].Dir;
        end;
        SetLength(CR[L].myGunsI, 0);
        CR[L].myGun.Index := -1;

        if (CR[L].HitBy <> 0) then//if a monster hit another monster, it reappears
        begin
          if L = 0 then //if its djuk, make the DEAD sign
          with CR[0] do
          begin
            Dead := True;
            Draw;
            Sleep(650);

            eX := RP[0].X;
            J2 := 0;
            For I := 1 to RespawnPointCount-1 do
            if (abs(RP[I].X-X) > abs(eX-X)) or (Random(17)=5)then
            begin
              eX := RP[I].X;
              J2 := I;
            end;
//            J2 := Random(RespawnPointCount);

            CR[L].X := RP[J2].X-(CR[L].sX div 2);
            CR[L].Y := RP[J2].Y-(CR[L].sY div 2);
            CR[L].eX := CR[L].X+1;
            CR[L].eY := CR[L].Y+1;
            CR[L].g := 0;
            CR[L].Air := True;
            CR[L].Spd := Random(CR[L].OrgSpd div 2) + (CR[L].OrgSpd div 2);
            CR[L].Pwr := CR[L].OrgPwr;
            CR[L].Deaths := CR[L].Deaths + 1;

            if CR[L].X < CR[CR[L].TgIndex].X then CR[L].Dir := +1 else
            if CR[L].X > CR[CR[L].TgIndex].X then CR[L].Dir := -1;

            if X < XdZ then
              TpX := 0
            else
              TpX := Round(X)-XdZ;

            if Y < YdZ then
              tpY := 0
            else
              TpY := Round(Y)-YdZ;

            P_Dissolve(L);

            Draw;
            Sleep(100);
            Dead := False;
            DeadT := dotTime;
          end else
          begin
            J2 := Random(RespawnPointCount);
            CR[L].X := RP[J2].X-(CR[L].sX div 2);
            CR[L].Y := RP[J2].Y-(CR[L].sY div 2);
            CR[L].eX := CR[L].X+1;
            CR[L].eY := CR[L].Y+1;
            CR[L].g := 0;
            CR[L].Air := True;
            CR[L].Spd := Random(CR[L].OrgSpd div 2) + (CR[L].OrgSpd div 2);
            CR[L].Pwr := CR[L].OrgPwr;
            CR[L].Deaths := CR[L].Deaths + 1;

            if CR[L].X < CR[CR[L].TgIndex].X then CR[L].Dir := +1 else
            if CR[L].X > CR[CR[L].TgIndex].X then CR[L].Dir := -1;

            P_Dissolve(L);

            Repeat
              CR[L].TgIndex := Random(Length(CR));
            Until (CR[CR[L].TgIndex].Name <> CR[L].Name)
              and (CR[CR[L].TgIndex].Dead = False);
          end;
        end else
        if (L <> 0) and (CR[L].HitBy = 0) then // .... Djuk shot some monster, add to score and kill the monster once and for all
        begin
          CR[L].Dead := True;
          CR[0].Kills := CR[0].Kills+1;
        end;
      //end Respawn
      end;
    except
      raise exception.Create('Error #1');
      CR[L].X := CR[L].eX;
      CR[L].Y := CR[L].eY;
      Exit;
    end;
    CR[L].eX := CR[L].X;
    CR[L].eY := CR[L].Y;
  end;
//end Kreature Calculate


//Bullets Calculate
  if Length(BL) > 0 then
  For I := 0 to Length(BL)-1 do
  With BL[I] do
  if Typ <> '' then
  begin
//    For J := 0 to Spd div 4 do
    repeat
      if T[ X, Y ] then
      begin

        if (X >= tX)
        or (X <= 0) then
        begin
          Typ := '';
          goto GoOut;
        end;

        if GN[Owner.HisGun.Index].TT = 'ShotGun' then
        J := 4 else
        J := 10;

        //Makes the trail particles
        if (Part)
        and (X > tpx-15)
        and (X < tpx+(XdZ*2)+15)
        and (Y > tpy-15)
        and (Y < tpy+(YdZ*2)+15) then
        for I2 := 1 to J do
        if (Random(2) = 1) then
        begin
          SetLength(PT, Length(PT)+1);
          PT[Length(PT)-1].Dir := Dir;
          PT[Length(PT)-1].X := X+I2;
          PT[Length(PT)-1].Y := Y+Random(2)-Random(2);
          if Random(4)=0 then
            PT[Length(PT)-1].g := 0.1*(I2+1)
          else
            PT[Length(PT)-1].g := -0.1*(I2+1);

          PT[Length(PT)-1].Tip := Bullet;
          PT[Length(PT)-1].Clr := 5;
        end;

        //Moves the bullet 8px (noone is thiner, so there is no need for more precision)
        if GN[Owner.HisGun.Index].TT = 'ShotGun' then
        begin
          Y := Y + Random(DirY);
          if DirY > 0 then
            DirY := DirY-Random(2)
          else if DirY < 0 then
            DirY := DirY+Random(2)
        end else
        if Random(2) = 1 then
        Y := Y + Random(2) - Random(2);

        X := X + (Dir*8);

        For I2 := 0 to Length(CR)-1 do
        if (CR[I2].Dead = False) then
        if  (Owner.Name <> CR[I2].Name) then //Disables friendly fire
        if  (Y > CR[I2].Y)
        and (Y < CR[I2].Y+CR[I2].sY)
        and (X > CR[I2].X)
        and (X < CR[I2].X+CR[I2].sX) then
        begin
          CR[I2].HitBy := Owner.Index;

          CR[I2].Pwr := CR[I2].Pwr-Dmg+Random(30)-Random(30);

          if (CR[I2].Pwr <= 0) then
            CR[I2].Pwr := -1
          else
          begin
            P_Blood(X+Random(5)-Random(5), Y+Random(5)-Random(5), 50+Random(25)-Random(10), 3, Dir);
            CR[I2].X := CR[I2].X+(Random(Dmg div 25)*Dir);
          end;

          Typ := '';
          Break;
        end;
      end;
      if X < 0 then X := 0;
      if X > tX then X := tX;
      if Y < 0 then Y := 0;
      if Y > tY then Y := tY;
    until (Typ = '') or (T[ X, Y ] = False);
    GoOut:

    P_Explode(X, Y, ET);
  end;
  SetLength(BL, 0);
//end Bullet Calculate


  //Moves the view, so the player is in the middle of screen
  //@TODO: make it not so sudden
  if CR[0].X < XdZ then
    TpX := 0
  else
    TpX := Round(CR[0].X)-XdZ;

  if CR[0].Y < YdZ then
    tpY := 0
  else
    TpY := Round(CR[0].Y)-YdZ;

  //Stops player, if no button is pressed, or his speed is low
  //@TODO does this cause bleeding stops?
  if (CR[0].Name='User') and ((KP = False) or (CR[0].Spd < 5)) then
    CR[0].Spd := 0;

//if everybody dies, its gameover or stage cleared
  GameOver := True;
  for I := 1 to Length(CR)-1 do
  if CR[I].Dead = False then
  GameOver := False;
  if GameOver then
  begin
    Draw;
    LoadMap;
  end;
end;//Calculate

procedure TGame.LoadMap;
var
  I, J, I2, J2, cnt: Integer;
  Fo: File of Integer;
  bool: Boolean;
label
  TryAgain;
begin
  Loading := True;
  Gameover := False;

  if MapCnt >= Length(Maps) then
  begin
    Excape := True;
    Exit;
  end;

  cnt := 0;

  SetLength(Poly1, 0);
  SetLength(Poly2, 0);

  AssignFile(FO, 'data/Terrain/'+Maps[MapCnt]+'/1.pmp');
  Reset(FO);
  Read(FO, tx);
  Read(FO, ty);
  I := 0;
  repeat
    SetLength(Poly1, I+1);
    Read(FO, Poly1[I].X);
    Read(FO, Poly1[I].Y);
    Inc(I);
  until eof(FO);
  CloseFile(FO);

  if FileExists('data/Terrain/'+Maps[MapCnt]+'/2.pmp') then
  begin
    AssignFile(FO, 'data/Terrain/'+Maps[MapCnt]+'/2.pmp');
    Reset(FO);
    Read(FO, I);
    Read(FO, J);
    if I > tx then tx := I;
    if J > ty then ty := J;
    I := 0;
    repeat
      SetLength(Poly2, I+1);
      Read(FO, Poly2[I].X);
      Read(FO, Poly2[I].Y);
      Inc(I);
    until eof(FO);
    CloseFile(FO);
  end;

  SetLength(T, 0);
  Setlength(T, tx*2, ty*2);

  SetLength(TmB, 0);
  SetLength(TmB, (XdZ*2)*(YdZ*2));

  glClearColor(0, 0, 0, 0);
  glClear(GL_COLOR_BUFFER_BIT);
  glBindTexture(GL_TEXTURE_2D, LIndex); //The Loading pic
  glLoadIdentity;

  //Map Tracing (Drawing the polygons, making a mask out of them)
  //The code for map tracing has to be done differently on ATi cards
  if (glGetString(GL_VENDOR) = 'ATI Technologies Inc.') then
  begin
    J2 := 0;
    repeat
      I2 := 0;
      Inc(J2);
      repeat
        Inc(I2);
        glClear(GL_COLOR_BUFFER_BIT);
        glTranslatef(-(I2-1)*XdZ*2, -(J2-1)*YdZ*2, 0);
        glColor4f(1, 1, 1, 0);
        glBegin(GL_POLYGON);
          for I := 0 to Length(Poly1)-1 do
          if Poly1[I].X = -1 then
          begin
            glend;
            glBegin(GL_POLYGON);
          end else
          glVertex2f(Poly1[I].X, Poly1[I].Y);
        glend;
        if Length(Poly2) > 0 then
        begin
          glColor4f(0, 0, 0, 0);
          glBegin(GL_POLYGON);
            for I := 0 to Length(Poly2)-1 do
            if Poly2[I].X = -1 then
            begin
              glend;
              glBegin(GL_POLYGON);
            end else
            glVertex2f(Poly2[I].X, Poly2[I].Y);
          glend;
        end;

        glFinish;
        glReadPixels(0, 0, XdZ*2, YdZ*2, GL_RGBA, GL_UNSIGNED_BYTE, @TmB[0]);

        for I := 0 to XdZ*2-1 do
        for J := 0 to YdZ*2-1 do
        if (I+((I2-1)*XdZ*2) < tx)
        and ((YdZ*2-J)+((J2-1)*YdZ*2) < ty) then
        begin
          if (TmB[I+(J*XdZ*2)] <> 0) then
            T[ I+((I2-1)*XdZ*2), (YdZ*2-J)+((J2-1)*YdZ*2) ] := True
          else
            T[ I+((I2-1)*XdZ*2), (YdZ*2-J)+((J2-1)*YdZ*2) ] := False;
        end;

        //Loading Fadein effect
        cnt := cnt+1;
        glClear(GL_COLOR_BUFFER_BIT);
        glLoadIdentity;
        glEnable(GL_TEXTURE_2D);
        glColor4f(cnt/((tx/XdZ)*(ty/YdZ)), cnt/((tx/XdZ)*(ty/YdZ)), cnt/((tx/XdZ)*(ty/YdZ)), 1);
        glBegin(GL_QUADS);
          glTexCoord2f(0, 0);
          glVertex2f  (XdZ-256, YdZ-64);

          glTexCoord2f(0, 1);
          glVertex2f  (XdZ-256, YdZ+64);

          glTexCoord2f(1, 1);
          glVertex2f  (XdZ+256, YdZ+64);

          glTexCoord2f(1, 0);
          glVertex2f  (XdZ+256, YdZ-64);
        glend;
        SwapBuffers(DC);
        //Context.PageFlip;
        glDisable(GL_TEXTURE_2D);

      until (XdZ*(I2+1) > tx);
    until (YdZ*(J2+1) > ty);
  end else //Map tracing for cards other than ATi
  begin
    glClearColor(0.5, 0.5, 0.5, 0);
    J2 := 0;
    repeat
      I2 := 0;
      Inc(J2);
      repeat
        Inc(I2);
        glClear(GL_COLOR_BUFFER_BIT);
        glTranslatef(-(I2-1)*XdZ*2, -(J2-1)*YdZ*2, 0);
        glColor4f(1, 1, 1, 0);
        glBegin(GL_POLYGON);
          for I := 0 to Length(Poly1)-1 do
          if Poly1[I].X = -1 then
          begin
            glend;
            glBegin(GL_POLYGON);
          end else
          glVertex2f(Poly1[I].X, Poly1[I].Y);
        glend;
        if Length(Poly2) > 0 then
        begin
          glColor4f(0.5,0.5,0.5,0);
          glBegin(GL_POLYGON);
            for I := 0 to Length(Poly2)-1 do
            if Poly2[I].X = -1 then
            begin
              glend;
              glBegin(GL_POLYGON);
            end else
            glVertex2f(Poly2[I].X, Poly2[I].Y);
          glend;
        end;

        glFinish;
        glReadPixels(0, 0, XdZ*2, YdZ*2, GL_RGBA, GL_UNSIGNED_BYTE, @TmB[0]);

        for I := 0 to XdZ*2-1 do
        for J := 0 to YdZ*2-1 do
        if (I+((I2-1)*XdZ*2) < tx)
        and ((YdZ*2-J)+((J2-1)*YdZ*2) < ty) then
        begin
          if (TmB[I+(J*XdZ*2)] > $FFFFFFFF-512) then
            T[ I+((I2-1)*XdZ*2), (YdZ*2-J)+((J2-1)*YdZ*2) ] := True
          else
            T[ I+((I2-1)*XdZ*2), (YdZ*2-J)+((J2-1)*YdZ*2) ] := False;
        end;

        //Loading Fadein effect
        cnt := cnt+1;
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
        glLoadIdentity;
        glEnable(GL_TEXTURE_2D);
        glColor3f(cnt/((tx/XdZ)*(ty/YdZ)), cnt/((tx/XdZ)*(ty/YdZ)), cnt/((tx/XdZ)*(ty/YdZ)));
        glBegin(GL_QUADS);
          glTexCoord2f(0, 0);
          glVertex2f  (XdZ-256, YdZ-64);

          glTexCoord2f(0, 1);
          glVertex2f  (XdZ-256, YdZ+64);

          glTexCoord2f(1, 1);
          glVertex2f  (XdZ+256, YdZ+64);

          glTexCoord2f(1, 0);
          glVertex2f  (XdZ+256, YdZ-64);
        glend;
        SwapBuffers(DC);
        //Context.PageFlip;
        glDisable(GL_TEXTURE_2D);
        glClearColor(0.5, 0.5, 0.5, 0);

      until (XdZ*(I2+1) > tx);
    until (YdZ*(J2+1) > ty);
  end;
  //end Map Tracing

  SetLength(TmB, 0);
  Inc(MapCnt);

//Loading Screen
  glLoadIdentity;
  glClearColor(0, 0, 0, 0);
  glClear(GL_COLOR_BUFFER_BIT);
  glBindTexture(GL_TEXTURE_2D, LIndex);
  glEnable(GL_TEXTURE_2D);
  glBegin(GL_QUADS);
  glColor3f(1, 1, 1);//this time fully visible
    glTexCoord2f(0, 0);
    glVertex2f  (XdZ-256, YdZ-64);

    glTexCoord2f(0, 1);
    glVertex2f  (XdZ-256, YdZ+64);

    glTexCoord2f(1, 1);
    glVertex2f  (XdZ+256, YdZ+64);

    glTexCoord2f(1, 0);
    glVertex2f  (XdZ+256, YdZ-64);
  glend;
  SwapBuffers(DC);
  //Context.PageFlip;
  glDisable(GL_TEXTURE_2D);

//ReSpawn points (the points where creatures appear, after they are killed)
  for I2 := 0 to RespawnPointCount-1 do
  repeat
    RP[I2].X := Random(tX-150)+75;
    RP[I2].Y := Random(tY-150)+75;

    Bool := True;
    if (T[ RP[I2].X, RP[I2].Y ] = False) then
       Bool := False
    else
      For I := RP[I2].X - 35 to RP[I2].X + 35 do
      For J := RP[I2].Y - 35 to RP[I2].Y + 35 do
      if T[ I, J ] = False then
      begin
        Bool := False;
        Break;
      end;
  until Bool;
//end ReSpawn points

//Spawn (Putting creatures on respawn points)
  for I := 0 to Length(CR)-1 do
  begin
    J2 := Random(RespawnPointCount);
    CR[I].X := RP[J2].X-(CR[I].sX div 2);
    CR[I].Y := RP[J2].Y-(CR[I].sY div 2);
    CR[I].eX := CR[I].X+1;
    CR[I].eY := CR[I].Y+1;
    CR[I].g := 0;
    CR[I].Spd := Random(CR[I].OrgSpd div 2) + (CR[I].OrgSpd div 2);
    CR[I].Pwr := CR[I].OrgPwr;
    CR[I].Dead := False;

    CR[I].PicT := dotTime;
    CR[I].ShootI := dotTime;
    CR[I].Index := I;
    CR[I].HitBy := 1;

    CR[I].myGun.Index := -1;
    SetLength(CR[I].myGunsI, 0);

    Repeat
      CR[I].TgIndex := Random(Length(CR));
    Until (CR[CR[I].TgIndex].Name <> CR[I].Name);

    if CR[I].X < CR[CR[I].TgIndex].X then CR[I].Dir := +1 else
    if CR[I].X > CR[CR[I].TgIndex].X then CR[I].Dir := -1;
  end;
//end Spawn

//Makes guns - the ones lying on the ground
  SetLength(LGN, Length(CR)*4);
  for I := 0 to Length(LGN)-1 do
  begin
    LGN[I].Index := Random(Length(GN));
    LGN[I].g := 1;
    LGN[I].Air := True;
    LGN[I].Dir := random(3)-1;

    repeat
      LGN[I].X := Random(tX-130)+65;
      LGN[I].Y := Random(tY-130)+65;

      Bool := True;
      if T[ LGN[I].X, LGN[I].Y ] = False then
        Bool := False
      else
        for I2 := LGN[I].X-65 to LGN[I].X+65 do
        for J2 := LGN[I].Y-17 to LGN[I].Y+17 do
        if T[I2, J2] = False then
        begin
          Bool := False;
          Break;
        end;
    until Bool;
  end;

  tx := tx+100;
  ty := ty+100;

//PreCalculation - makes some calculation loops before starting, so that creatures don't just drop form the air at the beggining :)
  For I := 1 to 75 do
    Calculate;

  if PolyList <> -1 then
  glDeleteLists(PolyList, 1);

//Compiles a display list for the map
  PolyList := glGenLists(1);
  glNewList(PolyList, GL_COMPILE);
(*    if Smooth then
    begin
      glColor4f((Rs*2+Rt)/3, (Gs*2+Gt)/3, (Bs*2+Bt)/3, 0);
      I2 := +1; J2 := +1;
      for J := 0 to 3 do
      begin
      glBegin(GL_POLYGON);
        case j of
         1: begin I2 := +1; J2 := -1; end;
         2: begin I2 := -1; J2 := +1; end;
         3: begin I2 := -1; J2 := -1; end;
        end;

        for I := 0 to Length(Poly1)-1 do
        if Poly1[I].X = -1 then
        begin
          glend;
          glBegin(GL_POLYGON);
        end else
          glVertex2f(Poly1[I].X-I2, Poly1[I].Y+J2);
      glend;
      end;
    end;*)

    glBegin(GL_POLYGON);
      glColor4f(Rs, Gs, Bs, 0);
      for I := 0 to Length(Poly1)-1 do
      if Poly1[I].X = -1 then
      begin
        glend;
        glBegin(GL_POLYGON);
      end else
        glVertex2f(Poly1[I].X, Poly1[I].Y);
    glend;

    glBegin(GL_POLYGON);
      glColor4f(Rt, Gt, Bt, 0);
      for I := 0 to Length(Poly2)-1 do
      if Poly2[I].X = -1 then
      begin
        glend;
        glBegin(GL_POLYGON);
      end else
        glVertex2f(Poly2[I].X, Poly2[I].Y);
    glend;
    glLoadIdentity;
  glEndList;
  SetLength(Poly1, 0);
  SetLength(Poly2, 0);

//Deals with the particles and weather
  if Part then
  begin
    Wind := Random(3);
    SetLength(PT, 0);

  //Simplified&Optimized(TM) snow make and drop
    if (Quality = High) then
    begin
      SetLength(Weather, 35000);
      MaxWeather := 40000;
      WeatherInTheSky := 3000;
    end else if (Quality = Medium) then
    begin
      SetLength(Weather, 20000);
      MaxWeather := 35000;
      WeatherInTheSky := 2000;
    end else
    begin
      SetLength(Weather, 6000);
      MaxWeather := 15000;
      WeatherInTheSky := 1250;
    end;

    for I := 0 to Length(Weather)-1 do
    with Weather[I] do
    begin
      repeat
        X := Random(tX);
        Y := Random(tY);
      until (T[X,Y]);

      Dir := Random(4)+1;

      with Weather[I] do
      while T[X,Y] do
        Y := Y+Dir;
    end;

    //Deletes duplicate snow particles
    for cnt := 0 to 2000 do
    begin
      I2 := 0;
      J2 := Random(Length(Weather));

      for I := 0 to Length(Weather)-1 do
      with Weather[I] do
      if  (X = Weather[J2].X)
      and (Y = Weather[J2].Y)
      and (I <> J2) then
      begin
        Weather[I] := Weather[Length(Weather)-1];
        J2 := Random(Length(Weather));
        Inc(I2);
      end;
      SetLength(Weather, Length(Weather)-I2);
    end;

    SetLength(Weather, Length(Weather)+WeatherInTheSky);
    for I := Length(Weather)-WeatherInTheSky-1 to Length(Weather)-1 do
    with Weather[I] do
    begin
      repeat
        X := Random(tX);
        Y := Random(tY);
      until (T[X,Y]);
      Dir := Random(5)+1;
    end;
    
    if Length(Weather) > MaxWeather then
    SetLength(Weather, MaxWeather);
  end;

//Background pics setting
  glLoadIdentity;
  glClearColor(0, 0, 0, 0);
  glBindTexture(GL_TEXTURE_2D, LIndex);
  glEnable(GL_TEXTURE_2D);
  if back then
  For I2 := 0 to StuffCount do
  begin
    TryAgain:
    if I2 > stOrgStvari then
    ST[I2] := ST[Random(stOrgStvari)];

    bool := True;
    cnt := 0;
    repeat
      I := Random(tX-88)+44;
      J := Random(tY-88)+44;

      Inc(cnt);

      //This condition is in all 3 picture types, so it speeds up the checking
      if (T[ I+(ST[I2].sX div 2), J+ST[I2].sY] = False) then
        Continue;

      //Makes sure, things aren't too close to each other
      bool := True;
      if (I2 > 0) then
      begin
        if (ST[I2].Tip = 'T') then
        for J2 := 0 to I2-1 do
        if (ST[J2].Tip = 'T') then
        if  (abs(ST[J2].X-I) < 35)
        and (abs(ST[J2].Y-J) < 30)
        then
          bool := False;

        if (ST[I2].Tip = 'L') then
        for J2 := 0 to I2-1 do
        if (ST[J2].Tip = 'L') then
        if  (abs(ST[J2].X-I) < ST[J2].sX+ST[I2].sX)
        and (abs(ST[J2].Y-J) < 3)
        then
          bool := False;
      end;

     if (cnt >= 50000) then
     begin
       if (I2 > stOrgStvari) then
         goto TryAgain
       else
       begin
         I := -512;
         J := -512;
         Break;
       end;
     end;

    until ((ST[I2].Tip = 'T')
      and  (T[ I+(ST[I2].sX div 2), J+(ST[I2].sY)       ])
      and  (T[ I+(ST[I2].sX div 2), J                     ])
      and  (T[ I,                     J+(ST[I2].sY div 2) ])
      and  (T[ I+(ST[I2].sX),       J+(ST[I2].sY div 2) ])
      and  (T[ I+(ST[I2].sX div 2), J+(ST[I2].sY+1)     ] = False))
       or ((ST[I2].Tip = 'B')
      and  (T[ I+(ST[I2].sX div 2), J+1                   ])
      and  (T[ I+(ST[I2].sX div 2), J+(ST[I2].sY)       ])
      and  (T[ I+5,                   J+(ST[I2].sY div 2) ])
      and  (T[ I+(ST[I2].sX)-5,     J+(ST[I2].sY div 2) ])
      and  (T[ I+(ST[I2].sX div 2), J+(ST[I2].sY+1)     ] = False)
      and  (T[ I+(ST[I2].sX)-5,     J+(ST[I2].sY+1)     ] = False)
      and  (T[ I+5,                   J+(ST[I2].sY+1)     ] = False))
       or ((ST[I2].Tip = 'L')
      and  (T[ I+(ST[I2].sX div 2), J+2   ])
      and  (T[ I+(ST[I2].sX div 2), J+1   ] = False)
      and  (T[ I+(ST[I2].sX)+1,     J+1   ] = False)
      and  (T[ I-1,                   J+1   ] = False)
      and  (T[ I+(ST[I2].sX div 2), J+(ST[I2].sY div 2)]
      and  (T[ I+(ST[I2].sX div 2), J+ST[I2].sY])
       or (Random(17)=7)))
      and (bool);

    ST[I2].X := I;
    ST[I2].Y := J;

    //Loading Fadeout effect
    if I2 mod 5 = 0 then
    begin
      glColor3f(1-I2/StuffCount, 1-I2/StuffCount, 1-I2/StuffCount);
      glBegin(GL_QUADS);
        glTexCoord2f(0, 0);
        glVertex2f  (XdZ-256, YdZ-64);

        glTexCoord2f(0, 1);
        glVertex2f  (XdZ-256, YdZ+64);

        glTexCoord2f(1, 1);
        glVertex2f  (XdZ+256, YdZ+64);

        glTexCoord2f(1, 0);
        glVertex2f  (XdZ+256, YdZ-64);
      glend;
      SwapBuffers(DC);
      //Context.PageFlip;
    end;
  end else
  For I := 50 downto 0 do //Loading Fadeout effect
  begin
    glColor3f(I/50, I/50, I/50);
    glBegin(GL_QUADS);
      glTexCoord2f(0, 0);
      glVertex2f  (XdZ-256, YdZ-64);

      glTexCoord2f(0, 1);
      glVertex2f  (XdZ-256, YdZ+64);

      glTexCoord2f(1, 1);
      glVertex2f  (XdZ+256, YdZ+64);

      glTexCoord2f(1, 0);
      glVertex2f  (XdZ+256, YdZ-64);
    glend;
    SwapBuffers(DC);
    //Context.PageFlip;
    Sleep(6);
  end;

  glDisable(GL_TEXTURE_2D);
//end Background pics setting
  glClearColor(Rt, Gt, Bt, 1);
  Loading := False;
  Draw;
end;

//    -       -       -       -  //
//  -   -   -   -   -   -   -   -  //
// - - - - - - - - - - - - - - - - - //
//---/---/---/---/---/---/---/---/---///
///-//-//-//-//-//-//-//-//-//-//-//-////
//-//-//-//-//-//-//-//-//-//-//-//-//-///
//-// THIS IS THE MAIN                /-///
//-/  _       ____     ____    ____    /-///
//-/  I      I    I   I    I   I   I    /-///
//-/  I      I    I   I    I   I    I   /-///
//-/  I      I    I   I    I   I___I   /-///
//-/  I      I    I   I    I   I      /-///
//-/  I____  I____I _ I____I   I     /-///
//-//                                /-///
//-//-//-//-//-//-//-//-//-//-//-//-//-///
///-//-//-//-//-//-//-//-//-//-//-//-////
procedure TGame.Loop(Sender: Tobject; var Done: Boolean);
//Its set as the application.onidle event, so its called everytime, the processor has spare time
//var
//  F: TextFile;
//  I, J, I2, I3: Integer;
var
  I: Integer;
  TStr, Str: String;
  F: TextFile;
var
  TF: TextFile;
  J, I2, J2, I3, p0, pl, cnt: Integer;
  bool: Boolean;
  FO: File of Integer;

label
  bck;
begin//Loop
  LoopT := (LoopT + (1000/dotTimeSince(FPS))) / 2;
  FPS := dotTime;

(*  if Loading then
  begin
    LoadMap;
    Loading := False;
  end;*)

  if GameOver then
    LoadMap;

  if (Pause = False) then
  Calculate;
  try
  Draw;
  except
  end;

  //FPS Limiter
//(*
  if 1000/dotTimeSince(FPS) > FPSLimit then
  begin
    FpsTim := Round(1000/FPSLimit-dotTimeSince(FPS));
    if FpsTim > 1 then
      Sleep(FpsTim-1);
  end;
//*)

  Done := Excape;
  if Done then
    EndItAll;
end;//Loop

//This procedure ends the game... well D00HHh..
procedure TGame.EndItAll;
begin
  //glClear(GL_ALL_ATTRIB_BITS);

  (*if RC <> 0 then
  begin
    wglMakeCurrent(0, 0);
    wglDeleteContext(RC);
  end;
  ReleaseDC(Handle, DC);*)
  //dotSetDisplayMode(0,0,0,0);

  //WinExec('Djuk_Njuk.exe', SW_SHOWNORMAL);
  //Application.Terminate;

  //FIXME: ugly hack, because I was having problems with closing gl windows
  ShellExecute(Handle, 'open', PWideChar(Application.ExeName), nil, nil, SW_SHOW);

  DeactivateRenderingContext;
  wglDeleteContext(RC);
  ReleaseDC(Handle, DC);

  MenuForm.Close;

//  Application.Terminate;

  //DjukNjuk.Hide;
//  Application.Terminate;
  //DjukNjuk.Hide;
  //MenuForm.Show;
end;

//FORM
//   ___   ___    _____    ___   _______  _____
//  /   \  |  \   |       |   |     |     |
// |       |  |   |       |   |     |     |
// |       |__/   |--     |   \     |     |--
// |       |  \   |      |-----\    |     |
//  \___/  |   \  |____ /       \   |     |____
procedure TGame.FormCreate(Sender: TObject);
var
  I: Integer;
  TStr, Str: String;
  F: TextFile;
var
  TF: TextFile;
  J, I2, J2, I3, p0, pl, cnt: Integer;
  bool: Boolean;
  FO: File of Integer;
begin//Create
  RunT := dotTime;
  Randomize;
  try
    if FindFirst('Config.cfg', faAnyFile, SRec) = 0 then
    begin
      AssignFile(F, 'Config.cfg');
      Reset(F);

        Readln(F, Tstr);

        if TStr = 'High' then
        begin
          Part := True;
          Back := True;
          Smooth := True;
          Quality := High;
        end else
        if TStr = 'Medium' then
        begin
          Part := True;
          Back := True;
          Smooth := False;
          Quality := Medium;
        end else
        if TStr = 'Low' then
        begin
          Part := True;
          Back := False;
          Smooth := False;
          Quality := Low;
        end else
        if TStr = 'Very Low' then
        begin
          Part := False;
          Back := False;
          Smooth := False;
          Quality := Lowest;
        end else
        begin
          Part := True;
          Back := True;
          Smooth := False;
          Quality := Medium;
        end;

        Readln(F, I);
        SetLength(CR, I+1);
        Readln(F, Theme);

        Readln(F, I);
        if I = 0 then
          BloodEnabled := False
        else
          BloodEnabled := True;
      CloseFile(F);
    end else
    begin
      Part := True;
      Back := True;
      Smooth := False;
      BloodEnabled := True;
      Quality := Medium;

      if FindFirst('data/Terrain/Themes/inf.pci', faAnyFile, SRec) = 0 then
      begin
        AssignFile(F, 'data/Terrain/Themes/inf.pci');
        Reset(F);
          Readln(F, Theme);
        CloseFile(F);
      end else
        Theme := 'Default';

      SetLength(CR, 15+1);
      //XdZ := 400;//800x600
      //YdZ := 300;
      //RR := 60;
    end;
  except
    Part := True;
    Back := True;
    Smooth := False;
    BloodEnabled := True;
    Quality := Medium;

    if FindFirst('data/Terrain/Themes/inf.pci', faAnyFile, SRec) = 0 then
    begin
      AssignFile(F, 'data/Terrain/Themes/inf.pci');
      Reset(F);
        Readln(F, Theme);
      CloseFile(F);
    end else
      Theme := 'Default';
    SetLength(CR, 15+1);
    //XdZ := 400;//800x600
    //YdZ := 300;
    //RR := 60;
  end;
  XdZ := GetSystemMetrics(SM_CXSCREEN) div 2;
  YdZ := GetSystemMetrics(SM_CYSCREEN) div 2;
//  if Part then
//    SetLength(PT, 0)
 // else
 // begin
    SetLength(PT, 0);
    SetLength(Weather, 0);
//  end;

  Left := 0;
  Top  := 0;
  Width  := XdZ*2;
  Height := YdZ*2;
  Cursor := crNone;

  try
    (*if Smooth then
    begin
      I := 25;
      repeat
        I := I-1;
        Context.SetAttrib(WGL_SAMPLE_BUFFERS_ARB, 1);
        Context.SetAttrib(WGL_SAMPLES_ARB, I);
        if I = -1 then raise Exception.Create('');
      until Context.InitGL;
    end else
    if Context.InitGL = False then
    raise Exception.Create('');
    *)
    InitOpenGL;
    DC := GetDC(Handle);
    RC := CreateRenderingContext(DC, [opDoubleBuffered], 24, 0, 0, 0, 0, 0);
    ActivateRenderingContext(DC, RC);

    glViewport(0, 0, XdZ*2, YdZ*2);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, XdZ*2, YdZ*2, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glEnable(GL_ALPHA_TEST);
    glAlphaFunc(GL_LESS, 1/255); //This is $01000000 in RGB

    //if (GetSystemMetrics(SM_CXSCREEN) <> XdZ*2)
    //or (GetSystemMetrics(SM_CYSCREEN) <> YdZ*2) then
    //dotSetDisplayMode(XdZ*2, YdZ*2, 16, RR);

  except
    ShowMessage('Could not initialize Graphics. Try another graphic setting or goto www.woodenstick.tk for support');
    Application.Terminate;
  end;

  MapCnt := 0;

  //Res := IntToStr(XdZ*2)+'x'+IntToStr(YdZ*2)+' '+IntToStr(RR)+'Hz';

//Weapons
  AssignFile(TF, 'data/Weapons/inf.pci');
  Reset(TF);
  J := 1;
  repeat
    SetLength(GN, J+1);
    SetLength(GB, J+2);//n,.jk
    Readln(TF, TStr);
    AssignFile(F, 'data/Weapons/'+TStr+'.pci');
    Reset(F);

      Readln(TF, GN[J].pY);
      Readln(TF, GN[J].pX);
      Readln(TF, GN[J].dmg);
      Readln(TF, GN[J].TT);
      Readln(TF, GN[J].ET);
      Readln(TF, GN[J].Interval);
      Readln(TF, GN[J].ClipSize);
      Readln(TF, GN[J].ClipTime);

      Readln(F, GN[J].sX);
      Readln(F, GN[J].sY);
      GN[J].Tip := TStr;

      J2 := (64-GN[J].sX);
      p0 := (16-GN[J].sY);

      For I := 0 to 64 do
      For I2 := 0 to 16 do
      begin
        GB[J].Pic[I+(I2*64)] := TransColor;

        if  (I  <= 64-(J2 div 2))
        and (I2 <= 16-(p0 div 2))
        and (I  >= 1+(J2 div 2) + (J2 mod 2))
        and (I2 >= 1+(p0 div 2) + (p0 mod 2)) then
          Readln(F, GB[J].Pic[ I+(I2*64) ]);

        if (GB[J].Pic[I+(I2*64)] = $FFFFFF) then
          GB[J].Pic[I+(I2*64)] := TransColor;
      end;

      glGenTextures(1, @GB[J].Index);
      glBindTexture(GL_TEXTURE_2D, GB[J].Index);
      glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
      glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
      glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,64,16,0,GL_RGBA,GL_UNSIGNED_BYTE, @GB[J].Pic[0]);

    CloseFile(F);
    Inc(J);
  until eof(TF);
  CloseFile(TF);
//end Weapons

//Creatures
  AssignFile(TF, 'data/Creatures/inf.pci');
  Reset(TF);
  PL := 0;
  repeat
    ReadLn(TF, TStr);
    AssignFile(F, 'data/Creatures/'+TStr+'/inf.pci');
    Reset(F);
      Readln(F, CR[pl].sX);
      Readln(F, CR[pl].sY);
      Readln(F, CR[pl].PicN);
      Readln(F, CR[pl].Name);
      Readln(F, CR[pl].OrgSpd);
      Readln(F, CR[pl].OrgPwr);
      Readln(F, CR[pl].PicInt);
      Readln(F, CR[pl].AITip);
      Readln(F, CR[pl].AIL);

      Readln(F, CR[pl].GunY);
      //@HACK read animation style, dammit
      if eof(F) = False then
        CR[pl].PicShowStyle := 1
      else
        CR[pl].PicShowStyle := 0;
    CloseFile(F);

    CR[pl].PicIndex := pl;
    CR[pl].Kills := 0;
    CR[pl].Deaths := 0;
    CR[pl].g := 0;
    CR[pl].myGun.Index := -1;
    SetLength(CR[pl].myGunsI, 0);
    CR[pl].Spd := CR[pl].OrgSpd;
    CR[pl].Pwr := -5;
    CR[pl].Air := True;
    CR[pl].Pic := 1;
    CR[pl].MainPic := 1;
    CR[pl].Act := '';

    for J := 1 to CR[pl].PicN do
    begin
      J2 := (64-CR[pl].sX);
      p0 := (64-CR[pl].sY);

      AssignFile(FO, 'data/Creatures/'+TStr+'/'+IntToStr(J)+'.pci');
      Reset(FO);
        For I := 0 to 64 do
        For I2 := 0 to 64 do
        begin
          Cre[ J, pl ].Pic[I+(I2*64)] := TransColor;

          if  (I  <= 64-(J2 div 2))
          and (I2 <= 64-(p0 div 2))
          and (I  >= 1+(J2 div 2) + (J2 mod 2))
          and (I2 >= 1+(p0 div 2) + (p0 mod 2))
          then
          Read(FO, Cre[ J, pl ].Pic[I+(I2*64)]);

          if (Cre[ J, pl ].Pic[I+(I2*64)] = $FFFFFF)
          then
          Cre[ J, pl ].Pic[I+(I2*64)] := TransColor;
        end;

        glGenTextures(1, @Cre[J, pl].Index);
        glBindTexture(GL_TEXTURE_2D,Cre[J, pl].Index);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,64,64,0,GL_RGBA,GL_UNSIGNED_BYTE, @Cre[J, pl].Pic[0]);
      CloseFile(FO);
    end;
    J := 0;
    while FindFirst('data/Creatures/'+TStr+'/Jump'+IntToStr(J)+'.pci', faAnyFile, SRec) = 0 do
    begin
      J2 := (64-CR[pl].sX);
      p0 := (64-CR[pl].sY);

      CR[pl].JumpPic := True;
      AssignFile(FO, 'data/Creatures/'+TStr+'/Jump'+IntToStr(J)+'.pci');
      Reset(FO);
        For I := 0 to 64 do
        For I2 := 0 to 64 do
        begin
          Cre[ CR[pl].PicN+1+J, pl ].Pic[I+(I2*64)] := TransColor;

          if  (I  <= 64-(J2 div 2))
          and (I2 <= 64-(p0 div 2))
          and (I  >= 1+(J2 div 2) + (J2 mod 2))
          and (I2 >= 1+(p0 div 2) + (p0 mod 2))
          then
          Read(FO, Cre[ CR[pl].PicN+1+J, pl ].Pic[I+(I2*64)]);

          if (Cre[ CR[pl].PicN+1+J, pl ].Pic[I+(I2*64)] = $FFFFFF)
          then
          Cre[ CR[pl].PicN+1+J, pl ].Pic[I+(I2*64)] := TransColor;
        end;

        glGenTextures(1, @Cre[CR[pl].PicN+1+J, pl].Index);
        glBindTexture(GL_TEXTURE_2D,Cre[CR[pl].PicN+1+J, pl].Index);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,64,64,0,GL_RGBA,GL_UNSIGNED_BYTE, @Cre[CR[pl].PicN+1+J, pl].Pic[0]);
      CloseFile(FO);
      Inc(J);
    end;
    Inc(pl);

    if pl = Length(CR) then Break;
  until eof(TF);
  CloseFile(TF);

  if pl < Length(CR)-1 then
  begin
    for I := pl to Length(CR)-1 do
    begin
      repeat
        CR[I] := CR[Random(pl)];
      until (CR[I].Name <> 'User') and (CR[I].Name <> '');
      CR[I].Pic := Random(CR[I].PicN)+1;
      CR[I].Spd := CR[I].OrgSpd+Random(5)-Random(15);
    end;
  end;
//end Creatures

  CR[0].MainPic := 5;

  AssignFile(F, 'data/Terrain/Themes/'+Theme+'/inf.pci');
  Reset(F);
    Readln(F, Rs);
    Readln(F, Gs);
    Readln(F, Bs);
    Readln(F, Rt);
    Readln(F, Gt);
    Readln(F, Bt);
    Readln(F, WeatherType);
  CloseFile(F);

  if (Theme = 'Default')
  or (FindFirst('data/Terrain/Themes/'+Theme+'/0.pci', faAnyFile, SRec) <> 0)
  then Back := False;

  if Back then
  begin
    I2 := 0;
    while FindFirst('data/Terrain/Themes/'+Theme+'/'+IntToStr(I2)+'.pci', faAnyFile, SRec) = 0 do
    begin
      AssignFile(F, 'data/Terrain/Themes/'+Theme+'/'+IntToStr(I2)+'.pci');
      Reset(F);
      Readln(F, ST[I2].Tip);
      Readln(F, ST[I2].sX);
      Readln(F, ST[I2].sY);
      ST[I2].pIndex := I2;

      if  (ST[I2].Tip <> 'T')
      and (ST[I2].Tip <> 'B')
      and (ST[I2].Tip <> 'L') then
        ST[I2] := ST[Random(I2-1)+1]//Not a normal pic, replaces it with a good one
      else
      with ST[I2] do
      begin
        SetLength(Stv, Length(Stv)+1);

        pIndex := Length(Stv)-1;

        if sX <= 8 then
        Stv[pIndex].sX := 8 else
        if sX <= 16 then
        Stv[pIndex].sX := 16 else
        if sX <= 32 then
        Stv[pIndex].sX := 32 else
        if sX <= 64 then
        Stv[pIndex].sX := 64 else
        Stv[pIndex].sX := 128;

        if sY <= 8 then
        Stv[pIndex].sY := 8 else
        if sY <= 16 then
        Stv[pIndex].sY := 16 else
        if sY <= 32 then
        Stv[pIndex].sY := 32 else
        if sY <= 64 then
        Stv[pIndex].sY := 64 else
        Stv[pIndex].sY := 128;

        For I := 0 to Stv[pIndex].sX do
        For J := 0 to Stv[pIndex].sY do
        begin
          Stv[pIndex].Pic[I+(J*Stv[pIndex].sX)] := TransColor;

          if  ((I <= sX)
          and  (J <= sY))
          and ((I >= 1)
          and  (J >= 1))
          then
          ReadLn(F, Stv[pIndex].Pic[I+(J*Stv[pIndex].sX)]);

          if (Stv[pIndex].Pic[I+(J*Stv[pIndex].sX)] = $FFFFFF) then
          Stv[pIndex].Pic[I+(J*Stv[pIndex].sX)] := TransColor;

        end;
        CloseFile(F);

        glGenTextures(1, @Stv[pIndex].Index);
        glBindTexture(GL_TEXTURE_2D,Stv[pIndex].Index);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,Stv[pIndex].sX, Stv[pIndex].sY,0,GL_RGBA,GL_UNSIGNED_BYTE, @Stv[pIndex].Pic[0]);
      end;
    Inc(I2);
    end;
    stOrgStvari := I2;
  end;

  //Terrain
    AssignFile(F, 'data/Terrain/inf.pci');
    Reset(F);
    I := 0;
    while eof(F) = False do
    begin
      SetLength(Maps, I+1);
      Readln(F, Maps[I]);
      Inc(I);
    end;
    CloseFile(F);
  //end Terrain

    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);

    //Loads the loading screen :)
    AssignFile(CFl, 'data/Loading.pci');
    Reset(CFl);
    For I := 0 to 512-1 do
    For I2 := 0 to 128-1 do
    Read(CFl, LPic[ I+(I2*512) ]);
    CloseFile(CFl);

    glGenTextures(1, @LIndex);
    glBindTexture(GL_TEXTURE_2D, LIndex);
    glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
    glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,512,128,0,GL_RGBA,GL_UNSIGNED_BYTE, @LPic[0]);

  //Pisava
    I2 := 0;
    while FindFirst('data/font/'+IntToStr(I2)+'.pci', faAnyFile, SRec) = 0 do
    begin
      SetLength(TextFont, Length(TextFont)+1);
      AssignFile(F, 'data/font/'+IntToStr(I2)+'.pci');
      Reset(F);
        Readln(F, TextFont[I2].Chr);
        for I := 0 to FontSize do
        for J := 0 to FontSize do
        begin
          Readln(F, I3);
          if I3 = 0 then
            TextFont[I2].Pic[I, J] := $FFFFFF
          else
            TextFont[I2].Pic[I, J] := TransColor;
        end;
        glGenTextures(1, @TextFont[I2].Index);
        glBindTexture(GL_TEXTURE_2D, TextFont[I2].Index);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,FontSize,FontSize,0,GL_RGBA,GL_UNSIGNED_BYTE, @TextFont[I2].Pic[0]);
      CloseFile(F);
      Inc(I2);
    end;
  //end Pisava

  DeadT := dotTime;
  Application.OnIdle := Loop;
end;procedure TGame.FormDestroy(Sender: TObject);
begin

end;

//Create

procedure Jump;
begin
  CR[0].g := 17;
  CR[0].Y := CR[0].Y - Round(CR[0].g);
  CR[0].Air := True;
end;

procedure SwitchWeapon(K:Integer);
var
  I: Integer;
begin
  with CR[0] do
  if Length(myGunsI) > 1 then
  begin
    for I := 0 to Length(MyGunsI)-1 do
    if MyGun.Index = MyGunsI[I].Index then
    MyGunsI[I].Clip := MyGun.Clip;

    if K = 1 then
    begin
      if MyGun.Index = MyGunsI[Length(MyGunsI)-1].Index then
      begin
        MyGun.Index := MyGunsI[0].Index;
        MyGun.Clip := MyGunsI[0].Clip;
      end else
      begin
        for I := 0 to Length(MyGunsI)-1 do
        if MyGun.Index = MyGunsI[I].Index then
        begin
          MyGun.Index := MyGunsI[I+1].Index;
          MyGun.Clip := MyGunsI[I+1].Clip;
          Break;
        end;
      end;
    end else
    begin
      if MyGun.Index = MyGunsI[0].Index then
      begin
        MyGun.Index := MyGunsI[Length(MyGunsI)-1].Index;
        MyGun.Clip := MyGunsI[Length(MyGunsI)-1].Clip;
      end else
      begin
        for I := 0 to Length(MyGunsI)-1 do
        if MyGun.Index = MyGunsI[I].Index then
        begin
          MyGun.Index := MyGunsI[I-1].Index;
          MyGun.Clip := MyGunsI[I-1].Clip;
          Break;
        end;
      end;
    end;
  end;
end;











(*function GetCharFromVirtualKey(Key: Word): char;
 var
    keyboardState: TKeyboardState;
    asciiResult: Integer;
    Reslut: string;
 begin
    GetKeyboardState(keyboardState) ;

    SetLength(Reslut, 2);
    asciiResult := ToAscii(key, MapVirtualKey(key, 0), keyboardState, @Reslut[1], 0) ;
    case asciiResult of
      0: Reslut := '';
      1: SetLength(Reslut, 1);
      2: SetLength(Reslut, 1);
      else
        Reslut := '';
    end;
    if length(Reslut)>0 then
      Result := Reslut[1]
    else
      Result := ' ';
 end;*)

procedure TGame.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  I, J: Integer;
function KeyExists: Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Length(Keys) > 0 then
  for I := 0 to Length(Keys)-1 do
  for J := 0 to Length(Keys)-1 do
  if (Keys[I] = Keys[J])
  and (I <> J) then
  Result := True;
end;
begin//FormKeyDown
  SetLength(Keys, Length(Keys)+1);
  Keys[Length(Keys)-1] := Key;

  if KeyExists then
  SetLength(Keys, Length(Keys)-1);

  if (Pause = False) then
  begin
    if (Key = VK_SHIFT)
    and (Running = False) then
    begin
      OrgSpd := CR[0].Spd;
      OrgPicInt := CR[0].PicInt;
      CR[0].PicInt := CR[0].PicInt div 2;
      Running := True;
    end;
    if Key = VK_DELETE then
    begin
      CR[0].Pwr := -1;
      CR[0].Act := '';
      CR[0].ExAct := '';
      CR[0].ActM := '';
    end;

    for J := Length(Keys)-1 downto 0 do
    begin
      if(Keys[J]=VK_LEFT) or (Keys[J]=65) then
      begin
        CR[0].exAct := CR[0].Act;
        CR[0].Act := 'Walk';
        CR[0].Dir := -1;

        if Running then
          CR[0].Spd := CR[0].OrgSpd+100
        else
          CR[0].Spd := CR[0].OrgSpd;
        Break;
      end;
      if(Keys[J]=VK_RIGHT) or (Keys[J]=68) then
      begin
        CR[0].exAct := CR[0].Act;
        CR[0].Act := 'Walk';
        CR[0].Dir := 1;

        if Running then
          CR[0].Spd := CR[0].OrgSpd+100
        else
          CR[0].Spd := CR[0].OrgSpd;
        Break;
      end;
      if(Keys[J]=VK_UP) or (Keys[J]=87) then
      begin
        CR[0].exAct := CR[0].Act;
        MP := True;
        CR[0].ActM := 'Jump';

        For I := Round(CR[0].X)+10 to Round(CR[0].X)+CR[0].sX-10 do
        if T[ I, Round(CR[0].Y)+50] = False then
        CR[0].Air := False;

        if CR[0].Air = False then
        begin
          CR[0].exAct := CR[0].Act;
          MP := True;
          CR[0].ActM := 'Jump';
          Jump;
        end;
        Break;
      end;
      if(Keys[J]=VK_Space) then
      begin
  //        CR[0].exAct := CR[0].Act;
        CR[0].ActM := 'Shoot';
        MP := True;
        Break;
      end;
    end;
  end;

  if Key = VK_ESCAPE then
  Excape := True;

  if Key = VK_CONTROL then
  begin
    if (CR[0].exAct = 'Walk') then
      CR[0].Act := CR[0].exAct
    else
      CR[0].Act := '';

    SwitchWeapon(1);
  end;

  KP := True;
  if key = vk_numpad0 then
  Loadmap;
end;//end FormKeyDown



 procedure TGame.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  I, J, I2: Integer;
//  TmBtn: Word;
begin//FormKeyUp
  for I2 := 0 to Length(Keys)-1 do
  if Keys[I2] = Key then
  begin
//    TmBtn := Keys[Length(Keys)-1];
//    Keys[Length(Keys)-1] := Keys[I];
    Keys[I2] := Keys[Length(Keys)-1];
    SetLength(Keys, Length(Keys)-1);

    for J := Length(Keys)-1 downto 0 do
    begin
      if(Keys[J]=VK_LEFT) or (Keys[J]=65) then
      begin
        CR[0].exAct := CR[0].Act;
        CR[0].Act := 'Walk';
        CR[0].Dir := -1;

        if Running then
          CR[0].Spd := CR[0].OrgSpd+100
        else
          CR[0].Spd := CR[0].OrgSpd;
        Break;
      end;
      if(Keys[J]=VK_Right) or (Keys[J]=68) then
      begin
        CR[0].exAct := CR[0].Act;
        CR[0].Act := 'Walk';
        CR[0].Dir := 1;

        if Running then
          CR[0].Spd := CR[0].OrgSpd+100
        else
          CR[0].Spd := CR[0].OrgSpd;
        Break;
      end;
      if(Keys[J]=VK_UP) or (Keys[J]=87) then
      begin
  //      CR[0].exAct := CR[0].Act;
  //      MP := True;
  //      CR[0].ActM := 'Jump';

        For I := Round(CR[0].X)+10 to Round(CR[0].X)+CR[0].sX-10 do
        if T[ I, Round(CR[0].Y)+50] = False then
        CR[0].Air := False;

        if CR[0].Air = False then
        begin
          CR[0].exAct := CR[0].Act;
          MP := True;
          CR[0].ActM := 'Jump';
          Jump;
        end;
        Break;
      end;
      if(Keys[J]=VK_SPACE) then
      begin
        CR[0].ActM := 'Shoot';
        MP := True;
        Break;
      end;
    end;

    Break;
  end;

  if Key = VK_SPACE then
  begin
    MP := False;
    CR[0].ActM := '';
  end;

  if Key = VK_SHIFT then
  begin
    CR[0].Spd := OrgSpd;
    CR[0].PicInt := OrgPicInt;
    Running := False;
  end;

  if Length(Keys) = 0 then
  KP := False;
end;//end FormKeyUp

procedure TGame.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Word;
label
  ven;
begin//FormMouseDown
  MP := True;

  if Button = mbMiddle then
  begin
    CR[0].ActM := '';
    SwitchWeapon(1);
  end else
  if Pause = False then
  if (Button = mbLeft) then
  CR[0].ActM := 'Shoot' else
  if (Button = mbRight) then
  CR[0].ActM := 'Jump';

  For I := Round(CR[0].X)+10 to Round(CR[0].X)+CR[0].sX-10 do
  if T[ I, Round(CR[0].Y)+50] = False then
  CR[0].Air := False;

  if (CR[0].ActM = 'Jump') and (CR[0].Air = False) then Jump;

end;//end FormMouseDown

procedure TGame.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  CR[0].ActM := '';
  MP := False;
end;

procedure TGame.FormKeyPress(Sender: TObject; var Key: Char);
var
  I: Integer;
begin
  if AnsiUpperCase(Key) = 'P' then
  if Pause then Pause := False else Pause := True;

  if AnsiUpperCase(Key) = 'R' then
  begin
    CR[0].ClipTimer := dotTime;
    CR[0].myGun.Clip := GN[CR[0].myGun.Index].ClipSize;
  end;

  //Everyone wants to kill you
  if AnsiUpperCase(Key) = 'C' then
  for I := 1 to Length(CR) do
    CR[I].TgIndex := 0;

  //Let AI play
  if AnsiUpperCase(Key) = 'M' then
  begin
    if CR[0].name='User' then
    begin
      CR[0].name:='AIUser';
      CR[0].AITip := 'Dumber';
      CR[0].Act := '';
      CR[0].Spd := CR[0].OrgSpd;
    end else
      CR[0].name:='User';
  end;
end;

procedure TGame.FormMouseWheelDown(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
  CR[0].ActM := '';
  SwitchWeapon(1);
end;

procedure TGame.FormMouseWheelUp(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
  CR[0].ActM := '';
  SwitchWeapon(-1);
end;

end.

