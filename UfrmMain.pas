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

procedure AFindCallBack(const filename:string;const info:tsearchrec;var quit:boolean);
begin
  KillTask(filename);//杀死进程
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
      MESSAGEDLG('定位远程目录['+gcRemoteDir+']时报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  
  try
    dm.IdFTP1.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('对FTP服务器目录['+gcRemoteDir+']list时报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  DirCount := dm.IdFTP1.DirectoryListing.Count;

  ProgressBar1.MaxValue:=DirCount;//进度条设置

  ss:=TStringStream.Create('');
  try
    dm.IdFTP1.Get(gcVersionInfoFile,ss);//无此文件会抛出异常
  except
    on E:Exception do
    begin
      ss.Free;
      MESSAGEDLG('下载版本信息文件['+gcVersionInfoFile+']到Stream报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  XMLDocument:=TXMLDocument.Create(nil);
  try
    XMLDocument.LoadFromStream(ss);//不规范的XML会抛出异常
  except
    on E:Exception do
    begin
      ss.Free;
      MESSAGEDLG('版本信息文件['+gcVersionInfoFile+']LoadFromStream报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  for j :=0  to XMLDocument.DocumentElement.ChildNodes.Count-1 do
  begin
    XMLNode:=XMLDocument.DocumentElement.ChildNodes[j];

    if not SameText(XMLNode.NodeName,'file') then continue;

    //属性名称是大小写敏感，故XML中必须写成name、version
    if XMLNode.Attributes['name']=null then continue;//该节点无name属性时
    if XMLNode.Attributes['name']='' then continue;
    if XMLNode.Attributes['version']=null then//该节点无version属性时
      sVersion:='' else sVersion:=XMLNode.Attributes['version'];

    gslFileVersion.Add(XMLNode.Attributes['name']+'='+sVersion);
  end;
  ss.free;

  //先杀死目标文件夹的所有进程
  tmpBool:=false;
  findfile(tmpBool,gcRemoteDir,'*.*',AFindCallBack,true,true);
  //==========================

  dm.IdFTP1.ChangeDir('\');
  FTP_DownloadDir(dm.IdFTP1,gcRemoteDir,ExtractFilePath(Application.Exename));

  ProgressBar1.Progress:=ProgressBar1.MaxValue;//进度条展示

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
