start-process -FilePath $PSHOME\powershell.exe -ArgumentList @("docker", "run", "--rm", "-it", "-e", "ACCEPT_EULA=Y", "-p", "127.0.0.1:8080:80", "-p", "5341:5341", "datalust/seq")
