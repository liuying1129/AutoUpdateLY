program AutoUpdateLY;

uses
  Forms,
  UfrmMain in 'UfrmMain.pas' {frmMain},
  USearchFile in 'USearchFile.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
