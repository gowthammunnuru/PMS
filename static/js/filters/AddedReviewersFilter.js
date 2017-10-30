// Generated by CoffeeScript 1.8.0
angular.module("perform").filter("AddedReviewersFilter", [
  function() {
    return function(input, current_reviewers_uid, map) {
      var i, item, _i, _len, _results;
      i = void 0;
      if (current_reviewers_uid === undefined) {
        return input;
      }
      _results = [];
      for (_i = 0, _len = input.length; _i < _len; _i++) {
        item = input[_i];
        if (current_reviewers_uid.indexOf(map[item]) === -1) {
          _results.push(item);
        }
      }
      return _results;
    };
  }
]);
