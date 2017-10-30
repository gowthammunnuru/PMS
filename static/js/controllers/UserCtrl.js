// Generated by CoffeeScript 1.10.0
(function() {
  var indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  angular.module("perform").controller("UserCtrl", [
    "$scope", "$sanitize", "$rootScope", "$stateParams", "allUsers", "Reviews", "WS", "BG", "Auth", "Utils", "user", "$state", "$interval", "$q", "$modal", "Cache", "review", "selfReview", "allReviews", "$window", "$route", function($scope, $sanitize, $rootScope, $stateParams, allUsers, Reviews, WS, BG, Auth, Utils, user, $state, $interval, $q, $modal, Cache, review, selfReview, allReviews, $window, $route) {
      var authUser, i, key, len, ref, ref1, ref2, section, sectionName, uid, value, x;
      $scope.headerExpanded = false;
      $scope.reminderSent = false;
      $scope.allReviews = allReviews;
      $scope.collabPaneIndex = 0;
      $scope.fullnames = [];
      $scope.cnToUidMap = {};
      $scope.fullnameToUidMap = {};
      authUser = Auth.getUser();
      for (i = 0, len = allUsers.length; i < len; i++) {
        x = allUsers[i];
        if (authUser.is_admin && authUser.uid === x.uid) {
          if (authUser.permissions.indexOf('EDIT_HR') === -1) {
            continue;
          }
        }
        if (x.active) {
          $scope.fullnames.push(x.cn.concat(' (', x.uid, ')'));
          $scope.cnToUidMap[x.cn] = x.uid;
          $scope.fullnameToUidMap[x.cn.concat(' (', x.uid, ')')] = x.uid;
        }
      }
      if (review != null ? review.latest_template : void 0) {
        $scope.sections = (function() {
          var ref, results;
          ref = review.latest_template.section;
          results = [];
          for (sectionName in ref) {
            section = ref[sectionName];
            results.push(section);
          }
          return results;
        })();
      }
      if ((ref = $state.$current.data) != null ? ref.section : void 0) {
        $scope.sectionName = $state.$current.data.section;
      } else {
        $scope.sectionName = $stateParams.section;
      }
      $scope.user = user;
      $scope.review_year = $stateParams.review_year;
      $scope.review_name = $stateParams.review_name;
      $scope.template_id = review.latest_review.template_id;
      $scope.valid_commitbtn_hover = false;
      $scope.review_type = $stateParams.review_type || $state.current.data.review_type;
      $scope.review = Reviews.getset(review.latest_review, $scope.review_type);
      $scope.selfReview = Reviews.getset(selfReview.latest_review, selfReview.latest_review.review_type);
      if ($scope.review_type === 'review') {
        WS.getBusyReviewer($scope.review.uid, $scope.review.year, $scope.review.rname).then(function(response) {
          return $scope.isCurrentlyEditedBy = response.isCurrentlyEditedBy;
        });
      }
      if (Auth.getUser().uid === $scope.review.uid && $scope.review.locked && $scope.review.change_type !== 'ACKNOWLEDGE_REVIEW') {
        $scope.acknowledgeReview = true;
        if (!$scope.$$phase) {
          $scope.$apply();
        }
      } else {
        $scope.acknowledgeReview = false;
      }
      $scope.switchSection = function(section) {
        $rootScope.deferPresent = true;
        return BG.addToDefer().then(function(response) {
          $scope.feedback.no_transition = true;
          $state.go($state.current.name, {
            'section': section.name
          });
          return $scope.feedback.no_transition = false;
        });
      };
      $scope.switchReview = function(year, name) {
        var reviewType, state;
        state = void 0;
        reviewType = void 0;
        if ($state.current.data.review_type === 'self-review') {
          state = 'user_self_review_year.start';
          reviewType = 'self-reviews';
        } else {
          state = 'user_review_year.start';
          reviewType = 'reviews';
        }
        return $state.go(state, {
          uid: user.uid,
          review_year: year,
          review_name: name
        });
      };
      $scope.$on('$destroy', function() {
        Reviews.remove($scope.review, $scope.review_type);
        Reviews.remove($scope.selfReview, 'self-review');
        return Reviews.stopAutoUpdate();
      });
      if ((ref1 = $scope.review_type) === "weights-performance" || ref1 === "weights-potential") {
        uid = $scope.template_id;
      } else {
        uid = $scope.user.uid;
      }
      $scope.review_packet = Reviews.getReviewPacketByUserAndYear(uid, $scope.review_year, $scope.review_name, $scope.review_type);
      $scope.review_payload = review;
      $scope.feedback_reveals = {};
      ref2 = $scope.review_payload.feedbacks_grouped;
      for (key in ref2) {
        value = ref2[key];
        $scope.feedback_reveals[key] = (function() {
          var j, len1, results;
          results = [];
          for (j = 0, len1 = value.length; j < len1; j++) {
            x = value[j];
            results.push(false);
          }
          return results;
        })();
      }
      $scope.getReviewers = function() {
        return (function() {
          var j, len1, ref3, results;
          ref3 = $scope.review_payload.permitted_users;
          results = [];
          for (j = 0, len1 = ref3.length; j < len1; j++) {
            x = ref3[j];
            if (x.uid !== $scope.user.uid) {
              results.push(x);
            }
          }
          return results;
        })();
      };
      $scope.getCurrentReviewersAndCollaborators = function() {
        return (function() {
          var j, len1, ref3, results;
          ref3 = $scope.review_payload.permitted_users.concat($scope.review_payload.contributors);
          results = [];
          for (j = 0, len1 = ref3.length; j < len1; j++) {
            x = ref3[j];
            if (x && (x != null ? x.uid : void 0) !== $scope.user.uid) {
              results.push(x.uid);
            }
          }
          return results;
        })();
      };
      $scope.localtime = Utils.localtime;
      $scope.restrictedAccess = (Auth.getUser().uid === $scope.user.uid) && ($scope.review_type === 'review');
      $scope.save = {
        status: "Last edit was " + (Utils.localtime(review.latest_review.datetime).fromNow()) + ".",
        date_str: "" + (Utils.localtime(review.latest_review.datetime).format('LLL')),
        last: "Last saved at " + (Utils.localtime(review.latest_review.datetime).format('LLL')) + ".",
        last_str: "Last saved at " + (Utils.localtime(review.latest_review.datetime).format('LLL')) + "."
      };
      $scope.btnIcons = {
        committed_true_true: 'pencil',
        committed_false_true: 'lock',
        committed_true_false: 'lock',
        committed_false_false: 'lock',
        committed_true_locked_false_ready_true_admin_false: 'ok',
        committed_true_locked_false_ready_true_admin_true: 'ok',
        committed_true_locked_false_ready_false_admin_true: 'thumbs-up',
        committed_true_locked_false_ready_false_admin_false: 'time',
        committed_false_locked_false_ready_false_admin_false: 'ok',
        committed_false_locked_false_ready_false_admin_true: 'ok',
        committed_true_locked_true_ready_false_admin_true: 'ok',
        committed_true_locked_true_ready_false_admin_false: 'ok',
        "review_and_print_self-review": 'print',
        review_and_print_review: $scope.restrictedAccess ? 'print' : 'print'
      };
      $scope.btnTexts = {
        committed_true: 'Completed',
        committed_false: 'Commit',
        committed_true_locked_false_ready_true_admin_true: 'Publish',
        committed_true_locked_false_ready_true_admin_false: 'Publish',
        committed_true_locked_false_ready_false_admin_true: 'OK to Publish',
        committed_true_locked_false_ready_false_admin_false: 'Publish',
        committed_false_locked_false_ready_false_admin_false: 'Publish',
        committed_false_locked_false_ready_false_admin_true: 'Publish',
        committed_true_locked_true_ready_false_admin_true: 'Delivered',
        committed_true_locked_true_ready_false_admin_false: 'Delivered',
        "review_and_print_self-review": 'Preview',
        review_and_print_review: $scope.restrictedAccess ? 'Print' : 'Preview',
        committed_true_true: 'Uncommit',
        committed_true_false: 'Completed',
        committed_false_true: 'Commit',
        committed_false_false: 'Commit'
      };
      $scope.btnHover = {
        committed_true: 'This review is locked',
        committed_false: 'Commit, lock and notify HR',
        committed_true_locked_false_ready_true_admin_true: 'Publish and open the review',
        committed_true_locked_false_ready_true_admin_false: 'Publish and open the review',
        committed_true_locked_false_ready_false_admin_true: 'Allow review to be published',
        committed_true_locked_false_ready_false_admin_false: 'Waiting for the OK from HR',
        committed_false_locked_false_ready_false_admin_false: 'Commit first to publish',
        committed_false_locked_false_ready_false_admin_true: 'Commit first to publish',
        committed_true_locked_true_ready_false_admin_true: $scope.user.cn + " can see this review",
        committed_true_locked_true_ready_false_admin_false: $scope.user.cn + " can see this review",
        "review_and_print_self-review": 'Review and print',
        review_and_print_review: 'Review and print',
        committed_true_true: $scope.review_type === 'review' ? 'Uncommit and notify reviewers' : 'Uncommit and notify the employee',
        committed_true_false: 'This review is locked',
        committed_false_false: 'Commit, lock and notify HR',
        committed_false_true: 'Commit, lock and notify HR'
      };
      $scope.previewReview = function(review, review_type) {
        $rootScope.deferPresent = true;
        return BG.addToDefer().then(function(response) {
          var state;
          if (review_type === 'review') {
            state = 'user_review_year.preview';
          } else {
            state = 'user_self_review_year.preview';
          }
          return $state.go(state, {
            'uid': review.uid,
            'review_year': review.year
          });
        });
      };
      $scope.acknowledgeCurrentReview = function(uid, rname, year) {
        Utils.showLoading();
        return WS.acknowledgeReview(uid, year, rname, 'review', $scope.template_id).then(function(response) {
          console.log('Going to review ..');
          Utils.hideLoading();
          return $state.go('landing.home', {
            uid: Auth.getUser().uid,
            review_year: year,
            review_name: rname
          });
        });
      };
      $scope.publishReview = function() {
        Utils.showLoading();
        return WS.publishReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.template_id).then(function(response) {
          Utils.hideLoading();
          return Reviews.set(response, $scope.review_type);
        });
      };
      $scope.sendSelfReviewReminder = function(user) {
        return WS.sendSelfReviewReminder(user.uid, $scope.review_year, $scope.review_name).then(function(response) {
          $scope.reminderSent = true;
          return console.log(response);
        });
      };
      $scope.isReviewer = function(uid) {
        return indexOf.call($scope.review_payload.latest_review.all_reviewers, uid) >= 0;
      };
      $scope.enableCommitBtnOnHover = function() {
        if ($scope.review_packet.committed) {
          if ($scope.review_type === 'self-review' && ($scope.Auth.isAdmin() || $scope.isReviewer($scope.Auth.getUser().uid)) && $scope.Auth.getUser().uid !== $scope.user.uid) {
            return true;
          }
          if ($scope.review_type === 'review' && $scope.Auth.isAdmin()) {
            return true;
          }
        }
        return false;
      };
      $scope.commitButtonClicked = function() {
        if ($scope.review_packet.committed) {
          if (($scope.review_type === 'review' && $scope.Auth.isAdmin()) || ($scope.review_type === 'self-review' && ($scope.Auth.isAdmin() || $scope.isReviewer($scope.Auth.getUser().uid)) && $scope.Auth.getUser().uid !== $scope.user.uid)) {
            console.log("uncommit");
            $scope.uncommitReview();
            return $window.location.reload();
          }
        } else if (!$scope.review_packet.committed && ($scope.review_type === 'review' || ($scope.review_type === 'self-review' && $scope.Auth.getUser().uid === $scope.review_packet.uid))) {
          console.log("commit this");
          $scope.confirmCommitDialog($scope.confirmMessages.commit, $scope.commitReview);
          return Utils.showLoading();
        }
      };
      $scope.releaseBusyBtn = function() {
        var currentReview;
        Utils.showLoading();
        currentReview = Reviews.getset(review.latest_review, 'review');
        return WS.updateIsBusyReviewer(currentReview.uid, currentReview.year, currentReview.rname, false, Auth.getUser().uid).then(function(response) {
          return $state.go('editing_in_progress', {
            'isCurrentlyEditedBy': ['admin']
          });
        });
      };
      $scope.confirmCommitDialog = function(messages, callback) {
        var dialog;
        Utils.showLoading();
        dialog = $modal.open({
          templateUrl: 'static/partials/dialog-commit-confirm.html',
          controller: 'DialogCommitCtrl',
          size: 'lg',
          windowClass: 'dialog-commit-window',
          resolve: {
            messages: function() {
              return messages;
            }
          }
        });
        return dialog.result.then(function() {
          $rootScope.deferPresent = true;
          return BG.addToDefer().then(function(response) {
            $stateParams.validate = void 0;
            Utils.showLoading();
            if ($scope.review_type === "review") {
              $state.transitionTo("user_review_year.preview", $stateParams, {
                location: 'replace',
                notify: true,
                reload: true
              });
            } else {
              $state.transitionTo("user_self_review_year.preview", $stateParams, {
                location: 'replace',
                notify: true,
                reload: true
              });
            }
            return callback();
          });
        }, function(modelkeys) {
          $scope.missingModelKeys = modelkeys.missing;
          if ($scope.missingModelKeys) {
            $stateParams.validate = true;
            $state.transitionTo($state.current.name, $stateParams, {
              location: 'replace',
              notify: true,
              reload: true
            });
          }
        });
      };
      $scope.publishButtonClicked = function() {
        if ($scope.review_packet.committed && !$scope.review_packet.locked) {
          if ($scope.review.change_type !== "READY2PUBLISH" && Auth.isAdmin()) {
            Utils.showLoading();
            return WS.okToPublishReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.template_id).then(function(response) {
              Reviews.set(response, $scope.review_type);
              Utils.hideLoading();
              if (!$scope.$$phase) {
                return $scope.$apply();
              }
            });
          } else if ($scope.review.change_type === "READY2PUBLISH") {
            $scope.confirmPublishDialog($scope.confirmMessages.publish, $scope.publishReview).then(function(response) {
              if (!$scope.$$phase) {
                return $scope.$apply();
              }
            });
            return Utils.showLoading();
          } else {
            return console.info("It is committed, but no user");
          }
        } else {
          return console.info("It is not committed");
        }
      };
      $scope.confirmPublishDialog = function(messages, callback) {
        var dialog;
        Utils.showLoading();
        dialog = $modal.open({
          templateUrl: 'static/partials/dialog-publish-confirm.html',
          controller: 'DialogPublishCtrl',
          size: 'lg',
          resolve: {
            messages: function() {
              return messages;
            }
          }
        });
        return dialog.result.then(function() {
          return callback();
        });
      };
      $scope.confirmMessages = {
        commit: {
          validate: false,
          header: "Commit review",
          body: "Mark as complete, and send email to Human Resources?",
          modelkeys: review.latest_template.modelkeys,
          getCurrModelKeys: function() {
            var modelkey, ref3, results;
            ref3 = $scope.review.review_body;
            results = [];
            for (modelkey in ref3) {
              value = ref3[modelkey];
              if (value !== "") {
                results.push(modelkey);
              }
            }
            return results;
          },
          buttons: {
            ok: "Mark as complete",
            cancel: "Go back and continue editing"
          }
        },
        publish: {
          validate: true,
          validateFn: function(string) {
            return string.toLowerCase() === $scope.user.cn.split(' ')[0].toLowerCase();
          },
          validateFn_self: function(string) {
            var initials;
            if (string) {
              initials = _.map(Auth.getUser().cn.split(' '), function(x) {
                return x[0];
              });
              return string.toLowerCase() === _.map(initials, function(x) {
                return x.toLowerCase();
              }).join('');
            } else {
              return false;
            }
          },
          header: "Publish review",
          body: "Mark as delivered and share the review with " + $scope.user.cn + "?",
          icon: "glyphicon-ok",
          buttons: {
            ok: "Publish and share",
            cancel: "Cancel"
          }
        }
      };
      $scope.findMissingModelKeys = function() {
        'Find the missing model keys';
        var allModelKeys, currModelKeys, missing;
        allModelKeys = review.latest_template.modelkeys;
        currModelKeys = $scope.confirmMessages.commit.getCurrModelKeys();
        missing = _.difference(allModelKeys, currModelKeys);
        return missing;
      };
      $scope.missingModelKeys = [];
      if ($stateParams.validate) {
        $scope.missingModelKeys = $scope.findMissingModelKeys();
      }
      $scope._getCnFromFullname = function(fullname) {
        return fullname.split(' (')[0];
      };
      $scope.commitReview = function() {
        Utils.showLoading();
        return WS.commitReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, $scope.template_id).then(function(response) {
          return Reviews.set(response, $scope.review_type);
        });
      };
      $scope.uncommitReview = function() {
        console.log("uncommiting review");
        Reviews.autoUpdate();
        return WS.uncommitReview($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, $scope.template_id).then(function(response) {
          return Reviews.set(response, $scope.review_type);
        });
      };
      $scope.overlay = {
        show: $stateParams.selfreview
      };
      $scope.showOverlay = function() {
        if ($scope.selfReview.locked) {
          $scope.overlay.show = !$scope.overlay.show;
          if ($scope.overlay.show) {
            $stateParams.selfreview = $scope.overlay.show;
          } else {
            $stateParams.selfreview = null;
          }
          $state.transitionTo($state.current.name, $stateParams, {
            location: 'replace',
            notify: false,
            reload: true
          });
        }
      };
      $scope.feedback = {
        show: $stateParams.feedback,
        no_transition: true
      };
      $scope.showFeedback = function() {
        if ($scope.review_payload.feedbacks.length > 0) {
          $scope.feedback.no_transition = false;
          $scope.feedback.show = !$scope.feedback.show;
          if ($scope.feedback.show) {
            $stateParams.feedback = $scope.feedback.show;
          } else {
            $stateParams.feedback = null;
          }
          return $state.transitionTo($state.current.name, $stateParams, {
            location: 'replace',
            notify: false,
            reload: false
          });
        }
      };
      $scope.enableAutoUpdate = function() {
        return Reviews.autoUpdate();
      };
      $scope.isAutoUpdating = function() {
        if (!$scope.review_packet.committed) {
          return !!Reviews.is_fresh;
        } else {
          return true;
        }
      };
      $scope.goToSelfReview = function() {
        $rootScope.deferPresent = true;
        return BG.addToDefer().then(function(response) {
          return $state.go('user_self_review_year.start', {
            'uid': $scope.review_packet.uid,
            'review_year': $scope.review_packet.year,
            'review_name': $scope.review_packet.rname
          });
        });
      };
      $scope.showAddCollaborators = false;
      $scope.collab = {};
      $scope.addCollaborator = function(mode, event, collabUser) {
        if (event.keyCode === 13) {
          console.log("Adding " + $sanitize(collabUser));
          $scope.collab.user = '';
          if (mode === 0) {
            return WS.addReviewers($scope.user.uid, $scope.review_year, $scope.review_name, [$scope.cnToUidMap[$scope._getCnFromFullname(collabUser)]], $scope.review_type).then(function(response) {
              var forceUpdate;
              return Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true);
            });
          } else if (mode === 1) {
            return WS.addContributors($scope.user.uid, $scope.review_year, $scope.review_name, [$scope.cnToUidMap[$scope._getCnFromFullname(collabUser)]], $scope.review_type).then(function(response) {
              var forceUpdate;
              return Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true);
            });
          }
        }
      };
      $scope.removeCollaborator = function(mode, collabUser) {
        console.log("Removing " + collabUser);
        if (mode === 0) {
          return WS.removeReviewers($scope.user.uid, $scope.review_year, $scope.review_name, [collabUser], $scope.review_type).then(function(response) {
            var forceUpdate;
            return Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true);
          });
        } else if (mode === 1) {
          return WS.removeContributors($scope.user.uid, $scope.review_year, $scope.review_name, [collabUser], $scope.review_type).then(function(response) {
            var forceUpdate;
            return Cache.getReviewByUser($scope.user.uid, $scope.review_year, $scope.review_name, $scope.review_type, forceUpdate = true);
          });
        }
      };
    }
  ]);

}).call(this);