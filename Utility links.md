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
- *[Bayden MezerTools](https://bayden.com/mezer)
- [StudioShell](http://studioshell.codeplex.com/) - DTE: access in VS (alt: `Install-Package StudioShell.Provider`)
- [Dependency Walker](http://www.dependencywalker.com/) - PE dependency scanner
- [ILSpy](https://github.com/icsharpcode/ILSpy) - .NET assembly browser and decompiler
- [Papercut](http://papercut.codeplex.com/) - simplified SMTP server with WPF UI <https://github.com/changemakerstudios/papercut>
- [LinqPad](http://www.linqpad.net) - .NET code scratchpad
- [PowerShell Gallery](https://www.powershellgallery.com/) or [PsGet](https://psget.net/) for older versions
    - `Install-Module -Name PowerShellGet -Force` or the PsGet iex
    - `Install-Module -Name Posh-Git -Force -AllowClobber`
    - `Install-Module -Name PSCX -Force -AllowClobber`
    - `Uninstall-Module AzureRm; Install-Module -Name Az -AllowClobber -Scope AllUsers`
- [Chocolatey](https://chocolatey.org/install) - Windows installer manager
    - `choco upgrade git 7zip zip unzip vscode nodejs-lts notepadplusplus googlechrome sysinternals firefox ilspy Linqpad5.AnyCPU.install InkScape paint.net nuget.commandline ruby.portable papercut dependencywalker large-text-file-viewer -y`
    - \# git.portable notepadplusplus.commandline ?silverlight? ?insomnia-rest-api-client? ?conemu?
    - `choco upgrade clipx -pre -y`
    - `choco install IIS-WebServerRole --source windowsfeatures -y`
    - s/community/enterprise/ ? `choco upgrade netfx-4.7.2-devpack netfx-4.8-devpack dotnetcore-sdk dotnetcore-windowshosting  visualstudio2019community visualstudio2019-workload-netweb visualstudio2019-workload-manageddesktop visualstudio2019-workload-Azure  visualstudio2019-workload-nativedesktop visualstudio2019-workload-netcoretools visualstudio2019-workload-netcrossplat visualstudio2019-workload-node  -y -r --no-progress --force --includeRecommended --includeOptional`
    - `choco install dotnetcore-sdk -y --allowmultiple --version "$(choco list dotnetcore-sdk -a | sls '2\.1\.' | sort | select -l 1 | % { $_.Line.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)[1]})"`
    - `choco upgrade docker-desktop -y`
    - `choco upgrade vlc audacity-lame audacity-ffmpeg audacity eac calibre ghostscript.app irfanview musescore -y`
    - `choco upgrade azure-cli microsoftazurestorageexplorer -y`
    - `choco upgrade sql-server-express sql-server-management-studio -y`

- other VS extensions
    - [Editor Guidelines](https://marketplace.visualstudio.com/items?itemName=PaulHarrington.EditorGuidelines) - allows column guides in VS editors
        - `Set-itemproperty -path 'HKCU:\Software\Microsoft\VisualStudio\9.0\Text Editor' -name Guides -type string -value 'RGB(128,0,0) 72, 80, 120, 132'`
        - Ctrl-Alt-A for Command window; `Edit.AddGuideline 72`
    - Refactoring Essentials
    - CodeMaid
    - SqlCeVsToolbox (SQLite/SQL Server Compact Toolbox)
    - ? EF Core Power Tools
    - IndentGuide
    - ? T4Toolbox
    - ~~Web Essentials~~ Web Extension Pack
        - NPM Task Runner
        - Sidewaffle Template Pack
        - Trailing Whitespace Visualizer
    - .NET Portability Analyzer [Analyzers](https://docs.microsoft.com/en-us/dotnet/standard/analyzers/)
    - ? Serilog Analyzer
    - Concurrency Visualizer
    - Open PowerShell Prompt
    - Productivity Power Tools
    - ? VSDebrix
    - [Regular Expression Tester Extension](https://marketplace.visualstudio.com/items?itemName=AndreasAndersen.RegularExpressionTesterExtension) or [Regex Editor](https://marketplace.visualstudio.com/items?itemName=GeorgyLosenkov.RegexEditorLite)
    - [XPath Tools](https://marketplace.visualstudio.com/items?itemName=UliWeltersbach.XPathInformation)
    - Solution Error Visualizer

- VSCode extensions
    - markdownlint
    - C#
    - PowerShell
    - SQL Server (mssql)
    - hexdump for VSCode
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
    "editor.renderWhitespace": "boundary",
    "editor.rulers": [
        72,80,120,132
    ]
    ```
