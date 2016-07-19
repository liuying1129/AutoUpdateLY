unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ComCtrls,Inifiles,StrUtils, FileCtrl, Gauges,
  Tlhelp32, ExtCtrls,ShellAPI;

type
  TfrmMain = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    ProgressBar1: TGauge;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Timer1: TTimer;
    procedure BitBtn1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    procedure ReadIni;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses UDM;

{$R *.dfm}

var
  gSourceDir,gSourceUser,gSourcePwd,gTargetDir:string;
  gQuit:boolean;
  giPos:integer;

function ShowOptionForm(const pCaption,pTabSheetCaption,pItemInfo,pInifile:Pchar):boolean;stdcall;external 'OptionSetForm.dll';
function DeCryptStr(aStr: Pchar; aKey: Pchar): Pchar;stdcall;external 'DESCrypt.dll';//解密

function KillTask(ExeFileName: string): boolean;//文件名
const
  PROCESS_TERMINATE=$0001;
var
  ContinueLoop,KillResult: LongBool;//C语言中的BOOL
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := true;//找不到进程返回true

  //CreateToolhelp32Snapshot获取系统运行进程(Process)列表、线程(Thread)列表和指定运行进程的堆 (Heap)列表、调用模块(Module)列表
  //如果函数运行成功将返回一个非零"Snapshot"句柄
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  //TPROCESSENTRY32是在Process32First、Process32Next两个函数所用到的数据结构.使用这两个数据结构的变量时要先设置dwSize的值
  FProcessEntry32.dwSize := Sizeof(FProcessEntry32);
  //Process32First对"Snapshot"所包含的列表进行息获取
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
  ss:='源文件目录'+#2+'Dir'+#2+#2+'0'+#2+'例如:\\192.168.1.1\共享文件'+#2+#3+
      '源目录登录用户'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
      '源目录登录密码'+#2+'Edit'+#2+#2+'0'+#2+#2+'1sp'+#3+
      '目标文件目录'+#2+'Dir'+#2+#2+'0'+#2+#2+#3;
  if ShowOptionForm('设置','设置',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
	  ReadIni;
end;

procedure TfrmMain.ReadIni;
var
  configini:tinifile;

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  CONFIGINI:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));

  gSourceDir:=configini.ReadString('设置','源文件目录','');
  gTargetDir:=configini.ReadString('设置','目标文件目录','');
  gSourceUser:=configini.ReadString('设置','源目录登录用户','');
  gSourcePwd:=configini.ReadString('设置','源目录登录密码','');
  if gSourcePwd='' then gSourcePwd:='A6BCEA93A2228AE2';//''
  //======解密gSourcePwd
  pInStr:=pchar(gSourcePwd);
  pDeStr:=DeCryptStr(pInStr,'sp');
  setlength(gSourcePwd,length(pDeStr));
  for i :=1  to length(pDeStr) do gSourcePwd[i]:=pDeStr[i-1];
  //==========

  configini.Free;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
//  ReadIni;
end;

procedure AFindCallBack(const filename:string;const info:tsearchrec;var quit:boolean);
var
  lfilename:string;
  sr: TSearchRec;
begin
  inc(giPos);
  frmMain.ProgressBar1.Progress:=giPos;

  lfilename:=stringreplace(filename,IfThen(gSourceDir[length(gSourceDir)]='\',gSourceDir,gSourceDir+'\'),IfThen(gTargetDir[length(gTargetDir)]='\',gTargetDir,gTargetDir+'\'),[rfIgnoreCase]);
  if FindFirst(lfilename,faAnyFile, sr) = 0 then//目标文件夹中有此文件
  begin
    if info.Time<=sr.Time then begin FindClose(SR);exit;end;
  end;
  FindClose(SR);

  if not ForceDirectories(ExtractFileDir(lfilename)) then MessageBox(frmMain.Handle, pchar('创建目录'+ExtractFileDir(lfilename)+'失败,请重试!'), '提示', MB_ICONERROR);

  if uppercase(Application.ExeName)=uppercase(lfilename) then//copy自身(升级程序)
  begin
    lfilename:=stringreplace(lfilename,'.exe','Tmp.exe',[rfIgnoreCase]);
  end;
  
  if not CopyFile(pchar(filename),pchar(lfilename),False) then MessageBox(frmMain.Handle, pchar('更新文件'+filename+'失败,关闭打开的程序后重试!'), '提示', MB_ICONERROR);
end;

procedure AFindCallBack_Target(const filename:string;const info:tsearchrec;var quit:boolean);
begin
  if uppercase(ExtractFileName(Application.ExeName))<>uppercase(ExtractFileName(filename)) then KillTask(filename);//杀死进程,不杀死自身(升级程序)
end;

procedure TfrmMain.BitBtn2Click(Sender: TObject);
var
  flb:TFileLIstBox;
  fNum:integer;
  tmpBool:boolean;
  NetSource : TNetResource;
begin
  //先杀死目标文件夹的所有进程
  tmpBool:=false;
  //findfile(tmpBool,gTargetDir,'*.*',AFindCallBack_Target,true,true);
  //==========================

  //映射网络驱动器
  with NetSource do
  begin
    dwType := RESOURCETYPE_ANY;
    lpLocalName := 'X:';       //将远程资源映射到此驱动器
    lpRemoteName := Pchar(gSourceDir);  //远程网络资源
    lpProvider := '';  //必须赋值,如为空则使用lpRemoteName的值。
  end;

  IF WnetAddConnection2(NetSource, Pchar(gSourcePwd), Pchar(gSourceUser),CONNECT_UPDATE_PROFILE)<>0 THEN
  BEGIN
    MessageBox(frmMain.Handle, '连接远程目录失败,请检查设置!', '提示', MB_ICONERROR);
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
  //findfile(gQuit,gSourceDir,'*.*',AFindCallBack,true,true);
  ProgressBar1.Progress:=ProgressBar1.MaxValue;
  WNetCancelConnection2('X:', CONNECT_UPDATE_PROFILE, False);//断开网络驱动器X:
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
//var
//  f: Textfile; 
begin
  {//在该事件中通过运行bat文件的方式更新自身(升级程序)
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
  winexec(PChar(ChangeFileExt(Application.ExeName,'.bat')),sw_hide);//}
end;

procedure TfrmMain.Timer1Timer(Sender: TObject);
//Var
  //RemoteDir:string;
  //DirCount:integer;
begin
  (Sender as TTimer).Enabled:=false;

  //RemoteDir:='检验信息管理系统';

  {dm.IdFTP1.ChangeDir(RemoteDir);
  try
    dm.IdFTP1.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('对FTP服务器内容list时报错:'+E.Message,mtError,[mbOK],0);
      exit;
    end;
  end;
  //ListBox1.Items.Assign(LS);
  DirCount := dm.IdFTP1.DirectoryListing.Count;

  ProgressBar1.MaxValue:=DirCount;}

  FTP_DownloadDir(dm.IdFTP1,gcRemoteDir,ExtractFilePath(Application.Exename));

  ProgressBar1.Progress:=ProgressBar1.MaxValue;
  //showmessage('下载完成');

  //if ShellExecute(Handle, 'Open', Pchar(ExtractFilePath(application.ExeName)+RemoteDir+'\'+'aa.txt'), '', '', SW_ShowNormal)<=32 then
  //  MessageDlg('aa.txt打开失败!',mtError,[mbOK],0);

  application.Terminate;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  Timer1.Enabled:=true;
end;

end.
