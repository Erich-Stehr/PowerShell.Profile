start-process -FilePath $PSHOME\powershell.exe -ArgumentList @("docker", "run", "--rm", "-it", "-e", "ACCEPT_EULA=Y", "-p", "5341:80", "datalust/seq")
