// Generated by CoffeeScript 1.10.0
angular.module("perform").filter("BreakNewLineFilter", [
  function() {
    return function(input) {
      if (input) {
        return input.replace(/\n/g, '<br />');
      } else {
        return input;
      }
    };
  }
]);

//# sourceMappingURL=BreakNewLineFilter.js.map
