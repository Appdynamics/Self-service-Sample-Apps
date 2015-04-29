// Generated by CoffeeScript 1.9.2
(function() {
  var app;

  app = angular.module('appdsampleapp', []);

  app.config([
    '$httpProvider', function($httpProvider) {
      return $httpProvider.interceptors.push([
        '$q', '$rootScope', function($q, $rootScope) {
          if ($rootScope.loaders == null) {
            $rootScope.loaders = 0;
          }
          return {
            request: function(request) {
              $rootScope.loaders++;
              return request;
            },
            requestError: function(error) {
              $rootScope.loaders--;
              if ($rootScope.loaders < 0) {
                $rootScope.loaders = 0;
              }
              return error;
            },
            response: function(response) {
              $rootScope.loaders--;
              if ($rootScope.loaders < 0) {
                $rootScope.loaders = 0;
              }
              return response;
            },
            responseError: function(error) {
              $rootScope.loaders--;
              if ($rootScope.loaders < 0) {
                $rootScope.loaders = 0;
              }
              return error;
            }
          };
        }
      ]);
    }
  ]);

  app.controller('AdminController', [
    '$scope', '$http', '$rootScope', '$timeout', function($scope, $http, $rootScope, $timeout) {
      var activeLoop, performLoopGet, recurses, setupProductUpdate;
      $scope.products = [];
      $scope.ready = false;
      $scope.activeTabIndex = 0;
      setupProductUpdate = function(product) {
        product.loading = false;
        product.stock = parseInt(product.stock, 10);
        product.save = function(decrement) {
          var useStock;
          if (product.name === "" || !angular.isNumber(product.stock)) {
            return;
          }
          useStock = decrement ? product.stock - 1 : product.stock;
          return $http.get('/update', {
            method: 'GET',
            params: {
              id: product.id,
              name: product.name,
              stock: useStock < 0 ? 0 : useStock
            }
          }).success(function(returnProduct) {
            product.stock = parseInt(returnProduct[0].stock, 10);
            return product.lodaing = false;
          }).error(function() {
            alert('Unable to update the product.');
            return product.loading = false;
          });
        };
        product["delete"] = function() {
          return $http.get('/delete', {
            method: 'GET',
            params: {
              id: product.id
            }
          }).success(function() {
            var lookup, results;
            product.loading = false;
            results = [];
            for (lookup in $scope.products) {
              if (!$scope.products.hasOwnProperty(lookup)) {
                continue;
              }
              if ($scope.products[lookup].id === product.id) {
                $scope.products.splice(lookup, 1);
                break;
              } else {
                results.push(void 0);
              }
            }
            return results;
          }).error(function() {
            alert('Unable to delete the product.');
            return product.loading = false;
          });
        };
        return $scope.products.push(product);
      };
      $http.get('/retrieveAll').success(function(data) {
        var product;
        for (product in data) {
          if (!data.hasOwnProperty(product)) {
            continue;
          }
          setupProductUpdate(data[product]);
        }
        $scope.ready = true;
        $scope.activateTab(1);
        return null;
      });
      $scope.looping = false;
      $scope.recursive = 25;
      activeLoop = 0;
      $scope.getActiveLoop = function() {
        if (Number(activeLoop) || activeLoop === 0) {
          if (activeLoop > 0) {
            return 'Sending Request #' + activeLoop + '...';
          } else {
            return '';
          }
        }
        return activeLoop;
      };
      recurses = 0;
      performLoopGet = function() {
        activeLoop++;
        return $http.get('/retrieveAll').success(function() {
          if (activeLoop < recurses) {
            return $timeout(performLoopGet, 500);
          } else {
            activeLoop = 'Completed ' + recurses + ' Requests';
            return $scope.looping = false;
          }
        }).error(function() {
          activeLoop = 'Error';
          return $scope.looping = false;
        });
      };
      $scope.loopingGet = function() {
        $scope.looping = true;
        activeLoop = 0;
        recurses = $scope.recursive;
        return performLoopGet();
      };
      $scope.slowRequest = false;
      $scope.delay = 5;
      $scope.slowRequestGet = function() {
        $scope.slowRequest = true;
        return $http.get('/slowrequest', {
          params: {
            delay: $scope.delay
          }
        }).success(function() {
          recurses = 10;
          performLoopGet();
          return $scope.slowRequest = false;
        }).error(function() {
          return $scope.slowRequest = false;
        });
      };
      $scope.newName = "";
      $scope.newStock = 0;
      $scope.loadingNew = false;
      $scope.addNew = function() {
        if ($scope.newName === "" || !angular.isNumber($scope.newStock)) {
          return;
        }
        $scope.loadingNew = true;
        return $http.get('/add', {
          method: 'GET',
          params: {
            name: $scope.newName,
            stock: $scope.newStock
          }
        }).success(function(data) {
          $scope.loadingNew = false;
          $scope.newName = "";
          $scope.newStock = 0;
          return setupProductUpdate(data[0]);
        }).error(function() {
          alert('Unable to add new product.');
          return $scope.loadingNew = false;
        });
      };
      if ($rootScope.exceptions == null) {
        $rootScope.exceptions = 0;
      }
      if ($rootScope.exceptionsJava == null) {
        $rootScope.exceptionsJava = 0;
      }
      if ($rootScope.exceptionsSql == null) {
        $rootScope.exceptionsSql = 0;
      }
      $scope.raising = false;
      $scope.getExceptions = function() {
        return $rootScope.exceptions;
      };
      $scope.raiseException = function() {
        $scope.raising = true;
        return $http.get('/exception', {
          method: 'GET'
        }).success(function(data) {
          $rootScope.exceptions++;
          return $scope.raising = false;
        }).error(function() {
          alert('Unable to raise exception.');
          return $scope.raising = false;
        });
      };
      $scope.raisingJava = false;
      $scope.getJavaExceptions = function() {
        return $rootScope.exceptionsJava;
      };
      $scope.raiseJavaException = function() {
        $scope.raisingJava = true;
        return $http.get('/exceptionJava', {
          method: 'GET'
        }).success(function(data) {
          $rootScope.exceptionsJava++;
          return $scope.raisingJava = false;
        }).error(function() {
          alert('Unable to raise exception.');
          return $scope.raisingJava = false;
        });
      };
      $scope.raisingSql = false;
      $scope.getSqlExceptions = function() {
        return $rootScope.exceptionsSql;
      };
      $scope.raiseSqlException = function() {
        $scope.raisingSql = true;
        return $http.get('/exceptionSql', {
          method: 'GET'
        }).success(function(data) {
          $rootScope.exceptionsSql++;
          return $scope.raisingSql = false;
        }).error(function() {
          alert('Unable to raise exception.');
          return $scope.raisingSql = false;
        });
      };
      $scope.isTabActive = function(tabIndex) {
        return $scope.activeTabIndex == tabIndex.toString();
      };
      $scope.tabClass = function(tabIndex) {
        return $scope.isTabActive(tabIndex) ? 'active' : '';
      };
      $scope.activateTab = function(tabIndex) {
        $scope.activeTabIndex = tabIndex.toString();
      };
      return null;
    }
  ]);

  app.directive('adLoader', [
    '$rootScope', function($rootScope) {
      return {
        restrict: 'E',
        templateUrl: '/partials/loader.html',
        link: function() {
          if ($rootScope.loaders == null) {
            $rootScope.loaders = 0;
          }
          $rootScope.$on('$routeChangeStart', function() {
            return $rootScope.loaders++;
          });
          return $rootScope.$on('$routeChangeSuccess', function() {
            $rootScope.loaders--;
            if ($rootScope.loaders < 0) {
              return $rootScope.loaders = 0;
            }
          });
        }
      };
    }
  ]);

  app.directive('adProduct', function() {
    return {
      restrict: 'E',
      templateUrl: '/partials/product.html',
      scope: {
        product: '=',
        consumeProduct: '='
      }
    };
  });

}).call(this);
