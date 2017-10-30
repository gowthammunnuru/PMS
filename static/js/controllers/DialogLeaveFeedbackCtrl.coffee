angular.module("perform").controller "DialogLeaveFeedbackCtrl", [
  "$scope"
  "$modal"
  "$modalInstance"
  "$state"
  "Auth"
  "allUsers"
  "Utils"

  ($scope, $modal, $modalInstance, $state, Auth, allUsers, Utils) ->

    Utils.hideLoading()

    $scope.fullnames = []
    $scope.cnToUidMap = {}
    $scope.fullnameToUidMap = {}
    $scope.users = [{uid: null}]
    $scope.showStatusMessage = false
    $scope.status = "You cannot leave feedback for yourself. Try the self-review."
    $scope.nameLength = ''
    $scope.enterOccurred = false

    user= Auth.getUser()
    for x in allUsers
      if (x.active && x.organization == user.organization && x.location.id.indexOf('china-offsite') == -1)
            $scope.fullnames.push(x.cn.concat(' (',x.uid,')'))
            $scope.cnToUidMap[x.cn] = x.uid
            $scope.fullnameToUidMap[x.cn.concat(' (',x.uid,')')]=x.uid

    $scope.validateInput = (user, name) ->
      user.uid = $scope.cnToUidMap[$scope._getCnFromFullname(name)]
      $scope.showStatusMessage = false
      $scope.nameLength = name.length
      if Auth.getUser().uid is user.uid
        $scope.okToProceed = false
        $scope.showStatusMessage = true
      else if user.uid.length
        $scope.okToProceed = true

    $scope.removeItem = (uid) ->
      $scope.showStatusMessage = false
      $scope.users.splice($scope.users.indexOf(uid), 1)
      $scope.users = [{uid: null}]

    $scope._getCnFromFullname = (fullname) ->
      fullname.split(' (')[0]

    $scope.keypress = (event, name, user) ->
      if (name? && name.length < $scope.nameLength) || event.keyCode == 8 || event.keyCode == 46
        user.uid = null
        $scope.okToProceed = false
        $scope.showStatusMessage = false

    $scope.enterFeedback = (event) ->
        if $scope.enterOccurred && event.keyCode == 13
            $scope.enterOccurred = false
            $scope.ok()
        else if event.keyCode == 13
            $scope.enterOccurred = true
        else if event.keyCode
            $scope.enterOccurred = false

    $scope.cancel = () -> $modalInstance.dismiss('cancel')
    $scope.ok     = () ->

      uids = _.filter(_.map $scope.users, 'uid' )
      $state.go 'feedback.form', uids: uids.join('+')

      $modalInstance.close()

    return
]
