// Generated by CoffeeScript 1.10.0
(function() {
  "use strict";
  var indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  angular.module("perform").service("Reviews", [
    "$q", "$interval", "$timeout", "WS", "BG", "Cache", "Utils", "$rootScope", "$state", "Auth", function($q, $interval, $timeout, WS, BG, Cache, Utils, $rootScope, $state, Auth) {
      this.saveDefers = [];
      this.saveReviewFilter = [];
      this.reviews = {
        'review': {},
        'self-review': {},
        'weights-performance': {},
        'weights-potential': {}
      };
      this.drafts = {
        'review': {},
        'self-review': {},
        'weights-performance': {},
        'weights-potential': {}
      };
      this.reviewPayload = {};
      this.remove = function(review, reviewType) {
        console.log("Removing " + (this.reviewkey(review)));
        return delete this.reviews[reviewType][this.reviewkey(review)];
      };
      this.getset = function(review, reviewType) {
        var cached, review_packet;
        cached = this.reviews[reviewType][this.reviewkey(review)];
        if (!((review != null ? review.year : void 0) === (cached != null ? cached.year : void 0))) {
          review_packet = {
            uid: review.uid,
            year: review.year,
            rname: review.rname,
            review_body: review.review_body,
            template_id: review.template_id,
            reviewer: review.reviewer,
            datetime: review.datetime,
            change_type: review.change_type,
            locked: review.locked,
            committed: review.committed,
            permitted_users: review.permitted_users,
            review_type: reviewType,
            auto_update_killswitch: null
          };
          this.reviews[reviewType][this.reviewkey(review)] = review_packet;
          this.drafts[reviewType][this.reviewkey(review)] = angular.copy(review_packet.review_body);
        } else {
          review_packet = cached;
        }
        this.is_fresh = true;
        return review_packet;
      };
      this.set = function(review, reviewType) {
        var key, reviewkey, value;
        reviewkey = this.reviewkey(review);
        if (!angular.equals({}, this.reviews[reviewType])) {
          for (key in review) {
            value = review[key];
            if (key === "review_body") {
              continue;
            }
            this.reviews[reviewType][reviewkey][key] = value;
          }
          return _.assign(this.reviews[reviewType][this.reviewkey(review)].review_body, review.review_body);
        }
      };
      this.getDiff = function(oldValue, newValue) {
        var diff, key, value;
        diff = {};
        for (key in newValue) {
          value = newValue[key];
          if (oldValue[key] !== newValue[key]) {
            diff[key] = newValue[key];
          }
        }
        return diff;
      };
      this.getReviewPacketByUserAndYear = function(uid, year, rname, reviewType) {
        return this.reviews[reviewType][uid + "-" + year + "-" + rname];
      };
      this.robustReviewComparison = function(newValue, oldValue) {
        var differentKeys, k, v;
        differentKeys = [];
        for (k in newValue) {
          v = newValue[k];
          if (!_.isEqual(oldValue[k], v)) {
            differentKeys.push(k);
          }
        }
        if (differentKeys.length === 0) {
          return true;
        } else if (differentKeys.length === 1 && differentKeys[0] === 'datetime') {
          return true;
        } else {
          return false;
        }
      };
      this.setSaveStatus = function(string, reviewType, token) {
        if (token == null) {
          token = '';
        }
        if (string === "saving") {
          return this.save[reviewType].status = "Saving ..";
        } else if (string === "pending") {
          return this.save[reviewType].status = "Editing ..";
        } else if (string === 'updating') {
          return this.save[reviewType].status = "Updating ..";
        } else if (string === 'saved') {
          return this.save[reviewType].status = "Saved";
        } else {
          this.save[reviewType].status = "Last edit was " + (Utils.localtime(string).fromNow());
          this.save[reviewType].last = string;
          return this.is_fresh = true;
        }
      };
      this.save = {
        freq: 2,
        'self-review': {},
        'review': {},
        'weights-performance': {},
        'weights-potential': {}
      };
      this.reviewkey = function(review) {
        return review.uid + "-" + review.year + "-" + review.rname;
      };
      this.setSaveReviewsFilter = function(users) {
        return this.saveReviewFilter = users;
      };
      this.saveReviews = function(reviewType) {
        '      ';
        var defer, forceUpdate, newValue, oldValue, ref, request, review, reviewkey, rname, toUpdate, uid, updates, year;
        if (this.saveDefers.length > 0) {
          return;
        }
        toUpdate = [];
        ref = this.reviews[reviewType];
        for (reviewkey in ref) {
          review = ref[reviewkey];
          if (review.locked && reviewType === "review") {
            return;
          }
          uid = review.uid;
          year = review.year;
          rname = review.rname;
          if (this.saveReviewFilter.length > 0) {
            if (indexOf.call(this.saveReviewFilter, uid) < 0) {
              continue;
            }
          }
          oldValue = this.drafts[reviewType][reviewkey];
          newValue = review.review_body;
          updates = this.getDiff(oldValue, newValue);
          if (Object.keys(updates).length !== 0) {
            defer = WS.addDraft(review.uid, review.year, review.rname, updates, review.template_id, review.reviewer, reviewType);
            defer.then(function(response) {
              return console.log("WS.addDraft()", response);
            });
            this.saveDefers.push(defer);
          } else {
            console.log("Update from cache");
            request = {
              uid: uid,
              year: year,
              rname: review.rname,
              review_type: reviewType
            };
            toUpdate.push(request);
          }
        }
        if (toUpdate.length) {
          Cache.getReviewByUserMulti(toUpdate, forceUpdate = true).then((function(_this) {
            return function(responses) {
              var i, len, response, results;
              console.log("Cache.getReviewByUserMulti() (" + reviewType + ")", responses);
              results = [];
              for (i = 0, len = responses.length; i < len; i++) {
                response = responses[i];
                reviewkey = _this.reviewkey(response.latest_review);
                reviewType = response.latest_review.review_type;
                _this.set(response.latest_review, reviewType);
                _this.drafts[reviewType][reviewkey] = response.latest_review.review_body;
                results.push(_this.setSaveStatus(response.latest_review.datetime, reviewType));
              }
              return results;
            };
          })(this));
        }
        this.setSaveReviewsFilter([]);
        if (this.saveDefers.length > 0) {
          this.setSaveStatus("saving", reviewType);
          $q.all(this.saveDefers).then((function(_this) {
            return function(responses) {
              var i, len, response;
              for (i = 0, len = responses.length; i < len; i++) {
                response = responses[i];
                reviewkey = _this.reviewkey(response.latest_review);
                _this.set(response.latest_review, reviewType);
                _this.drafts[reviewType][reviewkey] = response.latest_review.review_body;
              }
              _this.setSaveStatus("saved", reviewType);
              _.map(responses, function(x) {
                return _this.setSaveStatus(x.latest_review.datetime, reviewType);
              });
              return _this.saveDefers = [];
            };
          })(this));
        }
        return BG.resolveAll();
      };
      this.autoUpdate = (function(_this) {
        return function(resetKillSwitch, freq, reviewType) {
          var rid;
          if (resetKillSwitch == null) {
            resetKillSwitch = false;
          }
          if (freq == null) {
            freq = _this.save.freq;
          }
          rid = "xxx".replace(/[xy]/g, function(c) {
            var r, v;
            r = Math.random() * 16 | 0;
            v = (c === "x" ? r : r & 0x3 | 0x8);
            return v.toString(16);
          });
          if (resetKillSwitch) {
            $interval.cancel(_this.autoUpdatePromise);
            _this.autoUpdatePromise = null;
          }
          if (!_this.autoUpdatePromise) {
            if (!_this.is_fresh) {
              _this.setSaveStatus('updating', 'review');
              _this.saveReviews('review');
              _this.saveReviews('self-review');
              _this.saveReviews('weights-performance');
              _this.saveReviews('weights-potential');
            }
            _this.autoUpdatePromise = $interval(function() {
              _this.saveReviews('review');
              _this.saveReviews('self-review');
              _this.saveReviews('weights-performance');
              _this.saveReviews('weights-potential');
              Utils.hidePreventNavigation();
              return BG.resolveAll();
            }, 1000 * freq);
          }
          if (resetKillSwitch) {
            $timeout.cancel(_this.autoUpdateKillSwitch);
            _this.autoUpdateKillSwitch = null;
          }
          if (!_this.autoUpdateKillSwitch) {
            _this.autoUpdateKillSwitch = $timeout(function() {
              var ref, review, reviewkey, rname, uid, year;
              console.log('Inactivity detected. Killing auto update.');
              ref = _this.reviews[reviewType];
              for (reviewkey in ref) {
                review = ref[reviewkey];
                if (review.locked && reviewType === "review") {
                  return;
                }
                uid = review.uid;
                year = review.year;
                rname = review.rname;
                WS.getBusyReviewer(uid, year, rname).then(function(response) {
                  if (response.isCurrentlyEditedBy === Auth.getUser().uid) {
                    return WS.updateIsBusyReviewer(uid, year, rname, false, "admin").then(function(response) {
                      if (response === 'SUCCESS') {
                        return $state.go('editing_in_progress', {
                          isCurrentlyEditedBy: ['admin']
                        });
                      }
                    });
                  }
                });
              }
              $interval.cancel(_this.autoUpdatePromise);
              _this.is_fresh = false;
              _this.autoUpdatePromise = null;
              return _this.autoUpdateKillSwitch = null;
            }, 1000 * 60 * 10);
          }
        };
      })(this);
      this.autoUpdate();
      this.stopAutoUpdate = function() {
        return this.autoUpdateKillSwitch = $timeout((function(_this) {
          return function() {
            console.log('Killing auto update.');
            $interval.cancel(_this.autoUpdatePromise);
            _this.is_fresh = false;
            _this.autoUpdatePromise = null;
            return _this.autoUpdateKillSwitch = null;
          };
        })(this), 1);
      };
    }
  ]);

}).call(this);
