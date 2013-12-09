# ip-tracker

This is a small Sinatra app to keep track of IP addresses for remote systems. Basically it's useful if you have one or more computers that could end up changing their IP address and you want to know what the latest it. It's sort of a poor-man's dynamic DNS.

## Updating
Make a POST request to `/ip/<host>`, where <host> is the name of the machine you want to record. (I use the system's hostname but this can be anything.) You don't need to give any POST parameters; the IP address is obtained from the `REMOTE_ADDR` environment variable.

I have a cron entry set up to update the IP for a host every 15 minutes:

    */15 *    *       *       *       POST http://<server>/ip/`hostname` </dev/null >/dev/null
    @reboot                           POST http://<server>/ip/`hostname` </dev/null >/dev/null

## Viewing
By default, the index page shows you the IP address of the computer you're connecting from, and doesn't record this.

You can see the saved IP for a machine by visiting `/ip/<host>`, which will tell you the last recorded IP and when it was recorded. (You can use `/ip/<host>.txt` to get just the IP address in plain-text.)

## Notes
There's no authentication, so there's nothing to stop someone from adding their hosts or overwriting yours. This is meant to be for personal use only and this arrangement suits me just fine. (You could probably configure your web server to require HTTP authentication to be able to access this app, if you so desired.)
