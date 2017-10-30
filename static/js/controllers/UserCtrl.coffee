angular.module("perform").controller "UserCtrl", [

  "$scope"
  "$rootScope"
  "$stateParams"
  "allUsers"
  "Reviews"
  "WS"
  "BG"
  "Auth"
  "Utils"
  "user"
  "$state"
  "$interval"
  "$q"
  "$modal"
  "Cache"
  "review"
  "selfReview"
  "allReviews"
  "$window"
  "$route"


  ($scope, $rootScope, $stateParams, allUsers, Reviews, WS, BG, Auth, Utils, user, $state, $interval, $q, $modal, Cache, review, selfReview, allReviews, $window, $route) ->

    $scope.headerExpanded = false
    $scope.reminderSent = false
    $scope.allReviews = allReviews
    $scope.collabPaneIndex = 0

    $scope.fullnames = []
    $scope.cnToUidMap = {}
    $scope.fullnameToUidMap = {}

    authUser = Auth.getUser()
    for x in allUsers
      # Admins without EDIT_HR permission cannot add themselves as reviewers/contributors.
      if (authUser.is_admin && authUser.uid == x.uid)
        if authUser.permissions.indexOf('EDIT_HR') == -1
            continue
      if x.active
        $scope.fullnames.push(x.cn.concat(' (',x.uid,')'))
        $scope.cnToUidMap[x.cn] = x.uid
        $scope.fullnameToUidMap[x.cn.concat(' (',x.uid,')')]=x.uid

    if review?.latest_template
      $scope.sections = (section for sectionName, section of review.latest_template.section)

    if $state.$current.data?.section
      $scope.sectionName = $state.$current.data.section
    else
      $scope.sectionName = $stateParams.section

    $scope.user          = user
    $scope.review_year   = $stateParams.review_year
    $scope.review_name   = $stateParams.review_name
    $scope.template_id   = review.latest_review.template_id

    $scope.valid_commitbtn_hover = false

    $scope.review_type   = $stateParams.review_type || $state.current.data.review_type

    $scope.review        = Reviews.getset(review.latest_review, $scope.review_type)
    $scope.selfReview    = Reviews.getset(selfReview.latest_review, selfReview.latest_review.review_type)
    if $scope.review_type == 'review'
      WS.getBusyReviewer($scope.review.uid, $scope.review.year, $scope.review.rname).then((response)->
        $scope.isCurrentlyEditedBy = response.isCurrentlyEditedBy
      )
    if Auth.getUser().uid is $scope.review.uid && $scope.review.locked && $scope.review.change_type != 'ACKNOWLEDGE_REVIEW'
      $scope.acknowledgeReview = true
      if !$scope.$$phase
        $scope.$apply()
    else
      $scope.acknowledgeReview = false
    $scope.switchSection = (section) ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        $scope.feedback.no_transition = true
        $state.go($state.current.name, {'section': section.name})
        $scope.feedback.no_transition = false

    $scope.switchReview = (year, name) ->
      state = undefined
      reviewType = undefined

      if $state.current.data.review_type == 'self-review'
        state = 'user_self_review_year.start'
        reviewType = 'self-reviews'
      else
        state = 'user_review_year.start'
        reviewType = 'reviews'

      $state.go state,
        uid: user.uid
        review_year: year
        review_name: name

    $scope.$on '$destroy', () ->

      Reviews.remove($scope.review, $scope.review_type)
      Reviews.remove($scope.selfReview, 'self-review')
      Reviews.stopAutoUpdate()

    if $scope.review_type in ["weights-performance", "weights-potential"]
      uid = $scope.template_id
    else
      uid = $scope.user.uid

    $scope.review_packet = Reviews.getReviewPacketByUserAndYear(uid, $scope.review_year, $scope.review_name, $scope.review_type)

    $scope.review_payload = review

    $scope.feedback_reveals = {}

    for key, value of $scope.review_payload.feedbacks_grouped
      $scope.feedback_reveals[key] = (false for x in value)

    $scope.getReviewers = () ->
      return (x for x in $scope.review_payload.permitted_users when x.uid != $scope.user.uid)

    $scope.getCurrentReviewersAndCollaborators = () ->
      return (x.uid for x in $scope.review_payload.permitted_users.concat($scope.review_payload.contributors)  when x && x?.uid != $scope.user.uid)

    $scope.localtime = Utils.localtime

    # Check to see if its the user accessing his/her performance review
    $scope.restrictedAccess = (Auth.getUser().uid is $scope.user.uid) and ($scope.review_type is 'review')

    $scope.save =
      status: "Last edit was #{Utils.localtime(review.latest_review.datetime).fromNow()}."
      date_str: "#{Utils.localtime(review.latest_review.datetime).format('LLL')}"
      last: "Last saved at #{Utils.localtime(review.latest_review.datetime).format('LLL')}."
      last_str: "Last saved at #{Utils.localtime(review.latest_review.datetime).format('LLL')}."

    $scope.btnIcons =
      committed_true_true            : 'pencil'
      committed_false_true           : 'lock'
      committed_true_false           : 'lock'
      committed_false_false          : 'lock'

      committed_true_locked_false_ready_true_admin_false  : 'ok'
      committed_true_locked_false_ready_true_admin_true   : 'ok'

      committed_true_locked_false_ready_false_admin_true  : 'thumbs-up'  # thumbs up
      committed_true_locked_false_ready_false_admin_false : 'time' # wait

      committed_false_locked_false_ready_false_admin_false : 'ok'
      committed_false_locked_false_ready_false_admin_true  : 'ok'

      committed_true_locked_true_ready_false_admin_true  : 'ok'
      committed_true_locked_true_ready_false_admin_false : 'ok'

      "review_and_print_self-review" : 'print'
      review_and_print_review        : if $scope.restrictedAccess then 'print' else 'print'

    $scope.btnTexts =
      committed_true                 : 'Completed'
      committed_false                : 'Commit'

      committed_true_locked_false_ready_true_admin_true    : 'Publish'
      committed_true_locked_false_ready_true_admin_false   :  'Publish'

      committed_true_locked_false_ready_false_admin_true   : 'OK to Publish'
      committed_true_locked_false_ready_false_admin_false  : 'Publish'

      committed_false_locked_false_ready_false_admin_false : 'Publish'
      committed_false_locked_false_ready_false_admin_true  : 'Publish'

      committed_true_locked_true_ready_false_admin_true    : 'Delivered'
      committed_true_locked_true_ready_false_admin_false   : 'Delivered'

      "review_and_print_self-review" : 'Preview'
      review_and_print_review        : if $scope.restrictedAccess then 'Print' else 'Preview'
      committed_true_true            : 'Uncommit'
      committed_true_false           : 'Completed'
      committed_false_true           : 'Commit'
      committed_false_false          : 'Commit'

    $scope.btnHover =
      committed_true                              : 'This review is locked'
      committed_false                             : 'Commit, lock and notify HR'

      committed_true_locked_false_ready_true_admin_true    : 'Publish and open the review'
      committed_true_locked_false_ready_true_admin_false   :  'Publish and open the review'

      committed_true_locked_false_ready_false_admin_true   : 'Allow review to be published'
      committed_true_locked_false_ready_false_admin_false  : 'Waiting for the OK from HR'

      committed_false_locked_false_ready_false_admin_false : 'Commit first to publish'
      committed_false_locked_false_ready_false_admin_true  : 'Commit first to publish'

      committed_true_locked_true_ready_false_admin_true    : "#{$scope.user.cn} can see this review"
      committed_true_locked_true_ready_false_admin_false   : "#{$scope.user.cn} can see this review"

      "review_and_print_self-review"              : 'Review and print'
      review_and_print_review                     : 'Review and print'

      committed_true_true                         : if $scope.review_type == 'review' then 'Uncommit and notify reviewers' else 'Uncommit and notify the employee'
      committed_true_false                        : 'This review is locked'
      committed_false_false                       : 'Commit, lock and notify HR'
      committed_false_true                        : 'Commit, lock and notify HR'


    $scope.previewReview = (review, review_type) ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        if review_type == 'review'
          state = 'user_review_year.preview'
        else
          state = 'user_self_review_year.preview'

        $state.go(state, {'uid': review.uid, 'review_year': review.year})
    $scope.acknowledgeCurrentReview = (uid, rname, year)->
      Utils.showLoading()
      WS.acknowledgeReview(uid, year, rname, 'review', $scope.template_id).then (response) ->
        console.log('Going to review ..')
        Utils.hideLoading()
        $state.go 'landing.home',
          uid: Auth.getUser().uid,
          review_year: year,
          review_name: rname

    $scope.publishReview = () ->
      Utils.showLoading()
      WS.publishReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.template_id).then (response) ->
