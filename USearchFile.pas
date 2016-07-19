unit USearchFile;

interface

uses
  SysUtils{TSearchRec},Forms{application};

type 
  {TFindCallBack为回调函数,FindFile函数找到一个匹配的文件之后就会调用这个函数.
  filename:找到的文件名(包括路径),你在回调函数中可以根据文件名进行操作.
  info:找到的文件的记录信息,是一个TSearchRec结构.
  bQuit:决定是否终止文件的查找}
  TFindCallBack=procedure(const filename:string;const info:TSearchRec;var bQuit:boolean);

procedure FindFile(var Quit:boolean;const Path:String;const filename:string='*.*'; 
                  proc:TFindCallBack=nil;const bSub:boolean=true;const bMsg:boolean=true); 

implementation


procedure FindFile(var Quit:boolean;const Path:String;const filename:string='*.*';
                  proc:TFindCallBack=nil;const bSub:boolean=true;const bMsg:boolean=true); 
//Quit:决定是否退出查找，应该初始化为false； 
//Path:查找路径； 
//filename:文件名，可以包含Windows所支持的任何通配符的格式；默认所有的文件 
//proc:回调函数，默认为空 
//bSub:决定是否查找子目录，默认为查找子目录 
//bMsg:决定是否在查找文件的时候处理其他的消息，默认为处理其他的消息 
var 
  fpath: String;
  info: TsearchRec; 

  procedure ProcessAFile; 
  begin 
    if (info.Name<>'.')and(info.Name<>'..')and((info.Attr and faDirectory)<>faDirectory) then 
    begin 
      if assigned(proc) then proc(fpath+info.FindData.cFileName,info,quit);
    end; 
  end; 

  procedure ProcessADirectory; 
  begin 
    if (info.Name<>'.')and(info.Name<>'..')and((info.attr and fadirectory)=fadirectory) then
      findfile(quit,fpath+info.Name,filename,proc,bsub,bmsg); 
  end; 

begin 
  if path[length(path)]<>'\' then fpath:=path+'\' else fpath:=path;
  try 
    if 0=findfirst(fpath+filename,faanyfile and (not fadirectory),info) then 
    begin 
     ProcessAFile; 
     while 0=findnext(info) do 
     begin 
       ProcessAFile; 
       if bmsg then application.ProcessMessages; 
       if quit then 
       begin 
         findclose(info); 
         exit; 
       end; 
     end; 
    end; 
  finally 
    findclose(info); 
  end; 
  try 
    if bsub and (0=findfirst(fpath+'*',faanyfile,info)) then
    begin
      ProcessADirectory;
      while findnext(info)=0 do ProcessADirectory;
    end;
  finally
    findclose(info); 
  end;
end;

{调用示例
procedure AFindCallBack(const filename:string;const info:tsearchrec;var quit:boolean);
begin 
 form1.listbox1.Items.Add(filename);
end;

procedure TForm1.Button10Click(Sender: TObject);
begin
  listbox1.Clear;
  qqq:=false;
  findfile(qqq,edit1.text,'*.*',AFindCallBack,true,true);
end;

procedure TForm1.Button11Click(Sender: TObject);
begin
  qqq:=true;
end;
//}

end.
