# Komoku

### key value storage + time series database + pub sub

Komoku is a key value database for different types of data, which keeps track of all changes, and then can compact historical data in a clever way. You can subscribe to different key changes.

For now the API is going to be compatible with ruby version (https://github.com/comboy/komoku) but after I migrate my home automation to the new system I'm going to update it.

Why am I even writing this readme, it's way too early for that.

## Key types

HA denotes my personal use case in home automation as an example

### Numeric

Double. I'm considering using actual numeric type (specified precision, exact). Currently there's only gauge but I plan adding different types similar to what's known from rrdtool. It should be able to use different aggregations (for now, most of my cases are covered with gauge avg/min/max so I'm focusing on that)

HA: tracking temp, humidity light etc.

### Boolean

True and false. But. It represents the state changes that last. So with boolean you should be able to get stats like:

* what value was present at given time
* uptime-like stats e.g. 99.5% true during last month
* sum of time stats e.g. number of hours per day for which the state was false
* maybe common timespans stats (like avg distribution per hour during last month)

Boolean can be used for representing timespans between value changes.

HA: state of the light somewhere, is door open, is window open, how often am I at home

### Uptime

Boolean which automatically goes to false if not updated for `:max_time`

### String

Custom string.

* you can disable compacting and just use it as a log (better yet let's compact it, keeping in mind that it is a logfile), separate type may appear for that
* or you can be only assigning to it some set of strings representing state of something (stats then are boolean-alike but with more values)
* or use it to store some kind of config

HA: log, what's the alarm state (armed, disabled, waiting), selected radio station, what room I'm in

## TODO

### Features

* compacting historical data
* fetching historical data
** treating booleans as timespans
* user authentication

### Polishing and optimization

* reorg Storage vs Server
* KH supervisor, they are currently linked to master
* better error handling, there are supervisors but incorrect user input shouldn't be resulting in any process crash
* unused key processes can be killed when there's like 100K+ of them
* add bench for 100K+ keys
* use benchfella
* add distillery
* beter docs

### Low priority features

* protobuf + tcp as an alternative to websocket
* komowku-web with graphs
* string opt to only allow specified set of values (careful with `update_key` and historical values that may not comply)