# response itself is latest_review
        Utils.hideLoading()
        Reviews.set(response, $scope.review_type)

    $scope.sendSelfReviewReminder = (user) ->
      WS.sendSelfReviewReminder(user.uid,$scope.review_year,$scope.review_name).then (response) ->
        $scope.reminderSent = true
        console.log(response)

    $scope.isReviewer = (uid) ->
      return  uid in $scope.review_payload.latest_review.all_reviewers

    $scope.enableCommitBtnOnHover = () ->

      if $scope.review_packet.committed
        if $scope.review_type == 'self-review' && ($scope.Auth.isAdmin() || $scope.isReviewer($scope.Auth.getUser().uid)) && $scope.Auth.getUser().uid  != $scope.user.uid
          return true
        if  $scope.review_type =='review' && $scope.Auth.isAdmin()
          return true
      false

    $scope.commitButtonClicked = () ->
      if $scope.review_packet.committed
        if ($scope.review_type == 'review' && $scope.Auth.isAdmin()) || ($scope.review_type == 'self-review' && ($scope.Auth.isAdmin() || $scope.isReviewer($scope.Auth.getUser().uid)) && $scope.Auth.getUser().uid != $scope.user.uid)
          console.log("uncommit")
          $scope.uncommitReview()
          $window.location.reload()
      else if !$scope.review_packet.committed && ($scope.review_type == 'review' || ($scope.review_type == 'self-review' && $scope.Auth.getUser().uid == $scope.review_packet.uid))
        console.log("commit this")
        $scope.confirmCommitDialog($scope.confirmMessages.commit, $scope.commitReview)
        Utils.showLoading()




    $scope.releaseBusyBtn = ()->
      Utils.showLoading()
      currentReview=Reviews.getset(review.latest_review, 'review')
      WS.updateIsBusyReviewer(currentReview.uid, currentReview.year, currentReview.rname, false, Auth.getUser().uid).then( (response) ->
        $state.go 'editing_in_progress',
          {'isCurrentlyEditedBy':['admin']}
      )



    $scope.confirmCommitDialog = (messages, callback) ->
      Utils.showLoading()
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-commit-confirm.html'
        controller: 'DialogCommitCtrl'
        size: 'lg'
        windowClass: 'dialog-commit-window'
        resolve:
          messages: () -> messages


      dialog.result.then () ->
        $rootScope.deferPresent = true
        BG.addToDefer().then (response) ->

          $stateParams.validate = undefined
          Utils.showLoading()
          if $scope.review_type is "review"
            $state.transitionTo "user_review_year.preview", $stateParams,
              location: 'replace'
              notify: true
              reload: true

          else
            $state.transitionTo "user_self_review_year.preview", $stateParams,
              location: 'replace'
              notify: true
              reload: true

          callback()

      , (modelkeys) ->
