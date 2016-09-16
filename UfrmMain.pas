unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls,Inifiles,StrUtils, Gauges,Tlhelp32, 
  XMLIntf,XMLDoc, ExtCtrls;

type
  TfrmMain = class(TForm)
    ProgressBar1: TGauge;
    Image1: TImage;
    Label1: TLabel;
    Timer1: TTimer;
    procedure Timer1Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
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

procedure AFindCallBack(const filename:string;const info:tsearchrec;var quit:boolean);
begin
  KillTask(filename);//ɱ������
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
Var
  DirCount,j:integer;
  Save_Cursor:TCursor;
  tmpBool:boolean;
  ss:TStringStream;
  XMLDocument:IXMLDocument;
  XMLNode:IXMLNode;
  sVersion:string;
begin
  (Sender as TTimer).Enabled:=false;

  Save_Cursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;    { Show hourglass cursor }

  try
    dm.IdFTP1.ChangeDir(gcRemoteDir);
  except
    on E:Exception do
    begin
      MESSAGEDLG('��λԶ��Ŀ¼['+gcRemoteDir+']ʱ����:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  
  try
    dm.IdFTP1.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('��FTP������Ŀ¼['+gcRemoteDir+']listʱ����:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  DirCount := dm.IdFTP1.DirectoryListing.Count;

  ProgressBar1.MaxValue:=DirCount;//����������

  ss:=TStringStream.Create('');
  try
    dm.IdFTP1.Get(gcVersionInfoFile,ss);//�޴��ļ����׳��쳣
  except
    on E:Exception do
    begin
      ss.Free;
      MESSAGEDLG('���ذ汾��Ϣ�ļ�['+gcVersionInfoFile+']��Stream����:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  XMLDocument:=TXMLDocument.Create(nil);
  try
    XMLDocument.LoadFromStream(ss);//���淶��XML���׳��쳣
  except
    on E:Exception do
    begin
      ss.Free;
      MESSAGEDLG('�汾��Ϣ�ļ�['+gcVersionInfoFile+']LoadFromStream����:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  for j :=0  to XMLDocument.DocumentElement.ChildNodes.Count-1 do
  begin
    XMLNode:=XMLDocument.DocumentElement.ChildNodes[j];

    if not SameText(XMLNode.NodeName,'file') then continue;

    //���������Ǵ�Сд���У���XML�б���д��name��version
    if XMLNode.Attributes['name']=null then continue;//�ýڵ���name����ʱ
    if XMLNode.Attributes['name']='' then continue;
    if XMLNode.Attributes['version']=null then//�ýڵ���version����ʱ
      sVersion:='' else sVersion:=XMLNode.Attributes['version'];

    gslFileVersion.Add(XMLNode.Attributes['name']+'='+sVersion);
  end;
  ss.free;

  //��ɱ��Ŀ���ļ��е����н���
  tmpBool:=false;
  findfile(tmpBool,gcRemoteDir,'*.*',AFindCallBack,true,true);
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

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  gslFileVersion.Free;
end;

end.
