# Description:
#   Commands for ordering food.
#
# Commands:

_ = require "underscore"

module.exports = (robot) ->

  users = []
  canJoinOrder = false

  # Listen for the start of an order.
  robot.respond /start order$/i, (msg) ->
    leader = msg.message.user.name

    users.push leader
    canJoinOrder = true

    msg.send "#{leader} is the leader, and has started a group order. Reply \"I'm in\" to join."
    msg.send 'Reply "done" when everyone is in.'

    # Listen for the leader to say that everyone is in.
    robot.respond /done$/i, (doneMsg) ->
      user = doneMsg.message.user.name

      if user is leader and canJoinOrder
        canJoinOrder = false
        doneMsg.send 'Everyone is ready to order! Tell me "I\'m out" if you change your mind.'

  # Listen for users to join the order.
  robot.respond /I'm in$/i, (msg) ->
    user = msg.message.user.name
    if canJoinOrder and user not in users
      users.push user

  # Listen for users who want to be removed from the order.
  robot.respond /I'm in$/i, (msg) ->
    user = msg.message.user.name
    users = _.filter users, (userInOrder) -> userInOrder isnt user
