angular.module("perform").controller "FeedbackFormCtrl", [

  "$scope"
  "$state"
  "$stateParams"
  "Cache"
  "Utils"
  "Auth"
  "users"
  "feedbacks"

  ($scope, $state, $stateParams, Cache, Utils, Auth, users, feedbacks) ->

    $scope.feedbacks = ( user: x[0], uid: x[0].uid, latest_feedback: x[1].latest_feedback, feedbacks: _.filter(x[1].feedbacks, (y) -> y.locked)     for x in _.zip(users, feedbacks))


    if Auth.getUser().uid in _.pluck($scope.feedbacks, 'uid')
        $state.transitionTo 'auth_error', {},
          location: 'replace'
          inherit: true
          relative: $state.$current
          notify: true


    $scope.localtime = Utils.localtime

    # This contains latest of everyone, so that we can bind it.
    $scope.latest_feedbacks = {}

    for obj in $scope.feedbacks

      latest = obj.latest_feedback

      latest.btnTexts =
        save: 'Save'
        commit: 'Commit'

      # If its locked, create a new object based on the current one.
      # TODO: This at some point will go away. We'll create a new object only when the
      # user clicks on "new feedback" or some such.
      if latest.locked
        latest.feedback_body = ''

      $scope.latest_feedbacks[obj.uid] = latest

    $scope.addFeedback = (index, feedback, change_type = "SAVE_DRAFT") ->

      if change_type == "SAVE_DRAFT"
        feedback.btnTexts.save = "Saving .."
      else if change_type == "ADD_FEEDBACK"
        feedback.btnTexts.commit = "Committing .."
        feedback.btnTexts.save = "Save"

      Cache.addFeedback(feedback, change_type).then (response) =>
        prevFeedbackObj = $scope.feedbacks[index].feedbacks
        prevFeedbackObj.feedbacks = response

        # pick one
        uid = response[0].uid

        if change_type == 'ADD_FEEDBACK'
          $scope.latest_feedbacks[uid].feedback_body = ''
          $scope.feedbacks[index].feedbacks.push(response[response.length - 1])
          feedback.btnTexts.commit = "Committed"

        else if change_type == "SAVE_DRAFT"
          feedback.btnTexts.save = "Saved"

    return

]
