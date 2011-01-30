' Sistema de backup de site
' By 'amg1127' - amg1127<shift+2>gmail.com
'********************************************************'

Dim fso, wsh, pasta, titulo, rodou, ptmp, saida, nfconf, pbackcur, passo, nerros, papagar, pnav
Dim sitecopy_exec, sitecopy_conffile, sitecopy_rundir, backup_prefix, limtam, pdest, suff
Dim loginFTP, senhaFTP, siteFTP, raizFTP

'*********************************************************'
' Algumas configuracoes para mexer

titulo = "Sistema de Backup de site via FTP" ' Titulo das eventuais caixinhas de dialogo que aparecerem
backup_prefix = "site_backup_" ' Prefixo das pastas que guardam backups
limtam = 58 * 1024 * 1024 * 1024 ' 58GB de espaco para backups
loginFTP = "" ' Nome de usuario do site de FTP
senhaFTP = "" ' Senha do site FTP
siteFTP = "ftp.servidor.com.br" ' Site de FTP para acessar
raizFTP = "/" ' Dentro do site de FTP, qual pasta eh a raiz do site

'*********************************************************'

Sub ExitOnError(msg)
    If Err.Number <> 0 Then
        Call MsgBox (msg & vbCrLf & vbCrLf & Err.Number & ": " & Err.Description, 16, titulo)
        Call CreateObject("Scripting.FileSystemObject").GetFile(WScript.ScriptFullname).ParentFolder.Files.Item("sitecopyrc").Delete(True)
        Call WScript.Quit (1)
    End If
End Sub

Sub ContinueOnError(msg)
    If Err.Number <> 0 Then
        Call MsgBox (msg & vbCrLf & vbCrLf & Err.Number & ": " & Err.Description, 16, titulo)
        Call Err.Clear
    End If
End Sub

Function mknomepasta (pref)
    Dim y
    y = Year(Now)
    If y < 1900 Then
        y = y + 1900
    End If
    mknomepasta = pref & _
        y & Right ("0" & Month(Now), 2) & Right ("0" & Day(Now), 2) & "-" & _
        Right ("0" & Hour(Now), 2) & Right ("0" & Minute (Now), 2) & Right ("0" & Second(Now), 2)
End Function

