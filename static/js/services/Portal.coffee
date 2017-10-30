angular.module("perform").service "Portal", [

  "$q"
  "$http"
  "$rootScope"
  "$location"
  ($q, $http, $rootScope, $location) ->

    sendHTTPRequest = (url) ->

      $http.get(url).then (response) -> response.data

    # Create our websocket object with the address to the websocket
    _listener = (data) ->
      messageObj = data

      # If an object exists with callback_id in our callbacks object, resolve it
      if callbacks.hasOwnProperty(messageObj.callback_id)
        $rootScope.$apply callbacks[messageObj.callback_id].cb.resolve(messageObj.data)
        delete callbacks[messageObj.callbackID]
      return

    # Keep track of requests via a random callback_id
    # so that when the result gets back from backend,
    # we know what the original request was.
#    sendRequest = (request) ->
#      defer = $q.defer()
#
#      # Generate a random callbackId
#      callbackId = "xxxxxxxxx".replace(/[xy]/g, (c) ->
#        r = Math.random() * 16 | 0
#        v = (if c is "x" then r else (r & 0x3 | 0x8))
#        v.toString 16
#      )
#      data = {}
#      data.request = request
#      data.callback_id = callbackId
#      callbacks[callbackId] = cb: defer
#      unless ws.readyState is 0
#        ws.send JSON.stringify(data)
#      else
#        requestsBacklog.push data
#      defer.promise
#
#    callbacks = {}
#    currentCallbackId = 0
#    requestsBacklog = []
#    host = 'portal.ddu-india.com'
#
#    backendPorts = [81, 82, 83]
#    port = backendPorts[Math.floor(Math.random() * backendPorts.length)]
#
#    uri = "ws://#{host}:#{port}/ws/ip"
#
#    console.log "Connecting to " + uri
#    initDefer = $q.defer()
#    initDefer.promise.then (x) ->
#
#      for request in requestsBacklog
#        ws.send(JSON.stringify(request))
#
#      return
#
#    ws = new ReconnectingWebSocket(uri)
#
#    ws.onopen = ->
#      $rootScope.$broadcast('connection-open')
#      $rootScope.$apply initDefer.resolve(true)
#      return
#
#    ws.onmessage = (message) ->
#      _listener JSON.parse(message.data)
#      return
#
#    ws.onclose = () ->
#      $rootScope.$broadcast('connection-lost')
#
#    # This is what everybody from outside would access.
#    # Since we dont know when the result would appear on WebSocket,
#    # quickly create a promise and return.
#    #

    @performWSAPI = $location.protocol() + "://" + $location.host() + ":" + $location.port()
    @getUserInfo = (uid) ->
      url = "#{@performWSAPI}/get_user/#{uid}"
      sendHTTPRequest(url).then (response) ->
        return response

    @getAllUsersByLocation = (location)->
      location = encodeURI(location)
      url = "#{@performWSAPI}/get_active_location_users/#{location}"

      return sendHTTPRequest(url)


    @getAllUsers = (query) ->

      url = "#{@performWSAPI}/get_all_users"

      return sendHTTPRequest(url)

    return
]
