# cabot-device-check

## run check
```
docker-compose build
docker-compose run --rm check   # 通常出力
docker-compose run --rm checkj  # JSON通常出力
docker-compose run --rm test    # 通常出力 Test
docker-compose run --rm testj   # JSON通常出力 Test
```


## reuse SSH connection for faster device check
- add the following setting into ~/.ssh/config
```
Host *
     ControlMaster auto
     ControlPath  ~/.ssh/sockets/%r@%h-%p
     ControlPersist 600
```

## If check_device_status.sh and/or CaBot-odrive-diag.py were modified, please update *.pot, *.po and *.mo files for i18n (internationalization).

- Please make new *.pot file for each scripts.
```
$ xgettext -o potmp/check_device_status/check_device_status.pot check_device_status.sh
$ pygettext3 -o potmp/CaBot-odrive-diag/CaBot-odrive-diag.pot CaBot-odrive-diag.py
```

- Please update *.po files and make new *.mo files for each scripts and languages.
```
$ cd potmp/check_device_status
$ msgmerge -U ja.po check_device_status.pot --no-wrap
$ msgmerge -U en_US.po check_device_status.pot --no-wrap
$ vi ja.po        # Please edit msgstr lines in the file.
$ vi en_US.po     # Please edit msgstr lines in the file.
$ msgfmt -o ../../locale/ja/LC_MESSAGES/check_device_status.mo ja.po
$ msgfmt -o ../../locale/en_US/LC_MESSAGES/check_device_status.mo en_US.po

$ cd potmp/CaBot-odrive-diag
$ msgmerge -U ja.po CaBot-odrive-diag.pot --no-wrap
$ msgmerge -U en_US.po CaBot-odrive-diag.pot --no-wrap
$ vi ja.po        # Please edit msgstr lines in the file.
$ vi en_US.po     # Please edit msgstr lines in the file.
$ msgfmt -o ../../locale/ja/LC_MESSAGES/CaBot-odrive-diag.mo ja.po
$ msgfmt -o ../../locale/en_US/LC_MESSAGES/CaBot-odrive-diag.mo en_US.po
```
