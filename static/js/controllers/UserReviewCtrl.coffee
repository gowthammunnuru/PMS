angular.module("perform").controller "UserReviewCtrl", [

  "$scope"
  "$stateParams"
  "$rootScope"
  "Reviews"
  "WS"
  "Portal"
  "Utils"
  "user"
  "$state"
  "$timeout"
  "Cache"
  "review"
  "selfReview"
  "Auth"
  "$window"

  ($scope, $stateParams, $rootScope, Reviews, WS, Portal, Utils, user, $state, $timeout, Cache, review, selfReview, Auth,$window) ->

    # Used by UserReviewPreviewCtrl
    $scope.showSelfReview = {}

    if review?.latest_template
      $scope.sections = (section for sectionName, section of review.latest_template.section)
      $scope.template_id = review.latest_template.template_id

    $scope.review_payload = review
    $scope.review_type    = $stateParams.review_type || $state.current.data.review_type
    console.log($scope.review_type)
    # Setting up bindings (for updates)
    $scope.review      = Reviews.getset(review.latest_review, $scope.review_type)

    # Setting up bindings (for updates)
    $scope.selfReview  = Reviews.getset(selfReview.latest_review, selfReview.latest_review.review_type)

    Reviews.autoUpdate(resetKillSwitch = true)

    $scope.getSaveStatus = () -> Reviews.save
    
    if $scope.review_type == 'review'
      currentReview=Reviews.getset(review.latest_review, $scope.review_type)
      WS.getBusyReviewer(currentReview.uid, currentReview.year, currentReview.rname).then((response)->
          $scope.busyBtnDetails=response
          if !_.isEmpty(response.isCurrentlyEditedBy) && response.isCurrentlyEditedBy != 'admin' && response.isCurrentlyEditedBy!= Auth.getUser().uid && !currentReview.committed
            if  !_.contains(Auth.getUser().permissions, "EDIT_REVIEWS")
              $state.go 'editing_in_progress',
                {isCurrentlyEditedBy:[response.isCurrentlyEditedBy]}
          else
            if !_.contains(Auth.getUser().permissions, "EDIT_REVIEWS")
              WS.updateIsBusyReviewer(currentReview.uid, currentReview.year, currentReview.rname, true, Auth.getUser().uid).then( (response) ->
                $scope.busyBtnDetails= {
                  isCurrentlyEditedBy:Auth.getUser().uid
                  rname:currentReview.rname
                  uid:currentReview.uid
                  year:currentReview.year
                }
                if !$scope.$$phase
                  $scope.$apply()
              )

      )
    $scope.$watch 'getSaveStatus()', (newValue, oldValue) ->
      if newValue
        # First time the service (Reviews) get initialized, there isnt any value.
        if newValue[$scope.review_type].status
          $scope.save?.status = newValue[$scope.review_type].status
        $scope.save?.freq   = newValue.freq
        $scope.save?.last   = newValue[$scope.review_type].last
    , true


    if $state.$current.data?.section
      $scope.sectionName = $state.$current.data.section
    else
      $scope.sectionName = $stateParams.section

    $scope.user        = user
    $scope.review_year = $stateParams.review_year

    # Setup watch for review (and there by changes) only if not in restrictedAccess mode
    if not $scope.restrictedAccess

      $scope.$on '$destroy' , ()->
        if $scope.busyBtnDetails?.isCurrentlyEditedBy is Auth.getUser()?.uid || (Auth.getStatus() == false)
            WS.updateIsBusyReviewer(currentReview.uid, currentReview.year, currentReview.rname, false, "admin")

      $scope.$watch 'review', (newValue, oldValue) ->

        Utils.showPreventNavigation()

        if newValue is oldValue
          console.log("Comparision failed, returning ..")
          Reviews.setSaveStatus(newValue.datetime, $scope.review_type)
          Utils.hidePreventNavigation()
          return

        # A more robust comparision
        # This takes care of the sitatuion where "saving" was getting trigged again
        # because we modified review_body in place, which casused the update on the "oldValue"
        # .. The visible problem was that "Saving" would remain on for longer than what was required
        #
        if Reviews.robustReviewComparison(newValue, oldValue)
          console.info('The RobustComparison (R) found no changes. Returning without saving')
          return

        if $scope.onDemandSave
          $timeout.cancel($scope.onDemandSave)
          Reviews.setSaveStatus('pending', $scope.review_type)
          Reviews.autoUpdate(resetKillSwitch = true)

        console.log('Setting up on demand save', newValue)
        $scope.onDemandSave = $timeout () ->
          response = Reviews.saveReviews($scope.review_type)
          if _.contains(_.keys(response), 'error')
            $state.go 'editing_in_progress',
                {isCurrentlyEditedBy:[response.error]}
          Utils.hidePreventNavigation()
          freq=2
          if $scope.review_type =='review'
            Reviews.autoUpdate(resetKillSwitch = true, freq, 'review')
          else
            Reviews.autoUpdate(resetKillSwitch = true)
        , 1000 * 2

      , true

    $window.onunload = (event) ->
      if $scope.busyBtnDetails?.isCurrentlyEditedBy is Auth.getUser()?.uid || (Auth.getStatus() == false)
        WS.updateIsBusyReviewer(currentReview.uid, currentReview.year, currentReview.rname, false, "admin")

    return

]
