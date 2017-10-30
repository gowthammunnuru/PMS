angular.module("perform").controller "HomeCtrl", [
  "$scope"
  "$rootScope"
  "$stateParams"
  "$state"
  "WS"
  "BG"
  "Cache"
  "Auth"
  "Utils"
  "Reviews"
  "userinfo"
  "$modal"
  "$location"

  ($scope, $rootScope, $stateParams, $state, WS, BG, Cache, Auth, Utils, Reviews, userinfo, $modal, $location) ->

    $scope.userinfo = userinfo
    $scope.showStatistics = false
    $scope.isFilter = false
    $scope.percentage = {}
    $scope.statusCount = {}

    $scope.filteredReviews =
       active_results: {}
       archived_results: {}

    $scope.init = () ->
      #check if the url is correct or not
      if $state.current.url != $location.url()
        $location.url($state.current.url)

    $scope.init()

    # Ensuring that self-review comes before review
    $scope.userinfo.editable.unlocked = [
      $scope.userinfo.editable.unlocked['self-review']
      $scope.userinfo.editable.unlocked['review']
    ]

    $scope.validate = (review) ->
      if review.change_type isnt 'SET_TEMPLATE' and review.change_type isnt 'SET_REVIEWER'
        return true
      else
        return false

    # Filter added to remove reviews having state 'SET_REVIEWER' or 'SET_TEMPLATE'
    for reviews in $scope.userinfo.editable.unlocked
      index = $scope.userinfo.editable.unlocked.indexOf(reviews)
      indexToSplice = []
      for review in reviews
        if not $scope.validate(review)
          indexToSplice.push($scope.userinfo.editable.unlocked[index].indexOf(review))
      index2 = indexToSplice.length - 1
      while index2 >= 0
        $scope.userinfo.editable.unlocked[index].splice(indexToSplice[index2], 1)
        index2--

    # FIXME
    # Since publishing a review is essentially adding user to reviewer, remove those reviews
    # When we change this logic, the following filter wont be required
#    for reviews in $scope.userinfo.editable.unlocked
#
#      console.log(reviews)
#      reviews = (x for x in reviews when x.user.uid != Auth.getUser().uid)
#      console.log(reviews)
#
#    console.log($scope.userinfo.editable.unlocked)

#    $scope.userinfo.editable.unlocked = ((review for review in reviews when review.user.uid != Auth.getUser().uid) for reviews in $scope.userinfo.editable.unlocked)

    $scope._getUsersCount = () ->
      $scope.userinfo.editable.unlocked[1].length

    $scope._getCategoryCount = (category) ->
      count = 0

      # Calculate the stats for review only, not self-review
      for review in $scope.userinfo.editable.unlocked[1]
        if review.change_type is category
          count += 1
      return count

    $scope.calculateStatistics = () ->

      stages = ['READY2PUBLISH', 'COMMIT_REVIEW', 'REVIEW_DRAFT', 'SETUP_DONE']

      num_total_users = $scope._getUsersCount()

      $scope.percentage = {}
      $scope.statusCount = {}

      for category in stages
        $scope.statusCount[category] = $scope._getCategoryCount(category)
        $scope.percentage[category] = ($scope.statusCount[category] * 100) / num_total_users

    $scope.calculateStatistics()

    $scope.displayStats = (status) ->
      ###
      Displays a lightbox and shows detailed of task list
      ###
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-user-stats.html'
        controller: 'DialogUserStatsCtrl'
        size: 'lg'
        windowClass: 'dialog-user-stats'
        resolve:
          users: () ->
            # Send users depending on status
            users = []
            for user in $scope.userinfo.editable.unlocked[1]
              if user.change_type is status
                users.push(user)
            return users

          loggedUser: () ->
            return Auth.getUser().cn

          status: () ->
            return status

      dialog.result.then () ->
        return

      return

    $scope.tabs = [
      "pending"
      "archived"
    ]

    $scope.tabIndex = 0

    $scope.localtime = Utils.localtime

    $scope.len = (obj) ->
      items = []

      for x, y of obj
        items = items.concat y

      return items.length

    $scope.goToPublishedReview = (uid, year, rname) ->

      Cache.getReviewByUser(uid, year, rname, 'review').then (response) =>

        if response.latest_review.acknowledged
          $state.go 'user_review_year.start',
            uid: Auth.getUser().uid,
            review_year: year,
            review_name: rname
        else

          dialog = $modal.open
            templateUrl: 'static/partials/dialog-acknowledge-review.html'
            controller: 'DialogAcknowledgeCtrl'
            size: 'lg'
            windowClass: 'dialog-acknowledge-review'

          dialog.result.then () =>

            WS.acknowledgeReview(uid, year, rname, 'review', response.latest_review.template_id).then (response) ->

              console.log('Going to review ..')
              $state.go 'user_review_year.start',
                uid: Auth.getUser().uid,
                review_year: year,
                review_name: rname

            return


    $scope.selected = []

    $scope.goToReview = (review) ->

      if $scope.selected.length > 1
        $scope.goToMultiReview($scope.selected)
        return

      if review.review_type == 'self-review'
        state = 'user_self_review_year.start'
      else
        state = 'user_review_year.start'

      $state.go state,
        uid: review.uid
        review_year: review.year
        review_name: review.rname

    $scope.confirmMultiReview = (reviews) ->

      dialog = $modal.open
        templateUrl: 'static/partials/dialog-confirm-multireview.html'
        controller: 'DialogMultiReviewConfirmCtrl'
        size: 'lg'
        windowClass: "dialog-multireview-wrapper"
        resolve:
          reviews: () -> reviews

    $scope.goToMultiReview = (reviews) ->

      grouped = _.groupBy(reviews, (x) -> "#{x.year}-#{x.rname}-#{x.review_type}-#{x.template_id}")

      # More than 1 type of stuff
      if _.keys(grouped).length > 1
        $scope.confirmMultiReview(reviews)
        return

      uids = (x.uid for x in reviews)

      $state.go 'multi_user_review_year.start',
        uids: uids.join('+')
        review_year: reviews[0].year    # pick the first one. Doesnt matter
        review_name: reviews[0].rname

    $scope.selectAll = (toggle) ->

      if not toggle
        $scope.selected = []

      for review in $scope.filteredReviews.active_results[1]

        review.selected = toggle

        if toggle
          $scope.selected.push(review)

      if $scope.showArchived

        for review in $scope.filteredReviews.archived_results[0]

          review.selected = toggle

          if toggle
            $scope.selected.push(review)



    $scope.selectReview = (tabIndex, itemIndex, review, bypass = false) ->

      if not bypass
        review.selected = !review.selected

      if review.selected
        $scope.selected.push(review)
      else
        $scope.selected.splice($scope.selected.indexOf(review), 1)

    $scope.getCompletedPercentage  = (review, quantize = false) ->
      if quantize
        return Math.floor((review.curr_modelkeys * 10 / review.all_modelkeys).toFixed())
      else
        return (review.curr_modelkeys * 100 / review.all_modelkeys).toFixed()

    $scope.leaveFeedback = () ->
      Utils.showLoading()
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-leave-feedback.html'
        controller: 'DialogLeaveFeedbackCtrl'
        size: 'lg'
        windowClass: "dialog-leave-feedback-wrapper"
        resolve:
            allUsers: (Cache) ->
                Cache.getAllUsers().then (response) ->
                    response

    return


]
