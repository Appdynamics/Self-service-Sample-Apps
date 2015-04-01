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
  '$scope', '$http', '$rootScope'
  ($scope, $http, $rootScope) ->
    $scope.initialLoad = true

    $http.get '/retrieveAll'
      .success (data) ->
        $scope.initialLoad = false
        $scope.products = data
      .error ->
        alert 'Unable to retrieve product information!'

    $scope.consumeProduct = (product, $event) ->
      product.loading = true
      $http.get '/update',
        method: 'GET'
        params:
          id: product.id
          name: product.name
          stock: if product.stock - 1 > 0 then product.stock - 1 else 0
      .success (data) ->
        if not data.length
          alert 'Unable to purchase product!'
        else
          product.stock = data[0].stock
        product.loading = false
      .error ->
        alert 'Unable to purchase product!'
        product.loading = false

    if not $rootScope.exceptions?
      $rootScope.exceptions = 0

    $scope.raising = false
    $scope.getExceptions = ->
      $rootScope.exceptions
    $scope.raiseException = ->
      $scope.raising = true
      $http.get '/exception',
        method: 'GET'
      .success (data) ->
        $rootScope.exceptions++
        $scope.raising = false
      .error ->
        alert 'Unable to raise exception!'
        $scope.raising = false

]

app.controller 'AdminController', [
  '$scope', '$http'
  ($scope, $http) ->
    $scope.products = []

    setupProductUpdate = (product) ->
      product.loading = false
      product.stock = parseInt product.stock, 10
      product.save = ->
        if product.name == "" or not angular.isNumber product.stock
          return
        $http.get '/update',
          method: 'GET'
          params:
            id: product.id
            name: product.name
            stock: product.stock
        .success ->
          product.lodaing = false
        .error ->
          alert 'Unable to update the product!'
          product.loading = false
      product.delete = ->
        $http.get '/delete',
          method: 'GET'
          params:
            id: product.id
        .success ->
          product.loading = false
          for lookup of $scope.products
            if not $scope.products.hasOwnProperty lookup then continue
            if $scope.products[lookup].id == product.id
              $scope.products.splice lookup, 1
              break
        .error ->
          alert 'Unable to delete the product!'
          product.loading = false
      $scope.products.push product

    $http.get '/retrieveAll'
      .success (data) ->
        for product of data
          if not data.hasOwnProperty product then continue
          setupProductUpdate data[product]

    $scope.newName = ""
    $scope.newStock = 0

    $scope.loadingNew = false
    $scope.addNew = ->
      if $scope.newName == "" or not angular.isNumber $scope.newStock
        return
      $scope.loadingNew = true
      $http.get '/add',
        method: 'GET'
        params:
          name: $scope.newName
          stock: $scope.newStock
      .success (data) ->
        $scope.loadingNew = false
        $scope.newName = ""
        $scope.newStock = 0
        setupProductUpdate data[0]
      .error ->
        alert 'Unable to add new product!'
        $scope.loadingNew = false

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

