- [ClipX](http://bluemars.org/clipx/) - clipboard manager
    - $env:APPDATA\..\Local\ClipX\clipx_${env:USERNAME}.ini
- [PureText](http://stevemiller.net/puretext/) - strips formatting from text on clipboard
    - extract to $env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup
- [GitExtensions](http://gitextensions.github.io/) - adds Git menu to VS 2005-2015
    - `git config --local --add user.email Erich-Stehr@users.noreply.github.com`
    - `git config --local --add user.name "Erich Stehr"`
    - `git config --global color.status.changed "red normal bold"`
    - `git config --global color.status.untracked "red normal bold"`
    - `git config --global merge.tool kdiff3` or use vsdiffmerge.gitconfig and set vsdiffmerge
- [StudioShell](http://studioshell.codeplex.com/) - DTE: access in VS (alt: `Install-Package StudioShell.Provider`)
- [Dependency Walker](http://www.dependencywalker.com/) - PE dependency scanner
- [ILSpy](http://ilspy.net) - .NET assembly browser and decompiler
- [Papercut](http://papercut.codeplex.com/) - simplified SMTP server with WPF UI <https://github.com/changemakerstudios/papercut>
- [LinqPad](http://www.linqpad.net) - .NET code scratchpad
- [PowerShell Gallery](https://www.powershellgallery.com/) or [PsGet](https://psget.net/) for older versions
    - `Install-Module -Name PowerShellGet -Force` or the PsGet iex
    - `Install-Module -Name Posh-Git -Force`

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

- VSCode extensions
    - markdownlint
    - C#
    - PowerShell
    - SQL Server (mssql)
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