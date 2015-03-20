app = angular.module 'storefront', ['ngRoute']

app.config [
  '$routeProvider', '$httpProvider'
  ($routeProvider, $httpProvider) ->
    $routeProvider
      .when '/store',
        templateUrl: '/partials/store.html'
        controller: 'StoreFrontController'
      .when '/admin',
        templateUrl: '/partials/admin.html'
        controller: 'AdminController'
      .otherwise
        redirectTo: '/store'

    $httpProvider.interceptors.push [
      '$q', '$rootScope',
      ($q, $rootScope) ->
        if not $rootScope.loaders?
          $rootScope.loaders = 0

        request: (request) ->
          $rootScope.loaders++
          request
        requestError: (error) ->
          $rootScope.loaders--
          if $rootScope.loaders < 0 then $rootScope.loaders = 0
          error
        response: (response) ->
          $rootScope.loaders--
          if $rootScope.loaders < 0 then $rootScope.loaders = 0
          response
        responseError: (error) ->
          $rootScope.loaders--
          if $rootScope.loaders < 0 then $rootScope.loaders = 0
          error
    ]
]

app.controller 'StoreFrontController', [
  '$scope', '$http'
  ($scope, $http) ->
    $http.get '/retrieveAll'
      .success (data) ->
        $scope.products = data

    $scope.consumeProduct = (product, $event) ->
      product.loading = true
      $http.get '/consume',
        method: 'GET'
        params:
          id: product.id
      .success (data) ->
        product.stock = data[0].stock
        product.loading = false
      .error ->
        alert 'Unable to purchase product!'
        product.loading = false
]

app.controller 'AdminController', [
  '$scope', '$http'
  ($scope, $http) ->
    $scope.addProduct = ->

    $http.get '/retrieveAll'
      .success (data) ->
        $scope.products = data
]

app.directive 'adLoader', [
  '$rootScope',
  ($rootScope) ->
    restrict: 'E'
    templateUrl: '/partials/loader.html'
    link: () ->
      if not $rootScope.loaders?
        $rootScope.loaders = 0
      $rootScope.$on '$routeChangeStart', ->
        $rootScope.loaders++
      $rootScope.$on '$routeChangeSuccess', ->
        $rootScope.loaders--
        if $rootScope.loaders < 0 then $rootScope.loaders = 0
]

app.directive 'adProduct', ->
  restrict: 'E'
  templateUrl: '/partials/product.html'
  scope:
    product: '='
    consumeProduct: '='

