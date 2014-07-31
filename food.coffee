# Description:
#   Commands for ordering food.
#
# Commands:

_ = require 'underscore'
orderUtils = require './orderUtils'

address = process.env.HUBOT_ADDRESS
city = process.env.HUBOT_CITY
state = process.env.HUBOT_STATE
zip = process.env.HUBOT_ZIP
phone = process.env.HUBOT_ORDRIN_PHONE
email = process.env.HUBOT_ORDRIN_EMAIL
firstName = process.env.HUBOT_ORDRIN_FIRST_NAME
lastName = process.env.HUBOT_ORDRIN_LAST_NAME

module.exports = (robot) ->

  HUBOT_APP = {}
  HUBOT_APP.state = 1 #1-listening, 2-Selecting a restaurant 3-gathering orders 4-verify order
  HUBOT_APP.rid = ""
  HUBOT_APP.users = {} #user state 0 - waiting for order, 1 - waiting for confirmation, 2 - waiting for new request confirmation, 3 - complete
  HUBOT_APP.leader = ''
  HUBOT_APP.restaurants = []

  # What to do in case of an emergency.
  robot.error (err, msg) ->
    console.log err
    if msg?
      console.log msg
      msg.send "Something bad happened! #{err}"

  # Listen for the start of an order.
  robot.respond /start order$/i, (msg) ->
    if HUBOT_APP.state is 1
      leader = msg.message.user.name
      HUBOT_APP.leader = leader
      HUBOT_APP.users[leader] = {}
      HUBOT_APP.users[leader].orders = []
      HUBOT_APP.users[leader].state = 0
      msg.send "#{HUBOT_APP.leader} is the leader, and has started a group order."

      orderUtils.getUniqueList "ASAP", address, city, zip, 5, (err, data) ->
        if err
          msg.send err
          return err
        HUBOT_APP.restaurants = data
        restaurantsDisplay = ''
        for rest, index in data
          restaurantsDisplay += "(#{index}) #{rest.na}, "
        msg.send "Tell me a restaurant to choose from: #{restaurantsDisplay} (say \"more\" to see more restaurants)"
        HUBOT_APP.state = 2

  # Listen for the leader to say that everyone is in.
  robot.respond /done$/i, (msg) ->
    user = msg.message.user.name
    if user is HUBOT_APP.leader and HUBOT_APP.state is 3
      userString = ''
      _.each HUBOT_APP.users, (user, name) ->
        for order in user.orders
          userString += "#{name}: #{order.name}\n"
      msg.send "Awesome! Lets place this order. Here is what everyone wants:"
      msg.send userString
      msg.send "Is this correct?"
      HUBOT_APP.state = 4

  # Listen for users who want to be removed from the order.
  robot.respond /I'm out$/i, (msg) ->
    user = msg.message.user.name
    if user isnt HUBOT_APP.leader
      HUBOT_APP.users = _.filter HUBOT_APP.users, (userInOrder) -> userInOrder isnt user
      msg.send "I'm sorry to hear that. Looks like #{user} doesn't want to get food with us."

  # Listen for the leader to choose a restaurant.
  robot.respond /(.*)/i, (msg) ->
    if HUBOT_APP.state isnt 2 or msg.message.user.name isnt HUBOT_APP.leader
      return

    if isFinite msg.match[1]
      restaurant = HUBOT_APP.restaurants[msg.match[1]]
      msg.send "Alright lets order from #{restaurant.na}! Everyone enter the name of the item from the menu that you want. #{HUBOT_APP.leader}, tell me when you are done. Tell me \"I'm out\" if you want to cancel your order."
      HUBOT_APP.rid = "#{restaurant.id}"
      HUBOT_APP.state = 3
    else
      msg.send "I didn't get that. Can you try telling me again?"

  # Listen for orders.
  robot.respond /I want (.*)/i, (msg) ->
    if HUBOT_APP.state isnt 3 and HUBOT_APP.users[msg.message.user.name].state isnt 0
      return

    user = msg.message.user.name
    if user isnt HUBOT_APP.leader and user not in _.keys(HUBOT_APP.users)
      HUBOT_APP.users[user] = {}
      HUBOT_APP.users[user].state = 0
      msg.send "Awesome! #{user} is in!"

    order = escape(msg.match[1])

    orderUtils.getRelevantMenuItems(HUBOT_APP.rid, order,
      (err, data) ->
        if err
          console.log err
          return err
        console.log data[0]
        msg.send "#{msg.message.user.name} did you mean: \"#{data[0].name} (Price: #{data[0].price})\"?"
        HUBOT_APP.users[msg.message.user.name].pending_order = data[0]
        HUBOT_APP.users[msg.message.user.name].state = 1
    )

  # Listen for confirmation
  robot.respond /yes/i, (msg) ->
    username = msg.message.user.name

    if HUBOT_APP.state is 3 and HUBOT_APP.users[username].state is 2
      msg.send "#{username}, aight fatty. what do you want?"
      HUBOT_APP.users[username].state = 0
    if HUBOT_APP.state is 3 and HUBOT_APP.users[username].state is 1
      HUBOT_APP.users[username].orders.push(HUBOT_APP.users[username].pending_order)
      HUBOT_APP.users[username].state = 2
      msg.send "Cool. #{username} is getting #{HUBOT_APP.users[username].pending_order.name}."
      msg.send "#{username}, do you want anything else?"
    else if HUBOT_APP.state is 4
      # confirm and place order
      tray = ''
      _.each HUBOT_APP.users, (user) ->
        for order in user.orders
          tray += "+#{order.tray}"

      params =
        rid: HUBOT_APP.rid
        email: email
        first_name: firstName
        last_name: lastName
        phone: phone
        addr: address
        city: city
        state: state
        zip: zip
        tray: tray.substring(1)

      console.log params
      orderUtils.placeOrder params, (err, data) ->
        if err
          console.log err
          msg.send "Sorry guys! We messed up: #{err.body._msg}"
          HUBOT_APP.state = 1
          return err
        console.log data
        msg.send "Order placed: #{data.msg}"
        HUBOT_APP.state = 1

  # Listen for confirmation
  robot.respond /no/i, (msg) ->
    username = msg.message.user.name

    if HUBOT_APP.state is 3 and HUBOT_APP.users[username].state is 2
      HUBOT_APP.users[username].state = 3
      msg.send "#{username}, hold on while everyone else orders!"
    if HUBOT_APP.state is 3 and HUBOT_APP.users[username].state is 1

      msg.send "Well, #{username} what DO you want then?"
    else if HUBOT_APP.state is 4
      msg.send "It's all good. I'll keep listening for orders!"
      HUBOT_APP.state = 3

  # Print current orders
  robot.respond /ls/i, (msg) ->
    for user in HUBOT_APP.users
      msg.send "" + user + " is getting " + HUBOT_APP.users[user].order.name
