// Generated by CoffeeScript 1.10.0
(function() {
  angular.module("perform").controller("DialogLeaveFeedbackCtrl", [
    "$scope", "$sanitize", "$modal", "$modalInstance", "$state", "Auth", "allUsers", "Utils", function($scope, $sanitize, $modal, $modalInstance, $state, Auth, allUsers, Utils) {
      var i, len, user, x;
      Utils.hideLoading();
      $scope.fullnames = [];
      $scope.cnToUidMap = {};
      $scope.fullnameToUidMap = {};
      $scope.empNumbertoUidMap = {};
      $scope.users = [
        {
          uid: null,
          employeeNumber: null
        }
      ];
      $scope.showStatusMessage = false;
      $scope.status = "You cannot leave feedback for yourself. Try the self-review.";
      $scope.nameLength = '';
      $scope.enterOccurred = false;
      user = Auth.getUser();

      for (i = 0, len = allUsers.length; i < len; i++) {
        x = allUsers[i];
        //if (x.active && x.organization === user.organization && x.location.id.indexOf('china-offsite') === -1) {
        if (x.active && (x.organization === 'DreamWorks Animation L.L.C.' || x.organization === 'Universal City Studios Productions LLLP') && x.location.id.indexOf('china-offsite') === -1) {
          $scope.fullnames.push(x.cn.concat(' (', x.uid, ')'));
          $scope.cnToUidMap[x.cn] = x.uid;
          $scope.fullnameToUidMap[x.cn.concat(' (', x.uid, ')')] = x.uid;
          $scope.empNumbertoUidMap[x.uid] = x.employeeNumber;
        }
      }
      
      $scope.validateInput = function(user, name) {
        user.uid = $scope.cnToUidMap[$scope._getCnFromFullname(name)];
        user.employeeNumber = $scope.empNumbertoUidMap[user.uid];
        $scope.showStatusMessage = false;
        $scope.nameLength = name.length;
        if (Auth.getUser().uid === user.uid) {
          $scope.okToProceed = false;
          return $scope.showStatusMessage = true;
        } else if (user.uid.length) {
          return $scope.okToProceed = true;
        }
        
      };
      console.log($sanitize($scope.users));
      $scope.removeItem = function(uid) {
        $scope.showStatusMessage = false;
        $scope.users.splice($scope.users.indexOf(uid), 1);
        return $scope.users = [
          {
            uid: null,
            employeeNumber: null
          }
        ];
      };
      $scope._getCnFromFullname = function(fullname) {
        return fullname.split(' (')[0];
      };
      $scope.keypress = function(event, name, user) {
        if (((name != null) && name.length < $scope.nameLength) || event.keyCode === 8 || event.keyCode === 46) {
          user.uid = null;
          user.employeeNumber= null;
          $scope.okToProceed = false;
          return $scope.showStatusMessage = false;
        }
      };
      $scope.enterFeedback = function(event) {
        if ($scope.enterOccurred && event.keyCode === 13) {
          $scope.enterOccurred = false;
          return $scope.ok();
        } else if (event.keyCode === 13) {
          return $scope.enterOccurred = true;
        } else if (event.keyCode) {
          return $scope.enterOccurred = false;
        }
      };
      $scope.cancel = function() {
        return $modalInstance.dismiss('cancel');
      };
      $scope.ok = function() {
        var uids;
        uids = _.filter(_.map($scope.users, 'uid'));
        $state.go('feedback.form', {
          uids: uids.join('+')
        });
        return $modalInstance.close();
      };
    }
  ]);

}).call(this);
