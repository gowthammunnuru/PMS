"use strict"


angular.module("perform").service "Reviews", [

  "$q"
  "$interval"
  "$timeout"
  "WS"
  "BG"
  "Cache"
  "Utils"
  "$rootScope"
  "$state"
  "Auth"

  ($q, $interval, $timeout, WS, BG, Cache, Utils, $rootScope, $state, Auth) ->

    @saveDefers = []
    @saveReviewFilter = []

    @reviews =
      'review'              : {}
      'self-review'         : {}
      'weights-performance' : {}
      'weights-potential'   : {}

    @drafts =
      'review'              : {}
      'self-review'         : {}
      'weights-performance' : {}
      'weights-potential'   : {}

    @reviewPayload = {}

    @remove = (review, reviewType) ->
      console.log("Removing #{@reviewkey(review)}")
      delete @reviews[reviewType][@reviewkey(review)]

    @getset = (review, reviewType) ->

      cached = @reviews[reviewType][@reviewkey(review)]

      if not (review?.year == cached?.year)

        review_packet =

          uid: review.uid
          year: review.year
          rname: review.rname

          review_body: review.review_body
          template_id: review.template_id
          reviewer: review.reviewer
          datetime: review.datetime
          change_type: review.change_type
          locked: review.locked
          committed: review.committed
          permitted_users: review.permitted_users
          review_type: reviewType

          auto_update_killswitch: null

        @reviews[reviewType][@reviewkey(review)] = review_packet

        @drafts[reviewType][@reviewkey(review)] = angular.copy(review_packet.review_body)

      else
        review_packet = cached

      @is_fresh = true
      return review_packet

    @set = (review, reviewType) ->

      reviewkey = @reviewkey(review)

      if not angular.equals({}, @reviews[reviewType])

        for key, value of review
          if key is "review_body"
            continue

          @reviews[reviewType][reviewkey][key] = value

#        # this loop is required to ensure the same object gets updated
#        for key, value of review.review_body
#          @reviews[reviewType][@reviewkey(review)].review_body[key] = value

        # TODO: The below is hopefully an equivalent for the above loop.
        # I dont want to change it now because we're headed into a first demo.
        _.assign(@reviews[reviewType][@reviewkey(review)].review_body, review.review_body)

    @getDiff = (oldValue, newValue) ->

      diff = {}

      for key, value of newValue

        if oldValue[key] isnt newValue[key]
          diff[key] = newValue[key]


      return diff

    @getReviewPacketByUserAndYear = (uid, year, rname, reviewType) ->

      @reviews[reviewType]["#{uid}-#{year}-#{rname}"]


    @robustReviewComparison = (newValue, oldValue) ->

        differentKeys = []
        for k, v of newValue
          if !_.isEqual(oldValue[k], v)
            differentKeys.push(k)

        if differentKeys.length == 0
          return true
        else if differentKeys.length == 1 and differentKeys[0] is 'datetime'
          return true
        else
          return false


    @setSaveStatus = (string, reviewType, token = '') ->

      if string == "saving"
        @save[reviewType].status = "Saving .."
      else if string == "pending"
        @save[reviewType].status = "Editing .."
      else if string == 'updating'
        @save[reviewType].status = "Updating .."
      else if string == 'saved'
        @save[reviewType].status = "Saved"
      else
        @save[reviewType].status = "Last edit was #{Utils.localtime(string).fromNow()}"
        @save[reviewType].last   = string
        @is_fresh = true

    @save =
      freq: 2 # 2 seconds
      'self-review'         : {}
      'review'              : {}
      'weights-performance' : {}
      'weights-potential'   : {}

    @reviewkey = (review) -> "#{review.uid}-#{review.year}-#{review.rname}"

    @setSaveReviewsFilter = (users) ->

      @saveReviewFilter = users

    @saveReviews = (reviewType) ->
      '''
      '''

      if @saveDefers.length > 0
        return

      toUpdate = []

      for reviewkey, review of @reviews[reviewType]

        # Skip save if already review is already locked, but allow for self-review (because we allow uncommit)
        if review.locked and reviewType == "review"
          return


        uid   = review.uid
        year  = review.year
        rname = review.rname

        if @saveReviewFilter.length > 0
          if uid not in @saveReviewFilter
            continue

        oldValue = @drafts[reviewType][reviewkey]
        newValue = review.review_body

        updates = @getDiff(oldValue, newValue)

        if Object.keys(updates).length isnt 0

          defer = WS.addDraft(review.uid, review.year, review.rname, updates, review.template_id, review.reviewer, reviewType)

          defer.then (response) ->
            console.log("WS.addDraft()", response)

          @saveDefers.push(defer)
        else
          console.log("Update from cache")

          request =
            uid         : uid
            year        : year
            rname       : review.rname
            review_type : reviewType

          toUpdate.push(request)

          #Cache.getReviewByUser(uid, review.year, review.rname, reviewType, forceUpdate = true).then (response) =>

          #  reviewkey = @reviewkey(response.latest_review)

          #  @set(response.latest_review, reviewType)

          #  @drafts[reviewType][reviewkey] = response.latest_review.review_body

          #  @setSaveStatus(response.latest_review.datetime, reviewType)
          #

      if toUpdate.length
        Cache.getReviewByUserMulti(toUpdate, forceUpdate = true).then (responses) =>

          console.log("Cache.getReviewByUserMulti() (#{reviewType})", responses)

          for response in responses

            reviewkey = @reviewkey(response.latest_review)

            reviewType = response.latest_review.review_type

            @set(response.latest_review, reviewType)

            @drafts[reviewType][reviewkey] = response.latest_review.review_body

            @setSaveStatus(response.latest_review.datetime, reviewType)


      @setSaveReviewsFilter([])


      if @saveDefers.length > 0

        @setSaveStatus("saving", reviewType)

        $q.all(@saveDefers).then (responses) =>

          for response in responses

            reviewkey = @reviewkey(response.latest_review)

            @set(response.latest_review, reviewType)
            @drafts[reviewType][reviewkey] = response.latest_review.review_body

          @setSaveStatus("saved", reviewType)

          _.map responses, (x) => @setSaveStatus(x.latest_review.datetime, reviewType)

          @saveDefers = []

      BG.resolveAll()

    @autoUpdate = (resetKillSwitch = false, freq = @save.freq, reviewType) =>

      rid = "xxx".replace(/[xy]/g, (c) ->
        r = Math.random() * 16 | 0
        v = (if c is "x" then r else (r & 0x3 | 0x8))
        v.toString 16
      )

      # XXX: Adding the following so that we dont lose characters when typing a comment.
      # This makes the save happen t + 3secs after user has input something.
      # Not ideal, but we need to find a way to prevent lost characters
      if resetKillSwitch
        $interval.cancel(@autoUpdatePromise)
        @autoUpdatePromise = null

      if not @autoUpdatePromise

        if not @is_fresh
          @setSaveStatus('updating', 'review')

          @saveReviews('review')
          @saveReviews('self-review')
          @saveReviews('weights-performance')
          @saveReviews('weights-potential')


        @autoUpdatePromise = $interval () =>


          @saveReviews('review')
          @saveReviews('self-review')
          @saveReviews('weights-performance')
          @saveReviews('weights-potential')

          Utils.hidePreventNavigation()
          # Resolve any defer present
          BG.resolveAll()

        , 1000 * freq

      if resetKillSwitch
        $timeout.cancel(@autoUpdateKillSwitch)
        @autoUpdateKillSwitch = null

      if not @autoUpdateKillSwitch
        @autoUpdateKillSwitch = $timeout () =>

          console.log('Inactivity detected. Killing auto update.')

          for reviewkey, review of @reviews[reviewType]

            if review.locked and reviewType == "review"
              return


            uid   = review.uid
            year  = review.year
            rname = review.rname
            WS.getBusyReviewer(uid, year, rname).then((response)->
              if response.isCurrentlyEditedBy is Auth.getUser().uid
                WS.updateIsBusyReviewer(uid, year, rname, false, "admin").then((response)->
                  if response is 'SUCCESS'
                    $state.go 'editing_in_progress',
                      {isCurrentlyEditedBy:['admin']}
                )
            )

          $interval.cancel(@autoUpdatePromise)
          @is_fresh = false
          @autoUpdatePromise = null
          @autoUpdateKillSwitch = null

        , 1000 * 60 * 10  # 10mins of inactivity

      return

    @autoUpdate()

    @stopAutoUpdate = () ->

      @autoUpdateKillSwitch = $timeout () =>

          console.log('Killing auto update.')
          $interval.cancel(@autoUpdatePromise)

          @is_fresh = false
          @autoUpdatePromise = null
          @autoUpdateKillSwitch = null

        , 1  #1 millisecond, stopping immediately

    return

]

