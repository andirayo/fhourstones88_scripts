# fhourstones88_scripts
Scripts using fhourstones88

```
git clone --recursive git@github.com:andirayo/fhourstones88_scripts.git
cd fhourstones88_scripts/fhourstones88/
# potentially fix problem for Ubunut in line 139 of Search.cpp by adding as 3rd parameter:  ", S_IRUSR|S_IWUSR"
make
cd ../
apt-get install expect    # yum install expect
bundle install


# start Sinatra webserver:
ruby app.rb -o 0.0.0.0

# test locally in terminal:
ruby solve_situation.rb [GAME-NUMBER] (dutch|german|english)
ruby solve_situation.rb 'e1, e2, e3, e4, e5, e6, e7'
```

Please, refer to
https://github.com/tromp/fhourstones88


