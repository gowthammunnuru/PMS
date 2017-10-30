// Generated by CoffeeScript 1.8.0
var __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

angular.module("perform").controller("FeedbackFormCtrl", [
  "$scope", "$state", "$stateParams", "Cache", "Utils", "Auth", "users", "feedbacks", function($scope, $state, $stateParams, Cache, Utils, Auth, users, feedbacks) {
    var latest, obj, x, _i, _len, _ref, _ref1;

    $scope.feedbacks = (function() {
      var _i, _len, _ref, _results;
      _ref = _.zip(users, feedbacks);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        x = _ref[_i];
        _results.push({
          user: x[0],
          uid: x[0].uid,
          latest_feedback: x[1].latest_feedback,
          feedbacks: _.filter(x[1].feedbacks, function(y) {
            return y.locked;
          })
        });
      }

      return _results;
    })();
    $scope.empNumber = $scope.feedbacks[0].user.employeeNumber;
    if (_ref = Auth.getUser().uid, __indexOf.call(_.pluck($scope.feedbacks, 'uid'), _ref) >= 0) {
      $state.transitionTo('auth_error', {}, {
        location: 'replace',
        inherit: true,
        relative: $state.$current,
        notify: true
      });
    }
    $scope.localtime = Utils.localtime;
    $scope.latest_feedbacks = {};
    _ref1 = $scope.feedbacks;
    for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
      obj = _ref1[_i];
      latest = obj.latest_feedback;
      latest.btnTexts = {
        save: 'Save',
        commit: 'Commit'
      };
      if (latest.locked) {
        latest.feedback_body = '';
      }
      $scope.latest_feedbacks[obj.uid] = latest;
    }
    $scope.addFeedback = function(index, feedback, change_type) {
      if (change_type == null) {
        change_type = "SAVE_DRAFT";
      }
      if (change_type === "SAVE_DRAFT") {
        feedback.btnTexts.save = "Saving ..";
      } else if (change_type === "ADD_FEEDBACK") {
        feedback.btnTexts.commit = "Committing ..";
        feedback.btnTexts.save = "Save";
      }
      return Cache.addFeedback(feedback, change_type).then((function(_this) {
        return function(response) {
          var prevFeedbackObj, uid;
          prevFeedbackObj = $scope.feedbacks[index].feedbacks;
          prevFeedbackObj.feedbacks = response;
          uid = response[0].uid;
          if (change_type === 'ADD_FEEDBACK') {
            $scope.latest_feedbacks[uid].feedback_body = '';
            $scope.feedbacks[index].feedbacks.push(response[response.length - 1]);
            return feedback.btnTexts.commit = "Committed";
          } else if (change_type === "SAVE_DRAFT") {
            return feedback.btnTexts.save = "Saved";
          }
        };
      })(this));
    };
  }
]);