# Handler for when the user does 'continue to edit' (aka dismiss the dialog box)
        $scope.missingModelKeys = modelkeys.missing

        if $scope.missingModelKeys

          $stateParams.validate = true

          $state.transitionTo $state.current.name, $stateParams,

            location: 'replace'
            notify: true
            reload: true

        return

    $scope.publishButtonClicked = () ->

      if $scope.review_packet.committed && !$scope.review_packet.locked

        if ($scope.review.change_type != "READY2PUBLISH" and Auth.isAdmin())
          Utils.showLoading()
          WS.okToPublishReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.template_id).then (response) ->
            Reviews.set(response, $scope.review_type)
            Utils.hideLoading()
            if !$scope.$$phase
              $scope.$apply()
        else if $scope.review.change_type == "READY2PUBLISH"
          $scope.confirmPublishDialog($scope.confirmMessages.publish, $scope.publishReview).then((response) ->
            if !$scope.$$phase
              $scope.$apply()
          )
          Utils.showLoading()
        else
          console.info("It is committed, but no user")
      else
        console.info("It is not committed")



    #ng-click="review_packet.committed && !review_packet.locked  && confirmPublishDialog(confirmMessages.publish, publishReview); $event.stopPropagation()" -->

    $scope.confirmPublishDialog = (messages, callback) ->
      Utils.showLoading()
      dialog = $modal.open
        templateUrl: 'static/partials/dialog-publish-confirm.html'
        controller: 'DialogPublishCtrl'
        size: 'lg'
        resolve:
          messages: () -> messages

      dialog.result.then () ->

        callback()

    $scope.confirmMessages =

      commit:
        validate: false
        header: "Commit review"
        body  : "Mark as complete, and send email to Human Resources?"
        modelkeys: review.latest_template.modelkeys
        getCurrModelKeys: () ->
