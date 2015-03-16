require("appdynamics").profile({
  controllerHostName: "",
  controllerPort: "",
  accountName: "",
  accountAccessKey: "",
  controllerSslEnabled: "",
  applicationName: "",
  tierName: "NodeServer",
  nodeName: "NodeServer01",
  debug: true
});

var express = require('express');
var server = express();
var request = require('request');
var xml2js = require('xml2js');
var xmlParser = new xml2js.Parser();
var node = 8888;
var axis = 8887;

function setupStoreFrontCall(nodePath, apiRequest) {
  server.get('/' + nodePath, function(serverRequest, response) {
    var url = 'http://localhost:' + axis + '/axis2/services/StoreFrontService/' + apiRequest + '?';
    var params = '';
    for (var key in serverRequest.query) {
      if (serverRequest.query.hasOwnProperty(key)) {
        if (params != '') {
          url += '&';
        }
        url += key + '=' + serverRequest.query[key];
      }
    }
    request(url + '&t=' + (new Date()).getTime(), function(error, apiResponse, body) {
      if (apiResponse && body) {
        xmlParser.parseString(body, function (err, result) {
          response.send(result["ns:getAllProductsResponse"]["ns:return"][0]);
        });
      } else {
        response.send("{error: 'No Response'}");
      }
    });
  });
}

server.use(express.static(__dirname + '/public'));
setupStoreFrontCall('retrieveAll', 'getAllProducts');
setupStoreFrontCall('retrieve', 'getProduct');
setupStoreFrontCall('add', 'addProduct');
setupStoreFrontCall('update', 'updateProduct');
setupStoreFrontCall('delete', 'deleteProduct');
setupStoreFrontCall('consume', 'consumeProduct');
setupStoreFrontCall('restock', 'setProductStock');

server.listen(node, 'localhost', function () {
  console.log('Node Server Started');
});
server.on('error', function (e) {
  console.log('Node Server Failed');
  console.log(e);
});