Function ObtemNovoNome (pas) 
    Dim i, p
    i = 0
    p = pas
    Do While True
        i = InStr (i + 1, p, "\")
        If i = 0 Then
            Exit Do
        End If
        p = Left (p, i - 1) & "/" & Mid (p, i + 1)
    Loop
    If Mid (p, 2, 2) = ":/" Then
        p = Left (p, 1) & Mid (p, 3)
    Else
        Call Msgbox ("Erro fatal: este script so funciona se estiver localizado dentro de drives locais (i.e. 'A:\', 'C:\',...)!", 16, titulo)
        Call CreateObject("Scripting.FileSystemObject").GetFile(WScript.ScriptFullname).ParentFolder.Files.Item("sitecopyrc").Delete(True)
        Call WScript.Quit(1)
    End If
    ObtemNovoNome = "/cygdrive/" & p
End Function

' On Error Resume Next

' Inicializar alguns objetos fundamentais

Set wsh = CreateObject ("WScript.Shell")
Set fso = CreateObject ("Scripting.FileSystemObject")
Set pasta = fso.GetFile(WScript.ScriptFullname).ParentFolder
If Err.Number <> 0 Then
    Call MsgBox ("Erro inicializando programa!" & vbCrLf & vbCrLf & Err.Number & ": " & Err.Description, 16, titulo)
    Call CreateObject("Scripting.FileSystemObject").GetFile(WScript.ScriptFullname).ParentFolder.Files.Item("sitecopyrc").Delete(True)
    Call WScript.Quit (1)
End If

' Se o arquivo 'sitecopyrc' ja existe, eh sinal de que ha outro processo deste programa na memoria...
If fso.FileExists (pasta.Path & "\sitecopyrc") Or fso.FolderExists (pasta.Path & "\sitecopyrc") Then
    Call MsgBox ("Erro fatal: parece que ha outra instancia deste script em execucao." & vbCrLf & vbCrLf & _
                 "Se voce acha que isso esta errado, apague manualmente o arquivo '" & pasta.Path & "\sitecopyrc" & "'.", 16, titulo)
    Call WScript.Quit (1)
End If

' Localizar o executavel do sitecopy e ver se ele funciona
' (deveria estar na pasta ".\sitecopy.bin\bin")
rodou = 0
Set ptmp = pasta.SubFolders.Item("sitecopy.bin").SubFolders.Item("bin").Files.Item("sitecopy.exe")
If Err.Number = 0 Then
    saida = wsh.Run (Chr(34) & ptmp.Path & Chr(34) & " --version", 0, True)
    If Err.number = 0 Then
        If saida = 255 Or saida = 255 Then
            rodou = 1
        End If
    End If
End If

If rodou <> 1 Then
    Call ExitOnError ("Erro tentando executar 'sitecopy'!")
    Call CreateObject("Scripting.FileSystemObject").GetFile(WScript.ScriptFullname).ParentFolder.Files.Item("sitecopyrc").Delete(True)
    Call Msgbox ("Existe alguma anormalidade na instalacao que impede que este script localize e execute corretamente o programa 'sitecopy'. Investigue e corrija.", 16, titulo)
    Call WScript.Quit(1)
End If

' Criar a pasta de dados temporarios para o sitecopy (sitecopy.d)
If Not fso.FolderExists (pasta.Path & "\sitecopy.d") Then
    If fso.FileExists (pasta.Path & "\sitecopy.d") Then
        Call fso.DeleteFile(pasta.Path & "\sitecopy.d", true)
    End If
    Call fso.CreateFolder (pasta.Path & "\sitecopy.d")
End If

' Criar a pasta de copia do site, se ela nao existe
pbackcur = pasta.Path & "\" & backup_prefix & "current"
If Not fso.FolderExists (pbackcur) Then
    If fso.FileExists (pbackcur) Then
        Call fso.DeleteFile(pbackcur, true)
    End If
    Call fso.CreateFolder (pbackcur)
End If

passo = "--fetch"
nerros = 0

Do While True
    ' Criar ou refazer o arquivo sitecopyrc
    If loginFTP = "" Then
        loginFTP = "anonymous"
    End If
    If senhaFTP = "" Then
        senhaFTP = "anonymous@" + siteFTP
    End If
    Set sitecopy_conffile = pasta.CreateTextFile ("sitecopyrc", True)
    Call sitecopy_conffile.WriteLine("site backup_site")
    Call sitecopy_conffile.WriteLine("    server " & Chr(34) & siteFTP & Chr(34))
    Call sitecopy_conffile.WriteLine("    remote " & Chr(34) & raizFTP & Chr(34))
    Call sitecopy_conffile.WriteLine("    local " & Chr(34) & obtemnovonome(pbackcur) & Chr(34))
    Call sitecopy_conffile.WriteLine("    username " & Chr(34) & loginFTP & Chr(34))
    Call sitecopy_conffile.WriteLine("    password " & Chr(34) & senhaFTP & Chr(34))
    Call sitecopy_conffile.WriteLine("    protocol ftp")
    Call sitecopy_conffile.WriteLine("    permissions all")
    Call sitecopy_conffile.WriteLine("    permissions dir")
    Call sitecopy_conffile.WriteLine("    nodelete")
    Call sitecopy_conffile.WriteLine("    safe")
    Call sitecopy_conffile.Close
    Call ExitOnError ("Erro gravando arquivo de configuracao 'sitecopyrc'!")
    ' Verificar por atualizacoes no site...
    cmd = Chr(34) & ptmp.Path & Chr(34) & " " & _
          "-d files,ftp -r " & Chr(34) & obtemnovonome(pasta.Files.Item("sitecopyrc").Path) & Chr(34) & " " & _
          "-p " & Chr(34) & obtemnovonome(pasta.SubFolders.Item("sitecopy.d").Path) & Chr(34)
    Call ExitOnError ("Erro preparando linha de comando para ser executada!")
    saida = wsh.Run (cmd & " " & passo & " backup_site", 7, True)
    Call ExitOnError ("Erro executando linha de comando de verificacao!")
    If saida = 0 Then
        ' Sucesso
        If passo = "--fetch" Then
            passo = "--synch"
        Else
            Exit Do
        End If
    ElseIf saida = 2 Then
        ' Erro de autenticacao
        loginFTP = InputBox ("Ocorreu um erro de autenticacao no servidor de FTP." & vbCrLf & vbCrLf &_
                             "Digite o nome de usuario para uma nova tentativa de autenticacao:", titulo, loginFTP)
        senhaFTP = InputBox ("Digite a senha de autenticacao (CUIDADO, ELA SERA MOSTRADA NA TELA):", titulo, senhaFTP)
    Else
        ' Algum outro erro
        If passo = "--synch"  And nerros < 5 Then
            passo = "--fetch"
            nerros = nerros + 1
        Else
            Call pasta.Files.Item("sitecopyrc").Delete(True)
            Call MsgBox ("Impossivel realizar backup do site. Tente novamente mais tarde ou investigue o problema.", 16, titulo)
            Call WScript.Quit (1)
        End If
    End If
Loop

' Nomear a pasta
Do
    Call WScript.Sleep (1)
    pdest = pasta.Path & "\" & mknomepasta (backup_prefix)
Loop While fso.FolderExists (pdest) Or fso.FileExists (pdest)
Call fso.GetFolder(pbackcur).Copy(pdest, True)
Call ExitOnError ("Erro criando pasta de backup!")

' Apagar backups antigos
nerros = 0
Do While pasta.Size > limtam
    papagar = ""
    For Each pnav In pasta.SubFolders
        If Left(pnav.Name, Len(backup_prefix)) = backup_prefix Then
            If Len(pnav.Name) > Len(backup_prefix) Then
                suff = Right (LCase(pnav.Name), Len(pnav.Name) - Len(backup_prefix))
                If suff <> "current" Then
                    If papagar = "" Or StrComp (papagar, pnav.Name, 1) > 0 Then
                        papagar = pnav.Name
                    End If
                End If
            End If
        End If
    Next
    If papagar <> "" Then
        papagar = pasta.Path & "\" & papagar
        Call fso.DeleteFolder(papagar, True)
        If Err.Number <> 0 Then
            Call ContinueOnError ("Erro apagando pasta '" & papagar & "'!")
            nerros = nerros + 1
            If nerros > 4 Then
                Call CreateObject("Scripting.FileSystemObject").GetFile(WScript.ScriptFullname).ParentFolder.Files.Item("sitecopyrc").Delete(True)
                Call MsgBox ("Muitos erros durante a operacao de limpeza. Saindo...", 16, titulo)
                Call WScript.Quit (1)
            End If
        End If
    Else
        Exit Do
    End If
Loop

' Fim de papo...

Call pasta.Files.Item("sitecopyrc").Delete(True)
Call MsgBox ("Sincronismo foi realizado com sucesso em " & Now & ".", 64, titulo)
