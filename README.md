# Powershell-7z-backup
(RU) Cкрипт умеет архивировать содержимое (папки\файлы) прямым доступом или из теневой копии. Для архивации используется [7-zip](http://7-zip.org/ "официальный сайт")
. Автор не несет ответственности за любые последствия в результате установки и использования данного скрипта, пользователь использует его "как есть" на свой страх и риск.

(EN) The script can archive content (folders \ files) by direct access or from a shadow copy. [7-zip](http://7-zip.org/ "official site") is used for archiving. The author is not responsible for any consequences as a result of the installation and use of this script, the user uses it "as is" at his own peril and risk.

----
Перед использованием необходимо установить [7-zip](http://7-zip.org/ "official site")

В репозитории 3 файла:

1. install.ps1: *Автоматическая установка и настройка скрипта. Копирует скрипт backup_lite.ps1 в папку %appdata%, создает ярлык "Архивация.lnk" на рабочем столе и задание в "планировщике заданий" windows.*

**Usage:** *install.ps1 %1 %2 %3*
* %1 - путь до каталога с файлами, которые архивируем;
* %2 - путь до каталога, в который складываем архивы;
* %3 - пароль на архив (по умолчанию: "12345678").
```powershell
  Install -SrcPath $var1 -DstPath $var2 -TypeBackup $var3
```

2. backup_lite.ps1: *скрипт архивации*

**Usage:** *backup_lite.ps1 %1 %2 %3*
* %1 - путь до каталога с файлами, которые архивируем;
* %2 - путь до каталога, в который складываем архивы;
* %3 - тип архива (0-из теневой копии, 1-прямым доступом).
```powershell
  Backup -SrcPath $var1 -DstPath $var2 -TypeBackup $var3
```

3. backup_release.ps1: *скрипт архивации с возможностью отправки уведомлений о создании архива на почту*

**Usage:** *backup_release.ps1 %1 %2 %3 %4*
* %1 - путь до каталога с файлами, которые архивируем;
* %2 - путь до каталога, в который складываем архивы;
* %3 - тип архива (0-из теневой копии, 1-прямым доступом);
* %4 - признак отправки уведомлений на почту.
```powershell
  Backup -SrcPath $var1 -DstPath $var2 -TypeBackup $var3 -HasSendMail $var4	
```



