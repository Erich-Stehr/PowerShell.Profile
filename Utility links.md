- *[ClipX](https://web.archive.org/web/20200111230002/https://bluemars.org/clipx/) - clipboard manager, add ClipX Stickies to keep entries around
    - $env:LOCALAPPDATA\ClipX\clipx_${env:USERNAME}.ini ; a Stickies preset copy is in OneDrive
- *?[PureText](http://stevemiller.net/puretext/) - strips formatting from text on clipboard
    - extract to $env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup
- *[GitExtensions](http://gitextensions.github.io/) - adds Git menu to VS 2005-2015
    - `git config --local --add user.email Erich-Stehr@users.noreply.github.com`
    - `git config --local --add user.name "Erich Stehr"`
    - `git config --global color.status.changed "red normal bold"`
    - `git config --global color.status.untracked "red normal bold"` # <https://stackoverflow.com/questions/18420139/changing-git-status-output-colors-in-posh-git>
    - `git config --global color.status.added "green normal bold"`
    - `git config --global color.diff.old "red normal bold"`
    - `git config --global color.diff.new "green normal bold"`
    - `git config --global color.branch.remote "red normal bold"`
    - `git config --global merge.tool kdiff3` or use vsdiffmerge.gitconfig and set vsdiffmerge
    - `git config --global format.pretty 'tformat:%h%C(auto)% D %aI %al:: %s'`
    - `git config --global merge.tool vscode ; git config --global mergetool.vscode.cmd 'code --wait --merge $REMOTE $LOCAL $BASE $MERGED' ; git config --global diff.tool vscode ; git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'` # <https://stackoverflow.com/questions/44549733/how-to-use-visual-studio-code-as-the-default-editor-for-git-mergetool-including>

- *[Bayden MezerTools](https://bayden.com/mezer)
    - `Set-ItemProperty 'HKCU:\SOFTWARE\Bayden Systems\Mezer' HotKeysModifier 3` # (Ctrl-Alt) from 8 (Win)
- [StudioShell](http://studioshell.codeplex.com/) - DTE: access in VS (alt: `Install-Package StudioShell.Provider`)
- [Dependency Walker](http://www.dependencywalker.com/) - PE dependency scanner
- [ILSpy](https://github.com/icsharpcode/ILSpy) - .NET assembly browser and decompiler
- [Papercut](http://papercut.codeplex.com/) - simplified SMTP server with WPF UI <https://github.com/changemakerstudios/papercut>
- [LinqPad](http://www.linqpad.net) - .NET code scratchpad
- [PowerShell Gallery](https://www.powershellgallery.com/) or [PsGet](https://psget.net/) for older versions
    - `Install-Module -Name PowerShellGet -Force` or the PsGet iex
    - `Install-Module -Name Posh-Git -Force -AllowClobber -Scope CurrentUser`
    - `PowerShellGet\Install-Module posh-sshell -Scope CurrentUser -Force -AllowClobber` # SSH connection/server manager
    - `Install-Module -Name PSCX -Force -AllowClobber -Scope CurrentUser`
    - `Uninstall-AzureRm; Install-Module -Name Az -AllowClobber -Scope AllUsers`
    - `Install-Module -Name ImportExcel -Force -AllowClobber -Scope CurrentUser`
    - after VS/dotnet/Chocolatey `dotnet tool (install|upgrade) --global powershell --ignore-failed-sources  --add-source https://api.nuget.org/v3/index.json`
    - Powershell background color #233c67 aka R:35 G:60 B:103
- [Chocolatey](https://chocolatey.org/install) - Windows installer manager
    - `choco install python2 -y --forcex86`
    - `choco upgrade git 7zip zip unzip vscode nodejs-lts notepadplusplus googlechrome sysinternals babelmap firefox ilspy Linqpad5.AnyCPU.install InkScape paint.net nuget.commandline ruby.portable python papercut dependencywalker large-text-file-viewer winmerge microsoft-windows-terminal err drawio testdisk-photorec -y`
        - `choco uninstall googlechrome firefox microsoft-windows-terminal thunderbird -n --skipautouninstaller` # auto-updating, so just need Chocolatey to install then not update
    - `choco install dotnet3.5 wget -y`
    - `choco install chromedriver selenium-gecko-driver selenium-chromium-edge-driver -y` ? /skip-shim ?
    - `choco upgrade OpenSSL.Light -y` # <https://adamtheautomator.com/openssl-windows-10/>
    - \# git.portable notepadplusplus.commandline silverlight insomnia-rest-api-client conemu kdiff3 pencil krita
        - notepadplusplus: Settings > Preferences. Editing. Multi-select.
    - `choco upgrade clipx -pre -y`
    - `choco install NetFx3 IIS-WebServerRole Containers-DisposableClientVM --source windowsfeatures -y`
    - `choco upgrade netfx-4.6.2-devpack netfx-4.7.2-devpack netfx-4.8-devpack netfx-4.8.1-devpack -y`
        - list.exe from Windows Debugging Kit in Windows Settings > Apps > Windows SDK > Change (may need to use VS Installer; ${env:ProgramFilesX86}\Windows Kits)
        - `sqllocaldb v` failure on 13.1 (2016) needs `ren 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server Local DB\Installed Versions\13.0' 13.1`
        - `choco uninstall "vcredist140,KB2533623"` choose option 3's to allow NET(Core) upgrades with `all -y`
    - ? `choco upgrade dotnetcore-sdk dotnetcore-3.1-runtime dotnetcore-3.1-aspnetruntime  -y -r --no-progress --force --includeRecommended --includeOptional`
        - `choco uninstall dotnetcore-windowshosting dotnet-5.0-windowshosting dotnet-aspnetcoremodule-v2 -y; choco install dotnet-aspnetcoremodule-v2 dotnetcore-3.1-runtime dotnetcore-3.1-aspnetruntime dotnet-5.0-runtime dotnet-5.0-aspnetruntime -y` per <https://github.com/dotnetcore-chocolatey/dotnetcore-chocolateypackages/issues/62>
        - `choco install dotnetcore-sdk -y --allowmultiple --version "$(choco list dotnetcore-sdk -a | sls '2\.1\.' | sort | select -l 1 | % { $_.Line.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)[1]})"`
    - `choco install dotnet-aspnetcoremodule-v2 -y` # for multi-version aspnetcore
    - `choco install dotnet-8.0-sdk dotnet-8.0-runtime dotnet-8.0-aspnetruntime dotnet-8.0-desktopruntime -y` # not the `dotnet-*-windowshosting` metapackage!
    - `choco install dotnet-9.0-sdk dotnet-9.0-runtime dotnet-9.0-aspnetruntime dotnet-9.0-desktopruntime -y` # not the `dotnet-*-windowshosting` metapackage!
    - s/community/enterprise/ ? ` choco install visualstudio2022community visualstudio2022-workload-node visualstudio2022-workload-azure visualstudio2022-workload-python visualstudio2022-workload-visualstudioextension visualstudio2022-workload-nativecrossplat visualstudio2022-workload-manageddesktop visualstudio2022-workload-nativemobile visualstudio2022-workload-netcrossplat visualstudio2022-workload-netweb visualstudio2022-workload-universal visualstudio2022-workload-nativedesktop visualstudio2022-workload-azurebuildtools -y -r --no-progress --force --includeRecommended --includeOptional ` # visualstudio2022-workload-managedgame visualstudio2022-workload-nativegame
    - `choco install Microsoft-Windows-Subsystem-Linux VirtualMachinePlatform --source windowsfeatures -y ; choco install docker-desktop -y; choco uninstall docker-desktop -n --skipautouninstaller`
        - `choco install podman-cli podman-desktop -y` # instead of Docker Desktop; `podman machine init; podman machine start`
    - `choco upgrade wixtoolset -y`
    - `choco upgrade powertoys -y`
    - `choco upgrade vlc audacity-lame audacity-ffmpeg audacity lame eac calibre ghostscript.app irfanview okular thunderbird musescore openshot freeciv sigil imgburn cobian-backup obs-studio.install -y`
    - `choco upgrade azure-cli microsoftazurestorageexplorer azcopy azcopy10 -y`
    - `choco upgrade sql-server-management-studio azure-data-studio -y`
        - `choco install sql-server-express <# -o -ia "'/FEATURES=LocalDB'"#> -y; choco uninstall sql-server-express -n --skip-autouninstaller`
        - `choco install sqllocaldb -y`
    - `choco install sqlitebrowser -y`

- other VS extensions (choco isn't up to date)
    - [Editor Guidelines](https://marketplace.visualstudio.com/items?itemName=PaulHarrington.EditorGuidelines) - allows column guides in VS editors
        - `Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\9.0\Text Editor' -name Guides -type string -value 'RGB(128,0,0) 72, 80, 120, 132'`
        - Ctrl-Alt-A for Command window; `Edit.AddGuideline 72`
    - Refactoring Essentials
    - CodeMaid
    - SqlCeVsToolbox (SQLite/SQL Server Compact Toolbox)
    - ? EF Core Power Tools
    - IndentGuides
    - ? T4Toolbox ? T4 Language
    - Web Essentials ~~Web Extension Pack~~
        - NPM Task Runner
        - Sidewaffle Template Pack
        - Trailing Whitespace Visualizer
        - Open Command Line/Open PowerShell Prompt
    - .NET Portability Analyzer [Analyzers](https://docs.microsoft.com/en-us/dotnet/standard/analyzers/), [.NET Upgrade Assistant](https://docs.microsoft.com/en-us/dotnet/core/porting/upgrade-assistant-overview)
    - ? Serilog Analyzer, Moq Analyzer
    - Concurrency Visualizer
    - Productivity Power Tools
        - Time Stamp Margin
        - Solution Error Visualizer
    - VSDebrix
    - [Regular Expression Tester Extension](https://marketplace.visualstudio.com/items?itemName=AndreasAndersen.RegularExpressionTesterExtension) or [Regex Editor](https://marketplace.visualstudio.com/items?itemName=GeorgyLosenkov.RegexEditorLite)
    - [XPath Tools](https://marketplace.visualstudio.com/items?itemName=UliWeltersbach.XPathInformation)
    - WiX Toolset Visual Studio * Extension, Wax (3rd party WiX editor)
    - SpecFlow for Visual Studio 20** (Cucumber/Gherkin/Given-When-Then; <https://specflow.org>)
    - ? PostSharp (AOP)

- VSCode extensions
    - markdownlint
    - C# (or C# Dev Kit)
    - PowerShell
    - SQL Server (mssql)
    - ~~hexdump for VSCode~~ HexEditor
    - Python / Pylance / Jupyter
    - Remote - Containers (after Docker Desktop install)
    - EditorConfig for VSCode
    - XML Tools
    - Azure Resource Manager (ARM) Tools, Bicep
    - user settings (File > Preferences > Settings)

    ```json
    "markdownlint.config": {
        "default": true,
        "MD007": { "indent": 4 },
        "MD013": false,
        "MD041": false,
        "no-hard-tabs": false
    },
    "editor.wordWrap": "on",
    "editor.renderControlCharacters": true,
    "editor.renderWhitespace": "boundary", // "all"
    "editor.rulers": [
        72,80,120,132
    ]
    ```

- Windows Terminal settings.json changes

    ```json
    {
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles":
    {
      "defaults": {
        "fontSize": 8
      },
    }
    "keybindings":
    [
        { "command": "unbound", "keys": "ctrl+shift+c" },
        { "command": "unbound", "keys": "ctrl+shift+v" },
    ]

    }
    ```
