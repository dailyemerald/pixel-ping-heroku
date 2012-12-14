## Deploy Pixel Ping on Heroku

Clone the repo, setup a Heroku app and drop in two config varibles:

<code>
heroku config:add INTERVAL=10
</code>

<code>
heroku config:add ENDPOINT=http://somebackend/endpoint
</code>

If you're using WordPress, you could drop the image tag toward the bottom of &lt;body> with something like this:

<code>
&lt;img src="http://<your-app-name>.herokuapp.com/pixel.gif?key=<?php the_permalink()?>"></img>
</code>