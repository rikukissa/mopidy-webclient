# Mopidy webclient

Under development. 
Still needs a lot of work and is not ready for basic users.



## Development environment requirements

* Node.js
* CoffeeScript
* Running [Mopidy](http://www.mopidy.com/) instance



## Start development

    npm install
    james
    iexplore http://localhost:9002
    
You'll have to change the mopidy.js path **client/index.jade** and webSocketUrl in **client/js/main.coffee**

## Technology choices

* [James](https://github.com/leonidas/james.js)
* [Browserify](https://github.com/substack/node-browserify)
* [CoffeeScript](https://github.com/jashkenas/coffee-script)
* Static [Jade](https://github.com/visionmedia/jade) templates
* [Stylus](https://github.com/learnboost/stylus)
* [UglifyJS](https://github.com/mishoo/UglifyJS2)
* [Knockout](https://github.com/knockout/knockout)

## User interface

#### Now playing
![](http://i.imgur.com/rZ9ccqw.png)
#### Sidebar
![](http://i.imgur.com/5Ioopvk.png)

#### Play queue
![](http://i.imgur.com/71J3Cao.png)
#### List filtering
![](http://i.imgur.com/WQON8kv.png)
#### Search
![](http://i.imgur.com/pr8orlw.png)

## Default album art n__n
![](http://i.imgur.com/F8WJGOM.jpg)

