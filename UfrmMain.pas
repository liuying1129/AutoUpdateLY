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
  DirCount:integer;
  Save_Cursor:TCursor;
  tmpBool:boolean;
begin
  (Sender as TTimer).Enabled:=false;

  Save_Cursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;    { Show hourglass cursor }

  try
    dm.IdFTP1.ChangeDir(gcRemoteDir);
  except
    on E:Exception do
    begin
      MESSAGEDLG('定位远程目录时报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  
  try
    dm.IdFTP1.List(nil);
  except
    on E:Exception do
    begin
      MESSAGEDLG('对FTP服务器内容list时报错:'+E.Message,mtError,[mbOK],0);
      application.Terminate;
    end;
  end;
  DirCount := dm.IdFTP1.DirectoryListing.Count;

  ProgressBar1.MaxValue:=DirCount;//进度条设置

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

end.
