unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls,Inifiles,StrUtils, Gauges,
  Tlhelp32, ExtCtrls,ShellAPI, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdFTP;

type
  TfrmMain = class(TForm)
    ProgressBar1: TGauge;
    Image1: TImage;
    Label1: TLabel;
    Timer1: TTimer;
    procedure Timer1Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses UDM, USearchFile;

{$R *.dfm}

function KillTask(ExeFileName: string): boolean;//�ļ���
const
  PROCESS_TERMINATE=$0001;
var
  ContinueLoop,KillResult: LongBool;//C�����е�BOOL
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := true;//�Ҳ������̷���true

  //CreateToolhelp32Snapshot��ȡϵͳ���н���(Process)�б��߳�(Thread)�б��ָ�����н��̵Ķ� (Heap)�б�����ģ��(Module)�б�
  //����������гɹ�������һ������"Snapshot"���
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  //TPROCESSENTRY32����Process32First��Process32Next�����������õ������ݽṹ.ʹ�����������ݽṹ�ı���ʱҪ������dwSize��ֵ
  FProcessEntry32.dwSize := Sizeof(FProcessEntry32);
  //Process32First��"Snapshot"���������б����Ϣ��ȡ
  ContinueLoop := Process32First(FSnapshotHandle,FProcessEntry32);

  while integer(ContinueLoop)<>0 do
  begin 
    if UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) = UpperCase(ExtractFileName(ExeFileName)) then
    begin
      KillResult := TerminateProcess(OpenProcess(PROCESS_TERMINATE, false,FProcessEntry32.th32ProcessID), 0);
      if integer(KillResult)=0 then result:=false;
    end;
    ContinueLoop := Process32Next(FSnapshotHandle,FProcessEntry32);
  end;

  CloseHandle(FSnapshotHandle); 
end; 

procedure AFindCallBack_Target(const filename:string;const info:tsearchrec;var quit:boolean);
begin
  KillTask(filename);//ɱ������
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
Var
  DirCount:integer;
  Save_Cursor:TCursor;
  tmpBool:boolean;
begin
  (Sender as TTimer).Enabled:=false;

  Save_Cursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;    { Show hourglass cursor }

  dm.IdFTP1.ChangeDir(gcRemoteDir);
  try
    dm.IdFTP1.List(nil);
  except
    on E:Exception do
    begin
      Screen.Cursor := Save_Cursor;  { Always restore to normal }
      MESSAGEDLG('��FTP����������listʱ����:'+E.Message,mtError,[mbOK],0);
      exit;
    end;
  end;
  DirCount := dm.IdFTP1.DirectoryListing.Count;

  ProgressBar1.MaxValue:=DirCount;//����������

  //��ɱ��Ŀ���ļ��е����н���
  tmpBool:=false;
  findfile(tmpBool,gcRemoteDir,'*.*',AFindCallBack_Target,true,true);//ExtractFilePath(Application.Exename)+
  //==========================
  
  dm.IdFTP1.ChangeDir('\');
  FTP_DownloadDir(dm.IdFTP1,gcRemoteDir,ExtractFilePath(Application.Exename));

  ProgressBar1.Progress:=ProgressBar1.MaxValue;//������չʾ

  Screen.Cursor := Save_Cursor;  { Always restore to normal }
  
  MakeExeFile;

  application.Terminate;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Timer1.Interval:=300;
  Timer1.Enabled:=true;
end;

end.