# Ensure that the currModelKeys are only ones with values in it. That means empty notes/comments are not allowed.
          (modelkey for modelkey, value of $scope.review.review_body when value != "")

        buttons:
          ok    : "Mark as complete"
          cancel: "Go back and continue editing"
      publish:
        validate: true
        validateFn: (string) ->
          string.toLowerCase() == $scope.user.cn.split(' ')[0].toLowerCase()

        validateFn_self: (string) ->
          if string
            initials = _.map Auth.getUser().cn.split(' '), (x) -> x[0]
            return string.toLowerCase() == _.map(initials, (x) -> x.toLowerCase()).join('')
          else
            return false

        header: "Publish review"
        body  : "Mark as delivered and share the review with #{$scope.user.cn}?"
        icon  : "glyphicon-ok"
        buttons:
          ok    : "Publish and share"
          cancel: "Cancel"

    $scope.findMissingModelKeys = () ->
      '''
      Find the missing model keys
      '''

      allModelKeys  = review.latest_template.modelkeys
      currModelKeys = $scope.confirmMessages.commit.getCurrModelKeys()

      missing = _.difference(allModelKeys, currModelKeys)

      return missing

    $scope.missingModelKeys = []

    if $stateParams.validate
      $scope.missingModelKeys = $scope.findMissingModelKeys()

    $scope._getCnFromFullname = (fullname) ->
      fullname.split(' (')[0]

    $scope.commitReview = () ->
      Utils.showLoading()
      WS.commitReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, $scope.template_id).then (response) ->
        Reviews.set(response, $scope.review_type)

    $scope.uncommitReview = () ->
      console.log("uncommiting review")

      Reviews.autoUpdate()

      WS.uncommitReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, $scope.template_id).then (response) ->
        Reviews.set(response, $scope.review_type)


    $scope.overlay =
      show: $stateParams.selfreview

    $scope.showOverlay = () ->

      if $scope.selfReview.locked
        $scope.overlay.show =! $scope.overlay.show

        if $scope.overlay.show
          $stateParams.selfreview = $scope.overlay.show
        else
          $stateParams.selfreview = null


        $state.transitionTo $state.current.name, $stateParams,

          location: 'replace'
          notify: false
          reload: true

        return

    $scope.feedback =
      show: $stateParams.feedback
      no_transition: true

    $scope.showFeedback = () ->

      if $scope.review_payload.feedbacks.length > 0

        $scope.feedback.no_transition = false

        $scope.feedback.show =! $scope.feedback.show

        if $scope.feedback.show
          $stateParams.feedback = $scope.feedback.show
        else
          $stateParams.feedback = null

        $state.transitionTo $state.current.name, $stateParams,

          location: 'replace'
          notify: false
          reload: false

    $scope.enableAutoUpdate = () ->
      Reviews.autoUpdate()

    $scope.isAutoUpdating = () ->
      if not $scope.review_packet.committed
        !!Reviews.is_fresh
      else
        return true

    $scope.goToSelfReview = () ->
      $rootScope.deferPresent = true
      BG.addToDefer().then (response) ->
        $state.go('user_self_review_year.start', {'uid': $scope.review_packet.uid, 'review_year': $scope.review_packet.year, 'review_name': $scope.review_packet.rname})

    $scope.showAddCollaborators        = false
    $scope.collab = {}

    $scope.addCollaborator = (mode, event, collabUser) ->


      if event.keyCode == 13
        console.log("Adding #{collabUser}")
        $scope.collab.user = ''

        # mode = 0 -> Add Reviewer
        # mode = 1 -> Add Contributor
        if mode == 0

          WS.addReviewers($scope.user.uid, $scope.review_year, $scope.review_name, [$scope.cnToUidMap[$scope._getCnFromFullname(collabUser)]], $scope.review_type).then (response) ->

# This will ensure it shows up immediately in the list
            Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true)

        else if mode == 1

          WS.addContributors($scope.user.uid, $scope.review_year, $scope.review_name, [$scope.cnToUidMap[$scope._getCnFromFullname(collabUser)]], $scope.review_type).then (response) ->

# This will ensure it shows up immediately in the list
            Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true)

    $scope.removeCollaborator = (mode, collabUser) ->


      console.log("Removing #{collabUser}")

      # mode = 0 -> Add Reviewer
      # mode = 1 -> Add Contributor
      if mode == 0

        WS.removeReviewers($scope.user.uid, $scope.review_year, $scope.review_name, [collabUser], $scope.review_type).then (response) ->

# This will ensure it shows up immediately in the list
          Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true)
      else if mode == 1

        WS.removeContributors($scope.user.uid, $scope.review_year, $scope.review_name, [collabUser], $scope.review_type).then (response) ->

# This will ensure it shows up immediately in the list
          Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true)


    return

]