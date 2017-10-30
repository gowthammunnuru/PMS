angular.module("perform").controller "MultiUserCtrl", [

  "$scope"
  "$rootScope"
  "$stateParams"
  "Reviews"
  "BG"
  "Utils"
  "userinfo"
  "users"
  "$state"
  "$interval"
  "$timeout"
  "Cache"
  "reviews"
  "selfReviews"
  "Auth"
  "WS"
  "$q"
  "$window"
  ($scope, $rootScope, $stateParams, Reviews, BG, Utils, userinfo, users, $state, $interval, $timeout, Cache, reviews, selfReviews, Auth, WS, $q, $window) ->
    $scope.busyBtnDetails=[]
    uids = $stateParams.uids.split('+')
    year = $stateParams.review_year
    rname = $stateParams.review_name
    review_list = []
    for uid in uids
      review_list.push(uid+"-"+year+"-"+rname)



    WS.checkBusyReviewerForMulti(review_list).then((response) ->
      if !_.isEmpty(response) &&  !_.contains(Auth.getUser().permissions, "EDIT_REVIEWS") && !_.contains(response, Auth.getUser().uid)
        console.debug(response)
        $state.go 'editing_in_progress',
          {'isCurrentlyEditedBy':response}
      else
        console.debug("You got the review sista!! :D ")
        if !_.contains(Auth.getUser().permissions, "EDIT_REVIEWS")
          for review in review_list
            WS.updateIsBusyReviewer(review.split("-")[0], year, rname, true, Auth.getUser().uid).then((response)->
              $scope.busyBtnDetails= Auth.getUser().uid
            )
    )

    templates = (review?.latest_template?.template_id for review in reviews)

    $scope.template_id = templates[0] # pick the first one.

    # Check if all folks have the same template
    sameTemplate = templates.every (t) -> t == templates[0]

    if not sameTemplate
      console.log('Not same template. Error (404)')
      $state.go('404') # TODO: Make this better

    # set scope.sections with the first entry. Not significant
    $scope.sections = (section for sectionName, section of reviews[0].latest_template.section)

    $scope.switchSection = (section) ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        $state.go('multi_user_review_year.section', {'section': section.name})

    $scope.$on '$destroy', () ->

      for own uid, review of $scope.multi_review
        Reviews.remove(review, $scope.review_type)

      Reviews.stopAutoUpdate()

    $scope.goToUser = (user, review_year, review_name) ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        $state.go('user_review_year.start', {'uid': user.uid, 'review_year': review_year, 'review_name': review_name})

    if $state.$current.data?.section
      $scope.sectionName = $state.$current.data.section
    else
      $scope.sectionName = $stateParams.section


    $scope.removeUser = (user) ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        # If only two users are present, removing one should redirect to another user's review page
        uids = (x.uid for x in $scope.users)
        uids.splice(uids.indexOf(user.uid), 1)
        if uids.length == 1
          $state.go("user_review_year.start", {uid: uids[0], review_year: $stateParams.review_year, review_name: $stateParams.review_name}, {})
        else
          $state.go("multi_user_review_year.section", section: $scope.sectionName, uids: uids.join("+"), {})

    $scope.users   = users

    $scope.headerString = "#{$scope.users[0].cn}, #{$scope.users[1].cn}"

    if $scope.users.length > 2
      $scope.headerString += " and +#{$scope.users.length - 2}"

    $scope.review_year = $stateParams.review_year
    $scope.review_name = $stateParams.review_name

    $scope.review_type = $state.current.data.review_type

    $scope.userinfo = userinfo

    $scope.possibleNewReviews = () ->
      displayed = (x.uid for x in $scope.users)
      allReviews = (x for x in $scope.userinfo.editable.unlocked.review)
      return (x for x in allReviews when (x.uid not in displayed && x.rname is $scope.review_name && x.template_id is $scope.template_id))

    $scope.addReview = (uid) ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        uids = (x.uid for x in $scope.users)
        uids.push(uid)

        $state.go("multi_user_review_year.section", {section: $scope.sectionName, uids: uids.join("+")}, {})

    $scope.multi_review         = {}
    $scope.multi_review_packet  = {}
    for review in reviews
      uid = review.latest_review.uid
      $scope.multi_review[uid] = Reviews.getset(review.latest_review, $scope.review_type)
      $scope.multi_review_packet[uid] = Reviews.getReviewPacketByUserAndYear(uid, $scope.review_year, $scope.review_name, $scope.review_type)

    noOfUsers =  $scope.users.length
    if noOfUsers < 30
      freq = null  # default
    else
      freq = 6

    Reviews.autoUpdate(resetKillSwitch = true, freq = freq)

    $scope.localtime = Utils.localtime

    $scope.save =
      texts:
        saved: 'All changes saved'
        in_progress: 'Saving ..'
      status: 'All changes saved'

    $scope.sortOptions =
      axis: 'x'
      revert: 100
      forcePlaceholderSize: true
      delay: 150
      cursor: "move"
      tolerance: "pointer"
      cancel: '.unsortable'
      stop: (e, ui) ->
        uids = (x.uid for x in $scope.users)
        $state.go("multi_user_review_year.section", {section: $scope.sectionName, uids: uids.join("+")}, {})


    $scope.$watch 'multi_review', (newValue, oldValue) ->

      $scope.$on '$destroy' , ()->
        if !Auth.isAdmin() && ( ($scope.busyBtnDetails is Auth.getUser().uid)|| (Auth.getStatus() == false) )
          for user in $scope.users
            console.debug(user.uid)
            WS.updateIsBusyReviewer(user.uid, $scope.review_year, $scope.review_name, false, "admin")



      if newValue is oldValue
        console.log("Comparision failed, returning ..")
        return

      y = _.map(_.zip(_.values(newValue), _.values(oldValue)), (x) -> Reviews.robustReviewComparison(x[0], x[1]))

      uids = (x.uid for x in _.values(newValue))

      dirtyUsers = []

      for items in _.zip(uids, y)

        [uid, changed] = items

        if not changed
          dirtyUsers.push(uid)

      Reviews.setSaveReviewsFilter(dirtyUsers)

      if dirtyUsers.length == 0
        console.log('No dirty users, returning ..')
        return

      Utils.showPreventNavigation()

      if $scope.onDemandSave
        $timeout.cancel($scope.onDemandSave)
        Reviews.autoUpdate(resetKillSwitch = true)

      Reviews.setSaveStatus('pending', $scope.review_type)

      console.log('Setting up on demand save', newValue)

      $scope.onDemandSave = $timeout () ->
        console.log("Dirty users", dirtyUsers)
        Reviews.saveReviews($scope.review_type)
        Utils.hidePreventNavigation()

        Reviews.autoUpdate(resetKillSwitch = true)

      , 1000 * 2

    , true

    $window.onunload= (event)->
      if $scope.busyBtnDetails is Auth.getUser()?.uid || (Auth.getStatus() == false) && !Auth.isAdmin()
        for review in review_list
          WS.updateIsBusyReviewer(review.split("-")[0], year, rname, false, Auth.getUser().uid)
      return

    return

]
