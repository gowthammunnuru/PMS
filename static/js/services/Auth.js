// Generated by CoffeeScript 1.10.0
(function() {
  "use strict";
  angular.module("perform").service("Auth", [
    "WS", "BG", "$rootScope", "$http", "$state", "Portal", "$q", "$cookieStore", "$sanitize", function(WS, BG, $rootScope, $http, $state, Portal, $q, $cookieStore, $sanitize) {
      this.rejectState = [];
      this.getCookie = function() {
        var data;
        data = $cookieStore.get('session');
        if (!data) {
          data = {};
        } else {
          data = JSON.parse(data);
        }
        return data;
      };
      this.setCookie = function(data) {
        return $cookieStore.put('session', JSON.stringify(data));
      };
      this.clearCookie = function() {
        return $cookieStore.remove('session');
      };
      this.getStatus = function() {
        'See if someone\'s logged in or not';
        return this.getSession().status === "logged-in";
      };
      this.getUser = function() {
        if (this.getStatus()) {
          return this.getSession().user;
        }
      };
      this.isAdmin = function() {
        if (this.getStatus()) {
          return this.getUser().is_admin;
        }
      };
      this.getSession = function() {
        'Get session object';
        return this.getCookie();
      };
      this.userHasAdminMgmtRights = function() {
        if (this.getStatus()) {
          return _.contains(this.getUser().permissions,'SETUP_ROLES')
        }
      };

      this.userHasEditReviewsRights = function() {
        if (this.getStatus()) {
         return  _.contains(this.getUser().permissions,'SETUP_REVIEWS')
        }

      };
      this.setSession = (function(_this) {
        return function(response) {
          'Set session object';
          var data, retVal;
          if (response.error) {
            data = {
              user: '',
              status: 'auth_error'
            };
            retVal = data;
          } else {
            retVal = Portal.getUserInfo(response.uid).then(function(r) {
              if (typeof r !== "undefined") {
                console.log($sanitize(r));
                r.sid = response.sid;
                r.is_admin = response.is_admin;
                data = {
                  user: r,
                  status: 'logged-in'
                };
                return _this.setCookie(data);
              } else {
                data = {
                  user: '',
                  status: 'auth_error'
                };
                return retVal = data;
              }
            });
          }
          return $q.when(retVal).then(function(retVal) {
            return response;
          });
        };
      })(this);
      this.clearSession = function() {
        return this.clearCookie();
      };

      this.login = function(auth) {
        return Portal.loginCheckThroughHttp(auth).then(this.setSession); // Without the Websocket call
        // return WS.login(auth).then(this.setSession); // With the websocket call
      };
      this.logout = function() {
        $rootScope.deferPresent = true;
        return BG.addToDefer().then(function(response) {
          $rootScope.Auth.clearSession();
          $http.get('/logout'); // If login is without Websocket, this will help in deleting the secure cookie
          return $state.go('landing');
        });
      };
    }
  ]);

}).call(this);
