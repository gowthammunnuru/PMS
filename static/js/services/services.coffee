angular.module("perform").service "HTTP", ($http) ->

  # Expose this method so that HomeCtrl can use it
  # Essentially equivalent to this.search
  @search = (query) ->
    url = "ip/" + query
    return $http.get(url)

  return


# Service for adding Backgound events
angular.module("perform").service "BG", [

  "$q"
  "$state"
  "$rootScope"

  ($q, $state, $rootScope) ->

    $rootScope.deferList = []

    # Add to deferList is anything is going on
    @addToDefer = () ->

      defer = $q.defer()

      if $rootScope.preventNavigation
        $rootScope.deferList.push(defer)
      else
        defer.resolve("Success")

      defer.promise


    # Resolve all defer in deferList
    @resolveAll = () ->
      for defer in $rootScope.deferList
        defer.resolve(true)
      $rootScope.deferPresent = false

    @go = (state, params, options) ->
      $rootScope.deferPresent = true
      @addToDefer().then (response) ->

        $state.go(state, params, options)

    return
]

angular.module("perform").service "WS", [

  "$q"
  "$rootScope"
  "$state"

  ($q, $rootScope, $state) ->
    REVOKE_ADMIN_RIGHTS ='REVOKE_ADMIN_RIGHTS'

    # Create our websocket object with the address to the websocket
    _listener = (data) ->
      messageObj = data



      # If an object exists with callback_id in our callbacks object, resolve it
      if callbacks.hasOwnProperty(messageObj.callback_id)
        if messageObj.data.error && (messageObj.data.error == 'auth_error' || messageObj.data.error == 'error')

          console.log("ERROR: #{messageObj.data.error}")

          $state.transitionTo 'auth_error', {},
            location: 'replace'
            inherit: true
            relative: $state.$current
            notify: true

          $rootScope.$apply callbacks[messageObj.callback_id].cb.reject(messageObj.data)
        else if messageObj.data.error && messageObj.data.error == 'waitlist_error'
          $state.go 'editing_in_progress',
            {isCurrentlyEditedBy:[messageObj.data.isCurrentlyEditedBy]}
        else
          $rootScope.$apply callbacks[messageObj.callback_id].cb.resolve(messageObj.data)


        delete callbacks[messageObj.callbackID]
      return

    # Keep track of requests via a random callback_id
    # so that when the result gets back from backend,
    # we know what the original request was.
    sendRequest = (request) ->

      request.query.auth = $rootScope.auth().user

      defer = $q.defer()

      # Generate a random callbackId
      callbackId = "xxxxxxxxx".replace(/[xy]/g, (c) ->
        r = Math.random() * 16 | 0
        v = (if c is "x" then r else (r & 0x3 | 0x8))
        v.toString 16
      )
      data = {}
      data.request = request
      data.callback_id = callbackId
      callbacks[callbackId] = cb: defer
      unless ws.readyState is 0
        ws.send JSON.stringify(data)
      else
        requestsBacklog.push data
      defer.promise

    callbacks = {}
    currentCallbackId = 0
    requestsBacklog = []

    host = "" + window.location.host
    if host.split(":").length is 2
      port = host.split(":")[1]
      host = host.split(":")[0]
      uri = "ws://#{host}:#{port}/ws/ip"
    else
      port = 443
      uri = "wss://#{host}:#{port}/ws/ip"
    console.log "Connecting to #{uri}"

    initDefer = $q.defer()
    initDefer.promise.then (x) ->

      for request in requestsBacklog
        ws.send(JSON.stringify(request))

      return

    ws = new ReconnectingWebSocket(uri)

    ws.onopen = ->
      $rootScope.$broadcast('connection-open')
      $rootScope.$apply initDefer.resolve(true)
      return

    ws.onmessage = (message) ->
      _listener JSON.parse(message.data)
      return

    ws.onclose = () ->
      $rootScope.$broadcast('connection-lost')

    @login = (auth) ->
      d =
        type: 'login'
        query:
          user: auth.user
          pass: auth.pass

      promise = sendRequest(d)

      return promise

    @getReviewByUser = (uid, year, rname, reviewType) ->

      d =
        type: 'get_review'
        query:
          uid: uid
          year: year
          rname: rname
          review_type: reviewType

      promise = sendRequest(d)

      return promise

    @checkBusyReviewerForMulti = (requests) ->

      d =
        type: 'check_busy_reviewer_for_multi'
        query:
          review_list: requests

      promise = sendRequest(d)

      return promise


    @getReviewByUserMulti = (requests) ->

      d =
        type: 'get_review_multi'
        query:
          requests: requests

      promise = sendRequest(d)

      return promise

    @getEditableReviews = (uid) ->

      d =
        type: 'get_editable_reviews'
        query:
          uid: uid

      promise = sendRequest(d)

      return promise

    @getTemplate = (query) ->

      d =
        type: "template_lookup"
        query: query

      promise = sendRequest(d)
      return promise

    @getAllTemplateTypes = (year, rname) ->

      d =
        type: 'get_all_template_types'
        query:
          year: year
          rname: rname
          review_type: 'weights'  # This is required for handler_get_review()

      promise = sendRequest(d)
      return promise


    @getAllReviewsByYear = (uid, year, rname) ->

      d =
        type: 'get_all_reviews_by_year'
        query:
          uid: uid
          year: year
          rname: rname
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @getAllAdmins = () ->

      d =
        type: 'get_all_admins'
        query:
          activity:'SETUP_ROLES'

      promise = sendRequest(d)
      return promise


    @removeAdmin = (user) ->

      d =
        type: 'modify_admins'
        query:
          uid:user.uid
          uname: user.givenName+" "+ user.surname
          ou:user.ou
          date:new Date()
          roles:user.roles
          permissions:user.permissions
          action:REVOKE_ADMIN_RIGHTS
          activity:'SETUP_ROLES'

      promise = sendRequest(d)
      return promise

    @addAdmin = (user) ->

      d =
        type: 'modify_admins'
        query:
          uid:user.uid
          uname: user.givenName+" "+ user.surname
          ou:user.ou
          date:new Date()
          roles:user.roles
          permissions:user.permissions
          action:''
          activity:'SETUP_ROLES'

      promise = sendRequest(d)
      return promise


    @getAdminData = (uid) ->

      d =
        type: 'get_admin_data'
        query:
          uid: uid
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @setTemplateID = (uid, year, rname, template_id) ->

      d =
        type: 'set_template_id'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @okToPublishReview = (uid, year, rname, template_id) ->

      d =
        type: 'ready2publish_review'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @publishReview = (uid, year, rname, template_id) ->

      d =
        type: 'publish_review'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id

      promise = sendRequest(d)
      return promise

    @commitReview = (uid, year, rname, reviewType, template_id) ->

      d =
        type: 'commit_review'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @uncommitReview = (uid, year, rname, reviewType, template_id) ->

      d =
        type: 'uncommit_review'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @acknowledgeReview = (uid, year, rname, reviewType, template_id) ->

      d =
        type: 'acknowledge_review'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @sendSelfReviewReminder = (uid, year, rname) ->

      d =
        type: 'send_self_review_reminder'
        query:
          uid: uid
          year: year
          rname: rname

      promise = sendRequest(d)
      return promise


    @setPermissions = (uid, year, rname, template_id, permitted_users) ->

      d =
        type: 'set_permissions'
        query:
          uid: uid
          year: year
          rname: rname
          template_id: template_id
          permitted_users: permitted_users

      promise = sendRequest(d)
      return promise

    @addSelfReview = (uid, year, rname, review_body, template_id, reviewer) ->
      '''
      change_type can be 'review_add'
      '''

      d =
        type: 'self_review_add'
        query:
          uid: uid
          year: year
          rname: rname
          review_body: review_body
          template_id: template_id
          reviewer: reviewer

      promise = sendRequest(d)
      return promise

    @addReview = (uid, year, rname, review_body, template_id, reviewer) ->
      '''
      change_type can be 'review_add'
      '''

      d =
        type: 'review_add'
        query:
          uid: uid
          year: year
          rname: rname
          review_body: review_body
          template_id: template_id
          reviewer: reviewer

      promise = sendRequest(d)
      return promise

    @addDraft = (uid, year, rname, review_body, template_id, reviewer, reviewType) ->
      '''
      change_type can be 'review_draft'
      '''

      d =
        type: 'review_draft'
        query:
          uid: uid
          year: year
          rname: rname
          review_body: review_body
          template_id: template_id
          reviewer: reviewer
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @addReviewers = (uid, year, rname, users, reviewType) ->

      d =
        type: 'set_reviewers'
        query:
          mode: 'add'
          uid: uid
          year: year
          rname: rname
          users: users
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @removeReviewers = (uid, year, rname, users, reviewType) ->

      d =
        type: 'set_reviewers'
        query:
          mode: 'remove'
          uid: uid
          year: year
          rname: rname
          users: users
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @updateIsBusyReviewer = (uid, year, rname, isBusy, isCurrentlyEditedBy) ->

      d =
        type: 'update_busy_reviewer'
        query:
          uid: uid
          year: year
          rname: rname
          isBusy: isBusy
          isCurrentlyEditedBy:isCurrentlyEditedBy

      promise = sendRequest(d)
      return promise

    @getBusyReviewer = (uid, year, rname) ->

      d =
        type: 'get_busy_reviewer'
        query:
          uid: uid
          year: year
          rname: rname

      promise = sendRequest(d)
      return promise

    @addContributors = (uid, year, rname, users, reviewType) ->

      d =
        type: 'set_contributors'
        query:
          mode: 'add'
          uid: uid
          year: year
          rname: rname
          users: users
          review_type: reviewType

      promise = sendRequest(d)
      return promise

    @removeContributors = (uid, year, rname, users, reviewType) ->

      d =
        type: 'set_contributors'
        query:
          mode: 'remove'
          uid: uid
          year: year
          rname: rname
          users: users
          review_type: reviewType

      promise = sendRequest(d)
      return promise


    @getUser = (uid) ->

      d =
        type: 'get_user'
        query:
          uid: uid

      promise = sendRequest(d)
      return promise

    @setupReview = (year, rname, data) ->

      d =
        type: 'setup_review'
        query:
          year: year
          rname: rname
          data: data
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @archiveReview = (year, rname) ->
      '''
      Request to archvie a review
      '''

      d =
        type: 'archive_review'
        query:
          year: year
          rname: rname
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @unarchiveReview = (year, rname) ->
      '''
      Request to unarchvie a review
      '''

      d =
        type: 'unarchive_review'
        query:
          year: year
          rname: rname
          activity: "EDIT_REVIEWS"

      promise = sendRequest(d)
      return promise

    @getFeedback = (uid) ->

      d =
        type: 'get_feedback'
        query:
          uid: uid

      promise = sendRequest(d)
      return promise

    @addFeedback = (uid, feedback_body, change_type) ->

      d =
        type: 'add_feedback'
        query:
          uid           : uid
          feedback_body : feedback_body
          change_type   : change_type

      promise = sendRequest(d)
      return promise

    @getAppMetadata = () ->
      '''
      Get app metadata from the backend
      '''
      d =
        type : "app_metadata"
        query: ''

      promise = sendRequest(d)

      return promise

    @fetchBacklogStats = (ryear, rtype) ->
      '''
      Fetches the number of reviews per person
      '''
      d =
        type: 'fetch_backlog_stats'
        query:
          review_year: ryear
          review_type: rtype
          activity: "EDIT_REVIEWS"

      promise = sendRequest d
      return promise

    @setTemplateWeights = (template_id, year, rname) ->
      '''
      Initializes template weights
      '''
      d =
        type: 'set_template_weights'
        query:
          template_id: template_id
          year: year
          rname: rname
          activity: "EDIT_REVIEWS"

      promise = sendRequest d
      return promise

    return
]
