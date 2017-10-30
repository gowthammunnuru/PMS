angular.module("perform").controller "DialogPublishCtrl", [

  "$scope"
  "Auth"
  "$modal"
  "$modalInstance"
  "messages"

  ($scope, Auth, $modal, $modalInstance, messages) ->


    $scope.messages = messages

    $scope.selfInitials = (_.map Auth.getUser().cn.split(' '), (x) -> x[0]).join('')

    $scope.ok = () -> $modalInstance.close()

    $scope.cancel = () -> $modalInstance.dismiss('cancel')

    $scope.extra_confirmation = ''

    return
]
