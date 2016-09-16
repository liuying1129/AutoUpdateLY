program AutoUpdateLY;

uses
  Forms,
  UfrmMain in 'UfrmMain.pas' {frmMain},
  UDM in 'UDM.pas' {DM: TDataModule};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TDM, DM);
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
