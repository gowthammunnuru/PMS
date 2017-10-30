"use strict"


angular.module("perform").service "Cache", [

  "WS"
  "$q"
  "$timeout"
  "Portal"
  "Auth"
  "$state"


  (WS, $q, $timeout, Portal, Auth, $state) ->
# -------------------------------------------------------------------------------------
# Declaring the data structures to hold all the cached information as key value pairs
# -------------------------------------------------------------------------------------

    @userCache     = {}
    @reviewsCache  =
      'review'              : {}    # Reviews
      'self-review'         : {}    # Self Reviews
      'weights-performance' : {}    # Weights Performance
      'weights-potential'   : {}    # Weights Potential

    @templateCache = {}

    @feedbackCache = {}
    @allReviewsMetaData = {}

    anonUser =
      uid: 'anonymous'
      cn: 'Guest User'

    @appMetaData = {}

    @reset = () ->
      @userCache = {}
      @reviewsCache =
        'review'              : {}    # Reviews
        'self-review'         : {}    # Self Reviews
        'weights-performance' : {}    # Weights Performance
        'weights-potential'   : {}    # Weights Potential

      @templateCache = {}
      @feedbackCache = {}
      @allReviewsMetaData = {}
      @appMetaData = {}

    @getAppMetadata = () ->
      '''
      Get metadata of the app itself.
      '''

      if not @appMetaData.metadata
        WS.getAppMetadata().then (response) =>
          @appMetaData.metadata = response
          return response
      else
        metadata = @appMetaData.metadata
        return $q.when(metadata)

    @userCache[anonUser.uid] = anonUser

    @populateReviewsCache = (response, reviewType) ->

      uid   = response.latest_review.uid
      year  = response.latest_review.year
      rname = response.latest_review.rname


      reviewkey = @reviewkey(uid, year, rname)
      cached    = @reviewsCache[reviewType][reviewkey]

      if cached
        _.assign(@reviewsCache[reviewType][reviewkey], response)
      else
        @reviewsCache[reviewType][reviewkey] = response

    @getUser = (uid) ->
      '''
      uid:user information pair is retrieved
      '''
      if not @userCache[uid]
        console.log("Getting #{uid}")
        Portal.getUserInfo(uid).then (response) =>
          @userCache[response?.uid] = response
          return response

      else
        defer = $q.defer()
        user = @userCache[uid]
        defer.resolve(user)
        return defer.promise

    @getAllReviewsForUser = (uid) ->
      if not @allReviewsMetaData[uid]
        @allReviewsMetaData[uid] = []
        WS.getUser(uid).then (response) =>
          for year, reviews of response.reviews.data
            @allReviewsMetaData[uid].push {'year': year, 'name': review.rname} for name, review of reviews
          return @allReviewsMetaData[uid]
      else
        defer = $q.defer()
        defer.resolve @allReviewsMetaData[uid]
        return defer.promise

    @reviewkey = (uid, year, rname) -> "#{uid}-#{year}-#{rname}"

    @massageReview = (review) ->

        defer1 = $q.all(review.permitted_users.map (uid) => @getUser(uid)).then (users) =>

          review.permitted_users = _.filter(users)

          return review

        defer2 = $q.all(review.contributors.map (uid) => @getUser(uid)).then (users) =>

          review.contributors = _.filter(users)

          return review

        defer3 = $q.all(_.map(review.feedbacks, (x) => @getUser(x.reviewer))).then (users) =>

          _.map(_.zip(review.feedbacks, users), (x) => x[0].reviewer_user = x[1])

          # UPDATE -
          #   backend is no longer sending feedbacks_grouped
          #
          # OLD DESC (keeping it around just in case someone wants context) -
          #
          #  Even though backend is sending `feedbacks_grouped` we're overwriting it here because
          #  our version has uid and userInfo, while what backend supplies just has `uid`
          review.feedbacks_grouped = _.groupBy(review.feedbacks, (x) -> x.reviewer)

        return $q.all([defer1, defer2, defer3]).then (response) => review


    @getReviewByUser = (uid, year, rname, reviewType, forceUpdate = false) ->
      '''
      get notes from the cache if it exists, if not fetch
      from backend (using WS) and return it
      '''
      if (forceUpdate) or (not @reviewsCache[reviewType][@reviewkey(uid, year, rname)])

          return WS.getReviewByUser(uid, year, rname, reviewType).then (response) =>

                                                                            @massageReview(response).then (ret) =>

                                                                              @populateReviewsCache(response, reviewType)

                                                                              return response

                                                    , (response) ->
                                                      $state.transitionTo 'auth_error', {},
                                                        location: 'replace'
                                                        inherit: true
                                                        relative: $state.$current
                                                        notify: true


      else

        defer = $q.defer()
        response = @reviewsCache[reviewType][@reviewkey(uid, year, rname)]
        defer.resolve(response)
        return defer.promise


    @getReviewByUserMulti = (requests, forceUpdate = false) ->

      defers = []
      toResolve = []

      for request, i in requests

        uid        = request.uid
        year       = request.year
        rname      = request.rname
        reviewType = request.review_type

        if (forceUpdate) or (not @reviewsCache[reviewType][@reviewkey(uid, year, rname)])
          toResolve.push(request)
        else
          defer = $q.defer()
          cached = @reviewsCache[reviewType][@reviewkey(uid, year, rname)]
          defers.push(defer.promise)
          defer.resolve([cached])

      if toResolve.length

        defer = WS.getReviewByUserMulti(toResolve).then (response) =>

          for review in response
            @massageReview(review).then (ret) =>
              @populateReviewsCache(ret, ret.latest_review.review_type)


          return response


        defers.push(defer)

      return $q.all(defers).then (responses) =>
        responses = _.flatten(responses)

        orderedResponse = []

        requestOrder  = (x.uid for x in requests)
        responseOrder = (x.latest_review.uid for x in responses)

        for req in requestOrder

          index = responseOrder.indexOf(req)

          item = responses[index]

          orderedResponse.push(item)

        return orderedResponse

    @getTemplate = (templateID) =>
      '''
      Get template from the cache if it exists, if not fetch
      from Template and return it
      '''
      if not @templateCache[templateID]

        WS.getTemplate(templateID).then (response) =>

          @templateCache[templateID] = response

          return response

      else

        defer = $q.defer()
        template = @templateCache[templateID]
        defer.resolve(template)
        return defer.promise

    @getAdminData = () ->

      WS.getAdminData(Auth.getUser().uid)

    @getAllReviewsByYear = (year, rname)->
      '''
      Get all users' reviews of a particular year
      '''

      WS.getAllReviewsByYear(Auth.getUser().uid, year, rname)


    @getAuthUserInfo = () =>
      '''
      Get Authenticated userinfo
      '''

      WS.getUser(Auth.getUser().uid).then (response) =>

        uids = []
        defers = []

        for _, reviews of response.editable

          defers = defers.concat reviews['review'].map (review) => @getUser(review.uid).then (response) -> review.user = response
          defers = defers.concat reviews['self-review'].map (review) => @getUser(review.uid).then (response) -> review.user = response

        # Wait for all the defers, and return the original "response", which now has a new field "user"
        $q.all(defers).then (retVal) =>
          return response

    @getFeedback = (uid) ->
      '''
      Get feedback of a specified user
      '''
      WS.getFeedback(uid)

    @addFeedback = (feedback, change_type) ->
      '''
      Commit feedback
      '''
      WS.addFeedback(feedback.uid, feedback.feedback_body, change_type)

    @portal = {}

    @getAllAdmins = () ->
      WS.getAllAdmins()

    @addAdmin = (user) ->
      WS.addAdmin(user)

    @removeAdmin = (user) ->
      WS.removeAdmin(user)

    @getAllUsers = () ->

      if not @portal.allusers
        console.time('Portal.getUsers()')
        return Portal.getAllUsers().then (response) =>
          console.timeEnd('Portal.getUsers()')
          response = response.hits.hits
          results = []
          for i in response
            results.push(i._source)

          @portal.allusers = results
          #response
          #console.log(response)
      else
        allusers = @portal.allusers
        return $q.when(allusers)

    $timeout () =>
      @getAllUsers()
    , 1

    return

]
