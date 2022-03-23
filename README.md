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
