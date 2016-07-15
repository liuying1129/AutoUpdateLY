unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls,Inifiles,StrUtils, FileCtrl, Gauges,
  Tlhelp32, ExtCtrls;

type
  TfrmMain = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    ProgressBar1: TGauge;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    procedure BitBtn1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
    procedure ReadIni;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses USearchFile;

{$R *.dfm}

var
  gSourceDir,gSourceUser,gSourcePwd,gTargetDir:string;
  gQuit:boolean;
  giPos:integer;

function ShowOptionForm(const pCaption,pTabSheetCaption,pItemInfo,pInifile:Pchar):boolean;stdcall;external 'OptionSetForm.dll';
function DeCryptStr(aStr: Pchar; aKey: Pchar): Pchar;stdcall;external 'DESCrypt.dll';//����

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

procedure TfrmMain.BitBtn1Click(Sender: TObject);
var                                                                           
  ss:string;                                                                  
begin
  ss:='Դ�ļ�Ŀ¼'+#2+'Dir'+#2+#2+'0'+#2+'����:\\192.168.1.1\�����ļ�'+#2+#3+
      'ԴĿ¼��¼�û�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
      'ԴĿ¼��¼����'+#2+'Edit'+#2+#2+'0'+#2+#2+'1sp'+#3+
      'Ŀ���ļ�Ŀ¼'+#2+'Dir'+#2+#2+'0'+#2+#2+#3;
  if ShowOptionForm('����','����',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
	  ReadIni;
end;

procedure TfrmMain.ReadIni;
var
  configini:tinifile;

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  CONFIGINI:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));

  gSourceDir:=configini.ReadString('����','Դ�ļ�Ŀ¼','');
  gTargetDir:=configini.ReadString('����','Ŀ���ļ�Ŀ¼','');
  gSourceUser:=configini.ReadString('����','ԴĿ¼��¼�û�','');
  gSourcePwd:=configini.ReadString('����','ԴĿ¼��¼����','');
  if gSourcePwd='' then gSourcePwd:='A6BCEA93A2228AE2';//''
  //======����gSourcePwd
  pInStr:=pchar(gSourcePwd);
  pDeStr:=DeCryptStr(pInStr,'sp');
  setlength(gSourcePwd,length(pDeStr));
  for i :=1  to length(pDeStr) do gSourcePwd[i]:=pDeStr[i-1];
  //==========

  configini.Free;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ReadIni;
end;

procedure AFindCallBack(const filename:string;const info:tsearchrec;var quit:boolean);
var
  lfilename:string;
  sr: TSearchRec;
begin
  inc(giPos);
  frmMain.ProgressBar1.Progress:=giPos;

  lfilename:=stringreplace(filename,IfThen(gSourceDir[length(gSourceDir)]='\',gSourceDir,gSourceDir+'\'),IfThen(gTargetDir[length(gTargetDir)]='\',gTargetDir,gTargetDir+'\'),[rfIgnoreCase]);
  if FindFirst(lfilename,faAnyFile, sr) = 0 then//Ŀ���ļ������д��ļ�
  begin
    if info.Time<=sr.Time then begin FindClose(SR);exit;end;
  end;
  FindClose(SR);

  if not ForceDirectories(ExtractFileDir(lfilename)) then MessageBox(frmMain.Handle, pchar('����Ŀ¼'+ExtractFileDir(lfilename)+'ʧ��,������!'), '��ʾ', MB_ICONERROR);

  if uppercase(Application.ExeName)=uppercase(lfilename) then//copy����(��������)
  begin
    lfilename:=stringreplace(lfilename,'.exe','Tmp.exe',[rfIgnoreCase]);
  end;
  
  if not CopyFile(pchar(filename),pchar(lfilename),False) then MessageBox(frmMain.Handle, pchar('�����ļ�'+filename+'ʧ��,�رմ򿪵ĳ��������!'), '��ʾ', MB_ICONERROR);
end;

procedure AFindCallBack_Target(const filename:string;const info:tsearchrec;var quit:boolean);
begin
  if uppercase(ExtractFileName(Application.ExeName))<>uppercase(ExtractFileName(filename)) then KillTask(filename);//ɱ������,��ɱ������(��������)
end;

procedure TfrmMain.BitBtn2Click(Sender: TObject);
var
  flb:TFileLIstBox;
  fNum:integer;
  tmpBool:boolean;
  NetSource : TNetResource;
begin
  //��ɱ��Ŀ���ļ��е����н���
  tmpBool:=false;
  findfile(tmpBool,gTargetDir,'*.*',AFindCallBack_Target,true,true);
  //==========================

  //ӳ������������
  with NetSource do
  begin
    dwType := RESOURCETYPE_ANY;
    lpLocalName := 'X:';       //��Զ����Դӳ�䵽��������
    lpRemoteName := Pchar(gSourceDir);  //Զ��������Դ
    lpProvider := '';  //���븳ֵ,��Ϊ����ʹ��lpRemoteName��ֵ��
  end;

  IF WnetAddConnection2(NetSource, Pchar(gSourcePwd), Pchar(gSourceUser),CONNECT_UPDATE_PROFILE)<>0 THEN
  BEGIN
    MessageBox(frmMain.Handle, '����Զ��Ŀ¼ʧ��,��������!', '��ʾ', MB_ICONERROR);
    EXIT;
  END;
  //===============

  flb:=tfilelistbox.Create(nil);
  flb.Parent:=self;
  flb.Visible:=false;
  flb.Directory:=gSourceDir;
  fNum:=flb.Count;
  flb.Free;

  ProgressBar1.MaxValue:=fNum;
  
  giPos:=0;

  gQuit:=false;
  findfile(gQuit,gSourceDir,'*.*',AFindCallBack,true,true);
  ProgressBar1.Progress:=ProgressBar1.MaxValue;
  WNetCancelConnection2('X:', CONNECT_UPDATE_PROFILE, False);//�Ͽ�����������X:
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
var 
  f: Textfile; 
begin
  //�ڸ��¼���ͨ������bat�ļ��ķ�ʽ��������(��������) 
  assignfile(f,ChangeFileExt(Application.ExeName,'.bat'));
  rewrite(f);
  writeln(f,'@echo off');
  writeln(f,'If not exist "'+stringreplace(Application.ExeName,'.exe','Tmp.exe',[rfIgnoreCase])+'" Goto loop2');
  writeln(f,':loop');
  writeln(f,'Erase "'+Application.ExeName+'"');
  writeln(f,'If exist "'+Application.ExeName+'" Goto loop');
  writeln(f,'ren '+stringreplace(Application.ExeName,'.exe','Tmp.exe',[rfIgnoreCase])+' '+ExtractFileName(application.ExeName));
  writeln(f,':loop2');
  //writeln(f,'Erase "'+ChangeFileExt(Application.ExeName,'.bat')+'"');
  closefile(f); 
  winexec(PChar(ChangeFileExt(Application.ExeName,'.bat')),sw_hide);
end;

end.
