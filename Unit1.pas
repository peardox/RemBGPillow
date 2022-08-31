unit Unit1;

{$DEFINE USEGPUIFPRESENT}

  interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, PythonEngine,
  FMX.PythonGUIInputOutput, PyEnvironment, PyEnvironment.Embeddable,
  PyEnvironment.Embeddable.Res, PyEnvironment.Embeddable.Res.Python39,
  FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.Layouts, System.Threading, System.IOUtils,
  PyPackage, PyCommon, RemBG, Pillow, PyTorch, PyModule, PSUtil, FMX.StdCtrls;

type
  TForm1 = class(TForm)
    PyEmbed: TPyEmbeddedResEnvironment39;
    PyEng: TPythonEngine;
    PyIO: TPythonGUIInputOutput;
    Layout1: TLayout;
    mmLog: TMemo;
    PSUtil: TPSUtil;
    Torch: TPyTorch;
    Pillow: TPillow;
    RemBG: TRemBG;
    OpenDialog: TOpenDialog;
    Layout2: TLayout;
    btnTest: TButton;
    Splitter1: TSplitter;
    Layout3: TLayout;
    btnImage: TButton;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure PackageBeforeInstall(Sender: TObject);
    procedure PackageAfterInstall(Sender: TObject);
    procedure PackageInstallError(Sender: TObject; AErrorMessage: string);
    procedure PackageAfterImport(Sender: TObject);
    procedure PackageBeforeImport(Sender: TObject);
    procedure PackageBeforeUnInstall(Sender: TObject);
    procedure PackageAfterUnInstall(Sender: TObject);
    procedure PackageUnInstallError(Sender: TObject; AErrorMessage: string);
    procedure PackageAddExtraUrl(APackage: TPyManagedPackage; const AUrl: string);
    procedure btnTestClick(Sender: TObject);
    procedure btnImageClick(Sender: TObject);
  private
    { Private declarations }
    FTask: ITask;
    procedure Log(const AMsg: String);
    procedure SetupPackage(APackage: TPyManagedPackage);
    procedure SetupSystem;
    procedure ThreadedSetup;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

const
  pyver = '3.9';
  pypath = 'python';
  appname = 'RemBGPillow';

implementation

uses
  Math,
  PyPackage.Manager.Pip,
  PyPackage.Manager.Defs.Pip;

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
begin
  btnTest.Enabled := False;
  btnImage.Enabled := False;
  Layout1.Width := floor(Form1.Width / 2);
  SetupSystem;
end;

