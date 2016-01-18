# fhourstones88_scripts
Scripts using fhourstones88

```
git clone --recursive git@github.com:andirayo/fhourstones88_scripts.git
cd fhourstones88_scripts/fhourstones88/
# compile with extra memory:
# g++ -std=c++11 -O3 -Wextra -Wall -DWIDTH=8 -DHEIGHT=8 -DBOOKWORK=24 -DLOCKSIZE=42 -DTRANSIZE=1040187403 C4.cpp Search.cpp Window.cpp -o C488
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


