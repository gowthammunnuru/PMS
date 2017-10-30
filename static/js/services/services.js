// Generated by CoffeeScript 1.10.0
(function() {
  angular.module("perform").service("HTTP", function($http) {
    this.search = function(query) {
      var url;
      url = "ip/" + query;
      return $http.get(url);
    };
  });

  angular.module("perform").service("BG", [
    "$q", "$state", "$rootScope", function($q, $state, $rootScope) {
      $rootScope.deferList = [];
      this.addToDefer = function() {
        var defer;
        defer = $q.defer();
        if ($rootScope.preventNavigation) {
          $rootScope.deferList.push(defer);
        } else {
          defer.resolve("Success");
        }
        return defer.promise;
      };
      this.resolveAll = function() {
        var defer, i, len, ref;
        ref = $rootScope.deferList;
        for (i = 0, len = ref.length; i < len; i++) {
          defer = ref[i];
          defer.resolve(true);
        }
        return $rootScope.deferPresent = false;
      };
      this.go = function(state, params, options) {
        $rootScope.deferPresent = true;
        return this.addToDefer().then(function(response) {
          return $state.go(state, params, options);
        });
      };
    }
  ]);

  angular.module("perform").service("WS", [
    "$q", "$rootScope", "$state", function($q, $rootScope, $state) {
      var REVOKE_ADMIN_RIGHTS, _listener, callbacks, currentCallbackId, host, initDefer, port, requestsBacklog, sendRequest, uri, ws;
      REVOKE_ADMIN_RIGHTS = 'REVOKE_ADMIN_RIGHTS';
      _listener = function(data) {
        var messageObj;
        messageObj = data;
        if (callbacks.hasOwnProperty(messageObj.callback_id)) {
          if (messageObj.data.error && (messageObj.data.error === 'auth_error' || messageObj.data.error === 'error')) {
            console.log("ERROR: " + messageObj.data.error);
            $state.transitionTo('auth_error', {}, {
              location: 'replace',
              inherit: true,
              relative: $state.$current,
              notify: true
            });
            $rootScope.$apply(callbacks[messageObj.callback_id].cb.reject(messageObj.data));
          } else if (messageObj.data.error && messageObj.data.error === 'waitlist_error') {
            $state.go('editing_in_progress', {
              isCurrentlyEditedBy: [messageObj.data.isCurrentlyEditedBy]
            });
          } else {
            $rootScope.$apply(callbacks[messageObj.callback_id].cb.resolve(messageObj.data));
          }
          delete callbacks[messageObj.callbackID];
        }
      };
      sendRequest = function(request) {
        var callbackId, data, defer;
        request.query.auth = $rootScope.auth().user;
        defer = $q.defer();
        callbackId = "xxxxxxxxx".replace(/[xy]/g, function(c) {
          var r, v;
          r = Math.random() * 16 | 0;
          v = (c === "x" ? r : r & 0x3 | 0x8);
          return v.toString(16);
        });
        data = {};
        data.request = request;
        data.callback_id = callbackId;
        callbacks[callbackId] = {
          cb: defer
        };
        if (ws.readyState !== 0) {
          ws.send(JSON.stringify(data));
        } else {
          requestsBacklog.push(data);
        }
        return defer.promise;
      };
      callbacks = {};
      currentCallbackId = 0;
      requestsBacklog = [];
      host = "" + window.location.host;
      if (host.split(":").length === 2) {
        port = host.split(":")[1];
        host = host.split(":")[0];
        uri = "ws://" + host + ":" + port + "/ws/ip";
      } else {
        port = 443;
        uri = "wss://" + host + ":" + port + "/ws/ip";
      }
      console.log("Connecting to " + uri);
      initDefer = $q.defer();
      initDefer.promise.then(function(x) {
        var i, len, request;
        for (i = 0, len = requestsBacklog.length; i < len; i++) {
          request = requestsBacklog[i];
          ws.send(JSON.stringify(request));
        }
      });
      ws = new ReconnectingWebSocket(uri);
      ws.onopen = function() {
        $rootScope.$broadcast('connection-open');
        $rootScope.$apply(initDefer.resolve(true));
      };
      ws.onmessage = function(message) {
        _listener(JSON.parse(message.data));
      };
      ws.onclose = function() {
        return $rootScope.$broadcast('connection-lost');
      };
      this.login = function(auth) {
        var d, promise;
        d = {
          type: 'login',
          query: {
            user: auth.user,
            pass: auth.pass
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getReviewByUser = function(uid, year, rname, reviewType) {
        var d, promise;
        d = {
          type: 'get_review',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.checkBusyReviewerForMulti = function(requests) {
        var d, promise;
        d = {
          type: 'check_busy_reviewer_for_multi',
          query: {
            review_list: requests
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getReviewByUserMulti = function(requests) {
        var d, promise;
        d = {
          type: 'get_review_multi',
          query: {
            requests: requests
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getEditableReviews = function(uid) {
        var d, promise;
        d = {
          type: 'get_editable_reviews',
          query: {
            uid: uid
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getTemplate = function(query) {
        var d, promise;
        d = {
          type: "template_lookup",
          query: query
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getAllTemplateTypes = function(year, rname) {
        var d, promise;
        d = {
          type: 'get_all_template_types',
          query: {
            year: year,
            rname: rname,
            review_type: 'weights'
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getAllReviewsByYear = function(uid, year, rname) {
        var d, promise;
        d = {
          type: 'get_all_reviews_by_year',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getAllAdmins = function() {
        var d, promise;
        d = {
          type: 'get_all_admins',
          query: {
            activity: 'SETUP_ROLES'
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.removeAdmin = function(user) {
        var d, promise;
        d = {
          type: 'modify_admins',
          query: {
            uid: user.uid,
            uname: user.givenName + " " + user.surname,
            ou: user.ou,
            date: new Date(),
            roles: user.roles,
            permissions: user.permissions,
            action: REVOKE_ADMIN_RIGHTS,
            activity: 'SETUP_ROLES'
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addAdmin = function(user) {
        var d, promise;
        d = {
          type: 'modify_admins',
          query: {
            uid: user.uid,
            uname: user.givenName + " " + user.surname,
            ou: user.ou,
            date: new Date(),
            roles: user.roles,
            permissions: user.permissions,
            action: '',
            activity: 'SETUP_ROLES'
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getAdminData = function(uid) {
        var d, promise;
        d = {
          type: 'get_admin_data',
          query: {
            uid: uid,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.setTemplateID = function(uid, year, rname, template_id) {
        var d, promise;
        d = {
          type: 'set_template_id',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.okToPublishReview = function(uid, year, rname, template_id) {
        var d, promise;
        d = {
          type: 'ready2publish_review',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.publishReview = function(uid, year, rname, template_id) {
        var d, promise;
        d = {
          type: 'publish_review',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.commitReview = function(uid, year, rname, reviewType, template_id) {
        var d, promise;
        d = {
          type: 'commit_review',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.uncommitReview = function(uid, year, rname, reviewType, template_id) {
        var d, promise;
        d = {
          type: 'uncommit_review',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.acknowledgeReview = function(uid, year, rname, reviewType, template_id) {
        var d, promise;
        d = {
          type: 'acknowledge_review',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.sendSelfReviewReminder = function(uid, year, rname) {
        var d, promise;
        d = {
          type: 'send_self_review_reminder',
          query: {
            uid: uid,
            year: year,
            rname: rname
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.setPermissions = function(uid, year, rname, template_id, permitted_users) {
        var d, promise;
        d = {
          type: 'set_permissions',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            template_id: template_id,
            permitted_users: permitted_users
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addSelfReview = function(uid, year, rname, review_body, template_id, reviewer) {
        'change_type can be \'review_add\'';
        var d, promise;
        d = {
          type: 'self_review_add',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            review_body: review_body,
            template_id: template_id,
            reviewer: reviewer
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addReview = function(uid, year, rname, review_body, template_id, reviewer) {
        'change_type can be \'review_add\'';
        var d, promise;
        d = {
          type: 'review_add',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            review_body: review_body,
            template_id: template_id,
            reviewer: reviewer
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addDraft = function(uid, year, rname, review_body, template_id, reviewer, reviewType) {
        'change_type can be \'review_draft\'';
        var d, promise;
        d = {
          type: 'review_draft',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            review_body: review_body,
            template_id: template_id,
            reviewer: reviewer,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addReviewers = function(uid, year, rname, users, reviewType) {
        var d, promise;
        d = {
          type: 'set_reviewers',
          query: {
            mode: 'add',
            uid: uid,
            year: year,
            rname: rname,
            users: users,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.removeReviewers = function(uid, year, rname, users, reviewType) {
        var d, promise;
        d = {
          type: 'set_reviewers',
          query: {
            mode: 'remove',
            uid: uid,
            year: year,
            rname: rname,
            users: users,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.updateIsBusyReviewer = function(uid, year, rname, isBusy, isCurrentlyEditedBy) {
        var d, promise;
        d = {
          type: 'update_busy_reviewer',
          query: {
            uid: uid,
            year: year,
            rname: rname,
            isBusy: isBusy,
            isCurrentlyEditedBy: isCurrentlyEditedBy
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getBusyReviewer = function(uid, year, rname) {
        var d, promise;
        d = {
          type: 'get_busy_reviewer',
          query: {
            uid: uid,
            year: year,
            rname: rname
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addContributors = function(uid, year, rname, users, reviewType) {
        var d, promise;
        d = {
          type: 'set_contributors',
          query: {
            mode: 'add',
            uid: uid,
            year: year,
            rname: rname,
            users: users,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.removeContributors = function(uid, year, rname, users, reviewType) {
        var d, promise;
        d = {
          type: 'set_contributors',
          query: {
            mode: 'remove',
            uid: uid,
            year: year,
            rname: rname,
            users: users,
            review_type: reviewType
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getUser = function(uid) {
        var d, promise;
        d = {
          type: 'get_user',
          query: {
            uid: uid
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.setupReview = function(year, rname, data) {
        var d, promise;
        d = {
          type: 'setup_review',
          query: {
            year: year,
            rname: rname,
            data: data,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.archiveReview = function(year, rname) {
        'Request to archvie a review';
        var d, promise;
        d = {
          type: 'archive_review',
          query: {
            year: year,
            rname: rname,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.unarchiveReview = function(year, rname) {
        'Request to unarchvie a review';
        var d, promise;
        d = {
          type: 'unarchive_review',
          query: {
            year: year,
            rname: rname,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getFeedback = function(uid) {
        var d, promise;
        d = {
          type: 'get_feedback',
          query: {
            uid: uid
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.addFeedback = function(uid, feedback_body, change_type) {
        var d, promise;
        d = {
          type: 'add_feedback',
          query: {
            uid: uid,
            feedback_body: feedback_body,
            change_type: change_type
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.getAppMetadata = function() {
        'Get app metadata from the backend';
        var d, promise;
        d = {
          type: "app_metadata",
          query: ''
        };
        promise = sendRequest(d);
        return promise;
      };
      this.fetchBacklogStats = function(ryear, rtype) {
        'Fetches the number of reviews per person';
        var d, promise;
        d = {
          type: 'fetch_backlog_stats',
          query: {
            review_year: ryear,
            review_type: rtype,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
      this.setTemplateWeights = function(template_id, year, rname) {
        'Initializes template weights';
        var d, promise;
        d = {
          type: 'set_template_weights',
          query: {
            template_id: template_id,
            year: year,
            rname: rname,
            activity: "EDIT_REVIEWS"
          }
        };
        promise = sendRequest(d);
        return promise;
      };
    }
  ]);

}).call(this);