procedure TForm1.SetupSystem;
begin
  PyEng.IO := PyIO;
  PyIO.Output := mmLog;
  PyEng.RedirectIO := True;
  PyEng.AutoLoad := False;
  PyEmbed.PythonEngine := PyEng;
  PyEmbed.PythonVersion := pyver;
  // MacOSX with X64 CPU
  {$IF DEFINED(MACOS64) AND DEFINED(CPUX64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             'Library') +
                             appname) +
                             pypath;
  // MacOSX with ARM64 CPU (M1 etc)
  {$ELSEIF DEFINED(MACOS64) AND DEFINED(CPUARM64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             'Library') +
                             appname) +
                             pypath;
  // Windows X64 CPU
  {$ELSEIF DEFINED(WIN64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname) +
                             pypath;
  // Windows 32 bit
  {$ELSEIF DEFINED(WIN32)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname  + '-32')+
                             pypath;
  // Linux X64 CPU
  {$ELSEIF DEFINED(LINUX64)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname) +
                             pypath;
  // Android (64 CPU)Not presently working)
  {$ELSEIF DEFINED(ANDROID)}
  PyEmbed.EnvironmentPath := IncludeTrailingPathDelimiter(
                             IncludeTrailingPathDelimiter(
                             System.IOUtils.TPath.GetHomePath) +
                             appname) +
                             pypath;
  {$ELSE}
  raise Exception.Create('Need to set PyEmbed.EnvironmentPath for this build');
  {$ENDIF}
  // Create Pillow
  SetupPackage(Pillow);

  // Create RemBG
  SetupPackage(RemBG);

  // Create PSUtil
  {$IFNDEF MACOS64}
  SetupPackage(PSUtil);
  {$ENDIF}

  // Create Torch
  SetupPackage(Torch);
  {$IF DEFINED(USEGPUIFPRESENT) AND NOT DEFINED(USEMACOS64)}
  PackageAddExtraUrl(Torch, 'https://download.pytorch.org/whl/cu116');
  {$ENDIF}

  Log('Python path = ' + PyEmbed.EnvironmentPath);
  //  Call Setup
  FTask := TTask.Run(ThreadedSetup);

end;

procedure TForm1.ThreadedSetup;
begin
    try
      PyEmbed.Setup(PyEmbed.PythonVersion);
      FTask.CheckCanceled();
      TThread.Synchronize(nil, procedure() begin
        var act: Boolean := PyEmbed.Activate(PyEmbed.PythonVersion);
        if act then
          Log('Python Activated')
        else
          Log('Python Activation failed');
      end);
      FTask.CheckCanceled();

      Pillow.Install();
      FTask.CheckCanceled();

      RemBG.Install();
      FTask.CheckCanceled();

      {$IFNDEF MACOS64}
      PSUtil.Install();
      FTask.CheckCanceled();
      {$ENDIF}

      Torch.Install();
      FTask.CheckCanceled();

      TThread.Queue(nil, procedure() begin
        try
          MaskFPUExceptions(true);
          try
            Pillow.Import();
            RemBG.Import();
            {$IFNDEF MACOS64}
            PSUtil.Import();
            {$ENDIF}
            Torch.Import();
          finally
            MaskFPUExceptions(false);
          end;
        finally
          btnTest.Enabled := True;
          btnImage.Enabled := True;
        end;
        Log('All done!');
      end);
    except
      on E: Exception do begin
        TThread.Queue(nil, procedure() begin
          ShowMessage('Something went terribly wrong');
        end);
      end;
    end;
end;

procedure TForm1.Log(const AMsg: String);
begin
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    TThread.Synchronize(nil,
      procedure()
      begin
        mmLog.Lines.Add('* ' + AMsg);
        mmLog.GoToTextEnd;
        mmLog.Repaint;
      end
      )
  else
    begin
      mmLog.Lines.Add(AMsg);
      mmLog.GoToTextEnd;
      mmLog.Repaint;
    end;
end;

procedure TForm1.PackageAddExtraUrl(APackage: TPyManagedPackage; const AUrl: string);
var
  popts: TPyPackageManagerDefsPip;
begin
  popts := TPyPackageManagerDefsPip(APackage.Managers.Pip);
  popts.InstallOptions.ExtraIndexUrl := AUrl;
end;

procedure TForm1.PackageBeforeInstall(Sender: TObject);
begin
  Log('Installing ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterInstall(Sender: TObject);
begin
  Log('Installed ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageInstallError(Sender: TObject; AErrorMessage: string);
begin
  Log('Error for ' + TPyPackage(Sender).PyModuleName + ' : ' + AErrorMessage);
end;

procedure TForm1.PackageBeforeUnInstall(Sender: TObject);
begin
  Log('UnInstalling ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterUnInstall(Sender: TObject);
begin
  Log('UnInstalled ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageUnInstallError(Sender: TObject; AErrorMessage: string);
begin
  Log('Error for ' + TPyPackage(Sender).PyModuleName + ' : ' + AErrorMessage);
end;

procedure TForm1.PackageBeforeImport(Sender: TObject);
begin
  Log('Importing ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterImport(Sender: TObject);
begin
  Log('Imported ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.SetupPackage(APackage: TPyManagedPackage);
begin
  APackage.PythonEngine := PyEng;
  APackage.PyEnvironment := PyEmbed;

  APackage.AutoImport := False;
  APackage.AutoInstall := False;

  APackage.BeforeInstall := PackageBeforeInstall;
  APackage.AfterInstall := PackageAfterInstall;
  APackage.OnInstallError := PackageInstallError;
  APackage.BeforeImport := PackageBeforeImport;
  APackage.AfterImport := PackageAfterImport;
  APackage.BeforeUnInstall := PackageBeforeUnInstall;
  APackage.AfterUnInstall := PackageAfterUnInstall;
  APackage.OnUnInstallError := PackageUnInstallError;
end;

procedure TForm1.btnImageClick(Sender: TObject);
var
  image_in, image_out: Variant;
begin
  if not Pillow.IsImported then
    begin
      ShowMessage('Failed to import Pillow');
      Exit;
    end;
  try
    if OpenDialog.Execute then
      begin
        Log('Reading in ' + OpenDialog.FileName);
        image_in := Pillow.PIL.Image.open(OpenDialog.FileName);
        Log('Removing background from ' + OpenDialog.FileName);
        image_in := RemBG.rembg.remove(image_in);
        if SaveDialog.Execute then
          begin
            Log('Saving as ' + SaveDialog.FileName);
            image_in.save(SaveDialog.FileName);
          end;
      end;
  except
    on E: Exception do
      begin
        Log('Unhandled Exception');
        Log('Class : ' + E.ClassName);
        Log('Error : ' + E.Message);
      end;
  end;
end;

procedure TForm1.btnTestClick(Sender: TObject);
var
  I: Integer;
begin
  var gpu_count: Variant := Torch.torch.cuda.device_count();
  Log('Torch returned gpu_count = ' + gpu_count);
  if gpu_count > 0 then
    begin
      for I := 0 to gpu_count - 1 do
        begin
          var gpu_props: Variant := Torch.torch.cuda.get_device_properties(i);

          Log('Torch returned Name = ' + gpu_props.name);
          Log('Torch returned CudaMajor = ' + gpu_props.major);
          Log('Torch returned CudaMajor = ' + gpu_props.minor);
          Log('Torch returned Memory = ' + gpu_props.total_memory);
          Log('Torch returned CUs = ' + gpu_props.multi_processor_count);
        end;
    end;
  {$IFNDEF MACOS64}
  var cpu_cores: Variant := PSUtil.psutil.cpu_count(False);
  var cpu_threads: Variant := PSUtil.psutil.cpu_count(True);
  var cpu_freq: Variant := PSUtil.psutil.cpu_freq();
  var virtual_memory: Variant := PSUtil.psutil.virtual_memory();

  Log('PSUtil returned cpu_cores = ' + cpu_cores);
  Log('PSUtil returned cpu_threads = ' + cpu_threads);
  Log('PSUtil returned cpu_freq = ' + cpu_freq.current);
  Log('PSUtil returned total_memory = ' + virtual_memory.total);
  Log('PSUtil returned available_memory = ' + virtual_memory.available);
  {$ENDIF}
end;

end.
